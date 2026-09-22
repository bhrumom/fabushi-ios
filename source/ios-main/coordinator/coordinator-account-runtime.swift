import Foundation

@MainActor
final class CoordinatorAccountRuntime {
    enum Authorization: Equatable, Sendable {
        case ready(slot: String?)
        case refused(slot: String?, reason: String)
    }

    typealias Authorize = @MainActor (_ slot: String?, _ previousSlot: String?) async -> Authorization

    private let authorize: Authorize
    private let cleanup: ProductionAccountTransitionCleanup
    private(set) var activeSlot: String?

    init(
        activeSlot: String? = nil,
        cleanup: ProductionAccountTransitionCleanup,
        authorize: @escaping Authorize
    ) {
        self.activeSlot = activeSlot
        self.cleanup = cleanup
        self.authorize = authorize
    }

    func transition(to nextSlot: String?) async -> Authorization {
        let previous = activeSlot
        if previous != nextSlot {
            await cleanup.prepare(previousSlot: previous, nextSlot: nextSlot)
        }
        let result = await authorize(nextSlot, previous)
        if case .ready(let slot) = result {
            activeSlot = slot
        }
        return result
    }

    func reset() {
        activeSlot = nil
    }
}
