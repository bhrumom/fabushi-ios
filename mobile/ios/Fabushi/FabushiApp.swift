import SwiftUI

@main
struct FabushiApp: App {
    @State private var runtime = FabushiRuntime()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
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
        }
    }
}
