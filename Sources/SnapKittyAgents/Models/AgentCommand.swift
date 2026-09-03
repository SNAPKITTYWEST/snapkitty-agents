// Browser capability operations — 15 operations from hk_browser_capability.erl
// Argument validation mirrors the Erlang constraints exactly

import Foundation

enum BrowserOperation: String, CaseIterable, Codable {
    case create_session, close_session, open_tab, close_tab
    case navigate, back, forward, reload
    case read_page, query_element, click, type_, scroll
    case screenshot, extract_links

    var rawValue: String {
        if self == .type_ { return "type" }
        return String(describing: self)
    }

    var requiresArgs: Bool {
        switch self {
        case .navigate, .open_tab, .click, .query_element, .type_, .scroll: return true
        default: return false
        }
    }
}

struct AgentCommand: Codable, Identifiable {
    let id: UUID
    let tool: CommandTool
    let op: String
    let args: [String: AnyCodable]

    enum CommandTool: String, Codable {
        case browser, search
    }

    init(tool: CommandTool = .browser, op: BrowserOperation, args: [String: Any] = [:]) {
        self.id = UUID()
        self.tool = tool
        self.op = op.rawValue
        self.args = args.mapValues { AnyCodable($0) }
    }

    // Validated constructors — match constraints from hk_browser_capability.erl

    static func navigate(url: String) throws -> AgentCommand {
        try validateURL(url)
        return AgentCommand(op: .navigate, args: ["url": url])
    }

    static func click(selector: String) throws -> AgentCommand {
        try validateSelector(selector)
        return AgentCommand(op: .click, args: ["selector": selector])
    }

    static func type_(selector: String, text: String) throws -> AgentCommand {
        try validateSelector(selector)
        guard text.utf8.count <= 10_000 else {
            throw CommandError.textTooLong(actual: text.utf8.count, max: 10_000)
        }
        return AgentCommand(op: .type_, args: ["selector": selector, "text": text])
    }

    static func scroll(deltaY: Int) throws -> AgentCommand {
        guard (-100_000...100_000).contains(deltaY) else {
            throw CommandError.scrollOutOfRange(deltaY)
        }
        return AgentCommand(op: .scroll, args: ["delta_y": deltaY])
    }

    static func queryElement(selector: String) throws -> AgentCommand {
        try validateSelector(selector)
        return AgentCommand(op: .query_element, args: ["selector": selector])
    }

    static let readPage    = AgentCommand(op: .read_page)
    static let screenshot  = AgentCommand(op: .screenshot)
    static let extractLinks = AgentCommand(op: .extract_links)
    static let back        = AgentCommand(op: .back)
    static let forward     = AgentCommand(op: .forward)
    static let reload      = AgentCommand(op: .reload)

    private static func validateURL(_ url: String) throws {
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme,
              ["http","https","about","data"].contains(scheme) else {
            throw CommandError.invalidURL(url)
        }
    }

    private static func validateSelector(_ selector: String) throws {
        let bytes = selector.utf8.count
        guard bytes >= 1 && bytes <= 2047 else {
            throw CommandError.invalidSelector(bytes: bytes)
        }
    }

    func toRequestBody() -> [String: Any] {
        var body: [String: Any] = ["tool": tool.rawValue, "op": op]
        if !args.isEmpty {
            body["args"] = args.mapValues(\.value)
        }
        return body
    }
}

enum CommandError: LocalizedError {
    case invalidURL(String)
    case invalidSelector(bytes: Int)
    case textTooLong(actual: Int, max: Int)
    case scrollOutOfRange(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):       return "Invalid URL '\(url)' — must use http/https/about/data scheme"
        case .invalidSelector(let b):    return "Selector must be 1-2047 bytes, got \(b)"
        case .textTooLong(let a, let m): return "Text too long: \(a) bytes, max \(m)"
        case .scrollOutOfRange(let d):   return "delta_y \(d) out of range -100000..100000"
        }
    }
}
