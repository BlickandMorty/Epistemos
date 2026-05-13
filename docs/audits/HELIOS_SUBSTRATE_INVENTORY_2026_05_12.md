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

3. **`five_planes.rs` → provenance ledger plane anchors**
   - Originally framed as "Five-plane formalism (Audit / Canonical / Truth /
     Witnessed / Verification) would standardize the vocabulary."
   - **First-pass discovery (2026-05-12):** the inventory misnamed the planes.
     The canonical V6.1 §3 five planes are **State / Episodic / Assembly /
     Controller / Verification** (see
     `epistemos-research/src/five_planes.rs::RuntimePlane`). The "Audit /
     Canonical / Truth / Witnessed / Verification" set was a confusion with
     a different doctrine. Plane numbers (1..5) are fixed by V6.1 §3.
   - **Step 1 LANDED (2026-05-12):** added the constants
     `PROVENANCE_STORAGE_PLANE = Episodic` and `PROVENANCE_AUDIT_PLANE = Verification`
     to `epistemos-research/src/five_planes.rs`, mirroring the existing
     `acs.rs::ACS_CANONICAL_PLANE / ACS_AUDIT_PLANE` precedent. Provenance
     ledger storage (`agent_core::provenance::ClaimLedger`) is Episodic;
     replay-bundle audit (`agent_core::provenance::replay::ReplayBundle` +
     `epistemos_trace verify | verify-replay`) is Verification.
   - Doctrine cross-reference blocks added to both
     `agent_core/src/provenance/ledger.rs` and
     `agent_core/src/provenance/replay.rs`.
   - Drift gate `provenance_storage_in_episodic_audit_in_verification` in
     `five_planes.rs::tests` locks both placements + the inequality
     invariant (storage ≠ audit) so the two roles can't collapse onto a
     single plane.
   - Effort remaining: zero unless the ledger or audit surfaces move.

4. **`shadow_memory.rs::MemoryTier` (+ `self_evolving_l_se.rs`) → ShmPool L0 cross-reference**
   - Originally framed as "Six-tier memory taxonomy (L0–L_SE) matches the
     existing memory-pressure response in `agent_core::shared_memory.rs`."
   - **First-pass discovery (2026-05-12):**
     - The 5-tier ladder (L0-L4) lives in `shadow_memory.rs::MemoryTier`, not
       `self_evolving_l_se.rs`. L_SE is the SELF-EVOLVING extension that runs
       ALONGSIDE the ladder (LMM with surprise gradient + nightly SEAL-DoRA).
     - `agent_core::shared_memory::ShmPool` is single-tier — session-scoped
       shared-memory segments with TTL + count eviction, raw-byte payloads.
       That's the **L0 ExactHot** equivalent (bf16_fp16 codec). L1-L4 aren't
       implemented in active code; they're canonical doctrine targets per
       the canon-hardening protocol (`state: candidate`).
     - Renaming `evict_stale` → `evict_l0_stale` would be cosmetic and lose
       the simple "single tier" semantics. The honest move is to document
       the cross-reference and lock the alignment with a drift gate.
   - **Step 1 LANDED (2026-05-12):** doctrine cross-reference block on
     `agent_core::shared_memory::ShmPool` with the full 5-tier table + the
     "L0 only, L1-L4 are doctrine targets" status. Drift gate
     `active_app_shmpool_implements_l0_exact_hot_only` in
     `epistemos-research/src/shadow_memory.rs::tests` locks:
     (a) the L0 canonical name + codec id,
     (b) the L1-L4 canonical names,
     (c) the count invariant (5 doctrine tiers − 1 active = 4 unimplemented).
   - Effort remaining: zero unless agent_core implements L1/L2/L3/L4 tier
     semantics; drift gate is in place either way.

5. **`gate_action.rs` → ApprovalDecision doctrine cross-reference**
   - Originally framed as "GateAction taxonomy gives canonical names for
     accept/deny/escalate/defer."
   - **First-pass discovery (2026-05-12):** the active app already has
     `agent_core::approval::ApprovalDecision` (3-way: AutoApprove /
     RequireApproval / Deny) and `agent_core::command_center::ToolDecision`
     (2-way: Allow / Deny). HELIOS `GateAction` is 6-way (Pass / Hold /
     Quarantine / TriggerEvidenceSupremacy / EngramAnchor /
     MigrateResidency). The two abstractions DIFFER — ApprovalDecision
     gates tool execution; GateAction gates token emission + cognitive
     memory state. They partially overlap on a 3-variant gating slice:
     AutoApprove↔Pass, RequireApproval↔Hold, Deny↔Quarantine.
   - **Step 1 LANDED (2026-05-12):** doctrine cross-reference block + per-
     variant HELIOS-analog tail comments on `ApprovalDecision`. Drift gate
     `active_app_approval_gating_subset_alignment` added in
     `epistemos-research/src/gate_action.rs::tests` that locks the 3-variant
     mapping, the semantic invariants (Pass emits, Hold/Quarantine block,
     neither records persistent state), AND a count invariant (exactly 3
     mapped + 3 HELIOS-only memory-tier actions).
   - **Not migrated:** renaming `ApprovalDecision::AutoApprove` to `Pass`
     etc. would conflate two different abstractions. Doctrine reference is
     the canonical-but-honest move.
   - Effort remaining: zero unless HELIOS adds gating-tier actions beyond
     the current Pass/Hold/Quarantine triplet; drift gate is in place.

### Tier B — useful, larger lift

6. **`mas_capability_lattice.rs` → ToolTier capability-coverage cross-reference**
   - Originally framed as "Computer-use MCP uses ad-hoc capability strings."
   - **First-pass discovery (2026-05-12):**
     - The "full / click / read" strings in computer_use.rs are *actions*,
       not capabilities. The MAS lattice describes a different axis: a
       12-capability × 3-deployment-tier matrix (MasCore / Pro / Research).
     - The active app's `ToolTier` (None/ChatLite/ChatPro/Agent/Full) is the
       chat-mode-aware tool-exposure ladder; the MAS lattice is the
       deployment-tier-aware capability shipping policy. They are orthogonal
       axes — renaming `ToolTier` variants to match `Capability` would
       conflate them.
     - Audited active-app coverage of the 12 HELIOS capabilities:
       * 5 shipped in MAS baseline (SelectedVaultRetrieval, TouchIdGating,
         AppGroupSharedSubstrate, CuratedLocalToolManifests,
         FirstPartyCloudProviderAdapters).
       * 3 shipped on Pro only (ShellOrSubprocessOrchestration,
         AppleEventsAutomation, BrowserAutomation).
       * 4 not implemented yet (SandboxedXpcHelper = state:candidate;
         ArbitraryDownloadedSkills + RawAneOrPrivateFrameworks +
         UnrestrictedWasmOrJit = intentionally not in MAS).
   - **Step 1 LANDED (2026-05-12):** doctrine cross-reference block on
     `agent_core::tools::registry::ToolTier` with the full 12-row coverage
     table mapping each HELIOS Capability to its active-app analog +
     shipping status. Drift gate
     `active_app_capability_coverage_table_locked` in
     `mas_capability_lattice.rs::tests` locks the 12 canonical capability
     names (rename → test break) + the MAS-baseline-vs-Pro-only posture
     invariants from the cross-reference table.
   - Effort remaining: zero unless HELIOS adds capabilities OR the active
     app's MAS/Pro shipping posture for any of the 12 changes.

7. **`learning_modes.rs` → chat metadata standardization** — NO ACTIVE ANALOG
   - Originally framed as "could replace string-based learning-mode field in
     chat metadata."
   - **First-pass discovery (2026-05-12):** HELIOS `LearningMode` is
     `{ Freeze, FastWeight, LoRA, Sketch }` — these are TRAINING-PIPELINE
     modes (frozen weights vs fast-weight programming vs LoRA fine-tuning
     vs gradient sketching). The active app has no training pipeline; the
     chat-mode/routing enums it does have (`LocalRoutingMode`,
     `ChatModelSelection`, `ToolTier`) are about INFERENCE-time model
     selection and tool exposure, a different axis. Renaming any of those
     to `LearningMode::Freeze` would conflate inference behavior with
     training mode and confuse downstream readers.
   - **Verdict (2026-05-12):** no code change. `LearningMode` stays
     research-only with no doctrine cross-reference candidate. The donor-
     distillation + SEAL-DoRA paths it serves are training-pipeline
     doctrine targets per canon-hardening protocol; they don't ship in MAS.
     If a future training pipeline lands in the active app, revisit then.

### Tier C — naming only, mostly cosmetic (CLOSING AUDIT 2026-05-12)

8. **`stack_roles.rs`** — rename internal subsystem roles → ALREADY IMPLICIT
   - HELIOS `StackRole = { RustSpine, MlxHand, MetalNerves }` IS the active
     app's three-language split, already documented at the top of
     `CLAUDE.md`: "Swift 6.0 + Rust (UniFFI FFI) + Metal compute shaders."
   - No active-app enum exists to "rename"; the role split is structural
     (file paths, languages, build configurations). Adding a doctrine
     cross-reference would be either redundant with CLAUDE.md or would
     require introducing a synthetic enum that nothing reads from.
   - **Verdict (2026-05-12):** no code change. The role split is honest
     and visible at the project root.

9. **`acs.rs`** — diagnostics health row → ACS NOT IMPLEMENTED
   - The Settings → General → Diagnostics row exists
     (`EditorBundleHealthRow`, `SearchFusionHealthRow`, etc.), but ACS
     itself ("Anchored Cognitive Substrate") is research-tier and has
     no active-app implementation — there's nothing to surface yet.
   - **Verdict (2026-05-12):** deferred. Revisit if/when ACS anchors
     land in agent_core; until then the diagnostics surface should
     not advertise a feature that doesn't exist.

10. **`engram.rs`** — meaning-anchor naming → DIFFERENT SEMANTICS, DO NOT CONFLATE
    - The inventory hinted at unifying HELIOS `EngramTable` with the
      active app's `MeaningAnchor` (Epistemos/Engine/MeaningAnchorService.swift).
      Closer inspection shows they're DIFFERENT abstractions:
      * HELIOS `EngramTable` is a static-knowledge hash table (facts /
        signatures / dates / API contracts) separated from dynamic
        reasoning — Lane 3 RESEARCH-ONLY, "NEVER ships in MAS" per the
        module's posture comment.
      * Active app `MeaningAnchor` is a per-chat structured snapshot
        (topic, summary, insights, related notes, broader theme,
        confidence) emitted on chat exit and stored as a `.idea`-type
        graph node. It powers retrieval bias + prompt injection.
    - Renaming `MeaningAnchor` → `Engram*` would be a semantic regression
      that confuses readers into thinking the active app implements
      HELIOS's static-knowledge separation, which it doesn't.
    - **Verdict (2026-05-12):** no code change. Names stay distinct.

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

---

## Closing audit summary (2026-05-12)

Six items shipped as documentation + drift-gate cross-references during the
HELIOS V5 loop, two deferred with verdict notes, two left with "no
migration possible" verdicts. Every item that had a defensible active-app
analog now has both a doctrine comment on the active side AND a drift gate
on the research side so neither tier can change silently.

| # | Item                                            | Outcome                          |
|---|-------------------------------------------------|----------------------------------|
| S1 | `hardware_profile.rs` ↔ Swift dual-budget      | Drift gate (alignment table)     |
| S2 | `HardwareTier` ↔ `HardwareProfile`             | Doctrine cross-reference         |
| A3 | `five_planes.rs` ↔ provenance ledger           | Plane anchors + drift gate       |
| A4 | `shadow_memory.rs::MemoryTier` ↔ ShmPool       | L0-only cross-reference + gate   |
| A5 | `gate_action.rs` ↔ `ApprovalDecision`          | Partial mapping + drift gate     |
| B6 | `mas_capability_lattice.rs` ↔ `ToolTier`       | 12-row coverage table + gate     |
| B7 | `learning_modes.rs` → chat metadata            | **No analog** (training pipeline) |
| C8 | `stack_roles.rs` → subsystem roles             | **Already implicit** (CLAUDE.md) |
| C9 | `acs.rs` → diagnostics health row              | **Deferred** (ACS not impl)      |
| C10| `engram.rs` → meaning-anchor naming            | **Different semantics**          |

**What was achieved:** the substrate isolation gap from the start of the
loop ("zero direct references from active app to `epistemos_research::*`,
hermetically isolated by design") is now bridged by 6 documented cross-
references plus drift-gate tests that fire on either-side rename. The
research substrate stays research-tier per canon-hardening protocol; the
active app gets the canonical names + status as inline doctrine without
linking the gated crate.

**What was NOT achieved:** no actual HELIOS module promoted from
`state: candidate` to `state: canon`. That requires WRV (Witnessed-
Reachable-Visible) proof per the canon-hardening protocol and was never
the goal of the loop. The drift gates make a future promotion safer by
ensuring the doctrine and active code stay aligned in the meantime.

**Items explicitly left at doctrine-only state:** the five M2 Max kernels
(`m2_max_kernels.rs`), the L_SE Titans-MAC + SEAL-DoRA pipeline, the ACS
constitutive field, and the Engram static-knowledge separation. Per
canon: `KERNEL_IMPLEMENTATION_POSTURE = canonical_target_not_implemented_here`.

Total: 6 commits, 6 drift gates, 0 semantic risk, full inventory close-out.
