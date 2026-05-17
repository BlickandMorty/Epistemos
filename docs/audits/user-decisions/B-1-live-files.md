# B-1 Live Files — User Decision Research

**Status:** COMPLETE_RESEARCH_READY  
**Date:** 2026-05-16  
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide what, if anything, ships for Live Files in the V1/V1.1 window.

The canonical architecture says a Live File is not executable markdown. The runtime executes a signed `LivePlan.v1` emitted by a compiler, with state-machine gates, capability validation, thermal/battery checks, user-visible prompts, and later NightBrain/auto-research integration. The current repo has a Rust typed seam for the state names and `LivePlanV1` shape, but it is explicitly not a functional compiler or runner.

The decision is therefore not "do Live Files matter?" They are load-bearing for later auto-apply and substrate work. The decision is whether V1 should expose a read-only stub now, whether V1.1 should take on the full Wave 7 implementation, or whether Live Files should be deferred indefinitely.

## Options

### Option A — V1 read-only stub

Ship no Live File execution in V1. Keep the existing Rust typed seam and optionally surface a read-only marker/docs affordance that says a file is Live-capable only after a future compiler exists.

**Pros**
- Lowest risk for MAS review because no file mutation or scheduled agent runner is exposed.
- Uses the current `agent_core/src/live_files/mod.rs` seam without pretending the compiler exists.
- Gives future work a stable vocabulary for `LiveFileState` and `LivePlanV1`.

**Cons**
- A user-visible stub may create expectation without a working product.
- Does not deliver the "document as executable substrate" promise.
- Does not unlock auto-apply research loops; it only preserves the contract.

### Option B — V1.1 full state machine and compiler

Defer user-facing Live Files from V1, then schedule a dedicated V1.1 Wave 7 sprint for the compiler, validator, runner, state transitions, user prompts, and verification gates.

**Pros**
- Matches the doctrine acceptance bar instead of shipping a partial feature as "Live Files."
- Lets the current typed seam stay useful without overclaiming.
- Keeps MAS V1 focused while preserving a concrete post-V1 implementation path.

**Cons**
- Delays a marquee substrate primitive.
- Requires a real cross-layer effort across Rust, Swift UI, event scheduling, provenance, and verification.
- Blocks full auto-apply auto-research until after V1.1.

### Option C — Pro-only Live Files first

Keep MAS V1/V1.1 free of Live File execution and evaluate Live Files first in the Pro channel, where review and entitlement constraints are less strict.

**Pros**
- Reduces MAS reviewer confusion around scheduled mutation and network/file permissions.
- Allows faster iteration on runner semantics before committing to MAS.
- Keeps the MAS binary conservative.

**Cons**
- Splits the substrate story across editions.
- Risks divergence between Pro and MAS policy surfaces.
- Does not remove the need for the same signed-plan, validation, and revocation gates.

### Option D — Defer indefinitely

Do not schedule Live Files for V1.1; leave the typed seam and doctrine as dormant future architecture.

**Pros**
- Eliminates near-term implementation cost.
- Avoids every safety and review concern attached to agent-driven file mutation.

**Cons**
- Undercuts later auto-research, auto-apply, and "executable knowledge" doctrine.
- Leaves multiple downstream rows permanently blocked by a dormant primitive.
- Increases drift risk as adjacent features invent their own smaller execution models.

## Canonical Sources

### `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md`

- Lines 24-30: "Markdown is not the executable." The authority is the signed plan hash.
- Lines 42-60: capabilities, schema validation, Compile-Verify-Mint, and event-driven gating are mandatory.
- Lines 64-120: the canonical model is a 10-state state machine.
- Lines 183-201: the shipped Rust seam is not the full implementation.
- Lines 207-223: a real Wave 7 PR must compile, sign, validate, execute, prompt, verify, and stale-plan-detect.

### `/Users/jojo/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`

- Lines 3-11: FINAL_SYNTHESIS corrections supersede the older 5-state framing.
- Lines 13-15: Wave 7 starts after earlier plan and Obscura waves.
- Lines 126-127: scheduling is event-driven, not polling.
- Lines 318-361: JSON header is machine-consumed and condition logic is a closed grammar.
- Lines 753-844: Phase 17 breaks Live Files into file format/state, rotor, Cognitive Weight, glow UI, conditions/cron, and scans.
- Lines 986-993: the technical architecture includes a rotor, objective loops, closed predicates, and per-file weight.

### `agent_core/src/live_files/mod.rs`

- Lines 1-7: current code is a typed seam, "NOT a functional implementation."
- Lines 26-47: `LiveFileState` already names the 10 states.
- Lines 70-79: `LivePlanV1` exists as the top-level typed shape.
- Lines 167-253: focused unit tests verify state count, run eligibility, revoked read access, invariants count, and JSON round-trip.

### `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`

- Lines 249-257: Live File Compiler doctrine rows remain marked NOT-STARTED.
- Lines 805-809: the summary explicitly says only the seam exists; full state machine remains future work.

### `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`

- Lines 1140-1146: the existing compromise row recommends V1.1 defer and records user override paths.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_2026_05_15.md`

- Lines 26-29: B-1 is framed as the Wave 7 substrate primitive.
- Lines 232-232: the prior audit status says decisions were recorded and user input is requested.

## Code Impact Estimate

### Option A — V1 read-only stub

Estimated implementation: 0-300 LOC if limited to docs and existing Rust seam; 300-700 LOC if a user-facing read-only indicator is added.

Likely files:
- `agent_core/src/live_files/mod.rs` only if tests or metadata helpers are tightened.
- One Swift UI surface if the user wants a visible "Live Files coming later" affordance.
- Existing docs and release notes.

Tests:
- `cargo test --manifest-path agent_core/Cargo.toml live_files`
- Optional Swift UI snapshot or view-model test if a visible stub ships.

### Option B — V1.1 full state machine and compiler

Estimated implementation: 3,000-8,000 LOC across Rust, Swift, tests, and possibly Metal kernels.

Likely files/modules:
- `agent_core/src/live_files/state.rs`
- `agent_core/src/live_files/compiler.rs`
- `agent_core/src/live_files/validator.rs`
- `agent_core/src/live_files/runner.rs`
- `agent_core/src/live_files/rotor.rs`
- `agent_core/src/live_files/conditions.rs`
- `agent_core/src/provenance/ledger.rs`
- future `agent_core/src/security/egress.rs`
- Swift editor/file metadata UI and Live File status surfaces
- Metal kernels only if glow or rotor acceleration ships in the same wave

Tests:
- Rust state-transition tests.
- Schema validation tests for `LivePlan.v1`.
- Sandbox dry-run tests.
- Stale-plan invalidation tests.
- Capability-escalation rejection tests.
- `kani` invariant checks.
- Rotor tick benchmark for active-file event handling.
- Swift UI tests for prompt/revocation/status surfaces.

### Option C — Pro-only Live Files first

Estimated implementation: similar core LOC to Option B, plus edition-gating and distribution policy work.

Likely extra files:
- Pro/MAS capability gating docs.
- Entitlement and release-channel checks.
- Any Pro-only runner registration surfaces.

Tests:
- All Option B tests.
- Edition-gating tests proving MAS does not expose execution.

### Option D — Defer indefinitely

Estimated implementation: docs only now, but downstream future work remains blocked.

Tests:
- None beyond link/citation checks.

## Recommendation

Recommend **Option B: V1.1 full state machine and compiler**, with no V1 user-facing execution surface.

Reasoning:
- The current repo already has the right typed seam, so V1 does not need a noisy placeholder to prevent semantic drift.
- The doctrine's own acceptance bar is too large for a responsible V1 patch: signed compilation, schema validation, dry-run, production execution, user prompts, stale-plan handling, and `kani` verification.
- A partial V1 demo would be the riskiest path because it could look like Live Files while bypassing the actual signed-plan safety model.
- Indefinite deferral is too costly because later auto-research and auto-apply paths depend on Live Files as the safe mutation substrate.

Recommended wording for the decision record:

> Ship V1 with the typed seam only; do not expose Live File execution. Schedule a V1.1 Wave 7 sprint for the complete signed-plan compiler, state machine, validator, runner, prompts, and verification gates.

## Acceptance Criteria

If the user chooses **Option A**:
- No runtime executes markdown or scheduled file mutation.
- Any visible UI is explicitly read-only and cannot toggle execution.
- `cargo test --manifest-path agent_core/Cargo.toml live_files` passes.
- Release notes do not market Live Files as shipped.

If the user chooses **Option B**:
- A markdown source compiles into a signed `LivePlanV1`.
- G1/G4 schema validation rejects malformed or escalating plans.
- G3 sandbox dry-run runs before production execution.
- Runtime executes only the signed plan, never the markdown source.
- Capability changes show a user-visible diff prompt.
- Markdown mutation invalidates the plan and prompts recompilation.
- State machine covers all 10 canonical states with no orphan transitions.
- Revoked state kills execution authority but leaves source readable.
- `kani` checks cover the state-machine invariants.
- Rotor/event scheduling is event-driven, with no polling loop.

If the user chooses **Option C**:
- MAS cannot expose or invoke Live File execution.
- Pro-only status is documented in the feature registry and release notes.
- All signed-plan safety gates still apply in Pro.

If the user chooses **Option D**:
- Dependent auto-research/auto-apply rows are marked blocked or post-V2.
- No adjacent feature invents a parallel file-execution substrate.

## Decision-Ready Prompt

**B-1 Live Files decision:** Which Live Files path should Epistemos take?

1. **V1 read-only stub** — keep current typed seam and optionally expose a non-executing marker; no Live File runtime in V1.
2. **V1.1 full Wave 7** — no V1 user-facing surface; schedule the complete signed-plan compiler/state-machine/runner for V1.1. **Recommended.**
3. **Pro-only first** — evaluate Live File execution in Pro before MAS.
4. **Defer indefinitely** — leave the seam dormant and accept that downstream auto-apply paths remain blocked.

Answer with one option label and any override constraints, for example: "Option 2, but no glow UI in the first V1.1 PR."
