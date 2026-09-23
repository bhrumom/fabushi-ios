import Foundation

actor ClientSideToolV2Relay {
    enum RelayError: LocalizedError {
        case staleSequence
        case malformedMessage

        var errorDescription: String? {
            switch self {
            case .staleSequence: "client-side-tool-v2 sequence is stale"
            case .malformedMessage: "client-side-tool-v2 message is malformed"
            }
        }
    }

    private var lastSequenceByAgent: [String: UInt64] = [:]

    func accept(_ event: ClientSideToolV2TransportEvent) throws {
        let agentId: String
        switch event {
        case .update(_, _, let value, _, _, let message):
            guard message.decodedBytes != nil else { throw RelayError.malformedMessage }
            agentId = value
        case .reset(_, let value, _, _):
            agentId = value
        }
        guard !agentId.isEmpty else { throw RelayError.malformedMessage }

        let previous = lastSequenceByAgent[agentId] ?? 0
        guard event.sequence > previous else { throw RelayError.staleSequence }
        lastSequenceByAgent[agentId] = event.sequence
    }

    func reset(agentId: String) {
        lastSequenceByAgent.removeValue(forKey: agentId)
    }
}
