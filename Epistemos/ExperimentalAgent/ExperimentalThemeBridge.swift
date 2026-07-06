#if EPISTEMOS_EXPERIMENTAL
import AppKit
import SwiftUI

/// Phase-2 Task 2 (DoD-2): projects the LIVE Epistemos theme onto the embedded
/// 1Code SPA so the surface wears the app's palette, not stock donor colors.
///
/// 1Code is shadcn/Tailwind: CSS vars hold **HSL triplets** (`--background:
/// 0 0% 100%`) consumed as `hsl(var(--background))` (tailwind.config.js) — the
/// earlier theme bridge drop-in failed exactly because it emitted
/// `rgb(...)` (PATCH_LEDGER P2 investigation). This bridge emits HSL triplets.
///
/// Mode control: the donor's next-themes runs `defaultTheme="system"
/// enableSystem`, and the SwiftUI host pins the WebView's effective appearance
/// (`.colorScheme` + `webView.appearance`), so prefers-color-scheme — and with
/// it next-themes, Tailwind `dark:` utilities, xterm and Monaco — follows the
/// app theme natively. No class fights, no localStorage poking (the ledger's
/// second blocker dissolves at the appearance seam).
///
/// Values are inline `!important` custom properties on `documentElement`
/// (deterministically win the cascade; the donor never clears them), plus one
/// injected `<style>` for the parts vars can't reach: the donor's `.chroma-text`
/// brand gradient (hardcoded indigo/violet hex — killed to plain text) and the
/// Epistemos display font on landmarks ONLY (never transcript/editor body;
/// Monaco + xterm stay legible per §7).
@MainActor
enum ExperimentalThemeBridge {
    // MARK: - Payload

    /// `{"dark": Bool, "underPage": "...", "vars": {"--token": "H S% L%"}}`
    static func payloadJSON(for theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let dark = resolved.isDark

        let background = hsl(resolved.background, dark: dark)
        let foreground = hsl(resolved.foreground, dark: dark)
        let card = hsl(resolved.card, dark: dark)
        let muted = hsl(resolved.muted, dark: dark)
        let mutedForeground = hsl(resolved.mutedForeground, dark: dark)
        let border = hsl(resolved.border, dark: dark)
        let accent = srgb(resolved.accent.nsColor, dark: dark)
        let uiAccent = srgb(resolved.uiAccent.nsColor, dark: dark)
        let accentHSL = hsl(accent)
        let uiAccentHSL = hsl(uiAccent)

        // shadcn semantics (donor globals.css): --accent is the quiet hover
        // FILL (muted family), --primary is the brand. --destructive,
        // --plan-mode and --radius stay donor-semantic (feedback colors and
        // geometry are not brand).
        let vars: [String: String] = [
            "--background": background,
            "--foreground": foreground,
            "--card": card,
            "--card-foreground": foreground,
            "--popover": card,
            "--popover-foreground": foreground,
            "--primary": accentHSL,
            "--primary-foreground": hsl(contrastText(over: accent)),
            "--secondary": muted,
            "--secondary-foreground": foreground,
            "--muted": muted,
            "--muted-foreground": mutedForeground,
            "--accent": muted,
            "--accent-foreground": foreground,
            "--border": border,
            "--input": border,
            "--input-background": muted,
            "--ring": uiAccentHSL,
            "--selection": "\(accentHSL) / 0.28",
            "--tl-background": hsl(resolved.chatSurface, dark: dark),
        ]

        let object: [String: Any] = [
            "dark": dark,
            "vars": vars,
            "css": overrideCSS(),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"dark\":\(dark ? "true" : "false"),\"vars\":{},\"css\":\"\"}"
        }
        return json
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    /// The WKWebView's pre-paint blend color (§7 `underPageBackgroundColor`).
    static func underPageColor(for theme: EpistemosTheme) -> NSColor {
        srgb(theme.resolved.background.nsColor, dark: theme.resolved.isDark)
    }

    // MARK: - Scripts

    /// documentStart user script: defines the applier, applies the boot payload,
    /// re-asserts against SPA interference.
    ///
    /// PROBE-VERIFIED FAILURE MODE (2026-07-05): inline `style.setProperty(...,
    /// 'important')` on documentElement gets WIPED after hydration — next-themes
    /// rewrites the root style attribute — so the vars ALSO live in the injected
    /// `<style>` as `:root { --x: v !important }` (stylesheet importance beats
    /// the donor's non-important rules and survives attribute rewrites), and the
    /// observer watches the style/class attributes as well as childList.
    static func userScript(for theme: EpistemosTheme) -> String {
        """
        (function () {
          var cssFromVars = function (vars) {
            var lines = [':root {'];
            for (var k in vars) { lines.push(k + ': ' + vars[k] + ' !important;'); }
            lines.push('}');
            return lines.join('\\n');
          };
          var apply = function (payload) {
            try {
              var root = document.documentElement;
              if (!root || !payload) { return; }
              window.__EPISTEMOS_EXP_THEME__ = payload;
              root.setAttribute('data-epistemos-embed', 'true');
              var vars = payload.vars || {};
              for (var key in vars) { root.style.setProperty(key, vars[key], 'important'); }
              var style = document.getElementById('epistemos-exp-theme');
              if (!style) {
                style = document.createElement('style');
                style.id = 'epistemos-exp-theme';
                (document.head || root).appendChild(style);
              }
              var want = cssFromVars(vars) + '\\n' + (payload.css || '');
              if (style.textContent !== want) { style.textContent = want; }
            } catch (e) {}
          };
          window.__EPISTEMOS_EXP_THEME_APPLY__ = apply;
          apply(\(payloadJSON(for: theme)));
          try {
            new MutationObserver(function () {
              var p = window.__EPISTEMOS_EXP_THEME__;
              if (!p) { return; }
              var root = document.documentElement;
              if (!document.getElementById('epistemos-exp-theme')) { apply(p); return; }
              var keys = Object.keys(p.vars || {});
              var probe = keys.length ? keys[0] : null;
              if (probe && root.style.getPropertyValue(probe) !== p.vars[probe]) { apply(p); }
            }).observe(document.documentElement, {
              childList: true, subtree: false,
              attributes: true, attributeFilter: ['style', 'class']
            });
            document.addEventListener('DOMContentLoaded', function () {
              if (window.__EPISTEMOS_EXP_THEME__) { apply(window.__EPISTEMOS_EXP_THEME__); }
            }, { once: true });
          } catch (e) {}
        })();
        """
    }

    /// Live re-apply for `evaluateJavaScript` on theme change (no reload — a
    /// reload reboots the SPA and kills the live session, §7).
    static func applyScript(for theme: EpistemosTheme) -> String {
        """
        (function () {
          if (window.__EPISTEMOS_EXP_THEME_APPLY__) {
            window.__EPISTEMOS_EXP_THEME_APPLY__(\(payloadJSON(for: theme)));
          }
        })();
        """
    }

    // MARK: - Structural CSS (vars can't reach these)

    private static func overrideCSS() -> String {
        let fontFace = displayFontFaceCSS()
        let matrixFace = matrixFontFaceCSS()
        return """
        /* Donor brand gradient (.chroma-text, hardcoded indigo/violet) → plain text. */
        .chroma-text { background-image: none !important; -webkit-text-fill-color: currentColor !important; color: inherit !important; }
        .chroma-text-animate { animation: none !important; }
        \(fontFace)
        \(matrixFace)
        /* Epistemos display font on tagged landmarks ONLY (§7: never dense chat/editor body). */
        .epistemos-landmark, [data-epistemos-landmark] { font-family: "Epistemos Display", -apple-system, system-ui, sans-serif !important; letter-spacing: 0.01em; }
        /* Owner 2026-07-05: the landing greeting (h1 landmark) + the chat title wear the platinum
           landing face — Matrix Type. Scoped to those two landmarks ONLY; NEVER body/sidebar/
           composer/editor text (the webview typography boundary). */
        h1.epistemos-landmark, .epistemos-chat-title { font-family: "Epistemos Matrix", "Epistemos Display", -apple-system, system-ui, sans-serif !important; letter-spacing: 0.01em; }
        """
    }

    /// ChonkyPixels as a data: URL @font-face (JuneAgentSurfaceView precedent —
    /// the WebContent process can't see app-bundle fonts; embed or go without).
    private static var cachedFontFaceCSS: String?
    private static func displayFontFaceCSS() -> String {
        if let cachedFontFaceCSS { return cachedFontFaceCSS }
        var css = ""
        if let dataURL = displayFontDataURL() {
            css = """
            @font-face { font-family: "Epistemos Display"; src: url("\(dataURL)") format("truetype"); font-weight: 400 700; font-style: normal; font-display: swap; }
            """
        }
        cachedFontFaceCSS = css
        return css
    }

    private static func displayFontDataURL() -> String? {
        let direct = Bundle.main.url(forResource: "ChonkyPixels", withExtension: "ttf")
        let nested = Bundle.main.resourceURL?
            .appendingPathComponent("Fonts", isDirectory: true)
            .appendingPathComponent("ChonkyPixels.ttf")
        for url in [direct, nested].compactMap({ $0 }) {
            guard let data = try? Data(contentsOf: url) else { continue }
            return "data:font/ttf;base64,\(data.base64EncodedString())"
        }
        return nil
    }

    /// Matrix Type Display as a data: URL @font-face — the platinum-theme landing
    /// face (owner request), scoped in overrideCSS() to the landing greeting + chat
    /// title landmarks ONLY (never body/sidebar/composer — typography boundary).
    private static var cachedMatrixFaceCSS: String?
    private static func matrixFontFaceCSS() -> String {
        if let cachedMatrixFaceCSS { return cachedMatrixFaceCSS }
        var css = ""
        if let dataURL = matrixFontDataURL() {
            css = """
            @font-face { font-family: "Epistemos Matrix"; src: url("\(dataURL)") format("truetype"); font-weight: 400 700; font-style: normal; font-display: swap; }
            """
        }
        cachedMatrixFaceCSS = css
        return css
    }

    private static func matrixFontDataURL() -> String? {
        let direct = Bundle.main.url(forResource: "MatrixtypeDisplay-9MyE5", withExtension: "ttf")
        let nested = Bundle.main.resourceURL?
            .appendingPathComponent("Fonts", isDirectory: true)
            .appendingPathComponent("MatrixtypeDisplay-9MyE5.ttf")
        for url in [direct, nested].compactMap({ $0 }) {
            guard let data = try? Data(contentsOf: url) else { continue }
            return "data:font/ttf;base64,\(data.base64EncodedString())"
        }
        return nil
    }

    // MARK: - Color helpers

    private static func hsl(_ token: EpistemosTheme.ResolvedColorToken, dark: Bool) -> String {
        hsl(srgb(token.nsColor, dark: dark))
    }

    /// shadcn HSL triplet: `H S% L%` (alpha handled by callers via `/ a`).
    private static func hsl(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        let d = maxV - minV
        var h = 0.0, s = 0.0
        if d > 0.0001 {
            let denom = 1 - abs(2 * l - 1)
            s = denom > 0.0001 ? d / denom : 0
            if maxV == r {
                h = ((g - b) / d).truncatingRemainder(dividingBy: 6)
            } else if maxV == g {
                h = (b - r) / d + 2
            } else {
                h = (r - g) / d + 4
            }
            h *= 60
            if h < 0 { h += 360 }
        }
        return String(format: "%.0f %.1f%% %.1f%%", h, s * 100, l * 100)
    }

    /// System-dynamic tokens resolve per-appearance — snapshot under the
    /// theme's own appearance (agent-surface theme bridge precedent).
    private static func srgb(_ color: NSColor, dark: Bool) -> NSColor {
        var converted: NSColor?
        if let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) {
            appearance.performAsCurrentDrawingAppearance {
                converted = color.usingColorSpace(.sRGB)
            }
        } else {
            converted = color.usingColorSpace(.sRGB)
        }
        return converted ?? NSColor(
            red: dark ? 0.138 : 0.925,
            green: dark ? 0.135 : 0.918,
            blue: dark ? 0.128 : 0.902,
            alpha: 1
        )
    }

    /// Readable text over the accent (WCAG relative-luminance approximation).
    private static func contrastText(over color: NSColor) -> NSColor {
        let c = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return luminance > 0.55
            ? NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
            : .white
    }
}
#endif
