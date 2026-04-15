# BoltFFI Hot-Path Migration Audit

Date: 2026-04-15
Phase: 7, Step 8
Status: **audit inventory only — no migrations in this phase**
Authority: `docs/architecture/PLAN_V2.md` §22

## 0. Scope And Non-Goals

This document inventories every Swift ↔ Rust boundary currently in the
Epistemos codebase, classifies each surface against the PLAN_V2 §22
taxonomy, and picks the first migration candidate for a future
performance-driven slice.

### What this audit does

- Inventory every FFI surface, grouped by transport (C FFI header, UniFFI,
  JSON-over-FFI, shared-memory, XPC/process, Swift-only hot-paths).
- Classify each as one of:
  `keep_uniffi`, `boltffi_candidate`, `boltffi_priority`,
  `shared_memory_candidate`, `xpc_or_process_boundary`, `defer_no_measured_gain`.
- Note payload shape, call frequency, and user-visible symptom where known.
- Identify the first migration candidate.

### What this audit does NOT do

- **No migrations.** No code is moved to a BoltFFI transport in this phase.
- **No benchmarks yet.** A measurement harness lands in the first migration
  slice, not here. Classification below is best-effort from call-site
  inspection plus PLAN_V2 §22.4 priority order.
- **No PLAN_V2 edits.** This doc defers to `PLAN_V2.md` §22 wording whenever
  there is any ambiguity.
- **No removal of UniFFI surfaces.** Per §22.6 step 8, UniFFI retires only
  after a BoltFFI replacement is proven and the old callers are migrated.

## 1. FFI Transport Inventory

Epistemos has four live Swift ↔ Rust transports today:

| Transport | Owner crate | Surface count | Notes |
|-----------|-------------|---------------|-------|
| C FFI header (`graph_engine.h`) | `graph-engine` | ~127 exported functions across 28 section groups, 1042 lines | Graph data plane + input + camera + BTK + KC + SDF labels |
| UniFFI exports | `agent_core` | 37 exports in `bridge.rs`, additional surface across 20 other files | Agent loop, session, channel relay, tool registry, approval |
| UniFFI exports | `omega-mcp` | 16 exports in `dispatcher.rs` | Dispatcher, catalog, vault ops |
| UniFFI exports | `epistemos-core` | 0 direct exports in `lib.rs` today | Crate exists but exports live under it via sub-modules |

There are no XPC / subprocess boundaries for inference (per CLAUDE.md
non-negotiable). The Hermes subprocess is orchestration-only and is not
an inference FFI. FAL / Claude / Perplexity providers use HTTP rather
than FFI and are out of scope.

## 2. Graph Engine C FFI Surface (`graph_engine.h`)

The graph engine's C FFI is the largest single surface and the top
PLAN_V2 §22.4 BoltFFI priority. Grouped by section divider:

| Section (line) | Function count | Dominant call site | Payload shape | Frequency | Classification | Priority |
|---|---|---|---|---|---|---|
| Lifecycle (14) | 2 | MetalGraphView setup/teardown | opaque pointer | one-shot per app session | `keep_uniffi` | — |
| Graph Data Loading (25) | 7 | GraphState.applyPending* | typed scalar args + C strings (uuid, label); batch variants accept pointer + count | per edit / per tab switch | **`boltffi_priority`** | **First** |
| Rendering (109) | 3 | MetalGraphView draw loop | (engine, w, h) → u32 | 60 fps | `keep_uniffi` (call is one opaque scalar — not a marshalling bottleneck) | — |
| Input Events (115) | 8 | MetalGraphView mouse handlers | scalar coords + bool | high (mouseMoved) | `keep_uniffi` | — |
| Force Parameters (135) | 8 | GraphForceSettings bindings | scalar set/get | low (user tweak) | `keep_uniffi` | — |
| Highlighting (154) | 11 | `graph_engine_search_highlight`, hover neighborhood | C string query | medium (typed search) | `boltffi_candidate` | second tier |
| Camera (188) | 4 | GraphState.camera control | scalar | low | `keep_uniffi` | — |
| Node Pinning (213) | 3 | Hologram pin panel | uuid string | low | `keep_uniffi` | — |
| Cluster Parameters (224) | 2 | semantic clustering UI | scalar | low | `keep_uniffi` | — |
| Coordinate Conversion (232) | 4 | pointer picking | scalar | medium | `keep_uniffi` | — |
| Visibility Filtering (245) | 3 | GraphState filter apply | scalar + bool | medium | `keep_uniffi` | — |
| Display Settings (254) | 8 | theme + physics knobs | scalar | low | `keep_uniffi` | — |
| Queries (277) | 5 | `graph_engine_neighbors`, shortest path | uuid in, batch result out | medium (hover / inspector) | **`boltffi_priority`** | **First** |
| Search (292) | 6 | typed-ahead search | C string in, `GraphSearchResult*` array out | high (every keystroke during sidebar search) | **`boltffi_priority`** | **First** |
| Semantic Clustering (324) | 3 | cluster UI | scalar | low | `keep_uniffi` | — |
| Embeddings (337) | 12 | retrieval + reranker | `float*` vector, count | high (every retrieval) | **`shared_memory_candidate`** | second tier |
| Temporal Index (389) | 2 | timeline views | scalar + uuid | low | `keep_uniffi` | — |
| Confidence (399) | 12 | confidence overlay | scalar + uuid | medium | `boltffi_candidate` | second tier |
| Markdown Parser (468) | 11 | inline parse helpers called from NoteTextView | C string in, token array out | high (every edit) | **`boltffi_priority`** | close behind graph |
| Fold State (537) | 5 | code-block fold toggle | uuid + bool | low | `keep_uniffi` | — |
| Block Transaction Kernel (561) | 18 | BTK edit pipeline | large diff payloads | per edit | `boltffi_candidate` | second tier |
| Knowledge Core (752) | 15 | shared-memory reactive FFI | already SHM | already migrated | `keep_uniffi` (documented as existing SHM surface) | — |
| Note Recovery (922) | 2 | orphan recovery | path string | low | `keep_uniffi` | — |
| Shadow Attraction (936) | 3 | physics experiment | scalar | low | `keep_uniffi` | — |
| Mass-Based Drag Physics (953) | 2 | physics experiment | scalar | low | `keep_uniffi` | — |
| SDF Label Rendering (966) | 5 | text overlay | label instance array | 60 fps | **`boltffi_priority`** | close behind graph |

**Graph FFI summary:**
- **5 priority groups** total:
  `Graph Data Loading`, `Queries`, `Search`, `Markdown Parser`, `SDF Label Rendering`.
  These are the hot paths where allocation churn and JSON-over-FFI
  shape directly affect frame time or keystroke latency.
- **1 shared-memory candidate:** `Embeddings` (vectors large enough that
  even a typed BoltFFI transfer is the wrong shape).
- **4 second-tier BoltFFI candidates:** `Highlighting`, `Confidence`,
  `Block Transaction Kernel`, plus parts of `Search` overlap.
- **Everything else stays on C FFI + UniFFI.** Low-frequency scalar
  boundaries are not worth the migration cost.

## 3. agent_core UniFFI Surface

Top files by `#[uniffi::export]` count (scanned 2026-04-15):

| File | Exports | Role | Classification |
|---|---|---|---|
| `agent_core/src/bridge.rs` | 37 | Agent loop entry, tool exec, session mutation | `boltffi_candidate` (streaming events especially) |
| `agent_core/src/channel_relay.rs` | 16 | Channel registry mutations + routing | `keep_uniffi` (cold control-plane) |
| `agent_core/src/approval.rs` | 13 | Permission approval prompts | `keep_uniffi` (must stay auditable) |
| `agent_core/src/session.rs` | 14 | Session lineage, pruning, compaction | `boltffi_candidate` (session graph payloads) |
| `agent_core/src/storage/memory_classifier.rs` | 8 | Memory classification calls | `boltffi_candidate` (batch results) |
| `agent_core/src/storage/vault.rs` | 4 | Vault CRUD | `keep_uniffi` (typed ergonomics > throughput) |
| `agent_core/src/vault_registry.rs` | 6 | Per-model vault routing | `keep_uniffi` |
| `agent_core/src/routing.rs` | 2 | Runtime resolution | `keep_uniffi` |
| `agent_core/src/tirith.rs` | 5 | Tirith agent adapter | `keep_uniffi` |
| `agent_core/src/providers/openai.rs` | 5 | OpenAI adapter FFI surface | `keep_uniffi` |
| `agent_core/src/pty.rs` | 6 | PTY tool surface | `keep_uniffi` |
| `agent_core/src/example_bank.rs` | 4 | Example retrieval | `boltffi_candidate` |
| `agent_core/src/prompt_caching.rs` | 2 | Cache control flags | `keep_uniffi` |
| `agent_core/src/compaction.rs` | 2 | Context compaction | `boltffi_candidate` (output can be large) |
| `agent_core/src/storage/neural_cache.rs` | 5 | Neural cache access | `shared_memory_candidate` (KV slabs) |
| `agent_core/src/skill_router.rs` | 3 | Skill catalog | `keep_uniffi` |
| `agent_core/src/context_loader.rs` | 1 | Context loader entrypoint | `keep_uniffi` |
| `agent_core/src/dispatcher.rs` | 1 | Dispatcher entry | `keep_uniffi` |
| `agent_core/src/title_generator.rs` | 1 | Title generator | `keep_uniffi` |
| `agent_core/src/reasoning_metrics.rs` | 2 | Metrics read | `keep_uniffi` |

Total scanned: **182 exports across 20 files.**

### Highest-priority streaming surfaces

Per PLAN_V2 §22.4 "Agent and tool-event data plane," the following
agent_core surfaces are the right second migration target after graph:

- Agent stream events (token + thinking deltas)
- Tool call start / input / output events
- Trace / replay event batches
- Session lineage and session-browser summaries

These currently flow through UniFFI structs + JSON-over-FFI in several
places (command-center compile being the most visible). They stay on
UniFFI in this audit but are flagged for a dedicated later slice.

## 4. omega-mcp UniFFI Surface

`omega-mcp/src/dispatcher.rs` exports 16 `#[uniffi::export]` functions.
MCP tool dispatch is primarily process-boundary work (the MCP protocol
itself is the transport between Swift and external tools), so the
relevant BoltFFI opportunity is the **local** Swift ↔ Rust handoff
around MCP result objects:

| Surface | Shape | Classification |
|---|---|---|
| Dispatcher entry points | small typed args | `keep_uniffi` |
| Tool catalog fetch | batch JSON today | `boltffi_candidate` (low frequency, defer unless catalog grows) |
| Large resource payload metadata | typed struct + byte count | `boltffi_candidate` |
| Screenshot / file result references | path strings + bytes | `shared_memory_candidate` (large blobs) |
| Chunked MCP framing handoff | stream | `boltffi_candidate` if profiling shows bridge overhead |

No omega-mcp surface ranks above the graph data plane.

## 5. Shared-Memory / Knowledge Core

The `Knowledge Core (Shared-Memory Reactive FFI)` section at line 752 of
`graph_engine.h` (15 functions) is already shared-memory. That pattern
has the shape BoltFFI wants for the large-payload cases above. Rather
than migrate it again, use it as the reference implementation for the
future Embeddings + Neural Cache shared-memory migrations.

## 6. Classification Summary

| Classification | Surfaces | Action |
|---|---|---|
| `boltffi_priority` | 5 graph sections (Data Loading, Queries, Search, Markdown Parser, SDF Labels) | First migration slice candidates |
| `boltffi_candidate` | Highlighting, Confidence, BTK, Compaction, Memory Classifier, Example Bank, Session lineage, Agent streaming events | Second-tier, schedule after graph slice lands |
| `shared_memory_candidate` | Embeddings, Neural Cache KV slabs, large MCP resource blobs | Use Knowledge Core pattern |
| `keep_uniffi` | All low-frequency scalar surfaces; approval/permission surfaces; vault CRUD; routing; cold control plane | Stay on UniFFI |
| `xpc_or_process_boundary` | (none identified — Hermes is orchestration, not FFI) | — |
| `defer_no_measured_gain` | Mass-Based Drag Physics, Shadow Attraction, semantic clustering params | Defer |

## 7. First Migration Candidate

**Graph Data Loading + Queries + Search.**

Rationale:
- PLAN_V2 §22.4 explicitly names the graph data plane as the first
  serious candidate because "the user can feel latency, jitter, and
  allocation churn directly."
- Phase 7 Steps 2a, 4, and 5 just landed a real graph workspace that
  makes these surfaces user-visible for the first time (double-click
  → note page, subfolder navigation, nested back/forward history). Any
  bridge latency here surfaces as perceivable UI stutter.
- Data Loading, Queries, and Search share a common payload shape
  (node/edge batches, neighborhoods, search hits) so a single typed
  BoltFFI buffer layout can cover all three.

## 8. Measurement Protocol (Before First Migration)

Per PLAN_V2 §22.5, before any migration we must record:
- payload size
- call frequency (for a realistic 10K-node vault)
- allocation count
- Swift main-thread time
- Rust marshalling time
- end-to-end latency
- peak memory and copy count where measurable
- user-visible symptom, if any

The measurement harness belongs in a dedicated benchmark file —
suggested location: `EpistemosTests/GraphFFIBenchmarkTests.swift` with a
`@Suite` gated behind a runtime flag so it doesn't run in CI. After the
harness is in place and baseline numbers are recorded, a single vertical
slice migrates `graph_engine_add_nodes_batch` + the main query + search
paths to a BoltFFI typed buffer, keeps the existing C FFI behind a
compatibility switch, and runs parity + benchmark deltas before flipping
the switch.

## 9. Exit Criteria For The Full BoltFFI Program

Per PLAN_V2 §22.7, the migration program is done only when:

- every FFI boundary has an explicit keep/migrate/defer decision — **✓ this audit**
- graph hot-path transfer has been benchmarked and either migrated or justified — **pending first slice**
- agent event streaming has been benchmarked — **pending second slice**
- capture/transcript/evidence payloads benchmarked before Phase 6.5/7 expansion — **pending**
- embedding/retrieval payloads have a typed or SHM strategy — **flagged here, no code yet**
- UniFFI remains only where cold-path or ergonomically superior — **preserved in this audit**
- no migration weakens Rust sovereignty, permission gates, audit logs, local-first routing — **invariant**

## 10. Handoff To Next Slice

What this audit leaves for the next session:

1. Build `EpistemosTests/GraphFFIBenchmarkTests.swift` with disabled-by-default
   baseline measurements for the 5 priority graph sections.
2. Design the typed BoltFFI buffer layout for graph node/edge batches.
   Suggested starting point: `#[repr(C)]` `GraphNodeBuffer` + `GraphEdgeBuffer`
   with preallocated output pointers, matching the Knowledge Core SHM
   pattern for copy semantics.
3. Keep the existing C FFI header untouched; add the new buffer paths
   side-by-side behind a feature flag. Retire old callers only after
   parity + benchmark deltas pass.

No code in this commit.
