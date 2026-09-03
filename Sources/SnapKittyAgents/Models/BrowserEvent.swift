// Event envelope — maps exactly to hk_event:to_map/1
// Categories are dotted strings e.g. "agent.created", "agent.action.started"

import Foundation

struct BrowserEvent: Codable, Identifiable {
    let event_id: String
    let category: String
    let subject: EventSubject?
    let operation_id: String?
    let data: [String: AnyCodable]
    let emitted_at_ms: Int64

    var id: String { event_id }
    var emittedAt: Date { Date(timeIntervalSince1970: Double(emitted_at_ms) / 1000) }

    var eventType: EventCategory { EventCategory(rawValue: category) ?? .unknown }
}

struct EventSubject: Codable, Equatable {
    let type: String
    let id: String
}

// Known event category strings from hk_agent_fsm.erl emit calls
enum EventCategory: String {
    case agentCreated           = "agent.created"
    case agentObjectiveAssigned = "agent.objective.assigned"
    case agentActionStarted     = "agent.action.started"
    case agentActionCompleted   = "agent.action.completed"
    case agentActionFailed      = "agent.action.failed"
    case agentActionRejected    = "agent.action.rejected"
    case agentCompleted         = "agent.completed"
    case agentFailed            = "agent.failed"
    case agentTerminated        = "agent.terminated"
    case unknown
}

// Typed data accessors for known event categories
extension BrowserEvent {
    var agentId: String?     { data["agent_id"]?.value as? String }
    var actionCount: Int?    { data["action_count"]?.value as? Int }
    var tool: String?        { data["tool"]?.value as? String }
    var op: String?          { data["op"]?.value as? String }
    var reason: String?      { data["reason"]?.value as? String }
    var description_: String? { data["description"]?.value as? String }
    var fromState: String?   { data["from_state"]?.value as? String }

    var summary: String {
        switch eventType {
        case .agentCreated:           return "Agent created"
        case .agentObjectiveAssigned: return "Objective: \(description_ ?? "")"
        case .agentActionStarted:     return "→ \(tool ?? "").\(op ?? "")"
        case .agentActionCompleted:   return "✓ \(tool ?? "").\(op ?? "")"
        case .agentActionFailed:      return "✗ \(tool ?? "").\(op ?? ""): \(reason ?? "")"
        case .agentActionRejected:    return "⊘ \(tool ?? "").\(op ?? "") rejected"
        case .agentCompleted:         return "Agent completed (\(actionCount ?? 0) actions)"
        case .agentFailed:            return "Agent failed: \(reason ?? "")"
        case .agentTerminated:        return "Agent terminated: \(reason ?? "")"
        case .unknown:                return category
        }
    }
}
