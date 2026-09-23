import Foundation
import SwiftUI

/// iOS platform-main counterpart of Grok's Electron main process.
///
/// Owns lifecycle forwarding and the coordinator. It does not expose Host.
@MainActor
final class IOSMainRuntime {
    let coordinator: MahayanaCoordinator
    let lifecycleReporter: IOSLifecycleReporter
    private let lifecycleRecovery: IOSLifecycleRecoveryStore
    private let passkeyProvider: IOSAuthenticationServicesPasskeyProvider
    private let accountRuntime: CoordinatorAccountRuntime
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

        let reporter = IOSLifecycleReporter()
        lifecycleReporter = reporter

        let passkeyProvider = IOSAuthenticationServicesPasskeyProvider()
        self.passkeyProvider = passkeyProvider

        let coordinator = try MahayanaCoordinator.make(
            appDataDirectory: appDataDirectory,
            featureHostTest: featureHostTest,
            passkeyProvider: passkeyProvider,
            devControlAdapter: devControlAdapter
        )
        self.coordinator = coordinator

        let cleanup = ProductionAccountTransitionCleanup(
            dependencies: .init(
                clearAccountScope: {
                    coordinator.updateAccountSettingsScope(nil)
                },
                didClearAccountScope: { _, nextSlot in
                    reporter.report(
                        .coordinatorHandoff,
                        metadata: [
                            "account_scope": "cleared",
                            "next_scope": nextSlot == nil ? "logged-out" : "replacement",
                        ]
                    )
                }
            )
        )
        accountRuntime = CoordinatorAccountRuntime(
            cleanup: cleanup,
            authorize: { slot, _ in
                coordinator.updateAccountSettingsScope(slot)
                reporter.report(
                    .coordinatorHandoff,
                    metadata: [
                        "account_scope": slot == nil ? "logged-out" : "adopted",
                    ]
                )
                return .ready(slot: slot)
            }
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
        let args = try CoordinatorPayload.fromFoundation(params)
        let outcome = await dispatchTransport(method: method, args: args)
        switch outcome {
        case .ok(let payload):
            return .init(value: payload.foundationValue)
        case .failed(let failure):
            throw MahayanaCoordinator.CoordinatorError.requestFailed(failure.message)
        }
    }

    func makeRendererPortServer(port: CoordinatorPort) -> RendererPortServer {
        RendererPortServer(port: port) { [weak self] method, args in
            guard let self else {
                return .failed(.init(code: "coordinator-unavailable", message: "iOS main runtime was released"))
            }
            return await self.dispatchTransport(method: method, args: args)
        }
    }

    private func dispatchTransport(
        method: String,
        args: CoordinatorPayload
    ) async -> CoordinatorReplyOutcome {
        let outcome = await coordinator.dispatchTransport(method: method, args: args)
        if let accountAuthorization = await accountRuntime.observeAuthReply(method: method, outcome: outcome),
           case .refused(_, let reason) = accountAuthorization {
            lifecycleReporter.report(
                .coordinatorHandoff,
                level: .warn,
                metadata: [
                    "account_scope": "refused",
                    "reason": reason,
                ]
            )
        }
        return outcome
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
        accountRuntime.reset()
        coordinator.updateAccountSettingsScope(nil)
        coordinator.beginShutdown()
    }
}
