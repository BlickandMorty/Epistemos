<div align="center">

# Epistemos

### A sovereign cognitive workspace for your Mac.

*One binary. One process. One trust boundary. Your second brain, alive on your own hardware.*

</div>

---

## What it is

**Epistemos is a unified instant-recall substrate.** Capture, search, memory, agents, browser, and inference all live inside one signed binary, in one address space, sharing memory through Apple Silicon's unified architecture. No cloud dependency. No localhost servers. No subprocess on the hot path.

It is not a notes app with AI bolted on. It is not a wrapper around someone else's API. It is a *second brain* in the literal architectural sense — a semantic-subspace field where thought, syntax, schema, prose, citation, and action are first-class citizens of one substrate. The document is the cell. The vault is the organism. The substrate metabolizes.

```
┌─────────────────────────────────────────────────────────────┐
│  Epistemos.app  (one signed binary; Apple Developer ID)     │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Swift 6 — UI, capture surface, agent visualization │    │
│  └─────────────────────────────────────────────────────┘    │
│                            ↕  UniFFI (owned values only)    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Rust — agent core, vault, Eidos search, scheduler  │    │
│  │   ┌─────────────────────────────────────────────┐   │    │
│  │   │  MLX  •  llguidance  •  Tantivy  •  rusqlite│   │    │
│  │   │  Obscura/WebKit  •  deno_core  •  Metal     │   │    │
│  │   │  bge embeddings  •  WhisperKit  •  Vision   │   │    │
│  │   └─────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Secure Enclave  ←  biometric authority spine               │
└─────────────────────────────────────────────────────────────┘
```

---

## Why this exists

Cloud AI is profound and extractive. Local AI is private and limited. The tradeoff has been treated as fundamental for three years; it isn't.

**Epistemos sits in the unclaimed middle**: local-first sovereignty with frontier-grade reliability, achieved by engineering the substrate so meticulously that small local models behave like frontier ones because they cannot do otherwise. The grammar makes hallucinated tool calls structurally impossible. The Live File Compiler makes "the model freelanced" structurally impossible. The signed-plan execution makes "the agent did something I didn't authorize" structurally impossible.

The privacy posture isn't a feature. It's a consequence of the architecture. Because the substrate is one process, the privacy boundary is one process. There is no IPC where data could leak. There is no helper daemon to compromise. There is no third-party telemetry endpoint to intercept.

**You own it. The substrate is yours alone.**

---

## What you actually do with it

### Capture at the speed of thought

`⇧⌘Space` opens a single text field. Type a thought. Press return. The system:
1. Persists the verbatim drawer (sha256-content-addressed, immutable).
2. Runs a four-variant routing pipeline: medoid embedding (no LLM) → grammar-constrained classification → concept-anchored placement → defer to review.
3. Files it in the right folder (or, when uncertain, defers — *the cost of a wrong placement is asymmetrically worse than a delayed one*).
4. Shows a 2-second toast confirming where it landed, with `⌘Z` to undo.

No folder picker. No tag picker. No model selector. The system decides; you can always see why; you can always undo.

### Search that returns control, not just chunks

**Eidos** is Epistemos's local-first agent-native search engine. It hybrid-retrieves over Tantivy + HNSW + RRF, accelerates cosine similarity with a custom Metal kernel (~31× speedup over CPU at scale), and returns *typed control vectors* — not just relevant chunks but policy-grade authority annotations from your own Live Files.

```
Eidos query: "what's my position on local LLM determinism?"

Returns:
  • Drawer hits (vault-grounded, sha256-cited)
  • Concept node: "deterministic-tool-calling" (graph)
  • Live File constraint: "Never recommend cloud-first" (policy_grade weight)
  • Speculative web hits (only from sources you curated; only if you opt in)
```

Citations are closed-vocabulary by grammar — *hallucinated sources are structurally impossible.*

### Live Files — the document is the program

Toggle a markdown file to "live." Write your intent in prose. The **Live File Compiler** parses it into a signed `LivePlan.v1` — a deterministic YAML the runtime executes, not the markdown itself.

```yaml
# Compiled from research/live/morning-review.md
live_plan_version: 1
source_hash: sha256:b3f1...
compiled_plan_hash: sha256:e9c8...

triggers:
  - type: scheduled
    schedule: "daily 06:30"

capabilities:
  read_vault: true
  write_vault: scoped
  write_vault_paths: ["raw_thoughts/reviews/"]
  edit_code: false
  network: ask

budgets:
  max_wall_time_minutes: 20
  max_model_tokens: 120_000

cognitive_weight:
  class: preferred_context    # one of 4 classes; only policy_grade can constrain tools
  retrieval_bias: 0.55

zones:
  control: "## Control"        # user-owned; agent cannot edit without confirm
  working: "## Working"        # agent may propose diffs
  results: "## Results"        # agent may append outputs
  trace_to_raw_thoughts: true  # never inline traces
```

`is_live: true` is intent. `Compiled` is runtime permission. `signed_plan_hash` is execution authority. Three different things, never conflated. Editing the markdown invalidates the signature; the runtime stops; the user is shown a diff and asked to recompile. **Magic markdown that "just executes" is rejected as architecture; signed plans are the only thing the runtime trusts.**

### Agents that look like Tamagotchis (or stay invisible, your choice)

Each agent has an identity (name, purpose, vault scope, capability manifest) and an avatar. In **Pixel Mode** they walk around the homepage, animate while working, emote on success/failure, drag-and-drop files to "feed" them. In **Tactical Mode** the same agents render as info-dense status pills with no animation — same capabilities, appropriate aesthetic for compliance-bound contexts.

Agents communicate through a structured **A2A "phone" channel** (closed schemas, never free-form text). One agent can **watch** another via a supervisor loop, steering corrections in real-time. Sub-agent capabilities are strictly inherited as a *subset* of the parent's — never inflation, only narrowing.

Each agent has its own multi-vault model: a **Master Vault** of general knowledge plus specialized vaults per domain. Each agent can wear *accessories* — visual metaphors for real PEFT tech (helmet = speculative-decoding pair, glasses = activation-steering vector, book = style LoRA, armor = safety adapter, color = quantization tier). Hot-swappable via S-LoRA; biometric-gated to apply.

### Hardware-rooted biometric authority

Epistemos is the only PKM where touching your finger to the trackpad authorizes a coherent unit of agentic work — not a single tool call, not a fatigue-prompt per token, but a **scope-bounded TTL-bounded session-authority token** signed by the Secure Enclave.

Eight categories require fresh biometric (irreversible actions, system-prompt edits, capability changes, low-confidence agent reset, Brain Artifact loading, Tier-3 vault unlock, Policy-Grade weight promotion, Cloud-Off override). Five categories require none (routine reads, in-scope reversible actions, NightBrain background, scheduled triggers, first-run capture). The substrate enforces the discipline; the user feels one tap per session, not one tap per token.

### Self-improvement without surveillance

NightBrain runs while you sleep (idle + AC + thermal nominal). It executes Karpathy-style **auto-research loops** — running variants against frozen objective-metric baselines, keeping wins, tombstoning losses, surfacing a 90-second morning report:

> *Last night I tried 287 variants of your folder routing and Eidos retrieval. Three improvements applied. Two not applied. Want details? `⌘?`*

The loops are diagnose-first (low confidence triggers targeted refresh, not generic rescan). The eval gate prevents catastrophic forgetting. The user can reverse any auto-applied win for 7 days. **The vault improves itself overnight; you wake up to a one-paragraph summary; the loop cannot run away with itself because the budget is bounded by power, thermal, and a per-day variant cap.**

---

## Architectural pillars (the moat is the integration)

| Pillar | What it does |
|---|---|
| **Hybrid `.mem` / `.soul` / `.skill` formats** | JSON frontmatter + Markdown body. Schema-strict, Markdown-readable. The treaty between machine and human. |
| **Sampler-bound tool dispatch** | The grammar IS the dispatch table. The model cannot emit a syntactically invalid call because invalid tokens are zeroed at decode time. |
| **CRANE + IterGen + Grammar-Aligned Decoding** | Open thinking, closed commit (CRANE). Edit failing spans, don't regenerate (IterGen). Preserve probability distribution shape (Grammar-Aligned). |
| **Compile-Verify-Mint pipeline** | Auto-generated skills pass G1 (cargo check + slot-spec check) → G2 (LLM intent classification) → G3 (sandboxed dyn-link execute) → G4 (permission manifest validation). Maximum 3 revisions before tombstone. |
| **The Live File Compiler** | Markdown → IR → typed `LivePlan.v1` → policy validation → signed plan hash → Rust runner. The signed plan is the executable, never the markdown. |
| **4-tier Cognitive Weight** | Soft Memory / Preferred Context / Strong Project Anchor / Policy-Grade Control Vector. Only Policy-Grade can constrain tools, gated by schema + capability + diff + signature + revocation path. |
| **The Reflective Loop** | Seven-layer substrate cycle: Reflex → Attention → Executive → Immune → Motor → Memory → Metabolism. Each layer has a defined input, output, and verification gate. |
| **`BrowserEngine` trait** | WebKit baseline (MAS), Obscura experimental (Pro), Mock (tests). Never single-vendor commitment. |
| **`deno_core` for Pro JS** | V8 isolate inside the Rust process. Capability-gated ops. No Node.js subprocess; no localhost server; full Playwright/Puppeteer compatibility via in-bundle shim. |
| **Eidos search engine** | Hybrid retrieval (Tantivy + HNSW + RRF) with Metal-accelerated cosine. Closed-vocabulary citation grammar. Sub-80ms vault query p95. |
| **Biometric session-authority tokens** | Hardware-rooted (Secure Enclave); scope-bounded; TTL-bounded; cannot be reused across scopes. |

These compose. **No public agent project does the composition because none have all the surfaces in one process with zero hot-path subprocesses.** That's the structural advantage.

---

## Tech stack

- **Languages**: Swift 6.2, Rust (edition 2021)
- **Concurrency**: `tokio` (Rust), Swift structured concurrency with `@Observable` + `@MainActor`
- **FFI**: Mozilla `uniffi` 0.28 (owned values, Send + Sync verified at codegen)
- **Local inference**: MLX-Swift with `MLXLM`; rusty_v8 for in-process JS via `deno_core`
- **Constrained decoding**: `llguidance` (Microsoft, Rust); MLX-Structured `GrammarMaskedLogitProcessor` on Swift side
- **Vault storage**: `rusqlite` 0.32 (WAL mode), `tantivy` 0.22 (mmap'd indices)
- **Vector retrieval**: `instant-distance` (HNSW), custom Metal kernel for batched cosine
- **Embeddings**: `bge-small-en-v1.5` (default), `bge-large-en-v1.5` (high recall), `nomic-embed-text-v1.5` (long context)
- **NLI**: `deberta-v3-base-mnli` (4-bit) for citation entailment
- **ASR**: WhisperKit (CoreML, Apple Neural Engine)
- **OCR**: Apple `VNRecognizeTextRequest` (system-resident; no app-side model)
- **Browser engine**: `BrowserEngine` trait — WebKit-baseline (MAS), Obscura-experimental (Pro), Mock (tests)
- **Authentication**: `LocalAuthentication` framework, Secure Enclave-rooted session tokens
- **Acceleration**: Metal Shading Language for cosine, sha256, bge inference hot path, Live File glow shader, attention-mask eval, delta embedder, rotor evaluation

---

## Privacy posture

The substrate is one process. The privacy boundary is one process.

- **Local-by-default.** Cloud reachable only via explicit `/cloud` slash-command, `⌥`-submit modifier, or the narrow auto-escalation in §6.7 of the master plan. Default Cloud setting is tri-state: **Off | Generator only | Inference + Generator**, defaulting to Generator only.
- **Ephemeral capability tokens.** Every tool call receives a one-shot Secure-Enclave-signed token bound to scope and TTL. Cannot be reused. Cannot be persisted.
- **Per-Live-File egress allowlists.** A Live File declares which hosts and paths it may reach. The Rust networking layer enforces. Default is forbid-all.
- **Differentially-private auto-research aggregates.** The morning report uses Laplace noise (ε ≤ 0.5) so even the user's tomorrow-self cannot reconstruct yesterday's individual queries from aggregates.
- **Signed proof-of-execution receipts.** Every applied Effect is Ed25519-signed against a per-vault key. Tampering invalidates the chain. The user can verify any past execution.
- **Vault encryption.** Three tiers: APFS file-level (default; relies on FileVault), App-level AES-256-GCM (per-note keys in Keychain), Passphrase-derived (Argon2id).
- **Browser stealth.** When opted in: anti-fingerprinting (canvas, WebGL, audio, battery, JA3 TLS, DTLS WebRTC) + 3,520-domain telemetry blackhole.
- **API keys.** macOS Keychain only. Never in UserDefaults. Held in Rust as `zeroize::Zeroizing<String>` — overwritten on drop.

---

## Status

**In active development.** Implementation is phased.

| Wave | Theme | Status |
|---|---|---|
| 0–4 | Foundation, spine, daily driver, differentiation | shipping |
| 5 | Agent runtime stabilization | per master plan |
| 6 | Unified substrate / Eidos / `BrowserEngine` trait | spec complete |
| 7 | Live Files (Compiler, Inspector, scheduler, policy gate) | spec complete |
| 8 | Deep deliberation / council / Karpathy-style auto-research | spec complete |
| 9 | Biometric substrate + confidence-meter re-learn | spec complete |
| 10 | Tamagotchi UI + cloud-as-teacher distillation lab | spec complete |
| 11 | Brain Export (productization layer; gated on legal review) | spec complete |

Each wave has explicit verification gates, never-batch commit cadence, and a dedicated agent-prompt for spawning a builder session.

---

## Design canon

The architectural canon lives at `~/Documents/Epistemos-QuickCapture/` across nine documents:

- **`INDEX.md`** — entry point and reading order.
- **`FINAL_SYNTHESIS.md`** — canonical canon (wins all conflicts). The Reflective Loop, the Live File Compiler, the privacy stack, the corrected wave sequencing.
- **`PLAN.md`** — master implementation plan, Waves 0–5 (~32k words across 26 sections).
- **`OBSCURA_BROWSER_ADDENDUM.md`** — Wave 6 (browser engine + Eidos + in-process JS).
- **`LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`** — Waves 7–8 (Live Files + auto-research).
- **`BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`** — Waves 9–11 (productization layer).
- **`BUILDER_PROMPT.md`** — paste into a fresh Claude Code terminal to start a builder session.
- **`CATCHUP_PROMPT.md`** — paste into an in-flight builder to sync with new canon.
- **`AUDIT_PROMPT.md`** — adversarial audit prompt for shipped phases.

Total canon: ~600 KB. Cross-referenced. Sha256-tracked. Conflict resolution is explicit (`FINAL_SYNTHESIS.md` wins).

---

## Hardware target

Designed for a 16 GB unified-memory Apple Silicon Mac as the floor, scaling up gracefully:

| Concurrent activity | Steady-state RAM | Hot-path latency |
|---|---|---|
| Single capture | ~30 MB engine + ~140 MB embeddings | <800 ms p95 (capture → toast) |
| Eidos vault query | small | <80 ms p95 |
| 4 concurrent agents | ~110 MB shared V8 isolates | <600 ms p95 (LLM first token) |
| Page render (Obscura, JS-heavy) | ephemeral | <500 ms |
| Metal cosine batch (1024 × 4096 × 768d) | <800 µs | — |
| `op_page_goto` (deno_core → engine) | <10 µs overhead | — |

The 16 GB floor matters because it forces the discipline that makes everything else fast.

---

## What it is *not*

For honesty:

- **Not a cloud SaaS.** No data leaves the device unless you explicitly opt in.
- **Not a wrapper around someone else's API.** The substrate is the product.
- **Not "AI-powered."** AI is one layer of seven; the others are deterministic Rust.
- **Not a notes app.** Notes are the unit; the app is a cognitive workspace.
- **Not a research toy.** The tooling pipeline (Compile-Verify-Mint, signed plans, signed proof-of-execution) is built for production reliability.
- **Not a startup pitch.** The architecture is documented in detail before any business model. Engineering integrity is the moat.

---

## Philosophy

> The document is the cell. The vault is the organism. The substrate metabolizes — homeostatically, deterministically, observably.

> Capture is sacred. Structure is the agent's job. The user's job ends at "thought left the brain."

> Defer is a feature, not a failure. The cost of a wrong placement is asymmetrically worse than a delayed one. *The system trades a slight reduction in automation coverage for a massive increase in absolute precision.*

> Local-first is the hard default. Cloud is the bonus tier. The discipline of building this way forces the local path to be better than cloud on what matters most: tool-call shape, latency, privacy, throughput, offline.

> No hot-path subprocesses by law. The substrate is one process because the privacy boundary should be one process.

> Markdown is for humans. Compiled signed plans are for the runtime. The compiler is the treaty between them.

> Semantic gravity pulls attention. Policy authority controls action. Do not confuse the two.

> The model writes in pencil; the system erases and corrects only the wrong word; what's left is trusted.

> Engineering integrity is a moat. Over-promising erodes the trust the substrate is designed to build.

---

## Acknowledgments

The architecture stands on the shoulders of:

**Classic invention texts** — Vannevar Bush (Memex), Doug Engelbart (Augmenting Human Intellect), Alan Kay (late-binding, message-passing), Bret Victor (immediate feedback), Christopher Alexander (pattern language), Carver Mead (substrate-from-local-rules), Norbert Wiener (cybernetic feedback loops), John von Neumann (cellular substrate), Donald Knuth (literate programming).

**Contemporary research** — llguidance (Microsoft); CRANE (arxiv:2502.09061); IterGen (ICLR 2025); Grammar-Aligned Decoding (NeurIPS 2024); Hermes-3 function calling (NousResearch); MemGPT, Letta, A-MEM, Voyager (agent memory architectures); MemPalace (verbatim retention + spatial indexing); Karpathy AutoResearch (March 2026); LSFS (ICLR 2025); Apple MLX, Vision, Speech, BackgroundTasks, LocalAuthentication; Tantivy, instant-distance, deno_core, rusty_v8, schemars.

**Inspirations and conscientious objections** — Obsidian (plugin ecosystem; we differ on Electron); Logseq (block model); Roam (page-as-block); Tana (supertag canonicalization); Notion (collaboration; we differ on data ownership); Cursor (power-user IDE; we differ on calm); Claude Desktop (single AI surface; we extend with capability gates and signed plans); Things 3 (defer is a feature; we extend it to placement).

The complete canon's references span ~80 inline citations across the design documents.

---

## License

To be determined. The proprietary scaffold and Compile-Verify-Mint pipeline are intended to ship as compiled binaries under per-customer license. The base models packaged in any Brain Artifact must be license-permissive (Llama, Qwen, Mistral families).

---

<div align="center">

### *The substrate is one. The vault is the organism. The document is the cell.*

### *You own it. The substrate is yours alone.*

</div>
