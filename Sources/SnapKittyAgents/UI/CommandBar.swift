import SwiftUI

struct CommandBar: View {
    let agentId: String
    @EnvironmentObject var manager: AgentSessionManager
    @State private var input: String = ""
    @State private var opMode: CommandMode = .navigate
    @State private var isRunning: Bool = false
    @State private var lastResult: String?

    enum CommandMode: String, CaseIterable {
        case navigate = "NAVIGATE"
        case read = "READ"
        case screenshot = "SHOT"
        case click = "CLICK"
        case type_ = "TYPE"
        case scroll = "SCROLL"
        case extract = "LINKS"
        case back = "←"
        case forward = "→"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let result = lastResult {
                HStack {
                    Text(result)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Color(hex: "#888"))
                        .lineLimit(1)
                    Spacer()
                    Button("✕") { lastResult = nil }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(hex: "#444"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(hex: "#0f0f1a"))
                Divider().background(Color(hex: "#2a2a45"))
            }

            HStack(spacing: 6) {
                // Mode selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(CommandMode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) { opMode = mode }
                                .buttonStyle(TabButtonStyle(isActive: opMode == mode))
                        }
                    }
                }
                .frame(maxWidth: 340)

                // Input
                if needsInput {
                    TextField(placeholder, text: $input)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "#ccc"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#0a0a0f"))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "#2a2a45")))
                        .onSubmit { runCommand() }
                }

                Spacer()

                Button(isRunning ? "..." : "RUN") { runCommand() }
                    .buttonStyle(SKButtonStyle(color: Color(hex: "#00ff88")))
                    .disabled(isRunning || (needsInput && input.isEmpty))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#0a0a0f"))
        }
    }

    private var needsInput: Bool {
        switch opMode {
        case .navigate, .click, .type_, .scroll: return true
        default: return false
        }
    }

    private var placeholder: String {
        switch opMode {
        case .navigate: return "https://..."
        case .click:    return "CSS selector"
        case .type_:    return "selector:text"
        case .scroll:   return "delta_y (e.g. 500)"
        default:        return ""
        }
    }

    private func runCommand() {
        guard let agent = manager.store.agents[agentId] else { return }
        isRunning = true
        lastResult = nil

        Task {
            do {
                let command = try buildCommand()
                let op = try await manager.runAction(agentId: agentId, command: command)
                lastResult = "✓ \(op.status.rawValue)"
            } catch {
                lastResult = "✗ \(error.localizedDescription)"
            }
            isRunning = false
        }
    }

    private func buildCommand() throws -> AgentCommand {
        switch opMode {
        case .navigate:
            return try AgentCommand.navigate(url: input)
        case .read:
            return .readPage
        case .screenshot:
            return .screenshot
        case .click:
            return try AgentCommand.click(selector: input)
        case .type_:
            let parts = input.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { throw CommandError.invalidSelector(bytes: 0) }
            return try AgentCommand.type_(selector: parts[0], text: parts[1])
        case .scroll:
            let delta = Int(input) ?? 0
            return try AgentCommand.scroll(deltaY: delta)
        case .extract:
            return .extractLinks
        case .back:
            return .back
        case .forward:
            return .forward
        }
    }
}
