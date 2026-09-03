import Foundation
import Combine

@MainActor
final class AgentStore: ObservableObject {
    @Published private(set) var agents: [String: Agent] = [:]
    @Published private(set) var sessions: [String: BrowserSession] = [:]
    @Published private(set) var tabs: [String: BrowserTab] = [:]
    @Published private(set) var events: [String: [BrowserEvent]] = [:]   // agentId → events
    @Published private(set) var telemetry: [String: AgentTelemetry] = [:] // agentId → telemetry

    func upsert(agent: Agent) {
        agents[agent.agent_id] = agent
        if telemetry[agent.agent_id] == nil {
            telemetry[agent.agent_id] = .empty(agentId: agent.agent_id, model: "SnapKitty K1")
        }
        telemetry[agent.agent_id]?.currentState = agent.state
    }

    func upsert(session: BrowserSession) {
        sessions[session.session_id] = session
    }

    func upsert(tab: BrowserTab) {
        tabs[tab.tab_id] = tab
        if let agentId = sessions[tab.session_id]?.owner_agent_id {
            telemetry[agentId]?.currentURL = tab.url
            telemetry[agentId]?.currentTitle = tab.title
        }
    }

    func append(event: BrowserEvent, for agentId: String) {
        var list = events[agentId] ?? []
        list.append(event)
        if list.count > 500 { list.removeFirst(list.count - 500) } // cap per agent
        events[agentId] = list
        telemetry[agentId]?.record(event: event)
    }

    func remove(agentId: String) {
        agents.removeValue(forKey: agentId)
        events.removeValue(forKey: agentId)
        telemetry.removeValue(forKey: agentId)
    }

    func eventsFor(_ agentId: String) -> [BrowserEvent] {
        events[agentId] ?? []
    }

    func telemetryFor(_ agentId: String) -> AgentTelemetry? {
        telemetry[agentId]
    }
}
