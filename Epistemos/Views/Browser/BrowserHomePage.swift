import AppKit

/// Custom minimal, pixel-art, fully theme-aware home/new-tab page for the in-app
/// browser (owner request 2026-07-03). Rendered via `loadHTMLString` when the
/// browser opens with no destination. Provides a search box + an easy
/// Google/DuckDuckGo engine picker; submitting navigates the web view to the
/// chosen engine's results.
enum BrowserHomePage {
    /// Sentinel address that means "show the custom home page" instead of a URL.
    static let marker = "epistemos:home"

    static func isHome(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == marker
    }

    static func html(theme: EpistemosTheme) -> String {
        let resolved = theme.resolved
        let bg = EpistemosWebThemeCSS.color(resolved.background)
        let fg = EpistemosWebThemeCSS.color(resolved.foreground)
        let accent = EpistemosWebThemeCSS.color(resolved.accent)
        let muted = EpistemosWebThemeCSS.color(resolved.mutedForeground)
        let card = EpistemosWebThemeCSS.color(resolved.card)
        return """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          \(BrowserThemeInjection.pixelFontFaceCSS)
          * { box-sizing: border-box; }
          body {
            margin: 0; height: 100vh; background: \(bg); color: \(fg);
            font-family: 'EpistemosPixel', ui-monospace, monospace;
            display: flex; flex-direction: column; align-items: center; justify-content: center;
          }
          .title { font-size: 46px; letter-spacing: 3px; margin: 0 0 6px; }
          .sub { color: \(muted); font-size: 12px; letter-spacing: 1px; margin-bottom: 30px; text-transform: uppercase; }
          form { display: flex; width: min(600px, 82vw); border: 2px solid \(accent);
                 border-radius: 16px; overflow: hidden; background: \(card); }
          input { flex: 1; background: transparent; border: 0; color: \(fg);
                  font-family: inherit; font-size: 16px; padding: 15px 18px; outline: none; }
          input::placeholder { color: \(muted); }
          button { background: \(accent); color: \(bg); border: 0; padding: 0 20px;
                   font-family: inherit; font-size: 18px; cursor: pointer; }
          .engines { margin-top: 20px; display: flex; gap: 10px; }
          .engine { padding: 7px 16px; border: 1px solid \(muted); border-radius: 11px;
                    color: \(muted); font-size: 12px; cursor: pointer; user-select: none; letter-spacing: 1px; }
          .engine.active { border-color: \(accent); color: \(accent); }
        </style></head>
        <body>
          <div class="title">EPISTEMOS</div>
          <div class="sub">minimal research browser</div>
          <form onsubmit="return go()">
            <input id="q" placeholder="Search the web…" autofocus autocomplete="off">
            <button type="submit">&rarr;</button>
          </form>
          <div class="engines">
            <div class="engine" id="e-google" onclick="setEngine('google')">GOOGLE</div>
            <div class="engine" id="e-ddg" onclick="setEngine('ddg')">DUCKDUCKGO</div>
          </div>
          <script>
            var engine = 'google';
            try { engine = localStorage.getItem('epi-engine') || 'google'; } catch (e) {}
            function setEngine(e) {
              engine = e;
              try { localStorage.setItem('epi-engine', e); } catch (err) {}
              document.getElementById('e-google').className = 'engine' + (e === 'google' ? ' active' : '');
              document.getElementById('e-ddg').className = 'engine' + (e === 'ddg' ? ' active' : '');
            }
            setEngine(engine);
            function go() {
              var v = document.getElementById('q').value.trim();
              if (!v) return false;
              var q = encodeURIComponent(v);
              window.location = engine === 'ddg'
                ? 'https://duckduckgo.com/?q=' + q
                : 'https://www.google.com/search?q=' + q;
              return false;
            }
          </script>
        </body></html>
        """
    }
}
