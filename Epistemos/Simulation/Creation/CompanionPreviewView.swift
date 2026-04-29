//
//  CompanionPreviewView.swift
//  Simulation Mode S8 — live composed sprite preview for the
//  creation wizard (§6.1).
//
//  Per IMPLEMENTATION §S8 the wizard preview composes sprite
//  axes in real time using SwiftUI image layers. This is fine
//  for the small wizard preview pane — gameplay rendering uses
//  Metal (S4 + S7), but the wizard's 96×96 preview is too small
//  to justify a separate render pass.
//
//  Pre-S10 each axis renders as a simple geometric placeholder
//  keyed off the current spec value so the user gets *some*
//  visual feedback per choice. S10 swaps the placeholders for
//  the canonical Tamagotchi atlas tile.
//

import SwiftUI

public struct CompanionPreviewView: View {
    public let headShape: String
    public let paletteHex: String
    public let eyes: String
    public let arms: String
    public let prop: String?

    public init(
        headShape: String,
        paletteHex: String,
        eyes: String,
        arms: String,
        prop: String?
    ) {
        self.headShape = headShape
        self.paletteHex = paletteHex
        self.eyes = eyes
        self.arms = arms
        self.prop = prop
    }

    public var body: some View {
        ZStack {
            bodyLayer
            armsLayer
            eyesLayer
            propLayer
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("Companion preview")
    }

    // MARK: - Body shape

    @ViewBuilder
    private var bodyLayer: some View {
        let color = brandColor
        switch headShape {
        case "Block":
            // Per §5.1 Block is a square pixel block. We render
            // a rounded square so it reads as a chunky block at
            // 96×96 without literal pixel fidelity.
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .frame(width: 64, height: 64)
        case "Orb":
            Circle()
                .fill(color)
                .frame(width: 60, height: 60)
        case "Sage":
            // Tall humanoid silhouette stub.
            VStack(spacing: 2) {
                Circle().fill(color).frame(width: 28, height: 28)
                RoundedRectangle(cornerRadius: 5)
                    .fill(color).frame(width: 36, height: 36)
            }
        case "HermesSnake":
            // Hermes preset isn't reachable in S8 (deferred to
            // S9), but render *something* if a stale spec lands
            // here.
            RoundedRectangle(cornerRadius: 18)
                .fill(color).frame(width: 60, height: 24)
        default:
            RoundedRectangle(cornerRadius: 6).fill(color)
                .frame(width: 60, height: 60)
        }
    }

    // MARK: - Eyes overlay

    @ViewBuilder
    private var eyesLayer: some View {
        switch eyes {
        case "Round":
            HStack(spacing: 8) {
                Circle().fill(.black).frame(width: 6, height: 6)
                Circle().fill(.black).frame(width: 6, height: 6)
            }
            .offset(y: -8)
        case "Slit":
            HStack(spacing: 8) {
                Capsule().fill(.black).frame(width: 8, height: 2)
                Capsule().fill(.black).frame(width: 8, height: 2)
            }
            .offset(y: -8)
        case "Visor":
            RoundedRectangle(cornerRadius: 1)
                .fill(.black)
                .frame(width: 36, height: 4)
                .offset(y: -8)
        case "Closed":
            HStack(spacing: 8) {
                Capsule().fill(.black.opacity(0.7)).frame(width: 8, height: 2)
                Capsule().fill(.black.opacity(0.7)).frame(width: 8, height: 2)
            }
            .offset(y: -8)
        case "NegativeSpace":
            HStack(spacing: 8) {
                Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6)
                Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6)
            }
            .offset(y: -8)
        default:
            EmptyView()
        }
    }

    // MARK: - Arms overlay

    @ViewBuilder
    private var armsLayer: some View {
        switch arms {
        case "Short":
            HStack(spacing: 60) {
                Capsule().fill(brandColor).frame(width: 6, height: 14)
                Capsule().fill(brandColor).frame(width: 6, height: 14)
            }
            .offset(y: 4)
        case "Long":
            HStack(spacing: 64) {
                Capsule().fill(brandColor).frame(width: 6, height: 26)
                Capsule().fill(brandColor).frame(width: 6, height: 26)
            }
            .offset(y: 10)
        default:
            EmptyView()
        }
    }

    // MARK: - Prop overlay

    @ViewBuilder
    private var propLayer: some View {
        if let prop = prop {
            Image(systemName: propSymbol(for: prop))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(
                    Circle().fill(brandColor.opacity(0.9))
                )
                .offset(x: 30, y: 24)
        }
    }

    private func propSymbol(for prop: String) -> String {
        switch prop {
        case "Wrench":   return "wrench.adjustable"
        case "Scroll":   return "doc.text"
        case "Magnifier": return "magnifyingglass"
        case "Folder":   return "folder.fill"
        case "Baton":    return "music.note.list"
        case "Lantern":  return "flame.fill"
        default:         return "questionmark"
        }
    }

    // MARK: - Color helpers

    private var brandColor: Color {
        if paletteHex.hasPrefix("#"), paletteHex.count == 7 {
            return Color(hex: paletteHex) ?? .gray
        }
        // Curated palette slug → known hex.
        switch paletteHex {
        case "claude_warm_v1": return Color(hex: "#D97757") ?? .orange
        case "kimi_indigo_v1": return Color(hex: "#5B8DEF") ?? .blue
        case "local_teal_v1":  return Color(hex: "#2BA59B") ?? .teal
        case "hermes_gold_v1": return Color(hex: "#D4AF37") ?? .yellow
        case "gpt_neutral_v1": return Color(hex: "#9C9C9C") ?? .gray
        default:               return .gray
        }
    }
}

extension Color {
    /// Lenient `#RRGGBB` parser used only by the wizard preview.
    /// The Rust-side validation is the source of truth for real
    /// input; this helper just produces *some* render colour for
    /// any 7-char hex without erroring. Returns `nil` for
    /// non-hex input so the caller can fall back to gray.
    fileprivate init?(hex: String) {
        guard hex.count == 7, hex.first == "#" else { return nil }
        var r: UInt64 = 0
        var g: UInt64 = 0
        var b: UInt64 = 0
        let scanR = Scanner(string: String(hex.dropFirst().prefix(2)))
        let scanG = Scanner(string: String(hex.dropFirst(3).prefix(2)))
        let scanB = Scanner(string: String(hex.dropFirst(5).prefix(2)))
        guard scanR.scanHexInt64(&r), scanG.scanHexInt64(&g), scanB.scanHexInt64(&b) else {
            return nil
        }
        self = Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}
