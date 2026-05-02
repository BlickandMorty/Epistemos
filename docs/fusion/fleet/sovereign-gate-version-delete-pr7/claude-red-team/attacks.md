---
role: claude-red-team
slice: sovereign-gate-version-delete-pr7
brief: docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 4
p0_attacks: 0
p1_attacks: 2
p2_attacks: 1
p3_attacks: 1
verdict: brief-revise
usefulness: +1
usefulness_reason: Identified async selected-version drift and missing source guard before code was written.
---

## Attacks

### A1 - Async auth could delete a different selected version [P1]
**Surface:** `DiffSheetView.selectedVersion` and `deleteSelectedVersion()`.
**Attack:** The first brief authorized a selected version, then planned to call the current zero-argument delete path after `await`. Because selection is mutable UI state, the user could select another version before auth returns.
**Evidence:** [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:43), [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:559)
**Mitigation proposed:** Capture the `SDPageVersion` before awaiting auth and delete that exact captured value through an overload.

### A2 - Acceptance did not prove the menu path is gated [P1]
**Surface:** `Delete This Version` button and `RuntimeValidationTests`.
**Attack:** Mapper-only tests prove the classification helper, but not that the destructive menu action stopped calling `deleteSelectedVersion()` directly.
**Evidence:** [DiffSheetView.swift](/Users/jojo/Downloads/Epistemos/Epistemos/Views/Notes/DiffSheetView.swift:218), [RuntimeValidationTests.swift](/Users/jojo/Downloads/Epistemos/EpistemosTests/RuntimeValidationTests.swift:3566)
**Mitigation proposed:** Add a source guard that the menu section calls `requestSelectedVersionDeleteAuthorization()` and does not call `deleteSelectedVersion()` directly.

### A3 - Red-team artifact was referenced before it existed [P2]
**Surface:** Fleet evidence packet in the deliberation brief.
**Attack:** The first brief listed `claude-red-team/attacks.md` before the artifact existed.
**Evidence:** [sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md](/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md:60)
**Mitigation proposed:** Write this attack packet and update the brief status after addressing P1s.

### A4 - Docs write scope was broader than needed [P3]
**Surface:** Allowed files in the deliberation brief.
**Attack:** `docs/fusion/**` was too broad for a one-surface migration.
**Evidence:** [sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md](/Users/jojo/Downloads/Epistemos/docs/fusion/deliberation/sovereign_gate_version_delete_pr7_deliberation_2026_05_02.md:14)
**Mitigation proposed:** Narrow docs scope to this slice's deliberation, fleet artifacts, current-state, and workcard updates.

## Brief verdict
Revise before implementation. The smallest safe revision is to require captured-version deletion, add a source guard for the destructive menu action, and narrow the docs write scope.
