# Sovereign Gate Chat Delete PR6 Deliberation - 2026-05-02

## Slice

Sovereign Gate Chat Delete PR6 gates the existing Chat Sidebar context-menu
destructive chat delete action through the shared Core `SovereignGate`.

## Tier

Core. This is a local macOS authorization boundary over an existing destructive
UI action. No Pro tunnel, cloud, Hermes runtime, subprocess, graph, Rust,
generated transport, or external side-effect surface is in scope.

## Files Touched

- `Epistemos/Views/Chat/ChatSidebarView.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/deliberation/sovereign_gate_chat_delete_pr6_deliberation_2026_05_02.md`

## Protected Paths

- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Notes/ProseTextView2.swift`
- `Epistemos/Views/Graph/**`
- `graph-engine/**`
- `agent_core/**`
- `epistemos-core/**`
- generated bindings, generated libraries, Xcode project files, entitlements

## Gate Decision

Approved for this slice only:

- Add a tiny Chat Sidebar delete requirement mapper that maps chat delete to
  `.deviceOwnerAuthentication`.
- Route `SidebarChatRow`'s existing context-menu delete callback through
  `AppBootstrap.shared?.sovereignGate.confirm(...)`.
- Treat missing/unavailable auth as denied.
- Preserve the existing `deleteChat(_:)` implementation, active-chat clearing,
  rollback, error alert, and `modelContext.save()` behavior.
- Add a focused Swift Testing assertion proving the chat delete surface maps to
  Destructive auth with an explicit reason string.

Not approved:

- Editing `SovereignGate.swift`.
- Importing `LocalAuthentication` or instantiating `LAContext` anywhere new.
- Migrating note chat, other chat deletion paths, Settings reset, vault delete,
  workspace delete, or any additional confirmation popup.
- Changing chat persistence semantics.
- Touching Rust, generated transport, Omega, ChatCoordinator, protected graph
  or editor files, entitlements, subprocesses, solver paths, tensor copy paths,
  or memory hot paths.

## Verification

Red:

- `/tmp/epistemos-sovereign-gate-chat-delete-pr6-red-20260502.log`
- Expected failure: `ChatSidebarDeletionSovereignGate` did not exist yet.

Green:

- `/tmp/epistemos-sovereign-gate-chat-delete-pr6-green-20260502.log`
- Expected focused suite: `EpistemosTests/SovereignGateTests`.

Guardrails:

- `git diff --check`
- Diff-only invariant grep for duplicate auth, subprocess, solver, tensor-copy,
  and memory-hot-path violations.
- Source grep proving `LocalAuthentication` / `LAContext` remain confined to
  `Epistemos/Sovereign/SovereignGate.swift`.
- Protected-path staged diff audit before commit.

## Closeout

If green and guardrails pass, PR6 closes only the Chat Sidebar context-menu
destructive chat delete surface. Future Sovereign work must open a new exact
gate for each remaining confirmation surface, generated requirement transport,
lifecycle follow-up, or Secure Enclave / Sovereign-class Pro/Research route.
