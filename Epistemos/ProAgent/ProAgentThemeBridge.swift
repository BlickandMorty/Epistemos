#if !EPISTEMOS_APP_STORE
import AppKit
import SwiftUI

/// Maps the resolved Epistemos theme onto OpenChamber's CSS token system so the
/// Pro agent surface follows the LIVE app theme — light, dark, and custom
/// palettes (owner 2026-07-04: "pin prefers-color-scheme AND the accent/palette
/// to the live Epistemos theme", mirroring the June track's JuneThemeBridge).
///
/// Mechanism: OpenChamber applies its own theme via a `<style
/// id="opencode-theme-variables">` tag plus `.dark`/`.light` root classes
/// (cssGenerator.ts). This bridge never edits donor code — it sets the SAME
/// custom properties as INLINE `!important` styles on `documentElement`, which
/// deterministically win the cascade over any stylesheet (including the
/// donor's own `!important` rows), and pins the root scheme classes. Values
/// are concrete sRGB colors resolved natively. Status/syntax/markdown tokens
/// stay donor-semantic (theme-system skill: status colors are feedback-only).
@MainActor
enum ProAgentThemeBridge {
    /// JSON payload for `window.__EPISTEMOS_OC_THEME_APPLY__`:
    /// `{"dark": Bool, "vars": {"--token": "rgb(...)"}}`.
    static func payloadJSON(for theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let dark = resolved.isDark

        let background = css(resolved.background, dark: dark)
        let foreground = css(resolved.foreground, dark: dark)
        let card = css(resolved.card, dark: dark)
        let muted = css(resolved.muted, dark: dark)
        let mutedForeground = css(resolved.mutedForeground, dark: dark)
        let border = css(resolved.border, dark: dark)
        let accent = srgb(resolved.accent.nsColor, dark: dark)
        let uiAccent = srgb(resolved.uiAccent.nsColor, dark: dark)
        let fgColor = srgb(resolved.foreground.nsColor, dark: dark)
        let accentCSS = css(accent)
        let onAccent = contrastText(over: accent)

        var vars: [String: String] = [
            // Core surfaces + text.
            "--background": background,
            "--foreground": foreground,
            "--card": card,
            "--card-foreground": foreground,
            "--popover": card,
            "--popover-foreground": foreground,
            "--muted": muted,
            "--muted-foreground": mutedForeground,
            "--secondary": muted,
            "--secondary-foreground": foreground,
            // OpenChamber's --accent is its quiet hover FILL, not the brand.
            "--accent": muted,
            "--accent-foreground": foreground,
            "--border": border,
            "--input": border,
            "--ring": css(uiAccent.withAlphaComponent(0.5)),
            // Primary = the Epistemos accent, with natively-derived states
            // (donor derives hover/active when absent, but its theme JSONs set
            // them explicitly, so every member must be overridden together).
            "--primary": accentCSS,
            "--primary-base": accentCSS,
            "--primary-hover": css(accent.blended(withFraction: 0.10, of: fgColor) ?? accent),
            "--primary-active": css(accent.blended(withFraction: 0.16, of: fgColor) ?? accent),
            "--primary-emphasis": css(accent.blended(withFraction: 0.12, of: dark ? .white : .black) ?? accent),
            "--primary-muted": css(accent.withAlphaComponent(0.32)),
            "--primary-foreground": onAccent,
            // Interactive states.
            "--interactive-hover": muted,
            "--interactive-active": css(srgb(resolved.muted.nsColor, dark: dark).blended(withFraction: 0.12, of: fgColor) ?? srgb(resolved.muted.nsColor, dark: dark)),
            "--interactive-selection": muted,
            "--interactive-selection-foreground": foreground,
            "--interactive-border": border,
            "--interactive-border-hover": css(srgb(resolved.border.nsColor, dark: dark).blended(withFraction: 0.2, of: fgColor) ?? srgb(resolved.border.nsColor, dark: dark)),
            "--interactive-border-focus": css(uiAccent),
            "--interactive-focus": css(uiAccent),
            "--interactive-focus-ring": css(uiAccent.withAlphaComponent(0.4)),
            "--interactive-cursor": css(uiAccent),
            // Sidebar family (the slide-in overlay reads these).
            "--sidebar": background,
            "--sidebar-foreground": foreground,
            "--sidebar-accent": muted,
            "--sidebar-accent-foreground": foreground,
            "--sidebar-border": border,
            "--sidebar-primary": accentCSS,
            "--sidebar-primary-foreground": onAccent,
            "--sidebar-ring": css(uiAccent.withAlphaComponent(0.4)),
            "--sidebar-base": background,
            "--sidebar-base-rgb": rgbTriplet(resolved.background, dark: dark),
            "--sidebar-border-rgb": rgbTriplet(resolved.border, dark: dark),
            "--sidebar-accent-base": muted,
            "--sidebar-accent-base-rgb": rgbTriplet(resolved.muted, dark: dark),
            // Donor's non-vibrancy branch derives these from surface.muted.
            "--sidebar-overlay-strong": css(srgb(resolved.muted.nsColor, dark: dark).withAlphaComponent(0.95)),
            "--sidebar-overlay-soft": css(srgb(resolved.muted.nsColor, dark: dark).withAlphaComponent(0.6)),
            "--sidebar-vibrancy-overlay": css(srgb(resolved.muted.nsColor, dark: dark).withAlphaComponent(0.5)),
            // Chat tokens — Epistemos has first-class bubble tokens; map them.
            "--chat-background": css(resolved.chatSurface, dark: dark),
            "--chat-divider": border,
            "--chat-timestamp": mutedForeground,
            "--chat-typing": mutedForeground,
            "--chat-assistant-message": css(resolved.assistantBubbleForeground, dark: dark),
            "--chat-user-message": foreground,
            "--chat-user-message-bg": css(resolved.userBubbleBg, dark: dark),
            // Spinner follows the accent (donor emits literals, not references).
            "--loading-spinner": accentCSS,
            "--loading-spinner-track": muted,
        ]
        if let assistantBg = resolved.assistantBubbleBackground {
            vars["--chat-assistant-message-bg"] = css(assistantBg, dark: dark)
        }

        let object: [String: Any] = ["dark": dark, "vars": vars]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"dark\":\(dark ? "true" : "false"),\"vars\":{}}"
        }
        return json
    }

    /// documentStart user script: defines the applier, applies the boot
    /// payload immediately, and re-asserts the pinned scheme classes if the
    /// donor's own theme apply() flips them later (inline vars need no
    /// re-assert — the donor never clears documentElement.style).
    static func userScript(for theme: EpistemosTheme) -> String {
        """
        (function () {
          var apply = function (payload) {
            try {
              var root = document.documentElement;
              if (!root) { return; }
              window.__EPISTEMOS_OC_THEME__ = payload;
              if (payload.dark) {
                root.classList.add('dark'); root.classList.remove('light');
              } else {
                root.classList.add('light'); root.classList.remove('dark');
              }
              root.setAttribute('data-theme', payload.dark ? 'dark' : 'light');
              var vars = payload.vars || {};
              for (var key in vars) { root.style.setProperty(key, vars[key], 'important'); }
            } catch (e) {}
          };
          window.__EPISTEMOS_OC_THEME_APPLY__ = apply;
          apply(\(payloadJSON(for: theme)));
          // Pin the scheme classes against the donor's later theme apply().
          try {
            var observer = new MutationObserver(function () {
              var payload = window.__EPISTEMOS_OC_THEME__;
              if (!payload) { return; }
              var root = document.documentElement;
              var wantDark = !!payload.dark;
              if (root.classList.contains('dark') !== wantDark) { apply(payload); }
            });
            observer.observe(document.documentElement, { attributes: true, attributeFilter: ['class', 'data-theme'] });
          } catch (e) {}
        })();
        """
    }

    /// Live re-apply for `WebPage.callJavaScript` (function-body semantics —
    /// the `return` is required or the call bridges to nil).
    static func applyScript(for theme: EpistemosTheme) -> String {
        """
        if (window.__EPISTEMOS_OC_THEME_APPLY__) {
          window.__EPISTEMOS_OC_THEME_APPLY__(\(payloadJSON(for: theme)));
        }
        return true;
        """
    }

    // MARK: - Color helpers (JuneThemeBridge precedent)

    private static func css(_ token: EpistemosTheme.ResolvedColorToken, dark: Bool) -> String {
        css(srgb(token.nsColor, dark: dark))
    }

    private static func css(_ color: NSColor) -> String {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let red = Int((converted.redComponent * 255).rounded())
        let green = Int((converted.greenComponent * 255).rounded())
        let blue = Int((converted.blueComponent * 255).rounded())
        let alpha = converted.alphaComponent
        if alpha >= 0.999 { return "rgb(\(red), \(green), \(blue))" }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }

    /// "R G B" triplet for the donor's `rgb(<triplet> / alpha)` composition.
    private static func rgbTriplet(_ token: EpistemosTheme.ResolvedColorToken, dark: Bool) -> String {
        let color = srgb(token.nsColor, dark: dark)
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return "\(red) \(green) \(blue)"
    }

    /// System-dynamic tokens (windowBackground / controlBackground) resolve
    /// per-appearance, so snapshot under the theme's own appearance.
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

    /// Readable text over the accent by WCAG relative-luminance approximation.
    private static func contrastText(over color: NSColor) -> String {
        let converted = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.2126 * converted.redComponent
            + 0.7152 * converted.greenComponent
            + 0.0722 * converted.blueComponent
        return luminance > 0.55 ? "rgb(20, 20, 22)" : "rgb(255, 255, 255)"
    }
}
#endif
