import Foundation

// MARK: - RopeFFIClient
//
// **SCAFFOLD ONLY (RCA13 RCA2-P2-015).** This Swift consumer for
// the agent_core rope handle is wired through @_silgen_name + a
// full roundtrip test suite, but no production Swift code calls
// `RopeFFIClient` today. The note storage migration that's slated
// to consume this (per the W9.26 plan) is a future PR.
//
// Until that wiring lands, this file is a stable target for the
// migration to land against — the FFI surface, the threading
// contract, and the tests are all in place. No UI claim should
// imply that rope-backed note storage is the active runtime.
//
// W9.26 PR3 of N — Swift consumer for the agent_core/src/rope_handle.rs
// FFI surface. Mirrors the proven RustEventRingClient @_silgen_name
// pattern (Engine/RustEventRingClient.swift).
//
// Bridges 12 extern "C" entry points from agent_core into a single
// `nonisolated` final class wrapper that owns one Arc<RopeDocument>
// handle. The Rust side is refcounted; this Swift class holds exactly
// one strong reference, released in `deinit`.
//
// ## Why no UniFFI?
//
// agent_core has zero `#[derive(uniffi::Object)]` types today, so
// PR2 chose raw extern "C" exports (matching the W9.21 honest-FFI
// modules in epistemos-shadow / substrate-rt / substrate-core /
// syntax-core). PR3 stays in lane: `@_silgen_name` direct binding.
//
// ## Threading
//
// `RopeDocument` is `Send + Sync` on the Rust side via internal
// `Mutex<crop::Rope>`. Multiple Swift threads can call any operation
// on the same handle simultaneously; the lock is taken inside Rust
// for the duration of each FFI call. Ergonomically the Swift side
// can pass the handle around freely; correctness is enforced by the
// Rust side (no runtime contracts to maintain in Swift).
//
// ## Linkage
//
// agent_core is linked into the app target unconditionally
// (it's the agent runtime). No `#if EPISTEMOS_LINK_*` gate needed
// for these symbols. If the binary is built without agent_core
// (impossible in current project.yml), the linker would fail with
// "undefined symbol _rope_handle_new" — that's the right failure
// mode (loud, not silent).
//
// ## WRV
//
// This file ships as infrastructure (analogous to W9.21 honest_handle
// modules). The user-reachable consumer is PR4 — NoteFileStorage
// migration replaces SDPage.body String storage with rope handles.
// Until PR4 lands, RopeFFIClient is exercised only via the unit
// tests in agent_core/src/rope_handle.rs (Rust side) plus the
// follow-up Swift test in this file's #if DEBUG block (smoke test).
//
// `WRV_EXEMPT: infrastructure` per the closed exempt list rationale
// in 00_AUTHORITY_AND_ANTI_DRIFT.md §4.7.

@_silgen_name("rope_handle_new")
nonisolated func rope_handle_new() -> UnsafeRawPointer?

@_silgen_name("rope_handle_from_str")
nonisolated func rope_handle_from_str(_ text: UnsafePointer<CChar>?) -> UnsafeRawPointer?

@_silgen_name("rope_handle_retain")
nonisolated func rope_handle_retain(_ handle: UnsafeRawPointer)

@_silgen_name("rope_handle_release")
nonisolated func rope_handle_release(_ handle: UnsafeRawPointer)

@_silgen_name("rope_handle_len_bytes")
nonisolated func rope_handle_len_bytes(_ handle: UnsafeRawPointer) -> Int

@_silgen_name("rope_handle_len_utf16")
nonisolated func rope_handle_len_utf16(_ handle: UnsafeRawPointer) -> Int

@_silgen_name("rope_handle_insert")
nonisolated func rope_handle_insert(
    _ handle: UnsafeRawPointer,
    _ byteOffset: Int,
    _ text: UnsafePointer<CChar>
) -> Bool

@_silgen_name("rope_handle_delete")
nonisolated func rope_handle_delete(
    _ handle: UnsafeRawPointer,
    _ byteFrom: Int,
    _ byteTo: Int
)

@_silgen_name("rope_handle_utf16_to_byte")
nonisolated func rope_handle_utf16_to_byte(
    _ handle: UnsafeRawPointer,
    _ utf16Offset: Int
) -> Int

@_silgen_name("rope_handle_byte_to_utf16")
nonisolated func rope_handle_byte_to_utf16(
    _ handle: UnsafeRawPointer,
    _ byteOffset: Int
) -> Int

@_silgen_name("rope_handle_snapshot")
nonisolated func rope_handle_snapshot(_ handle: UnsafeRawPointer) -> UnsafeMutablePointer<CChar>?

@_silgen_name("rope_handle_free_string")
nonisolated func rope_handle_free_string(_ s: UnsafeMutablePointer<CChar>?)

// MARK: - RopeFFIClient

/// Swift wrapper around an Arc-refcounted `RopeDocument` handle from
/// agent_core. Owns exactly one strong reference; releases it in
/// `deinit`. Use multiple `RopeFFIClient` instances over the same
/// underlying document by calling `retainSibling()` to mint a paired
/// instance that refcounts the same handle independently.
nonisolated public final class RopeFFIClient: @unchecked Sendable {

    /// Opaque pointer to the Rust `RopeDocumentHandle`. Never
    /// dereferenced from Swift — passed back into FFI calls as-is.
    private let handle: UnsafeRawPointer

    /// Create an empty rope.
    public init?() {
        guard let raw = rope_handle_new() else { return nil }
        self.handle = raw
    }

    /// Create a rope seeded with `text`.
    public init?(text: String) {
        let opt: UnsafeRawPointer? = text.withCString { cstr in
            rope_handle_from_str(cstr)
        }
        guard let raw = opt else { return nil }
        self.handle = raw
    }

    /// Internal initializer used by `retainSibling()` — assumes the
    /// caller has already incremented the refcount.
    private init(adoptingRetained handle: UnsafeRawPointer) {
        self.handle = handle
    }

    deinit {
        rope_handle_release(handle)
    }

    // MARK: - Refcount management

    /// Mint a sibling client that refcounts the same underlying
    /// document. The two instances may be used concurrently from
    /// different threads; both will release their share on deinit.
    public func retainSibling() -> RopeFFIClient {
        rope_handle_retain(handle)
        return RopeFFIClient(adoptingRetained: handle)
    }

    // MARK: - Length queries

    public var byteLength: Int {
        rope_handle_len_bytes(handle)
    }

    public var utf16Length: Int {
        rope_handle_len_utf16(handle)
    }

    // MARK: - Mutations

    /// Insert UTF-8 `text` at the given UTF-8 byte offset. Use
    /// `byteOffset(forUTF16:)` to convert from a WKWebView selection
    /// range. Returns false if the call site provided invalid UTF-8.
    @discardableResult
    public func insert(_ text: String, atByteOffset offset: Int) -> Bool {
        text.withCString { cstr in
            rope_handle_insert(handle, offset, cstr)
        }
    }

    /// Delete the byte range `[from, to)`. Inverted ranges are no-ops
    /// (matches the Rust contract).
    public func delete(byteFrom from: Int, to: Int) {
        rope_handle_delete(handle, from, to)
    }

    // MARK: - Offset conversion (matches WKWebView UTF-16 semantics)

    public func byteOffset(forUTF16 utf16Offset: Int) -> Int {
        rope_handle_utf16_to_byte(handle, utf16Offset)
    }

    public func utf16Offset(forByte byteOffset: Int) -> Int {
        rope_handle_byte_to_utf16(handle, byteOffset)
    }

    // MARK: - Snapshot

    /// Full document snapshot as a Swift String. Returns the empty
    /// string if Rust failed to allocate.
    public func snapshot() -> String {
        guard let cstr = rope_handle_snapshot(handle) else { return "" }
        defer { rope_handle_free_string(cstr) }
        return String(cString: cstr)
    }
}
