import Foundation

enum SandText {
    static func clampLine(_ raw: String, maxLength: Int) -> String {
        let collapsed = raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(max(0, maxLength)))
    }

    static func clampBlock(_ raw: String, maxLength: Int) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max(0, maxLength)))
    }

    static func decapitalize(_ phrase: String) -> String {
        guard let first = phrase.first else { return phrase }
        return first.lowercased() + phrase.dropFirst()
    }

    static func slugifyName(_ name: String, fallbackPrefix: String, nowMilliseconds: Int64) -> String {
        let lower = name.lowercased()
        let replaced = lower.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
        let trimmed = replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let slug = String(trimmed.prefix(48))
        return slug.isEmpty ? "\(fallbackPrefix)-\(nowMilliseconds)" : slug
    }
}
