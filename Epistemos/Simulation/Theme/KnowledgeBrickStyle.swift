//
//  KnowledgeBrickStyle.swift
//  Simulation Mode S6 — design tokens for the Notes Sidebar
//
//  Per DOCTRINE §3.4.3 v1.6: the sidebar is the highest-density,
//  most-expressive surface in the app — typography, density, and
//  motion are tightly specified so the implementation matches
//  the canonical "knowledge-brick" aesthetic.
//
//  Every UI in `Epistemos/Simulation/Views/*Sidebar*` reads its
//  fonts / spacing / motion durations / brand colour helpers
//  from this module. Adding a new sidebar affordance MUST go
//  through these tokens — direct font / padding / animation
//  literals in view bodies are drift.
//

import SwiftUI

public enum KnowledgeBrickStyle {

    // MARK: - Typography (DOCTRINE §3.4.3)

    /// Sidebar title — New York semibold 16 pt. Warm, editorial,
    /// distinct from the SF Pro chrome elsewhere.
    public static let sidebarTitleFont: Font =
        .system(size: 16, weight: .semibold, design: .serif)

    /// Picker section header — Company name. Tracking +0.06em,
    /// uppercase via `.textCase(.uppercase)` at the call site.
    public static let companyHeaderFont: Font =
        .system(size: 11, weight: .semibold, design: .default)

    /// Picker subsection — Model row.
    public static let modelRowFont: Font =
        .system(size: 12, weight: .medium, design: .default)

    /// Agent leaf — paired with the 20 pt pixel-art mascot.
    /// SF Compact Rounded medium for warmth against the precise
    /// pixel-art mascot.
    public static let agentLeafFont: Font =
        .system(size: 13, weight: .medium, design: .rounded)

    /// Per-companion helper-model summary line in the dispatch
    /// panel / sidebar (§3.4.5).
    public static let summaryLineFont: Font =
        .system(size: 11, weight: .regular, design: .default)

    /// Note title rows under a vault.
    public static let noteTitleFont: Font =
        .system(size: 13, weight: .regular, design: .default)

    // MARK: - Density (DOCTRINE §3.4.3)

    /// Indent step per hierarchy level. Tight to fit four levels
    /// (company / model / agent leaf / per-agent vault tree)
    /// inside the 240-pt-wide column.
    public static let indentStep: CGFloat = 12

    /// Tree-row height (notes, sub-folders, vault disclosure
    /// children).
    public static let treeRowHeight: CGFloat = 22

    /// Model header row — slightly taller than tree rows for
    /// section legibility.
    public static let modelRowHeight: CGFloat = 28

    /// Agent leaf row — needs height to fit the 20 pt mascot
    /// tile + descenders on the agent name.
    public static let agentLeafHeight: CGFloat = 32

    /// Company section header row.
    public static let companyHeaderHeight: CGFloat = 24

    /// Default sidebar column width.
    public static let sidebarDefaultWidth: CGFloat = 240
    public static let sidebarMinWidth: CGFloat = 200
    public static let sidebarMaxWidth: CGFloat = 360

    // MARK: - Motion (DOCTRINE §3.4.3)

    /// Disclosure expand / collapse — spring-loaded ease-out.
    public static let disclosureAnimation: Animation =
        .spring(response: 0.22, dampingFraction: 0.85)

    /// Selection pulse — accent dot brightens then settles.
    public static let selectionPulseDuration: Double = 0.18
    public static let selectionPulseAnimation: Animation =
        .easeOut(duration: selectionPulseDuration)

    /// Toggle-chip pulse on enable/disable.
    public static let toggleChipPulseDuration: Double = 0.14
    public static let toggleChipAnimation: Animation =
        .easeInOut(duration: toggleChipPulseDuration)

    /// Sidebar workspace re-skin cross-fade.
    public static let reskinDuration: Double = 0.25
    public static let reskinAnimation: Animation = .easeInOut(duration: reskinDuration)

    // MARK: - Brand colour (DOCTRINE §10.7 / §3.4.3)

    /// Decode a `#RRGGBB` hex string from `provenance.json` into
    /// a SwiftUI `Color`. Returns `.accentColor` on parse failure
    /// so the UI never renders a black/transparent fallback.
    public static func brandColor(hex: String) -> Color {
        guard hex.hasPrefix("#"), hex.count == 7 else {
            return .accentColor
        }
        let scanner = Scanner(string: String(hex.dropFirst()))
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return .accentColor }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Composite shape style helpers

    /// Active-workspace section underline — 1 pt brand-color
    /// line at the row baseline.
    public static func activeUnderline(brand: Color) -> some View {
        Rectangle()
            .fill(brand)
            .frame(height: 1)
            .padding(.horizontal, 4)
    }

    /// Per-companion accent dot. 8 pt circle, drawn beside an
    /// agent leaf or section header.
    public static func accentDot(brand: Color, intensity: Double = 1.0) -> some View {
        Circle()
            .fill(brand)
            .frame(width: 8, height: 8)
            .opacity(intensity)
    }
}
