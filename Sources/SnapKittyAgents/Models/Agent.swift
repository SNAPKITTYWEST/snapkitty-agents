// Maps exactly to #agent{} and #agent_objective{} records from hyperkitty.hrl
// All timestamps are Unix epoch milliseconds (Int64)

import Foundation

struct Agent: Codable, Identifiable, Equatable {
    let agent_id: String
    var objective: AgentObjective?
    var state: AgentState
    var capabilities: [String]
    var action_count: Int
    var started_at_ms: Int64
    var updated_at_ms: Int64
    var limits: AgentLimits
    var result: AnyCodable?
    var failure_reason: String?

    var id: String { agent_id }

    var displayName: String {
        let suffix = String(agent_id.suffix(6)).uppercased()
        return "SK-\(suffix)"
    }

    var startedAt: Date { Date(timeIntervalSince1970: Double(started_at_ms) / 1000) }
    var updatedAt: Date { Date(timeIntervalSince1970: Double(updated_at_ms) / 1000) }
}

struct AgentObjective: Codable, Equatable {
    let objective_id: String
    let agent_id: String
    let description: String
    let success_criteria: String?
    let created_at_ms: Int64

    var createdAt: Date { Date(timeIntervalSince1970: Double(created_at_ms) / 1000) }
}

struct AgentLimits: Codable, Equatable {
    var max_actions: Int
    var max_execution_ms: Int
    var max_network_requests: Int
    var max_search_iterations: Int

    static let `default` = AgentLimits(
        max_actions: 1_000_000,
        max_execution_ms: 3_600_000,
        max_network_requests: 1_000_000,
        max_search_iterations: 1_000_000
    )
}

// Browser session — maps to #browser_session{}
struct BrowserSession: Codable, Identifiable, Equatable {
    let session_id: String
    let owner_agent_id: String?
    let profile: String
    var status: BrowserSessionStatus
    var tabs: [String]
    let created_at_ms: Int64
    var updated_at_ms: Int64

    var id: String { session_id }
    var createdAt: Date { Date(timeIntervalSince1970: Double(created_at_ms) / 1000) }
}

// Browser tab — maps to #browser_tab{}
struct BrowserTab: Codable, Identifiable, Equatable {
    let tab_id: String
    let session_id: String
    var url: String?
    var title: String?
    var status: TabStatus
    let created_at_ms: Int64
    var updated_at_ms: Int64

    var id: String { tab_id }
    var displayURL: String { url ?? "about:blank" }
    var displayTitle: String { title ?? displayURL }
}

// Search job — maps to #search_job{}
struct SearchJob: Codable, Identifiable, Equatable {
    let job_id: String
    let owner_agent_id: String?
    let query: String
    var stage: SearchStage
    let max_iterations: Int
    var iteration: Int
    var results: [String]
    let created_at_ms: Int64
    var updated_at_ms: Int64

    var id: String { job_id }
}

// Operation envelope — every mutating response
struct OperationEnvelope: Codable {
    let operation_id: String
    let request_id: String?
    let kind: String?
    var status: OperationStatus
    let subject: EventSubject?
    let error: AnyCodable?
    let created_at_ms: Int64?
    let updated_at_ms: Int64?

    // Convenience fields present on specific operations
    let agent_id: String?
    let session_id: String?
    let tab_id: String?
    let job_id: String?
    let observation: AnyCodable?
}

// AnyCodable for dynamic JSON values
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)   { value = v; return }
        if let v = try? container.decode(Int.self)    { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([AnyCodable].self) { value = v.map(\.value); return }
        if let v = try? container.decode([String: AnyCodable].self) {
            value = v.mapValues(\.value); return
        }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:   try container.encode(v)
        case let v as Int:    try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        "\(lhs.value)" == "\(rhs.value)"
    }
}
