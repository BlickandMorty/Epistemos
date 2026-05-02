---
role: claude-red-team
slice: oplog-replay-bundle-export-pr5
brief: docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 5
p0_attacks: 0
p1_attacks: 0
p2_attacks: 3
p3_attacks: 2
verdict: brief-approved
usefulness: +1
usefulness_reason: Approves the bounded Swift-only brief while tightening privacy, path-scope, and verification guardrails.
---

## Attacks

### A1 - ReplayBundle may export source payload JSON without an explicit privacy boundary [P2]
**Surface:** Implementation contract, records export; `MutationOpLogReplay.swift` record fields
**Attack:** The brief requires exporting `records` but does not say whether `MutationOpLogReplayRecord.sourcePayloadJSON` is allowed in the public bundle. Today the projector stores a summary payload, not full note text, but the field name and existing replay record make it easy for the export type to serialize the raw string by default. That would create a sticky privacy footgun for future projection payload expansion, especially because this is classified Core and described as evidence export.
**Evidence:** `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:40`; `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:14`; `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogProjector.swift:139`; `MASTER_RESEARCH_INDEX_2026_05_02.md` §1; `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` lines 431-435
**Mitigation proposed:** Keep the brief approved, but revise the implementation contract before coding to name the bundle record schema explicitly. Either omit `sourcePayloadJSON` from exported records or export only a clearly named `sourcePayloadSummaryJSON` with a test proving note bodies, prompt bodies, chat history, cwd, vault paths, and system prompts do not appear in deterministic JSON.

### A2 - Allowed `docs/fusion/**` write scope is broader than the slice needs [P2]
**Surface:** Allowed write set and protected-path acceptance
**Attack:** The brief claims the write set is narrowed below Card 6, but `docs/fusion/**` allows edits to unrelated canon, deliberations, fleet artifacts, or indexes. The acceptance scan then becomes too weak because any accidental broad doc edit would still be "inside the allowed write set." This is not source-code dangerous, but it is canon-drift dangerous in a fleet workflow where docs are authority.
**Evidence:** `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:18`; `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:66`; `MASTER_RESEARCH_INDEX_2026_05_02.md` §1
**Mitigation proposed:** Narrow docs writes to the specific PR5 fleet/deliberation artifacts that must be updated, or state that implementation should not edit docs except adding its completion evidence under `docs/fusion/fleet/oplog-replay-bundle-export-pr5/`. Keep source/test ownership unchanged.

### A3 - Failure-proof grep is informational, not a failing guard [P2]
**Surface:** Failure-proof guardrails
**Attack:** The guardrail uses plain `rg` for forbidden symbols, which exits successfully when it finds matches. It also searches for broad words like `rollback` and `repair` that can appear in test names or negative assertions, so it cannot distinguish safe mentions from forbidden behavior. As written, this command can produce alarming output without failing the build or can pass as a human-only checklist.
**Evidence:** `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:81`; `AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 6
**Mitigation proposed:** Change the guard to an explicit negative assertion with scoped patterns, for example `! rg -n "@_silgen_name|oplog_append_payload_json|markMutationProjectionOutboxProjected|recordMutationProjectionOutboxFailure|claimMutationProjectionOutboxRows" ...`, and handle allowed words like rollback only through positive tests that prove cutoff inspection is read-only.

### A4 - Replay count semantics are underspecified for ignored entries, duplicates, and cutoff [P3]
**Surface:** Implementation contract and acceptance
**Attack:** The brief asks for `replayed entry count`, `record count`, `duplicate count`, and `ignored non-projection count`, but it does not define whether replayed entries means all entries after cutoff filtering, all projection entries, unique records only, or records plus duplicates plus ignored entries. Current replay tracks records, duplicates, ignored rows, and highest sequence, but not a processed-entry total. A builder could choose any reasonable count and still satisfy the prose.
**Evidence:** `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:40`; `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:47`; `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/MutationOpLogReplay.swift:77`
**Mitigation proposed:** Define `replayedEntryCount` as the number of entries processed at or below `cutoffSeq`, including ignored non-projections and duplicate projections, then add one test with projection, duplicate, ignored, and cutoff-above-tail cases.

### A5 - Edge-case test ladder misses empty, max sequence, and unicode identifiers [P3]
**Surface:** Tests and acceptance
**Attack:** The brief names deterministic JSON and real-bridge tests, but the AGENTS edge-case ladder requires empty, max, unicode, and rapid/concurrent where relevant. This export is pure data, so empty snapshots, `UInt64.max` sequence/cutoff, and unicode mutation/artifact identifiers are cheap regression tests that would catch encoder ordering and integer-boundary mistakes. The omission is not a blocker because the slice is read-only, but it weakens the "deterministic evidence export" claim.
**Evidence:** `/Users/jojo/Downloads/Epistemos/AGENTS.md`; `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:53`; `/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/oplog_replay_bundle_export_pr5_deliberation_2026_05_02.md:60`
**Mitigation proposed:** Add one focused edge-case test that exports an empty snapshot and a synthetic snapshot with unicode IDs plus `UInt64.max` sequence values. No production code, Rust ABI, EventStore, or generated binding changes are needed.

## Brief verdict
Red Team would ship this brief. There are no P0/P1 blockers: tier classification is Core-compatible, the slice stays Swift-only, Rust ABI/generated bindings are forbidden, EventStore mutation and rollback/repair execution are explicitly out of scope, and current code confirms replay snapshots already exist without bundle export. The smallest improvement before dispatch is to tighten export privacy and docs write scope in prose, then make the forbidden-symbol grep an actual failing guard.
