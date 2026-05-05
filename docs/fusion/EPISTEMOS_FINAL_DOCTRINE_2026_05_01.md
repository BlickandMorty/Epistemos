# Epistemos Final Doctrine — 2026-05-01

> **NEW DOC — created 2026-05-02.** Filename: `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`. If a Codex/Kimi/Claude session, agent index, MEMORY.md pointer, or older auto-generated doc list does not show this file, **search for it by name** — it is real and in the canon. Sister packet docs from the same session: `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` (the new Codex overseer prompt), `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md` (cross-worktree salvage map), `ALL_DOCS_INDEX_2026_05_02.md` (the live index of every load-bearing doc), and `CODEX_DELIBERATION_PROMPT_2026_05_02.md` (non-interrupting deliberation prompt). The packet lives at `/Users/jojo/Downloads/Epistemos/docs/fusion/` and is mirrored into active worktree `docs/fusion/` folders when a session needs clickability. Recent research/plan docs this may resolve to: any *Kimi*, *no-compromise*, *resonance gate*, *sovereign gate*, *tier matrix*, *SCOPE-Rex*, *ACS*, *zero-copy*, *single-binary*, or *killer feature* doc dated 2026-04-30 or 2026-05-01.

> **One sentence.** Epistemos is a native macOS verifiable cognition substrate where every meaningful action becomes a typed, provenance-linked event before it becomes a UI effect — and every research feature ships, but tier-gated.

This doc is the truth-router for Codex, Kimi, and Claude builders. It does not replace the April 30 fusion canon — it sits on top of it, locks in three things the canon left implicit (parallel-tier ship model, three killer features, biometric gating), and points back into the canonical substrate state for everything else.

---

## 1. Authority Order

When sources disagree, this is the order:

1. **Current code + passing logs.**
   See `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`. If a file exists and a test passes, that wins.

2. **Repo authority docs.**
   `AGENTS.md`, `CLAUDE.md`, `docs/architecture/PLAN_V2.md`, `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md`, `docs/_consolidated/00_canonical_authority/*`, **`docs/APP_STORE_RELEASE_COMPLETION_STATUS_2026_04_24.md`** *(C8, merged 2026-05-05 — App Store closeout authority; mirrored at `docs/_consolidated/30_canonical_operational/`)*, **`docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md`** *(C14, named explicitly 2026-05-05 for searchability — Halo V1 stack reference)*.

3. **April 30 fusion canon.**
   `README_START_HERE_2026_04_30.md`, `CANONICAL_SOURCE_MAP_AND_GATE_REGISTER_2026_04_30.md`, `BUILDER_EXECUTION_PROMPT_2026_04_30.md`, `CODEX_ACTIVE_OVERSEER_KIMI_PROMPT_2026_04_30.md`, `FUSED_IMPLEMENTATION_QUEUE_2026_04_30.md`, plus the three Downloads-root April 30 docs.

4. **This doctrine.**
   Adds three-tier ship model, killer features, biometric gating. Does not override any of the above.

5. **Kimi research depth (read-only reference).**
   `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/`. Treated as donor research, not direct execution authority. Specific file pointers in §8 below.

5.5. **Quick Capture standalone canon.** *(C9, merged 2026-05-05.)*
   `/Users/jojo/Documents/Epistemos-QuickCapture/PLAN.md` + `FINAL_SYNTHESIS.md` (FINAL_SYNTHESIS corrects PLAN.md where they conflict). Authority for the Quick Capture track only. Worktree donor: `vigorous-goldberg-3a2d35`. Treat as authoritative for Quick Capture decisions; subordinate to repo authority docs (§1 #2) and this doctrine for everything else.

6. **Worktree code.**
   Donor evidence. Inventory before reuse. Never raw-merge.

---

## 2. Substrate Spine + Architectural Invariants

### 2.1 Substrate spine (unchanged)

```
TypedArtifact
  → MutationEnvelope
  → RunEventLog / AgentEvent / GraphEvent
  → Halo / Graph / Theater / Audit projections
```

### 2.2 Architectural invariants (every tier, non-negotiable)

These four hold for Core, Pro, and Research alike. Violating any of them is P0.

1. **Zero-copy unified memory.** Apple Silicon UMA means CPU, GPU, and ANE share one physical RAM pool at ~138–153 GB/s fabric bandwidth. Tensors flow via `MTLBuffer` with `storageModeShared` and IOSurface where ANE is involved. No `cudaMemcpy`-style double-buffering. No serialize-then-deserialize across the FFI boundary for hot tensors. Any inference patch that copies weights, KV vectors, or activations across CPU↔GPU↔ANE on the hot path is wrong.
2. **Single-binary in-process substrate.** All crates link into one `epistemos` process. Subprocess for **inference** is forbidden in every tier. The Quick Capture pattern — UniFFI hop into the same process address space — is the canonical shape. Hermes / CLI tunnels / browsers / Docker run in subprocesses for **orchestration only**, and only in Pro/Research builds.
3. **Markov blanket via Rust ownership.** The borrow checker is the organizational closure of the system. Internal state (claim graph, ledger, residency governor, KV cache) is owned by Rex (the Rust kernel); Swift sees it through narrow UniFFI surfaces. No FFI panics, no `unsafe` without `// SAFETY:` justification, no hidden global mutable state.
4. **Tiered determinism.** State transitions are logged, hashed (BLAKE3), and reproducible — *not* every byte of inference. T0–T4 verification ladder (see §5) decides what is checked when. Z3 never runs on the hot path; T2 Proptest catches 95% at ~1µs.
5. *(C5, merged 2026-05-05.)* **Canonical state is the only source of truth.** Visual layers — Liquid Wave, Simulation Theater, Halo overlays, Residency Rail, Sovereign Gate dialog, Pulse ghost text — project from canonical events (`AgentEvent`, `GraphEvent`, `MutationEnvelope`) and Rust kernel state. They do not own state. A visual surface that implies state the runtime does not authoritatively own is a §2.2 violation. If a UI shows "thinking" and the agent is not actually thinking, that is P0.

What is closed today (per `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`):

- Card 4 minimal typed-artifact slice (`TextCapturePipeline`, `QuickCaptureIntent`, `EventStore.saveMutationEnvelope`).
- OpLog Swift bridge (PR1), EventStore→OpLog projection (PR2), lease/retry (PR3A), dead-letter (PR3B), worker scheduling (PR3C), read-only diagnostics (PR3D), replay snapshots (PR4A), BLAKE3 chain verification (PR4B).
- AgentEvent durable persistence (PR1) + PipelineService observed-tool emission (PR2) + ChatCoordinator Rust-stream emission (PR3).
- Durable GraphEvent mutation mapping (PR1) + read-only Settings visibility (PR2) + read-only projection snapshots (PR3).
- R15 benchmark recorder + PR2/PR3/PR4 fixtures (graph payload, markdown FFI, code-token FFI, editor-shell, sqlite-vec 100k×32d KNN).
- R16 ETL substrate through PR3H (memory-pressure pause, MAS bookmark enforcement, model-derived badges, ETL worker execution).
- V0 Contextual Shadows production-mounted with Shadow backend route.

This is the floor. Build on it. Do not rebuild it.

---

## 3. The Tier Matrix — Three Parallel Tracks

The April 30 canon split Core vs Pro and listed Research as deferred. **The user's stance is no longer "Core first, then maybe Pro/Research" — it is "all three ship in parallel via different distribution channels."** This doctrine locks that in.

| Tier | Distribution | Sandbox | Hardened Runtime | Critical entitlements | What ships |
|---|---|---|---|---|---|
| **Core** | App Store + TestFlight | YES | YES | standard sandbox + security-scoped bookmarks | Local vault intelligence, Prose, graph, search, Halo / Contextual Shadows, typed artifacts + provenance, bounded chat/agent, Apple Foundation Models / MLX local inference, App Intents, Spotlight, public APIs only |
| **Pro** | Developer ID + Notarization (direct download) | NO | YES | `cs.allow-jit`, `cs.allow-unsigned-executable-memory`, `cs.disable-library-validation`, `automation.apple-events` | All Core + Hermes subprocess orchestration, Claude Code / Codex / Kimi / Gemini CLI tunnels, MCP server tunnels, browser/computer-use, Docker / devcontainer, Simulation Theater, Deep Deliberation jury, embedded JS runtime (QuickJS / Deno) |
| **Research** | Developer ID + Notarization (separate channel; can be same binary with feature flag) | NO | YES | Same as Pro + dynamic private framework loading | All Pro + direct ANE access via `_ANEClient` (loaded through `disable-library-validation`), KV cache implantation via `MTLBuffer.contents()`, activation steering, neural implant loading, Sherry 1.25-bit ternary weights, Resonance Gate full neural components, sparse autoencoder feature visualization |

**One codebase, three compile targets.** Cargo features `core`, `pro`, `research` plus a `PolicyProfile` enum gate everything at runtime. CI tests all three. Every PR declares profile impact.

**Why Developer ID + Notarization is legal for Pro/Research:** Notarization is an automated malware scan, not App Review. It does NOT check for private API use, embedded JS runtimes, subprocess freedom, or private framework loading. With `disable-library-validation` set, you can load `AppleNeuralEngine.framework` dynamically. This is the same path Chromium uses. (Source: `Kimi_Agent_Deterministic AI Deep Dive/EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md` Part II.)

**What is forbidden in every tier:**

- Private `com.apple.private.*` entitlements (Apple grants these only to Apple).
- Hidden cloud calls without user opt-in.
- Hot-path subprocess for *inference* (Hermes subprocess for *orchestration* is OK in Pro/Research; never in Core).
- API keys outside macOS Keychain.

---

## 4. UX Posture and the Three Killer Features

### 4.0 UX Posture (every tier) *(C4, merged 2026-05-05)*

**One composer, two modes.** Chat mode and Agent mode share the same input affordance — same composer view, same shortcut, same surface. Mode is a toggle next to the composer, not a separate entry point in the sidebar. The user sees one place to write; the system routes by mode.

**Effort control is separate from mode.** Effort (fast / thinking / research / agent / liveAgent) lives on its own axis next to the composer. Effort can be changed mid-conversation without leaving the thread. Effort is never bundled into "modes."

**Tools are capabilities, not a third mode.** A tool call is something the agent does inside a turn — not a separate UX surface. There is no "Tools mode." Capability gating happens at the agent layer through the Sovereign Gate (§4.2) and the tool registry (`agent_core/src/tools/registry.rs`), not at the composer.

**Per-tier UX:** All tiers ship the same composer + two-mode layout. Pro / Research add additional effort levels (e.g., long-horizon research, computer-use) but the input shape is identical. This is what makes Pro feel like a continuous evolution of Core, not a different app.

---

The killer features that wrap the entire substrate philosophy into shippable surfaces. They are listed once here, with status against current code, and pointers into Kimi research depth. **None of them are approved to start coding** — they require deliberation briefs per §10.

### 4.1 Resonance Gate

**What it is.** A single Rust daemon that sits between every information source (LLM token, user input, memory hit, web search, agent action) and every information sink (UI display, memory storage, agent dispatch, tool call). For each unit `x` it computes a **Resonance Signature**:

```
Σ(x) = [τ truth, δ direction, π prime/composite/gap, ρ resonance, κ KAM, η evidence, λ residency]
```

Target: `<100µs` per token on Apple Silicon (CPU does graph ops, ANE does neural components in Research tier).

**Naming.** The Resonance Gate is the user-facing surface of **SCOPE-Rex** — `Epistemos` is the product, `Rex` is the Rust semantic kernel, `SCOPE-Rex` is the full runtime (**S**parse-feature, **C**laim-graph, **O**ntology, **P**roof, **E**xecution). The Gate is one daemon inside Rex; it consumes the claim graph, runs the 5-tier verification ladder, and emits the signature.

**The 5 directional operators (δ component).** Every claim is classified as moving in exactly one of these directions on the claim graph:

- **upward** — generalization, transitive closure
- **downward** — specialization, graph pooling
- **sideways** — peer/community-bounded BFS
- **inward** — refinement, decomposition into parts
- **on-itself** — self-reference, the autopoietic self-loop

**The 9 claim types (π component).** The Resonance Gate's prime/composite/gap classification operates over 9 typed claims, not free-form strings:

`Equation`, `Inequality`, `Causal`, `Definition`, `Empirical`, `CodeInvariant`, `Prime` (in-degree 0), `Composite` (in-degree ≥ 1), `Gap` (unverified or newly proposed).

**Six mathematical pillars under the Gate** — read for depth, do not re-derive in code: **(1) Kleene K3 ternary logic** for τ; **(2) Laplace–Beltrami spectral geometry** on the attention graph for ρ; **(3) Rate-distortion** for λ residency target; **(4) Koopman operator** for δ direction prediction; **(5) Resonance eigenvector / centrality** for ρ scoring; **(6) KAM stability** with Diophantine condition for κ.

**Evidence Supremacy Protocol.** When the η component flags a claim as "edge" (insufficient evidence), the Gate **surrenders** internal model intuition and triggers real-time search. The model is never trusted to verify itself.

**Why it ships.** It is the single feature that makes the substrate's philosophy visible: ternary truth, evidence supremacy, residency governance, and prime/composite ontology become one filter the user can see.

**Tier behavior.**

- **Core:** ships only the τ + π + λ components (truth flag, prime/composite flag, residency target). Computed on CPU. Fully testable, no neural component, no private APIs.
- **Pro:** adds δ (direction) + ρ (resonance) via in-process MLX inference + claim-graph traversal.
- **Research:** adds κ (KAM stability via activation FFT) + η (evidence supremacy with edge-detection trigger). Requires private ANE path for full speed.

**Status.** Not started. Spec lives in Kimi research at `epistemos_resonance_gate.md`. Build only after Halo V1 closes and the Core provenance projection set is merged.

**Canonical code anchors when starting.** The Intent/Effect/Receipt pattern is the right shape but **lives only in the `vigorous-goldberg-3a2d35` worktree today** — donor, not yet merged. Read it at `~/Downloads/Epistemos/.claude/worktrees/vigorous-goldberg-3a2d35/agent_core/src/effect/dispatcher.rs` (IntentDispatcher) and `…/effect/receipt.rs` (ExecutionReceipt). EventStore `AgentProvenanceEvent` rows on main record what the Gate emits today.

### 4.2 Sovereign Gate (Biometric Touch ID on Popups + Footings)

**What it is.** Every confirmation surface in the app — popups, dangerous-action dialogs, permission gates, Settings footers, capability prompts — routes through one biometric gate. The Rust kernel decides *whether* a touch is required; Swift owns *how* it's presented; result flows back through UniFFI. No popup has its own ad-hoc confirm path. Same flow on Magic Keyboard with Touch ID, iPhone-as-key, and Apple Watch unlock.

**Why it ships.** It is the user's "fingerprint to start combos like notes" intuition (verbatim user phrasing). Touch ID is not just app unlock — it is the **key release** for Sovereign-class actions, sealing/unsealing Secure Enclave keys that wrap the Dark Node vault encryption.

**Action-class matrix (lives in Rust kernel, never on the Swift side):**

| Class | Touch needed | Examples |
|---|---|---|
| `Trivial` | never | open note, scroll, search |
| `Reversible` | never | new chat, draft edit, local capture, Quick Capture |
| `Sensitive` | once per 15-min grace, scoped to category | export note, share link, soft delete, OAuth scope grant |
| `Destructive` | every time, no grace, biometric **+** passcode | empty trash, drop vault, revoke key, change tier |
| `Sovereign` | every time + Secure Enclave key release | unwrap Dark Node key, sign attestation, change PolicyProfile, load neural implant (Research) |

**Tier behavior.**

- **Core:** Trivial / Reversible / Sensitive / Destructive classes. Standard `LocalAuthentication.LAContext` with `.deviceOwnerAuthenticationWithBiometrics` (or `.deviceOwnerAuthentication` for destructive). No Secure Enclave key sealing needed.
- **Pro:** adds Sovereign class with Secure Enclave key sealing via `kSecAttrTokenIDSecureEnclave` + `.biometryCurrentSet`. Re-enrolling a fingerprint invalidates sealed keys (intended).
- **Research:** every executive action (load implant, patch weights, enable steering, modify KV cache, load private ANE, execute untrusted) is Sovereign-class. Biometric session has 15-min grace inside the Executive Console only.

**Status.** Core seed work is started and code-closed for the first agent-tool approval path: `Epistemos/Sovereign/SovereignGate.swift` is now the single Swift `LocalAuthentication` entrypoint, `AppBootstrap` owns its lifecycle observer, and `ApprovalModalView` routes the existing agent-tool approval surface through `ChatApprovalSovereignGate`. The Rust action-class matrix seed now exists at `agent_core/src/sovereign/mod.rs` with doctrine-example tests, but generated transport, Rust-to-Swift requirement emission, broader popup migration, transport outcome wiring, and Pro/Research Secure Enclave sealing remain open. Spec depth in Kimi research at `EPISTEMOS_RESEARCH_LANDSLIDE.md` Part I §1.1.

**Canonical code anchors when starting.** Single Swift entrypoint `Epistemos/Sovereign/SovereignGate.swift`; Rust matrix seed `agent_core/src/sovereign/mod.rs` declares action classes, deterministic doctrine intents, `GateRequirement`, and `GateOutcome`. Future transport work emits requirements to Swift and flows outcomes back via UniFFI. Every existing popup/dialog code path is migrated one-by-one through gated PRs (no big bang). MutationEnvelope already has a `sensitivity` field — extend it to drive the gate decision rather than building a parallel matrix.

**Forbidden:** Touch ID prompt fired from anywhere except `SovereignGate.confirm`. Cached approvals that survive lock / sleep / app background. Any popup short-circuiting the gate "because the user just authed."

### 4.3 Freeform Pulse + Residency Rail (paired UI affordance)

**What it is.** Two surfaces that together make the substrate visible while the user types.

- **Freeform Pulse.** Local model drafts as the user types — ghost text suggestions, gated by the Resonance Gate's τ component (only suggestions with τ ≥ 0 surface) and stabilized by debounce. No suggestion ever fires without a prior typing pause threshold, so the user never feels chased.
- **Residency Rail.** A minimal, always-visible rail showing where every artifact in view currently lives (L0 Context Prior → L7 Quarantine), with one-tap promote/demote. The rail is the visible face of the Residency Governor.

**Why they ship together.** Pulse without Rail is autocomplete with no provenance story. Rail without Pulse is Settings buried in a sidebar. Together they give the user: "I can feel the substrate working, and I can see where it puts things."

**Tier behavior.**

- **Core:** Pulse uses MLX-local drafts only; Rail shows L0/L1/L2/L3 (working memory levels). Hidden behind a toggle that defaults off.
- **Pro:** Pulse can route to cloud providers under explicit policy; Rail extends to L4 (compressed Engram) + L5 (cold storage).
- **Research:** Pulse can read activation steering vectors live; Rail extends to L6 (Forbidden tier opt-in) + L7 (Quarantine with audit trail).

**Status.** Pulse and Rail are not started. Halo V1 seed work is now code-closed for protected editor mount, live domain re-query, and visible panel actions, but manual/runtime verification remains open before Pulse should mount. Rail still depends on the Residency Governor module existing — currently only conceptual in Kimi research at `scope_rex_final_architecture.md`.

**Canonical code anchors when starting.** Pulse uses existing `Epistemos/Engine/HaloController.swift` debounce machinery. Rail mounts as a non-blocking inspector view next to (not inside) `ProseEditorView` — protected-path rule applies, never edit `ProseEditor*.swift` for this.

**Halo V1 stack reference (do not re-derive).** *(C6, merged 2026-05-05.)* 6-state FSM (`dormant → watching → encoding → searching → available → open`) + trailing-edge debounce + Model2Vec + usearch + Tantivy + weighted RRF + non-activating NSPanel + explicit latency budgets per the V1 product canon. Implementation lives across `Epistemos/Engine/HaloController.swift`, `HaloEditorBridge.swift`, `ShadowSearchService.swift`. Stack rationale and budget targets are in `docs/_consolidated/00_canonical_authority/ambient_V1_DECISION.md` and `docs/fusion/KIMI_FUSION_REVIEW_2026_04_30.md`.

---

## 5. Tier-Locked Feature Ledger

What ships in each tier. Everything not listed is forbidden in that tier.

### Core (App Store)

- Vault intelligence: Prose editor, graph view, search, Halo / Contextual Shadows V0/V1.
- Substrate spine end-to-end: TypedArtifact → MutationEnvelope → OpLog projection → AgentEvent / GraphEvent durable rows → projections → diagnostics.
- Bounded chat/agent: Apple Foundation Models when available, MLX-Swift local inference, Anthropic / OpenAI / Perplexity raw URLSession providers behind explicit user opt-in.
- App Intents, Spotlight, menu bar capture, security-scoped bookmarks.
- Sovereign Gate (Trivial / Reversible / Sensitive / Destructive classes only).
- Resonance Gate (τ + π + λ components only, CPU-only).

### Pro (Developer ID)

- All Core +
- Hermes subprocess for orchestration (NOT inference).
- MCP tunnels (omega-mcp).
- Claude Code / Codex / Kimi / Gemini CLI tunnels.
- Browser / computer-use tools.
- Docker / devcontainer support.
- Simulation Theater (extracted from `worktree-simulation` per doctrine).
- Deep Deliberation jury.
- Embedded JS runtime (QuickJS / Deno) — requires `cs.allow-jit` + `cs.allow-unsigned-executable-memory`.
- Sovereign Gate full action-class matrix including Sovereign class with Secure Enclave key sealing.
- Resonance Gate δ + ρ components.
- Freeform Pulse (Core + cloud providers under policy) + Residency Rail (L0–L5).

### Research (Developer ID with private framework loading)

- All Pro +
- Direct ANE access via `_ANEClient` loaded through `cs.disable-library-validation` (private framework, not private entitlement).
- MIL compilation, E5 binaries, IOSurface zero-copy I/O.
- KV cache implantation via `MTLBuffer.contents()` UnsafeMutableRawPointer on UMA.
- Activation steering vectors.
- Neural implant loading (per-action Touch ID + passcode).
- Sherry 1.25-bit ternary weight format with Arenas annealing.
- Sparse autoencoder feature visualization.
- Resonance Gate κ + η components (full 7-field signature).
- Freeform Pulse with live activation steering. Residency Rail extends to L6/L7.

---

## 6. Hard Forbidden List (every tier)

- Edit `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`, or graph physics/render internals without an approved protected-path gate. *(Inherited from `BUILDER_EXECUTION_PROMPT_2026_04_30.md`.)*
- Replace Prose. Make Markdown projection canonical. Flatten Documents/Raw Thoughts/Code/Sources/Outputs into "notes". *(Inherited.)*
- Raw-merge any worktree. Pop stashes. Revert unrelated changes. Touch generated `.rlib`, DerivedData, `.xcresult`. *(Inherited.)*
- Use private `com.apple.private.*` entitlements anywhere.
- Use a subprocess for **inference** in any tier. (Subprocess for **orchestration** is allowed in Pro/Research only — Hermes / CLI / MCP / browser / Docker.)
- **Copy hot-path tensors across CPU↔GPU↔ANE.** Apple Silicon UMA + `MTLBuffer.storageModeShared` + IOSurface mean zero copies. Any patch that adds a `memcpy`-equivalent for weights, KV vectors, or activations on the inference hot path is a §2.2 invariant violation.
- **Run Z3 / Lean / Kani on the hot path.** Z3 is 0.43–30 ms; T2 Proptest is 1.4 µs and catches 95%. Hot path runs T0–T2 only.
- **Replace the 5-tier T0–T4 ladder with a single big check.** Each tier has a different timing budget; collapsing them is a category error.
- **Fan inference out across multiple processes.** Single binary, one process. Subprocess is for orchestration only.
- Strip thinking blocks from Anthropic message history when `stop_reason == "tool_use"`.
- Buffer streaming responses. Use `AsyncStream` with `.unbounded`. Use `DispatchQueue.main.sync` in UniFFI callbacks (deadlock).
- Force-unwrap, `try!`, `print()` in production paths.
- Mark items done in `PROGRESS.md` / `AGENT_PROGRESS.md` until verification greps pass.
- Fire a Touch ID prompt from anywhere except `SovereignGate.confirm` once that gate exists.
- Cache biometric approval across app sleep / lock / background. Cross category boundaries with a single grace.
- Spawn user-installed coding CLIs from the **Core** target.
- Put Hermes / Docker / browser-use in **Core**. Hidden cloud calls in any tier.
- Treat Hermes as the graph/Rex authority, or add new Pro/Research cloud/CLI/tool
  routes that bypass the unified gateway/control surface without an explicit
  deliberation gate.
- Use OSFT / PSOFT / coSO with QLoRA — they are not 4-bit compatible. Use QOFT / QDoRA / QPiSSA for production continual learning. (See Annex A.5.)
- Promote a behavior past L3 in the residency hierarchy without T2+ verification and a measurable runtime gain. (See Annex A.3.)
- *(C2, merged 2026-05-05.)* **Silent cloud fallback or escalation.** If a request is about to leave the device, the user sees an explicit opt-in prompt for that specific request OR has previously enabled the provider in Settings with a clear "use this for X" scope. No automatic "I couldn't answer locally, let me try cloud" behavior in any tier. The transition from local → cloud is always a UI event the user can audit.
- *(C3, merged 2026-05-05.)* **BYOK cloud providers enabled by default.** Default state for every cloud provider (Anthropic, OpenAI, Perplexity, etc.) is OFF on a fresh install. The user must explicitly add a key in Settings AND toggle the provider on. No marketing-defaults that pre-enable cloud routing.
- *(C5, merged 2026-05-05.)* **Visual surfaces that imply state the runtime doesn't authoritatively own.** Liquid Wave cannot animate "agent is thinking" if no agent turn is in flight. Simulation Theater cannot show a sub-agent dispatch that didn't emit an `AgentEvent`. Halo cannot show a hit count without a real query result. Visual layers project; they do not invent. (See §2.2 invariant #5.)
- *(C13, merged 2026-05-05.)* **Telemetry capture beyond metadata.** Input-driven telemetry (keystroke timing, modifier states, app activity) is metadata-only. Never content (typed text, note bodies, code, message contents, query strings). Retention bounded; explicit opt-in for any telemetry channel; default-off for cloud-uploaded telemetry. Consent copy reviewed before any new channel ships. (See Annex A.16.)

---

## 7. Build-Order Dependency Graph

What unblocks what. Read top-down — earlier rows must close before later rows start.

```
Core substrate (DONE / mostly DONE)
  ├─ Substrate spine (TypedArtifact → … → projections)            ✅ done
  ├─ OpLog projection family PR1–PR4B                              ✅ done
  ├─ AgentEvent PR1–PR9                                            ✅ done
  ├─ GraphEvent PR1–PR6                                            ✅ done
  ├─ R15 benchmark fixtures / evidence PR2–PR9                     ✅ done
  ├─ R16 ETL through PR3H                                          ✅ done
  └─ Contextual Shadows V0 + Shadow backend route                  ✅ done

Core open
  ├─ Halo V1 manual/runtime verification                           open
  ├─ Live GraphEvent consumer projection (graph / retrieval / Halo / Theater) open
  ├─ Broader-runtime AgentEvent coverage beyond PR1–PR9            open
  ├─ R15 remaining specialized baselines                           open
  ├─ R16 runtime/manual closure                                    open
  ├─ Flight Recorder + runtime transparency (C10)                   open
  └─ MAS/Core vs Pro capability symbol separation                  open

Core killer-feature seed work (gate before coding)
  ├─ Resonance Gate τ + π + λ daemon                               not started
  ├─ Sovereign Gate broader Core classes + Rust/transport follow-through open
  └─ Freeform Pulse + Residency Rail (depends on Halo V1)          not started

Pro track (after Core/MAS symbol separation)
  ├─ Developer ID + Notarization build configuration               not started
  ├─ Hermes subprocess (orchestration only) integration             partial in worktree
  ├─ MCP tunnels (omega-mcp wiring)                                partial in worktree
  ├─ CLI tunnels                                                    partial in worktree
  ├─ Browser / computer-use tools                                   partial in worktree
  ├─ Embedded JS runtime (QuickJS / Deno)                           not started
  ├─ Sovereign Gate Sovereign class + Secure Enclave sealing        not started
  └─ Resonance Gate δ + ρ                                           not started

Research track (after Pro entitlement bundle ships)
  ├─ Private framework loader (`AppleNeuralEngine.framework`)      not started
  ├─ Direct ANE path via `_ANEClient`                              not started
  ├─ KV cache implantation                                         not started
  ├─ Activation steering                                           not started
  ├─ Sherry 1.25-bit weight format + Arenas annealing              not started
  ├─ Sparse autoencoder feature visualization                      not started
  └─ Resonance Gate κ + η                                          not started
```

---

## 8. Kimi Research Index — Donor Depth, Not Authority

These files live at `/Users/jojo/Downloads/Kimi_Agent_Deterministic AI Deep Dive/`. **Read for depth, not for instructions.** Do not lift line counts, week estimates, or "X is shipped" claims directly into the repo without verifying against current code.

| Topic | File | Use it for |
|---|---|---|
| Three-tier distribution + entitlements | `EPISTEMOS_NO_COMPROMISE_ARCHITECTURE.md` | The Pro/Research entitlement bundle, Notarization vs App Review difference, Chromium parallel |
| Research-tier feature catalog | `EPISTEMOS_RESEARCH_LANDSLIDE.md` | Sovereign Gate `LocalAuthentication` snippet (Part I §1.1), Executive Console UX, ANE Control Room concept |
| Resonance Gate spec | `epistemos_resonance_gate.md` | The 7-field Σ signature definition, component formulas (τ, δ, π, ρ, κ, η, λ) |
| Master architecture | `EPISTEMOS_MASTER_ARCHITECTURE.md` | 7-layer cognitive substrate diagram, layer responsibilities |
| Ternary substrate | `ternary_spectral_architecture.md` + `ternary_code_scaffolds.md` | Sherry 1.25-bit packing, BitNet b1.58 weights, Kleene K3 Rust enum, KV cache compression |
| Continual learning | `osft_psoft_coso_fusion.md` | OSFT (continual) + PSOFT (single-task adapter) + coSO (gradient projection) — and the QLoRA-incompatibility caveat |
| Memory hierarchy / residency | `scope_rex_final_architecture.md` | L0–L7 residency levels, 5-tier verification (T0–T4) cost table, Residency Governor pattern |
| ANE feasibility | `EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md` | IOKit/SMC channels for power telemetry, SAE feature interception via `MLCustomLayer` |
| Memory breakthrough | `uasa_memory_breakthrough.md` + `EPISTEMOS_UNIFIED_MEMORY_CONTROL_ROOM.md` | Engram O(1) hash recall, KV implantation via `MTLBuffer.contents()` |
| ACS meta-layer | `acs_meta_layer.md` | Cell → Tissue → Organ → Organism → Ecosystem recursion |
| Current Kimi state | `EPISTEMOS_THIS_IS_WHERE_YOU_ARE.md` | Cross-worktree test counts, what is real vs proposed |

**Verified vs unverified claims (do not trust silently):** Sherry 1.25-bit packing is verified (Huang et al. 2026). BitNet b1.58 is verified (Microsoft, 2B params production). Engram O(1) is partially verified. Birkhoff Polytope mHC is **unverified theoretical conjecture**. The "3059× speedup" figure is **unsupported** — actual Sherry numbers are 10–18% over other ternary baselines on CPU. iPhone 17 Pro Max benchmarks are **projections**, not measurements. Treat the docs accordingly.

---

## 9. Canonical Code Anchors

Where the substrate already lives. New work attaches here.

**Path convention.** Bare paths are relative to `/Users/jojo/Downloads/Epistemos/` (the main checkout, currently on `feature/landing-liquid-wave`). Paths prefixed `worktree:<name>/…` exist **only** in that worktree — they're donor patterns, not on main, and won't open from the main checkout. To read them, navigate to `~/Downloads/Epistemos/.claude/worktrees/<name>/<path>`.

| Concept | Canonical file | Status |
|---|---|---|
| TypedArtifact + MutationEnvelope (Swift) | `Epistemos/Models/MutationEnvelope.swift` | production-canonical; includes `Sensitivity` enum (line 88) + `sensitivity` field (line 293) |
| MutationEnvelope parity test | `EpistemosTests/MutationEnvelopeParityTests.swift` | enforces wire-format byte parity Swift↔Rust |
| MutationEnvelope (Rust) | `agent_core/src/mutations/envelope.rs` | mirror of Swift; `Sensitivity` enum drives redaction policy |
| TextCapturePipeline vertical slice | `Epistemos/Engine/TextCapturePipeline.swift` | production-canonical |
| OpLog (Rust) | `agent_core/src/oplog.rs` | production-canonical on main; BLAKE3 Merkle chain, Swift bridge in place |
| Intent → Effect → Receipt | `worktree:vigorous-goldberg-3a2d35/agent_core/src/effect/{dispatcher,receipt,concept_applier,memory_applier,vault_applier}.rs` | donor pattern only — NOT on main; the right shape for the Resonance Gate's input/output |
| Halo V0 controller | `Epistemos/Engine/HaloController.swift` | production-mounted; debounce machinery for Freeform Pulse |
| Security / threat scanning | `agent_core/src/security.rs` | credential redaction, dangerous-command detection |
| Metal compute / Mamba-2 | `Epistemos/Engine/MetalRuntimeManager.swift` + `Epistemos/Shaders/Mamba2/*.metal` (`direct_conv`, `elementwise_ssm_helpers`, `inter_chunk_scan`, `segsum_stable`) | production-canonical |
| Landing wave (FDTD GPU) | `Epistemos/Shaders/LandingWave.metal` | production-canonical |
| `@Observable` view-model pattern | `Epistemos/KnowledgeFusion/UI/KnowledgeFusionViewModel.swift` | the canonical shape — never legacy `ObservableObject` |
| Hermes prompt builder (local agent) | `Epistemos/LocalAgent/HermesPromptBuilder.swift` | targets the local-agent NousResearch ChatML/XML helper path. `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H2 corrects hermes-parity donor status: `agent_core/src/prompts.rs` currently uses plain markdown prompts, so ChatML is future/local-agent format unless the active runtime path verifies it. |
| MCP protocol (Pro tier) | `omega-mcp/` crate | 131 tests, Pro-tunnel target |
| Shadow search FFI | `epistemos-shadow/` crate | 45 tests, vault search |
| FFI bench harness | `graph-engine/benches/graph_ffi_baselines.rs` | production-canonical on main; criterion + os_signpost baselines |
| Deliberation gate folder | `docs/fusion/deliberation/` | template at `BUILDER_EXECUTION_PROMPT_2026_04_30.md` §"Deliberation Brief Required" |

---

## 10. Operating Rule

For every new slice (Core / Pro / Research):

1. **Read first** — this doctrine, `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, the relevant repo authority docs. Never assume.
2. **Write a deliberation brief** at `docs/fusion/deliberation/<slice>_deliberation_2026_05_01.md` with the existing template. State explicit Core / Pro / Research / Both classification.
3. **Wait for Codex audit + approval** of the brief before any code.
4. **Build only the next approved slice.** Stop at the next gate. Do not stack approvals.
5. **Run focused tests, capture raw logs, report.** No "done" claim without a path-verified user-visible surface OR a passing log path.
6. **Commit per change** (per persistent user feedback in memory: lost work to `git checkout` once; never batch commits).
7. **WRV — the only honest "shipped" claim.** *(C1, merged from `CANON_GAPS_AND_ADDENDA_2026_05_02.md` 2026-05-05.)* Every claim of "done" or "shipped" must satisfy all four:

   - **Wired** — code path exists and compiles in the target tier
   - **Reachable** — at least one user-facing entry point reaches it
   - **Visible** — its state is observable in UI, diagnostics, or audit log
   - **Verified** — at least one test or raw log proves it works

   Files existing is not enough. A subsystem fully implemented but unreached by any UI is not shipped — it is donor code. WRV is enforced at the deliberation-brief layer (`Codex prompt §3.4 report-before-code`); a brief that cannot fill all four for its slice is returned. The 2026-05-05 canon-hardening protocol (`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`) extends WRV to a 6-state pipeline (research → implemented → wired → reachable → visible → verified → released).

---

## Annex A — Architectural Nuance (the depth that didn't fit above)

This annex is named, numbered detail. It is referenced from §2.2, §4.1, §6, §7, and §9 above. Every subsection here has a single tier-impact line so the Codex prompt can audit against it.

### A.1 Naming and crate map

| Name | What it is |
|---|---|
| **Epistemos** | The product — the macOS app users interact with |
| **Rex** | The Rust semantic kernel — deterministic, verified, governed (`agent_core` is becoming Rex; `epistemos-core` is the FFI surface) |
| **SCOPE-Rex** | The full runtime: **S**parse-feature observatory + **C**laim-graph + **O**ntology + **P**roof engine + **E**xecution. The Resonance Gate is the user-visible surface of this |
| **ClaimKernel** | Synonym for Rex's claim-graph + verification subsystem; appears in earlier Kimi docs |
| **Capability Residency Architecture** | The novel design pattern — every behavior is assigned to the safest, cheapest, most reversible residency layer |

Existing crates that map onto this naming: `agent_core` (becoming Rex), `epistemos-core` (FFI / UDL bridge), `epistemos-shadow` (search FFI), `omega-mcp` (MCP protocol — Pro tunnel surface), `graph-engine` (graph database, 2,508 tests), `substrate-core` (foundation types). The naming refactor is doc-only for now — do not rename crates without an explicit slice for it.

### A.2 The 5-tier verification ladder (T0–T4)

Hot path runs T0–T2 only. T3 runs in a background thread with a 100ms timeout. T4 runs as a separate worker, off the user-visible path entirely.

| Tier | Time | Method | What it verifies | Where |
|---|---|---|---|---|
| **T0** | <1 ns | Type system + const generics | Dimensional consistency, type safety | Compile time |
| **T1** | <1 µs | `debug_assert!` + inline checks | Bounds, nulls, simple invariants | Inline |
| **T2** | <1 ms | Property-based testing (Proptest) | 100 random cases, ~1.4µs/test | CI + dev loop |
| **T3** | <100 ms | Kani + Kissat | Memory safety, panic freedom | Background thread |
| **T4** | Background | Z3 / Lean / fuzzing | Theorem proving, exhaustive search | Off-path worker |

**Hard rule:** Z3 simple queries cost ~0.43ms, complex ~30ms. **NEVER on the hot path.** A patch that runs Z3 inline is P0.

**Tier impact:** All tiers honor T0–T2. Pro adds T3 by default. Research enables T4 with full Lean/Z3 verification on demand (Sovereign-class action).

### A.3 The 7-level residency hierarchy (L0–L7)

The Residency Governor (the core invention of SCOPE-Rex) decides where each capability lives, ordered cheapest/safest → most expensive/irreversible.

| L | Name | Reversibility | Cost | Use case |
|---|---|---|---|---|
| **L0** | Context Prior | Instant | ~0 | One-shot behavior, system prompts |
| **L1** | Retrieval Memory | Easy | Low | Frequently accessed facts, user preferences |
| **L2** | Feature Rule | Medium | Low | SAE steering vectors, learned patterns |
| **L3** | Harness Rule | Medium | Low | Tool eligibility, workflow patterns |
| **L4** | GRPO Prior / Engram hash | Hard | Medium | Reinforced behaviors, static knowledge with O(1) recall |
| **L5** | PSOFT / QOFT Adapter | Hard | Medium | Task specialization, style adaptation |
| **L6** | OSFT Identity | Very Hard | High | Core personality, consolidated knowledge (Pro R&D + Research only) |
| **L7** | Quarantine | N/A | N/A | Failed behaviors, unsafe outputs |

**Promotion criteria:** verified at T2+, score above threshold, demonstrated runtime gain.
**Demotion criteria:** accuracy degradation, user override, drift detection.

**Tier impact:** Core ships L0–L3 + L7. Pro adds L4–L5. Research opt-in for L6.

### A.4 ACS — the five-layer recursion

`Cell → Tissue → Organ → Organism → Ecosystem`. Each layer is a distinct *scale* that runs the same Residency Governor pattern at a different timescale. SCOPE-Rex is one Cell. The recursion is structural self-similarity (Stafford Beer's Viable Systems Model + Maturana & Varela's autopoiesis + Noble's biological relativity).

| Layer | Timescale | Mechanism | What it does | Tier |
|---|---|---|---|---|
| **Cell** | ~10⁰ s | One SCOPE-Rex instance (model + memory + tools + verification + governance) | The atomic cognitive unit. One `agent_core` runtime per Cell. | Core+Pro+Research |
| **Tissue** | ~10¹ s | Synchronized Cells via Kuramoto-coupled phase dynamics on Apple Silicon UMA | Specialized roles emerge: Research, Coding, Reasoning, Perception | Pro |
| **Organ** | ~10² s | Tissues coordinated around functional goals (the "Research Organ", the "Code Organ") | Goal-directed teams; differentiated via DSC adapters + PSOFT/QOFT specialization | Pro |
| **Organism** | ~10⁶ s | Homeostatic feedback: senses own state, predicts future needs, reconfigures before failure | Self-regulation; the ACS proper | Research |
| **Ecosystem** | ~10⁹ s | REP mesh + CRDT synchronization + cloud cascade (NeMoCLAW / OpenCLAW) | Multi-device, multi-user, cross-app orchestration | Research |

**Honest scheduling stack** (the biological metaphors are illustrative — at runtime use deterministic schedulers): work-stealing (Rayon/Tokio) ~10–100ns hot path; priority queue 50–100ns warm path; competitive allocation 1–100ms ONLY for agent role selection, not per-task routing. Notch-Delta lateral inhibition is **10¹²× too slow** for actual task routing — biological convergence is 10–1000h vs nanoseconds for a deterministic scheduler.

**Tier impact:** Cell-only in Core. Tissue + Organ in Pro. Organism + Ecosystem are Research only. Multi-agent on M4 Max tops out at ~10–15 concurrent 7B agents via work-stealing.

### A.5 Continual learning — honest stance (correction to earlier Kimi docs)

The earlier Kimi research framed OSFT/PSOFT/coSO as the production stack. **It does not work** with QLoRA 4-bit quantization, which is the production path on 16GB Macs. Production stack is QOFT/QDoRA/QPiSSA. OSFT/PSOFT/coSO live in Pro R&D only and never reach Core.

| Method | QLoRA-compatible | Continual learning | Status |
|---|---|---|---|
| **QOFT (OFTv2)** | ✅ native | ✅ orthogonal prevents forgetting | **Recommended production path** |
| **QDoRA** | ✅ native | ✅ high (decomposition) | **Practical deployments** |
| **QPiSSA** | ✅ convert | ✅ high (principal stable) | **Best accuracy** |
| OSFT | ❌ | ✅ ~20-task capacity | Pro R&D only |
| PSOFT | ❌ | ❌ single-task only despite the name; 16× param efficiency over LoRA | Pro R&D only |
| coSO | ❌ | ✅ no LLM experiments yet | Pro R&D only |

Adapter capacity on a 128GB MacBook is ~3,100 adapters at r=8. Switching latency <1ms from UMA. On 16GB Macs (per user hardware memory), keep concurrent adapter count modest.

**Tier impact:** QOFT in Core/Pro. QDoRA + QPiSSA in Pro. OSFT/PSOFT/coSO research surfaces in Research only.

### A.6 The four memory layers (honest capacity)

Memory is **not** infinite — earlier Kimi claims of literal-infinite-context are unverified. The honest 4-layer hierarchy:

| Layer | Tech | Latency | Capacity | Persistence |
|---|---|---|---|---|
| Working | MLA-compressed KV (Mamba-2 SSM) | <1 ms | 128K context | Session |
| Associative | HDC hypervectors | ~10 µs | ~20 items / 1000 dims | Hours–days |
| Deep | Kuramoto / Hopfield | ~1 ms | Exponential (specialized) | Days–weeks |
| Durable | HCache + KVCrush | <100 ms | **254 brain states on 128GB** | Permanent |

Mamba-2 runtime is already wired in this repo (`Epistemos/Engine/MetalRuntimeManager.swift` + `Epistemos/Shaders/Mamba2/*.metal`); Phase 1A save/load/resume/staleness landed (per project memory). KIVI KV cache is opt-in and currently blocked on MLX metallib runtime.

**Tier impact:** All tiers ship Working + Associative. Pro adds Deep. Research adds Durable HCache + KVCrush.

### A.7 Sovereign Gate — authentication routes

The Sovereign Gate is the only place in the codebase that calls `LocalAuthentication`. It accepts these biometric routes natively (no extra code per route):

- **MacBook Touch ID** (built-in)
- **Magic Keyboard with Touch ID** (Bluetooth/USB-C)
- **iPhone-as-key** (Continuity, requires same iCloud ID + paired)
- **Apple Watch unlock** (taps wrist after biometric session expires; counts as `LAContext.evaluatePolicy` success)

`LAPolicy.deviceOwnerAuthenticationWithBiometrics` accepts all four. `LAPolicy.deviceOwnerAuthentication` adds passcode fallback (used for Destructive class). Re-enrolling a fingerprint invalidates Secure Enclave-sealed keys via `kSecAttrAccessControl` flag `.biometryCurrentSet` — this is intended; do not work around it.

**Grace period:** 15 min, scoped to action **category** (approving export does not unlock delete). Cleared on lock, sleep, app background, kernel mode change, or `PolicyProfile` change. Never crosses tier boundaries.

**Tier impact:** Sensitive + Destructive in Core. Sovereign + Secure Enclave sealing in Pro/Research. Sovereign Gate file location is `Epistemos/Sovereign/SovereignGate.swift` (single entrypoint, never duplicated).

### A.8 Multi-agent orchestration — NeMoCLAW / OpenCLAW

Sub-agents called "claws" each control a specific app or domain. Coordination happens via **resonance-based orchestration** (each claw reports its Σ signature; the orchestrator routes work by direction + KAM stability), explicitly avoiding the self-attribution bias of letting one agent be both producer and grader.

REP mesh + CRDT synchronization make claws horizontally distributable — across processes, devices, or eventually users. This is the Ecosystem layer of ACS (A.4).

**Tier impact:** Single-claw in Core (no orchestration; one agent loop). Multi-claw + REP mesh in Research.

### A.9 KV cache substrate — Symphony OS / KIVI / virtualization

KV virtualization moves the K/V tensors out of model-private allocators into a dedicated namespace that can be paged, snapshotted, implanted, and shared across calls. This is the foundation of KV implantation (research A.10 below).

- Symphony OS pattern: KV cache as a virtualized file system with per-conversation namespace and snapshot/restore semantics.
- KIVI: project's existing partial implementation, opt-in, blocked on MLX metallib runtime (per `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`).
- HCache + KVCrush: 1.93× TTFT reduction vs KV offload, 5.73× vs recomputation. KVCrush gives 4× cache reduction at <1% accuracy loss.

**Tier impact:** Hidden in Core (just a runtime detail). Snapshot/restore exposed in Pro. Implantation + Sovereign-gated in Research.

### A.10 KV implantation + raw memory inspection (Research only)

On Apple Silicon UMA, `MTLBuffer(options: .storageModeShared)` plus `buffer.contents()` gives a direct `UnsafeMutableRawPointer` into bytes the GPU is actively using — no copy, no driver call. This enables:

- Raw memory hex dump of any GPU tensor while the model is running
- Live weight patching (per-action Sovereign Gate required)
- KV cache pre-loading ("implant" knowledge by writing pre-computed K/V vectors)
- Attention mask manipulation
- Activation interception between transformer layers
- Command buffer inspection

What it does **not** enable: ANE silicon internals (still a black box), kernel-level physical memory paging (SIP blocks this), in-place MLX ops (MLX avoids this by design — use raw buffer access to bypass).

**Tier impact:** Research only. Every action listed here is Sovereign-class (biometric + passcode for destructive subset) — see Doctrine §4.2 action-class matrix.

### A.11 ANE direct path (Research only)

`AppleNeuralEngine.framework` is private but loadable via `cs.disable-library-validation` (NOT `com.apple.private`). Path:

1. `dlopen` or `NSBundle` load of `AppleNeuralEngine.framework`
2. Method swizzling / direct message send to `_ANEClient`, `_ANECompiler`, `_ANEInMemoryModelDescriptor`
3. MIL (Machine Learning Intermediate Language) compilation to E5 binaries
4. IOSurface-based zero-copy I/O between GPU and ANE

CoreML is just a convenience layer on top of these. ANE per-core state is not exposed by Apple — best you get is power/frequency telemetry via IOKit/SMC channels (used for the Glass Ball / ANE Control Room visualization in the Research tier Executive Console).

**Tier impact:** Research only. Loading `AppleNeuralEngine.framework` is Sovereign-class.

### A.12 Hermes cloud/tool gateway + prompt format — donor pattern reference

Hermes is the unified Pro/Research external-intelligence control surface for
cloud model orchestration, MCP/web tooling, browser/computer-use,
Docker/devcontainer work, and user-installed coding CLI delegation. This does
not mean every token must flow through one Hermes subprocess: fast in-process
provider paths in Rex / `agent_core` remain valid when a gate approves them.
Hermes is **not** the graph, **not** Rex, and **not** the deterministic
substrate. Rex / `epistemos-core` / local Swift services own the claim graph,
ledger, residency governor, KV/cache state, verification ladder, and
mutation/event logs.

Direct CLIs are tools behind the gateway/control surface, not parallel app
architectures. New Pro/Research cloud/tool surfaces should start from that
gateway decision unless a deliberation gate explicitly approves a narrower
legacy/provider path. If a Hermes subprocess adapter is unavailable, the
Pro/Research feature degrades or falls back only through a gated in-process
provider path; do not pierce the Core/MAS boundary with a direct subprocess
fallback.

Cloud Hermes gateway and local Hermes-family model prompting are different
things. Cloud providers require network. The local Hermes prompt format can be
used offline when the corresponding local model is installed.

When wiring local-agent tool-calling under Hermes-3 / Hermes-Function-Calling: use the NousResearch ChatML XML format (`<tools>…</tools>`, `<tool_call>…</tool_call>`, `<tool_response>…</tool_response>`) only for the path that actually targets that grammar. Reference repo: `https://github.com/NousResearch/Hermes-Function-Calling` (per user memory). `Epistemos/LocalAgent/HermesPromptBuilder.swift` targets this helper shape, but `MASTER_RESEARCH_INDEX_2026_05_02.md` §0 H2 verified that the hermes-parity donor `agent_core/src/prompts.rs` currently uses plain markdown prompts. Do not rewrite an active markdown prompt path to ChatML without a route-specific gate and tests.

**Tier impact:** Pro/Research for the Hermes subprocess adapter
(orchestration only). Rex / `agent_core` can own gated in-process provider
paths. Local Hermes-family prompt formatting may be Core-safe when it targets
in-process local inference. Never put Hermes subprocess, MCP, Docker,
browser/computer-use, or user-installed coding CLIs in Core.

### A.13 Knowledge Sieve + Gap Winner Rule (graph mechanics)

For any retrieval, the claim DAG ranks sources by **dependency depth**: a Prime claim with high in-degree (many composites depend on it) outranks a peripheral Composite. The **Knowledge Sieve** constructs the graph by progressively eliminating composites; the **Gap Winner Rule** chooses among Gap candidates the one with the highest projected resolution leverage. Engram (L4) candidates are Prime claims with high divisor count — static, O(1) recall.

**Tier impact:** Mechanism is Core (the graph is local). The full gap-winner ranking with eigen-centrality is Pro.

### A.14 VRM — Verified Research Mode

VRM is a system-call-style entrypoint that initializes a sandboxed reasoning session with the full T0–T4 verification pipeline active and **external verifiers required** (Z3 for math, code execution for invariants, calculator for numerics). Inside VRM, the model is never trusted to verify itself. This is the canonical mode for the Resonance Gate's Evidence Supremacy Protocol when η flags an "edge" claim.

**Tier impact:** T0–T2 VRM in Core. T3+T4 VRM in Pro/Research.

### A.15 Flight Recorder + runtime transparency *(C10, merged 2026-05-05)*

User-facing trust visibility. Beyond OpLog projection (which is structural) — the Flight Recorder is the user-facing diagnostic surface that lets the user see and export what the system is doing.

**Three components:**

1. **Structured event log** — already exists as OpLog + `agent_events` + `graph_events` tables.
2. **Exportable diagnostic bundle** — Settings → Export Diagnostics. Bundles last N hours of OpLog + AgentEvent + GraphEvent + crash logs + benchmark JSON results. User-controlled scope (anonymize / include vault content / metadata-only).
3. **Live runtime status surface** — visible state of agent loop (idle / thinking / tool-running / waiting-on-approval), MLX inference state (loaded / loading / evicting / refused), FFI call counts and recent failures.

**Tier impact:** All tiers ship #1 and #2. #3 visible in Pro / Research; in Core it's behind a hidden Settings toggle (defaults off; trust-builder for users who want it).

### A.16 Telemetry policy *(C13, merged 2026-05-05)*

**Captured (allowed):** event timestamps, modifier-key states, anonymized event types (e.g., "agent_turn_completed"), failure categories (e.g., "tool_timeout"), aggregate latency histograms, feature flag enablement, OS version, app version, hardware class.

**Forbidden:** typed text content, note body text, code content, message bodies, file contents, file paths (paths can leak private structure), search query strings, vault content, screenshots, AX tree contents, microphone audio.

**Retention:** local-only by default. Bounded ring buffer (last 7 days for runtime telemetry; last 30 days for crash logs). Cloud upload requires explicit per-channel opt-in.

**Consent:** any new telemetry channel requires (a) Settings toggle defaulting OFF for cloud upload; (b) clear copy describing what is captured and why; (c) one-click "delete all telemetry" affordance.

**Tier impact:** identical across tiers. Pro and Research can layer additional opt-in channels but the metadata-only / no-content rule is invariant.

---

## Annex B — Quick reference: what each tier actually gets

If a builder asks "is this slice Core-shippable?" point them here.

**Core gets:** Substrate spine (DONE), Halo V0 (DONE), Halo V1 (open), Resonance Gate τ+π+λ on CPU, Sovereign Gate Sensitive+Destructive classes, Mamba-2 working memory + KIVI KV when unblocked, MLX-Swift inference, Apple Foundation Models, App Intents, security-scoped bookmarks, T0–T2 verification ladder, L0–L3 + L7 residency, single-claw agent, QOFT continual learning. All public Apple APIs only.

**Pro gets:** Everything Core, plus: Hermes subprocess (orchestration only), MCP tunnels, CLI tunnels (Claude Code / Codex / Kimi / Gemini), browser/computer-use, Docker/devcontainer, Simulation Theater, Deep Deliberation jury, embedded JS runtime (QuickJS/Deno), Sovereign Gate Sovereign class + Secure Enclave sealing, Resonance Gate δ+ρ, T3 verification, L4–L5 residency (Engram + adapters), Tissue + Organ in ACS, full QOFT/QDoRA/QPiSSA stack, OSFT R&D surfaces, KV snapshot/restore, eigen-centrality ranking. Built with `cs.allow-jit` + `cs.allow-unsigned-executable-memory` + `cs.disable-library-validation` + `automation.apple-events`.

**Research gets:** Everything Pro, plus: direct ANE via `_ANEClient` / MIL / E5 / IOSurface, KV cache implantation via `MTLBuffer.contents()`, activation steering, neural implant loading (Sovereign-class), Sherry 1.25-bit ternary weights + Arenas annealing, sparse autoencoder feature visualization (the "Glass Ball"), Resonance Gate κ+η, T4 verification (Z3/Lean), L6 residency (Forbidden tier opt-in), Organism + Ecosystem in ACS (multi-claw + REP mesh + CRDT), Symphony OS KV virtualization with implant, ANE Control Room with IOKit/SMC telemetry, raw-memory inspector, weight surgery. Same entitlements as Pro plus dynamic loading of private (not-private-entitlement) frameworks.

---

## 11. Bottom Line

The April 30 fusion canon is correct. This doctrine adds three deltas:

1. **Three tiers ship in parallel**, not sequentially. Core to App Store, Pro and Research to Developer ID + Notarization, one binary, three feature flags.
2. **Three killer features** (Resonance Gate, Sovereign Gate, Freeform Pulse + Residency Rail) wrap the philosophy into shippable surfaces — but each one starts with a deliberation brief, not code.
3. **Touch ID gates every popup and footing through one Sovereign Gate**, never ad-hoc per dialog. The action-class matrix lives in the Rust kernel.

Everything else — protected paths, the substrate spine, the audit ladder, the Kimi-as-donor stance, the worktree salvage rule — is unchanged. This doctrine routes back into the existing canon for those.

The next builder action is **not implementation.** It is a deliberation brief for whichever Core open item is next: Halo V1 editor mount, live GraphEvent consumer projection, MAS/Core vs Pro symbol separation, or Sovereign Gate Core action classes.
