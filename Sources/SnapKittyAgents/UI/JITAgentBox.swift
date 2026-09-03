// JIT Agent Box — primary interface
// OBJECTIVE → EXECUTE → OBSERVE → CONTROL
// Not a chatbot. A control console.

import SwiftUI

struct JITAgentBox: View {
    @EnvironmentObject var manager: AgentSessionManager
    @State private var objective: String = ""
    @State private var modelName: String = "SnapKitty K1"
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color(hex: "#2a2a45"))

            if let agent = manager.selectedAgent {
                AgentWorkspace(agent: agent)
            } else {
                newAgentForm
            }
        }
        .background(Color(hex: "#0a0a0f"))
        .frame(minWidth: 900, minHeight: 700)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("SNAPKITTY AGENTS")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(Color(hex: "#00ff88"))

            Spacer()

            // Connection badge
            HStack(spacing: 6) {
                Circle()
                    .fill(manager.isConnected ? Color(hex: "#00ff88") : Color(hex: "#ff4444"))
                    .frame(width: 6, height: 6)
                Text(manager.isConnected ? "connected" : "disconnected")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(hex: "#666"))
            }

            if !manager.isConnected {
                Button("Connect") {
                    Task { await manager.connect() }
                }
                .buttonStyle(SKButtonStyle(color: Color(hex: "#00ff88")))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#0f0f1a"))
    }

    // MARK: New agent form

    private var newAgentForm: some View {
        VStack(spacing: 0) {
            SessionPicker()
                .environmentObject(manager)

            Divider().background(Color(hex: "#2a2a45"))

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEW AGENT")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundColor(Color(hex: "#666"))

                    Text("OBJECTIVE")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Color(hex: "#444"))

                    TextEditor(text: $objective)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color(hex: "#ccc"))
                        .background(Color(hex: "#0f0f1a"))
                        .frame(height: 80)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(hex: "#2a2a45"), lineWidth: 1)
                        )

                    if objective.isEmpty {
                        Text("What should this agent do?")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(hex: "#333"))
                            .offset(x: 10, y: -90)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MODEL")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(Color(hex: "#444"))
                        TextField("SnapKitty K1", text: $modelName)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(hex: "#ccc"))
                            .textFieldStyle(.plain)
                            .padding(6)
                            .background(Color(hex: "#0f0f1a"))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#2a2a45")))
                            .frame(width: 180)
                    }

                    Spacer()

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(hex: "#ff4444"))
                    }

                    Button(isCreating ? "Creating..." : "CREATE AGENT") {
                        createAgent()
                    }
                    .buttonStyle(SKButtonStyle(color: Color(hex: "#00ff88")))
                    .disabled(objective.isEmpty || isCreating || !manager.isConnected)
                }
            }
            .padding(24)

            Spacer()
        }
    }

    private func createAgent() {
        errorMessage = nil
        isCreating = true
        Task {
            do {
                _ = try await manager.createJITAgent(objective: objective, modelName: modelName)
                objective = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// MARK: - Agent workspace (active agent)

struct AgentWorkspace: View {
    let agent: Agent
    @EnvironmentObject var manager: AgentSessionManager
    @State private var activeTab: WorkspaceTab = .browser

    enum WorkspaceTab: String, CaseIterable {
        case browser = "Browser"
        case events  = "Events"
        case telemetry = "Telemetry"
    }

    var body: some View {
        HSplitView {
            // Left: browser + tabs
            VStack(spacing: 0) {
                AgentStatusView(agent: agent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#0f0f1a"))
                Divider().background(Color(hex: "#2a2a45"))

                // Tab bar
                HStack(spacing: 0) {
                    ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                        Button(tab.rawValue) { activeTab = tab }
                            .buttonStyle(TabButtonStyle(isActive: activeTab == tab))
                    }
                    Spacer()
                }
                .background(Color(hex: "#0f0f1a"))
                Divider().background(Color(hex: "#2a2a45"))

                // Content
                Group {
                    switch activeTab {
                    case .browser:
                        BrowserPane(agentId: agent.agent_id)
                            .environmentObject(manager)
                    case .events:
                        EventTimeline(agentId: agent.agent_id)
                            .environmentObject(manager)
                    case .telemetry:
                        TelemetryPanel(agentId: agent.agent_id)
                            .environmentObject(manager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().background(Color(hex: "#2a2a45"))
                CommandBar(agentId: agent.agent_id)
                    .environmentObject(manager)
            }
            .frame(minWidth: 580)

            // Right: session picker + objective
            VStack(spacing: 0) {
                SessionPicker()
                    .environmentObject(manager)
                Divider().background(Color(hex: "#2a2a45"))
                if let obj = agent.objective {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OBJECTIVE")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(Color(hex: "#444"))
                        Text(obj.description)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(hex: "#ccc"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                }
                Spacer()
            }
            .frame(width: 260)
            .background(Color(hex: "#0f0f1a"))
        }
    }
}
