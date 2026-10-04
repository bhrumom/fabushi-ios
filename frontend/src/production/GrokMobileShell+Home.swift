import SwiftUI

extension GrokMobileShell {
    var home: some View {
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

    var filteredBots: [MobileBotSummary] {
        guard !query.isEmpty else { return bots }
        return bots.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) }
    }

    var filteredConversations: [ConversationSummary] {
        let rows = messaging.conversations.filter { !$0.isArchived }
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.preview.localizedCaseInsensitiveContains(query) }
    }

    func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 16)).foregroundStyle(Color.black.opacity(0.42)).padding(.horizontal, 18).padding(.top, 13).padding(.bottom, 7)
    }

    func botRow(_ bot: MobileBotSummary, subtitle: String, badge: String) -> some View {
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

    func conversationRow(_ conversation: ConversationSummary) -> some View {
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

    var createBotSheet: some View {
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
}
