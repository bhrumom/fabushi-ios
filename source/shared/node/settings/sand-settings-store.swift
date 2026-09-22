import Foundation

let SETTINGS_VERSION = 1
let SAND_DOWNGRADE_MAX_FAST_MIGRATION_ID = "downgrade-persisted-max-fast"
let SAND_SETTINGS_MIGRATION_IDS = [SAND_DOWNGRADE_MAX_FAST_MIGRATION_ID]

indirect enum SandStoredJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([SandStoredJSONValue])
    case object([String: SandStoredJSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([SandStoredJSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: SandStoredJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

struct SandStoredAutoReviewInstructions: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var allowInstructions: [String]
    var blockInstructions: [String]
}

struct SandStoredSidebarSection: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var agentIDs: [String]
    var isCollapsed: Bool?
}

struct SandStoredSettings: Codable, Equatable, Sendable {
    var version: Int
    var mcpBoxServers: [String]
    var autoUpdateWhenIdleOptIn: Bool
    var egressTunnelEnabled: Bool
    var webauthnProxyEnabled: Bool
    var mcpCustomInstructions: [String: String]
    var mcpCustomInstructionsByServerId: [String: String]
    var mcpDisabledToolsByServerId: [String: [String]]
    var conciergeConsent: String
    var settingsMigrations: [String]

    var hasSeenOnboarding: Bool?
    var hasSeenOnboardingAccountScope: String?
    var updateTrackOverride: String?
    var themePreference: String?
    var agentDefaultModel: SandAgentModelSelection?
    var computerUseModel: SandAgentModelSelection?
    var notifications: [String: SandStoredJSONValue]?
    var userTimeZone: String?
    var userTimeZoneOverride: String?
    var autoReviewInstructions: SandStoredAutoReviewInstructions?
    var localToolPermission: String?
    var localToolPermissionCeiling: String?
    var inferenceProvider: SandInferenceProvider?
    var inferenceRouterUsage: SandInferenceRouterUsage?
    var boxRuntime: SandBoxRuntime?
    var mcpCustomInstructionsAccountScope: String?
    var pinnedAgentIds: [String]?
    var sidebarSections: [SandStoredSidebarSection]?
}

func emptySandSettings() -> SandStoredSettings {
    .init(
        version: SETTINGS_VERSION,
        mcpBoxServers: [],
        autoUpdateWhenIdleOptIn: false,
        egressTunnelEnabled: false,
        webauthnProxyEnabled: true,
        mcpCustomInstructions: [:],
        mcpCustomInstructionsByServerId: [:],
        mcpDisabledToolsByServerId: [:],
        conciergeConsent: "unset",
        settingsMigrations: SAND_SETTINGS_MIGRATION_IDS
    )
}

private func uniqueNonEmpty(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { !$0.isEmpty && seen.insert($0).inserted }
}

private func validServerID(_ value: String) -> Bool {
    guard let first = value.first, first != "0", first.isNumber else { return false }
    return value.allSatisfy(\.isNumber)
}

private func normalizeStoredSettings(_ decoded: SandStoredSettings) -> SandStoredSettings? {
    guard decoded.version == SETTINGS_VERSION else { return nil }
    var value = decoded
    value.mcpBoxServers = uniqueNonEmpty(value.mcpBoxServers)
    value.conciergeConsent = ["unset", "allowed", "denied"].contains(value.conciergeConsent)
        ? value.conciergeConsent : "unset"
    value.settingsMigrations = uniqueNonEmpty(value.settingsMigrations)
    value.mcpCustomInstructions = value.mcpCustomInstructions.reduce(into: [:]) { result, pair in
        let clamped = clampMcpCustomInstruction(pair.value)
        if !clamped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !getDefaultMcpCustomInstruction(pair.key).isEmpty {
            result[pair.key] = clamped
        }
    }
    value.mcpCustomInstructionsByServerId = value.mcpCustomInstructionsByServerId.reduce(into: [:]) { result, pair in
        if validServerID(pair.key) {
            result[pair.key] = clampMcpCustomInstruction(pair.value)
        }
    }
    value.mcpDisabledToolsByServerId = value.mcpDisabledToolsByServerId.reduce(into: [:]) { result, pair in
        guard validServerID(pair.key) else { return }
        let tools = uniqueNonEmpty(pair.value)
        if !tools.isEmpty { result[pair.key] = tools }
    }
    if let raw = value.updateTrackOverride,
       UpdateTrackPolicy.managedTrack(raw) == nil {
        value.updateTrackOverride = nil
    }
    if let raw = value.themePreference,
       FabushiThemePreference(rawValue: raw) == nil {
        value.themePreference = nil
    }
    if let raw = value.localToolPermission,
       !isSandLocalToolPermission(raw) {
        value.localToolPermission = nil
    }
    if let raw = value.localToolPermissionCeiling,
       !isSandLocalToolPermission(raw) {
        value.localToolPermissionCeiling = nil
    }
    value.pinnedAgentIds = value.pinnedAgentIds.map(uniqueNonEmpty)
    value.sidebarSections = value.sidebarSections?.filter {
        !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    for keyPath in [\SandStoredSettings.userTimeZone, \.userTimeZoneOverride, \.mcpCustomInstructionsAccountScope] {
        if let raw = value[keyPath: keyPath]?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty {
            value[keyPath: keyPath] = nil
        }
    }
    return value
}

private func downgradePersistedFast(_ model: SandAgentModelSelection) -> SandAgentModelSelection {
    .init(
        modelId: model.modelId,
        maxMode: true,
        parameters: model.parameters.map {
            .init(id: $0.id, value: $0.id == "fast" ? "false" : $0.value)
        }
    )
}

final class SandSettingsStore: @unchecked Sendable {
    let settingsPath: String
    private let lock = NSLock()

    init(settingsPath: String) {
        self.settingsPath = settingsPath
    }

    func load() -> SandStoredSettings {
        lock.lock()
        defer { lock.unlock() }
        return loadLocked()
    }

    private func loadLocked() -> SandStoredSettings {
        guard FileManager.default.fileExists(atPath: settingsPath) else { return emptySandSettings() }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
            guard let parsed = normalizeStoredSettings(try JSONDecoder().decode(SandStoredSettings.self, from: data)) else {
                return emptySandSettings()
            }
            return applyPendingMigrationsLocked(parsed)
        } catch {
            return emptySandSettings()
        }
    }

    private func applyPendingMigrationsLocked(_ settings: SandStoredSettings) -> SandStoredSettings {
        guard !settings.settingsMigrations.contains(SAND_DOWNGRADE_MAX_FAST_MIGRATION_ID) else {
            return settings
        }
        var migrated = settings
        migrated.settingsMigrations.append(SAND_DOWNGRADE_MAX_FAST_MIGRATION_ID)
        if let model = migrated.agentDefaultModel {
            migrated.agentDefaultModel = downgradePersistedFast(model)
        }
        try? persistLocked(migrated)
        return migrated
    }

    func persist(_ settings: SandStoredSettings) throws {
        lock.lock()
        defer { lock.unlock() }
        try persistLocked(settings)
    }

    private func persistLocked(_ settings: SandStoredSettings) throws {
        guard let normalized = normalizeStoredSettings(settings) else {
            throw CocoaError(.coderInvalidValue)
        }
        let data = try JSONEncoder().encode(normalized)
        try writeFileAtomic(targetPath: settingsPath, data: data)
    }

    private func update(_ mutation: (inout SandStoredSettings) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var current = loadLocked()
        mutation(&current)
        try? persistLocked(current)
    }

    func getHasSeenOnboarding() -> Bool? { load().hasSeenOnboarding }

    func setHasSeenOnboarding(_ value: Bool) {
        update {
            $0.hasSeenOnboarding = value
            $0.hasSeenOnboardingAccountScope = $0.mcpCustomInstructionsAccountScope
        }
    }

    func clearHasSeenOnboarding() {
        update {
            $0.hasSeenOnboarding = nil
            $0.hasSeenOnboardingAccountScope = nil
        }
    }

    func getAutoUpdateWhenIdleOptIn() -> Bool { load().autoUpdateWhenIdleOptIn }
    func setAutoUpdateWhenIdleOptIn(_ value: Bool) { update { $0.autoUpdateWhenIdleOptIn = value } }

    func getThemePreference() -> FabushiThemePreference {
        load().themePreference.flatMap(FabushiThemePreference.init(rawValue:)) ?? FabushiDesktopPolicy.defaultTheme
    }

    func setThemePreference(_ value: FabushiThemePreference) {
        update { $0.themePreference = value.rawValue }
    }

    func getBoxRuntime() -> SandBoxRuntime { load().boxRuntime ?? DEFAULT_SAND_BOX_RUNTIME }
    func setBoxRuntime(_ value: SandBoxRuntime) { update { $0.boxRuntime = value } }

    func getEgressTunnelEnabled() -> Bool { load().egressTunnelEnabled }
    func setEgressTunnelEnabled(_ value: Bool) { update { $0.egressTunnelEnabled = value } }

    func getWebauthnProxyEnabled() -> Bool { load().webauthnProxyEnabled }
    func setWebauthnProxyEnabled(_ value: Bool) { update { $0.webauthnProxyEnabled = value } }

    func getAgentDefaultModel() -> SandAgentModelSelection? {
        guard let model = load().agentDefaultModel else { return nil }
        return .init(modelId: model.modelId, maxMode: true, parameters: model.parameters)
    }

    func setAgentDefaultModel(_ model: SandAgentModelSelection?) {
        update {
            $0.agentDefaultModel = model.map {
                .init(modelId: $0.modelId, maxMode: true, parameters: $0.parameters)
            }
        }
    }

    func getComputerUseModel() -> SandAgentModelSelection? { load().computerUseModel }
    func setComputerUseModel(_ model: SandAgentModelSelection?) { update { $0.computerUseModel = model } }

    func getUpdateTrackOverride() -> FabushiUpdateTrack? {
        guard let raw = load().updateTrackOverride,
              let track = UpdateTrackPolicy.managedTrack(raw) else { return nil }
        let coerced = UpdateTrackPolicy.coerceToEnabled(track)
        if coerced != track { setUpdateTrackOverride(coerced) }
        return coerced
    }

    func setUpdateTrackOverride(_ track: FabushiUpdateTrack?) {
        update { $0.updateTrackOverride = track?.rawValue }
    }

    func getMcpCustomInstructions() -> [String: String] { load().mcpCustomInstructions }
    func setMcpCustomInstructions(_ value: [String: String]) { update { $0.mcpCustomInstructions = value } }

    func getMcpCustomInstructionsByServerId() -> [String: String] { load().mcpCustomInstructionsByServerId }
    func setMcpCustomInstructionsByServerId(_ value: [String: String]) {
        update { $0.mcpCustomInstructionsByServerId = value }
    }

    func getMcpDisabledToolsByServerId() -> [String: [String]] { load().mcpDisabledToolsByServerId }
    func setMcpDisabledToolsByServerId(_ value: [String: [String]]) {
        update { $0.mcpDisabledToolsByServerId = value }
    }

    func scopeToAccount(_ accountScope: String) {
        update {
            let changed = $0.mcpCustomInstructionsAccountScope != nil
                && $0.mcpCustomInstructionsAccountScope != accountScope
            if changed {
                $0.mcpCustomInstructions = [:]
                $0.mcpCustomInstructionsByServerId = [:]
                $0.mcpDisabledToolsByServerId = [:]
                $0.autoReviewInstructions = nil
                $0.agentDefaultModel = nil
                $0.computerUseModel = nil
                $0.localToolPermission = nil
                $0.localToolPermissionCeiling = nil
            }
            if let seen = $0.hasSeenOnboarding,
               $0.hasSeenOnboardingAccountScope == nil || $0.hasSeenOnboardingAccountScope == accountScope {
                $0.hasSeenOnboarding = seen
                $0.hasSeenOnboardingAccountScope = accountScope
            } else if $0.hasSeenOnboardingAccountScope != accountScope {
                $0.hasSeenOnboarding = nil
                $0.hasSeenOnboardingAccountScope = nil
            }
            $0.mcpCustomInstructionsAccountScope = accountScope
        }
    }

    func clearAccountScope() {
        update {
            $0.mcpCustomInstructionsAccountScope = nil
            $0.mcpCustomInstructions = [:]
            $0.mcpCustomInstructionsByServerId = [:]
            $0.mcpDisabledToolsByServerId = [:]
            $0.autoReviewInstructions = nil
            $0.agentDefaultModel = nil
            $0.computerUseModel = nil
            $0.localToolPermission = nil
            $0.localToolPermissionCeiling = nil
        }
    }

    func getUserTimeZone() -> String? {
        let value = load()
        return value.userTimeZoneOverride ?? value.userTimeZone
    }

    func getDetectedUserTimeZone() -> String? { load().userTimeZone }
    func getUserTimeZoneOverride() -> String? { load().userTimeZoneOverride }

    func setUserTimeZone(_ value: String?) {
        update {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.userTimeZone = trimmed?.isEmpty == false ? trimmed : nil
        }
    }

    func setUserTimeZoneOverride(_ value: String?) {
        update {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.userTimeZoneOverride = trimmed?.isEmpty == false ? trimmed : nil
        }
    }

    func getMcpBoxServers() -> [String] { load().mcpBoxServers }
    func setMcpBoxServers(_ names: [String]) { update { $0.mcpBoxServers = names } }

    func getPinnedAgentIDs() -> [String] { load().pinnedAgentIds ?? [] }
    func setPinnedAgentIDs(_ ids: [String]) { update { $0.pinnedAgentIds = ids } }

    func getLocalToolPermission() -> SandLocalToolPermission {
        normalizeSandLocalToolPermission(load().localToolPermission)
    }

    func setLocalToolPermission(_ value: SandLocalToolPermission?) {
        update { $0.localToolPermission = value }
    }

    func getLocalToolPermissionCeiling() -> SandLocalToolPermission? {
        let raw = load().localToolPermissionCeiling
        return isSandLocalToolPermission(raw) ? raw : nil
    }

    func setLocalToolPermissionCeiling(_ value: SandLocalToolPermission?) {
        update { $0.localToolPermissionCeiling = value }
    }

    func getResolvedLocalToolPermission() -> SandLocalToolPermission {
        resolveSandLocalToolPermission(getLocalToolPermission(), adminCeiling: getLocalToolPermissionCeiling())
    }
}
