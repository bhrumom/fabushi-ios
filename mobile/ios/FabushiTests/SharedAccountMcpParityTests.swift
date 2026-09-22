import XCTest
@testable import Fabushi

private enum AccountMcpTestError: Error {
    case unavailable
}

private final class FakeAccountMcpClient: @unchecked Sendable, AccountMcpClient {
    var available: [AvailableMcpServer] = []
    var configResponse = AccountMcpConfigResponse(configJson: #"{"mcpServers":{}}"#, serverMetadataByName: [:])
    var effective: [EffectivePluginWire] = []
    var failAvailable = false
    var installed: [UInt64] = []
    var uninstalled: [UInt64] = []
    var updated: [(UInt64, [String: String])] = []
    var writtenConfig: String?
    var writtenServerIds: [String: UInt64] = [:]

    func getAvailableMcpServers(timeoutMs: Int) async throws -> [AvailableMcpServer] {
        if failAvailable { throw AccountMcpTestError.unavailable }
        return available
    }

    func getMcpConfig(
        teamScope: Bool,
        redactSecrets: Bool,
        teamId: UInt64?,
        timeoutMs: Int?
    ) async throws -> AccountMcpConfigResponse {
        configResponse
    }

    func getEffectiveUserPlugins(excludeConfiguredVariables: Bool) async throws -> [EffectivePluginWire] {
        effective
    }

    func setMcpConfig(configJson: String, serverIdsByName: [String: UInt64]) async throws {
        writtenConfig = configJson
        writtenServerIds = serverIdsByName
    }

    func installUserPlugin(pluginId: UInt64, variables: [String: String]?) async throws {
        installed.append(pluginId)
    }

    func uninstallUserPlugin(pluginId: UInt64) async throws {
        uninstalled.append(pluginId)
    }

    func updateUserPluginInstall(pluginId: UInt64, variables: [String: String]) async throws {
        updated.append((pluginId, variables))
    }
}

final class SharedAccountMcpParityTests: XCTestCase {
    func testConfigParserPreservesStdioRemoteAuthAndTls() throws {
        let parsed = try XCTUnwrap(parseAccountMcpConfigJson(#"""
        {
          "mcpServers": {
            "local": {
              "type": "stdio",
              "command": "node",
              "args": ["server.js"],
              "env": {"A":"B"},
              "cwd": "/workspace"
            },
            "remote": {
              "type": "sse",
              "url": "https://mcp.example.test",
              "headers": {"X-Test":"1"},
              "auth": {
                "CLIENT_ID": "client",
                "CLIENT_SECRET": "secret",
                "scopes": ["read"]
              },
              "tls": {"caBundle":"  CERT  "}
            }
          }
        }
        """#))

        guard case .stdio(let local) = parsed.mcpServers["local"] else {
            return XCTFail("expected stdio config")
        }
        XCTAssertEqual(local.command, "node")
        XCTAssertEqual(local.args, ["server.js"])
        XCTAssertEqual(local.env, ["A": "B"])
        XCTAssertEqual(local.cwd, "/workspace")

        guard case .remote(let remote) = parsed.mcpServers["remote"] else {
            return XCTFail("expected remote config")
        }
        XCTAssertEqual(remote.type, "sse")
        XCTAssertEqual(remote.auth?.clientID, "client")
        XCTAssertEqual(remote.auth?.scopes, ["read"])
        XCTAssertEqual(remote.tls?.caBundle, "CERT")

        let encoded = try accountMcpConfigJson(parsed)
        XCTAssertNotNil(parseAccountMcpConfigJson(encoded))
    }

    func testParserRejectsUnsafeOrMalformedConfiguration() {
        XCTAssertNil(parseAccountMcpConfigJson(""))
        XCTAssertNil(parseAccountMcpConfigJson(#"{"mcpServers":{"bad":{"type":"http","command":"sh"}}}"#))
        XCTAssertNil(parseAccountMcpConfigJson(#"{"mcpServers":{"bad":{"url":"https://x","headers":{"A":1}}}}"#))
        XCTAssertNil(parseAccountMcpConfigJson(#"{"mcpServers":{"bad":{"url":"https://x","tls":{"caBundle":"CERT","extra":"x"}}}}"#))
    }

    func testMetadataHelpersMatchReferenceSemantics() {
        XCTAssertEqual(normalizeMcpAccountLabel("  Work@Example.COM "), "work@example.com")
        XCTAssertEqual(teamServerTransport("SSE"), "sse")
        XCTAssertEqual(teamServerTransport("websocket"), "http")
        XCTAssertEqual(
            serverIdsByNameFromMetadata([
                "keep": .init(serverId: 12),
                "drop": .init(serverId: 0),
                "missing": .init(),
            ]),
            ["keep": 12]
        )
        XCTAssertEqual(toEffectivePluginInstallMode(1), .user)
        XCTAssertEqual(toEffectivePluginInstallMode(3), .teamRequired)
        XCTAssertEqual(toEffectivePluginInstallMode(99), .unknown)
    }

    func testFetchCombinesBackendMetadataWithoutRunningLocalProcesses() async throws {
        let client = FakeAccountMcpClient()
        client.available = [
            .init(
                id: 1, name: "stdio", serverIdentifier: "stdio-id", type: "stdio",
                enabled: true, isTeamServer: false, disabledByTeamAdminPolicy: false,
                pluginId: 100,
                accounts: [.init(accountKey: " USER@EXAMPLE.COM ", serverIdentifier: "slot", userHasAccessToken: true)]
            ),
            .init(
                id: 2, name: "remote", serverIdentifier: "remote-id", type: "http",
                url: "https://mcp.example.test", enabled: true, isTeamServer: false,
                disabledByTeamAdminPolicy: false
            ),
            .init(
                id: 3, name: "blocked", serverIdentifier: "blocked-id", type: "stdio",
                command: "blocked-command", args: ["--safe-metadata-only"],
                enabled: false, isTeamServer: false, disabledByTeamAdminPolicy: true
            ),
            .init(
                id: 4, name: "unresolved", serverIdentifier: "unresolved-id", type: "stdio",
                enabled: true, isTeamServer: false, disabledByTeamAdminPolicy: false
            ),
        ]
        client.configResponse = .init(
            configJson: #"{"mcpServers":{"stdio":{"command":"npx","args":["-y","server"]}}}"#,
            serverMetadataByName: ["stdio": .init(serverId: 1)]
        )

        let deps = AccountMcpDependencies(
            getAccessToken: { _ in "token-a" },
            getMachineId: { "machine" },
            getBackendUrl: { "https://api.example.test" },
            createClient: { _ in client }
        )
        let result = try XCTUnwrap(await fetchAccountMcpServers(deps))

        XCTAssertEqual(result.cacheScope, accountCacheScope("token-a"))
        XCTAssertEqual(result.servers.map(\.id), ["1", "2", "3"])
        XCTAssertEqual(result.unresolvedServerIds, ["4"])
        XCTAssertFalse(result.unavailable)

        let stdio = try XCTUnwrap(result.servers.first(where: { $0.id == "1" }))
        guard case .stdio(let config) = stdio.config else {
            return XCTFail("expected metadata-only stdio config")
        }
        XCTAssertEqual(config.command, "npx")
        XCTAssertEqual(stdio.accounts?.first?.accountKey, "user@example.com")
        XCTAssertEqual(stdio.pluginId, "100")
    }

    func testFetchDistinguishesAuthenticationFailureFromBackendUnavailability() async {
        let client = FakeAccountMcpClient()
        client.failAvailable = true

        let backendDown = await fetchAccountMcpServers(.init(
            getAccessToken: { _ in "token-a" },
            getMachineId: { "machine" },
            getBackendUrl: { "https://api.example.test" },
            createClient: { _ in client }
        ))
        XCTAssertEqual(backendDown?.unavailable, true)
        XCTAssertEqual(backendDown?.cacheScope, accountCacheScope("token-a"))

        let noIdentity = await fetchAccountMcpServers(.init(
            getAccessToken: { _ in throw AccountMcpTestError.unavailable },
            getMachineId: { "machine" },
            getBackendUrl: { "https://api.example.test" },
            createClient: { _ in client }
        ))
        XCTAssertNil(noIdentity)
    }

    func testEffectivePluginsBackfillAndWriterPreserveBackendContracts() async throws {
        let client = FakeAccountMcpClient()
        client.available = [
            .init(
                id: 7, name: "plugin-server", serverIdentifier: "plugin",
                type: "http", url: "https://plugin.example.test",
                enabled: true, isTeamServer: false, disabledByTeamAdminPolicy: false,
                pluginId: 55
            ),
        ]
        client.effective = [
            .init(
                plugin: .init(id: 44, name: "required", displayName: ""),
                installMode: 0,
                isTeamRequired: true,
                isEnabled: true
            ),
        ]
        client.configResponse = .init(
            configJson: #"{"mcpServers":{"remote":{"url":"https://mcp.example.test"}}}"#,
            serverMetadataByName: ["remote": .init(serverId: 9)]
        )

        let deps = AccountMcpDependencies(
            getAccessToken: { _ in "token" },
            getMachineId: { "machine" },
            getBackendUrl: { "https://api.example.test" },
            createClient: { _ in client }
        )

        let effective = try await fetchEffectiveUserPlugins(deps)
        XCTAssertEqual(effective.first?.installMode, .teamRequired)
        XCTAssertEqual(effective.first?.displayName, "required")

        XCTAssertEqual(await backfillUserPluginInstalls(deps), ["55"])
        XCTAssertEqual(client.installed, [55])

        let writer = createAccountMcpWriter(deps)
        let edit = try await writer.getConfigForEdit()
        XCTAssertEqual(edit.serverIdsByName, ["remote": 9])
        try await writer.setConfig(edit.config, serverIdsByName: edit.serverIdsByName)
        XCTAssertNotNil(client.writtenConfig)
        XCTAssertEqual(client.writtenServerIds, ["remote": 9])

        try await writer.uninstallPlugin(pluginId: 55)
        try await writer.updatePluginInstall(pluginId: 44, variables: ["TOKEN": "value"])
        XCTAssertEqual(client.uninstalled, [55])
        XCTAssertEqual(client.updated.first?.0, 44)
        XCTAssertEqual(client.updated.first?.1, ["TOKEN": "value"])
    }
}
