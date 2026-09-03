// Exact state atoms from hk_agent_fsm.erl
// States: created → ready → planning → executing → waiting → completed/failed/terminated

import Foundation

enum AgentState: String, Codable, Equatable, CaseIterable {
    case created
    case ready
    case planning
    case executing
    case waiting
    case completed
    case failed
    case terminated

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .terminated: return true
        default: return false
        }
    }

    var isActive: Bool {
        switch self {
        case .ready, .planning, .executing, .waiting: return true
        default: return false
        }
    }

    var displayName: String { rawValue.uppercased() }

    var color: StateColor {
        switch self {
        case .created:    return .dim
        case .ready:      return .green
        case .planning:   return .blue
        case .executing:  return .orange
        case .waiting:    return .yellow
        case .completed:  return .green
        case .failed:     return .red
        case .terminated: return .dim
        }
    }
}

enum BrowserSessionStatus: String, Codable, CaseIterable {
    case starting, ready, busy, closing, closed, crashed
}

enum TabStatus: String, Codable, CaseIterable {
    case opening, loading, idle, closed
}

enum OperationStatus: String, Codable {
    case accepted, in_progress, succeeded, failed
}

// Search pipeline stages in order (hk_search_job.erl)
enum SearchStage: String, Codable, CaseIterable {
    case user_query, query_normalization, search_planner, search_provider
    case result_normalization, url_deduplication, content_retrieval
    case content_extraction, source_ranking, result_synthesis
    case frontend_visibility, done, failed

    var index: Int { SearchStage.allCases.firstIndex(of: self) ?? 0 }
    var progress: Double { Double(index) / Double(SearchStage.allCases.count - 1) }
}

enum StateColor { case green, blue, orange, yellow, red, dim }
