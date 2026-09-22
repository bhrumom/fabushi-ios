import Foundation

#if DEBUG
@MainActor
enum IOSDevControlsPreloadEntrypoint {
    static func install(bridge: IOSPreloadBridge) -> IOSDevControlsPreload {
        IOSDevControlsPreload(bridge: bridge)
    }
}
#endif
