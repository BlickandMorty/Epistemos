import Foundation
import OSLog
import SwiftUI

// MARK: - CognitiveDepthOverlay
//
// Phase 8 of the master plan / Wave 13 §"Phase 8" Swift bridge: maps
// every note in the vault to a `DepthMarker` (L1 surface / L2
// synthesized / L3 coreBelief) so the existing MetalGraphView can
// color + scale nodes by their cognitive weight without owning the
// schema itself.
//
// Depth source-of-truth precedence (highest → lowest):
//   1. Per-note sidecar (`<note-stem>.epistemos.json` `depth` field)
//   2. In-memory user override (e.g. user manually promoted a note
//      to coreBelief from the inspector — written through to sidecar
//      on next save)
//   3. Default `surface` for any note not yet classified
//
// The overlay is queried by the graph rendering layer per-frame in
// the worst case; it caches the depth lookup in a hash map so the
// hot path is O(1). Sidecar writes invalidate the cache for the
// affected entity only.
//
// Master-plan Phase 8 design notes:
//   - L1 Surface  = ABox-only, ephemeral; renders as low-altitude
//                   small-radius node with cool tint.
//   - L2 Synthesized = ABox + lightweight type assertions; mid-
//                   altitude + medium radius + neutral tint.
//   - L3 CoreBelief = TBox; high-altitude + large radius + warm
//                   tint; participates in the SKOS broader/narrower/
//                   related edge inference cascade.
//
// `altitude(for:)` and `colorTint(for:)` codify the visualization
// contract so the MetalGraphView can read consistently across
// rendering passes.

@MainActor
@Observable
public final class CognitiveDepthOverlay {

    public static let shared = CognitiveDepthOverlay()

    private static let log = Logger(
        subsystem: "com.epistemos",
        category: "CognitiveDepthOverlay"
    )

    /// In-memory cache keyed by source URL string (sidecar lookup
    /// path). Invalidated per-entity on `setDepth(_:for:)`.
    private var cache: [String: DepthMarker] = [:]

    /// User overrides that haven't yet been persisted to disk. Cleared
    /// when `setDepth(_:for:persist:)` writes through with persist=true.
    private var pendingOverrides: [String: DepthMarker] = [:]

    private init() {}

    // MARK: - Lookup

    /// Look up the depth marker for a source file. Reads from cache
    /// first; falls back to sidecar; defaults to `.surface` when
    /// nothing has classified the note yet.
    public func depth(for source: URL) -> DepthMarker {
        let key = source.path
        if let cached = cache[key] { return cached }
        if let pending = pendingOverrides[key] { return pending }

        // Sidecar lookup
        do {
            if let sidecar = try EpistemosSidecarStore.read(for: source) {
                cache[key] = sidecar.depth
                return sidecar.depth
            }
        } catch {
            // Ineligible source / read failure — fall through to default
            Self.log.debug(
                "depth lookup fell back to default for \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }

        let fallback: DepthMarker = .surface
        cache[key] = fallback
        return fallback
    }

    /// Set the depth marker for a source file. When `persist` is true
    /// (the default), the change writes through to the sidecar
    /// immediately. When false, the override stays in memory so the
    /// UI can preview the change before committing.
    public func setDepth(
        _ depth: DepthMarker,
        for source: URL,
        persist: Bool = true
    ) {
        let key = source.path
        if persist {
            cache[key] = depth
            pendingOverrides.removeValue(forKey: key)
            do {
                var sidecar = try EpistemosSidecarStore.read(for: source)
                    ?? EpistemosSidecarStore.mintStub(for: source, depth: depth)
                sidecar.depth = depth
                sidecar.schemaVersion = EpistemosSidecar.currentSchemaVersion
                try EpistemosSidecarStore.write(sidecar, for: source)
                Self.log.debug(
                    "persisted depth=\(depth.rawValue, privacy: .public) for \(source.lastPathComponent, privacy: .public)"
                )
            } catch {
                Self.log.warning(
                    "failed to persist depth for \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        } else {
            pendingOverrides[key] = depth
        }
    }

    /// Clear all pending overrides. Used by Cancel buttons in
    /// inspector UIs that don't want to commit changes.
    public func discardPendingOverrides() {
        pendingOverrides.removeAll()
    }

    /// Invalidate the cache entry for one source. Used by sidecar
    /// file-watcher callbacks (Phase 13) so external edits show up.
    public func invalidate(_ source: URL) {
        cache.removeValue(forKey: source.path)
    }

    /// Clear the entire cache. Useful on vault switch.
    public func resetCache() {
        cache.removeAll()
        pendingOverrides.removeAll()
    }

    // MARK: - Visualization contract

    /// Vertical altitude in the force-directed graph for a depth
    /// marker. Master plan Phase 8: L1 cool/low → L3 warm/high.
    /// Returns a normalized [0.0, 1.0] value the renderer can scale.
    public func altitude(for depth: DepthMarker) -> Float {
        switch depth {
        case .surface:     return 0.15
        case .synthesized: return 0.50
        case .coreBelief:  return 0.85
        }
    }

    /// Node radius scale factor — coreBelief renders larger so the
    /// visual hierarchy reads at a glance. Returns a multiplier the
    /// renderer applies to the base radius.
    public func radiusScale(for depth: DepthMarker) -> Float {
        switch depth {
        case .surface:     return 0.7
        case .synthesized: return 1.0
        case .coreBelief:  return 1.5
        }
    }

    /// Color tint per depth — cool for L1, warm for L3. Returned as a
    /// SwiftUI `Color` so MetalGraphView's bridging layer can
    /// interpolate via `Color.resolve(in:)` when needed.
    public func colorTint(for depth: DepthMarker) -> Color {
        switch depth {
        case .surface:     return Color(red: 0.45, green: 0.55, blue: 0.75)  // cool blue
        case .synthesized: return Color(red: 0.65, green: 0.65, blue: 0.65)  // neutral grey
        case .coreBelief:  return Color(red: 0.85, green: 0.55, blue: 0.30)  // warm amber
        }
    }

    // MARK: - Bulk pre-warm

    /// Pre-load the depth markers for a batch of source URLs (e.g.
    /// the vault's notes directory) so the graph renderer's first
    /// frame doesn't pay per-node sidecar I/O. Returns the number of
    /// entries warmed (== sources.count when no I/O failures).
    @discardableResult
    public func prewarm(sources: [URL]) -> Int {
        var warmed = 0
        for source in sources {
            _ = depth(for: source)
            warmed += 1
        }
        return warmed
    }
}
