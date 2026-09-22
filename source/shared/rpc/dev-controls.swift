import Foundation

enum IOSDevControlDisposition: Equatable, Sendable {
    case local
    case remoteRunner
    case unavailable(reason: String)
}

enum IOSDevControlsContract {
    static func disposition(for method: String) -> IOSDevControlDisposition {
        switch method {
        case "restartOnboarding", "skipOnboarding", "themeStatus", "setThemePreference",
             "gatewayOfflineStatus", "setGatewayOffline":
            return .local
        case "boxStatus", "boxHealth", "upgradeHost", "pokeHostUpgrade", "rebuildBox",
             "tailLogs", "startBox", "teardownBox", "nukeBox", "openDesktop",
             "boxStoreStatus", "boxStoreSnapshotNow", "boxStoreLogs", "boxStoreRecreateFresh",
             "boxStoreClear", "attachProdBoxStatus", "setAttachProdBoxEnabled":
            return .remoteRunner
        case "restartElectron", "reloadWindow":
            return .unavailable(reason: "Electron process/window controls do not exist on iOS")
        default:
            return .unavailable(reason: "Unknown or unsupported iOS developer control")
        }
    }
}
