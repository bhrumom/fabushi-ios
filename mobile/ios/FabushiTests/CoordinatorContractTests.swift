import XCTest
@testable import Fabushi

@MainActor
private final class TestCoordinatorPort: CoordinatorPort {
    var frames: [CoordinatorFrame] = []
    var closed = false

    func post(_ frame: CoordinatorFrame) {
        frames.append(frame)
    }

    func close() {
        closed = true
    }
}

final class CoordinatorContractTests: XCTestCase {
    func testCoordinatorFrameRoundTripsReferenceWireShape() throws {
        let frame = CoordinatorFrame.request(
            requestId: "r-1",
            method: "sendPrompt",
            args: .object(["text": .string("hello"), "stream": .bool(true)])
        )
        let data = try JSONEncoder().encode(frame)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["kind"] as? String, "request")
        XCTAssertEqual(object["requestId"] as? String, "r-1")
        XCTAssertEqual(object["method"] as? String, "sendPrompt")
        XCTAssertEqual(try JSONDecoder().decode(CoordinatorFrame.self, from: data), frame)
    }

    func testMalformedRequestWithoutArgsIsRejected() throws {
        let data = #"{"kind":"request","requestId":"r-1","method":"sendPrompt"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(CoordinatorFrame.self, from: data))
    }

    @MainActor
    func testRendererPortRequiresHelloBeforeRequest() {
        let port = TestCoordinatorPort()
        let server = RendererPortServer(port: port) { _, _ in .ok(.null) }

        server.receive(.request(requestId: "r-1", method: "sendPrompt", args: .object([:])))

        XCTAssertEqual(server.phase, .settled)
        XCTAssertTrue(port.closed)
        guard case .shutdown(reason: .protocolError, detail: let detail)? = port.frames.last else {
            return XCTFail("expected protocol-error shutdown")
        }
        XCTAssertTrue(detail?.contains("before hello") == true)
    }

    @MainActor
    func testRendererPortHandshakeAndCancellationSettleDeterministically() async {
        let port = TestCoordinatorPort()
        let server = RendererPortServer(port: port) { _, _ in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            return .ok(.string("late"))
        }

        server.receive(.hello(protocolVersion: CoordinatorProtocol.version))
        XCTAssertEqual(port.frames.first, .ready(protocolVersion: CoordinatorProtocol.version))

        server.receive(.request(requestId: "r-2", method: "sendPrompt", args: .object([:])))
        server.receive(.cancel(requestId: "r-2"))

        XCTAssertTrue(port.frames.contains(.reply(
            requestId: "r-2",
            outcome: .failed(.init(code: CoordinatorProtocol.cancelled, message: "request cancelled"))
        )))
        XCTAssertEqual(server.phase, .serving)
    }

    @MainActor
    func testInProcessCarrierProvidesHandshakeAndRequestReply() async throws {
        let pair = InProcessCoordinatorPort.makePair()
        let server = RendererPortServer(port: pair.server) { method, args in
            .ok(.object(["method": .string(method), "args": args]))
        }
        let client = CoordinatorControlPortClient(port: pair.client, autoStart: false)

        pair.server.onFrame = { [weak server] frame in server?.receive(frame) }
        pair.server.onClose = { [weak server] in server?.portClosed() }
        pair.client.onFrame = { [weak client] frame in client?.receive(frame) }
        pair.client.onClose = { [weak client] in client?.portClosed() }

        client.start()
        XCTAssertTrue(client.readyObserved)

        let response = try await client.call(
            method: "sendPrompt",
            args: .object(["text": .string("hello")])
        )
        XCTAssertEqual(
            response,
            .object([
                "method": .string("sendPrompt"),
                "args": .object(["text": .string("hello")]),
            ])
        )
    }

    @MainActor
    func testIOSPreloadPortClientUsesRendererCoordinatorBoundary() async throws {
        let pair = InProcessCoordinatorPort.makePair()
        let server = RendererPortServer(port: pair.server) { method, args in
            .ok(.object([
                "method": .string(method),
                "args": args,
            ]))
        }

        pair.server.onFrame = { [weak server] frame in
            server?.receive(frame)
        }
        pair.server.onClose = { [weak server] in
            server?.portClosed()
        }

        let client = IOSCoordinatorPortClient(port: pair.client)
        XCTAssertTrue(client.readyObserved)

        let response = try await client.request(
            method: "feature.auth.status",
            args: .object(["refresh": .bool(true)])
        )
        XCTAssertEqual(
            response,
            .object([
                "method": .string("feature.auth.status"),
                "args": .object(["refresh": .bool(true)]),
            ])
        )

        client.shutdown()
        XCTAssertEqual(client.settlement, .shutdownRequested)
    }

    func testSSEDecoderPreservesEventDataBoundaries() {
        var decoder = SSEBlockDecoder()
        XCTAssertEqual(decoder.append("event: transcript\nid: 7\ndata: one\n"), [])
        XCTAssertEqual(
            decoder.append("data: two\n\n"),
            [.init(event: "transcript", id: "7", data: "one\ntwo")]
        )
    }
}
