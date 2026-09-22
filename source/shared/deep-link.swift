import Foundation

enum FabushiDeepLinkSource: String, Equatable, Sendable { case customProtocol, https }

enum FabushiDeepLink: Equatable, Sendable {
    case info(source: FabushiDeepLinkSource)
    case pluginAdd(pluginID: String, source: FabushiDeepLinkSource)
    case open(source: FabushiDeepLinkSource)
}

struct ParsedFabushiDeepLink: Equatable, Sendable {
    let link: FabushiDeepLink
    let canonicalURL: String
}

enum FabushiDeepLinkPolicy {
    static let scheme = "fabushi"
    static let authority = "app"
    static let httpsOriginHost = "fabushi.app"
    static let httpsPathPrefix = "/fabushi/link"
    static let maximumLength = 2_048
    static let openURL = "fabushi://app/v1/open"
    private static let infoPath = "/v1/info"
    private static let openPath = "/v1/open"

    static func canonicalURL(for link: FabushiDeepLink) -> String {
        switch link {
        case .info: "fabushi://app/v1/info?topic=deep-links"
        case .pluginAdd(let pluginID, _): FabushiDesktopPolicy.buildPluginDeepLink(pluginID: pluginID) ?? ""
        case .open: openURL
        }
    }

    static func parse(_ raw: String) -> ParsedFabushiDeepLink? {
        guard !raw.isEmpty,
              raw.utf8.count <= maximumLength,
              raw.unicodeScalars.allSatisfy({ $0.value >= 33 && $0.value <= 126 }),
              !raw.contains("#"), !raw.contains("\\"),
              hasValidPercentEncoding(raw), hasCanonicalPathSection(raw),
              let components = URLComponents(string: raw),
              components.user == nil, components.password == nil, components.port == nil,
              let rawScheme = components.scheme?.lowercased()
        else { return nil }

        let source: FabushiDeepLinkSource
        let path: String
        if rawScheme == scheme {
            guard components.host?.lowercased() == authority else { return nil }
            source = .customProtocol
            path = components.path
        } else if rawScheme == "https" {
            guard components.host?.lowercased() == httpsOriginHost,
                  components.path.hasPrefix(httpsPathPrefix)
            else { return nil }
            source = .https
            path = String(components.path.dropFirst(httpsPathPrefix.count))
        } else { return nil }

        let link: FabushiDeepLink
        switch path {
        case FabushiDesktopPolicy.pluginDeepLinkPath:
            guard let query = exactQuery(components, allowed: ["id": nil]),
                  let pluginID = query["id"],
                  FabushiDesktopPolicy.isDeepLinkPluginID(pluginID)
            else { return nil }
            link = .pluginAdd(pluginID: pluginID, source: source)
        case openPath:
            guard exactQuery(components, allowed: [:]) != nil else { return nil }
            link = .open(source: source)
        case infoPath:
            guard let query = exactQuery(components, allowed: ["topic": "deep-links"]),
                  query["topic"] == "deep-links"
            else { return nil }
            link = .info(source: source)
        default: return nil
        }
        return .init(link: link, canonicalURL: canonicalURL(for: link))
    }

    private static func exactQuery(_ components: URLComponents, allowed: [String: String?]) -> [String: String]? {
        let items = components.queryItems ?? []
        guard items.count == allowed.count else { return nil }
        var result: [String: String] = [:]
        for item in items {
            guard result[item.name] == nil, allowed.keys.contains(item.name), let value = item.value else { return nil }
            if let required = allowed[item.name] ?? nil, required != value { return nil }
            result[item.name] = value
        }
        return result
    }

    private static func hasValidPercentEncoding(_ value: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "%(?![0-9A-Fa-f]{2})") else { return false }
        return regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) == nil
    }

    private static func hasCanonicalPathSection(_ raw: String) -> Bool {
        let beforeQuery = raw.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? raw
        guard !beforeQuery.contains("%"),
              let regex = try? NSRegularExpression(pattern: #"/\.{1,2}(?:/|$)"#)
        else { return false }
        return regex.firstMatch(in: beforeQuery, range: NSRange(beforeQuery.startIndex..., in: beforeQuery)) == nil
    }
}
