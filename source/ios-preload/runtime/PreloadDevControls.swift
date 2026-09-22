import Foundation

@MainActor
final class PreloadDevControlsAPI {
    private let primary: PreloadPrimaryAPI

    init(primary: PreloadPrimaryAPI) {
        self.primary = primary
    }

    func invoke(method: String, payload: CoordinatorPayload = .object([:])) async throws -> CoordinatorPayload {
        switch IOSDevControlsContract.disposition(for: method) {
        case .local:
            return try await primary.call(method: "dev.\(method)", payload: payload)
        case .remoteRunner:
            return try await primary.call(method: "remote-runner.dev.\(method)", payload: payload)
        case .unavailable(let reason):
            throw ControlPortCallError(code: "unsupported-ios-dev-control", message: reason)
        }
    }
}
