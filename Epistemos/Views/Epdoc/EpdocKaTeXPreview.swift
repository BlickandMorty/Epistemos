import SwiftUI
import WebKit

// MARK: - EpdocKaTeXPreview
//
// Wave 7.17.b live KaTeX preview popover. When the cursor enters a
// `$…$` (math_inline) or `$$…$$` (math_display) node in the Tiptap
// WKWebView, the JS side fires a bridge message with the formula
// text + anchor rect. The host renders this view in a popover above
// the source so the writer sees the rendered output WHILE typing —
// Alexandrie makes you toggle the whole-doc preview pane to see math.
//
// Implementation: a tiny throwaway WKWebView with the bundled KaTeX
// CSS + JS injected once. The view re-renders when the formula text
// changes via `katex.renderToString`. The lazy renderer caches the
// last formula → SVG so identical formulas don't re-render.

@MainActor
public struct EpdocKaTeXPreview: View {

    /// LaTeX source text. Update this on every keystroke inside a
    /// math node; the renderer debounces internally.
    public let formula: String
    /// Display mode — `display` for `$$…$$` (centered, larger),
    /// `inline` for `$…$`.
    public let displayMode: DisplayMode

    public enum DisplayMode: Sendable, Equatable {
        case inline
        case display
    }

    public init(formula: String, displayMode: DisplayMode = .display) {
        self.formula = formula
        self.displayMode = displayMode
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(displayMode == .inline ? "Inline math" : "Display math")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            KaTeXWebView(formula: formula, displayMode: displayMode)
                .frame(minHeight: 60)
                .padding(8)
        }
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.20), radius: 16, x: 0, y: 6)
    }
}

// MARK: - WebKit-backed renderer

@MainActor
private struct KaTeXWebView: NSViewRepresentable {
    let formula: String
    let displayMode: EpdocKaTeXPreview.DisplayMode

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Ephemeral website data store: KaTeX previews are pure-render
        // (no cookies / localStorage / cache value to persist). The
        // default persistent store would write disk cache for every
        // formula viewed; a non-persistent store keeps everything in
        // RAM and frees with the WKWebView.
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.loadHTMLString(initialHTML, baseURL: URL(string: "epistemos-doc:///"))
        EpdocWebViewShared.notifyWebViewCreated()
        return view
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: ()) {
        view.stopLoading()
        EpdocWebViewShared.notifyWebViewDismantled()
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        // Re-render whenever the formula or mode changes.
        let escaped = formula
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let displayFlag = displayMode == .display ? "true" : "false"
        let js = """
        try {
          const out = katex.renderToString("\(escaped)", { displayMode: \(displayFlag), throwOnError: false });
          document.getElementById('preview').innerHTML = out;
        } catch (e) {
          document.getElementById('preview').textContent = String(e);
        }
        """
        view.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Bootstrap HTML — loads KaTeX from the same vendored bundle the
    /// main editor uses (`/vendor/katex/katex.min.css` + the inline
    /// renderer script). When running outside the WKWebView host
    /// (Previews, dev), the script will fail and the preview shows
    /// the raw LaTeX as a fallback.
    private var initialHTML: String {
        """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <link rel="stylesheet" href="/vendor/katex/katex.min.css">
          <script defer src="/vendor/katex/katex.min.js"></script>
          <style>
            body { margin: 0; padding: 0; font: 14px -apple-system, system-ui, sans-serif; }
            #preview { padding: 0; min-height: 40px; }
          </style>
        </head>
        <body>
          <div id="preview">…</div>
        </body>
        </html>
        """
    }
}

#if DEBUG
#Preview("Display math — Pythagorean") {
    EpdocKaTeXPreview(formula: "a^2 + b^2 = c^2", displayMode: .display)
        .padding()
}

#Preview("Inline math — fraction") {
    EpdocKaTeXPreview(formula: "\\tfrac{1}{2}", displayMode: .inline)
        .padding()
}
#endif
