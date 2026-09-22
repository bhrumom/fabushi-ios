import XCTest
@testable import Fabushi

final class IOSLifecycleParityTests: XCTestCase {
    func testDeepLinkParserCanonicalizesAuthAndRejectsUnsafeInputs() throws {
        let parsed = try XCTUnwrap(FabushiDeepLinkParser.parse(
            "fabushi://auth/complete?attemptId=abcdefgh&status=completed"
        ))
        XCTAssertEqual(parsed.route, .authComplete(attemptId: "abcdefgh", status: "completed"))
        XCTAssertEqual(
            parsed.canonicalURL.absoluteString,
            "fabushi://auth/complete?attemptId=abcdefgh&status=completed"
        )
        XCTAssertNil(FabushiDeepLinkParser.parse(
            "fabushi://user:password@auth/complete?attemptId=abcdefgh"
        ))
        XCTAssertNil(FabushiDeepLinkParser.parse(
            "fabushi://auth/../complete?attemptId=abcdefgh"
        ))
        XCTAssertNil(FabushiDeepLinkParser.parse(
            "fabushi://auth/complete?attemptId=%ZZ"
        ))
    }

    func testReferenceDeepLinksShareTheSameCanonicalRouter() throws {
        let custom = try XCTUnwrap(FabushiDeepLinkParser.parse(
            "fabushi://app/v1/info?topic=deep-links"
        ))
        XCTAssertEqual(custom.route, .info(topic: "deep-links"))
        XCTAssertEqual(custom.source, .customScheme)

        let universal = try XCTUnwrap(FabushiDeepLinkParser.parse(
            "https://fabushi.app/link/v1/open"
        ))
        XCTAssertEqual(universal.route, .open)
        XCTAssertEqual(universal.source, .universalLink)
        XCTAssertEqual(universal.canonicalURL.absoluteString, "fabushi://app/v1/open")
    }

    @MainActor
    func testDeepLinkControllerQueuesBeforeRendererReadyAndDedupes() {
        var now = Date(timeIntervalSince1970: 100)
        var dispatched: [ParsedFabushiDeepLink] = []
        let controller = IOSDeepLinkController(
            dispatch: { dispatched.append($0) },
            now: { now }
        )

        XCTAssertTrue(controller.handleCandidate("fabushi://app/v1/open", origin: "test"))
        XCTAssertTrue(controller.hasPendingActivation)
        XCTAssertFalse(controller.handleCandidate("fabushi://app/v1/open", origin: "duplicate"))
        XCTAssertTrue(dispatched.isEmpty)

        controller.markReady()
        XCTAssertEqual(dispatched.map(\.route), [.open])

        now = now.addingTimeInterval(IOSDeepLinkController.dedupeWindow + 0.1)
        XCTAssertTrue(controller.handleCandidate("fabushi://app/v1/open", origin: "after-window"))
        XCTAssertEqual(dispatched.count, 2)
    }

    @MainActor
    func testLifecycleCheckpointRequiresResyncAfterBackgroundOrUncleanTermination() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try IOSLifecycleRecoveryStore(appDataDirectory: directory)
        XCTAssertFalse(first.requiresColdStartResync)
        first.transition(to: .background)

        let second = try IOSLifecycleRecoveryStore(appDataDirectory: directory)
        XCTAssertTrue(second.requiresColdStartResync)
        second.markResyncCompleted()
        XCTAssertFalse(second.requiresColdStartResync)
    }

    @MainActor
    func testCleanShutdownDoesNotForceColdStartResync() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try IOSLifecycleRecoveryStore(appDataDirectory: directory)
        first.transition(to: .shuttingDown)
        let second = try IOSLifecycleRecoveryStore(appDataDirectory: directory)
        XCTAssertFalse(second.requiresColdStartResync)
    }

    @MainActor
    func testLifecycleReporterBuffersAndFlushesInOrder() {
        let reporter = IOSLifecycleReporter()
        reporter.report(.startup, metadata: ["phase": "one"])
        reporter.report(.rendererLifecycle, level: .warn, metadata: ["phase": "two"])
        XCTAssertEqual(reporter.bufferedCount, 2)

        var records: [IOSLifecycleTelemetryRecord] = []
        reporter.attach { records.append($0) }
        XCTAssertEqual(records.map(\.family), [.startup, .rendererLifecycle])
        XCTAssertEqual(records.map(\.level), [.info, .warn])
        XCTAssertEqual(reporter.bufferedCount, 0)
    }
}
