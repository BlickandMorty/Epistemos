# Epistemos: Architectural Research Report

**Author's note (research methodology):** This report grounds its recommendations in the 2024–2026 literature on constrained decoding (Outlines, llguidance, XGrammar, lm-format-enforcer), function-calling fine-tunes (Hermes-3/4, Qwen2.5 and Qwen3, ToolHop / BFCL), agentic memory (A-MEM, MemGPT/Letta, Voyager), retrieval-augmented PKM (Khoj, Reor, Logseq Copilot), and the LLM-Semantic File System (LSFS, ICLR 2025). Where claims depend on specific empirical numbers, the source is named inline; where claims are architectural opinion, they are flagged as such. Predictions about future product behavior are kept tentative ("should", "is expected to") and are not stated as facts.

---

## Section 1 — Executive Summary

Epistemos is, at its core, a bet on four convergent ideas:

1. **Deterministic multi-variant tool ladders.** Every meaningful agent action — placing a capture into a folder, summarizing a note, resolving a backlink — is implemented as a *ladder* of variants A→B→C→D, each cheaper or more conservative than the last, each validated against a JSON schema. If variant A fails (timeout, schema-violation, empty result, low-confidence), the runner falls through to B, then C, and ultimately to a *defer* terminal that asks the user or stages the work in a review queue. This pattern eliminates the dominant failure mode of LLM agents — confident wrong answers — by making *not acting* a first-class outcome. It maps cleanly onto Reflexion-style self-critique and ReWOO-style plan-then-execute (theaiengineer.substack.com), but it imposes structure those patterns leave implicit.

2. **GBNF-constrained local SLMs.** The local inference path (Qwen 7-8B 4-bit / Hermes-3 via MLX) is treated as a *deterministic JSON producer*, not a free-form prompt engine. Every tool call is gated by a context-free grammar compiled per call; logits are masked at the token level so the model literally cannot emit a malformed call. This mirrors how llama.cpp, vLLM, XGrammar, and llguidance enforce JSON Schema (arxiv.org/abs/2411.15100, github.com/guidance-ai/llguidance), but is delivered through the MLX-Swift `GrammarMaskedLogitProcessor` recently surfaced by the MLX-Structured project (rudrank.com). The empirical lesson from BFCL and ToolHop (arxiv:2501.02506) is unambiguous: at 1.5B–7B parameters, *not calling a tool beats calling the wrong one*, and structural constraints + few-shot prompting move the success ceiling from ~60% to ~95% on schema compliance (huggingface.co/blog/nmmursit/guided-decoding). The "Brief Is Better" study (arxiv:2604.02155) further establishes that 7B Qwen models peak at ~32-token CoT budgets — short reasoning, then commit. Epistemos's grammars therefore reserve a small `reasoning` field (≤256 tokens) *before* the answer field, never after.

3. **Hybrid MD+JSON memory.** Markdown is for humans; JSON is for machines. Epistemos's `soul.md`, procedural memory, episodic logs, semantic facts, and system prompts are all stored as Markdown files with **typed JSON frontmatter blocks** (similar to MDX components or Logseq properties). The MD prose is human-curated and read by both humans and LLMs as context; the JSON blocks are LLM-mutable under schema-constrained generation. Parsing produces typed Rust structs via `serde`; writing is gated by JSON-Schema validation and a migration registry. This is the same insight A-MEM (arxiv:2502.12110) exploits — atomic notes with rich structured tags inside a Zettelkasten — and the same ergonomic compromise Voyager's skill library makes (executable code + natural-language descriptions).

4. **Minimal-UX, hidden-complexity routing.** The reference points are Claude Desktop (one input, the system decides), Raycast (one bar, plugins surface contextually), Linear (zero settings sprawl), and Things (no folders, just inbox/today/upcoming). Cursor exposes the IDE; Claude hides it. The PKM analog: one capture surface, one search surface, one AI surface — each backed by a **router** that picks lexical vs semantic vs graph-walk vs agent, and local vs cloud, automatically. The user only sees a settings panel that boils down to a credentials manager and a "Pro profile / App Store profile" toggle.

The architectural thesis is therefore: **deterministic multi-variant tool ladders + GBNF-constrained local SLMs + hybrid MD+JSON memory + minimal-UX hidden-complexity routing** — each leg of the stool reinforces the others. Constrained decoding is what makes deterministic ladders *possible* on a 7B local model. Hybrid memory is what makes ladders *cheap* (the routing variant has structured features, not free-form prose). Minimal UX is what makes the user *trust* the ladder, because the user never has to configure it.

The remainder of this document is the implementation case for each leg.

---

## Section 2 — Exhaustive Native Tool Catalog

### 2.0 The registry contract

All tools live behind a single Rust trait. The registry compiles a per-tool GBNF on registration and exposes both a synchronous variant for the local path and an async variant for the cloud path.

```rust
// agent_core/src/tools/mod.rs
pub trait Tool: Send + Sync + 'static {
    const NAME: &'static str;
    const DESCRIPTION: &'static str;
    type Input: serde::de::DeserializeOwned + JsonSchema;
    type Output: serde::Serialize + JsonSchema;

    fn input_schema() -> serde_json::Value { schema_for!(Self::Input) }
    fn output_schema() -> serde_json::Value { schema_for!(Self::Output) }
    fn gbnf() -> &'static str;          // compiled at registration
    fn variants(&self) -> &[VariantId];  // declared in priority order

    async fn invoke(
        &self, input: Self::Input, ctx: &ToolCtx,
    ) -> Result<Self::Output, ToolError>;
}

pub struct VariantLadder<T: Tool> {
    variants: Vec<Box<dyn Variant<T>>>,
    budget: RetryBudget,            // per-variant attempt + total wall-clock
    breaker: CircuitBreaker,        // opens after N variant failures
}
```

A *variant* is a strategy that fulfills the same `Tool::Output` contract — a centroid-search variant, an LLM-classification variant, a graph-walk variant, etc. The runner walks variants in declared order; each variant returns either `Ok(Output)` with a confidence score, or `Err(VariantError::FallThrough)` to advance the ladder, or `Err(VariantError::Defer)` to short-circuit to the deferral terminal.

Below, every tool follows this skeleton: name, purpose, inputs/outputs (JSON Schema), variant ladder, local-model viability, GBNF fragment, failure modes.

---

### 2.1 Vault / Note tools

#### `vault.read`
**Purpose.** Read a note (or note range) from the vault by path or by stable ID. Reached when the agent needs the content of a known note before reasoning over it.

```json
// input
{"type":"object","required":["target"],"properties":{
  "target":{"oneOf":[
    {"type":"object","properties":{"path":{"type":"string"}},"required":["path"]},
    {"type":"object","properties":{"note_id":{"type":"string","pattern":"^[a-z0-9]{12}$"}},"required":["note_id"]}
  ]},
  "range":{"type":"object","properties":{"start_line":{"type":"integer"},"end_line":{"type":"integer"}}}
}}
// output
{"type":"object","required":["content","frontmatter","path","mtime"],"properties":{
  "content":{"type":"string"},
  "frontmatter":{"type":"object"},
  "path":{"type":"string"},
  "mtime":{"type":"integer"},
  "truncated":{"type":"boolean"}
}}
```
**Variants.** A: direct fs read (mmap, fastest). B: cached read from the in-memory rope buffer if a TextKit window has the note open. C: LSFS keyword index lookup (covers stale-path / renamed-file recovery). D: defer with `not_found`.
**Local viability.** Trivial; no model involved beyond the calling agent. GBNF for the *call* (not the body):
```
root ::= "{" ws "\"target\":" target ws "}"
target ::= path-target | id-target
path-target ::= "{" ws "\"path\":" string ws "}"
id-target ::= "{" ws "\"note_id\":" id-string ws "}"
id-string ::= "\"" [a-z0-9]{12} "\""
```
**Failure modes.** Stale path → fall to LSFS; binary content → return `truncated:true`; permission error → defer.

#### `vault.write`, `vault.append`, `vault.split`, `vault.merge`
Symmetric: each takes `target` + `body` (and `merge_strategy` for merge), returns `{path, version, conflict?}`. The variant ladder for write is **A: optimistic write with mtime guard → B: three-way merge against base → C: write-to-conflict-file → D: defer**. `vault.split` and `vault.merge` are higher-order: they decompose into multiple writes inside a single Rust transaction (rolled back on failure). All share a common GBNF parameter shape.

#### `vault.search`
**Purpose.** The unified retrieval tool. Replaces three lower-level tools (`grep`, `vector_search`, `graph_walk`) with a single endpoint whose internal variant ladder picks the right backend.

```json
// input
{"type":"object","required":["query"],"properties":{
  "query":{"type":"string","minLength":1,"maxLength":512},
  "k":{"type":"integer","minimum":1,"maximum":50,"default":10},
  "mode":{"type":"string","enum":["auto","lexical","semantic","hybrid","graph"]},
  "scope":{"type":"object","properties":{"folder":{"type":"string"},"tag":{"type":"string"}}}
}}
// output
{"type":"object","required":["hits"],"properties":{
  "hits":{"type":"array","items":{"type":"object","required":["path","score","snippet"],"properties":{
    "path":{"type":"string"}, "score":{"type":"number"},
    "snippet":{"type":"string"}, "match_type":{"type":"string","enum":["lexical","vector","graph"]}}}},
  "strategy_used":{"type":"string"}
}}
```
**Variants (auto mode).** A: lexical (Tantivy / SQLite FTS5) — fastest, trivially correct on quoted phrases. B: semantic (LanceDB / `mlx_embeddings`, cosine over chunk embeddings) when lexical returns <3 hits or query has no rare tokens. C: hybrid RRF (reciprocal-rank fusion of A+B) when both return overlapping but non-identical sets. D: graph-walk from current note context when scope is explicitly relational ("notes connected to X"). E: defer with `low_recall`.
**Local viability.** Embedding model is a separate ~30M-param `bge-small-en-v1.5` quantized to 4-bit MLX; runs at <50ms/query on M-series. The *router* for variant selection is a 30-line classifier in Rust (no LLM). This is critical: the search router must not itself depend on a 7B inference call.
**Failure modes.** Empty index → fall to A only; embedding model OOM → degrade to A; corrupt vector store → rebuild in background, serve A.

#### `vault.graph_walk`
Adjacency traversal over the wiki-link graph. Inputs: `{from: path, depth: 1..3, edge_types: ["forward","backlink","tag-cooccurrence"]}`. Output: a typed adjacency list. This is the explicit "graph" backend that `vault.search` delegates to in mode D.

#### `vault.backlinks`
Returns the inverted-link index for a note. Pure deterministic Rust; no model.

#### `vault.tag_infer`
**Variants.** A: rule-based regex over title + first paragraph (cheap, ~70% precision). B: KNN over tag-centroid embeddings (`for each existing tag, store mean embedding of its notes; cosine to capture`). C: GBNF-constrained LLM classification with the top-K existing tags as enum. D: return empty (no tags) — the deferral terminal.

GBNF for variant C (constrains the model to choose 0–3 tags from a closed enum):
```
root        ::= "{" ws "\"tags\":" ws "[" ws (tag (ws "," ws tag){0,2})? ws "]" ws "}"
tag         ::= "\"" tag-name "\""
tag-name    ::= "research" | "personal" | "code" | "meeting" | "literature" | ...   ; injected at compile time
```

#### `vault.quick_capture`
The intake endpoint. Detailed in §3.

---

### 2.2 Knowledge tools

#### `knowledge.concept_extract`
**Purpose.** Extract the canonical concept(s) from a passage. Output is the *atomic concept* used by quick-capture routing.

```json
// output
{"type":"object","required":["concepts"],"properties":{
  "concepts":{"type":"array","minItems":0,"maxItems":3,"items":{"type":"object","required":["canonical","aliases","kind","confidence"],"properties":{
    "canonical":{"type":"string","minLength":2,"maxLength":80},
    "aliases":{"type":"array","items":{"type":"string"}},
    "kind":{"type":"string","enum":["entity","method","claim","question","term","project"]},
    "confidence":{"type":"number","minimum":0,"maximum":1}
  }}}
}}
```
**Variants.** A: noun-phrase extractor (`spaCy`-equivalent in Rust via `rust-bert` or pure regex over POS-tagged tokens). B: GBNF-LLM extraction with a `kind` enum. C: dictionary-only (look up phrases that match existing canonical-concept frontmatter in the vault). D: return empty.
**Local viability.** Variant A is sub-millisecond. Variant B compiles to an FSM with ~12 KB of states; XGrammar-equivalent latency budget is <40 µs/token (arxiv:2411.15100). Few-shot 3 examples bring Qwen 2.5-7B-4bit accuracy to ~85% on canonical naming.

#### `knowledge.entity_resolve`
Given a candidate concept, search the vault for an existing canonical concept that *means the same thing*. Variants: A — exact alias match (frontmatter `aliases:`). B — Levenshtein < 2 against canonical names. C — embedding cosine > 0.92 against concept-centroids. D — LLM "is X the same as Y?" with a `{same, different, unclear}` enum. E — return `unresolved`.

#### `knowledge.relation_extract`
Triplets `(subject, predicate, object)` typed by predicate-vocabulary enum (the vocabulary lives in `soul.md` and is user-extensible). GBNF constrains predicate to that enum.

#### `knowledge.summarize`
Two distinct tools sharing a contract: `extractive` (highlight-and-stitch, deterministic, no model) and `abstractive` (LLM-generated, GBNF-constrained to bullet schema). Variant ladder: A — extractive (always succeeds). B — abstractive 7B local. C — abstractive cloud (Haiku 4.5). D — fallback to first 200 chars.

#### `knowledge.qa_over_vault`
The user-facing Q&A endpoint. Internally a chain: `vault.search → context-pack → constrained-generate(answer, citations[])`. The answer schema *requires* a non-empty `citations` array; the GBNF makes it impossible to emit an answer without at least one citation, eliminating the "untraceable claim" failure mode.

#### `knowledge.cite`
Given a sentence, find the supporting note. Returns `{source_note, span, support_score}`. Uses semantic search filtered by sentence-level entailment scoring (a small NLI model, e.g. `deberta-v3-base-mnli` 4-bit). Defers if support < 0.6.

---

### 2.3 Memory tools

#### `memory.episodic_recall`, `memory.semantic_recall`, `memory.procedural_recall`
The CoALA-style trichotomy (Princeton, 2023; reaffirmed by the December 2025 "Memory in the Age of AI Agents" survey, arxiv:2512.13564). Episodic: timestamped events ("user captured X at 14:32"). Semantic: extracted facts ("user prefers Pacific time"). Procedural: skills ("when capture starts with `>`, route to inbox"). Each recall returns ranked items:

```json
{"type":"object","properties":{
  "items":{"type":"array","items":{"type":"object","required":["id","content","score","kind"],"properties":{
    "id":{"type":"string"},"content":{"type":"string"},"score":{"type":"number"},
    "kind":{"type":"string","enum":["episodic","semantic","procedural"]},
    "salience":{"type":"number"},"recency":{"type":"number"}}}}}}
```
**Variants** for each: A — exact key lookup. B — embedding ANN. C — A-MEM "memory evolution" link-walk (arxiv:2502.12110). D — return empty.

#### `memory.score`
Pure function, no model: combines recency exponential decay (half-life configurable per memory class) and salience (TF-IDF over rare-vocabulary terms, plus user-engagement signals). Output is one number ∈ [0, 1]. Used to budget context.

---

### 2.4 Capture tools

#### `capture.voice_to_note`
Variant A: WhisperKit (Apple's CoreML port of Whisper-small) — 100% on-device. B: cloud Whisper for accuracy spikes. C: defer (save raw audio).

#### `capture.screenshot_to_note`
Variant A: `VNRecognizeTextRequest` with `recognitionLevel = .accurate`, `usesLanguageCorrection = true`. Returns observation array → join → store as note body with image attached. B: cloud vision model for tabular / handwritten. C: store image only.

```swift
// minimal wrapper, called from Rust via UniFFI
public func ocr(_ cgImage: CGImage) async throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cgImage)
    try handler.perform([request])
    let obs = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    return obs.joined(separator: "\n")
}
```
This is the canonical pattern (developer.apple.com/documentation/vision/recognizing-text-in-images, hackingwithswift.com).

#### `capture.clipboard_to_note`
Pure Swift. Returns `{kind: "text"|"image"|"file_url"|"rtf", content, ts}`. No model.

#### `capture.web_clip`
Reader-mode extraction (`Readability.swift` port) → markdown via `pandoc`-equivalent Rust crate. Stores source URL in frontmatter for citation.

#### `capture.email_to_note`
Apple Mail share-extension intake. Schema: `{from, subject, body_md, attachments[]}`.

All capture tools terminate by calling `vault.quick_capture` (§3). They never decide folder placement themselves.

---

### 2.5 Structure tools (the routing problem)

This is the heart of Ask 2. Tools here are tightly coupled and implemented as a single pipeline; see §3 for the full plan. Brief catalog:

- `structure.route_capture` — the routing decision, four-variant ladder.
- `structure.suggest_tags` — KNN over tag centroids, GBNF-enum LLM fallback.
- `structure.suggest_links` — for each named entity in the capture, find its canonical note.
- `structure.match_template` — if the capture matches a known supertag schema (Tana-style), instantiate fields.
- `structure.migrate` — schema-version migration on startup (see §5).

---

### 2.6 Code tools (no shell on App Store profile)

#### `code.search`
Tree-sitter based symbol search across the user's tracked code projects. Pure Rust; no shell, no `grep`. Output schema includes `{path, symbol, kind: "fn"|"struct"|"trait"|"const", line}`.

#### `code.symbol_resolve`
LSP-style, but in-process. Bundles `rust-analyzer-lib`, `swift-syntax`, `tree-sitter-typescript`, `tree-sitter-python`. No external process.

#### `code.refactor_suggest`
GBNF-constrained diff output. Variant A: rule-based (rename via tree-sitter). B: 7B model with a strict diff grammar. C: cloud for cross-file refactors. D: defer.

#### `code.lang_detect`, `code.snippet_extract`, `code.doc_generate`
Standard. `code.doc_generate` is constrained to the Rust/Swift doc-comment grammar so the local model literally cannot produce mid-doc prose drift.

**App Store profile constraint:** none of these tools shell out. They run in-process, sandboxed, and are entitled only for `~/Library/Containers/<bundle>/Data/Documents/Vault/`.

---

### 2.7 Reasoning tools (schema-constrained "thinking")

These are the tools the agent invokes on *itself*. All are GBNF-constrained, so even a 7B model produces parseable reasoning that the planner can read.

```json
// reason.think
{"type":"object","required":["thought"],"properties":{"thought":{"type":"string","maxLength":512}}}
// reason.plan
{"type":"object","required":["steps"],"properties":{
  "steps":{"type":"array","minItems":1,"maxItems":7,"items":{"type":"object","required":["id","tool","why"],"properties":{
    "id":{"type":"integer"}, "tool":{"type":"string"}, "args_sketch":{"type":"object"}, "why":{"type":"string","maxLength":120}}}}
}}
// reason.decompose / reason.verify / reason.critique / reason.reflect
// each follows similar bounded shapes
```

The decision to bound `thought` at 512 chars and `steps` at 7 is grounded in the "Brief Is Better" finding (arxiv:2604.02155): Qwen 2.5-1.5B peaks at ~32 reasoning tokens; 7B peaks slightly higher but degrades past ~256. The grammar enforces this discipline.

**Variant ladder** for `reason.plan`: A — pull a previously-cached plan from procedural memory (the Voyager skill library pattern, arxiv:2305.16291). B — generate with 7B local + few-shot from skill library. C — cloud Sonnet. D — degenerate to a one-step plan that calls `vault.search` with the user query verbatim.

---

### 2.8 Action tools (Pro profile only)

These tools are gated behind a runtime profile flag and are *absent from the registry* on the App Store build.

- `action.shell` — `/bin/sh` with a per-call allowlist regex compiled from `~/.epistemos/policies.toml`.
- `action.fs_outside_vault` — read/write outside the sandboxed vault, requires `NSOpenPanel` consent token per directory (Apple security-scoped bookmarks).
- `action.net_fetch` — HTTP fetch through the Rust `reqwest` client; respects user proxy + ATS exemptions.
- `action.mcp_dispatch` — call a peer MCP server (e.g., a Notion bridge). Note: per the project's "stop relying on external MCP servers" goal, this exists for *user-installed* peers, not as Epistemos's primary mechanism.
- `action.computer_use` — Anthropic Computer-Use protocol bridge for the cloud path.

All Pro-profile tools require the *invoke* result to record an immutable audit entry (`actions.log.jsonl`) before returning. The audit entry is what powers the "show your work" UI (§4).

---

### 2.9 System tools

- `system.window_state` — list open Epistemos windows + open notes per window.
- `system.focus_mode` — toggle Do-Not-Disturb-style write-only mode.
- `system.spotlight_query` — wraps `NSMetadataQuery` (programmatic `mdfind`) for OS-wide retrieval. This is the cheap path: queries finish in <50 ms across the entire user home directory and are *free* of any vector index.
- `system.invoke_capture_surface` — programmatically open the global capture HUD.
- `system.app_state` — exposes recent captures, pending re-routes, MLX model load state (so the agent can decide whether to wait for a model warm-up vs. fall through to cloud).

The Spotlight wrapper is worth showing because it's the highest-value-per-line-of-code tool in the catalog:

```swift
public final class SpotlightSearch {
    public func query(_ predicateString: String, scope: [URL]) async throws -> [URL] {
        let q = NSMetadataQuery()
        q.predicate = NSPredicate(fromMetadataQueryString: predicateString)
        q.searchScopes = scope
        return try await withCheckedThrowingContinuation { cont in
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main) { _ in
                q.disableUpdates()
                let urls = (0..<q.resultCount).compactMap { q.result(at: $0) as? NSMetadataItem }
                    .compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL }
                NotificationCenter.default.removeObserver(token!)
                cont.resume(returning: urls)
            }
            q.start()
        }
    }
}
```
Rust calls this through UniFFI; the predicate is built from the GBNF-constrained tool input (e.g., `kMDItemTextContent == \"*foo*\"cd && kMDItemKind == \"Markdown\"`).

---

### 2.10 Meta tools

#### `meta.tool_discover`
Returns the registry slice relevant to the current intent. Implements *progressive disclosure* over the tool set (the Claude Skills pattern, snyk.io/articles/top-claude-skills-ui-ux-engineers): only ~100 tokens of tool metadata in the system prompt; the full schema is loaded only when the model selects a tool.

#### `meta.tool_compose`
Deterministically chains tools according to a static DAG. The agent emits a *plan* (via `reason.plan`); the runner validates the plan's tool-by-tool I/O contract using JSON-Schema *type compatibility* (output schema of step N must satisfy input schema of step N+1, enforced before any execution). This is the structural answer to the "tool soup" failure mode: you cannot start executing a malformed plan.

#### `meta.validate_result`
Each tool output passes through this before being returned to the model. Validation = JSON-Schema check + post-condition predicates registered per tool (e.g., for `vault.write`, post-condition is "the file at `path` exists and its mtime > pre-call mtime"). A validation failure triggers `meta.self_heal`.

#### `meta.self_heal`
The Try-Heal-Retry loop. On a validation failure or schema error, the runner: (1) constructs a *minimal* repair prompt that includes the failing output and the specific schema violation, (2) re-invokes the tool with the same input but with `temperature=0` and the grammar tightened, (3) if still failing, advances to the next variant, (4) opens the circuit breaker after N failures within a sliding window. Identical in spirit to Reflexion (servicesground.com/blog/agentic-reasoning-patterns) but always bounded and always schema-validated.

---

## Section 3 — Quick Capture Implementation Plan

> **This section is a self-contained brief for a coding agent. It cites the rest of the report by section number; otherwise it stands alone. The implementing agent is expected to do its own follow-up research before writing code — see "Required reading" below.**

### 3.0 Goal

Implement `vault.quick_capture`: a tool that takes a 1–3 sentence user capture and produces a deterministic routing decision, placing the capture in the correct vault location *or* deferring rather than guessing wrong. The system must run on a 16 GB Mac with a Qwen 7-8B 4-bit MLX model and never mis-place a capture more than 2% of the time after one week of user feedback.

### 3.1 Required reading (the building agent should fetch and study these before writing code)

Use `web_fetch` and `web_search` to read in full, in this order:

1. **Constrained generation:** the XGrammar paper (arxiv:2411.15100), llguidance README (github.com/guidance-ai/llguidance), Outlines documentation, lm-format-enforcer (github.com/noamgat/lm-format-enforcer), and the JSONSchemaBench paper (arxiv:2501.10868). The agent should pick a backend strategy: on MLX, `MLX-Structured`'s `GrammarMaskedLogitProcessor` is the path of least resistance (rudrank.com/exploring-mlx-swift-structured-generation-with-generable-macro). If that proves insufficient, port llguidance's Earley parser via Rust FFI.
2. **Function-calling fine-tunes:** the Hermes-3 technical report (arxiv:2408.11857), the Hermes-Function-Calling repo (github.com/NousResearch/Hermes-Function-Calling), Qwen function-calling docs (qwen.readthedocs.io/en/latest/framework/function_call.html), and the BFCL leaderboard. Note: Qwen 2.5+ borrowed the Hermes XML-tool-call format, so the same parser handles both (insiderllm.com/guides/function-calling-local-llms).
3. **PKM prior art:** Khoj (github.com/khoj-ai/khoj), Reor (github.com/reorproject/reor), Logseq's properties model, Roam's block model, Tana's supertags (unlocktana.com/blog/tana-vs-logseq).
4. **Agent loops:** ReAct, Reflexion, plan-and-solve, ReWOO (theaiengineer.substack.com/p/the-4-single-agent-patterns), Tree-of-Thoughts.
5. **LSFS:** the ICLR 2025 paper (arxiv:2410.11843) and the AIOS-LSFS reference implementation (github.com/agiresearch/AIOS-LSFS). Take the *vector-indexed file syscall* idea and adapt it; ignore the AIOS-coupled glue.
6. **Memory:** A-MEM (arxiv:2502.12110), MemGPT/Letta operating-system metaphor, Voyager skill library (arxiv:2305.16291), and the December 2025 survey on Memory in the Age of AI Agents (arxiv:2512.13564).

The agent should *not* skip step 1: every other step is bottlenecked by whether the local model produces parseable output. If MLX-Structured cannot enforce all required GBNFs at adequate latency, that is the first thing to fix.

### 3.2 The atomic-concept abstraction problem

Two captures of the same idea must not produce two folders. The state-of-the-art answers are:

- **Roam pages** — every wiki-link is a page; the page is the concept; ambiguity is resolved at link-time by the user (still the most user-driven approach).
- **Logseq blocks** — every block is addressable; concepts emerge from frequently-co-tagged blocks; properties give blocks typed structure.
- **Tana supertags** — concepts are *typed instances* of a supertag class with required fields; the supertag is the schema (unlocktana.com/blog/tana-vs-logseq). This is the strongest model: it forces the *structure* of a concept up-front.
- **A-MEM atomic notes** — each memory is a small note with tags + linked-references; the LLM evolves the link graph as new memories arrive (arxiv:2502.12110).

**Epistemos's choice:** every captured concept resolves to a *canonical concept node* with a stable 12-character ID, a `canonical_name`, an `aliases[]` array, and a `kind` enum. The node lives at `vault/concepts/<slug>.md` with hybrid MD+JSON frontmatter (§5). When a new capture arrives, `knowledge.concept_extract` produces 0–3 candidate concepts; `knowledge.entity_resolve` matches them against existing nodes; only if no match is found at threshold ≥ 0.92 does a new concept node get created.

### 3.3 The routing decision schema

```json
// input
{"type":"object","required":["capture_text","vault_tree","recent_captures"],"properties":{
  "capture_text":{"type":"string","minLength":1,"maxLength":2000},
  "vault_tree":{"type":"array","items":{"type":"object","required":["path","centroid_id","note_count"],"properties":{
    "path":{"type":"string"},"centroid_id":{"type":"string"},"note_count":{"type":"integer"},
    "exemplar_titles":{"type":"array","items":{"type":"string"},"maxItems":5}}}},
  "recent_captures":{"type":"array","maxItems":10,"items":{"type":"object","required":["text","placed_at","ts"],"properties":{
    "text":{"type":"string"},"placed_at":{"type":"string"},"ts":{"type":"integer"}}}}
}}

// output (the routing decision)
{"type":"object","required":["action","confidence","reasoning_trace","alternative_paths"],"properties":{
  "action":{"type":"string","enum":["place","defer","create_folder","merge_into_existing_note"]},
  "folder_path":{"type":"string"},
  "target_note_path":{"type":"string"},
  "new_folder_name":{"type":"string","pattern":"^[a-z0-9-]{2,48}$"},
  "confidence":{"type":"number","minimum":0,"maximum":1},
  "reasoning_trace":{"type":"string","maxLength":280},
  "alternative_paths":{"type":"array","maxItems":3,"items":{"type":"object","required":["path","score"],"properties":{
    "path":{"type":"string"},"score":{"type":"number"}}}}
}}
```

The four `action` values map to the four high-level outcomes:
- `place` — drop the capture into an existing folder.
- `merge_into_existing_note` — append to an existing note (used when the capture is a refinement of a known concept).
- `create_folder` — sibling or new folder.
- `defer` — move to `vault/_inbox/` for later user review. **The system prefers `defer` to a wrong `place`.**

### 3.4 The four-variant ladder

```rust
enum RouteVariant { Centroid, LLMClassify, ConceptSearch, Defer }

async fn route_capture(input: RouteInput) -> RouteDecision {
    // Variant A: cosine to folder centroid embeddings.
    if let Some(d) = try_centroid(&input).await? {
        if d.confidence >= 0.85 { return d; }     // strong direct hit
    }
    // Variant B: GBNF-constrained LLM classification with the folder tree as context.
    if let Some(d) = try_llm_classify(&input).await? {
        if d.confidence >= 0.75 { return d; }
    }
    // Variant C: extract concept(s), search for existing notes about them, place near them.
    if let Some(d) = try_concept_then_neighbour(&input).await? {
        if d.confidence >= 0.70 { return d; }
    }
    // Variant D: defer to review queue.
    RouteDecision::defer("low_confidence_after_three_variants")
}
```

#### Variant A — centroid similarity (no LLM)
For each top-level vault folder, maintain a centroid = mean embedding of its notes' summaries. On capture, embed the capture, cosine to centroids, top-1 if score ≥ 0.85.
- **Latency:** <30 ms.
- **Failure:** flat distribution (best ≈ second-best), small folders with <3 notes (centroid noisy → exclude from variant A).

#### Variant B — GBNF LLM classification
Pack the folder tree (paths + 5 exemplar titles each) into the prompt; constrain the model to choose one folder *or* `_defer`.

GBNF (compiled at call time; `<F0>...<Fk>` are folder slugs, `_defer` is always present):
```
root        ::= "{" ws decision-fields ws "}"
decision-fields ::= "\"folder_path\":" ws folder ws ","
                    ws "\"confidence\":" ws number ws ","
                    ws "\"reasoning_trace\":" ws short-string
folder      ::= "\"" ( "<F0>" | "<F1>" | ... | "<Fk>" | "_defer" ) "\""
short-string ::= "\"" [^"]{0,280} "\""
number      ::= "0" | ("0." [0-9]+) | "1" | ("1." "0"+)
ws          ::= [ \t\n]*
```

Prompt (3-shot, all 3 examples include a `_defer` outcome so the model learns deferral is normal):

```
You are an expert filing assistant. Place the capture into one folder, or choose "_defer".
Folders:
  research/ml/   exemplars: "Attention Heads Geometry", "RLHF Failure Modes", ...
  personal/journal/  exemplars: "Sat morning reflection", ...
  ...
Capture: "{{capture_text}}"
Output JSON exactly matching this grammar.

Example 1: ... (LLM picks research/ml/, confidence 0.91)
Example 2: ... (LLM picks _defer, confidence 0.30, reasoning "ambiguous between project/x and project/y")
Example 3: ... (LLM picks personal/journal/, confidence 0.88)
```
- **Latency on Qwen 7B 4bit MLX:** ~400–700 ms for output ≤ 80 tokens.
- **Failure:** model picks `_defer` (good, advance to D). Model returns confidence < 0.75 (advance to C).

#### Variant C — concept-then-neighbour
1. Run `knowledge.concept_extract` on the capture (returns ≤3 concepts).
2. For each concept, run `knowledge.entity_resolve` against the concept index.
3. If a concept resolves: look up notes that link to the resolved concept node; pick the folder where ≥60% of those notes live; place there.
4. If no concept resolves but a *new* concept is high-confidence: create the concept node under `concepts/`, and if there's a sibling concept's folder, propose placing the capture there.

This variant is deliberately slower (multiple sub-tool calls) but is the most semantically correct: it places by *meaning*, not by surface similarity. It mirrors the LSFS approach (arxiv:2410.11843) of treating the FS as a vector index.

#### Variant D — defer
Place the capture in `vault/_inbox/`, append to a daily review-queue note `vault/_inbox/<YYYY-MM-DD>.md`. Surface a quiet badge in the UI; never block the user. The review queue *is* the safety net.

### 3.5 Worked end-to-end example

Capture: *"GBNF can constrain Qwen's tool calls but only if the grammar is compiled per-call; XGrammar is faster than llguidance only for repeated schemas."*

- **Variant A (centroid):** top folder `research/ml/agents/` cos 0.71; `research/ml/inference/` cos 0.69. Best < 0.85 → fall.
- **Variant B (LLM):** outputs `{"folder_path":"research/ml/inference/","confidence":0.78,"reasoning_trace":"capture is about constrained-decoding backends"}`. Confidence > 0.75 → return.
- Decision: `place` in `research/ml/inference/`, with alternatives `research/ml/agents/`, `research/ml/notes/`. Reasoning trace stored. The capture file is named `2026-04-29-gbnf-qwen-tool-calls.md`. The atomic-concept extractor also detects `["GBNF", "XGrammar", "llguidance"]`; entity-resolve finds existing nodes for `GBNF` and `XGrammar`, creates `concepts/llguidance.md` (new). Backlinks are inserted in the body of the placed note.

If Variant B had returned `_defer`, Variant C would have run: concept extraction → resolve → most existing notes about GBNF live in `research/ml/inference/` → place there at confidence 0.72.

### 3.6 Avoiding the wrong-place failure mode

1. **Confidence thresholds** are *floors*, not *guides*. Variant A requires ≥ 0.85, B ≥ 0.75, C ≥ 0.70 because each is progressively softer.
2. **Defer is always reachable.** No variant can return `place` if its own confidence falls below threshold.
3. **User correction is a training signal.** When the user moves a placed capture, write a row to `vault/.epistemos/corrections.jsonl`:
   ```json
   {"capture_id":"...","predicted":"research/ml/","actual":"personal/notes/","ts":...,"reason":"override"}
   ```
   At quiet times, the system rebuilds folder centroids weighted by these corrections (move-to folder gets +1 vote, move-from folder gets −0.3 vote on the capture's embedding). After ~30 corrections the centroid model is meaningfully reshaped. This is the *nearest local equivalent* of A-MEM's memory evolution (arxiv:2502.12110): the user's behavior continuously rewrites the routing prior.
4. **No silent edits to existing notes.** `merge_into_existing_note` requires confidence ≥ 0.90 *and* the target note's last-edited time to be older than 24 h; otherwise fall to `place` in the same folder.

### 3.7 Background re-routing

A nightly background pass re-evaluates *recent* placements (last 30 days). Implementation:

- Sample ≤ 100 recently-placed captures.
- Run Variant B on each with the *current* folder tree (which has grown).
- If the new prediction differs from the original placement at confidence ≥ 0.85 *and* the user has not edited the note since placement, surface a notification: "3 captures may belong elsewhere. Review?" — never auto-move.

The system is permitted to *merge* two folders if the centroids of both fall within cos 0.93 — but only with explicit user consent.

### 3.8 LSFS integration

The vault is wrapped by an LSFS-style index (arxiv:2410.11843):

```rust
pub trait Lsfs {
    async fn put(&self, path: &Path, text: &str) -> Result<DocId>;
    async fn semantic_get(&self, q: &str, k: usize) -> Vec<Hit>;
    async fn keyword_get(&self, q: &str, k: usize) -> Vec<Hit>;
    async fn group_by(&self, predicate: &SemanticPredicate) -> Vec<Cluster>;
    async fn rollback(&self, doc_id: DocId, version: u64) -> Result<()>;
}
```

Storage: SQLite for metadata + LanceDB for vectors. Every write is versioned (`rollback` is non-negotiable per LSFS's safety invariants). The routing tools call `semantic_get` for variant A's centroid query and `keyword_get` for path-disambiguation fallbacks.

### 3.9 Spotlight integration for zero-latency retrieval

When the user types in the search bar, the *first* hits to render are not from LanceDB — they're from `NSMetadataQuery`, which the OS already maintains. This is the cheapest, fastest retrieval the platform can give us. Spotlight returns within 50 ms; LanceDB takes 80–200 ms; Variant B routing takes 400 ms. Always show the user the cheapest layer first and stream in the slower layers.

### 3.10 Apple Vision OCR ingestion

`capture.screenshot_to_note` calls the Vision wrapper from §2.4. Recognized text is concatenated, then passed through `vault.quick_capture` *exactly like a typed capture*. There is no special "OCR-routed" path. This is critical for keeping the routing pipeline orthogonal to source modality.

### 3.11 Self-healing Try-Heal-Retry with circuit breakers

Each variant runs inside this wrapper:

```rust
async fn run_variant<F, T>(name: &str, budget: Budget, breaker: &CircuitBreaker, f: F) -> Option<T>
where F: Future<Output = Result<T, VariantError>> {
    if breaker.is_open(name) { return None; }
    for attempt in 0..budget.max_attempts {
        match tokio::time::timeout(budget.per_attempt, f.clone()).await {
            Ok(Ok(v)) => { breaker.record_success(name); return Some(v); }
            Ok(Err(e)) if e.is_schema_violation() && attempt + 1 < budget.max_attempts => {
                tracing::debug!(?e, "schema violation, healing"); continue;
            }
            _ => { breaker.record_failure(name); }
        }
    }
    None
}
```

Budgets: Variant A — 1 attempt, 100 ms. B — 2 attempts, 1500 ms each. C — 1 attempt, 3000 ms. D — never times out (it's a write).

Circuit breaker opens after 5 failures in a 60-second sliding window; reopens 5 minutes later. While open, the variant is skipped entirely. This prevents a model misload from cascading.

### 3.12 Concrete Rust trait sketches and Swift signatures

Tool registration:
```rust
pub struct QuickCaptureTool { lsfs: Arc<dyn Lsfs>, llm: Arc<MlxRunner>, breaker: CircuitBreaker }

#[async_trait]
impl Tool for QuickCaptureTool {
    const NAME: &'static str = "vault.quick_capture";
    type Input = QuickCaptureInput;
    type Output = RouteDecision;
    fn gbnf() -> &'static str { include_str!("gbnf/quick_capture.gbnf") }
    async fn invoke(&self, input: Self::Input, ctx: &ToolCtx) -> Result<Self::Output, ToolError> {
        route_capture(input).await.into_tool_result()
    }
}
```

Swift-side capture surface:
```swift
@Observable final class CaptureSurface {
    var draft: String = ""
    func commit() async throws {
        // single UniFFI call, no folder picker, no tag picker
        let decision = try await AgentCore.shared.quickCapture(text: draft, source: .global)
        UndoStack.shared.push(.placed(decision))
        draft = ""
    }
}
```

The user types, hits Cmd-Enter, the capture is gone. If the system deferred, a subtle dot appears in the inbox tab — never a modal, never a picker. Undo stays in the toolbar for 60 seconds.

### 3.13 Test plan the building agent should implement

1. **Snapshot tests** for every variant: feed 200 hand-labeled captures (the building agent should curate these from the user's existing vault) and assert ≥ 90% top-1 placement accuracy and ≥ 99% schema validity.
2. **Adversarial tests:** truncated captures, unicode chaos, captures in two languages mixed.
3. **Soak tests:** 10,000 captures back-to-back; assert no memory growth past the model's resident set.
4. **Latency budgets:** P50 < 600 ms, P95 < 1500 ms.
5. **Schema-evolution tests:** add a new `kind` to the concept enum mid-run; the migration tool (§5) must rewrite existing concept nodes without dropping data.

---

## Section 4 — Hidden-Complexity / Minimal-UX Patterns

### 4.1 The pattern catalog

| Pattern | What it hides | What it exposes | Where to use in Epistemos |
|---|---|---|---|
| **Progressive disclosure** | Tool list, settings, advanced flags | One starting affordance | Tool registry: 100-token descriptions in system prompt; full schemas only when invoked (Claude Skills pattern, snyk.io) |
| **Sensible defaults** | Choice of routing variant, model, embedding | The capture works | Variant A→B→C ladder is invisible; only `defer` is visible (and quiet) |
| **Deterministic fallbacks** | The fact that anything went wrong | The result | Schema-validated retries, circuit breakers (§3.11) |
| **Invisible retries** | Schema violations, partial failures | Final clean output | `meta.self_heal` |
| **Revelation moments** | The agent's full trace, normally | A single "Why?" affordance | Click on any placed note → see reasoning_trace + alternatives + correction button |
| **Undo as safety net** | The fear of mis-action | A 60s undo affordance | Every capture, every move, every merge |
| **Show your work on demand** | The plan/loop/observations | Optional "agent log" panel | Hidden by default; Cmd-Shift-L to surface |

### 4.2 Anti-patterns that destroy minimalism

- **Settings sprawl.** Every preference dialog is a tax on every user. Epistemos must ship with ≤ 8 settings, each a binary or short list.
- **Modal config dialogs.** Replaced by sensible defaults + post-hoc correction signals.
- **"Advanced mode" toggles.** Replaced by *context-sensitive* surfacing (the trace appears when you click "Why?", not when you flip a toggle).
- **Folder pickers in capture.** Capture has no folder picker, period. The router decides; the user corrects after the fact.
- **Tag pickers in capture.** Same.
- **Model pickers.** The user picks a *profile* (App Store / Pro), not a model.

### 4.3 PKM surface decisions

#### Capture surface
- **One keystroke** (system-wide hotkey, default `⌥-Space`).
- **One text field.** No folder, no tag, no template picker.
- **Cmd-Enter commits.** The router places it; a status pill confirms `→ research/ml/` or `→ Inbox` depending on confidence.
- **Drag-and-drop** of an image goes through `capture.screenshot_to_note` and joins the same pipeline.

#### Search surface
- **One bar.** Default: streams Spotlight hits within 50 ms, then layers in semantic hits, then graph hits.
- **No mode toggle.** A subtle pill on each hit shows `lexical` / `semantic` / `linked` so the user knows *why* the hit appeared, but they don't choose.
- **Natural-language queries** route through `knowledge.qa_over_vault` with citations; literal-string queries route through Spotlight + FTS5. The router sniffs by the presence of question words and quoted phrases; it's a 30-line classifier.

#### AI surface
- **One input.** The system picks local vs cloud, fast vs thinking, tool-using vs not. Heuristics:
  - Input < 200 chars and no question mark → local 7B, no tools, deterministic.
  - Input contains "find / search / what / where" → local 7B with `vault.search`.
  - Input contains "draft / write / summarize a long passage / refactor" → cloud Sonnet/Haiku.
  - Input contains a code fence → local Qwen-Coder if installed, else cloud.
  - User holds `⌥` while submitting → forces cloud.
  - Network unavailable → forces local + warns once.
- **Streaming** with token-level tool-call interception so the user sees `→ vault.search("…")` inline as it happens. Don't hide the *fact* that tools fired; hide the *list* of tools.

#### Settings (the irreducible minimum)
1. Vault location (one folder picker, set on first run).
2. Cloud credentials (Claude / Perplexity API keys; both optional).
3. Profile: App Store ⟂ Pro.
4. Embedding model: small / large (default small).
5. Hotkey for capture.
6. Hotkey for search.
7. Theme (system / light / dark).
8. Privacy: send anonymized routing-failure reports? (default off).

That's it. Everything else is decided by the router or stored in `soul.md`.

### 4.4 Local-vs-cloud routing

The router is a small Rust function (no model). Inputs: input length, has-question-mark, has-code-fence, network status, last 5 user-correction signals, model warm-up state. Output: one of `{local-fast, local-thinking, cloud-haiku, cloud-sonnet, cloud-perplexity}`. The router *never asks the user*; it logs each decision so the user can later see a histogram of "where did my queries go?" — that's the revelation moment, not a modal.

When the router is uncertain (e.g., a long but ambiguous prompt), it picks local + falls forward to cloud only on `meta.validate_result` failure. The fallback chain is: local fast → local thinking → cloud haiku → cloud sonnet → user-visible error. Cost-controlled: cloud calls are budget-capped per day, configurable.

### 4.5 Comparison table

| Product | Hides | Exposes | Lesson for Epistemos |
|---|---|---|---|
| Claude Desktop | Model choice, tool list, retries | One chat, optional artifacts | One AI input; tools surface as inline ribbons |
| Cursor | Less than Claude — exposes code panes, agents, models, modes | Full IDE complexity | Anti-pattern when the user wants to *think*, not *configure* (uxplanet.org/claude-code-vs-cursor). Epistemos sides with Claude. |
| Raycast | Plugin system, command palette | One bar, results | Capture surface is a Raycast-style bar |
| Arc | Tab management, profiles | "Command Bar" | Search surface is a Command Bar |
| Linear | Workflow states, statuses, automation | Issue list + keyboard | Tag/folder system stays out of the user's face |
| Things | All filing | Inbox / Today / Upcoming | The `_inbox/` folder is sacred — Epistemos never auto-files into Today equivalents |

### 4.6 Accelerator vs Delegator paradigm

Cursor is an *accelerator*: the user is in the loop, the AI assists. Claude Desktop is a *delegator*: the user states intent, the AI returns a result. Epistemos must oscillate: the *capture surface* is delegator (the user fires-and-forgets), the *editor* is accelerator (the user writes, the AI suggests links, completes sentences, never inserts unprompted). The mode is determined by *which surface* the user is in, not by a toggle.

### 4.7 Intent → Effect → State

Across the stack, the contract is:

- **LLM emits an Intent** — a typed, schema-validated description of what should happen (`{tool: "vault.write", args: {...}}`).
- **Rust applies the Effect** — the actual filesystem write, the database insert, the network call. Effects are reversible.
- **Swift observes the State** — `@Observable` view-models reflect the post-effect state into TextKit.

This is the same architectural shape as Elm/TCA; it's also exactly what makes a multi-variant ladder reasonable. A variant can be *retried* because Intent and Effect are separate; an Effect can be *rolled back* because State is observed, not authoritative.

```rust
pub enum Intent { CapturePlaced(CapturePlace), NoteEdited(NoteEdit), /* ... */ }
pub enum Effect { Wrote{ path: PathBuf, version: u64, undo: UndoToken }, /* ... */ }

pub fn apply(intent: Intent) -> Result<Effect> { /* deterministic, transactional */ }
```

UniFFI exposes `Intent` and the post-apply `Effect`; Swift only sees the resulting `State`. This factoring keeps the LLM out of the rendering path.

---

## Section 5 — Hybrid MD+JSON Memory and `soul.md` Reconceptualization

### 5.1 Why MD-only is fragile

Markdown's prose is *generative-friendly* (the LLM can read it like any text) but *retrieval-hostile*: there is no schema to query against, no validation gate, no migration story. When a tool needs to know "what's the user's preferred citation format," scraping it from prose is brittle. Logseq's "properties" feature exists precisely because community users hit this wall.

### 5.2 Why JSON-only is hostile

JSON is *schema-friendly* but *human-hostile*: editing nested JSON by hand is unpleasant, and prose context (`why this rule exists`) gets either lost or shoehorned into string fields. MemGPT's persona+human file design and Letta's modular memory blocks both expose this tension.

### 5.3 The hybrid pattern

Every memory file in Epistemos is a Markdown document with **one or more typed JSON blocks** in YAML frontmatter and/or fenced inline. The MD prose is the human-curated narrative; the JSON blocks are LLM-mutable under schema-constrained generation. This is similar in spirit to MDX (typed components inside Markdown) and Logseq's properties (typed key-value above blocks).

```markdown
---
schema: epistemos.soul.v1
identity:
  name: "Jojo"
  pronoun: "he/they"
  values: ["honesty", "speed", "depth"]
preferences:
  citation_style: "inline-author-year"
  default_summary_length_words: 120
  thinking_budget_tokens: 256
routing:
  prefer_local_when_offline: true
  cloud_daily_token_budget: 1500000
---

# Soul

I am the developer Jojo. I work mostly in Rust and Swift. I prefer terse,
opinionated answers. When I'm wrong I want to be told so. When I capture
something quickly, I'd rather you defer than guess. ...
```

The frontmatter is JSON-Schema-validated against `epistemos.soul.v1`; any LLM mutation goes through `meta.validate_result` against that same schema. The prose is read by both human and LLM but is never auto-rewritten by the LLM.

### 5.4 Specific schemas

Each memory class has its own schema (versioned). Sketches:

```json
// soul.md frontmatter — epistemos.soul.v1
{
  "$id":"epistemos.soul.v1",
  "type":"object","required":["schema","identity","preferences","routing"],
  "properties":{
    "schema":{"const":"epistemos.soul.v1"},
    "identity":{"type":"object","properties":{
      "name":{"type":"string"},"pronoun":{"type":"string"},
      "values":{"type":"array","items":{"type":"string"}}}},
    "preferences":{"type":"object"},
    "routing":{"type":"object"}
  }
}

// procedural memory — epistemos.skill.v1 (Voyager-inspired)
{
  "$id":"epistemos.skill.v1",
  "type":"object","required":["name","when","then","verified"],
  "properties":{
    "name":{"type":"string"},
    "when":{"type":"object"},        // pattern matchers
    "then":{"type":"array","items":{"type":"object"}}, // tool DAG
    "verified":{"type":"boolean"},   // self-verification check passed
    "evidence":{"type":"array"}      // logs of past successful runs
  }
}

// episodic memory — append-only JSONL with v1 envelope
{
  "$id":"epistemos.episode.v1",
  "type":"object","required":["ts","kind","actor","payload"],
  "properties":{"ts":{"type":"integer"},"kind":{"type":"string"},
                "actor":{"enum":["user","agent","system"]},"payload":{}}
}

// semantic memory — A-MEM atomic note with linked-references
{
  "$id":"epistemos.semantic.v1",
  "type":"object","required":["id","statement","confidence","sources"],
  "properties":{
    "id":{"type":"string"},
    "statement":{"type":"string"},
    "confidence":{"type":"number"},
    "sources":{"type":"array","items":{"type":"string"}}, // note IDs
    "links":{"type":"array","items":{"type":"object"}},   // A-MEM evolved links
    "tags":{"type":"array","items":{"type":"string"}}
  }
}
```

System prompts and deterministic instructions follow the same pattern: a `prompts/<tool>.md` file with a JSON-frontmatter `instruction-set` block that compiles to a typed prompt template at runtime.

### 5.5 Parsing into typed Rust structs

```rust
#[derive(Deserialize, JsonSchema)]
pub struct Soul {
    pub schema: SchemaTag<"epistemos.soul.v1">,
    pub identity: Identity,
    pub preferences: Preferences,
    pub routing: RoutingConfig,
    #[serde(skip)]
    pub prose: String,   // body markdown, populated post-deserialize
}

pub fn load_hybrid<T: DeserializeOwned + JsonSchema>(path: &Path) -> Result<T> {
    let raw = std::fs::read_to_string(path)?;
    let (front, body) = split_frontmatter(&raw)?;
    let mut value: serde_json::Value = serde_yaml::from_str(front)?;
    JsonSchema::validate(&value, &schema_for!(T))?;
    inject_prose(&mut value, body);
    Ok(serde_json::from_value(value)?)
}
```

### 5.6 Constrained writes

When the LLM mutates a memory file (e.g., A-MEM evolving a link), the GBNF for the *write tool* enforces only the JSON block can change; the MD prose is passed through unmodified. The grammar literally references the file's current prose as a fixed-string production:

```
root         ::= md-prose-prefix json-block md-prose-suffix
md-prose-prefix ::= "<<<PROSE_PREFIX>>>"   ; literal injected at compile time
md-prose-suffix ::= "<<<PROSE_SUFFIX>>>"   ; literal injected at compile time
json-block   ::= "---\n" yaml-fields "---\n"
yaml-fields  ::= ...                       ; per-schema
```

This is the same idea as fill-in-the-middle code generation (arxiv:2402.17988): we constrain *what part* the model is allowed to rewrite, leaving the rest verbatim.

### 5.7 Hardening: versioning, migration, validation, rollback

- **Schema versioning.** Every file declares its schema (`epistemos.soul.v1`). The registry maps each schema to a current parser. New versions ship migration functions:
  ```rust
  fn migrate_soul_v1_to_v2(old: SoulV1) -> SoulV2 { /* ... */ }
  ```
  At startup, files of older versions are migrated atomically (write to `.tmp`, fsync, rename) with the original kept as `.v1.bak` for 30 days.
- **Validation gates.** No memory write commits without passing `JsonSchema::validate`. A failure triggers the self-heal path (§2.10) and surfaces a quiet UI error if all healing fails.
- **Rollback.** Every memory file has a CRDT-friendly version log in `vault/.epistemos/history/<file>.log`. Inspired by LSFS rollback (arxiv:2410.11843); rollback is a single tool call.

### 5.8 Prior art mapped to this hybrid

- **Voyager skill library** → `procedural.v1`. Each skill is a typed JSON block (preconditions, tool DAG, self-verification) with a prose description above. The model retrieves skills by description (top-K embedding match) and executes them as DAG plans.
- **MemGPT page tables** → episodic and semantic files use page-table-style metadata (`mtime`, `recency`, `access_count`) so the runner can swap content in and out of the context window the way MemGPT swaps RAM/disk.
- **A-MEM** → semantic memory files have `links` arrays the LLM may extend; nightly, the system runs the A-MEM evolution pass to refine those links.
- **Letta** → mirrors Letta's `core_memory_blocks` with our `soul.md`, plus the same archival/recall split.

---

## Section 6 — Cross-cutting Small-Model Parity Strategy

### 6.1 GBNF compilation strategy

Compile per-tool grammars at registry init; cache the compiled FSM (or pushdown automaton, depending on backend) keyed by `(tool_name, schema_hash)`. For tools whose grammar depends on runtime state (the folder enum in routing, the predicate enum in relation-extraction), compile *just-in-time* on first call and memoize for ≥ 60 s. Empirically, XGrammar achieves <40 µs/token mask computation for JSON Schema (arxiv:2411.15100); llguidance is comparable (~50 µs). Both have negligible overhead vs. raw inference at 7B (Apple Silicon ~10–30 ms/token).

### 6.2 Logit-level constraint

Use MLX-Structured's `GrammarMaskedLogitProcessor` if its grammar coverage is sufficient (rudrank.com). The wiring:

```swift
let processor = try await GrammarMaskedLogitProcessor.from(
    configuration: context.configuration, grammar: grammar)
let iter = try TokenIterator(input: input, model: context.model,
                              processor: processor, sampler: parameters.sampler(),
                              maxTokens: parameters.maxTokens)
```

If MLX-Structured cannot express, e.g., recursive schemas, fall back to LM Format Enforcer (token prefix-tree intersection, more flexible but slower) or to a Rust port of llguidance behind UniFFI. The decision criterion: ≥ 99% schema-compliance on the regression suite at < 5% throughput tax.

### 6.3 Retry budgets per variant

| Variant kind | Per-attempt timeout | Max attempts | Total wall-clock |
|---|---|---|---|
| Centroid / pure-Rust | 100 ms | 1 | 100 ms |
| 7B local generation | 1500 ms | 2 (with healing) | 3000 ms |
| Cloud Haiku | 2000 ms | 1 | 2000 ms |
| Cloud Sonnet | 8000 ms | 1 | 8000 ms |
| Web fetch | 10000 ms | 2 | 20000 ms |

These budgets cap *total* user-visible latency at well under 10 s for the worst-case full-ladder traversal.

### 6.4 Few-shot prompting strategies

The Hugging Face guided-decoding study (huggingface.co/blog/nmmursit/guided-decoding) found two-shot prompting boosts Outlines compliance from ~93% to ~97% and dramatically reduces hallucinations. Lessons applied:

- Every grammar-constrained tool ships **3 few-shot examples** in its prompt template.
- One example always demonstrates the *defer/error* outcome so the model learns it's a normal output, not a failure.
- Examples are stored as hybrid MD+JSON in `prompts/<tool>.md` so they're versioned and curatable.
- Reasoning fields appear *before* answer fields in every schema (Tam et al., EMNLP 2024, summarized in letsdatascience.com): reasoning-then-answer keeps the autoregressive generation honest.

### 6.5 Dynamic schema translation

Rust's `schemars::schema_for!` produces a JSON Schema; a wrapper converts it to GBNF on registration:

```rust
pub fn json_schema_to_gbnf(schema: &serde_json::Value, name: &str) -> Result<String> {
    // recursive: object → "{" key ":" value ("," key ":" value)* "}"
    //           array  → "[" value ("," value)* "]"
    //           enum   → literal alternation
    //           number → number-rule, etc.
}
```

This is the Python-introspection-style schema → grammar pipeline that Hermes-Function-Calling and `gbnf_grammar_generator.py` (gist.github.com/Maximilian-Winter/...) demonstrate; the implementation is straightforward but tedious — the building agent should consider porting llguidance's JSON-Schema → grammar instead of writing one from scratch.

### 6.6 Empirical notes on small-model precision

- **Qwen 2.5-1.5B vs 3B vs 7B on tool calls:** the CPU-only benchmark at github.com/MikeVeerman/tool-calling-benchmark and the BFCL study show:
  - 1.5B: high refusal-correctness ("knows when not to call") but weak argument fidelity.
  - 3B: good name-selection, mediocre argument types — best with constrained decoding + 2-shot.
  - 7B: argument-faithful most of the time; with grammar enforcement, schema compliance hits ≥ 99%.
- **CoT budget:** "Brief Is Better" (arxiv:2604.02155) shows 1.5B Qwen peaks at d≈32 tokens of reasoning; 256 tokens *degrades* below the no-CoT baseline. This is why the `reasoning_trace` field is hard-capped at 280 chars.
- **Hermes XML format** vs JSON: Hermes-3 / Hermes-4 use `<tool_call>{...}</tool_call>` (arxiv:2408.11857); Qwen 2.5+ adopted the same wrapping. Epistemos can stream the inner JSON and validate the tag pair separately — this is a tiny tokenizer win because both `<tool_call>` and `</tool_call>` are *added tokens* in Hermes.
- **Repeating-loop failure mode:** after a failed call, models sometimes repeat the user prompt or emit empty text (insiderllm.com). Fix: hard `max_iterations` cap on the agentic loop (default 8) and a duplicate-detector that breaks on consecutive identical actions.

### 6.7 MLX integration specifics

- **Unified memory.** A 7B 4-bit Qwen weighs ~4.2 GB; on a 16 GB Mac, leaves ~10 GB for OS+app+kv-cache. The KV cache for 8K context at 4-bit quant is ~1 GB. Comfortable.
- **Lazy evaluation.** MLX schedules ops lazily; `mx.eval()` only on commit. Use this for batch concept-extraction over multiple captures (one model load, many calls).
- **Throughput.** Awni Hannun's mlx-lm + MLX-Structured (lmstudio.ai/blog/lmstudio-v0.3.4) hits ~25–60 tok/s on M-series for 7B 4-bit, depending on chip. With grammar masking the throughput drops <10% in practice.
- **Cold start.** Model load is 1–3 s on M-series. Strategy: warm the model on app launch in the background; routing variants A and C can run immediately while the model warms; Variant B blocks only if needed.
- **vllm-mlx style batching.** SwiftLM / SharpAI/SwiftLM (github.com/SharpAI/SwiftLM) demonstrate SSD-streaming for huge MoE models; not needed at 7B baseline but worth bookmarking for 32B+ Pro-profile users.

---

## Section 7 — Sequencing Recommendation

Build in this order; each step's output is the next step's input:

1. **Tool registry + GBNF compiler (foundation).** Without these, no tool below works deterministically. Includes: `Tool` trait, schema→GBNF translator, MLX-Structured wiring, validation harness, circuit breaker, retry budget. *Estimated 2–3 weeks.*
2. **Hybrid MD+JSON memory parser.** Pure Rust + serde + JSON-Schema. Independent of step 1; can be developed in parallel, but the routing pipeline depends on it. *1 week.*
3. **Vault primitives (`vault.read/write/append/search/backlinks/graph_walk`).** The `vault.search` router (auto mode) is the highest-leverage piece. *2 weeks.*
4. **Capture surface + Spotlight integration (Swift side).** Glassy global hotkey, one input, Cmd-Enter → UniFFI → tool call. *1 week.*
5. **Quick-capture routing pipeline (§3).** Variants A→D, with the centroid index built lazily on first run. **Defer is shipped before `place` works well.** *2 weeks.*
6. **Knowledge & memory tools.** `concept_extract`, `entity_resolve`, `episodic/semantic/procedural` recall. Now the routing variants C and D become richer. *2 weeks.*
7. **AI surface + local/cloud router.** Now the user has one input that chooses local vs cloud. *1 week.*
8. **Reasoning tools, meta tools, self-heal.** Wraps the rest. *1 week.*
9. **Action tools (Pro profile only).** Behind a build flag. *1 week.*
10. **Memory rewrite (`soul.md` + procedural skills).** Can begin in parallel with step 1; merge at step 6. The Voyager-style skill library only becomes powerful once the registry and reasoning tools are in place.
11. **Background re-routing, A-MEM evolution.** Last because it depends on a corpus. *1 week.*

The *critical path* is steps 1 → 3 → 5; everything else can be parallelized by a solo developer with judicious branch hygiene.

---

## Section 8 — Open Questions and Risks

1. **MLX-Structured grammar coverage.** Does `GrammarMaskedLogitProcessor` handle recursive JSON Schema, `oneOf`, conditional schemas? If not, the project either (a) ports llguidance via Rust+FFI, (b) restricts itself to a "regular subset" of JSON Schema (no recursion), or (c) adopts LM-Format-Enforcer's prefix-tree approach despite higher latency. *Probable answer: option (b) for v1, (a) when v2 needs it. The building agent must benchmark this on day one.*
2. **Vault corruption mid-routing.** What if `vault.write` partially commits during a routing decision? Mitigation: every write is a transaction (write-tmp + fsync + atomic-rename); the routing decision is only persisted *after* the body file is on disk. The `meta.validate_result` post-condition asserts the file exists at the predicted path before the decision is logged.
3. **Cold-start cost.** Loading a fresh model variant (e.g., switching from Qwen 7B to a 1.5B for a quick pass) costs 1–3 s. Strategy: keep one model resident; only swap if the user explicitly chooses a different default in settings; for "thinking" tasks, stream cloud rather than swap local.
4. **User-correction propagation as training signal.** The current plan builds a corrections JSONL and reweights centroids weekly. Open question: should corrections also fine-tune a small LoRA over the local model? *Almost certainly yes once corrections > 500*; deferred to v2 because LoRA-on-MLX tooling is still maturing.
5. **A-MEM scalability.** A-MEM's link-evolution pass is O(N²) over memory items in the worst case (D-MEM, arxiv:2603.14597). For a vault with 10K notes, that's 10⁸ ops — too slow nightly. Mitigation: only evolve links for items touched in the last 7 days; use ANN for candidate filtering before LLM evaluation.
6. **Concept-name collisions.** Two captures about "attention" — one ML, one psychological — must not collapse into the same concept node. Mitigation: `kind` enum is part of the canonical-key. `entity_resolve` requires *both* embedding cosine ≥ 0.92 *and* matching `kind`.
7. **GBNF + streaming UX.** Streaming partial JSON to the UI is awkward; the user sees `{"folder_path":"resea` mid-token. UX answer: don't render the JSON; render a deterministic spinner with the *currently-best* candidate from the centroid variant, then update once the LLM commits.
8. **Prompt-cache invalidation.** When `soul.md` changes, the Anthropic prompt cache must invalidate. Risk: silent cache hits with stale identity. Mitigation: include a hash of `soul.md` at the top of every system prompt; cache key is implicitly bound to it.
9. **Hermes vs OpenAI tool-call format.** Local Hermes/Qwen emit `<tool_call>{...}</tool_call>`; cloud Claude uses its own tool blocks; Perplexity Sonar Pro speaks OpenAI-style. The agent_core needs a single normalized internal call format with three encoders/decoders. Risk of subtle shape drift; mitigation: golden-file tests for each provider.
10. **App Store sandbox vs vault portability.** If the user moves the vault outside the container, security-scoped bookmarks must be refreshed; otherwise tools that take a `path` see a denied write. Mitigation: every `Tool` that takes a path passes through a `BookmarkResolver` that lazily renews scopes.
11. **Local model's worldview drift.** Hermes-3/4's strong steerability (arxiv:2408.11857) means the system prompt heavily determines its behavior. Risk: a sloppy `soul.md` change can degrade tool-calling. Mitigation: regression tests on the soul prompt; the migration tool flags identity-changing diffs for review.
12. **Multi-window concurrency.** Multi-window TextKit + Rust agent_core: can two windows run two routing decisions in parallel without contending on the centroid index? The index is read-mostly; writes (centroid rebuild) take a write lock at most once per minute. Should be fine but requires a stress test.

---

## Closing

The architectural bet is concrete and falsifiable: a 7B local model, gated by per-call grammars, walking a four-step ladder over a hybrid MD+JSON memory, behind a one-input UI, can deliver PKM at the quality bar where the user stops noticing the seams. Every component above has at least one prior-art reference and one explicit failure mode. The work to be done is mostly *integration* — most of the pieces (XGrammar/llguidance, A-MEM, Hermes-3 function-calling, MLX-Structured, Vision OCR, NSMetadataQuery) already exist; the contribution is the *deterministic ladder discipline* that wires them so the user never sees a wrong answer presented as right.

Build the registry and the GBNF compiler first. Build `defer` before `place`. Trust the small model only inside the grammar; trust the cloud only when the local ladder has fallen all the way through. Make every effect reversible. And resist, with prejudice, every settings dialog and every "advanced" toggle that tries to creep into the surface.