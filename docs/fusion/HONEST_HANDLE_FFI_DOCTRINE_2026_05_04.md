# Honest Handle FFI Doctrine — 2026-05-04

Track: T0 Rust-FFI / T1 substrate foundation.

This doctrine promotes the D-series worktree's "honest handle" pattern into
fusion canon. The pattern is already partially live in main; this file prevents
future Rust/Swift boundary work from sliding back to fake ownership contracts.

## Donor Authority

Primary donor:

- `.claude/worktrees/agent-a0550f9c/epistemos-shadow/src/honest_handle.rs`
- `.claude/worktrees/agent-a0550f9c/substrate-core/src/honest_handle.rs`
- `.claude/worktrees/agent-a0550f9c/substrate-rt/src/honest_handle.rs`
- `.claude/worktrees/agent-a0550f9c/syntax-core/src/honest_handle.rs`
- `.claude/worktrees/agent-a0550f9c/Epistemos/Engine/RustShadowFFIClient.swift`

Current main evidence:

- `epistemos-shadow/src/honest_handle.rs`
- `substrate-core/src/honest_handle.rs`
- `syntax-core/src/honest_handle.rs`
- `Epistemos/Engine/RustShadowFFIClient.swift`

## Rule

An FFI handle must express the ownership semantics the runtime actually needs.
If Swift shares a Rust object across services, actors, tools, or UI surfaces,
the Rust side must expose a refcounted opaque handle. The refcount is the
contract.

Do not represent shared ownership with a `Box::into_raw` pointer plus prose
such as "caller must not free while another subsystem uses it." That is not a
contract; it is a hope.

## Canonical Shape

The honest-handle pattern is:

1. Rust owns the real object behind `Arc<T>` or `Arc<Mutex<T>>` / `Arc<RwLock<T>>`
   when the inner type is not `Sync`.
2. Rust exposes an opaque `*const Handle`.
3. `*_handle_new` or `*_handle_open_at` returns refcount 1.
4. `*_handle_retain(handle)` increments the refcount.
5. `*_handle_release(handle)` decrements the refcount; the object drops at zero.
6. Operation functions take `*const Handle` and borrow the inner object without
   transferring ownership.
7. Null handles fail deterministically.
8. FFI entry points that can panic catch unwinds and surface typed errors rather
   than aborting Swift.

Swift owns the returned handle in a `final class` and releases exactly once in
`deinit`. If another Swift owner must outlive the original, it must retain its
own handle.

## Live Substrate Cases

| Crate / surface | Handle | Synchronization reason |
|---|---|---|
| `epistemos-shadow` | `ShadowEngineHandle` | `Arc<RealBackend>`; Swift owns one per vault-backed search/indexing client |
| `substrate-core` | `StoreHandle` | `Store` is `Send + Sync`; shared entity store handle is refcounted |
| `substrate-rt` donor | `EventRingHandle` | SPSC event ring is shared by producer/consumer/destroyer; drops at final release |
| `syntax-core` | `SyntaxDocumentHandle` | `tree_sitter::Parser` is `Send` but not `Sync`, so the document is behind `Mutex` |

`substrate-rt` is donor evidence in the D-series worktree and should be checked
against current main before any port. Do not assume it is already live.

## Swift Binding Rule

Swift bindings should look like `RustShadowFFIClient`:

- private `@_silgen_name` declarations for the handle functions;
- a non-optional stored handle after a throwing initializer succeeds;
- typed Swift errors decoded from Rust discriminants;
- `defer`-based freeing for Rust-owned C strings;
- no app-wide global backend state standing in for a per-vault handle;
- no direct exposure of the Rust inner type to Swift.

`shadow_warm` is allowed to remain global because it warms a shared embedder
singleton, not a per-vault backend.

## Safety Requirements

- Every `unsafe` block in Rust keeps a `SAFETY:` explanation.
- `release(null)` is allowed and no-ops.
- Double-release of a non-null handle remains undefined behavior; Swift wrappers
  must prevent it.
- Borrow helpers that temporarily reconstruct `Arc::from_raw` must re-leak with
  `Arc::into_raw` before returning.
- String returns are caller-owned and freed by the matching Rust free function.
- Panic boundaries map to typed error codes such as `rustPanic`, not silent
  crashes.

## Anti-Patterns

- `Box::into_raw` for a handle that multiple Swift subsystems share.
- Global `RwLock<Option<...>>` as a hidden backend singleton for per-vault state.
- Swift storing raw handles in structs that can be copied without retaining.
- Operation functions that consume or free a handle implicitly.
- JSON string copying as a hot-path substitute for a typed/shared-memory
  boundary when the data is large or per-frame.

## Recovery Placement

Recovery status:

- `epistemos-shadow` honest handles are live in main.
- `RustShadowFFIClient` is already cut over to handle-based calls in main.
- `substrate-core` and `syntax-core` handle files exist in main and must remain
  source-guarded.
- `substrate-rt` donor evidence still needs a current-main check before port.

Next recovery slices:

1. Add source guards that prevent regression to global shadow backend calls in
   `RustShadowFFIClient`.
2. Audit current FFI surfaces for `Box::into_raw` handles that are actually
   shared ownership.
3. Keep zero-copy and shared-memory routes separate from honest handles: honest
   handles fix ownership, not large-payload transport by themselves.
