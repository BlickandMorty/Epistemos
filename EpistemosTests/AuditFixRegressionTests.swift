import Foundation
import Testing
@testable import Epistemos

@Suite("Audit Fix Regression")
struct AuditFixRegressionTests {
    @Test("vault registry exposes the shared helpers required by vault services")
    func vaultRegistryExposesSharedHelpers() throws {
        let registry = try loadAuditSource("Epistemos/Vault/VaultRegistry.swift")

        #expect(registry.contains("static let shared = VaultRegistry()"))
        #expect(registry.contains("func resolveVaultPath(for identity: VaultIdentity) -> String?"))
    }

    @Test("code editor stays editor-only and drops inline assistant chrome")
    func codeEditorStaysEditorOnlyAndDropsInlineAssistantChrome() throws {
        let source = try loadAuditSource("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains(".onDisappear {"))
        #expect(!source.contains("AIPartnerService("))
        #expect(!source.contains("CodeAskBarService("))
        #expect(!source.contains("InlineSuggestionOverlay("))
    }

    @Test("agent tool approvals route through SwiftUI queue instead of NSAlert")
    func agentToolApprovalsRouteThroughSwiftUIQueueInsteadOfNSAlert() throws {
        let approvalModal = try loadAuditSource("Epistemos/Views/Approval/ApprovalModalView.swift")
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")
        let environment = try loadAuditSource("Epistemos/App/AppEnvironment.swift")
        let app = try loadAuditSource("Epistemos/App/EpistemosApp.swift")

        #expect(approvalModal.contains("enum ChatApprovalResolution"))
        #expect(approvalModal.contains("@MainActor @Observable"))
        #expect(approvalModal.contains("final class ChatApprovalQueue"))
        #expect(approvalModal.contains("var pendingApproval: ApprovalModalView.PendingApproval?"))
        #expect(approvalModal.contains("func enqueue("))
        #expect(approvalModal.contains("withCheckedContinuation"))
        #expect(approvalModal.contains("func resolve("))
        #expect(approvalModal.contains("case applyLessInterruptions"))
        #expect(approvalModal.contains("ApprovalAuditDiagnostics.externalLogMessage"))
        #expect(!approvalModal.contains("error.localizedDescription"))
        #expect(!approvalModal.contains("String(describing: error)"))

        #expect(bootstrap.contains("let chatApprovalQueue = ChatApprovalQueue()"))
        #expect(environment.contains(".environment(bootstrap.chatApprovalQueue)"))
        #expect(app.contains("Binding<ApprovalModalView.PendingApproval?>"))
        #expect(app.contains("bootstrap.chatApprovalQueue.pendingApproval"))
        #expect(app.contains("bootstrap.chatApprovalQueue.resolve"))
        #expect(app.contains(".interactiveDismissDisabled(true)"))
    }

    @MainActor
    @Test("chat approval queue resolves modal decisions without hanging continuations")
    func chatApprovalQueueResolvesModalDecisions() async throws {
        let queue = ChatApprovalQueue()

        let first = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-a",
                toolName: "shell.execute",
                argsJSON: "{}",
                deadline: Date().addingTimeInterval(60),
                summary: nil,
                authorityCategoryLabel: nil
            )
        }
        let firstApproval = try await nextPendingApproval(from: queue)
        queue.resolve(firstApproval, decision: .applyLessInterruptions)
        #expect(await first.value == .applyLessInterruptions)
        #expect(queue.pendingApproval == nil)

        let timeout = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-b",
                toolName: "file.write",
                argsJSON: "{}",
                deadline: Date(),
                summary: nil,
                authorityCategoryLabel: nil
            )
        }
        let timeoutApproval = try await nextPendingApproval(from: queue)
        queue.resolve(timeoutApproval, decision: .timedOut)
        #expect(await timeout.value == .deny)

        let held = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-c",
                toolName: "browser.click",
                argsJSON: "{}",
                deadline: Date().addingTimeInterval(60),
                summary: nil,
                authorityCategoryLabel: nil
            )
        }
        let heldApproval = try await nextPendingApproval(from: queue)
        let overlapping = await queue.enqueue(
            sessionId: "session-d",
            toolName: "browser.type",
            argsJSON: "{}",
            deadline: Date().addingTimeInterval(60),
            summary: nil,
            authorityCategoryLabel: nil
        )
        #expect(overlapping == .deny)
        queue.resolve(heldApproval, decision: .approveOnce)
        #expect(await held.value == .allowOnce)
    }

    @MainActor
    @Test("CONC-4: an unresolved approval times out view-independently (no modal render)")
    func chatApprovalQueueTimesOutWithoutModalRender() async throws {
        let queue = ChatApprovalQueue()
        // Enqueue with a short deadline; call NO resolve() and render NO modal/TimelineView.
        // Only the view-independent deadline task can end this — the old code, whose only
        // timeout lived in the on-screen TimelineView, would hang the continuation forever.
        let result = await queue.enqueue(
            sessionId: "session-view-independent-timeout",
            toolName: "shell.execute",
            argsJSON: "{}",
            deadline: Date().addingTimeInterval(0.3),
            summary: nil,
            authorityCategoryLabel: nil
        )
        #expect(result == .deny)          // timedOut resolves to .deny
        #expect(queue.pendingApproval == nil)
    }

    @MainActor
    @Test("chat approval queue dedupes approved args and appends audit JSONL")
    func chatApprovalQueueDedupesApprovedArgsAndAppendsAuditJSONL() async throws {
        let queue = ChatApprovalQueue()
        let sessionFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosApprovalQueue-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: sessionFolder) }
        queue.auditLogDirectoryOverride = sessionFolder

        let argsJSON = #"{"command":"pwd"}"#
        let first = Task { @MainActor in
            await queue.enqueue(
                sessionId: "session-audit",
                toolName: "shell.execute",
                argsJSON: argsJSON,
                deadline: Date().addingTimeInterval(60),
                summary: "List the working directory.",
                authorityCategoryLabel: "Shell"
            )
        }
        let firstApproval = try await nextPendingApproval(from: queue)
        queue.resolve(firstApproval, decision: .approveOnce)
        #expect(await first.value == .allowOnce)

        let duplicate = await queue.enqueue(
            sessionId: "session-audit",
            toolName: "shell.execute",
            argsJSON: argsJSON,
            deadline: Date().addingTimeInterval(60),
            summary: "List the working directory again.",
            authorityCategoryLabel: "Shell"
        )
        #expect(duplicate == .allowOnce)
        #expect(queue.pendingApproval == nil)

        let entries = try ChatApprovalAuditLog.entries(in: sessionFolder)
        let argsHash = ChatApprovalQueue.dedupHash(toolName: "shell.execute", argsJSON: argsJSON)
        #expect(entries.contains { $0.eventKind == "prompt_shown" && $0.argsHash == argsHash })
        #expect(entries.contains { $0.eventKind == "user_resolved" && $0.resolution == "allow_once" })
        #expect(entries.contains { $0.eventKind == "dedup_short_circuit" && $0.argsHash == argsHash })
    }

    @Test("approval audit diagnostics redact external errors")
    func approvalAuditDiagnosticsRedactExternalErrors() throws {
        let message = ApprovalAuditDiagnostics.externalLogMessage(
            "approval audit append failed",
            error: NSError(
                domain: "/Users/jojo/PrivateVault/audit.swift",
                code: 13,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not append /Users/jojo/PrivateVault/approval.jsonl"
                ]
            )
        )

        #expect(message.contains("approval audit append failed"))
        #expect(message.contains("code=13"))
        #expect(message.count <= ApprovalAuditDiagnostics.maxLogMessageCharacters)
        for forbidden in [
            "/Users/jojo",
            "PrivateVault",
            "audit.swift",
            "approval.jsonl",
        ] {
            #expect(!message.contains(forbidden))
        }

        let source = try loadAuditSource("Epistemos/Views/Approval/ApprovalModalView.swift")
        #expect(source.contains("String(message.prefix(maxLogMessageCharacters + 32))"))
        #expect(source.contains("String(domain.prefix(maxDomainCharacters + 32))"))
    }

    @Test("managed tools use an application-support scratch vault instead of crashing when no vault is attached")
    func managedToolsUseApplicationSupportScratchVaultWhenNoVaultIsAttached() throws {
        let bridge = try loadAuditSource("Epistemos/Bridge/ToolTierBridge.swift")
        let extensions = try loadAuditSource("Epistemos/Engine/Extensions.swift")

        #expect(extensions.contains("managedToolRuntimeVaultDirectory"))
        #expect(extensions.contains("ManagedToolRuntime"))
        #expect(extensions.contains("ScratchVault"))
        #expect(bridge.contains("FoundationSafety.managedToolRuntimeVaultDirectory"))
    }

    @Test("session context preview opens the vault read-only so tool runs do not trip an index writer lock")
    func sessionContextPreviewOpensTheVaultReadOnlySoToolRunsDoNotTripAnIndexWriterLock() throws {
        let bridge = try loadAuditSource("agent_core/src/bridge.rs")
        let vault = try loadAuditSource("agent_core/src/storage/vault.rs")
        let commandCenter = try loadAuditSource("agent_core/src/command_center.rs")

        #expect(bridge.contains("VaultStore::open_read_only(&vault_path)"))
        #expect(vault.contains("pub fn open_read_only(vault_root: &str) -> Result<Self, VaultError>"))
        #expect(commandCenter.contains("VaultStore::open_read_only(vault_path)"))
    }

    @Test("embedded rust dylibs still ad hoc sign when hosted tests disable app signing")
    func embeddedRustDylibsStillAdHocSignWithoutAppSigning() throws {
        let helper = try loadAuditSource("embed-and-sign-rust-dylib.sh")

        #expect(helper.contains("if [ \"${CODE_SIGNING_ALLOWED:-NO}\" != \"YES\" ]; then"))
        #expect(helper.contains("codesign --force --sign - --timestamp=none \"$DEST_DYLIB\""))
    }

    @Test("model profile creation sheet avoids retired Hermes local labels")
    func modelProfileCreationSheetAvoidsRetiredHermesLabels() throws {
        let source = try loadAuditSource("Epistemos/State/InferenceState.swift")
        let displayNames = try auditSourceSlice(
            source,
            from: "var displayName: String {",
            to: "var compactDisplayName: String {"
        )

        // Cloud-only removal (2026-07-03, owner-approved): the entire local-model
        // display-name catalog was deleted from InferenceState, so NO local labels
        // survive — retired or otherwise. (Was: Hermes/Gemma retired, Qwen/Ternary kept;
        // all local models are now gone, so every local label must be absent.)
        #expect(!displayNames.contains("Hermes 3 8B"))
        #expect(!displayNames.contains("Gemma 4 4B"))
        #expect(!displayNames.contains("Qwen 3 4B"))
        #expect(!displayNames.contains("Ternary Bonsai 4B"))
    }

    @Test("release archive no longer strips linked agent dylibs or disables agent services")
    func releaseArchiveKeepsLinkedAgentDylibsAndServices() throws {
        let spec = try loadAuditSource("project.yml")
        let bootstrap = try loadAuditSource("Epistemos/App/AppBootstrap.swift")

        #expect(spec.contains(#"bash \"${SRCROOT}/build-rust.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-syntax-core.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-omega-mcp.sh\""#))  // tool bus — KEPT
        // build-omega-ax.sh removed with the Omega/computer-use lane (cloud-only, 2026-07-03).
        #expect(spec.contains(#"bash \"${SRCROOT}/build-epistemos-core.sh\""#))
        #expect(spec.contains(#"bash \"${SRCROOT}/build-agent-core.sh\""#))
        #expect(!spec.contains("SHIP_MODE=release"))
        #expect(!spec.contains("skipping agent crates"))
        #expect(bootstrap.contains("static let agentsEnabled = true"))
        #expect(!bootstrap.contains("static let agentsEnabled = false"))
    }

    @Test("inference state skips blocking keychain warmup while hosted tests boot")
    func inferenceStateSkipsBlockingKeychainWarmupDuringTests() throws {
        let source = try loadAuditSource("Epistemos/State/InferenceState.swift")

        #expect(source.contains("private nonisolated static let isRunningTests"))
        #expect(source.contains("private nonisolated static func defaultKeychainLoad"))
        #expect(source.contains("private nonisolated static func defaultKeychainSave"))
        #expect(source.contains("private nonisolated static func defaultKeychainDelete"))
        #expect(source.contains("guard !isRunningTests else { return nil }"))
        #expect(source.contains("guard !isRunningTests else { return false }"))
        #expect(source.contains("keychainLoad: @escaping (String) -> String? = InferenceState.defaultKeychainLoad"))
    }

    @MainActor
    @Test("session graph generation decodes the current Rust session graph payload")
    func sessionGraphGenerationDecodesCurrentRustSessionGraphPayload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionFolder = root.appendingPathComponent("session_knowledge_graph", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "".write(
            to: sessionFolder.appendingPathComponent("transcript.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        try """
        # Summary

        ## Key Decisions
        Keep the release build fail-closed.
        """.write(
            to: sessionFolder.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )

        let graphJSON = try generate_session_graph(sessionFolder: sessionFolder.path)
        let graphData = try decodeGraphData(from: Data(graphJSON.utf8))

        #expect(graphData.nodes.contains(where: { $0.id == "session_session_knowledge_graph" }))
    }

    @Test("retired vault lifecycle graph maintenance service remains physically absent")
    func retiredVaultLifecycleGraphMaintenanceServiceRemainsPhysicallyAbsent() {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Epistemos/Vault/VaultLifecycleService.swift")

        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
    }
}

private func loadAuditSource(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

private func auditSourceSlice(_ source: String, from startMarker: String, to endMarker: String) throws -> String {
    let start = try #require(source.range(of: startMarker))
    let tail = source[start.lowerBound...]
    let end = try #require(tail.range(of: endMarker))
    return String(tail[..<end.lowerBound])
}

@MainActor
private func nextPendingApproval(
    from queue: ChatApprovalQueue
) async throws -> ApprovalModalView.PendingApproval {
    for _ in 0..<100 {
        if let pendingApproval = queue.pendingApproval {
            return pendingApproval
        }
        await Task.yield()
    }
    throw ChatApprovalQueueTestError.pendingApprovalNeverArrived
}

private enum ChatApprovalQueueTestError: Error {
    case pendingApprovalNeverArrived
}
