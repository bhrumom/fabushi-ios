import SwiftUI

internal struct GrokMobileShell: View {
    @Bindable var model: MarketplaceModel
    @Bindable var messaging: MessagingModel
    let bridge: IOSPreloadBridge
    let appAgentSurface: FabushiAppAgentSurface

    @State private var query = ""
    @State private var searchOpen = false
    @State private var composeOpen = false
    @State private var createBotOpen = false
    @State private var botName = ""
    @State private var botDescription = ""
    @State private var botBusy = false
    @State private var botError: String?
    @State private var bots: [MobileBotSummary] = []
    @State private var selectedBot: MobileBotSummary?
    @State private var botDrafts: [String: String] = [:]
    @State private var botTranscripts: [String: [MobileChatMessage]] = [:]
    @State private var legacyOpen = false

    var body: some View {
        if model.onboardingStep < 3 || !model.authResolved || !model.loggedIn {
            ContentView(model: model, messaging: messaging, appAgentSurface: appAgentSurface)
        } else if let selectedBot {
            MobileBotChat(
                bot: selectedBot,
                bridge: bridge,
                model: model,
                appAgentSurface: appAgentSurface,
                onClose: { self.selectedBot = nil },
                draft: Binding(
                    get: { botDrafts[selectedBot.id] ?? "" },
                    set: { botDrafts[selectedBot.id] = $0 }
                ),
                entries: Binding(
                    get: { botTranscripts[selectedBot.id] ?? [] },
                    set: { botTranscripts[selectedBot.id] = $0 }
                )
            )
        } else if legacyOpen {
            VStack(spacing: 0) {
                HStack {
                    Button { legacyOpen = false } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityIdentifier("grok-mobile-back")
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                ContentView(model: model, messaging: messaging, appAgentSurface: appAgentSurface)
            }
        } else {
            home
                .task { await loadBots() }
                .task { await messaging.refresh() }
                .task(id: appAgentSurfaceFingerprint) { publishAppAgentSurface() }
        }
    }

    private var appAgentSurfaceFingerprint: String {
        [
            query,
            String(searchOpen),
            String(composeOpen),
            String(createBotOpen),
            botName,
            botDescription,
            String(botBusy),
            botError ?? "",
            bots.map { "\($0.id):\($0.name):\($0.miniAppId ?? "")" }.joined(separator: ","),
            messaging.conversations.map { "\($0.id):\($0.unreadCount):\($0.isArchived)" }.joined(separator: ","),
        ].joined(separator: "|")
    }

    @MainActor
    private func publishAppAgentSurface() {
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

    private static func semanticId(_ value: String) -> String {
        String(value.map { character in
            character.isASCII && (character.isLetter || character.isNumber || "._:/@-".contains(character)) ? character : "-"
        }.prefix(200))
    }

    private var home: some View {
        ZStack {
            Color(red: 0.985, green: 0.985, blue: 0.975).ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button { legacyOpen = true } label: {
                            ZStack {
                                Circle().fill(Color(red: 1.0, green: 0.78, blue: 0.82))
                                Text(String(model.accountName.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                            }
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(.white, lineWidth: 3)).shadow(color: .black.opacity(0.08), radius: 6)
                        }
                        .accessibilityIdentifier("grok-mobile-legacy")
                        Spacer()
                        Button {
                            searchOpen.toggle()
                            if !searchOpen { query = "" }
                        } label: { Image(systemName: "magnifyingglass") }
                            .accessibilityIdentifier("grok-mobile-search")
                        Button { composeOpen = true } label: { Image(systemName: "plus") }
                            .accessibilityIdentifier("grok-mobile-add")
                    }
                    .font(.system(size: 19, weight: .semibold)).foregroundStyle(.black)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18).padding(.top, 10)

                    VStack(spacing: 7) {
                        ZStack {
                            ClothGhostAvatar(botId: "all-hands-green", size: 50).offset(x: -25, y: 7).rotationEffect(.degrees(-8))
                            ClothGhostAvatar(botId: "all-hands-violet", size: 50).offset(x: -1, y: 17).rotationEffect(.degrees(7))
                            ClothGhostAvatar(botId: "mahayana-assistant", size: 55).offset(x: 24, y: -1)
                            Text("+2").font(.system(size: 29, weight: .bold)).foregroundStyle(Color.black.opacity(0.34)).offset(x: 48, y: 28)
                        }.frame(width: 130, height: 82)
                        Text("All Hands").font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 38).padding(.bottom, 34)

                    if searchOpen {
                        TextField("Search", text: $query)
                            .textFieldStyle(.plain).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16).padding(.bottom, 14)
                            .accessibilityIdentifier("grok-mobile-search-field")
                    }

                    sectionTitle("Board")
                    botRow(MobileBotSummary(id: "mahayana-assistant", name: "Mahayana", description: "Ready to help"), subtitle: "that's the only new one.", badge: "Board")

                    if !bots.isEmpty {
                        sectionTitle("Bots  \(bots.count)")
                        ForEach(filteredBots) { bot in botRow(bot, subtitle: bot.description.isEmpty ? "Ready" : bot.description, badge: bot.miniAppId == nil ? "Bot" : "Mini App Bot") }
                    }

                    let projects = filteredConversations.filter { $0.kind == .group || $0.kind == .direct }
                    if !projects.isEmpty {
                        sectionTitle("Projects  \(projects.count)")
                        ForEach(projects.prefix(8)) { conversation in conversationRow(conversation) }
                    }
                    let channels = filteredConversations.filter { $0.kind == .channel }
                    if !channels.isEmpty {
                        sectionTitle("Channels  \(channels.count)")
                        ForEach(channels.prefix(8)) { conversation in conversationRow(conversation) }
                    }
                    Spacer(minLength: 40)
                }
            }
        }
        .confirmationDialog("Create", isPresented: $composeOpen, titleVisibility: .visible) {
            Button("New Bot") { createBotOpen = true }
            Button("New message") { legacyOpen = true }
            Button("New group") { legacyOpen = true }
            Button("New channel") { legacyOpen = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $createBotOpen) { createBotSheet }
        .accessibilityIdentifier("grok-mobile-home")
    }

    private var filteredBots: [MobileBotSummary] {
        guard !query.isEmpty else { return bots }
        return bots.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) }
    }

    private var filteredConversations: [ConversationSummary] {
        let rows = messaging.conversations.filter { !$0.isArchived }
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.preview.localizedCaseInsensitiveContains(query) }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 16)).foregroundStyle(Color.black.opacity(0.42)).padding(.horizontal, 18).padding(.top, 13).padding(.bottom, 7)
    }

    private func botRow(_ bot: MobileBotSummary, subtitle: String, badge: String) -> some View {
        Button { selectedBot = bot } label: {
            HStack(spacing: 12) {
                ClothGhostAvatar(botId: bot.id, size: 47, badge: .green)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(bot.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                        Text(badge).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 7).padding(.vertical, 3).background(Color.black.opacity(0.045), in: Capsule())
                    }
                    Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text("now").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        Button { legacyOpen = true } label: {
            HStack(spacing: 12) {
                ClothGhostAvatar(botId: "conversation:\(conversation.id)", size: 45, badge: conversation.unreadCount > 0 ? .blue : nil)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(conversation.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.black).lineLimit(1)
                        Text(conversation.kind == .channel ? "Channel" : "Engineering").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 7).padding(.vertical, 3).background(Color.black.opacity(0.045), in: Capsule())
                    }
                    Text(conversation.preview.isEmpty ? "Ready" : conversation.preview).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text(conversation.time).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 9)
        }.buttonStyle(.plain)
    }

    private var createBotSheet: some View {
        NavigationStack {
            Form {
                Section {
                    HStack { Spacer(); ClothGhostAvatar(botId: botName.isEmpty ? "new-bot" : botName, size: 82, active: botBusy); Spacer() }
                }
                Section("Name") { TextField("Bot name", text: $botName).accessibilityIdentifier("new-bot-name") }
                Section("Description") { TextField("What does this Bot do?", text: $botDescription, axis: .vertical).lineLimit(2...5) }
                if let botError { Section { Text(botError).foregroundStyle(.red).font(.footnote) } }
            }
            .navigationTitle("New Bot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { createBotOpen = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(botBusy ? "Creating…" : "Create") { Task { await createBot() } }
                        .disabled(botBusy || botName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("create-bot-submit")
                }
            }
        }
    }

    @MainActor
    private func loadBots() async {
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
    private func createBot() async {
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

    private static func mergeBots(_ installed: [MobileBotSummary], _ surface: [MobileBotSummary]) -> [MobileBotSummary] {
        var byId: [String: MobileBotSummary] = [:]
        for bot in surface { byId[bot.id] = bot }
        for bot in installed { byId[bot.id] = bot }
        return byId.values.sorted {
            if ($0.miniAppId != nil) != ($1.miniAppId != nil) { return $0.miniAppId != nil }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func parseBot(_ row: [String: Any]) -> MobileBotSummary? {
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
