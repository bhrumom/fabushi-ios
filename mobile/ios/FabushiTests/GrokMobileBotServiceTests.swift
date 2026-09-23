import XCTest
@testable import Fabushi

final class GrokMobileBotServiceTests: XCTestCase {
    @MainActor
    func testMergePrefersInstalledMiniAppProjectionForSameBot() {
        let surface = [
            MobileBotSummary(
                id: "global-dharma-bot",
                name: "Surface",
                description: "surface",
                miniAppId: nil,
                menuButtonText: nil
            ),
            MobileBotSummary(
                id: "plain-bot",
                name: "Plain",
                description: "plain"
            ),
        ]
        let installed = [
            MobileBotSummary(
                id: "global-dharma-bot",
                name: "全球法布施",
                description: "installed",
                miniAppId: GlobalDharmaMiniAppBridge.globalDharmaId,
                menuButtonText: "打开应用"
            ),
        ]

        let merged = GrokMobileBotService.mergeBots(installed, surface)

        XCTAssertEqual(merged.first?.id, "global-dharma-bot")
        XCTAssertEqual(merged.first?.name, "全球法布施")
        XCTAssertEqual(merged.first?.miniAppId, GlobalDharmaMiniAppBridge.globalDharmaId)
        XCTAssertEqual(merged.count, 2)
    }

    @MainActor
    func testParseBotAppliesGlobalDharmaMiniAppFallback() throws {
        let bot = try XCTUnwrap(GrokMobileBotService.parseBot([
            "id": "global-dharma-bot",
            "displayName": "全球法布施",
            "description": "Dharma",
        ]))

        XCTAssertEqual(bot.name, "全球法布施")
        XCTAssertEqual(bot.miniAppId, GlobalDharmaMiniAppBridge.globalDharmaId)
        XCTAssertEqual(bot.menuButtonText, "打开应用")
    }

    @MainActor
    func testParseBotRejectsMissingIdentity() {
        XCTAssertNil(GrokMobileBotService.parseBot(["name": "Missing id"]))
    }
}
