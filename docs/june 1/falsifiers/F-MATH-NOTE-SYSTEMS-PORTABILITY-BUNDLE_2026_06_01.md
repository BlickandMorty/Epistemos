---
state: backlog-falsifier-bundle
created_on: 2026-06-01
umbrella_tag: JUNE1-PATTERNBOOST-LOCK
thread_umbrella_tag: JUNE1-CANON-FUSION-LOCK
source: docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md
status: candidate tests; not implemented unless a later PR wires artifacts
---

# F-Math Note Systems Portability Bundle - 2026-06-01

This bundle turns the math and portable note-system intake into testable gates.
It does not authorize a new editor stack, Tauri shell, CRDT runtime, or repo
code import. It defines what must be proven before those motifs can influence
live product behavior.

## Shared artifact contract

Each falsifier emits:

```text
falsifier_id
source_doc
fixture_id
source_of_truth_kind
source_digest_before
source_digest_after
delta_count
projection_version
projection_digest
loss_budget
latency_ms
allocation_count_if_measured
license_status
rollback_ref
answer_packet_visibility
pass
failure_reason
```

## Falsifier Matrix

| Falsifier | Pass condition | Rejects |
|---|---|---|
| `F-EditorDeltaMonoid` | Synthetic insert/delete/replace/AI-stream deltas compose deterministically, preserve selection/scroll metadata, and carry undo inverse or reason absent. | Whole-document replacement masquerading as incremental edit, missing undo, or selection loss. |
| `F-ProjectionFunctor-Digest` | Derived Markdown/search/plain/graph projections bind source digest, projection version, loss budget, and output digest across fixture edits. | Derived views that cannot prove what source produced them. |
| `F-MarkdownSidecar-Portability` | A vault note remains readable and useful as Markdown when Epistemos is removed; sidecar JSON is additive and may be regenerated or ignored. | Proprietary-only required data hidden outside Markdown. |
| `F-IncrementalParseForest` | Long-note and rapid-edit fixtures reparse only changed ranges and stay within per-keystroke latency budget. | Full reparse on every edit, syntax-error crash, or hot-path allocation spike. |
| `F-DifferentialKnowledgeView` | Backlinks, graph edges, tag views, and review queues update from deltas and beat full rebuild on held-out edit batches. | Whole-vault rebuild for small edits or stale derived views. |
| `F-CRDTVaultConflict` | Concurrent same-note and sidecar edits either merge by documented CRDT law or emit conflict witnesses with no data loss. | Silent last-writer-wins loss or unexplainable conflict resolution. |
| `F-GitVaultLineage` | File body, YAML frontmatter, sidecar, and derived projections bind to commit IDs and restore refs. | Git history that cannot restore or explain note-state changes. |
| `F-FSRSNoteReview` | Note/block/concept resurfacing beats recency-only and random surfacing on a held-out utility/recall task and reports why each item surfaced. | Notification vibes, opaque recommendations, or review loops with no measured utility. |
| `F-SemanticEntropyGate` | High semantic uncertainty fixtures route to abstain, citation, verifier, or follow-up rather than unsupported confidence. | Treating uncertainty score as truth or suppressing answer risk. |
| `F-ConstrainedMutationDecode` | Model-authored note edits, query ASTs, and tool arguments are accepted only when incremental parse and schema checks pass. | Post-hoc JSON repair as the only guard for dangerous mutations. |
| `F-LicensePortabilityGate` | Every external repo motif is classified as importable, source-mine-only, or rejected with license, dependency, and setup notes. | Copying source before license/setup/vendor review. |

## Required fixture families

1. **Long markdown note.** Large body with headings, links, code fences, math,
   callouts, and tables.
2. **AI streaming zone.** Tokens append below a protected divider while user
   edits above it.
3. **Rich `.epdoc` package.** ProseMirror JSON with `shadow.md` and searchable
   block projection.
4. **External editor drift.** Markdown file changes outside Epistemos.
5. **Concurrent edit.** Two actors modify overlapping ranges and sidecar fields.
6. **Frontmatter lens.** Optional type fields are missing, extra, and renamed.
7. **Git restore.** Note, sidecar, and projection are restored from history.
8. **Review queue.** Recency-only, random, and FSRS-style resurfacing compete.
9. **High-uncertainty answer.** Candidate generations cluster into conflicting
   meanings.
10. **Bad mutation JSON.** Model emits invalid, partial, or malicious edit
    packet.
11. **License trap.** AGPL source motif appears in a proposed product import.

## Build order

1. Define artifact schemas over current note/editor fixtures.
2. Add `F-LicensePortabilityGate` before any source import work.
3. Add `F-EditorDeltaMonoid` and `F-ProjectionFunctor-Digest`.
4. Add `F-MarkdownSidecar-Portability` and `F-GitVaultLineage`.
5. Add `F-IncrementalParseForest` only after latency fixture exists.
6. Add `F-DifferentialKnowledgeView` against current projector/index baselines.
7. Add `F-FSRSNoteReview`, `F-SemanticEntropyGate`, and
   `F-ConstrainedMutationDecode` as Pro Research gates.
8. Add CRDT fixtures only after the single-device vault path is fully stable.

## Product locks

- Mac app remains native Swift/AppKit/TextKit unless a later architecture vote
  explicitly changes that.
- Tauri repos are reference systems for this repo, not live shell migrations.
- AGPL code is source-mine-only until a deliberate license strategy exists.
- Markdown remains user-readable; sidecars are additive.
- Derived projections must name source digest, projection version, and loss
  budget.
- No hot-path editor parse/index/model work without measured latency proof.

## Companion gates

- Cache-lineage autoresearch:
  `docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`
- Constructive residency:
  `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- Existing editor rules:
  `docs/windows_research_handoff/06_notes_editor_and_textkit_patterns.md`
