import Foundation

enum ExternalURLPolicy {
    static let allowedSchemes: Set<String> = ["http", "https", "mailto", "obsidian", "tel"]

    static func parseAllowed(_ value: String) -> String? {
        guard !value.isEmpty,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              allowedSchemes.contains(scheme),
              let url = components.url
        else { return nil }
        return url.absoluteString
    }

    static func isHTTP(_ value: String) -> Bool {
        guard let scheme = URLComponents(string: value)?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
