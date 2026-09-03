import SwiftUI

@main
struct SnapKittyAgentsApp: App {
    @AppStorage("hk_base_url") var baseURL: String = "http://localhost:8080"
    @AppStorage("hk_api_key") var apiKey: String = ""

    @StateObject private var manager: AgentSessionManager

    init() {
        let base = UserDefaults.standard.string(forKey: "hk_base_url") ?? "http://localhost:8080"
        let key  = UserDefaults.standard.string(forKey: "hk_api_key")
        var config = HyperKittyConfig.localhost()
        if let url = URL(string: base) {
            let wsURL = URL(string: base.replacingOccurrences(of: "http", with: "ws") + "/api/events/stream")
                ?? URL(string: "ws://localhost:8080/api/events/stream")!
            config = HyperKittyConfig(baseURL: url, apiKey: key, eventStreamURL: wsURL)
        }
        _manager = StateObject(wrappedValue: AgentSessionManager(config: config))
    }

    var body: some Scene {
        WindowGroup {
            JITAgentBox()
                .environmentObject(manager)
                .preferredColorScheme(.dark)
                .onAppear {
                    Task { await manager.connect() }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
                .environmentObject(manager)
        }
    }
}
