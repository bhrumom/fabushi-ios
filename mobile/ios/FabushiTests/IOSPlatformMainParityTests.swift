import XCTest
@testable import Fabushi

private actor RecordingBadgeApplier: IOSAppBadgeApplying {
    private(set) var counts: [Int] = []

    func setBadgeCount(_ count: Int) async {
        counts.append(count)
    }

    func recordedCounts() -> [Int] { counts }
}

final class IOSPlatformMainParityTests: XCTestCase {
    func testSentryConversationReportRequiresNullOrBoundedAgentId() {
        XCTAssertTrue(isValidSentryConversationReport(["agentId": NSNull()]))
        XCTAssertTrue(isValidSentryConversationReport(["agentId": "agent-123"]))
        XCTAssertFalse(isValidSentryConversationReport([:]))
        XCTAssertFalse(isValidSentryConversationReport(["agentId": "bad value with spaces"]))
        XCTAssertFalse(isValidSentryConversationReport(["agentId": "person@example.com"]))
        XCTAssertFalse(isValidSentryConversationReport(nil))
    }

    func testDockBadgeMatchesRecoveredUnreadRulesAndAppliesNativeBadgeCount() async {
        let agents = [
            IOSDockBadgeAgent(hasUnread: true, unreadCount: 3.9),
            IOSDockBadgeAgent(hasUnread: true, unreadCount: 0),
            IOSDockBadgeAgent(hasUnread: false, unreadCount: 50),
            IOSDockBadgeAgent(hasUnread: true, isHiddenFromSidebar: true, unreadCount: 8),
            IOSDockBadgeAgent(hasUnread: true, unreadCount: nil),
        ]
        XCTAssertEqual(computeDockBadgeTotal(agents), 5)

        let recorder = RecordingBadgeApplier()
        let controller = IOSDockBadgeController(applier: recorder)
        let total = await controller.update(agents: agents)
        XCTAssertEqual(total, 5)
        let recordedCounts = await recorder.recordedCounts()
        XCTAssertEqual(recordedCounts, [5])
    }


    func testSendTelemetryValidationAndProjectionMatchRecoveredContract() {
        let value: [String: Any] = [
            "durationMs": 10.4,
            "commitMs": 4.6,
            "attachmentCount": 2,
            "isFork": true,
            "traceId": "trace-1",
            "spanId": "span-1",
        ]
        let report = parseValidSendLatencyReport(value)
        XCTAssertNotNil(report)
        XCTAssertFalse(isValidSendLatencyReport([
            "durationMs": -1,
            "attachmentCount": 0,
            "isFork": false,
        ]))
        XCTAssertFalse(isValidSendLatencyReport([
            "durationMs": 1,
            "attachmentCount": 0,
            "isFork": false,
            "traceId": NSNull(),
        ]))
        let event = sendLatencyReportToTelemetry(report!)
        XCTAssertEqual(event.level, "info")
        XCTAssertEqual(event.metadata["duration_ms"], "10")
        XCTAssertEqual(event.metadata["commit_ms"], "5")
        XCTAssertEqual(event.metadata["attachment_count"], "2")
        XCTAssertEqual(event.metadata["is_fork"], "true")
    }

    func testProcessNameRedactionPreservesOnlyKnownHelperLabels() {
        let helper = sanitizeProcessName("/Applications/Grok Bot Helper (GPU)")
        XCTAssertEqual(helper.name, "Grok Bot Helper (GPU)")
        XCTAssertEqual(helper.nameHash.count, 64)

        let unknown = sanitizeProcessName("/Users/person/Secret Process --token abc")
        XCTAssertEqual(unknown.name, "Secret")
        XCTAssertEqual(
            unknown.nameHash,
            hashProcessName("/Users/person/Secret Process --token abc")
        )
    }

    func testUnavailableOnePasswordProvisioningSinkFailsClosed() async {
        let sink = UnavailableOnePasswordProvisioningSink<String>()
        XCTAssertEqual(sink.availability, .unavailable)
        do {
            try await sink.accept("credential")
            XCTFail("unconfigured 1Password provisioning must fail closed")
        } catch let error as OnePasswordProvisioningError {
            XCTAssertEqual(error.code, "sink-unavailable")
            XCTAssertTrue(error.message.contains("unavailable"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
