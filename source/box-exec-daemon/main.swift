import Foundation

/// iOS adaptation of Grok box-exec-daemon. Unsupported desktop execution is
/// explicitly routed to a remote Runner instead of being simulated on-device.
@MainActor
final class RemoteRunner {
    private let bridge: IOSPreloadBridge

    init(bridge: IOSPreloadBridge) {
        self.bridge = bridge
    }

    func dispatch(method: String, params: [String: Any]) async throws -> IOSPreloadBridge.JSONResult {
        try await bridge.request(method: method, params: params)
    }
}
