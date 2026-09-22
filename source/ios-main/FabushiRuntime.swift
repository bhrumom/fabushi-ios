import Foundation
import Observation
import SwiftUI

/// Production composition root. FabushiApp only owns Scene/App lifecycle and
/// forwards events here.
@MainActor
@Observable
final class FabushiRuntime {
    let main: IOSMainRuntime
    let bridge: IOSPreloadBridge
    let appAgentSurface: FabushiAppAgentSurface
    let remoteDeviceGateway: FabushiRemoteDeviceGateway
    let marketplace: MarketplaceModel
    let messaging: MessagingModel

    @ObservationIgnored private var deepLinkController: IOSDeepLinkController?
    @ObservationIgnored private var wasBackgrounded = false
    @ObservationIgnored private var resumeTask: Task<Void, Never>?

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.ombhrum.fabushi", isDirectory: true)
        #if DEBUG
        let featureHostTest = ProcessInfo.processInfo.environment["FABUSHI_FEATURE_HOST_SMOKE"] == "1"
            || ProcessInfo.processInfo.environment["FABUSHI_FEATURE_HOST_TEST"] == "1"
        #else
        let featureHostTest = false
        #endif

        do {
            let main = try IOSMainRuntime(appDataDirectory: base, featureHostTest: featureHostTest)
            let bridge = IOSPrimaryPreloadEntrypoint.install(main: main)
            let surface = FabushiAppAgentSurface()
            self.main = main
            self.bridge = bridge
            appAgentSurface = surface
            marketplace = MarketplaceModel(bridge: bridge)
            messaging = MessagingModel(bridge: bridge)
            remoteDeviceGateway = FabushiRemoteDeviceGateway(
                bridge: bridge,
                surface: surface,
                traceURL: base.appendingPathComponent("device-gateway-trace.jsonl")
            )
            deepLinkController = IOSDeepLinkController(
                dispatch: { [weak self] parsed in
                    self?.dispatchGrokDeepLink(parsed)
                }
            )
        } catch {
            fatalError("Failed to initialize iOS runtime: \(error)")
        }
    }

    func start() async {
        await marketplace.runFeatureHostSmokeIfRequested()
        await marketplace.initializeApp()
        await remoteDeviceGateway.setLoggedIn(marketplace.loggedIn)
        if marketplace.loggedIn {
            await messaging.refresh()
        }
        deepLinkController?.markReady()
        if main.requiresColdStartResync {
            await resyncAfterLifecycleRecovery(reason: "cold-start")
        } else {
            main.markResyncCompleted()
        }
    }

    func loginStateChanged(_ loggedIn: Bool) async {
        await remoteDeviceGateway.setLoggedIn(loggedIn)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        main.scenePhaseChanged(phase)
        switch phase {
        case .background:
            wasBackgrounded = true
        case .active where wasBackgrounded:
            wasBackgrounded = false
            resumeTask?.cancel()
            resumeTask = Task { [weak self] in
                await self?.resyncAfterLifecycleRecovery(reason: "background-resume")
            }
        default:
            break
        }
    }

    func handleOpenURL(_ url: URL) {
        if deepLinkController?.handleCandidate(
            url.absoluteString,
            origin: "scene-open-url"
        ) == true {
            return
        }

        // Product auth/navigation callbacks predate Grok's app/info/plugin-add
        // deep-link family and stay fail-closed behind their existing validators.
        guard url.scheme?.lowercased() == "fabushi",
              url.user == nil,
              url.password == nil,
              url.port == nil
        else { return }

        let host = url.host?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        switch host {
        case "auth":
            marketplace.handleDeepLink(url)
        case "agent":
            guard let agentId = parts.first,
                  !agentId.isEmpty,
                  agentId.count <= 200,
                  agentId.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil
            else { return }
            marketplace.message = "已接收智能体链接：\(agentId)"
        case "settings", "feedback", "about", "widgets", "onboarding":
            guard parts.isEmpty else { return }
            marketplace.message = "已接收应用链接：\(host)"
        default:
            return
        }
    }

    private func dispatchGrokDeepLink(_ parsed: ParsedFabushiDeepLink) {
        switch parsed.link {
        case .info:
            marketplace.message = "Deep Link 支持已就绪"
        case .open:
            marketplace.message = "已通过 Deep Link 打开 Fabushi"
        case .pluginAdd(let pluginID, _):
            marketplace.query = pluginID
            Task { [weak self] in
                await self?.marketplace.refresh()
            }
        }
    }

    private func resyncAfterLifecycleRecovery(reason: String) async {
        await marketplace.refresh()
        await remoteDeviceGateway.resumeAfterBackground()
        if marketplace.loggedIn {
            await messaging.refresh()
        }
        main.markResyncCompleted()
        main.lifecycleReporter.report(
            .coordinatorHandoff,
            metadata: [
                "resync_reason": reason,
                "result": "completed",
            ]
        )
    }
}
