#if EPISTEMOS_EXPERIMENTAL
import WebKit

/// Phase-2 Task 0 — the keystone native→SPA state bridge (EXPERIMENTAL_R §1.11).
///
/// The donor SPA's send transports read model/mode/project LIVE from the shared
/// Jotai `appStore` at send time, so native SwiftUI chrome must write the
/// renderer's own atoms — native-only state silently desyncs the running chat.
/// The renderer half (`src/renderer/lib/epistemos-state-bridge.ts`, a fork
/// overlay imported from main.tsx) exposes an allow-listed
/// `window.__epistemosState` API; this class drives it via `evaluateJavaScript`.
///
/// Escaping discipline: every argument is serialized through JSONSerialization
/// (`.fragmentsAllowed`) and then U+2028/U+2029-escaped, so injected content can
/// never break out of the script context (mirrors the agent bridge rules).
@MainActor
final class ExperimentalStateBridge {
    static let shared = ExperimentalStateBridge()

    /// Set by the surface Coordinator when the WKWebView is created; weak so a
    /// dismantled surface never pins the web process.
    weak var webView: WKWebView?

    private init() {}

    // MARK: - Public API

    /// Set a named Jotai atom in the renderer's shared appStore. Family atoms
    /// (per-sub-chat model/mode) require `subChatId`. Retries briefly if the SPA
    /// bundle hasn't registered the bridge yet (early-boot race).
    func setAtom(_ name: String, value: Any?, subChatId: String? = nil) {
        guard let nameJS = Self.jsonFragment(name),
              let valueJS = Self.jsonFragment(value ?? NSNull()),
              let subChatJS = Self.jsonFragment(subChatId ?? NSNull()) else { return }
        callBridge("setAtom(\(nameJS), \(valueJS), \(subChatJS))")
    }

    /// Run an allow-listed renderer action (Zustand: updateSubChatMode, …).
    func action(_ name: String, args: [Any] = []) {
        guard let nameJS = Self.jsonFragment(name) else { return }
        let argFragments = args.compactMap { Self.jsonFragment($0) }
        guard argFragments.count == args.count else { return }
        let joined = ([nameJS] + argFragments).joined(separator: ", ")
        callBridge("action(\(joined))")
    }

    /// Fire a namespaced `epistemos:*` CustomEvent into the SPA (§7 no-reload
    /// intent lane — never reload the URL; a reload reboots the SPA).
    func dispatch(event: String, detail: Any? = nil) {
        guard let eventJS = Self.jsonFragment(event),
              let detailJS = Self.jsonFragment(detail ?? NSNull()) else { return }
        callBridge("dispatch(\(eventJS), \(detailJS))")
    }

    /// Read a named atom back (for probes / native chrome mirroring renderer
    /// truth). Completion receives nil when the atom or bridge is absent.
    func getAtom(_ name: String, subChatId: String? = nil,
                 completion: @escaping @MainActor (Any?) -> Void) {
        guard let webView,
              let nameJS = Self.jsonFragment(name),
              let subChatJS = Self.jsonFragment(subChatId ?? NSNull()) else {
            completion(nil)
            return
        }
        let script = "window.__epistemosState ? window.__epistemosState.getAtom(\(nameJS), \(subChatJS)) : null"
        webView.evaluateJavaScript(script) { result, _ in
            MainActor.assumeIsolated { completion(result) }
        }
    }

    // MARK: - Internals

    /// Evaluate `window.__epistemosState.<call>`, retrying while the SPA bundle
    /// is still booting (the bridge registers at module load, which trails
    /// document start). 8 × 250 ms covers any realistic SPA boot without
    /// spinning forever on a dead page.
    private func callBridge(_ call: String, attempt: Int = 0) {
        guard let webView else { return }
        let script = "window.__epistemosState ? (window.__epistemosState.\(call), true) : false"
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            MainActor.assumeIsolated {
                let delivered = (result as? Bool) ?? false
                guard !delivered, attempt < 8 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self?.callBridge(call, attempt: attempt + 1)
                }
            }
        }
    }

    /// JSON-encode any Sendable-ish value as a JS expression fragment. Returns
    /// nil for unencodable values (never emits unescaped content). U+2028/U+2029
    /// are legal in JSON strings but were statement terminators in older JS —
    /// escape them so the fragment is safe to inline in a script.
    static func jsonFragment(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject([value]) else { return nil }
        guard let data = try? JSONSerialization.data(
            withJSONObject: value, options: [.fragmentsAllowed]
        ), let text = String(data: data, encoding: .utf8) else { return nil }
        return text
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}
#endif
