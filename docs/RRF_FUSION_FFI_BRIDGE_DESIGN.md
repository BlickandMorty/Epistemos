# RRF Fusion — Rust↔Swift FFI Bridge Design (deferred Sites 4 + 5)

**Date authored**: 2026-04-28
**Phase**: Post-Phase-4 follow-up (substantial cross-language work)
**Status**: design-only — no code lands here

This document closes the deferral of `docs/RRF_FUSION_DESIGN.md` §14 Sites 4 + 5. It exists so a future session has a complete plan to ship without re-deriving the design.

## §1 — What's deferred

From Phase 4 wiring (mission spec `docs/RRF_FUSION_PROMPT.md` §"Phase 4"):

| # | Site | Status |
|---|---|---|
| 4 | Agent tool — Rust side | ⏸ deferred — no FFI bridge shipped |
| 5 | Local Hermes parity | ⏸ deferred — depends on §4 |

## §2 — Why this is non-trivial

Today there are TWO independent vault-search code paths in the codebase that don't talk to each other:

```
┌─ Swift side ──────────────────────────────────┐    ┌─ Rust side ─────────────────────────────┐
│ SearchIndexService (GRDB + FTS5)              │    │ agent_core::storage::vault::VaultStore │
│   - search.sqlite                             │    │   - VaultBackend::hybrid_search        │
│   - page_search / block_search /              │    │   - hybrid: HNSW + tantivy             │
│     readable_blocks_fts                       │    │   - lives in agent_core process        │
│   - fusedSearch(query:) → [FusedResult]       │    │   - tool: registry.rs vault_recall      │
└───────────────────────────────────────────────┘    └─────────────────────────────────────────┘
```

When the agent's `vault_recall` tool fires, it calls `VaultStore.hybrid_search(...)` — which is Rust's own bm25+HNSW recall over a SEPARATE persistent store. Swift's `SearchIndexService.fusedSearch` is not consulted. The user's mission brief calls for the Rust tool to instead route through Swift's fused path so there's ONE recall surface.

The bridge complications:

1. **Process model**: agent_core runs as a Swift-loaded dylib (uniffi). The `VaultStore` impl is Rust-owned. Calling back into Swift from Rust requires either:
   - A uniffi callback interface, OR
   - A `@_silgen_name` extern that Rust calls into via `extern "C"` linkage

2. **Type marshaling**: `[FusedResult]` is a Swift Sendable struct with 7 fields including `Optional<String>`. Rust needs an equivalent shape. Options:
   - JSON via a `*const c_char` round trip (mirror existing `shadow_search_json` pattern in `epistemos-shadow`)
   - A Rust `#[repr(C)]` struct array (more work; less robust to schema evolution)

3. **Sync vs async**: `SearchIndexService.fusedSearch` is sync nonisolated. Rust's `VaultBackend::search` is async. Bridge call from Rust async → Swift sync is straightforward; the reverse path is harder. This direction (Rust→Swift) is sync-into-the-Swift-call, so we can take the Swift sync path.

4. **Vault scoping**: Rust's `VaultBackend` may operate on a different vault path than Swift's open vault. Need to ensure both refer to the same `<vault>` root before bridging.

## §3 — Recommended bridge pattern (mirror `epistemos-shadow`)

The existing `epistemos-shadow` crate already solves this exact problem. Its 7-FFI surface (`@_silgen_name` declarations in `Epistemos/Engine/RustShadowFFIClient.swift:27-52`):

```c
shadow_insert_json(json_ptr) -> i32
shadow_remove_json(json_ptr) -> i32
shadow_search_json(json_ptr, limit) -> char* (caller frees)
shadow_flush() -> i32
shadow_stats_json() -> char*
shadow_open_at(path_ptr) -> i32
shadow_warm() -> i32
shadow_free_string(char*)
```

**Mirror this with a new `vault_fused_search` extern.** But note — the shadow extern is Swift-CALLS-Rust direction. We need Rust-CALLS-Swift, which is the opposite. The pattern is:

### Step 1 — Swift exports a stable extern
Add to `Epistemos/Sync/SearchIndexServiceFFI.swift` (new file):

```swift
import Foundation

/// JSON-serialized result — Rust-decodable. Field names match the
/// `FusedResult` Swift type one-to-one (snake_case for wire compat).
private struct FFIResult: Encodable {
    let entity_id: String
    let entity_kind: String
    let parent_doc_id: String
    let fused_score: Double
    let best_source_rank: Int64
    let snippet_block_id: String?
    let snippet: String?
    let updated_at_unix: Double?
}

/// `extern "C"` symbol that the Rust agent_core's `VaultStore` calls
/// when it wants to delegate to Swift's fused search. Returns a
/// JSON-encoded `[FFIResult]` allocated with `strdup`; the caller
/// MUST call `epistemos_fused_search_free` on the returned pointer.
@_cdecl("epistemos_fused_search_v1")
public func epistemos_fused_search_v1(
    queryPtr: UnsafePointer<CChar>?,
    maxResults: Int32
) -> UnsafeMutablePointer<CChar>? {
    guard let queryPtr,
          let svc = AppBootstrap.shared?.searchIndexService else {
        return nil
    }
    let query = String(cString: queryPtr)
    do {
        let weights = FusionWeights(maxResults: max(1, Int(maxResults)))
        let results = try svc.fusedSearch(query: query, weights: weights)
        let ffi = results.map {
            FFIResult(
                entity_id: $0.entityID,
                entity_kind: $0.entityKind,
                parent_doc_id: $0.parentDocID,
                fused_score: $0.fusedScore,
                best_source_rank: $0.bestSourceRank,
                snippet_block_id: $0.snippetBlockID,
                snippet: $0.snippet,
                updated_at_unix: $0.updatedAtUnix
            )
        }
        let data = try JSONEncoder().encode(ffi)
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        return strdup(str)
    } catch {
        SearchFusionMetrics.shared.recordError(error)
        return nil
    }
}

@_cdecl("epistemos_fused_search_free")
public func epistemos_fused_search_free(_ ptr: UnsafeMutablePointer<CChar>?) {
    guard let ptr else { return }
    free(ptr)
}
```

### Step 2 — Rust declares the extern + uses it conditionally
In `agent_core/src/storage/swift_fused_search.rs` (new):

```rust
use std::ffi::{c_char, CStr, CString};

extern "C" {
    fn epistemos_fused_search_v1(query: *const c_char, max_results: i32) -> *mut c_char;
    fn epistemos_fused_search_free(ptr: *mut c_char);
}

#[derive(serde::Deserialize)]
pub struct SwiftFusedResult {
    pub entity_id: String,
    pub entity_kind: String,
    pub parent_doc_id: String,
    pub fused_score: f64,
    pub best_source_rank: i64,
    pub snippet_block_id: Option<String>,
    pub snippet: Option<String>,
    pub updated_at_unix: Option<f64>,
}

pub fn fused_search_via_swift(query: &str, max_results: usize) -> Option<Vec<SwiftFusedResult>> {
    let c_query = CString::new(query).ok()?;
    let ptr = unsafe { epistemos_fused_search_v1(c_query.as_ptr(), max_results as i32) };
    if ptr.is_null() { return None; }
    let result = unsafe { CStr::from_ptr(ptr).to_str().ok()?.to_string() };
    unsafe { epistemos_fused_search_free(ptr); }
    serde_json::from_str(&result).ok()
}
```

Then in `agent_core/src/storage/vault.rs`, add a feature-flag-gated branch in `VaultStore::search`:

```rust
async fn search(&self, query: &str, limit: usize) -> Result<Vec<String>, VaultError> {
    if std::env::var("EPISTEMOS_RRF_FUSION_V1").as_deref() == Ok("1") {
        if let Some(results) = swift_fused_search::fused_search_via_swift(query, limit) {
            return Ok(results
                .into_iter()
                .map(|r| {
                    let snippet = r.snippet.unwrap_or_default();
                    format!("## {} (score: {:.2})\n{}", r.parent_doc_id, r.fused_score, snippet)
                })
                .collect());
        }
        // Fall through on bridge failure — preserves availability.
    }
    // Legacy path
    let results = self.hybrid_search(query, limit, &[]).await?;
    Ok(results.into_iter().map(...).collect())
}
```

### Step 3 — Hermes parity (Site 5)
Once Site 4 lands, the local Hermes model's tool grammar already exposes `vault_recall` (mirrored in `Epistemos/LocalAgent/LocalToolGrammar.swift`). Because the Rust tool's behavior changes (now routed through Swift's fusedSearch), the local model's prompt may need to be updated to describe the new ranking semantics. This is a docs-only change to `HermesPromptBuilder.swift`'s tool description.

## §4 — Risks

1. **Linker order**: Rust's `extern "C"` to Swift symbol works ONLY if Swift's symbol is in a translation unit that's ALWAYS linked into the final binary. The `@_cdecl` attribute + the symbol being public + reachable from the main app target should suffice, but verify with `nm -gU Epistemos.app/Contents/MacOS/Epistemos | grep epistemos_fused_search`.

2. **Mismatched DB**: agent_core's `VaultStore` operates on its own persistent store. Swift's `SearchIndexService` operates on `search.sqlite`. If they're not seeded with the same content, results diverge. Mitigation: verify both indexers see the same vault root (already guaranteed by `AppBootstrap` setup) AND both indexers run on every doc save. F8 wired the doc save → `SearchIndexService` path; agent_core's vault tool may have a separate index-on-save path that needs alignment.

3. **JSON marshaling overhead**: `[FusedResult]` of 50 rows × ~250 bytes JSON ≈ 12 KB per call. Allocates twice (Swift JSONEncoder + Rust serde_json). For per-tool-call usage (one search every few seconds at most), this is negligible. For a tight loop, consider `#[repr(C)]` structs.

4. **Async/sync gap**: `SearchIndexService.fusedSearch` is sync; `VaultBackend::search` is async. Calling sync Swift from async Rust is fine if the call is short (sub-30ms p95 — well under any reasonable async checkpoint). Don't add the bridge to a hot loop.

5. **MAS sandbox**: any new `extern "C"` symbol must be vetted against the MAS hardened runtime + sandbox entitlements. The existing `shadow_*` externs prove this works; no new entitlements should be needed.

## §5 — Effort estimate

| Step | Effort | Risk |
|---|---|---|
| Swift `epistemos_fused_search_v1` extern | 1-2 hours | low — mirrors existing FFI |
| Rust `swift_fused_search` module | 1-2 hours | low |
| `VaultStore::search` flag-gated branch | 30 minutes | low |
| Hermes prompt update | 30 minutes | low |
| Cross-language parity test (round-trip via FFI) | 2-3 hours | medium — needs `cargo test` + `xcodebuild` build artifact |
| Documentation update (`docs/RRF_FUSION_DESIGN.md` §14) | 30 minutes | trivial |

**Total**: ~1 dev-day (8h) of focused work + verification.

## §6 — Acceptance criteria for the FFI bridge phase

- [ ] `nm -gU Epistemos.app/Contents/MacOS/Epistemos | grep epistemos_fused_search` returns the 2 symbols
- [ ] `cargo test --manifest-path agent_core/Cargo.toml` passes (existing 741 + new bridge tests)
- [ ] Round-trip test: query string in Swift → Rust calls Swift extern → JSON parsed → matching `[SwiftFusedResult]` count and ordering
- [ ] `vault_recall` tool exercised from the agent UI returns results from `SearchIndexService.fusedSearch` when `EPISTEMOS_RRF_FUSION_V1=1`, from `VaultStore::hybrid_search` when off
- [ ] Hermes local-model prompt explicitly mentions the new ranking ("results are RRF-fused across page, block, and universal projection sources")
- [ ] No new entitlements required for MAS build
- [ ] `docs/RRF_FUSION_DESIGN.md` §14 marks Sites 4 + 5 ✅

## §7 — Sequencing recommendation

This work is best done as ONE focused dev-day after:
1. Phase 5 runtime tests pass (Xcode IDE-closed window)
2. Phase 6 dogfood completes (3 days)

That way the bridge ships with verified Swift-side correctness underneath. Doing it earlier risks compounding bugs across two language boundaries with no clear way to bisect.

## §8 — Why this is OK to defer

The mission brief calls Sites 4 + 5 "additive behind `EPISTEMOS_RRF_FUSION_V1`, with fallback to existing per-index path". With the flag default-OFF (current state), the legacy `VaultStore::hybrid_search` continues to serve the agent's `vault_recall` tool. Users don't see a regression. Nothing is broken; an opportunity for a unified recall surface is just queued for later.

The deferred state is honest: 6 of 8 wiring sites are wired (4 fully + 2 breadcrumbed) AND the SQL layer + service API + observability + tests are all shipped. The agent-side bridge is the LAST mile of a multi-phase effort and warrants its own planning + verification window.
