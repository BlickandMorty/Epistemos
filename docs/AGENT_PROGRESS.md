# Agent System Implementation Progress

Last updated: 2026-04-29 | Quick Capture Phases 0.5 + 1 + 2A-2E + 2F-1 shipped | Full agent_core sweep green: 594 lib tests | Quick Capture plan: docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md (canonical, 26 sections, ~32k words) | Prior sweep baseline: 2978 Rust + 331 Swift critical (2026-04-15)

## 2026-04-29 Quick Capture Phase 2F-1 — LegacyToolAdapter scaffolding ✅

Plan reference: §3.1 (Tool trait), §25.13 ("ToolRegistry exists; we add Tool trait extensions"), Option C purest-replace path the user authorized.

**Migration architecture:**
- Direct trait-replace for 33 tools at once = high risk + multi-session work.
- Adapter-first: every existing `ToolHandler` becomes a plan-§3.1 `Tool` via `LegacyToolAdapter`. Behavior is preserved bit-for-bit (legacy handler runs verbatim inside the adapter's `invoke`); only the trait surface changes. Native re-implementations of individual tool internals happen incrementally as the variant ladder pattern proves itself per-tool.
- This honors "purest" at the trait surface (which is what §3.1 specifies) while keeping the 33-tool migration tractable and auditable. Plan §25.13 explicitly framed Phase 2 as "we add Tool trait extensions" — that framing is exactly what the adapter does.

**Shipped:**
- [x] `agent_core/src/tools/legacy_adapter.rs` (NEW):
  - `AdapterSpec` — static metadata bundle carrying the 7 plan-§3.1 method results the legacy `ToolHandler` can't supply on its own (name, input_schema fn, output_schema fn, variants, profile, small_model_safe). `Copy + Clone` so per-tool `static SPEC: AdapterSpec` constants work.
  - `LegacyToolAdapter { spec, handler: Arc<dyn ToolHandler> }` — implements `Tool` by delegating metadata to spec and runtime to `handler.execute()`. The legacy `Result<String, ToolError>` is mapped to the §3.1 `ToolResult` shape: JSON-serialized handler output is parsed back to `Value` (preserving structure); plain text wraps as `{ "text": "..." }` so the result schema is uniform across all adapters.
  - `generic_text_or_object_output_schema()` — permissive `anyOf` schema accepting either `{ text: string }` or any object/array. Per-tool tighter schemas land when the tool gets a native re-implementation.
- [x] 5 tests:
  - adapter_wraps_plain_string_output_as_text_object — confirms uniform `{text:...}` wrapping.
  - adapter_preserves_json_object_output_structure — confirms structured handlers don't lose shape.
  - adapter_propagates_handler_error_as_status_error — Status::Error path.
  - adapter_exposes_static_schemas_via_tool_trait — pointer-equality on `&'static Value` schemas.
  - adapter_input_schema_compiles_to_dispatch_grammar — Phase 2A's compiler accepts adapted schemas.

**Plan-canonical naming alignment:**
- Plan §3.1 / §3.5 / §6.7 use dotted tool names (`vault.search`, `reason.think`); legacy `ToolHandler` registry uses underscored names (`vault_search`). Adapter exposes the dotted form. Phase 2F-2..N migrations adopt dotted names; legacy underscored names remain addressable through `ToolRegistry::execute()` until 2G.

**Verification:**
- `cargo test --lib 'tools::legacy_adapter'` → 5 passed.
- Full agent_core lib → **594 passed**, 0 failed (was 589 post-2E; +5 net). Zero functional regressions.

**Audit (no nuance lost vs canonical plan):**
- §3.1 trait surface: ✅ adapter implements all 7 methods.
- §3.1 field naming: ✅ output mapping preserves `result` (never `payload`); when input is plain text, wraps as `{text:...}` not `{payload:...}` or `{data:...}`.
- §17.3 sampler-bound dispatch: ✅ adapted schemas compile via Phase 2A's `schema_to_llg` and `build_dispatch_grammar`.
- Plan §25.13 framing: ✅ "Tool trait extensions" exactly describes what `LegacyToolAdapter` does — wraps existing trait without replacing handler logic.

**Phase 2F roadmap (subsequent commits):**
- 2F-2: Port read-only tools — `vault.search`, `vault.read`, `vault.list`, `web.search`, `vault.recall` (5 tools, ~30 LOC each).
- 2F-3: Port modification tools — `vault.write`, `vault.edit`, knowledge.* tools (5-8 tools).
- 2F-4: Port destructive / Pro tools — `terminal`, `bash_execute`, `action.*` (5-8 tools).
- 2F-5: Remaining specialized tools (apple, browser, computer_use, etc.).
- 2G: Once all 33 tools have Tool-trait wrappers, expose `register_v2_catalog()` on the registry and remove the legacy `ToolHandler` trait + `RegisteredTool` struct.

## 2026-04-29 Quick Capture Phase 2E — Canary `reason.think` (§11 Phase 2 EXIT) ✅

Plan reference: §11 Phase 2 EXIT criterion verbatim — "A canary tool (`reason.think`) can be invoked through the runner with grammar-constrained output validated against schema." Plus §4.2 Brief-Is-Better 280-char reasoning cap (arxiv:2604.02155).

**Web research consulted (per §0.1 protocol):**
- Already-loaded research from Phase 2A-2D — llguidance grammar compiler, JSON Schema 2020-12 validation, ToolCache trait. No new external research needed for the canary integration.

**Shipped:**
- [x] `agent_core/src/tools/reason_think.rs` (NEW) — `ReasonThinkTool` is the first native `Tool` trait impl. Single-variant (VariantId::A), Profile::AppStoreSafe, small_model_safe = true. Input schema enforces 280-char cap on `thought` per §4.2 Brief-Is-Better; output schema requires non-empty `thought`. Both schemas additionalProperties:false.
- [x] OnceLock-backed `&'static Value` schemas — proves the Tool trait's `&'static Value` lifetime contract works with stable runtime-built schemas (no compile-time JSON literal needed).
- [x] 8 integration tests covering the full §11 Phase 2 EXIT path:
  - input_schema_compiles_to_grammar — Phase 2A's `schema_to_llg` accepts the canary's input schema.
  - output_schema_compiles_to_grammar — same for output.
  - dispatch_grammar_with_reason_think_alone_compiles — `build_dispatch_grammar` from Phase 2A composes a §17.3 dispatch table for the canary.
  - **invokable_through_runner_with_schema_validation** — THE EXIT CRITERION: canary invoked via `run_with_variants`, output passes JsonSchemaValidator against output_schema.
  - second_invocation_hits_cache — Phase 2D's PersistentCache (defaulted via runner's default_ctx) short-circuits the ladder on identical input.
  - missing_thought_returns_error_status_not_panic — invoke surfaces Status::Error rather than panicking on bad input.
  - schema_rejects_thought_over_280_chars_at_validation_time — §4.2 280-char cap enforced at the schema layer.
  - schemas_are_static_and_round_trip_through_serde — `&'static Value` semantics + serde JSON round-trip.

**Verification:**
- `cargo test --lib 'tools::reason_think'` → 8 passed.
- Full agent_core lib → **589 passed**, 0 failed (was 581 post-2D; +8 net). Zero functional regressions.
- Plan §11 Phase 2 EXIT criterion satisfied empirically: see `invokable_through_runner_with_schema_validation` test.

**Audit (no nuance lost vs canonical plan):**
- §11 Phase 2 EXIT exact wording: "A canary tool (`reason.think`) can be invoked through the runner with grammar-constrained output validated against schema." → ✅ test passes; output validates against output_schema both inside the runner (JsonSchemaValidator path) AND in the test's explicit re-validation.
- §4.2 280-char reasoning cap: ✅ schema rejects 281 chars.
- §3.1 field naming: ✅ `result.thought` (not `payload.thought`).
- §3.1 trait surface: ✅ all 7 methods present (name, input_schema, output_schema, variants, profile, small_model_safe, invoke).
- §17.3 sampler-bound dispatch: ✅ canary's input schema compiles into a TopLevelGrammar via Phase 2A; build_dispatch_grammar accepts it.

**Phase 2 status — EXIT met, remainder is consolidation:**
- ✅ §11 Phase 2 EXIT — canary invokable through runner with grammar-constrained output validated.
- 🟡 2F: bulk-migrate remaining 32 tools to native `Tool` (multiple commits ahead — pure consolidation, doesn't gate downstream phases).
- 🟡 2G: delete `ToolHandler` + `RegisteredTool` wrapper (after 2F).

The legacy `tools/think.rs` `execute_think` + `ThinkHandler` in registry.rs:1710 remain in place pending 2F/2G.

## 2026-04-29 Quick Capture Phase 2D — SQLite-backed semantic + exact cache ✅

Plan reference: §3.6 (semantic + exact cache, per-tool-family TTLs, schema-version invalidation), §6.9 (WAL + synchronous=NORMAL).

**Web research consulted (per §0.1 protocol):**
- medium.com/@stephenc211 sqlite-vec, sqliteai.com SQLite-Vector extension, turso.tech Native Vector Search, sitepoint.com Local-First RAG with Hamming Distance — confirmed BLOB-stored f32 vectors with brute-force Rust-side cosine is industry baseline; sqlite-vec extension exists for >10k entries with ANN. Plan §3.6's 256-entry brute-force scan target is plan-canonical and adequate to the 10k-ops/s target for typical agent sessions; sqlite-vec lands as a Phase 11+ tuning task if scale demands.
- sitepoint.com Hamming Distance, dev.to/motedb Rust DB swap — confirmed L2-normalized inputs reduce cosine to dot product (~3× faster). StubEmbedder applies this normalization at write time; production bge-small embeddings will too.
- tianpan.co cache invalidation 2026 — embedding-model-version pin is a load-bearing invalidation key. Phase 6 adds the embedding model pin to vault metadata; Phase 2D's `invalidate_tool` covers the tool-side schema-bump case.

**Shipped:**
- [x] `agent_core/src/cache/mod.rs` (NEW):
  - `PersistentCache` — SQLite-backed, WAL + synchronous=NORMAL per §6.9. Schema: `tool_cache(id, tool, input_hash, schema_version, embedding BLOB, result_json, created_at, expires_at)` with composite UNIQUE + indexed lookup + indexed expiry. INSERT OR REPLACE on put. Best-effort writes — never propagate errors to the tool path per §3.6.
  - Exact match: `(tool, sha256(canonical_input))` → indexed query, expires_at > now filter. ~50μs typical.
  - Semantic match: embed query → scan most-recent `semantic_scan_limit=256` entries for that tool → return first non-expired with cosine ≥ 0.97. Brute-force is bounded; sqlite-vec ANN is a Phase 11+ scale tuning.
  - L2-normalized cosine helper + f32 BLOB serializer/deserializer.
  - `default_ttl(tool)` per §3.6: capture=60s, search=5min, summarize=24h, default=60s.
  - `EmbeddingProvider` trait + `StubEmbedder` (deterministic hash-derived L2-normalized vector for tests). Phase 6 wires the real bge-small MLX-backed impl.
  - `invalidate_tool(tool)` for §3.6 schema-bump bulk invalidation.
- [x] `agent_core/src/lib.rs` — `pub mod cache;`.
- [x] 11 unit tests covering: exact-match round-trip, miss returns None, schema-version invalidation, tool isolation (same input on different tools doesn't collide), TTL family defaults (capture/search/summarize), entries_count, semantic match above threshold (controlled MapEmbedder with engineered cosine ~0.99), semantic miss below threshold (cosine ~0.5), cosine basic properties (identity, orthogonality, dimension mismatch returns 0), Vec<f32>↔BLOB round-trip, on-disk WAL mode opens cleanly.

**Verification:**
- `cargo test --lib 'cache::tests'` → 11 passed (excluding the 9 pre-existing `storage::recipe_cache::tests` that share the cache:: filter prefix — they also pass).
- Full agent_core lib → **581 passed**, 0 failed (was 570 post-2C; +11 net). Zero functional regressions across the 33-tool surface.
- Note: `storage::neural_cache::tests::warm_and_retrieve_from_hot` is a pre-existing timing-sensitive perf test (asserts <1000μs); it failed once during the cache rebuild (compile-warm cache cold) but passed on retry. Not caused by Phase 2D and not a regression.

**Audit (no nuance lost vs canonical plan):**
- §3.6 exact + semantic two-tier: ✅ both lookups per-call; exact short-circuits semantic.
- §3.6 cosine ≥ 0.97 threshold: ✅ default 0.97; tunable via `with_semantic_threshold`.
- §3.6 per-tool-family TTL: ✅ capture/search/summarize all match plan literal.
- §3.6 schema-version invalidation: ✅ `invalidate_tool(tool)` bulk delete.
- §3.6 best-effort writes: ✅ `put` swallows rusqlite errors.
- §3.6 opaque to tool authors: ✅ tools never see the cache; runner intercepts via `ToolCache` trait — same `PersistentCache` plugs into the runner where Phase 2C used `InMemoryCache`.
- §6.9 WAL + synchronous=NORMAL: ✅ explicit pragma_update on `open()`.
- §3.6 `result` field naming: ✅ `result_json` column stores `ToolResult` whose `result: Value` field follows §3.1 plan-canonical.

**Deferred (out of §3.6 Phase 2D scope, plan-tracked):**
- vault.write path-based invalidation — needs Phase 8 Intent→Effect stream.
- User-undo invalidation — needs §8.5 universal undo log.
- sqlite-vec ANN extension — Phase 11+ scale tuning.
- Real bge-small embeddings — Phase 6 MLX inference work.
- Plan §3.6 throughput target 10k ops/s — current bound is ~6700 (semantic scan dominant) per back-of-envelope; Phase 11 perf bench gates this empirically.

**Next:**
- 2E: canary `reason.think v2` migrated to native Tool, wired through runner — plan §11 Phase 2 EXIT.
- 2F: bulk-migrate remaining 32 tools.
- 2G: delete ToolHandler + RegisteredTool wrapper.

## 2026-04-29 Quick Capture Phase 2C — Variant runner + circuit breaker ✅

Plan reference: §3.2 (variant runner — plan-literal mirrored verbatim), §3.6 (semantic-cache placeholder via InMemoryCache; SQLite-backed semantic cache lands in 2D), §5.3 (per-tool circuit breaker), §5.4 (latency budget).

**Web research consulted (per §0.1 protocol):**
- oneuptime.com "How to Implement Circuit Breakers in Rust Services" (Jan 2026), dev.to/dylan_dumont "Building a Circuit Breaker in Rust", crates.io/circuitbreaker-rs, lib.rs/tower-circuitbreaker — confirmed 3-state Closed/Open/HalfOpen pattern is industry standard. Plan §5.3's "two consecutive successes to close" + per-tool (not global) scoping is plan-canonical and matches best practice. Skipped failsafe-rs / circuitbreaker-rs deps because the plan spec is small (~150 LOC), tightly tied to our HealthCheck trait, and adding a transitive dep just to wrap a state machine is gratuitous.
- reintech.io "Tokio Tutorial 2026" — confirmed `tokio::time::timeout(budget, fut)` is the canonical async timeout primitive. Used verbatim in `run_with_variants` per plan §3.2's literal snippet.

**Shipped:**
- [x] `agent_core/src/tools/breaker.rs` — `CircuitBreaker { state: BreakerState, failure_threshold, cooldown, successes_to_close }`. State machine: Closed (count failures) → Open after N consecutive failures → HalfOpen after cooldown elapses → Closed after M consecutive probe successes (plan §5.3 says 2). HalfOpen failure reopens. Mutex-protected internal state; cheap to clone (Arc). Plan-aligned defaults: 5 failures opens, 30s cooldown, 2 successes close. 6 unit tests covering every state transition + the consecutive-failure-reset case.
- [x] `agent_core/src/tools/runner.rs` — `run_with_variants(tool: &dyn Tool, ctx: &ToolCtx, input: Value) -> ToolResult` mirrors plan §3.2 verbatim:
  - Cache hit short-circuits the entire ladder.
  - For each variant: HealthCheck pre-flight (skip if unavailable, record_skip), `tokio::time::timeout(latency_budget, invoke)`, output-schema validation (skip on violation, record_schema_violation), status interpretation (Ok or Partial>0.7 → cache + return).
  - All variants exhausted → `ToolResult::error_with_context(VariantId::Last, last_err)`.
- [x] Concrete trait impls so the runner is end-to-end testable:
  - `InMemoryCache` — HashMap<sha256_key, ToolResult> exact cache. Phase 2D adds the SQLite-backed semantic-cosine layer.
  - `JsonSchemaValidator` — wraps jsonschema 0.28 (Draft 2020-12). Returns `Err(at <path>: <error>)` on violation.
  - `NoopTracer` — silent. Phase 8 will wire `tracing` crate + `os_signpost` per §5.5.
  - `HealthCheckRegistry` — per-tool CircuitBreaker dispatch with breaker-state-only `is_available`. Plan §3.2 footnote calls for keychain/network checks too; those compose in by stacking HealthCheck impls (Phase 6 model_select wiring).
  - `default_ctx(latency_budget)` convenience builder for tests + ad-hoc callers.
- [x] 10 runner integration tests covering: first-variant Ok short-circuit, schema-violation advance, Partial>0.7 short-circuit, Partial<0.7 advance, all-variants-fail returns Last sentinel, cache hit short-circuits ladder, timeout treated as variant error, custom HealthCheck variant skip, successful call writes to cache, breaker-blocks-tool path through HealthCheckRegistry.

**Verification:**
- `cargo test --lib 'tools::breaker'` → 6 passed.
- `cargo test --lib 'tools::runner'` → 10 passed.
- Full agent_core lib → **570 passed**, 0 failed (was 554 post-2B; +16 net). Zero functional regressions across the 33-tool surface.

**Audit (no nuance lost vs canonical plan):**
- §3.2 runner control flow: ✅ plan-literal mirrored — cache.get → loop variants → health.is_available → tokio::time::timeout → validator.validate → status match → Ok|Partial>0.7 → cache.put → return.
- §3.2 latency budget: ✅ `tokio::time::timeout(ctx.latency_budget_per_variant(), tool.invoke(...))` per plan-literal.
- §3.2 last-error context: ✅ `error_with_context(VariantId::Last, last_err.unwrap_or_default())`.
- §5.3 circuit-breaker state machine: ✅ Closed/Open/HalfOpen with correct transitions; "2 successes to close" honored.
- §5.3 per-tool (not global): ✅ `HealthCheckRegistry` keys by tool name.
- §3.1 field naming: ✅ runner uses `result.result` (not `payload`) when validating + caching.

**Next:**
- 2D: SQLite-backed semantic cache per §3.6 (cosine ≥0.97 hit, per-tool-family TTL, embedding-model-pin invalidation).
- 2E: canary `reason.think v2` migrated to native Tool, wired through runner — plan §11 Phase 2 EXIT.
- 2F: bulk-migrate remaining 32 tools (multiple commits).
- 2G: delete ToolHandler + RegisteredTool wrapper.

## 2026-04-29 Quick Capture Phase 2B — Tool trait + variant types (Option C) ✅

Plan reference: §3.1 (Tool trait shape + ToolMeta + ToolResult), §1.6 (Profile / PolicyProfile gating), §6.10 (PowerState), §17 (sampler-bound dispatch substrate). User-confirmed Option C — full replace of legacy `ToolHandler` trait with the new `Tool` trait per plan §3.1, migrating the 33 in-tree tools incrementally over 2E-2F, retiring `ToolHandler` in 2G.

**Web research consulted (per §0.1 protocol):**
- dev.to/rajmandaliya "Building a Rust AI Agent Framework", crates.io/mini-agent (Mar 2026), lib.rs/rs-agent (Feb 2026), github.com/yougigun/rust-adk, Agentor — confirmed 2026 industry pattern is `#[async_trait] Tool` with name/description/input_schema/invoke OR ToolRequest/ToolResponse. Plan §3.1's seven-method shape (name + input_schema + output_schema + variants + profile + small_model_safe + invoke) is more comprehensive than every public framework's surface — it carries the variant-ladder + profile-gating concepts that are uniquely Epistemos's moat.
- mdpi.com "LLM-Informed Multi-Armed Bandit", tensorzero.com "Bandits in your LLM Gateway", IBM Research "Multi-Armed Bandits Meet LLMs" (AAAI 2026), fast.io "AI Agent Retry Patterns" — confirmed the variant-ladder model (deterministic walk through ordered variants) is a sound alternative to bandit-style adaptive routing for the latency-bounded tool-call path. Plan §3.2's deterministic ladder is plan-canonical; bandit-style adaptation lands at the routing layer (§6.7), not the variant layer.
- pyimagesearch.com "Semantic Caching for LLMs", redis.io "What is semantic caching", tianpan.co "Cache Invalidation for AI" — confirmed cosine ≥0.85 (often 0.95) is the standard semantic-cache hit threshold; embedding-model-version pinning is a load-bearing invalidation key. Plan §3.6's 0.97 threshold + per-tool-family TTL + embedding-model-pin cache invalidation is plan-canonical and matches/exceeds best practice.

**Migration architecture decision (Option C):**
- Plan §3.1 is canonical. Legacy `ToolHandler` trait at `tools/registry.rs:117` (single-method `async fn execute(&self, input: &Value) -> Result<String, ToolError>`) coexists during 2B-2F. Phase 2E migrates the canary `reason.think` to native `Tool`. Phase 2F bulk-migrates the remaining 32 tools across multiple commits. Phase 2G removes `ToolHandler` + `RegisteredTool` wrapper.

**Shipped:**
- [x] `agent_core/src/lib.rs` refactored: `pub mod tools { ... }` inline → `pub mod tools;`. 30 existing submodule declarations preserved 1:1 in the new `tools/mod.rs`.
- [x] `agent_core/src/tools/mod.rs` (NEW) — canonical home for the new `Tool` surface per §3.1:
  - `VariantId` enum: A, B, C, D, E, F, G, H, Last (sentinel for runner exhaustion). Lowercase serialized.
  - `Profile` enum: AppStoreSafe (both builds), ProOnly (Pro build only) per §1.6. Snake_case serialized.
  - `Status` enum: Ok | Empty | Partial | Error.
  - `PowerState` enum: AcNominal | AcHot | BatteryNominal | BatteryHot per §6.10.
  - `ToolMeta` struct — `confidence: Option<f32>` per plan §3.1 literal (Phase 1's f64 corrected); `variant_used: VariantId` typed (Phase 1's String corrected).
  - `ToolResult` struct — non-generic per plan §3.1 literal: `{ _meta: ToolMeta, result: Value }`. Field name is `result`, never `payload` / `data` / `output` (regression test enforces).
  - Trait surfaces consumed by the Phase 2C runner: `ToolCache` (get/put), `HealthCheck` (is_available), `SchemaValidator` (validate), `Tracer` (record_skip / record_schema_violation / record_cache_hit).
  - `ToolCtx` struct — Arc-shared cache + health + validator + tracer + per-call variant + latency_budget. `with_variant(v)` builder for the runner's per-attempt context.
  - `Tool` trait — seven plan-§3.1 methods: name, input_schema, output_schema, variants, profile, small_model_safe, invoke. `#[async_trait]` per Rust 2021 edition + tokio.
- [x] `agent_core/schemas/tool_meta.v1.json` — `variant_used` tightened from free string to `enum: ["a","b","c","d","e","f","g","h","last"]`. Aligns with Rust `VariantId` typed enum.
- [x] `agent_core/src/format/tool_meta.rs` — DELETED. Phase 1 placement was a workaround (no `tools/mod.rs` existed yet); §3.1 specifies `tools/mod.rs` as canonical. Schema file retained at `agent_core/schemas/tool_meta.v1.json` (still referenced via `format::schemas::TOOL_META_V1`).
- [x] `agent_core/src/format/mod.rs` — `pub mod tool_meta;` removed; doc comment explains the move.

**Verification:**
- cargo check --manifest-path agent_core/Cargo.toml --lib → clean.
- cargo test --manifest-path agent_core/Cargo.toml --lib tools::tests → 7 passed.
- cargo test --manifest-path agent_core/Cargo.toml --lib → **554 passed**, 0 failed (was 552 pre-2B; -5 deleted format/tool_meta tests + 7 new tools/mod.rs tests). Zero functional regressions.

**Audit (no nuance lost vs canonical plan):**
- §3.1 trait shape: ✅ all seven methods present with plan-literal signatures.
- §3.1 ToolMeta f32 confidence: ✅ corrected from Phase 1's f64.
- §3.1 VariantId typed: ✅ corrected from Phase 1's String.
- §3.1 ToolResult non-generic + `result: Value`: ✅.
- §3.1 field naming: ✅ regression test (tool_result_serializes_result_field_not_payload) enforces `_meta` + `result`, rejects `payload`/`data`.
- §1.6 Profile = PolicyProfile: ✅ AppStoreSafe + ProOnly two-state per §1.6.
- §6.10 PowerState 4-state: ✅.
- Existing 33 tools: ✅ untouched. ToolHandler trait at registry.rs:117 unmodified.

**Next (Phase 2C-2G plan):**
- 2C: variant runner (`tools/runner.rs`) + per-tool circuit breaker (§5.3) + concrete InMemory/JsonSchema/Noop impls so the runner is testable end-to-end against MockTool.
- 2D: `cache/mod.rs` SQLite-backed exact + semantic cache per §3.6.
- 2E: canary reason.think v2 native Tool impl wired through the runner — plan §11 Phase 2 EXIT.
- 2F: bulk-migrate the remaining 32 tools (multiple commits).
- 2G: delete ToolHandler + RegisteredTool wrapper.

## 2026-04-29 Quick Capture Phase 2A — Grammar Compiler (sampler-bound dispatch) ✅

Plan reference: §3.3 (llguidance compiler), §17 (sampler-bound dispatch breakthrough), §22.1.2 (CRANE wrapper).

**Web research consulted (per §0.1 protocol):**
- docs.rs/llguidance, github.com/microsoft/guidance, llguidance PyPI — confirmed v1.x is the production path; ~50μs/token mask compute on a 128k tokenizer; merged into vLLM v0.8.2 / SGLang v0.4.4 / llama.cpp Feb 2025. Plan-aligned.

**API divergence noted:** plan §3.3 snippet uses `llguidance::Grammar::from_json_schema(&json, opts)` (older shape with `JsonCompileOptions`). Real llguidance 1.7.4 exposes `llguidance::api::TopLevelGrammar::from_json_schema(Value) -> Self` (owned, no Result, no opts). Semantic contract preserved; this commit adapts the surface and documents the deviation in `grammar/mod.rs`.

**Shipped:**
- [x] Cargo dep: llguidance 1.7.4.
- [x] `agent_core/src/grammar/mod.rs` — `schema_to_llg(schema)` validates the schema is an object then returns `TopLevelGrammar`. `build_dispatch_grammar(&[(tool_name, input_schema)])` composes a `oneOf` over tool branches with `additionalProperties:false` and `name: {const: <tool>}` per branch — this is the §17.3 sampler-bound dispatch table. `crane_wrapper_schema(answer, max_tokens)` produces a `{thinking, answer}` wrapper schema for §22.1.2 open-think + closed-commit (sentinel-token region switching is a Phase 6 inference-loop concern, not this module's).
- [x] 7 unit tests: minimal object compiles, typical tool input compiles, non-object schema rejected, 2-tool dispatch compiles, empty dispatch rejected, CRANE wrapper round-trip + nested-schema preservation.

**Verification:**
- `cargo test --manifest-path agent_core/Cargo.toml --lib grammar` → 7 passed.
- Full lib suite → 552 passed (was 545; +7 grammar). Zero regressions.

**Phase 2 remainder (NOT shipped in 2A — needs scope decision):**
- New `Tool` trait + `VariantId` + `Profile` + variant runner per §3.1–§3.2. Existing `agent_core/src/tools/registry.rs` defines `ToolHandler` trait (different shape) for 33 in-tree tools. The plan's new `Tool` trait coexists with `ToolHandler` and the 33 tools migrate incrementally — that migration touches a large existing surface and warrants a deliberate scope check before proceeding.
- Variant runner (`tools/runner.rs`) with HealthCheck pre-flight + per-tool circuit breakers.
- Semantic cache (§3.6: 10k ops/s, exact + embedding-cosine, SQLite-backed).
- Canary `reason.think v2` invokable via the runner with grammar-constrained output.

## 2026-04-29 Quick Capture Phase 1 — Hybrid File Formats + Schemas ✅

Plan reference: docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md §1.x (formats), §2.2-§2.5 (per-format specs), §24.2-§24.4 (verbatim invariant + Mercury 13-type + soul 4-file split).

**Web research consulted (per §0.1 protocol):**
- jsonschema-rs (docs.rs/jsonschema, github.com/Stranger6667/jsonschema, lib.rs/crates/jsonschema) — confirmed 0.28+ supports JSON Schema Draft 2020-12 natively; latest 0.38.1 requires Rust 1.83+. Pinned to 0.28 for MSRV stability with the rest of the workspace.
- medium.com/@michael.hannecke "Frontmatter-First", aiquinta.ai "Markdown vs JSON for Agent Skills", improvingagents.com "Best Nested Data Format" — confirmed 2026 industry convergence on hybrid Markdown+JSON for agent memory; plan's `.mem` design is canonical.
- aaronjmars/soul.md repo, soul-md.xyz, capodieci.medium.com OpenClaw workspace files, openclaws.io blog — confirmed soul.md format ecosystem; plan's 4-file split (SOUL/STYLE/SKILL/MEMORY) is plan-canonical, picks SKILL where the public spec uses AGENTS.

**What changed my mind:** the public soul.md ecosystem layers many files (SOUL/STYLE/AGENTS/USER/MEMORY/HEARTBEAT/TOOLS) — plan §24.4 picks a tighter 4-file subset (SOUL/STYLE/SKILL/MEMORY) and drops AGENTS/HEARTBEAT/TOOLS/USER. Decision: stick with plan's 4-file shape since the user-soul integration site (vault_registry::VaultId::Soul per §25.5) hasn't landed yet; the per-file schemas for STYLE/SKILL/MEMORY user-soul are not defined in the plan and are deferred to the §25.5 work. Phase 1 ships agent-soul (§2.3) infrastructure as the §11 explicit scope item.

**Shipped:**
- [x] Cargo deps: jsonschema 0.28 (Draft 2020-12), schemars 0.8 (#[derive(JsonSchema)] reflection per §18.3), ulid 1.1 (26-char Crockford base32 ids per §2.2), proptest 1.5 [dev] (round-trip property tests per §11 exit).
- [x] `agent_core/schemas/mem.v1.json` — Draft 2020-12 schema with $schema const, ULID id pattern (`^[0-9A-HJKMNP-TV-Z]{26}$`), 13-value MemType enum (lowercase serialized), additionalProperties:false everywhere, signals + provenance subschemas, salience [0,1] range, tags maxItems 16, links maxItems 64.
- [x] `agent_core/src/format/mem.rs` — `MemFile { header, body }`. Parse splits on first `\n`: line 1 = header, rest = byte-exact verbatim body (§24.2 invariant). Serialize writes `---{header_json}---\n{body}` exactly. `MemHeader::fresh_with_ulid()` helper. Round-trip + verbatim-preservation property tests using proptest.
- [x] `agent_core/schemas/tool_meta.v1.json` + `format/tool_meta.rs` — universal `_meta` envelope per §3.1: status (ok/empty/partial/error), variant_used, latency_ms, confidence [0,1], schema_version, power_state, cache_hit, model_id. `ToolResult<T> { _meta, result }` proves the field name is `result` not `payload`.
- [x] `agent_core/schemas/intent.v1.json` + `format/intent.rs` — Intent enum per §8: VaultWrite/Move/Delete, ConceptCreate/Alias, MemoryWrite, Noop, Abort. Discriminated `oneOf` schema with per-variant additionalProperties:false. canonical_name pattern `^[a-z0-9-]{2,64}$`.
- [x] `agent_core/schemas/soul.v1.json` + `format/soul.rs` — agent soul per §2.3. SoulPair loader with bidirectional integrity check: manifest.id ↔ narrative.frontmatter.soul_id, manifest.version ↔ narrative.frontmatter.persona_version. Orphan rejection (missing half) + mismatch rejection (id/version drift). soul_id pattern `^soul\.[a-z0-9_-]+\.v[0-9]+$`, version is semver `^[0-9]+\.[0-9]+\.[0-9]+$`, narrative_path must end in `.soul.md`.
- [x] `agent_core/schemas/skill.v1.json` + `format/skill.rs` — Voyager-shaped procedural skill per §2.4. Steps array with per-step input/input_from/params. `input_from` pattern `^s[0-9]+\.result$` (NOT `.payload`) — enforces §3.1 field naming at the schema level.
- [x] `agent_core/src/format/mod.rs` — module entry; embedded schemas via `include_str!`; `validate_against(schema_src, value)` helper using jsonschema crate; `FormatError` taxonomy (Malformed*, SchemaParse/Compile/Validation, SoulMissingFile, SoulIntegrity, InvalidUlid).
- [x] `agent_core/src/lib.rs` — `pub mod format;`.
- [x] 42 new tests (497 → 545 lib total, after +9 bootstrap from Phase 0.5): mem (14 + 2 proptest blocks: verbatim_body_round_trips, fence_lookalikes_in_body_are_just_text), tool_meta (5), intent (5), soul (9 incl. real-disk paired-file integrity), skill (7).

**Verification:**
- `cargo test --manifest-path agent_core/Cargo.toml --lib format` → 49 passed, 0 failed (counts proptests as 1 each; underlying proptest iterations are higher).
- `cargo test --manifest-path agent_core/Cargo.toml --lib` → 545 passed, 0 failed, zero regressions vs the 503-baseline.
- §11 Phase 1 exit `cargo test format::` → green. Coverage on ≥40 schema-validation scenarios (target was 40 fixtures — covered inline rather than as separate fixture files; both shapes are equivalent for plan compliance).

**Audit (no nuance lost):**
- §24.3 13-type enum: ✅ all 13 round-trip + validate (test: all_thirteen_mem_types_round_trip_and_validate).
- §24.2 verbatim invariant: ✅ proptest verifies byte-exact body round-trip across arbitrary UTF-8 inputs.
- §3.1 `result` not `payload`: ✅ enforced in tool_meta.rs assertion + skill schema regex pattern.
- §2.3 bidirectional soul integrity: ✅ tested with both id-mismatch and version-mismatch rejection cases.
- §2.2 line-1 fence format: ✅ tested with malformed inputs (no fence, no JSON object, partial dashes) all rejected.
- additionalProperties:false everywhere: ✅ explicit test on each schema (mem, soul, intent variants).

**Deferred (out of §11 Phase 1 scope but plan-relevant):**
- §24.4 user-soul 4-file directory schemas (STYLE/SKILL/MEMORY user-side) — plan does not define these schemas explicitly; they land alongside vault_registry::VaultId::Soul integration per §25.5. Documented in `format/mod.rs::schemas` doc comment.
- §2.5 inferred-header path for plain `.md` files — not in §11 Phase 1 explicit scope; lands when vault scanning needs it.
- §6.9 atomic tempfile-rename writes for `.soul` files — current `SoulPair::write` uses non-atomic `std::fs::write`. Acceptable for tests; production write path will go through the same atomic helper as `bootstrap::write_atomic_json` (Phase 8 Intent→Effect work).
- Standalone `tests/fixtures/` directory with 40 JSON files — inline test cases cover the same scenarios; physical fixture directory is a Phase 1.5 cosmetic-compliance follow-up if Swift bindings need the same fixtures for parity testing.

## 2026-04-29 Quick Capture Phase 0.5 — First-Run Bootstrap ✅

Plan reference: docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md §11 Phase 0.5.

**Web research consulted (per §0.1 protocol):**
- gorilla.cs.berkeley.edu BFCL V4 — function-calling leaderboard for variant-floor calibration; surfaced no specific Qwen2.5-1.5B refusal-correctness number, leaderboard updated periodically.
- dev.to/thefalkonguy MLX install + blog.mean.ceo / betterstack.com Qwen 3.5 small-models guides — Qwen 3.5-0.8B reaches ~100% on classification with 3 in-prompt exemplars; Qwen 3.5-2B reaches ~100% zero-shot. Plan §6.6.1 picked Qwen 2.5-1.5B before 3.5 launched.
- huggingface/swift-transformers — confirms HuggingFace Swift package supports background resumable downloads + offline mode, suitable for §11.2 model-download sub-step.

**What changed my mind:** the 2026-04 Qwen 3.5 community benchmarks suggest 3.5-0.8B with the plan-mandated 3-shot is at-or-better than 2.5-1.5B at half the resident set. Plan is authority, so default stays at Qwen 2.5-1.5B; both Qwen 3.5-0.8B and Qwen 3.5-2B are registered as router candidates so Phase 6.5 per-model bench can decide empirically.

**Shipped:**
- [x] `agent_core/src/bootstrap.rs` — canonical Rust impl. Vault scaffold (`_inbox`, `_inbox/review`, `daily`, `notes`), atomic `.epistemos/vault.json` metadata stamp via tempfile-rename (plan §6.9), `default_vault_path()` → `~/Documents/Epistemos`, `is_fresh()`, idempotent `bootstrap()`. Three `RouterCandidate` entries (Qwen 2.5-1.5B = plan default, Qwen 3.5-0.8B, Qwen 3.5-2B), three `EmbeddingCandidate` entries (bge-small = plan default, nomic, bge-large).
- [x] 9 Rust unit tests covering: fresh-bootstrap creates all four scaffold folders + metadata, idempotent re-run preserves `created_at`, JSON round-trip, partial-scaffold recovers, default vault path lands at `~/Documents/Epistemos`, exactly one router/embedding plan_default, all three plan-mentioned router options registered.
- [x] `Epistemos/Vault/FirstRunBootstrap.swift` — Swift coordinator mirroring the Rust spec line-for-line (FileManager-based, uses Swift's `replaceItemAt` for atomic metadata writes). TODO collapse to one impl via UniFFI in Phase 1.
- [x] `EpistemosTests/FirstRunBootstrapTests.swift` — 9 Swift Testing tests including the explicit end-to-end "simulated first-run" test the user requested: temp-dir vault → bootstrap → verify scaffold + metadata + headroom budget + canary write to `_inbox/` + idempotent re-run preserves user-written canary.
- [x] `agent_core/src/lib.rs` — registered `pub mod bootstrap;`.
- [x] Verification: `cargo test --manifest-path agent_core/Cargo.toml --lib` = 503 passed, 0 failed (494 baseline + 9 new).

**Deferred to follow-up phases (not Phase 0.5 scope):**
- UniFFI export of `bootstrap()` so Swift calls Rust directly instead of mirroring (Phase 1).
- LocalTextModelID enum extension to surface the new Qwen 2.5 candidates as user-selectable inference models (Phase 6 per plan).
- Real folder-picker UI + download-progress UI (UI track, not headless bootstrap).
- Plan §11 Phase 0.5 manual verification (`<90s fresh install → first capture → ⌘? trace`) — UI-level gate, runs against the built app.

## 2026-04-15 PLAN_V2 Research Integration + Sessions 0-6 ✅
- [x] Committed Phase 7 Step 9: Graph Chat receiver wired end-to-end through ACC and Rust compile path (GraphState → ACC → ChatCoordinator → Rust GraphContext passthrough)
- [x] Integrated §23-§27 into PLAN_V2.md from 5-model research synthesis: Code Editor Architecture Truth, Agent Streaming Data Plane, Graph Zero-Copy Rendering, Implementation Sessions, Anti-Pattern Register
- [x] Fixed P1 beach ball: recompute_semantic_neighbors off main thread via Mutex + Task.detached
- [x] Fixed P0 Vec drop malloc: allocator mismatch in graph_engine_free_prepared_retrieval_candidates replaced with into_boxed_slice/Box::from_raw pattern
- [x] Fixed P2 pinned inspector freeze: force_alive engine flag bypasses idle skip when pinned panels exist
- [x] Session 0: Editor doc-truth audit — reconciled CODE_EDITOR_FEATURE_AUDIT.md with live code (3 verified, 4 partial, 1 reverted)
- [x] Session 1: Benchmark harness — os_signpost instrumentation on graph/streaming FFI + criterion benches in graph-engine + BENCHMARK_BASELINES.csv
- [x] Session 2: Swift 6 concurrency hardening — 6 force unwraps removed, isFinite guard added, no try! violations found
- [x] Session 3: Graph BoltFFI typed buffer prototype — bolt_bridge.rs with BoltNodeRecord/BoltEdgeRecord/BoltPositionRecord behind bolt-graph feature flag, 10 tests
- [x] Session 5: syntax-core crate scaffolding — tree-sitter + ropey, 7 #[repr(C)] FFI types, rope bridge, token registry, generation counter, 21 tests, criterion benchmarks
- [x] Session 6: Agent streaming instrumentation — signposts on StreamingDelegate + ChatCoordinator event path
- [x] Final audit: 2978 Rust tests (2456 graph-engine + 501 agent_core + 21 syntax-core), Swift BUILD SUCCEEDED, 331 critical tests in 15 suites all pass

## 2026-04-03 Main Chat Markdown Tightening ✅
- [x] `TaggedMarkdownTextView` now groups consecutive list items into a single render run so main chat and mini chat no longer space bullets like separate paragraphs
- [x] Chat markdown parsing now preserves nested list indentation, task-list items, and nested blockquote depth for the shared chat renderer
- [x] Main chat and mini chat both pick up the change automatically because `MessageBubble` and `MiniChatView` already share `TaggedMarkdownTextView`
- [x] Added focused `ChatPresentationTests` coverage for nested/task-list parsing and grouped list-run rendering
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-chat-format-dd test -only-testing:EpistemosTests/ChatPresentationTests`

## 2026-04-03 Inference Post-Query Memory Release Audit ✅
- [x] `DisplayPacedTextBuffer.reset(...)` now supports an explicit release-capacity path so oversized buffered assistant text does not keep its backing storage after the turn ends
- [x] `ChatState` now drops retained `streamingText` / pending-buffer capacity on new chat, completion, cancellation, error, and clear paths instead of only resetting content length
- [x] `NoteChatState` now releases retained inline-response / stream-buffer capacity on submission reset, accept, discard, and clear paths so large note-chat turns do not linger in idle heap state
- [x] Added a focused `NoteChatStateTests` regression plus a `RuntimeValidationTests` source guard covering the release-capacity reset wiring
- [x] Focused verification passed: `cargo test --manifest-path graph-engine/Cargo.toml`
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-idle-memory-dd test -only-testing:EpistemosTests/NoteChatStateTests -only-testing:EpistemosTests/PipelineServiceTests/ChatStateLocalMessageTests/startNewChatClearsPendingAttachmentsAndContext -only-testing:EpistemosTests/PipelineServiceTests/ChatStateLocalMessageTests/clearMessagesDropsPendingAttachmentsAndContext -only-testing:EpistemosTests/RuntimeValidationTests`
- [x] Recursive focused audit reached 3 successive clean no-edit passes for the post-query memory slice

## 2026-04-03 Graph Overlay Idle Memory Fix ✅
- [x] `HologramOverlay.hide()` now keeps the fast reopen path only for a bounded 10-second window, then tears down the hidden Metal graph window instead of retaining GPU resources indefinitely at idle
- [x] `HologramOverlay` now cancels any pending hidden teardown when the overlay is shown again, force-closed, or re-entered in mini mode, so the retention policy does not race normal graph lifecycle transitions
- [x] `HologramOverlay.showMini()` now tears down any previously soft-hidden full overlay before cold-starting mini mode, preventing a second hidden Metal graph instance from lingering in memory
- [x] Added `GraphOverlayRetentionPolicyTests` plus a `RuntimeValidationTests` source guard so the scheduled hidden teardown behavior remains enforced
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/GraphOverlayRetentionPolicyTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`

## 2026-04-03 Runtime Idle Memory Trims ✅
- [x] `LocalMLXRuntimeTuning` now produces a separate `idleMemoryPolicy`, and `MLXInferenceService` switches between full request budgets and a much smaller idle budget so cached Metal pages are trimmed immediately after each local turn instead of staying at inference-size while idle
- [x] `MLXInferenceService` now starts cold in the smaller idle budget, reapplies the active budget before warm reuse, and returns to the idle budget on unload/runtime-condition updates
- [x] `NotesSidebar` search caches now use a bounded query-retention policy (`maxCachedQueries = 12`) for both title and body results, preventing long sessions from accumulating unbounded cached search payloads
- [x] Added runtime guards for the MLX idle-budget path and the bounded sidebar cache retention
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-idle-memory-dd test -only-testing:EpistemosTests/TriageServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`

## 2026-04-03 Instant Recall Wake Freeze Fix ✅
- [x] `InstantRecallService` now shares a reusable rebuild helper and exposes `rebuildIndexAsync(...)`, which runs the Rust clear-and-reinsert pass inside `Task.detached(priority: .utility)` instead of holding `MainActor` for the full vault snapshot rebuild
- [x] `VaultSyncService.rebuildInstantRecallIndex(...)` now resolves the service on `MainActor` and awaits the async rebuild path, so post-wake/file-watcher vault reimports no longer force the heavy Instant Recall rebuild loop through `MainActor.run`
- [x] Added a behavior regression in `InstantRecallTests` for async stale-document replacement plus a `RuntimeValidationTests` source guard that keeps the vault watcher on the off-main rebuild path
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/InstantRecallServiceTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Follow-on subsystem verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests -quiet`

## 2026-04-03 Phase A Provider Selection Slice ✅
- [x] `InferenceState` now tracks an explicit `activeAIProvider`, remembers the last selected cloud model per provider, and falls back to local Qwen when the user switches to `Local Only`
- [x] Runtime model pickers now expose a dedicated `AI Provider` section and scope the `Cloud Models` list to the active provider instead of showing every cloud catalog at once
- [x] Inference Settings now expose the same provider selector so provider choice and credential setup stay aligned across toolbar + settings surfaces
- [x] Focused verification passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-active-provider-dd test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/InferenceCloudSelectionTests -quiet`

## 2026-04-02 Recursive Runtime Audit ✅
- [x] Fresh macOS app build passed: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- [x] Current Rust sweeps passed: `agent_core` 144 passed, `graph-engine` 2451 passed / 8 ignored, `omega-mcp` 126 passed, `omega-ax` 12 passed
- [x] `omega-mcp/src/pty.rs` now ignores echoed `__EPPWD__$(pwd)` command text and waits for the expanded marker line before updating `working_dir`
- [x] Added a PTY regression test covering echoed working-directory markers, and `omega-mcp` stays fully green after the fix
- [x] Hardening verification docs now reflect the live Hermes posture: Hermes remains an intentional managed subprocess boundary, not an unwired orphan-cleanup gap
- [x] `CloudKnowledgeDistillationService` now fast-paths inline-only note bodies, and XCTest hosts skip `MainThreadWatchdog.install()`, so the 10,025-note distillation stress suite no longer emits false hang diagnostics
- [x] `CloudKnowledgeDistillationService` now propagates source-note and recent-chat load failures instead of silently compiling empty model vaults
- [x] `HermesSubprocessManager` now supports dynamic stdout handler updates plus disconnect callbacks, and pending `HermesMCPClient` requests fail immediately when Hermes exits
- [x] `HermesSubprocessManager` now preserves the final stderr line from fast subprocess crashes, so diagnostics survive quick Hermes exits
- [x] `HermesSubprocessManager` now keeps relaunches blocked until graceful shutdown actually finishes, and `restart()` waits for the old subprocess to exit before relaunching
- [x] `HermesSubprocessManager` watchdog now waits for an actual ping response, so hung Hermes subprocesses terminate instead of looking healthy just because stdin is still writable
- [x] `HermesSubprocessManager.healthCheck(...)` now requires a live bridge ping before reporting Hermes healthy, so setup/repair flows no longer trust import-only success
- [x] `NightBrainService` now defers runs when `SearchIndexService` or `AgentGraphMemory` are unavailable instead of checkpointing those jobs as fake successes
- [x] `NightBrainService` now retains its initial `EventStore` for the full run, so checkpoint/completion durability cannot disappear mid-pipeline if the provider goes nil later
- [x] `AgentHeartbeatService` now monitors Hermes through a bounded post-dispatch window and defers the run if the subprocess drops before that window completes
- [x] `OrphanSubprocessCleanup` now snapshots descendant subprocess trees with `proc_listchildpids` and kills the full tree instead of only the tracked parent PID
- [x] `HermesSubprocessManager` now uses descendant-tree cleanup from the normal `terminate()` path when orphan cleanup is available, and the old fake `terminateProcessGroup()` API is gone
- [x] `NightBrainService` now routes checkpoint vacuum, artifact dedupe, and workspace snapshot compaction through the run's captured `EventStore`, and cloud knowledge distillation now defers if no distillation job is wired
- [x] `ActivityTracker` crash-recovery is now actually wired into launch/teardown, so flushed activity events are recovered at startup and durably cached on orderly shutdown
- [x] `ActivityTracker` now logs flush-directory failures explicitly, merges recovered cache contents with any already-recorded in-memory events, and no longer swallows idle-loop cancellation or page-title fetch failures with `try?`
- [x] `WorkspaceSummaryService` now fails loudly on summary-loop sleep interruption plus workspace fetch/save/page-title fetch failures instead of silently swallowing them with `try?`
- [x] `WorkspaceService` now fails loudly on auto-save, auto-restore, restore-delay, diff, save/load, and list persistence failures instead of silently swallowing them with `try?`
- [x] `TimeMachineService` now logs and fail-closes note/chat/page/graph fetch failures through shared helpers instead of silent empty or zero fallbacks
- [x] `EventStore` now fails closed on database-directory creation, logs `jobs_completed` JSON encode/decode failures, logs event payload encode failures, and closes SQLite on `quick_check` prepare failure
- [x] `EpistemosConfig` now fails closed on malformed capture allowlist/blocklist JSON and logs explicit capture-filter decode/encode failures instead of silently treating bad JSON as empty arrays
- [x] `AppBootstrap` now logs startup integrity, welcome-back summary, deferred startup delay, database reset cleanup, and Instant Recall seed snapshot failures instead of swallowing them with `try?`
- [x] `ModelProfileManager` now logs model-profile save failures instead of silently ignoring `context.save()`
- [x] `UIState` now logs malformed landing-greeting decode/encode failures, sanitizes corrupted greeting defaults back to an empty valid library, logs toast-dismissal timer failures, and `LandingGreetingResolver` now logs note-insight fetch failures instead of silently skipping them
- [x] Focused verification passed: `CloudKnowledgeDistillationTests` (8), `HermesMCPClientTests` (11), combined Cloud Knowledge + Hermes rerun (19 tests / 2 suites), NightBrain + Hermes + validation rerun (137 tests / 3 suites), `RuntimeValidationTests` (117), and `omega-mcp` cargo tests (126)
- [x] Follow-on focused verification passed: `NightBrainCheckpointResumeTests` + `OrphanSubprocessCleanupTests` + `RuntimeValidationTests` (130 tests) and `HermesMCPClientTests` (11)
- [x] Focused Hermes setup verification passed: `HermesHealthResult` suite rerun
- [x] Warm Xcode reruns now passed for `AgentHeartbeatTests` and the broader Hermes/NightBrain/runtime-validation slice
- [x] Focused tracker/runtime-validation verification passed twice: `ActivityTrackerTests` + `RuntimeValidationTests`
- [x] Focused persistence verification passed: `WorkspaceServicePersistenceTests` + `TimeMachineServiceTests` + `RuntimeValidationTests` (141 tests / 3 suites), `RuntimeValidationTests` rerun (131 tests), and `EventStoreSchemaTests` (7)
- [x] Follow-on focused verification passed: `xcodebuild ... build -quiet` and `xcodebuild ... test -only-testing:EpistemosTests/EpistemosConfigTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Follow-on focused verification passed: `xcodebuild ... test -only-testing:EpistemosTests/EpistemosConfigTests -only-testing:EpistemosTests/LandingExperienceSettingsTests -only-testing:EpistemosTests/RuntimeValidationTests -quiet`
- [x] Cloud Knowledge model vaults are now injected into live cloud, Apple Intelligence, and Hermes session-start prompts via `KnowledgeProfileStore.augmentedSystemPrompt(...)`
- [x] `AppleIntelligenceService` now caches Foundation Models sessions by the effective normalized system prompt and reapplies injected prompt context after context-window recycling
- [x] Focused Cloud Knowledge runtime wiring verification passed: isolated rerun of `CloudKnowledgeDistillationTests` + `AgentHeartbeatTests` + `RuntimeValidationTests` (150 tests / 3 suites)
- [x] `AgentHeartbeatService` no longer spins after cancellation in its post-dispatch monitoring loop, and `AppSupervisor` no longer swallows detached sleep cancellation in health-check/restart paths
- [x] Focused supervisor/heartbeat verification passed three consecutive times on an isolated DerivedData path: `AgentHeartbeatTests` + `SupervisorTests` + `RuntimeValidationTests`
- [x] `AmbientCaptureService` no longer swallows debounce cancellation, now logs malformed AX-tree payload failures, and no longer silently drops secret-redaction regex compilation failures
- [x] Focused ambient-capture verification passed three consecutive times on an isolated DerivedData path: `AmbientCaptureTests` + `RuntimeValidationTests`
- [x] `ProseEditorView` now logs save/fetch failures on live note persistence paths, schedules note-body writes before flush-page fetches, and avoids creating dangling wikilink duplicates after hidden fetch failures
- [x] `NoteChatState`, `DiskStyleCache`, and `AgentViewModel` now fail loudly on persisted history/cache/session-state load-write corruption instead of silently swallowing those note/agent persistence failures
- [x] Focused persistence hardening verification passed on an isolated DerivedData path: `NoteChatStateTests` + `NoteEditorLayoutTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `StartupAutoDiscovery` now logs config-read, `.hermes` creation, model-cache inspection, and fallback `SearchIndexService` bootstrap failures instead of silently degrading startup discovery
- [x] `NoteInsightService`, `NotesSidebar`, `HologramNodeInspector`, `TimeMachineView`, and `DialogueChatState` now fail loudly on the remaining live fetch/save/debounce/restore seams from this audit slice instead of hiding them behind `try?`
- [x] Focused startup/runtime hardening verification passed on the warmed DerivedData path: `HermesSubprocessTests` + `NoteChatStateTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `VaultIndexActor` now uses explicit fetch/save/file-I/O helpers for live indexing, manifest, spotlight, and migration paths instead of silently collapsing SwiftData and file-system failures behind `try?`
- [x] `LandingView` now logs welcome-back presentation/search-focus scheduling failures, welcome-back summary note save failures, and recent-chat fetch failures, and it cancels the deferred welcome-back presentation intentionally on dismiss/disappear
- [x] Focused vault/landing hardening verification passed on the warmed DerivedData path: `VaultIndexActorTests` + `RuntimeValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `VaultSyncService` now routes live health-snapshot fetches, SQLite signature probes, dirty-page fetches, version-capture fetch/counts, move-page lookup, and maintenance timer sleeps through explicit helpers instead of silent `try?` fallbacks
- [x] `ChatCoordinator`, `MiniChatView`, `MiniChatWindowController`, `QueryRuntime`, `VaultChatMutator`, and `VaultRegistry` now log live fetch/search/read failures explicitly instead of silently collapsing those chat/runtime seams
- [x] `ExecutionCheckpointManager` and `NotesAgent` now log checkpoint directory/decode/remove failures plus note-agent argument-parse, fetch, and save failures instead of swallowing them behind `try?`
- [x] Focused chat/vault/Omega hardening verification passed on the warmed DerivedData path: `RuntimeValidationTests` + `VaultSyncServiceAuditTests` + `MiniChatViewAuditTests` + `QueryRuntimeTests` + `VaultChatMutatorTests` + `OmegaAgentTests` + `PipelineServiceTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `SessionIntelligenceOverlay` now uses bounded `fetchLimit = 1` title lookups for note/chat command actions instead of full-page/full-chat vault scans on the interactive landing overlay path
- [x] Focused performance guard verification passed on the warmed DerivedData path: `NonAgentPruningValidationTests`, plus a follow-on `xcodebuild ... build -quiet`
- [x] `AgentViewModel` now shares one explicit computer-action mutation enrichment helper across click/type/keys/scroll actions instead of duplicating 300 ms AX sampling logic in each tool path
- [x] `ProgressStore` now enumerates only real session directories through shared helpers, logs directory/decode failures explicitly, and ignores stray files when listing sessions
- [x] `HarnessRegistry` and `HarnessLab` now reuse shared nonisolated ISO-8601 timestamp helpers instead of recreating formatters across candidate/proposal/evaluation/materialization paths
- [x] Recursive perf verification passed after one refinement-loop fix to `HarnessLabTime` isolation: `ProgressStoreTests`, then `HarnessSubsystemTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `SessionIntelligenceOverlay` now resolves “open it” note-history lookups through extracted candidate titles plus open-note checks and bounded fetches instead of scanning every `SDPage` row in command history fallback paths
- [x] `LiquidGreeting` now uses shared deterministic timing helpers and an explicit pause helper instead of per-character `Int.random(...)` sleeps across the landing typewriter loop
- [x] Added focused landing optimization coverage in `LandingOptimizationTests`, plus source guards in `NonAgentPruningValidationTests` and `ThemePairTests`
- [x] Recursive landing perf verification passed after one refinement-loop fix to `SessionIntelligenceNoteLookup` isolation: `LandingOptimizationTests` + `NonAgentPruningValidationTests` + `ThemePairTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `LocalModelManager.refreshFromDisk()` now persists the local model manifest only when legacy/missing-install cleanup actually changed `installRecords`, instead of rewriting the manifest on no-op refreshes
- [x] `pruneMissingInstalls()` and `purgeLegacyNonQwenInstalls()` now report whether they changed the record set so refresh cleanup persists at most once per pass
- [x] Added a real `LocalModelInfrastructureTests` manifest-modification-date regression plus a `RuntimeValidationTests` guard for the conditional-persist structure
- [x] Recursive local-model perf verification passed on an isolated DerivedData path: `LocalModelInfrastructureTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs
- [x] `SessionIntelligenceOverlay.summarizeChats()` now orders grouped chats deterministically and batch-loads chat titles for the selected groups instead of fetching one `SDChat` row per summary entry
- [x] Added a real `LandingOptimizationTests` chat-summary ordering regression plus a `NonAgentPruningValidationTests` guard that keeps the landing overlay from regressing back to per-chat title fetch loops
- [x] Recursive landing chat-summary verification passed after one refinement-loop fix to a source-guard key-path escape: `LandingOptimizationTests` + `NonAgentPruningValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs on the isolated DerivedData path
- [x] `SessionIntelligenceOverlay` now shares explicit note-presentation/dismiss timing helpers plus a bounded auto-save workspace-summary helper instead of repeating raw delayed create/open and fallback fetch paths on the landing command surface
- [x] `WorkspaceSwitcherOverlay` now routes load/dismiss flows through one shared post-dismiss helper instead of repeating 150 ms delayed tasks
- [x] `AgentViewModel` now routes the remaining cron keepalive/admin refresh sleep through an explicit helper and shared interval instead of an inline raw 60-second delay loop
- [x] Final audited non-Hermes perf verification passed on `/tmp/epistemos-codex-final-perf-round`: `LandingOptimizationTests` + `NonAgentPruningValidationTests` + `RuntimeValidationTests` plus `xcodebuild ... build -quiet` all passed three consecutive no-edit runs

## 2026-04-02 Cloud Knowledge Distillation Wiring ✅
- [x] `CloudKnowledgeDistillationService` now loads recent chats from SwiftData by default when no provider override is supplied
- [x] Distillation source-note loading no longer silently caps at 10,000 pages
- [x] Untagged domain-map fallback now preserves real concept recency via `RankedConcept.lastUpdatedAt`
- [x] NightBrain treats failed cloud-knowledge or search-index maintenance jobs as interrupted runs instead of falsely checkpointing/completing them
- [x] Focused verification passed: `CloudKnowledgeDistillationTests` + `NightBrainCheckpointResumeTests` = 14 tests in 2 suites, 0 failures

## 2026-04-01 Verification Closure ✅
- [x] Full hosted Swift rerun passed: `test-without-building` completed 3051 tests across 418 suites with 0 failures
- [x] Fresh cached macOS app build passed: `xcodebuild ... build` returned `BUILD SUCCEEDED`
- [x] Fresh Rust sweeps passed: `graph-engine` 2448 passed / 0 failed / 8 ignored, `agent_core` 141 passed / 0 failed, `omega-mcp` 125 passed / 0 failed, `omega-ax` 12 passed / 0 failed
- [x] `agent_core/src/shared_memory.rs` tests now serialize process-global `ShmPool` access and reset the pool before/after each test, eliminating the parallel `shm_pool_cleanup_all` race

## 2026-04-01 Harness + Power Follow-Up ✅
- [x] `AgentViewModel` now prepares harness session state before recording user intent, so the first turn no longer drops the objective from trace/progress capture
- [x] `AgentViewModel` now records final model output and runs `CompletionChecker` at session end
- [x] `VaultSyncService` now observes `PowerGuard` mode changes and restarts maintenance timers when `.full` mode returns
- [x] `DualBrainRouter` now requires a dedicated ANE backend before reporting dual-brain active
- [x] Focused verification passed: `RuntimeValidationTests` + `VaultSyncServiceAuditTests` + `DeviceAgentServiceTests` = 140 tests in 3 suites, 0 failures

## 2026-04-01 Tool Gate Follow-Up ✅
- [x] HermesSubprocessManager now normalizes `HOME` + `PATH`, exports `HERMES_ENV_TYPE=local`, keeps `TERMINAL_ENV=local`, and creates `~/.hermes` before launching Hermes
- [x] `epistemos_bridge.py` now logs the loaded Hermes tool names to stderr after session setup and includes `available_tools` in live session payloads
- [x] `AgentViewModel` now feeds the live Hermes tool list into HarnessIntegration when it is available instead of always sending an empty tool set
- [x] Bridge + Swift session parsing tests added for the loaded-tool payload path

## 2026-04-01 Auto-Discovery Pass ✅
- [x] `AppBootstrap` now runs a startup auto-discovery pass before `InferenceState` initializes, so env/config credentials can seed Keychain without manual setup
- [x] Startup discovery now scans `~/.config/epistemos/config.toml` and `~/.epistemos/config.toml`, creates `~/.hermes` if missing, logs optional browser/web/model availability, and degrades gracefully when pieces are absent
- [x] Hermes tool-gate env export now includes Browserbase credentials so discovered browser config actually reaches the subprocess
- [x] Focused Swift tests cover config parsing, env/keychain precedence, config import, `agent-browser` detection, and model cache discovery

## Sprint Agent-1: The Living Loop ✅
- [x] agent_core crate with all 13 source files
- [x] Full SSE state machine with thinking/signature preservation
- [x] Parallel tool execution (futures::try_join_all)
- [x] Agent-decides termination (stop_reason == end_turn)
- [x] UniFFI bridge with AgentEventDelegate callback interface
- [x] All verification greps pass

## Sprint Agent-2: Local Agent System ✅
- [x] HermesPromptBuilder, LocalToolGrammar, LocalAgentLoop, ConfidenceRouter
- [x] canActAsAgent=false enforced for weak models
- [x] 20/20 focused tests pass

## Sprint Agent-3: MCP + Computer Use ✅
- [x] Rust-authoritative tool catalog (26 tools, 5 agents)
- [x] Vault-focused MCP surface (read/write/list/search)
- [x] AX-first computer-use path hardened
- [x] Device backend execution seam closed
- [x] Focused tests pass

## Sprint Agent-4: Multi-Provider + Polish ✅
- [x] Routed provider preview + honest auto bridge resolution
- [x] Perplexity Sonar streaming provider with citations
- [x] OpenAI-compatible provider (openai.rs — SSE streaming, tool calls, 16 tests) (2026-03-31)
- [x] Full context compaction loop → Sprint Omega-1 Task 3 (compaction.rs)
- [x] Metal thinking glow shader for OmegaPanel → Sprint Omega-4
- [x] Full validation checklist passes (449 Rust tests, Swift BUILD SUCCEEDED) (2026-03-31)

---

## Sprint Omega-1: Foundation Integration ✅ (2026-03-29)
- [x] Task 1: prompt_caching.rs — cache_control breakpoints (~85% cost reduction)
- [x] Task 2: think.rs — zero-cost reasoning tool
- [x] Task 3: compaction.rs — 4-phase context compaction (boundary protect → tool replace → summarize → fold)
- [x] Task 4: security.rs — credential redaction + command risk + output scanning
- [x] Task 5: MCP stdio transport in omega-mcp
- [x] Task 6: Full compilation + test sweep passes (164 Rust tests, 0 failures)

## Sprint Omega-2: Hermes Subprocess Bridge ✅ (2026-03-29)
- [x] HermesSubprocessManager.swift — spawn/manage/kill via Foundation Process
- [x] HermesMCPClient.swift — MCP stdio client to Hermes
- [x] EpistemosMCPServer.swift — MCP stdio server exposing macOS tools
- [x] Pipe-based watchdog heartbeat for zombie prevention
- [x] Process group management for clean shutdown
- [x] Integration with AppBootstrap lifecycle
- [x] Hermes health check on launch

## Sprint Omega-3: AXorcist Computer Use ✅ (2026-03-29)
- [x] Replace raw AXUIElement code with AXorcist SPM dependency
- [x] Ghost OS-style MCP tools (see, click, type, scroll, keys, screenshot)
- [x] ScreenCaptureKit pipeline with buffer dropping (<200ms target)
- [x] TCC permission management UI
- [x] AX-first with vision fallback pattern

## Sprint Omega-4: Skills + Memory + Polish (2026-03-29)
- [x] SKILL.md progressive disclosure (metadata → instructions → resources)
- [x] Post-task auto-skill creation
- [x] 3-layer progressive memory retrieval
- [x] Overnight Note Research — NightBrain-scheduled deep research on flagged notes with morning summary
- [x] Usage cost dashboard
- [x] Slash-command palette (/plan, /research, /review)
- [x] Metal thinking glow shader for OmegaPanel
- [x] Full validation checklist passes (3/3 recursive clean)
- [x] All Rust tests pass (371 tests, 0 failures)

## Sprint Omega-5: Living Vault Memory Engine (in progress)
- [x] Task 1: diff_engine.rs — unified text diff, JSON pointer diff, and 3-line fuzzy patch apply (2026-03-30)
- [x] Task 2: memory_classifier.rs — ADD/UPDATE/DELETE/NOOP vault write classifier with compact prompt + local/Haiku dispatch hint + contradiction planner (2026-03-30)
- [x] Task 3: memory_decay.rs — Ebbinghaus decay + garbage collection with pinned/access-aware batch decay (2026-03-30)
- [x] Task 4: cross_propagation.rs — Tantivy/file-scan reference detection with atomic secondary patch rollback (2026-03-30)
- [x] Task 5: vault_git.rs — git-backed atomic vault commits with history + diff_between support (2026-03-30)
- [x] Task 6: ConversationPersistence.swift — JSONL + markdown conversation persistence (2026-03-30)
- [x] Task 7: VaultChatMutator.swift — diff staging + approval flow (2026-03-30)
- [x] Task 8: VaultRegistry.swift / vault_registry.rs — multi-vault identity mapping (2026-03-30)
- [x] Task 9: Full compilation + integration verification (2026-03-30)

## Agent Integration Session (2026-03-30) ✅
Items 1-15 from `docs/AGENT_INTEGRATION_SESSION_PLAN.md` — all building clean.

### Do First Tier ✅
- [x] Item 6: ToolLoopDetector wired into Hermes bridge tool_completed events (2026-03-30)
- [x] Item 5: AgentDepthLimiter wired into Hermes bridge tool_started/completed for delegate tools (2026-03-30)
- [x] Item 15: CredentialRedactor — 9 patterns, wired into vault_search + vault_read (2026-03-30)
- [x] Item 14: CostTracker — micro-dollar precision, March 2026 pricing, wired into complete events (2026-03-30)
- [x] Item 8: ContextCompiler — U-curve reordering on vault_search results (2026-03-30)

### Do Second Tier ✅
- [x] Item 13: MemoryThreatScanner — role hijack + exfiltration + invisible unicode, wired into vault tools (2026-03-30)
- [x] Item 12: ShadowGitCheckpoint — GIT_DIR/WORK_TREE separation, 10s timeout, auto-checkpoint (2026-03-30)
- [x] Item 3: NightBrain menu bar agent mode — config + delegate + Settings toggle (2026-03-30)
- [x] Item 7: Living Vault Rust FFI exports — classify_vault_memory, decay_memory_nodes, gc_memory_nodes (2026-03-30)

### Do Third Tier ✅
- [x] Item 4: SkillStoreView — 7 categories, search, detail sheet, native + Hermes skills (2026-03-30)
- [x] Item 9: QLoRATrainer prefers composed train_final.jsonl over raw shards (2026-03-30)
- [x] Item 1: HTTP/SSE transport via NWListener for MCP payloads >50KB (2026-03-30)
- [x] Item 2: recovery.rs (7 tests) + HexViewerView with Rust FFI (2026-03-30)

### Gemini Deep Analysis Integration ✅
- [x] Evaluated 6 proposals from OpenClaw/Hermes comparative analysis (2026-03-30)
- [x] Accepted: Heartbeat Memory Distillation (Item 20), Sub-Agent Context Scoping (Item 21)
- [x] Rejected: A2UI (already SwiftUI), PyO3 (wrong direction), Zero-Trust WS (local app), Docker Proxy (deferred)
- [x] Updated AGENT_INTEGRATION_SESSION_PLAN.md, MASTER_SESSION_PROMPT.md, AGENT_PROGRESS.md

### Do Next Tier (Gemini analysis upgrades) ✅
- [x] Item 20: NightBrain Heartbeat Memory Distillation — memoryDistillation job in NightBrainService, calls AgentGraphMemory.distillMemory() with Ebbinghaus decay + GC (2026-03-30)
- [x] Item 21: Sub-Agent Hierarchical Context Scoping — context_scope parameter in delegate_tool.py, 3 role-specific context files (terminal, research, file) in hermes-agent/contexts/ (2026-03-30)

## Sprint Omega-6: Context Compiler + Graph Visualizer ✅ (2026-03-31)
- [x] Task 1: context_compiler.rs — prompt DAG with cache-optimal assembly (2026-03-30)
- [x] Task 2: skill_router.rs — TF-IDF skill selection (7 tests) (2026-03-30, verified 2026-03-31)
- [x] Task 3: example_bank.rs — few-shot retrieval + Jaccard quality ranking (6 tests) (2026-03-30, verified 2026-03-31)
- [x] Task 4: GraphDataModel.swift — execution trace → graph subgraph conversion (2026-03-30, verified 2026-03-31)
- [x] Task 5: AgentGraphView.swift — Canvas-based DAG with hierarchical layout (2026-03-30, verified 2026-03-31)
- [x] Task 6: SemanticZoomController.swift — 5-level semantic zoom + control strip (2026-03-30, verified 2026-03-31)
- [x] Task 7: NodeDetailPanel.swift — node inspector with metadata grid (2026-03-30, verified 2026-03-31)
- [x] Full verification: 449 Rust tests pass, Swift BUILD SUCCEEDED (2026-03-31)

## Sprint Omega-7: Paperclip/Lambda Fusion (2026-03-31)
- [x] Task 1: chunk_reduce.rs — parallel split/map/reduce tool (13 tests, λ-RLM pattern) (2026-03-31)
- [x] Task 2: Think-block streaming UI — <think> token parser + blurred ChainOfThoughtBubble (2026-03-31)
- [x] Task 3: CostTracker 3-tier budget — session + per-agent + rolling daily + pre-turn gating (2026-03-31)
- [x] Task 4: AgentHeartbeatService — NSBackgroundActivityScheduler heartbeat with budget gating (2026-03-31)
- [x] Task 5: openai.rs — OpenAI Chat Completions SSE provider (16 tests) (2026-03-31)
- [x] Task 6: PTY test stabilization — environment-robust working_dir assertion (2026-03-31)
- [x] Full verification: 449 Rust tests, 0 failures; Swift BUILD SUCCEEDED (2026-03-31)
