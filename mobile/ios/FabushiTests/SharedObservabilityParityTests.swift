import XCTest
@testable import Fabushi

private struct ObservabilityRateLimitError: ConnectErrorLike {
    let connectCode: Int
    let connectMetadata: [String: String]
}

final class SharedObservabilityParityTests: XCTestCase {
    func testHeapMetricsRejectInvalidCoreValuesAndKeepsValidCounts() {
        XCTAssertNil(parseHeapMetricsReport(["usedBytes": -1, "limitBytes": 100]))
        XCTAssertNil(parseHeapMetricsReport(["usedBytes": 1, "limitBytes": 0]))
        let parsed = parseHeapMetricsReport([
            "usedBytes": 10,
            "limitBytes": 100,
            "loadedAgents": 2,
            "loadedTranscriptEntries": 9,
            "idleMinutesLast15m": -1,
        ])
        XCTAssertEqual(parsed?.usedBytes, 10)
        XCTAssertEqual(parsed?.loadedAgents, 2)
        XCTAssertNil(parsed?.idleMinutesLast15m)
    }

    func testLogShipDelayBackoffRetryAfterAndBatchLimits() {
        XCTAssertEqual(nextLogShipDelayMs(outcome: "shipped", streak: 0, random: { 0 }), 15_000)
        XCTAssertEqual(nextLogShipDelayMs(outcome: "failed", streak: 1, random: { 0 }), 30_000)
        XCTAssertEqual(
            nextLogShipDelayMs(outcome: "rate_limited", streak: 1, retryAfterMs: 90_000, random: { 0 }),
            90_000
        )
        let buffer = (0..<130).map { LogShipBufferedEntry(message: "m\($0)", metadata: [:]) }
        let split = takeLogShipBatch(buffer)
        XCTAssertEqual(split.batch.count, 128)
        XCTAssertEqual(split.remaining.count, 2)
    }

    func testLogShipScheduleUsesConnectRetryAfter() {
        let schedule = LogShipSchedule()
        let error = ObservabilityRateLimitError(
            connectCode: CONNECT_CODE_RESOURCE_EXHAUSTED,
            connectMetadata: ["retry-after": "2"]
        )
        schedule.record(.failed(error), nowMs: 1_000, random: { 0 })
        XCTAssertTrue(schedule.isBackingOff())
        XCTAssertFalse(schedule.isDue(eager: true, nowMs: 2_999))
    }

    func testRequestLineageStripsHeaderNewlines() {
        let headers = buildSandRequestLineageHeaders(.init(
            parentRequestId: "p\r\n1",
            rootParentRequestId: "root\n2",
            parentAgentToolCallId: "tool\r3"
        ))
        XCTAssertEqual(headers["x-parent-request-id"], "p1")
        XCTAssertEqual(headers["x-root-parent-request-id"], "root2")
        XCTAssertEqual(headers["x-parent-agent-tool-call-id"], "tool3")
    }

    func testTraceparentParsingSamplingAndChildDerivation() {
        let parent = "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"
        let parsed = parseTraceparent(parent)
        XCTAssertEqual(parsed?.traceId, "0123456789abcdef0123456789abcdef")
        XCTAssertEqual(parsed?.traceFlags, 1)
        XCTAssertNil(parseTraceparent("00-00000000000000000000000000000000-0123456789abcdef-01"))
        XCTAssertFalse(shouldSampleSend(ratio: 0, random: { 0 }))
        XCTAssertTrue(shouldSampleSend(ratio: 0.5, random: { 0.4 }))
        XCTAssertTrue(deriveChildTraceparent(parent)?.traceparent.hasSuffix("-01") == true)
    }

    func testSentryPrivacyTierAndTelemetryVocabulary() {
        XCTAssertEqual(sandSentryPrivacyTierForMode(.usageDataTrainingAllowed), .full)
        XCTAssertEqual(sandSentryPrivacyTierForMode(.noTraining), .scrubbed)
        XCTAssertEqual(sandSentryPrivacyTierForMode(.noStorage), .fatalMetadata)
        XCTAssertEqual(TELEMETRY_DROP_UNIT_BY_REASON["ship_failed"], "attempts")
        XCTAssertEqual(TURN_USAGE_SCHEMA_VERSION, "2")
        XCTAssertTrue(WEBAUTHN_SIGN_ERROR_CLASSES.contains("platform_api"))
        XCTAssertTrue(isSandClientPersistenceSlice("send-journal"))
        XCTAssertFalse(isSandClientPersistenceSlice("unknown-slice"))
        XCTAssertEqual(SAND_QUEUED_FLUSH_CAUSE_CODES["ackExpired"], "SAND-E0707")
    }
}
