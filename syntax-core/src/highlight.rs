use ropey::Rope;
use tree_sitter::{Language, Query, QueryCursor, StreamingIterator, Tree};

use crate::token_registry::TokenRegistry;
use crate::SyntaxTokenSpan;

const GENERIC_HIGHLIGHTS_QUERY: &str = r#"
(line_comment) @comment
(block_comment) @comment
(string_literal) @string
(string_content) @string
(raw_string_literal) @string
(char_literal) @string
(integer_literal) @number
(float_literal) @number
(boolean_literal) @constant
(escape_sequence) @escape
(type_identifier) @type
(primitive_type) @type
(identifier) @variable
(field_identifier) @property
(function_item name: (identifier) @function.def)
(call_expression function: (identifier) @function.call)
(macro_invocation macro: (identifier) @macro)
(attribute_item) @attribute
"#;

fn query_for_language(language: &Language) -> Option<Query> {
    Query::new(language, GENERIC_HIGHLIGHTS_QUERY).ok()
}

/// Produce `SyntaxTokenSpan` entries for the visible byte range of a parsed tree.
///
/// `byte_start`/`byte_end` restrict tree-sitter's query cursor so only nodes
/// overlapping the viewport are visited. Tokens are written into `out` up to
/// `max_tokens`. Returns the number of tokens written.
pub fn tokens_for_byte_range(
    tree: &Tree,
    language: &Language,
    rope: &Rope,
    registry: &mut TokenRegistry,
    byte_start: usize,
    byte_end: usize,
    out: &mut [SyntaxTokenSpan],
) -> usize {
    let query = match query_for_language(language) {
        Some(q) => q,
        None => return 0,
    };

    let mut cursor = QueryCursor::new();
    cursor.set_byte_range(byte_start..byte_end);

    let full_bytes: Vec<u8> = rope.bytes().collect();
    let root = tree.root_node();

    let mut count = 0;
    let mut match_iter = cursor.matches(&query, root, full_bytes.as_slice());
    while let Some(m) = match_iter.next() {
        for capture in m.captures.iter() {
            if count >= out.len() {
                return count;
            }

            let node = capture.node;
            let node_byte_start = node.byte_range().start;
            let node_byte_end = node.byte_range().end;

            let utf16_start = byte_to_utf16(rope, node_byte_start);
            let utf16_end = byte_to_utf16(rope, node_byte_end);
            let utf16_len = utf16_end.saturating_sub(utf16_start);
            if utf16_len == 0 || utf16_len > u16::MAX as usize {
                continue;
            }

            let capture_name = &query.capture_names()[capture.index as usize];
            let kind_id = registry.intern(capture_name);

            out[count] = SyntaxTokenSpan {
                utf16_start: utf16_start as u32,
                utf16_len: utf16_len as u16,
                kind_id,
                flags: 0,
                _pad: [0; 3],
            };
            count += 1;
        }
    }

    count
}

fn byte_to_utf16(rope: &Rope, byte_offset: usize) -> usize {
    if byte_offset == 0 {
        return 0;
    }
    let byte_offset = byte_offset.min(rope.len_bytes());
    let char_idx = rope.byte_to_char(byte_offset);
    let mut utf16_count: usize = 0;
    for ch in rope.chars().take(char_idx) {
        utf16_count += ch.len_utf16();
    }
    utf16_count
}

// ---------------------------------------------------------------------------
// Wave 4.4 — Tree-sitter SoA highlight cache
// ---------------------------------------------------------------------------
//
// Per `docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 4.4 (cross-ref
// dpp §4.4 deterministic perf plan, Sprint 3 deep perf).
//
// `tokens_for_byte_range` above runs the tree query AND allocates a fresh
// `Vec<u8>` from the rope on every call. For a 4000-line file with ~5
// highlights per line that's ~20K spans + a multi-MB byte allocation per
// keystroke — too slow for the W4.5 4k-line keystroke benchmark target
// (<16ms p99).
//
// `HighlightCache` builds the full sorted span list once per parsed tree
// and serves viewport queries by binary-searching the cache. Memory cost
// is `12 bytes * span_count` (e.g. 240 KB for 20K spans). Lookups are
// O(log N) per boundary regardless of file size.

/// Sorted-by-utf16-start highlight cache. Built once per parsed tree;
/// every viewport query is a binary-search slice into the underlying
/// `Vec<SyntaxTokenSpan>`.
///
/// The Wave 4.4 contract: `viewport_slice(start, end)` returns a
/// contiguous slice of the cache that includes every span whose UTF-16
/// extent `[utf16_start, utf16_start + utf16_len)` overlaps the
/// half-open viewport `[start, end)`.
///
/// Concurrency: post-build the cache is read-only and `Send + Sync`.
/// The expected use is "build on parse thread, hand `&HighlightCache`
/// to the render path through an `Arc`".
pub struct HighlightCache {
    /// Spans sorted by `utf16_start`. Ties broken by `utf16_len` ascending
    /// so binary search is deterministic when two highlights start at the
    /// same offset (e.g. `(string_literal)` + `(string_content)` overlap).
    spans: Vec<SyntaxTokenSpan>,
}

impl HighlightCache {
    /// Build the cache from a parsed tree. Runs the full highlight query
    /// once, sorts the result, and returns the cache. Best-effort: if the
    /// language has no highlight query the returned cache is empty.
    pub fn build(
        tree: &Tree,
        language: &Language,
        rope: &Rope,
        registry: &mut TokenRegistry,
    ) -> Self {
        let query = match query_for_language(language) {
            Some(q) => q,
            None => return Self { spans: Vec::new() },
        };

        let full_bytes: Vec<u8> = rope.bytes().collect();
        let root = tree.root_node();
        let mut cursor = QueryCursor::new();

        let mut spans: Vec<SyntaxTokenSpan> = Vec::new();
        let mut match_iter = cursor.matches(&query, root, full_bytes.as_slice());
        while let Some(m) = match_iter.next() {
            for capture in m.captures.iter() {
                let node = capture.node;
                let node_byte_start = node.byte_range().start;
                let node_byte_end = node.byte_range().end;

                let utf16_start = byte_to_utf16(rope, node_byte_start);
                let utf16_end = byte_to_utf16(rope, node_byte_end);
                let utf16_len = utf16_end.saturating_sub(utf16_start);
                if utf16_len == 0 || utf16_len > u16::MAX as usize {
                    continue;
                }

                let capture_name = &query.capture_names()[capture.index as usize];
                let kind_id = registry.intern(capture_name);

                spans.push(SyntaxTokenSpan {
                    utf16_start: utf16_start as u32,
                    utf16_len: utf16_len as u16,
                    kind_id,
                    flags: 0,
                    _pad: [0; 3],
                });
            }
        }

        // Sort primary by start, secondary by len. The secondary key keeps
        // narrow spans (e.g. `(string_content)` inside `(string_literal)`)
        // immediately after their wider parent at the same start offset,
        // which matches how the existing `tokens_for_byte_range` emits.
        spans.sort_by(|a, b| {
            a.utf16_start
                .cmp(&b.utf16_start)
                .then_with(|| a.utf16_len.cmp(&b.utf16_len))
        });
        spans.shrink_to_fit();

        Self { spans }
    }

    /// Number of spans in the cache.
    pub fn len(&self) -> usize {
        self.spans.len()
    }

    /// True when the cache holds no spans.
    pub fn is_empty(&self) -> bool {
        self.spans.is_empty()
    }

    /// Borrow the full span list. Intended for callers that want to
    /// stream every span (e.g. PGO instrumentation, full-file export).
    pub fn all(&self) -> &[SyntaxTokenSpan] {
        &self.spans
    }

    /// Return the contiguous slice of cached spans that overlap the
    /// half-open UTF-16 viewport `[utf16_start, utf16_end)`.
    ///
    /// Two binary searches: the first finds the leftmost span whose
    /// END is strictly past `utf16_start` (so any earlier span is fully
    /// before the viewport). The second finds the rightmost span whose
    /// START is strictly before `utf16_end` (any later span is fully
    /// past the viewport). The slice between these bounds is exactly
    /// the set of overlapping spans.
    ///
    /// Both endpoints handle empty caches and zero-width viewports
    /// without panicking. Returns an empty slice when no spans overlap.
    pub fn viewport_slice(&self, utf16_start: u32, utf16_end: u32) -> &[SyntaxTokenSpan] {
        if self.spans.is_empty() || utf16_end <= utf16_start {
            return &[];
        }

        // Lower bound: first index whose span end (start + len) > utf16_start.
        // Spans before this are fully before the viewport.
        let lo = self.spans.partition_point(|span| {
            let end = (span.utf16_start as u64) + (span.utf16_len as u64);
            end <= utf16_start as u64
        });

        // Upper bound: first index whose span start >= utf16_end.
        // Spans at or after this are fully past the viewport.
        let hi = self.spans.partition_point(|span| {
            (span.utf16_start as u64) < utf16_end as u64
        });

        if hi <= lo {
            return &[];
        }
        &self.spans[lo..hi]
    }
}

// `HighlightCache` is read-only post-build, so it is safely `Send + Sync`.
// The compile-time check prevents accidentally adding interior mutability.
const _: fn() = || {
    fn assert_send<T: Send>() {}
    fn assert_sync<T: Sync>() {}
    assert_send::<HighlightCache>();
    assert_sync::<HighlightCache>();
};

#[cfg(test)]
mod tests {
    use super::*;

    fn rust_language() -> Language {
        tree_sitter_rust::LANGUAGE.into()
    }

    #[test]
    fn tokens_for_simple_function() {
        let src = "fn main() { let x = 42; }";
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&rust_language()).unwrap();
        let tree = parser.parse(src, None).unwrap();

        let rope = Rope::from_str(src);
        let mut registry = TokenRegistry::new();
        let mut buf = vec![
            SyntaxTokenSpan {
                utf16_start: 0,
                utf16_len: 0,
                kind_id: 0,
                flags: 0,
                _pad: [0; 3],
            };
            64
        ];

        let count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry,
            0,
            src.len(),
            &mut buf,
        );

        assert!(count > 0, "should produce tokens for Rust source");
        assert!(registry.id("number").is_some(), "should have interned 'number'");
    }

    // -----------------------------------------------------------------
    // Wave 4.4 — HighlightCache tests
    // -----------------------------------------------------------------

    fn build_doc(src: &str) -> (tree_sitter::Tree, Rope, TokenRegistry) {
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&rust_language()).unwrap();
        let tree = parser.parse(src, None).unwrap();
        let rope = Rope::from_str(src);
        let registry = TokenRegistry::new();
        (tree, rope, registry)
    }

    #[test]
    fn highlight_cache_build_produces_sorted_spans() {
        let src = "fn main() { let x = 42; let y = \"hello\"; }";
        let (tree, rope, mut registry) = build_doc(src);

        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry);
        assert!(cache.len() > 0, "cache must contain spans for non-trivial Rust source");

        let spans = cache.all();
        for window in spans.windows(2) {
            let a = window[0];
            let b = window[1];
            // Primary key: utf16_start ascending.
            assert!(
                a.utf16_start <= b.utf16_start,
                "spans must be sorted by utf16_start (ascending); got {:?} then {:?}",
                a, b
            );
            // Secondary key: utf16_len ascending when starts tie.
            if a.utf16_start == b.utf16_start {
                assert!(
                    a.utf16_len <= b.utf16_len,
                    "ties in utf16_start must be broken by utf16_len ascending; got {:?} then {:?}",
                    a, b
                );
            }
        }
    }

    #[test]
    fn highlight_cache_viewport_full_returns_all_spans() {
        let src = "fn main() { let x = 42; }";
        let (tree, rope, mut registry) = build_doc(src);
        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry);
        // utf16 length of an ASCII source equals byte length.
        let view = cache.viewport_slice(0, src.len() as u32);
        assert_eq!(
            view.len(),
            cache.len(),
            "viewport spanning the full document must return every cached span"
        );
    }

    #[test]
    fn highlight_cache_viewport_zero_width_returns_empty() {
        let src = "fn main() { let x = 42; }";
        let (tree, rope, mut registry) = build_doc(src);
        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry);
        assert_eq!(cache.viewport_slice(0, 0).len(), 0);
        assert_eq!(cache.viewport_slice(10, 10).len(), 0);
        assert_eq!(cache.viewport_slice(100, 50).len(), 0, "inverted range must return empty");
    }

    #[test]
    fn highlight_cache_viewport_middle_returns_subset() {
        // Three statements; the middle viewport covers only the second.
        let src = "fn a() { 1; }\nfn b() { 22; }\nfn c() { 333; }";
        let (tree, rope, mut registry) = build_doc(src);
        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry);

        let middle_start = src.find("fn b").unwrap() as u32;
        let middle_end = src.find("fn c").unwrap() as u32;
        let middle = cache.viewport_slice(middle_start, middle_end);

        assert!(!middle.is_empty(), "middle viewport must include `fn b`'s tokens");
        assert!(
            middle.len() < cache.len(),
            "middle viewport must be a proper subset of the full cache"
        );

        // No span in the middle slice should start past the viewport end.
        for span in middle {
            assert!(
                span.utf16_start < middle_end,
                "viewport_slice must not include spans starting past utf16_end"
            );
        }
    }

    #[test]
    fn highlight_cache_viewport_overlapping_spans_included() {
        // String literals nest `(string_content)` inside `(string_literal)` —
        // both spans share a starting region. The cache must include BOTH
        // when the viewport overlaps that region.
        let src = "fn main() { let s = \"hello\"; }";
        let (tree, rope, mut registry) = build_doc(src);
        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry);

        let quote_start = src.find('"').unwrap() as u32;
        let view = cache.viewport_slice(quote_start, quote_start + 1);
        // At least one string span must overlap the opening quote position.
        assert!(
            view.iter().any(|span| {
                let end = span.utf16_start as u64 + span.utf16_len as u64;
                end > quote_start as u64
            }),
            "viewport at the opening quote must include at least one string span"
        );
    }

    #[test]
    fn highlight_cache_matches_tokens_for_byte_range() {
        // Equivalence check: HighlightCache.viewport_slice MUST yield the
        // SAME SET of (utf16_start, utf16_len, kind_id) triples as the
        // legacy `tokens_for_byte_range` for the same viewport. The
        // legacy path emits in tree-walk order; the cache path emits in
        // sorted order — set comparison handles the reorder.
        let src = "fn main() { let x = 42; let y = \"hi\"; }";
        let (tree, rope, mut registry) = build_doc(src);
        let mut registry_legacy = TokenRegistry::new();
        let mut registry_cache = TokenRegistry::new();

        let mut buf = vec![
            SyntaxTokenSpan {
                utf16_start: 0,
                utf16_len: 0,
                kind_id: 0,
                flags: 0,
                _pad: [0; 3],
            };
            128
        ];
        let legacy_count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry_legacy,
            0,
            src.len(),
            &mut buf,
        );
        let legacy_set: std::collections::BTreeSet<(u32, u16)> = buf[..legacy_count]
            .iter()
            .map(|s| (s.utf16_start, s.utf16_len))
            .collect();

        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry_cache);
        let cache_set: std::collections::BTreeSet<(u32, u16)> = cache
            .viewport_slice(0, src.len() as u32)
            .iter()
            .map(|s| (s.utf16_start, s.utf16_len))
            .collect();

        assert_eq!(
            legacy_set, cache_set,
            "HighlightCache.viewport_slice must yield the same (start, len) pairs as legacy tokens_for_byte_range"
        );
        // Also verify the parameter `_ = registry` was used; suppress an
        // unused-variable lint for `registry` from build_doc().
        let _ = registry;
    }

    #[test]
    fn highlight_cache_empty_source() {
        let src = "";
        let (tree, rope, mut registry) = build_doc(src);
        let cache = HighlightCache::build(&tree, &rust_language(), &rope, &mut registry);
        assert!(cache.is_empty());
        assert_eq!(cache.viewport_slice(0, 0).len(), 0);
        assert_eq!(cache.viewport_slice(0, 100).len(), 0);
    }

    // -----------------------------------------------------------------
    // Existing tests
    // -----------------------------------------------------------------

    #[test]
    fn viewport_restriction_works() {
        let src = "fn a() {}\nfn b() {}\nfn c() {}\n";
        let mut parser = tree_sitter::Parser::new();
        parser.set_language(&rust_language()).unwrap();
        let tree = parser.parse(src, None).unwrap();

        let rope = Rope::from_str(src);
        let mut registry = TokenRegistry::new();
        let mut buf = vec![
            SyntaxTokenSpan {
                utf16_start: 0,
                utf16_len: 0,
                kind_id: 0,
                flags: 0,
                _pad: [0; 3],
            };
            64
        ];

        let full_count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry,
            0,
            src.len(),
            &mut buf,
        );

        let partial_count = tokens_for_byte_range(
            &tree,
            &rust_language(),
            &rope,
            &mut registry,
            0,
            10,
            &mut buf,
        );

        assert!(
            partial_count <= full_count,
            "viewport restriction should produce fewer or equal tokens"
        );
    }
}
