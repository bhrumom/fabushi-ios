import Foundation

@MainActor
final class InProcessCoordinatorPort: CoordinatorPort {
    weak var peer: InProcessCoordinatorPort?

    var onFrame: ((CoordinatorFrame) -> Void)? {
        didSet { flushPendingFrames() }
    }
    var onClose: (() -> Void)?

    private var pendingFrames: [CoordinatorFrame] = []
    private(set) var isClosed = false

    func post(_ frame: CoordinatorFrame) {
        guard !isClosed, let peer, !peer.isClosed else { return }
        peer.receive(frame)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        pendingFrames.removeAll()
        onClose?()
        peer?.peerClosed()
    }

    private func receive(_ frame: CoordinatorFrame) {
        guard !isClosed else { return }
        guard let onFrame else {
            pendingFrames.append(frame)
            return
        }
        onFrame(frame)
    }

    private func flushPendingFrames() {
        guard let onFrame, !pendingFrames.isEmpty, !isClosed else { return }
        let queued = pendingFrames
        pendingFrames.removeAll(keepingCapacity: true)
        queued.forEach(onFrame)
    }

    private func peerClosed() {
        guard !isClosed else { return }
        isClosed = true
        pendingFrames.removeAll()
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
