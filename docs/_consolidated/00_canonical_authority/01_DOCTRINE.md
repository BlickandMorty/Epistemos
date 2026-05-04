# 01 — Doctrine: The Fifth Position

**Authority:** This document is subordinate to `docs/architecture/PLAN_V2.md`. It
extends PLAN_V2 with operational rulings on the four-architect synthesis (A/B/C/D),
not by replacing PLAN_V2's principles.

**Status:** Binding for all execution. Disagreements with this doctrine must be
surfaced as STOP-and-surface events (per `00_AUTHORITY_AND_ANTI_DRIFT.md §5`), not
silently overridden.

---

## 0. Executive Verdict (3 sentences, no hedging)

**Epistemos is a provenance-first cognitive substrate where the moat is verifiable
cognition — durable, replayable, retraction-aware records of how thought was formed
— and where commodity LLMs are interchangeable engines plugged into a non-commodity
graph.** The hot path streams `AgentEvent`s for live UI; the cold path persists
`MutationEnvelope`s for durable state, and these two planes are kept distinct on
purpose because conflating them either makes the UI slow or loses the audit trail.
The novel architectural primitive that makes this durable is **retraction
propagation**: when a Claim's evidence is invalidated, every dependent inference is
walked and marked `AT_RISK` or `RETRACTED`, forcing the system to surface — never
silently keep — what is no longer trustworthy.

---

## 1. The Four Planes

Epistemos is layered into four planes. Each owns specific concerns. Crossing a plane
boundary requires a typed contract.

```
┌─────────────────────────────────────────────────────────────┐
│  RENDER PLANE                                               │
│  SwiftUI views, Tiptap WKWebView editor, Metal graph.       │
│  Owns: pixels, gestures, animations.                        │
│  Subscribes to: AgentEvent stream (hot), GRDB notifications │
│  (warm), MutationEnvelope replay (cold).                    │
│  Does NOT own: any source of truth.                         │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ AgentEvent (hot) + GRDB observe (warm)
                            │
┌─────────────────────────────────────────────────────────────┐
│  FACULTY & PROVIDER PLANE                                   │
│  Provider matrix (Claude, Codex, Gemini, Hermes, local      │
│  Qwen, AFM). Faculties expose graph verbs to providers via  │
│  MCP. The Hermes faculty is one provider among many — it    │
│  gets dedicated UX, NOT architectural privilege.            │
│  Owns: provider sessions, tool dispatch, capability gating. │
│  Emits: AgentEvent (hot), proposed MutationEnvelope (cold). │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ proposed MutationEnvelope
                            │
┌─────────────────────────────────────────────────────────────┐
│  PROVENANCE PLANE                                           │
│  ClaimLedger, evidence references, audit findings,          │
│  retraction graph, ReplayBundle export.                     │
│  Owns: the W3C PROV-DM-shaped graph of cognition.           │
│  Validates: every MutationEnvelope before commit.           │
│  Enforces: retraction propagation (the novel primitive).    │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ validated MutationEnvelope
                            │
┌─────────────────────────────────────────────────────────────┐
│  SUBSTRATE PLANE                                            │
│  GRDB tables (ULID-keyed), .epdoc canonical bodies,         │
│  ProseMirror JSON, FTS5 search, tantivy BM25 + usearch HNSW │
│  + RRF fusion. Append-only OpLog (W9.27, gated).            │
│  Owns: durable state. Single source of truth.               │
│  Exposes: the seven graph verbs (read-only + commit).       │
└─────────────────────────────────────────────────────────────┘
```

**The crossing rule:** higher planes cannot mutate lower planes directly. Higher
planes propose; lower planes validate and commit; lower planes notify.

---

## 2. The Five Tensions, Ruled

The four prior architects (A — Agent OS / AgentEvent bloodstream; B — Provenance
not generation; C — Verifiable cognition is the moat; D — Sandbox ladder + native
speed) disagreed on five questions. Here are the rulings.

### 2.1 Tension: Event bus vs MutationEnvelope — which is the source of truth?

**Ruling:** **Both, at different planes.** The `AgentEvent` stream is the hot-path
source for UI subscription. The `MutationEnvelope` is the cold-path source for
durable state. They are not interchangeable and are not redundant.

**Justification:** The brain analogy is exact. Reflexes (events) and memory
consolidation (envelopes) operate on different timescales and serve different
functions. Conflating them either:
- Makes the UI slow (envelope-only — every UI tick goes through validation +
  persistence).
- Loses the audit trail (events-only — no durable record of what happened).

**Operational contract:** Every committed `MutationEnvelope` MUST emit corresponding
`AgentEvent`s. `AgentEvent`s MAY exist without envelopes (read-only, ephemeral —
e.g., "thinking…" indicator, search progress). The reverse is forbidden: a
`MutationEnvelope` that commits without emitting events is a violation of the
no-silent-behavior rule.

### 2.2 Tension: Hermes — faculty (privileged) or provider (equal)?

**Ruling:** **Provider, not faculty.** Hermes is one engine among many. It is
interchangeable with Claude, Codex, Gemini, local Qwen, and Apple Foundation Models
at the architecture level. It receives dedicated UX affordances (a discoverable
landing surface, a labeled provider entry), but no architectural privilege.

**Justification:** Per Architect C and PLAN_V2: models commoditize, the substrate
does not. Privileging Hermes at the architecture level couples Epistemos to a single
upstream that may not exist in three years. The "Hermes faculty" framing also
contradicts the open-standard goal — third-party agents must be able to plug in via
the same surface Hermes uses, or the standard isn't a standard.

**Operational contract:** The Hermes provider implements the same trait (`Provider`
in Rust, `Provider` protocol in Swift) as every other provider. Hermes-specific UX
lives in `Epistemos/Views/Faculty/HermesLanding*` and similar — visual privilege only,
not architectural privilege. The MCP graph verbs are the contract; Hermes does not
get private graph access.

### 2.3 Tension: Fallback inspector for unknown schemas — allowed or forbidden?

**Ruling:** **Forbidden.** Unknown schemas are validation errors. The A2UI catalog
is closed (~25 components, all schemars-derived). Anything else is rejected and
surfaces as an audit finding.

**Justification:** PLAN_V2 §3.4: "no silent fallback." A fallback inspector is a
silent fallback dressed in degraded UI. It also corrodes the integrity of the
provenance plane — a Claim rendered through a generic inspector is a Claim the user
cannot reason about structurally. Closed catalog with strict validation upholds the
doctrine. The cost (some agent emissions don't render) is mitigated by shipping a
generous catalog covering ≥95% of agent emissions.

**Operational contract:** The catalog lives in `Epistemos/A2UI/Catalog.swift` (or
equivalent). New components require a doctrine update — they are not added by
agents in passing. Validation runs on every emission and emits a typed audit
finding (`A2UIValidationFailure`) on miss.

### 2.4 Tension: First slice — horizontal pipeline first or vertical end-to-end first?

**Ruling:** **Vertical first.** Build one end-to-end slice that proves the spine
works (Run → MutationEnvelope → AgentEvent → NoteCard render → ReplayBundle export).
Then horizontalize.

**Justification:** A horizontal pipeline you can't render is unobservable; correctness
cannot be confirmed. A vertical slice that ships with one render path proves
correctness in production and gives a working demo for the Hermes hackathon path
(per `final/Building Epistemos x Hermes Hackathon.txt`). After the slice, expand
horizontally with confidence and reusable contracts.

**Operational contract:** Phase 1 in `04_PHASES.md` codifies this. The first slice
is the W9.25 (grammar masking) → W9.30 (KIVI) → W9.21 (Honest FFI minimum) chain
that delivers one provable improvement to one user-visible surface. Horizontal items
(W9.6 cost dashboard, W9.8 approval modal) follow once the vertical slice is green.

### 2.5 Tension: Cognition layer composition — five composable features or one shared layer?

**Ruling:** **One layer with five projections.** The ClaimLedger is the substrate.
Claims, evidence, audit findings, retractions, and confidence weights are projections
from the ledger. No composable features that each separately implement a piece.

**Justification:** Provenance is the moat. Splitting it splits the moat. Five
independent features means five places to forget about retraction propagation, five
places to drift on schema, five places to skip the audit log on a bad day. One layer
with five projections has a single integrity invariant: every projection reads from
the ledger; no projection writes outside the ledger's commit path.

**Operational contract:** The ledger lives in `agent_core/src/provenance/ledger.rs`.
Projections are read-only views (Rust trait `LedgerProjection`) implemented by typed
view structs. Mutations go through the ledger's `commit_envelope(env)` method — which
runs validation, retraction propagation, and event emission atomically.

---

## 3. The Novel Architectural Primitive: Retraction Propagation

**None of the four prior architects named retraction propagation as a graph-level
primitive that walks dependencies and marks descendants.** Architect A had
`AgentEvent`s but not retraction. Architect B had `ClaimLedger` but no propagation.
Architect C had verifiable cognition but no active propagation mechanism. Architect
D was scoped to sandbox.

This is the doctrine's contribution.

### 3.1 Definition

When a `Claim` or `Evidence` node in the ClaimLedger is mutated or invalidated, the
substrate walks its descendant Claims (those that cited it as evidence or as a
dependency Claim) and marks each one with one of:

| Status | Trigger | UI behavior |
|---|---|---|
| `RETRACTED` | A directly cited Claim was retracted, or all evidence references resolved to deleted/withdrawn artifacts. | Strikethrough in UI; counts in "what is no longer true" digest. |
| `AT_RISK` | An indirectly cited Claim was retracted (one or more hops); OR a contradicting Claim of higher confidence was committed. | Yellow flag; user prompted on next interaction. |
| `NEEDS_REVALIDATION` | A non-deterministic dependency (e.g., a web fetch result) is older than the policy threshold. | Banner in the rendering view; user can re-run derivation. |

### 3.2 Why this is the keystone

A static audit trail can be ignored. A retraction-propagating substrate **forces**
the system to surface when a previously-trusted inference is no longer trustworthy.
This is the difference between "we logged it" and "we know what is currently true."

It is also what makes the open Provenance Standard meaningful — third-party agents
can emit `MutationEnvelope`s, but the integrity of the resulting graph depends on
retraction propagation being a guaranteed substrate property, not an optional add-on.
Otherwise the standard is just a logging format.

### 3.3 Operational contract

- Every `Claim` carries a `dependencies: Vec<ClaimId>` and `evidence: Vec<EvidenceRef>`.
- The ledger's `commit_envelope()` runs retraction propagation as part of commit, in
  the same transaction. Propagation is not eventual. There is no eventual consistency.
- Cycles in the dependency DAG are forbidden by ledger validation. Self-reference is
  also forbidden.
- Propagation depth is bounded by policy (default: 16 hops). Beyond that, descendants
  are marked `NEEDS_REVALIDATION` rather than walked further. This prevents
  combinatorial cost on degenerate graphs.
- Propagation is observable: each propagation emits a typed `AgentEvent`
  (`RetractionPropagated { from, to, depth, status }`) so the UI can show what just
  happened. No silent propagation.

### 3.4 Failure modes mitigated

| Without retraction propagation | With it |
|---|---|
| User trusts a Claim they shouldn't (the supporting evidence was deleted last month). | UI surfaces `AT_RISK`; user is forced to revalidate. |
| A bad provider emits poisonous Claims; cleanup requires manual database surgery. | Retract the root; descendants are walked automatically. |
| The graph drifts from "what was true" to "what is true" silently. | Drift surfaces in the audit log and the daily briefing. |

---

## 4. The Hardware Reality (6 GB realtime budget)

**Floor:** 16 GB Mac, ~6 GB available to the Epistemos process at runtime.

**Implications, codified:**

| Component | Steady-state budget | Notes |
|---|---|---|
| Local 7B 4-bit weights (Qwen3.5 / Hermes-3) | ~3.5 GB | Eviction-on-load mandatory. One model at a time. |
| KV cache (FP16, 8K context) | ~448 MB | Acceptable for short prompts. |
| KV cache (KIVI 2-bit, 8K) | ~58 MB | Required for >8K context. |
| KV cache (KIVI 2-bit, 32K) | ~232 MB | Stretch on 16 GB; comfortable on 18 GB. |
| Hermes Python subprocess (Pro only) | 200–400 MB | Pro path; counts against the 6 GB. |
| GRDB connection + caches | ~50 MB | |
| Tantivy index | ~30 MB / 1k notes | Linear in vault size. |
| usearch HNSW index | ~20 MB / 10k vectors | At 768 dim. |
| SwiftUI + Metal frame buffers | ~150 MB | Steady-state. |
| Tiptap WKWebView | ~80 MB | One per open editor. |

**Doctrine-level rule:** any feature whose steady-state cost exceeds **50 MB** must
declare its budget in `03_EXECUTION_MAP.md` for that item, and must hook
`DispatchSourceMemoryPressure` to yield within 100 ms of `.warning`.

**MAS path constraint:** sandboxed App Store build cannot spawn Python subprocesses
(forbids Hermes orchestration in MAS), cannot run Bollard/Docker (Tier C sandbox
forbidden), and must respect security-scoped bookmarks for vault access. See
`02_BUILD_MATRIX.md` for the full feature gating.

---

## 5. The Open Provenance Standard (the moat-building move, maximum ambition)

The strategy is to ship the standard as a **separate, open, fully-featured ecosystem**
alongside the closed native app. Not a documentation page — a working set of crates,
binaries, and reference implementations that any agent author can adopt today. This
is the durable moat: when the standard becomes the default replay/audit format for
agentic work, the native app sits at the center of the ecosystem regardless of which
LLM is currently winning.

### 5.1 What ships in the open standard

A new top-level project — `epistemos-provenance-standard` — published openly
(Apache 2.0). Five components:

1. **`epistemos-provenance` Rust crate.** Schemars-derived JSON Schema for every
   wire type: `MutationEnvelope`, `AgentEvent`, `Claim`, `Evidence`, `AuditFinding`,
   `ProviderRun`, `RouterDecision`, `ToolCall`, `Approval`, `Artifact`, `ReplayBundle`,
   `EpistemosManifest`. Includes the ledger-validation library (cycle detection,
   retraction propagation, dependency walking).
2. **`epistemos-provider` Rust crate.** The `Provider` trait + helper macros that
   third-party agent authors implement to emit Epistemos-compatible runs.
3. **`epistemos-trace` CLI binary.** Single tool with four verbs:
   - `verify <bundle.zip>` — schema-validate every event/envelope; fails on any
     unknown variant.
   - `replay <bundle.zip>` — re-runs the bundle's deterministic operations and asserts
     byte-equivalent reconstruction of the resulting graph hash.
   - `lint <bundle.zip>` — retraction integrity (no orphan retractions), dependency
     cycle detection, dangling evidence references, schema-version-skew warnings.
   - `diff <a.zip> <b.zip>` — semantic diff over the graph deltas.
4. **`epistemos-conformance` test suite.** A directory of fixtures + a runner. Any
   provider implementation runs the suite and prints a conformance score. A passing
   run earns a versioned badge.
5. **Reference provider implementations**, each their own crate, each runnable
   standalone:
   - `epistemos-provider-hermes` (Hermes ACP) — primary, drives the hackathon demo.
   - `epistemos-provider-claude-code` (Claude Code stream-json subprocess wrapper).
   - `epistemos-provider-codex` (Codex `--json` subprocess wrapper).
   - `epistemos-provider-gemini` (Gemini CLI stream wrapper).
   - `epistemos-provider-openhands` (OpenHands event stream wrapper).
   - `epistemos-provider-claude-api` (Anthropic HTTP, raw URLSession-equivalent in
     Rust via `reqwest`).

### 5.2 The ReplayBundle format (specified, not aspirational)

A `.epbundle` is a zip archive containing:

```
bundle.epbundle/
├── manifest.json           # Schema versions, agent ID, run ID, timestamps
├── events.jsonl            # Chronological AgentEvent stream (line-delimited JSON)
├── envelopes.jsonl         # Chronological MutationEnvelope stream
├── claims/                 # One canonical JSON per ClaimId
│   ├── 01HW...A.json
│   └── ...
├── evidence/               # Referenced artifacts (or symlinks if external)
│   └── ...
├── retractions.jsonl       # Append-only retraction log (every status change)
└── replay-policy.json      # What's deterministic vs. wall-clock-dependent
```

**Byte-equivalence guarantee:** running `epistemos-trace replay <bundle>` on any
two machines must produce graph state with the same `blake3(canonical-form)` hash,
provided the bundle's `replay-policy.json` declares all non-determinism upfront
(e.g., "this run depended on `web_fetch(url)` at time T; replays substitute the
captured response from `evidence/<hash>.bin`").

This is non-trivial. It is also the keystone: a verifiable replay is the difference
between "I have logs" and "I can prove what happened."

### 5.3 The Rust `Provider` trait (sketch — verify before commit)

The exact signatures must be verified against `agent_core/src/providers/mod.rs`
before this is treated as canonical. This is the shape:

```rust
// DRAFT — verify file path and method signatures against the live codebase
// before merging. See agent_core/src/providers/mod.rs.

pub trait Provider: Send + Sync {
    fn id(&self) -> ProviderId;
    fn capabilities(&self) -> Capabilities;

    /// Invoke the provider and stream events. The provider is responsible for
    /// emitting AgentEvents on the `out` channel as work progresses, and must
    /// return a ProposedEnvelope on success — the envelope is *not yet committed*;
    /// it must pass Provenance Plane validation before it lands in the substrate.
    fn invoke(
        &self,
        request: ProviderRequest,
        ctx: ProviderContext,
        out: mpsc::Sender<AgentEvent>,
    ) -> impl Future<Output = Result<ProposedEnvelope, ProviderError>> + Send;

    /// Cancel must propagate to the provider's underlying runtime within 100ms.
    /// For subprocess-backed providers, this means SIGTERM → grace → SIGKILL.
    fn cancel(&self, run_id: RunId);

    /// Conformance test entry point. Every provider implementation must pass
    /// the standard's conformance suite to earn the badge.
    fn conformance_self_test(&self) -> ConformanceReport { /* default: run suite */ }
}
```

A `ProposedEnvelope` is the third-party agent's output, awaiting validation by the
Provenance Plane (cycle check, retraction propagation, schema validation). The
substrate does not commit unvalidated envelopes. This is non-negotiable.

### 5.4 Pattern alignment (why this works)

- **Tailwind / shadcn-ui:** open utilities + components, proprietary product wins
  because of the ecosystem. The standard makes Epistemos-compatible agents trivial
  to build; the value compounds at the runtime.
- **Markdown / Bear:** open format, proprietary editor. Markdown's universality made
  Bear matter. The Provenance Standard intends the same trajectory.
- **OpenAPI / Postman:** open spec, proprietary tooling. The spec is industry
  default; the tools earn revenue.
- **WireGuard / Tailscale:** open protocol, proprietary deployment. Same shape.

### 5.5 Adoption=0 fallback (the bet that doesn't depend on anyone else)

Even if no third party ever implements the trait, the standard still wins for Jojo's
own build:

- Internal discipline: every agent emission is schema-validated; every Claim has a
  citable origin; every replay is byte-equivalent.
- Forced coherence: the standard's existence means Epistemos's own internal types
  cannot drift without bumping the public schema version (a costly, visible event).
- Faster onboarding for future engineers: the spec is the documentation.

Adoption is upside. The bet does not depend on it.

### 5.6 Hackathon launch strategy

The Hermes hackathon submission (April 25 → EOD May 4, 2026, $25K Nous Research ×
Kimi/Moonshot) is the launch event. The native app demo opens with a Hermes-driven
agent run that emits a `ReplayBundle`, validated live by `epistemos-trace verify`,
replayed byte-equivalent on stage. The standard repo goes public the same day. The
conformance suite ships with at least the Hermes reference implementation passing
100%. Other agent authors discovering the spec post-hackathon find a working trail
to follow.

### 5.7 What does NOT ship in the open standard

- The native macOS app (Swift, Metal, GRDB integration, Tiptap chrome, Halo).
- The MLX inference integration and KV quantization (W9.30 KIVI, W9.10 TurboQuant).
- The graph rendering pipeline.
- The Pro feature set (shell exec, Bollard, AXorcist computer use, iMessage).
- Any code that depends on Apple-only frameworks.

The split is: **substrate format and validation = open; runtime, rendering, and
platform integration = closed.**

---

## 6. The Thirteen Non-Negotiables

These are the hard nos. Every one is defended in one sentence. Violating any of
these is a STOP-and-surface trigger per `00_AUTHORITY_AND_ANTI_DRIFT.md §5`.

1. **No silent behavior.** PLAN_V2 §3.4. Everything important surfaces in telemetry.
2. **No subprocess inference.** All inference is in-process via Rust FFI or MLX-Swift.
   Hermes subprocess (Pro only) is for orchestration, not inference.
3. **No fake features.** Real provider APIs, verified against current docs. No
   stubs that pretend to work.
4. **No fallback inspector.** Closed A2UI catalog. Unknown schemas are validation
   errors, not degraded renders.
5. **No silent fallback.** If Provider A fails and Provider B is invoked, the user
   sees it happen.
6. **No `AnyView` in render hot paths.** Typed view-builder enums or specific view
   types only. (Per Architect D's structural-identity concern; see W9.15 in
   `03_EXECUTION_MAP.md`.)
7. **No editing PLAN_V2.** It is the architectural authority. Disagreements surface;
   PLAN_V2 changes are user-driven, not agent-driven.
8. **No hidden CoT reconstruction.** Thinking blocks are preserved verbatim per
   provider rules. When `stop_reason == "tool_use"`, the entire content array passes
   back including thinking blocks + signatures.
9. **No MAS sandbox compromises in Pro paths.** Pro features that need full
   capabilities don't apologize for them; they ship in Pro and don't degrade Pro
   to satisfy MAS.
10. **No retraction skipping.** Every Claim invalidation propagates. There is no
    "fast path" that skips propagation.
11. **No UnifFI callback `DispatchQueue.main.sync`.** Always `.async`.
12. **No API keys in `UserDefaults`.** Keychain only.
13. **No marking items done before verification.** The greps must pass first.
14. **No orphaned scaffolding.** Every new feature must be Wired (called from a
    production code path), Reachable (the user can trigger it without debug knobs),
    and Visible (the user can SEE it is active). Code that is written but unwired,
    unreachable, or invisible is indistinguishable from no feature at all and is
    forbidden. See `00_AUTHORITY_AND_ANTI_DRIFT.md §4.7` for the WRV gate.

---

## 7. The Build Order (high-level — full version in `04_PHASES.md`)

- **Phase 0 (1 week, P0):** Ship the existing app. `A+_RELEASE_ROADMAP.md` items.
  ~50 LOC across 7 files. Bundle <200 MB. ShipGate flipped. MOHAWK excluded.
- **Phase 1 (2 weeks):** Vertical slice. R14 (UniFFI 0.29.5 + Sendable patches),
  W9.25 (grammar masking — package link only), W9.30 (KIVI as opt-in flag with
  perplexity regression test). All Bucket A items per the dossier. Doctrine-aligned
  because this is where the hot/cold split, the no-silent-behavior surface, and the
  retraction primitive get their foothold.
- **Phase 2 (3 weeks):** Horizontal expansion. W9.8 approval modal (gates the
  approval contract — mandatory for both MAS and Pro), W9.6 cost dashboard +
  budget gate (gates Pro), W9.23 bit-packed circuit breaker (hot-path latency).
- **Phase 3 (gated):** W9.21 → W9.22 (Honest FFI → Typestate Islands). Only if
  shipping is delayed for other reasons. 4 PRs over 2 weeks. Real engineering,
  not polish.
- **Phase 4 (deferred):** W9.10 / W9.11 / W9.12 / W9.14 / W9.15 / W9.24 / W9.26 /
  W9.27 / W9.28 / R16. Revisit only after Phase 0–2 ships to real users.

---

## 8. Doctrine vs. the 21-item dossier — reconciliation summary

| Dossier item | Survives doctrine? | Notes |
|---|---|---|
| R14 UniFFI bump | Yes, revised | Reframe as hygiene + Sendable, not the rebuild-perf win the dossier oversells. |
| R15 Benchmark harness | Yes | Required for Phase 1 verification gates. |
| R16 ETL crawler | Yes, gated | Must respect 6 GB budget; AFM sidecars must be xattr-marked + UI-distinguished. Phase 4. |
| W9.6 Cost dashboard | Yes | Required for Pro approval contract. |
| W9.7 Vault selector | Yes | Phase 2+. UI-only, low risk. |
| W9.8 Approval modal | Yes | **Required for both MAS and Pro.** Gates the approval contract. |
| W9.10 TurboQuant | Deferred | Pick KIVI OR TurboQuant, not both. Doctrine: KIVI first via opt-in flag, TurboQuant only if KIVI proves insufficient. |
| W9.11 Personalized embeddings | Deferred | High value but eval methodology nontrivial. Phase 4. |
| W9.12 Orphan rediscovery | Deferred | Needs OpLog (W9.27). |
| W9.13 Daily notes + FSRS | Yes | Phase 2+. |
| W9.14 Block references | Deferred | Needs rope (W9.26). Phase 4. |
| W9.15 Routing macro | Aligned with doctrine | Embodies "no AnyView" non-negotiable. Phase 3+ if rendering perf demands it. |
| W9.21 Honest FFI | Yes | Phase 3. Foundation for typestate. |
| W9.22 Typestate Islands | Yes | After W9.21. |
| W9.23 Bit-packed breaker | Yes | Phase 2. |
| W9.24 Metal zero-copy | Deferred | Measure first; UMA may make it a no-op gain. |
| W9.25 Grammar masking | Yes | **Phase 1.** Lowest-risk Bucket A item. |
| W9.26 B-tree rope | Deferred | Phase 4. Needed for W9.14. |
| W9.27 OpLog | Deferred | Phase 4. Migration risk demands its own session. |
| W9.28 Blelloch scan | Deferred (research) | Gate on Mamba-2 being on active roadmap. Currently research backlog only. |
| W9.29 Thermal-aware throttle | Yes | Phase 2 alongside W9.23. |
| W9.30 KIVI | Yes | **Phase 1.** Opt-in flag with perplexity regression test. |

Per-item details (research refs, files-to-touch, definition of done) live in
`03_EXECUTION_MAP.md`.

---

## 9. What this doctrine is NOT

- It is not a feature spec. Features live in `03_EXECUTION_MAP.md`.
- It is not a sequencing plan. Sequencing lives in `04_PHASES.md`.
- It is not a Pro/MAS gate. Gating lives in `02_BUILD_MATRIX.md`.
- It is not a research synthesis. Research links live in `05_RESEARCH_INDEX.md`.
- It is not a substitute for `PLAN_V2.md`. PLAN_V2 is the authority; this is one
  layer down.

---

## 10. Last updated

2026-04-26 — Initial creation. Fifth-position rulings on the five A/B/C/D tensions.
Retraction propagation named as the novel architectural primitive. Hardware budget
revised to 6 GB realtime per user input.
