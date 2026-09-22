import Foundation

protocol AgentSummaryIdentity {
    var id: String { get }
    var updatedAt: Double { get }
}

/// Mirrors the numeric comparator used by the Grok renderer.
func compareAgentSummaries<T: AgentSummaryIdentity>(_ a: T, _ b: T) -> Double {
    b.updatedAt - a.updatedAt
}

func upsertAgentSummary<T: AgentSummaryIdentity>(
    _ summaries: [T],
    updated: T
) -> [T] {
    var found = false
    var next = summaries.map { summary in
        guard summary.id == updated.id else { return summary }
        found = true
        return updated
    }
    if !found {
        next.append(updated)
    }
    next.sort { left, right in
        if left.updatedAt == right.updatedAt {
            return left.id < right.id
        }
        return compareAgentSummaries(left, right) < 0
    }
    return next
}
