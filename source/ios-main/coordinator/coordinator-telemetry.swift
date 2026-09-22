import Foundation

enum CoordinatorExitClass: String, Equatable, Sendable {
    case clean
    case breach
    case bootstrap
    case suspended
    case other
}

struct CoordinatorLifecycleTelemetry: Equatable, Sendable {
    let outcome: String
    let exitClass: CoordinatorExitClass?
    let uptimeMilliseconds: Int?
    let relaunchSequence: Int
    let delayMilliseconds: Int?
}

enum CoordinatorTelemetry {
    static let recentFailureWindowMilliseconds = 30_000
    static let healthyUptimeMilliseconds = 30_000

    static func classify(exitCode: Int?) -> CoordinatorExitClass {
        switch exitCode {
        case 0: .clean
        case 1: .breach
        case 2: .bootstrap
        case nil: .suspended
        default: .other
        }
    }

    static func relaunchDelayMilliseconds(attempt: Int) -> Int {
        let exponent = max(0, min(attempt, 8))
        return min(10_000, 250 * (1 << exponent))
    }
}
