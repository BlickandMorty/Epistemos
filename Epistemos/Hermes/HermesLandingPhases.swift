//
//  HermesLandingPhases.swift
//  Simulation Mode S9 — 7-phase landing-ritual phase enum +
//  per-phase duration constants per DOCTRINE §8.2.2.
//
//  Total ritual duration: ~4.7 s (300+600+800+1000+500+700+200+600).
//  Phase 0 "Anchor" is treated as a 300 ms cross-fade and is
//  numbered separately from the canonical 7 phases that follow.
//
//  Reduce-motion variant per §8.2.4 collapses the entire timeline
//  to a 450 ms instant-pose path.
//

import Foundation

/// One phase of the Hermes landing ritual. The ordering is
/// canonical: phase 0 cross-fades the prior scene out, phases
/// 1–7 stage the opulent treatment, phase 8 hands control to
/// the chat surface.
public enum HermesLandingPhase: Int, CaseIterable, Sendable {
    /// Phase 0 — cross-fade the prior scene to the deep-indigo
    /// base layer (`#0A0A1F`). Existing Landing Farm sprites
    /// fade out.
    case anchor              = 0
    /// Phase 1 — ASCII Nous Research portrait fades in at the
    /// left half of the canvas.
    case portraitEmerges     = 1
    /// Phase 2 — rightward ASCII-character wave sweeps across
    /// the canvas.
    case asciiWave           = 2
    /// Phase 3 — "HERMES-AGENT" pixel-art wordmark types on
    /// glyph-by-glyph at the right half.
    case heroTitleTypes      = 3
    /// Phase 4 — separate additive-blend gold halo quad pulses
    /// (0 → 0.6 → 0.3, then holds at 0.3 for the session).
    case goldHaloPulse       = 4
    /// Phase 5 — canonical snake mascot fades in at the lower
    /// center, performs a single coil animation (5 frames,
    /// integer-pixel motion).
    case snakeCoils          = 5
    /// Phase 6 — single-frame additive glare flash sweeps left
    /// to right.
    case glareFlash          = 6
    /// Phase 7 — Hermes chat surface slides up from the bottom
    /// edge (250 pt height, easeOut).
    case chatEmerges         = 7

    /// Duration (in milliseconds) for the standard ritual per
    /// §8.2.2 table.
    public var standardDurationMs: Int {
        switch self {
        case .anchor:           return 300
        case .portraitEmerges:  return 600
        case .asciiWave:        return 800
        case .heroTitleTypes:   return 1000
        case .goldHaloPulse:    return 500
        case .snakeCoils:       return 700
        case .glareFlash:       return 200
        case .chatEmerges:      return 600
        }
    }

    /// Duration in seconds (Double) for SwiftUI animations.
    public var standardDuration: Double {
        Double(standardDurationMs) / 1000.0
    }

    /// Reduce-motion duration per §8.2.4. Collapses everything
    /// to ~450ms; phases that are pure motion (wave, halo
    /// pulse, coil, glare) become 0 ms (instant pose).
    public var reduceMotionDurationMs: Int {
        switch self {
        case .anchor:           return 150
        case .portraitEmerges:  return 0   // appear instantly
        case .asciiWave:        return 0   // skip
        case .heroTitleTypes:   return 0   // appear instantly
        case .goldHaloPulse:    return 0   // hold at 0.3 immediately
        case .snakeCoils:       return 0   // skip coil animation
        case .glareFlash:       return 0   // skip
        case .chatEmerges:      return 300
        }
    }

    /// Cumulative offset (ms) where this phase BEGINS, in the
    /// standard timeline. Used by the orchestrator to schedule
    /// per-phase enter actions.
    public var standardOffsetMs: Int {
        Self.allCases
            .prefix(while: { $0.rawValue < self.rawValue })
            .map(\.standardDurationMs)
            .reduce(0, +)
    }

    /// Cumulative offset (ms) where this phase BEGINS, in the
    /// reduce-motion timeline.
    public var reduceMotionOffsetMs: Int {
        Self.allCases
            .prefix(while: { $0.rawValue < self.rawValue })
            .map(\.reduceMotionDurationMs)
            .reduce(0, +)
    }
}

/// Total ritual duration (sum of all phase durations).
public enum HermesLandingTimeline {
    /// ~4.7 s for the standard opulent treatment.
    public static let standardTotalMs: Int = HermesLandingPhase.allCases
        .map(\.standardDurationMs)
        .reduce(0, +)

    /// ~450 ms for the reduce-motion variant.
    public static let reduceMotionTotalMs: Int = HermesLandingPhase.allCases
        .map(\.reduceMotionDurationMs)
        .reduce(0, +)

    /// `true` when macOS reports reduce-motion preference is on.
    /// Wraps `NSAccessibility.isReduceMotionEnabled` so the
    /// orchestrator can branch on it without importing AppKit
    /// at call sites.
    @MainActor
    public static var isReduceMotionEnabled: Bool {
        // Imported lazily — keeps the type usable from non-AppKit
        // surfaces (tests, previews) without the framework dep.
        #if canImport(AppKit)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return false
        #endif
    }
}

#if canImport(AppKit)
import AppKit
#endif
