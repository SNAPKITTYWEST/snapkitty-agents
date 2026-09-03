// Protocol-based HyperKitty Chromium API client
// All endpoint paths verified against hk_api_router.erl
// Never hard-codes assumptions — all configuration via HyperKittyConfig

import Foundation

struct HyperKittyConfig {
    var baseURL: URL
    var apiKey: String?
    var requestTimeout: TimeInterval = 55.0   // ACTION_TIMEOUT_MS(45s) + buffer
    var actionTimeout: TimeInterval  = 50.0   // matches caller timeout in hk_agent_fsm.erl
    var eventStreamURL: URL          // ws:// or wss://

    static func localhost(port: Int = 8080) -> HyperKittyConfig {
        let base = URL(string: "http://localhost:\(port)")!
        let ws   = URL(string: "ws://localhost:\(port)/api/events/stream")!
        return HyperKittyConfig(baseURL: base, eventStreamURL: ws)
    }
}

// MARK: - Protocol

protocol HyperKittyClientProtocol {
    var config: HyperKittyConfig { get }
    func health() async throws -> HealthStatus

    // Agents
    func createAgent(capabilities: [String], limits: AgentLimits?) async throws -> OperationEnvelope
    func listAgents() async throws -> [Agent]
    func describeAgent(id: String) async throws -> Agent
    func assignObjective(agentId: String, description: String) async throws -> OperationEnvelope
    func runAction(agentId: String, command: AgentCommand) async throws -> OperationEnvelope
    func completeAgent(agentId: String, result: Any?) async throws -> OperationEnvelope
    func terminateAgent(agentId: String, reason: String) async throws -> OperationEnvelope

    // Browser sessions
    func createSession(ownerAgentId: String?) async throws -> OperationEnvelope
    func listSessions() async throws -> [BrowserSession]
    func describeSession(id: String) async throws -> BrowserSession
    func closeSession(id: String) async throws -> OperationEnvelope
    func openTab(sessionId: String, url: String) async throws -> OperationEnvelope
    func navigate(sessionId: String, tabId: String, url: String) async throws -> OperationEnvelope
    func tabAction(sessionId: String, tabId: String, command: AgentCommand) async throws -> OperationEnvelope

    // Search
    func startSearch(query: String, ownerAgentId: String?, maxIterations: Int) async throws -> OperationEnvelope
    func listJobs() async throws -> [SearchJob]
    func describeJob(id: String) async throws -> SearchJob
    func pollResult(jobId: String) async throws -> SearchResult

    // Events (returns an AsyncSequence of BrowserEvent)
    func eventStream() -> EventStream
}

struct HealthStatus: Codable {
    let status: String
    let subsystems: [String: String]?

    var isHealthy: Bool { status == "ok" }
}

struct SearchResult: Codable {
    let job_id: String
    let status: String?
    let results: [String]?
}

// MARK: - Concrete implementation

final class HyperKittyClient: HyperKittyClientProtocol {
    let config: HyperKittyConfig
    private let session: URLSession

    init(config: HyperKittyConfig) {
        self.config = config
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = config.requestTimeout
        self.session = URLSession(configuration: c)
    }

    // MARK: Health

    func health() async throws -> HealthStatus {
        try await get("/api/health")
    }

    // MARK: Agents

    func createAgent(capabilities: [String] = [], limits: AgentLimits? = nil) async throws -> OperationEnvelope {
        var body: [String: Any] = ["capabilities": capabilities]
        if let l = limits {
            body["limits"] = [
                "max_actions": l.max_actions,
                "max_execution_ms": l.max_execution_ms,
                "max_network_requests": l.max_network_requests,
                "max_search_iterations": l.max_search_iterations,
            ]
        }
        return try await post("/api/agents", body: body)
    }

    func listAgents() async throws -> [Agent] {
        struct ListResponse: Codable { let agents: [Agent] }
        let r: ListResponse = try await get("/api/agents")
        return r.agents
    }

    func describeAgent(id: String) async throws -> Agent {
        try await get("/api/agents/\(id)")
    }

    func assignObjective(agentId: String, description: String) async throws -> OperationEnvelope {
        try await post("/api/agents/\(agentId)/objective", body: ["description": description])
    }

    func runAction(agentId: String, command: AgentCommand) async throws -> OperationEnvelope {
        try await post("/api/agents/\(agentId)/actions", body: command.toRequestBody())
    }

    func completeAgent(agentId: String, result: Any? = nil) async throws -> OperationEnvelope {
        var body: [String: Any] = [:]
        if let r = result { body["result"] = r }
        return try await post("/api/agents/\(agentId)/complete", body: body)
    }

    func terminateAgent(agentId: String, reason: String = "operator_requested") async throws -> OperationEnvelope {
        try await post("/api/agents/\(agentId)/terminate", body: ["reason": reason])
    }

    // MARK: Browser sessions

    func createSession(ownerAgentId: String? = nil) async throws -> OperationEnvelope {
        var body: [String: Any] = ["profile": "manual"]
        if let id = ownerAgentId { body["owner_agent_id"] = id }
        return try await post("/api/browser/sessions", body: body)
    }

    func listSessions() async throws -> [BrowserSession] {
        struct ListResponse: Codable { let sessions: [BrowserSession] }
        let r: ListResponse = try await get("/api/browser/sessions")
        return r.sessions
    }

    func describeSession(id: String) async throws -> BrowserSession {
        try await get("/api/browser/sessions/\(id)")
    }

    func closeSession(id: String) async throws -> OperationEnvelope {
        try await post("/api/browser/sessions/\(id)/close", body: [:])
    }

    func openTab(sessionId: String, url: String = "about:blank") async throws -> OperationEnvelope {
        try await post("/api/browser/sessions/\(sessionId)/tabs", body: ["url": url])
    }

    func navigate(sessionId: String, tabId: String, url: String) async throws -> OperationEnvelope {
        try await post("/api/browser/sessions/\(sessionId)/tabs/\(tabId)/navigate", body: ["url": url])
    }

    func tabAction(sessionId: String, tabId: String, command: AgentCommand) async throws -> OperationEnvelope {
        try await post("/api/browser/sessions/\(sessionId)/tabs/\(tabId)/actions", body: command.toRequestBody())
    }

    // MARK: Search

    func startSearch(query: String, ownerAgentId: String? = nil, maxIterations: Int = 3) async throws -> OperationEnvelope {
        var body: [String: Any] = ["query": query, "max_iterations": maxIterations]
        if let id = ownerAgentId { body["owner_agent_id"] = id }
        return try await post("/api/search", body: body)
    }

    func listJobs() async throws -> [SearchJob] {
        struct ListResponse: Codable { let jobs: [SearchJob] }
        let r: ListResponse = try await get("/api/search")
        return r.jobs
    }

    func describeJob(id: String) async throws -> SearchJob {
        try await get("/api/search/\(id)")
    }

    func pollResult(jobId: String) async throws -> SearchResult {
        // 202 = pending, 200 = done
        let (data, response) = try await rawGet("/api/search/\(jobId)/result")
        let code = (response as? HTTPURLResponse)?.statusCode ?? 200
        if code == 202 { return SearchResult(job_id: jobId, status: "pending", results: nil) }
        return try JSONDecoder().decode(SearchResult.self, from: data)
    }

    // MARK: Event stream

    func eventStream() -> EventStream {
        EventStream(url: config.eventStreamURL, apiKey: config.apiKey)
    }

    // MARK: - HTTP helpers

    private func url(_ path: String) -> URL {
        config.baseURL.appendingPathComponent(path)
    }

    private func request(_ path: String, method: String, body: [String: Any]? = nil) throws -> URLRequest {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = config.apiKey {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return req
    }

    private func get<T: Codable>(_ path: String) async throws -> T {
        let req = try request(path, method: "GET")
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
        return try JSONDecoder.hk.decode(T.self, from: data)
    }

    private func post<T: Codable>(_ path: String, body: [String: Any]) async throws -> T {
        let req = try request(path, method: "POST", body: body)
        let (data, response) = try await session.data(for: req)
        try validate(response, data: data)
        return try JSONDecoder.hk.decode(T.self, from: data)
    }

    private func rawGet(_ path: String) async throws -> (Data, URLResponse) {
        let req = try request(path, method: "GET")
        return try await session.data(for: req)
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw HyperKittyError.httpError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }
}

// MARK: - Errors

enum HyperKittyError: LocalizedError {
    case httpError(statusCode: Int, body: String?)
    case connectionFailed(underlying: Error)
    case invalidResponse
    case sessionNotFound(String)
    case agentNotFound(String)
    case operationFailed(reason: String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):   return "HTTP \(code): \(body ?? "no body")"
        case .connectionFailed(let err):       return "Connection failed: \(err.localizedDescription)"
        case .invalidResponse:                 return "Invalid response from HyperKitty"
        case .sessionNotFound(let id):         return "Session not found: \(id)"
        case .agentNotFound(let id):           return "Agent not found: \(id)"
        case .operationFailed(let r):          return "Operation failed: \(r)"
        case .timeout:                         return "Request timed out"
        }
    }
}

extension JSONDecoder {
    static let hk: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()
}
