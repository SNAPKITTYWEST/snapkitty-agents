import SwiftUI

struct TelemetryPanel: View {
    let agentId: String
    @EnvironmentObject var manager: AgentSessionManager

    var telemetry: AgentTelemetry? {
        manager.store.telemetryFor(agentId)
    }
    var agent: Agent? {
        manager.store.agents[agentId]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                group("IDENTITY") {
                    row("Agent ID", agentId)
                    row("Model", telemetry?.modelName ?? "—")
                    row("Session ID", telemetry?.sessionId ?? "—")
                    row("State", agent?.state.displayName ?? "—")
                }

                group("EXECUTION") {
                    row("Current URL", telemetry?.currentURL ?? "—")
                    row("Page Title", telemetry?.currentTitle ?? "—")
                    row("Action Count", "\(agent?.action_count ?? 0)")
                    row("Elapsed", telemetry?.elapsedFormatted ?? "—")
                }

                group("EVENTS") {
                    row("Total Events", "\(telemetry?.eventCount ?? 0)")
                    row("Error Count", "\(telemetry?.errorCount ?? 0)")
                    row("Last Event", telemetry?.lastEvent?.category ?? "—")
                    row("Last Command", telemetry?.lastCommand?.op ?? "—")
                }

                group("LIMITS") {
                    if let limits = agent?.limits {
                        row("Max Actions", "\(limits.max_actions)")
                        row("Max Runtime", "\(limits.max_execution_ms / 1000)s")
                        row("Max Network", "\(limits.max_network_requests)")
                        row("Max Search", "\(limits.max_search_iterations)")
                    }
                }

                if let agent, agent.state == .failed, let reason = agent.failure_reason {
                    group("FAILURE") {
                        row("Reason", reason)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(hex: "#0a0a0f"))
    }

    @ViewBuilder
    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "#444"))
                .padding(.top, 16)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(hex: "#0f0f1a"))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#2a2a45")))
            .cornerRadius(4)
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(hex: "#555"))
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(hex: "#aaa"))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        Divider().background(Color(hex: "#1a1a2a"))
    }
}
