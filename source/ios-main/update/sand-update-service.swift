import Foundation

/// App Store/TestFlight counterpart of Grok's desktop self-update service.
///
/// iOS applications cannot replace their own bundle. This service preserves the
/// renderer-visible update state while making the store-owned mechanism
/// explicit and refusing desktop-only apply operations.
@MainActor
final class IOSAppStoreUpdateService {
    enum ServiceError: LocalizedError, Equatable {
        case releaseMetadataUnavailable

        var errorDescription: String? {
            "The signed iOS bundle has no valid release metadata."
        }
    }

    private let metadataProvider: @MainActor () -> IOSReleaseMetadata?

    init(metadataProvider: @escaping @MainActor () -> IOSReleaseMetadata? = {
        IOSReleaseMetadataReader.read()
    }) {
        self.metadataProvider = metadataProvider
    }

    func statusPayload() throws -> CoordinatorPayload {
        guard let metadata = metadataProvider() else {
            throw ServiceError.releaseMetadataUnavailable
        }
        return .object([
            "type": .string("managed-by-app-store"),
            "version": .string(metadata.version),
            "buildNumber": .string(metadata.buildNumber),
            "bundleIdentifier": .string(metadata.bundleIdentifier),
            "mechanism": .string(metadata.updateMechanism),
            "selfUpdateSupported": .bool(false),
        ])
    }

    func unsupportedActionPayload(_ action: String) -> CoordinatorPayload {
        .object([
            "accepted": .bool(false),
            "action": .string(action),
            "reason": .string("managed-by-app-store"),
            "selfUpdateSupported": .bool(false),
        ])
    }
}
