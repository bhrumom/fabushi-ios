import SwiftUI

extension GrokMobileShell {
    @MainActor
    func publishAppAgentSurface() {
        var elements: [FabushiAppAgentSurface.Element] = []
        var actions: [String: FabushiAppAgentSurface.Action] = [:]
        func add(
            _ id: String,
            role: String,
            name: String,
            enabled: Bool = true,
            action: FabushiAppAgentSurface.Action? = nil
        ) {
            let normalizedId = Self.semanticId(id)
            elements.append(.init(
                agentId: normalizedId,
                role: String(role.prefix(80)),
                name: String(name.prefix(240)),
                enabled: enabled
            ))
            if let action { actions[normalizedId] = action }
        }

        if createBotOpen {
            add("grok-create-bot", role: "dialog", name: "新建 Bot")
            add("new-bot-name", role: "textbox", name: "Bot 名称", action: .init(allowed: ["setValue"]) { value in botName = value ?? "" })
            add("new-bot-description", role: "textbox", name: "Bot 描述", action: .init(allowed: ["setValue"]) { value in botDescription = value ?? "" })
            add(
                "create-bot-submit",
                role: "button",
                name: botBusy ? "正在创建 Bot" : "创建 Bot",
                enabled: !botBusy && !botName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: .init(allowed: ["invoke"]) { _ in Task { await createBot() } }
            )
            add("create-bot-cancel", role: "button", name: "取消创建 Bot", action: .init(allowed: ["invoke"]) { _ in createBotOpen = false })
            if botError != nil { add("create-bot-error", role: "status", name: "Bot 创建失败") }
            try? appAgentSurface.publish(screen: "grok-create-bot", elements: elements, actions: actions)
            return
        }

        if composeOpen {
            add("grok-compose", role: "dialog", name: "创建")
            add("grok-compose-bot", role: "button", name: "新建 Bot", action: .init(allowed: ["invoke"]) { _ in composeOpen = false; createBotOpen = true })
            add("grok-compose-message", role: "button", name: "新消息", action: .init(allowed: ["invoke"]) { _ in composeOpen = false; legacyOpen = true })
            add("grok-compose-group", role: "button", name: "新建群组", action: .init(allowed: ["invoke"]) { _ in composeOpen = false; legacyOpen = true })
            add("grok-compose-channel", role: "button", name: "新建频道", action: .init(allowed: ["invoke"]) { _ in composeOpen = false; legacyOpen = true })
            add("grok-compose-cancel", role: "button", name: "取消", action: .init(allowed: ["invoke"]) { _ in composeOpen = false })
            try? appAgentSurface.publish(screen: "grok-compose", elements: elements, actions: actions)
            return
        }

        add("grok-mobile-home", role: "application", name: "Fabushi")
        add("grok-mobile-legacy", role: "button", name: "打开完整消息工作台", action: .init(allowed: ["invoke"]) { _ in legacyOpen = true })
        add("grok-mobile-search", role: "button", name: searchOpen ? "关闭搜索" : "打开搜索", action: .init(allowed: ["invoke"]) { _ in
            searchOpen.toggle()
            if !searchOpen { query = "" }
        })
        add("grok-mobile-search-field", role: "textbox", name: "搜索", action: .init(allowed: ["setValue"]) { value in
            searchOpen = true
            query = value ?? ""
        })
        add("grok-mobile-add", role: "button", name: "创建", action: .init(allowed: ["invoke"]) { _ in composeOpen = true })
        add("grok-bot-mahayana-assistant", role: "button", name: "Mahayana", action: .init(allowed: ["invoke"]) { _ in selectedBot = MobileBotSummary(id: "mahayana-assistant", name: "Mahayana", description: "Ready to help") })
        for bot in filteredBots.prefix(100) {
            add("grok-bot-\(bot.id)", role: "button", name: bot.name, action: .init(allowed: ["invoke"]) { _ in selectedBot = bot })
        }
        for conversation in filteredConversations.prefix(100) {
            add(
                "grok-conversation-\(conversation.id)",
                role: "button",
                name: conversation.title,
                action: .init(allowed: ["invoke"]) { _ in legacyOpen = true }
            )
        }
        try? appAgentSurface.publish(screen: "grok-home", elements: elements, actions: actions)
    }

    static func semanticId(_ value: String) -> String {
        String(value.map { character in
            character.isASCII && (character.isLetter || character.isNumber || "._:/@-".contains(character)) ? character : "-"
        }.prefix(200))
    }
}
