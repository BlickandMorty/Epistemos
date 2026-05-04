# Capture Routing Classifier — Resonance Gate Direction Component — 2026-05-04

This document preserves the Quick Capture worktree's `route_capture` prototype
as a canonical T4 Resonance Gate input without bulk-copying the donor
implementation.

## Donor Authority

Sources:

- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/route/mod.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/route/variant_a.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/route/variant_b.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/route/variant_c.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/grammar/mod.rs`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/schemas/route_capture.input.v1.json`
- `.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/schemas/route_capture.output.v1.json`

## Product Intent

Quick Capture needs to decide where a user's captured thought belongs without
rewriting the user's words. The classifier is the direction component of the
Resonance Gate: it can place, merge, create a folder, or defer with traceable
confidence and alternatives.

The important canon is the ladder and schema, not the exact donor module
layout.

## Four Actions

The action enum has exactly four values:

| Action | Meaning |
|---|---|
| `place` | Put the capture into an existing folder |
| `merge_into_existing_note` | Append to an existing note when the merge gate passes |
| `create_folder` | Propose a new folder when the new-concept gate passes |
| `defer` | Route to review; this is a high-trust fallback, not failure |

No fifth action should be added without a canon update and schema migration.

## Schemas

Input schema id: `epistemos://schemas/route_capture.input.v1.json`

Required fields:

- `capture_text`: byte-exact user text, 1 to 2000 characters.
- `vault_tree`: folder path, centroid id, note count, and optional exemplar
  titles.
- `recent_captures`: recent text, placement path, and timestamp context.

Output schema id: `epistemos://schemas/route_capture.output.v1.json`

Required fields:

- `action`
- `confidence`
- `reasoning_trace`
- `alternative_paths`

Optional action-specific fields:

- `folder_path`
- `target_note_path`
- `new_folder_name`

`reasoning_trace` is hard-capped at 280 characters. `alternative_paths` is
hard-capped at three entries.

## Variant Ladder

The ladder is A -> B -> C -> D. Floors are floors, not hints.

| Variant | Method | Accepted output | Floor / gate |
|---|---|---|---|
| A | Deterministic cosine against folder medoids | `place` | confidence >= 0.85 |
| B | GBNF / llguidance closed-vocab classifier | `place` or self-`defer` | confidence >= 0.75 for place; self-defer accepted at any confidence |
| C | Concept-anchored graph/neighbour routing | `place`, `merge_into_existing_note`, `create_folder` | confidence >= 0.70 |
| D | Fallback review route | `defer` | always available |

Variant A excludes `_inbox/*`, excludes folders with fewer than three notes,
uses no LLM, and targets a sub-50ms hot path.

Variant B builds a grammar from allowed vault paths plus `NEW` and `DEFER`.
Invalid paths should be structurally impossible at decode time.

Variant C is the only variant that can emit `merge_into_existing_note` or
`create_folder`. Its gates are:

- Merge: confidence >= 0.90 and target note last-edited age greater than 24h.
- Create folder: new concept with no existing concept within cosine 0.92,
  at least three neighbours clustered at cosine >= 0.80, and no existing parent
  folder fits.
- Otherwise, when at least three neighbours agree, place by neighbour majority
  at confidence 0.70.

Variant D routes to `_inbox/review/`, sets confidence to 1.0 because the system
is certain about deferring, and carries up to three alternatives for quick user
override.

## Grammar Contract

The donor grammar module compiles JSON Schema into `llguidance`'s
`TopLevelGrammar`. The intended production rule is:

- tool names are closed over the registered Tool V2 catalog;
- route outputs are closed over the current allowed vault paths;
- unknown tool names, missing required fields, and type-mismatched arguments are
  structurally impossible at decode time;
- CRANE-style open thinking / closed commit remains a wrapper around the typed
  output schema, not a license for unconstrained final answers.

Do not hand-write a divergent grammar when this lands in main. Reuse the schema
compiler path or document why the compiler cannot represent the needed shape.

## Recovery Placement

Track: T4 Resonance Gate, with T5 Tools V2 and T13 agent-runtime dependencies.

Recovery stage:

- A-F recovery: preserve the ladder, schemas, thresholds, and grammar contract.
- B.1 / Hermes runtime slice: keep `structure.route_capture` available as a
  typed command target after the Tool V2 name migration.
- V2 Cognitive DAG: represent routing decisions as typed replayable events so
  capture placement can be verified, corrected, and time-traveled.

## Live Gap

This classifier is not yet wired in main. The live recovery state is doctrine
promotion plus the Tools V2 alias anchor. The next implementation slice should:

1. Add schema files or regenerate them from Rust types in main.
2. Introduce route decision types behind existing MAS/Pro feature gates.
3. Add tests for the exact four actions and variant floors.
4. Wire UI visibility so deferred captures and alternatives are user-facing.
5. Attach ExecutionReceipt and RunEventLog records to any mutating placement.

Until those steps land, the donor remains a prototype authority, not shipped
runtime.
