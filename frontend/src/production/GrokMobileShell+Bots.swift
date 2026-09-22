import SwiftUI

extension GrokMobileShell {
    @MainActor
    func loadBots() async {
        let canonical = (try? await GlobalDharmaMiniAppBridge(bridge: bridge).installedMiniAppBots()) ?? []
        let installedBots = canonical.map {
            MobileBotSummary(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                miniAppId: $0.miniAppId,
                menuButtonText: $0.menuButtonText
            )
        }
        let requestId = "ios-mobile-bot-list-\(UUID().uuidString.lowercased())"
        do {
            _ = try await bridge.request(method: "feature.execute", params: ["command": ["type": "bot.list", "requestId": requestId]])
            for _ in 0..<32 {
                let result = try await bridge.request(method: "feature.receive", params: ["timeoutMs": 80])
                guard let event = result.value as? [String: Any], let type = event["type"] as? String else { continue }
                if type == "bot.listed", let rows = event["bots"] as? [[String: Any]] {
                    let surfaceBots = rows.compactMap(Self.parseBot).filter { $0.id != "mahayana-assistant" }
                    bots = Self.mergeBots(installedBots, surfaceBots)
                    return
                }
            }
            bots = installedBots
        } catch {
            bots = installedBots
        }
    }

    @MainActor
    func createBot() async {
        let name = botName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !botBusy else { return }
        botBusy = true
        botError = nil
        let requestId = "ios-mobile-bot-create-\(UUID().uuidString.lowercased())"
        do {
            _ = try await bridge.request(method: "feature.execute", params: ["command": ["type": "bot.create", "requestId": requestId, "name": String(name.prefix(72)), "description": String(botDescription.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))]])
            botName = ""
            botDescription = ""
            createBotOpen = false
            await loadBots()
            await messaging.refresh()
        } catch {
            botError = error.localizedDescription
        }
        botBusy = false
    }

    static func mergeBots(_ installed: [MobileBotSummary], _ surface: [MobileBotSummary]) -> [MobileBotSummary] {
        var byId: [String: MobileBotSummary] = [:]
        for bot in surface { byId[bot.id] = bot }
        for bot in installed { byId[bot.id] = bot }
        return byId.values.sorted {
            if ($0.miniAppId != nil) != ($1.miniAppId != nil) { return $0.miniAppId != nil }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func parseBot(_ row: [String: Any]) -> MobileBotSummary? {
        guard let id = row["id"] as? String, !id.isEmpty else { return nil }
        let explicitMiniAppId = (row["miniAppId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let miniAppId = explicitMiniAppId?.isEmpty == false
            ? explicitMiniAppId
            : (id == "global-dharma-bot" ? GlobalDharmaMiniAppBridge.globalDharmaId : nil)
        let menuText = (row["menuButtonText"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MobileBotSummary(
            id: id,
            name: (row["name"] as? String) ?? (row["displayName"] as? String) ?? id,
            description: row["description"] as? String ?? "",
            miniAppId: miniAppId,
            menuButtonText: menuText?.isEmpty == false ? menuText : (miniAppId == nil ? nil : "打开应用")
        )
    }
}
