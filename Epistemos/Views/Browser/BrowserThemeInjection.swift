import AppKit
import WebKit

/// Injects the Epistemos theme (palette + pixel-art heading font) into EVERY web
/// page loaded in the in-app browser, so browsing stays canon with the app theme
/// (owner request 2026-07-03). Palette colors are forced with `!important`; the
/// theme's pixel display face is embedded via `@font-face` and applied to
/// headings (body text stays in the site's readable face so long-form pages
/// remain usable). Re-applied on every navigation (WKUserScript) and on live
/// theme change (evaluateJavaScript from updateNSView).
enum BrowserThemeInjection {
    static let styleElementID = "__epistemos_theme_style__"

    /// Font file → base64 data URI, computed once. Reading + encoding a font on
    /// every navigation would be wasteful, so cache the whole @font-face block.
    /// Internal so the custom home page (BrowserHomePage) can reuse it.
    static let pixelFontFaceCSS: String = {
        guard let url = Bundle.main.url(forResource: "ChonkyPixels", withExtension: "ttf"),
              let data = try? Data(contentsOf: url) else { return "" }
        let base64 = data.base64EncodedString()
        return "@font-face{font-family:'EpistemosPixel';"
            + "src:url(data:font/ttf;base64,\(base64)) format('truetype');"
            + "font-display:swap;}"
    }()

    static func css(for theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let background = EpistemosWebThemeCSS.color(resolved.background)
        let foreground = EpistemosWebThemeCSS.color(resolved.foreground)
        let accent = EpistemosWebThemeCSS.color(resolved.accent)
        let heading = EpistemosWebThemeCSS.color(resolved.headingAccent)
        return """
        \(pixelFontFaceCSS)
        html,body{background-color:\(background) !important;color:\(foreground) !important;}
        p,span,li,td,th,div,section,article,main,figcaption,blockquote,label{color:\(foreground) !important;}
        a,a:link,a:visited{color:\(accent) !important;}
        /* Owner 2026-07-03: pixel font on headings, LINKS, BOLD, and page titles —
           NOT plain body/paragraph text (keeps long-form pages readable). */
        h1,h2,h3,h4,h5,h6,a,a:link,a:visited,strong,b,th,summary,title{
          font-family:'EpistemosPixel',ui-monospace,monospace !important;letter-spacing:0.4px;
        }
        h1,h2,h3,h4,h5,h6{color:\(heading) !important;}
        ::selection{background:\(accent);color:\(background);}
        """
    }

    /// JS that (re)creates the injected `<style>` with the current theme CSS.
    /// Idempotent — updates the existing element on theme change.
    static func applyThemeJS(for theme: EpistemosTheme) -> String {
        let escaped = css(for: theme)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        return """
        (function(){try{
          var id='\(styleElementID)';
          var el=document.getElementById(id);
          if(!el){el=document.createElement('style');el.id=id;
            (document.head||document.documentElement).appendChild(el);}
          el.textContent=`\(escaped)`;
        }catch(e){}})();
        """
    }

    /// User script injected at document end on EVERY navigation, all frames, so
    /// each page (and iframe) picks up the theme as it loads.
    static func userScript(for theme: EpistemosTheme) -> WKUserScript {
        WKUserScript(
            source: applyThemeJS(for: theme),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}
