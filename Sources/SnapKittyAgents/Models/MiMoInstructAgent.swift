// MiMoInstructAgent.swift
// Sovereign MiMo-4B instruct model agent
// Integrates with local Ollama instance running sovereign-mimo-4b
//
// Sovereign Source License v1.0 + BSL-1.1 + AGPL-3.0
// Copyright (C) 2026 Ahmad Ali Parr / SNAPKITTYWEST

import Foundation

// MARK: - MiMo Agent Configuration

struct MiMoConfig: Codable, Equatable {
    var baseURL: URL
    var model: String
    var maxTokens: Int
    var temperature: Double
    var topK: Int
    var topP: Double
    var systemPrompt: String
    var timeout: TimeInterval

    static let `default` = MiMoConfig(
        baseURL: URL(string: "http://localhost:11434")!,
        model: "sovereign-mimo-4b",
        maxTokens: 512,
        temperature: 0.7,
        topK: 50,
        topP: 0.9,
        systemPrompt: "You are Sovereign MiMo-4B, a sovereign instruct model. Follow instructions precisely. Write code, answer questions, reason through problems.",
        timeout: 60.0
    )
}

// MARK: - MiMo Request/Response

struct MiMoGenerateRequest: Codable {
    let model: String
    let prompt: String
    let system: String?
    let stream: Bool
    let options: MiMoOptions

    struct MiMoOptions: Codable {
        let num_predict: Int
        let temperature: Double
        let top_k: Int
        let top_p: Double
        let repeat_penalty: Double
    }
}

struct MiMoGenerateResponse: Codable {
    let model: String
    let response: String
    let done: Bool
    let context: [Int]?
    let total_duration_ns: Int64?
    let eval_count: Int?
    let eval_duration_ns: Int64?
}

// MARK: - MiMo Agent

final class MiMoInstructAgent: ObservableObject, Identifiable {
    let id = UUID()
    let config: MiMoConfig

    @Published var isConnected: Bool = false
    @Published var isGenerating: Bool = false
    @Published var lastResponse: String = ""
    @Published var lastError: String?
    @Published var generationCount: Int = 0
    @Published var totalLatencyMs: Double = 0

    private let session: URLSession
    private var平均LatencyMs: Double { generationCount > 0 ? totalLatencyMs / Double(generationCount) : 0 }

    init(config: MiMoConfig = .default) {
        self.config = config
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = config.timeout
        self.session = URLSession(configuration: c)
    }

    // MARK: - Health Check

    func checkHealth() async -> Bool {
        guard let url = URL(string: "api/tags", relativeTo: config.baseURL) else { return false }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = decoded?["models"] as? [[String: Any]] ?? []
            let found = models.contains { ($0["name"] as? String ?? "").contains(config.model) }
            await MainActor.run { isConnected = found }
            return found
        } catch {
            await MainActor.run { isConnected = false }
            return false
        }
    }

    // MARK: - Generate

    func generate(prompt: String, system: String? = nil) async -> String {
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }

        let body = MiMoGenerateRequest(
            model: config.model,
            prompt: prompt,
            system: system ?? config.systemPrompt,
            stream: false,
            options: MiMoGenerateRequest.MiMoOptions(
                num_predict: config.maxTokens,
                temperature: config.temperature,
                top_k: config.topK,
                top_p: config.topP,
                repeat_penalty: 1.1
            )
        )

        guard let url = URL(string: "api/generate", relativeTo: config.baseURL) else {
            await MainActor.run {
                isGenerating = false
                lastError = "Invalid URL"
            }
            return ""
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        let start = Date()

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let msg = String(data: data, encoding: .utf8) ?? "unknown"
                await MainActor.run {
                    isGenerating = false
                    lastError = "HTTP \(code): \(msg)"
                }
                return ""
            }

            let decoded = try JSONDecoder().decode(MiMoGenerateResponse.self, from: data)
            let latency = Date().timeIntervalSince(start) * 1000

            await MainActor.run {
                lastResponse = decoded.response
                isGenerating = false
                generationCount += 1
                totalLatencyMs += latency
            }

            return decoded.response
        } catch {
            await MainActor.run {
                isGenerating = false
                lastError = error.localizedDescription
            }
            return ""
        }
    }

    // MARK: - Generate with ERE Gates

    func generateWithERE(prompt: String) async -> MiMoResult {
        let response = await generate(prompt: prompt)

        // ERE gate checks
        var violations: [String] = []

        // P1: No secrets
        let secretPatterns = ["sk-", "api_key", "token:", "password:", "secret:", "bearer "]
        for pat in secretPatterns {
            if response.localizedCaseInsensitiveContains(pat) {
                violations.append("P1: secret pattern")
                break
            }
        }

        // P2: No injection
        let injectionPatterns = ["eval(", "exec(", "__import__", "subprocess", "os.system", "rm -rf"]
        for pat in injectionPatterns {
            if response.localizedCaseInsensitiveContains(pat) {
                violations.append("P2: injection pattern")
                break
            }
        }

        // P3: Loop safety
        if response.contains("while True") && !response.contains("break") {
            violations.append("P3: unsafe loop")
        }

        // P4: No telemetry
        let telemetryPatterns = ["fetch(", "XMLHttpRequest", "sendBeacon"]
        for pat in telemetryPatterns {
            if response.localizedCaseInsensitiveContains(pat) {
                violations.append("P4: telemetry beacon")
                break
            }
        }

        let passed = violations.isEmpty
        let seal = passed ? sha256("\(config.model):\(prompt):\(response)") : ""

        return MiMoResult(
            text: response,
            erePassed: passed,
            violations: violations,
            seal: seal,
            model: config.model
        )
    }

    // MARK: - SHA-256

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - MiMo Result

struct MiMoResult {
    let text: String
    let erePassed: Bool
    let violations: [String]
    let seal: String
    let model: String

    var verdict: String {
        if !erePassed { return "ERE_HALT" }
        return "GENERATED"
    }
}

import CommonCrypto
