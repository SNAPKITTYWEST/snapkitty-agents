import Foundation

struct AgentTelemetry {
    let agentId: String
    var modelName: String
    var sessionId: String?
    var currentURL: String?
    var currentTitle: String?
    var currentState: AgentState
    var lastCommand: AgentCommand?
    var lastEvent: BrowserEvent?
    var elapsedMs: Int64
    var eventCount: Int
    var errorCount: Int
    var actionCount: Int
    var startedAt: Date

    var elapsedFormatted: String {
        let s = Int(elapsedMs / 1000)
        let m = s / 60
        let h = m / 60
        if h > 0 { return "\(h)h \(m % 60)m \(s % 60)s" }
        if m > 0 { return "\(m)m \(s % 60)s" }
        return "\(s)s"
    }

    mutating func record(event: BrowserEvent) {
        eventCount += 1
        lastEvent = event
        if event.eventType == .agentActionFailed || event.eventType == .agentFailed {
            errorCount += 1
        }
        if let count = event.actionCount {
            actionCount = count
        }
    }

    static func empty(agentId: String, model: String) -> AgentTelemetry {
        AgentTelemetry(
            agentId: agentId, modelName: model,
            sessionId: nil, currentURL: nil, currentTitle: nil,
            currentState: .created, lastCommand: nil, lastEvent: nil,
            elapsedMs: 0, eventCount: 0, errorCount: 0, actionCount: 0,
            startedAt: Date()
        )
    }
}
