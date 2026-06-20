import Testing
import Foundation

@testable import Epistemos

// SS-THX item (4a, owner 2026-06-20): the theme-switch HANG. AppCustomTheme.resolved(isDark:)
// rebuilt the whole ResolvedTheme from ~15-20 synchronous UserDefaults reads on EVERY
// `theme.resolved.*` access — dozens per view body × the tree per toggle = thousands of
// rebuilds on the MainActor. Fix: memoize the resolve keyed on (revision, isDark); the
// revision bumps on every color writer (setHex / reset). Prerequisite for SS-TC.
// Serialized: these probe a shared static counter on the live `.standard` store.
@Suite("SS-THX custom-theme resolve cache", .serialized)
struct SSTHXThemeCacheTests {

    @Test("a theme read resolves ONCE per change, not per-read (the hang fix)")
    func resolveIsMemoizedPerRevision() {
        // Invalidate, then read many times. A memoized resolve rebuilds ~once per
        // (revision, isDark), NOT once per read — the uncached path would rebuild on every
        // read (the hang).
        AppCustomTheme.bumpThemeRevision()
        let before = AppCustomTheme.resolveBuildCount
        for _ in 0..<200 { _ = AppCustomTheme.resolved(isDark: true) }
        let rebuilds = AppCustomTheme.resolveBuildCount - before
        // ≈1 (a little slack only if another suite raced the shared revision) — NOT 200.
        #expect(rebuilds <= 5)
    }

    @Test("a color change invalidates the cache (edits repaint — never stale)")
    func colorChangeInvalidates() {
        _ = AppCustomTheme.resolved(isDark: true)  // prime the cache
        let primed = AppCustomTheme.resolveBuildCount
        AppCustomTheme.bumpThemeRevision()         // what setHex / reset do on a color write
        _ = AppCustomTheme.resolved(isDark: true)  // must rebuild, not serve the stale theme
        #expect(AppCustomTheme.resolveBuildCount > primed)
    }

    @Test("every custom-theme color writer bumps the revision (complete invalidation)")
    func writersBumpRevision() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Theme/EpistemosTheme.swift")
        // setHex + reset both invalidate; resolved() gates the cache on (revision, isDark).
        #expect(src.contains("if defaults === UserDefaults.standard { bumpThemeRevision() }"))
        #expect(src.contains("if let entry = _cache[isDark], entry.revision == revision"))
    }
}
