import Testing

/// REGRESSION GUARDS for the owner's AUTHORITATIVE ontology refactor (iter54-66).
///
/// Epistemos is the app; Osaurus is the Act backend; OpenCode is the Work backend; ONE shared native state.
/// These source-guards lock in the owner-critical invariants that were each a real fix (and one a real
/// owner-reported symptom — main-act chats missing from recent-chats), so a future refactor cannot silently
/// regress them. They mirror `ActSurfaceOsaurusUIDirectionGuardTests` (source-guard via loadMirroredSourceTextFile).
@Suite("Ontology refactor — owner-critical invariants")
struct OntologyRefactorRegressionGuardTests {

    /// 0.48: main-act Osaurus turns MUST persist to the unified SDChat recent-chats store. The new
    /// `runActOsaurusTurn` path bypasses the deprecated ChatCoordinator pipeline (the old SDChat writer), so
    /// without this seam main-act chats never save / reopen — the exact owner-reported symptom. Guard the wiring.
    @Test("main-act turns persist to unified recent-chats (ChatState.persistActTurn → persistChatCompletion)")
    func mainActPersistenceWired() throws {
        let chatState = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")
        // ChatState exposes the persistence seam and invokes it after the final append (success + cancelled).
        #expect(chatState.contains("var persistActTurn:"))
        #expect(chatState.contains("persistActTurn?(chatId, safeQuery"))

        let bootstrap = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        // AppBootstrap wires the seam to the PROVEN SDChat writer (where chatState + chatCoordinator co-exist).
        #expect(bootstrap.contains("chatState.persistActTurn = "))
        #expect(bootstrap.contains("persistChatCompletion("))
    }

    /// 0.47/0.47b: the Act surfaces share ONE streaming core. Both main act and Mini Chat MUST consume
    /// `ActTurnStreamCore.consume` rather than hand-rolling a `for try await` event loop — so the surfaces stay
    /// unified (one delta-accumulation / finalVisibleText / tool-block / cancellation implementation).
    @Test("act surfaces share ActTurnStreamCore (main act + Mini Chat both consume it)")
    func actSurfacesShareStreamingCore() throws {
        let chatState = try loadMirroredSourceTextFile("Epistemos/State/ChatState.swift")
        let miniChat = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        #expect(chatState.contains("ActTurnStreamCore.consume("))
        #expect(miniChat.contains("ActTurnStreamCore.consume("))
        // The core itself exists with its sink contract + result.
        let core = try loadMirroredSourceTextFile("Epistemos/LocalAgent/ActTurnStreamCore.swift")
        #expect(core.contains("enum ActTurnStreamCore"))
        #expect(core.contains("struct ActTurnStreamSinks"))
        #expect(core.contains("struct ActTurnStreamResult"))
    }

    /// 0.49b: Work's fusion MCP server MUST root at the Epistemos APP VAULT (so the work agent sees vault notes +
    /// `skills/` as MCP context), falling back to the canonical default vault — NEVER the shell cwd/home.
    @Test("Work fusion MCP roots at the app vault, never the cwd (0.49b)")
    func workFusionRootsAtAppVault() throws {
        let runtime = try loadMirroredSourceTextFile("Epistemos/Work/WorkOpenCodeRuntime.swift")
        #expect(runtime.contains("epistemosVaultRoot ?? FirstRunBootstrap.defaultVaultURL()"))
        #expect(runtime.contains("vaultRoot: fusionVaultRoot"))
        // Persistence stays merge-preserving so user-installed MCPs survive quit (0.49).
        #expect(runtime.contains("writeMergedFusionConfig("))
    }

    /// 0.48b / part2: the recent-chats popover is ONE unified store split into ACT + WORK sections, and a Work
    /// row reopens the work surface (never loads as an empty act transcript).
    @Test("recent-chats popover splits Act/Work + worker rows reopen work (0.48b)")
    func recentChatsTwoSectionAndWorkReopen() throws {
        let sidebar = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatSidebarView.swift")
        // Top-level Act/Work split over the ONE SDChat store.
        #expect(sidebar.contains("private var actChats:"))
        #expect(sidebar.contains("private var workChats:"))
        #expect(sidebar.contains("$0.isWorkerSession"))
        // A worker row reopens work (posts the reopen notification) rather than loading an act transcript.
        #expect(sidebar.contains("if sdChat.isWorkerSession"))
        #expect(sidebar.contains(".openWorkSession"))

        // The reopen handler flips the workspace to .work (mirrors the act reopen).
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        #expect(root.contains(".openWorkSession"))
        #expect(root.contains("workspaceMode = .work"))
    }

    /// Audit A invariant: NO Osaurus management/chat UI is mounted as product UI (only the engine seams). This
    /// complements ActSurfaceOsaurusUIDirectionGuardTests — the act surface is native, Osaurus is underneath.
    @Test("no Osaurus management/chat host mounted in the product (engine-only)")
    func noOsaurusUIMounted() throws {
        let root = try loadMirroredSourceTextFile("Epistemos/App/RootView.swift")
        #expect(!root.contains("EpistemosOsaurusChatHost("))
        #expect(!root.contains("ManagementView("))
    }
}
