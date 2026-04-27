// W9.26 — B-tree text rope foundation
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §W9.26: replace String-based
// note storage with a B-tree rope (`crop` v0.4+ with the
// `utf16-metric` feature). Edits become O(log n); snapshots are O(1)
// (copy-on-write); UTF-16 metrics line up with WKWebView's selection
// API so cursor offsets translate without an O(n) walk.
//
// FOUNDATION (this commit ships):
//   - the `RopeDocument` newtype wrapping `crop::Rope`
//   - insert/delete/snapshot/utf16↔byte helpers
//   - tests verifying UTF-8 + UTF-16 boundary safety
//
// FOLLOW-UPS (separate PRs per the dossier's plan):
//   - UniFFI bindings (5-7 entry points: new/insert/delete/snapshot/
//     utf16_to_byte/byte_to_utf16/dispose)
//   - Swift `RopeFFIClient` + `~Copyable` handle
//   - Migration of `NoteFileStorage.swift` String → rope handle
//   - WKWebView/Tiptap bridge update so selection ranges round-trip
//
// 16GB Mac feasibility: crop chunks at ~1KB; 100KB note ≈ 100 leaf
// chunks; 10K notes loaded = <100MB resident. FFI cost will dominate
// over the algorithm.

use crop::Rope;
use std::sync::Mutex;

/// Thread-safe rope document. The Mutex is the simplest correct
/// shape today; if we hit contention (single-writer is the planned
/// access pattern per W9.27 OpLog), we'll switch to a per-document
/// `RwLock` or move to an actor.
pub struct RopeDocument {
    inner: Mutex<Rope>,
}

impl Default for RopeDocument {
    fn default() -> Self {
        Self::new()
    }
}

impl RopeDocument {
    pub fn new() -> Self {
        Self {
            inner: Mutex::new(Rope::new()),
        }
    }

    pub fn from_str(text: &str) -> Self {
        Self {
            inner: Mutex::new(Rope::from(text)),
        }
    }

    /// Total length in bytes (UTF-8).
    pub fn len_bytes(&self) -> usize {
        self.lock().byte_len()
    }

    /// Total length in UTF-16 code units. Matches WKWebView's
    /// `getSelection().getRangeAt(0)` semantics.
    pub fn len_utf16(&self) -> usize {
        self.lock().utf16_len()
    }

    /// Snapshot the entire document as a String. Returns the full
    /// content; for large docs prefer `iter_chunks` (TODO in a
    /// future commit).
    pub fn snapshot(&self) -> String {
        self.lock().to_string()
    }

    /// Insert text at the given byte offset. Caller is responsible
    /// for translating from UTF-16 (use `utf16_to_byte`) when
    /// coming from WKWebView.
    pub fn insert(&self, byte_offset: usize, text: &str) {
        self.lock().insert(byte_offset, text);
    }

    /// Delete the byte range `[from, to)`.
    pub fn delete(&self, byte_from: usize, byte_to: usize) {
        if byte_from >= byte_to {
            return;
        }
        self.lock().delete(byte_from..byte_to);
    }

    /// Convert a UTF-16 offset to a UTF-8 byte offset.
    pub fn utf16_to_byte(&self, utf16_offset: usize) -> usize {
        self.lock().byte_of_utf16_code_unit(utf16_offset)
    }

    /// Convert a UTF-8 byte offset to a UTF-16 offset.
    pub fn byte_to_utf16(&self, byte_offset: usize) -> usize {
        self.lock().utf16_code_unit_of_byte(byte_offset)
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Rope> {
        self.inner.lock().unwrap_or_else(|e| e.into_inner())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_rope_has_zero_lengths() {
        let r = RopeDocument::new();
        assert_eq!(r.len_bytes(), 0);
        assert_eq!(r.len_utf16(), 0);
        assert_eq!(r.snapshot(), "");
    }

    #[test]
    fn insert_and_snapshot() {
        let r = RopeDocument::new();
        r.insert(0, "Hello, ");
        r.insert(7, "world!");
        assert_eq!(r.snapshot(), "Hello, world!");
        assert_eq!(r.len_bytes(), 13);
        assert_eq!(r.len_utf16(), 13);
    }

    #[test]
    fn delete_range() {
        let r = RopeDocument::from_str("Hello, world!");
        r.delete(5, 7);
        assert_eq!(r.snapshot(), "Helloworld!");
    }

    #[test]
    fn utf16_metrics_match_apis() {
        // ASCII: byte and utf16 lengths match.
        let r = RopeDocument::from_str("abc");
        assert_eq!(r.len_bytes(), 3);
        assert_eq!(r.len_utf16(), 3);
        assert_eq!(r.utf16_to_byte(2), 2);

        // BMP non-ASCII char: 2 UTF-8 bytes, 1 UTF-16 code unit.
        let r = RopeDocument::from_str("aäb");
        assert_eq!(r.len_bytes(), 4);
        assert_eq!(r.len_utf16(), 3);
        // ä starts at byte 1, utf16 unit 1
        assert_eq!(r.utf16_to_byte(1), 1);
        assert_eq!(r.utf16_to_byte(2), 3);
        assert_eq!(r.byte_to_utf16(3), 2);
    }

    #[test]
    fn supplementary_plane_uses_two_utf16_units() {
        // 𐀀 (U+10000) — 4 UTF-8 bytes, 2 UTF-16 code units (surrogate pair).
        let r = RopeDocument::from_str("a𐀀b");
        assert_eq!(r.len_bytes(), 6);
        assert_eq!(r.len_utf16(), 4);
        // 'b' starts at byte 5, utf16 unit 3
        assert_eq!(r.utf16_to_byte(3), 5);
    }

    #[test]
    fn delete_with_invalid_range_is_noop() {
        let r = RopeDocument::from_str("hi");
        r.delete(2, 1);  // inverted
        assert_eq!(r.snapshot(), "hi");
    }
}
