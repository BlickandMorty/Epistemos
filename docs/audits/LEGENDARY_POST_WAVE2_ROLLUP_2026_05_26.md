# LEGENDARY Post-Wave-2 Roll-Up - 2026-05-26

Status: checkpoint and next-terminal map.

Source of truth: `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`.

This roll-up exists because the stash recovery queue is now closed, but the
architecture is not done. The next work is not "find more old stash work"; it is
new terminal work from current `main`.

## Current Ground Truth

- `main` is the checkpoint branch.
- Recovery checkpoint tag:
  `checkpoint/stash-substrate-research-queue-closed-2026-05-26`.
- The lattice coordinate explainer is present at
  `artifacts/lattice-coordinate-explainer/index.html`.
- The lattice explainer keeps the ambition map and now carries a 2026-05-26
  checkpoint overlay so old Wave-1 rows do not masquerade as current state.
- The active product-recovery stash queue is closed by
  `docs/audits/STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md`.
- Draft PRs `#81` and `#82` are preservation references, not merge queues.

## Numbers To Treat As Working Estimates

- Substrate floor: about 92 percent after Wave 2.
- W-rows wired: about 30 of 53 after Wave 2.
- Falsifier artifact files on main: 10.
- Green claims still require production wiring plus matching witness/falsifier.

These are not release claims. A future full LEGENDARY run can refine the exact
count, but it must not demote already-merged product surfaces just because old
HTML rows or old terminal prompts say "pending."

## Completed / No Longer Pending

- T14 Five-plane UAS bridge is live on main.
- T25 ACS naming reconciliation lint is live in
  `agent_core/src/bin/epistemos_doctrine_lint.rs`.
- T11 System G real seam is on main.
- T22 Substrate Health panel row expansion is on main.
- W-13 Power-user mode Settings toggle is live.
- W-20 / W-27 B-prime chat provenance and AnswerPacket badge surfaces are live.
- W-29 Unified Substrate Health panel is live.
- W-30 Settings weight-class badges are live, with broader policy enforcement
  still deferred.
- W-32 Experimental Features Settings panel is live.
- W-46/W-47 Eidos bridge and citation validation gate are live.
- W-46/W-47 ACS adapter and proof carrier are live.
- W-52 CSISafeguard production caller gate is live.

## Next Terminal Wave

### Wave 3 - Agent Path Closure

1. AgentBlueprint end-to-end replay UI.
2. Deterministic RunEventLog replay into visible AnswerPacket output.
3. Per-model agent metadata badges: `HONEST`, `EXPERIMENTAL`, `OFF`.
4. System G timeline replay surface.

This is the right next wave because it turns the now-landed runtime substrate
into a visible, replayable user path.

### Wave 4 - UAS / ClaimLedger / Graph Closure

1. `hybrid_search` returns typed `Vec<UasAddress>`.
2. `UasKind` appears on agent traces.
3. `AcsAnchor` lands in ClaimLedger.
4. `page_gather` escalates through vault retrieval.
5. Cognitive DAG visualizer.
6. Tri-Fusion typed mutations in `agent_runtime`.

This is the next substrate wave because it moves the "everything is one
substrate object" doctrine from Settings witnesses into the data plane.

### Side Hardeners

These are small, parallel-safe hardening terminals:

- W-49: `IMessageDriverService` App Store guard.
- W-50: `MemoryTier` / residency enum reconciliation. Guard live in
  `docs/audits/W50_RESIDENCY_TIER_RECONCILIATION_2026_05_26.md`.
- W-53: `ModelDownloadManager` SHA256 / LFS verification.
- D-27: scoped `F-ACS-Anchor-Addressing` harness, codeword
  `RESUME ACS ANCHOR HARNESS`.

## Do Not Reopen As Stash Work

The following are preserved but closed for current product recovery:

- `stash@{0}`, `stash@{2}`, `stash@{3}`, `stash@{5}`, `stash@{6}`,
  `stash@{7}`, `stash@{8}`, `stash@{9}`, `stash@{13}`, `stash@{14}`,
  `stash@{15}`, `stash@{16}`, `stash@{17}`, `stash@{18}`, and `stash@{19}`.

If any future agent wants to revive one anyway, it must write a decision doc,
extract a focused patch, and prove that the new slice is not deleting newer
main. No raw stash pop. No raw stash checkout. No bulk apply.
