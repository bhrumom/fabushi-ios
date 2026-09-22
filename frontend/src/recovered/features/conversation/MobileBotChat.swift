import SwiftUI

internal struct MobileBotChat: View {
    let bot: MobileBotSummary
    let bridge: IOSPreloadBridge
    let model: MarketplaceModel
    let appAgentSurface: FabushiAppAgentSurface
    let onClose: () -> Void

    @Binding var draft: String
    @Binding var entries: [MobileChatMessage]
    @State private var busy = false
    @State private var activeOperationId: String?
    @State private var errorText: String?
    @State private var openedMiniApp = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.045), in: Circle())
                }
                Spacer()
                HStack(spacing: 8) {
                    ClothGhostAvatar(botId: bot.id, size: 28, active: busy)
                    Text(bot.name).font(.system(size: 17, weight: .semibold))
                }
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(.white, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 12, y: 3)
                Spacer()
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(Color.black.opacity(0.045), in: Circle())
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.white.opacity(0.97))

            Divider().opacity(0.35)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        if entries.isEmpty {
                            VStack(spacing: 13) {
                                ClothGhostAvatar(botId: bot.id, size: 82)
                                Text(bot.name).font(.title2.bold())
                                if !bot.description.isEmpty {
                                    Text(bot.description).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.top, 96).padding(.horizontal, 30)
                        }

                        ForEach(entries) { entry in
                            transcript(entry)
                                .id(entry.id)
                        }
                        if let errorText {
                            Text(errorText).font(.caption).foregroundStyle(.red).padding(.top, 4)
                                .accessibilityIdentifier("mobile-bot-error")
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 18)
                }
                .background(Color(red: 0.985, green: 0.985, blue: 0.975))
                .onChange(of: entries.count) { _, _ in
                    if let last = entries.last { withAnimation(.easeOut(duration: 0.16)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onSubmit { if !busy { Task { await send() } } }
                    .accessibilityIdentifier("mobile-bot-draft")

                if bot.miniAppId == GlobalDharmaMiniAppBridge.globalDharmaId {
                    Button {
                        openedMiniApp = true
                    } label: {
                        Text(bot.menuButtonText ?? "打开应用")
                            .font(.caption.bold())
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 39)
                            .background(Color.black.opacity(0.075), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(bot.menuButtonText ?? "打开应用")
                    .accessibilityIdentifier("mobile-bot-open-miniapp")
                }

                Button {
                    if busy { Task { await stop() } } else { Task { await send() } }
                } label: {
                    Image(systemName: busy ? "stop.fill" : "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 39, height: 39)
                        .background(busy ? Color.red : Color.black, in: Circle())
                }
                .disabled(!busy && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier(busy ? "mobile-bot-stop" : "mobile-bot-send")
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
        .background(Color(red: 0.985, green: 0.985, blue: 0.975))
        .accessibilityIdentifier("mobile-bot-chat")
        .task(id: semanticFingerprint) { publishAppAgentSurface() }
        .fullScreenCover(isPresented: $openedMiniApp) {
            GlobalDharmaMiniAppView(model: model, bridge: bridge)
        }
    }

    private var semanticFingerprint: String {
        [
            bot.id,
            bot.miniAppId ?? "",
            bot.menuButtonText ?? "",
            draft,
            String(busy),
            String(openedMiniApp),
            activeOperationId ?? "",
            errorText ?? "",
            entries.map { "\($0.id):\($0.kind.rawValue):\($0.role.rawValue)" }.joined(separator: ","),
        ].joined(separator: "|")
    }

    @MainActor
    private func publishAppAgentSurface() {
        var elements: [FabushiAppAgentSurface.Element] = [
            .init(agentId: "mobile-bot-chat", role: "application", name: "Bot \(String(bot.name.prefix(160)))"),
            .init(agentId: "mobile-bot-close", role: "button", name: "关闭 Bot 对话"),
            .init(agentId: "mobile-bot-draft", role: "textbox", name: "Bot 消息"),
        ]
        let sendId = busy ? "mobile-bot-stop" : "mobile-bot-send"
        elements.append(.init(
            agentId: sendId,
            role: "button",
            name: busy ? "停止 Bot" : "发送 Bot 消息",
            enabled: busy || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ))
        if bot.miniAppId == GlobalDharmaMiniAppBridge.globalDharmaId {
            elements.append(.init(
                agentId: "mobile-bot-open-miniapp",
                role: "button",
                name: bot.menuButtonText ?? "打开应用",
                enabled: !openedMiniApp
            ))
        }
        if errorText != nil {
            elements.append(.init(agentId: "mobile-bot-error", role: "status", name: "Bot 或 Mini App 调用失败"))
        }
        for entry in entries.suffix(50) {
            let id = Self.semanticId("mobile-bot-entry-\(entry.id)")
            let roleName = entry.role == .user ? "用户消息" : entry.kind == .action ? "Bot 动作" : entry.kind == .thinking ? "Bot 思考" : "Bot 消息"
            elements.append(.init(agentId: id, role: "log", name: roleName))
        }
        var actions: [String: FabushiAppAgentSurface.Action] = [
            "mobile-bot-close": .init(allowed: ["invoke"]) { _ in onClose() },
            "mobile-bot-draft": .init(allowed: ["setValue"]) { value in draft = value ?? "" },
        ]
        actions[sendId] = .init(allowed: ["invoke"]) { _ in
            if busy { Task { await stop() } } else { Task { await send() } }
        }
        if bot.miniAppId == GlobalDharmaMiniAppBridge.globalDharmaId {
            actions["mobile-bot-open-miniapp"] = .init(allowed: ["invoke"]) { _ in openedMiniApp = true }
        }
        try? appAgentSurface.publish(screen: "bot-chat", elements: elements, actions: actions)
    }

    private static func semanticId(_ value: String) -> String {
        String(value.map { character in
            character.isASCII && (character.isLetter || character.isNumber || "._:/@-".contains(character)) ? character : "-"
        }.prefix(200))
    }

    @ViewBuilder
    private func transcript(_ entry: MobileChatMessage) -> some View {
        if entry.kind == .thinking {
            HStack(spacing: 7) {
                ClothGhostAvatar(botId: bot.id, size: 22, active: true)
                Text(entry.actionTitle ?? "Thinking…").font(.caption).foregroundStyle(.secondary)
                ProgressView().controlSize(.mini)
            }
            .padding(.vertical, 4)
        } else if entry.kind == .action {
            HStack(spacing: 7) {
                Circle().fill(entry.actionStatus == "failed" ? Color.red : Color.orange).frame(width: 7, height: 7)
                Text(entry.actionTitle ?? "Working").font(.caption.weight(.medium))
                if let detail = entry.actionDetail, !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            .padding(.vertical, 2)
        } else if entry.role == .user {
            HStack {
                Spacer(minLength: 54)
                Text(entry.text)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15).padding(.vertical, 10)
                    .background(.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(bot.name).font(.caption).foregroundStyle(.secondary).padding(.leading, 12)
                HStack(alignment: .bottom, spacing: 7) {
                    ClothGhostAvatar(botId: bot.id, size: 20)
                    Text(entry.text)
                        .overlay(alignment: .trailing) {
                            if entry.streaming {
                                Text("▌").foregroundStyle(.black.opacity(0.65))
                            }
                        }
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 15).padding(.vertical, 10)
                        .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Spacer(minLength: 30)
                }
            }
        }
    }

    @MainActor
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        draft = ""
        busy = true
        errorText = nil
        let requestId = "ios-mobile-bot-chat-\(UUID().uuidString.lowercased())"
        entries.append(MobileChatMessage(id: requestId, role: .user, text: text))

        if let miniAppId = bot.miniAppId {
            await sendMiniApp(pluginId: miniAppId, text: text, operationId: requestId)
            activeOperationId = nil
            busy = false
            return
        }

        do {
            let result = try await bridge.request(
                method: "feature.execute",
                params: ["command": ["type": "chat.send", "requestId": requestId, "text": text, "agentId": bot.id, "mode": "agent"]]
            )
            let accepted = result.value as? [String: Any]
            let operationId = accepted?["operationId"] as? String ?? requestId
            activeOperationId = operationId
            entries.append(MobileChatMessage(id: "thinking:\(operationId)", role: .assistant, text: "", kind: .thinking, operationId: operationId, actionTitle: "Thinking", actionStatus: "running"))
            await pump(operationId: operationId)
        } catch {
            errorText = error.localizedDescription
        }
        activeOperationId = nil
        busy = false
    }

    @MainActor
    private func sendMiniApp(pluginId: String, text: String, operationId: String) async {
        activeOperationId = operationId
        entries.append(MobileChatMessage(
            id: "thinking:\(operationId)",
            role: .assistant,
            text: "",
            kind: .thinking,
            operationId: operationId,
            actionTitle: "正在通过 WebMCP 理解并执行",
            actionStatus: "running"
        ))
        do {
            let bridge = GlobalDharmaMiniAppBridge(bridge: bridge)
            let routed = try await bridge.routeInput(pluginId: pluginId, input: text)
            guard let execution = routed["execution"] as? [String: Any] else {
                removeThinking(operationId)
                let reply = (routed["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                entries.append(MobileChatMessage(
                    id: "assistant:\(operationId)",
                    role: .assistant,
                    text: reply?.isEmpty == false ? reply! : "全球法布施没有把这条输入解析成可执行命令。",
                    operationId: operationId
                ))
                return
            }
            let command = routed["command"] as? [String: Any]
            let slash = command?["slash"] as? String ?? ""
            if routed["requiresApproval"] as? Bool == true {
                removeThinking(operationId)
                entries.append(MobileChatMessage(
                    id: "assistant:\(operationId)",
                    role: .assistant,
                    text: "已通过统一 Mini App 路由解析\(slash.isEmpty ? "" : "为 \(slash)")。该 Tool 需要宿主明确批准；iOS 不会静默执行写入或破坏性调用。",
                    operationId: operationId
                ))
                return
            }
            guard (execution["kind"] as? String) == "mcp-http",
                  let tool = execution["tool"] as? String,
                  !tool.isEmpty
            else {
                throw MahayanaCoordinator.CoordinatorError.requestFailed("iOS Mini App Bot only accepts governed mcp-http execution")
            }
            let arguments = routed["arguments"] as? [String: Any] ?? [:]
            let result = try await bridge.callOfficialMcpTool(pluginId: pluginId, name: tool, arguments: arguments)
            removeThinking(operationId)
            entries.append(MobileChatMessage(
                id: "assistant:\(operationId)",
                role: .assistant,
                text: GlobalDharmaMiniAppBridge.resultText(result),
                operationId: operationId
            ))
        } catch {
            removeThinking(operationId)
            errorText = error.localizedDescription
            entries.append(MobileChatMessage(
                id: "assistant:\(operationId):error",
                role: .assistant,
                text: "Mini App 调用失败：\(error.localizedDescription)",
                operationId: operationId
            ))
        }
    }

    @MainActor
    private func stop() async {
        guard bot.miniAppId == nil, let activeOperationId else { return }
        _ = try? await bridge.request(method: "feature.interrupt", params: ["operationId": activeOperationId])
    }

    @MainActor
    private func pump(operationId: String) async {
        for _ in 0..<1800 {
            if Task.isCancelled { return }
            do {
                let result = try await bridge.request(method: "feature.receive", params: ["timeoutMs": 250])
                guard let event = result.value as? [String: Any], let type = event["type"] as? String else {
                    try? await Task.sleep(for: .milliseconds(60)); continue
                }
                let eventOperationId = event["operationId"] as? String ?? operationId
                if ["chat.message", "chat.delta", "agent.step", "operation.started", "operation.completed", "operation.interrupted", "operation.failed", "model.routed"].contains(type), eventOperationId != operationId { continue }
                switch type {
                case "chat.message":
                    guard (event["role"] as? String) != "user" else { continue }
                    removeThinking(operationId)
                    upsertAssistant(operationId, text: event["text"] as? String ?? "", append: false, streaming: false)
                case "chat.delta":
                    removeThinking(operationId)
                    upsertAssistant(operationId, text: event["delta"] as? String ?? "", append: true, streaming: true)
                case "agent.step":
                    let id = "action:\(operationId):\((event["stepId"] as? String) ?? UUID().uuidString)"
                    let row = MobileChatMessage(id: id, role: .assistant, text: "", kind: .action, operationId: operationId, actionTitle: event["title"] as? String ?? "Working", actionDetail: event["detail"] as? String, actionStatus: event["status"] as? String ?? "completed")
                    if let index = entries.firstIndex(where: { $0.id == id }) { entries[index] = row } else { entries.append(row) }
                case "model.routed":
                    let id = "action:\(operationId):model"
                    let provider = event["provider"] as? String ?? ""
                    let model = event["model"] as? String ?? ""
                    let row = MobileChatMessage(id: id, role: .assistant, text: "", kind: .action, operationId: operationId, actionTitle: "Model", actionDetail: [provider, model].filter { !$0.isEmpty }.joined(separator: " · "), actionStatus: "completed")
                    if let index = entries.firstIndex(where: { $0.id == id }) { entries[index] = row } else { entries.append(row) }
                case "operation.completed", "operation.interrupted":
                    removeThinking(operationId)
                    finishAssistant(operationId)
                    return
                case "operation.failed":
                    removeThinking(operationId)
                    finishAssistant(operationId)
                    errorText = event["message"] as? String ?? "Bot run failed"
                    return
                default:
                    break
                }
            } catch {
                errorText = error.localizedDescription
                return
            }
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    private func removeThinking(_ operationId: String) {
        entries.removeAll { $0.kind == .thinking && $0.operationId == operationId }
    }

    private func upsertAssistant(_ operationId: String, text: String, append: Bool, streaming: Bool) {
        guard !text.isEmpty else { return }
        if let index = entries.lastIndex(where: { $0.kind == .message && $0.role == .assistant && $0.operationId == operationId }) {
            entries[index].text = append ? entries[index].text + text : text
            entries[index].streaming = streaming
        } else {
            entries.append(MobileChatMessage(id: "assistant:\(operationId)", role: .assistant, text: text, operationId: operationId, streaming: streaming))
        }
    }

    private func finishAssistant(_ operationId: String) {
        for index in entries.indices where entries[index].operationId == operationId && entries[index].role == .assistant {
            entries[index].streaming = false
        }
    }
}
