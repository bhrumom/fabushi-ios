import Foundation
import SwiftUI

/// iOS platform-main counterpart of Grok's Electron main process.
///
/// Owns lifecycle forwarding and the coordinator. It does not expose Host.
@MainActor
final class IOSMainRuntime {
    let coordinator: MahayanaCoordinator
    let lifecycleReporter = IOSLifecycleReporter()
    private let lifecycleRecovery: IOSLifecycleRecoveryStore
    private let passkeyProvider: IOSAuthenticationServicesPasskeyProvider
    let devCapability: IOSDevCapability
    private let devControlAdapter: IOSNativeDevControlAdapter

    init(
        appDataDirectory: URL,
        featureHostTest: Bool = false,
        devCapability: IOSDevCapability = .live(),
        devControlsGate: IOSDevControlsGate = .live()
    ) throws {
        self.devCapability = devCapability
        devControlAdapter = IOSNativeDevControlAdapter(gate: devControlsGate)
        lifecycleRecovery = try IOSLifecycleRecoveryStore(appDataDirectory: appDataDirectory)
        let passkeyProvider = IOSAuthenticationServicesPasskeyProvider()
        self.passkeyProvider = passkeyProvider
        coordinator = try MahayanaCoordinator.make(
            appDataDirectory: appDataDirectory,
            featureHostTest: featureHostTest,
            passkeyProvider: passkeyProvider,
            devControlAdapter: devControlAdapter
        )
        lifecycleReporter.report(
            .startup,
            metadata: [
                "cold_start_resync": lifecycleRecovery.requiresColdStartResync ? "true" : "false",
                "session_id": lifecycleRecovery.currentCheckpoint.sessionID,
            ]
        )
    }

    var devControlsEnabled: Bool {
        devControlAdapter.isEnabled
    }

    func coordinatorDidLaunchForDevControls() {
        devControlAdapter.coordinatorDidLaunch()
    }

    var requiresColdStartResync: Bool {
        lifecycleRecovery.requiresColdStartResync
    }

    func markResyncCompleted() {
        lifecycleRecovery.markResyncCompleted()
    }

    func protectedDataWillBecomeUnavailable() {
        lifecycleRecovery.markResyncRequired()
        lifecycleReporter.report(
            .rendererLifecycle,
            level: .warn,
            metadata: ["phase": "protected-data-unavailable"]
        )
        coordinator.sceneWillSuspend()
    }

    func protectedDataDidBecomeAvailable() {
        lifecycleReporter.report(
            .rendererLifecycle,
            metadata: ["phase": "protected-data-available"]
        )
    }

    func memoryPressureReceived() {
        lifecycleReporter.report(
            .processRecovery,
            level: .warn,
            metadata: ["reason": "memory-pressure"]
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
            lifecycleRecovery.transition(to: .active)
            lifecycleReporter.report(.rendererLifecycle, metadata: ["phase": "active"])
            coordinator.sceneBecameActive()
        case .background:
            lifecycleRecovery.transition(to: .background)
            lifecycleReporter.report(.rendererLifecycle, metadata: ["phase": "background"])
            coordinator.sceneEnteredBackground()
        case .inactive:
            lifecycleRecovery.transition(to: .inactive)
            lifecycleReporter.report(.rendererLifecycle, metadata: ["phase": "inactive"])
            coordinator.sceneWillSuspend()
        @unknown default:
            lifecycleRecovery.transition(to: .inactive)
            lifecycleReporter.report(
                .rendererLifecycle,
                level: .warn,
                metadata: ["phase": "unknown"]
            )
            coordinator.sceneWillSuspend()
        }
    }

    func shutdown() {
        lifecycleRecovery.transition(to: .shuttingDown)
        lifecycleReporter.report(
            .rendererLifecycle,
            metadata: ["phase": "shutting-down"]
        )
        coordinator.beginShutdown()
    }
}
