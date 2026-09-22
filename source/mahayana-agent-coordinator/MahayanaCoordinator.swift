import Foundation

/// iOS-owned counterpart of Grok's node-agent-coordinator boundary.
///
/// The coordinator is the only production owner allowed to invoke the native
/// Mahayana Host. Renderer and platform code communicate through typed
/// Coordinator frames carried by IOSMainRuntime/IOSPreloadBridge.
@MainActor
final class MahayanaCoordinator {
    struct JSONResult: @unchecked Sendable {
        let value: Any
    }

    enum CoordinatorError: LocalizedError {
        case invalidResponse
        case invalidParams
        case unavailable
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Mahayana Coordinator returned an invalid response"
            case .invalidParams: "Mahayana Coordinator request params must be a JSON object"
            case .unavailable: "Mahayana Coordinator is unavailable"
            case .requestFailed(let message): message
            }
        }
    }

    enum LifecycleState: Equatable, Sendable {
        case starting
        case ready
        case background
        case suspended
        case shuttingDown
        case failed(String)
    }

    private let host: MahayanaHostRuntime
    private(set) var lifecycleState: LifecycleState = .starting
    private var inFlight = Set<String>()

    init(host: MahayanaHostRuntime) {
        self.host = host
        lifecycleState = .ready
    }

    static func make(appDataDirectory: URL, featureHostTest: Bool = false) throws -> MahayanaCoordinator {
        MahayanaCoordinator(
            host: try MahayanaHostRuntime(
                appDataDirectory: appDataDirectory,
                featureHostTest: featureHostTest
            )
        )
    }

    /// Compatibility entry used while feature-specific typed facades are
    /// replacing dictionary-shaped calls. Host ownership remains here.
    func request(method: String, params: [String: Any] = [:]) async throws -> JSONResult {
        guard lifecycleState != .shuttingDown else { throw CoordinatorError.unavailable }
        let requestId = UUID().uuidString.lowercased()
        inFlight.insert(requestId)
        defer { inFlight.remove(requestId) }
        do {
            let result = try await host.request(method: method, params: params)
            return JSONResult(value: result.value)
        } catch {
            throw CoordinatorError.requestFailed(error.localizedDescription)
        }
    }

    /// Typed transport entry used by RendererPortServer.
    func dispatchTransport(method: String, args: CoordinatorPayload) async -> CoordinatorReplyOutcome {
        guard lifecycleState != .shuttingDown else {
            return .failed(.init(code: "coordinator-unavailable", message: CoordinatorError.unavailable.localizedDescription))
        }
        guard case .object = args, let params = args.foundationValue as? [String: Any] else {
            return .failed(.init(code: "invalid-params", message: CoordinatorError.invalidParams.localizedDescription))
        }

        do {
            let result = try await request(method: method, params: params)
            return .ok(try CoordinatorPayload.fromFoundation(result.value))
        } catch {
            return .failed(.init(code: "request-failed", message: error.localizedDescription))
        }
    }

    func sceneBecameActive() {
        lifecycleState = .ready
    }

    func sceneEnteredBackground() {
        lifecycleState = .background
    }

    func sceneWillSuspend() {
        lifecycleState = .suspended
    }

    func beginShutdown() {
        lifecycleState = .shuttingDown
        inFlight.removeAll()
    }
}
