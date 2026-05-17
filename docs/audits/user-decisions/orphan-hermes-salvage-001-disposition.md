---
item: ORPHAN-HERMES-SALVAGE-001
created_on: 2026-05-16
scope: Hermes-parity salvage Rust file disposition
status: COMPLETE_RESEARCH_READY
---

# ORPHAN-HERMES-SALVAGE-001 Disposition User Decision

## Problem Statement

The B-6 Hermes-parity salvage verification demoted a supposed V1 blocker into an explicit disposition decision for three Rust files:

- `agent_core/src/credential_pool.rs`
- `agent_core/src/error_classifier.rs`
- `agent_core/src/session_persistence.rs`

The original blocker framing was wrong: the suspected security/session risks do not currently materialize in production because two files are not declared in `agent_core/src/lib.rs`, and the third compiles but has no production caller. The real decision is whether to wire these salvage modules, formally quarantine them as scaffold/reference work, selectively keep only the useful one, or delete/archive them.

This decision has to respect two constraints from the Hermes removal sprint: remove the old Hermes-agent bloat, and do not delete deep work that may encode useful contracts. It is not a V1 blocker unless the user chooses to make one of these modules part of V1 product behavior.

## Options

### Option A - Formal quarantine for V1; no product wire now

Keep all three files out of V1 product behavior and record them as quarantined Hermes-parity salvage:

- `credential_pool.rs`: do not wire until it is redesigned around the current Keychain-backed credential path. The current Rust file stores raw keys in `Vec<String>` and has no Keychain integration.
- `error_classifier.rs`: keep compiled and tested, but do not wire until a Rust-agent error-recovery sprint decides how it relates to Swift `UserFacingChatErrorKind`.
- `session_persistence.rs`: do not wire until the current `agent_core::session` and Swift chat/vault persistence paths are reconciled against its SQLite checkpoint design.

Pros:

- Preserves the deep work.
- Avoids premature credential/session architecture churn.
- Matches the current fact that none of the three files is a V1 blocker.
- Leaves a clean post-V1 split: rewrite credential rotation if needed, wire error classification if useful, and either reconcile or archive session checkpoints.

Cons:

- Leaves two source files uncompiled and one compiled orphan.
- Requires a future guard/doc cleanup slice so this does not get rediscovered as a fresh blocker.

### Option B - Wire all three now

Promote the salvage modules into production:

- Declare `credential_pool` and `session_persistence` in `agent_core/src/lib.rs`.
- Connect credential rotation into provider routing.
- Connect session checkpointing into the agent loop.
- Connect error classification into the agent error handling path.

Pros:

- Maximizes salvage reuse.
- Could improve Rust-side recovery behavior if carefully integrated.
- Converts the open disposition into product behavior.

Cons:

- High risk for V1.
- `credential_pool.rs` does not use Keychain; direct wiring would conflict with current credential-security discipline.
- `session_persistence.rs` introduces a second checkpoint/session schema beside `agent_core::session` and Swift-side persistence.
- The three modules were not designed against the current MAS surface.

### Option C - Selective salvage: wire `error_classifier`, quarantine or archive the other two

Treat `error_classifier.rs` as the only near-term product candidate, because it already compiles and its tests pass. Keep `credential_pool.rs` and `session_persistence.rs` quarantined or archive them as reference material.

Pros:

- Captures the most immediately usable code.
- Avoids raw key rotation and duplicate session persistence risks.
- Smaller implementation surface than Option B.

Cons:

- Still requires mapping Rust `ErrorCategory` to current Swift user-facing errors.
- Could duplicate the already-shipped Swift `UserFacingChatErrorKind` logic.
- Deletes or archives two pieces of salvage unless the user explicitly accepts that.

### Option D - Delete/archive all three now

Remove the three Rust files from `agent_core/src/`, optionally preserving them only under `docs/fusion/salvage/` or git history.

Pros:

- Eliminates the orphan-source ambiguity.
- Reduces future false blocker reports.
- Simplest source tree outcome.

Cons:

- Most aggressive against the user's "do not delete deep work" constraint.
- Loses tested error-classifier code and session schema design unless explicitly archived.
- Makes later salvage work start from docs/history instead of live source.

## Canonical Sources

- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md:1095` records the B-6 verification: `credential_pool.rs` and `session_persistence.rs` are uncompiled dead files, `error_classifier.rs` compiles but has zero production callers, and the item is not a V1 blocker.
- `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md:71` through `:73` corrects the stale "wired into agent_loop" claim and defers the wire/scaffold/delete disposition.
- `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md:615` lists ORPHAN-HERMES-SALVAGE-001 as a remaining user-decision queue item.
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md:14722` through `:14724` records the three orphan inventory rows.
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md:14726` through `:14729` says the three Hermes-parity rows are genuinely open disposition items, not known scaffold.
- `docs/HERMES_REMOVAL_HANDOFF_2026_05_05.md:7` through `:22` records the user intent: remove Hermes-agent bloat while preserving deep work.
- `agent_core/src/lib.rs:21` declares `error_classifier`; `credential_pool` and `session_persistence` are absent from the module list.
- `agent_core/src/credential_pool.rs:13` through `:170` stores provider keys as Rust strings and exposes rotation helpers; no Keychain integration exists in that file.
- `agent_core/src/error_classifier.rs:1` through `:43` defines the structured classifier and `classify`.
- `agent_core/src/error_classifier.rs:274` through `:375` contains the seven unit tests.
- `agent_core/src/session_persistence.rs:36` through `:103` opens `.epistemos/sessions.db` and creates checkpoint/session tables plus FTS.
- `agent_core/src/session.rs:23` through `:178` is the current live agent session-state path.
- `agent_core/src/context_loader.rs:177`, `agent_core/src/agent_loop.rs:229`, and `agent_core/src/bridge.rs:1618` / `:1630` show the current session-context caller chain.
- `Epistemos/Engine/CredentialPool.swift:1` through `:128` is the current Swift Keychain-backed credential pool.
- `Epistemos/Engine/PipelineService.swift:34` through `:93` is the current Swift user-facing chat error classifier.

Verification performed in Terminal E:

- `cargo test --manifest-path agent_core/Cargo.toml --lib error_classifier` passed on 2026-05-16: 7 passed, 0 failed, 1183 filtered out. The run emitted two unrelated dead-code warnings in other test helpers.

## Code Impact Estimate

### Option A impact

Estimated code change: small.

- Docs: record the quarantine decision and per-file future trigger.
- Optional guard: add a drift/source-guard test that makes unreviewed production wiring visible.
- No V1 product behavior changes.

Risk:

- Low runtime risk.
- Moderate process risk if no guard is added, because future audits may keep rediscovering the same three files.

### Option B impact

Estimated code change: large.

- Declare two new Rust modules in `lib.rs`.
- Resolve compilation and test coverage for their internal tests.
- Design a Keychain-safe Rust/Swift credential bridge before credential rotation can be production.
- Design session checkpoint retention, redaction, schema migration, and UI/recovery behavior.
- Define error-classifier policy and bridge it into agent events / Swift UI.

Risk:

- High, because credentials and full-message session checkpoints are sensitive surfaces.
- Likely out of scope for V1.

### Option C impact

Estimated code change: moderate.

- Wire `error_classifier` into the agent loop or bridge error emission path.
- Map Rust categories to Swift `UserFacingChatErrorKind` or replace duplicate logic.
- Add integration tests for user-visible recovery hints.
- Archive or quarantine the other two files with an explicit source-tree decision.

Risk:

- Moderate. Error classification is less sensitive than credentials/session persistence, but duplicate Swift/Rust policy can drift.

### Option D impact

Estimated code change: small to moderate.

- Delete or move all three files.
- Remove `pub mod error_classifier;` from `lib.rs`.
- Preserve the content in an archive if the user wants recoverability.
- Update audit inventory rows.

Risk:

- Low runtime risk.
- High process/user-trust risk unless the archive/provenance is explicit.

## Recommendation

Recommend **Option A: formal quarantine for V1; no product wire now**.

Recommended decision record:

> ORPHAN-HERMES-SALVAGE-001 is not a V1 blocker. Keep `credential_pool.rs`, `error_classifier.rs`, and `session_persistence.rs` as quarantined Hermes-parity salvage for V1. Do not wire `credential_pool.rs` without a Keychain-safe redesign. Do not wire `session_persistence.rs` until it is reconciled against current `agent_core::session` and Swift chat/vault persistence. Keep `error_classifier.rs` tested as the only compiled salvage module, but wire it only in a dedicated error-recovery sprint that resolves duplication with Swift `UserFacingChatErrorKind`.

Reasoning:

- Immediate delete conflicts with the user's explicit "do not delete deep work" instruction.
- Immediate wire is worse: it would introduce credential and session surfaces that have not been reconciled with current MAS architecture.
- The only safe near-term action is to make the quarantine explicit and stop treating the files as blockers.
- The passing `error_classifier` tests are useful preservation evidence, not proof of production wiring.

## Acceptance Criteria

If the user chooses **Option A**:

- Keep all three files out of V1 product behavior.
- Keep `error_classifier` tests passing while it remains compiled.
- Add or maintain a visible audit/guard record so these files cannot be mistaken for shipped capability.
- Require a Keychain-safe design before any credential-pool wire.
- Require a session-schema reconciliation before any session-persistence wire.
- Require a Swift/Rust error-taxonomy reconciliation before wiring `error_classifier`.
- Do not delete or archive the files before V1 without explicit user approval.

If the user chooses **Option B**:

- Produce one implementation plan covering credentials, session persistence, and error classification together.
- Add security tests for credential handling and redaction.
- Add migration/retention tests for session checkpoints.
- Add integration tests proving user-visible recovery behavior.

If the user chooses **Option C**:

- Wire only `error_classifier`.
- Keep or archive the other two with explicit provenance.
- Add tests proving Rust classification changes the visible error path and does not drift from Swift classification.

If the user chooses **Option D**:

- Archive the file contents or cite the preserving git commit before deletion.
- Remove the module declaration for `error_classifier`.
- Update the orphan inventory so the same issue does not recur.

## Decision-Ready Prompt

Choose the ORPHAN-HERMES-SALVAGE-001 disposition:

1. **Recommended:** Formal quarantine for V1; keep all three as preserved salvage, wire none now, and add/maintain guards so they are not mistaken for shipped capability.
2. Wire all three now: credential rotation, session checkpoints, and error classification.
3. Selective salvage: wire `error_classifier`, quarantine/archive `credential_pool` and `session_persistence`.
4. Delete or archive all three now, removing `error_classifier` from `lib.rs`.
