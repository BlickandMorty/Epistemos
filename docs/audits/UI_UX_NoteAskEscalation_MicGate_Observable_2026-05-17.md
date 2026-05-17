# UI/UX Audit — Note-ask auto-escalation + mic OS-gate + final @Observable migration

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 9)
- **Driver**: §4.C — three flow-critical / refactor commits from the
  14-day window that weren't yet audited.
- **Trigger commits**:
  - `3a43066df` (2026-05-13) — *fix(note-ask): auto-escalate
    agent-intent queries to main chat with tools*
  - `dd978c1e6` (2026-05-13) — *fix(chat): close RCA4-P1-006 —
    ComposerMicButton gated to #unavailable(macOS 26)*
  - `3a0856cd7` (2026-05-15) — *refactor(code-editor): final 3
    ObservableObject → @Observable* (closes iter-7 carry-over)
- **Verification mode**: Static. iter-1 env constraints unchanged.

## 1. Note-ask auto-escalation (3a43066df)

`Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1927-1956` adds a
guard *before* the inline `noteChatState.submitToolbarQuery` call:

```swift
let prediction = ChatCapability.predictIntent(text: trimmed, isCloudProvider: ...)
if prediction.predicted == .agent || prediction.predicted == .research {
    routeToolbarAskToMainChat()
    return
}
```

When intent classifies as agent-tier, the query is silently routed to
`routeToolbarAskToMainChat()` (lines 1968-1996), which:
- Clears `noteChatState.inputText`.
- Calls `bootstrap.chatState.startNewChat()`.
- Adds the current note as a `ContextAttachment` so the model still
  has the note's content available.
- Switches the active panel to `.home` via `ui.setActivePanel(.home)`.
- Routes through `MainChatSubmissionRouter.submit(...)` carrying the
  note's selected operating mode.

**Verdict**: this is the **honest** fix to USABILITY-001 — running
agent-intent queries through `TriageService.stream` (which only dispatches
provider-native cloud tools, not Epistemos's vault/file tools) was
structurally guaranteed to hallucinate. The escalation lets the full
agent_core toolchain run while preserving note context. The
panel-switch makes the route visible — no silent black hole.

**Strengths preserved**:
- Non-agent intents (rewrite/summarize/explain/expand) stay on the fast
  inline path — UX continuity for the common note-transform case.
- `ContextAttachment` carries the note into main chat so the model
  doesn't have to re-derive it.
- The same `selectedNoteChatOperatingMode` is passed through, so the
  agent runs in the user's chosen mode.
- Honest disclosure comment at lines 1927-1942 explains the structural
  reason.

### Findings

**P0/P1**: none.

**P2-1 — Panel switch is silent.**
`ui.setActivePanel(.home)` snaps the UI to main chat. No transient
"Sent to main chat — agent tools needed" toast or fade. A user typing
in their note's ask bar suddenly sees their whole UI change panel.
For first-time users this can read as "where did my query go?"

- Fix sketch: brief 1.5-second toast / banner at top of Home anchored
  to the new chat row, with the note's title + the query. Defer.

**P2-2 — Intent prediction is the load-bearing classifier.**
`ChatCapability.predictIntent(text:, isCloudProvider:)` decides
whether a query is `.agent | .research | other`. A false-positive
(misclassifying a "rewrite this paragraph" as `.agent`) yanks the
user into main chat for a simple transform; a false-negative
(misclassifying "find my notes about X" as `.other`) keeps them on
the broken inline path. Not in this audit's scope to evaluate the
classifier itself; flag for a NLP-classifier sub-mission.

**P2-3 — Graph chat surfaces explicitly deferred** per the commit
body — sidebar + dialogue need similar treatment with a
less-disruptive bridge pattern. Worth a separate iter once landed.

## 2. ComposerMicButton OS-gate (dd978c1e6)

`Epistemos/Views/Chat/ChatInputBar.swift:665-679` wraps the legacy
`ComposerMicButton` in `if #unavailable(macOS 26.0) { ... }`. On
macOS 26+, only the native `VoiceInputButton` (SpeechAnalyzer) renders
further down the bar. The legacy `ComposerMicButton` (W10.10
Whisper.cpp + SFSpeechRecognizer fallback) only renders on older
macOSes.

**Verdict**: textbook OS-version gating with a clear comment.
Surfacing both simultaneously had confused users about which mic
owned the dictation lifecycle + temp-file cleanup.

### Findings

**P0/P1**: none.

**P3 — observation**: the gate is `#unavailable(macOS 26.0)`. If
SpeechAnalyzer ever needs a deeper minor-version gate (e.g., macOS
26.4 to fix a known bug), the `unavailable` predicate needs to be
revisited. Document the assumption inline if it tightens.

## 3. Final 3 ObservableObject → @Observable (3a0856cd7)

`Epistemos/Views/Notes/CodeEditorView.swift` — 51 LOC diff — converts
the last three legacy `ObservableObject` services to the Swift 5.9+
`@Observable` macro path:

- `CodeCompanionService`
- `CodeContextBridge`
- `CodeInsightGenerator`

Consumer changes: `@StateObject` → `@State`, `@ObservedObject` → no
property wrapper / `let` (per @Observable + @Bindable conventions for
plain references).

**Verdict**: closes standing-check #4 (`docs/APP_ISSUES_AUTO_FIX.md`
§Standing Checks) — ObservableObject count was 3 after the
`8b182ced6` ComposerVoiceInputService slice; now zero. ✅ Closes the
iter-7 carry-over I flagged.

**Strengths preserved**:
- Drop-in macro replacement; no behavioral change.
- All 3 classes already used non-Combine APIs (`@Published` only, no
  `.publisher` / `.sink`), so the migration is purely additive.

### Findings

**P0/P1**: none. Pure refactor.

**P3 — observation**: `private(set) var` properties on `@Observable`
classes track observation automatically; the migration drops the
`@Published` annotations correctly. ✅

## Action taken this iter

- Filed this audit doc.
- **No code edits.** All P0/P1 issues addressed in trigger commits.
- Closes the iter-7 carry-over about the 3 remaining
  ObservableObject usages.

## Carry-overs

- P2-1 toast/banner for note-ask auto-escalation.
- P2-2 evaluation of `ChatCapability.predictIntent` accuracy (NLP
  classifier sub-mission).
- P2-3 same auto-escalation treatment for graph-chat sidebar +
  dialogue surfaces.

## Iter 1-9 surface coverage

| iter | feature | doc |
|---|---|---|
| 1 | AmbientFrequencies + Settings UI (3 P1 fixes applied) | UI_UX_AmbientFrequencies_2026-05-17.md |
| 2 | AmbientFrequencyLivePlayer | UI_UX_AmbientFrequencyLivePlayer_2026-05-17.md |
| 3 | Settings → Diagnostics rows | UI_UX_Settings_Diagnostics_2026-05-17.md |
| 4 | Halo panel + Provenance Console | UI_UX_Halo_ProvenanceConsole_2026-05-17.md |
| 5 | CognitiveWeightBadge | UI_UX_CognitiveWeightBadge_2026-05-17.md |
| 6 | Notes ask-bar runtime error surface | UI_UX_NotesAskBarError_2026-05-17.md |
| 7 | 5 minor UI fixes | UI_UX_MinorFixes_2026-05-17.md |
| 8 | EditorBundleHealthRow + BackgroundIndexingHealthRow | UI_UX_EditorBundleHealthRow_2026-05-17.md |
| 9 | Note-ask auto-escalate + mic OS-gate + final @Observable | this doc |
