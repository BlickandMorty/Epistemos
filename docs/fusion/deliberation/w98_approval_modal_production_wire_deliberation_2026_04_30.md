# W9.8 Approval Modal Production Wire Deliberation - 2026-04-30

## Gate

Approved action: **replace the main ChatCoordinator production tool-approval `NSAlert` path with the existing SwiftUI `ApprovalModalView` via a complete local queue model**.

This gate approves a narrow W9.8 slice only. It does not approve raw stash application, a multi-site NSAlert purge, protected graph/editor edits, `StreamingDelegate` protocol rewrites, Rust agent-core session-state changes, generated artifact edits, staging, commits, branches, or manual app verification.

## Context

W9.8 has carried as an orphan-scaffold/status-drift item because `ApprovalModalView` exists, but the live `ChatCoordinator.promptUserForToolApproval(...)` path still constructs `NSAlert`.

Current source evidence:

- `Epistemos/App/ChatCoordinator.swift` uses `NSAlert` for production agent tool permission prompts.
- `Epistemos/Views/Approval/ApprovalModalView.swift` exists but lacks `applyLessInterruptions` parity and a production queue.
- `Epistemos/App/AppBootstrap.swift` has no `chatApprovalQueue`.
- `Epistemos/App/EpistemosApp.swift` has no `.sheet(item:)` mounted for approval prompts.

Read-only stash evidence:

- `stash@{0}` contains partial W9.8 donor edits in `ChatCoordinator`, `EpistemosApp`, and `ApprovalModalView`.
- The donor references `ChatApprovalQueue` and `ChatApprovalResolution`, but current source defines neither type.
- Therefore the stash must not be applied directly.

## Decision

Implement W9.8 fresh and minimal:

- Define `ChatApprovalResolution`.
- Define `@MainActor @Observable final class ChatApprovalQueue`.
- Mount `ApprovalModalView` from `HomeSceneRootContent` using `.sheet(item:)`.
- Route `ChatCoordinator.promptUserForToolApproval(...)` through `bootstrap.chatApprovalQueue.enqueue(...)`.
- Preserve all four existing production choices:
  - Allow once
  - Always allow the current authority category
  - Apply Less Interruptions and allow this action
  - Deny
- Treat timeout as deny.
- Keep the sheet non-interactively dismissible so the awaiting continuation cannot hang.

## Core/Pro Classification

Classification: **Both**.

The prompt is a Core safety surface for all local agent tool approval. Some downstream callers are Pro/direct-distribution, but the queue and modal must be safe in Core/MAS builds and must not introduce hidden Pro behavior.

## Files Approved

- `Epistemos/Views/Approval/ApprovalModalView.swift`
- `Epistemos/App/ChatCoordinator.swift`
- `Epistemos/App/AppBootstrap.swift`
- `Epistemos/App/AppEnvironment.swift`
- `Epistemos/App/EpistemosApp.swift`
- `EpistemosTests/AuditFixRegressionTests.swift`
- `docs/fusion/deliberation/w98_approval_modal_production_wire_deliberation_2026_04_30.md`
- `docs/fusion/oversight/CODEX_KIMI_OVERSIGHT_ROUND_011_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Files Forbidden

- `stash@{0}` mutation by apply, pop, drop, branch extraction, checkout, or cherry-pick
- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/` physics/render internals
- `agent_core/` Rust session-state changes
- `Epistemos/Bridge/StreamingDelegate.swift`
- `Epistemos/Bridge/ClarifyPromptBridge.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Views/Chat/MessageBubble.swift`
- `Epistemos/Views/Settings/AuthoritySettingsView.swift`
- generated `.rlib`, `.d`, DerivedData, `.xcresult`, project files, entitlements, branches, staging, or commits

## Alternatives Considered

- Apply the stash directly: rejected because the donor is incomplete and references missing queue/resolution types.
- Remove every `NSAlert` site in one pass: rejected because that would touch unrelated UI flows and protected graph code.
- Keep `NSAlert` fallback in ChatCoordinator: rejected for this specific path because the W9.8 bug is the live production prompt not using the modal.
- Wire Rust `PausedForApproval` session-state plumbing now: rejected because this slice targets the existing Swift `AgentPermissionRequest` approval path and does not approve Rust or delegate protocol churn.

## Tests

Red first:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AuditFixRegressionTests/agentToolApprovalsRouteThroughSwiftUIQueueInsteadOfNSAlert test
```

Required assertions:

- `ApprovalModalView.swift` defines `ChatApprovalQueue` and `ChatApprovalResolution`.
- The queue uses `pendingApproval`, `enqueue`, `withCheckedContinuation`, and `resolve`.
- The modal exposes the Less Interruptions decision.
- `AppBootstrap` owns `let chatApprovalQueue = ChatApprovalQueue()`.
- `AppEnvironment` injects `bootstrap.chatApprovalQueue`.
- `EpistemosApp` mounts `.sheet(item:)` with `interactiveDismissDisabled(true)`.
- `ChatCoordinator` calls `bootstrap.chatApprovalQueue.enqueue(...)`.
- `ChatCoordinator` no longer contains `NSAlert`, `beginSheetModal`, or `runModal()` in the tool-approval path.

Green:

- Run the same focused source guard.
- Run an additional focused approval/UI source cluster if the compiler requires it.
- Do not run manual app verification in this slice; the user explicitly deferred manual testing for now.

## Rollback

Revert only the approved files in this gate if the focused test or build fails in a way that cannot be fixed locally. Do not revert unrelated dirty files.

## Stop Triggers

- Any need to edit protected graph/editor files.
- Any need to change Rust session-state or `StreamingDelegate` protocols.
- Any loss of the Less Interruptions parity choice.
- Any continuation path that can hang on sheet dismissal or double-resume on timeout/user click race.
- Any source change outside the approved file list.

## Kimi

Kimi may provide read-only advisory critique only. Kimi is not approved to edit code, apply stashes, stage, commit, or run write-scope implementation.

## Implementation

- Added `ChatApprovalResolution` and `@MainActor @Observable final class ChatApprovalQueue`.
- Extended `ApprovalModalView.PendingApproval` with issued time, summary text, and authority category label.
- Added the Less Interruptions decision path to the modal and mapped timeout to deny.
- Replaced the production `ChatCoordinator.promptUserForToolApproval(...)` `NSAlert` path with `bootstrap.chatApprovalQueue.enqueue(...)`.
- Mounted the approval modal from `HomeSceneRootContent` with `.sheet(item:)` and `.interactiveDismissDisabled(true)`.
- Added `chatApprovalQueue` to `AppBootstrap` and injected it through `withAppEnvironment(...)`.
- Added source guards plus a focused async queue behavior test for decision resolution, timeout-as-deny, and overlapping prompt denial.

## Verification

- Kimi read-only audit: `SAFE_TO_STAGE_EXACT_SLICE`; Kimi flagged that `AppBootstrap.swift` and `EpistemosApp.swift` must not be staged whole-file because they contain unrelated dirty work.
- Focused suite command:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -parallel-testing-enabled NO -only-testing:EpistemosTests/AuditFixRegressionTests test`
- Log: `/tmp/epistemos-w98-approval-modal-auditfix-green-20260501.log`
- Result bundle: `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.05.01_22-02-08--0500.xcresult`
- Result: 26 Swift Testing tests passed in `AuditFixRegressionTests`; Xcode reported `** TEST SUCCEEDED **`.
- Note: the method-level command `/tmp/epistemos-w98-approval-modal-green-20260501.log` built successfully but executed 0 tests due Swift Testing method-name filtering, so it is not acceptance evidence.
