import Foundation

let SAND_TEACH_MAX_DURATION_MS = 10 * 60 * 1_000

struct TeachRecordingStatus: Equatable, Sendable {
    enum State: String, Equatable, Sendable {
        case idle
        case recording
    }

    let state: State
    let agentId: String?
    let startedAtMs: Int?
    let maxDurationMs: Int
}

let IDLE_TEACH_RECORDING_STATUS = TeachRecordingStatus(
    state: .idle,
    agentId: nil,
    startedAtMs: nil,
    maxDurationMs: SAND_TEACH_MAX_DURATION_MS
)
