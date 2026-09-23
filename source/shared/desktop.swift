import Foundation

enum FabushiThemePreference: String, CaseIterable, Sendable { case system, light, dark }

enum FabushiDesktopPolicy {
    static let defaultTheme: FabushiThemePreference = .system
    static let pluginDeepLinkPath = "/v1/plugin/add"

    static func isThemePreference(_ value: String) -> Bool { FabushiThemePreference(rawValue: value) != nil }

    static func isDeepLinkPluginID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 19 else { return false }
        return value.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    static func buildPluginDeepLink(pluginID: String) -> String? {
        guard isDeepLinkPluginID(pluginID) else { return nil }
        var components = URLComponents()
        components.scheme = "fabushi"
        components.host = "app"
        components.path = pluginDeepLinkPath
        components.queryItems = [URLQueryItem(name: "id", value: pluginID)]
        return components.string
    }
}
