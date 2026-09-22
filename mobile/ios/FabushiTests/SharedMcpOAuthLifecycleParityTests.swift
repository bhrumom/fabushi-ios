import XCTest
@testable import Fabushi

private final class McpOAuthTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64

    init(_ value: Int64) { self.value = value }

    func now() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(_ delta: Int64) {
        lock.lock()
        value += delta
        lock.unlock()
    }
}

private actor McpOAuthCompletionRecorder {
    private(set) var calls: [(String, String)] = []
    private var transientFailuresRemaining: Int

    init(transientFailures: Int = 0) {
        transientFailuresRemaining = transientFailures
    }

    func complete(state: String, code: String) throws {
        calls.append((state, code))
        if transientFailuresRemaining > 0 {
            transientFailuresRemaining -= 1
            throw URLError(.networkConnectionLost)
        }
    }

    func snapshot() -> [(String, String)] { calls }
}

final class SharedMcpOAuthLifecycleParityTests: XCTestCase {
    func testAuthorizationRequiresRegisteredIOSCallbackAndState() throws {
        let redirect = MCP_OAUTH_IOS_CALLBACK_URL.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
        let valid = "https://provider.example/authorize?redirect_uri=\(redirect)&state=state-1"
        XCTAssertEqual(
            parseMcpOAuthLoopbackAuthorization(valid),
            .init(state: "state-1")
        )

        let desktopRedirect = "http://localhost:8787/callback".addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        )!
        XCTAssertNil(parseMcpOAuthLoopbackAuthorization(
            "https://provider.example/authorize?redirect_uri=\(desktopRedirect)&state=state-1"
        ))
        XCTAssertNil(parseMcpOAuthLoopbackAuthorization(
            "https://provider.example/authorize?redirect_uri=\(redirect)"
        ))
    }

    func testCallbackCompletesOnceAndConsumesState() async throws {
        let recorder = McpOAuthCompletionRecorder()
        let lifecycle = SandMcpOAuthCallbackLifecycle(
            completeOAuth: { state, code in
                try await recorder.complete(state: state, code: code)
            }
        )
        let auth = try XCTUnwrap(URLComponents(string: "https://provider.example/authorize"))
        var components = auth
        components.queryItems = [
            .init(name: "redirect_uri", value: MCP_OAUTH_IOS_CALLBACK_URL),
            .init(name: "state", value: "state-once"),
        ]
        XCTAssertTrue(await lifecycle.registerPendingAuthFromUrl(
            authorizationUrl: try XCTUnwrap(components.url?.absoluteString),
            serverName: "GitHub"
        ))

        let callback = try XCTUnwrap(URL(string: "fabushi://auth/callback?state=state-once&code=abc"))
        XCTAssertEqual(await lifecycle.handleCallback(callback), .success)
        XCTAssertEqual(await recorder.snapshot().map { [$0.0, $0.1] }, [["state-once", "abc"]])
        XCTAssertEqual(await lifecycle.handleCallback(callback), .notFound)
    }

    func testProviderErrorAndMissingCodeConsumePendingState() async throws {
        let lifecycle = SandMcpOAuthCallbackLifecycle(
            completeOAuth: { _, _ in XCTFail("completion must not run") }
        )

        func authorization(_ state: String) throws -> String {
            var components = try XCTUnwrap(URLComponents(string: "https://provider.example/authorize"))
            components.queryItems = [
                .init(name: "redirect_uri", value: MCP_OAUTH_IOS_CALLBACK_URL),
                .init(name: "state", value: state),
            ]
            return try XCTUnwrap(components.url?.absoluteString)
        }

        XCTAssertTrue(await lifecycle.registerPendingAuthFromUrl(
            authorizationUrl: try authorization("provider-error")
        ))
        let providerError = try XCTUnwrap(URL(string:
            "fabushi://auth/callback?state=provider-error&error=access_denied"
        ))
        XCTAssertEqual(
            await lifecycle.handleCallback(providerError),
            .refused(.providerError)
        )
        XCTAssertFalse(await lifecycle.hasPendingState("provider-error"))

        XCTAssertTrue(await lifecycle.registerPendingAuthFromUrl(
            authorizationUrl: try authorization("missing-code")
        ))
        let missing = try XCTUnwrap(URL(string:
            "fabushi://auth/callback?state=missing-code"
        ))
        XCTAssertEqual(
            await lifecycle.handleCallback(missing),
            .refused(.missingCode)
        )
        XCTAssertFalse(await lifecycle.hasPendingState("missing-code"))
    }

    func testTransientCompletionRetriesOnceWithoutDuplicateSuccess() async throws {
        let recorder = McpOAuthCompletionRecorder(transientFailures: 1)
        let lifecycle = SandMcpOAuthCallbackLifecycle(
            completeOAuth: { state, code in
                try await recorder.complete(state: state, code: code)
            },
            sleepMs: { _ in }
        )

        var authorization = try XCTUnwrap(URLComponents(string: "https://provider.example/authorize"))
        authorization.queryItems = [
            .init(name: "redirect_uri", value: MCP_OAUTH_IOS_CALLBACK_URL),
            .init(name: "state", value: "retry-state"),
        ]
        XCTAssertTrue(await lifecycle.registerPendingAuthFromUrl(
            authorizationUrl: try XCTUnwrap(authorization.url?.absoluteString)
        ))
        let callback = try XCTUnwrap(URL(string:
            "fabushi://auth/callback?state=retry-state&code=retry-code"
        ))
        XCTAssertEqual(await lifecycle.handleCallback(callback), .success)
        XCTAssertEqual(await recorder.snapshot().count, 2)
        XCTAssertFalse(await lifecycle.hasPendingState("retry-state"))
    }

    func testSceneResumeStyleExpiryAndUnsupportedURLAreFailClosed() async throws {
        let clock = McpOAuthTestClock(10_000)
        let lifecycle = SandMcpOAuthCallbackLifecycle(
            completeOAuth: { _, _ in },
            nowMs: { clock.now() }
        )
        var authorization = try XCTUnwrap(URLComponents(string: "https://provider.example/authorize"))
        authorization.queryItems = [
            .init(name: "redirect_uri", value: MCP_OAUTH_IOS_CALLBACK_URL),
            .init(name: "state", value: "expiring-state"),
        ]
        XCTAssertTrue(await lifecycle.registerPendingAuthFromUrl(
            authorizationUrl: try XCTUnwrap(authorization.url?.absoluteString)
        ))
        clock.advance(Int64(MCP_OAUTH_PENDING_TTL_MS) + 1)
        await lifecycle.expirePending()
        XCTAssertFalse(await lifecycle.hasPendingState("expiring-state"))

        let browserLogin = try XCTUnwrap(URL(string:
            "fabushi://auth/complete?attemptId=browser-login-1&status=completed"
        ))
        XCTAssertEqual(await lifecycle.handleCallback(browserLogin), .unsupportedURL)
    }

    func testCoordinatorRegistryUsesSameTTLAndSingleUseCallbackIdentity() async throws {
        let registry = MCPOAuthCallbackRegistry()
        let listener = MCPOAuthCallbackListener(registry: registry)
        let created = Date(timeIntervalSince1970: 100)
        await registry.register(
            state: "coordinator-state",
            providerIdentifier: "server-7",
            now: created
        )
        let callback = try XCTUnwrap(URL(string:
            "fabushi://auth/callback?state=coordinator-state&code=abc"
        ))
        let accepted = try await listener.accept(callback)
        XCTAssertEqual(accepted.providerIdentifier, "server-7")

        do {
            _ = try await listener.accept(callback)
            XCTFail("callback state must be single-use")
        } catch let error as MCPOAuthCallbackListener.CallbackError {
            XCTAssertEqual(error, .stateMismatch)
        }

        await registry.register(
            state: "expired-state",
            providerIdentifier: "server-8",
            now: created
        )
        let expired = await registry.consume(
            state: "expired-state",
            now: created.addingTimeInterval(
                TimeInterval(MCP_OAUTH_PENDING_TTL_MS) / 1_000 + 1
            )
        )
        XCTAssertNil(expired)
    }
}
