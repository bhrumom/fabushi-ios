import XCTest
@testable import Fabushi

final class DevControlsParityTests: XCTestCase {
    func testDevCapabilityRequiresDebugBuildAndExplicitOptIn() {
        XCTAssertEqual(
            IOSDevCapability.resolve(
                isDebugBuild: true,
                environment: [IOSDevCapability.environmentKey: "1"]
            ).preloadKind,
            .devControls
        )
        XCTAssertEqual(
            IOSDevCapability.resolve(
                isDebugBuild: false,
                environment: [IOSDevCapability.environmentKey: "1"]
            ).preloadKind,
            .primary
        )
        XCTAssertEqual(
            IOSDevCapability.resolve(
                isDebugBuild: true,
                environment: [:]
            ).preloadKind,
            .primary
        )
    }

    func testDevControlsGateFailsClosedWhenDisabled() {
        let gate = IOSDevControlsGate(enabled: false)
        XCTAssertThrowsError(try gate.requireEnabled()) { error in
            XCTAssertEqual(error as? IOSDevControlsGateError, .disabled)
        }
    }

    @MainActor
    func testGatewayOfflineBlocksProductionRequestBeforeLatency() async throws {
        var sleptNanoseconds: UInt64?
        let offline = IOSDevGatewayOfflineControl()
        let latency = IOSDevNetworkLatency { nanoseconds in
            sleptNanoseconds = nanoseconds
        }
        _ = latency.setMilliseconds(25)
        let adapter = IOSNativeDevControlAdapter(
            gate: IOSDevControlsGate(enabled: true),
            gatewayOffline: offline,
            networkLatency: latency
        )

        _ = try await adapter.route(
            method: "dev.setGatewayOffline",
            params: ["induced": true]
        )

        do {
            try await adapter.beforeProductionRequest()
            XCTFail("offline developer control must fail before Host dispatch")
        } catch let error as IOSDevGatewayOfflineError {
            XCTAssertEqual(error, .induced)
        }
        XCTAssertNil(sleptNanoseconds)

        _ = try await adapter.route(
            method: "dev.setGatewayOffline",
            params: ["induced": false]
        )
        try await adapter.beforeProductionRequest()
        XCTAssertEqual(sleptNanoseconds, 25_000_000)
    }

    @MainActor
    func testNetworkLatencyClampsToReferenceMaximum() async throws {
        var sleptNanoseconds: UInt64?
        let latency = IOSDevNetworkLatency { nanoseconds in
            sleptNanoseconds = nanoseconds
        }
        let adapter = IOSNativeDevControlAdapter(
            gate: IOSDevControlsGate(enabled: true),
            networkLatency: latency
        )

        let routed = try await adapter.route(
            method: "dev.setNetworkLatency",
            params: ["ms": 50_000]
        )
        guard case .handled(let value) = routed,
              let object = value as? [String: Any],
              let milliseconds = object["ms"] as? Int else {
            return XCTFail("expected handled latency result")
        }
        XCTAssertEqual(milliseconds, IOSDevNetworkLatency.maximumMilliseconds)

        try await adapter.beforeProductionRequest()
        XCTAssertEqual(sleptNanoseconds, 10_000_000_000)
    }

    @MainActor
    func testGatewayOfflineStateSurvivesCoordinatorPortRelaunch() async throws {
        let offline = IOSDevGatewayOfflineControl()
        let adapter = IOSNativeDevControlAdapter(
            gate: IOSDevControlsGate(enabled: true),
            gatewayOffline: offline
        )
        _ = try await adapter.route(
            method: "dev.setGatewayOffline",
            params: ["offline": true]
        )
        adapter.coordinatorDidLaunch()
        XCTAssertTrue(offline.isInduced)
        XCTAssertTrue(offline.reapplyAfterCoordinatorLaunch())
    }

    func testPreloadContractKeepsNativeNetworkControlsLocal() {
        XCTAssertEqual(IOSDevControlsContract.disposition(for: "setGatewayOffline"), .local)
        XCTAssertEqual(IOSDevControlsContract.disposition(for: "gatewayOfflineStatus"), .local)
        XCTAssertEqual(IOSDevControlsContract.disposition(for: "setNetworkLatency"), .local)
        XCTAssertEqual(IOSDevControlsContract.disposition(for: "networkLatencyStatus"), .local)
    }
}
