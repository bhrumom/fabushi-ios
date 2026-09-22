import Foundation

private let SAND_SENTRY_REDACTED_PATH = "<REDACTED: user-file-path>"
private let SAND_SENTRY_REDACTED_URL = "<REDACTED: url>"
private let SAND_SENTRY_REDACTED_EXCEPTION = "<REDACTED: exception-message>"
private let SAND_SENTRY_MAX_EXCEPTIONS = 8
private let SAND_SENTRY_MAX_FRAMES = 100
private let SAND_SENTRY_FATAL_TAGS: Set<String> = [
    "app_flavor",
    "event.environment",
    "event.origin",
    "event.process",
    "exit.reason",
    "crash.kind",
    "sand.failure_code",
    "sand.process",
]

private let sandSentryBoundedCode = try! NSRegularExpression(pattern: #"^[A-Za-z0-9._:@-]+$"#)
private let sandSentryOpaqueID = try! NSRegularExpression(pattern: #"^[A-Za-z0-9._:@|\-]+$"#)
private let sandSentryEmail = try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#)
private let sandSentrySecret = try! NSRegularExpression(
    pattern: #"(github_pat_[A-Za-z0-9_]{20,}|gh[psuro]_[A-Za-z0-9]{20,}|xox[pbar]-[A-Za-z0-9-]+|AIza[A-Za-z0-9_\\\-]{30,}|(?:key|token|sig|secret|signature|password|passwd|pwd)[^A-Za-z0-9])"#,
    options: [.caseInsensitive]
)

private func sandSentryMatches(_ regex: NSRegularExpression, _ value: String) -> Bool {
    regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
}

private func sandSentryBounded(_ value: Any?, maxLength: Int = 128) -> String? {
    guard let value = value as? String, !value.isEmpty, value.count <= maxLength else { return nil }
    guard sandSentryMatches(sandSentryBoundedCode, value) else { return nil }
    guard sandSentryEmail.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) == nil else { return nil }
    guard sandSentrySecret.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) == nil else { return nil }
    return value
}

private func sandSentryBoundedID(_ value: Any?) -> Any? {
    if let number = value as? NSNumber {
        let double = number.doubleValue
        return double.isFinite ? number : nil
    }
    guard let value = value as? String, !value.isEmpty, value.count <= 128 else { return nil }
    guard sandSentryMatches(sandSentryOpaqueID, value) else { return nil }
    guard sandSentryEmail.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) == nil else { return nil }
    guard sandSentrySecret.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) == nil else { return nil }
    return value
}

private func sandSentryScrubURL(_ value: Any?) -> String? {
    guard let value = value as? String else { return nil }
    if value == SAND_SENTRY_REDACTED_URL { return value }
    guard let components = URLComponents(string: value),
          components.scheme == "app",
          components.host == nil || components.host == "",
          components.user == nil,
          components.password == nil else {
        return SAND_SENTRY_REDACTED_URL
    }
    let path = components.percentEncodedPath
    guard !path.isEmpty, path.count <= 512 else { return SAND_SENTRY_REDACTED_URL }
    let candidate = "app://\(path)"
    return candidate.range(of: #"^app:///[A-Za-z0-9._/\-]+$"#, options: .regularExpression) != nil
        ? candidate
        : SAND_SENTRY_REDACTED_URL
}

private func sandSentryFrameFilename(_ value: Any?) -> String? {
    guard let value = value as? String else { return nil }
    if value.count <= 512,
       value.range(of: #"^node:[A-Za-z0-9._/\-]+$"#, options: .regularExpression) != nil {
        return value
    }
    let appURL = sandSentryScrubURL(value)
    return appURL == SAND_SENTRY_REDACTED_URL ? SAND_SENTRY_REDACTED_PATH : appURL
}

private func sandSentryScrubFrame(_ value: Any) -> [String: Any]? {
    guard let value = value as? [String: Any] else { return nil }
    var result: [String: Any] = [:]
    if let filename = sandSentryFrameFilename(value["filename"]) {
        result["filename"] = filename
        if filename != SAND_SENTRY_REDACTED_PATH {
            if let function = sandSentryBounded(value["function"]) { result["function"] = function }
            if let module = sandSentryBounded(value["module"]) { result["module"] = module }
        }
    }
    for key in ["platform", "instruction_addr", "addr_mode", "debug_id"] {
        if let code = sandSentryBounded(value[key]) { result[key] = code }
    }
    for key in ["lineno", "colno"] {
        if let number = value[key] as? NSNumber, number.doubleValue.isFinite { result[key] = number }
    }
    if let inApp = value["in_app"] as? Bool { result["in_app"] = inApp }
    return result
}

private func sandSentryScrubStacktrace(_ value: Any?) -> [String: Any]? {
    guard let value = value as? [String: Any], let frames = value["frames"] as? [Any] else { return nil }
    return ["frames": frames.prefix(SAND_SENTRY_MAX_FRAMES).compactMap(sandSentryScrubFrame)]
}

private func sandSentryScrubException(_ value: Any?, tier: SandSentryPrivacyTier) -> [String: Any]? {
    guard let value = value as? [String: Any], let values = value["values"] as? [Any] else { return nil }
    let projected: [[String: Any]] = values.prefix(SAND_SENTRY_MAX_EXCEPTIONS).compactMap { item in
        guard let item = item as? [String: Any] else { return nil }
        var output: [String: Any] = [:]
        if let type = sandSentryBounded(item["type"]) {
            output["type"] = type
        } else if item["type"] is String {
            output["type"] = "<REDACTED: exception-type>"
        }
        guard tier != .fatalMetadata else { return output }
        if item["value"] is String { output["value"] = SAND_SENTRY_REDACTED_EXCEPTION }
        if let threadID = sandSentryBoundedID(item["thread_id"]) { output["thread_id"] = threadID }
        if let stack = sandSentryScrubStacktrace(item["stacktrace"]) { output["stacktrace"] = stack }
        if let mechanism = item["mechanism"] as? [String: Any] {
            var clean: [String: Any] = [:]
            if let type = sandSentryBounded(mechanism["type"]) { clean["type"] = type }
            if let handled = mechanism["handled"] as? Bool { clean["handled"] = handled }
            if let synthetic = mechanism["synthetic"] as? Bool { clean["synthetic"] = synthetic }
            if !clean.isEmpty { output["mechanism"] = clean }
        }
        return output
    }
    return projected.isEmpty ? nil : ["values": projected]
}

private func sandSentryScrubTags(_ value: Any?, tier: SandSentryPrivacyTier) -> [String: Any]? {
    guard let value = value as? [String: Any] else { return nil }
    var result: [String: Any] = [:]
    for (key, raw) in value {
        guard sandSentryBounded(key) != nil else { continue }
        if tier == .fatalMetadata && !SAND_SENTRY_FATAL_TAGS.contains(key) { continue }
        if let string = raw as? String, let safe = sandSentryBounded(string) {
            result[key] = safe
        } else if tier != .fatalMetadata, raw is Bool || raw is NSNumber || raw is NSNull {
            result[key] = raw
        }
    }
    return result.isEmpty ? nil : result
}

private func sandSentryScrubRequest(_ value: Any?) -> [String: Any]? {
    guard let value = value as? [String: Any] else { return nil }
    var result: [String: Any] = [:]
    if let method = sandSentryBounded(value["method"]) { result["method"] = method }
    if let url = sandSentryScrubURL(value["url"]) { result["url"] = url }
    return result.isEmpty ? nil : result
}

private func sandSentryScrubUser(_ value: Any?) -> [String: Any]? {
    guard let value = value as? [String: Any], let id = sandSentryBoundedID(value["id"]) else { return nil }
    return ["id": id]
}

private func sandSentryProjectEvent(_ event: [String: Any], tier: SandSentryPrivacyTier) -> [String: Any] {
    if tier == .full { return event }

    var result: [String: Any] = [:]
    for key in ["event_id", "platform", "environment", "release", "dist", "level", "transaction"] {
        if let value = sandSentryBounded(event[key]) { result[key] = value }
    }
    if let timestamp = event["timestamp"] as? NSNumber, timestamp.doubleValue.isFinite {
        result["timestamp"] = timestamp
    }
    if let user = sandSentryScrubUser(event["user"]) { result["user"] = user }
    if let tags = sandSentryScrubTags(event["tags"], tier: tier) { result["tags"] = tags }
    if let exception = sandSentryScrubException(event["exception"], tier: tier) { result["exception"] = exception }
    if tier == .scrubbed, let request = sandSentryScrubRequest(event["request"]) { result["request"] = request }
    return result
}

private func sandSentryProjectSession(_ session: [String: Any], tier: SandSentryPrivacyTier) -> [String: Any] {
    if tier == .full { return session }
    var result: [String: Any] = [:]
    if let did = sandSentryBoundedID(session["did"]) { result["did"] = did }
    for key in ["sid", "status", "release", "environment"] {
        if let value = sandSentryBounded(session[key]) { result[key] = value }
    }
    for key in ["started", "timestamp", "duration", "errors"] {
        if let value = session[key] as? NSNumber, value.doubleValue.isFinite { result[key] = value }
    }
    return result
}

func projectSandSentryEnvelope(
    _ envelope: SandSentryEnvelope,
    tier: SandSentryPrivacyTier
) -> SandSentryEnvelope? {
    if tier == .full { return envelope }

    var header: [String: Any] = [:]
    if let eventID = sandSentryBounded(envelope.header["event_id"]) { header["event_id"] = eventID }
    if let sentAt = sandSentryBounded(envelope.header["sent_at"]) { header["sent_at"] = sentAt }

    var items: [SandSentryItem] = []
    for item in envelope.items {
        let type = item.header["type"] as? String
        switch type {
        case "event":
            guard let event = item.payload as? [String: Any] else { continue }
            items.append(.init(header: ["type": "event"], payload: sandSentryProjectEvent(event, tier: tier)))
        case "session":
            guard let session = item.payload as? [String: Any] else { continue }
            items.append(.init(header: ["type": "session"], payload: sandSentryProjectSession(session, tier: tier)))
        default:
            continue
        }
    }
    return items.isEmpty ? nil : SandSentryEnvelope(header: header, items: items)
}
