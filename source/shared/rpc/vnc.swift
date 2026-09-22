import Foundation

enum RemoteComputerMethod: String, Codable, CaseIterable, Sendable {
    case readClipboard
    case writeClipboard
    case reportUserPresence
}

struct RemoteClipboardWriteRequest: Codable, Equatable, Sendable {
    let text: String
}

struct RemoteUserPresenceRequest: Codable, Equatable, Sendable {
    let active: Bool
    let timestampMilliseconds: Int64
}
