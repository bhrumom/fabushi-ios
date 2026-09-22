import Foundation

/// iOS-owned counterpart of Grok's node-agent-coordinator boundary.
///
/// The coordinator is the only production owner allowed to invoke the native
/// Mahayana Host. Renderer and platform code communicate through IOSMainRuntime.
@MainActor
final class MahayanaCoordinator {
    struct JSONResult: @unchecked Sendable {
        let value: Any
    }

    enum CoordinatorError: LocalizedError {
        case invalidResponse
        case unavailable
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Mahayana Coordinator returned an invalid response"
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

    /// Compatibility dispatch while existing feature models are moved to
    /// generated typed facade methods. It deliberately lives at the coordinator
    /// boundary: no renderer/model receives a Host reference.
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
