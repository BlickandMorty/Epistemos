# UNFINISHED RESEARCH SWEEP — Local/Chat focus (2026-06-18)

Owner-mandated deep sweep of the Obscura / Simulation / EML eras (and the
B2/B3/HELIOS/Eidos/registers/Living-Index). **Hermes excluded** (purged — no
Hermes-named work resurrected). Each item was verified against CURRENT code, not
just docs. Items already shipped are omitted. Focus = LOCAL-model + CHAT research
that got dropped. Size: S(<1d) / M(days) / L(week+). **(d)** = owner's
LOCAL/CHAT focus.

## TOP LOCAL/CHAT items, genuinely unbuilt & not blocked (do these first)
- **OBS-1/2/3 Eidos→chat wiring** (d, M+M+S): real EidosBridge FFI (W-46), the
  closed-citation emit-gate into ChatCoordinator (W-47, chat context can't cite
  fabricated sources), and the "Retrieved by Eidos" Brain Panel (W-48). Eidos Rust
  substrate (21 files, ~472 tests, 10 modes) is DONE; the chat wiring is not.
  `agent_core/src/eidos/STATUS.md:66-68,97-99`.
- **OBS-5 Eidos cold-build Swift-6 isolation fix** (d, S): `EidosBridge.swift` +
  `EidosWiring.swift` `nonisolated` fns call MainActor UniFFI `eidos*` globals →
  COLD-DerivedData/CI build fails (latent from owner commit 29ba6cc9f). Already
  flagged in AGENT_PROGRESS; this is the concrete fix. **Quick win.**
- **EML-2 / EML-3** (d, M): inject the (already-shipped) EML energy potential into
  `ConfidenceRouter` routing + a vault-recall EML re-rank pass
  (`storage/vault.rs`, ≥2pp on the F-VaultRecall-50 fixture). EML core shipped;
  these two call-sites are forward-staged. `EML_INTEGRATION_DOCTRINE_2026_05_17.md:81-138,323-325`.
- **LF-1/2/3 kill the MoLoRA/QLoRA Python subprocess** (d, L+L+S): `Epistemos/
  KnowledgeFusion/MoLoRA/molora_inference.py` (+ a live `__pycache__`) still runs
  Python — a standing **NO-SIDECAR doctrine breach**. Port MoLoRA (W7-H) + QLoRA
  (W7-I) to in-process MLX-Swift, then delete `PythonEnvironmentManager` (W7-J).
  `B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md:113-115`.
- **REG-1 F-KV-Direct-Gate harness** (d, M): gate code shipped
  (`scope_rex/kv/direct_gate.rs`); run the measurement (Qwen3-8B @128k, peak RAM
  ≤13 GB, D_KL/token ≤0.08, ≥10 tok/s). `DEFERRED_WORK_GUARANTEE_2026_05_23.md:18`.
- **REG-3 NightBrain V1.x bodies** (d, M): 949-LOC skeleton at
  `agent_core/src/nightbrain/`; add the 4 eligibility conditions + 6 real task
  bodies (dedupe_artifacts, cloud_knowledge_distillation, nano_continual_step…).
  `DEFERRED_WORK_GUARANTEE_2026_05_23.md:27`.

## ERA 1 — SIMULATION
UI shell is live (`Views/Landing/Farm/*`); the visual substrate is unbuilt
(companions render as SF Symbols, not the doctrine's Metal pixel-art). Donor
mining closed **blocked** (donor code imports companion/Hermes coupling — nothing
salvageable without clean-room). SIM-1 raster-atlas pipeline (L, no), SIM-2 body
grammar (M, no), SIM-3 adapter gift-box→real config (M, partial), **SIM-4 real
MLX-Swift LoRA hot-swap (d, L)**, SIM-5 Graph Live Theater (M, no), SIM-6 honesty
audit ledger surface (S, partial), SIM-7 NotesSidebarSkin wiring (S, no).
`docs/fusion/simulation/IMPLEMENTATION.md` + `DOCTRINE.md`. (Naming note: "Hermes
Snake → LocalAgent Snake" is naming-reconciliation only, NOT a Hermes revival.)

## ERA 2 — EML  ⚠ disambiguation
"EML"/"EML-IR" in this repo = the **elementary-math primitive** `eml(x,y)=exp(x)−ln(y)`
(F-ULP-Oracle arithmetic floor), **NOT** an "episodic memory lattice." No doc
matches "episodic memory lattice"; the real episodic-memory track is the separate
CoALA `epistemos.episode.v1` (`MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md:297`).
EML MVP shipped (~80-103 tests). Open: EML-1 FFI + `EmlEnergyHealthRow` (S, gated
on `research`→mas-build), **EML-2 ConfidenceRouter scoring (d, M)**, **EML-3
vault-recall re-rank (d, M)**, EML-4 tri-fusion argmin (M), EML-5 100-fn corpus +
Lean cert (L), EML-6 Carney inexpressibility cite (S). (OxiEML vendoring
deliberately deferred — not a todo.)

## ERA 3 — OBSCURA + Eidos + deno_core
Obscura + deno_core W6 runtime **never built** (zero `obscura-*`/`deno_core`
deps). Eidos partially shipped (substrate done; chat wiring not — see TOP items).
OBS-4 ShadowBackedSemanticIndex over the real usearch HNSW (d, M), OBS-6 Obscura
browser engine W6-A→D (L, Pro), OBS-7 deno_core V8 isolate (L, Pro), OBS-8 Eidos
Metal-cosine re-rank kernel (d, M), OBS-9 llguidance-constrained LLM re-rank (d, M).
`B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md` + `agent_core/src/eidos/STATUS.md`.

## ERA 4 — registers / T0-T15 (local/chat only)
`KNOWN_ISSUES_REGISTER.md` is CLOSED (15/18 fixed, 3 intentional). Open local/chat:
REG-2 T20 Variant Ladder (d, M; branch `codex/t20-*` never merged — deterministic→
embedding→classical→small-LLM→mid→cloud→defer honest routing ladder), REG-4 custom
local model (d, L; post-v2.0), REG-5 T17 Cognitive-Weight enforcement W2 (d, M),
REG-6 per-model native memory folder + chat-as-graph-node (d, M; additive,
`EPISTEMOS_GRAPH_INDEX_CHATS` flag). Pro/Research D-items (XPC, F-70B, Lean,
T16) intentionally deferred.

## ERA 5 — B2 Live Files + KnowledgeFusion subprocess debt
(See LF-1/2/3 in TOP.) Plus LF-4 Live File Compiler app wiring (L, partial — T16
Rust seam exists, no Swift surface: 10-state machine + FSEvents rotor + Metal
glow), LF-5 Vector Universe scans over a bge-small format (d, M), LF-6 Eidos Plus
auto-research (L, Pro). `B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md:106-116`.

## ERA 6 — Living Index "things I wanted" (`EPISTEMOS_LIVING_INDEX_2026_05_24.md`)
§8 deferred-ledger = the D-01..D-26 register above. Beyond it: LI-1 Terminal H
Research Construction Engine (L, no; hold until Wave 2), **LI-2 Residency
PatternBoost offline-discovery (d, L)** — newest research bridge (search/repair/
fingerprint/archive elite resident assemblies offline, small live scout
use-or-abstain; `F-RESIDENCY-PATTERNBOOST-BUNDLE`-gated, doctrine-only), **LI-3
ColdStream residency transport (d, L)** (PageRun/SlabArena/MetalBufferLease;
falsifier-gated). The index's falsifier/witness ledger entries (lines 3500-8500)
are metadata-only T0/L1 canon by design — research scaffolding, NOT dropped
product. Heavy-long-context/70B lanes are deliberately gated behind
`EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT=1` — preserved red research, not dropped.

## What's dropped vs deferred (honest)
- **Genuinely unbuilt & actionable (local/chat):** the TOP block above.
- **Deliberately deferred (NOT dropped):** OxiEML vendoring, Obscura/deno_core W6
  (Pro), Pro/Research D-items, heavy-long-context/70B lanes.
- **Blocked:** Simulation donor mining (Hermes coupling — needs clean-room).
- **Disambiguation:** EML = elementary-math IR, not episodic memory (the latter is
  the separate CoALA episode track).
