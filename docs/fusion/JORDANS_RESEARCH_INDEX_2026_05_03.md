# Jordan's Research — Executive Adds Index — 2026-05-03

> **NEW DOC — created 2026-05-03.** Filename: `JORDANS_RESEARCH_INDEX_2026_05_03.md`. Companion to `MASTER_RESEARCH_INDEX_2026_05_02.md` (do not replace — this layers under it). Sister docs: `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`, `CODEX_TASK_CONTINUITY_HANDOFF_2026_05_03.md`, `CODEX_RECONCEPTUALIZATION_HANDOFF_AND_VERIFY_2026_05_03.md`.

> **Purpose.** Jordan dropped a folder at `docs/fusion/jordan's research/` containing the executive-add research that drove the **substrate reconceptualization** of 2026-05-03. This index is the canonical pointer so future Codex / Claude / Kimi sessions cite these sources correctly and don't re-discover them. Read this doc before opening any of the contents — it tells you which file is load-bearing and which is reference.

---

## 0. Folder layout (verified)

`docs/fusion/jordan's research/`:

```
CODEX_SCOPE_REX_SUBSTRATE_PROMPT_2026_05_01.md     — Codex prompt for SCOPE-Rex substrate
CODEX_UNIFIED_EXECUTION_PROMPT_2026_04_30 (1).md   — earlier overlay (already in canon)
SCOPE_REX_GATE_REGISTER_2026_05_01.md              — gate register for SCOPE-Rex
compass_artifact_*.md                              — research artifact (Anthropic Compass)
deterministicapp.md                                — single-binary + dynamic-schema thesis
helios v2.md                                       — Helios v2 (superseded by v3)
helios v3.md                                       — Helios v3 final synthesis (LOAD-BEARING)
hermes.md                                          — Hermes XPC boundary thesis (LOAD-BEARING)
mac store edition.md                               — MAS Core architecture (LOAD-BEARING)
scope rex.md                                       — SCOPE-Rex original
scope rex omega.md                                 — SCOPE-Rex Omega with State Witness Layer
ternary kernel.md                                  — Sherry 1.25-bit ternary kernel work
kimi's research/                                   — full Kimi corpus (already canon-referenced)
```

---

## 1. Load-bearing additions (read before any substrate change)

These four files **change the architecture's center of gravity** and must be cited canonically by every downstream slice.

### 1.1 `helios v3.md` — the inference substrate's interior

**What it gives you:**
- Five mathematical pillars (Wyner-Ziv, Babai/GPTQ, ½-Lipschitz softmax, Test-Time Regression unification, eml-operator) — each peer-reviewed, named-theorem
- The **WBO-6 master inequality** bounding output drift across composed compression layers; leading factor ½ ≡ Pillar III softmax constant
- The **six-tier memory architecture** (L0 Exact Hot → L_SE Self-Evolving)
- The **KV-Direct gate** (Qasim et al. arXiv:2603.19664): residual stream is bit-identically sufficient → 27× KV memory reduction at D_KL=0
- The **Koan**: residual stream = prediction error = surprise gradient = Koopman mode = free cumulant
- 12-week build path with 7 validation thresholds
- Three deliverables: research bible, contractor build spec, MLSys/NeurIPS paper outline

**Anchors to:** Existing Resonance Gate τ+π+λ work (Lane 3 killer feature). Helios's Pillar III ½-Lipschitz IS the same ½ in the Resonance Gate truth filter. Helios's L_SE surprise gradient IS the η (evidence) component the Resonance Gate spec needs.

**Status:** **(P)** mathematical pillars; **(EV)** WBO-6 inequality; **(C)** the deeper interdisciplinary weave (free probability, Koopman, predictive coding). Treat the C parts as falsifiable predictions, not theorems.

### 1.2 `mac store edition.md` — the MAS-shippable boundary

**What it gives you:**
- The **bounded cognitive substrate** thesis: ship a vault-scoped cognitive agent, not a CLI-clone-in-MAS-clothing
- Three product features that wrap the philosophy: Vault Guard, Bounded Agent Service, Provenance Console
- Concrete entitlement plists for MAS / Pro / Research (App Sandbox + App Group + bookmarks + Touch ID + XPC + UniFFI)
- Capability-grant Rust scaffold with HMAC-scoped tokens, expiry, allowed providers, vault scope
- Migration plan: feature flags `mas_core` / `pro_cloud` / `research_unsafe` — **do not fork the architecture**
- 6–8 week MAS path with 4 owner roles (macOS lead, Rust/IPC lead, security lead, QA/review lead)
- App Review packet template
- The closing line: *"Epistemos does not make MAS agents powerful by escaping the sandbox. It makes them powerful by turning the sandbox into a user-granted cognitive boundary."*

**Anchors to:** Existing Sovereign Gate Core PR1–PR16 + ToolTierBridge + AgentEvent provenance + RRF cross-index fusion + Vault sync. Roughly 9 of 12 architectural pieces already exist on disk under different names.

**Status:** **(EV)** every concrete platform invariant cited to Apple primary docs; **(C)** the recommended XPC + App Group migration path until measured under Epistemos's exact sandbox config.

### 1.3 `hermes.md` — the cloud boundary, not a sidecar

**What it gives you:**
- The hard architectural thesis: **Epistemos owns durable memory, permissions, provenance, planning, user trust; Hermes is the exclusive boundary for cloud providers, remote MCP, web/tool execution, provider-specific churn.**
- Why XPC > raw `std::process::Command` for Hermes: child processes inherit parent sandbox, XPC services get their own
- Control plane via XPC (tiny typed messages); data plane via App Group + file-backed mmap (handles, not payloads)
- Where Wasm fits (plugins, policy-constrained executors) vs where FFI fits (audited local kernels) vs where neither fits (the cloud boundary itself — XPC wins)
- `SMAppService` for long-running Pro background work
- Capability lattice: same Hermes brain, three exterior envelopes (Core stays sandboxed; Pro adds wider providers + `SMAppService`; Research opens entitlements)
- The strategic positioning: **become the persistent host substrate that mounts provider runtimes**, not yet-another-CLI

**Anchors to:** The existing `HermesGatewayPolicy` (already shipped) + `HermesCapabilityRegistry` (just shipped) + the 26 Hermes parity commands + master dispatcher (just shipped this session). The MAS architecture in §1.2 IS the housing for this.

**Status:** **(P)** every macOS platform claim cited to Apple developer documentation. **(EV)** the recommended substrate split.

### 1.4 `deterministicapp.md` — the single-binary + super-dynamic-schema thesis

**What it gives you:**
- **Four convergent ideas** that define the app as a single binary:
  1. **Deterministic multi-variant tool ladders** — every action is A→B→C→D, each cheaper/more conservative; defer is a first-class outcome
  2. **GBNF-constrained local SLMs** — local model is a deterministic JSON producer, not a free-form prompt engine
  3. **Hybrid MD+JSON memory** — Markdown for humans, typed JSON frontmatter for machines, schema-validated writes
  4. **Minimal-UX, hidden-complexity routing** — one capture surface, one search surface, one AI surface
- The **Tool trait** Rust contract with `gbnf()`, `variants()`, `Variant<T>` strategy, `RetryBudget`, `CircuitBreaker`
- Exhaustive native tool catalog (sections 2.1–2.N) covering every Epistemos surface as a typed tool with variants
- The reasoning budget rule: ≤256 tokens of `reasoning` BEFORE the answer field, never after (BFCL/ToolHop empirical lesson)
- The "Brief Is Better" finding: Qwen 7B peaks at ~32-token CoT budgets

**Anchors to:** The Hermes parity dispatcher (just shipped) + the Resonance Gate ½-Lipschitz constraint + the existing MutationEnvelope schema-validated writes. Deterministicapp's "tool ladder with defer terminal" IS the same idea as the Resonance Gate's "no τ=-1 reaches the user" invariant — both make *not acting* a first-class outcome.

**Status:** **(P)** every cited paper (BFCL, ToolHop, Brief Is Better, A-MEM, MemGPT, Voyager, LSFS) is real. **(EV)** the integrated substrate as proposed for Epistemos.

---

## 2. High-context references (read when slice touches the topic)

### 2.1 `scope rex omega.md` + `scope rex.md` + `SCOPE_REX_GATE_REGISTER_2026_05_01.md` + `CODEX_SCOPE_REX_SUBSTRATE_PROMPT_2026_05_01.md`

**What it gives you:**
- **SCOPE-Rex Omega** = Sparse-feature observatory + Claim-graph + Ontology + Proof + Execution runtime + **State Witness Layer** (the new addition)
- The state vector S_t = (h_t, z_t, g_t, p_t, m_t, w_t, ℓ_t, u_t) — model working state, sparse features, claim graph, proof state, persistent memory, tool/world state, durable ledger, authorization
- "Inter-dimensional reasoning" reframed as **cross-space consistency** (token / latent / claim / proof / memory / tool / runtime spaces)
- The **constrained action selection** objective with weighted ontology violation, proof failure, drift, compute, info-gain, feature-target terms
- The **brain time machine** three-layer memory: working state (KV / MLA), semantic active memory (claim graph), durable event history (immutable semantic deltas)
- DeepSeek MLA + mHC routing recommendation: **don't rewrite attention; route via Sinkhorn-projected balanced matrix** instead

**Anchors to:** Existing OpLog + EventStore + AgentEvent + GraphEvent layers — those ARE Layer C (durable event history) per SCOPE-Rex Omega's three-layer memory hierarchy.

### 2.2 `ternary kernel.md`

**What it gives you:**
- The Sherry 1.25-bit ternary kernel (Huang et al. arXiv:2601.07892, ACL 2026) full implementation guide
- Pack/unpack patterns, Apple Silicon Metal kernels, the 3:4 sparsity invariant
- Doctrine §A.5 honest-stance compatibility check (NOT QLoRA-compatible; use QOFT/QDoRA/QPiSSA for production continual learning)

**Anchors to:** Lane 6 (ternary) work in `AGENT_BUILD_WORKCARDS_LANES_3_TO_6_2026_05_03.md` L6-CARD-1.

### 2.3 `helios v2.md`

**Superseded by `helios v3.md`** for normative claims. Keep for reference on which decisions changed between v2 and v3 (the WBO-6 ½ factor is new in v3; the KV-Direct gate is new in v3).

### 2.4 `compass_artifact_wf-*.md`

External research artifact (Anthropic Compass-format). Reference; not load-bearing.

### 2.5 `kimi's research/` (full subfolder)

The Kimi research depth folder. Already canonically referenced in `MASTER_RESEARCH_INDEX_2026_05_02.md` §8 ("Kimi Research Index — Donor Depth, Not Authority"). Continue treating as donor depth — read for breadth, do not lift line counts or "X is shipped" claims directly. Notable files: `epistemos_resonance_gate.md` (Σ signature spec, 9 claim types, 5 directional operators), `scope_rex_final_architecture.md` (definitive SCOPE-Rex architecture), `ternary_spectral_architecture.md` + `ternary_code_scaffolds.md` + `ternary_reconceptualization.md` (the ternary trio), `EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md` (Pro/Research entitlement bundle), `EPISTEMOS_MASTER_ARCHITECTURE.md` (7-layer cognitive substrate diagram), `acs_meta_layer.md` (ACS recursion), `osft_psoft_coso_fusion.md` (continual learning), `EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` (KV implantation).

---

## 3. Authority order — where these new docs sit

Updates the doctrine §1 authority hierarchy from `MASTER_RESEARCH_INDEX_2026_05_02.md`:

| Order | Layer | Includes |
|---|---|---|
| 1 | Current code + passing logs | unchanged |
| 2 | Repo authority docs | unchanged |
| 3 | April 30 fusion canon | unchanged |
| 4 | May 2 fusion packet | unchanged |
| **4.25** | **Jordan's executive-add research (May 3)** | `helios v3.md`, `mac store edition.md`, `hermes.md`, `deterministicapp.md`, `scope rex omega.md` (THIS SECTION) |
| 4.5 | Quick Capture standalone canon | unchanged |
| 5 | Kimi research depth | unchanged |
| 5.5 | External research depth | unchanged |
| 6 | Worktree code | unchanged |

**Why 4.25 not higher:** these docs are research-grade syntheses, not yet repo authority. They influence doctrine but don't override it until reconciled by `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md` (the next sister doc).

---

## 4. Concept → source map (what to cite when)

| Concept | Canonical source in this folder |
|---|---|
| KV-Direct gate (residual sufficiency) | `helios v3.md` Part II, T_R; cites Qasim et al. arXiv:2603.19664 |
| WBO-6 master inequality | `helios v3.md` Part II |
| Six-tier memory (L0–L_SE) | `helios v3.md` Part III |
| Sherry 1.25-bit ternary | `helios v3.md` Part II T_Q + `ternary kernel.md` |
| MAS-shippable XPC + App Group + bookmarks | `mac store edition.md` (full doc) |
| Hermes as XPC boundary, not child process | `hermes.md` (full doc) |
| Capability grants (HMAC-scoped, time-bounded) | `mac store edition.md` §"Capability grants" + `hermes.md` |
| Vault-Scoped Cognitive Agent framing | `mac store edition.md` closing section |
| Single-binary + super-dynamic-schema thesis | `deterministicapp.md` §1 |
| Deterministic multi-variant tool ladders | `deterministicapp.md` §1 + §2.0 |
| GBNF-constrained local SLM as JSON producer | `deterministicapp.md` §1 |
| Hybrid MD+JSON memory | `deterministicapp.md` §1 |
| Minimal-UX, hidden-complexity routing | `deterministicapp.md` §1 |
| State Witness Layer + cross-space consistency | `scope rex omega.md` §"The architecture revision" |
| Three-layer memory (working / semantic / durable event history) | `scope rex omega.md` §"The brain time machine" |

---

## 5. What this index does NOT do

- It does **not** override `MASTER_RESEARCH_INDEX_2026_05_02.md`. That remains the first-stop for any concept. This index is the **augment** that adds the May-3 executive layer.
- It does **not** restate doctrine §7 build-order. That stays. The reconceptualization doc explains how the new pieces map onto existing lanes.
- It does **not** decide what ships. That's the reconceptualization doc's job.
- It does **not** rewrite any existing canon. Reconciliation happens in the sister `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`.

---

## 6. How to use this index (operational rule)

When opening a slice:

1. Look up the concept in `MASTER_RESEARCH_INDEX_2026_05_02.md` §22 first.
2. If the concept appears in §4 of this doc, also read the named source from `docs/fusion/jordan's research/`.
3. If the source contradicts older canon, the resolution is in `EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md`. If no resolution exists yet, flag a gap in `CANON_GAPS_AND_ADDENDA_2026_05_02.md` and stop.

That keeps the new research grounded without letting it silently overwrite older decisions.
