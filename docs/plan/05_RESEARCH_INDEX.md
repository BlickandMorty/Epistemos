# 05 — Research Index

**Authority:** Companion to `03_EXECUTION_MAP.md`. Every item in the execution map
references entries here. Agents must read the entries flagged for their item before
writing code.

**Convention:** every entry has a one-line topic summary + a list of `03_EXECUTION_MAP.md`
items it informs. The reverse index at the bottom lets agents go from item → docs.

---

## A. `/Users/jojo/Downloads/Advice/`

The "Advice" corpus — early-stage architectural guidance from Claude, Gemini, GPT,
Perplexity. Primarily doctrine-level.

### A.1 `claude advice.md` (62 KB, .md)
**Topics:** Mirror of PLAN_V2 doctrine — local-first cognitive OS, layered architecture, fault-proof failure modes, Rust sovereignty.
**Informs:** doctrine-level decisions across `01_DOCTRINE.md` §1, §2; faculty plane; substrate plane.
**Read when:** doing anything that crosses plane boundaries; ruling on a doctrinal question.

### A.2 `Claude paper.pdf` (273 KB, .pdf)
**Topics:** Claude-authored deep architectural paper — substrate moat, provenance theory.
**Informs:** §0 verdict, §3 (retraction primitive), §5 (open standard rationale).
**Read when:** defending the determinism+provenance moat; making strategic decisions on what's open vs closed.

### A.3 `claudy research.md` (63 KB, .md)
**Topics:** Auto-regenerated AI Coding CLI configuration templates — CLAUDE.md, settings.json, .claude/ directory layout, Codex CLI config, Gemini CLI config (April 2026 verified).
**Informs:** D11 (epistemos-trace CLI distribution patterns); settings format if Epistemos ever exports its own.
**Read when:** working on CLI binary distribution; understanding Claude Code's config conventions.

### A.4 `Gemini paper.pdf` (253 KB, .pdf)
**Topics:** Gemini-authored deep paper on Epistemos architecture (paired with Claude paper for cross-model perspective).
**Informs:** §0 verdict; §1 four-planes; D2 (MCP boundary).
**Read when:** sanity-checking architectural decisions across multiple model perspectives.

### A.5 `Gpt paper.md` (23 KB, .md)
**Topics:** Provider runtimes as plug-ins; Claude Agent SDK / Codex app-server / Gemini CLI as official agent surfaces; Episdemo as the host runtime owning workspace + approvals + sandbox + sessions + UI.
**Informs:** §2.2 (Hermes-as-provider); §5 (open standard); D9 (skills as graph nodes); the entire provider matrix.
**Read when:** working on any provider integration; deciding whether to embed external CLI tooling.

### A.6 `perplexity 2.md` (32 KB, .md)
**Topics:** Architecture brief + Claude brainstorm prompt; Docker/DevContainer + Claude Agent SDK + Qwen-Agent + Generative UI strategy.
**Informs:** D3 (A2UI catalog — generative UI counterpoint); doctrine §6 #4 (closed catalog vs generative).
**Read when:** considering any generative-UI feature.

### A.7 `Perplexity paper.md` (32 KB, .md)
**Topics:** Episdemo AI architecture — full automation, agentic local models, generative UI; Docker chassis; Claude Agent SDK piggybacking.
**Informs:** R16 (ETL); D9 (skills); doctrine §5 (provider plane).
**Read when:** scoping local-vs-cloud capability gating.

---

## B. `/Users/jojo/Downloads/final/`

The "final" corpus — post-research convergence; hackathon-ready material.

### B.1 `Building Epistemos x Hermes Hackathon.txt` (45 KB, .txt)
**Topics:** Hermes hackathon technical dossier — MCP substrate surface, rmcp crate, stdio transport, schemars-derived schemas.
**Informs:** D2 (7-verb MCP boundary); §5.6 (hackathon launch); the entire Hermes-provider implementation.
**Read when:** doing ANY MCP-server work; planning the hackathon demo.

### B.2 `compass_artifact_wf-2d55c11c-8cbd-48a1-a967-04bd500b1825_text_markdown.md` (63 KB, .md)
**Topics:** AI Coding CLI config templates (April 2026) — CLAUDE.md, settings.json, .claude/. Detailed precedence hierarchy, scope locations, settings flow.
**Informs:** D11 (CLI distribution); reading conventions for settings files.
**Read when:** designing Epistemos's own settings format or CLI config UX.

### B.3 `compass_artifact_wf-2de4a4f7-c7f2-479f-ae00-bb7523459bd9_text_markdown.md` (57 KB, .md)
**Topics:** Hermes Hackathon architectural dossier — solo dev plan, GRDB+SQLite WAL, F_FULLFSYNC, Metal at 120 fps, MLX-Swift, Hermes Agent v0.11.x.
**Informs:** D5 (durability discipline); §4 (perf budget); §5.6 (hackathon).
**Read when:** working on storage durability or Hermes integration.

### B.4 `deep-research-report (2).md` (33 KB, .md)
**Topics:** Win-condition narrowness for the hackathon — DON'T replace Hermes, DON'T finish the in-repo agent, DON'T migrate everything. Build a tiny Rust MCP seam.
**Informs:** §0 verdict; §2.2 (Hermes-as-provider, integration not replacement); Phase 1 vertical-slice scoping.
**Read when:** scoping any Hermes work; deciding what NOT to build.

### B.5 `Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md` (32 KB, .md)
**Topics:** Master architecture prompt — Swift 6 + Rust + UniFFI + BoltFFI + MLX-Swift + GRDB; M2 Pro 16 GB target; the "app feels dead" core problem; quick-actions vs ambient agency tension.
**Informs:** §0 verdict; §4 (faculty roster); doctrine on "ambient agency" vs request-response.
**Read when:** designing any user-facing AI surface; scoping ambient features.

### B.6 `EPISTEMOS_HERMES_MANIFESTO.md` (37 KB, .md)
**Topics:** Hermes manifesto — three parts (the soul, the executable research brief, the compressed nine-day vision); capability honesty; structural trace.
**Informs:** §0 verdict; §6 #3 (no fake features — capability honesty); §5 (open standard moral framing).
**Read when:** writing any user-facing copy; making strategic narrative decisions.

### B.7 `executive sumaries/compass_artifact_wf-929d1097-bdc7-4efc-86bc-c8e97ca19b9f_text_markdown.md` (69 KB, .md)
**Topics:** Executive summary — fused doctrine across multiple research tracks. 69 KB, the largest exec summary.
**Informs:** §0 verdict; phase ordering; cross-cutting doctrine.
**Read when:** orienting to the doctrine for the first time; lost in the weeds.

### B.8 `executive sumaries/deeper research from gpt.md` (33 KB, .md)
**Topics:** GPT-authored deeper research synthesis.
**Informs:** doctrine-level cross-checks.
**Read when:** sanity-checking against another model's synthesis.

### B.9 `executive sumaries/epistemos-rival-doctrine.md` (22 KB, .md)
**Topics:** Rival/competitive doctrine — what other PKM/agent products are doing and why Epistemos is different.
**Informs:** §5 (pattern alignment — Tailwind/Bear/OpenAPI); strategic positioning.
**Read when:** doing competitive analysis or positioning work.

### B.10 `executive sumaries/gpt deep.md` (35 KB, .md)
**Topics:** GPT-authored deep synthesis paired with B.8.
**Informs:** cross-model sanity check on doctrine.
**Read when:** as B.8.

### B.11 `last round of thinking/AI App Architecture Consensus Building.txt` (43 KB, .txt)
**Topics:** Consensus-building across all four architects — what A/B/C/D agree on and what they don't.
**Informs:** §2 (the five tensions); the foundation for the fifth-position rulings.
**Read when:** disagreeing with one of the §2 rulings; want to see the original positions in detail.

### B.12 `last round of thinking/compass_artifact_wf-1d5bf47c-b010-4114-996e-ccf0d93a45a2_text_markdown.md` (67 KB, .md)
**Topics:** Final round-of-thinking compass artifact — fused doctrine post-debate.
**Informs:** doctrine-level cross-cutting; phase ordering.
**Read when:** as B.7.

### B.13 `last round of thinking/Epistemos App_ Privacy, Speed, SDK Integration.txt` (47 KB, .txt)
**Topics:** Privacy + speed + SDK integration tradeoffs; sandbox vs Pro analysis.
**Informs:** `02_BUILD_MATRIX.md` entirely; §6 #9 (no MAS sandbox compromises in Pro paths).
**Read when:** working on any MAS vs Pro gating decision.

### B.14 `last round of thinking/Epistemos Architecture Consensus & Disruption.txt` (25 KB, .txt)
**Topics:** Consensus on architecture + disruption potential.
**Informs:** §5 (open standard disruption strategy).
**Read when:** scoping the open standard launch.

---

## C. `/Users/jojo/Downloads/final v2/` (latest research, the most current)

Per user 2026-04-26: the final research corpus. No more after this.

### C.1 `compass_artifact_wf-c2d78e2f-9482-4530-8780-87218a449cb3_text_markdown.md` (63 KB, .md)
**Topics:** Master Doctrine & Implementation Cookbook. 12-moat audit. Faculty roster (Hermes-3 8B + Llama-3.2 1B drafter + bge-small + AFM = ~5.6 GB resident). BLAKE3 Merkle chain. 10-stage SOAR replay. FSRS-6 epoch decay. AFM `@Generable` as structurer. Swift macro-static A2UI v0.9. M2 Pro 18 GB hardware reality.
**Informs:** D1 (BLAKE3 chain); D3 (A2UI catalog); D4 (faculty roster); D7 (FSRS-6); §3 (retraction primitive cryptographic backing); §4 (6 GB budget — note: this doc claims 18 GB; user's clarified 16 GB takes precedence).
**Read when:** working on any Phase 1 D-item; verifying memory math; doing any provenance work.
**Note:** the doc has its own `UNVERIFIED` markers — preserve them; don't treat as canon.

### C.2 `deep-research-report (4).md` (13 KB, .md)
**Topics:** Moats audit; North Star metric ("Meaningful Knowledge Created per Active User"); structured output (`@Generable`); KIVI vs TurboQuant; UniFFI 0.28→0.29.5 breaking changes (the `UniffiCustomTypeConverter` removal); rope; oplog; Apalis ETL.
**Informs:** R14 (UniFFI specifics); W9.10 (TurboQuant); W9.25 (grammar masking — `@Generable` + `LocalToolGrammar.swift`); W9.26 (rope); W9.27 (OpLog); W9.30 (KIVI); R16 (ETL Apalis).
**Read when:** working on ANY of those items.

### C.3 `deep-research-report (4) copy.md` (14 KB, .md)
**Topics:** Architecture and model optimization; SSM / hybrid models (Amazon Mamba2-primed Qwen3-8B, NVIDIA Nemotron-3-Nano-4B, AI21 Jamba-Reasoning-3B); low-memory inference + fine-tuning strategies.
**Informs:** W9.28 (Blelloch scan / Mamba-2 context); D4 (faculty roster — counter-perspectives on what to run); D10 (speculative decoding).
**Read when:** considering any hybrid SSM model; expanding the faculty roster.

### C.4 `deep-research-report (4) copy 2.md` (22 KB, .md)
**Topics:** Deep research audit + implementation blueprint — moat under-expression, missing memory mechanics, raw-thought decay, hierarchical concepts, depth markers, emotional anchors, structured artifacts vs loose markdown, morning consolidation, brain-dump button. Critique of "over-indexing on parity" with Hermes/Claude.
**Informs:** D6 (hierarchical concept extraction); D7 (FSRS-6 + raw-thought decay); D8 (Night Brain + morning consolidation); §0 verdict (don't be Hermes-in-Swift).
**Read when:** working on cognitive memory features; designing the user's "feels alive" experience.

### C.5 `App Moats, AI Integration, and Master Plan.txt` (40 KB, .txt)
**Topics:** Cognitive substrate doctrine — provenance plane, biological memory metabolism, agentic provenance. ULID-keyed graph. DenseSlotMap arena. GRDB WAL + F_FULLFSYNC. 7-verb MCP. AFM `@Generable` for offloading. Hermes intercepts skills system → reroutes filesystem writes over MCP into the graph. CLI orchestration (Claude Code, Codex, Kimi, alt local Claude) silent subprocess delegation. 120 fps Metal. AnyView ban. **BoltFFI mentioned as 1000× UniFFI speedup `[UNVERIFIED]`**.
**Informs:** D1 (BLAKE3 chain); D2 (7-verb MCP); D3 (A2UI catalog, AnyView ban); D5 (durability — DenseSlotMap, F_FULLFSYNC); D6 (hierarchical concepts); D7 (decay); D8 (Night Brain); D9 (skills as graph nodes); D12 (BoltFFI investigation); §0 verdict; §1 four-planes; §6 #6 (no AnyView).
**Read when:** working on ANY substrate-plane feature; ANY Hermes integration; ANY FFI work.

### C.6 `Epistemos Hackathon_ Deep Research Plan.txt` (42 KB, .txt)
**Topics:** Workspace OS paradigm; cognitive substrate; provenance plane; A2UI protocol with closed catalog + AnyView ban + VALIDATION_FAILED rejection; "Night Brain"; hierarchical concept extraction; emotional anchors; SSM hardware acceleration; AFM bridging; KV cache compression. 7-verb MCP boundary. **BoltFFI 1000× speedup claim `[UNVERIFIED]`**.
**Informs:** Same as C.5 plus §5.6 (hackathon launch); D2 (MCP); D3 (A2UI v0.9 + VALIDATION_FAILED); D6/D7/D8.
**Read when:** working on hackathon demo; any cognitive feature; any A2UI component.

---

## C-bis. `/Users/jojo/Downloads/final v3/` (latest research drop, post-v2 — orthogonal not superseding)

Per Explore-agent digest 2026-04-27. v3 does NOT supersede v2 (different domain): v2 = inference/runtime/substrate, v3 = LLM prompt engineering for production robustness. Both stay canonical; their claims are cumulative.

### C-bis.1 `deep-research-report (4).md` (~13 KB, .md)
**Topics:** "Ambiguity Tax" mitigation via JSON-schema prompting; prompt industrialization (strict format + template + rules + examples) for >99% JSON validity; modular prompt trees (system/tools/memory/task split); Anthropic prompt caching mechanics (85–92% token savings via `cache_control`); Tool Search (~85% token deferral); ingestion pipeline (parsing → validation → auditing → feedback).
**Informs:** N1 (Prompt Tree JSPF/PTF design verification); W9.6 (`cached_tokens_share` telemetry); any provider-call optimization that targets external LLMs (Claude/Gemini/OpenAI). Phase 3+ value when provider optimization becomes active.
**Read when:** implementing or optimizing any external-LLM provider call; designing multi-turn cache strategy; building MCP tool-invocation prompt templates.
**Note:** Orthogonal to v2 (runtime) and v1 (Hermes integration). Cumulative, not superseding.

---

## D. Auxiliary research (Downloads root — older, secondary, NOT mandatory reads)

These exist in `/Users/jojo/Downloads/` at the root level. They were earlier
research; the consolidated synthesis is in folders A/B/C above. Read these only if
an item in `03_EXECUTION_MAP.md` explicitly references them, OR if a topic is not
covered in A/B/C and these are the only source.

| File | Topic |
|---|---|
| `Advanced Agent Harness & Orchestration Reference — Epistemos Deep Audit.md` | Agent harness patterns |
| `Architecture Hardening AppSupervisor, EpistemosMode, FFI Safety & Inference Resilience.md` | Hardening — relevant to W9.21, W9.22, W9.29 |
| `Custom Metal Mamba 2 Implementation for Epistemos Technical Specification.md` | Mamba-2 Metal implementation — relevant to W9.28 |
| `Custom Metal Mamba-2 Implementation Technical Specification for Epistemos.md` | (duplicate / variant of above) |
| `Epistemos Deep Diagnostics, Custom Logging, and Real-Time Self-Healing Architecture.md` | Diagnostics — relevant to W9.29, telemetry mandate |
| `Epistemos Definitive Security & Concurrency Failure Analysis.md` | Security/concurrency — relevant to W9.21, W9.22 |
| `Epistemos Keystroke Telemetry, Input-Driven Hardening & Runtime Perfection.md` | Input hardening (Pro AXorcist context) |
| `Epistemos Low-Memory Model Expansion + TurboQuant Implementation Guide.md` | TurboQuant — relevant to W9.10 |
| `Epistemos State-of-the-Art Architecture for a Swift 6 Rust (UniFFI) macOS 26 PKM That Never Hangs.md` | Hang prevention; runtime stability |
| `Epistemos Zero-Copy, Zero-Latency Implementation Masterclass.md` | Zero-copy FFI — relevant to W9.24, D12 (BoltFFI investigation) |
| `Epistemos Agent System — Verification Plan.md` | Verification plan — relevant to test invariants |
| `Epistemos Canonical Pattern Integrity Audit.md` | Pattern audit |
| `Epistemos Complete Model Support & Feature Expansion Plan.md` | Feature expansion (older) |
| `Epistemos Graph Engine — Optimal Performance Roadmap.md` | Graph perf — relevant to W9.24 |
| `Epistemos Graph Engine — Superb Performance — The Definitive Optimization Playbook.md` | Graph perf playbook |
| `Epistemos Graph SDF Label System — Deep Engineering Report.md` | SDF labels |
| `Epistemos Next-Generation Research Mode — Migration Blueprint 2.md` | Research mode |
| `Epistemos Omniscient Architecture Manifesto.md` | Architecture manifesto (predecessor to current doctrine) |
| `Epistemos Public Shell — Website Revamp & Interactive Tool Strategy.md` | Public website (out of scope for app) |
| `Epistemos Training Readiness Audit.md` | Training data audit |
| `Epistemos AI Cognitive Partner Analysis.txt` | AI cognitive partner framing |
| `Epistemos High-Performance macOS Agent Architecture.txt` | macOS agent perf |
| `epistemos_computer_prompt.md` | Computer-use prompt |
| `EPISTEMOS_MASTER_THESIS.md` | Master thesis |
| `EPISTEMOS_MEGAPROMPT.md` | Mega-prompt for AI sessions |
| `EPISTEMOS_PHASE_I_IMPLEMENTATION_GUIDE.md` (89 KB) | Phase I implementation (reference for Phase 0) |
| `EPISTEMOS-CODEX-PLAN.md` (62 KB) | Codex-specific plan |
| `EPISTEMOS-CODEX-REMAINING.md` | Codex remaining work |
| `EPISTEMOS-FEATURE-SPEC.md` (115 KB) | Comprehensive feature spec — large reference |
| `epistemos-final-release-plan.md` | Older final-release plan |
| `EPISTEMOS-HERMES-PARITY-PLAN.md` | Hermes parity (the parity-trap docs warn against; relevant for §0) |
| `Epistemos-Master-Resolution-Plan.md` | Older master plan |
| `epistemos-master-session-prompt.md` | Older session prompt |
| `EPISTEMOS-PLUGIN-PORTING-SPEC.md` (120 KB) | Plugin porting (large reference) |
| `EPISTEMOS-RESEARCH-REFERENCE.md` | Research reference index (older, this doc supersedes it) |
| `EPISTEMOS-RESEARCH-REFERENCE-v2.md` | Research reference v2 |
| `EPISTEMOS-SESSION-AUDIT-FOR-CODEX.md` | Session audit for Codex |
| `epistemos-upgrade-plan.md` | Upgrade plan |
| `Fixing Epistemos Build-and-Ship Issues.md` | Build/ship issues — possibly relevant to Phase 0 |
| `macOS 26 Epistemos Complete Mouse Keyboard Input Death — Diagnosis & Fixes.md` | macOS 26 input issues — relevant if hitting input bugs |
| `man7final.md` | Final man-page-style reference |

---

## E. Reverse index — items → required reads

For each `03_EXECUTION_MAP.md` item, the *minimum* research reads. The item entry
in `03_EXECUTION_MAP.md` may name additional ones.

| Item | Required reads (min) |
|---|---|
| **R14** UniFFI bump | C.2 (deep-research-report (4).md) — UniFFI section |
| **R15** Benchmark harness | C.6 (Epistemos Hackathon Plan) |
| **R16** ETL crawler | C.2 (deep-research-report (4).md) — ETL section; A.7 (Perplexity paper) |
| **W9.6** Cost dashboard | A.1 (claude advice); B.6 (manifesto); provider docs |
| **W9.7** Vault selector | B.5 (master architecture brief) |
| **W9.8** Approval modal | C.5 (App Moats); B.4 (deep-research-report (2)) |
| **W9.10** TurboQuant | C.1 (compass artifact); C.2; root: TurboQuant guide |
| **W9.11** Personalized embeddings | C.2 (deep-research-report (4) — embeddings) |
| **W9.12** Orphan rediscovery | C.4 (deep-research-report (4) copy 2) |
| **W9.13** Daily notes + FSRS | C.1 (FSRS-6 doctrine); C.4 |
| **W9.14** Block references | C.1 (compass artifact) |
| **W9.15** Routing macro | A.1 (claude advice — `AnyView` ban context) |
| **W9.21** Honest FFI | C.5 (App Moats); root: Architecture Hardening |
| **W9.22** Typestate Islands | C.5; root: Concurrency Failure Analysis |
| **W9.23** Circuit breaker | C.6 (Hackathon Plan) |
| **W9.24** Metal zero-copy | root: Zero-Copy, Zero-Latency Masterclass |
| **W9.25** Grammar masking | C.2 (Structured Output section); B.6 (manifesto); C.1 |
| **W9.26** B-tree rope | C.2; C.1 |
| **W9.27** Append-only OpLog | C.2 (operation logs); C.5 (provenance plane) |
| **W9.28** Blelloch scan | C.3 (SSM section); root: Custom Metal Mamba 2 |
| **W9.29** Thermal-aware throttle | C.6; root: Diagnostics + Self-Healing |
| **W9.30** KIVI 2-bit KV | C.2 (KIVI section); C.1 (KV-quant doctrine) |
| **D1** BLAKE3 Merkle chain | C.1 (BLAKE3 section); C.5 (provenance plane) |
| **D2** 7-verb MCP boundary | B.1 (Hackathon Hermes); C.5; C.6; MCP spec |
| **D3** Closed A2UI catalog | C.5 (A2UI ban-list); C.6 (A2UI v0.9); C.1 |
| **D4** Faculty roster | C.1 (faculty roster); B.5 (master architecture brief); C.5 |
| **D5** Substrate durability | C.5 (DenseSlotMap, F_FULLFSYNC); B.3 |
| **D6** Hierarchical concepts | C.4; C.5 |
| **D7** FSRS-6 + decay | C.1; C.4 |
| **D8** Night Brain | C.5; C.4 |
| **D9** Skills as graph nodes | C.5 (Hermes faculty section); C.6 |
| **D10** Speculative decoding | C.1 (drafter section); C.3 |
| **D11** epistemos-trace CLI | A.3 (claudy research — CLI patterns); B.2 |
| **D12** BoltFFI investigation | C.5 (BoltFFI claim); root: Zero-Copy Masterclass |

---

## F. How to read research efficiently (anti-drift)

When an item points to research, the agent MUST:

1. **Read the file in full** before writing any code for the item. "Skim" is not
   acceptable; load the content into context and summarize the load-bearing
   constraints to itself.
2. **Quote the source** in the PR description for any claim that depends on it.
   "Per `final v2/compass_artifact_wf-c2d78e2f` §faculty-roster, the drafter is
   `Llama-3.2-1B-4bit`" beats unattributed "the drafter is `Llama-3.2-1B-4bit`."
3. **Resolve contradictions explicitly.** If two research docs disagree, the
   agent does NOT pick one silently. It surfaces the conflict and asks. Per
   `00_AUTHORITY_AND_ANTI_DRIFT.md §5` (STOP-and-surface).
4. **Honor `[UNVERIFIED]` markers** in the source docs. Do not strip them when
   citing. If the agent's own work cannot verify the marked claim, the marker
   propagates into the implementation.
5. **Prefer C-corpus over B-corpus over A-corpus when they conflict.** C is the
   most recent (final v2). Reasoning: research evolves; the latest synthesis
   subsumes prior tracks. (Exception: PLAN_V2 always wins regardless of corpus.)

---

## Last updated

2026-04-26 — Initial creation. Research files cataloged across `/Advice`, `/final`,
`/final v2`, plus auxiliary listing for `/Downloads` root. Reverse index keyed by
item ID.
