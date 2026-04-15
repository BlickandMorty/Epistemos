# PLAN_V2 Canonicalization Master Prompt

Status: active
Date: 2026-04-14
Audience: Claude Code / continuation agents
Authoring context: generated after a repo-level checkpoint audit on 2026-04-14

Purpose

This prompt is the canonical startup bundle for bringing the repo back into full alignment with `PLAN_V2` through Phase 6.

Your job is not merely to "check Phase 6."

Your job is to:

1. audit Phases 1 through 6 against current code and `PLAN_V2`
2. identify every place where code, docs, tests, and routing authority are drifting
3. fix the real canonicality gaps
4. bring code, routing, tests, and supporting docs back into alignment with `PLAN_V2`
5. determine whether Phase 6 is actually ready to close

Do not treat older handoffs as truth. They are evidence only.

Architecture docs override stale handoffs.
The current local `PLAN_V2.md` is the primary authority unless the user explicitly asks to revise the plan itself.
Current code overrides stale implementation-status claims only for "what is implemented today," not for "what should be canonical."
Closure claims must be backed by current verification.

## Mission

Make the repo canonical with `PLAN_V2` through Phase 6.

That means:

- no major subsystem in code without plan coverage
- no plan deliverable marked complete if code does not actually implement it
- no second control plane in Swift where `PLAN_V2` requires Rust authority
- no Phase 6 closure claim without the required verification evidence
- no stale handoff left to mislead future sessions

Important directionality:

- Prefer changing code to match `PLAN_V2`
- Prefer writing reconciliation notes or handoffs rather than editing `PLAN_V2`
- Do not rewrite `PLAN_V2` to bless drift unless the user explicitly asks for a plan revision

## Non-Negotiable Rules

Preserve these throughout the work:

- Rust is the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` are sibling runtimes.
- No silent backend reroute.
- No silent cloud self-escalation.
- No mid-generation backend switching.
- No second control plane in Swift.
- No hidden permission expansion.
- Destructive communication actions stay explicit and auditable.
- Do not silently widen Phase 6 into Phase 7, marketplace work, memory redesign, or runtime-contract rewrites.
- Do not revert unrelated user/worktree changes.

The user wants canonicality with `PLAN_V2`, not speculative redesign.

## Read In This Exact Order

Read these before making architectural claims or code changes:

1. `/Users/jojo/Downloads/Epistemos/AGENTS.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/README.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
4. `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
5. `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
6. `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
7. `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
8. `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
9. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_1_TO_1_5_HANDOFF.md`
10. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md`
11. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md`
12. `/Users/jojo/Downloads/Epistemos/AGENT_COMMAND_CENTER_UX_HANDOFF.md`
13. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
14. `/Users/jojo/Downloads/Epistemos/docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`
15. `/Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md`

Optional advisory docs after the list above:

- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-27-final-release-closure-report.md`
- `/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-28-manual-runtime-verification-evidence.md`
- other release or research memos under `docs/plans/`

Rule:

- `PLAN_V2` and the architecture bundle override old release memos
- the current local `PLAN_V2.md` is the authority for intended architecture
- do not edit `PLAN_V2.md` during canonicalization unless the user explicitly asks for a plan revision
- current code only tells you what exists now, not what is acceptable to keep

## What You Must Say Before Editing

Your first substantial reply must include:

- the docs you read
- a concise Phase 1-6 scope summary
- an explicit statement that Phase 6 is already substantially implemented in code
- a short list of the top canonicality risks
- a statement of what you will audit before rewriting anything

If you cannot do that, you have not loaded enough context.

## Current Repo Reality You Must Respect

### 1. Phase 1 and 1.5 are in better shape than older handoffs implied

Do not repeat the stale claim that Phase 1.5 is missing capability handshake and plan trace.

Current code reality:

- Rust handshake is live in `/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs`
- Swift surfaces it through `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift`
- `planTracePresent` is a real runtime summary/stats field
- the newer `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_1_TO_1_5_HANDOFF.md` reflects this state

Treat these as landed unless current code disproves them.

### 2. Phase 6 is real code, not a greenfield build

The repo already contains the Phase 6 surfaces:

- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/communication.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/media.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/imessage.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/imessage_contacts.rs`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Channels/ChannelRegistryState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/IMessageDriverSettingsView.swift`

Treat Phase 6 as:

- audit
- reconcile
- harden
- verify
- close

### 3. Some older Clark findings are now stale

Do not blindly propagate these old claims without rechecking code:

- "capability handshake missing"
- "plan trace missing"
- "fallback telemetry missing"
- "iMessage model picker is still hardcoded"
- "iMessage driver has no per-contact rate limit"
- "Command Center tool toggles do not flow authoritatively into Rust"
- "ChatCoordinator has no Phase 6 touch points"

Those claims were true or partly true earlier, but some have already been fixed.

### 4. Code-side Phase 6 hardening already landed

Re-verify these; do not re-implement them from scratch:

- explicit unavailable brains no longer silently reroute
- local agent tool allowlist now propagates through Swift bridge into Rust registry
- relay-to-native fallback telemetry now exists
- iMessage driver now has a 60/hour per-contact reply limiter
- iMessage settings now use dynamic model suggestions instead of a hardcoded preset list
- a Dataview folder-query predicate crash found during this audit was fixed

Relevant files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/bridge.rs`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Channels/ChannelRegistryState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Channels/DriverChannelControlPlane.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/IMessageDriverSettingsView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/DataviewService.swift`

## The Actual Drift List

This is the current canonicality gap list after the 2026-04-14 audit.

### Drift 1 — Highest severity

The Agent Command Center still keeps too much control-plane authority in Swift.

Why this is drift:

- `PLAN_V2` says Swift parses UI state, but Rust should compile the normalized request and own routing, policy, permissions, and runtime truth.
- The repo still has a Swift `CommandCenterRequestCompiler` that resolves:
  - context refs
  - runtime selection truth
  - tool permission allow/deny
  - execution policy / route summaries

Why this matters:

- This is still the single biggest violation of "Rust is the sole control-plane authority."
- Every future tool or phase added to the Command Center path will make the Swift compiler harder to retire.
- It creates two places where request-truth can drift: Swift compiler and Rust runtime.

Current code evidence:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift`

What "fixed" means:

- Swift remains the parser and UI binder only
- Rust gets a real request-compilation entry point, e.g. `compile_command_center_request(...)`
- Rust owns final:
  - runtime resolution
  - permission resolution
  - tool/MCP restriction truth
  - execution policy truth
  - routing truth
- the right-side inspector is fed from Rust-produced canonical request state
- tests prove parity across explicit brain choice, unavailable brain truthfulness, allowlist behavior, and inspector diagnostics

You do not need to throw away the current Swift shapes.
You do need to move authority.

### Drift 2 — High severity, mostly docs/architecture

`PLAN_V2` no longer fully describes the shipped repo through Phase 6.

Specific gaps:

- `PLAN_V2` roadmap stops at Phase 5
- there is no explicit Phase 6 roadmap section in `PLAN_V2`
- the channel subsystem is real code but still not clearly described in the plan
- future agents can no longer tell from `PLAN_V2` which parts of communication/media are planned, shipped, or deferred

Why this matters:

- the repo fails the "canonical plan" test if major shipped code has no plan coverage
- future sessions will keep repeating the same reconciliation work
- stale roadmap docs cause false drift claims

What "fixed" means:

- do not silently edit `PLAN_V2` to accommodate drift
- instead, either:
  - bring code back within existing `PLAN_V2` boundaries
  - or create a separate reconciliation note that explicitly says where code is ahead or divergent
- if the user later wants the plan revised, do that as a deliberate follow-up, not as part of silent canonicalization
- document the channel subsystem in a separate spec or handoff if needed, but do not treat that as permission to weaken `PLAN_V2`

### Drift 3 — Medium severity

`image_generate` is still plan/code mismatched.

Why this is drift:

- `PLAN_V2` says MLX owns image generation and Apple-native auxiliary workloads
- current code uses an explicit FAL cloud call only

Current code evidence:

- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/media.rs`

Why this matters:

- today the mismatch is explicit, not silent, which is good
- but it is still not canonical with the plan
- future agents cannot tell whether the plan or the code is the intended truth

What "fixed" can mean:

Preferred direction:

- move code toward the plan by restoring an MLX-first image path or an equivalent local-first architecture consistent with `PLAN_V2`
- treat FAL as non-canonical until the user explicitly approves a plan revision

Minimum acceptable fallback if that is too large:

- document the mismatch in a separate reconciliation note
- do not claim this surface is canonical with `PLAN_V2`

Do not solve this by silently weakening the plan.

### Drift 4 — Medium severity, closure blocker

Phase 6 still lacks the required manual runtime verification evidence.

Why this is drift:

- the protocol requires both automated and manual verification
- code may be correct and still not be closure-ready

Current status:

- automated verification is strong
- some safe manual checks exist
- real outbound/provider-backed/manual-OS-permission checks are still incomplete

What "fixed" means:

- perform the remaining live checks if credentials and permissions are available
- otherwise document exact blockers precisely and truthfully

No Phase 6 sign-off without this.

### Drift 5 — Verification integrity

A fresh full `xcodebuild test` pass on the current tree still needs to complete end-to-end after the Dataview fix.

Why this matters:

- the full-suite run during this audit surfaced a real non-Phase-6 blocker in `DataviewService`
- that blocker was fixed and the focused Dataview test now passes
- but a complete fresh all-suite success should still be captured before making any release-style closure claim

Current fix:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/DataviewService.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/DataviewServiceTests.swift`

Do not ignore this because it is "outside Phase 6."
The user asked for a canonical checkpoint through Phase 6, not a narrow tool-only pass.

## Things That Are Canonical Enough Today

Do not waste time "fixing" these unless your audit disproves them.

### Phase 1

Looks canonical enough:

- real `gguf` primary path
- `mlx` preserved
- explicit fallback
- runtime truth surfaces
- serial constraints still owned in runtime layer

### Phase 1.5

Looks canonical enough:

- capability handshake
- reasoning profiles
- execution-policy references
- plan-trace presence
- agent-hierarchy scaffolding
- overseer protocol scaffolding
- guardrail scaffold
- KAN scaffold off main path

### Phase 2 and 3 scaffolding

Looks canonical enough for this checkpoint:

- compute steering scaffolding present
- adaptation / canary / rollback / SSM scaffolding present

Do not widen this audit into Phase 7 or speculative research implementation.

## Files You Must Audit

### Canonicality-critical docs

- `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_1_TO_1_5_HANDOFF.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md`
- `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`

### Command Center / control-plane authority

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/CommandCenterRequestCompiler.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/CommandInputParser.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/AgentCommandCenterState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/State/CommandCenterDiagnostics.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/ToolTierBridge.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Bridge/StreamingDelegate.swift`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/bridge.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/registry.rs`

### Phase 6 Rust surfaces

- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/communication.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/media.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/imessage.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/tools/imessage_contacts.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/agent_loop.rs`
- `/Users/jojo/Downloads/Epistemos/agent_core/src/security.rs`

### Phase 6 Swift surfaces

- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Channels/ChannelRegistryState.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/Channels/DriverChannelControlPlane.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/iMessageDriver/IMessageDriverService.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Views/Settings/IMessageDriverSettingsView.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/AppBootstrap.swift`

### Runtime truth surfaces

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/BackendRuntimeContract.swift`
- `/Users/jojo/Downloads/Epistemos/epistemos-core/src/runtime_contract.rs`
- `/Users/jojo/Downloads/Epistemos/epistemos-core/src/compute_steering.rs`
- `/Users/jojo/Downloads/Epistemos/epistemos-core/src/adaptation.rs`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AgentHierarchyProtocol.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/OverseerProtocol.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/LocalGuardrailScaffold.swift`
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/KANPilotScaffold.swift`

### Full-suite blocker found during this audit

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/DataviewService.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/DataviewServiceTests.swift`

## Work Sequence

Follow this order.

### Step 1 — Build a canonicality matrix

Before editing, build a matrix for every named deliverable in `PLAN_V2` through Phase 6.

For each row record:

- plan source of truth
- code surface(s)
- current implementation status
- tests that cover it
- whether the plan accurately documents it
- whether the gap is code, docs, test, or closure-only

At minimum include:

- Phase 1 deliverables
- Phase 1.5 deliverables
- Phase 2 scaffolds
- Phase 3 scaffolds
- Phase 5 Command Center authority requirements
- Phase 6 communication/media/iMessage surfaces
- channel subsystem plan coverage

Do not start editing before this matrix exists.

### Step 2 — Separate stale claims from real drift

You must explicitly separate:

- stale handoff claims
- real code defects
- real architectural drift
- docs-only drift
- verification-only closure gaps

Do not conflate "not documented" with "not implemented."
Do not conflate "not manually verified" with "not coded."
Do not treat "code exists" as permission to rewrite the plan.

### Step 3 — Fix canonicality in this order

1. command-center authority drift
2. plan/docs drift
3. Phase 6 code gaps that remain after re-audit
4. verification gaps
5. stale handoffs/docs

Interpret "plan/docs drift" as:

- first: fix code that violates plan authority
- second: write separate reconciliation docs for drift that cannot be fixed immediately
- last: revise `PLAN_V2` only if the user explicitly wants the plan changed

### Step 4 — Keep scope disciplined

Allowed:

- Rust request-compilation authority work for the Command Center
- separate reconciliation docs or handoffs describing mismatches
- Phase 6 closure hardening
- canonicality tests
- verification improvements

Not allowed unless directly required:

- Phase 7 feature work
- memory system redesign
- marketplace / skill installation work
- speculative research implementation
- broad UI redesign unrelated to canonicality
- silent weakening of `PLAN_V2` to match existing drift

## Verification You Must Run

At minimum rerun these:

```bash
cargo test --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml
cargo test --manifest-path /Users/jojo/Downloads/Epistemos/epistemos-core/Cargo.toml
cd /Users/jojo/Downloads/Epistemos/graph-engine && cargo test
cd /Users/jojo/Downloads/Epistemos/omega-mcp && cargo test
cd /Users/jojo/Downloads/Epistemos/omega-ax && cargo test
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
```

Also rerun focused Command Center and Phase 6 tests as needed, including:

- `EpistemosTests/CommandCenterRequestCompilerTests`
- `EpistemosTests/CommandCenterDiagnosticsTests`
- `EpistemosTests/DeviceAgentServiceTests`
- `EpistemosTests/ControlPlaneSurfaceTests`
- `EpistemosTests/RuntimeValidationTests`
- `EpistemosTests/DataviewServiceTests`

Important note:

`xcodebuild` output contains noisy vendored SwiftLint lines for `CodeEditTextView` and `CodeEditSourceEditor`.
Treat exit code and actual test/build result as authoritative.
Do not misclassify those vendored lines as app test failures if the command exits successfully.

## Manual Verification Status You Inherit

Already observed during this audit:

- safe TTS file output succeeded via `say -o ...`
- iMessage DB access on this machine truthfully fails with `authorization denied` without FDA
- focused Dataview regression test passes after the predicate fix

Still missing unless you can perform them:

- real outbound `send_message`
- provider-backed `vision_analyze`
- real `image_generate`
- real iMessage send
- full iMessage driver end-to-end with permissions and safe recipient

If credentials/permissions are missing, document blockers exactly.

## Current Commands And Results From The 2026-04-14 Audit

These are evidence, not a substitute for your reruns:

- `cargo test --manifest-path agent_core/Cargo.toml` → `471 passed, 0 failed`
- `cargo test --manifest-path epistemos-core/Cargo.toml` → `366 passed, 0 failed`
- `cd graph-engine && cargo test` → `2456 passed, 0 failed, 8 ignored`
- `cd omega-mcp && cargo test` → `126 passed, 0 failed`
- `cd omega-ax && cargo test` → `12 passed, 0 failed`
- `xcodebuild ... build` → succeeded
- focused Command Center + Phase 6 Swift tests → `48 tests in 4 suites, 0 failures`
- first full `xcodebuild test` surfaced a real Dataview predicate crash
- `DataviewService` was fixed
- focused `EpistemosTests/DataviewServiceTests` rerun passed

Do not claim a fresh full-suite green unless you rerun it yourself.

## Specific Fix Already Applied During This Audit

This was a real blocker and is now fixed:

- `DataviewService` folder-based `FROM "Projects"` queries were using a predicate shape SQLite could not generate
- the archive filter remains in SwiftData fetch
- folder matching now happens in post-fetch filtering

Files:

- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/DataviewService.swift`
- `/Users/jojo/Downloads/Epistemos/EpistemosTests/DataviewServiceTests.swift`

Do not undo this.

## Your Final Deliverables

You must finish with:

1. a Phase 1-6 canonicality matrix
2. a drift list ordered by severity
3. the exact files changed
4. the exact commands run
5. exact pass/fail results
6. manual verification evidence or precise blockers
7. separate reconciliation docs or handoffs for any remaining plan/code mismatch
8. a direct answer:
   - `Phase 6 ready to close`
   - or `Phase 6 not ready to close`

If not ready to close, classify each blocker as:

- code
- docs
- test
- environment
- credential
- OS permission

## Copy-Paste Start Prompt

Use everything below as your Claude Code instruction block:

Read `/Users/jojo/Downloads/Epistemos/AGENTS.md` first, then read the canonicalization bundle in this exact order:

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/README.md`
2. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md`
3. `/Users/jojo/Downloads/Epistemos/docs/architecture/CODEX_CONTEXT_PACK.md`
4. `/Users/jojo/Downloads/Epistemos/docs/BACKEND_INTERFACE_SPEC_v1.md`
5. `/Users/jojo/Downloads/Epistemos/docs/architecture/COMPUTE_STEERING_SPEC_v1.md`
6. `/Users/jojo/Downloads/Epistemos/docs/architecture/ADAPTATION_SUBSYSTEM_SPEC_v1.md`
7. `/Users/jojo/Downloads/Epistemos/docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md`
8. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_1_TO_1_5_HANDOFF.md`
9. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_5_HANDOFF.md`
10. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_PROTOCOL.md`
11. `/Users/jojo/Downloads/Epistemos/AGENT_COMMAND_CENTER_UX_HANDOFF.md`
12. `/Users/jojo/Downloads/Epistemos/docs/architecture/PHASE_6_CLARK_HANDOFF_2026_04_14.md`
13. `/Users/jojo/Downloads/Epistemos/docs/TOOL_TIER_AND_IMESSAGE_INTEGRATION.md`
14. `/Users/jojo/Downloads/Epistemos/docs/architecture/RESEARCH_INDEX.md`
15. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md`

Then:

- build a Phase 1-6 canonicality matrix against `PLAN_V2`
- treat older handoffs as evidence, not authority
- do not restart Phase 6 from scratch
- preserve the already-landed Phase 6 hardening
- identify the real remaining drifts
- fix the highest-severity canonicality gaps first
- treat `PLAN_V2` as the architectural authority
- prefer changing code to match `PLAN_V2`
- if code is ahead of or divergent from the plan, write a separate reconciliation note instead of rewriting `PLAN_V2`
- rerun the required verification
- do not call Phase 6 complete without manual-verification evidence or explicit blockers

Most important current drift to resolve:

- the Agent Command Center still keeps request-compilation authority in Swift, which is not fully canonical with `PLAN_V2`

Most important current docs drifts to resolve:

- `PLAN_V2` does not yet express Phase 6
- the channel subsystem is still ahead of the plan
- `image_generate` is FAL cloud-only in code while the plan still implies MLX ownership

Handle those drifts by:

- making code canonical where feasible
- documenting mismatches separately where not yet feasible
- not silently editing `PLAN_V2` unless the user later asks for a deliberate plan revision

Most important closure rule:

- no Phase 6 closure claim without the protocol-required manual verification matrix or explicit blockers
