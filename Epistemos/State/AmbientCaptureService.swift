import AppKit
import CryptoKit
import Foundation
import os
import Vision

// MARK: - Ambient Cross-App Capture Service
// Captures selective semantic artifacts from other apps on frontmost-app change.
// Event-driven via NSWorkspace notification — zero overhead when idle.
// AX reads happen on main thread (required by Accessibility API), then
// hashing/redaction/storage dispatched to actor's serial context.
//
// Config is read LIVE at each capture decision point via @MainActor hop,
// so toggling the setting in Cognitive Settings takes effect immediately.

actor AmbientCaptureService {
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "AmbientCapture")
    nonisolated private static let startupWarmupInterval: TimeInterval = 1.0

    private let config: EpistemosConfig
    private let screen2AXFusion: Screen2AXFusion
    private var debounceTask: Task<Void, Never>?
    private var lastCaptureHash: [String: String] = [:]  // bundleId → last hash
    private nonisolated(unsafe) var observer: NSObjectProtocol?
    private var startupWarmupStartedAt: Date?

    init(config: EpistemosConfig, screen2AXFusion: Screen2AXFusion) {
        self.config = config
        self.screen2AXFusion = screen2AXFusion
    }

    // MARK: - Config Reads (hop to MainActor for @Observable properties)

    private func readConfig() async -> (enabled: Bool, ocrFallback: Bool, blocked: Set<String>, allowed: Set<String>) {
        await MainActor.run {
            (config.captureEnabled, config.ocrFallbackEnabled,
             Set(config.blocklist), Set(config.allowlist))
        }
    }

    // MARK: - Lifecycle

    /// Always registers the observer. Config is checked live at each activation.
    func start() {
        guard observer == nil else { return }
        startupWarmupStartedAt = Date()
        let obs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier,
                  let appName = app.localizedName else { return }
            let pid = app.processIdentifier
            Task { [weak self] in
                await self?.handleActivation(pid: pid, bundleId: bundleId, appName: appName)
            }
        }
        observer = obs
        Self.log.info("AmbientCapture: observer registered")
    }

    func stop() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
        debounceTask?.cancel()
        debounceTask = nil
    }

    // MARK: - Capture Pipeline

    private func handleActivation(pid: pid_t, bundleId: String, appName: String) {
        // Don't capture our own app
        guard bundleId != Bundle.main.bundleIdentifier else { return }
        if let startupWarmupStartedAt {
            guard Self.shouldProcessActivationDuringStartupWarmup(
                startedAt: startupWarmupStartedAt,
                now: Date()
            ) else {
                return
            }
            self.startupWarmupStartedAt = nil
        }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await performCapture(pid: pid, bundleId: bundleId, appName: appName)
        }
    }

    private func performCapture(pid: pid_t, bundleId: String, appName: String) async {
        // Read config LIVE — toggling capture off in Settings stops captures immediately
        let cfg = await readConfig()
        guard cfg.enabled else { return }

        // Check allow/blocklist
        if cfg.blocked.contains(bundleId) { return }
        if !cfg.allowed.isEmpty && !cfg.allowed.contains(bundleId) { return }

        // AX tree read on main thread (required by AX API)
        let perception = await MainActor.run {
            screen2AXFusion.perceiveQuick(pid: pid)
        }

        var text = extractTextFromAXTree(perception.axTreeJson)
        var ocrUsed = false

        // Fall back to OCR if AX sparse and setting enabled
        if text.count < 20 && cfg.ocrFallback {
            let ocrPerception = await screen2AXFusion.perceive(appName: appName)
            if !ocrPerception.ocrTexts.isEmpty {
                text = ocrPerception.ocrTexts.map(\.text).joined(separator: " ")
                ocrUsed = true
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return }

        let redacted = Self.redactSecrets(trimmed)
        let hash = Self.stableHash(bundleId + redacted)

        if lastCaptureHash[bundleId] == hash { return }
        lastCaptureHash[bundleId] = hash

        let artifact = CapturedArtifact(
            sourceBundleId: bundleId,
            appName: appName,
            textContent: redacted,
            capturedAt: Date().timeIntervalSince1970,
            dedupeHash: hash,
            ocrUsed: ocrUsed
        )
        Task { @MainActor in
            EventStore.shared?.insertCapturedArtifact(artifact)
        }
        Self.log.debug("AmbientCapture: captured artifact from \(appName, privacy: .public) (ocr=\(ocrUsed))")
    }

    // MARK: - Text Extraction

    private nonisolated func extractTextFromAXTree(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let tree = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = tree["elements"] as? [[String: Any]] else {
            return ""
        }

        var texts: [String] = []
        if let windowTitle = tree["title"] as? String, !windowTitle.isEmpty {
            texts.append(windowTitle)
        }

        for element in elements {
            if let value = element["value"] as? String, !value.isEmpty {
                texts.append(value)
            } else if let title = element["title"] as? String, !title.isEmpty {
                texts.append(title)
            } else if let desc = element["description"] as? String, !desc.isEmpty {
                texts.append(desc)
            }
        }
        let joined = texts.joined(separator: " ")
        return joined.count > 2000 ? String(joined.prefix(2000)) : joined
    }

    // MARK: - Secret Redaction

    nonisolated static let secretPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?i)(api[_-]?key|token|password|secret|bearer)\s*[:=]\s*\S+"#,
            #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#,
            #"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#,
            #"\b\d{3}-\d{2}-\d{4}\b"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    nonisolated static func redactSecrets(_ text: String) -> String {
        var result = text
        for regex in secretPatterns {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "[REDACTED]"
            )
        }
        return result
    }

    // MARK: - Hashing

    nonisolated static func stableHash(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private nonisolated static func shouldProcessActivationDuringStartupWarmup(
        startedAt: Date,
        now: Date
    ) -> Bool {
        now.timeIntervalSince(startedAt) >= startupWarmupInterval
    }

    nonisolated static func shouldProcessActivationDuringStartupWarmupForTesting(
        startedAt: Date,
        now: Date
    ) -> Bool {
        shouldProcessActivationDuringStartupWarmup(startedAt: startedAt, now: now)
    }
}
