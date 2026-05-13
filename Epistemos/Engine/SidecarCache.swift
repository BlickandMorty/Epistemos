import Foundation
import OSLog

// MARK: - SidecarCache (AP2 + AP7)
//
// Process-wide LRU cache for `EpistemosSidecar` objects so the
// CognitiveDepthOverlay graph hot path + the W11.4 inspector + the
// W10.1 classifier persist path all share one decode. Was: every
// caller paid a `Data(contentsOf:)` + JSONDecoder.decode per query
// (the perf agent's Win #2 measurement: 12 ms per per-frame depth
// lookup × 60 nodes/frame = 720 ms of file I/O per second on a
// 60-FPS pan/zoom; complete CPU stall).
//
// Now: first decode populates the cache; subsequent reads are O(1)
// for both lookup AND touch (RCA13 P2-015 fix). Eviction is O(n)
// in cache size but only fires when count exceeds `bound`, not on
// every read.
// in-memory lookups. Bulk vault-prefetch (AP7) at AppBootstrap time
// fires `prefetchAll(under:)` so the first frame already has the
// full vault's sidecars warm.
//
// Concurrency contract: an internal `os_unfair_lock` serialises
// reads/writes. The lookup path is synchronous (no actor hop) so
// SwiftUI render passes don't pay a Task suspension per node draw —
// the perf agent's CognitiveDepthOverlay wins depend on this.
//
// Eviction policy: LRU bounded at 4096 entries (~16 MB working set
// at typical sidecar sizes; matches CognitiveDepthOverlay's bound).

nonisolated public final class SidecarCache: @unchecked Sendable {

    public static let shared = SidecarCache()

    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "SidecarCache"
    )

    /// Max in-memory entries before LRU eviction. Each entry is one
    /// EpistemosSidecar (~1-4 KB). 4096 × ~4 KB ≈ 16 MB working set —
    /// fine for vaults of any practical size.
    public static let bound: Int = 4096

    /// `os_unfair_lock` is the canonical macOS primitive for
    /// short-critical-section contention. Lower overhead than
    /// `NSLock` / `DispatchQueue` for ≤1 µs critical sections like
    /// dictionary lookups; never blocks more than briefly so it's
    /// safe under the SwiftUI render-pass deadline.
    private let lock = OSAllocatedUnfairLock()
    /// RCA13 P2-015: store payload + a monotonically increasing
    /// touch counter. Lookup + touch are now O(1) (just dictionary
    /// access + counter bump). Eviction is O(n) in store size, but
    /// only fires when count exceeds `bound` — not on every read,
    /// which was the previous O(n) hot path under the lock.
    private struct Entry {
        let sidecar: EpistemosSidecar
        var lastTouchCounter: UInt64
    }
    private var store: [URL: Entry] = [:]
    private var touchCounter: UInt64 = 0

    private init() {}

    // MARK: - Public API

    public func lookup(_ url: URL) -> EpistemosSidecar? {
        lock.withLock {
            guard var entry = store[url] else { return nil }
            touchCounter &+= 1
            entry.lastTouchCounter = touchCounter
            store[url] = entry
            return entry.sidecar
        }
    }

    public func store(_ sidecar: EpistemosSidecar, for url: URL) {
        lock.withLock {
            touchCounter &+= 1
            store[url] = Entry(sidecar: sidecar, lastTouchCounter: touchCounter)
            evictLocked()
        }
    }

    public func invalidate(_ url: URL) {
        // `removeValue(forKey:)` returns the evicted entry (an
        // `Optional<EpistemosSidecar>`); the closure therefore returns
        // that optional, which `withLock` propagates. Discard with
        // `_ =` so Swift 6 strict-result-of-call doesn't warn-as-error.
        _ = lock.withLock {
            store.removeValue(forKey: url)
        }
    }

    public func reset() {
        lock.withLock {
            store.removeAll()
            touchCounter = 0
        }
        Self.log.debug("SidecarCache reset")
    }

    public var count: Int {
        lock.withLock { store.count }
    }

    // MARK: - Internals (lock-held)

    /// O(n) eviction — scans for the oldest counter and drops it.
    /// Only fires when count > bound, which under steady-state load
    /// happens at most once per insert past 4096, not per read.
    private func evictLocked() {
        while store.count > Self.bound {
            guard let oldestURL = store.min(by: {
                $0.value.lastTouchCounter < $1.value.lastTouchCounter
            })?.key else { return }
            store.removeValue(forKey: oldestURL)
        }
    }
}
