import SwiftUI

struct SettingsView: View {
    @AppStorage("hk_base_url") var baseURL: String = "http://localhost:8080"
    @AppStorage("hk_api_key") var apiKey: String = ""
    @AppStorage("dev_mode") var devMode: Bool = false
    @EnvironmentObject var manager: AgentSessionManager

    var body: some View {
        Form {
            Section("HyperKitty Connection") {
                LabeledContent("Base URL") {
                    TextField("http://localhost:8080", text: $baseURL)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 280)
                }
                LabeledContent("API Key") {
                    SecureField("sk-...", text: $apiKey)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 280)
                }
                LabeledContent("Status") {
                    HStack {
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(manager.isConnected ? "Connected" : "Disconnected")
                            .font(.system(.caption, design: .monospaced))
                        Button("Test") { Task { await manager.connect() } }
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }

            Section("Developer") {
                Toggle("Developer Mode", isOn: $devMode)
                if devMode {
                    LabeledContent("WebSocket") {
                        Text(manager.eventStream.connectionState == .connected ? "connected" : "disconnected")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(manager.eventStream.connectionState == .connected ? .green : .red)
                    }
                    LabeledContent("Active Agents") {
                        Text("\(manager.store.agents.count)")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }

            Section("Security") {
                Text("AWS/Bedrock credentials are never stored in this application. Model inference is routed through the SnapKitty API server.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .padding()
        .navigationTitle("Settings")
    }
}
