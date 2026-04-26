import SwiftUI

// MARK: - EditorBundleHealthRow
//
// Wave 7.17 settings diagnostic — read-only status rows for the
// W7.17 Tiptap WKWebView bundle + the W8.4 Halo Shadow backend.
// Surfaces in the Settings sheet so the user can verify their .app
// is fully wired without launching a doc.
//
// Per the W7.17 setup-research agent's 2026-04-26 verdict: NO
// rebuild button. NO auto-install. The .app ships the bundle
// pre-compiled inside Resources/Editor/; the user never runs npm.
// This view ONLY reports health — if something is missing the user
// re-installs the .app or rebuilds from source (`xcodebuild` runs
// the `build-tiptap-bundle.sh` chain automatically).

@MainActor
public struct EditorBundleHealthRow: View {

    @State private var bundleAvailable: Bool = false
    @State private var haloOpen: Bool = false
    @State private var haloPath: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(
                label: "Editor bundle",
                symbol: "doc.text",
                ok: bundleAvailable,
                detail: bundleAvailable ? "Resources/Editor/editor.html" : "Missing — rebuild the app"
            )
            row(
                label: "Halo backend",
                symbol: "circle.hexagongrid",
                ok: haloOpen,
                detail: haloOpen
                    ? haloPath ?? "Open"
                    : "Not opened yet — call shadow_open_at(path) at bootstrap"
            )
        }
        .onAppear { refresh() }
    }

    /// Re-probe both health indicators. Called on view appearance +
    /// optionally exposed to a "Refresh" button if the host wants one.
    public func refresh() {
        bundleAvailable = Self.bundleIsAvailable()
        let halo = Self.haloStatus()
        haloOpen = halo.isOpen
        haloPath = halo.path
    }

    @ViewBuilder
    private func row(label: String, symbol: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18, height: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Health probes

    /// True iff `Resources/Editor/editor.html` exists in the app
    /// bundle. Mirrors the lookup `EpdocEditorURLSchemeHandler` does
    /// at every WKWebView load, so a `false` here predicts a runtime
    /// "asset not found" the moment a doc opens.
    static func bundleIsAvailable() -> Bool {
        Bundle.main.url(
            forResource: "editor",
            withExtension: "html",
            subdirectory: "Editor"
        ) != nil
    }

    /// Read the Halo backend state. Returns (isOpen, path?) — we
    /// avoid binding to the Rust crate's static singleton directly
    /// to keep this view dependency-light. The host can update the
    /// `EpdocEditorChromeController` or a UserDefaults key when the
    /// Swift bootstrap calls `shadow_open_at(path)`; this read
    /// surfaces that flag.
    static func haloStatus() -> (isOpen: Bool, path: String?) {
        let path = UserDefaults.standard.string(forKey: "epistemos.halo.openPath")
        let opened = UserDefaults.standard.bool(forKey: "epistemos.halo.isOpen")
        return (opened, path)
    }

    /// Convenience the bootstrap calls after a successful
    /// `shadow_open_at(path)` so this diagnostic surfaces the path.
    public static func recordHaloOpened(at path: String) {
        UserDefaults.standard.set(true, forKey: "epistemos.halo.isOpen")
        UserDefaults.standard.set(path, forKey: "epistemos.halo.openPath")
    }

    public static func recordHaloClosed() {
        UserDefaults.standard.set(false, forKey: "epistemos.halo.isOpen")
        UserDefaults.standard.removeObject(forKey: "epistemos.halo.openPath")
    }
}

#if DEBUG
#Preview("EditorBundleHealthRow — both ready") {
    EditorBundleHealthRow.recordHaloOpened(at: "/Users/jojo/Library/Application Support/Epistemos/shadow")
    return EditorBundleHealthRow()
        .padding()
        .frame(width: 480)
}

#Preview("EditorBundleHealthRow — both missing") {
    EditorBundleHealthRow.recordHaloClosed()
    return EditorBundleHealthRow()
        .padding()
        .frame(width: 480)
}
#endif
