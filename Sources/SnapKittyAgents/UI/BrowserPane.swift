import SwiftUI
import WebKit

// BrowserPane — visual representation of the browser session
// WKWebView mirrors what HyperKitty Chromium is doing — it is NOT the execution backend.
// Backend remains responsible for actual agent browser execution.

struct BrowserPane: View {
    let agentId: String
    @EnvironmentObject var manager: AgentSessionManager

    var currentURL: String? {
        manager.store.telemetry[agentId]?.currentURL
    }
    var currentTitle: String? {
        manager.store.telemetry[agentId]?.currentTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            // URL bar (read-only display of what HyperKitty is doing)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#444"))
                    Text(currentURL ?? "about:blank")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "#888"))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#0a0a0f"))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#2a2a45")))
                .frame(maxWidth: .infinity)

                Text("PREVIEW")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
                    .padding(.horizontal, 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#0f0f1a"))

            Divider().background(Color(hex: "#2a2a45"))

            // WebView mirror
            if let urlString = currentURL, let url = URL(string: urlString) {
                BrowserMirrorView(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "#222"))
            Text("No active browser session")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(hex: "#333"))
            Text("Run a NAVIGATE command to see the browser state")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color(hex: "#222"))
            Spacer()
        }
    }
}

// WKWebView wrapper — display mirror only, not execution backend
struct BrowserMirrorView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }
}
