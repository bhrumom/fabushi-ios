import Foundation

/// Narrow renderer-facing bridge. This is the only runtime surface intended for
/// SwiftUI feature models. Host and Coordinator stay behind IOSMainRuntime.
@MainActor
final class IOSPreloadBridge {
    struct JSONResult: @unchecked Sendable {
        let value: Any
    }

    private let main: IOSMainRuntime

    init(main: IOSMainRuntime) {
        self.main = main
    }

    func request(method: String, params: [String: Any] = [:]) async throws -> JSONResult {
        let result = try await main.dispatch(method: method, params: params)
        return JSONResult(value: result.value)
    }
}
