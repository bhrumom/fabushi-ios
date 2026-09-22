import Foundation

@MainActor
final class IOSCoordinatorRuntime {
    enum State: Equatable, Sendable {
        case stopped
        case running(generation: UInt64)
        case restarting(generation: UInt64)
        case disposed
    }

    private let main: IOSMainRuntime
    private var handle: IOSCoordinatorLaunchHandle?
    private var highestAcceptedGeneration: UInt64 = 0

    private(set) var state: State = .stopped

    init(main: IOSMainRuntime) {
        self.main = main
    }

    @discardableResult
    func start() -> IOSCoordinatorLaunchHandle {
        if let handle { return handle }
        highestAcceptedGeneration &+= 1
        let launched = IOSCoordinatorLauncher.launch(main: main)
        handle = launched
        state = .running(generation: highestAcceptedGeneration)
        return launched
    }

    func accepts(generation: UInt64) -> Bool {
        guard generation >= highestAcceptedGeneration else { return false }
        highestAcceptedGeneration = generation
        return true
    }

    func restart() {
        guard state != .disposed else { return }
        highestAcceptedGeneration &+= 1
        state = .restarting(generation: highestAcceptedGeneration)
        handle?.dispose()
        handle = IOSCoordinatorLauncher.launch(main: main)
        state = .running(generation: highestAcceptedGeneration)
    }

    func dispose() {
        guard state != .disposed else { return }
        handle?.dispose()
        handle = nil
        state = .disposed
    }
}
