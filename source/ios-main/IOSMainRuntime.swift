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

    func dispatch(method: String, params: [String: Any] = [:]) async throws -> MahayanaCoordinator.JSONResult {
        try await coordinator.request(method: method, params: params)
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
