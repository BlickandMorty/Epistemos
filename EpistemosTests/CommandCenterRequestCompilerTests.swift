import Foundation
import Testing
@testable import Epistemos

// MARK: - Command Center Request Compiler Contract Tests
//
// These tests pin the Phase 5 authority contract:
//   - @ mentions must compile into real ResolvedContextRef values (not just chips)
//   - notesContext must be populated when a mention resolves to a vault note body
//   - requested brain/runtime must be preserved alongside the resolved runtime
//   - runtime fallbacks must emit a fallbackReason
//   - tool permissions must be resolved against the full Rust catalog
//   - the compiled request must round-trip through JSON (Rust port surface)
//
// The compiler is dependency-injected, so these tests run without a real
// VaultSyncService / InferenceState / UniFFI bridge.

@MainActor
struct CommandCenterRequestCompilerTests {

    // MARK: - Fixtures

    private static func makeCompiler(
        noteLookup: [String: VaultManifest.ManifestEntry] = [:],
        noteBodies: [String: VaultManifest.NoteBody] = [:],
        brains: [ACCBrainSelection] = [.appleIntelligence],
        preferredAutoBrain: ACCBrainSelection? = nil,
        vaultPath: String = ""
    ) -> CommandCenterRequestCompiler {
        // `vaultPath` defaults to empty — Rust responds with an empty
        // catalog and synthesized `tool_catalog_unavailable` deny entries
        // for every user-toggled tool. Tests that need a populated Rust
        // tool catalog must supply a real vault path so Rust can construct
        // a `ToolRegistry`. Tool-permission semantics are primarily
        // covered by the Rust-side unit tests in
        // `agent_core/src/command_center.rs` — the Swift tests here focus
        // on mention resolution, brain fallback, and JSON round-trip
        // contract stability.
        let deps = CommandCenterRequestCompiler.Dependencies(
            findNotesByTitle: { title in
                if let match = noteLookup[title] { return [match] }
                return []
            },
            fetchNoteBodies: { ids in
                ids.compactMap { noteBodies[$0] }
            },
            searchIndex: { _ in [] },
            availableBrains: { brains },
            preferredAutoBrain: { preferredAutoBrain },
            vaultPath: { vaultPath }
        )
        return CommandCenterRequestCompiler(dependencies: deps)
    }

    private static func makeManifestEntry(
        pageId: String,
        title: String,
        wordCount: Int = 500,
        snippet: String = "stub snippet"
    ) -> VaultManifest.ManifestEntry {
        VaultManifest.ManifestEntry(
            pageId: pageId,
            title: title,
            tags: [],
            folderName: nil,
            wordCount: wordCount,
            snippet: snippet,
            updatedAt: Date(),
            createdAt: Date()
        )
    }

    private static func makeNoteBody(
        pageId: String,
        title: String,
        body: String
    ) -> VaultManifest.NoteBody {
        VaultManifest.NoteBody(pageId: pageId, title: title, body: body)
    }

    private static func makeTool(name: String, agent: String = "notes") -> OmegaToolDefinition {
        OmegaToolDefinition(
            name: name,
            agent: agent,
            description: "test tool \(name)",
            argumentsExample: "{}",
            schemaJson: "{}",
            destructive: false,
            requiresConfirmation: false
        )
    }

    private static func makeRequest(
        query: String = "summarize this",
        mentions: [ACCContextMention] = [],
        tools: Set<String> = [],
        brain: ACCBrainSelection? = nil,
        mode: EpistemosOperatingMode = .agent,
        slash: ParsedSlashToken? = nil,
        graphContext: GraphChatRequest? = nil
    ) -> ACCCommandRequest {
        ACCCommandRequest(
            query: query,
            slashToken: slash,
            mentions: mentions,
            enabledToolNames: tools,
            brainOverride: brain,
            operatingMode: mode,
            graphContext: graphContext
        )
    }

    // MARK: - Mention Resolution

    @Test("@-mention of a vault note resolves into a ResolvedContextRef.note with the real body")
    func mentionResolvesToNoteBody() async throws {
        let entry = Self.makeManifestEntry(pageId: "p1", title: "Project Alpha")
        let body = Self.makeNoteBody(pageId: "p1", title: "Project Alpha", body: "The alpha project ships in Q3.")
        let compiler = Self.makeCompiler(
            noteLookup: ["Project Alpha": entry],
            noteBodies: ["p1": body]
        )
        let mention = ACCContextMention(
            id: "note:Project Alpha",
            token: "Project Alpha",
            resolvedLabel: "Project Alpha",
            mentionType: .openNote
        )
        let compiled = await compiler.compile(
            request: Self.makeRequest(query: "Summarize @[Project Alpha]", mentions: [mention]),
            conversationHistory: nil
        )

        #expect(compiled.resolvedContextRefs.count == 1)
        guard case .note(let id, let title, _, let resolvedBody, _) = compiled.resolvedContextRefs[0] else {
            Issue.record("Expected .note ref, got \(compiled.resolvedContextRefs[0])")
            return
        }
        #expect(id == "p1")
        #expect(title == "Project Alpha")
        #expect(resolvedBody == "The alpha project ships in Q3.")
        // notesContext must be non-nil and include the resolved body so it
        // reaches the model — not just the chip label.
        #expect(compiled.notesContext != nil)
        #expect(compiled.notesContext?.contains("The alpha project ships in Q3.") == true)
    }

    @Test("@-mention for a missing note compiles to .unresolved with a reason, not a crash")
    func unresolvableMentionBecomesUnresolved() async throws {
        let compiler = Self.makeCompiler()
        let mention = ACCContextMention(
            id: "note:Ghost Note",
            token: "Ghost Note",
            resolvedLabel: "Ghost Note",
            mentionType: .openNote
        )
        let compiled = await compiler.compile(
            request: Self.makeRequest(mentions: [mention]),
            conversationHistory: nil
        )

        #expect(compiled.resolvedContextRefs.count == 1)
        guard case .unresolved(let token, let reason) = compiled.resolvedContextRefs[0] else {
            Issue.record("Expected .unresolved ref, got \(compiled.resolvedContextRefs[0])")
            return
        }
        #expect(token == "Ghost Note")
        #expect(!reason.isEmpty)
        #expect(compiled.unresolvedMentions == ["Ghost Note"])
        // No real note body → no notesContext block.
        #expect(compiled.notesContext == nil)
    }

    @Test("agent, vault, graph, and folder mentions compile to their scoped ref variants")
    func scopeMentionsCompileToScopedRefs() async throws {
        let compiler = Self.makeCompiler()
        let mentions: [ACCContextMention] = [
            ACCContextMention(id: "agent:safari", token: "Safari", resolvedLabel: "Safari", mentionType: .agent),
            ACCContextMention(id: "vault:all", token: "AllNotes", resolvedLabel: "AllNotes", mentionType: .vault),
            ACCContextMention(id: "vault:graph", token: "CurrentGraph", resolvedLabel: "CurrentGraph", mentionType: .graph),
            ACCContextMention(id: "folder:work", token: "work", resolvedLabel: "work", mentionType: .folder),
        ]
        let compiled = await compiler.compile(
            request: Self.makeRequest(mentions: mentions),
            conversationHistory: nil
        )

        #expect(compiled.resolvedContextRefs.count == 4)
        #expect(compiled.resolvedContextRefs.contains {
            if case .agentTarget(let id, _) = $0, id == "safari" { return true }
            return false
        })
        #expect(compiled.resolvedContextRefs.contains {
            if case .vaultScope(.allNotes, _) = $0 { return true }
            return false
        })
        #expect(compiled.resolvedContextRefs.contains {
            if case .graphScope = $0 { return true }
            return false
        })
        #expect(compiled.resolvedContextRefs.contains {
            if case .folderScope(let folder, _) = $0, folder == "work" { return true }
            return false
        })
    }

    // MARK: - Requested vs Resolved Runtime

    @Test("requested brain that is available is preserved with no fallback reason")
    func requestedBrainHonoredWhenAvailable() async throws {
        let requested: ACCBrainSelection = .local(
            modelId: "qwen35_4b",
            displayName: "Qwen 3.5 4B",
            supportsThinking: true,
            supportsVision: false,
            supportsTools: true
        )
        let compiler = Self.makeCompiler(brains: [requested, .appleIntelligence])
        let compiled = await compiler.compile(
            request: Self.makeRequest(brain: requested),
            conversationHistory: nil
        )

        #expect(compiled.resolvedRuntime.fallbackReason == nil)
        guard case .local(let modelId, _) = compiled.resolvedRuntime.resolved else {
            Issue.record("Expected .local resolved runtime, got \(compiled.resolvedRuntime.resolved)")
            return
        }
        #expect(modelId == "qwen35_4b")
    }

    @Test("requested brain that is unavailable stays explicit and surfaces unavailable truth instead of silently rerouting")
    func requestedBrainUnavailableStaysExplicit() async throws {
        let requested: ACCBrainSelection = .local(
            modelId: "nonexistent",
            displayName: "Nonexistent Model",
            supportsThinking: false,
            supportsVision: false,
            supportsTools: false
        )
        let compiler = Self.makeCompiler(brains: [.appleIntelligence])
        let compiled = await compiler.compile(
            request: Self.makeRequest(brain: requested),
            conversationHistory: nil
        )

        #expect(compiled.resolvedRuntime.fallbackReason == "requested_brain_unavailable")
        #expect(compiled.resolvedRuntime.requested?.displayName == "Nonexistent Model")
        if case .unavailable(let reason) = compiled.resolvedRuntime.resolved {
            #expect(reason == "requested_brain_unavailable")
        } else {
            Issue.record("Expected .unavailable for an unavailable explicit brain, got \(compiled.resolvedRuntime.resolved)")
        }
    }

    @Test("auto runtime preview prefers the injected current brain before falling back to the first available brain")
    func autoRuntimePreviewUsesPreferredBrain() async throws {
        let preferred: ACCBrainSelection = .cloud(provider: .anthropic)
        let compiled = await Self.makeCompiler(
            brains: [
                .local(
                    modelId: "mlx-community/Qwen3.5-4B-4bit",
                    displayName: "Qwen 3.5 4B",
                    supportsThinking: true,
                    supportsVision: false,
                    supportsTools: true
                ),
                .appleIntelligence,
                preferred,
            ],
            preferredAutoBrain: preferred
        ).compile(
            request: Self.makeRequest(brain: nil),
            conversationHistory: nil
        )

        #expect(compiled.resolvedRuntime.fallbackReason == nil)
        #expect(compiled.resolvedRuntime.requested == nil)
        #expect(compiled.resolvedRuntime.resolved == .cloud(provider: CloudModelProvider.anthropic.rawValue, displayName: CloudModelProvider.anthropic.displayName))
    }

    @Test("no requested brain + no available brains yields .unavailable, not a crash")
    func noBrainsYieldsUnavailable() async throws {
        let compiler = Self.makeCompiler(brains: [])
        let compiled = await compiler.compile(
            request: Self.makeRequest(brain: nil),
            conversationHistory: nil
        )

        if case .unavailable(let reason) = compiled.resolvedRuntime.resolved {
            #expect(reason == "no_brains_available")
        } else {
            Issue.record("Expected .unavailable, got \(compiled.resolvedRuntime.resolved)")
        }
    }

    // MARK: - Tool Permission Resolution
    //
    // The detailed allow/deny matrix over a populated Rust catalog is
    // covered by the Rust-side unit tests in
    // `agent_core/src/command_center.rs`. The Swift-side tests below
    // exercise the fail-closed path (empty vault → synthesized deny
    // entries with a truthful reason) and the end-to-end JSON round-trip.

    @Test("Rust synthesizes explicit deny entries for user-toggled tools when the vault path is unavailable")
    func toolPermissionsFailClosedWithoutVault() async throws {
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(tools: ["vault.read", "web.search"]),
            conversationHistory: nil
        )

        // With no vault path, Rust's `ToolRegistry` cannot be built and the
        // catalog is empty. Every user-toggled tool must surface as an
        // explicit deny entry with reason `tool_catalog_unavailable` so
        // the inspector can show that the user asked for something that
        // could not be satisfied — no silent drops, no fake successes.
        #expect(compiled.allowedToolNames.isEmpty)
        #expect(compiled.resolvedToolPermissions.count == 2)
        for perm in compiled.resolvedToolPermissions {
            if case .deny(let reason) = perm.decision {
                #expect(reason == "tool_catalog_unavailable")
            } else {
                Issue.record("Expected deny decision for \(perm.toolName), got \(perm.decision)")
            }
        }
        // User intent is preserved verbatim in requestedToolNames, independent
        // of the catalog — this is what a future run with a populated vault
        // will re-evaluate against the real Rust registry.
        #expect(compiled.requestedToolNames == ["vault.read", "web.search"])
    }

    // MARK: - Round-trip / Contract Envelope

    @Test("CompiledCommandCenterRequest round-trips through JSON encoding")
    func compiledRequestRoundTripsThroughJSON() async throws {
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(
                query: "hello world",
                tools: ["vault.read"],
                brain: .appleIntelligence
            ),
            conversationHistory: "prior turn"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(compiled)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CompiledCommandCenterRequest.self, from: data)

        #expect(decoded.query == compiled.query)
        #expect(decoded.contractVersion == CommandCenterRequestCompiler.contractVersion)
        #expect(decoded.conversationHistory == "prior turn")
        #expect(decoded.allowedToolNames == compiled.allowedToolNames)
        #expect(decoded.resolvedRuntime.resolved == compiled.resolvedRuntime.resolved)
    }

    @Test("contract version is v1 and compiled requests stamp it explicitly")
    func contractVersionStamped() async throws {
        #expect(CommandCenterRequestCompiler.contractVersion == "v1")
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(),
            conversationHistory: nil
        )
        #expect(compiled.contractVersion == "v1")
    }

    // MARK: - Execution Policy

    @Test("compiled request surfaces the resolved execution policy (route, budgets, experts)")
    func executionPolicyIsResolved() async throws {
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(mode: .agent),
            conversationHistory: nil
        )

        let policy = compiled.resolvedExecutionPolicy
        #expect(policy.requestedOperatingMode == .agent)
        #expect(!policy.summary.isEmpty)
        // All depth budget fields must be present (not zero by default)
        // except for routes that legitimately allow zero tool calls.
        #expect(policy.maxTurns > 0)
        #expect(policy.maxOutputTokens > 0)
        #expect(!policy.route.isEmpty)
    }

    // MARK: - P1: allowlist plumbing (Phase 5 runtime authority)

    @Test("allowedToolNames stays in lockstep with the .allow decisions in resolvedToolPermissions")
    func allowedToolNamesMatchesAllowDecisions() async throws {
        // The `allowedToolNames` computed property must always equal the
        // set of tool names with `.allow` decisions — that invariant is
        // the single source of truth for what will reach Rust's
        // ToolConfig.allowedToolNames field on execution. This test pins
        // the invariant without pinning any specific tool name, so it
        // survives both the empty-catalog branch (Swift tests) and the
        // populated-catalog branch (exercised via the Rust-side tests).
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(tools: ["vault.read", "run_command"]),
            conversationHistory: nil
        )
        let allowDecisions = compiled.resolvedToolPermissions.filter {
            $0.decision == .allow
        }
        #expect(Set(allowDecisions.map(\.toolName)) == compiled.allowedToolNames)
    }

    @Test("user-toggled legacy tool names compile to canonical V2 names")
    func terminalToolAllowlistPreservesTrueName() async throws {
        // User toggles ONLY run_command — not the older `bash` alias.
        // The compiled request now canonicalizes that legacy spelling to the
        // model-facing V2 name before it reaches the Rust control plane.
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(tools: ["run_command"]),
            conversationHistory: nil
        )

        #expect(compiled.requestedToolNames.contains("action.bash"))
        #expect(!compiled.requestedToolNames.contains("run_command"))
        #expect(!compiled.requestedToolNames.contains("bash"))
        #expect(!compiled.requestedToolNames.contains("run_persistent"))
    }

    @Test("empty tool toggles compiles to an empty allowlist (deny everything)")
    func emptyToolToggleIsDenyAll() async throws {
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(tools: []),
            conversationHistory: nil
        )
        #expect(compiled.allowedToolNames.isEmpty)
        #expect(compiled.resolvedToolPermissions.allSatisfy {
            if case .deny = $0.decision { return true }
            return false
        })
    }

    // MARK: - P2: diagnostics carries the compiled slash token

    @Test("compiled request preserves the requested slash token so the inspector can render it post-submit")
    func compiledRequestPreservesSlashToken() async throws {
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(slash: .builtinMode(.plan)),
            conversationHistory: nil
        )

        #expect(compiled.requestedSlashToken != nil)
        #expect(compiled.requestedSlashToken?.kind == .builtinMode)
        #expect(compiled.requestedSlashToken?.identifier == "plan")
        #expect(compiled.requestedSlashToken?.displayName == "Plan")
        // The SF Symbol must be reconstructable from the serialized token so
        // the inspector does not need a live ParsedSlashToken to render.
        #expect(compiled.requestedSlashToken?.icon == "list.bullet.clipboard")
    }

    @Test("SerializedSlashToken.icon falls back to wand.and.stars for skill tokens")
    func serializedSkillTokenIconFallsBack() async throws {
        let skill = SkillDiscoveryEntry(
            identifier: "custom-review",
            description: "",
            category: "",
            tags: [],
            source: .bundled,
            sourcePath: "/skills/custom-review"
        )
        let compiler = Self.makeCompiler()
        let compiled = await compiler.compile(
            request: Self.makeRequest(slash: .skill(skill)),
            conversationHistory: nil
        )
        #expect(compiled.requestedSlashToken?.kind == .skill)
        #expect(compiled.requestedSlashToken?.icon == "wand.and.stars")
    }
}
