# QUICK CAPTURE — Implementation Plan

**Status**: Master plan for Waves 0–5 (substrate + agent runtime). Created 2026-04-28. Updated 2026-04-28 (R2 + R3 + R4 + R5 + audit merge).
**Canon**: this doc is canonical for Waves 0–5 only. The unified architecture canon — Live File Compiler, Reflective Loop, Cognitive Weight class system, BrowserEngine trait, corrected wave sequencing — lives at `~/Documents/Epistemos-QuickCapture/FINAL_SYNTHESIS.md` and wins all conflicts. Read that first; this plan after.
**Owner**: Single building agent (one-shot continuous session preferred).
**Scope**: Hybrid JSON+Markdown memory/soul/skill formats; deterministic multi-variant tool schemas; grammar-constrained local-model tool calling via MLX-Structured (primary) / LM-Format-Enforcer / llguidance (fallbacks); four-variant auto-structure routing pipeline with `place | merge_into_existing_note | create_folder | defer` action enum; self-healing Try-Heal-Retry loop; LSFS + Spotlight + Vision OCR native skills; ephemeral local inference on MLX-Swift; per-model engineering catalog (Qwen 2.5 family, Hermes-3, Phi-3.5, Llama 3.2, embedding/NLI/ASR specialists); tool-call format normalizer (Hermes XML / Qwen JSON / OpenAI / Claude); Model Workspace Protocol orchestration; Intent-to-Effect state pattern with universal undo; observability stack; minimalist capture surface; trust-mechanism action-trace UI.

**This is the canonical Wave 0–5 reference for Quick Capture.** The R2/R3/R4 delta brief at `~/.claude/plans/gleaming-jingling-thimble.md` is plan-mode scratch and is **superseded by this document**. Do not read it; everything Wave-0–5 is here. Wave 6+ corrections (substrate / Live Files / deliberation / biometric / Tamagotchi / Brain Export) live in the `~/Documents/Epistemos-QuickCapture/` canon and override any framing here that conflicts with them.

The plan integrates four rounds of research (R1 original, R2 architectural blueprint, R3 multi-variant runtime synthesis, R4 model+citation grounding with per-model engineering) plus a self-audit pass that surfaced 12 shippability gaps. Citations to the literature are inline; arxiv numbers and GitHub repos are kept verbatim so the building agent can fetch them.

---

## 0. Building-Agent Protocol — READ FIRST

The agent implementing this plan **MUST** follow this protocol on every phase. Skipping it is the single biggest source of failed implementations in this codebase.

### 0.1 Pre-implementation research — mandatory

Before touching any code in any phase, the agent must:

1. **Read the relevant on-disk research docs in full** (the list in §0.2 is exhaustive — read every doc tagged for the current phase, not the highlights).
2. **Run a web search** for the most recent (2025–2026) state of the art on the specific subsystem being built. Required searches per phase:
   - Phase 1 (memory format): "JSON frontmatter markdown hybrid 2026", "JSON Schema 2020-12 streaming validation Rust", "soul file format LLM agent identity".
   - Phase 2 (GBNF + schemas): "llguidance 2026", "Outlines structured generation", "Hermes-3 function calling eval", "JSON Schema constrained decoding pushdown automaton".
   - Phase 3 (auto-route): "LLM semantic file system 2026", "folder routing embeddings 2026", "concept canonicalization Tana supertag", "TRACER learning to defer".
   - Phase 4 (self-heal): "ReAct Reflexion self-healing agent 2026", "circuit breaker pattern Rust async".
   - Phase 5 (LSFS/Spotlight/Vision): "NSMetadataQuery Spotlight programmatic 2026", "VNRecognizeTextRequest accuracy benchmark 2026".
   - Phase 6 (local inference): "llama.cpp Metal Apple Silicon benchmark 2026", "MLX-Swift unload model VRAM 2026", "speculative decoding draft model 2026".
   - Phase 7 (MWP): "filesystem-based agent orchestration 2026", "model workspace protocol".
3. **Re-read this plan's relevant section in full** before writing code. The schemas here are normative; do not freelance them.
4. **Write a 1-paragraph implementation note** in the phase's verification block (§14) summarizing what you read and what changed your mind.

If a web search returns information that contradicts this plan, **stop and surface the contradiction** to the user before proceeding. Do not silently diverge.

### 0.2 Disk research index — read these before coding

Sorted by relevance:

| Doc | When to read |
|---|---|
| `docs/EPISTEMOS_FUSED_v3.md` | Phase 0, 1, 12 — the master spec context |
| `docs/AGENT_PROGRESS.md` | Phase 0 — current state of the agent system |
| `docs/agent-system/AGENT_ARCHITECTURE.md` | All phases — non-negotiable structural constraints |
| `docs/HERMES_INTEGRATION_RESEARCH.md` | Phases 2, 6, 7 — local-model tool calling reality |
| `docs/INSTANT_RECALL_ARCHITECTURE.md` | Phases 3, 5 — recall pipeline grounding |
| `docs/IMPLEMENTATION_BLUEPRINT.md` | Phase 0 — prior blueprint conventions |
| `docs/HARDENING_VERIFICATION.md` | All phases — hardening checklist style |
| `docs/CONTROL_PLANE_RESEARCH.md` | Phase 7 — orchestration prior art |
| `docs/CUSTOM_TEXT_ENGINE_RESEARCH.md` | Phase 11 — UI surface integration |
| `docs/sprint-sessions/sprint-omega-1-foundation.md` | Phase 0 — foundation invariants |
| `docs/sprint-sessions/sprint-omega-5-living-vault.md` | Phase 5 — vault orchestration patterns |
| `docs/APP_ISSUES_AUTO_FIX.md` | All phases — known runtime bugs to avoid regressing |
| `CLAUDE.md` (project root) | Always — non-negotiable rules |
| Memory: `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md` and all linked files | Phase 0 — user intent and constraints |
| `~/.claude/plans/gleaming-jingling-thimble.md` | Phase 0 — full R2/R3/audit delta brief, Part D shows merge map |

### 0.3 Verification gates — non-negotiable

Each phase has explicit verification commands in §12. **A phase is not complete until its verification commands pass.** Do not advance. Do not mark complete in `docs/AGENT_PROGRESS.md`. Do not commit "in-progress" code that hasn't passed its gate.

### 0.4 Commit cadence

Commit after every phase passes verification. Never batch. Memory rule from the user: *"User lost massive work to git checkout. ALWAYS commit after each feature/fix. Never batch."*

---

## 1. Mission and Design Thesis

Epistemos becomes a knowledge environment where:

- **The user types a thought** (or speaks it, or pastes a screenshot) and the system **abstracts the concept, picks the right folder, files it, and proves what it did** — without any picker, modal, or confirmation dialog.
- **Every system instruction, every tool signature, every memory entry, every soul-file** is a **hybrid JSON+Markdown** artifact: the JSON half is schema-strict and machine-consumed by tools; the Markdown half is human-readable narrative and LLM-consumed as context. Neither half is optional. Neither half can drift from the other.
- **Every agent action is grammar-constrained at the logit level** via llguidance (Earley/PDA-based, JSON-Schema-native, ~50μs/token amortized overhead), so a 1.5B local model and Claude Opus produce structurally identical tool calls. Local-cloud parity is enforced by a single grammar derived from a single schema.
- **Every tool has a multi-variant fallback ladder** declared as static ordered list. Variant A fails → variant B → variant C → defer. The runtime walks the ladder; tool authors do not write retry logic. Every variant attempt passes a pre-flight `HealthCheck` (key present, model resident, breaker not open) before invocation, eliminating the silent-fallback-on-missing-credential failure mode.
- **Every error becomes a heal step**, not a user-facing failure. The Try-Heal-Retry loop captures stderr/schema-violation/empty-result and feeds it back to a diagnostic agent role with a corrected intent.
- **The filesystem is the substrate** — both for storage (durable, Finder-visible, no proprietary lock-in) and for orchestration (numbered folders + Markdown step files implement the Model Workspace Protocol).
- **Local models load just-in-time, execute in unified memory, and unload immediately.** No always-on inference daemon. No VRAM hoarding. The router model is the only persistently-loaded model, and it's tiny (1.5B).

### 1.1 Why no external MCP servers

Loading dozens of MCP tool schemas into the LLM's system prompt **degrades attention measurably** ("lost in the middle"), induces hallucinated parameters, and inflates token consumption. Tools live as compiled-in Rust skills with their schemas materialized into the prompt only when `meta.discover` selects them for the current step. Per-call token reduction can reach ~98% versus a "load everything" baseline. The catalog is the surface; `action.mcp_dispatch` (Pro-only) keeps MCP-as-peer for genuinely external systems.

### 1.2 The thesis in one sentence

**Immense complexity in the Rust core; nothing in the user's way.**

### 1.3 Local-first is not "local-only" but it is "local-default"

Cloud is a **bonus tier**, not the primary path. The default `model_select` route is local; cloud is invoked only when:

1. The user explicitly types `/cloud` in the AI input bar.
2. The user holds `⌥` while submitting (matches Cursor/Claude Desktop convention).
3. The local ladder has fully fallen through and the cloud path is the last variant in the ladder.
4. The task is provably outside local capacity — abstractive summarization >2000 output tokens, or research-grade multi-hop QA over a corpus the local model has not seen — AND the user has cloud-allowed in Settings.

In every other case the answer is **local**. The discipline of building this way forces the local path to be *better than cloud on the things that matter most* (tool-call shape, latency, privacy, throughput, offline). Cloud being a bonus is what makes the system survive a flight, a network outage, or a user without API keys. It is also what justifies the per-model engineering rigor in §6.6: if cloud were a primary fallback for shape correctness, none of the local engineering would matter.

The breakthrough in §17 is what makes this stance *honest*: the local path with grammar-bound dispatch is strictly more reliable than cloud on tool-call structural correctness, because cloud cannot mask logits at the user-side sampler.

### 1.4 No-LLM-first within the local path; no external services anywhere

Two further disciplines tighten "local-default" into an even harder stance:

**No-LLM-first.** Inside the local path, the variant ladder MUST start with a deterministic, non-LLM variant whenever one exists. The escalation order is strict:

```
deterministic Rust  →  embedding lookup / centroid match  →
small classical model (NLI, BERT, distilled)  →  small local LLM (1.5B–3B)  →
mid local LLM (7B–8B)  →  [cloud, only by §1.3 explicit opt-in]
```

Examples:
- `vault.search` Variant A is FTS5/Tantivy lexical; Variant B is embedding semantic; Variant C is RRF hybrid; only Variant D escalates to an LLM. The LLM never runs when the lexical hit set has ≥3 strong matches.
- `structure.route_capture` Variant A is centroid cosine (no LLM); Variant B is GBNF-classify; Variants C/D follow.
- `knowledge.cite_find` Variant A is embedding nearest-neighbour; Variant B is the deberta-v3-mnli NLI classifier (a 150MB classical model, not an LLM); Variant C is a local LLM with citations grammar; cloud only on explicit override.
- `knowledge.summarize` Variant A is extractive (TextRank, no LLM); Variant B is LLM abstractive; Variant C cloud only on long-output override.
- `vault.tag_infer` Variant A is regex over title; Variant B is KNN over tag-centroid embeddings; Variant C is LLM closed-vocab; D returns empty.

This pattern is enforced at code review: a tool that has an LLM as its first variant is rejected unless the author proves no deterministic predecessor exists.

**No external services.** The app does not depend on online SaaS for any feature on the hot path. Concretely:

- **No hosted auth, no Vercel-class deployment proxies, no SaaS telemetry, no online activation, no usage analytics dashboard, no remote feature-flag service, no third-party LLM router middleware.** All such infrastructure is excluded.
- **No localhost web servers** spun up by the app for IPC. Communication is UniFFI (Rust ↔ Swift) and, for the Pro orchestrator only, a stdin/stdout pipe to Hermes.
- **No background "phone-home" connections.** Network usage during a session is exactly: (a) cloud LLM calls when explicitly invoked per §1.3; (b) `capture.web_clip` when the user pastes a URL; (c) software updates checked at user request only. Nothing else.
- **No external MCP servers on the default install.** `action.mcp_dispatch` exists for Pro users who want to bridge to peer MCP servers they install — that's a *peer*, not a *backend*. The default install never reaches an MCP server it didn't ship with.
- **No auto-generated cloud accounts.** API keys are user-supplied through Settings and live in Keychain. The app never signs the user up for anything.
- **No ambient indexing of user data into anyone else's database.** Spotlight is OS-managed, on-device. Embedding indices are per-vault, on disk, not synced.

The mental model: **Epistemos is one Mac app, one Rust core, one optional subprocess (Hermes for Pro orchestration), and the macOS frameworks it's already entitled to use.** Nothing else. If a feature requires an external service, that feature is either (a) opt-in and documented or (b) not shipped.

This is the "negative app" mandate from §20.5 made concrete at the policy layer.

---

## 2. Hybrid JSON+Markdown File Formats

### 2.1 Why hybrid

JSON is what tools and the deterministic runtime consume — schema-validated, parseable, predictable. Markdown is what humans and LLMs consume as narrative — readable, embeddable, RAG-compatible. The historical mistake is picking one. The right answer is a fused format where both halves are first-class and bidirectionally linked.

This plan defines **three file types** that all use the hybrid approach with different fusion strategies.

### 2.2 The `.mem` format — single-file fusion (memory entries)

A memory entry — episodic, semantic, procedural, or note — is a single `.mem` file with JSON frontmatter and Markdown body:

```
---{"$schema":"epistemos://schemas/mem.v1.json","id":"01HX4...","type":"episodic","ts":"2026-04-28T14:32:11Z","actor":"user","tags":["routing","quick-capture"],"links":["c_4f2a","c_9b18"],"salience":0.62,"signals":{"access_count":3,"last_accessed":"2026-04-28T14:35:00Z"},"provenance":{"source":"capture.voice","device":"M4Pro"}}---

# Routing instinct on rematerialization captures

The system should treat **rematerialization** and **gradient checkpointing**
as canonical-equivalent. Picked up two captures yesterday that landed in
different folders before alias-table merge fired.

See: [[gradient-checkpointing]], [[concept-canonicalization]].
```

The header is **single-line, fenced by `---{...}---`** — this lets `head -1` extract the JSON without parsing Markdown, and `tail -n +2` extract the Markdown without parsing JSON. The format is line-oriented for incremental indexing. The `$schema` field is mandatory.

JSON Schema for `.mem` (Draft 2020-12, stored at `agent_core/schemas/mem.v1.json`):

```json
{
  "$id": "epistemos://schemas/mem.v1.json",
  "type": "object",
  "required": ["$schema", "id", "type", "ts"],
  "properties": {
    "$schema": { "const": "epistemos://schemas/mem.v1.json" },
    "id": { "type": "string", "pattern": "^[0-9A-HJKMNP-TV-Z]{26}$" },
    "type": { "enum": ["episodic", "semantic", "procedural", "capture"] },
    "ts": { "type": "string", "format": "date-time" },
    "actor": { "enum": ["user", "agent", "system"] },
    "tags": { "type": "array", "items": { "type": "string" }, "maxItems": 16 },
    "links": { "type": "array", "items": { "type": "string" }, "maxItems": 64 },
    "salience": { "type": "number", "minimum": 0, "maximum": 1 },
    "signals": {
      "type": "object",
      "properties": {
        "access_count": { "type": "integer", "minimum": 0 },
        "last_accessed": { "type": "string", "format": "date-time" },
        "explicit_importance": { "type": "number", "minimum": 0, "maximum": 1 }
      }
    },
    "provenance": {
      "type": "object",
      "properties": {
        "source": { "type": "string" },
        "device": { "type": "string" },
        "tool_chain": { "type": "array", "items": { "type": "string" } }
      }
    },
    "schema_version": { "type": "integer", "minimum": 1 }
  },
  "additionalProperties": false
}
```

### 2.3 The `.soul` format — paired-file fusion (system identity / agent souls)

Soul files describe an agent's persistent identity, capability surface, system prompt, and tool whitelist. They are paired:

- `<name>.soul.json` — the **machine surface**: schema-strict capability declaration. Read by the runtime.
- `<name>.soul.md` — the **narrative surface**: human-readable persona, voice, philosophy. Read by the LLM as system-prompt context.

The two are bidirectionally linked: the JSON file's `narrative_path` field points to the MD; the MD file's frontmatter contains `soul_id` matching the JSON's `id`. The runtime validates the pair at load time — orphans are rejected.

Example `router.soul.json`:

```json
{
  "$schema": "epistemos://schemas/soul.v1.json",
  "id": "soul.router.v1",
  "name": "Router",
  "version": "1.0.0",
  "narrative_path": "router.soul.md",
  "model_preference": {
    "primary": { "tier": "local", "model": "qwen2.5-1.5b-instruct-4bit" },
    "fallback": { "tier": "local", "model": "qwen2.5-7b-instruct-4bit" },
    "escalation": { "tier": "cloud", "model": "claude-haiku-4-5" }
  },
  "tool_whitelist": [
    "vault.search", "vault.read", "knowledge.concept_extract",
    "structure.route_folder", "memory.recall_semantic", "reason.think"
  ],
  "tool_blacklist": ["action.shell", "action.fs", "action.fetch"],
  "max_turns": 6,
  "latency_budget_ms": 800,
  "schema_version": 1
}
```

Example `router.soul.md`:

```markdown
---{"soul_id":"soul.router.v1","persona_version":"1.0.0"}---

# Router

You are the Router. Your only job is to look at an incoming capture and decide
where it goes — and to defer rather than guess when confidence is low.

## Operating principles

1. **Defer is a first-class outcome.** When confidence is below threshold,
   route to `_inbox/review/`. Do not attempt to be impressive.
2. **Concept canonicalization is upstream of placement.** Two captures of the
   same idea must reach the same canonical name even when surface vocabulary
   differs. Use the alias table; do not invent merges.
3. **Never create a new folder unless the cluster of nearest notes is tight
   (cosine ≥ 0.8, ≥3 notes, all in the same parent).** When in doubt, defer.

## Voice

Terse. Reasons given as bullet points. Confidence as a number, never as prose.
```

### 2.4 The `.skill` format — Voyager-style procedural memory

Skills are persisted compositions — Voyager / A-MEM style. Same paired hybrid: `<name>.skill.json` (the executable plan) and `<name>.skill.md` (the human-readable description, when-to-use, examples).

```json
{
  "$schema": "epistemos://schemas/skill.v1.json",
  "id": "skill.weekly-review.v1",
  "name": "weekly-review",
  "narrative_path": "weekly-review.skill.md",
  "preconditions": ["day_of_week == 'Sunday'", "vault.size > 50"],
  "steps": [
    { "id": "s1", "tool": "memory.recall_episodic", "input": { "window_days": 7 } },
    { "id": "s2", "tool": "knowledge.summarize", "input_from": "s1.result", "params": { "style": "outline" } },
    { "id": "s3", "tool": "vault.write", "input": { "folder": "reviews/{{week}}", "body_from": "s2.result" } }
  ],
  "success_metric": "vault.write returned status:ok",
  "last_used": "2026-04-21T10:00:00Z",
  "success_rate": 0.93,
  "schema_version": 1
}
```

### 2.5 Migration story

Existing `.md` notes remain valid. They are interpreted as `.mem` files with an inferred header: `{"type":"semantic","id":<derived>,"ts":<file mtime>}`. A NightBrain job promotes high-value notes to true `.mem` format opportunistically. **No mass-migration.** The user must be able to drop a plain `.md` file into the vault and have it work immediately.

---

## 3. Multi-Variant Deterministic Tool Schemas

### 3.1 Tool registry

Every tool implements:

```rust
// agent_core/src/tools/mod.rs
pub trait Tool: Send + Sync {
    fn name(&self) -> &'static str;
    fn input_schema(&self) -> &'static serde_json::Value;
    fn output_schema(&self) -> &'static serde_json::Value;
    fn variants(&self) -> &[VariantId];
    fn profile(&self) -> Profile;
    fn small_model_safe(&self) -> bool;
    async fn invoke(&self, ctx: &ToolCtx, variant: VariantId, input: Value) -> ToolResult;
}

#[derive(Serialize, Deserialize)]
pub struct ToolMeta {
    pub status: Status,           // Ok | Empty | Partial | Error
    pub variant_used: VariantId,
    pub latency_ms: u32,
    pub confidence: Option<f32>,
    pub schema_version: u32,
    pub power_state: Option<PowerState>,    // see §6.7
}

#[derive(Serialize, Deserialize)]
pub struct ToolResult {
    pub meta: ToolMeta,
    pub result: serde_json::Value,    // schema-validated against output_schema
}
```

**Naming convention**: `result` is the typed payload; `_meta` is the universal envelope. Every tool output, every API surface, every cache entry uses these two names — no `payload`, no `data`, no `output`, no exceptions.

**Variant ordering is task-shaped, not size-shaped.**
- Routing/classification/extraction → small-first. Constrained decoding makes small models structurally identical to large; the work is information lookup, not reasoning.
- Open reasoning, planning, multi-step abstraction → large-first; small is fallback under degraded conditions (offline, breaker open, cost ceiling).

The variant author writes the order; the runner follows. Tools that get this wrong are the most common source of "small model invoked when it shouldn't have been" complaints.

### 3.2 Variant runner — runtime concern, not tool concern

```rust
// agent_core/src/tools/runner.rs
pub async fn run_with_variants(
    tool: &dyn Tool,
    ctx: &ToolCtx,
    input: Value,
) -> ToolResult {
    if let Some(cached) = ctx.cache.get(tool.name(), &input).await {
        ctx.tracer.record_cache_hit(tool.name());
        return cached;
    }
    let mut last_err = None;
    for &variant in tool.variants() {
        if !ctx.health.is_available(tool.name(), variant).await {
            ctx.tracer.record_skip(tool.name(), variant, "unavailable");
            continue;
        }
        let attempt_ctx = ctx.with_variant(variant);
        let result = match tokio::time::timeout(
            ctx.latency_budget_per_variant(),
            tool.invoke(&attempt_ctx, variant, input.clone()),
        ).await {
            Ok(r) => r,
            Err(_) => ToolResult::error(variant, "timeout"),
        };
        // schema validation is mandatory — never trust result shape
        if let Err(e) = ctx.validator.validate(tool.output_schema(), &result.result) {
            ctx.tracer.record_schema_violation(tool.name(), variant, &e);
            last_err = Some(e.to_string());
            continue;
        }
        match result.meta.status {
            Status::Ok => {
                ctx.cache.put(tool.name(), &input, &result).await;
                return result;
            }
            Status::Partial if result.meta.confidence.unwrap_or(0.0) > 0.7 => {
                ctx.cache.put(tool.name(), &input, &result).await;
                return result;
            }
            _ => { last_err = Some(format!("{:?}", result.meta.status)); continue; }
        }
    }
    ToolResult::error_with_context(VariantId::Last, last_err.unwrap_or_default())
}

pub trait HealthCheck: Send + Sync {
    async fn is_available(&self, tool: &str, variant: VariantId) -> bool;
}
```

`HealthCheck` impls cover:
- Cloud variants: keychain item present, network reachable, rate-limit budget remaining.
- Local variants: model file resident or loadable in budget; inference engine initialized.
- Pro-only variants: feature flag set; profile = Pro.
- Any variant: per-tool circuit breaker not Open.

Cached for 5s per `(tool, variant)`; evicted on any tool-error event.

This eliminates the silent-fallback-on-missing-credential failure mode where a missing API key looks like a model timeout to the user.

### 3.3 GBNF/llguidance compiler — single source of truth

Local Hermes/Qwen and cloud function-calling derive their constraints from the **same** JSON Schema via one compiler. We standardize on **llguidance** (Microsoft, Rust-native).

llguidance is preferred over llama.cpp's native GBNF because GBNF compiles JSON Schemas to a flat finite-state machine that requires bounded recursion depth — pure FSMs cannot handle JSON's recursive structure (arrays of objects of arrays) without a fixed cap. llguidance uses a **pushdown automaton with an Earley-parser frontend**, tracking nesting depth dynamically. The amortized CPU cost is ~50μs/token on a 128k tokenizer thanks to lexer/parser splitting and "slicer" optimizations — ~5ms total overhead on a 100-token tool call, negligible against any latency budget. The Earley/Lark-syntax frontend also accepts JSON Schema directly without a manual GBNF translation, eliminating the schema → grammar transpiler that would otherwise be a perpetual source of subtle bugs.

```rust
// agent_core/src/grammar/mod.rs
pub fn schema_to_llg(schema: &Value) -> Result<llguidance::Grammar> {
    let json_schema = schema.clone();
    let opts = llguidance::JsonCompileOptions {
        coerce_enum: true,
        compact: true,
        whitespace_pattern: r"[ \t\n]*",
        ..Default::default()
    };
    llguidance::Grammar::from_json_schema(&json_schema, opts)
}

pub fn build_tool_grammar(registry: &ToolRegistry, allowed: &[&str]) -> llguidance::Grammar {
    let dispatch = json!({
        "oneOf": allowed.iter().map(|name| {
            let tool = registry.get(name).unwrap();
            json!({
                "type": "object",
                "required": ["name", "input"],
                "properties": {
                    "name": { "const": name },
                    "input": tool.input_schema()
                },
                "additionalProperties": false
            })
        }).collect::<Vec<_>>()
    });
    schema_to_llg(&dispatch).expect("registered tool schemas must compile")
}
```

The local model **cannot** emit a tool name not in `allowed`, **cannot** miss a required field, **cannot** type-mismatch.

> **Footnote — alternatives.** Equivalent constraint primitives exist in Microsoft Guidance (`gen("name", choices=[...])`) and SGLang (`sglang.gen(choices=[...])`). They are subsets of llguidance's general-grammar capability. We pin llguidance for: Rust-native (no Python dependency), JSON-Schema-direct, Earley/PDA superset of FSM-only constraint engines. If llguidance regresses, the fallback is the SGLang Python interface gated behind a feature flag. We do not maintain two grammar paths in production simultaneously.

### 3.4 Eager-invocation defense

Hermes-3 / Qwen-2.5-1.5B in particular tend to invoke tools on simple greetings. Defense:

1. **Pre-router classifier**: a 6-class intent classifier (`chat | tool | search | capture | recall | command`) runs first. Only `tool | search | capture | recall | command` proceed to GBNF-tool-grammar generation.
2. **GBNF includes a `noop` branch** at the dispatch top level: `{"name":"noop","input":{"reason":"..."}}` — the model can choose not to act.
3. **`reason.think` always available** as the safe outlet for "I want to deliberate" — prevents forced action.

### 3.5 Tool catalog summary

The full ten-category tool catalog (vault, knowledge, memory, capture, structure, code, reasoning, action, system, meta) is specified in the deep research report referenced in §15. Phase 2 of this plan lands the **registry, runner, and llguidance compiler**; Phase 3+ lands the actual tools per the catalog.

### 3.6 Semantic cache layer

A cache wraps the variant runner. For each `(tool, canonical_input_hash)` the cache stores `{result, _meta, ttl, embedding}`.

- **Exact-match cache**: `(tool, sha256(canonicalized_input))` → result. TTL per tool family (capture: 60s, search: 5min, summarize: 24h).
- **Semantic cache**: `(tool, embedding(input))` → result, retrieved via cosine similarity ≥ 0.97. Used for QA-style tools where paraphrased questions should hit the same answer.

Implementation: `agent_core/src/cache/mod.rs`. SQLite-backed for durability. Cache writes are best-effort and never block the tool result. Cache invalidation:
- Tool-result schema-version bump invalidates that tool's cache.
- `vault.write` events invalidate any cache entry whose result references the written path.
- User undo (§8.5) invalidates the cache entry for the undone tool call.

The cache is opaque to tool authors — they always see a cache miss; the runner intercepts.

Throughput target: **10,000 lookups/s** (exact + semantic), <2ms p95.

### 3.7 Concept canonicalization (and multilingual stub)

Two captures of the same idea **must** map to the same canonical name even when surface vocabulary differs. Mechanism, in order of strength:

1. **Deterministic canonicalizer** (no LLM): lowercase → unicode-normalize → strip stopwords → lemmatize (`rust-stemmers`) → kebab-case → sort multi-word tokens alphabetically. `gradient checkpointing` and `Gradient Checkpointing!` both → `gradient-checkpointing`.
2. **Alias table**: persisted per concept node. Grows from explicit user merges and from B-variant `aliases:[...]` outputs. Stored as `.alias.json` next to concept node.
3. **Embedding tie-breaker**: concept name+definition embedding cosine distance to existing concepts.
   - **≥ 0.88**: propose merge (never auto). User approves → alias added.
   - **0.72–0.88**: defer band — always to user.
   - **< 0.72**: confidently new concept; auto-create.
4. **No silent renames.** Renaming a canonical concept requires explicit user action. The system never decides on its own that "rematerialization" should become "gradient-checkpointing"; it only proposes.

The canonicalizer is **pluggable per-language**. Default: English (`rust-stemmers` Porter, ASCII fold, kebab-case). For other languages, a `LanguageNormalizer` trait selected by `whatlang-rs` detection on the input. ICU-based segmentation for CJK. Multilingual support is **not on the Quick Capture critical path**; English-first ships at Phase 12. CJK and major European languages added per user demand. Mixed-language captures use the dominant language's normalizer; both forms are stored as aliases.

Tana's supertag model is the closest prior art for getting this right; Logseq's tag-as-page works but proliferates; Roam's page-as-block is too granular for folder routing.

---

## 4. Quick Capture Pipeline — The Four-Variant Ladder

This is the daily-driver. Every captured thought traverses this ladder. Latency budget: **800ms p95 from submit to toast.**

### 4.1 Pipeline shape and action enum

The action enum has **four values**, not two:

- `place` — drop the capture into an existing folder.
- `merge_into_existing_note` — append to an existing note when the capture is a refinement of a known concept (gated: confidence ≥ 0.90 AND target note's last-edited time > 24h, otherwise demoted to `place` in the same folder).
- `create_folder` — sibling or new folder, only when the concept-anchored variant finds a tight cluster of notes that don't yet have a folder.
- `defer` — move to `_inbox/review/` for later user review. **The system always prefers `defer` to a wrong `place`.**

```
Capture (text/voice/screenshot/clipboard/url)
  │
  ├─► [vault.quick_capture] persists raw to /_inbox/raw/<id>.mem with status="unrouted"
  │
  ▼
[structure.route_capture] — the four-variant ladder
  │
  ├─ Variant A: cosine to folder centroid embeddings (no LLM) ┐
  │             confidence ≥ 0.85 → place                     │
  ├─ Variant B: GBNF-constrained LLM classification           │  walk top
  │             confidence ≥ 0.75 → place                     │  to bottom
  ├─ Variant C: concept-extract → entity_resolve → neighbour  │  thresholds
  │             concept resolved + cluster ≥3 in folder       │  are FLOORS
  │             confidence ≥ 0.70 → place / create_folder /   │  not guides
  │             merge_into_existing_note (with 24h gate)      │
  └─ Variant D: defer to /_inbox/review/                      ┘
  │
  ▼
[apply effect] write to chosen destination, emit ActionTrace, fire toast
```

Thresholds are **floors, not guides** (a variant cannot return `place` if its own confidence is below threshold). Each tier is progressively softer because each variant is progressively more semantically grounded: A is surface-similarity, B is closed-vocab classification, C is concept-anchored nearest-neighbour. Floors come from the BFCL/ToolHop literature (arxiv:2501.02506) and the empirical observation that small-model false-positives outweigh false-negatives in trust-cost terms.

### 4.2 Schemas

`structure.route_capture` input:

```json
{ "type":"object","required":["capture_text","vault_tree","recent_captures"],"properties":{
  "capture_text":{"type":"string","minLength":1,"maxLength":2000},
  "vault_tree":{"type":"array","items":{"type":"object","required":["path","centroid_id","note_count"],"properties":{
    "path":{"type":"string"},"centroid_id":{"type":"string"},"note_count":{"type":"integer"},
    "exemplar_titles":{"type":"array","items":{"type":"string"},"maxItems":5}}}},
  "recent_captures":{"type":"array","maxItems":10,"items":{"type":"object","required":["text","placed_at","ts"],"properties":{
    "text":{"type":"string"},"placed_at":{"type":"string"},"ts":{"type":"integer"}}}}
}}
```

Output (the routing decision):

```json
{ "type":"object","required":["action","confidence","reasoning_trace","alternative_paths"],"properties":{
  "action":{"type":"string","enum":["place","defer","create_folder","merge_into_existing_note"]},
  "folder_path":{"type":"string"},
  "target_note_path":{"type":"string"},
  "new_folder_name":{"type":"string","pattern":"^[a-z0-9-]{2,48}$"},
  "confidence":{"type":"number","minimum":0,"maximum":1},
  "reasoning_trace":{"type":"string","maxLength":280},
  "alternative_paths":{"type":"array","maxItems":3,"items":{"type":"object","required":["path","score"],"properties":{
    "path":{"type":"string"},"score":{"type":"number"}}}},
  "_meta":{"$ref":"#/defs/tool_meta"}
}}
```

The `reasoning_trace` is hard-capped at **280 chars** (≈70 tokens). This is grounded in the "Brief Is Better" finding (arxiv:2604.02155): Qwen 2.5-1.5B peaks at d≈32 reasoning tokens; 256 tokens *degrades below the no-CoT baseline*. The grammar enforces this discipline — the model literally cannot emit a longer trace.

The schema is intentionally placed *before* the answer fields in every variant prompt (Tam et al., EMNLP 2024): reasoning-then-answer keeps autoregressive generation honest.

### 4.3 Variant A — embedding to folder medoids

Threshold **0.85**. For each top-level vault folder, maintain a centroid (mean) or medoid (geometric median) embedding of its notes' summaries. On capture, embed the capture, cosine to centroids, top-1 if score ≥ 0.85. Folders with <3 notes are excluded from variant A (centroid noisy).

```rust
async fn variant_a(text: &str, ctx: &RouteCtx) -> Option<RouteCandidate> {
    let q = ctx.embedder.embed(text).await.ok()?;
    let mut scored: Vec<_> = ctx.tree.folders()
        .filter(|f| !f.path.starts_with("_inbox/"))
        .map(|f| (f.path.clone(), cosine(&q, &f.medoid)))
        .collect();
    scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
    let top = scored.into_iter().take(5).collect::<Vec<_>>();
    let confidence = top.first().map(|(_, s)| *s).unwrap_or(0.0);
    if confidence >= 0.85 {
        Some(RouteCandidate {
            path: top[0].0.clone(),
            confidence,
            alternatives: top[1..].iter().map(|(p, s)| FolderScore { path: p.clone(), score: *s }).collect(),
        })
    } else {
        None
    }
}
```

Folder medoids (not centroids — medoids are robust to outliers) are recomputed by a NightBrain job on note add/move/delete. Embedding model is pinned per vault (default: `nomic-embed-text-v1.5` quantized, ~140MB resident).

### 4.4 Variant B — GBNF-constrained classification

Threshold **0.75**. Build a one-shot grammar from the current vault tree:

```rust
fn build_route_grammar(tree: &FolderTree) -> llguidance::Grammar {
    let allowed: Vec<String> = tree.folders()
        .filter(|f| !f.path.starts_with("_inbox/"))
        .map(|f| f.path.clone())
        .collect();
    let schema = json!({
        "type": "object",
        "required": ["path", "confidence"],
        "properties": {
            "path": {
                "oneOf": [
                    { "enum": allowed },
                    { "const": "NEW" },
                    { "const": "DEFER" }
                ]
            },
            "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
            "rationale": { "type": "string", "maxLength": 200 }
        },
        "additionalProperties": false
    });
    schema_to_llg(&schema).unwrap()
}
```

Few-shot prompt **must** include a DEFER exemplar — without it, small models avoid the "boring" answer.

### 4.5 Variant C — concept-anchored placement (with create_folder + merge support)

Threshold **0.70**. This variant is the most semantically grounded — it places by *meaning* rather than surface similarity, and it is the only variant that may emit `create_folder` or `merge_into_existing_note` actions.

```rust
async fn variant_c(text: &str, ctx: &RouteCtx) -> Option<RouteDecision> {
    let concepts = ctx.tools.invoke("knowledge.concept_extract", json!({ "text": text })).await.ok()?;
    let primary = concepts.result["concepts"].as_array()?.first()?;
    let canonical = primary["canonical_name"].as_str()?;

    // Try to resolve to an existing concept node.
    let resolved = ctx.tools.invoke("knowledge.entity_resolve", json!({ "canonical_name": canonical })).await.ok()?;
    let resolution: Resolution = serde_json::from_value(resolved.result.clone()).ok()?;

    let neighbors = ctx.tools.invoke("vault.search", json!({
        "query": canonical, "mode": "hybrid", "k": 12
    })).await.ok()?;

    let folder_counts = group_by_folder(&neighbors.result["hits"]);
    let (top_folder, count) = folder_counts.into_iter().max_by_key(|(_, c)| *c)?;

    match (resolution, count, cluster_tight(&neighbors.result["hits"], &top_folder)) {
        // Concept exists; many neighbours in one folder; consider merging into the strongest neighbour
        // if confidence is very high AND the target note has not been touched in 24h.
        (Resolution::Found { concept_id }, n, true) if n >= 3 => {
            let merge = consider_merge(&neighbors.result["hits"], &concept_id, ctx).await;
            if let Some(m) = merge {
                if m.confidence >= 0.90 && note_age_hours(&m.target_note_path) > 24.0 {
                    return Some(RouteDecision::merge(m.target_note_path, m.confidence));
                }
            }
            Some(RouteDecision::place(top_folder, 0.72))
        }
        // New concept; tight cluster of neighbours all in one folder → propose create_folder
        // ONLY if the cluster is tight (cosine ≥ 0.8 across ≥3 notes) AND no parent folder fits.
        (Resolution::New, n, true) if n >= 3 && parent_unfit(&top_folder, ctx) => {
            let new_name = canonical.replace('_', "-");
            Some(RouteDecision::create_folder(&top_folder, &new_name, 0.71))
        }
        // Otherwise place by neighbour majority (the safe default).
        (_, n, _) if n >= 3 => Some(RouteDecision::place(top_folder, 0.70)),
        _ => None,
    }
}
```

The `merge_into_existing_note` gate (≥0.90 confidence + 24h staleness on target) is the safety net that prevents the system from silently editing a note the user is actively working on.

The `create_folder` path is only taken when (a) the concept is genuinely new (no existing concept node within cosine 0.92), (b) ≥3 neighbouring notes cluster tightly (cosine ≥0.8) in a single folder, (c) no existing parent folder is a better fit. All three conditions reduce false-folder-creation, which is the worst failure mode at this variant.

### 4.6 Variant D — defer is a feature

The cost of a wrong placement is **asymmetric**: a false positive (silently filing a tax document under recipes) destroys trust permanently; a false negative (one extra triage keystroke) is minor friction. Defer-when-uncertain is the only choice that respects this asymmetry.

```rust
fn variant_d(_text: &str, trace: &[VariantStep]) -> RouteCandidate {
    RouteCandidate {
        path: "_inbox/review/".to_string(),
        confidence: 1.0,    // certain in deferring
        alternatives: trace.iter().flat_map(|s| s.top.clone()).take(5).collect(),
    }
}
```

The review queue is **not failure**. It is the highest-trust path.

**Triage queue as continuous on-device RL surface.** Every user interaction is a labeled training signal:

- **Accept top suggestion** → strengthens the matching variant's exemplar set; positive embedding pair (capture, target_folder).
- **Pick alternative** → negative for the picked path, positive for the chosen path; alias table updated if the user typed a concept name not in the canonical index.
- **Type a path** → strong supervised label; canonicalizer learns a new alias if the typed path matches an existing folder via fuzzy resolution.
- **Leave for later** → no signal; queue retains the item with its trace for the next pass.

Each event triggers an **incremental folder-medoid recompute** (online k-means update), an **alias-table append**, and an **exemplar-set update** for Variant B's few-shot prompt. The queue is therefore a continuous on-device adaptation loop, not a batch fine-tuning queue. Daily NightBrain consolidation merges the incremental updates into stable indices.

This is the on-device analogue of the TRACER framework's "learning to defer" pattern — easy cases routed automatically, hard cases routed to the user, confirmed answers feeding the surrogate's training set.

### 4.7 Worked example (revised under R4 thresholds 0.85/0.75/0.70)

**Capture 1**: *"GBNF can constrain Qwen's tool calls but only if the grammar is compiled per-call; XGrammar is faster than llguidance only for repeated schemas."*

- **Variant A** (centroid): top folder `research/ml/agents/` cosine 0.71; `research/ml/inference/` cosine 0.69. Best 0.71 < 0.85 → fall through.
- **Variant B** (LLM): outputs `{"folder_path":"research/ml/inference/","confidence":0.78,"reasoning_trace":"capture is about constrained-decoding backends"}`. 0.78 ≥ 0.75 → **place**. Done, ~600ms.

Decision: `{"action":"place","folder_path":"research/ml/inference/","confidence":0.78,...}`. The capture file is named `2026-04-29-gbnf-qwen-tool-calls.mem`. The atomic-concept extractor also detects `["GBNF", "XGrammar", "llguidance"]`; entity-resolve finds existing nodes for `GBNF` and `XGrammar`, creates `concepts/llguidance.mem` (new). Backlinks inserted in the body of the placed note.

**Capture 2** (would have hit Variant C): *"Rematerialization in autograd — recompute forward to save memory."*

- **Variant A**: top `research/ml/training-tricks/` at 0.62 (different vocabulary). Fall through.
- **Variant B**: returns `_defer` confidence 0.55 (LLM is uncertain because the surface tokens don't match folder exemplars). Fall through.
- **Variant C**: `concept_extract` returns `gradient-checkpointing` (canonicalized from "rematerialization"). `entity_resolve` finds the existing concept node from Capture 1's vault state. `vault.search` for `gradient-checkpointing` returns 4 hits, all in `research/ml/training-tricks/`. Cluster tight, count ≥ 3, parent fits → **place** at confidence 0.72.

Both captures end up in the same folder, linked through the same concept node, despite zero surface-vocabulary overlap. This is exactly the canonical-name problem that Variant C is designed to solve.

**Failure-case** (deliberately hits Variant D): *"thinking about how to handle the screenshot review queue"*

- **Variant A**: top 0.58, fall through.
- **Variant B**: returns `{"folder_path":"_defer","confidence":0.30,"reasoning_trace":"ambiguous between projects/epistemos and engineering/ux"}`. Fall through.
- **Variant C**: `concept_extract` returns `screenshot-review-queue` (new concept). `entity_resolve` returns `Resolution::New`. `vault.search` returns 2 hits across 3 folders — cluster not tight, count < 3. Fall through.
- **Variant D**: deferred to `_inbox/review/2026-04-29.md` with the full reasoning_trace appended. The user triages it next morning in two keystrokes; the medoid for the chosen folder updates immediately, and an `aliases:[]` entry is added to the relevant concept node.

The asymmetric-cost framing applies sharply here: **Variant D is not a failure**. The capture is findable (it's in the inbox, indexed by search, surfaced in the daily review HUD). A wrong `place` would have been a trust-destroying false positive. Defer is the right call.

### 4.8 Background re-routing

Yes, but conservatively:

- **Re-route only on explicit triggers**: folder rename, folder split, concept merge, or NightBrain "stale routing" pass that flags notes whose current folder medoid score is now ≥0.15 below their best alternative.
- **Re-route never auto-moves**. It surfaces a "suggested moves" review item, batched daily.
- **Re-routing respects user-pinned placements**. A note frontmatter field `routing: pinned` excludes from re-evaluation.

---

## 5. Self-Healing, Budgets, Observability, Cascading

### 5.1 Failure as signal

The agent never directly mutates state. It emits an **Intent**. The Rust runtime applies the Intent. If application fails, the **failure becomes a heal step** — the Intent is fed back to the LLM with the captured stderr/violation/empty-result and a diagnostic prompt asking for a corrected Intent. This is bounded by a circuit breaker.

### 5.2 Implementation sketch

```rust
// agent_core/src/heal/mod.rs
pub struct HealLoop {
    breaker: CircuitBreaker,
    max_heal_steps: u32,
    diagnostic_soul: SoulId,
}

impl HealLoop {
    pub async fn run<F, Fut>(&self, mut intent: Intent, mut apply: F) -> Result<Effect>
    where
        F: FnMut(Intent) -> Fut,
        Fut: Future<Output = Result<Effect, ApplyError>>,
    {
        for step in 0..self.max_heal_steps {
            self.breaker.before_call()?;
            match apply(intent.clone()).await {
                Ok(effect) => {
                    self.breaker.record_success();
                    return Ok(effect);
                }
                Err(err) => {
                    self.breaker.record_failure(&err);
                    if step == self.max_heal_steps - 1 {
                        return Err(err.into());
                    }
                    intent = self.diagnose_and_correct(intent, err).await?;
                }
            }
        }
        unreachable!()
    }

    async fn diagnose_and_correct(&self, intent: Intent, err: ApplyError) -> Result<Intent> {
        let prompt = json!({
            "role": "diagnostic",
            "original_intent": intent,
            "error": err.to_serializable(),
            "instruction": "Emit a corrected intent that resolves the failure. \
                            If the failure is unrecoverable, emit {\"action\":\"abort\",\"reason\":...}."
        });
        let corrected = self.diagnostic_soul.invoke_grammar_constrained(&prompt).await?;
        Intent::from_json(corrected)
    }
}
```

### 5.3 Circuit breaker

Per-tool breakers (not global). State: `Closed` | `HalfOpen` | `Open`. Open → tool returns `{status:"error", reason:"breaker_open"}` immediately. Half-open after cooldown → allow one probe. Two consecutive successes → close.

### 5.4 Latency and throughput budgets

| Surface | Latency p95 | Sustained throughput |
|---|---|---|
| Capture submit → toast | 800 ms | 5 ops/s (single user, bursty) |
| Search keystroke → first result | 80 ms | 100 ops/s (during typing) |
| AI input → first token | 600 ms | 10 ops/s |
| Background NightBrain (re-route, re-embed, medoid recompute) | n/a | **≥500 captures/min sustained on local 7B** |
| Cache lookup (exact + semantic) | <2 ms | 10,000 ops/s |
| Action trace open | 80 ms | n/a |

Throughput budgets are enforced by Phase 11 evals — the 200-case set is run *concurrently* (8 parallel) and total wall time is logged.

llguidance amortizes ~50μs/token of constraint overhead — at 30 tok/s for a 100-token tool call this is ~5ms, negligible against the 800ms capture budget.

Network savings: self-hosting eliminates the 100–400ms API round-trip penalty on every call. Local-first throughput: well-engineered 7B can sustain **10,000+ req/s** for simple classification tasks vs ~100/s for cloud APIs. The 100× gap is what allows aggressive NightBrain workloads without the user feeling them.

### 5.5 Observability stack

- **Structured logs**: `tracing` crate + `tracing-subscriber` with JSON formatter. Every tool invocation gets a span; spans include `tool`, `variant`, `latency_ms`, `cache_hit`, `model_id`, `vault_id`, `session_id`.
- **Metrics**: per-tool `histogram_p50_p95_p99(latency_ms)`, `counter(success/error/empty)`, `counter(cache_hit/miss)`, `gauge(model_resident_bytes)`. Persisted hourly to a local SQLite metrics table.
- **Profiling hooks**: `os_signpost` regions around each variant attempt, named `tool.<name>.variant.<id>`. Already in place per session-6 commit; extend to all tools.
- **Action trace ingestion**: every span emits a row in `action_trace.sqlite`. UI reads this directly for the cmd-? trace view.
- **Privacy**: structured logs **never** include capture text; only ids, hashes, and shapes. Regulatory-safe by construction.

### 5.6 Cascading and speculative decoding

The variant ladder is a cascade by construction. For latency-critical hot paths, specialize the smallest variant aggressively:

- **Capture pre-tag**: a 30M-param distilled classifier runs <10ms on every capture, producing a tag distribution. Variant A (medoid embedding) consumes this distribution as a prior; Variant B's GBNF few-shot is conditioned on it.
- **Code completion**: a 121M-class draft model proposes; a 7B verifier accepts or rewrites. Cloud is invoked only on draft↔verifier disagreement above a token-edit-distance threshold. (Reference: a 121M model handles ~38% of code completions correctly at 2× the speed of a 7B model.)
- **Speculative decoding for long generations**: when a generation exceeds 256 tokens, a small "draft" model proposes 4-token chunks that a larger model verifies in parallel. Standard llama.cpp speculative decoding via the `--draft-model` flag — no custom code.

The discipline: the smallest model that handles the case at acceptable confidence wins. Bigger models are recourse, not default.

### 5.7 Heal-event log schema

```sql
CREATE TABLE heal_events (
  id INTEGER PRIMARY KEY,
  ts TEXT NOT NULL,
  tool TEXT NOT NULL,
  variant TEXT NOT NULL,
  original_intent JSON NOT NULL,
  error JSON NOT NULL,
  corrected_intent JSON,
  outcome TEXT NOT NULL,    -- recovered | abandoned | escalated
  step_idx INTEGER NOT NULL,
  session_id TEXT NOT NULL
);
CREATE INDEX heal_events_tool_ts ON heal_events (tool, ts);
```

Recurring heal patterns (same tool, same error class, ≥10 events in 7 days) auto-surface as a "prompt drift" alert in the action trace UI.

---

## 6. Native Skills + Local Inference + Hardware Awareness

### 6.1 Spotlight metadata as instant retrieval

Wrap `NSMetadataQuery` in Swift, expose to Rust via UniFFI:

```swift
// Epistemos/Skills/SpotlightSkill.swift
@MainActor
public final class SpotlightSkill {
    public func query(_ predicate: String, scope: [URL]) async -> [SpotlightHit] {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(fromMetadataQueryString: predicate)
        query.searchScopes = scope
        return await withCheckedContinuation { cont in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query, queue: .main
            ) { _ in
                query.disableUpdates()
                let hits = (0..<query.resultCount).compactMap { i -> SpotlightHit? in
                    let item = query.result(at: i) as? NSMetadataItem
                    return item.map { SpotlightHit.from($0) }
                }
                if let observer = observer { NotificationCenter.default.removeObserver(observer) }
                cont.resume(returning: hits)
            }
            query.start()
        }
    }
}
```

Tool: `vault.search` variant E — Spotlight-backed lexical fallback for content outside the vault directory (with explicit user opt-in per scope).

### 6.2 Vision OCR

```swift
// Epistemos/Skills/VisionOCRSkill.swift
public final class VisionOCRSkill {
    public func recognize(_ image: CGImage, level: RecognitionLevel) async throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = (level == .accurate) ? .accurate : .fast
        request.usesLanguageCorrection = (level == .accurate)
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return OCRResult(blocks: observations.map { OCRBlock.from($0) })
    }
}
```

Tool: `capture.screenshot` variant A (Fast, ~80ms), variant B (Accurate, ~500ms with language correction). Bounding boxes preserved in output.

### 6.3 Local inference — MLX-Swift + MLX-Structured primary

The project already runs MLX-Swift per `CLAUDE.md`. R4 grounds the primary path: **MLX-Swift + MLX-Structured `GrammarMaskedLogitProcessor`** (rudrank.com/exploring-mlx-swift-structured-generation-with-generable-macro). The processor enforces context-free grammars at the logit level inside the MLX inference loop, exactly mirroring how llama.cpp does it for GBNF and how vLLM does it for XGrammar (arxiv:2411.15100). Token-mask compute is ~50μs at a 128k tokenizer; with grammar masking active, throughput drops <10% versus unconstrained generation in published benchmarks.

The constraint-backend decision tree (in priority order):

1. **MLX-Structured** (default). If the grammar coverage is sufficient — covers all schemas in this plan as written.
2. **LM-Format-Enforcer** (fallback). Token-prefix-tree intersection. More flexible (handles edge cases MLX-Structured may miss) but ~5–15% slower.
3. **llguidance via Rust FFI** (when v2 needs full Earley + recursive). Highest fidelity; pulled in only when (1) and (2) demonstrably fail on a target schema.

The decision criterion at integration time is **≥99% schema-compliance on the regression suite at <5% throughput tax**. Phase 6 verification gates this empirically.

The engine sits behind a trait so we can swap without disturbing call sites:

```rust
// agent_core/src/inference/mod.rs
pub trait LocalInference: Send + Sync {
    fn load(path: &Path, opts: LoadOpts) -> Result<Self> where Self: Sized;
    fn generate_with_grammar(
        &self, prompt: &[u32], grammar: &Grammar,
        stop: StopCondition,
    ) -> Result<Vec<u32>>;
    fn unload(self);
    fn info(&self) -> ModelInfo;
}

pub struct MlxEngine { /* MLX-Swift handle exposed via UniFFI */ }
pub struct LlamaCppEngine { /* alternative for llama.cpp-only checkpoints */ }
impl LocalInference for MlxEngine { /* ... */ }
impl LocalInference for LlamaCppEngine { /* ... */ }
```

The Swift side wires MLX-Structured directly into the token iterator:

```swift
// Epistemos/Inference/MlxConstrainedRunner.swift
import MLX
import MLXStructured

public func generateConstrained(
    prompt: String, grammar: Grammar, model: ModelContext, params: GenerateParameters
) async throws -> String {
    let processor = try await GrammarMaskedLogitProcessor.from(
        configuration: model.configuration, grammar: grammar)
    let input = try model.tokenizer.encode(text: prompt)
    let iter = try TokenIterator(
        input: input, model: model.model,
        processor: processor, sampler: params.sampler(),
        maxTokens: params.maxTokens)
    var out: [Int] = []
    for token in iter { out.append(token); if shouldStop(token) { break } }
    return model.tokenizer.decode(tokens: out)
}
```

Models load on demand via a reference-counted `ModelLease`, generate constrained by grammar, and unload on idle-TTL (60s). Unified memory eliminates copy cost on M-series. The router model (a small 1.5B-class) is the only one that may stay warm across captures; everything else cold-loads.

**Lazy evaluation** (`mx.eval()` only on commit) is used for batch concept-extraction over multiple captures (one model load, many calls). **Cold-start** is 1–3s on M-series for 7B-class; the bootstrap warms the router model on app launch in the background. Variants A and C can run immediately while the model warms; Variant B blocks only if needed.

### 6.4 Ephemeral pipeline assembly

```rust
// agent_core/src/pipeline/ephemeral.rs
pub async fn quick_capture_pipeline(input: CaptureInput) -> Result<RouteResult> {
    let router_model = ModelLease::acquire("qwen2.5-1.5b-instruct-4bit").await?;
    let route = structure::route_folder(input.text(), &router_model).await?;
    drop(router_model);

    if route.deferred { return Ok(route); }

    let writer_ctx = vault::WriteCtx::for_folder(&route.folder_path);
    let effect = vault::write_capture(input, &writer_ctx).await?;
    Ok(RouteResult { route, effect })
}
```

No persistent inference daemon. The router model is the only one that *might* stay warm (controlled by `ModelLease`'s reference-counted cache — TTL 60s of idleness). Larger models are always cold-loaded.

### 6.5 Tool-call format normalizer

Local Hermes/Qwen models emit `<tool_call>{...}</tool_call>` (Hermes XML wrapping; arxiv:2408.11857). Qwen 2.5+ adopted the same wrapping (insiderllm.com/guides/function-calling-local-llms). Cloud Claude uses native tool blocks. Perplexity Sonar Pro speaks OpenAI-style. The agent core needs **one normalized internal call format** with three encoders/decoders so providers stay swappable.

```rust
// agent_core/src/toolcall/format.rs
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct NormalizedToolCall {
    pub name: String,
    pub input: serde_json::Value,
    pub call_id: String,
}

pub trait WireFormat: Send + Sync {
    fn encode_request(&self, calls: &[NormalizedToolCall]) -> String;
    fn parse_response(&self, raw: &str) -> Result<Vec<NormalizedToolCall>, ParseError>;
    fn stop_tokens(&self) -> &[&'static str];
}

pub struct HermesXml;       // <tool_call>{...}</tool_call>
pub struct QwenJson;        // ```json\n{...}\n``` or raw JSON
pub struct OpenAiTools;     // {"tool_calls":[...]} structure
pub struct ClaudeBlocks;    // tool_use content blocks
```

Implementation notes per format:

- **Hermes XML** (`HermesXml`): both `<tool_call>` and `</tool_call>` are *added tokens* in Hermes-3/4 tokenizers — they're single tokens, so detection is cheap. Stream the inner JSON; validate the tag pair separately. The grammar wraps each tool-call envelope: `tool_call ::= "<tool_call>" json "</tool_call>"`. The model's KV-cache stays clean because the open/close tokens are atomic.
- **Qwen JSON** (`QwenJson`): Qwen 2.5+ also accepts the Hermes XML format natively (qwen.readthedocs.io/en/latest/framework/function_call.html). Default to `HermesXml` on Qwen models; fall back to bare-JSON only when the model is older or fine-tuned without the chat template.
- **OpenAI tools** (`OpenAiTools`): used only by Perplexity Sonar Pro; simple JSON schema parse.
- **Claude blocks** (`ClaudeBlocks`): native Anthropic tool_use blocks; no GBNF needed (Claude does its own constraining server-side). Parse `content` array, filter `type == "tool_use"`.

**Repeating-loop failure mode.** After a failed call, models sometimes repeat the user prompt or emit empty text (insiderllm.com). Defenses:

1. Hard `max_iterations` cap on the agentic loop (default 8).
2. Duplicate-detector: break the loop on consecutive identical actions (same tool, same canonicalized input).
3. Empty-response detector: if the assistant message is empty AND no tool call was emitted, advance to the next variant immediately (don't retry the same model).

**Streaming UX.** Streaming partial JSON to the UI is awkward; the user sees `{"folder_path":"resea` mid-token. Don't render the JSON. Render a deterministic spinner with the *currently-best* candidate from the centroid variant (already known from Variant A), then update once the LLM commits the final structured output. The structured output is what the user sees.

### 6.6 Per-Model Engineering Catalog

**This section is the centerpiece of the local-first parity strategy.** Each candidate model gets bespoke wiring — no generic treatment. The catalog is sized for the user's 16GB Mac: simultaneous resident set must stay below 6GB to leave headroom for the OS, the app, and the KV-cache.

**Resident-set budget** (worst case during a multi-tool capture):

| Component | Resident |
|---|---|
| OS + Epistemos UI process | ~3.5 GB |
| Active inference model (one at a time) | up to 4.5 GB |
| Embedding model (always resident) | ~50–250 MB |
| NLI model (loaded for `cite_find`) | ~150 MB |
| KV-cache for 8k context @ 4-bit | ~1 GB |
| **Headroom margin** | ~6 GB |

The "active inference model is one at a time" rule is enforced by `ModelLease`. Two large models cannot coexist; the lease blocks the second load until the first unloads.

#### Model role assignments

| Role | Default model | Quant | Resident | Why this model |
|---|---|---|---|---|
| **Router (1.5B)** | Qwen2.5-1.5B-Instruct | 4-bit MLX | ~1.0 GB | Highest refusal-correctness in BFCL — knows when not to call |
| **Function-caller (8B)** | Hermes-3-Llama-3.1-8B | 4-bit MLX | ~4.5 GB | XML tool-call format; argument fidelity ≥99% under grammar constraint |
| **General agent (7B)** | Qwen2.5-7B-Instruct | 4-bit MLX | ~4.2 GB | Argument-faithful, broad knowledge, reasoning peaks at ~256 tokens |
| **Code (7B)** | Qwen2.5-Coder-7B-Instruct | 4-bit MLX | ~4.2 GB | Code-specific pre-training; tree-sitter alignment |
| **Concept extractor (3B)** | Phi-3.5-mini-instruct | 4-bit MLX | ~2.2 GB | Strong reasoning per param; closed-vocab classification |
| **Speculative draft (1B)** | Llama-3.2-1B-Instruct | 4-bit MLX | ~700 MB | Fast draft for speculative decoding pair with 7B verifier |
| **Embedding (small)** | bge-small-en-v1.5 | 4-bit MLX | ~50 MB | 384-dim, fast (<10ms/query), good for centroids |
| **Embedding (large)** | bge-large-en-v1.5 | 4-bit MLX | ~250 MB | 1024-dim, better recall, opt-in via setting |
| **Embedding (alt)** | nomic-embed-text-v1.5 | 4-bit MLX | ~140 MB | 768-dim, longer context window (8k), opt-in |
| **NLI (entailment)** | deberta-v3-base-mnli | 4-bit | ~150 MB | Sentence-level entailment for `knowledge.cite_find` |
| **ASR** | WhisperKit small.en | CoreML | ~250 MB | On-device, Apple Neural Engine, near-zero CPU |
| **OCR** | Vision Framework `VNRecognizeTextRequest` | (system) | 0 MB app-side | Native, accurate path with language correction |

Below, each model gets bespoke engineering notes. **Do not generalize across models.** Each is wired specifically.

---

#### 6.6.1 Qwen2.5-1.5B-Instruct (4-bit MLX) — Router

- **Source**: `mlx-community/Qwen2.5-1.5B-Instruct-4bit` on Hugging Face.
- **Best at**: refusal detection, intent classification, closed-vocab classification (Variant B routing).
- **Known weakness**: argument fidelity in tool calls. Use only with grammar constraints; never trust free-form output.
- **Reasoning budget**: hard-cap at **32 tokens** of `thought` (per Brief Is Better, arxiv:2604.02155 — 1.5B Qwen peaks at d≈32 reasoning tokens; longer degrades below the no-CoT baseline).
- **Tool-call format**: Hermes XML (Qwen 2.5+ natively supports the wrapping).
- **Constraint backend**: MLX-Structured. Grammar must close every enum tightly; the model otherwise drifts on free-string fields.
- **Few-shot count**: 3 exemplars, all in-prompt, including one DEFER outcome and one NEW outcome. Without these, the model picks "the obvious" answer 100% of the time even when the right answer is to abstain.
- **Temperature**: `0.0` for routing decisions; `0.2` for tag suggestions.
- **Latency on M-series**: cold-load <1s; first token ~80ms; ~80 tok/s. A typical routing call (input ~600 tok prompt + ~50 tok output) lands at 600–800ms.
- **Custom engineering**:
  - **Lock the system prompt** to the soul-file content; never inject ad-hoc instructions per call (the 1.5B is sensitive to prompt drift).
  - **Disable multi-turn**: the router gets one shot and emits one decision; no follow-ups.
  - **Force `noop` always available** in any GBNF dispatch grammar for this model — eager invocation is its biggest failure mode.
- **Phase to integrate**: Phase 3 (Variant B), Phase 6 (engine wiring).

#### 6.6.2 Qwen2.5-7B-Instruct (4-bit MLX) — General agent

- **Source**: `mlx-community/Qwen2.5-7B-Instruct-4bit`.
- **Best at**: tool-call argument fidelity, abstractive summarization (under 8k context), multi-step reasoning when bounded.
- **Known weakness**: confabulates citations in QA without explicit grammar requiring `citations[]`.
- **Reasoning budget**: **256 tokens** maximum. Brief Is Better shows degradation past ~256 even on 7B.
- **Tool-call format**: Hermes XML (Qwen 2.5+ supports natively).
- **Constraint backend**: MLX-Structured for routine schemas; LM-Format-Enforcer fallback if grammar coverage misses.
- **Few-shot count**: 3 exemplars with one `defer` / one `new` / one `place`. Reasoning field appears *before* answer field (Tam et al., EMNLP 2024).
- **Temperature**: `0.0` for tool calls; `0.3` for summaries.
- **Latency**: cold-load ~3s; first token ~120ms; ~30–40 tok/s on M4 Pro. Typical tool call ~600ms.
- **Custom engineering**:
  - For `knowledge.qa_over_vault`, the GBNF *requires* a non-empty `citations` array — the model literally cannot emit an answer without at least one citation.
  - Pair with Llama-3.2-1B as a speculative-decoding draft model when generating >256 tokens (llama.cpp supports natively; MLX-Structured pairing requires manual draft loop).
  - Repeat-suppression: if the same tool+input is emitted twice in a row, advance variant immediately (don't retry).
- **Phase to integrate**: Phase 3 (Variant B fallback when 1.5B is uncertain), Phase 6.

#### 6.6.3 Hermes-3-Llama-3.1-8B (4-bit MLX) — Function-caller

- **Source**: `mlx-community/Hermes-3-Llama-3.1-8B-4bit` (note: license is permissive but verify).
- **Best at**: function calling specifically — Hermes-3 was fine-tuned on Hermes-Function-Calling data with the XML format. Steerability via system prompt is the strongest of any local model in this catalog.
- **Known weakness**: 4.5GB resident is the largest in the catalog. Use only when XML tool-call fidelity matters more than memory headroom; otherwise default to Qwen 2.5-7B.
- **Reasoning budget**: 256 tokens.
- **Tool-call format**: Hermes XML (native).
- **Constraint backend**: MLX-Structured. Hermes-3's strong format adherence means the grammar can be looser without compliance loss.
- **Few-shot count**: 2 exemplars (Hermes-3 needs less few-shot than Qwen because its tool-calling is post-trained).
- **Temperature**: `0.0`.
- **Latency**: cold-load ~3.5s; first token ~140ms; ~25–35 tok/s on M4 Pro.
- **Custom engineering**:
  - **The strongest steerability is also the biggest risk** (arxiv:2408.11857): a sloppy soul-file change can degrade tool-calling significantly. Soul-file changes affecting Hermes routing must run a regression test before merging (Phase 11.5 hooks this).
  - Use Hermes-3 specifically for **multi-tool plans** — `reason.plan` outputs that chain ≥3 tools — where argument fidelity matters across the chain.
  - Match `<tool_call>` and `</tool_call>` as added single tokens in the tokenizer; faster than substring detection.
- **Phase to integrate**: Phase 3 (Variant B for multi-tool plans), Phase 6.

#### 6.6.4 Qwen2.5-Coder-7B-Instruct (4-bit MLX) — Code

- **Source**: `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit`.
- **Best at**: code completion, refactor suggestions, doc generation in language-aware doc formats.
- **Reasoning budget**: 256 tokens for explanations; for code itself, no reasoning field.
- **Tool-call format**: Hermes XML.
- **Constraint backend**: MLX-Structured for tool calls; for raw code generation, no constraint (free-form). For doc generation, GBNF constrained to language-specific doc grammar (rustdoc / jsdoc / docc).
- **Few-shot count**: 1 exemplar (code generation with structured output rarely needs more).
- **Temperature**: `0.2` for code; `0.0` for doc generation.
- **Latency**: cold-load ~3s; ~30 tok/s.
- **Custom engineering**:
  - **Tree-sitter alignment**: this model is post-trained on code tokenized with tree-sitter-style boundaries. Pair its output through tree-sitter validation to catch bracket/quote drift before applying edits.
  - For `code.refactor_suggest`, GBNF outputs an LSP-style `WorkspaceEdit` JSON shape — the grammar enforces ranges and new_text syntax.
  - **Speculative pair**: pair with Llama-3.2-1B as draft for >100 token generations.
- **Phase to integrate**: Phase 3 (code tool catalog, deferred to Wave 3 per §11), Phase 6.

#### 6.6.5 Phi-3.5-mini-instruct (4-bit MLX) — Concept extractor

- **Source**: `mlx-community/Phi-3.5-mini-instruct-4bit`.
- **Best at**: classification under closed enums, concept extraction, short structured tasks. Microsoft's "small but mighty" — strong reasoning per param.
- **Known weakness**: not as steerable as Hermes; not as broad as Qwen. Use it for narrow tasks.
- **Reasoning budget**: 64 tokens (smaller than Qwen 7B because the model is 3B).
- **Tool-call format**: JSON (Phi doesn't natively support Hermes XML; wrap manually).
- **Constraint backend**: MLX-Structured. Phi handles GBNF cleanly when the grammar is tight.
- **Few-shot count**: 3 exemplars; Phi benefits from explicit format examples.
- **Temperature**: `0.0`.
- **Latency**: cold-load ~1.8s; ~50 tok/s.
- **Custom engineering**:
  - Use specifically for `knowledge.concept_extract` — its closed-vocab classification is crisp at this size.
  - Avoid for free-form reasoning; the limited reasoning budget makes it brittle.
- **Phase to integrate**: Phase 3 (Variant C concept extractor), Phase 6.

#### 6.6.6 Llama-3.2-1B-Instruct (4-bit MLX) — Speculative draft

- **Source**: `mlx-community/Llama-3.2-1B-Instruct-4bit`.
- **Best at**: serving as a draft model for speculative decoding paired with Qwen 7B or Hermes 8B.
- **Use only as a draft** — Llama 3.2 1B is safety-tuned but its tool-call fidelity at 1B is poor. Never use as a primary tool-caller.
- **Latency**: ~80 tok/s. Pair speeds up Qwen 7B generations of >256 tokens by ~1.4–1.8× in published benchmarks (a 121M model handles ~38% of code completions correctly at 2× the speed of a 7B; 1B sits between).
- **Custom engineering**:
  - Loaded only when the active path generates >256 tokens; unloaded on idle.
  - Vocabulary mismatch between Llama and Qwen tokenizers means speculative pairing is only valid within the *same* tokenizer family. Pair Llama-3.2-1B with Hermes-3-Llama-3.1-8B (same family); pair a Qwen-1.5B draft with Qwen-7B.
- **Phase to integrate**: Phase 6 speculative path, deferred to Wave 3 if cold-start cost is unacceptable.

#### 6.6.7 bge-small-en-v1.5 (4-bit MLX) — Embedding (default)

- **Source**: `mlx-community/bge-small-en-v1.5-mlx` or via `mlx_embeddings`.
- **Output**: 384-dim float vectors.
- **Always-resident**: embedding model is the only ML asset that stays loaded across captures (because Variant A runs on every capture).
- **Latency**: <10ms/query on M-series; <50ms for 32-document batch.
- **Custom engineering**:
  - Pin per-vault — changing the embedding model invalidates all centroids (see Phase 11.5 migration).
  - L2-normalize at write time so cosine reduces to dot-product at query time (~3× faster).
  - Quantize to int8 in storage, dequant at query (5× storage win, <1% recall loss).
- **Phase to integrate**: Phase 2 (cache layer needs embeddings), Phase 3 (Variant A).

#### 6.6.8 bge-large-en-v1.5 (4-bit MLX) — Embedding (high-recall opt-in)

- **Source**: `mlx-community/bge-large-en-v1.5-mlx`.
- **Output**: 1024-dim. Higher recall than small; use when the user opts in via Settings ("Embedding model: small/large").
- **Latency**: ~25ms/query.
- **Custom engineering**: same pinning, L2-norm, int8-quant rules as small.
- **Phase to integrate**: Phase 2 (Settings option), Phase 11.5 migration covers swap.

#### 6.6.9 nomic-embed-text-v1.5 (4-bit MLX) — Embedding (long-context)

- **Source**: `mlx-community/nomic-embed-text-v1.5-mlx`.
- **Output**: 768-dim. Distinguishing feature: **8k-token context window** (vs bge's 512). Use when chunking long documents semantically — fewer chunks per document, better cohesion.
- **Latency**: ~15ms/query; ~80ms for an 8k-token chunk.
- **Custom engineering**: same pinning rules. Choose between bge and nomic on vault setup based on average note length: <2k tokens/note → bge; >2k → nomic.
- **Phase to integrate**: Phase 2 (Settings), Phase 11.5.

#### 6.6.10 deberta-v3-base-mnli (4-bit) — NLI for citation entailment

- **Source**: `MoritzLaurer/deberta-v3-base-mnli-fever-anli-ling-wanli`, quantized to 4-bit.
- **Use case**: `knowledge.cite_find` — given a claim, find the supporting note. The NLI model classifies (claim, candidate-sentence) → `{entailment, contradiction, neutral}` with calibrated probabilities.
- **Latency**: ~30ms per (claim, sentence) pair. Batch 32 candidates per claim → ~120ms.
- **Custom engineering**:
  - Run only after `vault.search` narrows candidates to top-K=12 — never on the whole vault.
  - Threshold: `support_score ≥ 0.6` to attach a citation; below → defer with `unsupported`.
- **Phase to integrate**: Phase 5 (knowledge tools wave).

#### 6.6.11 WhisperKit small.en — ASR

- **Source**: Apple WhisperKit (CoreML port of Whisper-small).
- **Best at**: on-device transcription with Apple Neural Engine acceleration.
- **Latency**: ~0.4× real-time on M-series with ANE (a 30s clip transcribes in ~12s; in practice we transcribe streamed audio incrementally).
- **Custom engineering**:
  - Stream-mode transcription: feed audio in 10s windows; emit partials as they finalize.
  - Pipe directly into `vault.quick_capture` — voice → text → same routing pipeline as typed capture (no special "voice path").
  - Cloud Whisper as cloud fallback only when accuracy is critical (user setting).
- **Phase to integrate**: Phase 5.

#### 6.6.12 Vision Framework `VNRecognizeTextRequest` — OCR

- **No app-side model file**; fully OS-resident.
- **Two paths**: `.fast` (~80ms for screenshot-sized image) and `.accurate` (~500ms with `usesLanguageCorrection = true`).
- **Custom engineering**:
  - Use `.accurate` by default; it handles structured documents, tables, and diagrams meaningfully better.
  - Output bounding boxes are preserved through to the routing pipeline so downstream tools can do region selection.
  - Pipe directly into `vault.quick_capture` — image → text → same routing pipeline.
- **Phase to integrate**: Phase 5.

### 6.7 Model selection routing

A small Rust function (no model) decides which model handles each call. Inputs: tool name, input length, network status, last 5 user-correction signals, model warm-up state, power state. Output: model id + variant id. The router *never asks the user*; it logs each decision so the user can later see "where did my queries go?" — that's the revelation moment, not a modal.

**Local is the hard default.** Cloud is reachable only via the explicit overrides listed in §1.3 — `/cloud`, `⌥`-submit, or the rare provably-out-of-local-capacity path (output >2000 tokens AND cloud-allowed in Settings). The router below biases hard toward local at every branch; cloud is the explicit final clause, not the convenient middle one.

```rust
// agent_core/src/routing/model_select.rs
pub fn select_model(call: &ToolCall, ctx: &AppCtx) -> ModelChoice {
    use ToolFamily::*;
    match (call.tool.family(), call.input.len(), ctx.power, ctx.network) {
        // Routing decisions: 1.5B router on the hot path, 3B fallback.
        (Routing, _, _, _) => ModelChoice::local("qwen2.5-1.5b-instruct-4bit"),

        // Concept extraction: 3B Phi for crisp closed-vocab work.
        (Concept, _, _, _) => ModelChoice::local("phi-3.5-mini-instruct-4bit"),

        // Multi-tool plans: Hermes-3-8B for argument fidelity across chains.
        (Plan, _, Power::AC, _) if call.tools_in_plan() >= 3 =>
            ModelChoice::local("hermes-3-llama-3.1-8b-4bit"),

        // Code: Qwen-Coder.
        (Code, _, _, _) => ModelChoice::local("qwen2.5-coder-7b-instruct-4bit"),

        // Citations / NLI: deberta entailment.
        (Cite, _, _, _) => ModelChoice::local("deberta-v3-base-mnli-4bit"),

        // Long-form abstractive >2000 tokens AND cloud-allowed AND user has not overridden /local.
        // This is the only case where cloud is reached *implicitly*.
        (Summarize, n, _, Network::Online) if n > 2000 && ctx.cloud_allowed && !ctx.user_local_override =>
            ModelChoice::cloud("claude-haiku-4-5"),

        // Battery + heavy thermal: degrade everything to the 1.5B router.
        (_, _, Power::BatteryHot, _) => ModelChoice::local("qwen2.5-1.5b-instruct-4bit"),

        // Default general agent.
        _ => ModelChoice::local("qwen2.5-7b-instruct-4bit"),
    }
}
```

User overrides via slash-commands in the AI input bar:
- `/local` — force the local path on this turn.
- `/cloud` — force cloud.
- `/fast` — force the 1.5B router regardless of task.
- Hold `⌥` while submitting — force cloud (matches Claude Desktop / Cursor convention).

The router emits its decision to the action trace; the user can see a histogram of where their queries went over time (Layer-2 disclosure).

### 6.8 Swift 6.2 ↔ Rust UniFFI Boundary Invariants

- **All Rust types crossing UniFFI implement `Send + Sync`**. Verified at codegen.
- **Owned values only**. UniFFI rejects functions returning borrowed data; the lifetime contract is owned-on-Swift-side.
- **State pattern**: `Mutex<RustAppState>` inside the Rust core, exposed as a UniFFI Object. Swift wraps each accessor in an `@Observable @MainActor` class. SwiftUI re-renders reactively when an `Effect` mutation completes.
- **Async**: Rust futures map to Swift `async`/`await`. Foreign bindings supply the executor — Swift's concurrent runtime drives Rust's futures, no separate runtime needed.
- **No reentrancy across actors**. The `IntentApplier` writes inside a single Rust-side actor; Swift observes the resulting state snapshot, never holds a mutable handle.
- **Compile-time data-race elimination**: Swift 6.2's region-based isolation flags ownership transfers. Wrapper classes stay region-isolated to `@MainActor`; Rust mutations go through the Mutex and emit copies, not references.
- **Secret zeroization**: API keys retrieved from Keychain via the Swift bridge per-call, passed across UniFFI as a borrowed string into the Rust call site, used immediately, dropped. Rust holds the key only inside a `zeroize::Zeroizing<String>` guard — on drop, the buffer is overwritten with zeros. No Rust-side cache.

### 6.9 Crash safety contract

- **All SQLite databases use WAL mode** (`PRAGMA journal_mode=WAL`) with `synchronous=NORMAL`. WAL gives crash-consistency without per-write fsync overhead.
- **Vault file writes are tempfile-rename**: write to `.tmp.<uuid>`, fsync, atomic rename to final path. No partial files visible to other processes.
- **`.mem` writes are line-atomic**: header line written first, body written second, but the writer holds the file lock until both complete; readers seeing only the header file get `Status::Empty` (incomplete).
- **Crash recovery**: on startup, `agent_core/src/recovery/mod.rs` scans `_inbox/raw/` for orphan tempfiles older than 60s, scans `undo_log.sqlite` for half-applied effects (effect logged, no inverse — replay forward), scans `heal_log.sqlite` for in-flight heal sessions (resume or abandon based on session age).

### 6.10 Power and thermal awareness

The router consults `IOPMrootDomain` (battery state, thermal state) on every routing decision:

- **AC + Nominal thermal**: full pipeline. Variant ladder runs to completion.
- **AC + Heavy thermal**: skip Variant C (concept extract — most expensive) and degrade to DEFER faster.
- **Battery + Nominal**: cap concurrent NightBrain workers to 1; defer batch jobs to next charge.
- **Battery + Heavy thermal**: pause NightBrain entirely; capture surface remains responsive but routing skips to Variant D after Variant A.

Surfaced in trace via `_meta.power_state`. Surfaced in Settings: nothing — the system tunes itself.

---

## 7. Model Workspace Protocol — Filesystem as Orchestrator

For multi-step pipelines that span minutes (e.g. nightly re-routing, batch ingestion of an email archive), use **filesystem-backed orchestration**:

```
agent_core/data/workspace/<job_id>/
  00_inputs/
    capture-01.mem
    capture-02.mem
  01_concept_extract/
    _step.soul.md
    _step.soul.json
    out/
      capture-01.concepts.json
      capture-02.concepts.json
  02_canonicalize/
    _step.soul.md / _step.soul.json / out/...
  03_route/
    _step.soul.md / _step.soul.json / out/...
  04_apply/
    _step.soul.md / _step.soul.json / receipts/...
```

Each numbered folder = one stage. The soul file dictates: which model, which grammar, which tool whitelist. Each stage reads from `<previous>/out/` and writes to `<current>/out/`. Stages are independent processes — each can be inspected, replayed, or hot-fixed. **Replays are deterministic**: reset the breaker, rerun stage N with the same inputs, get byte-identical outputs.

### 7.1 NightBrain runner

NightBrain is a single-process, multi-task scheduler that runs maintenance work when the system is idle:

- **Trigger**: macOS `NSProcessInfo.thermalState == .nominal` AND user idle > 60s AND on AC OR battery > 50%.
- **Worker pool**: Tokio multi-threaded runtime, capped at `min(4, available_cores - 2)`.
- **Tasks**: re-route low-confidence captures, re-embed delta-modified notes, recompute folder medoids, vacuum SQLite WAL, rotate heal_log/action_trace, propose skills (§11 Phase 12.5).
- **Preemption**: any user input (keystroke, hotkey, capture) within `agent_core/src/lifecycle/idle_monitor.rs` triggers `cancel_all` on NightBrain. Tasks check `ctx.cancellation_token` between batch units (every 32 items typically).
- **Persistence**: each task writes a `<task>.checkpoint.json` after each batch unit. Resumable on next idle window.

---

## 8. Intent-to-Effect State Pattern

The LLM never mutates state. It emits an `Intent`. The runtime applies the `Effect`. Swift observes the new state and re-renders.

```rust
// agent_core/src/intent/mod.rs
#[derive(Serialize, Deserialize, Clone)]
#[serde(tag = "action")]
pub enum Intent {
    #[serde(rename = "vault.write")]
    VaultWrite { path: String, body: String, frontmatter: Value },
    #[serde(rename = "vault.move")]
    VaultMove { from: String, to: String },
    #[serde(rename = "vault.delete")]
    VaultDelete { path: String },
    #[serde(rename = "concept.create")]
    ConceptCreate { canonical_name: String, definition: String },
    #[serde(rename = "concept.alias")]
    ConceptAlias { canonical_name: String, alias: String },
    #[serde(rename = "memory.write")]
    MemoryWrite { entry: MemEntry },
    #[serde(rename = "noop")]
    Noop { reason: String },
    #[serde(rename = "abort")]
    Abort { reason: String },
}

pub trait IntentApplier {
    async fn apply(&mut self, intent: Intent) -> Result<Effect, ApplyError>;
}
```

The Swift side observes the resulting `Effect` via UniFFI async stream and re-renders.

### 8.5 Universal undo

Every applied `Effect` is appended to `undo_log.sqlite` with the inverse operation pre-computed:

```sql
CREATE TABLE undo_events (
  id INTEGER PRIMARY KEY,
  ts TEXT NOT NULL,
  session_id TEXT NOT NULL,
  intent JSON NOT NULL,
  effect JSON NOT NULL,
  inverse JSON NOT NULL,    -- pre-computed reverse Effect
  ttl_until TEXT NOT NULL,  -- 24h from ts
  undone INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX undo_ttl ON undo_events (ttl_until);
```

The inverse is computed at intent-apply time, not at undo time — this guarantees undo always works even if the world has moved on (e.g. the file was deleted by the user). For destructive Intents (`vault.delete`), the inverse is a soft-delete restore from a 24h shadow copy.

Reversible: `vault.write` (reverse: delete or restore prior content), `vault.move` (reverse: move back), `concept.alias` (reverse: remove alias), `memory.write` (reverse: tombstone). Special case: `vault.delete` (handled via shadow copy). Irreversible: `action.shell` (Pro only, never undoable).

A NightBrain job evicts expired entries. ⌘Z opens an undo HUD listing the last N reversible effects; one keystroke per row reverts.

---

## 9. Minimalist Capture Surface

One global hotkey: `⇧⌘Space` opens a single text field. No folder picker. No tag picker. No template picker. No model selector.

Submit triggers:

1. `vault.quick_capture` → persist raw to `_inbox/raw/`.
2. `structure.route_folder` → pick destination (≤800ms p95).
3. `apply` → write to chosen destination, emit ActionTrace.
4. **Toast** (2s, fades): *"Routed to research/training-tricks · ⌘Z undo · ⌘. triage"*.

That's the entire surface. The toast is the **revelation moment** that proves the machinery is alive.

`⌘Z` within 24h triggers `Effect::Reverse` — every applied effect is invertible. `⌘.` opens the **review queue** with the current capture pre-selected for triage.

Voice: `⌃⌘Space` → SpeechAnalyzer → text → same pipeline. Screenshot: `⇧⌘5`-like → Vision OCR → text → same pipeline.

### 9.5 Three-Layer Disclosure Architecture

- **Layer 1 — Ambient (always visible)**: capture surface, search bar, AI input, current note, inbox count badge. No model selectors, no tool toggles, no folder pickers, no confirmation dialogs.
- **Layer 2 — On-demand (one keystroke)**: action trace (`⌘?`), review queue (`⌘.`), backlinks panel, concept graph view, alternative-suggestion list. Each loads its detail only when invoked.
- **Layer 3 — Deep (debug, hidden)**: schema inspector, model swap, raw `_meta` envelopes, retry-budget tuning, embedding-model swap. Gated by `EPISTEMOS_DEBUG=1`. Ships disabled.

The same three-layer principle governs **LLM context loading**: per-step context assembly loads only the tools, schemas, and graph fragments the current step requires. `meta.discover` returns the candidate tool *names*; only the selected tool's schema is materialized into the prompt. This eliminates the 30-MCP-server context bloat issue and reduces per-call tokens by ~98% versus a "load everything" approach.

### 9.6 UX Pattern Borrows

| Inspiration | Pattern | Integration |
|---|---|---|
| Things 3 | Aesthetic minimalism + spatial memory | No visual borders. High-typography focus. Notes/captures rely on spatial arrangement, not labels. |
| Raycast | Global omnibar + invisible parsing | `⌘K` system-wide bar parses natural language ("add milk to groceries") to structured intent without dedicated UI. |
| Arc | Adaptive sidebars + fluid workspaces | Folder tree fluidly reorders by semantic relevance to the active note. No pinned-everywhere global tree. |
| Linear | Keyboard-centric determinism | Every action — capture, search, ask, summarize, route, undo — has a deterministic shortcut. Mouse never required. |
| Tana | Object-oriented supertags | `#meeting` instantiates a structured object with AI-populated attendees/actions; merges text and database. |
| Logseq | Journal-first ingestion | Daily journal is the default capture surface; auto-structure routes async to permanent ontological homes. |

### 9.7 Action trace UI

⌘? on any artifact opens a translucent overlay anchored to that artifact:

- **Header**: artifact id, when, what tool produced it.
- **Trace timeline** (vertical, scannable): each row = one variant attempt, showing tool name, variant id, status, latency_ms, confidence. Failed variants are grey-strikethrough; the winning variant is bold.
- **Heal steps** (if any): nested under the variant they corrected. Original intent, error, corrected intent, outcome.
- **Alternatives** (for routing decisions): the top-5 candidates with scores. One keystroke moves the artifact to an alternative.
- **Concept lineage** (for placed captures): the canonical concept name, alias path, neighboring notes.
- **Footer**: "Undo this action (⌘Z)" / "Train router to prefer alternative (⌘T)" / "Open in Finder (⌘O)".

The overlay is read-only by default. Editing requires explicit modifier (⌘E).

The trace UI is the **single most important UX surface** in the application. If it ships broken or laggy, hidden automation collapses. Phase 8 verification must include: trace open ≤80ms p95, trace data load ≤200ms p95, trace UI handles 10k-event traces without jank.

---

## 10. Settings — Seven Rows, No More

```
Vault location ........ /Users/jojo/Vault
Capture hotkey ........ ⇧⌘Space
Search hotkey ......... ⌘K
Cloud .................. Off | Generator only | Inference + Generator   (default: Generator only)
Telemetry ............. opt-in
Pause automation ...... [   ] (off)
API keys .............. › (Keychain-backed sub-pane)
```

Anything else is system-tuned. Confidence thresholds, retry budgets, embedding model choice, defer-rate target — none are user-facing. A debug pane exists; it ships disabled and is gated by `EPISTEMOS_DEBUG=1`.

### 10.1 Vault privacy tiers (debug-only at first)

Three vault-encryption tiers; default is tier 1:

- **Tier 1 — APFS file-level**: rely on FileVault (full-disk encryption, almost universal on modern Macs). No app-level encryption. Default. Adds zero overhead.
- **Tier 2 — App-level AES-256-GCM**: vault notes encrypted with a key stored in Keychain. Each note encrypted independently for granular access. Embedding indices encrypted (cosine search runs on plaintext after in-memory decrypt). Costs ~5% of search latency.
- **Tier 3 — Passphrase-derived**: tier 2 + Argon2id-derived key from a user passphrase. App requires unlock per session. Highest privacy; significant friction.

Tier choice lives in the debug pane initially; surface in Settings only after Phase 12 dogfooding shows users want it. Switching tiers is a re-encryption batch job mirroring the embedding-model migration in Phase 11.5.

---

## 11. Phase-by-Phase Implementation Sequence

### 11.0 Wave-to-phase mapping

| Wave | Master Plan Phases | Outcome |
|---|---|---|
| Wave 0 — Foundation | Phase 0.5 (first-run), Phase 1 (formats), Phase 2 (registry/grammar) | Hybrid file formats valid; tools callable through llguidance |
| Wave 1 — Spine | Phase 3 (route), Phase 4 (heal), Phase 8 (Intent-to-Effect + action trace + undo) | Routing reliable, self-healing live, trust UI shipped |
| Wave 2 — Daily driver | Phase 5 (skills), Phase 6 (local inference), Phase 6.5 (per-model bench), Phase 7 (MWP), Phase 9 (capture surface), Phase 10 (settings) | Capture-to-structure end-to-end on user's machine |
| Wave 3 — Differentiation | Phase 11 (eval CI), Phase 11.5 (embedding migration), Phase 12 (docs); plus knowledge/code tool families per the prior tool-catalog report | Agentic differentiator features land |
| Wave 4 — Pro | Pro-only tools (action.*) — gated behind profile, not in this plan's scope | Pro release |
| Wave 5 — Meta | Phase 12.5 (skill discovery), `meta.compose` skills, persisted Voyager-style procedural memory | Self-extending agent |

**Action-trace must be in Wave 1 (Phase 8) before Wave 2 ships any user-facing surface — this is the trust gate.** No shippable Phase 9 without Phase 8 in production.

### Phase 0.5 — First-run bootstrap

When the user opens the app for the first time:

1. Vault location prompt (one folder picker, default `~/Documents/Epistemos`).
2. Model download in background — a single 1.5B-class router model (~1GB) plus the embedding model (~140MB). User can capture immediately; routing falls back to "DEFER all" until the model is resident.
3. Initial folder scaffold: `_inbox/`, `_inbox/review/`, `daily/`, `notes/` — minimal, user-extensible.
4. The first capture surfaces a 1-line tooltip: "Press ⇧⌘Space anywhere to capture. ⌘? to see what the system did."

No wizard. No "advanced settings." No "do you want telemetry" modal — telemetry is opt-in via the seven-row Settings, off by default.

**Exit**: fresh install → first capture → toast → cmd-? action trace, all in <90s including first-time model download on a 100Mbps connection.

### Phase 1 — Hybrid file formats and schema infrastructure

**Scope**: Define `.mem`, `.soul.json`/`.soul.md` pair, `.skill.json`/`.skill.md` pair. Implement:
- `agent_core/schemas/mem.v1.json`, `soul.v1.json`, `skill.v1.json`, `intent.v1.json`, `tool_meta.v1.json`.
- `agent_core/src/format/mem.rs` — parser/serializer for `.mem` (line-1 JSON header + body).
- `agent_core/src/format/soul.rs` — paired-file loader with bidirectional integrity check.
- Validation against JSON Schema 2020-12 via `jsonschema` crate.
- Round-trip property tests: parse → serialize → parse must be identity.

**Exit**: `cargo test format::` passes; 100% schema-validation coverage on test corpus of 40 fixtures.

### Phase 2 — llguidance compiler + tool registry

**Scope**:
- `agent_core/src/grammar/llg.rs` — JSON-Schema → llguidance compiler.
- `agent_core/src/tools/mod.rs` — `Tool` trait, `ToolMeta`, `ToolResult`, `Status`, `VariantId` (with `result` not `payload`).
- `agent_core/src/tools/runner.rs` — variant runner with output-schema validation, HealthCheck pre-flight, semantic cache.
- `agent_core/src/tools/registry.rs` — registry with `discover()`, `get()`, `build_tool_grammar()`.
- `agent_core/src/cache/mod.rs` — exact + semantic cache with SQLite backing.

**Exit**: A canary tool (`reason.think`) can be invoked through the runner with grammar-constrained output validated against schema. `cargo test grammar:: tools:: cache::` passes.

### Phase 3 — `structure.route_folder` with all four variants

**Scope**:
- Folder-medoid index (incremental, persisted).
- Variant A (centroids, 0.85 threshold), B (closed-vocab GBNF, 0.75), C (concept-anchored, 0.70 with merge/create_folder support), D (defer to inbox/review).
- Concept canonicalizer (`agent_core/src/canon/mod.rs`) with English default.
- Alias table (`agent_core/src/canon/alias.rs`, persisted per concept node).
- Eval harness: 200 hand-labeled captures with expected folder placement.

**Exit**: Eval harness reports ≥85% top-1 accuracy on placed captures, defer rate within 8–15% target band, zero schema violations on output.

### Phase 4 — Self-healing Try-Heal-Retry + circuit breakers

**Scope**:
- `agent_core/src/heal/mod.rs` — `HealLoop`.
- `agent_core/src/heal/breaker.rs` — `CircuitBreaker` (per-tool).
- `agent_core/data/heal_log.sqlite` — heal events persistence (WAL mode).
- Diagnostic soul file at `agent_core/souls/diagnostician.soul.{json,md}`.

**Exit**: Inject 50 synthetic failures across 10 tool types; verify heal recovery rate ≥70%, breaker correctly opens at threshold, log contains every event with full intent diff.

### Phase 5 — Native skills (Spotlight + Vision + voice)

**Scope**:
- `Epistemos/Skills/SpotlightSkill.swift` + UniFFI binding.
- `Epistemos/Skills/VisionOCRSkill.swift` + UniFFI binding.
- `Epistemos/Skills/SpeechSkill.swift` (SpeechAnalyzer on macOS 26, whisper.cpp fallback).
- `capture.screenshot`, `capture.voice`, `capture.clipboard`, `vault.search` Spotlight variant.

**Exit**: End-to-end voice → text → route → write succeeds in <2s p95 on M-series. Screenshot → OCR → route → write succeeds with bounding-box preservation.

### Phase 6 — Local inference (MLX-Swift + MLX-Structured primary) + ModelLease + per-model wiring

**Scope**:
- `agent_core/src/inference/mod.rs` — `LocalInference` trait.
- `agent_core/src/inference/mlx.rs` — `MlxEngine` (default, via UniFFI to MLX-Swift).
- `Epistemos/Inference/MlxConstrainedRunner.swift` — `GrammarMaskedLogitProcessor` integration.
- `agent_core/src/inference/llamacpp.rs` — `LlamaCppEngine` (alternative for llama.cpp-only checkpoints).
- Reference-counted `ModelLease` cache with idle-TTL unload (60s).
- Grammar-constrained generation through MLX-Structured as primary, LM-Format-Enforcer as fallback, llguidance via Rust FFI as escape hatch.
- Power/thermal awareness (§6.10) wiring.
- Speculative decoding pair (Llama-3.2-1B draft × Hermes-3-8B verifier; Qwen-1.5B draft × Qwen-7B verifier).
- Crash safety contract (§6.9) implementation.
- Tool-call format normalizer (§6.5).
- Per-model wiring per §6.6 — each model gets its bespoke few-shot, temperature, reasoning budget, format.
- Model selection router (§6.7).
- **Grammar-Aligned Decoding (§22.1.1)** — `agent_core/src/grammar/aligned.rs` + Swift `Epistemos/Inference/AlignedLogitProcessor.swift` overriding the default mask-and-rescore.
- **CRANE open-thinking + closed-commit (§22.1.2)** — `agent_core/src/grammar/crane.rs` with sentinel-token region switching; applied to every reasoning-bearing tool by default.
- **IterGen backtrack-and-edit (§22.1.3, §22.1.4)** — `agent_core/src/heal/itergen.rs` with KV-snapshot management at grammar-symbol boundaries; integrated into the heal loop (§5.2) so semantic failures patch only the failing span instead of regenerating.

**Exit**: Cold-load to first-token <1.5s for 1.5B, <4s for 7B. Generation ≥30 tok/s on 7B 4-bit. Idle unload reclaims ≥95% of resident memory within 90s. MLX-Structured and LM-Format-Enforcer paths produce identical grammar emissions on the 50-case shape eval. The 12 models in §6.6 all load and produce schema-valid output for at least one canary tool. Grammar-Aligned Decoding produces ≥98% identical top-1 picks vs zero-out baseline on a 50-sample control set with measurably higher BERTScore on the structured-output benchmark. CRANE wins by ≥7% accuracy on a 50-case hard-reasoning eval vs constrained-only with no structural-compliance regression. IterGen recovers ≥85% of synthetic 100-case fault injections within 1 backtrack and ≥97% within 3 backtracks, median backtrack <500ms.

### Phase 6.5 — Per-Model Benchmark and Calibration

This is a **new phase** specifically for the per-model engineering work. It runs after Phase 6's engine wiring and before any tool ships against the models.

**Scope**:
- `agent_core/src/eval/per_model.rs` — harness that runs the same 50-case shape eval on every model in §6.6.
- For each model: capture cold-load time, first-token latency, sustained tok/s, schema-compliance rate, refusal-correctness rate (BFCL-style), repeat-loop incidence.
- Per-model `agent_core/eval/baselines/<model_id>.json` baseline files.
- Calibration: per-model thresholds may differ — Variant B's 0.75 floor is set against Qwen2.5-1.5B; Hermes-3-8B may calibrate higher (0.80) because it self-reports confidence more conservatively. Calibration is data-driven, written into the model's soul-file `confidence_offset` field.
- Per-model few-shot exemplar tuning: each model's `prompts/<tool>/<model_id>/few_shot.md` is hand-curated; exemplars are not shared across models.

**Exit**: Per-model baseline file exists for all 12 models. Each model passes:
- Schema compliance ≥99% on its eval slice.
- Refusal correctness ≥90% (model declines to call tools when it should — measured against a 30-case "you should not call any tool" eval).
- No repeat-loops on a 100-iteration adversarial set.

The per-model files are checked into the repo so the agent's behavior is reproducible session-to-session.

### Phase 7 — Model Workspace Protocol orchestrator + NightBrain

**Scope**:
- `agent_core/src/workspace/mod.rs` — numbered-folder pipeline runner.
- Replay support: rerun stage N with identical inputs.
- Workspace inspector CLI: `epistemos workspace show <job_id>`.
- `agent_core/src/lifecycle/idle_monitor.rs` + `agent_core/src/nightbrain/mod.rs` — NightBrain runner with cancellation.

**Exit**: A 4-stage MWP pipeline (concept-extract → canonicalize → route → apply) processes a 100-capture batch deterministically; replay of stage 3 produces byte-identical outputs. NightBrain processes 500 captures/min sustained, preempts cleanly on user input.

### Phase 8 — Intent-to-Effect bridge + universal undo + observability

**This phase blocks Phase 9.** The action trace UI is the trust mechanism that justifies all hidden automation. Phase 9 capture surface ships only after Phase 8 is in production.

**Scope**:
- `Intent` enum (Phase 1 schema implementation).
- `IntentApplier` impl for vault, concept graph, memory, settings.
- UniFFI async stream of `Effect` events to Swift.
- Action-trace persistence (`agent_core/data/action_trace.sqlite`).
- `agent_core/src/undo/mod.rs` — universal undo log with pre-computed inverses.
- `tracing` integration; metrics persistence; `os_signpost` regions on all variants.
- Action-trace UI in Swift (`Epistemos/Trace/ActionTraceView.swift`).

**Exit**: Every Phase 3–7 operation routes through `Intent` → `Effect`; Swift subscribes to the stream and re-renders without polling. ⌘? opens trace for any artifact in <80ms p95. ⌘Z reverses any auto-decision within 24h, in <100ms. Trace UI handles 10k events without jank.

### Phase 9 — Capture surface (Swift UI)

**Scope**:
- `Epistemos/Capture/CaptureWindow.swift` — global-hotkey single-field surface.
- Toast component with undo / triage actions.
- Triage queue UI (`Epistemos/Capture/ReviewQueueView.swift`).

**Exit**: ⇧⌘Space → type → submit → toast in <800ms p95 measured on M-series. ⌘Z reverses within 24h. ⌘. opens triage with capture preselected.

### Phase 10 — Settings collapse + debug pane

**Scope**:
- Reduce existing settings surface to the seven rows in §10.
- Move legacy settings behind debug pane gated by `EPISTEMOS_DEBUG=1`.
- Privacy tier UI (debug-only initially per §10.1).

**Exit**: Settings UI shows only the seven rows in default builds.

### Phase 11 — Eval harness and CI gates

**Scope**:
- 200-case capture eval set (folder placement labels).
- 50-case tool-call shape eval (per-model GBNF emission).
- 30-case heal-recovery eval.
- 20-case throughput eval (concurrent runs).
- CI job runs eval on every PR; zero regressions required.

**Exit**: CI green; first eval baseline committed as `agent_core/eval/baselines/<git-sha>.json`.

### Phase 11.5 — Embedding-model migration plan

When the embedding model is changed (rare; vault-pinned by default):

1. NightBrain detects pin mismatch on startup and surfaces a one-time prompt: *"Upgrade vault to {new_model}? Re-embed N notes (~M minutes)."*
2. On approval, the migration job:
   - Computes new embeddings in batches of 256 with the new model.
   - Writes to a parallel index (`embeddings_v2.sqlite`) — old index stays readable until cutover.
   - Recomputes folder medoids from the new index.
   - Atomic cutover: rename old → archive, rename new → primary. Vault metadata pin updated.
3. On crash mid-migration: resume from last-batch checkpoint. Old index remains primary until cutover.

The vault is fully usable (search, route, capture) during migration; routing uses the old index until cutover.

**Exit**: Synthetic 500-note vault upgrades cleanly; mid-migration kill-9 → resume → byte-identical final state.

### Phase 12 — Documentation and migration

**Scope**:
- Update `docs/AGENT_PROGRESS.md` with all phases ✅.
- Write `docs/QUICK_CAPTURE_USER_GUIDE.md` (user-facing, 1 page).
- Add migration note in `docs/APP_ISSUES_AUTO_FIX.md` for any `.md` notes that should opportunistically promote to `.mem`.

**Exit**: All references in this plan link correctly; the user guide reads as one page from cmd-? in-app.

### Phase 12.5 — Skill discovery

When the agent successfully completes a multi-tool composition (`meta.compose`), the runtime checks:
- Was this composition novel (no existing skill matches by tool-sequence-hash)?
- Did it succeed within latency budget?
- Did the user accept the result (no ⌘Z within 5 minutes)?

If all three, the runtime drafts a `.skill.json` + `.skill.md` pair into `agent_core/data/proposed_skills/`, named after the inferred goal. A weekly NightBrain digest surfaces these in the review queue: *"You've done X 4 times this week. Save as a skill?"* User accepts → moves to active skills directory; declines → tombstoned, never re-proposed.

This is on-device, lazy, and never silent — every promotion is user-confirmed. Voyager's autonomy is replaced with progressive disclosure.

---

## 12. Verification Commands

| Phase | Command |
|---|---|
| 0.5 | Manual: fresh install, first capture, ⌘? trace — all <90s |
| 1 | `cargo test --manifest-path agent_core/Cargo.toml -p agent_core format::` |
| 2 | `cargo test --manifest-path agent_core/Cargo.toml grammar:: tools:: cache::` |
| 3 | `cargo run --manifest-path agent_core/Cargo.toml --bin route_eval -- --set agent_core/eval/route_v1.jsonl` |
| 4 | `cargo run --manifest-path agent_core/Cargo.toml --bin heal_eval -- --inject 50` |
| 5 | `xcodebuild -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SkillsTests 2>&1 \| xcbeautify` |
| 6 | `cargo bench --manifest-path agent_core/Cargo.toml --bench inference -- --engine mlx,llamacpp` |
| 6.5 | `cargo run --manifest-path agent_core/Cargo.toml --bin per_model_eval -- --models all --tasks routing,concept,plan,code,cite` |
| 7 | `cargo run --manifest-path agent_core/Cargo.toml --bin workspace_runner -- --batch agent_core/eval/batch_100.jsonl --replay 3` |
| 8 | `cargo test --manifest-path agent_core/Cargo.toml intent:: undo:: trace::` and `swift test --filter ActionTraceTests` |
| 9 | `xcodebuild -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CaptureSurfaceTests 2>&1 \| xcbeautify` |
| 10 | `swift test --filter SettingsCollapseTests` |
| 11 | `cargo run --manifest-path agent_core/Cargo.toml --bin eval_all` |
| 11.5 | `cargo run --manifest-path agent_core/Cargo.toml --bin embedding_migration_test -- --kill-mid` |
| 12 | grep verify all `[file](path)` links resolve; `cat docs/AGENT_PROGRESS.md` shows all ✅ |
| 12.5 | `cargo test --manifest-path agent_core/Cargo.toml skill_discovery::` |

Each phase's verification **must pass** before commit.

---

## 13. Risks and Open Questions

1. **Embedding-model pinning**: changing it invalidates folder medoids and concept index. Pin per-vault in vault metadata. Migrations explicit (Phase 11.5), batched, never silent.
2. **GBNF performance at 4-bit quantization**: structured-emission rate can drop. Phase 11 eval must catch this; runtime fallback to higher-bit quant or cloud.
3. **Defer-rate calibration**: too high → review-queue burden; too low → wrong-place errors. Target 8–15%. Tune in first dogfooding month.
4. **Variant-ladder cost amplification**: 4-variant tool × 100 calls/day = nontrivial. Cache (§3.6) absorbs the worst of it; surface variant cost in telemetry.
5. **llama.cpp vs MLX engine drift**: two engines must produce identical grammar emissions. CI must run the 50-case shape eval on both.
6. **Concept canonicalizer multilingual support**: English-first; per-language normalizers added on demand (§3.7).
7. **Action-trace storage cost**: ring-buffer 30 days at full fidelity; summarize older; cap at vault-relative size.
8. **macOS 26 entitlement creep**: SpeechAnalyzer, ScreenCaptureKit, Vision all require explicit entitlements. Phase 5 must confirm App Store profile compatibility before lock-in.
9. **Schema versioning**: `_meta.schema_version` mandatory; tolerate older traces during replay. Migration registry at `agent_core/src/tools/schema_migrations.rs`.
10. **Soul file orphans**: paired-file integrity check at load time. Orphans (one half missing) reject loudly, never silently fall back.
11. **Throughput regression**: NightBrain target ≥500 captures/min. Phase 11 throughput eval is the gate; regressions block merge.
12. **Thermal cliff**: aggressive variant-C usage on a hot machine can amplify thermal throttling. §6.7 power-aware downgrade is the mitigation; eval under simulated thermal pressure.
13. **Cache coherence**: cache invalidation on `vault.write` events must be transactional with the write. Test: write + immediate cache lookup → must miss.
14. **Speculative decoding edge cases**: draft↔verifier disagreement loops. Bound at 3 retries before falling back to verifier-only.
15. **Undo log unbounded growth**: 24h TTL + NightBrain eviction. Test: simulate 100k events/day; verify steady-state size.

---

## 14. Implementation-Note Stubs (fill these in per phase)

```
### Phase N implementation note (filled by agent)

**Web research consulted**:
- [ ] (URL) — (1-line takeaway)
- [ ] (URL) — (1-line takeaway)

**Disk research consulted**:
- [ ] (path) — (1-line takeaway)

**What changed my mind**:
(Paragraph: what did the research surface that wasn't in this plan? What did I update?)

**Verification command run**: `<command>`
**Result**: <green/red, key metric>
**Commit**: <sha>
```

---

## 15. References — Read Before Coding

### Internal docs (in this repo)

- [`docs/EPISTEMOS_FUSED_v3.md`](EPISTEMOS_FUSED_v3.md) — master spec.
- [`docs/AGENT_PROGRESS.md`](AGENT_PROGRESS.md) — current state of agent system.
- [`docs/agent-system/AGENT_ARCHITECTURE.md`](agent-system/AGENT_ARCHITECTURE.md) — non-negotiable architecture.
- [`docs/HERMES_INTEGRATION_RESEARCH.md`](HERMES_INTEGRATION_RESEARCH.md) — local-model tool calling.
- [`docs/INSTANT_RECALL_ARCHITECTURE.md`](INSTANT_RECALL_ARCHITECTURE.md) — recall pipeline grounding.
- [`docs/IMPLEMENTATION_BLUEPRINT.md`](IMPLEMENTATION_BLUEPRINT.md) — prior blueprint patterns.
- [`docs/HARDENING_VERIFICATION.md`](HARDENING_VERIFICATION.md) — hardening checklist style.
- [`docs/CONTROL_PLANE_RESEARCH.md`](CONTROL_PLANE_RESEARCH.md) — orchestration prior art.
- [`docs/CUSTOM_TEXT_ENGINE_RESEARCH.md`](CUSTOM_TEXT_ENGINE_RESEARCH.md) — UI surface integration.
- [`docs/APP_ISSUES_AUTO_FIX.md`](APP_ISSUES_AUTO_FIX.md) — open runtime issues.
- [`CLAUDE.md`](../CLAUDE.md) — project rules.
- User memory: `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md` and all linked files.
- `~/.claude/plans/gleaming-jingling-thimble.md` — full R2/R3/audit delta brief.

### External research — required web searches per phase (see §0.1)

The 2026-04-28 user-supplied architectural blueprints (R2 + R3) and the 2026-04-28 deep-research tool-catalog report establish normative inputs for this plan.

### Suggested external reading (with citations)

**Constrained decoding**
- **XGrammar** — arxiv:2411.15100. JSON-Schema mask compute at <40 µs/token on 128k tokenizer.
- **llguidance** — github.com/guidance-ai/llguidance. Rust-native, Earley/PDA, JSON-Schema-direct.
- **Outlines** — dottxt-ai. FSM construction for structured generation.
- **lm-format-enforcer** — github.com/noamgat/lm-format-enforcer. Token prefix-tree intersection, more flexible than FSM.
- **JSONSchemaBench** — arxiv:2501.10868. Coverage and latency benchmarks across constraint engines.
- **MLX-Structured `GrammarMaskedLogitProcessor`** — rudrank.com/exploring-mlx-swift-structured-generation-with-generable-macro. Primary backend on MLX-Swift.
- **Microsoft Guidance / SGLang `select`** — subset constraint primitives.

**Function calling and small-model parity**
- **Hermes-3 technical report** — arxiv:2408.11857. Strong steerability; XML tool-call format.
- **Hermes-Function-Calling** — github.com/NousResearch/Hermes-Function-Calling.
- **Qwen function-calling docs** — qwen.readthedocs.io/en/latest/framework/function_call.html. Qwen 2.5+ adopted Hermes XML wrapping.
- **BFCL leaderboard** — function-calling benchmark.
- **ToolHop** — arxiv:2501.02506. Multi-step tool-calling eval.
- **Brief Is Better** — arxiv:2604.02155. Qwen 1.5B reasoning peaks at d≈32 tokens; 7B peaks slightly higher but degrades past 256.
- **Tam et al. EMNLP 2024** — reasoning-then-answer ordering in structured output.
- **Hugging Face guided-decoding study** — huggingface.co/blog/nmmursit/guided-decoding. 2-shot bumps Outlines compliance from ~93% to ~97%.

**Memory and agent architecture**
- **A-MEM** — arxiv:2502.12110. Atomic notes with link evolution.
- **MemGPT / Letta** — paged-memory operating-system metaphor.
- **Voyager** — arxiv:2305.16291. Skill library as procedural memory.
- **Memory in the Age of AI Agents survey** — arxiv:2512.13564 (Dec 2025).
- **CoALA trichotomy** (Princeton 2023) — episodic / semantic / procedural memory.
- **Self-RAG, Reflexion, ReAct, ReWOO, Tree-of-Thoughts, Plan-and-Solve** — reasoning scaffolds for grounded generation.
- **TRACER** (2024) — formal "learning to defer" framework with confirmation-based training.

**Filesystem and PKM**
- **LSFS** — arxiv:2410.11843 (ICLR 2025). LLM-based Semantic File System with vector-indexed syscalls.
- **AIOS-LSFS** — github.com/agiresearch/AIOS-LSFS. Reference implementation.
- **Khoj** — github.com/khoj-ai/khoj. Local-first PKM with semantic search.
- **Reor** — github.com/reorproject/reor. Local-first note app with embeddings.
- **Tana supertag model** — unlocktana.com/blog/tana-vs-logseq. Closest prior art for concept canonicalization.
- **Logseq properties / Roam blocks** — alternative concept-as-page models.

**Platform and integration**
- **Mozilla UniFFI guide** — async Rust ↔ Swift contract; Send+Sync requirements.
- **llama.cpp** — Metal backend on Apple Silicon, speculative decoding via `--draft-model`.
- **Apple MLX** — github.com/ml-explore/mlx. Lazy evaluation, unified memory.
- **mlx-lm + LM Studio** — lmstudio.ai/blog/lmstudio-v0.3.4. ~25–60 tok/s on M-series for 7B 4-bit.
- **Apple Vision `VNRecognizeTextRequest`** — developer.apple.com/documentation/vision/recognizing-text-in-images.
- **WhisperKit** — Apple's CoreML port of Whisper.
- **NSMetadataQuery** — programmatic Spotlight; <50ms over the user home directory.

**The three load-bearing decode mechanisms (§22.1)**
- **CRANE — Constrained Reasoning Augmented Generation** (arxiv:2502.09061). Alternate unconstrained reasoning with constrained committal; preserves thinking quality.
- **IterGen — Iterative semantic backtracking** (ICLR 2025, openreview L6CYAzpO1k). Stored intermediate parser states + KV-cache reuse for backtrack-and-edit instead of regenerate.
- **Grammar-Aligned Decoding** (Park et al., NeurIPS 2024, proceedings 2bdc2267c3d7d01523e2e17ac0a754f3). Mask-and-rescore that preserves probability distribution shape over the valid subset.

**Cloud-as-Generator + Templater (R6)**
- **Voyager skill library** — arxiv:2305.16291. Cloud GPT-4 drafts JS code; local Minecraft executes; skills indexed by description embedding. The seminal pattern. We extend with pre-vetted skeletons and the four-gate mint pipeline.
- **Skill Trust and Lifecycle Governance Framework (G1–G4)** — arxiv:2602.12430. Static analysis → semantic intent classification → behavioral sandbox → permission manifest validation. Adopted wholesale into our Compile-Verify-Mint gate (§17.2 + §21.3).
- **Vericoding vs vibe coding** — POPL 2026 benchmark for formally-verified program synthesis. Establishes the category our mint pipeline targets (verified-by-construction), not the category we reject (prompt-and-pray code).
- **Claude Skills pattern** — instructions + scripts + domain expertise packaged as modular capabilities. Inspires the .skill format (§2.4) and the templater concept (§21.2).

**Auto-generation, sandboxing, and verified skill minting (R5)**
- **schemars (Rust)** — JSON Schema reflection from Rust types; backbone of §17.3 schema extraction.
- **proptest** — property-based testing for invariants in minted skills.
- **cargo-miri** — undefined-behavior detection for `unsafe` code in minted skills.
- **macOS `sandbox_init` / `sandbox-exec`** — entitlement-stripped child processes for skill mint sandbox.
- **MLX `mlx_lm.convert`** — local hardware-aware quantization with tunable group sizes and per-layer precision.
- **ArcSwap (Rust)** — wait-free atomic pointer swap for runtime grammar updates (§17.3).
- **content-addressed storage (sha256 over canonical JSON)** — pinning minted skill grammars by hash for cache invalidation.

**Patterns explicitly *not* adopted as frameworks** — borrow ideas, do not depend
- **OpenCode and CLI-agent peers** — sandboxed code-gen patterns borrowed; subprocess/TTY orchestration not adopted (§18.6).
- **Ollama, LocalAI, vLLM, llama-server** — generic local-LLM runtimes; we use MLX-Swift directly to avoid subprocess inference (§20.5).
- **Vercel, hosted activation, telemetry SaaS, remote feature flags** — explicitly excluded (§1.4).
- **External MCP servers** — `action.mcp_dispatch` is opt-in peer surface for Pro users only; never primary (§1.4, §6.7).

**Trust and UX**
- **Cormack et al. 2009** — Reciprocal Rank Fusion baseline for hybrid retrieval.
- **Lee & See 2004** — calibrated trust in automation.
- **Claude Skills pattern** — snyk.io/articles/top-claude-skills-ui-ux-engineers. Progressive disclosure over a tool surface.
- **uxplanet.org/claude-code-vs-cursor** — Accelerator vs Delegator paradigm comparison.

---

## 16. Definition of Done

Quick Capture is shippable when:

1. ⇧⌘Space → type → submit → toast in <800ms p95 on M-series.
2. 200-capture eval reports ≥85% top-1 placement, 8–15% defer rate, zero schema violations.
3. ⌘Z reverses any auto-decision within 24h, in <100ms.
4. ⌘? opens action trace from any artifact in <80ms p95 and shows full reasoning trace; UI handles 10k-event traces without jank.
5. Same 200-capture eval passes on Qwen2.5-1.5B, Qwen2.5-7B, Hermes-3-Llama-3.1-8B, Phi-3.5-mini local models, and Claude Haiku 4.5 cloud — **identical placement on ≥80% of cases across all five**.
6. NightBrain throughput ≥500 captures/min sustained on local 7B; preemption on user input <50ms.
7. 7-day dogfood with the user shows zero data loss, zero unrecoverable failures, ≤3 user-corrected mis-routes.
8. App Store profile compiles and runs the entire pipeline (no Pro-only tools on the hot path).
9. MLX-Structured and LM-Format-Enforcer paths produce identical grammar emissions on the 50-case shape eval. Phase 6.5 per-model bench has baseline files for all 12 models in §6.6 with ≥99% schema compliance and ≥90% refusal correctness on each.
10. First-run experience: fresh install → first successful capture → ⌘? action trace, all in <90s including model download.
11. Crash safety: kill-9 during a route or migration → restart → byte-identical final state on the recovered files.
12. **Per-model parity**: each of the 12 models in §6.6 has a working soul file, calibrated `confidence_offset`, hand-curated few-shot exemplars, and passes its eval slice. No model is "wired generically" — every model is engineered specifically.
13. **Action enum coverage**: the 200-case eval contains examples that exercise all four actions (`place`, `merge_into_existing_note`, `create_folder`, `defer`) and the system handles each correctly.
14. `docs/AGENT_PROGRESS.md` shows phases 0.5–12.5 ✅ with sha references.
15. **Tool/skill surface scale**: registry contains ≥61 Tier-1 tools, ≥150 Tier-2 auto-minted variants, ≥80 Tier-3 skills. Each has a sealed mint record (Tier 2 + 3) or a hand-author review record (Tier 1). Total ≥300 callable units.
16. **Auto-mint quality**: at least 95% of mint attempts pass the gate without revision; tombstone rate <2% over 30-day window; zero crashes traced to a minted skill.
17. **100% deterministic syntactic correctness**: across the 200-case eval, schema-validation pass rate is **100%** for the local path (this is the breakthrough's testable claim — sampler-bound dispatch makes invalid output structurally impossible).
18. **Local-first proof**: with the network disabled, the entire 200-case eval still passes top-1 placement at ≥85% (the same threshold as with cloud allowed). If cloud is required for ≥85%, the local path is not yet good enough.
19. **No subprocess inference**: `ps -ef | grep epistemos` during a heavy capture session shows the main app process and (Pro profile only) the Hermes orchestration subprocess. No additional inference processes, no llama-server, no Python on the inference path.
20. **Cloud-Off mode parity**: with the Cloud setting set to `Off`, the system passes the 200-case eval at ≥80% top-1 placement and successfully mints ≥10 skills via local generation alone. The local-only path is provably usable.
21. **Generator-only mode behavior**: with Cloud set to `Generator only`, no cloud calls fire during routine inference (verified by network trace over a 30-minute dogfood session); cloud calls fire only during explicit `meta.draft_*` operations (verified in action trace).
22. **Templater coverage**: Phase 12.5 ships with ≥15 templates spanning vault, knowledge, memory, capture, structure, code, reasoning, system, plus a multi-step skill template. Each template has ≥3 reference exemplars and a verified test fixture.
23. **First-pass mint rate via templates**: ≥95% of cloud-generator drafts that target an existing template pass the §17.2 gate without revision. Free-form (no-template) drafts are not held to this bar.
24. **Three load-bearing decode mechanisms ship and verify**: Grammar-Aligned Decoding (§22.1.1), CRANE (§22.1.2), and IterGen (§22.1.3) all pass their Phase 6 verification gates and are active by default on every reasoning-bearing tool. The heal loop's median recovery time on validation failures drops to <500ms (vs ~3000ms for full regeneration) because IterGen edits the failing span in place rather than regenerating.

That is the bar.

---

## 17. Breakthrough — Compile-Verify-Mint + Sampler-Bound Tool Dispatch

This section is the architectural insight that makes everything else in this plan reach the user's ambition (300+ tools, 100+ skills, 100% deterministic local execution, no cloud dependency for correctness). It was derived from Round 5 research; it unifies all five user demands into a single mechanism.

### 17.1 The insight

**The grammar is the dispatch table.** When the local model is generating a tool call, the MLX-Structured `GrammarMaskedLogitProcessor` enforces the grammar at the sampler level. The grammar is compiled from the tool registry's JSON Schema. The model literally cannot emit a syntactically invalid call — the sampler zeros out invalid tokens at decode time. There is no "tool selection prompt", no "JSON parse and pray", no string regex post-hoc. The constraint *is* the dispatch.

Combined with hardware-aware quantization on Apple Silicon (4-bit on M-series is **compute-bound, not memory-bound**, because a 4.2GB 4-bit model streams in ~16ms at 273 GB/s on M4 Pro; the bottleneck is sequential decoding, not weight loading), the local path becomes:

- **Strictly more reliable than cloud on tool-call shape** (cloud cannot mask user-side logits; it can only validate post-hoc).
- **Faster than cloud on tool latency** (no network round-trip; ~600ms total for a structured tool call vs ~1.5–3s for cloud).
- **Cheaper than cloud at all scales** (zero marginal cost; throughput ≥10,000 ops/s for cached lookups).
- **Auditable** (every constraint is a grammar artifact; every grammar is content-addressed; every minted skill has a sealed test record).

### 17.2 The Compile-Verify-Mint pipeline

A skill (or tool) is **minted** only after passing this sealed gate. Once minted, it is added to the registry and immediately becomes deterministically callable by the local model on the next inference step.

```
[draft] ─► [compile] ─► [property tests] ─► [miri] ─► [sandbox load] ─► [schema extract] ─► [grammar compile] ─► [mint]
   │           │              │                │              │                  │                    │              │
   reasoning   cargo check    proptest         cargo miri    dyn-link in        schemars::          llguidance     register +
   model       (no I/O)       (≥3 invariants)  (UB-free)     test process       schema_for!         compile        index ANN
```

Each gate is a hard pass/fail. Failure at any gate sends the trace back to the reasoning model with the exact error and the model drafts a revision. A skill that fails 3 revisions is tombstoned; the user is never shown a half-working skill.

```rust
// agent_core/src/mint/mod.rs
pub struct MintPipeline {
    sandbox: Sandbox,
    test_runner: TestRunner,
    registry: Arc<RwLock<ToolRegistry>>,
    grammar_cache: Arc<RwLock<GrammarCache>>,
}

#[derive(Debug)]
pub enum MintOutcome {
    Minted { skill_id: SkillId, sha: ContentHash, registered_at: Instant },
    Rejected { stage: Stage, reason: String, revision_count: u8 },
    Tombstoned { skill_id: SkillId, total_revisions: u8 },
}

impl MintPipeline {
    pub async fn mint(&self, draft: SkillDraft) -> MintOutcome {
        let mut current = draft;
        for revision in 0..3 {
            match self.gate(&current).await {
                Gate::Passed { schema, code, tests } => {
                    let grammar = compile_grammar(&schema)?;
                    let sha = content_hash(&code);
                    self.grammar_cache.write().await.insert(sha, grammar);
                    self.registry.write().await.register(SkillEntry {
                        id: derive_id(&schema), code, schema, sha, tests
                    });
                    return MintOutcome::Minted { skill_id, sha, registered_at: Instant::now() };
                }
                Gate::Failed { stage, error } => {
                    current = self.revise(current, &stage, &error).await?;
                }
            }
        }
        MintOutcome::Tombstoned { skill_id: derive_id(&current.schema), total_revisions: 3 }
    }

    async fn gate(&self, draft: &SkillDraft) -> Result<Gate, ApplyError> {
        // 1. Compile
        self.sandbox.cargo_check(&draft.code).await?;
        // 2. Property tests
        self.test_runner.proptest(&draft.code, &draft.tests).await?;
        // 3. Miri (catches UB, leaks, aliasing)
        if draft.uses_unsafe() { self.sandbox.cargo_miri(&draft.code).await?; }
        // 4. Sandbox dyn-link load + execute against test harness in separate process
        let dylib = self.sandbox.build_dylib(&draft.code).await?;
        self.sandbox.run_in_subprocess(&dylib, &draft.tests).await?;
        Ok(Gate::Passed { schema: draft.schema.clone(), code: draft.code.clone(), tests: draft.tests.clone() })
    }
}
```

The sandbox is a Rust process running with `seccomp`-equivalent restrictions on macOS (`sandbox_init` + entitlement-stripped child process). No network. No filesystem outside a temp directory. No spawned subprocesses. The sandbox is the only place auto-generated code ever executes in test mode.

### 17.3 Sampler-bound tool dispatch

The tool registry exposes one thing the sampler needs at every inference step: **the current grammar** to apply. The grammar is rebuilt on registry change (new mint, removed tool, profile switch) and cached by content hash.

```rust
// agent_core/src/dispatch/sampler.rs
pub struct SamplerDispatch {
    grammar: ArcSwap<llg::Grammar>,
}

impl SamplerDispatch {
    pub fn current(&self) -> Arc<llg::Grammar> { self.grammar.load_full() }

    pub fn swap(&self, new: Arc<llg::Grammar>) {
        self.grammar.store(new);
        // Atomic; the next decode call picks up the new grammar at the next safe boundary.
    }

    pub fn rebuild(&self, registry: &ToolRegistry, profile: Profile) {
        let active = registry.active_for(profile);
        let dispatch_schema = build_dispatch_schema(&active);
        let new_grammar = llg::Grammar::from_json_schema(&dispatch_schema, JsonCompileOpts::default()).unwrap();
        self.swap(Arc::new(new_grammar));
    }
}
```

The `ArcSwap` ensures swaps are wait-free and never tear. The Swift-side `GrammarMaskedLogitProcessor` calls `current()` once at the start of each tool-dispatch token slot and holds that reference for the duration of the slot — no swap lands mid-token.

### 17.4 Why this is a 100% solution

100% syntactic correctness is provable: the sampler cannot emit invalid tokens because the constraint is enforced at the logit level. **Semantic** correctness (right tool, right args) is not 100% from the model alone — but the variant ladder + retry budget + minted-skill verification gives a *system-level* 100% bound on visibility: any semantic miss either succeeds on a later variant, defers to the user, or is logged with a heal-event that the next session can learn from. The user never sees a malformed call. The user never sees a crash from a bad tool. The user never sees an unverified skill execute.

### 17.5 Failure modes and bounds

- **Reasoning-model drafts an unverifiable skill**: the model loops in revision; after 3 revisions the skill is tombstoned. Bound: the user never sees a half-working skill.
- **Sandbox escape**: the sandbox process has minimum entitlements; even a successful escape is bounded by the sandbox container. macOS sandbox-init policy is the security boundary.
- **Grammar compile failure on a minted skill**: the mint pipeline's grammar-compile step is the last gate; if it fails, the skill is rejected. A registry entry without a compilable grammar cannot exist.
- **Sampler swap during decode**: `ArcSwap` is wait-free; the Swift-side grabs a snapshot at slot start. Swap takes effect on the next dispatch slot, not mid-call.
- **Skill drift across model swaps**: the skill's grammar is model-agnostic (JSON-Schema-derived); model-specific tuning lives in the model's soul-file `confidence_offset`, not in the skill itself. A skill works on every model in §6.6.

---

## 18. Auto-Generation Pipeline for Skills and Tools

This section formalizes how the Compile-Verify-Mint pipeline produces the 300+ tools and 100+ skills the user wants, **without hand-crafting every one** but **with verification gates that make every one production-grade**.

### 18.1 The three-tier hierarchy

All tools and skills live in one of three tiers. Each tier has different generation, verification, and review characteristics.

| Tier | Source | Verification | Estimated Size | Examples |
|---|---|---|---|---|
| **Tier 1 — Hand-crafted base** | Human-authored Rust code (this plan) | Static analysis + integration tests + the 200-case eval | ~50 tools | `vault.read`, `vault.search`, `structure.route_capture`, `knowledge.concept_extract`, `reason.plan` |
| **Tier 2 — Auto-generated adjacency** | Reasoning-model-drafted variants of Tier 1 tools (e.g. `vault.search_by_tag`, `vault.search_recent`, `vault.search_in_folder`) | Compile-Verify-Mint pipeline (§17.2) | ~150–200 tools | `vault.search_by_tag`, `memory.recall_episodic_window`, `knowledge.summarize_extractive_short` |
| **Tier 3 — Auto-generated composition skills** | `meta.compose` chains of 2–7 tools recorded as successful agent paths | Compile-Verify-Mint + observed-success criterion (§12.5) | ~100 skills | `weekly-review`, `meeting-followups`, `daily-research-digest`, `email-to-task` |

**Tier 1** is rigorously specified in this plan and the prior tool-catalog research report. It is the bedrock; it does not auto-generate.

**Tier 2** is auto-generated **lazily on demand** — when the model issues a search-by-tag call that doesn't yet exist as a tool, the dispatch handler intercepts, drafts the variant tool by reflecting on the closest existing Tier 1 tool, runs the mint pipeline, and registers if successful. The first call pays the latency cost of mint (~5–15s); subsequent calls hit the registry directly. NightBrain proactively mints high-frequency adjacency tools in idle time.

**Tier 3** is auto-generated from observed user patterns. When the agent successfully completes a multi-tool composition under the criteria of Phase 12.5 (novel sequence, accepted by user, within budget), the runtime drafts a skill, runs the mint pipeline, and surfaces the proposal. This is Voyager-style skill discovery with a hard verification gate.

### 18.2 Auto-generation prompt schema

The reasoning model's drafting step is itself GBNF-constrained — it cannot emit a draft that fails to parse:

```json
{ "type": "object",
  "required": ["name", "description", "input_schema", "output_schema", "rust_code", "tests"],
  "properties": {
    "name": { "type": "string", "pattern": "^[a-z][a-z0-9_]+\\.[a-z][a-z0-9_]+$" },
    "description": { "type": "string", "maxLength": 200 },
    "input_schema": { "type": "object" },
    "output_schema": { "type": "object" },
    "rust_code": { "type": "string", "minLength": 50, "maxLength": 8192 },
    "tests": {
      "type": "array",
      "minItems": 3,
      "items": {
        "type": "object",
        "required": ["name", "input", "expected_output_pattern"],
        "properties": {
          "name": { "type": "string" },
          "input": { "type": "object" },
          "expected_output_pattern": { "type": "object" }
        }
      }
    }
  }
}
```

**Three or more tests is mandatory** at the schema level — the model literally cannot emit a skill draft with fewer than 3 tests. This is a structural defence against under-tested generated code.

### 18.3 Reflection-based schema extraction

After successful compile, schema extraction is fully deterministic via Rust reflection:

```rust
use schemars::schema_for;

pub fn extract_schema<T: schemars::JsonSchema>() -> serde_json::Value {
    serde_json::to_value(schema_for!(T)).expect("schemars output is always valid JSON")
}
```

The mint pipeline runs `schema_for!(SkillInput)` and `schema_for!(SkillOutput)` against the just-compiled types. This guarantees the schemas in the registry are byte-identical to what the Rust code accepts and produces — no drift between docs and behavior is structurally possible.

### 18.4 Dynamic grammar swap on mint

When a skill is minted mid-session:

1. Mint completes successfully (§17.2).
2. The new skill's grammar is compiled and cached.
3. `SamplerDispatch::rebuild` runs, producing a new dispatch grammar that includes the new skill in the `oneOf` of allowed tool calls.
4. `ArcSwap::store` atomically replaces the active grammar.
5. The next inference step (whether the model is currently mid-generation or not — swap is wait-free at slot boundaries) sees the new tool as a valid call target.

The user notices nothing. The agent gains a capability. The action trace records the mint event with the verification record attached.

### 18.5 Tombstoning and revocation

A minted skill that produces a heal-event ≥3 times within 7 days is auto-tombstoned: its grammar is removed from the dispatch grammar at the next rebuild; its registry entry is marked `tombstoned: true`; the user is shown a notification *only if* the skill was promoted to active status. Tombstoned skills can be re-drafted by the reasoning model with the failure trace as input.

This bounds the cost of an over-eager mint pipeline. A skill cannot persistently degrade the system — it gets one chance, three failures, then it's gone.

### 18.6 OpenCode and similar frameworks

OpenCode-class frameworks (CLI agents that drive code-generation loops via subprocess orchestration) provide the *patterns* this plan needs but not the *primitives* — they're optimized for hosted dev workflows, they assume a shell, and they orchestrate via subprocess + TTY.

**Decision: do not adopt OpenCode (or its peers) as a framework dependency.** The user's "no subprocess bloat" mandate is correct here. We borrow:

- **Sandboxed code-execution loop pattern** — implemented natively in Rust via `sandbox_init` + child process with stripped entitlements. No `ttyd`, no PTY emulator, no shell.
- **Test-first skill drafting** — implemented via the GBNF schema in §18.2 that requires `tests[]` of length ≥3.
- **Iterative revision on failure** — implemented in §17.2's revision loop, bounded at 3.

Everything else (TUI rendering, terminal multiplexing, shell-mode, interactive REPL) is excluded. The Rust core stays narrow; the Swift UI stays minimal; the agent loop stays in-process.

---

## 19. Scaling the Tool and Skill Surface

The user's targets — **300+ tools, ~100 skills** — are realistic *only* under the three-tier hierarchy of §18.1. Hand-crafting 300 tools is unattainable for a single developer; auto-generating without verification produces tool-soup that the agent cannot rely on. The Compile-Verify-Mint gate makes auto-generation safe at scale.

### 19.1 Coverage roadmap

| Domain | Tier 1 (hand) | Tier 2 (auto) | Tier 3 (skill) | Total |
|---|---|---|---|---|
| Vault | 8 | 24 | 8 | 40 |
| Knowledge | 6 | 18 | 6 | 30 |
| Memory | 4 | 12 | 4 | 20 |
| Capture | 5 | 10 | 5 | 20 |
| Structure | 5 | 15 | 5 | 25 |
| Code | 6 | 18 | 6 | 30 |
| Reasoning | 6 | 12 | 8 | 26 |
| System | 5 | 10 | 5 | 20 |
| Action (Pro) | 5 | 15 | 10 | 30 |
| Meta | 3 | 9 | 3 | 15 |
| Communication | 4 | 12 | 8 | 24 |
| Time / scheduling | 4 | 10 | 6 | 20 |
| **Subtotal** | **61** | **165** | **74** | **300** |
| Skill compositions (Tier 3 cross-domain) | — | — | **+30** | **+30** |
| **Grand total** | **61 tools** | **165 tools** | **104 skills** | **330 callable units** |

Tier 1 is shipped in Phases 1–9 of §11. Tier 2 starts auto-minting at Phase 7 (NightBrain capacity). Tier 3 starts at Phase 12.5 (skill discovery). All tiers ship gated by the same eval suite plus the per-skill verification record.

### 19.2 Discovery and disclosure

300 tools cannot all live in the LLM's system prompt simultaneously — that's the context-bloat issue §1.1 warned about. Solution: **lazy schema materialization** via `meta.discover`.

```
Step 1: model gets ~100 tokens of tool *names* + 1-line descriptions, organized by category.
Step 2: model emits `meta.discover {"category": "vault", "intent": "search by tag"}`.
Step 3: runner returns the schemas of the 12 vault.search* variants.
Step 4: model picks one, calls it under the now-loaded grammar.
```

Average tokens per call drops from ~3000 (full catalog) to ~600 (names + 1 discover roundtrip). For tool-heavy plans the savings compound.

### 19.3 Quality gate at scale

Every tool — Tier 1, 2, or 3 — passes:

- 3+ unit tests (mandatory by schema in §18.2 for auto-gen; for Tier 1 hand-crafted, enforced by review).
- Property test for input-schema → output-schema invariant.
- Latency budget per its category (§5.4).
- 5-sample shape eval with ≥99% schema compliance on each model in §6.6.

The eval harness (Phase 11) runs *every tool's* 5-sample shape eval on every model swap. A tool that drops below 99% compliance is auto-tombstoned and can be re-minted.

---

## 20. Bespoke Apple Silicon Engineering

The user's R5 framing is exactly right: generic local-LLM stacks (Ollama, llama.cpp packaged binaries, LM Studio) are designed to run on everything from an Intel Mac to an Nvidia H100. They make compromises for portability that we don't have to make.

### 20.1 Zero-copy unified memory

On M-series, system RAM and GPU/Neural-Engine memory are the same physical memory. There is no "VRAM transfer." MLX exploits this; the user's existing project does too. The implication for our architecture:

- **Embedding store, knowledge graph, KV-cache, model weights all share one address space.** The cosine-search index (LanceDB or our custom ANN) holds vectors at the same physical addresses MLX reads as kernel inputs. No serialization.
- **Cross-component slices, not copies.** A `vault.search` result that the agent will reason over is passed as a `&[u8]` slice into the prompt template, and the prompt-template compilation hands MLX a token-buffer pointer that aliases the same data. No marshalling, no cloning, no JSON re-serialize-then-tokenize.
- **Inside Rust, this is `Arc<[u8]>` shared across threads. Across UniFFI to Swift, owned values per Mozilla's contract — but on the Rust side everything is zero-copy.**

The bound: the user-facing `_meta.latency_ms` includes only inference compute time, not data movement. On a 7B 4-bit model at M4 Pro 273 GB/s, that means ~16ms to stream the weights and ~30 tok/s sustained. Latency budgets in §5.4 are derived from this hardware truth.

### 20.2 Hardware-aware quantization

Off-the-shelf 4-bit GGUF quantizations are tuned for portability. We can do better by quantizing locally for M-series specifically:

- **Group size aligned to M-series cache lines** (256-element groups, not 128) — fewer dequant operations, better cache locality.
- **Mixed precision per layer**: attention layers stay 8-bit (sensitive to quantization noise); MLP layers go 4-bit; embedding layers stay 16-bit (small absolute size, big quality impact). MLX-LM already supports this via its `mlx_lm.convert` tool.
- **KV-cache 4-bit** during long-context inference. The savings on an 8k-context KV cache is ~1GB → ~250MB, freeing memory for parallel model loads (e.g., draft + verifier for speculative decoding).
- **Profile against memory bandwidth, not just model size.** A model is "good for M-series" if its dequant + read pattern lands within the bandwidth envelope at the target throughput. The benchmark target is ≥30 tok/s on a 7B 4-bit on M4 Pro; failing that, re-tune.

The Phase 6 verification gate now includes a hardware-aware quantization step: each model in §6.6 is quantized locally with `mlx_lm.convert` using these settings; the output is checksummed and committed alongside the model card.

### 20.3 Sampler overhead is the real bottleneck (not weight size)

On M-series at 4-bit, the system is **compute-bound, not memory-bound**. This inverts the standard local-LLM optimization story. The actual bottlenecks:

1. **Sampler logit-mask compute** (~50μs/token at 128k tokenizer; ~5ms per 100-token call). Mitigated by lexer/parser splitting in llguidance.
2. **KV-cache locality**. Aligned to cache lines per §20.2; this is where most speed wins come from past 4-bit.
3. **Speculative decoding pair overhead**. Worth it for >256 token generations (~1.4× speedup); not worth it for short tool calls.
4. **Tokenizer dispatch**. Hermes XML wrapper tokens (`<tool_call>`) are added single tokens, so the wrapper costs 2 tokens not 8. Use the chat template, not raw concatenation.

The guidance: do **not** spend optimization budget on shrinking weights below 4-bit (3-bit hurts more than it helps on M-series); do spend it on sampler integration, KV layout, and tokenizer choice.

### 20.4 Apple framework integration

Five Apple frameworks are first-class dependencies. None are subprocess; all are linked or NPC-IPC:

| Framework | What it does | Used by |
|---|---|---|
| **MLX-Swift** | Inference engine, unified memory, autograd | Phase 6 |
| **Vision (`VNRecognizeTextRequest`)** | OCR fast/accurate | Phase 5 |
| **Speech (`SpeechAnalyzer`)** | ASR on macOS 26+ | Phase 5 |
| **WhisperKit** | ASR via CoreML on older macOS | Phase 5 fallback |
| **NSMetadataQuery** | Spotlight, sub-50ms file search | Phase 5 |
| **CoreML** | Distilled classifiers (concept extraction draft, intent router) | §5.6 cascade |
| **Network.framework** | Network state for power-aware routing (§6.10) | Phase 6 |
| **IOPMrootDomain** | Battery + thermal state | §6.10 |
| **Sandbox (`sandbox_init`)** | Restricted child process for skill mint | §17.2 |

Every one of these is in-process or first-party IPC. **No subprocesses for inference.** The Hermes Python subprocess (per `CLAUDE.md`) is for orchestration only and is the exception, not the pattern.

### 20.5 The "negative app" mandate

The user's word: keep the app **negative** — minimal in dependencies, surface area, footprint, and ambient resource use. This translates to:

- **One inference engine** (MLX-Swift). No alternative engine on the hot path.
- **One constraint backend at a time** (MLX-Structured primary, others as fallbacks behind feature flags).
- **No language runtimes besides Rust + Swift in the main process.** Python is for the Hermes orchestrator subprocess only.
- **No daemons.** Models lease and unload. NightBrain runs only when idle + on AC.
- **No non-Apple GPU stacks.** Metal only.
- **No web server, no localhost API.** The Rust core exposes UniFFI; that's the only IPC surface from Swift.
- **Plugin loading is dyn-link, not subprocess.** Skills are sandboxed dylibs minted inside the same process model.

Every dependency that survives this filter justifies its place by being load-bearing in the breakthrough (§17) or the user-facing surface (§9).

---

## 21. Cloud-as-Generator Mode + Skill Templater

This section adds the **moat-defining capability**: a toggle that lets cloud models invent new schemas, skills, and tools on the fly that are **compiled, verified, and minted locally** — never executed by the cloud, never persisted off-device, never depended on at runtime. The cloud is a *draft engine*, not a runtime dependency. The user always owns the artifact.

This pairs with a **Templater** library — pre-vetted Rust/Swift skeletons with slot-fill specifications that both local and cloud generators reference when drafting. The templater is the IP that makes first-pass drafts pass the §17 mint gate at high rates, regardless of which model wrote them.

The pattern's prior art is Voyager (cloud GPT-4 drafts code; local Minecraft executes; skills are JavaScript functions indexed by description embedding). We extend it with pre-vetted skeletons (so the model doesn't draft from scratch), the four-gate Compile-Verify-Mint pipeline (so generated code is provably safe before it ships), and the local-first execution mandate (the cloud never sees a runtime hot path).

### 21.1 The tri-state Cloud setting

The existing seven-row Settings contains "Cloud allowed". That row's value becomes **tri-state** instead of a binary:

| State | Meaning |
|---|---|
| **Off** | No cloud calls of any kind. The system is fully air-gapped. Local-only generation; local-only inference. |
| **Generator only** | Cloud may be invoked **only** for `meta.draft_skill`, `meta.draft_tool`, `meta.draft_schema` operations. Cloud may not be invoked for routine inference (routing, summarization, QA). The user pays cloud tokens only when the system mints a new capability — bounded by the mint pipeline, not by user query volume. |
| **Inference + Generator** | Cloud may be invoked for both generation AND the rare inference cases per §1.3 / §6.7. This is the most permissive state; opt-in. |

**Default is `Generator only`** when API keys are configured. Users get the moat (cloud-drafted skills compiled locally) without paying cloud tokens on every chat. Seven rows preserved.

The state is enforced at the model_select layer (§6.7); any cloud invocation outside the allowed envelope returns `error: cloud_disabled` and falls through to the next variant.

### 21.2 Templater library

Templates live at `agent_core/templates/<category>/<purpose>.template.{rs,toml,gbnf,test}`. Each template has four pieces:

```
agent_core/templates/vault/search_specialized.template.rs       <- skeleton (hand-vetted)
agent_core/templates/vault/search_specialized.template.toml     <- slot specification
agent_core/templates/vault/search_specialized.template.gbnf     <- pre-compiled grammar shape
agent_core/templates/vault/search_specialized.template.tests.rs <- reference test fixture
```

The **skeleton** is hand-authored Rust. It has placeholder slots delimited by `{{SLOT_NAME}}` that the generator fills:

```rust
// agent_core/templates/vault/search_specialized.template.rs
use crate::tools::*;
use schemars::JsonSchema;
use serde::{Serialize, Deserialize};

#[derive(Deserialize, JsonSchema)]
pub struct {{TOOL_TYPE}}Input {
    {{INPUT_FIELDS}}
}

#[derive(Serialize, JsonSchema)]
pub struct {{TOOL_TYPE}}Output {
    pub hits: Vec<SearchHit>,
    pub _meta: ToolMeta,
}

pub struct {{TOOL_TYPE}}Tool;

#[async_trait]
impl Tool for {{TOOL_TYPE}}Tool {
    const NAME: &'static str = "vault.{{TOOL_NAME}}";
    type Input = {{TOOL_TYPE}}Input;
    type Output = {{TOOL_TYPE}}Output;

    async fn invoke(&self, input: Self::Input, ctx: &ToolCtx) -> Result<Self::Output, ToolError> {
        // PRE: deterministic filter (the no-LLM-first variant)
        let candidates = ctx.vault.search_lexical(&input.{{PRIMARY_FIELD}}, ctx.k()).await?;

        // SLOT: filtering logic specific to this specialization
        {{FILTER_BODY}}

        Ok({{TOOL_TYPE}}Output {
            hits: filtered,
            _meta: ToolMeta::ok_now("variant_a", started.elapsed_ms(), Some(0.95)),
        })
    }
}
```

The **slot specification** (TOML) declares each slot's type, allowed values, examples, and constraints:

```toml
# agent_core/templates/vault/search_specialized.template.toml
[meta]
template_id = "vault.search_specialized.v1"
parent_tool = "vault.search"
description_pattern = "Search the vault, filtered by ..."

[[slots]]
name = "TOOL_NAME"
kind = "ident"
pattern = "^search_[a-z_]+$"
example = "search_by_tag"

[[slots]]
name = "TOOL_TYPE"
kind = "type_name"
pattern = "^[A-Z][A-Za-z]+$"
example = "SearchByTag"

[[slots]]
name = "INPUT_FIELDS"
kind = "rust_struct_fields"
must_include = ["query: String"]
allowed_extra = ["tag: String", "folder: String", "since: i64", "limit: u32"]

[[slots]]
name = "PRIMARY_FIELD"
kind = "ident"
must_match_input_field = true

[[slots]]
name = "FILTER_BODY"
kind = "rust_block"
must_assign = "filtered"
must_use_slice = "candidates"
must_not_call = ["std::process::Command", "std::net::*", "std::fs::*"]
max_lines = 40
```

The **grammar shape** is the JSON schema fragment the input type must conform to once derived; pre-compiled so the mint pipeline doesn't re-derive on every call. The **reference test fixture** is a parameterized test the slot-filled code must extend to ≥3 cases.

Generators (local or cloud) receive: skeleton + slot spec + 3 reference exemplars from already-minted variants of the same template. The model fills slots only — never the surrounding code. Compile-by-construction is preserved because the skeleton is hand-vetted; failure modes shrink to slot-fill semantic errors.

### 21.3 Generation flow

```
[user need detected]                       [/skill draft <description>]
    │                                            │
    ▼                                            ▼
[meta.discover finds no matching tool]    [meta.draft_skill explicit invocation]
    │                                            │
    └────────────┬───────────────────────────────┘
                 ▼
         [select template by category + intent]
                 │
                 ▼
         [build slot-fill prompt: skeleton + spec + 3 exemplars]
                 │
                 ▼
         ┌───────┴──────────┐
         │                  │
   Cloud=Generator     Cloud=Off
   ─ cloud drafts      ─ local drafts (Hermes-3-8B preferred for code synth)
         │                  │
         └─────────┬────────┘
                   ▼
         [apply slot-fills to skeleton]
                   ▼
         [Compile-Verify-Mint pipeline (§17.2)]
                   ▼
         ┌─────────┴─────────────────────┐
         │                               │
       Pass                            Fail (≤3 revisions)
         ▼                               ▼
       [register in tool registry]   [revise slot-fills with error trace]
       [grammar swap (§17.3)]            │
       [available on next inference]     └─► loop or tombstone
```

**Cloud's advantage is in the draft.** Frontier models compose better Rust at first pass; that's measurable and worth using. The advantage stops at the draft. After slot-fill, **everything else is local**: compile, test, miri, sandbox-load, schema-extract, grammar-compile, register. The cloud never executes the skill; the cloud never sees the test results; the cloud never knows whether the mint succeeded.

Per the G1–G4 framework (arxiv:2602.12430): G1 = our `cargo check` + `cargo clippy` + the slot-spec's `must_not_call` static checks. G2 = LLM semantic intent check (the cloud-generated `description_pattern` is compared to the slot-fill's actual implementation; mismatches fail). G3 = our sandbox dyn-link execution against the test fixture. G4 = the slot-spec's `must_not_call` permission manifest, with `seccomp`-equivalent enforcement at runtime.

### 21.4 The moat thesis

Most local PKM apps face a Hobson's choice:

- **Pre-built tool catalog** (Obsidian, Logseq, Roam): limited growth, every new capability is a plugin the user has to find/install/trust.
- **External MCP servers** (Cursor-class, MCP-bridge ecosystems): unlimited growth, but every tool runs in someone else's process, sees user data, can be deprecated, and is a privacy/reliability liability.

Epistemos's third path: **cloud-drafted, locally-minted, locally-executed.** The cloud is a code-generation oracle for a few seconds during mint; the rest of the lifecycle is on-device. There is no MCP server to keep alive. There is no third-party endpoint to trust. The user can mint a skill on a flight (`Cloud Off`, local draft), refine it on Wi-Fi (`Generator only`, cloud draft), or live in either world indefinitely.

The templater is what makes this moat sustainable. Without templates, generators draft from scratch and the mint failure rate would be unworkable. With templates, generators fill slots into pre-verified skeletons, mint success rates rise above 95% on first pass, and the catalog grows at a rate the user can actually consume.

This is the formal answer to the user's "stop relying on external MCPs" goal: replace external MCP discovery with **internal generative discovery**, gated by Compile-Verify-Mint. The cloud still helps; the user still owns the runtime; the privacy boundary holds.

### 21.5 Template file format

Templates are themselves hybrid MD+JSON (mirroring the .skill format from §2.4) so they're inspectable, editable, and version-controlled:

```markdown
---{"$schema":"epistemos://schemas/template.v1.json","id":"tmpl.vault.search_specialized.v1","category":"vault","parent_tool":"vault.search","slot_count":5,"reference_exemplars":["vault.search_by_tag","vault.search_recent","vault.search_in_folder"],"grammar_shape_path":"./search_specialized.template.gbnf","skeleton_path":"./search_specialized.template.rs","tests_path":"./search_specialized.template.tests.rs","verified_against_models":["qwen2.5-7b","hermes-3-8b","claude-haiku-4-5","claude-opus-4-7"]}---

# Vault Search Specialized — Template

This template produces a specialized variant of `vault.search` filtered by some
additional dimension (tag, folder, recency, etc.). The variant runs the
deterministic lexical search first (no LLM), then applies the filter.

## When to use this template

Use this template when the agent (or user) needs a search that is too specific
for the generic `vault.search` tool but follows the same shape. Concretely:
the result set must be a `Vec<SearchHit>`, the filter is a deterministic
boolean over hit metadata, and no LLM call is needed inside the tool body.

## Slot guidance

- `TOOL_NAME` should be a snake_case verb phrase ending in the filter dimension.
- `FILTER_BODY` must be pure (no I/O outside `ctx.vault`).
- ≥3 unit tests are mandatory (enforced by the mint pipeline).

## Negative examples (what NOT to do)

- Do not call into LLM-bearing tools from `FILTER_BODY`. This template is for
  *deterministic* specializations.
- Do not introduce new fields to `Output` beyond what the parent contract allows.
```

The JSON header is what the mint pipeline consumes; the markdown body is what generators read as guidance. Identical to the `.soul.md` / `.skill.md` patterns elsewhere in this plan.

The template registry is loaded once at app startup; templates are added/edited via PR review (Tier 1 hand process), never auto-generated. The auto-generation surface is the *slot-fills*, not the templates themselves.

### 21.6 Local-only generation (no cloud at all)

When the toggle is `Off`, the same flow runs with the local 7B/8B function-caller as the generator:

- **Hermes-3-Llama-3.1-8B** is preferred for code synthesis (strong steerability + permissive license).
- **Qwen2.5-Coder-7B-Instruct** is the fallback when Hermes is unavailable.
- Few-shot count climbs from 3 (cloud) to 5 (local) — the local model needs more reference exemplars to match cloud quality on first pass.
- Revision count budget rises from 1 (cloud average) to 2–3 (local average).
- Total mint latency rises from ~6s (cloud) to ~25s (local) per skill.

The system is fully usable in `Cloud Off` mode. The catalog grows more slowly. That is the only difference. Privacy is absolute; offline is real.

### 21.7 Updates to other sections

- **§10 Settings**: the "Cloud allowed" row becomes tri-state (Off / Generator only / Inference + Generator). Total rows still 7. Tri-state UI is a small dropdown, not three separate rows.
- **§16 Definition of Done** (criterion 20): system passes the 200-case eval in `Cloud Off` mode at ≥80% top-1 placement (5 points lower than the cloud-allowed bar; this gap defines the cloud's incremental value and bounds it).
- **§11 Phase 6.5** per-model bench: each generator-capable model (Hermes-3-8B local, Qwen-Coder-7B local, Claude Sonnet/Opus cloud) is benchmarked on draft-quality (mint-pass-rate on first pass) against the templater fixture set.
- **§17.2 Compile-Verify-Mint**: the gate now includes the G2 semantic intent check (LLM compares declared description vs implementation behavior) before sandbox execution. This catches the "skill does what it claims" class of bugs early.
- **§18.2 Auto-generation prompt schema**: when a template applies, the prompt schema is replaced by the template's slot-fill schema (per §21.2). The model sees a much smaller decision surface; first-pass quality rises proportionally.

### 21.8 Worked example

User types in the AI input bar: *"/skill weekly-research-digest — pull last 7 days of research-folder notes, summarize each with citations, output to a daily review note"*.

1. Intent parser (local 1.5B) extracts: action=`draft_skill`, name=`weekly-research-digest`, description, requires_tools=[`memory.recall_episodic`, `vault.search`, `knowledge.summarize`, `vault.write`].
2. Template selector matches against the procedural-memory skill template at `agent_core/templates/skill/multi_step_review.template.toml`. The template is for skills that aggregate notes from a window, summarize, and write to a daily note.
3. Slot-fill prompt is assembled: skeleton + spec + 3 reference exemplars (`weekly-review`, `monthly-research-digest`, `meeting-followups`).
4. With `Cloud=Generator only`: prompt sent to Claude Haiku 4.5. Returns slot-fills in ~2.4s.
5. Slot-fills applied to skeleton. `cargo check` passes. `cargo clippy` passes. `proptest` extended from the reference test fixture passes 100/100. `cargo miri` skipped (no `unsafe`). Sandbox dyn-link load + execute against test fixture passes. Schema extracted. Grammar compiled. Skill registered. Total mint time: ~7s.
6. `meta.discover` instantly sees the new skill. The agent can call it on the next turn.
7. User runs the skill. It executes locally (Tier 1 tools chained per the slot-filled DAG). User sees the result; the cloud was never invoked at runtime.

Action trace for the mint shows: who drafted (Claude Haiku 4.5), what template (skill.multi_step_review.v1), what gates passed (G1/G2/G3/G4), what tests covered the slot, and a content-addressed sha for the minted skill.

### 21.9 What this is not

- **Not** a cloud runtime. The cloud doesn't execute the skill, ever. It only drafts.
- **Not** an MCP server bridge. Minted skills are local Rust dylibs; they don't live in someone else's process.
- **Not** a free pass to generate anything. The mint gate (Compile-Verify-Mint) blocks all four classes of failure: syntactic, semantic, runtime, and intent.
- **Not** a code-execution playground. There is no REPL surface, no "run arbitrary code" tool. Skills are pre-compiled and registered before they're callable.
- **Not** dependent on cloud at all when toggle is `Off`. Local generation produces the same final artifacts, just slower per skill.

### 21.10 Risks and bounds

1. **Templater coverage**: not every conceivable skill maps to an existing template. New templates are hand-authored; the templater library grows at human pace. **Bound**: Phase 12.5 ships with ~15 templates covering vault/knowledge/memory/capture/structure/code/reasoning/system; user-requested skills outside template coverage fall through to free-form generation (more revisions, lower mint pass-rate, higher cost — but still possible).
2. **Cloud draft cost**: a heavy mint week could rack up cloud tokens. **Bound**: per-day cloud generation token budget cap (Settings, advanced pane); when exceeded, generation falls through to local for the rest of the day.
3. **Semantic intent drift** (G2 false negative): a skill that claims to "summarize emails" but actually exfiltrates tokens passes G1+G3+G4 but should fail G2. **Bound**: G2 uses the same Hermes-3-8B locally for intent classification — a sloppy local check misses subtle drift. Mitigation: the slot spec's `must_not_call` list includes all I/O surfaces, so G1 catches most exfiltration patterns mechanically before G2 even runs.
4. **Template-vs-generation mismatch**: cloud-drafted slot-fill assumes Rust idioms the local skeleton doesn't support. **Bound**: the slot spec's grammar (§21.2) is explicit; any divergence fails compilation at G1. Cloud cannot write through the constraint.
5. **Skill explosion**: the templater can mint 50 specialized search variants when 5 would do. **Bound**: §19's tier-2 cap (~165 auto-generated tools); when exceeded, NightBrain proposes deduplication via embedding similarity over descriptions. Skills with cosine ≥ 0.97 to an existing skill are not minted.

This is the moat. It defends the local-first thesis without sacrificing the auto-extension story. Cloud helps when it can; locally everything is owned, audited, and controllable.

---

## 22. Structural Enforcement Beyond Tool Calls — Extending the Moat

The philosophy in §17 (sampler-bound dispatch) is a special case of a larger principle: **anywhere a model produces output, structural enforcement at decode time makes a small model behave like a frontier model on shape correctness**, and frees the prompt budget to focus on semantic correctness. This section enumerates every place in Epistemos where the same enforcement applies, and how each one becomes structurally impossible-to-fail.

The unifying insight: **the model's job is to choose among valid options, never to generate them from a vacuum.** Whatever the artifact (a tool call, a date, a citation, a paragraph rewrite, a query, a rename), the grammar encodes "what is valid" and the sampler enforces it.

### 22.1 Three load-bearing decode-time mechanisms

Three mechanisms together turn the local model into a structurally-bound, reasoning-quality-preserving, edit-rather-than-regenerate generator. **All three ship in Phase 6** (see §11). They are not "future work"; they are part of the core inference path and the heal loop.

#### 22.1.1 Grammar-Aligned Decoding (NeurIPS 2024)

Naive grammar-constrained decoding zeros out the logits of invalid tokens. This is *correct* but *quality-shifting*: the probability mass of invalid tokens is renormalized across valid tokens uniformly, even when some valid tokens were originally far less likely than others. Output quality degrades subtly because the model's calibration is broken.

Grammar-Aligned Decoding (Park et al., NeurIPS 2024) solves this by **preserving the relative probability distribution shape over the valid subset** rather than uniformly renormalizing. The mask-and-rescore step uses a temperature-aware projection that keeps the top-1 / top-k orderings intact among the valid options.

```rust
// agent_core/src/grammar/aligned.rs
pub fn aligned_mask_and_rescore(logits: &mut [f32], valid_mask: &[bool], temperature: f32) {
    // 1. Apply mask: invalid tokens get -infinity (effectively zero probability).
    for (l, ok) in logits.iter_mut().zip(valid_mask) {
        if !ok { *l = f32::NEG_INFINITY; }
    }
    // 2. Renormalize ONLY among the valid set, preserving the temperature-scaled
    //    relative ordering. This is the Grammar-Aligned step.
    let max = logits.iter().filter(|l| l.is_finite()).cloned().fold(f32::NEG_INFINITY, f32::max);
    let mut sum = 0.0;
    for l in logits.iter_mut() {
        if l.is_finite() {
            *l = ((*l - max) / temperature).exp();
            sum += *l;
        }
    }
    for l in logits.iter_mut() {
        if l.is_finite() { *l /= sum; }
    }
    // The valid subset now sums to 1.0 and the relative ordering of the
    // valid tokens matches what the unconstrained model would have produced
    // among that same subset.
}
```

Effect: the model's *quality* under constraint is indistinguishable from its quality without constraint, on the subset of outputs that were valid in the first place. We get structural enforcement for free.

This wraps the MLX-Structured `GrammarMaskedLogitProcessor`. Implementation: a thin Swift adapter `Epistemos/Inference/AlignedLogitProcessor.swift` overrides the default mask-and-rescore step. Phase 6 verification gate: a 50-sample paired comparison shows aligned vs zero-out decoding produces ≥98% identical top-1 picks on a control set; aligned decoding produces measurably higher BERTScore on the structured-output benchmark.

#### 22.1.2 CRANE — open thinking, closed commit (arxiv:2502.09061)

Grammar enforcement applied to the *entire* output hurts reasoning quality on hard tasks. CRANE's fix: alternate **unconstrained reasoning** with **constrained committal**.

Every reasoning-bearing tool's output schema becomes:

```
output := SENTINEL_THINK reasoning_freeform(≤256 tok) SENTINEL_END_THINK
        + constrained_answer(grammar)
```

Inside the `reasoning_freeform` region the grammar is the trivial accept-everything grammar. The MLX-Structured processor switches to identity-mask. The model chains thoughts, hypothesizes, self-critiques. When the closing sentinel `SENTINEL_END_THINK` is emitted, the processor switches to the strict answer grammar; the model commits structurally.

```rust
// agent_core/src/grammar/crane.rs
pub fn crane_grammar(answer_grammar: &llg::Grammar, reasoning_max_tokens: u32) -> llg::Grammar {
    // Pseudo-grammar:
    //   root := <think>{free_text limit reasoning_max_tokens}</think>{answer}
    //   answer := <answer_grammar>
    let template = format!(r#"
        root: "<think>" think_body "</think>" answer
        think_body: any_token{{0,{}}}
        any_token: <unconstrained, any vocabulary token except </think>>
        answer: <embed_answer_grammar>
    "#, reasoning_max_tokens);
    llg::Grammar::compile_with_embed(&template, answer_grammar)
}
```

Sentinel tokens `<think>` and `</think>` are added to the model's tokenizer at training time for Hermes-3 (single-token wrappers, cost-free). For Qwen the wrappers are 2-3 tokens each — still negligible.

Default in §4.2 already reserved a `reasoning_trace` field, but that field was inside the constrained answer grammar. CRANE moves it *outside* — open during the think block, closed during the answer. This is a strict upgrade: same observability (the reasoning trace is captured in the action trace), better thinking quality.

**Applied to**: every reasoning-bearing tool — `reason.plan`, `reason.critique`, `reason.verify`, `knowledge.qa_over_vault`, `structure.route_capture` Variant B, `meta.draft_skill` slot-fill drafting (§21), and the heal-loop diagnostic prompt (§5.2). Phase 6 verification gate: paired eval comparing constrained-only vs CRANE on 50 hard reasoning cases shows CRANE wins on accuracy by ≥7% with no regression on structural compliance.

#### 22.1.3 IterGen — backtrack-and-edit, not regenerate (ICLR 2025)

This is the mechanism the user asked about: **the model edits part of its prior output without re-generating the whole thing or re-reading the prompt.** Here's exactly how it works.

**Step-by-step:**

1. **During generation**, the runtime stores two things at every grammar-symbol boundary (e.g., the start of each JSON field):
   - **The KV-cache snapshot**: the model's internal attention state at that point. Lightweight on M-series unified memory because it's just a pointer to MLX-managed buffers.
   - **The grammar parser state**: which production we're inside, what comes next.

2. **Output stream so far** (e.g., a 1200-token tool call) is also retained. So we have a triple `(tokens_emitted_so_far, kv_state_at_each_boundary, parser_state_at_each_boundary)`.

3. **Validation fires** on the completed (or partial) output. Suppose field `confidence` at token index 1100 is `0.95` but the schema requires `0.0–1.0` and somehow a malformed numeric was emitted. (In practice, grammar-aligned decoding makes this nearly impossible — but post-generation checks like custom validators or external invariants can still fail.)

4. **Heal loop selects the backtrack point.** It looks up the most recent grammar boundary *before* the failing field — say token index 1080, which was the start of the `confidence` field's value.

5. **State restoration is constant-time:**
   - Truncate `tokens_emitted` from 1200 back to 1080. (No re-tokenization. No re-running the prompt through the model.)
   - Restore the KV-cache to its snapshot at index 1080. **The model's "memory" of everything that came before is now exactly what it was when it was about to generate token 1080.**
   - Restore the parser state.

6. **Inject a repair hint into the prompt context.** The runtime adds (in the model's view, prepended to the next token to be generated) a small directive: `"the previous attempt emitted an invalid 'confidence' value. confidence must be a number in [0.0, 1.0]."` This becomes a few tokens of context the model attends to.

7. **Resume generation from index 1080.** Crucially, the model does **not re-read the prompt or the 1080 tokens that came before** — that work is captured in the KV-cache. It just produces tokens 1080, 1081, 1082, … forward, with the grammar enforcing valid syntax and the repair hint nudging semantic choice.

8. **Continue until completion or another failure.** If another failure, backtrack again (bounded at 3 backtracks per call). If success, commit.

**Cost analysis on M-series:**

- Full regenerate: re-process the entire prompt + 1200 tokens through the model. At 30 tok/s on Qwen 7B, that's ~50s for 1500 tokens of context.
- IterGen backtrack: restore cached state at boundary, generate only from boundary forward. For ~120 tokens (1200 → 1080 + completion), that's ~4s.
- ~12× speedup on the typical heal case. The user perceives a tight retry, not a regeneration cliff.

**Implementation:**

```rust
// agent_core/src/heal/itergen.rs
pub struct GenerationState {
    pub tokens: Vec<TokenId>,
    pub kv_snapshots: BTreeMap<TokenIdx, KvSnapshotHandle>,
    pub grammar_boundaries: BTreeMap<TokenIdx, GrammarSymbolId>,
    pub field_index: HashMap<FieldPath, TokenIdx>,
}

pub struct KvSnapshotHandle {
    // MLX manages the underlying buffer; this is a cheap reference + commit-id.
    pub mlx_handle: MlxKvHandle,
    pub committed_at: TokenIdx,
}

impl HealLoop {
    pub async fn backtrack_and_retry(
        &self, state: &mut GenerationState, error: ValidationError,
    ) -> Result<GenerationState> {
        // 1. Find boundary before the failing field
        let failing_idx = state.field_index.get(&error.field_path)
            .ok_or(BacktrackError::FieldNotFound)?;
        let (&boundary_idx, _) = state.grammar_boundaries.range(..*failing_idx)
            .next_back().ok_or(BacktrackError::NoBoundary)?;

        // 2. Truncate tokens
        state.tokens.truncate(boundary_idx);

        // 3. Restore KV-cache (constant-time on MLX — pointer swap)
        let kv_handle = state.kv_snapshots.get(&boundary_idx)
            .ok_or(BacktrackError::NoSnapshot)?;
        self.engine.restore_kv(kv_handle).await?;

        // 4. Restore grammar parser to its state at the boundary
        self.grammar.restore_parser_state(boundary_idx)?;

        // 5. Inject repair hint as a few extra context tokens
        let hint = self.compose_repair_hint(&error);
        self.engine.inject_context_tokens(&hint).await?;

        // 6. Resume generation
        let new_tokens = self.engine.continue_generation(state.tokens.len()).await?;
        state.tokens.extend(new_tokens);
        Ok(state.clone())
    }

    fn compose_repair_hint(&self, error: &ValidationError) -> String {
        match error {
            ValidationError::Range { field, expected, got } =>
                format!("// {field} must be {expected}; got {got}\n"),
            ValidationError::Enum { field, allowed } =>
                format!("// {field} must be one of: {}\n", allowed.join(", ")),
            ValidationError::Required { field } =>
                format!("// {field} is required and was missing\n"),
            ValidationError::Pattern { field, regex } =>
                format!("// {field} must match pattern: {regex}\n"),
        }
    }
}
```

**Critical invariants:**

- **Snapshots are committed at grammar-symbol boundaries only**, not every token. This bounds memory; for a 1200-token output with ~50 boundaries, snapshots cost ~50 small KV deltas.
- **Snapshots are dropped after the call returns**. No persistence; no leak.
- **Backtracks are bounded at 3 per call.** After 3, fall through to the next variant in the ladder (§5.4).
- **The repair hint is itself constrained**: the runtime never injects model-generated text into the hint, only structured error info from the validator. No prompt-injection attack surface.

**The "rereads it" question.** No — the model does not re-read its prior output. The KV-cache *is* the model's memory of the prior context; restoring the KV-cache restores that memory. The model picks up at token N+1 with full awareness of tokens 0..N because the attention layers' working memory at that point in the sequence is exactly preserved. The repair hint is a small new prefix that nudges the next token's distribution; the model attends to it the same way it attends to any context.

Phase 6 verification gate: synthetic 100-case fault-injection test where validation fails at known field positions; assert backtrack succeeds in <500ms median, ≥85% of cases recover within 1 backtrack, ≥97% within 3.

#### 22.1.4 Deterministic generation + targeted self-healing — the hybrid moat

To answer the question directly: yes, exactly. **Instead of re-thinking or rebuilding, the model edits a small region of its prior output to fix the failing part.** The unchanged part is *not regenerated, not re-read, not re-tokenized*. Only the bad span is replaced, in-context, with the model's KV-cache restored to the moment just before the bad span started.

This is the **hybrid the user named**: *deterministic and also self-healing*. It pairs two properties that usually trade off:

- **Deterministic** (Grammar-Aligned + CRANE): the model's output is structurally bound; it cannot emit malformed JSON, cannot omit required fields, cannot drift outside the schema. The shape is guaranteed.
- **Self-healing** (IterGen): when something *does* go wrong — a semantic check fails, a value is out of range, an external invariant is violated — the system fixes the *exact failing span* in place rather than throwing the work away.

These three mechanisms (Grammar-Aligned + CRANE + IterGen) are the load-bearing trio. Wherever one of them lands, the others are also present. The combination is what produces the reliability the user wants from a 7B local model.

**Where the deterministic + self-healing hybrid applies in Epistemos** (every place where the model produces structured output):

| Surface | Deterministic side | Self-healing side |
|---|---|---|
| **Tool calls** (any tool in §3 catalog) | grammar-bound dispatch (§17) | IterGen on schema violation |
| **Quick-capture routing** (§4) | closed-vocab folder enum + 4-action enum | IterGen on confidence-out-of-range |
| **Concept extraction** (§3.7) | closed `kind` enum, canonical-name pattern | IterGen on alias collision |
| **QA with citations** (§22.6) | citation note IDs as closed enum | IterGen on bad note ID — replaces just the bad citation |
| **Inline editing** (§22.3) | length bounds + entity preservation in grammar | IterGen on entailment-check failure — replaces just the offending sentence |
| **Search query AST** (§22.4) | typed query primitives only | IterGen on filter-value not in vault — replaces the bad filter |
| **Date / time parsing** (§22.7) | closed grammar over date expressions | IterGen on temporal contradiction |
| **PII redaction** (§22.8) | closed `pii_kind` enum | IterGen on missing required redaction |
| **Bibliography** (§22.9) | BibTeX/CSL grammar | IterGen on malformed entry |
| **Diff explanation** (§22.10) | closed `diff_kind` enum | IterGen on missing rationale |
| **Voice command parsing** (§22.11) | typed intent grammar | IterGen on ambiguous intent |
| **Schema migration** (§22.12) | typed AST of field ops | IterGen on inverse-not-derivable |
| **Skill drafting** (§17, §21) | template-bound slot-fill | IterGen on slot-spec violation — replaces only the bad slot |
| **Reasoning traces** (every reasoning-bearing tool) | CRANE-bounded answer block | IterGen on answer-block violation, reasoning untouched |

This is essentially **everywhere the model produces output that another part of the system has to consume**. Free-form prose to the user (e.g., a chat response to a question that's outside the catalog) is one of the few surfaces where the hybrid does *not* apply — there, the user is the consumer and human judgment is the validator. Everywhere else, the trio is on by default.

The mental model the user can carry: **"the model writes in pencil, the system erases and corrects only the wrong word, and what's left is trusted."** That's the moat in one image.

### 22.3 Inline editing under invariants

When the user invokes "rewrite this paragraph" or "shorten this sentence", the LLM is gated by an editing grammar:

- **Length range**: output token count must be within `±20%` of input.
- **Named-entity preservation**: every named entity in the input must appear in the output (extracted by deterministic NER first; the entity list becomes a closed-vocab requirement in the grammar).
- **No new claims**: a claim-extractor runs on input; the grammar requires output claims to be a subset of input claims (semantically — measured by entailment classifier, deberta-v3-mnli).
- **Style preservation**: writer voice fingerprint (sentence length variance, lexical density) bounded within ±10% of input.

```rust
// agent_core/src/tools/note/edit.rs
pub struct EditConstraints {
    pub min_tokens: u32,
    pub max_tokens: u32,
    pub required_entities: Vec<String>,    // closed vocab in grammar
    pub permitted_claim_set: ClaimSetHash,  // entailment-checked post-hoc
    pub style_bounds: StyleFingerprint,
}

pub fn edit_grammar(orig: &str, c: &EditConstraints) -> llg::Grammar {
    // The grammar is a free-text generator with: length bounds enforced via
    // explicit token-count countdown; required-entity inserted as mandatory
    // sub-strings; closing once length budget is met.
    // ...
}
```

The user gets an edit that is *structurally an edit*, not a rewrite-disguised-as-an-edit. The model cannot drift into invention.

### 22.4 Search query AST

Natural-language queries to the search bar parse through a closed grammar of valid query primitives before any retrieval runs:

```
query := primitive (BOOL primitive)*
primitive := lexical_term | semantic_phrase | filter
filter := "tag:" tag_name | "folder:" folder_path | "since:" date | "before:" date | "linked_to:" note_id
BOOL := "AND" | "OR" | "NOT"
```

The intent classifier converts natural language to this AST (or returns "free-form, route to QA"). Every search becomes a typed query; the model cannot inject filter values that don't exist in the vault (folder names, tags, note IDs are closed enums injected at grammar-build time).

Result: search is **provably scoped**. The user typing "show me my AI notes from last month" lands as `tag:ai AND since:2026-03-28` deterministically; no fabricated filters, no missed narrowing.

### 22.5 Action grammars for rename / move / merge

Destructive operations are gated by typed action AST:

```
action := move(source_predicate, target_path) | rename(old, new) | merge(sources, target)
source_predicate := tag_query | folder_query | embedding_cluster | explicit_list
target_path := existing_folder | new_folder
```

The model emits the AST under grammar; the runtime previews effects (count of files affected, sample file paths) before executing. The model **cannot emit a destructive op that doesn't have a preview path**. Combined with universal undo (§8.5), no action is irreversible from the user's perspective.

### 22.6 Citation grammar — no fabricated sources

Whenever the LLM emits a citation, the grammar requires it to reference an existing note id from the vault. Note IDs are 12-char ULIDs; they're injected into the grammar as a closed enum at every QA call:

```
citation := "{" "\"note_id\":" "\"" note_id "\"" "," "\"span\":" range "}"
note_id := "01HX42KQM3R7" | "01HX5N9P2T8K" | ...       ; injected at runtime
range := "{" "\"start\":" int "," "\"end\":" int "}"
```

Effect: there is no possible token sequence that cites a note the vault doesn't contain. Hallucinated citations are structurally impossible.

### 22.7 Date and time expressions

"Remind me in 3 days" / "next Tuesday at 4pm" / "the day after Mom's birthday" all parse through a closed grammar over date expressions, with the parser consuming the model's output and producing a canonical `DateTime<Utc>`. No ambiguous dates reach the runtime.

```
date_expr := absolute | relative | reference
absolute := iso8601 | calendar_date_hm
relative := "in" int unit | unit "from" reference
unit := "day" | "week" | "month" | "year" | "hour" | "minute"
reference := "today" | "tomorrow" | "yesterday" | "next" weekday | "last" weekday | named_event
named_event := <closed enum of vault-known events>
```

Vault-known events come from notes tagged `event:`. The model can reference Mom's birthday only if there's a note for it; otherwise `named_event` matches none and the grammar fails the path.

### 22.8 PII redaction with closed entity types

The redaction tool's output is structurally a list of typed redactions:

```
redaction := { "kind": pii_kind, "span": range, "replacement": placeholder }
pii_kind := "email" | "phone" | "ssn" | "card" | "address" | "name" | "dob"
```

The model cannot invent a new PII kind or skip the kind field. Closed vocabulary makes downstream rendering deterministic.

### 22.9 Bibliography and citation styles

Reference entries must conform to BibTeX or CSL grammar — both have well-defined formal grammars. The model produces references under these grammars; the parser fails closed. No malformed `@article{...}` ever lands in a vault note.

### 22.10 Diff explanation

When the agent describes what changed between two notes, the output is a typed diff list:

```
diff_entry := { "kind": diff_kind, "before": string, "after": string, "rationale": short_string }
diff_kind := "added_claim" | "removed_claim" | "rephrased" | "added_link" | "removed_link" | "moved_block"
```

Closed vocabulary on `diff_kind` means downstream rendering, search-by-diff-kind, and analytics ("you've added the most claims to your ML notes this month") all work without prose parsing.

### 22.11 Voice command parsing

Voice transcripts pass through `intent.parse_voice` before any side-effect. The intent grammar covers capture (default), search, action (with confirmation), question, command. No voice transcript reaches a destructive path without the user's final tap-to-confirm, which the grammar requires as a separate token.

### 22.12 Schema migration as constrained AST

When a schema version bumps (e.g., `mem.v1.json` → `v2`), the migration is expressed as a typed AST of field operations:

```
migration := op*
op := add_field | remove_field | rename_field | transform_field | split_field | merge_fields
```

Migrations are deterministically reversible (every op has a known inverse) and verifiable (apply to test fixtures, compare). The mint pipeline (§17.2) gates migrations the same way it gates skills.

### 22.13 The pattern, generalized

For every output the model produces, ask three questions:

1. **What is the closed set of valid options?** Encode it as enum or closed-vocab in the grammar.
2. **What invariants must the output preserve?** Encode them as grammar productions (length bounds, required substrings, structural shape).
3. **What is the mechanical post-condition?** Encode it as an output-schema validator that the runner enforces (the `meta.validate_result` step in §2.10's prior research).

If you can't answer any of the three, the surface is not yet ready for structural enforcement; do the work to define them. Don't ship prompt-and-pray on a path the user will trust.

---

## 23. The Fortress — Catalog of Novel Built-in Skills

The user's framing — *"a fortress of truly useful skills and tools"* — translates to a catalog of pre-built skills that exist on first launch, all gated through Compile-Verify-Mint, all structurally enforced per §22. These skills are the *Tier-1 + Tier-3 hand-crafted seed* for the broader auto-mint flywheel (§19).

Each skill below has: name, what it does, why structural enforcement makes it reliable, and (for the most novel ones) a code sketch.

### 23.1 Concept and idea management

#### 23.1.1 Idea Genealogy Tracker

When a new note is captured, the system identifies its conceptual ancestors (notes whose ideas seeded this one). Genealogy edges are typed: `inspired_by`, `extends`, `contradicts`, `applies`, `synthesizes`.

```rust
// agent_core/src/skills/idea_genealogy.rs
#[derive(Serialize, Deserialize, JsonSchema)]
pub struct GenealogyEdge {
    pub kind: GenealogyKind,         // closed enum, grammar-enforced
    pub ancestor_note_id: NoteId,    // closed enum from vault, grammar-enforced
    pub confidence: f32,
    pub rationale: String,           // ≤140 chars, grammar-enforced
}

#[derive(Serialize, Deserialize, JsonSchema)]
pub enum GenealogyKind {
    InspiredBy, Extends, Contradicts, Applies, Synthesizes,
}

pub struct IdeaGenealogyTool;

#[async_trait]
impl Tool for IdeaGenealogyTool {
    const NAME: &'static str = "knowledge.idea_genealogy";
    type Input = GenealogyInput;
    type Output = Vec<GenealogyEdge>;

    async fn invoke(&self, input: Self::Input, ctx: &ToolCtx) -> Result<Self::Output, ToolError> {
        // No-LLM-first: embedding nearest neighbours over the vault's existing notes.
        let candidates = ctx.vault.semantic_search(&input.note_text, 12).await?;
        // Constrained classify each candidate's relationship.
        let mut edges = Vec::new();
        for cand in candidates.iter().take(5) {
            let edge = ctx.tools.invoke("reason.classify_relation", json!({
                "subject": &input.note_text, "candidate": &cand.body
            })).await?;
            if edge.confidence >= 0.6 { edges.push(edge.into()); }
        }
        Ok(edges)
    }
}
```

**Why the structural moat matters here:** without grammar enforcement, models hallucinate kinds like "is_related_to" or "kind_of" that aren't in any taxonomy. With closed-enum `GenealogyKind`, they cannot. The genealogy graph stays clean.

#### 23.1.2 Steelman Generator

For any claim the user has made in their vault, find the strongest counter-argument from elsewhere in the vault — or, if none exists, propose one drawn from concept-adjacent territory.

The output is structured as a Toulmin argument: claim, grounds, warrant, backing, rebuttal. Each field is grammar-bound; the rebuttal is the steelman.

#### 23.1.3 Polyseme Disambiguator

Detects when a word like "attention" carries two meanings across the vault (ML attention vs psychological attention). When you write a note that mentions the term, the system asks (one keystroke): "Which sense?" The answer attaches a `sense:` frontmatter field; future searches can disambiguate.

#### 23.1.4 Concept Density Heatmap

Pure-Rust, no LLM. Reports which concepts in the vault have grown most this month (most new edges, most new notes mentioning them, most cross-folder activity). Surfaces as a Layer-2 panel; never blocks capture.

#### 23.1.5 Latent Idea Detector

Clusters sentences across notes that aren't yet linked but cosine to a single concept. Surfaces weekly: *"You wrote about X in 5 different notes this month with no link between them — synthesis candidate."* Pure embedding clustering; no LLM in the detection path. LLM (under grammar) is invoked only when the user accepts the synthesis suggestion.

### 23.2 Argument and reasoning

#### 23.2.1 Argument Map Builder

Extracts claims from prose, links to supports / contradictions / rebuttals across the vault, builds a Toulmin-style argument tree. Every node is a typed claim (closed `kind` enum); every edge is a typed relation. The model emits only the AST; rendering is deterministic SVG.

#### 23.2.2 Trust Provenance

Every factual claim in the vault has a provenance chain. When a source note is deleted or modified, downstream claims that depend on it are flagged "provenance broken — reverify or remove". Structurally enforced by a `provenance_chain: [note_id]` field that must be a closed enum from the vault at write time.

#### 23.2.3 Opinion Drift Tracker

Detects when the user's stated position on a topic has shifted over time. Implementation: per-topic time-series of stance vectors (extracted via NLI on every note), surface drift alerts when stance variance exceeds a threshold. The output schema is typed; no fabricated drift events possible.

#### 23.2.4 Question-Driven Research

Extracts open questions from notes (sentences ending in `?` plus a closed-vocab classifier for "is this a research question") and surfaces them periodically. Each question becomes a first-class node in the vault graph; resolution is tracked when a later note asserts an answer (entailment-checked).

### 23.3 Memory and recall

#### 23.3.1 Forgetting Curve Surfacer

Surfaces old notes per Ebbinghaus / SM-2 (Anki) spacing — but ambiently, not as flashcards. When you open the daily journal, three notes from 1/7/30/180 days ago appear in a sidebar. Pure deterministic algorithm; no LLM. The selection criteria are typed; the surfacing is consistent across sessions.

#### 23.3.2 Deferred Wisdom

Surfaces notes you wrote 3+ years ago that are now relevant to current work. Implementation: when you start writing a new note, embed the partial draft, find old notes within cosine 0.85 that haven't been referenced in 365+ days, and surface them as Layer-2 suggestions.

#### 23.3.3 Knowledge Graph Diff

Pure-Rust. Shows how the concept network changed week-over-week — new nodes, new edges, deleted edges, drifted centroids. Surfaces in the weekly review.

#### 23.3.4 Reading Halflife Tracker

Each book/paper you read is tagged with how often you re-cite it over time. Half-life decay is mechanical; the tag value is computed deterministically. Lets you spot which sources continue to inform your thinking vs. which were one-time citations.

### 23.4 Capture quality control

#### 23.4.1 Capture Throttle

Detects when you're capturing in volume without processing — inbox count growing faster than triage rate. Surfaces a quiet badge ("you have 47 unrouted captures, 12 from this week") with one-tap to triage. Pure rate-based math; no LLM.

#### 23.4.2 Cognitive Stuck Detector

Notices when you've been writing about the same concept for >N days without progress (no new claims, no new links, only rephrasing). Surfaces an intervention prompt: *"You've been on X for 5 days with no new claims. Want to draft a synthesis or move to a different thread?"*

#### 23.4.3 Quiet Concept Detector

Concepts you mention exactly once but never elaborate. Could be abandoned thoughts worth resurfacing. Weekly digest, opt-in.

### 23.5 Authoring assistance under invariants

#### 23.5.1 Summary Drift Alert

When you write a summary of a note, the system runs entailment between summary and source. Summary claims that aren't entailed by the source are flagged at write time. Prevents inadvertent paraphrasing-into-fabrication.

#### 23.5.2 Citation Round-trip

Every external claim you write must be traceable to a source you've explicitly added. The grammar of citation insertion (§22.6) makes fabricated citations structurally impossible; this skill checks the inverse — claims without citations get a soft flag.

#### 23.5.3 Synthesis Prompts

Weekly digest of "you have 12 notes about X but no synthesis note; want to draft one?" — only fires when the cluster is tight (cosine ≥ 0.85 across ≥10 notes) and no synthesis note exists.

### 23.6 Time-aware skills

#### 23.6.1 Temporal Reasoning Grammar

Every time-bound claim is anchored to a date, with valid-since/valid-until ranges. The grammar enforces that any claim with temporal modifiers ("currently", "since 2024", "until December") parses to a typed range; ambiguous temporal claims are flagged or routed to defer.

#### 23.6.2 Habit / Streak Tracker

Log entries are typed; the LLM extracts them from journal text (under grammar) but cannot fabricate them. Closed-vocab `habit_id` ensures only habits the user has declared are tracked.

#### 23.6.3 Note Recency Guarantee

When a note is last touched > N days ago and the user references it in a new note, surface a "this note is stale (last touched 2026-01-15) — reverify?" prompt. Pure mtime check.

### 23.7 Procedural and meta

#### 23.7.1 Procedural Memory Auto-Capture

When you do the same multi-step thing 3+ times (detected by `meta.compose` repeated patterns), propose codifying as a skill via the cloud-generator pipeline (§21). The proposal is opt-in; minted skills go through Compile-Verify-Mint same as any other.

#### 23.7.2 Cross-Vault Pattern Detection

Find behavioral patterns across years of journal entries — "you mention sleep issues every March" or "your output drops the week after travel". Pure time-series analytics over typed log entries; no LLM in detection.

#### 23.7.3 Diff-as-Idea

Every edit to a note is captured as a typed "idea event" — what changed, when, with what mental motivation (auto-extracted from the commit message or contextual clues). Lets you replay the evolution of your own thinking.

#### 23.7.4 Intent-of-Reading

When you clip a web page, the system asks "for what?" — that intent becomes structured frontmatter, retrievable later: *"all the things I've read for project X"*.

#### 23.7.5 Note-as-Question

A note can be flagged as an open question. The system tracks when it's been answered (by another note that entails the answer). Open-question lifecycle becomes first-class.

### 23.8 Code skills under structural enforcement

#### 23.8.1 Refactor as Typed Edit

Every refactor proposal is a typed `WorkspaceEdit` (LSP shape) — not free-form text describing the refactor. The model emits ranges and replacement text under grammar; the editor previews atomically; user accepts or rejects.

#### 23.8.2 Doc Generation Bound to Style

`code.doc_generate` outputs constrained to the language-specific doc grammar (rustdoc / jsdoc / docc). The model cannot drift into mid-doc prose that breaks the doc-generator pipeline.

#### 23.8.3 Test-First Skill Mint

A user can say "I want a tool that does X" without writing code. The system drafts the skill *test-first* (cloud or local generator, per §21), runs the test, then drafts the implementation. The test is the spec; the implementation is constrained to satisfy it.

### 23.9 Catalog summary

| Category | Skills (count) | All structurally enforced? | LLM in hot path? |
|---|---|---|---|
| Concept / idea | 5 | yes | only under grammar |
| Argument / reasoning | 4 | yes | only under grammar |
| Memory / recall | 4 | yes | none for surfacing |
| Capture quality | 3 | yes | none for detection |
| Authoring | 3 | yes | only under grammar |
| Time-aware | 3 | yes | none for detection |
| Procedural / meta | 5 | yes | only under grammar |
| Code | 3 | yes | only under grammar |
| **Total** | **30 hand-crafted built-in skills** | | |

These 30 are the seed. The auto-mint pipeline (§18, §21) grows the skill library from this base. Every skill ships with: input schema, output schema, grammar, ≥3 unit tests, integration test, soul prompt template, model-by-model calibration in §6.5.

### 23.10 Generating the skill code

To make this concrete and actionable: the building agent can generate scaffolding for a new skill in this catalog using the templater pipeline (§21.2). A reference invocation:

```bash
# Future CLI surface (not yet built — this is the contract)
epistemos skill new \
  --template skill/observation_with_typed_kind.template \
  --slot SKILL_NAME=knowledge.idea_genealogy \
  --slot KIND_ENUM='InspiredBy,Extends,Contradicts,Applies,Synthesizes' \
  --slot CONFIDENCE_THRESHOLD=0.6 \
  --slot CANDIDATES_K=12
# → drafts the slot-fills via local Hermes-3-8B
# → runs Compile-Verify-Mint (§17.2)
# → registers on success
# → writes the test fixture and soul prompt template alongside
```

The template `skill/observation_with_typed_kind.template` captures the common pattern: extract candidates via no-LLM retrieval → classify each via grammar-bound LLM call → filter by confidence → return typed array. Most of §23's skills fit this shape; that template alone covers ~12 skills. Three more templates cover the other ~18.

Result: shipping 30 built-in skills doesn't require 30 hand-coded skill files. It requires ~5 templates and 30 slot-spec files. The templater compounds.

### 23.11 Verification of the catalog

Phase 11 eval gains a catalog-wide test:

- Every built-in skill must pass its own ≥3 unit tests on every model in §6.5.
- Every built-in skill must pass an integration test that exercises it on a 50-note seed vault.
- Every built-in skill's grammar must compile on every constraint backend in §6.3.
- Every built-in skill's `_meta.confidence` distribution must be calibrated (Brier score ≤ 0.15) against held-out labeled data.

Skills that fail any gate are not shipped. The fortress is built from verified bricks only.

---

## 24. Architectural Borrows from Cutting-Edge Agent Repositories — The Real Moat

The 2026 agent memory landscape has converged on a small set of repositories whose architectural choices have been battle-tested in public. This section enumerates each one's *moat*, decides which to adopt, and shows how the synthesis becomes Epistemos's defensible architectural position. Citations are inline; everything below is grounded in the public record as of 2026-04.

### 24.1 The 2026 memory-wars context

The agent-memory space has fragmented into three philosophies:

| School | Exemplar | Core idea |
|---|---|---|
| **Graph-based** | Mem0 | Facts as triples; retrieval traverses relationships (`user works in Python → at company X → using dbt → migrating from Spark`). |
| **Observational / long-context** | Mastra | Brute-force coverage. With 1–2M context windows, retrieval is sometimes worse than just loading everything; SOTA on LongMemEval via this approach. |
| **OS-inspired tiered** | Letta (formerly MemGPT) | Core (RAM-like) → Recall (disk-cache-like) → Archival (cold-storage); agent self-edits via tool calls to promote/demote. |

A fourth, **MemPalace**, is rising fast (22K stars in 48h, leads LongMemEval at 96.6% raw / 100% with reranker) by going against the grain: verbatim-only retention, spatial indexing.

Epistemos's position: **adopt the strongest moat from each, compose them, and let the user's vault be the substrate that holds them all.** The composition is the moat — no single repo above is doing it.

### 24.2 MemPalace borrow — verbatim retention + spatial indexing

**Moat**: MemPalace stores conversation history *verbatim*. It does not summarize, extract, or paraphrase. The index is structured spatially — **Wings** (projects, people, topics) → **Rooms** (sub-topics within a wing) → **Halls** (memory-type corridors that *cut across* all wings) → **Drawers** (the verbatim content). Retrieval is scoped to a wing/room/hall, not run flat across a corpus. This dual-axis index (spatial + by-memory-type) is the trick.

**Adopt for Epistemos**: yes, in full. The vault becomes a Wing/Room/Hall/Drawer addressing space *layered on top of* the existing folder hierarchy. Folders give the user filesystem-native navigation; spatial coordinates give the agent multi-axis retrieval.

```rust
// agent_core/src/spatial/mod.rs
#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug)]
pub struct SpatialCoord {
    pub wing: WingId,           // project / person / topic — closed enum (auto-extends)
    pub room: Option<RoomId>,   // sub-topic — closed within wing
    pub hall: HallId,           // memory-type corridor — closed enum (10 types per §24.3)
    pub drawer_path: PathBuf,   // verbatim content (the actual .mem file)
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug)]
pub enum HallId {
    Identity, Preference, Goal, Project, Habit,
    Decision, Constraint, Relationship, Episode, Reflection,
    Capture, Semantic, Procedural,    // Epistemos extensions
}
```

**Verbatim invariant** (NEW INVARIANT in §2.5): the original capture text is **never** rewritten in place. Summaries, extractions, abstractions are *derived artifacts* stored alongside, with provenance pointers back to the verbatim drawer. Accidental data loss via "the model summarized over my words" is structurally impossible. The user can always read what they actually said/captured, byte-for-byte.

Spatial coords are stored in the .mem frontmatter; the spatial index is a thin SQLite+FTS5 table mirroring the user's folder tree plus the cross-cutting hall index. Every search tool gains a `scope` parameter that takes a SpatialCoord prefix.

**Verification gate**: 50-case retrieval eval where the answer requires hall-cross-wing scoping (e.g., "what decisions have I made about Python in any project?"). Spatial-scoped search must beat flat search by ≥30% top-1 accuracy on this set.

### 24.3 Mercury borrow — 10 typed memory categories with SQLite+FTS5 substrate

**Moat**: Mercury (cosmicstack-labs/mercury-agent) maintains a **structured persistent memory of 10 closed types** — identity, preference, goal, project, habit, decision, constraint, relationship, episode, reflection — stored in `~/.mercury/memory/second-brain/second-brain.db` (SQLite + FTS5). Closed enum at the type level forces the model to *file* rather than free-form.

**Adopt**: yes, with extensions. Our `.mem` format's `type` field expands from `{episodic, semantic, procedural, capture}` to the unified 13-type enum (Mercury's 10 + our 3). The `HallId` from §24.2 is the same enum, used for spatial indexing. SQLite+FTS5 backs the index.

```rust
// agent_core/src/format/mem.rs (extension)
#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug)]
pub enum MemType {
    // Mercury's 10
    Identity, Preference, Goal, Project, Habit,
    Decision, Constraint, Relationship, Episode, Reflection,
    // Epistemos extensions for PKM
    Capture,        // raw quick-capture, not yet processed
    Semantic,       // extracted facts (an A-MEM atomic note)
    Procedural,     // skills (Voyager-shaped)
}
```

The grammar for any tool that writes to memory uses this 13-value closed enum. The model picks one — never fabricates a 14th.

### 24.4 soul.md borrow (aaronjmars/soul.md) — split identity into 4 typed files

**Moat**: instead of one monolithic identity file, soul.md splits into four:

- **SOUL.md** — who the user is (values, voice, context).
- **STYLE.md** — how the user writes (sentence length, tone, citation conventions).
- **SKILL.md** — operating modes (when to be terse, when to push back, when to defer).
- **MEMORY.md** — session continuity log (notable events appended).

Each is a typed artifact with its own schema. The agent reads all four as system prompt context but the *write* paths are separate (e.g., MEMORY.md is append-only).

**Adopt**: yes. Our `.soul` paired-file (§2.3) becomes a directory of four typed files. Schema:

```
agent_core/data/soul/
  SOUL.json           # 4 typed files, JSON-schema validated
  SOUL.md             # narrative
  STYLE.json
  STYLE.md
  SKILL.json
  SKILL.md
  MEMORY.jsonl        # append-only event log (no .md half — pure structured)
```

The four `.json` files are read into one composed `Soul` struct at session start. The `.md` files are concatenated into the system prompt as Layer-2 context. **Append-only MEMORY.jsonl** is critical — like Mercury's session-continuity log, it accumulates "notable events" the agent decides are worth carrying forward. Append-only is the safety net; nothing the agent does can erase prior session memory.

### 24.5 Hermes Agent borrow — 15-tool self-eval checkpoint

**Moat**: Hermes Agent (NousResearch) hits a **self-evaluation checkpoint every 15 tool calls** asking *"what worked, what failed, is anything worth capturing as a skill?"* Empirically: an image-gen workflow took 23 tool calls on first run; after the checkpoint captured a skill, run 2 was 8 calls and run 3 was 6. Measurable compound improvement.

**Adopt**: yes. The variant runner gains a checkpoint counter; every 15 successful tool invocations (per session) triggers `meta.self_evaluate`:

```rust
// agent_core/src/heal/checkpoint.rs
pub struct SelfEvalCheckpoint {
    pub interval: u32,                // 15 tool calls
    pub min_session_age: Duration,    // skip if session is too young
}

impl ToolRunner {
    async fn maybe_checkpoint(&mut self, ctx: &SessionCtx) -> Option<CheckpointOutcome> {
        if ctx.tool_calls_this_session % 15 == 0 && ctx.tool_calls_this_session > 0 {
            let trace_window = ctx.recent_trace(15);
            let outcome: CheckpointOutcome = self.tools
                .invoke("meta.self_evaluate", json!({"window": trace_window}))
                .await.ok()?.into();
            if let Some(skill_draft) = outcome.skill_proposal {
                // Hand off to the cloud-or-local generator pipeline (§21).
                self.mint_pipeline.queue(skill_draft).await;
            }
            Some(outcome)
        } else { None }
    }
}
```

The output is grammar-bound (closed enum on `outcome` — `improved | unchanged | skill_proposed | refactor_proposed`); the model cannot freelance. The checkpoint is the cadence at which the agent *learns from itself* — not a continuous overhead, not a one-shot summary, but a periodic structured reflection.

### 24.6 Hermes Self-Evolution borrow — GEPA + DSPy trace-driven optimization

**Moat**: NousResearch/hermes-agent-self-evolution (ICLR 2026 Oral) uses **GEPA** (Genetic-Pareto) + **DSPy** to read execution traces, identify *why* things failed, and propose targeted prompt/skill/code revisions. Not random sampling — failure-trace-driven evolution.

**Adopt** as **Phase 13 (post-Wave 5)** — opt-in evolutionary optimization. The heal-event log (§5.7) and the action-trace log (§5.5) are exactly the trace data GEPA consumes. A weekly NightBrain job (opt-in) runs GEPA over the past 7 days of traces, proposes prompt/few-shot/skill revisions, and surfaces them in the review queue. User accepts → the revision goes through the §17.2 mint pipeline same as any other skill change.

```
agent_core/src/evolution/
  gepa.rs                    # genetic-pareto trace mining
  dspy_optimizer.rs          # DSPy program adapter
  proposals.rs               # revision proposals — typed AST of what to change
```

This bounds the optimization surface: only prompt+few-shot+skill-code changes are proposed. The Rust core itself is never auto-modified.

**Explicit non-goal**: never automatic. Every proposal is user-confirmed. Evolution serves the user; it doesn't take over.

### 24.7 Atropos borrow — trajectory export for opt-in RL fine-tuning

**Moat**: NousResearch/atropos is an RL framework that consumes batched tool-calling trajectories. The user's own corpus of successful captures + corrections + heal events is exactly that data shape. Once exported, the user can fine-tune a personal LoRA against their own behavior.

**Adopt**: yes, as opt-in export tool (`meta.export_trajectories_atropos_format`). The tool serializes the action trace + corrections + heal events into Atropos's expected format. The user runs Atropos elsewhere (separate machine, separate process — Atropos is heavyweight). The result LoRA can be loaded back into the local model via MLX adapter loading.

This closes the loop: **the user's behavior becomes the dataset; the local model becomes more aligned with the user over time, on the user's own machine, never via cloud fine-tuning.** This is the deepest moat in this entire plan.

### 24.8 Letta borrow — OS-tiered memory with explicit promotion tools

**Moat**: Letta (formerly MemGPT) separates memory into **three tiers** explicitly addressable by the agent:

- **Core memory** — small, always in-context (RAM-like). The agent reads/writes directly.
- **Recall memory** — searchable conversation history (disk-cache-like). Queried via tool.
- **Archival memory** — long-term storage queried via tool calls (cold-storage-like).

Crucially, **the agent self-edits via function calls to move information between tiers**. Promotion and demotion are first-class agent actions, not background heuristics.

**Adopt**: yes. Add three memory tools to §3.5's catalog:

- `memory.promote_to_core` — pin a fact into the always-loaded context block.
- `memory.demote_to_archival` — move a stale fact out of recall into archival.
- `memory.swap_recall` — explicitly swap recall slots (when context is tight).

The grammar bounds tier transitions (each transition is a typed AST of source-tier + target-tier + entry-id + reason). The model decides, the runtime enforces, the user sees the trace.

**The Mercury-typed memory + Letta-tiered memory composition is novel.** Mercury's 10-type closed enum tells you *what kind* of memory it is; Letta's three tiers tell you *how hot* it is. Each .mem file has both: `type: MemType` and `tier: Tier`. The agent can ask "give me all Decisions in Core" or "promote this Reflection from Archival to Recall."

### 24.9 Mem0 (graph) and Mastra (observational) — modes, not architectures

**Moat (Mem0)**: graph memory traverses fact-relationships. Strong on multi-hop QA. Already implicit in our concept graph (§4.7) — each canonical concept node has typed edges (genealogy, contradiction, refinement) per §23.1.1.

**Moat (Mastra)**: with 1–2M context windows, brute-force loading sometimes beats elegant retrieval. Mastra holds SOTA on LongMemEval via this approach.

**Adopt as modes**: when the local 7B's context budget allows it (≥8k tokens free) AND the conversation has been short (<20 turns), the **observational mode** loads the entire recent context verbatim instead of running retrieval. Pure-Rust heuristic; no model decision. The graph mode is the default for cross-document reasoning (already in concept-graph code).

```rust
// agent_core/src/memory/mode.rs
pub enum MemoryMode { Observational, Graph, Tiered }

pub fn pick_memory_mode(ctx: &Ctx) -> MemoryMode {
    if ctx.conversation_turns < 20 && ctx.context_budget_remaining > 8000 {
        MemoryMode::Observational         // Mastra-style; brute force
    } else if ctx.intent.is_relational() {
        MemoryMode::Graph                  // Mem0-style; traverse edges
    } else {
        MemoryMode::Tiered                 // Letta-style; explicit promotion/demotion
    }
}
```

### 24.10 OpenClaw borrow (Pro profile only) — multi-channel + sender-scoped permission

**Moat**: OpenClaw (302K stars by 2026-04-03) is a multi-channel local-first agent gateway with permission boundaries scoped per sender. If multiple people can message the same tool-enabled agent, each is steered within their granted permissions; non-owner senders affect only owner-scoped tools.

**Adopt**: **Pro profile only**. Phase H (iMessage as channel, per project memory) consumes this pattern: incoming messages enter through a `ChannelDispatch` layer that scopes the available tool surface per `(channel, sender)`. App Store profile ships single-user single-channel; Pro ships multi-channel.

This is the **OpenClaw pattern from your existing Phase R / Phase K plans** — already aligned. §24 just names the source of the architectural moat.

### 24.11 The synthesized moat

No public agent project does *all* of this. Each picks one or two of the moats above and stops. Epistemos's defensible position is the **composition**:

```
Verbatim retention (MemPalace)
  + Wing/Room/Hall/Drawer spatial indexing (MemPalace)
  + 13 closed-enum memory types (Mercury + Epistemos extensions)
  + 4-file split soul (soul.md repo)
  + 15-tool self-eval checkpoint (Hermes Agent)
  + Trace-driven evolution via GEPA (Hermes self-evolution)
  + Trajectory export for personal-LoRA RL (Atropos)
  + Tiered memory with explicit promotion (Letta)
  + Graph + observational + tiered as adaptive modes (Mem0 + Mastra + Letta)
  + Multi-channel sender-scoped permission (OpenClaw, Pro only)
  + Compile-Verify-Mint for skills (§17, beyond all of the above)
  + Sampler-bound dispatch for tool calls (§17, beyond all of the above)
  + CRANE + IterGen + Grammar-Aligned (§22.1, beyond all of the above)
  + Cloud-as-Generator + Templater for capability extension (§21, beyond all of the above)
```

Each line is its own moat. Each line by itself is something at least one well-funded competitor is trying to ship. The product is the integration. **No external service is required for any of it.** The vault is the substrate that holds them all.

This is the answer to *"what makes Epistemos defensible"*: it's not a single trick — it's that every cutting-edge agent-architecture moat from the 2026 agent-memory wars composes into one coherent local-first system on the user's Mac, with the user's data, with the user's control. Competitors will pick two and ship. Epistemos picks all of them, and the engineering rigor in §17–§22 is what makes the composition tractable instead of fragile.

### 24.12 Phase additions

| Phase | New scope from §24 | Verification |
|---|---|---|
| **Phase 1** | `.mem` type enum extends to 13 (Mercury borrow §24.3); soul splits into 4 typed files (§24.4); Verbatim invariant (§24.2) | Round-trip tests on 4-file soul; verbatim-preservation property test |
| **Phase 2** | Spatial index (Wing/Room/Hall/Drawer) layered on folder tree (§24.2) | Spatial-scoped retrieval beats flat by ≥30% top-1 on hall-cross-wing eval |
| **Phase 3** | Memory mode selector (Observational / Graph / Tiered, §24.9) | Mode picker matches expert labels on 50-case eval ≥85% |
| **Phase 4** | 15-tool self-eval checkpoint (§24.5) | Eval workflow: same task run 3× shows decreasing tool-call count by ≥30% |
| **Phase 8** | Letta-style memory.promote / demote / swap tools (§24.8) | Round-trip tier transitions preserve content; agent's stored intent matches outcome |
| **Phase 11.5 → Phase 13 (new)** | GEPA + DSPy evolution (§24.6); Atropos trajectory export (§24.7) | Weekly digest produces ≥3 actionable revision proposals against a 7-day synthetic trace; Atropos export validates against the framework's reader |
| **Phase H (Pro)** | OpenClaw multi-channel + sender-scoped permission (§24.10) | Permission scope test: non-owner sender cannot invoke owner-only tools |

Phase 13 is **new** and slots between current Phase 12.5 (skill discovery) and Pro/Wave 5 work — it's the evolution-and-export wave.

### 24.13 Updates to other sections

- **§2.5 Migration story**: add "verbatim retention is invariant — derived artifacts (summaries, extractions, abstractions) are stored alongside the verbatim drawer with provenance pointers, never replacing the original."
- **§16 Definition of Done**: add criterion #25 — "MemPalace-style retrieval bench: Epistemos vault scoped retrieval beats flat retrieval by ≥30% top-1 on a hall-cross-wing test set; soul split passes integrity checks; 15-tool checkpoint demonstrates measurable skill capture."
- **§15 References**: add the eight repos cited in §24.

---

## 25. Porting the Moat to Your Codebase — Zero-Copy Hybrid Expression

The previous sections (§17–§24) describe architectural moats. This section grounds every one of them in **the actual files that already exist in this repo** and shows how to port the new patterns onto the existing surface rather than build from scratch. The work is dramatically smaller than the section count implies — much of the substrate is already there.

The deep claim of this section: **the moats from MemPalace / Mercury / soul.md / Hermes / Letta / OpenClaw can all be expressed as additive extensions on top of existing Rust types in `agent_core/` and Swift types in `Epistemos/`, with zero-copy data flow across UniFFI, leveraging Apple Silicon's unified memory.** The hybrid is not a rewrite; it is a careful composition.

### 25.1 Inventory of what already exists

A codebase scan surfaced eight load-bearing primitives that map almost 1:1 to moats from §24. Each is a working module today, not a plan.

| Existing surface | File | What it already does | Moat alignment |
|---|---|---|---|
| **VaultStore** | `agent_core/src/storage/vault.rs` | rusqlite + Tantivy hybrid search | MemPalace substrate |
| **MemoryClassifier** | `agent_core/src/storage/memory_classifier.rs` | `VaultFact` + `MemoryOperation::{Add, Update, Delete, Noop}` with 384-dim embeddings | Mercury typed memory |
| **SessionGraph** | `agent_core/src/storage/session_graph.rs` | Typed nodes (entity / concept / tool / file) + edges with `EdgeConfidence` (Extracted / Inferred / Ambiguous) | Mem0 graph memory |
| **VaultRegistry** | `agent_core/src/vault_registry.rs` | Multi-vault identity: `Model / Agent / Team / UseCase / Personal` with priority-based merge | soul.md split substrate |
| **SkillRouter** | `agent_core/src/skill_router.rs` | TF-IDF skill matching from `SKILL.md` files in `vault/skills/` | Voyager + Hermes Agent skill capture |
| **ContextLoader** | `agent_core/src/context_loader.rs` | 5-tier injection: L4=SOUL.md, L3=facts, L2=patterns/skills, L1=episodes, L0=working | **Letta tiered memory, already implemented** |
| **ToolRegistry** | `agent_core/src/tools/registry.rs` | 33 tools registered with `ToolTier` (None/ChatLite/ChatPro/Agent/Full) + `RiskLevel` (ReadOnly/Modification/Destructive) | OpenClaw permission scoping |
| **HermesPromptBuilder** + **LocalToolGrammar** | `Epistemos/LocalAgent/HermesPromptBuilder.swift`, `LocalToolGrammar.swift` | Hermes XML format + Swift-side tool grammar | Tool-call normalizer + Grammar-Aligned wiring |
| **AgentSession** + `AgentEvent` stream | `epistemos-core/uniffi/epistemos_core.udl`, `epistemos-core/src/uniffi_exports.rs` | UniFFI-exposed agent loop with `{sequence, phase, payload, timestamp}` async events | Intent→Effect stream substrate |
| **InstantRecall** + **TrigramEmbedder** | UDL lines 101–122 | Embedding create/insert/remove/search/encode | MemPalace verbatim retrieval substrate |

Cargo dependencies already present: `uniffi 0.28`, `tantivy 0.22`, `rusqlite 0.32`, `tracing 0.1`, `tokio 1.43` (full), `serde`, `uuid`, `chrono`, `regex`, `sha2`, `rayon`. Missing: `llguidance`, `schemars`, `jsonschema`, `proptest`. These are net-new but additive.

### 25.2 The zero-copy spine

The user's framing — "zero-copy like magic deterministic engineering" — translates to a specific data-flow contract across the three layers (Rust, MLX, Swift). On Apple Silicon's unified memory, this contract eliminates serialization-marshalling-deserialization between layers.

```
┌───────────────────────────────────────────────────────────────┐
│  UNIFIED MEMORY (one physical address space)                  │
│                                                                │
│  ┌──────────────────┐    ┌──────────────────┐    ┌─────────┐ │
│  │ Rust agent_core  │    │ MLX-Swift        │    │ Swift UI │ │
│  │ — VaultFact      │    │ — model weights  │    │ — Views  │ │
│  │ — embeddings     │◄──►│ — KV cache       │◄──►│ — TextKit│ │
│  │ — SessionGraph   │    │ — logit buffers  │    │          │ │
│  │ — Tantivy index  │    │                  │    │          │ │
│  └──────────────────┘    └──────────────────┘    └─────────┘ │
│           ▲                                                    │
│           │                                                    │
│  Tantivy mmap'd indexes + rusqlite WAL = on-disk persistence,  │
│  in-memory zero-copy slices = working set                      │
└───────────────────────────────────────────────────────────────┘
```

Concrete invariants:

- **Tantivy indices are mmap'd**, not copied into Rust heap; `tantivy::Index::open_in_dir` already does this. No serialization on read.
- **`Vec<f32>` embedding (384-dim) in `VaultFact`** is contiguous and `Send`. When passed to MLX as an input tensor, MLX wraps the same memory — no copy. (Implementation detail: `mlx_rs::Array::from_slice` accepts a `&[f32]` and the underlying buffer becomes the MLX kernel input; MLX-Swift is the same on the Swift side.)
- **UniFFI types crossing the boundary are owned values, not borrowed** (per Mozilla's contract; §6.8). But on the Rust side, every internal call is `Arc<[u8]>` or `&[T]` — no clone. Marshalling cost is paid once at the boundary, never inside the Rust core.
- **Grammar-bound generation reads token IDs from MLX's KV-cache buffer directly**; the constraint mask is computed in-place over the logit array MLX writes to. No temporary buffers.

This is what "zero-copy magic" means in the user's vocabulary. The plan is to never violate it. Every port below preserves it.

### 25.3 Port: MemPalace verbatim + spatial indexing → `VaultStore`

The MemPalace moat (§24.2) — verbatim retention plus Wing/Room/Hall/Drawer spatial coords — is an **extension** of `VaultStore` and `vault_registry::VaultId`, not a replacement.

**Extension to `agent_core/src/storage/vault.rs`** (additive):

```rust
// Existing trait stays unchanged.
pub trait VaultBackend {
    async fn hybrid_search(&self, query: &str, limit: usize, tag_filter: &[String]) -> Result<Vec<SearchResult>>;
    async fn read(&self, path: &str) -> Result<VaultDoc>;
    async fn write(&self, path: &str, body: &str, frontmatter: Value) -> Result<WriteReceipt>;
    // ... existing operations
}

// NEW: spatial-aware additions, not replacements.
pub trait SpatialVault: VaultBackend {
    async fn search_scoped(
        &self, query: &str, scope: SpatialScope, limit: usize,
    ) -> Result<Vec<SearchResult>>;
    async fn list_hall(&self, hall: HallId, limit: usize) -> Result<Vec<VaultDoc>>;
    async fn promote_drawer_to_hall(&self, drawer: &str, hall: HallId) -> Result<()>;
}

#[derive(Serialize, Deserialize, JsonSchema)]
pub struct SpatialScope {
    pub wing: Option<WingId>,    // optional; absent = all wings
    pub room: Option<RoomId>,
    pub hall: Option<HallId>,
}

// Wings auto-extend from existing folder tree at index time.
// Halls are the closed enum from §24.3 (13 values).
```

**Verbatim invariant in writes**: `VaultBackend::write` gets a paired method `write_verbatim_with_derivative`:

```rust
async fn write_verbatim_with_derivative(
    &self,
    path: &str,
    verbatim: &str,                      // user's words, byte-for-byte
    derivative: Option<DerivativeArtifact>,  // summary/extraction with provenance
) -> Result<WriteReceipt>;
```

The verbatim drawer is content-addressed by sha256 and immutable. Derivatives reference the drawer hash. Tantivy indexes both — verbatim for exact recall, derivative for fast summary lookup.

**Storage layout** (additive, no breaking change to existing):

```
vault/
  <existing folder tree per current convention>
  .epistemos/
    spatial/
      wings.sqlite          # wing_id → folder_path mapping
      halls.sqlite          # hall_id → drawer_id index (cross-cutting)
      drawers/              # content-addressed verbatim store
        sha256_<hash>.mem   # immutable; derivatives reference these
```

Existing `vault.read("SOUL.md")` keeps working. New `vault.search_scoped("Python decisions", SpatialScope { hall: Some(Decision), wing: None, room: None })` adds the new capability.

### 25.4 Port: Mercury 13-type memory → `MemoryClassifier::VaultFact`

The Mercury moat (§24.3) — 13 typed memory categories — is an **extension of the existing `MemoryOperation` enum** in `agent_core/src/storage/memory_classifier.rs`. The current code already does typed memory operations; we extend the type space.

**Extension to `agent_core/src/storage/memory_classifier.rs`**:

```rust
// EXISTING (preserved):
pub struct VaultFact {
    pub file_path: String,
    pub section: String,
    pub embedding: Vec<f32>,    // 384 dims — KEEP
    pub strength: f64,
}

pub enum MemoryOperation {
    Add { fact: VaultFact, mem_type: MemType },     // <- mem_type added
    Update { target_file: String, target_section: String, fact: VaultFact, mem_type: MemType },
    Delete { target_file: String, target_section: String },
    Noop { reason: String },
}

// NEW: closed enum across Rust + Swift via UniFFI.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug)]
#[repr(u8)]
pub enum MemType {
    Identity, Preference, Goal, Project, Habit,
    Decision, Constraint, Relationship, Episode, Reflection,
    Capture, Semantic, Procedural,
}
```

Add a `mem_type` column to the existing rusqlite schema (forward-compatible migration; old rows default to `Capture`). The `memory_classifier.rs` decision logic gains a `select_mem_type` step (grammar-bound LLM call into the closed 13-enum) before producing `MemoryOperation::Add`.

UniFFI exposure: the enum becomes `MemType` in the Swift API automatically (UDL `enum MemType { Identity, ... };`). Swift code can switch on it directly — no string parsing.

### 25.5 Port: soul.md 4-file split → `VaultRegistry` + `ContextLoader`

The soul.md moat (§24.4) — split identity into SOUL/STYLE/SKILL/MEMORY — maps cleanly onto two existing modules:

- **`agent_core/src/vault_registry.rs`** already supports multi-vault identity (`Model / Agent / Team / UseCase / Personal`). Each soul-file pair becomes a `VaultId`. `Personal` vault is `SOUL.{json,md}`. `Style` is added as a new `VaultId` variant. Skills already live in `vault/skills/` per `SkillRouter`. `MEMORY.jsonl` is append-only — a new vault variant.
- **`agent_core/src/context_loader.rs`** already does 5-tier context injection (L4=SOUL.md, L3=facts, ...). The 4-file split fits into the existing tiers: L4 reads SOUL.md + STYLE.md + SKILL.md (concatenated as identity) + MEMORY.jsonl (recent events).

**Extension to `vault_registry.rs`**:

```rust
pub enum VaultId {
    Model(ModelId),
    Agent(AgentId),
    Team(TeamId),
    UseCase(String),
    Personal,
    // NEW:
    Soul,        // 4-file directory: SOUL/STYLE/SKILL/MEMORY
}

impl VaultRegistry {
    pub fn load_soul(&self) -> Result<ComposedSoul> {
        let soul = self.read_pair("SOUL")?;
        let style = self.read_pair("STYLE")?;
        let skill = self.read_pair("SKILL")?;
        let memory_log = self.read_jsonl("MEMORY.jsonl")?;    // last N events
        Ok(ComposedSoul { soul, style, skill, memory_log })
    }
}
```

The `ContextLoader` gains a `Soul` variant in its tier-4 source, replacing the single `SOUL.md` read with the composed read above. Backwards compatible: a vault with only `SOUL.md` (no `STYLE.md` etc.) loads with empty optional fields.

### 25.6 Port: Hermes 15-tool checkpoint → `AgentSession::run_scaffold_turn`

The Hermes moat (§24.5) — periodic self-evaluation every 15 tool calls — slots directly into the existing agent loop entry point.

**Extension to `agent_core/src/agent_loop.rs`**:

```rust
pub struct AgentConfig {
    pub effort: Effort,
    pub max_turns: u32,
    pub max_output_tokens: u32,
    pub permission_config: PermissionConfig,
    // NEW:
    pub self_eval_interval: u32,    // default 15
}

impl AgentSession {
    pub async fn run_scaffold_turn(&mut self, user_message: String) -> Result<AgentTurnResult> {
        let result = self.run_inner(user_message).await?;
        self.tool_calls_this_session += result.tool_calls_made;
        if self.tool_calls_this_session % self.cfg.self_eval_interval == 0
            && self.tool_calls_this_session > 0
        {
            let outcome = self.run_self_evaluation().await?;
            self.emit_event(AgentEvent::SelfEval(outcome));
        }
        Ok(result)
    }
}
```

The `AgentEvent` enum (already exposed via UniFFI as a stream) gains a `SelfEval(SelfEvalOutcome)` variant. Swift observers see checkpoint events on the same stream as normal turn events; the UI can surface a Layer-2 hint when a skill is proposed.

The self-eval tool call is itself grammar-bound: outcome is `improved | unchanged | skill_proposed | refactor_proposed`. Closed-enum, no fabricated outcomes.

### 25.7 Port: Letta tiered memory → `ContextLoader`'s existing 5 tiers (90% already there)

This is the most pleasant surprise of the codebase scan. **Letta's three tiers (Core / Recall / Archival) already exist in `context_loader.rs` as a 5-tier system**: L4 (SOUL.md / identity), L3 (facts), L2 (patterns/skills), L1 (episodes), L0 (working). The mapping:

| Letta tier | Epistemos `ContextLoader` tier | Notes |
|---|---|---|
| Core (RAM-like) | L4 + L0 | SOUL is permanent core; working set is volatile core |
| Recall (disk-cache-like) | L3 + L2 + L1 | facts, patterns, episodes — searchable but not always loaded |
| Archival (cold-storage) | (everything else in vault) | reachable via `vault.search`, never preloaded |

**Port: add explicit promote/demote tools** (the missing 10%):

```rust
// agent_core/src/tools/memory.rs (extension)
pub struct PromoteToCore;       // moves a fact from L3/L2/L1 → L4 (pinned)
pub struct DemoteToArchival;    // removes a fact from L4/L3/L2/L1 → archival (search-only)
pub struct SwapRecall;          // explicit recall slot management when budget tight
```

Each tool's input is `{entry_id: String, reason: String}`; output is `{tier_before: Tier, tier_after: Tier, applied: bool}`. The grammar bounds the transitions (no skipping tiers; no impossible transitions). The agent calls these tools when it decides a fact is becoming load-bearing or stale.

### 25.8 Port: GEPA + DSPy evolution → `heal_log` + `action_trace` as input

Phase 13 (§24.6) — GEPA-style evolution — consumes the existing observability data. Per §5.7, the heal-event SQLite already exists in the plan; per the codebase scan, `tracing` is already a dependency. So the inputs are at hand.

**New module `agent_core/src/evolution/gepa.rs`** (Phase 13):

```rust
pub struct GepaSession {
    pub heal_log: PathBuf,             // existing per §5.7
    pub action_trace: PathBuf,         // from §5.5
    pub corrections: PathBuf,          // user corrections (§3.6)
}

impl GepaSession {
    pub async fn run_weekly(&self) -> Result<Vec<Proposal>> {
        let traces = self.load_traces_window(Duration::from_days(7)).await?;
        let failures = traces.iter().filter(|t| t.failed());
        let improvements = self.dspy_optimize(&failures, &self.skill_library())?;
        Ok(improvements.into_iter().map(Proposal::from).collect())
    }
}

pub enum Proposal {
    PromptRevision { soul_path: PathBuf, before: String, after: String, expected_lift: f32 },
    SkillRevision  { skill_id: SkillId, slot_diffs: Vec<SlotDiff>, expected_lift: f32 },
    FewShotRevision { tool: ToolName, model: ModelId, exemplar_diffs: Vec<ExemplarDiff>, expected_lift: f32 },
}
```

Every `Proposal` flows back through the §17.2 mint pipeline before applying. User-confirmed always.

### 25.9 Port: Atropos trajectory export → new tool `meta.export_atropos`

Built on `meta` tool category. Reads the action trace + heal log + corrections, serializes to Atropos JSONL format. Tool already lives in §3.5's catalog as a meta operation; implementation is ~100 lines of serde wiring. Pro-only initially (export consumes considerable disk; bounded by user storage).

### 25.10 Port: OpenClaw multi-channel + sender-scoped permission → existing `ToolTier` + `RiskLevel`

Another delightful overlap with existing infrastructure. `agent_core/src/tools/registry.rs` already has:

- `ToolTier::{None, ChatLite, ChatPro, Agent, Full}` — capability tiers.
- `RiskLevel::{ReadOnly, Modification, Destructive}` — operation risk.

This *is* OpenClaw's permission model. The remaining work for Pro Phase H is to add a `(channel, sender)` axis:

```rust
pub struct PermissionScope {
    pub channel: ChannelId,       // imessage / telegram / cli / web
    pub sender: SenderId,         // owner / family / coworker / unknown
    pub allowed_tiers: BitSet<ToolTier>,
    pub allowed_risk: RiskLevel,
}

impl ToolRegistry {
    pub fn resolve_for_call(&self, name: &str, scope: &PermissionScope) -> Option<&RegisteredTool> {
        let tool = self.get(name)?;
        if !scope.allowed_tiers.contains(tool.tier) { return None; }
        if tool.risk_level > scope.allowed_risk { return None; }
        Some(tool)
    }
}
```

The Pro profile builds atop the existing tier+risk infrastructure; nothing breaks for App Store builds.

### 25.11 Port: CRANE + IterGen + Grammar-Aligned → `LocalToolGrammar.swift`

The Swift-side grammar already exists at `Epistemos/LocalAgent/LocalToolGrammar.swift`. The §22.1 trio extends it:

**Grammar-Aligned**: replace the existing mask-and-zero-out with mask-and-rescore (preserve top-k ordering on the valid subset). ~30 lines of Swift in `LocalToolGrammar.swift`.

**CRANE**: add sentinel-token region switching. The grammar emits `<think>` (single added Hermes token) → identity-mask region (free text up to N tokens) → `</think>` → strict answer grammar resumes. ~50 lines of grammar state-machine extension.

**IterGen**: new Rust module `agent_core/src/heal/itergen.rs` (already specified in §22.1.3); Swift calls it via UniFFI when the heal loop fires. The KV-snapshot management lives in MLX-Swift via the existing `MLXInferenceService.swift` — request the engine to snapshot after each `}` token (grammar-symbol boundary in JSON output), restore on backtrack. ~100 lines of Swift glue + 80 lines of Rust.

Total: ~260 lines of Swift + Rust to ship the entire §22.1 trio. The user's existing infrastructure absorbs ~80% of the work.

### 25.12 The brilliant hybrid — what makes Epistemos's composition truly novel

Now the synthesis. Each public moat in §24 ports onto one or two existing surfaces. **No public agent project does the composition because no public agent project has all eight surfaces in one process with zero-copy data flow.** That's the structural advantage:

```
HermesPromptBuilder.swift           ◄── tool-call format normalizer (§6.5) [DONE]
  + LocalToolGrammar.swift          ◄── sampler-bound dispatch (§17) + CRANE/IterGen/Aligned (§22.1)
  + MLXInferenceService.swift       ◄── zero-copy unified-memory inference [DONE]
                ▲
                │  via UniFFI (zero-copy owned values)
                ▼
ToolRegistry::resolve_for_call      ◄── permission scope (§24.10) [DONE infrastructure]
  → AgentSession::run_scaffold_turn ◄── 15-tool checkpoint (§24.5)
  → run_with_variants               ◄── variant ladder + cache (§3.2/§3.6)
  → mint pipeline (§17.2)            ◄── Compile-Verify-Mint
  → IntentApplier                    ◄── Intent→Effect (§8) [stream DONE]
                ▲
                │
                ▼
VaultStore + SpatialVault           ◄── MemPalace verbatim + Wing/Room/Hall (§24.2)
  + memory_classifier::MemType      ◄── Mercury 13-typed (§24.3)
  + SessionGraph                    ◄── Mem0 graph (§24.9) [DONE]
  + VaultRegistry::Soul             ◄── soul.md 4-file (§24.4)
  + ContextLoader 5-tier            ◄── Letta tiered (§24.8) [DONE infrastructure]
  + heal_log + action_trace         ◄── GEPA evolution input (§24.6)
  + corrections.jsonl               ◄── Atropos trajectory source (§24.7)
```

Every line touches existing code or extends an existing trait. **Nothing in the moat composition requires a new top-level subsystem.** That is the real engineering value of having built the substrate first.

The user's "zero-copy magic deterministic" expression is preserved end-to-end:

- **VaultFact's 384-dim embedding** moves through Tantivy → SessionGraph → MLX → grammar mask → tool dispatch without serialization.
- **Tool calls** crossing UniFFI carry typed enums (MemType, ToolTier, RiskLevel), not strings.
- **AgentEvent stream** flows from Rust to Swift with owned values; the `payload` is a typed enum, not a JSON string.
- **Generation buffers** (token IDs, KV cache, logit array) live in MLX's unified-memory pool; the constraint mask reads/writes in place.

### 25.13 Updated phase work — most phases are extensions, not new builds

The codebase scan changes the difficulty estimate of many phases:

| Phase | Original estimate | Revised estimate | Why |
|---|---|---|---|
| Phase 1 (formats) | 1 week | 4–5 days | `MemoryClassifier`, `VaultRegistry`, `vault.rs` already do most of this; we extend enums and add 4-file soul split |
| Phase 2 (registry/grammar) | 2–3 weeks | 1–2 weeks | `ToolRegistry` exists; we add `Tool` trait extensions and llguidance crate |
| Phase 3 (router) | 2 weeks | 7–10 days | `MemoryClassifier` + `SessionGraph` cover 70%; new work is variant ladder + spatial scope |
| Phase 4 (heal) | 1 week | 4–5 days | `tracing` already wired; new work is heal-loop module + breaker + IterGen |
| Phase 5 (skills) | 2 weeks | 1 week | Hermes prompt + LocalToolGrammar already in Swift; new work is Spotlight + Vision + Speech wrappers |
| Phase 6 (inference) | 2 weeks | 7–10 days | `MLXInferenceService` exists; new work is engine trait, MLX-Structured wiring, three-mechanism trio |
| Phase 7 (MWP) | 1 week | 5 days | `AgentSession` + `AgentEvent` stream exist; new work is filesystem-orchestrator + NightBrain |
| Phase 8 (Intent→Effect) | 1 week | 4 days | Async event stream already in UDL; new work is Intent enum + IntentApplier + universal undo |
| Phase 9 (UI) | 1 week | as planned | UI is genuinely new |

**Total estimate compresses from ~13 weeks to ~7–8 weeks** for phases 1–9. The substrate that already exists is the 5–6 weeks the user has already invested. Phases 11.5 / 12.5 / 13 (migration / skill discovery / evolution) are the same as planned — they're net-new.

### 25.14 The expression — Swift + Rust + UniFFI determinism in one paragraph

> A user's typed thought enters the captured surface (Swift). A typed `Capture` value crosses UniFFI as an owned struct. The Rust `MemoryClassifier` types it via grammar-bound LLM call (closed `MemType` enum) into a `VaultFact` whose 384-dim embedding lives in unified memory. The variant runner consults `ToolRegistry` for permission scope (existing tier+risk), runs the 4-variant routing ladder under a CRANE-shaped grammar, IterGen-recovers any field-level failures by editing only the failing span (KV-cache restored from the boundary snapshot), and emits a typed `Intent`. The Rust `IntentApplier` writes verbatim to the spatial vault (MemPalace-shaped Wing/Room/Hall/Drawer), updates the session graph (Mem0-shaped), and tier-promotes via `ContextLoader::promote_to_l4` if the entry is load-bearing (Letta-shaped). An owned `AgentEvent::EffectApplied(typed_payload)` flows back across UniFFI to the `@Observable` Swift store; SwiftUI re-renders. Every step's output schema is grammar-validated; every failure mode is bounded by retry budget; every action is reversible within 24h via the undo log. **Throughout: no serialization between layers, no copies of the embedding, no model output that escapes the grammar, no path that reaches cloud unless the user typed `/cloud`.** That is the deterministic Swift+Rust+UniFFI hybrid expression — the moat, ported, alive.

---

*End of plan. Begin Phase 0 by reading the disk references in §0.2 and running the web searches in §0.1 for Phase 1.*
