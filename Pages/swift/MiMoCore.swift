// MiMoCore.swift
// SwiftWasm module for sovereign-mimo-4b chat portal
// ERE gates + WORM chain in pure Swift
//
// Build: swift build --target MiMoCore -Xswiftc -Xwasm
// Output: .build/wasm32-unknown-wasi/MiMoCore.wasm
//
// Sovereign Source License v1.0 + BSL-1.1 + AGPL-3.0
// Copyright (C) 2026 Ahmad Ali Parr / SNAPKITTYWEST

import Foundation

// MARK: - ERE Gate Protocol

struct EREGateResult {
    let p1Secrets: Bool
    let p2Injection: Bool
    let p3Loop: Bool
    let p4Telemetry: Bool
    let p5Seal: String
    let passed: Bool
    let violations: [String]
}

func ereCheck(agentId: String, intent: String, output: String) -> EREGateResult {
    var violations: [String] = []

    // P1: No secrets
    let secretPatterns = ["sk-", "api_key", "token:", "password:", "secret:", "bearer "]
    for pat in secretPatterns {
        if output.lowercased().contains(pat) {
            violations.append("P1: secret pattern")
            break
        }
    }

    // P2: No injection
    let injectionPatterns = ["eval(", "exec(", "__import__", "subprocess", "os.system", "rm -rf"]
    for pat in injectionPatterns {
        if output.lowercased().contains(pat) {
            violations.append("P2: injection pattern")
            break
        }
    }

    // P3: Loop safety
    if output.contains("while True") && !output.contains("break") {
        violations.append("P3: unsafe loop")
    }

    // P4: No telemetry
    let telemetryPatterns = ["fetch(", "XMLHttpRequest", "sendBeacon"]
    for pat in telemetryPatterns {
        if output.lowercased().contains(pat) {
            violations.append("P4: telemetry beacon")
            break
        }
    }

    let passed = violations.isEmpty
    let seal = passed ? sha256("\(agentId):\(intent):\(output)") : ""

    return EREGateResult(
        p1Secrets: !violations.contains(where: { $0.hasPrefix("P1") }),
        p2Injection: !violations.contains(where: { $0.hasPrefix("P2") }),
        p3Loop: !violations.contains(where: { $0.hasPrefix("P3") }),
        p4Telemetry: !violations.contains(where: { $0.hasPrefix("P4") }),
        p5Seal: seal,
        passed: passed,
        violations: violations
    )
}

// MARK: - WORM Chain

struct WormEntry: Codable {
    let seq: Int
    let timestamp: String
    let agentId: String
    let intentHash: String
    let outputHash: String
    let verdict: String
    let hashPrev: String
    let hashSelf: String
    let ereSeal: String
}

class WORMChain {
    private(set) var entries: [WormEntry] = []
    private var lastHash = "genesis"

    func append(agentId: String, intent: String, output: String, verdict: String, ereSeal: String) -> WormEntry {
        let seq = entries.count
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let intentHash = sha256(intent)
        let outputHash = sha256(output)

        let payload = "\(seq):\(timestamp):\(agentId):\(intentHash):\(outputHash):\(verdict):\(lastHash)"
        let hashSelf = sha256(payload)

        let entry = WormEntry(
            seq: seq,
            timestamp: timestamp,
            agentId: agentId,
            intentHash: intentHash,
            outputHash: outputHash,
            verdict: verdict,
            hashPrev: lastHash,
            hashSelf: hashSelf,
            ereSeal: ereSeal
        )

        entries.append(entry)
        lastHash = hashSelf
        return entry
    }

    func verify() -> Bool {
        var prev = "genesis"
        for entry in entries {
            guard entry.hashPrev == prev else { return false }
            let payload = "\(entry.seq):\(entry.timestamp):\(entry.agentId):\(entry.intentHash):\(entry.outputHash):\(entry.verdict):\(entry.hashPrev)"
            guard entry.hashSelf == sha256(payload) else { return false }
            prev = entry.hashSelf
        }
        return true
    }
}

// MARK: - SHA-256

func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    var hash = [UInt8](repeating: 0, count: 32)
    data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
    return hash.map { String(format: "%02x", $0) }.joined()
}

// MARK: - WASM Exports

@_cdecl("ere_check")
func ereCheckExport(agentId: UnsafePointer<CChar>, intent: UnsafePointer<CChar>, output: UnsafePointer<CChar>) -> UnsafePointer<CChar>? {
    let aId = String(cString: agentId)
    let intentStr = String(cString: intent)
    let outputStr = String(cString: output)

    let result = ereCheck(agentId: aId, intent: intentStr, output: outputStr)
    let json = """
    {"passed":\(result.passed),"violations":\(result.violations),"seal":"\(result.p5Seal)"}
    """

    return json.withCString { strdup($0) }
}

@_cdecl("worm_append")
func wormAppend(agentId: UnsafePointer<CChar>, intent: UnsafePointer<CChar>, output: UnsafePointer<CChar>, verdict: UnsafePointer<CChar>, ereSeal: UnsafePointer<CChar>) -> UnsafePointer<CChar>? {
    static let chain = WORMChain()

    let aId = String(cString: agentId)
    let intentStr = String(cString: intent)
    let outputStr = String(cString: output)
    let verdictStr = String(cString: verdict)
    let seal = String(cString: ereSeal)

    let entry = chain.append(agentId: aId, intent: intentStr, output: outputStr, verdict: verdictStr, ereSeal: seal)

    let json = """
    {"seq":\(entry.seq),"hash":"\(entry.hashSelf)","verdict":"\(entry.verdict)"}
    """

    return json.withCString { strdup($0) }
}

@_cdecl("worm_verify")
func wormVerify() -> Bool {
    static let chain = WORMChain()
    return chain.verify()
}

@_cdecl("free_string")
func freeString(_ ptr: UnsafeMutablePointer<CChar>?) {
    ptr?.deallocate()
}
