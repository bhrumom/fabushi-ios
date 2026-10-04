import XCTest
@testable import Fabushi

@MainActor
private final class ClientSideToolRelayTestHost: MahayanaHostRequesting {
    var nextValue: Any = NSNull()

    func request(method: String, params: [String: Any]) async throws -> MahayanaHostJSONResult {
        MahayanaHostJSONResult(value: nextValue)
    }
}

final class ClientSideToolV2RelayParityTests: XCTestCase {
    private func callMessage(_ callID: String) -> ClientSideToolV2WireMessage {
        let id = Array(callID.utf8)
        return .init(
            messageType: "aiserver.v1.ClientSideToolV2Call",
            bytes: Data([0x1a, UInt8(id.count)] + id)
        )
    }

    private func resultMessage(_ callID: String) -> ClientSideToolV2WireMessage {
        let id = Array(callID.utf8)
        return .init(
            messageType: "aiserver.v1.ClientSideToolV2Result",
            bytes: Data([0x9a, 0x02, UInt8(id.count)] + id)
        )
    }

    @MainActor
    func testRelayFencesEpochsSequencesSettlesAndReplays() {
        let relay = ClientSideToolV2Relay()
        let call = ClientSideToolV2TransportEvent.update(
            version: 1,
            kind: .call,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-a",
            sequence: 1,
            message: callMessage("call-7")
        )
        XCTAssertEqual(relay.accept(call)?.bytes, Data([0x1a, 0x06] + Array("call-7".utf8)))
        XCTAssertNil(relay.accept(call))

        let result = ClientSideToolV2TransportEvent.update(
            version: 1,
            kind: .result,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-a",
            sequence: 2,
            message: resultMessage("call-7")
        )
        XCTAssertNotNil(relay.accept(result))
        XCTAssertEqual(relay.replay().map(\.kind), ["call", "result"])

        let nextEpoch = ClientSideToolV2TransportEvent.update(
            version: 1,
            kind: .call,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-b",
            sequence: 1,
            message: callMessage("call-8")
        )
        XCTAssertNotNil(relay.accept(nextEpoch))
        XCTAssertNil(relay.accept(.update(
            version: 1,
            kind: .result,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-a",
            sequence: 3,
            message: resultMessage("call-7")
        )))
        XCTAssertEqual(relay.replay().map(\.kind), ["call"])

        XCTAssertNotNil(relay.accept(.reset(
            version: 1,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-b",
            sequence: 2
        )))
        XCTAssertTrue(relay.replay().isEmpty)
    }

    @MainActor
    func testRelayRejectsInvalidWireAndOrphanResult() {
        let relay = ClientSideToolV2Relay()
        XCTAssertNil(relay.accept(.update(
            version: 2,
            kind: .call,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-a",
            sequence: 1,
            message: callMessage("call-1")
        )))
        XCTAssertNil(relay.accept(.update(
            version: 1,
            kind: .call,
            accountSlot: "other",
            agentId: "agent-1",
            epoch: "epoch-a",
            sequence: 1,
            message: callMessage("call-1")
        )))
        XCTAssertNil(relay.accept(.update(
            version: 1,
            kind: .result,
            accountSlot: "host",
            agentId: "agent-1",
            epoch: "epoch-a",
            sequence: 1,
            message: resultMessage("missing")
        )))
    }

    @MainActor
    func testCoordinatorProductionReceiveOwnsRelayProjection() async {
        let host = ClientSideToolRelayTestHost()
        let supervisor = MahayanaLocalHostSupervisor(host: host, factory: { host })
        let coordinator = MahayanaCoordinator(hostSupervisor: supervisor)
        var projected: [(String, CoordinatorPayload)] = []
        coordinator.setRendererEventSink { family, payload in projected.append((family, payload)) }

        let callID = Array("call-9".utf8)
        host.nextValue = [
            "channel": ClientSideToolV2Transport.family,
            "payload": [
                "version": 1,
                "kind": "call",
                "accountSlot": "host",
                "agentId": "agent-9",
                "epoch": "epoch-9",
                "sequence": 1,
                "message": [
                    "encoding": "protobuf-base64",
                    "messageType": "aiserver.v1.ClientSideToolV2Call",
                    "bytes": Data([0x1a, UInt8(callID.count)] + callID).base64EncodedString(),
                ],
            ],
        ]

        _ = await coordinator.dispatchTransport(method: "feature.receive", args: .object([:]))
        XCTAssertEqual(projected.count, 1)
        XCTAssertEqual(projected.first?.0, ClientSideToolV2Transport.family)
        guard case .object(let payload)? = projected.first?.1 else {
            return XCTFail("Coordinator must project a typed renderer event")
        }
        XCTAssertEqual(payload["agentId"], .string("agent-9"))
        XCTAssertEqual(payload["kind"], .string("call"))

        coordinator.beginShutdown()
        var replayedAfterShutdown = 0
        coordinator.setRendererEventSink { _, _ in replayedAfterShutdown += 1 }
        XCTAssertEqual(replayedAfterShutdown, 0)
    }

    @MainActor
    func testCompatibilityCallsFailClosedAndClearOnSettlement() {
        let relay = ClientSideToolV2Relay()
        XCTAssertNoThrow(try relay.begin(callID: "compat-1", toolName: "read"))
        XCTAssertThrowsError(try relay.begin(callID: "compat-1", toolName: "read"))
        let settled = try? relay.settle(callID: "compat-1", output: .string("ok"))
        XCTAssertEqual(settled?.tool, "read")
        XCTAssertEqual(settled?.output, .string("ok"))
        relay.clear()
        XCTAssertThrowsError(try relay.settle(callID: "compat-1", output: .null))
    }
}
