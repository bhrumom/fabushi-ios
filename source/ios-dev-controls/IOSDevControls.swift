import Foundation

#if DEBUG
@MainActor
final class IOSDevControls {
    private let main: IOSMainRuntime

    init(main: IOSMainRuntime) {
        self.main = main
    }

    func setGatewayOffline(_ offline: Bool) async throws {
        _ = try await main.dispatch(
            method: "dev.gateway.offline",
            params: ["offline": offline]
        )
    }
}
#endif
