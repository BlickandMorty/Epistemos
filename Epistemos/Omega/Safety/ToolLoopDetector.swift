import Foundation
import CryptoKit
import os

private let loopLog = Logger(subsystem: "com.epistemos", category: "ToolLoopDetector")

// MARK: - Tool Loop Detector
// Detects 4 types of infinite execution loops:
//   1. Generic Repeat — same tool+args hash seen N times
//   2. Poll No Progress — same tool repeatedly returns identical output
//   3. Ping-Pong — two tools alternating without state change
//   4. Global Circuit Breaker — total tool calls exceed hard cap
//
// Ported from OpenClaw's loop-detection patterns. Operates on AgentStep
// argument hashes so it works with both Omega and LocalAgent agent paths.

struct LoopDetectorRecord: Sendable {
    let toolName: String
    let argsHash: String
    let outputHash: String
    let timestamp: Date
}

@MainActor
final class ToolLoopDetector {

    // MARK: - Configuration

    struct Config: Sendable {
        /// Max times the same tool+args can repeat before aborting.
        var genericRepeatThreshold: Int = 4
        /// Max times the same tool can return identical output.
        var pollNoProgressThreshold: Int = 3
        /// Max alternating pair cycles (A→B→A→B) before aborting.
        var pingPongThreshold: Int = 3
        /// Absolute max tool calls per session.
        var globalCircuitBreakerLimit: Int = 200
    }

    enum LoopType: String, Sendable {
        case genericRepeat = "generic_repeat"
        case pollNoProgress = "poll_no_progress"
        case pingPong = "ping_pong"
        case globalCircuitBreaker = "global_circuit_breaker"
    }

    struct LoopDetection: Sendable {
        let type: LoopType
        let toolName: String
        let count: Int
        let message: String
    }

    // MARK: - State

    private var history: [LoopDetectorRecord] = []
    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    func reset() {
        history.removeAll()
    }

    var totalCalls: Int { history.count }

    // MARK: - Record & Check

    /// Record a tool call and check for loops. Returns a detection if a loop is found.
    func record(
        toolName: String,
        argumentsJson: String,
        outputJson: String
    ) -> LoopDetection? {
        let argsHash = sha256(argumentsJson)
        let outputHash = sha256(outputJson)

        let record = LoopDetectorRecord(
            toolName: toolName,
            argsHash: argsHash,
            outputHash: outputHash,
            timestamp: Date()
        )
        history.append(record)

        // Check in order of severity
        if let detection = checkGlobalCircuitBreaker() {
            loopLog.warning("Loop detected: \(detection.message)")
            return detection
        }
        if let detection = checkGenericRepeat(toolName: toolName, argsHash: argsHash) {
            loopLog.warning("Loop detected: \(detection.message)")
            return detection
        }
        if let detection = checkPollNoProgress(toolName: toolName, outputHash: outputHash) {
            loopLog.warning("Loop detected: \(detection.message)")
            return detection
        }
        if let detection = checkPingPong() {
            loopLog.warning("Loop detected: \(detection.message)")
            return detection
        }

        return nil
    }

    // MARK: - Detection Algorithms

    /// 1. Same tool + same args repeated N times
    private func checkGenericRepeat(toolName: String, argsHash: String) -> LoopDetection? {
        let recentCount = history.suffix(config.genericRepeatThreshold * 2)
            .filter { $0.toolName == toolName && $0.argsHash == argsHash }
            .count

        guard recentCount >= config.genericRepeatThreshold else { return nil }
        return LoopDetection(
            type: .genericRepeat,
            toolName: toolName,
            count: recentCount,
            message: "Tool '\(toolName)' called \(recentCount) times with identical arguments"
        )
    }

    /// 2. Same tool returns identical output N times (poll with no progress)
    private func checkPollNoProgress(toolName: String, outputHash: String) -> LoopDetection? {
        let recentSameTool = history.suffix(config.pollNoProgressThreshold * 2)
            .filter { $0.toolName == toolName }

        let identicalOutputCount = recentSameTool
            .filter { $0.outputHash == outputHash }
            .count

        guard identicalOutputCount >= config.pollNoProgressThreshold else { return nil }
        return LoopDetection(
            type: .pollNoProgress,
            toolName: toolName,
            count: identicalOutputCount,
            message: "Tool '\(toolName)' returned identical output \(identicalOutputCount) times"
        )
    }

    /// 3. Two tools alternating: A→B→A→B→A→B
    private func checkPingPong() -> LoopDetection? {
        let minEntries = config.pingPongThreshold * 2
        guard history.count >= minEntries else { return nil }

        let recent = history.suffix(minEntries)
        let tools: [String] = recent.map(\.toolName)

        // Check if it's strictly alternating between exactly 2 tools
        let uniqueTools = Set(tools)
        guard uniqueTools.count == 2 else { return nil }

        let toolArray = Array(uniqueTools)
        let expected = (0..<minEntries).map { toolArray[$0 % 2] }
        let expectedReversed = (0..<minEntries).map { toolArray[($0 + 1) % 2] }

        let isAlternating = Array(tools) == expected || Array(tools) == expectedReversed
        guard isAlternating else { return nil }

        return LoopDetection(
            type: .pingPong,
            toolName: "\(toolArray[0]) ↔ \(toolArray[1])",
            count: config.pingPongThreshold,
            message: "Ping-pong detected: '\(toolArray[0])' and '\(toolArray[1])' alternating \(config.pingPongThreshold) times"
        )
    }

    /// 4. Total calls exceed hard cap
    private func checkGlobalCircuitBreaker() -> LoopDetection? {
        guard history.count >= config.globalCircuitBreakerLimit else { return nil }
        return LoopDetection(
            type: .globalCircuitBreaker,
            toolName: "all",
            count: history.count,
            message: "Global circuit breaker: \(history.count) tool calls exceed limit of \(config.globalCircuitBreakerLimit)"
        )
    }

    // MARK: - Hashing

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
