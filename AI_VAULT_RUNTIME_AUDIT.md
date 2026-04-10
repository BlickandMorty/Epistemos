# AI Vault Runtime Audit

**Date:** 2026-04-08
**Purpose:** Ground-truth inventory of what exists, what's reusable, and what must be built for Mamba-2 vault runtime.

---

## 1. Current Local AI Runtime

### MLX-Swift (WORKING)
- **Location:** `Epistemos/Engine/MLXInferenceService.swift` (41K bytes)
- **Status:** Production. Runs local models via MLX-Swift framework.
- **SSM Support:** Model catalog includes Mamba2, LFM2, LFM2.5, Jamba, FalconH1 with `isSSM = true`
- **Metal:** Uses MLX-Swift's internal Metal kernels (50+ shaders: GEMV, attention, conv, norm, quantized ops)
- **State Access:** `MambaCache` (subclass of `ArraysCache`) stores SSM state as `cache[0]` (conv) and `cache[1]` (ssm). Accessible via subscript.
- **Built-in Persistence:** `savePromptCache`/`loadPromptCache` in MLXLMCommon/KVCache.swift — handles MambaCache natively
- **Streaming:** Token-by-token via `ChatSession.streamDetails()`

### Custom Metal (NOT YET BUILT)
- **Existing:** Only `ThinkingGlow.metal` (UI animation shader)
- **Needed:** segsum_stable, inter_chunk_scan, elementwise helpers, direct conv

---

## 2. Rust Infrastructure

### agent_core/ (DEBUG ONLY — not in release builds)
| Module | Status | Reuse? |
|--------|--------|--------|
| `ssm_state.rs` (349 LOC) | Working v1 binary format | **Port to epistemos-core** (done) |
| `neocortex.rs` | Text-only awareness | Wire to real state later |
| `neural_cache.rs` (373 LOC) | 4-layer tiered retrieval | **Reuse as-is** |
| `hyperbolic_topology.rs` (613 LOC) | Poincaré embeddings | **Reuse for Phase 3** |
| `vault.rs` (433 LOC) | Tantivy FTS + SQLite | **Reuse as-is** |
| `session_store.rs` (497 LOC) | JSONL transcripts | **Reuse as-is** |
| `memory_classifier.rs` (535 LOC) | Add/Update/Delete | **Reuse as-is** |
| `bridge.rs` | 40+ FFI exports | Debug-only, not shipping |

### epistemos-core/ (ALWAYS SHIPS)
| Module | Status | Notes |
|--------|--------|-------|
| `ssm_state.rs` | **NEW** — ported from agent_core | v2 format with vault_id, model_hash |
| `uniffi_exports.rs` | Extended | Added 6 SSM FFI functions |
| `instant_recall/` | Working | BM25 + trigram search |
| `vault_analyzer/` | Working | Chunking, classification |

---

## 3. Swift/Rust FFI Boundary

### Shipping FFI Bridge
- **Crate:** `epistemos-core` via UniFFI 0.28
- **Binary:** `-lepistemos_core` linked in project.yml
- **Bindings:** Generated to `build-rust/swift-bindings/epistemos_coreFFI/`
- **New exports:** `ssm_save_state`, `ssm_load_state`, `ssm_list_states`, `ssm_prune_states`, `ssm_hash_vault_path`, `ssm_hash_model_id`

### Debug-Only FFI Bridge
- **Crate:** `agent_core` — compiled only when `SHIP_MODE != release`
- **Gate:** `ShipGate.agentsEnabled` in AppBootstrap.swift
- **Not usable** for shipping SSM state persistence

---

## 4. What Must Be Built

### Phase 1A (MLX State Persistence) — SMALLEST VERTICAL SLICE
1. ~~Feature flag in EpistemosConfig~~ ✅ Done
2. ~~SSM state module in epistemos-core~~ ✅ Done
3. ~~SSMStateService Swift actor~~ ✅ Done
4. Hook MLXInferenceService to save state after generation
5. Hook session resume to load state before generation
6. Wire into AppBootstrap dependency graph

### Phase 1B (Custom Metal Runtime)
1. `segsum_stable.metal` — stable log-space segment sum
2. `inter_chunk_scan.metal` — Decoupled Fallback scan (Apple-safe)
3. `elementwise_ssm_helpers.metal` — decay, merge, utilities
4. `direct_conv.metal` — 4-tap depthwise conv
5. `MetalRuntimeManager.swift` — pipeline management
6. Benchmark harness

### Phase 2 (Vault Integration)
1. Vault-scoped state directories
2. Session → state file binding in ConversationPersistence
3. State-aware session resume in ChatCoordinator
4. Lifecycle pruning in VaultLifecycleService / NightBrain

---

## 5. Model Weight & State Sizes

| Model | Params | INT4 Size | SSM State | Fits 16GB? |
|-------|--------|-----------|-----------|------------|
| LFM2 350M | 350M | ~175MB | ~2MB | Yes |
| LFM2.5 1.6B | 1.6B | ~800MB | ~8MB | Yes |
| Mamba2 2.7B | 2.7B | ~1.35GB | ~12-16MB | Yes |
| LFM2 24B | 24B | ~12GB | ~128MB | Tight |

---

## 6. Performance Baselines (To Measure)

| Metric | Expected | Actual | Hardware |
|--------|----------|--------|----------|
| State save (16MB) | < 5ms | TBD | |
| State load (mmap) | < 2ms | TBD | |
| tok/s (2.7B INT4) | 50-135 | TBD | |
| TTFT with state | < 100ms | TBD | |
| Memory overhead | < 50MB | TBD | |
