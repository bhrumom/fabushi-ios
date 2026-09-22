import Foundation

enum CoordinatorProtocol {
    static let version = 1
}

struct CoordinatorFailure: Codable, Equatable, Sendable {
    let code: String
    let message: String
    let transportKind: String?
}

enum CoordinatorReplyOutcome: Equatable, Sendable {
    case ok
    case failed(CoordinatorFailure)
}

enum CoordinatorLifecyclePhase: String, Codable, Sendable {
    case hello
    case ready
    case shutdown
}

struct CoordinatorRequestEnvelope: Equatable, Sendable {
    let requestId: String
    let method: String

    init(requestId: String = UUID().uuidString.lowercased(), method: String) {
        precondition(!requestId.isEmpty)
        precondition(!method.isEmpty)
        self.requestId = requestId
        self.method = method
    }
}

struct CoordinatorEventEnvelope: Equatable, Sendable {
    let family: String
    let sequence: UInt64

    init(family: String, sequence: UInt64) {
        precondition(!family.isEmpty)
        self.family = family
        self.sequence = sequence
    }
}

/// Shared request/reply/cancel/event contract. Payload serialization is kept at
/// the transport edge; feature-facing Swift APIs must use typed values.
protocol CoordinatorPort: AnyObject {
    func cancel(requestId: String) async
    func lifecycle(_ phase: CoordinatorLifecyclePhase) async
}
