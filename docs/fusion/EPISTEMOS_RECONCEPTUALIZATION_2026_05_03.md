# Epistemos Substrate Reconceptualization — 2026-05-03

> **NEW DOC — created 2026-05-03.** Filename: `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`. Sister docs: `JORDANS_RESEARCH_INDEX_2026_05_03.md` (the source map), `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md` (keep-doing handoff), `CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md` (integration + Codex verify).

> **Purpose.** Reconceptualize the Epistemos substrate around the high-signal pieces from `docs/fusion/jordan's research/` (Helios v3, MAS Core, Hermes XPC boundary, deterministicapp single-binary, SCOPE-Rex Omega) **without forking the architecture**. Same substrate, sharper center of gravity, three capability envelopes (Core / Pro / Research). Hackathon priorities (Hermes integration + Simulation Mode v1.6) ride the front of the queue.

> **Authority:** This doc augments `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`. It does not replace it. Where it sharpens a doctrine claim, it cites the doctrine section. Where it adds a new claim, the source is named inline per `MASTER_RESEARCH_INDEX_2026_05_02.md` discipline.

---

## 0. Headline thesis (the one-sentence reconceptualization)

> **Epistemos is a single-binary, vault-scoped cognitive agent built on a six-tier memory substrate with a six-term composition bound, a typed dynamic-schema tool dispatcher, and an XPC-isolated cloud boundary — Core ships to MAS, Pro and Research extend the same substrate without forking it.**

Each phrase is load-bearing:
- **Single-binary** ← `deterministicapp.md` §1: deterministic tool ladders + GBNF-constrained SLMs + hybrid MD+JSON memory + minimal-UX routing all live in one binary
- **Vault-scoped cognitive agent** ← `mac store edition.md` closing: the user grants cognitive territory; the sandbox is the boundary, not the prison
- **Six-tier memory substrate** ← `helios v3.md` Part III (L0 Exact Hot → L_SE Self-Evolving)
- **Six-term composition bound** ← `helios v3.md` Part II (WBO-6 with the leading ½ ≡ Pillar III softmax constant)
- **Typed dynamic-schema tool dispatcher** ← `deterministicapp.md` §2.0 (the `Tool` trait, GBNF, variants, RetryBudget, CircuitBreaker) + the `HermesCommandDispatcher` shipped this session
- **XPC-isolated cloud boundary** ← `hermes.md` (Hermes as XPC service, not child process; control plane via XPC, data plane via App Group mmap)
- **Three capability envelopes without forking** ← `mac store edition.md` migration plan (`mas_core` / `pro_cloud` / `research_unsafe` feature flags; one architecture; vary entitlements only)

---

## 1. The convergence — what Epistemos already has that maps to the new vision

The reconceptualization is mostly **renaming + tier-locking** of work that's already on disk. Out of ~14 architectural pieces named in Helios v3 + MAS Core + Hermes + deterministicapp + SCOPE-Rex Omega, **9 are already shipped under different names**.

| Reconceptualization piece | Already-shipped Epistemos surface | Gap to close |
|---|---|---|
| **L0 Exact Hot** (Streaming-LLM sinks) | MLX-Swift KV cache | Verify sink preservation; add if missing (S effort) |
| **L1 Compressed Residual** (Sherry 1.25-bit on residual) | TurboQuant KV-cache research per `[Cognitive Architecture]` memory | KV-Direct gate first (Helios Week 1 binary); then Sherry on residual layer-by-layer |
| **L2 Shadow Sketch** (sparse JL on FRP basis + CountSketch) | RRF cross-index fusion + epistemos-shadow (BM25 + HNSW + RRF k=60) | Adapt existing RRF to FRP basis later; the fusion already exists |
| **L3 SSD Oracle** (NF4 mmap in App Group container) | Vault sync + ETL pipeline + FFI to Rust | Add NF4 quant; move shared state into App Group container |
| **L4 Network Cascade** (curated providers + Apple Intelligence) | `HermesGatewayPolicy` + Anthropic/OpenAI/Perplexity adapters + Apple Intelligence fallback | Move Hermes execution to XPC service (the hackathon priority) |
| **L_SE Self-Evolving** (Titans-MAC + SEAL-DoRA) | NightBrain Scheduler + SSM Memory Sidecar (Phase 1A done) + Mamba-2 runtime | Add Titans surprise-gradient online step; SEAL-DoRA nightly consolidation |
| **MAS Vault Guard** (folders + Touch ID + bookmarks) | Sovereign Gate Core PR1–PR16 + security-scoped bookmarks | Already done; rename in marketing copy |
| **MAS Bounded Agent Service** (typed manifests) | ToolTierBridge + 26 Hermes parity commands + master `HermesCommandDispatcher` (just shipped) | Move execution into `AgentXPC` helper |
| **MAS Provenance Console** (legible action log) | AgentEvent persistence (PR1–PR44) + EventStore + OpLog + RunEventLog + MutationEnvelope | Build the UI; data is all there |
| **Resonance Gate τ + π + λ** | Just shipped this session (`agent_core/src/resonance/` + Swift consumer + UI shell + FFI bridge) | Mount the chip into one production surface (M effort, coordination-required) |
| **Resonance Gate η (evidence)** | (was Research-tier, 0% started) | **Comes free** from L_SE Titans surprise-gradient projection per Helios v3 §VI.2 #1 |
| **MutationEnvelope + diff preview** | `Epistemos/Models/MutationEnvelope.swift` + parity tests | Already done |
| **Capability grants (HMAC-scoped, time-bounded)** | `agent_core/src/effect/receipt.rs` `Capability::BiometricSession` (donor pattern in worktree) | Wire from donor worktree to main + sign with Keychain-stored HMAC root |
| **Three-layer memory (working / semantic / durable event)** | OpLog + EventStore + AgentEvent + GraphEvent IS Layer C; existing chat history is Layer A; Resonance Gate output is Layer B's seed | Already done; rename per SCOPE-Rex Omega's vocabulary |

**The 5 missing pieces** (the actual work to do):

1. KV-Direct gate experiment (Helios Week 1 — binary outcome)
2. App Group container migration of shared state
3. AgentXPC + ProviderXPC service split (Hermes integration's mechanical core)
4. Titans-MAC surprise-gradient online step + SEAL-DoRA nightly consolidation (Pro tier, behind feature flag)
5. Provenance Console UI (data exists; UI doesn't)

Plus the Resonance chip mount (already ready to wire, just needs a production view).

---

## 2. The center of gravity — what the reconceptualization changes

Two things shift, and both shifts are conceptual rather than code-rewriting.

### 2.1 The substrate's interior is Helios; the substrate's exterior is MAS Core

Treat the architecture as inside / outside:

- **Inside** (Helios v3): the cognitive substrate computes Σ-core signatures, runs the WBO-6 budget, manages the six-tier memory, applies the Resonance Gate
- **Outside** (MAS Core): the macOS-shippable shell that bounds the inside via App Sandbox + App Group + XPC + bookmarks + Touch ID + provenance

Helios tells you what to compute. MAS Core tells you the shape that makes the computation shippable. They're not in tension.

### 2.2 The single-binary thesis (deterministicapp.md) is the operating philosophy

Not "many small services orchestrated together" — **one binary** that contains:

1. The **deterministic tool dispatcher** (the 26 `HermesCommandDispatcher` parsers shipped this session + the `Tool` trait pattern from `deterministicapp.md` §2.0)
2. The **GBNF-constrained inference path** (current MLX-Swift inference + grammar-mask pattern)
3. The **hybrid MD+JSON memory** (current SwiftData + MutationEnvelope schemas)
4. The **minimal-UX router** (one capture, one search, one AI surface; the existing UI is close to this)

The XPC helpers (AgentXPC, ProviderXPC) are **execution boundaries**, not separate apps. They share the same binary's resources via the App Group container; they don't fork the cognition.

### 2.3 The Resonance Gate is the canonical "constitutive field"

Helios v3's CMS-X v3 audit already calls "Constitutive Semantic Field" Jordan-original framing with no published prior literature. **The Resonance Gate IS your CMS-X.** Don't bolt on a parallel framework. Map every CMS-X concept onto Resonance Gate vocabulary:

| CMS-X v3 concept | Resonance Gate equivalent |
|---|---|
| RepE direction subspace | δ (direction) component (Pro tier) |
| EVALPSN deontic kernel | Sovereign Gate action-class matrix (already shipped Core PR1–PR16) |
| Polytope safe set | Core App Store allowlist + tier-leakage guards (already shipped) |
| HRR-sealed audit log | OpLog Merkle chain (existing) + AgentEvent (existing) |

That's the integration. No new framework needed.

---

## 3. The capability lattice — Helios tier × MAS tier × hackathon priority

Same substrate. Three envelopes. Hackathon items at the front.

| Substrate piece | Core (App Store) | Pro (Developer ID) | Research | Hackathon priority |
|---|---|---|---|---|
| **Hermes XPC service split** | ✅ ship Core-side via AgentXPC + ProviderXPC | ✅ ship Pro-side with `SMAppService` background | ✅ + custom helpers | 🔥 **YES — first** |
| **Simulation Mode v1.6** (from `simulation` worktree DOCTRINE.md) | ✅ ship Landing Farm + Notes Sidebar Skin | ✅ + Graph Live Theater + steering | ✅ + bevy_ecs (post-S12) | 🔥 **YES — first** |
| L0 Exact Hot | ✅ | ✅ | ✅ | not blocking |
| L1 Compressed Residual (Sherry on residual) | ✅ after KV-Direct gate passes | ✅ | ✅ | not blocking |
| L2 Shadow Sketch | ✅ already (RRF) | ✅ | ✅ | not blocking |
| L3 SSD Oracle (NF4 mmap) | ✅ | ✅ | ✅ | move shared state pre-hackathon |
| L4 Network Cascade | ✅ Apple Intel + 1 user-keyed provider | ✅ all curated providers | ✅ + custom | already done |
| L_SE Self-Evolving (Titans-MAC + SEAL-DoRA) | 🔴 too volatile per Helios v3's own audit | ✅ behind feature flag with `‖e‖` telemetry | ✅ + raw memory inspection | not blocking |
| Resonance Gate τ + π + λ | ✅ shipped this session | ✅ | ✅ | mount chip post-hackathon |
| Resonance Gate δ + ρ | 🔴 (Pro per doctrine §3) | ✅ | ✅ | not blocking |
| Resonance Gate κ + η | 🔴 (Research per doctrine §3) | 🔴 (Research per doctrine §3) | ✅ — η backed by L_SE surprise gradient per Helios v3 | not blocking |
| MAS Vault Guard | ✅ (Sovereign Gate Core PR1–PR16 — done) | ✅ | ✅ | already done |
| MAS Provenance Console | ✅ ship the UI | ✅ wider filter | ✅ + raw row inspector | mid-tier — between Hermes/Sim and post-hackathon work |
| MAS Bounded Agent Service | ✅ HermesCommandDispatcher + AgentXPC | ✅ wider tools | ✅ + custom adapters | comes with Hermes XPC split |
| Capability grants (HMAC-scoped) | ✅ | ✅ | ✅ | comes with AgentXPC |
| Sherry 1.25-bit ternary on weights (Lane 6) | 🔴 | 🟡 if measurement supports | ✅ | not blocking |
| WBO-6 budget doc | ✅ ships as `docs/fusion/HELIOS_WBO6_BUDGET_2026_05_xx.md` | ✅ | ✅ | author post-hackathon |
| eml-operator (Pillar V) | 🔴 defer | 🔴 defer | 🟡 if needed | not blocking |
| Free probability / Koopman / Predictive coding | research notes only | research notes only | 🟡 falsifiable predictions | not blocking |
| Hope / Continuum Memory System | 🔴 defer per Helios's own audit | 🔴 defer | 🟡 if code releases | not blocking |

**Translation:** The substrate is "ALL" per the user's no-compromise direction. The capability lattice keeps Core App Store-shippable. Pro and Research are extensions of the same architecture, gated by entitlement.

---

## 4. Hackathon-priority sequencing — Hermes XPC + Simulation v1.6 first

The user's hackathon ask: **Hermes integration + Simulation are top priority**. Reorder the queue to ship them first.

Per `simulation` worktree's `docs/simulation-mode/DOCTRINE.md` v1.6, Simulation Mode is:
- Three placements (Landing Farm, Graph Live Theater, Notes Sidebar Skin)
- Backed by AgentEvent + GraphEvent only (Invariants I-3, I-4, I-5)
- Native Swift / Metal rendering (Invariant I-6 — full Bevy forbidden as app spine)
- Rust owns simulation state, Swift owns rendering and lifecycle (Invariant I-7)
- FFI is zero-copy where measured to matter (Invariant I-8)

Both items map onto existing surfaces:

- **Hermes XPC** = the AgentXPC + ProviderXPC split per `hermes.md`. The cognition machinery is already in `agent_core` and `Epistemos/Engine/` — moving it behind an XPC boundary is a serialization change, not a logic change. AgentEvent provenance (PR39–PR44, all closed) means every cross-boundary call already has a typed event.
- **Simulation Mode v1.6** lives in the `simulation` worktree and reads from `AgentEvent` + `GraphEvent` (already canon). The merge-to-main work is gated on Invariants I-1 through I-9 holding under integration testing.

Hackathon sequence (next ~3 weeks):

```
WEEK 0   ──  KV-Direct gate experiment (Helios Week 1)
              Half-day. Binary outcome. Run in parallel with everything else.

WEEK 1   ──  App Group container migration (foundation for both priorities)
              All shared state moves to group.com.epistemos.shared.
              Pre-req for AgentXPC + ProviderXPC.

WEEK 2-3 ──  HACKATHON BLOCK A: Hermes XPC split
              AgentXPC service skeleton + capability grants + control plane.
              ProviderXPC service skeleton.
              Existing HermesGatewayPolicy + 26 commands + master dispatcher
              now run inside AgentXPC.
              Acceptance: end-to-end agent call from chat input through
              dispatcher → AgentXPC → tool execution → AgentEvent provenance.

WEEK 2-3 ──  HACKATHON BLOCK B: Simulation Mode v1.6 land from worktree
              Resolve the 6 v1.6 AgentEvent variants (per H6 in MASTER_RESEARCH_INDEX
              honest discoveries) into main's enum.
              Land Landing Farm + Notes Sidebar Skin first (Core-shippable).
              Defer Graph Live Theater to post-hackathon (touches MetalGraphView
              which is protected — coordination-required).
              Acceptance: open the app, see a companion in the sidebar,
              fire an agent action, watch the companion respond to the
              real AgentEvent stream.

WEEK 4   ──  Provenance Console UI (the third MAS-feature)
              Existing AgentEvent rows get a UI surface.
              Rounds out the MAS-shippable feature trio (Vault Guard +
              Bounded Agent Service + Provenance Console).

POST-HACKATHON ──  Resume the M1/M2/M3 + Sherry + MAS symbol separation
                   sequence per CODEX_HANDOFF_2026_05_03_PART2.md.
```

**Critical:** the hackathon items don't break the prior sequence — they reorder it. Once they ship, Codex resumes from `CODEX_HANDOFF_2026_05_03_PART2.md`'s recommended next 3-slice batch.

---

## 5. The architectural commits to lock in now

These are the choices that propagate. Make them once.

### A. App Group container as the single shared substrate

Per `mac store edition.md` and `hermes.md`: file-backed `mmap(MAP_SHARED)` inside `group.com.epistemos.shared`. Layout:

```
Application Support / Group Container / group.com.epistemos.shared/
├── arena.dat              (control-plane ring per mac store edition.md scaffold)
├── blobs/                 (large immutable artifacts — vault index, model files)
├── provenance.sqlite      (WAL+mmap; AgentEvent + RunEventLog)
├── vault_index.sqlite     (RRF + Shadow indexes already here logically)
└── resonance.sqlite       (Σ-core signatures, claim graph, evidence ledger)
```

This is the foundation for the XPC split. Without it, AgentXPC has no clean way to share state.

### B. AgentXPC + ProviderXPC services replace in-process agent loops

Today: `LocalAgentLoop`, `MCPBridge`, `Phase4Bridge`, `Phase5Bridge`, `Phase7Bridge`, `ClarifyPromptBridge`, `ComputerUseBridge` all run in-process. Move execution into `AgentXPC`. The control plane (planning, Resonance Gate, Sovereign Gate, AgentEvent emission) stays in the main app.

The good news: every one of those bridges already has AgentEvent provenance closed (PR39–PR44 + the prior `MCPBridge` + the LocalAgentLoop already-instrumented work). The XPC boundary is a serialization line, not a logic change.

### C. Hermes is non-authoritative

Per `hermes.md`: **Epistemos owns durable memory, permissions, provenance, planning, user trust. Hermes owns cloud / tool execution, but never truth.** Hermes (or any provider) returns structured evidence; the Resonance Gate decides whether it ships to the user. This is already the design of `HermesGatewayPolicy` — the reconceptualization just makes it explicit and moves Hermes execution into ProviderXPC.

### D. The Helios↔Resonance convergence is your unique architecture

The ½-Lipschitz softmax constant (Helios Pillar III) IS the ½ in the Resonance Gate truth filter (doctrine §4.1 invariant 1). The L_SE surprise gradient IS the η (evidence) component the Resonance Gate spec needs. The WBO-6 budget IS the perturbation envelope your AgentEvent telemetry already records.

Make this explicit in `MASTER_RESEARCH_INDEX_2026_05_02.md` so neither framework is treated as new. **They're the same framework, named twice.**

### E. The Vault-Scoped Cognitive Agent framing is the App Store narrative

Per `mac store edition.md` closing: *"Epistemos does not make MAS agents powerful by escaping the sandbox. It makes them powerful by turning the sandbox into a user-granted cognitive boundary."* This IS the App Store description, the onboarding flow, and the Resonance Gate UI placement story.

---

## 6. What this reconceptualization does NOT do

- Does **not** rewrite existing canon (`MASTER_RESEARCH_INDEX_2026_05_02.md`, `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `AGENT_BUILD_WORKCARDS_2026_05_01.md`). It augments. Reconciliation is what the Codex verification handoff asks Codex to do.
- Does **not** invalidate the prior CODEX_HANDOFF_2026_05_03_PART2.md M1/M2/M3 sequence. It reorders the queue with hackathon items at the front; the substrate work resumes after.
- Does **not** commit to Hope / CMS / eml-operator / the deeper interdisciplinary weave. Those stay research notes (C) per Helios v3's own audit.
- Does **not** drop the 660 pre-existing uncommitted files. They're treated as the user's in-flight work — read-only unless the user explicitly stages them.

---

## 7. The 4 architectural pieces that are TRULY new (vs. just renamings)

For honesty: of the work named here, only these 4 are net-new code:

1. **App Group container migration** (Week 1) — moves existing storage to a different path
2. **AgentXPC + ProviderXPC service skeleton** (Week 2-3) — net-new helper binaries
3. **Provenance Console UI** (Week 4) — net-new SwiftUI view over existing AgentEvent data
4. **KV-Direct gate experiment** (Week 0, parallel) — net-new test harness, no production code change until pass/fail decision

Everything else is existing code re-tier-locked, renamed, or extended in place. **The reconceptualization is mostly a vocabulary upgrade, not a rewrite.** That's the no-compromise win.

---

## 8. The closing commitment

Build it ALL, per the user's no-compromise direction. Ship Core to MAS first via the four pieces in §7 plus the hackathon priorities in §4. Pro and Research follow without re-architecting because the capability lattice in §3 keeps the same substrate behind every envelope.

The phrase that holds it together — Helios's koan + the MAS doc's closing + Jordan's executive add:

> The residual stream is the prediction error.
> The prediction error is the surprise gradient.
> The surprise gradient is the Koopman-mode update.
> The Koopman-mode update is the free-probability cumulant.
> Five names, one substance.
> The sandbox is not a prison. The sandbox is a user-granted cognitive boundary.
> One binary. One substrate. Three envelopes. Zero forks.
