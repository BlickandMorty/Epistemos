# Deterministic Schema Engine (P8) — Systems Blueprint + Reuse Map (2026-06-18)

Research-first grounding for the owner's `DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md`.
**Build ON existing work, do not greenfield.** A code inventory (2026-06-18) shows
P8 is ~80% already implemented as real, tested Rust/Swift symbols; the truly
net-new surface is small. This doc is the blueprint (spec deliverable C.1) + the
phased checklist (C.4), each step naming the existing symbol it builds on.

Sequencing: P8 is the CHAT-MODE substrate spine but comes AFTER the chat-side
reality audit (picker rebuild etc.). This is the plan, not a claim of
implementation.

## Predecessor

P4.3 (`EPISTEMOS_MASTER_LOOP_PROMPT_2026_06_17.md:449`, status `◐ FFI wired`) is
the direct predecessor: the `--json-schema` FFI (`run_local_gguf_generation` +
`with_json_schema`) is already wired; P4.3 asks to validate the local Pro tool
loop end-to-end. P8 generalizes that into the full engine. (Note: the two docs
named "deterministic"/"schema gate" — `DETERMINISTIC_RUNTIME_V1_PREFLIGHT.md`
and `SCHEMA_GATE_STATUS_2026_05_16.md` — are UNRELATED: the first is knowledge-core
query-invalidation, the second the F-ULP-Oracle numeric fixture. Do not reuse
their naming.)

## Systems blueprint (spec C.1): the request trace

```
SwiftUI View (Chat)
  │  user prompt
  ▼
[B] RAG Preflight Tool Selector  ── NET-NEW assembly ──
  │  embed prompt (EmbeddingService.TextEmbeddingLookup)
  │  → ANN over tool-description index (epistemos-shadow usearch HNSW)
  │  → pick ~3-5 tool schemas (tool catalog: ToolTierBridge / registry)
  ▼
[A] Schema assembly
  │  per-tool input_schema (schemars schema_for! where Rust-typed)
  │  → dispatch grammar (grammar/mod.rs dispatch_schema_for_tools → llguidance)
  ▼
Local Gemma 4 generation (off @MainActor)
  │  run_local_gguf_generation(..., with_json_schema(dispatch_schema))   bridge.rs:1080/1148
  │  llama-cli --json-schema constrains the sampler → valid tool-call JSON
  ▼
[B] Reasoning-token isolation
  │  ThinkTagStreamRouter splits [Start thinking]/[End thinking] → UI trace
  │  args → execution; thinking preserved (honesty constraint)
  ▼
parse_tool_calls (agent_runtime/function_call.rs:141 / FFI bridge.rs:2511)
  ▼
[A] Deterministic schema GATE  ── NET-NEW wiring ──
  │  JsonSchemaValidator (tools_v2/runner.rs:144) validates args vs schema
  │  (+ optional repair: research/hyperdynamic_schemas/repair.rs:249)
  │  AST quality gate for code artifacts: tree-sitter parse BEFORE write/compile
  │  (lsp_runtime/mod.rs:524 parsers) ── NET-NEW gate orchestration ──
  ▼
[C] Tool Router executes (tools/registry.rs:482 ToolRegistry.execute, MAS-gated)
  ▼
typed result event → UniFFI async stream (AgentEventDelegate) → Swift actor → View
```

## Reuse map (build on these — do NOT rewrite)

| Spec capability | Existing symbol (file:line) | Status |
|---|---|---|
| JSON-schema validation (Draft 2020-12, jsonschema 0.28) | `agent_core/src/tools_v2/runner.rs:144` `JsonSchemaValidator` / `SchemaValidator` trait | EXISTS |
| Rust struct → JSON schema | `agent_core/src/route/mod.rs:193` `schema_for!`; `schemars` `Cargo.toml:720` | EXISTS |
| Schema → sampler grammar; tool-dispatch grammar | `agent_core/src/grammar/mod.rs:16-46` (llguidance) | EXISTS |
| Constrained Gemma gen (llama-cli `--json-schema`) | `agent_core/src/providers/gguf_cli.rs:141` `with_json_schema`; FFI `bridge.rs:1080,1148` | EXISTS |
| Constrained-decode tool surface | `tools_v2/v2_catalog/inference_constrained_generate.rs`; `reason_think.rs:122` | EXISTS |
| Tool-call parsing (text → calls) | `agent_runtime/function_call.rs:141` `parse_tool_calls`; FFI `bridge.rs:2511` | EXISTS |
| Tool Router | `tools/registry.rs:482` `ToolRegistry` (+ `mas_runtime_preflight`) | EXISTS |
| AST parsing (Rust/Swift, in-proc) | `lsp_runtime/mod.rs:524-526` tree-sitter (feature `lsp-runtime`) | EXISTS |
| Embeddings for RAG | `Epistemos/Graph/EmbeddingService.swift` `TextEmbeddingLookup`; `epistemos-shadow/.../vector_index.rs` usearch HNSW | EXISTS |
| Schema repair (widening / optional) | `research/hyperdynamic_schemas/repair.rs:249` `validate_value` + `RepairReport` | EXISTS |
| Reasoning-token isolation | Rust `gguf_cli.rs:409` framing filter; Swift `ThinkTagStreamRouter.swift:58-73`; `Extensions.swift:228-237` | EXISTS |
| Thinking-block preservation reference | `agent_core/src/providers/claude.rs:152-156,375-410` | EXISTS |
| Swift structured-gen plan builders | `Epistemos/LocalAgent/LocalToolGrammar.swift:163-256` | EXISTS |
| UniFFI async stream seam | `agent_core/src/bridge.rs:1080` `run_local_gguf_generation` + `AgentEventDelegate` | EXISTS |
| RAG retrieval plumbing (keyword today) | `agent_core/src/context_compiler.rs:107,218` `load_rag_context` (term-overlap, limit 3) | PARTIAL |

## Truly NET-NEW (the only real build work)

1. **RAG preflight tool *selector*** — embed prompt → ANN over a *tool-description*
   embedding index → return ~3-5 tool schemas. All parts exist (EmbeddingService,
   usearch HNSW, tool catalog, `dispatch_schema_for_tools`); only the assembly +
   a tool-description index build/refresh are new. (`load_rag_context` is keyword-
   only today — this is where the spec's "vector embeddings" is currently
   aspirational on the Rust side.)
2. **AST quality gate before disk-write/compile** — parse the model's emitted
   code artifact with the existing tree-sitter parsers and reject/repair before
   persisting. Parser exists; the gate orchestration is new.
3. **Unifying `schema_engine` module + single Swift `actor` coordinator** — compose
   RAG-preflight → constrained-gen → schema-gate → executor stream into one
   race-free actor (today split across `StreamingDelegate` + `ThinkTagStreamRouter`).
4. **Wire `JsonSchemaValidator` as a pre-execution gate inside `ToolRegistry`** —
   validate tool args against the schema as a gate in routing, not just in tools_v2.

## Phased checklist (spec C.4) — stability + determinism FIRST

- **P8.0 (this doc)** — research-first inventory + blueprint. DONE.
- **P8.1 Gate-in-router (determinism first, smallest risk):** add `JsonSchemaValidator`
  as an opt-in pre-execution validation gate in `ToolRegistry.execute` behind a flag;
  pure Rust + cargo tests (valid passes, malformed rejected with `at {path}: {err}`).
  Reuses `runner.rs:144` + `registry.rs:739`. No Swift, no UI risk.
- **P8.2 Tool-description index + RAG selector (pure core):** a pure Rust selector
  `select_tools(prompt_vec, tool_vecs, k) -> [tool_id]` (cosine/ANN), unit-tested;
  index build over tool descriptions. Defer wiring into the live turn until tested.
- **P8.3 AST quality gate (pure core):** `validate_artifact(lang, source) -> AstVerdict`
  using `lsp_runtime` tree-sitter; cargo tests (well-formed Rust/Swift passes,
  truncated/garbage rejected). Gate runs before any write/compile.
- **P8.4 Swift actor coordinator:** one `actor` fusing the stream
  (`run_local_gguf_generation` delegate + `ThinkTagStreamRouter`), inference
  off `@MainActor`; reuse, don't duplicate, the existing routers.
- **P8.5 Visible determinism surface:** show "why this route" + schema-gate
  pass/fail + selected-tools (~3-5) in the Chat UI (it's the edge, not plumbing).
  Ties to the Provenance Console / AnswerPacket.
- **P8.6 End-to-end (P4.3 closeout):** validate the local Pro tool loop on real
  Gemma with `llama-cli --json-schema` honest tools; near-100% tool-call fidelity.

Each phase = pure tested core before any UI wiring (the pattern that's been
working). Surface the determinism visibly per spec §D.
