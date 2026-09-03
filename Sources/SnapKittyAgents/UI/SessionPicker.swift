import SwiftUI

struct SessionPicker: View {
    @EnvironmentObject var manager: AgentSessionManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AGENTS")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
                Spacer()
                Button("+ NEW") { manager.selectedAgentId = nil }
                    .buttonStyle(SKButtonStyle(color: Color(hex: "#444")))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if manager.allAgents.isEmpty {
                Text("No agents")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(hex: "#333"))
                    .padding(12)
            } else {
                ForEach(manager.allAgents) { agent in
                    AgentListRow(agent: agent,
                                 isSelected: manager.selectedAgentId == agent.agent_id)
                        .onTapGesture { manager.selectedAgentId = agent.agent_id }
                }
            }
        }
    }
}

struct AgentListRow: View {
    let agent: Agent
    let isSelected: Bool

    var stateColor: Color {
        switch agent.state {
        case .executing: return Color(hex: "#ffaa00")
        case .ready, .completed: return Color(hex: "#00ff88")
        case .failed, .terminated: return Color(hex: "#ff4444")
        default: return Color(hex: "#555")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(stateColor).frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(isSelected ? Color(hex: "#00ff88") : Color(hex: "#ccc"))
                Text(agent.objective?.description ?? "no objective")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
                    .lineLimit(1)
            }

            Spacer()

            Text(agent.state.rawValue)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(stateColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Color(hex: "#00ff88").opacity(0.05) : Color.clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? Color(hex: "#00ff88") : Color.clear)
                .frame(width: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        )
        .contentShape(Rectangle())
    }
}
