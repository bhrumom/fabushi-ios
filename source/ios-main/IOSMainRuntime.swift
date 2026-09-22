import Foundation
import SwiftUI

/// iOS platform-main counterpart of Grok's Electron main process.
///
/// Owns lifecycle forwarding and the coordinator. It does not expose Host.
@MainActor
final class IOSMainRuntime {
    let coordinator: MahayanaCoordinator

    init(appDataDirectory: URL, featureHostTest: Bool = false) throws {
        coordinator = try MahayanaCoordinator.make(
            appDataDirectory: appDataDirectory,
            featureHostTest: featureHostTest
        )
    }

    /// Compatibility entry for platform-only callers. Renderer-facing code uses
    /// IOSPreloadBridge and never receives a Coordinator or Host reference.
    func dispatch(method: String, params: [String: Any] = [:]) async throws -> MahayanaCoordinator.JSONResult {
        try await coordinator.request(method: method, params: params)
    }

    func makeRendererPortServer(port: CoordinatorPort) -> RendererPortServer {
        RendererPortServer(port: port) { [weak self] method, args in
            guard let self else {
                return .failed(.init(code: "coordinator-unavailable", message: "iOS main runtime was released"))
            }
            return await self.coordinator.dispatchTransport(method: method, args: args)
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            coordinator.sceneBecameActive()
        case .background:
            coordinator.sceneEnteredBackground()
        case .inactive:
            coordinator.sceneWillSuspend()
        @unknown default:
            coordinator.sceneWillSuspend()
        }
    }

    func shutdown() {
        coordinator.beginShutdown()
    }
}
