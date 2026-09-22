import XCTest
@testable import Fabushi

final class CoordinatorAdapterTests: XCTestCase {
    func testClientSideToolRelayRejectsStaleSequence() async throws {
        let relay = ClientSideToolV2Relay()
        let message = ClientSideToolV2WireMessage(
            messageType: "aiserver.v1.ClientSideToolV2Call",
            bytes: Data([0x01, 0x02, 0x03])
        )
        let event = ClientSideToolV2TransportEvent.update(
            kind: .call,
            accountSlot: ClientSideToolV2Transport.accountSlot,
            agentId: "agent-1",
            epoch: "epoch-1",
            sequence: 1,
            message: message
        )

        try await relay.accept(event)
        do {
            try await relay.accept(event)
            XCTFail("stale sequence should be rejected")
        } catch let error as ClientSideToolV2Relay.RelayError {
            XCTAssertEqual(error.localizedDescription, ClientSideToolV2Relay.RelayError.staleSequence.localizedDescription)
        }
    }

    func testOAuthCallbackUsesAppURLAndConsumesStateOnce() async throws {
        let registry = MCPOAuthCallbackRegistry()
        let listener = MCPOAuthCallbackListener(registry: registry)
        await registry.register(state: "state-1", providerIdentifier: "provider-a")

        let url = try XCTUnwrap(URL(string: "fabushi://auth/callback?state=state-1&code=abc"))
        let accepted = try await listener.accept(url)
        XCTAssertEqual(accepted.providerIdentifier, "provider-a")

        do {
            _ = try await listener.accept(url)
            XCTFail("OAuth state must be single-use")
        } catch let error as MCPOAuthCallbackListener.CallbackError {
            XCTAssertEqual(error, .stateMismatch)
        }
    }

    @MainActor
    func testHostSupervisorReusesHealthyConnectionWithinTTL() async throws {
        var now = Date(timeIntervalSince1970: 100)
        var resolveCount = 0
        var probeCount = 0
        let expected = CoordinatorGatewayClient.Connection(
            baseURL: try XCTUnwrap(URL(string: "https://gateway.example")),
            headers: ["authorization": "Bearer test"]
        )
        let supervisor = CoordinatorHostSupervisor(
            now: { now },
            resolveConnection: {
                resolveCount += 1
                return expected
            },
            healthProbe: { _ in
                probeCount += 1
                return true
            }
        )

        let first = try await supervisor.ensureConnection()
        XCTAssertEqual(first, expected)
        XCTAssertEqual(resolveCount, 1)
        XCTAssertEqual(probeCount, 0)

        let second = try await supervisor.ensureConnection()
        XCTAssertEqual(second, expected)
        XCTAssertEqual(resolveCount, 1)
        XCTAssertEqual(probeCount, 1)

        now = now.addingTimeInterval(1)
        let third = try await supervisor.ensureConnection()
        XCTAssertEqual(third, expected)
        XCTAssertEqual(resolveCount, 1)
        XCTAssertEqual(probeCount, 1)
    }

    func testGatewayDNSDiagnosticsClassifyLoopbackWithoutResolvingIt() throws {
        let report = GatewayDNSDiagnostics.inspect(try XCTUnwrap(URL(string: "http://127.0.0.1:9999/health")))
        XCTAssertEqual(report.kind, .loopback)
        XCTAssertFalse(report.isSecureTransport)
    }

    func testIOSDevControlsDoNotPretendElectronExists() {
        XCTAssertEqual(
            IOSDevControlsContract.disposition(for: "restartElectron"),
            .unavailable(reason: "Electron process/window controls do not exist on iOS")
        )
        XCTAssertEqual(IOSDevControlsContract.disposition(for: "boxHealth"), .remoteRunner)
        XCTAssertEqual(IOSDevControlsContract.disposition(for: "setThemePreference"), .local)
    }

    func testLocalExecSupervisorRoutesDesktopProcessSemanticsRemote() async {
        let supervisor = IOSLocalExecSupervisor()
        let processRoute = await supervisor.route(capabilityName: "process.spawn")
        let localRoute = await supervisor.route(capabilityName: "openExternalURL")
        XCTAssertEqual(processRoute, .remote)
        XCTAssertEqual(localRoute, .local(.openExternalURL))
    }
}
