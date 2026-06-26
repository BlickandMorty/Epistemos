import Foundation
import AppKit

// Reskin (2026-06-24; plan in WORK_OPENWORK_PARITY_LEDGER §RESKIN PLAN): the OpenWork SPA themes ENTIRELY via CSS
// custom properties — `--dls-*` design tokens + shadcn `--background/--foreground/--primary/…` — defined on `:root`
// and `[data-theme="dark"]` (donor `apps/app/src/app/index.css`). So we can impose the Epistemos look WITHOUT
// rebuilding the SPA by injecting a `<style>` (served alongside the auto-connect bootstrap by `WorkSPAServer`) that
// overrides those tokens with `EpistemosTheme` values. `!important` + the combined `:root,[data-theme="dark"]`
// selector force the Epistemos palette regardless of the SPA's own light/dark toggle.
//
// LOOK-BEARING → owner visual proof is OWED. v1 maps the high-impact tokens (bg / surface / text / accent / border);
// remaining tokens (charts, warning, ring nuance) keep the SPA defaults until refined against a screenshot.
enum WorkSPAReskin {
    /// The `<style id="epistemos-reskin">…</style>` block overriding OpenWork's theme tokens with `theme`.
    nonisolated static func styleBlock(theme: EpistemosTheme.ResolvedTheme) -> String {
        let bg = cssColor(theme.background)
        let fg = cssColor(theme.foreground)
        let accent = cssColor(theme.accent)
        let muted = cssColor(theme.muted)
        let mutedFg = cssColor(theme.mutedForeground)
        let border = cssColor(theme.border)
        let accentFg = "#ffffff" // accent is a saturated brand color → white foreground reads on it

        let vars: [(String, String)] = [
            // OpenWork design-language-system tokens
            ("--dls-app-bg", bg), ("--dls-background", bg), ("--dls-surface", bg), ("--dls-canvas", bg),
            ("--dls-sidebar", muted), ("--dls-surface-muted", muted),
            ("--dls-text-primary", fg), ("--dls-text-secondary", mutedFg),
            ("--dls-accent", accent), ("--dls-accent-hover", accent), ("--dls-accent-fg", accentFg),
            ("--dls-border", border), ("--dls-hover", muted), ("--dls-active", muted),
            // shadcn tokens
            ("--background", bg), ("--foreground", fg), ("--card", bg), ("--card-foreground", fg),
            ("--popover", bg), ("--popover-foreground", fg), ("--popover-border", border),
            ("--primary", accent), ("--primary-foreground", accentFg),
            ("--secondary", muted), ("--secondary-foreground", fg),
            ("--muted", muted), ("--muted-foreground", mutedFg),
            ("--accent", muted), ("--accent-foreground", fg),
            ("--border", border), ("--input", border),
            // "DUI" flat/boxy: kill the curved-radius + shadows at the token level (the SPA's 16px radius → square).
            ("--dls-radius", "0px"), ("--dls-radius-lg", "0px"), ("--radius", "0px"),
            ("--dls-shell-shadow", "none"), ("--dls-card-shadow", "none"),
        ]
        let body = vars.map { "\($0.0):\($0.1)!important;" }.joined()
        return "<style id=\"epistemos-reskin\">:root,[data-theme=\"dark\"]{\(body)}\(duiRules(accent: accent))</style>"
    }

    /// The "DUI" global rules (owner: flat, boxy, MONOSPACE everywhere, block caret, "looks like code, a GUI not a
    /// TUI"). Injected as ordinary CSS rules after the token block (the injection mechanism allows arbitrary CSS,
    /// not just var overrides). `!important` + end-of-`<head>` placement win over the SPA's own styles.
    /// - Monospace is forced on every NON-SVG element (lucide icons are SVG → unaffected; keeps glyphs intact).
    /// - Square corners + no shadows/gradients = flat & boxy.
    /// - `caret-shape: block` gives a terminal-style block caret where WebKit supports it; `caret-color` colors it.
    nonisolated static func duiRules(accent: String) -> String {
        let mono = "ui-monospace,\"SF Mono\",SFMono-Regular,Menlo,Monaco,\"Cascadia Mono\",monospace"
        return [
            // monospace everywhere (exclude SVG so icon paths render normally)
            "body,body *:not(svg):not(svg *){font-family:\(mono)!important;}",
            // flat + boxy: square corners, no shadows. Keep real image backgrounds intact, but remove decorative
            // gradient utilities/inline gradients so the embedded SPA matches the flat OpenCode-style target.
            "*{border-radius:0!important;box-shadow:none!important;}",
            "[class*=\"bg-gradient-\"],[style*=\"linear-gradient\"],[style*=\"radial-gradient\"]{background-image:none!important;}",
            // block, theme-colored text caret
            "input,textarea,[contenteditable]{caret-color:\(accent)!important;caret-shape:block!important;}",
        ].joined()
    }

    /// `EpistemosTheme` color → CSS string (`#rrggbb`, or `rgba()` when translucent). System colors resolve via sRGB.
    nonisolated static func cssColor(_ token: EpistemosTheme.ResolvedColorToken) -> String {
        guard let srgb = token.nsColor.usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        let a = srgb.alphaComponent
        if a >= 0.999 { return String(format: "#%02x%02x%02x", r, g, b) }
        return String(format: "rgba(%d,%d,%d,%.3f)", r, g, b, a)
    }
}
