# Deliberation - Build/Test Floor Verification - 2026-04-30

> **Slice:** Queue item 1, build/test floor verification and protected-path audit.
> **Decision requested:** Approve verification commands only. No source implementation.
> **Floor:** `ac8c6d28` on `feature/landing-liquid-wave`.

## 1. Scope

This slice establishes the current build/test floor before any fusion implementation. It may run verification commands and capture/summarize results. It may not modify source code, stage files, commit, pop stashes, merge worktrees, or clean generated artifacts.

Allowed outputs:

- Shell output captured by Codex.
- Optional follow-up docs under `docs/fusion/` summarizing verification results.

Forbidden outputs:

- Source edits.
- Project/scheme/plist edits.
- Build setting edits.
- Generated `.rlib`, DerivedData, `.xcresult`, or build-output changes committed or staged.

## 2. Repo Evidence

Phase 0 evidence records:

- Current branch: `feature/landing-liquid-wave`.
- Current HEAD: `ac8c6d28`.
- Main status entries: 1292 total.
- Modified entries: 503.
- Untracked entries: 789.
- Stashes: 4, all suspect until separately audited.
- Protected files clean by Phase 0 audit:
  - `Epistemos/Views/Notes/ProseEditor*.swift`
  - `Epistemos/Views/Graph/MetalGraphView.swift`
  - `Epistemos/Views/Graph/HologramController.swift`
- High-risk graph dirty diff:
  - 12 files under `graph-engine/`.
  - Approximately +1008 / -118 lines.
  - Includes `graph-engine/src/knowledge_core/store.rs` at +808 lines.

## 3. Research Evidence

Relevant authority:

- `AGENTS.md` requires tests before committing and forbids protected-path drift.
- Release audit skill requires logs as first-class evidence before any release/readiness claim.
- `KIMI_FUSION_REVIEW_2026_04_30.md` says the queue must prioritize build-floor verification before worktree extraction.
- `FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md` makes this the first queue item.

## 4. Worktree Donor Evidence

No worktree donor extraction is involved in this slice.

Worktrees remain read-only evidence only:

- Lane A: archive only.
- Quick Capture: extract slices later, no raw merge.
- Simulation/Theater: Pro donor only.
- Honest Handle/FFI: defer until benchmark and safety proof.
- Hermes parity: Pro donor only.
- Inspiring-Heisenberg: benchmark harness donor only.

## 5. Alternatives Considered

| Alternative | Why rejected |
|---|---|
| Start Halo implementation immediately | Would violate the first queue item and could build on a broken dirty floor. |
| Let Kimi run build/test in Antigravity | Antigravity terminal/tool rendering has been unreliable; Codex shell can capture and audit commands directly. |
| Skip tests because the repo is dirty | The dirty state is exactly why floor verification is required. |
| Clean generated files first | Cleaning/deleting data is out of scope and would require explicit approval. |

## 6. Approved Commands

Run in `/Users/jojo/Downloads/Epistemos` unless stated otherwise:

1. `git status --short -uall`
2. `git diff --name-only -- Epistemos/Views/Notes/ProseEditor*.swift Epistemos/Views/Graph/MetalGraphView.swift Epistemos/Views/Graph/HologramController.swift`
3. `git status --short -uall -- graph-engine/`
4. `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
5. `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
6. `cargo test` in `/Users/jojo/Downloads/Epistemos/graph-engine`
7. `cargo test` in `/Users/jojo/Downloads/Epistemos/agent_core`

If an earlier command fails in a way that makes later commands meaningless, stop and summarize the failure instead of bulldozing forward.

## 7. Files Likely Touched

No repo files should be intentionally touched by this slice.

Local tooling may create DerivedData, `.xcresult`, cargo `target/`, or temporary build artifacts. These must not be staged, committed, cleaned, or deleted in this slice.

## 8. Protected Files

Protected files remain read-only:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- `graph-engine/src/renderer.rs`
- graph physics/force/motion internals
- generated `.rlib`
- DerivedData and `.xcresult`

## 9. Manual Verification

Manual app runtime verification is not required for this slice unless build/test passes and the next deliberation chooses a UI slice. This slice only establishes command-line floor evidence.

## 10. Rollback

No rollback should be needed for read-only/build commands.

Do not delete generated files in this slice. If generated artifacts appear in git status, record them and stop for a separate cleanup decision.

## 11. Acceptance Criteria

- Fresh status count is captured.
- Protected-path audit is captured.
- Graph-engine dirty status is captured.
- Build/test/cargo results are captured or a blocking failure is reported.
- No source implementation occurs.
- No stage/commit/branch/stash/delete operation occurs.

## 12. Stop Triggers

Stop immediately if:

- A protected file becomes dirty.
- A command attempts to stage, commit, clean, delete, pop stash, switch branch, or merge.
- Build/test creates tracked generated artifacts that require cleanup.
- Xcode or cargo failure indicates a code decision rather than an environmental hiccup.
- Kimi asks to edit code before a later implementation deliberation is approved.

## 13. Gate Decision

**Codex decision:** Approved for verification commands only.

Implementation remains blocked after this slice until the verification results are audited and the next deliberation brief is approved.
