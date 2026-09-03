// Orchestrates the JIT agent lifecycle:
// Create → Connect → Assign Objective → Run → Observe → Destroy

import Foundation
import Combine

@MainActor
final class AgentSessionManager: ObservableObject {
    let client: HyperKittyClient
    let store: AgentStore
    let eventStream: EventStream

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var lastError: HyperKittyError?
    @Published var selectedAgentId: String?

    private var pollingTasks: [String: Task<Void, Never>] = [:]

    init(config: HyperKittyConfig) {
        self.client = HyperKittyClient(config: config)
        self.store = AgentStore()
        self.eventStream = EventStream(url: config.eventStreamURL, apiKey: config.apiKey)
        hookEventStream()
    }

    // MARK: - Connection

    func connect() async {
        do {
            let health = try await client.health()
            isConnected = health.isHealthy
            if isConnected {
                eventStream.connect()
                await refreshAll()
            }
        } catch {
            isConnected = false
            lastError = error as? HyperKittyError ?? .connectionFailed(underlying: error)
            SKLogger.error("Connect failed: \(error)")
        }
    }

    func disconnect() {
        eventStream.disconnect()
        pollingTasks.values.forEach { $0.cancel() }
        pollingTasks.removeAll()
        isConnected = false
    }

    // MARK: - JIT Agent Lifecycle

    func createJITAgent(
        objective: String,
        modelName: String = "SnapKitty K1",
        capabilities: [String] = ["navigate","read_page","screenshot","extract_links","click","type","scroll","back","forward","reload"]
    ) async throws -> String {
        // Step 1: Create agent
        let op = try await client.createAgent(capabilities: capabilities, limits: nil)
        guard let agentId = op.agent_id, op.status == .accepted || op.status == .succeeded else {
            throw HyperKittyError.operationFailed(reason: "create agent: \(op.status)")
        }

        // Step 2: Create browser session
        let sessionOp = try await client.createSession(ownerAgentId: agentId)
        guard let sessionId = sessionOp.session_id else {
            throw HyperKittyError.operationFailed(reason: "create session")
        }

        // Step 3: Open initial tab
        let tabOp = try await client.openTab(sessionId: sessionId, url: "about:blank")
        guard let tabId = tabOp.tab_id else {
            throw HyperKittyError.operationFailed(reason: "open tab")
        }

        // Step 4: Assign objective
        _ = try await client.assignObjective(agentId: agentId, description: objective)

        // Step 5: Refresh agent state
        let agent = try await client.describeAgent(id: agentId)
        let session = try await client.describeSession(id: sessionId)
        store.upsert(agent: agent)
        store.upsert(session: session)
        store.telemetry[agentId]?.sessionId = sessionId
        store.telemetry[agentId]?.modelName = modelName

        selectedAgentId = agentId
        SKLogger.info("JIT agent created: \(agentId), session: \(sessionId), tab: \(tabId)")
        return agentId
    }

    func runAction(agentId: String, command: AgentCommand) async throws -> OperationEnvelope {
        let op = try await client.runAction(agentId: agentId, command: command)
        store.telemetry[agentId]?.lastCommand = command
        return op
    }

    func terminateAgent(agentId: String) async throws {
        _ = try await client.terminateAgent(agentId: agentId, reason: "operator_requested")
        // Clean up browser session
        if let sessionId = store.telemetry[agentId]?.sessionId {
            try? await client.closeSession(id: sessionId)
        }
        store.remove(agentId: agentId)
        if selectedAgentId == agentId { selectedAgentId = nil }
        SKLogger.info("Agent \(agentId) terminated and session cleaned up")
    }

    func pauseAgent(agentId: String) async throws {
        // HyperKitty doesn't have a pause endpoint — we terminate with a reason
        // that allows the UI to distinguish pause intent
        _ = try await client.terminateAgent(agentId: agentId, reason: "operator_paused")
    }

    func resetAgent(agentId: String, objective: String) async throws -> String {
        // JIT: destroy old, create fresh
        try await terminateAgent(agentId: agentId)
        let modelName = store.telemetry[agentId]?.modelName ?? "SnapKitty K1"
        return try await createJITAgent(objective: objective, modelName: modelName)
    }

    // MARK: - Refresh

    func refreshAll() async {
        do {
            let agents = try await client.listAgents()
            agents.forEach { store.upsert(agent: $0) }
        } catch { SKLogger.error("refreshAll: \(error)") }
    }

    func refreshAgent(_ agentId: String) async {
        do {
            let agent = try await client.describeAgent(id: agentId)
            store.upsert(agent: agent)
        } catch { SKLogger.error("refreshAgent \(agentId): \(error)") }
    }

    // MARK: - Event stream routing

    private func hookEventStream() {
        eventStream.onEvent { [weak self] event in
            guard let self else { return }
            let agentId = event.subject?.id ?? event.agentId ?? ""
            if !agentId.isEmpty {
                self.store.append(event: event, for: agentId)
                // Refresh agent state on terminal events
                if [.agentCompleted, .agentFailed, .agentTerminated].contains(event.eventType) {
                    Task { await self.refreshAgent(agentId) }
                }
            }
        }
    }

    // MARK: - Computed

    var selectedAgent: Agent? {
        selectedAgentId.flatMap { store.agents[$0] }
    }

    var allAgents: [Agent] {
        store.agents.values.sorted { $0.started_at_ms < $1.started_at_ms }
    }
}
