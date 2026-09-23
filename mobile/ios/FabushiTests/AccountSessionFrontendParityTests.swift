import XCTest
@testable import Fabushi

final class AccountSessionFrontendParityTests: XCTestCase {
    func testSignInPhaseKeepsActiveBrowserAttemptAheadOfBusyFlag() {
        XCTAssertEqual(
            AccountSignInPhase.resolve(attemptID: "attempt-12345678", busy: true),
            .awaitingBrowser(attemptID: "attempt-12345678")
        )
        XCTAssertEqual(AccountSignInPhase.resolve(attemptID: nil, busy: true), .starting)
        XCTAssertEqual(AccountSignInPhase.resolve(attemptID: nil, busy: false), .idle)
    }

    func testSignOutSurfaceClosesOnlyAfterLoggedOutProjection() {
        XCTAssertEqual(
            accountSignOutResult(isLoggedIn: false, message: "已退出登录"),
            .signedOut
        )
        XCTAssertEqual(
            accountSignOutResult(isLoggedIn: true, message: "退出登录失败：network"),
            .failed(message: "退出登录失败：network")
        )
        XCTAssertEqual(
            accountSignOutResult(isLoggedIn: true, message: "   "),
            .failed(message: "退出登录失败，请重试。")
        )
    }
}
