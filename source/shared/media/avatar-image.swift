import Foundation

enum AvatarImagePolicy {
    static let sourceMaxBytes = 25 * 1024 * 1024
    static func sourceSizeError(byteLength: Int) -> String? {
        byteLength > sourceMaxBytes ? "Choose an image smaller than 25 MB." : nil
    }
    static let extensionMime: [String: String] = [
        ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp",
        ".gif": "image/gif", ".bmp": "image/bmp", ".avif": "image/avif", ".svg": "image/svg+xml",
    ]
    static func mimeHint(forExtension ext: String) -> String {
        extensionMime[ext.lowercased()] ?? "application/octet-stream"
    }
}
