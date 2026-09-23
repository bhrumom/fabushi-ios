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

    @MainActor
    func testCoordinatorAccountRuntimeFollowsSettledRustAuthReplies() async {
        var clearCount = 0
        var transitions: [(String, String?)] = []
        var adopted: [String?] = []

        let cleanup = ProductionAccountTransitionCleanup(
            dependencies: .init(
                clearAccountScope: { clearCount += 1 },
                didClearAccountScope: { previous, next in
                    transitions.append((previous, next))
                }
            )
        )
        let runtime = CoordinatorAccountRuntime(
            cleanup: cleanup,
            authorize: { slot, _ in
                adopted.append(slot)
                return .ready(slot: slot)
            }
        )

        let first = await runtime.observeAuthReply(
            method: "feature.auth.status",
            outcome: .ok(.object([
                "loggedIn": .bool(true),
                "user": .object(["id": .string("account-1")]),
            ]))
        )
        XCTAssertEqual(first, .ready(slot: "id:account-1"))
        XCTAssertEqual(runtime.activeSlot, "id:account-1")
        XCTAssertEqual(clearCount, 0)

        _ = await runtime.observeAuthReply(
            method: "feature.auth.browserPoll",
            outcome: .ok(.object([
                "status": .string("completed"),
                "auth": .object([
                    "loggedIn": .bool(true),
                    "user": .object(["email": .string("Second@Example.COM")]),
                ]),
            ]))
        )
        XCTAssertEqual(runtime.activeSlot, "email:second@example.com")
        XCTAssertEqual(clearCount, 1)
        XCTAssertEqual(transitions.count, 1)
        XCTAssertEqual(transitions.first?.0, "id:account-1")
        XCTAssertEqual(transitions.first?.1, "email:second@example.com")

        _ = await runtime.observeAuthReply(
            method: "feature.auth.logout",
            outcome: .ok(.object(["loggedIn": .bool(false)]))
        )
        XCTAssertNil(runtime.activeSlot)
        XCTAssertEqual(clearCount, 2)
        XCTAssertEqual(adopted, ["id:account-1", "email:second@example.com", nil])
    }

    @MainActor
    func testCoordinatorAccountRuntimeFailsClosedOnLoggedInReplyWithoutStableIdentity() async {
        var clearCount = 0
        var adopted: [String?] = []
        let cleanup = ProductionAccountTransitionCleanup(
            dependencies: .init(
                clearAccountScope: { clearCount += 1 },
                didClearAccountScope: { _, _ in }
            )
        )
        let runtime = CoordinatorAccountRuntime(
            activeSlot: "id:prior",
            cleanup: cleanup,
            authorize: { slot, _ in
                adopted.append(slot)
                return .ready(slot: slot)
            }
        )

        let result = await runtime.observeAuthReply(
            method: "feature.auth.status",
            outcome: .ok(.object([
                "loggedIn": .bool(true),
                "user": .object(["nickname": .string("Display only")]),
            ]))
        )

        guard case .refused(let slot, let reason)? = result else {
            return XCTFail("missing stable account identity must be refused")
        }
        XCTAssertNil(slot)
        XCTAssertTrue(reason.contains("stable account slot"))
        XCTAssertNil(runtime.activeSlot)
        XCTAssertEqual(clearCount, 1)
        XCTAssertEqual(adopted.count, 1)
        XCTAssertNil(adopted[0])
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
