# Epistemos Fusion Handoff — Kimi+GPT as Reference, Codex Builds Canonical — 2026-05-03

> **READ FIRST — FRAMING CORRECTION (Jordan, 2026-05-03):**
>
> Kimi and GPT did **deep research and produced mockups**. Neither agent had access to
> the canonical Epistemos docs/code on this disk. Their workspaces under
> `/Users/jojo/Downloads/kimis deep research/` and `/Users/jojo/Downloads/GPT research/`
> are **research-grade reference material, not production code, not canon, not
> ratified for the Epistemos tree.** The "21 audit cycles passed" claim in Kimi's
> META_AUDIT_REPORT.md is self-audit inside Kimi's own sandbox — it does **not**
> mean the work is consistent with Epistemos doctrine.
>
> **What this means for Codex:**
>
> 1. **Do NOT `git mv` or `cp` any Kimi/GPT file into the Epistemos tree.**
>    Read the file, extract the design intent, then re-derive a canonical
>    implementation that lives in the Epistemos repo and matches Epistemos style,
>    naming, modules, doctrine, and the existing in-tree canon
>    (Resonance Gate, Sovereign Gate, AgentEvent, MutationEnvelope,
>    HermesCommandDispatcher, AppBootstrap, etc.).
> 2. **Treat every Kimi/GPT file as a `.reference.md` peer-research note**, not as
>    source. The disposition tables in §1 below have been re-labeled accordingly:
>    every entry is now "Reference / Re-derive canonically" — there are no
>    "pull verbatim" rows.
> 3. **The canonical scaffolds for Sovereign Gate, AgentEvent, Resonance Gate,
>    HermesCommandDispatcher, Hermes parsers, and AppBootstrap are already
>    landed in the Epistemos tree** in this session's commits
>    (`06230e8d`, `e03fb890`, `07e33fed`, `3cc3c612`, `6f8ad5af`, `469f6879`,
>    `caa46d05`, `d2641b12`, `0658b391`, `8f4309a5`). Anything Kimi/GPT proposed
>    in those areas is supplementary — never replace canon with mockup.
> 4. **For everything Kimi/GPT proposed that is NOT yet in the Epistemos tree
>    (App Group container, Arena bridge, AgentXPC, ProviderXPC, CapabilityBridge,
>    Companion Farm UI, Provenance Console, WBO-6 module, lattice/sketch/ternary,
>    Metal kernels, Simulation Reducer/PRNG/AccessibilityGating)**, you re-derive
>    them in canonical Epistemos shape: file paths under
>    `Epistemos/...` or `agent_core/...`, Epistemos naming conventions, Swift 6.2
>    + Rust 2024 idioms, Sovereign Gate as the single LAContext owner,
>    `AgentEvent` as the single provenance enum, and the Capability Lattice
>    (Core | Pro | Research | Both | All) gating per
>    `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §3.
> 5. **Cross-validate every Kimi/GPT proposal** against (in order):
>    `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`,
>    `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`,
>    `MASTER_RESEARCH_INDEX_2026_05_02.md`,
>    `JORDANS_RESEARCH_INDEX_2026_05_03.md`. If a Kimi/GPT proposal contradicts
>    canon, **canon wins** and you log the divergence in
>    `CANON_GAPS_AND_ADDENDA_2026_05_02.md`.
>
> The original framing of this doc treated Kimi's `epistenos/` workspace as a
> 32K-line ratified Cargo workspace ready to be cherry-picked into the tree. That
> framing was wrong. The correct framing is: Kimi/GPT did the research that
> validates the *design intent*; Codex (and Claude) still have to build the
> production substrate, file by file, the canonical Epistemos way.

---

## 0. The two reference workspaces (what they actually are)

### Kimi's `/Users/jojo/Downloads/kimis deep research/epistenos/`

```
Cargo.toml (workspace, 8 members)
├── crates/
│   ├── agent_core/         (Kimi's mockup of arena/mod.rs, container.rs)
│   ├── helios-core/        (mockup of inequality.rs, lattice.rs, sketch.rs, prcda.rs, traits.rs)
│   ├── helios-mlx/
│   ├── helios-models/
│   ├── helios-metal/       (6 .metal kernels: dora_apply, eml_softmax_lse, count_sketch_update,
│   │                        ternary_proj_residual, ternary_gemv, kv_fingerprint)
│   ├── helios-runtime/     (mockup hermes.rs, gate.rs, agent.rs, orchestrator.rs, replay.rs, self_tuning.rs)
│   ├── helios-bench/       (mockup kl_drift.rs, recall.rs)
│   └── helios-ffi/
├── swift/
│   ├── EpistenosKit/Sources/  (mockup AppGroupContainer, ArenaBridge, ResonanceServiceWired,
│   │                           ProvenanceConsole*, CompanionAdapterView, BiometricGate,
│   │                           DeterministicPRNG/Reducer, AccessibilityGating, plus
│   │                           Models/CompanionModel, State/CompanionState,
│   │                           Events/AgentProvenanceEvent, Security/SovereignGate,
│   │                           Environment/AppEnvironment, Views/Landing/*, Views/Notes/*)
│   ├── EpistenosApp/Sources/  (mockup primary window + TernaryControlRoomView)
│   ├── XPCServices/AgentXPC/  (mockup main + AgentService)
│   ├── XPCServices/ProviderXPC/ (mockup main + ProviderService)
│   ├── EpistenosXPC/Sources/HermesXPCService.swift
│   ├── Epistemos/Security/CapabilityBridge.swift   (mockup HMAC capability grant verify)
│   ├── Epistemos/XPC/                              (mockup AgentServiceClient, ProviderServiceClient, AgentServiceProtocol)
│   ├── EpistemosTests/                             (mockup XPCSmokeTests, SimulationModeTests, ArenaTests)
│   └── EpistemosMAS.entitlements                   (mockup App Sandbox + group + bookmarks)
├── DESIGN.md                (cross-crate API contracts — design intent, not contract)
├── BUILD_REPORT.md
├── SLICE1_BUILD_SUMMARY.md  (self-reported Arena + AppGroup migration)
└── META_AUDIT_REPORT.md     (self-audit; not Epistemos canon validation)
```

**Reality:** ~32K lines of *research code Kimi wrote in a sandbox*. The bundle
is internally consistent within Kimi's own sandbox, but **no part of it has
been verified against the actual Epistemos repo** (Sovereign Gate location,
AgentEvent enum shape, ResonanceService API, AppBootstrap structure, the
existing `agent_core/src/resonance/` module, etc.).

### GPT's `/Users/jojo/Downloads/GPT research/`

The same workspace skeleton with slight differences (5 Metal kernels, different
runtime module names) plus a `D1`–`D20` documentation set, a
`tools/verify_hotpath.py` portable verification harness, a
`bench/G1_KV_DIRECT_GATE.md` runbook, and a `tests/red_team_prompts.json`
red-team corpus.

**Reality:** GPT also worked in a sandbox without the actual Epistemos canon.
Its docs (D1–D20) and `verify_hotpath.py` are the highest-signal artifacts
because they're tier-portable: tests + math invariants don't require the
canon to evaluate.

---

## 1. The fusion strategy — re-derive canonically, do not import

**Rule:** Every Kimi/GPT file is a *reference design* for a subsystem that
Codex now builds canonically in the Epistemos tree. Use Kimi/GPT to validate
that the *direction* is sound; then implement the *destination* file from
scratch in Epistemos style, matching the existing in-tree patterns
(Resonance Gate, HermesCommandDispatcher, Sovereign Gate, AgentEvent,
MutationEnvelope, AppBootstrap).

### 1.1 Rust subsystems — Kimi reference → canonical destination

| Kimi reference                                                     | Canonical Epistemos destination                                    | Action |
|---|---|---|
| `crates/helios-core/src/inequality.rs` (WBO-6)                     | `agent_core/src/wbo6/mod.rs` (NEW)                                 | Re-derive: read the inequality, read GPT's `D2_WBO6_INEQUALITY.md`, then write a fresh `WBOSix` struct in Epistemos style with `compute_bound`, `assert_within_bound`, full unit tests, plus integration with the existing `agent_core::resonance` module so τ tracks the bound budget. |
| `crates/helios-core/src/lattice.rs` (E8 + Leech + Babai)           | `agent_core/src/lattice/mod.rs` (NEW)                              | Re-derive: extract the codebook + Babai algorithm; write Epistemos-style. Cite the source paper in module docstring. Ship with property-based tests against random inputs. |
| `crates/helios-core/src/sketch.rs` (CountSketch + JL + FRP)        | `agent_core/src/sketch/mod.rs` (NEW)                               | Re-derive: same approach. Future basis for L2 Shadow Sketch tier. |
| `crates/helios-core/src/prcda.rs` (Sherry 1.25-bit pack)           | `agent_core/src/ternary/mod.rs` (NEW; Lane 6 / Research)           | Re-derive behind `cfg(feature = "research")` flag. Sherry paper ref in docstring. |
| `crates/agent_core/src/arena/mod.rs` (mmap arena, 910 lines)       | `agent_core/src/arena/mod.rs` (NEW)                                | Re-derive carefully — this is mmap + memmap2 + lifetime-safe FFI. Verify the API against the actual XPC needs, not Kimi's mockup XPC needs. |
| `crates/agent_core/src/arena/container.rs` (App Group resolver)    | `agent_core/src/arena/container.rs` (NEW)                          | Re-derive. App Group identifier must be `group.com.epistemos.shared`, not Kimi's `group.com.epistenos.shared`. |
| `crates/helios-runtime/src/hermes.rs`                              | (do nothing — canon already exists)                                | The canonical Hermes routing is `Epistemos/LocalAgent/HermesGatewayPolicy.swift` + `HermesCommandDispatcher.swift` + the 13 parser files landed this session. Read Kimi's hermes.rs only to verify our route classification covers the same intent space. |
| `crates/helios-metal/metal/eml_softmax_lse.metal`                  | `agent_core/metal/eml_softmax_lse.metal` (NEW)                     | Re-derive: numerically stable softmax (Pillar III + V). Validate against the WBO-6 ½-Lipschitz constant. |
| `crates/helios-metal/metal/count_sketch_update.metal`              | `agent_core/metal/count_sketch_update.metal` (NEW)                 | Re-derive. |
| `crates/helios-metal/metal/ternary_proj_residual.metal`            | `agent_core/metal/ternary_proj_residual.metal` (NEW; Research)     | Re-derive behind feature flag. |
| `crates/helios-metal/metal/ternary_gemv.metal`                     | `agent_core/metal/ternary_gemv.metal` (NEW; Research)              | Re-derive behind feature flag. |
| `crates/helios-metal/metal/kv_fingerprint.metal`                   | `agent_core/metal/kv_fingerprint.metal` (NEW)                      | Re-derive. KV-Direct gate fingerprint for the Helios v3 Week 0 experiment per GPT's `bench/G1_KV_DIRECT_GATE.md`. |
| `crates/helios-metal/metal/dora_apply.metal`                       | `agent_core/metal/dora_apply.metal` (NEW; Pro / L_SE)              | Re-derive behind feature flag. |
| `crates/helios-bench/src/kl_drift.rs` + `recall.rs`                | `agent_core/benches/kl_drift.rs` + `recall.rs` (NEW)               | Re-derive as criterion benches. |

### 1.2 Swift subsystems — Kimi reference → canonical destination

| Kimi reference                                                            | Canonical Epistemos destination                                              | Action |
|---|---|---|
| `EpistenosKit/Sources/AppGroupContainer.swift`                            | `Epistemos/App/AppGroupContainer.swift` (NEW)                                | Re-derive: read Kimi's mockup, then write Epistemos-style with `group.com.epistemos.shared`. Single resolver, security-scoped bookmark API, doctrine-correct error handling. |
| `EpistenosKit/Sources/ArenaBridge.swift`                                  | `Epistemos/Engine/ArenaBridge.swift` (NEW)                                   | Re-derive. Actor wrapping the Rust arena FFI. Must compose with the canonical bridge pattern in `Epistemos/Bridge/StreamingDelegate.swift`. |
| `EpistenosKit/Sources/ArenaPathResolver.swift`                            | `Epistemos/Engine/ArenaPathResolver.swift` (NEW)                             | Re-derive. |
| `EpistenosKit/Sources/ResonanceServiceWired.swift`                        | extend `Epistemos/Engine/ResonanceService.swift` (existing)                  | **Do not replace.** The canonical scaffold landed in `e03fb890`. Read Kimi's "wired" version to learn how to swap the in-Swift placeholder for the FFI call (`compute_resonance_signature_core`); apply that swap in-place in the canonical file. |
| `EpistenosKit/Sources/ResonanceGateView.swift`                            | extend `Epistemos/Views/Resonance/ResonanceChip.swift` family (existing)     | **Do not replace.** Compare both views; pick the better surface; keep the canonical name `ResonanceChip` + `ResonanceLegendView`. |
| `EpistenosKit/Sources/ProvenanceConsoleState.swift` + `ProvenanceConsoleView.swift` | `Epistemos/Views/Settings/ProvenanceConsoleView.swift` (NEW)                | Re-derive. Wire to the canonical `agent_core::events::AgentEvent` + EventStore + OpLog + RunEventLog data path, **not** to Kimi's parallel ring buffer. |
| `EpistenosKit/Sources/CompanionAdapterView.swift`                         | `Epistemos/Views/Resonance/CompanionAdapterView.swift` (NEW)                 | Re-derive. The LoRA unwrap UI per Simulation Invariant I-11. |
| `EpistenosKit/Sources/Models/CompanionModel.swift`                        | `Epistemos/Models/CompanionModel.swift` (NEW)                                | Re-derive as canonical SwiftData `@Model` with Epistemos field naming. |
| `EpistenosKit/Sources/State/CompanionState.swift`                         | `Epistemos/State/CompanionState.swift` (NEW)                                 | Re-derive as canonical `@Observable @MainActor` service. |
| `EpistenosKit/Sources/Events/AgentProvenanceEvent.swift`                  | extend `agent_core::events::AgentEvent` (existing)                           | **Do not pull a parallel enum.** The canonical `AgentEvent` is in `agent_core/src/events/`. Read Kimi's mockup, identify the 6 v1.6 forward variants (SteerRequested, SummaryStarted, SummaryDelta, SummaryCompleted, VaultCreated, VaultArchived) per H6, and add them to the canonical enum + bridge. |
| `EpistenosKit/Sources/Security/SovereignGate.swift`                       | (do nothing — canon already exists)                                          | The canonical Sovereign Gate is `Epistemos/Sovereign/SovereignGate.swift`. Single LAContext owner per doctrine §A.7. **Reject Kimi's parallel SovereignGate.** |
| `EpistenosKit/Sources/BiometricGate.swift`                                | (do nothing — canon already exists)                                          | Same — Sovereign Gate is the only LAContext owner. **Reject Kimi's parallel BiometricGate.** |
| `EpistenosKit/Sources/Environment/AppEnvironment.swift`                   | extend `Epistemos/App/AppBootstrap.swift` (existing)                         | **Do not pull a parallel environment.** AppBootstrap is Epistemos's existing `@Observable` single-source-of-truth. Read Kimi's mockup, port any useful single-source patterns into AppBootstrap. |
| `EpistenosKit/Sources/AppBootstrap.swift`                                 | extend `Epistemos/App/AppBootstrap.swift` (existing)                         | **Do not replace.** Compare bootstraps; merge launch-sequence additions (App Group ensure → Companion bootstrap → AgentEvent ring init) into the canonical file. |
| `EpistenosKit/Sources/DeterministicPRNG.swift`                            | `Epistemos/Engine/DeterministicPRNG.swift` (NEW; Simulation Invariant I-13) | Re-derive. Seeded by `(session_id, agent_id, event_id)` per the Invariant. |
| `EpistenosKit/Sources/DeterministicReducer.swift`                         | `Epistemos/Engine/SimulationReducer.swift` (NEW; Invariant I-7)             | Re-derive. |
| `EpistenosKit/Sources/AccessibilityGating.swift`                          | `Epistemos/Engine/AccessibilityGating.swift` (NEW; Invariant I-14)          | Re-derive. Reduce-motion fallback to static pose + state badge. |
| `EpistenosKit/Sources/CaptureSurface.swift`                               | `Epistemos/Views/Capture/CaptureSurface.swift` (NEW)                         | Re-derive only if it doesn't conflict with existing capture surfaces; else skip. |
| `EpistenosKit/Sources/AgentDashboard.swift`                               | `Epistemos/Views/Settings/AgentDashboard.swift` (NEW)                        | Re-derive. |
| `EpistenosKit/Sources/VaultManager.swift`                                 | merge into existing vault management surface                                 | Compare with existing; port bookmark-store additions only. |

**Simulation Mode v1.6 Views (the user's hackathon priority):**

| Kimi reference                                              | Canonical Epistemos destination                                    | Action |
|---|---|---|
| `Views/Landing/LandingFarmView.swift`                       | `Epistemos/Views/Landing/LandingFarmView.swift` (NEW)              | Re-derive in Epistemos style. **DEFAULT APP VIEW** per the user's emphasis. |
| `Views/Landing/CompanionView.swift`                         | `Epistemos/Views/Landing/CompanionView.swift` (NEW)                | Re-derive. Orb avatar + TimelineView breathing (cosmetic_idle per I-5). |
| `Views/Landing/CompanionCreationFlow.swift`                 | `Epistemos/Views/Landing/CompanionCreationFlow.swift` (NEW)        | Re-derive. 4-step wizard, every cosmetic choice maps to ModelProfile per I-10. |
| `Views/Landing/CompanionDeleteSheet.swift`                  | `Epistemos/Views/Landing/CompanionDeleteSheet.swift` (NEW)         | Re-derive. **Routes through the canonical `Epistemos/Sovereign/SovereignGate.swift`** — not Kimi's parallel BiometricGate. |
| `Views/Landing/CompanionRestoreSheet.swift`                 | `Epistemos/Views/Landing/CompanionRestoreSheet.swift` (NEW)        | Re-derive. Same Sovereign Gate routing. |
| `Views/Landing/LandingFarmWindowManager.swift`              | `Epistemos/Views/Landing/LandingFarmWindowManager.swift` (NEW)     | Re-derive. Window lifecycle. |
| `Views/Notes/NotesSidebarSkin.swift`                        | `Epistemos/Views/Notes/NotesSidebarSkin.swift` (NEW)               | Re-derive. Sidebar wrapper with companion presence. |

**XPC services (Hermes hackathon priority):**

| Kimi reference                                                                | Canonical Epistemos destination                                    | Action |
|---|---|---|
| `XPCServices/AgentXPC/main.swift` + `AgentService.swift`                      | `XPCServices/AgentXPC/` (NEW dir; coordination-required)           | Re-derive. New XPC target requires `project.pbxproj` sync. The protocol surface must compose with the canonical `HermesCommandDispatcher.parseCore` already shipped this session. |
| `XPCServices/ProviderXPC/main.swift` + `ProviderService.swift`                | `XPCServices/ProviderXPC/` (NEW dir)                               | Re-derive. |
| `Epistemos/XPC/AgentServiceProtocol.swift` + `AgentServiceClient.swift` + `ProviderServiceClient.swift` | `Epistemos/XPC/` (NEW dir)                              | Re-derive. Main-app side. |
| `Epistemos/Security/CapabilityBridge.swift`                                   | `Epistemos/Security/CapabilityBridge.swift` (NEW)                  | Re-derive. **Must compose with** the canonical `agent_core/src/effect/receipt.rs` `Capability::BiometricSession` Donor pattern — Donor pattern wins on type names. |
| `EpistemosMAS.entitlements`                                                   | augment existing `Epistemos-AppStore-Info.plist` + add `EpistemosMAS.entitlements` | Re-derive App Sandbox + group `group.com.epistemos.shared` + bookmarks; merge with existing entitlement story. |

**Test harness:**

| Kimi reference                                                          | Canonical Epistemos destination                                    | Action |
|---|---|---|
| `EpistenosKit/Tests/SimulationModeTests.swift` (8 tests)                | `EpistemosTests/SimulationModeTests.swift` (NEW)                   | Re-derive against the canonical `CompanionState` + `SovereignGate`. The 8 test scenarios are correct; the assertions need to bind to the canonical types. |
| `EpistemosTests/XPCSmokeTests.swift`                                    | `EpistemosTests/XPCSmokeTests.swift` (NEW)                         | Re-derive. |
| `EpistenosKit/Tests/ArenaTests.swift` (6 tests)                         | `EpistemosTests/ArenaTests.swift` (NEW)                            | Re-derive against the canonical `ArenaBridge`. |

### 1.3 GPT's docs/ + tools/ — these are the most usable artifacts

GPT's research note set is more digestible than Kimi's because it's documentation, not code. Treat each one as a reference brief.

| GPT reference                                          | Canonical Epistemos destination                                                     | Action |
|---|---|---|
| `docs/WBO6_INEQUALITY.md`                              | `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md` (NEW)                                | Read GPT's note. Author a canonical Epistemos budget doc that ties WBO-6 terms to in-tree budgets (Resonance Gate τ + π + λ, KV cache budget, embedding budget). Cite GPT's research as a source. |
| `docs/RESONANCE_GATE.md`                               | merge into existing `MASTER_RESEARCH_INDEX_2026_05_02.md` Resonance Gate section    | Cite, don't duplicate. |
| `docs/HERMES_GATEWAY.md`                               | already covered by existing `docs/fusion/jordan's research/hermes.md`               | Skip (duplicate). |
| `docs/METAL_KERNELS.md`                                | `docs/fusion/HELIOS_METAL_KERNELS_2026_05_03.md` (NEW)                              | Author canonical Epistemos kernel index that names every kernel under `agent_core/metal/`, what budget term it serves, and the Lipschitz/budget claim. |
| `docs/SECURITY_AUDIT.md`                               | append to existing `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md`               | Cross-check against existing security audits. |
| `docs/SOURCE_INDEX.md`                                 | merge into existing `MASTER_RESEARCH_INDEX_2026_05_02.md`                           | Cite, don't duplicate. |
| `docs/UNIVERSAL_PLASTICITY.md`                         | `docs/fusion/jordan's research/UNIVERSAL_PLASTICITY.md` (NEW; Research tier)        | Mirror under `jordan's research/` as a research note. |
| `docs/SELF_TUNING.md`                                  | `docs/fusion/jordan's research/SELF_TUNING.md` (NEW; Pro / L_SE tier)               | Mirror as a research note for the Titans-MAC + SEAL-DoRA design. |
| `docs/PAPER_DRAFT.md`                                  | `docs/fusion/HELIOS_PAPER_DRAFT_2026_05_03.md` (NEW)                                | Mirror as MLSys/NeurIPS draft starter. |
| `docs/COMPETITOR_ANALYSIS.md`                          | `docs/fusion/jordan's research/COMPETITOR_ANALYSIS.md` (NEW)                        | Mirror as App Store positioning context. |
| `docs/VAULT_GATED_SWARM.md`                            | merge into `mac store edition.md` reference                                         | Cite, don't duplicate. |
| `tools/verify_hotpath.py`                              | `scripts/verify_hotpath.py` (NEW)                                                   | **Re-derive against actual Epistemos paths.** GPT's tool checks for files at GPT's mockup paths; rewrite the path table to point at canonical Epistemos destinations. |
| `bench/G1_KV_DIRECT_GATE.md`                           | `docs/fusion/HELIOS_KV_DIRECT_GATE_RUNBOOK_2026_05_03.md` (NEW)                     | Mirror as the Week 0 KV-Direct experiment runbook. The decision rule (D_KL = 0 + token_match = 100% + peak_RAM ≥ 8× lower) is doctrine-shaped and stays. |
| `tests/red_team_prompts.json`                          | `EpistemosTests/Fixtures/red_team_prompts.json` (NEW)                               | Mirror as Red Team test corpus. |

---

## 2. The build order (re-derive in this sequence)

```
STEP 1 (this hour) ──────────────────────────────────────────────────────────
  Read this doc + the 3 sister docs:
    EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md
    JORDANS_RESEARCH_INDEX_2026_05_03.md
    CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md
  Skim Kimi's META_AUDIT_REPORT.md + DESIGN.md to absorb the design intent
    (NOT to import as contracts).
  Skim GPT's D1–D20 docs and `verify_hotpath.py` to absorb the verification
    discipline (this is the highest-signal cross-tier artifact).

STEP 2 (this day — verification floor) ──────────────────────────────────────
  Author canonical Epistemos versions of the highest-leverage docs first:
    docs/fusion/HELIOS_WBO6_BUDGET_2026_05_03.md          (re-derive from GPT)
    docs/fusion/HELIOS_METAL_KERNELS_2026_05_03.md        (re-derive from GPT)
    docs/fusion/HELIOS_KV_DIRECT_GATE_RUNBOOK_2026_05_03.md (re-derive from GPT)
    EpistemosTests/Fixtures/red_team_prompts.json         (mirror from GPT)
    scripts/verify_hotpath.py                             (re-derive against
                                                           canonical paths)
  Run python3 scripts/verify_hotpath.py — must pass on the existing tree
    before any new code lands.

STEP 3 (Week 0 — KV-Direct gate, half-day) ──────────────────────────────────
  Per docs/fusion/HELIOS_KV_DIRECT_GATE_RUNBOOK_2026_05_03.md:
    Run KV-Direct vs KV-full on Qwen3-8B-MLX-4bit at 32k context (16GB Mac).
    Decision rule: D_KL = 0 + token_match = 100% + peak_RAM ≥ 8× lower.
    PASS → proceed. FAIL → audit before any L1 work.

STEP 4 (Week 1 — Rust foundation re-derivation) ─────────────────────────────
  Re-derive each Rust subsystem as its own commit. For each: read Kimi's
  mockup + GPT's doc, then write the canonical Epistemos version.
    a. agent_core/src/wbo6/mod.rs              (re-derive from helios-core/inequality.rs)
    b. agent_core/src/lattice/mod.rs           (re-derive from helios-core/lattice.rs)
    c. agent_core/src/sketch/mod.rs            (re-derive from helios-core/sketch.rs)
    d. agent_core/src/arena/mod.rs + container.rs (re-derive from agent_core arena)
    e. agent_core/metal/*.metal                (re-derive the 6 kernels)
    f. cargo test agent_core — all passes; integrate wbo6 into the existing
       agent_core::resonance budget tracking.

STEP 5 (Week 1 — App Group + Arena bridge re-derivation) ────────────────────
  Re-derive each Swift piece:
    a. Epistemos/App/AppGroupContainer.swift   (canonical, group.com.epistemos.shared)
    b. Epistemos/Engine/ArenaBridge.swift      (canonical actor)
    c. Epistemos/Engine/ArenaPathResolver.swift
    d. Merge launch additions into existing Epistemos/App/AppBootstrap.swift
    e. Add group.com.epistemos.shared to Epistemos.xcodeproj entitlements
    f. EpistemosTests/ArenaTests.swift         (re-derive against canonical ArenaBridge)

STEP 6 (HACKATHON BLOCK A — Week 2-3, Hermes XPC + multi-CLI) ────────────────
  Re-derive the XPC service skeleton:
    a. XPCServices/AgentXPC/{main.swift, AgentService.swift}
    b. XPCServices/ProviderXPC/{main.swift, ProviderService.swift}
    c. Epistemos/XPC/{AgentServiceProtocol.swift, AgentServiceClient.swift, ProviderServiceClient.swift}
    d. Epistemos/Security/CapabilityBridge.swift  (compose with Donor pattern)
    e. Wire HermesCommandDispatcher.parseCore (already shipped) into the chat
       input surface so /help, /calc, /todo, etc. round-trip through AgentXPC
    f. EpistemosTests/XPCSmokeTests.swift
    g. project.pbxproj sync — add the two XPC targets (coordination-required)

STEP 7 (HACKATHON BLOCK B — Week 2-3, Simulation Mode v1.6 with full assets) ─
  Re-derive Simulation v1.6 in this order (each is one commit):
    a. agent_core::events — add the 6 v1.6 forward variants per H6
       (SteerRequested, SummaryStarted/Delta/Completed, VaultCreated, VaultArchived)
    b. Epistemos/Models/CompanionModel.swift              (canonical SwiftData @Model)
    c. Epistemos/State/CompanionState.swift               (canonical @Observable @MainActor)
    d. Epistemos/Engine/DeterministicPRNG.swift           (Invariant I-13)
    e. Epistemos/Engine/SimulationReducer.swift           (Invariant I-7)
    f. Epistemos/Engine/AccessibilityGating.swift         (Invariant I-14)
    g. Epistemos/Views/Landing/CompanionView.swift        (orb + breathing)
    h. Epistemos/Views/Landing/CompanionCreationFlow.swift (4-step wizard)
    i. Epistemos/Views/Landing/CompanionDeleteSheet.swift  (routes through
                                                            Epistemos/Sovereign/SovereignGate.swift)
    j. Epistemos/Views/Landing/CompanionRestoreSheet.swift (same Sovereign Gate)
    k. Epistemos/Views/Landing/LandingFarmView.swift       (DEFAULT APP VIEW)
    l. Epistemos/Views/Landing/LandingFarmWindowManager.swift
    m. Epistemos/Views/Notes/NotesSidebarSkin.swift
    n. Epistemos/Views/Resonance/CompanionAdapterView.swift (LoRA unwrap I-11)
    o. EpistemosTests/SimulationModeTests.swift           (8 tests vs canon)
    p. Wire EpistemosApp.swift primary window = LandingFarmView ("home window stuff")

STEP 8 (Week 4 — Provenance Console UI; closes MAS feature trio) ─────────────
    a. Epistemos/Views/Settings/ProvenanceConsoleState.swift  (re-derive)
    b. Epistemos/Views/Settings/ProvenanceConsoleView.swift   (re-derive)
    c. Wire to canonical AgentEvent + EventStore + OpLog + RunEventLog
    d. Filter / search / export buttons

STEP 9 (POST-HACKATHON — resume prior queue) ─────────────────────────────────
    a. M1: Mount Resonance chip into one production surface (chat or Halo)
    b. M3: Swap Epistemos/Engine/ResonanceService.swift placeholder for the
       FFI call (compute_resonance_signature_core); read Kimi's "wired"
       mockup for the swap shape, apply in-place in the canonical file.
    c. M2: Wire HermesCommandDispatcher.parseCore into chat input — done in
       BLOCK A; verify.
    d. WBO-6 budget doc — done in STEP 2.
    e. Sherry 1.25-bit ternary on residual (Lane 6) — re-derive
       agent_core/src/ternary/ + the 2 ternary metal kernels behind
       cfg(feature = "research").
    f. Titans-MAC + SEAL-DoRA (L_SE) — design from GPT's SELF_TUNING.md;
       Pro tier feature flag; ‖e‖ telemetry mandatory.
    g. MAS/Core symbol separation closure (L2-CARD-1 from prior workcards draft).
```

---

## 3. The conflict resolution rules — canon always wins

When a Kimi/GPT mockup disagrees with the existing Epistemos canon:

1. **Sovereign Gate / BiometricGate / LAContext** — `Epistemos/Sovereign/SovereignGate.swift` ALWAYS wins. Single owner per doctrine §6 + §A.7. **Reject** Kimi's parallel `BiometricGate.swift` and `Security/SovereignGate.swift`. Migrate every Kimi caller to the canonical Sovereign Gate.

2. **AgentEvent enum** — `agent_core::events::AgentEvent` (instrumented through PR44) ALWAYS wins. Add only the 6 v1.6 forward variants per H6. **Reject** Kimi's parallel `Events/AgentProvenanceEvent.swift` ring buffer if it conflicts with EventStore.

3. **Resonance Gate** — `agent_core/src/resonance/` (this session's commits `06230e8d` + `07e33fed`) ALWAYS wins. Kimi's `ResonanceServiceWired.swift` is read-only reference for the FFI swap pattern; do not import it as a parallel service.

4. **HermesGatewayPolicy + HermesCommandDispatcher** — the canon (this session's commits `caa46d05` + `d2641b12` + the 13 parser files) ALWAYS wins. Don't re-derive Kimi's `helios-runtime/src/hermes.rs`; cherry-pick only what isn't already covered.

5. **AppBootstrap** — `Epistemos/App/AppBootstrap.swift` ALWAYS wins. Merge Kimi's launch-sequence additions in (App Group ensure + Companion bootstrap + AgentEvent ring init); do not replace the file.

6. **AppEnvironment** — AppBootstrap is Epistemos's `@Observable` single-source-of-truth. Reject Kimi's parallel `AppEnvironment.swift`; merge any single-source patterns into AppBootstrap.

7. **App Group identifier** — canonical is `group.com.epistemos.shared`. Kimi's mockup uses `group.com.epistenos.shared` (a typo from the workspace name). Always use the canonical.

8. **Protected paths** — `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph internals, `.rlib`, `DerivedData`, `.xcresult` — never touched, even if Kimi/GPT proposed edits there.

9. **Tier classification** — every new file gets a `Core | Pro | Research | Both | All` label per the capability lattice in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` §3. Anything Kimi/GPT marked ambiguously gets re-classified.

10. **Capability grants** — re-derive `CapabilityBridge.swift` so it composes with the existing `agent_core/src/effect/receipt.rs` `Capability::BiometricSession` Donor pattern. Donor pattern wins on type names.

11. **Naming** — Kimi's workspace name "Epistenos" is a sandbox typo. Everything in the canon is "Epistemos". When re-deriving, every `Epistenos*` symbol becomes `Epistemos*`.

---

## 4. The verification ask (Codex, run this after each STEP)

After every STEP from §2:

1. `cargo build --manifest-path agent_core/Cargo.toml --lib` — must pass.
2. `cargo test --manifest-path agent_core/Cargo.toml` — must pass with no regressions.
3. `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify` — must pass after pbxproj sync.
4. `python3 scripts/verify_hotpath.py` (after STEP 2) — portable invariants must pass against canonical paths.
5. `grep -rn 'LAContext\|canEvaluatePolicy\|evaluatePolicy' Epistemos/ --include='*.swift' | grep -v 'Epistemos/Sovereign/'` — must return zero (Sovereign single-owner).
6. `grep -rn 'Process()' Epistemos/Bridge/ Epistemos/LocalAgent/ Epistemos/Omega/ --include='*.swift'` — must return zero (no inference subprocess).
7. `grep -rn 'Epistenos\|epistenos' Epistemos/ agent_core/ XPCServices/ --include='*.swift' --include='*.rs'` — must return zero (canonical naming).
8. Append a row to `CANON_GAPS_AND_ADDENDA_2026_05_02.md` if any unexpected drift surfaces.

---

## 5. The hackathon acceptance bar (re-emphasize from the prior verify-handoff)

### Hermes (BLOCK A)
- Type `/help core` → see Core-tier slate
- Type `/calc 2*pi` → see `6.28...`
- Type `/ask <question>` → cloud provider responds via Hermes through ProviderXPC, with provenance row
- Type `/run <cmd>` (Pro) → routed through CLI passthrough, AgentEvent recorded
- Switch active provider in Settings → next `/ask` uses new provider

### Simulation (BLOCK B) — full assets, the user's explicit list
- App opens → Landing Farm visible by default → companions present, idle-breathing
- Settings → Companions → Create New Companion → 4-step wizard → companion appears in Landing Farm
- Long-press companion → Delete sheet → **Touch ID gate via canonical Sovereign Gate** → fade animation → AgentEvent
- Trash/archive surface → restore companion within time window → same canonical Sovereign Gate
- Apply LoRA adapter → unwrap animation duration ≥ adapter apply duration (Invariant I-11); failure shows failure state
- Notes Sidebar → companion presence visible, reacts to AgentEvent stream in real time
- Reduce-motion on → static pose + state badge + audit-readable text
- Pixel-identical replay given same event log + seed

If any acceptance-bar item fails at hackathon demo, the slice is not done.

---

## 6. The closing commitment (corrected)

Kimi and GPT did the **research** that validates the design intent — six-tier
substrate, WBO-6 master inequality, Resonance Gate ternary truth, Companion
Farm topology, AgentXPC + ProviderXPC isolation, Sherry 1.25-bit ternary,
KV-Direct gate experiment, MAS Core architecture. The intent is correct.

**The canonical implementation is Codex's job.** Every file in this handoff
gets re-derived in Epistemos style, in the Epistemos tree, in the Epistemos
naming, against the Epistemos canon. Kimi/GPT are read-only references —
helpful prior art, not source files to import.

When you're done, Epistemos will have:
- The full Helios v3 substrate (10 crates' worth of design re-derived as Epistemos modules + 6 Metal kernels + WBO-6 + lattice + sketch + ternary)
- The MAS Core architecture (App Group + Arena + AgentXPC + ProviderXPC + Capability grants + canonical Sovereign Gate + Provenance Console)
- The Vault-Scoped Cognitive Agent framing
- Simulation Mode v1.6 with companion creation/delete/restore + adapter UI + home window + Notes Sidebar Skin
- Hermes XPC + multi-CLI integration end-to-end
- All three tiers (Core / Pro / Research) ready behind feature flags
- Zero forks of the architecture
- Zero parallel implementations of Sovereign Gate, AgentEvent, Resonance Gate, AppBootstrap, or HermesCommandDispatcher (canon stays canonical)

> One binary. One substrate. Three envelopes. Zero forks. Canon wins over mockup.

Build it.

---

## Appendix A — File paths to make this clickable

```
docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md   ← this doc
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md
docs/fusion/JORDANS_RESEARCH_INDEX_2026_05_03.md
docs/fusion/CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md
docs/fusion/CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md

/Users/jojo/Downloads/kimis deep research/epistenos/      ← Kimi's REFERENCE workspace (research-grade mockup)
/Users/jojo/Downloads/kimis deep research/epistenos/META_AUDIT_REPORT.md  ← Kimi self-audit (NOT canon validation)
/Users/jojo/Downloads/kimis deep research/epistenos/DESIGN.md             ← cross-crate design intent (read for direction, not contracts)

/Users/jojo/Downloads/GPT research/                      ← GPT's REFERENCE artifacts (research-grade mockup + docs)
/Users/jojo/Downloads/GPT research/docs/                 ← D1-D20 doc set (highest-signal artifacts)
/Users/jojo/Downloads/GPT research/tools/verify_hotpath.py  ← portable verification harness (re-derive against canon paths)
/Users/jojo/Downloads/GPT research/bench/G1_KV_DIRECT_GATE.md  ← Week 0 experiment runbook (decision rule is doctrine-shaped)
/Users/jojo/Downloads/GPT research/tests/red_team_prompts.json  ← red-team corpus (mirror as fixture)

docs/fusion/jordan's research/   ← canonical research folder (mirrored from Downloads)
docs/fusion/jordan's research/kimi's research/   ← Kimi's narrative research (referenced from MASTER_RESEARCH_INDEX §8)
```

Hand this doc + the four sister docs above + pointers to the Kimi/GPT folders to Codex. Codex reads, plans, **re-derives canonically** in the order in §2.
