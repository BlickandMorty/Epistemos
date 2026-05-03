---
role: claude-red-team
slice: rrf-search-fusion-health-row-pr35
brief: docs/fusion/deliberation/rrf_search_fusion_health_row_pr35_deliberation_2026_05_03.md
date: 2026-05-03
attacks_total: 3
p0_attacks: 0
p1_attacks: 1
p2_attacks: 2
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Catches the draft polling loop and narrows the Phase 6 claim before implementation.
---

## Attacks

### A1 - Draft row polls indefinitely while Settings is open [P1]

**Surface:** `Epistemos/Views/Settings/SearchFusionHealthRow.swift`
**Attack:** The current draft uses `.task` plus `while !Task.isCancelled`. Even though it is scoped to Settings, the brief's own failure-proof gate forbids timers/polling in this row. An event-driven refresh from `SearchFusionMetrics` is smaller and more aligned with the performance doctrine.
**Evidence:** `Epistemos/Views/Settings/SearchFusionHealthRow.swift:75`; `docs/fusion/fleet/rrf-search-fusion-health-row-pr35/aggregator.md`
**Mitigation proposed:** Add a metrics-change notification to `SearchFusionMetrics`, refresh the row with `.onReceive`, and source-guard no `Timer`, `DispatchSourceTimer`, `repeatForever`, or `while !Task.isCancelled` remains in the row.

### A2 - Phase 6 wording can accidentally imply default-flag completion [P2]

**Surface:** brief acceptance and future current-state update
**Attack:** Phase 6 contains two halves: Settings observability and a later 3-day dogfood/default flip. The brief is mostly clear, but any current-state update must say "observability half only" and keep dogfood/default flip blocked.
**Evidence:** `docs/RRF_FUSION_PROMPT.md:90`; `docs/RRF_FUSION_DESIGN.md:272`
**Mitigation proposed:** In docs and commit message, say PR35 closes "Phase 6 observability row" only and explicitly leaves default-ON MAS flip deferred.

### A3 - Existing SettingsView Sovereign symbols are grep-noisy [P2]

**Surface:** `Epistemos/Views/Settings/SettingsView.swift`
**Attack:** The invariant grep reports pre-existing `.deviceOwnerAuthentication` symbols in `SettingsView`. This slice does not add them, but the audit packet must distinguish unchanged Sovereign Gate routing from a new biometric bypass.
**Evidence:** `git show HEAD:Epistemos/Views/Settings/SettingsView.swift`
**Mitigation proposed:** Treat those hits as pre-existing and unchanged. Do not add `LAContext`, `evaluatePolicy`, or any new auth prompt in PR35.

## Brief Verdict

Do not ship the draft as-is. Ship after A1 is fixed and A2/A3 are documented in the guard/current-state update. No P0 found.
