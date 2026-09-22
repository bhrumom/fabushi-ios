import Foundation

@MainActor
final class InProcessCoordinatorPort: CoordinatorPort {
    weak var peer: InProcessCoordinatorPort?
    var onFrame: ((CoordinatorFrame) -> Void)?
    var onClose: (() -> Void)?

    private(set) var isClosed = false

    func post(_ frame: CoordinatorFrame) {
        guard !isClosed, let peer, !peer.isClosed else { return }
        peer.onFrame?(frame)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        onClose?()
        peer?.peerClosed()
    }

    private func peerClosed() {
        guard !isClosed else { return }
        isClosed = true
        onClose?()
    }

    static func makePair() -> (client: InProcessCoordinatorPort, server: InProcessCoordinatorPort) {
        let client = InProcessCoordinatorPort()
        let server = InProcessCoordinatorPort()
        client.peer = server
        server.peer = client
        return (client, server)
    }
}
