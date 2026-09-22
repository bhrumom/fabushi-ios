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
        XCTAssertEqual(await recorder.recordedCounts(), [5])
    }
}
