import Foundation
import Security

// Phase-0 spike B harness (Plan 1-MAS §7 / §11 R2): one REAL agent_core turn
// through the UniFFI surface the app uses — runAgentSession + the full
// AgentEventDelegate vocabulary — against a libagent_core built with the MAS
// feature set (--no-default-features --features mas-build,lsp-runtime).
//
// Proves: Swift ↔ UniFFI ↔ tokio loop ↔ streaming delegate, with every
// callback hopping to the main queue via DispatchQueue.main.async (the
// standing FFI threading rule — never .sync), and text/thinking deltas
// arriving live.
//
// The provider key is read from the macOS Keychain AT RUNTIME (same
// service/account the app uses) and scoped into the process environment for
// the single call — it is never printed, logged, or persisted. Driven by
// scripts/agent-core-mas-spike.sh; compiled together with the generated
// build-rust/swift-bindings/agent_core.swift.

func keychainString(service: String, account: String) -> String? {
    for useDataProtection in [false, true] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if useDataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8),
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

final class SpikeDelegate: AgentEventDelegate, @unchecked Sendable {
    // Mutated ONLY on the main queue — every callback hops there first.
    var textDeltas = 0
    var thinkingDeltas = 0
    var toolStarts = 0
    var turnStarts = 0
    var completions: [String] = []
    var errorMessages: [String] = []
    var hopSawMainThread = true
    var textPreview = ""

    private func hop(_ body: @escaping @Sendable () -> Void) {
        DispatchQueue.main.async { [self] in
            if !Thread.isMainThread { hopSawMainThread = false }
            body()
        }
    }

    func onThinkingDelta(thought: String) {
        hop { [self] in
            thinkingDeltas += 1
            if thinkingDeltas == 1 { print("SPIKE-EVENT first_thinking_delta") }
        }
    }

    func onTextDelta(delta: String) {
        hop { [self] in
            textDeltas += 1
            if textDeltas == 1 { print("SPIKE-EVENT first_text_delta") }
            if textPreview.count < 200 { textPreview += delta }
        }
    }

    func onToolInputDelta(index: UInt32, partialJson: String) {}

    func onToolStarted(toolUseId: String, name: String, inputJson: String) {
        hop { [self] in
            toolStarts += 1
            print("SPIKE-EVENT tool_started name=\(name)")
        }
    }

    func onToolCompleted(toolUseId: String, result: String, isError: Bool) {}

    func onSubagentSpawned(agentId: String, role: String) {}

    func onPermissionRequired(permissionId: String, toolName: String, inputJson: String, riskLevel: String) {
        hop {
            print("SPIKE-EVENT permission_required tool=\(toolName) risk=\(riskLevel)")
        }
    }

    func onContextCompacting(currentTokens: UInt32) {}

    func onContextCompacted(newMessageCount: UInt32) {}

    func onTurnStarted(turnNumber: UInt32, messageCount: UInt32) {
        hop { [self] in
            turnStarts += 1
            print("SPIKE-EVENT turn_started n=\(turnNumber) messages=\(messageCount)")
        }
    }

    func onComplete(stopReason: String, inputTokens: UInt32, outputTokens: UInt32) {
        hop { [self] in
            completions.append(stopReason)
            print("SPIKE-EVENT complete stop=\(stopReason) in=\(inputTokens) out=\(outputTokens)")
        }
    }

    func onError(message: String) {
        hop { [self] in
            errorMessages.append(message)
            print("SPIKE-EVENT error \(message.prefix(240))")
        }
    }

    // Service callbacks (Rust → Swift, synchronous). None of these fire for a
    // plain Q&A objective with the MAS tool allowlist; benign stubs keep the
    // spike honest about what it exercises.
    func executeComputerAction(actionJson: String) -> String { "{\"error\":\"unsupported in spike\"}" }
    func waitForPermission(permissionId: String) -> Bool { true }
    func askUserQuestion(questionJson: String) -> String { "{\"answer\":\"\"}" }
    func perceiveApp(appName: String, depth: String) -> String { "{\"error\":\"unsupported in spike\"}" }
    func interactWithApp(actionJson: String) -> String { "{\"error\":\"unsupported in spike\"}" }
    func startScreenWatch(watchJson: String) -> String { "{\"error\":\"unsupported in spike\"}" }
    func manageSsmState(actionJson: String) -> String { "{\"error\":\"unsupported in spike\"}" }
    func generateConstrained(prompt: String, grammarJson: String) -> String { "" }
    func generateImage(prompt: String, aspectRatio: String) -> String { "{\"error\":\"unsupported in spike\"}" }
    func triggerNightbrainJob(jobType: String, priority: String) -> String { "{\"job_id\":\"\",\"status\":\"skipped\"}" }
    func getPartnerContext(noteId: String, cursorOffset: UInt32) -> String { "{}" }
}

let providerName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "claude_sonnet"

guard let apiKey = keychainString(service: "app.epistemos", account: "epistemos.anthropic.apiKey") else {
    print("SPIKE-FAIL keychain key epistemos.anthropic.apiKey unavailable")
    exit(1)
}
// Scoped like AppBootstrap.withScopedAgentCoreEnvironment: set for the run only.
setenv("ANTHROPIC_API_KEY", apiKey, 1)

// Tiny scratch vault: session startup indexes the vault path recursively, so
// pointing it at $HOME crawls the entire home directory (measured via
// `sample`: minutes of stat/readdir — the same latent risk exists in
// GooseMASAgentCoreRunner.defaultVaultPath and must be fixed in Surface B
// wiring by always passing the real, bounded vault directory).
let scratchVault = FileManager.default.temporaryDirectory
    .appendingPathComponent("mas-spike-vault-\(UUID().uuidString.prefix(6))", isDirectory: true)
try? FileManager.default.createDirectory(at: scratchVault, withIntermediateDirectories: true)
try? "MAS spike scratch vault.\n".write(
    to: scratchVault.appendingPathComponent("readme.md"),
    atomically: true,
    encoding: .utf8
)

// Same MAS-bounded tool surface as GooseMASAgentCoreRunner.
let toolConfig = ToolConfig(
    vaultPath: scratchVault.path,
    enableBash: false,
    enableWebSearch: true,
    toolTier: "agent",
    allowedToolNames: [
        "vault.search", "vault.read", "vault.write", "vault.list",
        "knowledge.recall", "web.search", "web.fetch", "http_fetch", "think",
    ]
)
let agentConfig = AgentConfigFfi(
    maxTurns: 4,
    maxOutputTokens: 400,
    contextThreshold: 120_000,
    enableThinking: true,
    effort: "high",
    systemPrompt: nil,
    autoApproveReads: false,
    autoApproveWrites: false,
    promptMode: "general",
    maxCostUsd: nil
)

let delegate = SpikeDelegate()
let sessionID = "mas-spike-\(UUID().uuidString.prefix(8))"
let objective = "Compute 17 multiplied by 23. Think it through briefly, then reply with only the final number."

print("SPIKE start provider=\(providerName) session=\(sessionID)")

let watchdog = Task {
    try? await Task.sleep(nanoseconds: 75_000_000_000)
    if Task.isCancelled { return }
    await MainActor.run {
        print("SPIKE-FAIL timeout after 75s — state at timeout: text=\(delegate.textDeltas) thinking=\(delegate.thinkingDeltas) turns=\(delegate.turnStarts) tools=\(delegate.toolStarts) errors=\(delegate.errorMessages.count)")
        exit(3)
    }
}

do {
    let result = try await runAgentSession(
        sessionId: sessionID,
        objective: objective,
        providerName: providerName,
        toolConfig: toolConfig,
        agentConfig: agentConfig,
        delegate: delegate
    )
    watchdog.cancel()
    unsetenv("ANTHROPIC_API_KEY")
    print("SPIKE-RESULT turns=\(result.turns) in=\(result.inputTokens) out=\(result.outputTokens) cache_read=\(result.cacheReadInputTokens)")
} catch {
    watchdog.cancel()
    unsetenv("ANTHROPIC_API_KEY")
    print("SPIKE-FAIL run error=\(error)")
    exit(1)
}

// The main queue is FIFO: this block runs after every earlier callback hop.
await MainActor.run {
    let preview = delegate.textPreview.replacingOccurrences(of: "\n", with: " ")
    print("SPIKE-PROOF text_deltas=\(delegate.textDeltas) thinking_deltas=\(delegate.thinkingDeltas) turn_starts=\(delegate.turnStarts) tool_starts=\(delegate.toolStarts) complete=\(delegate.completions.joined(separator: ",")) main_hop=\(delegate.hopSawMainThread ? 1 : 0) errors=\(delegate.errorMessages.count)")
    print("SPIKE-PREVIEW \(preview.prefix(160))")
    let pass = delegate.textDeltas > 0 && !delegate.completions.isEmpty && delegate.errorMessages.isEmpty
    exit(pass ? 0 : 1)
}
