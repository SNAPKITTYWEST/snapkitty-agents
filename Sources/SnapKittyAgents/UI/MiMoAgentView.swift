// MiMoAgentView.swift
// SwiftUI view for sovereign-mimo-4b instruct agent
//
// Sovereign Source License v1.0 + BSL-1.1 + AGPL-3.0
// Copyright (C) 2026 Ahmad Ali Parr / SNAPKITTYWEST

import SwiftUI

struct MiMoAgentView: View {
    @StateObject private var agent: MiMoInstructAgent
    @State private var prompt: String = ""
    @State private var conversation: [ChatMessage] = []
    @State private var isCheckingHealth: Bool = false

    init(config: MiMoConfig = .default) {
        _agent = StateObject(wrappedValue: MiMoInstructAgent(config: config))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Connection status
            if isCheckingHealth {
                ProgressView("Checking connection...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if !agent.isConnected {
                notConnectedView
            }

            // Conversation
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversation) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: conversation.count) { _ in
                    withAnimation {
                        proxy.scrollTo(conversation.last?.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            inputBar
        }
        .frame(minWidth: 500, minHeight: 600)
        .task { await checkHealth() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sovereign MiMo-4B")
                    .font(.headline)
                Text("Instruct Model · Local · Sovereign")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Label(systemStatus, systemImage: agent.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(agent.isConnected ? .green : .red)
                    .font(.caption)

                if agent.generationCount > 0 {
                    Label("\(agent.generationCount) gen", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: { Task { await checkHealth() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }

    private var systemStatus: String {
        agent.isConnected ? "Connected" : "Disconnected"
    }

    // MARK: - Not Connected

    private var notConnectedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundColor(.orange)
            Text("Ollama not running or model not found")
                .font(.caption)
            Text("Start Ollama and pull sovereign-mimo-4b:")
                .font(.caption2)
                .foregroundColor(.secondary)
            CodeBlock(text: "ollama create sovereign-mimo-4b -f Modelfile\nollama run sovereign-mimo-4b")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask MiMo anything...", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit { send() }

            Button(action: send) {
                if agent.isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agent.isGenerating)
        }
        .padding()
    }

    // MARK: - Actions

    private func send() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        conversation.append(ChatMessage(role: .user, text: text))
        prompt = ""

        Task {
            let result = await agent.generateWithERE(prompt: text)

            await MainActor.run {
                let role: ChatMessage.Role = result.erePassed ? .assistant : .system
                let displayText = result.erePassed
                    ? result.text
                    : "ERE HALT: \(result.violations.joined(separator: ", "))"
                conversation.append(ChatMessage(role: role, text: displayText))
            }
        }
    }

    private func checkHealth() async {
        isCheckingHealth = true
        _ = await agent.checkHealth()
        isCheckingHealth = false
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()

    enum Role {
        case user
        case assistant
        case system
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(bubbleColor)
                    .foregroundColor(bubbleTextColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return Color(.controlBackgroundColor)
        case .system: return .red.opacity(0.2)
        }
    }

    private var bubbleTextColor: Color {
        switch message.role {
        case .user: return .white
        case .assistant: return .primary
        case .system: return .red
        }
    }
}

// MARK: - Code Block

struct CodeBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Preview

#Preview {
    MiMoAgentView()
}
