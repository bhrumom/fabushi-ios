import Foundation

@MainActor
final class ProductionAccountTransitionCleanup {
    struct Dependencies {
        let setAccountDeparting: @MainActor () -> Void
        let onAccountDeparted: @MainActor () -> Void
        let noteAccountDeparted: @MainActor () -> Void
        let clearRemoteHostSettings: @MainActor () async throws -> Void
        let clearAccountScope: @MainActor () -> Void
        let clearGatewayDescriptor: @MainActor () async -> Void
        let resetMCPManager: @MainActor () async -> Void
        let reportHostSettingsClearFailure: @MainActor (Error) -> Void
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func prepare(previousSlot: String?, nextSlot: String?) async {
        guard previousSlot != nil else { return }
        dependencies.setAccountDeparting()
        dependencies.onAccountDeparted()
        dependencies.noteAccountDeparted()
        do {
            try await dependencies.clearRemoteHostSettings()
        } catch {
            dependencies.reportHostSettingsClearFailure(error)
        }
        dependencies.clearAccountScope()
        await dependencies.clearGatewayDescriptor()
        await dependencies.resetMCPManager()
    }
}
