import SwiftUI

extension GrokMobileShell {
    @MainActor
    func loadBots() async {
        bots = await GrokMobileBotService(bridge: bridge).loadBots()
    }

    @MainActor
    func createBot() async {
        let name = botName.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = botDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !botBusy else { return }

        botBusy = true
        botError = nil
        defer { botBusy = false }

        do {
            bots = try await GrokMobileBotService(bridge: bridge).createBot(
                name: name,
                description: description
            )
            botName = ""
            botDescription = ""
            createBotOpen = false
            await messaging.refresh()
        } catch {
            botError = error.localizedDescription
        }
    }
}
