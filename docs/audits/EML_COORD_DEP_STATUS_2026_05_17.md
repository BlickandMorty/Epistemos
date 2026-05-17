# EML Forward-Stage Coordination-Dependency Status — iter 14 check

**Date**: 2026-05-17
**Branch**: codex/t7-eml-2026-05-16 (cut from main)
**Cycle**: post-iter-13 (Phase C)
**Predecessor**: `docs/audits/EML_AUDIT_OF_AUDIT_2026_05_17.md` §5 forward-stage register item 5 ("Coord-dependency unblock checks").

T7's audit-of-audit §5 named four forward-staged integration sites
((a) Tri-Fusion · (b) ConfidenceRouter · (c) Kuramoto · (d) F-VaultRecall)
and committed to re-checking their coordination-blocker status every
10 iters. Iter 14 is the first such check.

Method: re-grep each candidate's host module on the current T7 worktree
(cut from main 2026-05-16). If the host module exists and exposes a
clean extension hook, the site is **unblocked**. If the host module is
absent or its hook is missing, the site remains **forward-staged**.

---

## (a) EML→Tri-Fusion ambiguity resolution — COORD T1

**Re-grep**: `ls agent_core/src/research/tri_fusion* agent_core/src/tri_fusion*`
**Result**: no matches.

**Verdict**: **FORWARD-STAGE HOLDS.** T1's Tri-Fusion module does not
yet exist on main. T1 is iterating on its own branch
(`codex/t1-trifusion-2026-05-16` per the 9-terminal plan; T7 cannot
verify branch state across worktrees). Site (a) remains gated on T1's
merge.

---

## (b) EML→ConfidenceRouter scoring — COORD T2

**Re-grep (Rust side)**: `grep -n "pub struct ConfidenceRouter" agent_core/src/routing.rs`
**Result**: `routing.rs:126` defines `pub struct ConfidenceRouter` with
a `classifier: HeuristicClassifier` field. The `route` method records
into a process-global `RoutingStatsAccumulator` and delegates to
`route_inner`. **No external-score extension hook today.**

**Re-grep (Swift side)**: `head -50 Epistemos/LocalAgent/ConfidenceRouter.swift`
**Result**: Swift `ConfidenceRouter` exists with a typed `Classification`
struct including a `confidence: Double` field. The router has a `Route`
enum + `Reason` enum mapped from heuristics. No `confidenceFloor`
injection hook + no external-score parameter.

**Verdict**: **FORWARD-STAGE HOLDS.** Both Rust + Swift confidence
routers exist but neither exposes the extension hook the doctrine §2.(b)
encoding requires. Wiring EML potential as an inverse-confidence proxy
would need either (i) a `RouteOverlay` trait in Rust + Swift mirror, or
(ii) an `external_score: Option<f64>` parameter at the `route()` entry.
Either change requires coord with T2 (agent_runtime owner) since the
prompt's SCOPE LOCK lists agent_runtime as don't-touch.

**Note**: T7's SCOPE LOCK explicitly forbids touching `agent_runtime`,
but `agent_core::routing` is NOT in that don't-touch list. A future
T7 iter could plausibly add a non-breaking `route_with_overlay()`
method to `routing.rs` and leave the existing `route()` untouched. To
preserve coord boundary, hold this for now.

---

## (c) EML→Kuramoto coupling tempering — COORD T3

**Re-grep**: `ls agent_core/src/research/acs/`
**Result**:
```
autopoiesis.rs
governance.rs
kuramoto.rs
mod.rs
notch_delta.rs
vsm.rs
```

`kuramoto.rs` exists. Per the T7 prompt's SCOPE LOCK explicit don't-
touch list (`uas (T3)` — `research/acs/` IS the UAS-ACS substrate), this
module is **not in T7's write scope**. T3 owns its current state +
extensibility.

**Verdict**: **FORWARD-STAGE HOLDS.** T3's UAS-ACS audit (per
[[project-terminal-t3-override-2026-05-17]] memory) is mid-flight; T7
holds until T3 publishes a coupling-overlay hook + scope-LOCK
boundary is reconfirmed at session level.

---

## (d) EML→F-VaultRecall-50 re-ranking — COORD T4

**Re-grep (vault.rs:495+ per doctrine reference)**: lines 495-500 show
the tail of `index_note` declaration; lines 495-548 referenced in
doctrine §3.30 are the Fix B query-chatter-strip + AND-for-short-queries
patch.

`agent_core/src/storage/vault.rs` is in the T7 prompt's SCOPE LOCK
explicit don't-touch list.

**Verdict**: **FORWARD-STAGE HOLDS.** T4 owns vault.rs. Re-ranking
overlay would need T4 to expose a `Reranker` trait (or accept a `Vec<f64>
external_scores` parameter at the search entry). T7 holds.

---

## §5. Summary

| Site | Status | Blocker | Next-check |
|---|---|---|---|
| (a) Tri-Fusion | FORWARD-STAGE | T1 module not yet on main | next iter-24 cycle |
| (b) ConfidenceRouter | FORWARD-STAGE | No extension hook; SCOPE LOCK boundary | next iter-24 cycle |
| (c) Kuramoto | FORWARD-STAGE | SCOPE LOCK don't-touch (T3 owns) | next iter-24 cycle |
| (d) F-VaultRecall | FORWARD-STAGE | SCOPE LOCK don't-touch (T4 owns) | next iter-24 cycle |

All four sites remain forward-staged. T7's MVP (site (e), SAE
Observatory anomaly augmentation) is the only landed integration.

**Note for the next cycle**: per the audit-of-audit pattern, the iter-
24 check should also re-confirm that T7's commits haven't introduced
drift into the audit/doctrine/FILE-MAP/§3.44 anchors (i.e. cross-link
integrity across the 12+ commits this session). The iter-14 sanity
check above only addresses the forward-stage register; drift detection
on T7-OWN commits is the audit-of-audit's separate concern.

---

*End of coord-dep status. Forward-stage register unchanged.*
