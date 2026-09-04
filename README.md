# SnapKitty Agents

[![License: Tri](https://img.shields.io/badge/license-Sovereign%20Source%20v1.0%20%7C%20BSL--1.1%20%7C%20AGPL--3.0-critical.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014+-blue.svg)](https://www.apple.com/macos/)
[![HyperKitty](https://img.shields.io/badge/HyperKitty-Erlang%20Agent%20Orchestration-red.svg)](#hyperkitty)
[![MiMo-4B](https://img.shields.io/badge/MiMo-4B-Sovereign%20Instruct-76b900.svg)](#mimo-4b-instruct)
[![ERE](https://img.shields.io/badge/ERE-P1--P5%20Gates-purple.svg)](#ere-gates)
[![WORM](https://img.shields.io/badge/WORM-Append--Only%20Chain-blue.svg)](#worm-chain)

> **Sovereign agent orchestration. HyperKitty browser automation. MiMo-4B instruct model. ERE gates + WORM chain. No cloud.**

---

## Architecture

```mermaid
flowchart TD
    subgraph APP["SnapKittyAgents (macOS)"]
        A["SwiftUI App<br/>TabView"] --> B["HyperKitty Client<br/>Erlang Agent FSM"]
        A --> C["MiMo-4B Agent<br/>Ollama Local"]
        A --> D["Event Timeline<br/>WebSocket Stream"]
    end

    subgraph HYPERKITTY["HyperKitty (Erlang)"]
        E["Agent FSM<br/>create → assign → run → complete"]
        F["Browser Sessions<br/>Chromium headless"]
        G["Search Jobs<br/>Multi-iteration crawl"]
        H["Event Stream<br/>ws:// events"]
    end

    subgraph MIMO["Sovereign MiMo-4B"]
        I["Ollama Server<br/>localhost:11434"]
        J["Instruct Model<br/>4B params, local"]
        K["ERE Gates<br/>P1-P5 on every output"]
        L["WORM Chain<br/>SHA-256 audit"]
    end

    B -->|"HTTP + WS"| E
    B --> F
    B --> G
    B --> H
    C -->|"HTTP POST"| I
    I --> J
    J --> K
    K --> L

    style A fill:#2563eb,stroke:#1d4ed8,color:#fff
    style E fill:#dc2626,stroke:#991b1b,color:#fff
    style J fill:#059669,stroke:#047857,color:#fff
    style K fill:#d97706,stroke:#b45309,color:#fff
    style L fill:#6b21a8,stroke:#581c87,color:#fff
```

---

## What This Is

A macOS SwiftUI application that provides:

1. **HyperKitty Agent Orchestration** — Interface with Erlang-based agent FSM for browser automation, search jobs, and multi-step workflows
2. **Sovereign MiMo-4B Instruct** — Local AI assistant running on Ollama, no cloud dependency
3. **Event Timeline** — Real-time WebSocket stream of agent events
4. **ERE Gates** — Five-gate verification on every MiMo output
5. **WORM Chain** — Append-only SHA-256 audit trail

---

## Components

### HyperKitty Client

```mermaid
flowchart LR
    A["createAgent()"] --> B["assignObjective()"]
    B --> C["runAction()"]
    C --> D["completeAgent()"]
    D --> E["terminateAgent()"]

    F["createSession()"] --> G["openTab()"]
    G --> H["navigate()"]
    H --> I["tabAction()"]

    J["startSearch()"] --> K["pollResult()"]

    style A fill:#2563eb,stroke:#1d4ed8,color:#fff
    style F fill:#dc2626,stroke:#991b1b,color:#fff
    style J fill:#059669,stroke:#047857,color:#fff
```

| Endpoint | Description |
|----------|-------------|
| `createAgent(capabilities:)` | Spawn new agent with capabilities |
| `assignObjective(agentId:description:)` | Set agent goal |
| `runAction(agentId:command:)` | Execute agent action |
| `createSession(ownerAgentId:)` | Create browser session |
| `openTab(sessionId:url:)` | Open new tab |
| `startSearch(query:ownerAgentId:maxIterations:)` | Multi-iteration search |
| `eventStream()` | WebSocket event stream |

### MiMo-4B Instruct Agent

```mermaid
flowchart TD
    A["User Prompt"] --> B["PREFLIGHT<br/>SEAL + CHAIN + IDENTITY"]
    B -->|pass| C["Ollama POST<br/>api/generate"]
    C --> D["MiMo-4B Response"]
    D --> E["ERE Gates<br/>P1-P5"]
    E -->|pass| F["WORM Chain<br/>SHA-256 Seal"]
    F --> G["Response"]
    E -->|fail| H["HALT<br/>Violations logged"]

    style B fill:#d97706,stroke:#b45309,color:#fff
    style E fill:#dc2626,stroke:#991b1b,color:#fff
    style H fill:#dc2626,stroke:#991b1b,color:#fff
```

| Feature | Value |
|---------|-------|
| Model | sovereign-mimo-4b (Q4_K_M) |
| Server | Ollama (localhost:11434) |
| Parameters | ~4B |
| Context | 8192 tokens |
| Temperature | 0.7 |
| Top-P | 0.9 |

### ERE Gates

Every MiMo output passes through 5 verification gates:

| Gate | Name | Check | Failure |
|------|------|-------|---------|
| P1 | Secrets | No API keys, tokens, passwords | Output suppressed |
| P2 | Injection | No `eval`, `exec`, `subprocess`, `rm -rf` | Output suppressed |
| P3 | Loop Safety | No `while True` without `break` | Output suppressed |
| P4 | Telemetry | No `fetch`, `XMLHttpRequest`, `sendBeacon` | Output suppressed |
| P5 | Seal | SHA-256 audit seal (agent:intent:output) | Seal not generated |

### WORM Chain

Append-only SHA-256 audit chain. Every entry links to previous hash.

```
Entry[0]: genesis
Entry[1]: seq=1, timestamp, model, prompt_hash, output_hash, verdict, hash_prev=Entry[0].hash
Entry[2]: seq=2, timestamp, model, prompt_hash, output_hash, verdict, hash_prev=Entry[1].hash
...
```

---

## Setup

### Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+ with Swift 5.9
- Ollama installed (`brew install ollama`)
- sovereign-mimo-4b model pulled

### Install Ollama & Model

```bash
# Install Ollama
brew install ollama

# Start Ollama server
ollama serve

# Pull sovereign-mimo-4b
ollama create sovereign-mimo-4b -f /path/to/sovereign-mimo-4b/Modelfile
ollama run sovereign-mimo-4b
```

### Build & Run

```bash
# Clone
git clone https://github.com/SNAPKITTYWEST/snapkitty-agents
cd snapkitty-agents

# Open in Xcode
open Package.swift

# Build
swift build

# Run
swift run SnapKittyAgents
```

---

## Configuration

### HyperKitty

```swift
// Settings → HyperKitty
Base URL: http://localhost:8080
API Key: (optional)
```

### MiMo-4B

```swift
// MiMoConfig.default
Base URL: http://localhost:11434
Model: sovereign-mimo-4b
Max Tokens: 512
Temperature: 0.7
Top-K: 50
Top-P: 0.9
```

---

## Files

```
snapkitty-agents/
├── Package.swift                    # Swift 5.9, macOS 14+
├── Sources/SnapKittyAgents/
│   ├── App/
│   │   └── SnapKittyAgentsApp.swift # Main app, TabView
│   ├── Models/
│   │   ├── Agent.swift              # HyperKitty agent model
│   │   ├── AgentCommand.swift       # Agent commands
│   │   ├── AgentState.swift         # Agent states
│   │   ├── AgentTelemetry.swift     # Telemetry data
│   │   ├── BrowserEvent.swift       # Browser events
│   │   └── MiMoInstructAgent.swift  # Sovereign MiMo-4B agent
│   ├── Networking/
│   │   ├── EventStream.swift        # WebSocket event stream
│   │   └── HyperKittyClient.swift   # HyperKitty HTTP client
│   ├── State/
│   │   ├── AgentSessionManager.swift
│   │   └── AgentStore.swift
│   ├── UI/
│   │   ├── AgentStatusView.swift
│   │   ├── BrowserPane.swift
│   │   ├── CommandBar.swift
│   │   ├── EventTimeline.swift
│   │   ├── JITAgentBox.swift
│   │   ├── MiMoAgentView.swift      # MiMo chat UI
│   │   ├── SessionPicker.swift
│   │   ├── SettingsView.swift
│   │   └── TelemetryPanel.swift
│   └── Utilities/
│       ├── DesignSystem.swift
│       └── Logger.swift
├── Tests/
│   └── SnapKittyAgentsTests/
└── README.md
```

---

## Sovereign Stack

| Component | Source | Pattern |
|-----------|--------|---------|
| HyperKitty | HK API | Erlang agent FSM, browser automation |
| MiMo-4B | sovereign-mimo-4b | Ollama local instruct model |
| ERE Gates | bert-agent | P1-P5 verification, halt on failure |
| WORM Chain | DEVFLOW-FINANCE | Append-only SHA-256 audit chain |
| FSM | DEVFLOW-FINANCE | IDLE → PREFLIGHT → REASONING → SEALING → RESPONDING |

---

## License

Tri-licensed: **Sovereign Source License v1.0** (Bel Esprit d'Accord Trust, 2026-06-01) | **BSL-1.1** (Change Date 2030-06-01 → Apache 2.0) | **AGPL-3.0**.

Copyright (C) 2026 Ahmad Ali Parr <ahmedparr93@gmail.com> / Jessica <jessica@snapkitty.com>
Bel Esprit D'Accord Irrevocable Trust · EIN 42-697643

---

*Built on BBQBADDIE. No cloud. No vendor. Sovereign.*
