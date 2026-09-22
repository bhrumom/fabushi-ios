import SwiftUI
import Combine
import UIKit

/// Scene-facing adapter for the iOS product runtime.
///
/// This view owns only the SwiftUI-to-platform lifecycle forwarding needed by
/// the application scene. Product orchestration remains in FabushiRuntime and
/// lower layers; FabushiApp stays a thin App/Scene entry point.
@MainActor
internal struct FabushiSceneRoot: View {
    @State private var runtime = FabushiRuntime()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ProductionRenderer(
            model: runtime.marketplace,
            messaging: runtime.messaging,
            bridge: runtime.bridge,
            appAgentSurface: runtime.appAgentSurface
        )
        .task {
            await runtime.start()
        }
        .onChange(of: runtime.marketplace.loggedIn) { _, loggedIn in
            Task { await runtime.loginStateChanged(loggedIn) }
        }
        .onChange(of: scenePhase) { _, phase in
            runtime.scenePhaseChanged(phase)
        }
        .onOpenURL { url in
            runtime.handleOpenURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            runtime.handleOpenURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataWillBecomeUnavailableNotification
        )) { _ in
            runtime.protectedDataWillBecomeUnavailable()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.protectedDataDidBecomeAvailableNotification
        )) { _ in
            Task { await runtime.protectedDataDidBecomeAvailable() }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )) { _ in
            runtime.memoryPressureReceived()
        }
    }
}
