# Helios V6.1 New Research Integration — 2026-05-16

**Purpose:** Authoritative integration of two Helios V6.1 research synthesis documents (the "From UI Demo to a Real Agent Spine" implementation plan + the "Foundation Document") into the 6-terminal autonomous loop cocktail. Every terminal references this doc on first session start.

**Source documents:**
- `docs/fusion/helios v6.1 [implementation].md` — engineering plan (12 repo deep-dives · `Executor` trait · MAS vs Pro hard line · 8-week roadmap)
- `docs/fusion/Epistemos V6_1 — Final Synthesis Lock (Attention as Interrupt).pdf` — V6.1 lock
- `docs/fusion/helios v6.2.md` — V6.2 delta (strict V6.1 superset)
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — Phases 1-7 (already in canon)
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — Phase 8 (already in canon)

**Status:** CANONICAL — read at session start for every terminal. Owner: Terminal C maintains. Cross-references: `docs/CANONICAL_DOC_INDEX_2026_05_16.md §4` adds this row.

---

## §1. What's NEW vs existing canon

The Cognitive Kernel + Cognitive DAG doctrines already canonize: unified Rust kernel · Hermes-in-Rust · WASM exec · in-process MCP · capability lattice · Sovereign Gate · AgentEvent ring · typed Merkle DAG · Macaroon capabilities · LoRA-light companions.

**This integration adds** (in priority order):

### §1.1 F-ULP-Oracle (W1) — the gate that freezes AnswerPacket schema

**THE Monday deliverable** per Foundation Doc Part X. AnswerPacket schema does NOT ship until F-ULP-Oracle passes. Disciplinary commitment: no claim envelope without a verified arithmetic floor.

Required artifacts:
- Vendor `oxieml` (cool-japan/oxieml, MIT) into `epikernel-eml-ir/` as path-dep submodule, READ-ONLY
- Vendor `eml-lean` (tomdif/eml-lean, claims 0-`sorry`; verify via `lake build` + `grep sorry`) into `epikernel-lean/vendored/`
- Land `morph_eval_reduced.metal v0.1` in `epikernel-kernel-pack/` — implement only `exp`, `ln`, and fused intrinsic `eml(x,y) = exp(x) − ln(y)` plus log-sampled stress-point harness
- ULP fixture in `epikernel-eml-ir/tests/ulp_oracle.rs`: 412k log-sampled points across `[2⁻¹⁵, 2¹⁵] × [2⁻¹⁵, 2¹⁵]` + 2,048 stress points (denormals · ±0 · ±∞ · NaN · branch cuts of `ln`)
- **Tolerance: ≤ 2 ULP fp16 in `[0.5, 2]`** · **Budget: < 90s wall-clock M2 Pro**
- Lean toolchain pin verification — current public Lean is 4.25.0 (2025-11-14); if locked stack's 4.29.1 doesn't resolve against `leanprover-community.github.io/mathlib4`, downgrade + document divergence

**Owner:** Terminal B Phase B.0 (NEW, precedes all other Wave J work)

### §1.2 EML operator + Stachowiak structure (theoretical anchor)

**Status:** P for Liouvillian-elementary universality (Odrzywołek arXiv:2603.21852); P for abelian-group + functional-inverse decomposition (Stachowiak arXiv:2604.23893); **OPEN for constant-free universal EML generator**.

`eml(x, y) = exp(x) − ln(y)` (principal branch over ℂ) + terminal `1` → grammar `S → 1 | eml(S, S)` generates every elementary function on the Liouvillian-solvable subdomain.

**Hard fence:** EML universality is over the Liouvillian-solvable subdomain ONLY. Smith's quintic counter-construction bounds every "EML for everything" claim. State in every EML publication.

**Hard fence:** EML is the strongest *computational* primitive for elementary functions; the **metric/connection (Levi-Civita)** is the strongest *physics-aligned* primitive. Don't conflate.

### §1.3 `Executor` trait — load-bearing abstraction (Terminal D Phase D.0, NEW)

Not currently in canon as such; should become the single per-provider abstraction:

```rust
#[async_trait::async_trait]
pub trait Executor: Send + Sync + 'static {
    type Credential: Send + Sync;
    fn provider_id(&self) -> &'static str;
    fn supports_streaming(&self) -> bool { true }
    fn supports_tool_use(&self) -> bool { true }
    fn supports_prompt_caching(&self) -> bool { false }

    async fn execute(
        &self,
        mission: MissionPacket,
        cred: Arc<Self::Credential>,
        cancel: tokio_util::sync::CancellationToken,
    ) -> Result<BoxStream<'static, ExecutorEvent>, ExecutorError>;
}
```

`MissionPacket` carries: `system_prompt · user_message · context_artifacts (RepoMap · VaultSlice) · tools · claim_kinds_allowed · gbnf_grammar · answer_packet_schema · max_tokens · temperature · deadline`.

`ExecutorEvent` is the streamed output: `Started · TokenDelta{channel: Reasoning|Final|ToolArgs} · ToolCallRequested · ToolCallResult · ClaimEmitted · AnswerPacketFinalized · Error · Cancelled · Completed`.

Implementations:
- `AnthropicExecutor` (~600 LoC hand-roll on `reqwest` + `eventsource-stream` + `tokio` + `serde`; **do NOT use Anthropic Agent SDK** — proprietary + bundles Claude Code CLI binary)
- `OpenAIExecutor` (use `async-openai = "0.30"`, last release 2025-10-20, actively maintained, supports `/v1/responses` via `client.responses().create()`)
- `GeminiExecutor` (use `genai = "0.5"` multi-provider crate OR hand-roll)
- `LocalMlxExecutor` (uses `mlx-rs = "0.21"` locked; dedicated OS thread for MLX work because mlx-rs arrays not safely Send across tokio tasks)
- `LocalLlamaCppExecutor` (fallback when F-LocalToolUse fails on MLX)
- `OllamaHttpExecutor` (localhost:11434 over HTTP)
- `LmStudioHttpExecutor` (localhost:1234 OpenAI-compatible)
- `CodexCliExecutor` (Pro only; uses `codex mcp-server` mode — verified supported)
- `ClaudeCodeCliExecutor` (Pro only; same MCP-server pattern)

**Owner:** Terminal D Phase D.0 (NEW, precedes all D.2 provider work)

### §1.4 Hybrid-SSM landscape + Granite-4.0-H-Micro routing

**Operational change:** Qwen3-8B-MLX-4bit ALONE degrades tool-use over 5+ rounds (mlx-lm issue #1011, verified). **F-LocalToolUse falsifier** is real and per-model.

**Routing rule:**
- `ClaimKind::ToolCall` → **Granite-4.0-H-Micro 3B 4-bit MLX** (Apache 2.0 · ISO 42001 · hybrid Mamba-2 + transformer · NoPE · 15T tokens · 128k validated context · top-tier on Berkeley Function-Calling Leaderboard v3 · MLX support confirmed)
- All other claim kinds → **Qwen3-8B-MLX-4bit** (Lane-E "mouth" / prose articulation)

**Dual-backend strategy:**
- Primary: `mlx-rs = 0.21` locked, features `["metal", "accelerate"]`
- Fallback: `llama-cpp-2` for GGUF Q4_K_XL when F-LocalToolUse fails

**Mamba-3** (arXiv:2603.15569 March 2026): exponential-trapezoidal discretization · complex-valued state for state tracking · MIMO formulation · RoPE-trick recurrence · +0.6-1.8 pts vs Gated DeltaNet at 1.5B. Research-tier Terminal B.

**Falcon-Mamba 7B** (arXiv:2410.05355): pure SSM · 5.8T tokens · Open LLM Leaderboard #1 SSLM at release. Pro-tier alternative.

**Phi-4-mini-flash** (arXiv:2507.06607): SambaY decoder-hybrid-decoder · GMU · up to 10× decoding throughput · 64k context. Inspiration.

**Owner:** Terminal D adds Granite as D.2.8 (new provider); Terminal B handles Mamba-3 research as Phase B.1 J10.

### §1.5 Hybrid-SSM + attention-as-interrupt thesis (Terminal B research)

The V6.1 thesis:
```
u_t = α·H_t + β·WBO_t + γ·Sheaf_t + δ·ToolNeed_t + ε·ConnectomeAlarm_t
```

- `H_t` — token-level entropy of SSM head distribution
- `WBO_t` — WBO-7 master-inequality signal (UST-1.5 bookkeeping)
- `Sheaf_t` — patch-bounded `H⁰(G, F)` violation rate from cellular sheaf inference layer
- `ToolNeed_t` — GBNF grammar / ClaimKind dispatch gate
- `ConnectomeAlarm_t` — Goodfire-component-level activation against learned alarm set

When interrupt-logic fails: emit `STATIC_FALLBACK_ACKNOWLEDGED` ClaimKind → Residency Governor switches to fixed 9:1 SSM:attention ratio. **Honest audit-traced operating mode, not hidden fallback.**

**F-Interrupt-Calibration:** 30-task corpus, AUROC ≥ 0.85 on hand-labeled "interrupt-needed" set. Terminal B Phase B.6.x.

### §1.6 Repo deep-dive ports (Terminal D Phase D.7-D.10, NEW)

**SWE-agent ACI** (Princeton/Stanford SWE-agent, MIT, mini-SWE-Agent = 100 lines / 65% SWE-bench Verified): port the tool bundle verbatim, ~1 week:
- `file_viewer` (windowed scroll · LM-shaped output)
- `str_replace_editor` (line-anchored · syntax-checked)
- `bash` (persistent shell · sandboxed XPC helper in MAS via `app-sandbox + inherit + user-selected.read-write`)
- `search_file` / `search_dir` (LM-shaped output)
- Interactive Agent Tools (IATs) for debuggers without blocking main shell

**Aider repo-map** (Apache 2.0, 41k★+): port to `epikernel-repomap`, ~1 week:
- `tree-sitter` (Rust bindings 0.22+, `tree-sitter-rust` · `tree-sitter-python` · etc.)
- `petgraph::algo::page_rank` (built-in)
- Per-language `tags.scm` queries for `name.definition.*` / `name.reference.*`
- Cache in SQLite by mtime
- Emit as `TypedArtifact::RepoMap`

**Goose architecture** (Apache 2.0, Linux Foundation hosted): port the architecture, NOT the binary:
- `Provider` trait pattern from `providers/base.rs` → becomes basis for `Executor` trait above
- `goose-mcp` crate layout (in-process for built-ins · subprocess for external)
- Sessions-as-event-log (post-threads refactor)
- ACP (Agent Client Protocol) layer for bidirectional Client+Server

**OpenHands** (MIT, V1 SDK arXiv:2511.03690): port the EventLog reducer model, NOT the Docker:
- `Action` → `AgentEvent::Action`
- `Observation` → `AgentEvent::Observation`
- `Condenser` → `RunEventLog::compact_with_summary(model)` method
- Synchronous conversation loop with opt-in sandbox

**Plandex** (Apache 2.0, Go): copy the data model, NOT the Go code:
- Plans = first-class persistent objects with branches · diff-stages · rollback graph
- Maps to `TypedArtifact::Plan` with `PlanStage` children and `branch_of` edges

**Codex CLI** (Apache 2.0, Rust): already-Rust — vendor `codex-core` as dependency OR learn line-by-line:
- `SandboxPolicy` → CLI args → helper-binary subprocess pattern
- macOS Seatbelt sandbox · Linux Landlock + seccomp
- Functions as MCP server via `codex mcp-server` — clean Pro-tier integration

**Anthropic Agent SDK** (proprietary): DO NOT port. Re-implement the 600-LoC loop:
- `messages.create` → if `stop_reason == "tool_use"` → execute tool → append `tool_result` → loop

**DROP entirely:** OpenManus (unverifiable community Manus clone) · Cline / Continue (UX templates only, study don't port)

### §1.7 Hard-line MAS = API-only (Terminal A §0 sharpening)

**Verdict from implementation doc Part VI:** No CLI bridge ships in MAS, no exceptions, including security-scoped bookmarks.

Why:
1. `com.apple.security.app-sandbox = YES` required for MAS
2. Subprocess via `NSTask`/`posix_spawn` from sandboxed parent MUST inherit sandbox with exactly `app-sandbox + inherit` — any third sandbox-class entitlement aborts child
3. Inherited child cannot read user-installed binaries outside bundle
4. Even bundled helper running user-supplied `/usr/local/bin/codex` requires security-scoped bookmark + reliably rejected by App Review for non-Developer-Tools categories

**Ship two builds:**
- **MAS build** (`cfg(feature = "mas")`): compiles out `CodexCli` and `ClaudeCodeCli` variants from `AgentProvider`; UI hides them; all other providers (Anthropic · OpenAI · Gemini · LocalMLX · LocalLlamaCpp · Ollama · LM Studio) work (Ollama is separate process user runs, app does HTTP only)
- **Pro / Developer-ID build** (`cfg(feature = "pro")`): Hardened Runtime + notarization · no sandbox · `CodexCli` + `ClaudeCodeCli` enabled · entitlements `cs.disable-library-validation` (if codex needs dynamic loading) + `cs.allow-jit` (if MLX needs)

**Bash-tool subprocess in MAS:** legal path = bundled XPC helper with `app-sandbox + inherit + user-selected.read-write` for user-picked workspace folder. SWE-agent ACI `bash` tool ships in MAS via this pattern.

**Owner:** Terminal A sharpens §0 immutable rule 6 to make this explicit.

### §1.8 Research-tier theorem hunts (Terminal B Wave J extensions)

Publishable side-quests with M2-Pro-runnable falsifiers:

| Theorem | Falsifier | Budget | Publishable target |
|---|---|---|---|
| **T-EML-IR-Lowering** — every elementary expr compiles to EML preserving extensional equivalence | F-EML-Basis-Recovery (compile exp/log/+/−/×/÷/sin/cos/sqrt; verify vs fp64 on ≥10⁶ points) | <30 min CPU | MLSys 2026 / POPL 2026 |
| **T-EML-Normal-Form** — Stachowiak abelian-group + functional-inverse canonical normal form preserved by all passes | F-EML-Normal-Form (round-trip > 95% canonical library) | <1 day CPU | Journal of Symbolic Computation |
| **T-Action-to-EML** — Lagrangians lower to EML preserving Euler-Lagrange | F-Action-Demo (harmonic oscillator + simple pendulum + Lean-verified conservation) | <1 day CPU + Lean | Journal of Symbolic Computation — **the killer demo** |
| **T-Tropical-Affine** — minimal tropical-affine basis approximates ReLU NN class within bounded error | F-Tropical-Side-Quest (depth ≤4, hidden ≤64, ε-bounded approx drift) | 4h Metal | NeurIPS 2026 / ICML 2026 — **best near-term publishable side-quest** |
| **T-Geometric-Lowering** — metric/connection data lowers preserving geodesic + parallel-transport | F-Geo (2D Riemannian surface · geodesic integrator · parallel-transport drift bound) | <1 day | Journal of Geometry & Physics |
| **T-Sparse-Active-Assembly** — defined sparse subset reproduces dense execution within bounded drift | F-Sparse-Runtime-Split (Granite 3B 4-bit · ≤5% logit-KL on 1000-prompt suite) | 1 week | ICLR 2027 |
| **T-Lean-Schema-Authority** — Lean = single source of truth for IR schema + proof obligations + ClaimLedger | F-Lean-End-to-End (one theorem family · Rust type · Swift type round-trip) | 2 weeks | CAV / TACAS |
| **T-Substrate-Independence** — BZ + sandpile + Kuramoto match silicon-LLM AR(1) Hadamard residual variance bound | F-BZ-Substrate-Independence (≤$250 BZ kit · pre-registered KL envelope) | research-tier | Foundations of Physics / PRL |

### §1.9 Additional research-tier anchors (Terminal B references)

- **Test-Time Regression** unification (Wang-Shi-Fox arXiv:2501.12352, v3 2025-05-02) — unifies linear attention · SSMs · fast-weight programmers · online learners · softmax attention as test-time regression parameterized by `(regression weights, regressor function class, optimization algorithm)`. Strongest public theoretical anchor for `LatticeCoder + TestTimeRegressor` traits.
- **DoRA** (Liu et al. arXiv:2402.09353, ICML 2024 Oral) — magnitude/direction weight decomposition · right PEFT primitive for M2 Pro fine-tuning.
- **`Para(Lens(Smooth))`** (Cruttwell-Gavranović-Ghani-Wilson-Zanasi arXiv:2103.01931 + arXiv:2404.00408) — bicategory with 1-cells = parameterized lenses `(P, f, f*)` · 2-cells = reparameterizations · **1:1 correspondence with Rust trait** `Para<P, A, B> { fn fwd(p: P, a: A) -> B; fn rev(p: P, a: A, db: B) -> (P, A); }`.
- **Metriplectic 4-bracket** (Morrison-Updike Phys Rev E 109 045202 / arXiv:2306.06787 + Zaidni-Morrison arXiv:2501.00159) — Hamiltonian + entropy from one curvature-like 4-bracket. T-Metriplectic-Scheduler (C) — Hamiltonian = compute resource · entropy = dissipation · provable fairness.
- **Sheaf-cohomological inference** (Bodnar arXiv:2202.04579 + Hansen-Ghrist arXiv:1808.01513) — patch-bounded `H⁰(G, F)` runtime consistency check feeding `Sheaf_t` in interrupt-score.
- **RWKV-7 "Goose"** (arXiv:2503.14456, 2.9B Apache 2.0) — generalized delta rule with vector-valued gating · recognizes all regular languages · exceeds TC⁰ · constant-memory RNN.
- **Titans-MAC** (Behrouz-Zhong-Mirrokni arXiv:2501.00663) — Memory-as-Context + Memory-as-Gate + Memory-as-Layer · long-term memory MLP that updates weights at test time using gradient-of-surprise.
- **PageIndex** (apache-2.0) — ToC-tree reasoning RAG · 98.7% FinanceBench.

### §1.10 Honest caveats from the docs

State these in every relevant publication / claim:

1. **EML universality is on the Liouvillian-solvable subdomain only.** Smith's quintic counter-construction bounds every "EML for everything" claim.
2. **Metric/connection (Levi-Civita) is the strongest physics-aligned primitive** — stronger than EML for physics. Don't conflate.
3. **Apple MSL §6.5.4 ≤2-ULP claim is empirical-only** — F-ULP-Oracle is the empirical evidence the project generates.
4. **M2 Pro 16 GB is hard constraint.** Sparse-runtime split must fit two-path inference in <14 GB working set; large-context tests use 4-bit; BZ harness CPU only.
5. **Goodfire numerics:** 67M / 28M / 38,912 rank-1 subcomponents are verified ✅. Older citations of 9972 / 205 / 2.1% NOT corroborated in public sources — re-verify against `goodfire-ai/spd` source files before external citation.
6. **Monnerot eml★** (12-plane bundle conjugate density extension) — no web-verifiable arXiv ID — DROP-to-conditional. Treat as inspiration only.
7. **Lean toolchain pin** (4.29.1 / mathlib v4.29.0-rc6 / LeanCopilot 4.27.0) may be ahead of public. Latest verifiable Lean: 4.25.0 (2025-11-14). Downgrade if 4.29.x doesn't resolve.
8. **Bentov / Phase Calculus / PCop / QBL / VDM / RHQ / "1.1 MB seed"** — DROP unless independently verified.
9. **eml★ Monnerot extension** — DROP-to-conditional; do not cite; do not condition falsifiers on it.
10. **Single-2-cell quantum Sheffer stroke for ZX/ZH** appears OPEN. Beyond 8-week horizon.
11. **Single-generator Clifford universality** — OPEN, almost certainly hard. Park as inspiration.
12. **Single-primitive Krohn-Rhodes** — DROP-as-novel (already-decomposed territory).

### §1.11 Cargo workspace updates (Terminal D + B coordination, lockstep)

New crates to land per B2-M15 lockstep rule (`Cargo.toml` + `docs/legal/licenses.md` + HERMES §6.1 + FEATURE_CHANGE_TRACKER, same commit):

```toml
[workspace]
members = [
  # ... existing ...
  "epikernel-executor",      # Executor trait + MissionPacket + ExecutorEvent
  "epikernel-eml-ir",        # vendors oxieml read-only via path = "../oxieml"
  "epikernel-lean",          # Lean → Rust extraction surface; vendors eml-lean
  "epikernel-mlx",           # LocalMlxExecutor with dedicated-thread isolation
  "epikernel-anthropic",     # AnthropicExecutor ~600 LoC
  "epikernel-openai",        # OpenAIExecutor via async-openai 0.30
  "epikernel-gemini",        # GeminiExecutor via genai 0.5 OR hand-roll
  "epikernel-llamacpp",      # LocalLlamaCppExecutor fallback
  "epikernel-mcp",           # rmcp-consumer MCP runtime per Goose pattern
  "epikernel-repomap",       # tree-sitter + petgraph PageRank → TypedArtifact::RepoMap
  "epikernel-tools-aci",     # SWE-agent ACI tool bundle
  "epikernel-plan",          # Plandex plan-as-data
  "epikernel-codex-bridge",  # Pro-only Codex CLI as MCP server
  "epikernel-kernel-pack",   # Metal kernels (morph_eval_reduced.metal)
  "epikernel-scope-rex",     # MutationEnvelope governor
  "epikernel-hermes",        # External executor across XPC trust boundary
  "epikernel-claims",        # AnswerPacket + ClaimKind + GBNF grammar
  "epikernel-substrate",     # LatticeCoder + TestTimeRegressor traits
]

# Locked
mlx-rs = "=0.21.0"           # features = ["metal", "accelerate"]
async-openai = "=0.30"
genai = "=0.5"
reqwest = "*"
eventsource-stream = "*"
tokio = "*"
serde = "*"
async-trait = "*"
tokio-util = "*"
tree-sitter = "*"
petgraph = "*"
objc2-metal = "*"
uniffi = "=0.28"
```

### §1.12 L3 SSD Oracle / F-KV-Direct-Gate (memory architecture floor, NEW Phase B.0-KV)

**The other half of the "Verified Floor" pattern.** F-ULP-Oracle (§1.1) gates the arithmetic floor; **F-KV-Direct-Gate** gates the memory-architecture floor. Together they bound the substrate Epistemos rests on.

**The bottleneck this solves:** local AI on M2 Pro 16 GB hits a wall around 32k context because the KV cache for an 8B model at 128k eats 4-8 GB of RAM on top of the model (~5GB) + macOS overhead (~2GB) + app + browser. Without SSD spill, 128k context thrashes on 16GB hardware.

**The architectural answer (L3 SSD Oracle):**

```
L0  RAM hot          ─ current attention pattern working set
L1  RAM compressed   ─ Sherry 1.25-bit 3:4 sparsity (Huang arXiv:2601.07892)
L3  SSD Oracle       ─ NF4 IOSurface mmap, file-backed       ← THIS LAYER
L5  Network Cascade  ─ cloud fallback for rarest queries
L_SE Self-Evolving   ─ Titans-MAC + SEAL-DoRA nightly LoRA
```

Three Apple-Silicon-specific techniques stacked:
1. **NF4 quantization** (QLoRA lineage) — 4-bit NormalFloat for KV cache · 4× compression
2. **IOSurface zero-copy** — Apple's GPU/CPU/ANE shared-memory framework · no copy overhead
3. **mmap-backed KV pages on SSD** — macOS virtual memory pages into RAM as needed; SSD = authoritative full-precision oracle

**The research claim being tested:** KV-Direct (Qasim et al. arXiv:2603.19664) — *the residual stream is bit-identical sufficient*. Means: keep most KV cache cold on SSD; swap in small residual deltas to reproduce model output AS IF the full KV were hot.

**Substrate state (verified 2026-05-16):**
- ✅ `Epistemos/Shaders/kv_direct_gate.metal` (65 LOC) — Tier-1 BIT-IDENTICAL contract shader, landed commit `99cab68c1` (HELIOS-V5-W6+W7+W8) · refined commit `b970f98fe`
- ✅ `agent_core/src/scope_rex/kv/direct_gate.rs` (290 LOC) — Rust reference with `direct_path_eligible()` predicate + 7 eligibility tests
- ✅ `agent_core/src/scope_rex/kv/mod.rs` — module entry registered
- ❌ End-to-end harness — **NOT-STARTED** (this is what Phase B.0-KV ships)

**Owner:** Terminal B Phase B.0-KV (NEW, parallel to B.0 EML work — different shaders/Rust/tests, both can verify on same iter if cargo budget allows).

**The gate experiment:**

| Setup | Spec |
|---|---|
| Model | Qwen3-8B-MLX-4bit |
| Context | 128k tokens |
| Test corpus | 100 prompts (25 long-prefix recall · 25 multi-turn · 25 code-completion · 25 reasoning) |
| Reference path | Full-RAM KV cache via existing `scope_rex/kv/` |
| Test path | Residual-patched output via mmap-backed NF4 KV (synthetic SSD spill OK for gate) |
| Measurement | D_KL between reference + residual-patched logit distributions |
| **Threshold** | **D_KL < 0.05 nats** averaged across suite |
| Budget | ≤ 30 min wall-clock on M2 Pro |

**Pass case:** L3 SSD Oracle implementation track unblocks (Phase B.6.21 new). **128k context shippable on consumer 16GB Macs without cloud, no quality loss.** MAS-compatible (mmap + IOSurface = sandbox-friendly · NF4 = no special entitlement · all math in-process MLX-Swift). Total path to MAS-shippable L3: 8-16 weeks.

**Fail case:** still publishable result ("KV-Direct doesn't generalize to Qwen3-8B-MLX-4bit at 128k"). Pivot to softer eviction:
- Selective cold-region purge by attention-frequency
- Prefix caching for system + persistent context
- Attention-sink preservation per Streaming-LLM (arXiv:2309.17453)
- Sliding-window attention with bounded historical KV

**Risk surface to track:**
- KV-Direct paper validated on different hardware/models — Qwen3 generalization is empirical conjecture
- SSD wear concerns: consumer NVMe is 600-1200 TBW; aggressive spill/reload could prematurely age the drive → mitigation via write-coalescing + tier policy that keeps hot KV in RAM
- SSD↔RAM bandwidth gap (~5GB/s vs ~200GB/s on M2 Pro PCIe 4.0 vs LPDDR5-6400) → mitigation via prefetch + speculative load + attention-pattern prediction
- MLX-Swift internals — KV cache layout is mlx-rs internal; may need upstream contribution or fork at `LocalPackages/mlx-swift-lm/`
- Apple Intelligence convergence — Apple's on-device model may ship competing memory-spill techniques first

**Why this pairs with F-ULP-Oracle:** both are **empirical verification gates** for foundational substrate claims. F-ULP-Oracle verifies Apple's Metal `exp`/`ln` accuracy spec (≤2 ULP); F-KV-Direct-Gate verifies the Qasim et al. residual-sufficiency claim. Neither trusts the spec or paper without local empirical evidence. **Verification-native engineering.**

**Status tags:**
- Shader + Rust reference + eligibility predicate + tests = **EV** (verified in tree)
- Harness implementation = **EB** (engineering bet, 1-2 weeks focused work)
- D_KL < 0.05 nats on Qwen3-8B at 128k = **C** (conjecture; tested by the harness)
- L3 SSD Oracle MAS-shippable implementation = **C** (conditional on conjecture passing)
- Apple Intelligence convergence risk = **C** (market risk, not technical)

---

## §2. Per-terminal phase additions

### Terminal A — V1 ship (additions)

- **§0 immutable rule 6 sharpening**: MAS = API-only HARD LINE. No CLI bridge in MAS, no exceptions including security-scoped bookmarks. Two builds: MAS (`cfg(feature = "mas")`) + Pro Developer-ID (`cfg(feature = "pro")`).
- **Phase A.x addition**: Anthropic API hand-roll path verification — Anthropic Agent SDK is proprietary + bundles Claude Code CLI binary; we re-implement the 600-LoC loop on `reqwest` + `eventsource-stream`.
- **§0 addition**: every shipped feature ships via the `Executor` trait (Terminal D's Phase D.0) as the single abstraction surface.

### Terminal B — post-V1 + research (Phase B.0 NEW + multiple research additions)

**Phase B.0 (NEW — precedes all Wave J)**: F-ULP-Oracle (W1)
- B.0.1: Vendor `oxieml` into `epikernel-eml-ir/` as path-dep submodule, read-only
- B.0.2: Vendor `eml-lean` into `epikernel-lean/vendored/`, verify `0 sorry` via `lake build` + grep
- B.0.3: Land `morph_eval_reduced.metal v0.1` (only `exp`, `ln`, fused `eml(x,y)` intrinsic)
- B.0.4: Land ULP fixture in `epikernel-eml-ir/tests/ulp_oracle.rs` (412k log-sampled + 2048 stress)
- B.0.5: Verify Lean toolchain pin against public mathlib
- B.0.6: **GATE — AnswerPacket schema freeze blocked until B.0.4 passes**

**Phase B.1 J-tier additions:**
- J10 Mamba-3 (arXiv:2603.15569) — exponential-trapezoidal · complex-state MIMO · RoPE-trick
- J11 Test-Time Regression unification (arXiv:2501.12352) — theoretical anchor for `LatticeCoder + TestTimeRegressor`
- J12 RWKV-7 "Goose" (arXiv:2503.14456) — vault candidate
- J13 Titans-MAC (arXiv:2501.00663) — long-term memory MLP
- J14 DoRA (arXiv:2402.09353) — PEFT primitive for M2 Pro fine-tuning

**Phase B.6 additions (NOT-STARTED inventory extensions):**
- B.6.15 Tropical-affine completeness for ReLU (T-Tropical-Affine, F-Tropical-Side-Quest)
- B.6.16 Action-to-EML / Lean-verified Euler-Lagrange (T-Action-to-EML, F-Action-Demo — "killer demo")
- B.6.17 Substrate-independence (T-Substrate-Independence, F-BZ-Substrate-Independence)
- B.6.18 DoRA PEFT primitive
- B.6.19 `Para(Lens(Smooth))` ↔ Rust trait correspondence (arXiv:2103.01931 + arXiv:2404.00408)
- B.6.20 Hybrid-SSM + attention-as-interrupt thesis calibration (F-Interrupt-Calibration · 30-task corpus · AUROC ≥ 0.85)

**Phase B.2 (Helios kernels) update:**
- Add `morph_eval_reduced.metal` as B.2.0 (already in B.0)
- `SemiseparableBlockScan.metal` aligns to cartesia-metal reference for Mamba-2 SSD
- F-128K-Recall validated against Granite-4.0-H-Micro's *validated* 128k window (not theoretical 512k)

### Terminal C — audit (CANONICAL_DOC_INDEX additions)

Add to `docs/CANONICAL_DOC_INDEX_2026_05_16.md §4`:
- `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md` — THIS doc, read at session start
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — Phases 1-7 kernel doctrine
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — Phase 8 typed Cognitive DAG

### Terminal D — providers + tools + MCP (Phase D.0 NEW + D.7-D.10 NEW)

**Phase D.0 (NEW — precedes D.1)**: `Executor` trait formalization
- D.0.1: Land `epikernel-executor` crate with `Executor` trait + `MissionPacket` + `ExecutorEvent`
- D.0.2: `MissionPacketBuilder` from `AgentDefinition`
- D.0.3: `ExecutorRegistry::resolve(&AgentProvider)` dispatch
- D.0.4: `CredentialVault::load_for(&AgentProvider)` Keychain integration
- D.0.5: `AgentRunController::start(agent_def, user_msg)` lifecycle

**Phase D.2 update** — refactor providers as `Executor` implementations:
- D.2.1 Anthropic → `AnthropicExecutor` (~600 LoC hand-roll · NOT the proprietary SDK)
- D.2.2 OpenAI → `OpenAIExecutor` via `async-openai = "0.30"`
- D.2.3 Gemini → `GeminiExecutor` via `genai = "0.5"` OR hand-roll
- D.2.4 Kimi → `KimiExecutor` (existing)
- D.2.5 Codestral → `CodestralExecutor` (existing per current loop work)
- D.2.6 OpenRouter → `OpenRouterExecutor`
- D.2.7 Together AI → `TogetherExecutor` (existing per current loop work)
- D.2.8 (NEW) Granite-4.0-H-Micro → `LocalMlxExecutor::granite_h_micro` — tool-use-reliable backbone routing for `ClaimKind::ToolCall`
- D.2.9 (NEW) Qwen3-8B-MLX-4bit → `LocalMlxExecutor::qwen3_8b` — Lane-E "mouth" routing for prose
- D.2.10 (NEW) Falcon-Mamba 7B → `LocalMlxExecutor::falcon_mamba` (Pro alternative)
- D.2.11 (NEW) Mamba-3 → `LocalMlxExecutor::mamba3` (research-tier)
- D.2.12 (NEW) Ollama HTTP → `OllamaHttpExecutor`
- D.2.13 (NEW) LM Studio HTTP → `LmStudioHttpExecutor`

**Phase D.7 (NEW)**: SWE-agent ACI tool bundle (`epikernel-tools-aci` crate)
- D.7.1 `file_viewer` (windowed scroll)
- D.7.2 `str_replace_editor` (line-anchored syntax-checked)
- D.7.3 `bash` (XPC sandboxed helper for MAS · `app-sandbox + inherit + user-selected.read-write`)
- D.7.4 `search_file` / `search_dir` (LM-shaped output)
- D.7.5 Interactive Agent Tools (IATs) for debuggers

**Phase D.8 (NEW)**: Aider repo-map (`epikernel-repomap` crate)
- D.8.1 `tree-sitter` integration for each language
- D.8.2 `petgraph::algo::page_rank` symbol-graph ranking
- D.8.3 `tags.scm` queries for `name.definition.*` / `name.reference.*`
- D.8.4 SQLite cache by mtime
- D.8.5 Emit as `TypedArtifact::RepoMap`

**Phase D.9 (NEW)**: Plandex plan-as-data (`epikernel-plan` crate)
- D.9.1 `TypedArtifact::Plan` with `PlanStage` children
- D.9.2 `branch_of` edges for plan branches
- D.9.3 Diff-stages + rollback graph

**Phase D.10 (NEW)**: Dual-backend MLX strategy
- D.10.1 `mlx-rs = 0.21` primary path with dedicated-thread isolation (mlx-rs arrays not Send-safe across tokio tasks)
- D.10.2 `llama-cpp-2` fallback for F-LocalToolUse failures
- D.10.3 Per-model F-LocalToolUse test — verify each MLX checkpoint maintains tool-use across 5+ rounds; switch to GGUF Q4_K_XL if fails

### Terminal E — user-decision research (NEW items)

**Phase E.6 additions:**
- E.6.3 Granite-4.0-H-Micro vs Qwen3-8B routing decision — for ClaimKind::ToolCall: confirm Granite; for prose: confirm Qwen3. Default per Foundation Doc but needs user sign-off.
- E.6.4 MLX vs llama-cpp-2 dual-backend decision — dual-backend recommended; confirm per-model fallback threshold.
- E.6.5 Anthropic hand-roll vs SDK decision — hand-roll recommended (SDK is proprietary + bundles CLI binary); confirm.
- E.6.6 Lean toolchain pin decision — verify 4.29.1 resolves; if not, downgrade to latest stable (4.25.0).
- E.6.7 EML-IR vendoring decision — confirm `oxieml` MIT + `eml-lean` 0-sorry path-dep submodule strategy.

### Terminal F — external integrations (Phase F.7-F.8 NEW)

**Phase F.7 (NEW)**: Codex CLI as MCP server (Pro tier)
- F.7.1 `epikernel-codex-bridge` crate (Pro-only · `cfg(feature = "pro")`)
- F.7.2 `codex mcp-server` mode integration
- F.7.3 MCP-over-stdio protocol loop emitting `ExecutorEvent`
- F.7.4 Tests: tool list cache · ping batching · cross-process call latency

**Phase F.8 (NEW)**: Claude Code as MCP server (Pro tier) + ACP layer
- F.8.1 `claude-code mcp-server` mode integration (same pattern as F.7)
- F.8.2 ACP (Agent Client Protocol) layer per Goose's bidirectional Client+Server framing
- F.8.3 Treat Codex CLI / Claude Code as upstream "provider" agents over ACP

---

## §3. Order of operations (Monday-onward)

1. **Monday**: Terminal B Phase B.0 — F-ULP-Oracle (W1). Vendor oxieml + eml-lean. Land `morph_eval_reduced.metal v0.1` + ULP fixture. Pass within <90s wall-clock M2 Pro. **GATE: AnswerPacket schema freeze blocked until this passes.**
2. **Tuesday-Wednesday**: Terminal D Phase D.0 — `Executor` trait + `MissionPacket` + `ExecutorEvent`. Terminal D Phase D.2 refactor (existing providers become `Executor` impls).
3. **Thursday-Friday**: Terminal D Phase D.2.8 — Granite-4.0-H-Micro `LocalMlxExecutor` + F-LocalToolUse verification. Terminal D Phase D.7 — SWE-agent ACI tool bundle start.
4. **Week 2**: Terminal D Phase D.8 — Aider repo-map. Terminal F Phase F.7 — Codex CLI as MCP server.
5. **Weeks 3-4**: Terminal B Phase B.6.15 — Tropical-affine theorem hunt. Terminal B Phase B.6.16 — Action-to-EML killer demo.
6. **Weeks 5-8**: Terminal B Wave J research-tier hunts. Terminal D Phase D.10 — dual-backend MLX hardening.

---

## §4. Cross-references

- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — Phases 1-7 (the unified Rust kernel)
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` — Phase 8 (typed Cognitive DAG)
- `docs/fusion/helios v5 first.md` + `helios v5 updated.md` — V5 substrate (LANDED 2026-05-06)
- `docs/fusion/helios v6.2.md` — V6.2 strict V6.1 superset
- `docs/CANONICAL_DOC_INDEX_2026_05_16.md` — master doc TOC
- `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md` — 6-terminal flow
- `docs/HARDENING_TRACKER_2026_05_16.md` — Phase 2 hardening per shipped feature
- `docs/FEATURE_CHANGE_TRACKER_2026_05_16.md` — same-commit lockstep checklist
- All 6 `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_*_2026_05_16.md` prompts

---

*Living integration doc. Owner: Terminal C maintains. Read at session start per each prompt's §3 mandatory reading. Updates require Terminal C audit-of-audit cycle to surface drift.*
