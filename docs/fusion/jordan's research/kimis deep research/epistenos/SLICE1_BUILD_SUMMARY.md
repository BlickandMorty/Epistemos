# SLICE 1 — App Group Container + Shared Arena
## Build Summary

**Date:** 2026-05-04  
**Mission:** Foundational App Group container and mmap arena enabling XPC service split and Simulation state sharing.

---

## Files Created / Modified

### Rust — `agent_core` crate (new)

| File | Lines | Description |
|------|-------|-------------|
| `crates/agent_core/Cargo.toml` | 23 | Crate manifest: `memmap2`, `thiserror`, `tracing`, `objc2`, `dirs` |
| `crates/agent_core/src/lib.rs` | 28 | Re-exports: `Arena`, `MappedArena`, `AppGroupContainer`, etc. |
| `crates/agent_core/src/arena/mod.rs` | 910 | **Full arena implementation** — `ArenaHeader`, `RequestSlot`, `ResponseSlot`, `MappedArena` with mmap ring buffer, atomic Release-Acquire protocol, 6 unit tests |
| `crates/agent_core/src/arena/container.rs` | 161 | App Group path resolution via `NSFileManager.containerURLForSecurityApplicationGroupIdentifier` (objc2), legacy fallback, `ensure_layout()` |

### Rust — Workspace & FFI integration

| File | Lines | Description |
|------|-------|-------------|
| `Cargo.toml` | ~100 | Added `agent_core` to workspace members and dependencies |
| `crates/helios-ffi/Cargo.toml` | ~22 | Added `agent_core` dependency + `tracing` |
| `crates/helios-ffi/src/bridge.rs` | ~330 | Added `arena_open`, `arena_submit`, `arena_poll`, `arena_signal_epoch`, `arena_bump_epoch` UniFFI exports |
| `crates/helios-ffi/src/api.udl` | ~85 | UDL declarations for arena FFI errors and functions |

### Swift — Shared substrate

| File | Lines | Description |
|------|-------|-------------|
| `swift/EpistenosKit/Sources/AppGroupContainer.swift` | ~195 | `@MainActor` singleton, App Group URL resolution, legacy fallback, idempotent `ensureLayout()`, async `migrateFromLegacyIfNeeded()` |
| `swift/EpistenosKit/Sources/ArenaPathResolver.swift` | ~62 | `resolve()` → App Group preferred, `legacyFallback()`, `resolveCString()` for FFI boundary |
| `swift/EpistenosKit/Sources/ArenaBridge.swift` | ~167 | `actor ArenaBridge`, `ArenaOp` enum, `submitRequest`, `pollResponse`, `awaitResponse`, DEBUG synthetic response path |
| `swift/EpistenosMAS.entitlements` | ~65 | App Sandbox + App Group `group.com.epistenos.shared` + user-selected files + bookmarks |
| `swift/EpistenosKit/Tests/ArenaTests.swift` | ~113 | 6 Swift XCTest cases: container existence, path resolution, legacy migration, bridge submit, bridge timeout, layout idempotency |

### Swift — Integration into existing code

| File | Lines | Description |
|------|-------|-------------|
| `swift/EpistenosKit/Sources/Environment/AppEnvironment.swift` | ~48 | Added `appGroupContainer: AppGroupContainer` property |
| `swift/EpistenosKit/Sources/Views/Landing/LandingFarmWindowManager.swift` | ~40 | Updated `AppBootstrap.run()` to call `AppGroupContainer.shared.ensureLayout()` and `migrateFromLegacyIfNeeded()` |

---

## Arena Layout

```text
Offset      Size        Content
0x00000     4096 B      ArenaHeader (magic, version, head/tail atomics, signal_epoch)
0x01000     65536 B     RequestSlot[16]  (4096 B each)
0x11000     131072 B    ResponseSlot[16] (8192 B each)
0x31000     —           Total = 200 704 bytes (~196 KiB)
```

## Memory Ordering Protocol

| Step | Producer | Ordering |
|------|----------|----------|
| 1 | Fill slot data (op, payload, refs) | Relaxed |
| 2 | `state.store(READY, Release)` | **Release** |
| 3 | `head.store(seq, Release)` | **Release** |
| 4 | Consumer `state.load(Acquire)` | **Acquire** |
| 5 | Consumer reads slot data | Relaxed (guaranteed visible by step 2) |
| 6 | Consumer `tail.store(seq, Release)` | **Release** |

## Corruption Recovery

If magic ≠ `0x4550_4152` or version ≠ `2`, the arena file is:
1. Zero-filled via `core::ptr::write_bytes`
2. Magic/version written last
3. `fence(SeqCst)` ensures visibility

## Critical Design Decisions

1. **File-backed mmap (not `shm_open`)** — MAS-safe; `shm_open` is prohibited by App Review.
2. **Page-aligned structs** — `#[repr(C, align(4096))]` / `#[repr(C, align(8192))]` guarantee that ring slots never cross page boundaries.
3. **Raw pointer field access** — All writes through `*mut T` field projections (`(*ptr).field = value`) without intermediate `&mut` references, ensuring soundness under Stacked Borrows / Tree Borrows.
4. **`Send` + `Sync` impls** — Explicit with `// SAFETY:` justifications; actual synchronisation is via atomics, not mutexes.
5. **`#[no_mangle] epistenos_arena_path`** — C ABI boundary for non-UniFFI consumers.

## Swift Integration Notes

- `AppBootstrap.run()` (called from `AppDelegate.applicationDidFinishLaunching`) is now the single entry point for App Group layout + legacy migration.
- `VaultManager.sharedContainerURL()` already existed; `AppGroupContainer` supersedes it as the canonical source.
- SQLite stores (`EventStore`, `VaultSync`) should be updated to use `provenanceDBURL` / `vaultIndexURL` when App Group is active (see `AppEnvironment.appGroupContainer`).
- Migration is idempotent: the `.migrated` marker file prevents re-running.

## Next Steps (SLICE 2 + SLICE 3)

- **SLICE 2 (AgentXPC):** The Rust `poll_next_request` / `publish_response` / `complete_request` helpers are already implemented in `MappedArena` for the XPC service side.
- **SLICE 3 (Simulation):** `ArenaBridge` has a `signal_epoch` reader; the companion can detect configuration changes by polling `readSignalEpoch()`.

## Testing

### Rust tests (`cargo test -p agent_core`)
- `arena_create_and_open` — magic/version verification
- `arena_submit_take_roundtrip` — full request → response flow
- `arena_ring_wraparound` — >16 requests, index wrapping
- `arena_concurrent_submit` — 4 threads, 8 requests each, no corruption
- `arena_corruption_recovery` — corrupt magic, verify re-init
- `arena_drop_munmap` — file persists after drop
- `arena_layout_sizes` — struct size/alignment assertions
- `arena_signal_epoch` — epoch bump/read

### Swift tests (`Cmd+U` in Xcode on EpistenosKit tests)
- `testAppGroupContainerExists`
- `testArenaPathResolve`
- `testLegacyFallback`
- `testLegacyMigration`
- `testArenaBridgeSubmit`
- `testArenaBridgePollTimeout`
- `testEnsureLayoutIdempotent`
