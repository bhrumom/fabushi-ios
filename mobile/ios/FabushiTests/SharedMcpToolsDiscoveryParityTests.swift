import XCTest
@testable import Fabushi

private actor FakeRunnerMcpPort: RunnerMcpExecuting {
    private(set) var loadedConfigs: [String] = []
    private(set) var listRequests: [[String]] = []
    private(set) var executions: [McpToolExecutionRequest] = []
    var servers: [RunnerMcpToolServer] = []

    func loadServers(configJson: String) async throws {
        loadedConfigs.append(configJson)
    }

    func listTools(serverIdentifiers: [String]) async throws -> [RunnerMcpToolServer] {
        listRequests.append(serverIdentifiers)
        return servers
    }

    func executeTool(
        providerIdentifier: String,
        toolName: String,
        args: McpJSONValue,
        toolCallId: String,
        agentId: String?
    ) async -> SandMcpResult {
        executions.append(.init(
            providerIdentifier: providerIdentifier,
            name: toolName,
            args: args,
            toolCallId: toolCallId
        ))
        return .init(result: .success(.init(
            content: [.init(content: .text(.init(text: "runner-ok")))],
            isError: false,
            structuredContent: nil
        )))
    }

    func setServers(_ value: [RunnerMcpToolServer]) { servers = value }
    func loadedCount() -> Int { loadedConfigs.count }
    func executionCount() -> Int { executions.count }
}

private final class BackendDiscoveryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _listCalls = 0
    private var _executeCalls = 0

    func listCalled() {
        lock.lock()
        _listCalls += 1
        lock.unlock()
    }

    func executeCalled() {
        lock.lock()
        _executeCalls += 1
        lock.unlock()
    }

    var listCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return _listCalls
    }

    var executeCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return _executeCalls
    }
}

final class SharedMcpToolsDiscoveryParityTests: XCTestCase {
    private func makeSettings() throws -> (SandSettingsStore, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (
            SandSettingsStore(settingsPath: root.appendingPathComponent("settings.json").path),
            root
        )
    }

    private static func success(_ text: String) -> SandMcpResult {
        .init(result: .success(.init(
            content: [.init(content: .text(.init(text: text)))],
            isError: false,
            structuredContent: nil
        )))
    }

    func testHTTPUsesBackendAndStdioUsesRunnerOnly() async throws {
        let (settings, root) = try makeSettings()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = SandMcpDefinitionSource(includeBuiltins: false)
        await source.adoptAccountConfig(.init(mcpServers: [
            "remote": .http(url: "https://mcp.example.test"),
            "local": .stdio(command: "node", args: ["server.js"]),
        ]))

        let runner = FakeRunnerMcpPort()
        await runner.setServers([
            .init(
                serverIdentifier: "local",
                status: "connected",
                tools: [
                    .init(
                        providerIdentifier: "local",
                        name: "run",
                        toolName: "run"
                    ),
                ]
            ),
        ])
        let backend = BackendDiscoveryRecorder()
        let discovery = SandMcpToolsDiscovery(deps: .init(
            definitionSource: source,
            settingsStore: settings,
            backendListTools: { names in
                backend.listCalled()
                XCTAssertEqual(names, ["remote"])
                return [
                    .init(
                        serverIdentifier: "remote",
                        status: "connected",
                        tools: [
                            .init(
                                name: "search",
                                providerIdentifier: "remote",
                                toolName: "search",
                                clientKey: "remote",
                                description: nil,
                                inputSchema: nil
                            ),
                        ],
                        accountLabel: "default",
                        rowServerIdentifier: "remote"
                    ),
                ]
            },
            backendExecuteTool: { _, _, _, _, _ in
                backend.executeCalled()
                return Self.success("backend-ok")
            },
            runnerMcpExec: runner
        ))
        await discovery.setAccountDisplay(.init(servers: [
            .init(
                id: "1",
                name: "Remote",
                serverIdentifier: "remote",
                config: .http(url: "https://mcp.example.test"),
                isTeamServer: false
            ),
            .init(
                id: "2",
                name: "Local",
                serverIdentifier: "local",
                config: .stdio(command: "node", args: ["server.js"]),
                isTeamServer: false
            ),
        ]))

        let tools = try await discovery.getTools()
        XCTAssertEqual(Set(tools.map(\.providerIdentifier)), Set(["remote", "local"]))
        XCTAssertEqual(backend.listCalls, 1)
        let loadedCount = await runner.loadedCount()
        XCTAssertEqual(loadedCount, 1)

        let backendResult = await discovery.executeTool(.init(
            providerIdentifier: "remote",
            name: "search",
            args: .object([:]),
            toolCallId: "call-http"
        ))
        if case .error(let message) = backendResult.result {
            XCTFail("unexpected backend error: \(message)")
        }
        XCTAssertEqual(backend.executeCalls, 1)

        let runnerResult = await discovery.executeTool(.init(
            providerIdentifier: "local",
            name: "run",
            args: .object([:]),
            toolCallId: "call-runner"
        ))
        if case .error(let message) = runnerResult.result {
            XCTFail("unexpected runner error: \(message)")
        }
        let executionCount = await runner.executionCount()
        XCTAssertEqual(executionCount, 1)
    }

    func testStdioNeverFallsBackToLocalProcessWhenRunnerMissing() async throws {
        let (settings, root) = try makeSettings()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = SandMcpDefinitionSource(includeBuiltins: false)
        await source.adoptAccountConfig(.init(mcpServers: [
            "local": .stdio(command: "dangerous-command"),
        ]))
        let backend = BackendDiscoveryRecorder()
        let discovery = SandMcpToolsDiscovery(deps: .init(
            definitionSource: source,
            settingsStore: settings,
            backendListTools: { _ in
                backend.listCalled()
                return []
            },
            backendExecuteTool: { _, _, _, _, _ in
                backend.executeCalled()
                return Self.success("wrong")
            }
        ))

        let tools = try await discovery.getTools()
        XCTAssertTrue(tools.isEmpty)

        let result = await discovery.executeTool(.init(
            providerIdentifier: "local",
            name: "run",
            args: .object([:]),
            toolCallId: "call"
        ))
        guard case .error(let message) = result.result else {
            return XCTFail("missing Runner must fail closed")
        }
        XCTAssertTrue(message.contains("Remote Runner"))
        XCTAssertEqual(backend.executeCalls, 0)
    }

    func testDisabledToolsAreFilteredAndCustomInstructionsArePrepended() async throws {
        let (settings, root) = try makeSettings()
        defer { try? FileManager.default.removeItem(at: root) }
        settings.setMcpDisabledToolsByServerId(["9": ["delete"]])
        settings.setMcpCustomInstructionByServerId(
            serverId: "9",
            displayName: "GitHub",
            value: "Only inspect public repositories.",
            mirrorLegacyName: true
        )

        let source = SandMcpDefinitionSource(includeBuiltins: false)
        await source.adoptAccountConfig(.init(mcpServers: [
            "github": .http(url: "https://mcp.example.test"),
        ]))
        let discovery = SandMcpToolsDiscovery(deps: .init(
            definitionSource: source,
            settingsStore: settings,
            backendListTools: { _ in
                [
                    .init(
                        serverIdentifier: "github",
                        status: "connected",
                        tools: [
                            .init(
                                name: "search",
                                providerIdentifier: "github",
                                toolName: "search",
                                clientKey: "github",
                                description: nil,
                                inputSchema: nil
                            ),
                            .init(
                                name: "delete",
                                providerIdentifier: "github",
                                toolName: "delete",
                                clientKey: "github",
                                description: nil,
                                inputSchema: nil
                            ),
                        ],
                        accountLabel: "default",
                        rowServerIdentifier: "github"
                    ),
                ]
            },
            backendExecuteTool: { _, _, _, _, _ in Self.success("tool-result") }
        ))
        await discovery.setAccountDisplay(.init(servers: [
            .init(
                id: "9",
                name: "GitHub",
                serverIdentifier: "github",
                config: .http(url: "https://mcp.example.test"),
                isTeamServer: false
            ),
        ]))

        let tools = try await discovery.getTools()
        XCTAssertEqual(tools.map(\.toolName), ["search"])

        let disabled = await discovery.executeTool(.init(
            providerIdentifier: "github",
            name: "delete",
            args: .object([:]),
            toolCallId: "delete"
        ))
        if case .error(let message) = disabled.result {
            XCTAssertTrue(message.contains("disabled"))
        } else {
            XCTFail("disabled tool must fail closed")
        }

        let enabled = await discovery.executeTool(.init(
            providerIdentifier: "github",
            name: "search",
            args: .object([:]),
            toolCallId: "search"
        ))
        guard case .success(let success) = enabled.result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(success.content.count, 2)
        if case .text(let note) = success.content[0].content {
            XCTAssertTrue(note.text.contains("Only inspect public repositories."))
        } else {
            XCTFail("custom instruction note must be first")
        }
    }

    func testDiscoveryCacheAndRunnerConfigPushAreDeduplicated() async throws {
        let (settings, root) = try makeSettings()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = SandMcpDefinitionSource(includeBuiltins: false)
        await source.adoptAccountConfig(.init(mcpServers: [
            "remote": .http(url: "https://mcp.example.test"),
            "stdio": .stdio(command: "tool", args: ["--serve"]),
        ]))
        let runner = FakeRunnerMcpPort()
        await runner.setServers([])
        let backend = BackendDiscoveryRecorder()
        let discovery = SandMcpToolsDiscovery(deps: .init(
            definitionSource: source,
            settingsStore: settings,
            backendListTools: { _ in
                backend.listCalled()
                return []
            },
            backendExecuteTool: { _, _, _, _, _ in Self.success("ok") },
            runnerMcpExec: runner,
            nowMs: { 100 }
        ))

        _ = try await discovery.getTools()
        _ = try await discovery.getTools()
        XCTAssertEqual(backend.listCalls, 1)
        let firstPushCount = await runner.loadedCount()
        XCTAssertEqual(firstPushCount, 1)

        await discovery.resetPushState()
        await discovery.invalidateToolsCache()
        _ = try await discovery.getTools()
        let secondPushCount = await runner.loadedCount()
        XCTAssertEqual(secondPushCount, 2)
    }

    func testBackendResultConversionPreservesTextAndErrors() {
        let success = sandMcpResultFromBackend(.init(
            caseName: "success",
            value: .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string("hello"),
                    ]),
                ]),
                "isError": .bool(false),
            ])
        ))
        guard case .success(let payload) = success.result,
              case .text(let text) = payload.content.first?.content else {
            return XCTFail("expected converted text success")
        }
        XCTAssertEqual(text.text, "hello")

        let failure = sandMcpResultFromBackend(.init(
            caseName: "error",
            value: .object(["error": .string("failed")])
        ))
        XCTAssertEqual(failure, generatedMcpResultFactory.error("failed"))
    }
}
