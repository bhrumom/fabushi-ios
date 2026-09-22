import Foundation

enum ClientSideToolV2Transport {
    static let family = "client-side-tool-v2"
    static let wireVersion = 1
    static let accountSlot = "host"
}

enum ClientSideToolV2MessageKind: String, Codable, Sendable {
    case call
    case result
}

struct ClientSideToolV2WireMessage: Codable, Equatable, Sendable {
    let encoding: String
    let messageType: String
    let bytes: String

    init(messageType: String, bytes: Data) {
        encoding = "protobuf-base64"
        self.messageType = messageType
        self.bytes = bytes.base64EncodedString()
    }

    var decodedBytes: Data? {
        guard encoding == "protobuf-base64",
              let data = Data(base64Encoded: bytes),
              data.base64EncodedString() == bytes
        else { return nil }
        return data
    }
}

enum ClientSideToolV2TransportEvent: Equatable, Sendable {
    case update(
        kind: ClientSideToolV2MessageKind,
        accountSlot: String,
        agentId: String,
        epoch: String,
        sequence: UInt64,
        message: ClientSideToolV2WireMessage
    )
    case reset(accountSlot: String, agentId: String, epoch: String, sequence: UInt64)

    var sequence: UInt64 {
        switch self {
        case .update(_, _, _, _, let sequence, _), .reset(_, _, _, let sequence):
            sequence
        }
    }
}
