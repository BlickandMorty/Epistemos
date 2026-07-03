# Goose Note-Context Plumbing — CODE PACK (2026-06-27, superseded in part 2026-06-29)

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02.** The note-context PLUMBING detail (ActiveEpdocTracker / NoteContextProvider / bounded head-tail projection) is durable — it now feeds the Agent surface's context + the note-edit PROVENANCE system. STALE: the whole embedded "mini-Goose-chat panel / reskinned Goose WebView / Option 1 / dock slot in Epdoc" premise — that minichat is DEFERRED (owner 2026-07-02); the agent works notes via shared files + a companion mascot, not an in-editor chat. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02` + `project_product_shape_agent_center_2026_07_02`.

> Original Pass-4d deliverable was a minichat. After the 2026-06-29 upgrade, the live deliverable is only the
> note-context plumbing that feeds open-note context to the Plan-1-owned Goose WebView/reskin. Tags
> [VERIFIED-CODE]/[INFERRED].

> **★ 2026-06-29 supersession:** Plan 1 Option 1 is locked: Goose chat/agent UI stays in the reskinned Goose
> WebView, with native frame/models only. Therefore this codepack is now **Plan-2 editor-side context plumbing
> only**. Do NOT build a separate native chat UI from this document; keep the context/session/affordance ideas
> that let the Plan-1-owned Goose WebView act on the open note.

## 0. Active scope after the 2026-06-29 upgrade
The live chat/agent surface is **not Plan 2's UI** and is **not blocked on a Phase-0 sign-off wait** from this
codepack. Plan 2 may build the zero-Goose-dependency editor plumbing: active-note tracking, bounded context
snapshots, `_meta` builders, vault MCP descriptors, wikilink/selection context, and editor affordance routes.
Plan 1 owns the Goose WebView/reskin live UI and `Epistemos/Goose/*` / `Epistemos/Agent/*`.

## 1. Active architecture — context bridge into Goose WebView/reskin
The earlier separate-native-chat recommendation is historical and rejected by the 2026-06-29 Plan 1 upgrade.
The active architecture is: one Goose session can be scoped to the open note through ACP `_meta` + the vault/context
MCP server, while the user-facing chat remains the Plan-1-owned Goose WebView surface. Plan 2's deliverable is the
note-aware context bridge and editor affordance routing, not a second chat UI.

## 2. Lifecycle: ONE shared session, re-scoped per note
`goose serve` is one process; session-per-note explodes count + loses continuity. Keep `cwd = vault root`
constant; change only the note context (cheap, via `_meta` + a re-seed preamble + the live MCP snapshot).
Tear down on panel close / vault switch; keep alive across note switches within a vault.

## 3. Auto-init on note open (build-now, zero Goose dependency)
```swift
// ActiveEpdocTracker.swift — frontmost note via NSWindow key changes
@MainActor @Observable final class ActiveEpdocTracker {
    private(set) var activeDocument: EpdocDocument?
    private var observers: [NSObjectProtocol] = []
    func start() {
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] n in
            MainActor.assumeIsolated { self?.recompute(keyWindow: n.object as? NSWindow) } })
        recompute(keyWindow: NSApp.keyWindow)
    }
    private func recompute(keyWindow: NSWindow?) {
        let doc = NSDocumentController.shared.documents.compactMap { $0 as? EpdocDocument }
            .first { $0.windowControllers.contains { $0.window === keyWindow } }
        if doc !== activeDocument { activeDocument = doc }   // @Observable fires
    }
}
// NoteContextProvider.swift — bounded head/tail body via the EXISTING projector
@MainActor struct NoteContextProvider {
    let tracker: ActiveEpdocTracker; let vaultRoot: () -> URL?
    func snapshot() -> WorkAppContextSnapshot {
        guard let doc = tracker.activeDocument else { return .empty }
        let md = ProseMirrorMarkdownProjector.project(jsonData: doc.package.contentJSON) ?? ""   // [VERIFIED-CODE]
        return WorkAppContextSnapshot(vaultPath: vaultRoot()?.path, appMode: "minichat",
            activeNoteTitle: doc.package.manifest.title, activeNotePath: doc.fileURL?.path,
            currentSelectionPreview: nil, activeNoteBodyExcerpt: headTail(md, head: 4000, tail: 1500))
    }
}
```
Wire `tracker.activeDocument` change → `WorkNativeMCPHost.shared.updateContext(provider.snapshot())` so the
live `epistemos.context.snapshot` MCP tool always reflects the frontmost note.

## 4. Goose-side + MCP engineering list (the exact gaps)
1. **Expose `mcpServers` on the client (1-line, build-now)** — `GooseACPClient.newSession` drops it though the
   request struct (`GooseACPNewSessionRequest.mcpServers`) supports it:
   ```swift
   func newSession(cwd: String, mcpServers: [JSONValue] = [], metadata: [String:JSONValue]? = nil) async throws
   ```
2. **Vault MCP server entry (build-now)** — `WorkNativeMCPHost.startAndAwaitRegistration` yields `{url, token}`;
   shape as an ACP HTTP MCP descriptor `{name:"epistemos-vault", type:"http", url, headers:{Authorization:Bearer}}`
   so the agent can RE-PULL the live note mid-turn via `epistemos.context.snapshot`. (Verify exact key vs goosed schema.)
3. **Note `_meta` channel (build-now)** — `session/new`+`session/prompt` encode `_meta`; carry
   `{epistemos.note:{title,path,vault}}`.
4. **Epdoc UI-steering affordances (build-now)** — add `open_note`/`highlightEditor`/`replaceSelection` to
   `GooseWebNativeAffordanceBridge` (routes into existing `EpdocDocumentOpening.openDocument(withManifestID:)`
   + `EpdocEditorChromeController.dispatch`). The "callbacks into Epdoc" the owner wants.
5. **Stop/cancel ACP method (build-now, NEW)** — there is NO cancel method today (only a `cancelled`
   stop-reason). Add `session/cancel` (confirm shape vs vendored goosed ACP server).
6. **AGENTS.md vault guidance (build-now, Goose-side file)** — at vault root: "You are the note companion;
   current note is in `_meta.epistemos.note` + via `epistemos.context.snapshot`; prefer `epistemos-vault`
   tools; call `open_note` to navigate; never write outside the vault." Makes the SAME Goose agent note-aware.

## 5. Historical view-model sketch — mine for plumbing only, do not ship a native chat UI
The sketch below is useful for session scoping, cancellation, and context refresh semantics. Treat UI/state fields
(`turns`, composer, tool cards, native permission panel) as historical unless Plan 1 explicitly asks Plan 2 for them.
```swift
@MainActor @Observable final class MiniChatViewModel {
    enum Availability { case ready, unavailable(String) }
    private(set) var availability: Availability
    private(set) var turns: [MiniChatTurn] = []; private(set) var isStreaming = false
    private(set) var pendingPermission: GooseACPPermissionPrompt?; var draft = ""
    private let noteContext: NoteContextProvider
    private var client: GooseACPClient?; private var sessionId: String?; private var lastNotePath: String?

    init(noteContext: NoteContextProvider) {
        self.noteContext = noteContext
        #if EPISTEMOS_APP_STORE
        availability = .unavailable("Historical native note chat UI is superseded; use Goose WebView/reskin.")
        #else
        availability = GooseSurfaceAvailability.current().runtimeBinary == nil
            ? .unavailable("Goose runtime is not staged.") : .ready
        #endif
    }
    func activateForCurrentNote() async {                 // AUTO-INIT (.task on appear + on note change)
        guard case .ready = availability else { return }
        let snap = noteContext.snapshot()
        guard snap.activeNotePath != lastNotePath || sessionId == nil else { return } // re-scope on change
        lastNotePath = snap.activeNotePath
        await ensureSessionScoped(to: snap)              // newSession(cwd:vault, mcpServers:[vault], _meta:note) + seed preamble
    }
    func send() { /* turns.append(.user); client.prompt(sessionId:, text: wikilinkExpanded(draft)); */ }
    func stop() { /* client.cancel(sessionId:) — §4.5 */ }
    func resolvePermission(optionID: String?) { /* client.respondToPermission(...) — inline approval */ }
    func openInFullGoose() { GooseSurfaceWindowController.shared.open() }  // hybrid escape hatch
    private func apply(_ e: GooseACPClientEvent) {        // streaming pump (forward every chunk)
        // .agentThoughtChunk -> appendThinking; .agentMessageChunk -> appendAnswer;
        // .toolCall/.toolCallUpdate -> tool cards; .permissionRequest -> pendingPermission
    }
}
```
UX: compact composer, streamed thinking (auto-expand/collapse) + tool cards (pending/inProgress/completed),
inline per-edit approval (reuse existing `GooseACPPermissionPanel`), stop button, `[[wikilink]]` reference
(resolve via existing `EpdocDocumentLocator`), selection-aware ("explain this") from `caretChanged`.

## 6. Build-vs-exists ledger
**EXISTS:** ACP client (init/new/prompt/load/fork/permission/elicitation), `session/new` request carries
`mcpServers`+`_meta`, `session/update` streaming vocab, event bridge, native MCP server + bearer/loopback,
`epistemos.context.snapshot` tool, `WorkAppContextSnapshot` (title/path/selection), `ProseMirrorMarkdownProjector`,
document controller + `EpdocDocument` + open-by-id, full Goose web surface (escape hatch), MAS gate in supervisor.
**BUILD-NOW (zero Goose dep, testable today):** `ActiveEpdocTracker`, `NoteContextProvider`,
`activeNoteBodyExcerpt` field, populate-context-on-note-change, `newSession` mcpServers param, `_meta` builders,
Epdoc `open_note`/highlight affordances, and the `[[wikilink]]` resolver.
**PLAN-1-OWNED LIVE SURFACE:** the Goose WebView/reskin owns live prompt/stream/permission UI and any runtime
availability gate. Plan 2 should not flip a separate native chat UI to `.ready`.
**NOT BLOCKED HERE:** no Phase-0 sign-off wait remains in this codepack; if Plan 2's context plumbing is buildable,
build and verify it without touching Plan-1-owned Goose UI files.

**Net:** the note-context seam rides a mature ACP stack. After the 2026-06-29 upgrade, the build-now bulk is
editor-side note-context plumbing with zero Goose dependency; the live chat remains Goose WebView/reskin. Three small
Goose-boundary gaps to coordinate with Plan 1 if needed: `newSession` drops `mcpServers` (1-line), no cancel method,
no Epdoc UI-steering affordances.
