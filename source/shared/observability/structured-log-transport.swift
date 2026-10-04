import Foundation

let MAX_BUFFER_SIZE = 1_000
let STRUCTURED_LOG_SUBMIT_DEADLINE_MS = 15_000
let STRUCTURED_LOG_REPLAY_MAX_AGE_MS = 17 * 60 * 60 * 1_000
let DEADLINE_EXPIRY_CODE = "deadline_exceeded"

enum StructuredLogLevel: String, Sendable {
    case debug
    case info
    case warn
    case error
}

enum ClientLogLevel: Int, Sendable {
    case unspecified = 0
    case info = 1
    case debug = 2
    case warn = 3
    case error = 4
}

struct StructuredLogEntry: Equatable, Sendable {
    let level: ClientLogLevel
    let message: String
    let metadata: [String: String]
    let timestamp: Int64
    let key: String
}

struct BufferedStructuredLog: Equatable, Sendable {
    let level: StructuredLogLevel
    let message: String
    let metadata: [String: String]
    let timestampMs: Int64
}

struct StructuredLogReceipt: Equatable, Sendable {
    let logsProcessed: Int
    let logsDropped: Int
}

struct StructuredLogDropCounter: Equatable, Sendable {
    var observed: Int
    var acknowledgedThrough: Int
}

typealias StructuredLogDropCounters = [String: StructuredLogDropCounter]

struct StructuredLogCheckpoint: Equatable, Sendable {
    let counterID: String
    let counters: StructuredLogDropCounters
    let records: [BufferedStructuredLog]
}

struct StructuredLogDeadlineError: Error, Equatable, Sendable {
    let code = DEADLINE_EXPIRY_CODE
}

func isDeadlineExpiry(_ error: Error) -> Bool {
    if let error = error as? StructuredLogDeadlineError {
        return error.code == DEADLINE_EXPIRY_CODE
    }
    let nsError = error as NSError
    return nsError.userInfo["code"] as? String == DEADLINE_EXPIRY_CODE
}

func createDropCounterID() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
}

func emptyDropCounters() -> StructuredLogDropCounters {
    Dictionary(uniqueKeysWithValues: TELEMETRY_DROP_REASONS.map {
        ($0, StructuredLogDropCounter(observed: 0, acknowledgedThrough: 0))
    })
}

func cloneDropCounters(_ counters: StructuredLogDropCounters) -> StructuredLogDropCounters {
    counters
}

func isValidLogShipReceipt(_ response: StructuredLogReceipt, requestSize: Int) -> Bool {
    guard response.logsProcessed >= 0, response.logsDropped >= 0 else { return false }
    return response.logsProcessed + response.logsDropped == requestSize
}

func cleanStructuredLogMetadata(_ metadata: [String: String?]) -> [String: String] {
    metadata.reduce(into: [:]) { result, pair in
        if let value = pair.value, !value.isEmpty {
            result[pair.key] = value
        }
    }
}

func truncateStructuredLogValue(_ value: String, max: Int) -> String {
    guard max > 0, value.count > max else { return max <= 0 ? "" : value }
    return String(value.prefix(max))
}

func toClientLogLevel(_ level: StructuredLogLevel) -> ClientLogLevel {
    switch level {
    case .debug: return .debug
    case .info: return .info
    case .warn: return .warn
    case .error: return .error
    }
}

typealias StructuredLogSubmitter = @Sendable ([StructuredLogEntry]) async throws -> StructuredLogReceipt

actor StructuredLogTransport {
    private let key: String
    private let platformTags: [String: String]
    private let submit: StructuredLogSubmitter
    private var identityTags: [String: String] = [:]
    private var buffer: [BufferedStructuredLog]
    private var counters: StructuredLogDropCounters
    private var counterID: String
    private var holdForIdentity: Bool
    private var disposed = false

    init(
        key: String,
        platformTags: [String: String?],
        initialCheckpoint: StructuredLogCheckpoint? = nil,
        holdForIdentity: Bool = false,
        submit: @escaping StructuredLogSubmitter
    ) {
        self.key = key
        self.platformTags = cleanStructuredLogMetadata(platformTags)
        self.submit = submit
        self.buffer = Array((initialCheckpoint?.records ?? []).suffix(MAX_BUFFER_SIZE))
        self.counters = initialCheckpoint?.counters ?? emptyDropCounters()
        self.counterID = initialCheckpoint?.counterID ?? createDropCounterID()
        self.holdForIdentity = holdForIdentity
    }

    func setIdentityTags(_ tags: [String: String?]) {
        identityTags = cleanStructuredLogMetadata(tags)
        holdForIdentity = false
    }

    func enqueue(
        _ level: StructuredLogLevel,
        message: String,
        metadata: [String: String?] = [:],
        timestampMs: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) {
        guard !disposed else { return }

        var merged = platformTags
        for (key, value) in cleanStructuredLogMetadata(metadata) {
            merged[key] = value
        }

        buffer.append(.init(
            level: level,
            message: message,
            metadata: merged,
            timestampMs: timestampMs
        ))

        if buffer.count > MAX_BUFFER_SIZE {
            let overflow = buffer.count - MAX_BUFFER_SIZE
            buffer.removeFirst(overflow)
            recordDropped(reason: "overflow_evicted", count: overflow)
        }
    }

    func capturePending() -> [BufferedStructuredLog] {
        buffer
    }

    func captureCheckpoint() -> StructuredLogCheckpoint {
        .init(counterID: counterID, counters: counters, records: buffer)
    }

    func recordDropped(reason: String, count: Int) {
        guard count > 0 else { return }
        var counter = counters[reason] ?? .init(observed: 0, acknowledgedThrough: 0)
        counter.observed += count
        counters[reason] = counter
    }

    func clearPending() {
        if !buffer.isEmpty {
            recordDropped(reason: "account_rotated", count: buffer.count)
        }
        buffer.removeAll()
        counterID = createDropCounterID()
        counters = emptyDropCounters()
    }

    func flushNow(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)) async -> Bool {
        guard !disposed else { return buffer.isEmpty }
        guard !holdForIdentity else { return false }

        let expiredCutoff = nowMs - Int64(STRUCTURED_LOG_REPLAY_MAX_AGE_MS)
        let expiredCount = buffer.lazy.filter { $0.timestampMs < expiredCutoff }.count
        if expiredCount > 0 {
            buffer.removeAll { $0.timestampMs < expiredCutoff }
            recordDropped(reason: "replay_expired", count: expiredCount)
        }

        guard !buffer.isEmpty else { return true }

        let split = takeLogShipBatch(buffer) {
            LogShipBufferedEntry(message: $0.message, metadata: $0.metadata)
        }
        let batch = split.batch
        buffer = split.remaining

        let entries = batch.map { record in
            StructuredLogEntry(
                level: toClientLogLevel(record.level),
                message: record.message,
                metadata: record.metadata.merging(identityTags) { _, identity in identity },
                timestamp: record.timestampMs,
                key: key
            )
        }

        do {
            let receipt = try await submit(entries)
            guard isValidLogShipReceipt(receipt, requestSize: entries.count) else {
                buffer.insert(contentsOf: batch, at: 0)
                recordDropped(reason: "ship_failed", count: 1)
                return false
            }
            if receipt.logsDropped > 0 {
                recordDropped(reason: "backend_dropped", count: receipt.logsDropped)
            }
            return true
        } catch {
            buffer.insert(contentsOf: batch, at: 0)
            recordDropped(reason: isDeadlineExpiry(error) ? "ship_failed" : "ship_failed", count: 1)
            return false
        }
    }

    func dispose(retainUndelivered: Bool = true) {
        disposed = true
        if !retainUndelivered {
            buffer.removeAll()
        }
    }
}
