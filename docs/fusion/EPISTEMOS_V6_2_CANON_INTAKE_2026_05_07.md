---
state: canon-intake
created_on: 2026-05-07
source: "docs/fusion/jordan's research/helios v6.2.md"
scope: V6.2 Lean verification canon, M2 Pro 16GB falsifier handbook, V6.1 delta
verdict: V6_2_ACCEPTED_AS_STRICT_DELTA_NOT_APP_RENAME
---

# Epistemos V6.2 Canon Intake - 2026-05-07

This intake records the load-bearing content from
`docs/fusion/jordan's research/helios v6.2.md` and pins how the current
Epistemos build should reference it.

V6.2 does not fork the product. It sharpens the verification envelope:

> If it works on Jojo's M2 Pro 16 GB, it can ship. If it requires a
> workstation, it is research-tier.

Product name remains **Epistemos**. **Helios** remains the architecture /
substrate canon name. A future clean repo may use a project codename, but
the current app should not split brand identity until the existing
Epistemos build is fully finished and audited.

## Authority Placement

V6.2 layers under the May 3 Jordan executive-add index and above ordinary
donor research for the topics it explicitly covers:

- hardware falsifier rig
- Lean verification envelope
- V6.1 to V6.2 delta
- M2 Pro 16GB budget revisions
- dependency-ordered Stage 0 to Stage 3 plan

It preserves the V6.1 lock phrase and five-plane / three-stream runtime
formalism. It does not remove V5/V6/V6.1 nuance; it retags what cannot fit
the 16GB ship rig.

## Load-Bearing Deltas

| Area | V6.1 posture | V6.2 posture |
|---|---|---|
| Ship rig | M2 Max reference was too prominent | M2 Pro 16GB is the shippability lock |
| PageGather | 70% of theoretical / M2 Max language | 70% of measured `BW_baseline_M2Pro`, 1s windows |
| LocalRecallIsland | 128K default-like falsifier | 32K Core, 128K Stretch |
| SemiseparableBlockScan | 128K primary | 32K Core, 128K Stretch |
| InterruptScore | Metal kernel framing | Swift CPU canonical; Metal shadow only for batches >=64 tokens |
| Lean | older/stale pin language | Lean 4.29.1, mathlib v4.29.0-rc6, LeanCopilot CI-only until aligned |
| Goodfire VPD | 9972 / 205 / 2.1% public-confirmed | V6.2 source warned to reverify; Codex revalidated live page on intake |
| Timelines | "one Monday" could read as schedule | lock phrase only, no calendar commitment |

## Feature Preservation Matrix

| Feature family | Status after V6.2 |
|---|---|
| Five planes | Preserved: State, Episodic, Assembly, Controller, Verification |
| Three streams | Preserved: MAS, Pro, Vault |
| Attention as interrupt | Preserved and strengthened by CPU `InterruptScore` expected path |
| AnswerPacket audit | Preserved: `attention_mode` and static fallback acknowledgement remain required |
| ACS | Preserved: Episodic plane storage, Verification plane audit |
| Goodfire VPD | Preserved for atlas/observability; runtime acceleration remains candidate |
| T35/T36/T37/T42 | Preserved; falsifiers must run against M2 Pro 16GB Core lanes first |
| Donor-distillation | Preserved as research/training ramp, not MAS prerequisite |
| Granite family | Expanded: H-1B / H-350M floor options become relevant for 16GB budgets |
| Lean theorem work | Strengthened: every theorem gets a Lean statement; sorry burn-down is visible |

## Codex Web Revalidation Notes

Targeted intake validation checked primary/current sources for the facts most
likely to drift:

- Apple support page 111340 confirms M2 Pro 14-inch 2023 options including
  12-core CPU / 19-core GPU, 16GB unified memory, and 200GB/s memory
  bandwidth.
- Lean release page confirms Lean `v4.29.1` as the current latest stable
  release family, with `v4.30.0-rc*` still pre-release.
- mathlib4 release page confirms `v4.29.0-rc6` as a tagged pre-release.
- Goodfire's public page currently exposes the VPD table with total
  `38912`, alive `9972`, mean L0 `205.0`, and `0.021` activity fraction.

## Implementation Hooks Landed

- `epistemos-research/src/v6_2.rs` records the V6.2 hardware lock, Core
  falsifier budgets, dependency order, and Goodfire revalidation posture.
- `epistemos-research/tests/canonical_consistency.rs` now cross-checks V6.2
  against the existing V6.1 kernel targets and user hardware profile.
- `epistemos-research/src/goodfire_vpd_specs.rs` now carries the V6.2 intake
  note so future agents do not accidentally demote the 2.1% public table
  after it has been revalidated.

## Next Work

The next real implementation gate is still the hardware falsifier harness,
not app renaming:

1. PageGather baseline on the M2 Pro 16GB rig.
2. PageGather scatter against 70% of measured baseline.
3. Swift CPU InterruptScore with P99 < 100us.
4. PacketRouter1bit dispatch P99 < 100us.
5. ControllerKernelPack reference-equivalence tests.
6. SemiseparableBlockScan correctness against `ssd_minimal.py`.
7. LocalRecallIsland 32K Core passkey / NIAH trials.

The current app remains Epistemos. Helios is the north-star substrate name.
