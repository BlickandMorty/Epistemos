import AppKit
import Foundation

struct MarkEditCoreEditorThemePalette: Equatable, Encodable {
    let colorScheme: String
    let background: String
    let foreground: String
    let muted: String
    let lineNumber: String
    let gutter: String
    let border: String
    let accent: String
    let heading: String
    let codeBackground: String
    let codeForeground: String
    let selection: String
    let activeLine: String
    let searchMatch: String

    static func current(theme: EpistemosTheme) -> Self {
        let surfaceTheme = theme
        let resolved = surfaceTheme.resolved
        let background = MarkdownPreviewSurfaceStyle
            .solidFlatBackgroundNSColor(for: surfaceTheme)
            .withAlphaComponent(1.0)
        let gutter = background
        let border = resolved.glassBorder.nsColor.withAlphaComponent(surfaceTheme.isDark ? 0.48 : 0.34)
        let accent = resolved.accent.nsColor
        let foreground = resolved.foreground.nsColor
        let muted = resolved.mutedForeground.nsColor

        return MarkEditCoreEditorThemePalette(
            colorScheme: surfaceTheme.isDark ? "dark" : "light",
            background: EpistemosWebThemeCSS.color(background),
            foreground: EpistemosWebThemeCSS.color(foreground),
            muted: EpistemosWebThemeCSS.color(muted),
            lineNumber: EpistemosWebThemeCSS.color(muted, opacity: surfaceTheme.isDark ? 0.74 : 0.68),
            gutter: EpistemosWebThemeCSS.color(gutter),
            border: EpistemosWebThemeCSS.color(border),
            accent: EpistemosWebThemeCSS.color(accent),
            heading: EpistemosWebThemeCSS.color(resolved.markdownHeadingAccent.nsColor),
            codeBackground: EpistemosWebThemeCSS.color(resolved.card.nsColor.withAlphaComponent(1.0)),
            codeForeground: EpistemosWebThemeCSS.color(resolved.codeType.nsColor),
            selection: EpistemosWebThemeCSS.color(accent, opacity: surfaceTheme.isDark ? 0.30 : 0.22),
            activeLine: EpistemosWebThemeCSS.color(accent, opacity: surfaceTheme.isDark ? 0.12 : 0.08),
            searchMatch: EpistemosWebThemeCSS.color(resolved.headingAccent.nsColor, opacity: surfaceTheme.isDark ? 0.38 : 0.28)
        )
    }
}

enum MarkEditCoreEditorSourceTypography {
    static let heading1FontFace = "Epistemos Matrix Type Bold"

    /// The initial document owns the font request so Markdown Source does not
    /// wait until the CoreEditor bridge has finished before its H1 metrics can
    /// settle. The document loader rewrites this bounded bundle URL to the
    /// existing custom scheme before WebKit receives it.
    static let bootstrapHTML = """
    <link rel="preload" href="/chunk-loader/fonts/MatrixTypeDisplay-Bold.otf" as="font" type="font/otf" crossorigin>
    <style id="epistemos-source-heading-font">
      @font-face {
        font-family: "Epistemos Matrix Type Bold";
        src: url("/chunk-loader/fonts/MatrixTypeDisplay-Bold.otf") format("opentype");
        font-display: optional;
      }
    </style>
    """
}

enum MarkEditCoreEditorThemeOverlay {
    static func script(themeName: String?, palette: MarkEditCoreEditorThemePalette) -> String? {
        guard let paletteJSON = jsonString(palette) else { return nil }
        let themeNameJSON = themeName.flatMap { jsonString($0) } ?? "null"
        let sourceHeading1FontFaceJSON = jsonString(
            MarkEditCoreEditorSourceTypography.heading1FontFace
        ) ?? "\"Epistemos Matrix Type Bold\""

        return """
        (() => {
          const themeName = \(themeNameJSON);
          const palette = \(paletteJSON);
          const sourceHeading1FontFace = \(sourceHeading1FontFaceJSON);
          if (themeName && window.webModules?.config?.setTheme) {
            try {
              window.webModules.config.setTheme({ name: themeName });
            } catch (error) {}
          }

          let style = document.getElementById("epistemos-core-editor-theme");
          if (!style) {
            style = document.createElement("style");
            style.id = "epistemos-core-editor-theme";
            document.head.appendChild(style);
          }
          style.textContent = `
            :root {
              color-scheme: ${palette.colorScheme};
              background: ${palette.background} !important;
              --epistemos-editor-bg: ${palette.background};
              --epistemos-editor-fg: ${palette.foreground};
              --epistemos-editor-muted: ${palette.muted};
              --epistemos-editor-line: ${palette.lineNumber};
              --epistemos-editor-gutter: ${palette.gutter};
              --epistemos-editor-border: ${palette.border};
              --epistemos-editor-accent: ${palette.accent};
              --epistemos-editor-heading: ${palette.heading};
              --epistemos-editor-code-bg: ${palette.codeBackground};
              --epistemos-editor-code-fg: ${palette.codeForeground};
              --epistemos-editor-selection: ${palette.selection};
              --epistemos-editor-active-line: ${palette.activeLine};
              --epistemos-editor-search: ${palette.searchMatch};
            }
            html,
            body,
            #editor,
            .cm-editor,
            .cm-scroller {
              background: var(--epistemos-editor-bg) !important;
              color: var(--epistemos-editor-fg) !important;
            }
            .cm-content {
              caret-color: var(--epistemos-editor-accent) !important;
            }
            .cm-gutters {
              background: var(--epistemos-editor-gutter) !important;
              border-right-color: var(--epistemos-editor-border) !important;
              color: var(--epistemos-editor-line) !important;
            }
            .cm-scroller::-webkit-scrollbar,
            .cm-scroller::-webkit-scrollbar-track,
            .cm-scroller::-webkit-scrollbar-corner {
              background: var(--epistemos-editor-bg) !important;
            }
            .cm-scroller::-webkit-scrollbar-thumb {
              background-color: var(--epistemos-editor-border) !important;
              border: 2px solid var(--epistemos-editor-bg) !important;
              border-radius: 999px;
            }
            .cm-gutterElement,
            .cm-foldGutter,
            .cm-foldPlaceholder {
              color: var(--epistemos-editor-line) !important;
            }
            .cm-activeLine,
            .cm-activeLineGutter,
            .cm-md-activeIndicator {
              background: var(--epistemos-editor-active-line) !important;
            }
            .cm-selectionBackground,
            .cm-content ::selection,
            .cm-focused .cm-selectionBackground {
              background: var(--epistemos-editor-selection) !important;
            }
            .cm-searchMatch {
              background: var(--epistemos-editor-search) !important;
            }
            .cm-md-heading1 {
              color: var(--epistemos-editor-heading) !important;
              font-family: ${sourceHeading1FontFace}, ui-monospace, monospace !important;
              font-weight: normal !important;
            }
            .cm-md-heading2,
            .cm-md-heading3,
            .cm-md-heading4,
            .cm-md-heading5,
            .cm-md-heading6,
            .cm-md-header:not(.cm-md-quote) {
              color: var(--epistemos-editor-heading) !important;
            }
            .cm-md-link,
            .cm-md-linkMark,
            .cm-md-url,
            .cm-link {
              color: var(--epistemos-editor-accent) !important;
            }
            .cm-md-quote,
            .cm-md-quoteMark,
            .cm-comment {
              color: var(--epistemos-editor-muted) !important;
            }
            .cm-md-inlineCode,
            .cm-md-codeBlock,
            .cm-md-codeBlock *,
            .cm-md-monospace,
            .cm-md-monospace * {
              background-color: var(--epistemos-editor-code-bg) !important;
              color: var(--epistemos-editor-code-fg) !important;
            }
          `;
          document.documentElement.dataset.epistemosCoreEditorTheme = palette.colorScheme;
          window.__epistemosCoreEditorThemePalette = palette;
          return true;
        })();
        """
    }

    private static func jsonString<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
