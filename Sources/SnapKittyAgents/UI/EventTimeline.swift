import SwiftUI

struct EventTimeline: View {
    let agentId: String
    @EnvironmentObject var manager: AgentSessionManager

    var events: [BrowserEvent] {
        manager.store.eventsFor(agentId).reversed()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EVENTS")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
                Spacer()
                Text("\(events.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(hex: "#444"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#0f0f1a"))

            Divider().background(Color(hex: "#2a2a45"))

            if events.isEmpty {
                VStack {
                    Spacer()
                    Text("No events yet")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "#333"))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(events) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
        }
    }
}

struct EventRow: View {
    let event: BrowserEvent
    @State private var expanded = false

    var categoryColor: Color {
        switch event.eventType {
        case .agentActionCompleted: return Color(hex: "#00ff88")
        case .agentActionFailed, .agentFailed: return Color(hex: "#ff4444")
        case .agentActionRejected: return Color(hex: "#ffaa00")
        case .agentCompleted: return Color(hex: "#00ff88")
        case .agentTerminated: return Color(hex: "#666")
        case .agentActionStarted, .agentObjectiveAssigned, .agentCreated: return Color(hex: "#00aaff")
        default: return Color(hex: "#555")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { expanded.toggle() }) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(categoryColor)
                        .frame(width: 2, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.summary)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(hex: "#ccc"))
                            .lineLimit(1)

                        Text(event.category)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#444"))
                    }

                    Spacer()

                    Text(event.emittedAt, style: .time)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#333"))

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#444"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#0a0a0f"))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                // Raw JSON payload
                let json = (try? JSONSerialization.data(withJSONObject: event.data.mapValues(\.value), options: .prettyPrinted))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

                ScrollView(.horizontal) {
                    Text(json)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#888"))
                        .padding(10)
                }
                .background(Color(hex: "#0f0f1a"))
            }
        }
    }
}
