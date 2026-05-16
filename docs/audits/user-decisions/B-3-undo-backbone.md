# B-3 Undo Backbone — User Decision Research

**Status:** COMPLETE_RESEARCH_READY  
**Date:** 2026-05-16  
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide the Undo backbone direction: ship the existing Effect/Inverse plus UndoLog architecture as the canonical substrate now, defer the full product Undo surface to Wave 10+, or choose a different architecture such as CRDT/Operational Transform.

The reconciliation gate materially changes the decision. `agent_core/src/effect/` is already in main and Hermes 2.0 §5.4 already records it as shipped. `agent_core/src/undo/` is also already in main with a SQLite-backed `UndoLog`, TTL classes, `mark_undone`, and eviction tests. The open question is not whether an Undo substrate exists; it does. The open question is whether to ratify Effect/Inverse plus UndoLog as canonical for B-3/H-3 consumers, how soon to wire apply-inverse execution and user-facing undo rows/buttons, and whether to defer CRDT/OT to multi-device/collaborative futures.

## Options

### Option A — Ratify Effect/Inverse + UndoLog now; wire consumers in V1.1

Choose the already-shipped Effect/Inverse plus SQLite UndoLog architecture as canonical. Treat MAS V1 as already having the substrate. Schedule V1.1 consumer wiring for low-confidence re-learn rollback, `edit_note_block` undo rows, apply-inverse execution, retention task hookup, and user-visible Undo buttons.

**Pros**
- Matches current code and Hermes §5.4 doctrine.
- Avoids inventing a second Undo architecture.
- Keeps the current local-first single-writer scope simple.
- Gives H-3 EditPage and B-3 confidence/re-learn a concrete rollback primitive.

**Cons**
- Still needs product wiring: consumer calls into the undo ledger, apply-inverse executor, UI affordance, and retention task scheduling.
- Does not solve multi-device merge conflicts by itself.
- Existing code has inverse computation but not a full user-facing undo stack.

### Option B — Wave 7 ship-now full product Undo

Immediately build the full user-facing Undo product around the existing Effect/Inverse + UndoLog substrate: inverse application executor, chat/editor buttons, consumer-specific writes, retention scheduling, and tests for each destructive tool path.

**Pros**
- Fastest way to make the shipped substrate visible to users.
- Reduces fear around agent-driven edits before H-3/EditPage lands.
- Creates a verification harness for future mutation tools.

**Cons**
- Touches broad product surfaces outside Terminal E's scope.
- Competes with V1 closure and sibling implementation tracks.
- Risky if built before final H-3/EditPage and B-3 re-learn tool shapes settle.

### Option C — Wave 10+ defer full Undo product

Keep Effect/Inverse in code as dormant substrate, but defer all user-facing Undo work until a later Wave 10+ replay/graph/oplog milestone.

**Pros**
- Minimal near-term implementation pressure.
- Aligns full historical/time-travel UX with later graph/oplog architecture.

**Cons**
- Leaves V1.1 mutation features without a user-visible rollback story.
- Wastes an already-shipped substrate.
- Forces H-3/EditPage and auto-research to either block or invent ad hoc rollback affordances.

### Option D — Replace with CRDT/OT architecture

Do not choose Effect/Inverse as the primary Undo backbone. Instead, move toward CRDT/Operational Transform or a graph OpLog-first model.

**Pros**
- Better long-term fit for multi-device collaborative editing.
- Can support branch/merge and time-travel features when the graph becomes event-sourced.

**Cons**
- Overbuilt for current single-user/local-first scope.
- Canonical graph plan explicitly defers CRDT sync to v2+.
- Would duplicate the already-shipped Effect/Inverse + UndoLog stack.
- OT is text-operation-centric and does not naturally cover vault, concept graph, memory, and agent tool effects.

## Canonical Sources

### `agent_core/src/effect/`

- `mod.rs` lines 18-53: `Effect` already has success variants including vault, concept, memory, noop, abort, and reversed.
- `mod.rs` lines 55-92: `compute_inverse` maps each effect to an inverse or `NotReversible`.
- `mod.rs` lines 95-139: `PriorState`, `Inverse`, and `is_reversible()` exist.
- `mod.rs` lines 141-160: `ApplyError` and `IntentApplier` define typed failure and apply surfaces.
- `dispatcher.rs` lines 45-82: `IntentDispatcher` routes typed intents to vault/concept/memory appliers.
- `vault_applier.rs` lines 44-107: vault writes, moves, and deletes produce effects and prior state/shadow paths.
- `receipt.rs` lines 14-24: `ExecutionReceipt` records tool execution fields and capabilities.

### `agent_core/src/undo/`

- `mod.rs` lines 1-2: the module is a SQLite-backed universal undo log recovered from the Quick Capture salvage track.
- `mod.rs` lines 14-31: `undo_events` schema records timestamp, session, intent, effect, inverse, TTL, and undone flag, with TTL and session indexes.
- `mod.rs` lines 33-34: canonical TTL classes exist for routine undo rows and auto-research undo rows.
- `mod.rs` lines 57-67: `UndoEntry` stores intent/effect/inverse JSON plus session and TTL metadata.
- `mod.rs` lines 101-235: `UndoLog` exposes `open`, `open_in_memory`, `append`, `get`, `recent`, `mark_undone`, `has_undo_since`, `evict_expired`, `len`, and `is_empty`.

### `agent_core/tests/undo_salvage.rs`

- Lines 25-38: append/get round-trips JSON effect and inverse.
- Lines 40-55: recent rows filter by session and order newest first.
- Lines 57-73: `mark_undone` returns inverse, flips the flag, records acceptance signal, and rejects duplicate undo.
- Lines 75-90: expired entries cannot be undone and eviction removes only past-TTL rows.
- Lines 92-118: routine and auto-research TTL classes match canon.
- Lines 120-128: file-backed log creates the canonical schema at `.epistemos/undo_events.sqlite`.

### `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`

- Lines 534-540: Hermes §5.4 marks the Intent→Effect subsystem shipped and describes the architecture.
- Lines 542-551: the six main files and their roles are listed.
- Lines 569-584: Effect→Inverse pairing is the Undo discipline.
- Lines 628-632: V1 ships the subsystem; V1.1 consumes it for B-3/H-3.
- Lines 634-643: crosslinks name B-3 Confidence Meter and H-3/EditPage consumers.

### `docs/NIGHTBRAIN_SCHEDULER_POLICY_2026_05_15.md`

- Lines 138-158: UndoEvictionTask is specified as a future retention consumer.
- Lines 288-295: the scheduler crosslinks Hermes §5.4 as the Undo backbone.

### `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md`

- Lines 63-64: CRDT sync is deferred; v1 uses single-writer oplog scope.
- Lines 79-80: Yjs/Automerge are rejected for v1.
- Lines 501-506: multi-device CRDT and graph topology CRDT are v2+.

### `agent_core/src/oplog.rs`

- Lines 1-5: the current graph OpLog is explicitly hand-rolled and not Automerge/yrs/diamond-types.
- Lines 12-17: the foundation ships the Op enum, serde wire format, and append/iterate APIs; persistent GRDB and Swift subscription are later work.

### `docs/RESEARCH_DOSSIER_TIER_3_4.md`

- Lines 1915-1925: W9.27 recommends hand-rolled OpLog first, not Automerge/yrs/diamond-types.
- Lines 1936-1948: OpLog enables future time travel, undo, and CRDT-friendly replication.

### `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`

- Line 1166: MAS §8 records the B2-M10 §5.0 catch that the Effect subsystem is already shipped.

## Code Impact Estimate

### Option A — Ratify Effect/Inverse + UndoLog now; wire consumers in V1.1

Estimated implementation: 800-2,000 LOC for V1.1 consumer wiring, mostly outside the already-shipped substrate.

Likely files/modules:
- `agent_core/src/effect/` only for small additions such as inverse application helpers.
- `agent_core/src/undo/` only for small integration helpers if consumer code needs typed wrappers around stored JSON values.
- H-3/EditPage tool implementation when it lands.
- B-3 confidence/re-learn consumer path.
- Chat transcript/editor UI Undo affordance.
- NightBrain UndoEvictionTask body or retention integration.

Tests:
- Unit tests for inverse computation and inverse application.
- Integration tests for write/move/delete rollback.
- Existing ledger persistence/retention tests should remain green; add consumer-specific append/mark-undo tests.
- UI tests for Undo button availability on reversible effects.

### Option B — Wave 7 ship-now full product Undo

Estimated implementation: 2,500-5,500 LOC across Rust runtime, Swift UI, and tests.

Likely extra work:
- End-to-end mutation ledger integration using existing `UndoLog`.
- Apply-inverse executor.
- Rollback UI for chat, note edits, and auto-apply wins.
- Source-of-truth policy for conflicting user edits after an effect.
- Release-quality copy and safety prompts.

Tests:
- All Option A tests.
- End-to-end user flow tests from agent edit → receipt → undo → audit trail.
- Conflict tests when original target changed after effect.

### Option C — Wave 10+ defer

Estimated implementation now: docs only.

Future work remains at least Option A-sized, plus graph/oplog integration.

Tests:
- None now beyond citation/status checks.

### Option D — Replace with CRDT/OT

Estimated implementation: 8,000-20,000 LOC depending on whether it covers text only, graph topology, vault files, and tool effects.

Likely files/modules:
- Graph OpLog storage and replay.
- Swift subscription/mirror layer.
- CRDT/OT dependency integration or custom operation model.
- Migration from existing Effect/Inverse semantics.

Tests:
- Replay/fold correctness.
- Merge conflict tests.
- Multi-device simulation.
- Migration tests from existing effects and graph state.

## Recommendation

Recommend **Option A: ratify Effect/Inverse + UndoLog now; wire consumers in V1.1**.

Reasoning:
- The code and Hermes doctrine already agree on Effect/Inverse, and the repo already has a tested SQLite UndoLog. Re-deciding the architecture would create drift.
- Current app scope is local-first and single-writer; CRDT/OT is future multi-device/collaboration infrastructure, not the right backbone for today's agent tool effects.
- Full user-facing Undo is valuable, but shipping it immediately as a broad Wave 7 product slice would cross into sibling implementation scope and may outrun H-3/EditPage and B-3 re-learn tool definitions.
- Deferring to Wave 10+ is too late because V1.1 mutation features need a rollback contract.

Recommended wording for the decision record:

> Choose Effect/Inverse plus UndoLog as the canonical Undo backbone now. MAS V1 already ships the substrate. V1.1 wires it into concrete consumers: H-3/EditPage, B-3 confidence re-learn, apply-inverse execution, visible Undo buttons, and UndoEvictionTask retention. CRDT/OT stays deferred to v2+/Wave 10+ graph/multi-device work.

## Acceptance Criteria

If the user chooses **Option A**:
- No second Undo architecture is introduced.
- Every new destructive agent tool emits an `Effect`, optional `PriorState`, and `ExecutionReceipt`.
- Reversible effects persist their `Inverse` into the existing `UndoLog`.
- UI shows Undo only when `Inverse::is_reversible()` is true.
- Undo application emits `Effect::Reversed` and a new receipt.
- UndoEvictionTask or equivalent retention policy handles expired rows.
- CRDT/OT docs remain future-scope and do not block V1.1 mutation features.

If the user chooses **Option B**:
- All Option A criteria land immediately.
- End-to-end user-visible Undo works for vault write/move/delete before H-3/EditPage ships.
- Conflict handling is specified for target-changed-after-effect cases.

If the user chooses **Option C**:
- H-3/EditPage and B-3 re-learn must either remain blocked or explicitly ship without rollback.
- Existing Effect/Inverse code remains documented as substrate only.

If the user chooses **Option D**:
- A migration plan explains how current Effect/Inverse receipts map into CRDT/OT or OpLog events.
- Graph/vault/text scopes are separated so OT does not pretend to solve non-text effects.
- Multi-device/collaboration requirements are signed off before implementation begins.

## Decision-Ready Prompt

**B-3 Undo backbone decision:** Which Undo architecture and timing should Epistemos use?

1. **Ratify Effect/Inverse + UndoLog now; wire V1.1 consumers** — keep the shipped architecture, use it for H-3/EditPage and B-3 re-learn rollback, and defer CRDT/OT to v2+. **Recommended.**
2. **Full Wave 7 product Undo now** — immediately build user-visible undo ledger/buttons around the existing substrate.
3. **Wave 10+ defer** — leave Effect/Inverse dormant until a later graph/oplog/time-travel milestone.
4. **Replace with CRDT/OT** — redesign Undo around collaboration/multi-device semantics instead of Effect/Inverse.

Answer with one option label and any constraints, for example: "Option 1, but Undo UI only for H-3 edits in the first V1.1 PR."
