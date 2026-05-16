# Recursive Governance — Beer Viable Systems Model (S1-S5)

**Date:** 2026-05-16
**Status:** Doctrine pointer (Wave 9+ research-tier). NOT V1.
**Authority:** Doctrine doc. Cross-referenced from `RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` B2-H9.
**Source:** `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_MASTER_ARCHITECTURE.md` "Layer 5: Recursive Self-Governance"; Stafford Beer, *Brain of the Firm* (1972) + *The Heart of Enterprise* (1979).

> The architecture sentence:
> *Every named component of Epistemos exposes a viable-systems S1-S5 structure, and each S1 contains its own S1-S5 — making the system recursively governable at every scale.*

---

## 0. Why this doc exists

PASS 2 gap audit B2-H9 surfaced that the Beer VSM five-system structure (S1-S5) is named in `EPISTEMOS_MASTER_ARCHITECTURE.md` Layer 5 but absent from every canonical plan. Audit-of-audit #2 (iter 20) additionally surfaced B2-M13 ACS (Autopoietic Cognitive Stack) as a broader frame — ACS treats Beer VSM S1-S5 as one of its six recursive anchors. This doc lands the **VSM scaffold** as its own doctrine target, with explicit cross-links to ACS, so a future Wave 9+ governance sprint can reach for both without rediscovering the taxonomy.

The doc is **scaffold only**: it names the systems, maps each system to existing Epistemos primitives where there's a match, and lists what's deferred. No code is implied. No V1 surface is committed.

---

## 1. The five systems

Beer's Viable Systems Model decomposes any viable system (organism, organization, agent) into five interdependent subsystems. A system is "viable" iff all five are present and recursively present at every level of decomposition.

| System | Beer's name | Function | Epistemos primitive (when present) |
|---|---|---|---|
| **S1** | **Operations** | The primary activity producing the system's outputs. The "doing" layer. | `agent_core::agent_runtime` — tool execution · turn assembly · LLM provider dispatch |
| **S2** | **Coordination** | Damping oscillations between concurrent S1 instances; prevents resonance / interference. | `ObservationTask` lane substrate + `NightBrain` scheduler (Wave 8 — partial) · `agent_core::session` (turn isolation) |
| **S3** | **Control** | Internal regulation: optimizing how S1+S2 use shared resources. | **Residency Governor** (PASS 2 B2-M12 = §3.2 preamble in `MASTER_FUSION_NO_COMPROMISE`) — solves `min E[d(X, g(Z))] s.t. I(Z; X) ≤ R` at the per-residency-decision level |
| **S4** | **Intelligence** | Outward-looking: monitors environment + future, drift detection, adaptation strategy. | **Feature Observatory** (PASS 2 B2-H11 SAE Cognition Observatory · §3.4 SCOPE-Rex sub-module) · spectral hallucination detection (PASS 2 B2-H7 / Hermes 2.0 §13.5.8) · ClaimLedger retraction propagation (`agent_core::provenance::ledger`) |
| **S5** | **Policy** | Identity + ethos + final approval; the human-in-the-loop substrate. | **SovereignGate** (action-class biometric, MAS_COMPLETE_FUSION §B.3) · `instructions.md` per-model knowledge vault (PASS 2 B2-H2 / Hermes 2.0 §13.5.7) · scope rule 7 (Five Laws, NEW_SESSION_HANDOFF §3) · explicit User approval gates throughout `agent_core` |

---

## 2. The recursion property

Beer's load-bearing claim is that **each S1 contains its own complete S1-S5 structure**. The agent's S1 (tool execution) is itself viable: it has its own S1 (the tool's `execute()` body), S2 (intra-tool retry/circuit breaker — `agent_core::circuit_breaker`), S3 (per-tool resource governor), S4 (per-tool error_classifier — see also ORPHAN-HERMES-SALVAGE-001 status row), and S5 (per-tool approval mode in `ToolDefinition::approval`).

Tarski's fixed-point theorem provides the formal grounding: the recursive composition operator has a fixed point in the lattice of "components that own a viable-systems decomposition." In practice this means: if every named component in Epistemos exposes S1-S5, the system as a whole is recursively governable — operator-introspection at any zoom level returns a usable view.

This is **distinct from** ACS (B2-M13) recursion which uses 7 scales with 4 homeostatic loops + Kuramoto coupling. VSM is 5 systems with no oscillator-coupling claim; ACS is 7 scales with explicit coupling. They are **complementary frames**: ACS describes how recursion synchronizes across scales; VSM describes what each scale must contain to be viable.

---

## 3. Mapping table — where each VSM system already lives in main

| Epistemos component | S1 (Ops) | S2 (Coord) | S3 (Control) | S4 (Intel) | S5 (Policy) |
|---|---|---|---|---|---|
| **Agent runtime** | tool execution loop | `agent_loop` `max_turns` safety rail + session isolation | `agent_core::routing` (provider/tier select) | `error_classifier` (orphan today) | SovereignGate · per-tool approval |
| **Vault** | `NoteFileStorage` write path | `VaultIndexActor` bounded-word-count gating | `VaultStore` (Tantivy writer heap cap) | Tantivy / usearch / Halo Shadow fusion | User-initiated reset / connect only |
| **Graph** | `GraphState.applyDelta` + Rust `graph-engine` Metal renderer | `physics.rs` damping forces | `GraphCamera` adaptive framing | `GraphForceSettings` filters (B2-H5 verified shipped) | Graph-protected rule (loop §8 #12) — no camera/renderer changes without scoped approval |
| **NightBrain** | `register_canonical_tasks` task firing | `ObservationTask` 256-slot ring + (future) φ-spacing (B2-H8) | Per-task `runtime_budget` + memory-pressure FFI hook | `recent_lane_entries` diagnostic reader | `mas_runtime_preflight` (forbids Pro-only tasks in MAS bundle) |
| **Confidence / Honesty** | LLM token-stream | streaming buffer (`bufferingNewest(256)`) | logprob-based confidence routing | Spectral detector (B2-H7, post-V1) + ClaimLedger | Confidence Meter (B-3, V1 simple form) + 70%-re-learn (V1.1 full form) |
| **Identity (S5 root)** | — | — | — | — | `instructions.md` per-model · Five Laws scope rule 7 · CLAUDE.md NO SIDECAR (immutable) |

---

## 4. What's missing for a real S1-S5 mapping

The §3 table is **partial scaffolding**, not a working VSM implementation. Honest gaps:

- **S2 across components is uncoordinated.** `circuit_breaker`, `ObservationTask` lanes, `VaultIndexActor` bounded gating, and `physics.rs` damping are each S2 for their own S1, but they don't share a coordination primitive. A real VSM would have an algebra over S2 instances.
- **S3 is split between `Routing` and `Residency Governor`.** `agent_core::routing` decides provider/tier per turn (active control); Residency Governor (post-V1) decides where each capability *lives* (compression control). The two don't talk yet.
- **S4 is the weakest layer.** `error_classifier` is orphaned; SAE Cognition Observatory (B2-H11) hasn't shipped; spectral detection is Wave 9+. Until S4 has a wired drift-detection path, the system runs blind on environment changes.
- **Recursion isn't enforced.** No source-guard test asserts that every `pub struct` named in §3 actually exposes an S1-S5 introspection surface. Adding such a test would make the recursion claim falsifiable.

These are NOT bugs to fix in this slice. They're observations a future Wave 9+ governance sprint would address.

---

## 5. V1 scope

**Nothing in this doc ships in V1.** V1 keeps the existing implicit governance (SovereignGate biometrics · scope rules · per-tool approval). The VSM scaffold is forward-staging:

- When **B-3 Confidence Meter** ships its V1.1 full form (biometric + auto-re-learn), it slots into S5 cleanly.
- When **Residency Governor** ships as a real Rust module (post-V1, after the Six-tier memory table grows real eviction logic), S3 becomes load-bearing.
- When **error_classifier** is either wired or deleted per ORPHAN-HERMES-SALVAGE-001 disposition, S4 either gains its first real wire OR loses one of its few existing references — both are valid outcomes.

The acceptance bar for "VSM is real in Epistemos" would be: a source-guard test that walks the §3 table, verifies each `Epistemos primitive` cell points at code that exists, and asserts each component's introspection surface returns five non-empty fields. That test is **Wave 9+**.

---

## 6. Cross-references

- **PASS 2 gap audit B2-H9** — this doc closes that row.
- **PASS 2 gap audit B2-M13 ACS** — broader 7-scale autopoietic frame. VSM is one of ACS's six recursive anchors. Pair this doc with the future ACS doctrine row.
- **PASS 1 gap audit H-4 Overseer hierarchy** — Planner / Guardrail / Critique / Budget decomposition. Maps loosely to S5 (Planner = identity), S4 (Guardrail = drift detection), S4 (Critique = environment-aware judgment), S3 (Budget = resource control). Pair this doc with H-4 when both land.
- **`MASTER_FUSION §3.2` Residency Governor** — S3 candidate; cross-link.
- **`MASTER_FUSION §3.8` ACS** — 7-scale frame; cross-link.
- **`HERMES_AGENT_CORE_2_0_DESIGN §13.5.8` Spectral hallucination** — S4 candidate; cross-link.
- **`MAS_COMPLETE_FUSION §10` B-3 Confidence Meter** — S5 candidate (V1.1 full form); cross-link.

---

*— End. Doctrine pointer only. No code, no V1 commitment.*
