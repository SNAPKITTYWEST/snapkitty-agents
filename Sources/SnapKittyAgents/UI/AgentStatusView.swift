import SwiftUI

struct AgentStatusView: View {
    let agent: Agent
    @EnvironmentObject var manager: AgentSessionManager

    var body: some View {
        HStack(spacing: 16) {
            // Agent ID
            VStack(alignment: .leading, spacing: 2) {
                Text("AGENT")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
                Text(agent.displayName)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(Color(hex: "#ccc"))
            }

            // State pill
            statePill

            // Action count
            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIONS")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
                Text("\(agent.action_count)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(hex: "#888"))
            }

            Spacer()

            // Controls
            if !agent.state.isTerminal {
                controlButtons
            } else {
                Button("NEW AGENT") { manager.selectedAgentId = nil }
                    .buttonStyle(SKButtonStyle(color: Color(hex: "#666")))
            }
        }
    }

    private var statePill: some View {
        let color: Color = {
            switch agent.state {
            case .ready:     return Color(hex: "#00ff88")
            case .planning:  return Color(hex: "#00aaff")
            case .executing: return Color(hex: "#ffaa00")
            case .waiting:   return Color(hex: "#ffdd00")
            case .completed: return Color(hex: "#00ff88")
            case .failed:    return Color(hex: "#ff4444")
            case .terminated:return Color(hex: "#666")
            default:         return Color(hex: "#555")
            }
        }()

        return HStack(spacing: 4) {
            if agent.state == .executing {
                Circle().fill(color).frame(width: 6, height: 6)
                    .modifier(PulseModifier())
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(agent.state.displayName)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4)))
        .cornerRadius(10)
    }

    private var controlButtons: some View {
        HStack(spacing: 6) {
            if agent.state == .ready || agent.state == .waiting {
                Button("RUN") {
                    // Run next action via CommandBar
                }
                .buttonStyle(SKButtonStyle(color: Color(hex: "#00ff88")))
            }

            if agent.state.isActive {
                Button("PAUSE") {
                    Task { try? await manager.pauseAgent(agentId: agent.agent_id) }
                }
                .buttonStyle(SKButtonStyle(color: Color(hex: "#ffaa00")))
            }

            Button("STOP") {
                Task { try? await manager.terminateAgent(agentId: agent.agent_id) }
            }
            .buttonStyle(SKButtonStyle(color: Color(hex: "#ff4444")))

            Button("RESET") {
                Task {
                    if let obj = agent.objective?.description {
                        try? await manager.resetAgent(agentId: agent.agent_id, objective: obj)
                    }
                }
            }
            .buttonStyle(SKButtonStyle(color: Color(hex: "#666")))
        }
    }
}

// Pulsing indicator for executing state
struct PulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.6
                }
            }
    }
}
