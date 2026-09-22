import Foundation

/// Narrow renderer-facing bridge. This is the only runtime surface intended for
/// SwiftUI feature models. Host and Coordinator stay behind IOSMainRuntime.
///
/// Even though this compatibility API still accepts Foundation JSON values, it
/// crosses the runtime boundary through the same typed request/reply/cancel
/// protocol used by the Grok-shaped Coordinator architecture.
@MainActor
final class IOSPreloadBridge {
    struct JSONResult: @unchecked Sendable {
        let value: Any
    }

    private let clientPort: InProcessCoordinatorPort
    private let serverPort: InProcessCoordinatorPort
    private let server: RendererPortServer
    private let client: CoordinatorControlPortClient

    init(main: IOSMainRuntime) {
        let pair = InProcessCoordinatorPort.makePair()
        let server = main.makeRendererPortServer(port: pair.server)
        let client = CoordinatorControlPortClient(port: pair.client, autoStart: false)

        pair.server.onFrame = { [weak server] frame in
            server?.receive(frame)
        }
        pair.server.onClose = { [weak server] in
            server?.portClosed()
        }
        pair.client.onFrame = { [weak client] frame in
            client?.receive(frame)
        }
        pair.client.onClose = { [weak client] in
            client?.portClosed()
        }

        clientPort = pair.client
        serverPort = pair.server
        self.server = server
        self.client = client
        client.start()
    }

    func request(method: String, params: [String: Any] = [:]) async throws -> JSONResult {
        let payload = try CoordinatorPayload.fromFoundation(params)
        let result = try await client.call(method: method, args: payload)
        return JSONResult(value: result.foundationValue)
    }

    func shutdown() {
        client.shutdown()
    }
}
