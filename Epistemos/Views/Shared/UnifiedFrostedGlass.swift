import SwiftUI

// MARK: - Unified Frosted Glass
//
// 2026-05-20 — HYBRID DESIGN (revised after live testing).
//
// THE TWO MATERIAL CATEGORIES IN THIS APP:
//
//   1. WINDOW WALLPAPER BLUR (NSVisualEffectView)
//      One per window, at the contentView level. Wraps the whole window
//      behind every SwiftUI surface inside it. Set up by:
//        - `HologramOverlay.swift`  (graph window + mini panel + mini inspector)
//        - `ShadowPanel.swift`      (Halo panel)
//        - MiniChat's window        (its own 3-layer stack; left untouched)
//
//   2. CHROME GLASS (macOS 26 `.glassEffect()` SwiftUI modifier)
//      Native Liquid Glass primitive. Apple optimized this for chrome
//      controls (toolbars, sidebars, capsules, inspectors). It composites
//      on top of the wallpaper blur as a single GPU shader pass — NOT a
//      second NSVisualEffectView blur kernel. Cheaper than stacked
//      `.ultraThinMaterial`, and required to make chrome read as "native
//      macOS controls" rather than flat tinted boxes.
//
// The previous all-tint-only rewrite (2026-05-20 morning) stripped chrome
// glass entirely. Toolbar + sidebar lost their native liquid-glass feel
// and read as flat gray. This revision restores chrome glass on the
// interactive surfaces + a `nativeGlass: true` opt-in for non-interactive
// chrome (the graph note/folder header strip) while still letting
// backdrops + folder rows + the Halo panel content stay tint-only
// (because those are wide surfaces that should inherit the window blur).
//
// API SUMMARY:
//
//   - Default (no flags):        tint + stroke + soft drop shadow. Use for
//                                backdrops and large surfaces that should
//                                show the window wallpaper blur through.
//
//   - `nativeGlass: true`:       macOS 26 `.glassEffect(.regular, in: shape)`
//                                + theme tint behind. Use for non-interactive
//                                chrome (toolbar header strip, fixed bars).
//
//   - `interactive: true`:       `.glassEffect(.regular.interactive(), in: shape)`
//                                + theme tint behind. Use for pressable
//                                chrome (capsule controls, inspector,
//                                search sidebar). Press feedback comes
//                                from the native material — no extra
//                                ButtonStyle needed.
//
// THEME PASS-THROUGH preserved on every variant — the chrome reads
// the active EpistemosTheme through `theme.glassBg` + `theme.glassBorder`.
//
// Untouched: graph theme pass-through, physics defaults, label settings,
// shape-bound defaults, MiniChat itself, the 120Hz CADisplayLink in
// MetalGraphView.

extension View {
    func unifiedFrostedGlass<S: InsettableShape>(
        theme: EpistemosTheme,
        in shape: S,
        extraDarkenOnDark: Bool = false,
        interactive: Bool = false,
        nativeGlass: Bool = false
    ) -> some View {
        modifier(
            UnifiedFrostedGlassViewModifier(
                theme: theme,
                shape: shape,
                extraDarkenOnDark: extraDarkenOnDark,
                interactive: interactive,
                nativeGlass: nativeGlass
            )
        )
    }
}

private struct UnifiedFrostedGlassViewModifier<S: InsettableShape>: ViewModifier {
    let theme: EpistemosTheme
    let shape: S
    let extraDarkenOnDark: Bool
    let interactive: Bool
    let nativeGlass: Bool

    func body(content: Content) -> some View {
        if interactive {
            // Native macOS 26 Liquid Glass with interactive press feedback.
            // `.glassEffect` is ONE optimized GPU shader pass — not a stack
            // of `.ultraThinMaterial`. Keeps the chrome reading as native
            // pressable controls while staying within the compositor budget.
            content
                .background(themeTintBehindNativeGlass)
                .glassEffect(.regular.interactive(), in: shape)
        } else if nativeGlass {
            // Native macOS 26 Liquid Glass (non-interactive). For chrome
            // bars / headers that should look like native macOS toolbars
            // but don't have press feedback.
            content
                .background(themeTintBehindNativeGlass)
                .glassEffect(.regular, in: shape)
        } else {
            // Tint-only backdrop. Use for wide surfaces that should
            // inherit the window's wallpaper blur (folder backdrop,
            // Halo content background, large rectangles).
            content
                .background(tintLayer)
                .overlay(shape.strokeBorder(theme.glassBorder, lineWidth: 0.5))
                .shadow(
                    color: Color.black.opacity(theme.isDark ? 0.25 : 0.10),
                    radius: 6,
                    y: 2
                )
        }
    }

    /// Subtle theme tint sitting BEHIND the native `.glassEffect()` material.
    /// 0.35 matches MiniChat's tinting ratio — a hint of the theme color
    /// without overpowering the native liquid-glass look + its animations.
    private var themeTintBehindNativeGlass: some View {
        ZStack {
            shape.fill(theme.glassBg.opacity(0.35))
            if extraDarkenOnDark && theme.isDark {
                shape.fill(Color.black.opacity(0.10))
            }
        }
    }

    /// Tinted-color fill that lets the window's NSVisualEffectView blur
    /// show through. Non-interactive backdrops keep the full theme alpha
    /// so they read as solid tinted glass.
    private var tintLayer: some View {
        ZStack {
            shape.fill(theme.glassBg)
            if extraDarkenOnDark && theme.isDark {
                shape.fill(Color.black.opacity(0.18))
            }
        }
    }
}
