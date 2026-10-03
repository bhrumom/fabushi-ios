import XCTest
@testable import Fabushi

final class MarketplaceModelLifecycleTests: XCTestCase {
    func testMahayanaChatPumpOutcomeOnlySettlesOnTerminalEvent() {
        XCTAssertTrue(MahayanaChatPumpOutcome.terminal.shouldSettleLifecycle)
        XCTAssertFalse(MahayanaChatPumpOutcome.nonTerminal.shouldSettleLifecycle)
    }

    func testListenerConnectTranscriptCardProjectsHostTruthWithoutOwningResumeState() throws {
        let pending = try XCTUnwrap(projectListenerConnectTranscriptCard(
            event: [
                "type": "transcript.card",
                "entryId": "listener-connect:mahayana-assistant:slack",
                "card": [
                    "kind": "listenerConnect",
                    "platform": "slack",
                    "reason": "so this routine can fire",
                    "connected": false,
                    "pending": true,
                ],
            ],
            operationId: "op-1"
        ))
        XCTAssertEqual(pending.kind, .action)
        XCTAssertEqual(pending.actionTitle, "连接 Slack")
        XCTAssertEqual(pending.actionDetail, "so this routine can fire")
        XCTAssertEqual(pending.actionStatus, "pending")
        XCTAssertEqual(pending.operationId, "op-1")

        let connected = try XCTUnwrap(projectListenerConnectTranscriptCard(
            event: [
                "type": "transcript.card",
                "entryId": pending.id,
                "card": [
                    "kind": "listenerConnect",
                    "platform": "slack",
                    "connected": true,
                    "pending": false,
                ],
            ],
            operationId: "op-1"
        ))
        XCTAssertEqual(connected.id, pending.id)
        XCTAssertEqual(connected.actionTitle, "Slack 已连接")
        XCTAssertEqual(connected.actionStatus, "completed")
        XCTAssertTrue(connected.actionDetail?.contains("已连接") == true)
    }
    func testListenerProjectionFallbackIdentityAndDefaultDetailArePlatformSpecific() throws {
        func card(_ platform: String, connected: Bool) throws -> MobileChatMessage {
            try XCTUnwrap(projectListenerConnectTranscriptCard(
                event: ["card": ["kind": "listenerConnect", "platform": platform,
                                  "connected": connected, "reason": "  "]],
                operationId: nil
            ))
        }
        let slack = try card("Slack", connected: false)
        let github = try card("github", connected: true)
        XCTAssertEqual(slack.id, "listener-connect:slack")
        XCTAssertEqual(github.id, "listener-connect:github")
        XCTAssertNotEqual(slack.id, github.id)
        XCTAssertEqual(slack.actionDetail, "连接 Slack 后，此例程才能接收对应事件。")
        XCTAssertEqual(github.actionDetail, "GitHub 已连接。")
    }

}
