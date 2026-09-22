import Foundation

#if DEBUG
@MainActor
final class IOSDevControlsPreload {
    private let bridge: IOSPreloadBridge

    init(bridge: IOSPreloadBridge) {
        self.bridge = bridge
    }

    func setGatewayOffline(_ offline: Bool) async throws {
        _ = try await bridge.request(
            method: "dev.gateway.offline",
            params: ["offline": offline]
        )
    }
}
#endif
