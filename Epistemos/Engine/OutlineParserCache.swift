import Foundation

// MARK: - OutlineParserCache (T+8 Phase-S item 3)
//
// Per `docs/CODE_EDITOR_POLISH_SCOPE.md` Phase-S item 3:
//   "Outline cache + diff (4 hrs) — hash-keyed cache around the
//    outline parser; only diff-merge on miss."
//
// `CodeEditorView.scheduleOutlineRefresh` re-parses the entire
// document on every text change debounce tick. For an unchanged
// document (e.g. after a cursor movement triggered the refresh
// path) this throws away the previously-computed outline and walks
// the whole content again. This cache returns the prior result
// when the (content, language) pair hashes identically — turning a
// re-parse into a hash compare.
//
// Single-bucket: holds only the most recent (key, value) pair.
// The outline view is per-document, and a single editor never
// flips between two contents simultaneously, so a single bucket
// is sufficient. No LRU complexity, no eviction policy tuning.
//
// Thread safety: every caller is `@MainActor`
// (`scheduleOutlineRefresh` runs in `Task { @MainActor in ... }`).
// The cache is therefore a plain class — no locking overhead.

@MainActor
final class OutlineParserCache {

    private var lastKey: Int = 0
    private var lastResult: [OutlineItem] = []
    private var seeded: Bool = false

    /// Hits since this cache was constructed. Used by
    /// `CodeEditorView` debug logs + tests to verify the cache
    /// actually short-circuits instead of always re-parsing.
    private(set) var hits: UInt64 = 0
    /// Misses since this cache was constructed.
    private(set) var misses: UInt64 = 0

    init() {}

    /// Return the outline for `(content, language)`. On hit, the
    /// prior result is returned without invoking the parser. On
    /// miss, the parser runs once + the result is memoized.
    func parse(
        content: String,
        language: String
    ) -> [OutlineItem] {
        let key = Self.computeKey(content: content, language: language)
        if seeded && key == lastKey {
            hits &+= 1
            return lastResult
        }
        misses &+= 1
        let result = OutlineParser.parse(content: content, language: language)
        lastKey = key
        lastResult = result
        seeded = true
        return result
    }

    /// Drop the memoized entry. Useful when the editor's language
    /// changes mid-session and the host wants to force a re-parse
    /// even on an identical content body (a Swift→Python language
    /// switch should not return the cached Swift outline).
    public func invalidate() {
        seeded = false
        lastKey = 0
        lastResult = []
    }

    private static func computeKey(content: String, language: String) -> Int {
        var hasher = Hasher()
        hasher.combine(content)
        hasher.combine(language)
        return hasher.finalize()
    }
}
