---
state: audit
created_on: 2026-05-12
scope: epistemos-research crate (39 .rs files, ~11,230 LOC) — what's wired into the active app, what stays research-tier, what could reasonably be ported forward
---

# HELIOS Substrate Inventory — 2026-05-12

User request: "I want to make sure I have all my things" — concern that HELIOS architecture work is sitting in `epistemos-research` and never reaching the active app.

## Top-level finding

**Zero direct references** from `Epistemos/**/*.swift` or `agent_core/**/*.rs` to `epistemos_research::*`. The crate is hermetically isolated by design: it's gated behind `--features research` and represents the **doctrine-target tier** — load-bearing math + canon constants — that the active app must EVENTUALLY conform to but does not yet implement.

Per the canonical plan §"What gets deferred and why":

> HELIOS V6.1 GPU kernels (SemiseparableBlockScan, LocalRecallIsland, PageGather, ControllerKernelPack, PacketRouter1bit) — these are doctrine targets in the research substrate, NOT graph-engine work. They live in `epistemos-research` behind `--features research` and remain `KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"`.

That separation is intentional. Promoting a research module into the active app is a deliberate decision — per the CANON_HARDENING_PROTOCOL_2026_05_05.md, items must transition `state: candidate → state: canon` via WRV (Witnessed-Reachable-Visible) proof.

## Module-by-module audit

| # | Module | Posture | App impact | Migration candidate? |
|---|---|---|---|---|
| 1 | `acs.rs` | ACS (Active Capacity Substrate) canon | None (doctrine) | **Maybe** — defines audit-plane checks that could feed a Diagnostics health row |
| 2 | `agent_swarm.rs` | Hermes Gateway-era swarm contract | Superseded — Hermes purged 2026-05-05 | No — purged namespace |
| 3 | `cargo_features.rs` | 9 canonical Cargo feature taxonomy | Build-system substrate | No — meta-doctrine |
| 4 | `cms_v2.rs` | Compute/Memory Stack v2 | None (doctrine) | **Maybe** — memory-tier router could surface as runtime budget gate |
| 5 | `cross_domain_lens.rs` | T_safety bound + 5 lenses | None (doctrine) | No — pure math substrate |
| 6 | `donor_distillation.rs` | Training pipeline canon | None (research-only, marked) | No — explicit no-implement |
| 7 | `engram.rs` | Memory engram doctrine | None | **Maybe** — could inform meaning-anchor system memory rep |
| 8 | `falsifier_actions.rs` | Falsifier verdict actions | None | No — research-tier verification |
| 9 | `five_planes.rs` | Five-plane formalism | None (doctrine) | **Yes (high-value)** — five-plane vocab (Audit / Canonical / Truth / Witnessed / Verification) maps directly onto provenance ledger + agent runtime; would standardize naming |
| 10 | `gate_action.rs` | ResonanceGate GateAction taxonomy | None | **Yes** — gate actions are real runtime decisions; could replace ad-hoc safety-gate strings in `agent_core::security` |
| 11 | `goodfire_vpd_specs.rs` | Goodfire VPD baseline numerics | None (research-only) | No — public-baseline only |
| 12 | `hardware_profile.rs` | M2Pro16Gb / M2Max profiles + budgets | **Active value** — runtime budget enforcement | **Yes (high-value)** — could feed the existing `PowerGuard` + memory-pressure subsystem with the canonical 10.5 GB ship budget |
| 13 | `interrupt_score.rs` | Interrupt score formula | None (Swift CPU canonical per V6.2) | **Yes** — V6.2 says Swift CPU is canonical; the Rust reference is the validation oracle |
| 14 | `kv_direct_gate.rs` | KV-Direct gate doctrine | **Already in MLX** — direct gate is wired | Confirm parity, no migration needed |
| 15 | `lane4_falsifier.rs` | Lane 4 verdict format | None | No — research lane |
| 16 | `learning_modes.rs` | LearningMode + Direction taxonomy | None | **Maybe** — could replace string-based learning-mode field in chat metadata |
| 17 | `m2_max_kernels.rs` | 5 load-bearing kernels (research-only) | None | **No** — explicit `KERNEL_IMPLEMENTATION_POSTURE = "canonical_target_not_implemented_here"` |
| 18 | `mas_capability_lattice.rs` | MAS capability lattice | None | **Maybe** — could harden the `request_access` / capability system in computer-use MCP |
| 19 | `mathematical_pillars.rs` | Theorem status canon | None (proof substrate) | No |
| 20 | `scientific_calculator_basis.rs` | SCB doctrine | None | No |
| 21 | `self_evolving_l_se.rs` | L_SE six-tier memory | None | **Yes (high-value)** — six-tier memory (L0–L_SE: register/SIMD/L1/L2/L3/SLC/DRAM/SSD/SE) is exactly the eviction pattern app needs; matches existing memory-pressure hooks |
| 22 | `shadow_memory.rs` | Shadow memory taxonomy | **Partial** — epistemos-shadow crate exists | Confirm taxonomy parity |
| 23 | `sherry.rs` | Sherry doctrine | None | No — research-only |
| 24 | `stack_roles.rs` | Stack roles taxonomy | None | **Maybe** — could rename internal subsystem roles to canonical names |
| 25 | `ternary_kernel.rs` | Ternary kernel (BitNet b1.58) | **Active** — BitNet b1.58 shader exists | Confirm parity |
| 26 | `theorem_status.rs` | E1-E7 / H1-H17 / PCF status | None (proof substrate) | No |
| 27 | `theorems/` | Theorem proofs | None | No |
| 28 | `ulp_compare.rs` | Sign-correct ULP distance | Used in 1-2 Rust tests | Already integrated |
| 29 | `v6_1.rs` | V6.1 canon substrate | None | No — meta-doctrine |
| 30 | `v6_2.rs` | V6.2 canon delta | None | No — meta-doctrine |

## High-value migration candidates (ranked by ROI)

These are HELIOS modules where porting forward would deliver concrete app value, not just naming consistency. Each carries a "wire-up sketch" — the minimum integration step.

### Tier S — high ROI, low risk

1. **`hardware_profile.rs` → PowerGuard / HardwareTierManager budget alignment**
   - V6.2 locks `M2Pro16Gb` as the ship rig with a 10.5 GB ceiling
   - **First-pass discovery (2026-05-12):** `Epistemos/State/PowerGuard.swift` is a
     three-mode state machine (`.full/.eco/.lowPower`); it does NOT own RAM-budget
     numbers. The active analog of `realistic_resident_budget_gb` lives in
     `Epistemos/Omega/Inference/HardwareTierManager.swift`
     (`computeDualModelBudget = totalBytes * 0.60`).
   - **Step 1 LANDED (2026-05-12):** added
     `helios_swift_dual_budget_alignment_table` test in
     `epistemos-research/src/hardware_profile.rs` documenting per-profile drift:
     M2Pro18Gb matches Swift 60% (10.8 GB), M2Pro16Gb intentionally diverges
     (10.5 vs 9.6 — doctrine sweet-spot), M2Max64Gb diverges by design
     (12.0 vs 38.4 — V6.1 PEAK_RAM ceiling). Test breaks if either side
     changes silently.
   - **Step 2 (pending):** decide whether to (a) align Swift's uniform 60% formula
     onto HELIOS doctrine where they diverge, or (b) keep the divergence
     documented as canonical. The 16 GB profile divergence is intentional
     (doctrine > Swift formula by ~1 GB); aligning would loosen the budget on
     16 GB rigs and is a release-quality decision, not a drive-by patch.
   - Effort remaining: ~1 commit if (a), zero if (b). Drift gate is in place
     either way.

2. **`hardware_profile.rs` → AppBootstrap Hardware tier logging**
   - User's startup log shows `Hardware tier: pro-18GB` — that string is computed by Swift
   - Could read canonical tier from research crate to ensure the tier classification matches doctrine
   - Effort: ~1 commit

### Tier A — high ROI, moderate risk

3. **`five_planes.rs` → provenance ledger naming**
   - Provenance ledger (`agent_core::provenance`) already has "claim" / "evidence" / "retraction" concepts
   - Five-plane formalism (Audit / Canonical / Truth / Witnessed / Verification) would standardize the vocabulary
   - Effort: doc-rename pass + per-plane invariant tests

4. **`self_evolving_l_se.rs` → memory eviction policy**
   - Six-tier memory taxonomy (L0–L_SE) matches the existing memory-pressure response in `agent_core::shared_memory.rs`
   - Already have `evict_stale` + `evict_oldest_n` hooks — could rename to L_n tiers + add canonical TTL per tier
   - Effort: ~2 commits

5. **`gate_action.rs` → safety-gate canonical names**
   - `agent_core::security::harden_cli_subprocess` and the approval system use ad-hoc string gate names
   - GateAction taxonomy gives canonical names for accept/deny/escalate/defer
   - Effort: ~1 commit + Swift mirror

### Tier B — useful, larger lift

6. **`mas_capability_lattice.rs` → computer-use capability hardening**
   - Computer-use MCP uses ad-hoc capability strings ("full", "click", "read")
   - MAS lattice formalizes capability transitions
   - Effort: ~3-5 commits to fully wire

7. **`learning_modes.rs` → chat metadata standardization**
   - Chat metadata has string-based mode fields
   - Canonical enum would catch typos at compile time
   - Effort: ~2 commits

### Tier C — naming only, mostly cosmetic

8. **`stack_roles.rs`** — rename internal subsystem roles
9. **`acs.rs`** — diagnostics health row
10. **`engram.rs`** — meaning-anchor naming

## Items explicitly NOT migrating

These stay in `epistemos-research` per canon:

- All theorem proofs (`theorem_status.rs`, `theorems/`, `mathematical_pillars.rs`)
- All research-only kernels (`m2_max_kernels.rs` — explicit marker)
- All training-pipeline doctrine (`donor_distillation.rs`)
- Baseline numerics with revalidation gates (`goodfire_vpd_specs.rs`)
- Meta-doctrine (V5/V6.1/V6.2 canon files)

## Recommended next-session action

If user wants to actively migrate HELIOS work forward, the highest-leverage commit chain is:

1. **Tier S #1** — `HardwareProfile` FFI surface + Swift consumer (~1 day)
2. **Tier A #4** — Six-tier memory eviction policy ports (~2 days)
3. **Tier A #3** — Five-plane provenance ledger naming pass (~3 days)

Total: ~1 week of focused work to fold the highest-impact HELIOS substrate into the active app.

The rest (Tier B, Tier C) can be opportunistic during related feature work.
