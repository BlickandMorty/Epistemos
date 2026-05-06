---
state: canon
canon_promoted_on: 2026-05-05
covers: discipline for future "dead-code" audits — preserve scaffold, only delete proven-dead
trigger: user instruction 2026-05-05 + CodeEditorContentDebouncer near-miss
---

# Preservation-First Audit Policy — 2026-05-05

> **User instruction (verbatim 2026-05-05):** *"the most importnat thing is tha in the hrdenning u dont get rid of hte things i obv wnat to keep unless its dead code in the past dead code. was mixed up with the scaffodl and thnigs i wanted to keep but were not wried only built."*
>
> **Trigger:** Codex's earlier audit pass flagged `CodeEditorContentDebouncer` as orphan/dead because it had zero callers — but it was canonical intentional scaffold the user wanted wired (not deleted). Codex correctly wired it instead. This near-miss makes the discipline explicit.

## The rule

**NEVER auto-delete a file or symbol based on "no callers found" alone.** Every audit-and-delete action requires ALL THREE:

1. **Proven-dead chain** — the file/symbol is unreachable from any user-facing entry point AND has been unreachable for ≥ 1 release cycle (check `git log --since=...`).
2. **Superseded-by replacement** — there is a named replacement in the current code that does the same job. Cite the replacement file path in the deletion commit message.
3. **Explicit user OR Codex sign-off** — the user or Codex has approved the deletion in writing for THIS file. No blanket "delete all unused" approvals.

If ANY of the three fails, the file is **scaffold to preserve**, not dead code to delete.

## The two categories

| Category | Indicators | Action |
|---|---|---|
| **Scaffold (PRESERVE)** | Has been added recently (`git log` shows recent commits). Has documentation comments referring to it as "wired" / "next slice" / "TODO wire" / "future use". Compiles + has tests. NO replacement exists. | **WIRE OR PRESERVE** — never delete. Wiring may require finding the right call site + adding it. If unsure, leave alone. |
| **Dead-code (DELETE)** | Has not been touched in ≥ 1 release cycle. Documentation references say "removed" / "superseded by X" / "deprecated". Replacement exists and is the canonical path. Tests against the dead file have been removed or marked `@available(*, unavailable)`. | **DELETE** — with explicit per-file commit message citing replacement + linked sign-off. |

## Why "no callers found" is insufficient

Three failure modes the CodeEditorContentDebouncer near-miss revealed:

1. **Forward-staged scaffold:** the file is intentionally added BEFORE its first caller, with the wiring planned for a follow-up commit. "No callers" = "wiring incomplete" not "dead."
2. **Test-only callers:** the file is exercised by tests but not yet by production. "No production callers" = "in-flight migration" not "dead."
3. **Indirect callers via reflection / runtime registry:** the file registers itself with a tool registry, agent registry, or similar dynamic dispatch. "No direct callers" = "called via registry" not "dead."

A conservative auditor checks for ALL THREE failure modes before classifying any file as dead.

## Suggested marker convention (proposal — not yet applied)

To make scaffold visually distinguishable from dead-code, propose adding a doc-comment header convention:

```swift
// MARK: - Intentional scaffold (W7.17.b — wire in EpdocEditorChromeView)
//
// This view is registered with the chrome controller's panel registry
// but the controller's `installPanel(_:)` call site is staged for the
// next slice. Do NOT delete — wiring is in flight per
// docs/sprint-sessions/W7.17.b.md.
```

```rust
//! # Intentional scaffold (Phase 8.D — wire in CompanionRegistry)
//!
//! This module is the canonical companion-registration substrate.
//! Currently invoked only from cognitive_dag tests; the live caller
//! lands when companion lifecycle goes live in V2.x continual-learning
//! work. Do NOT delete — wiring is held until lifecycle ships.
```

The marker doesn't have to be syntactically enforced; it just has to be searchable. A future doctrine linter (B6?) could refuse to land a deletion commit that touches a file with the `Intentional scaffold` marker without an explicit `closes scaffold marker per <commit>` line in the deletion commit.

## How to run an audit-with-preservation pass

For each candidate dead-code file:

1. **Git log check:** `git log --oneline --since="6 months ago" -- <file>` — if recent activity, default to PRESERVE.
2. **Symbol-presence check:** `grep -rn '<SymbolName>' --include='*.swift' --include='*.rs'` — count callers including test-only.
3. **Doc-comment check:** read the file's header; look for "scaffold" / "wire" / "TODO" / "follow-up slice" / "next phase" markers.
4. **Replacement check:** does a different file/module do the same job today? If YES, cite the replacement; if NO, the file is the canonical path.
5. **Per-file commit message:** state the WHY for deletion. "No callers found" is INSUFFICIENT. Required: superseded by X / proven dead since Y / explicit sign-off Z.

If steps 1-4 don't all line up for deletion, **the file is scaffold to preserve**.

## Examples

### Example: CodeEditorContentDebouncer (preserved + wired by Codex)

- Step 1 git log: recent commits. → PRESERVE-LEANING.
- Step 2 callers: zero direct callers; one ad-hoc 500ms Task debounce in CodeEditorView doing the same job. → SUPERSEDED IN REVERSE (the dead is the ad-hoc, not the canonical helper).
- Step 3 doc comments: described as the canonical 300ms quiet-window helper. → PRESERVE.
- Step 4 replacement: ad-hoc Task debounce IS the duplicate; the file IS the canonical replacement. → WIRE, don't delete.
- Outcome: Codex correctly wired CodeEditorContentDebouncer + replaced the ad-hoc Task debounce + added a source guard test. ✅

### Example: Hermes subprocess (deleted 2026-05-05)

- Step 1 git log: deletion commits explicitly. → CONFIRMED-DEAD.
- Step 2 callers: zero after subprocess removal commits. → DEAD.
- Step 3 doc comments: marked SUPERSEDED in `docs/_archive/hermes-removal-2026-05-05/`. → DEAD.
- Step 4 replacement: `agent_core::agent_runtime` (in-process Rust) named explicitly in CLAUDE.md. → REPLACEMENT NAMED.
- Outcome: deleted with explicit commits citing replacement + user sign-off. ✅

### Example (counter-factual): hypothetical "delete CodeEditorContentDebouncer"

- Would have been WRONG because step 4 fails — there's no canonical replacement; the file IS the canonical replacement for the duplicated ad-hoc Task debounce in CodeEditorView.
- Caught by Codex's preservation discipline.
- This is the failure mode the user's 2026-05-05 instruction guards against.

## Cross-refs

- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — canon promotion protocol (this preservation policy is the deletion-side counterpart of the canon promotion protocol's promotion-side discipline)
- `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` — B5 source-guard sweep that previously identified 3 orphan files in `agent_core/src/tools/` — Codex's continuation correctly distinguished the 2 dead (`code_execution.rs`, `graph_query.rs` — superseded by cli_passthrough + graph.rs) from the 1 scaffold (`note_tools.rs` — promoted to compiled registry)
- `docs/CODEX_FULL_HANDOFF_2026_05_05.md` §4.2 — orphan source files held for sign-off (correctly distinguished + resolved)

## Bottom line

**Preserve by default. Delete only with proven-dead + superseded-by + sign-off.** When in doubt, leave the file alone — a near-miss that deletes wanted scaffold costs more than a near-miss that leaves behind unused but compiling code.
