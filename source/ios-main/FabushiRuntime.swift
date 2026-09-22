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
            let bridge = IOSPreloadBridge(main: main)
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
    }

    func loginStateChanged(_ loggedIn: Bool) async {
        await remoteDeviceGateway.setLoggedIn(loggedIn)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        main.scenePhaseChanged(phase)
    }

    func handleOpenURL(_ url: URL) {
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
            guard let agentId = parts.first, !agentId.isEmpty, agentId.count <= 200 else { return }
            marketplace.message = "已接收智能体链接：\(agentId)"
        case "settings", "feedback", "about", "widgets", "onboarding":
            marketplace.message = "已接收应用链接：\(host)"
        default:
            return
        }
    }
}
