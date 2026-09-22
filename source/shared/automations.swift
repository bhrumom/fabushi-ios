import Foundation

let TRIGGER_ANY_SCOPE = "*"
let GITHUB_EVENT_KINDS = [
    "pr-opened","pr-pushed","pr-merged","review-requested","review-approved","review-changes-requested",
    "review-commented","pr-comment","inline-review-comment","review-thread-resolved","review-thread-unresolved",
    "issue-assigned","ci-passed","ci-failed",
]
let LINEAR_EVENT_CASES = ["issueCreated","statusChanged","endOfCycle"]
let SENTRY_EVENT_CASES = ["issueCreated","issueResolved","issueAssigned","issueArchived","issueUnresolved","issueAny"]
let PAGERDUTY_EVENT_CASES = ["incidentTriggered","incidentAcknowledged","incidentResolved","incidentEscalated","incidentAny"]
let TRIGGER_MAX_GROUP_LISTENERS = 8
let TRIGGER_MAX_REACTION_EMOJI = 8
let LISTENER_INTEGRATION_PLATFORMS = ["github","slack"]
let AUTOMATION_WAKE_CUE = "[routine]"

struct CronTrigger: Equatable, Sendable { let schedule: String }

enum SlackMatch: Equatable, Sendable {
    case mention
    case message
    case keyword(String)
    case reaction(emoji: [String], bySelf: Bool?)
}

struct SlackTrigger: Equatable, Sendable {
    let channel: String
    let match: SlackMatch
}

struct GithubTrigger: Equatable, Sendable {
    let repo: String
    let events: [String]
    var ciBranch: String? = nil
    var userAllowlist: [String]? = nil
}

struct MicrosoftTeamsTrigger: Equatable, Sendable {
    let tenantId: String
    let teamId: String
    let teamIds: [String]
    let channelIds: [String]
    let messageContains: String
    let messageContainsIsRegex: Bool
    let blockUnauthenticatedTeamsUsers: Bool
}

struct CaseTrigger: Equatable, Sendable {
    enum Platform: String, Equatable, Sendable { case linear, sentry, pagerduty }
    let platform: Platform
    let eventCase: String
    var projectIds: [String] = []
    var teamIds: [String] = []
    var serviceIds: [String] = []
    var statusIds: [String] = []
    var cycleIds: [String] = []
}

enum AutomationTriggerMember: Equatable, Sendable {
    case cron(CronTrigger)
    case slack(SlackTrigger)
    case github(GithubTrigger)
    case microsoftTeams(MicrosoftTeamsTrigger)
    case integration(CaseTrigger)
}

enum AutomationTrigger: Equatable, Sendable {
    case member(AutomationTriggerMember)
    case group([AutomationTriggerMember])
}

func isGithubCiEventKind(_ kind: String) -> Bool {
    kind == "ci-passed" || kind == "ci-failed"
}

func normalizeReactionEmoji(_ raw: String) -> String {
    var bare = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    while bare.hasPrefix(":") { bare.removeFirst() }
    while bare.hasSuffix(":") { bare.removeLast() }
    return String(bare.split(separator: "::", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

func isValidReactionEmoji(_ value: String) -> Bool {
    !value.isEmpty && value.allSatisfy { $0.isLowercase || $0.isNumber || "_+-".contains($0) }
}

func isValidGithubRepo(_ repo: String) -> Bool {
    let parts = repo.split(separator: "/", omittingEmptySubsequences: false)
    return parts.count == 2 && parts.allSatisfy { !$0.isEmpty && !$0.contains(where: { $0.isWhitespace }) }
}

func isValidGitBranch(_ branch: String) -> Bool {
    guard !branch.isEmpty,
          !branch.hasPrefix("-"), !branch.hasPrefix("/"), !branch.hasSuffix("/"),
          !branch.contains(".."), !branch.contains("@{") else { return false }
    return !branch.contains { $0.isWhitespace || "~^:?*[\\]|".contains($0) }
}

func cronTrigger(_ schedule: String) -> CronTrigger { .init(schedule: schedule) }

func triggerList(_ trigger: AutomationTrigger) -> [AutomationTriggerMember] {
    switch trigger {
    case .member(let member): return [member]
    case .group(let listeners): return listeners
    }
}

func triggerFromList(_ members: [AutomationTriggerMember]) -> AutomationTrigger? {
    guard let first = members.first else { return nil }
    return members.count == 1 ? .member(first) : .group(members)
}

func triggerListeners(_ trigger: AutomationTrigger) -> [AutomationTriggerMember] {
    triggerList(trigger).filter {
        switch $0 {
        case .slack, .github: return true
        default: return false
        }
    }
}

func triggerEventTriggers(_ trigger: AutomationTrigger) -> [AutomationTriggerMember] {
    triggerList(trigger).filter {
        if case .cron = $0 { return false }
        return true
    }
}

func triggerCronSchedules(_ trigger: AutomationTrigger) -> [String] {
    triggerList(trigger).compactMap {
        if case .cron(let cron) = $0 { return cron.schedule }
        return nil
    }
}

func triggerSchedule(_ trigger: AutomationTrigger) -> String? {
    triggerCronSchedules(trigger).first
}

private func joinWithOr(_ parts: [String]) -> String {
    if parts.count <= 1 { return parts.first ?? "" }
    if parts.count == 2 { return "\(parts[0]) or \(parts[1])" }
    return "\(parts.dropLast().joined(separator: ", ")), or \(parts.last!)"
}

private func slackScope(_ channel: String) -> String {
    channel == TRIGGER_ANY_SCOPE ? "anywhere on Slack" : "in \(channel)"
}

func describeSlackListener(_ listener: SlackTrigger) -> String {
    let scope = slackScope(listener.channel)
    switch listener.match {
    case .mention:
        return "When @mentioned \(scope)"
    case .message:
        return "On any message \(scope)"
    case .keyword(let keyword):
        return "When \"\(keyword)\" is mentioned \(scope)"
    case .reaction(let emoji, let bySelf):
        let names = joinWithOr(emoji.map { ":\($0):" })
        if bySelf == true {
            return "When you react\(emoji.isEmpty ? "" : " \(names)") \(scope)"
        }
        return "On \(emoji.isEmpty ? "a reaction" : names) \(scope)"
    }
}

private let GITHUB_PHRASES = [
    "pr-opened":"a PR opens","pr-pushed":"a PR is updated","pr-merged":"a PR merges",
    "review-requested":"a review is requested","review-approved":"a review approves a PR",
    "review-changes-requested":"a review requests changes","review-commented":"a review comments on a PR",
    "pr-comment":"a PR comment lands","inline-review-comment":"an inline review comment lands",
    "review-thread-resolved":"a review thread is resolved","review-thread-unresolved":"a review thread is reopened",
    "issue-assigned":"an issue is assigned","ci-passed":"CI passes","ci-failed":"CI fails",
]

func describeGithubListener(_ listener: GithubTrigger) -> String {
    let phrases = listener.events.map { kind -> String in
        var phrase = GITHUB_PHRASES[kind] ?? kind
        if isGithubCiEventKind(kind), let branch = listener.ciBranch { phrase += " on \(branch)" }
        return phrase
    }
    let base = "When \(joinWithOr(phrases)) in \(listener.repo)"
    guard let allowlist = listener.userAllowlist, !allowlist.isEmpty else { return base }
    let users = allowlist.map { $0.hasPrefix("@") ? $0 : "@\($0)" }
    return "\(base) (by \(joinWithOr(users)))"
}

private let CASE_PHRASES: [CaseTrigger.Platform: [String: String]] = [
    .linear:["issueCreated":"a Linear issue is created","statusChanged":"a Linear issue changes status","endOfCycle":"a Linear cycle ends"],
    .sentry:["issueCreated":"a Sentry issue is created","issueResolved":"a Sentry issue is resolved","issueAssigned":"a Sentry issue is assigned","issueArchived":"a Sentry issue is archived","issueUnresolved":"a Sentry issue becomes unresolved","issueAny":"a Sentry issue changes"],
    .pagerduty:["incidentTriggered":"a PagerDuty incident is triggered","incidentAcknowledged":"a PagerDuty incident is acknowledged","incidentResolved":"a PagerDuty incident is resolved","incidentEscalated":"a PagerDuty incident is escalated","incidentAny":"a PagerDuty incident changes"],
]

func describeListener(_ listener: AutomationTriggerMember) -> String {
    switch listener {
    case .cron(let cron): return cron.schedule
    case .slack(let slack): return describeSlackListener(slack)
    case .github(let github): return describeGithubListener(github)
    case .microsoftTeams(let teams):
        return teams.messageContains.isEmpty ? "On a Microsoft Teams message" : "When a Microsoft Teams message matches \"\(teams.messageContains)\""
    case .integration(let integration):
        return "When \(CASE_PHRASES[integration.platform]?[integration.eventCase] ?? integration.eventCase)"
    }
}
