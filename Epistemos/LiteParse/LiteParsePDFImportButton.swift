import SwiftUI
import AppKit
import SwiftData
import UniformTypeIdentifiers

// R-LITEPARSE — the note-sidebar IMPORT button (owner 2026-06-19). Pick one or more PDFs
// → convert each via LiteParsePDFImportController → create markdown vault note(s); shows
// an HONEST per-file status. Visibility is gated by EPISTEMOS_LITEPARSE_PDF_V0
// (LiteParseImportGateStatus) — on by default, hidden only by the kill switch.
// Self-contained: it reads vault/graph/model from the environment the sidebar already
// provides.
struct LiteParsePDFImportButton: View {
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(GraphState.self) private var graphState
    @Environment(\.modelContext) private var modelContext

    @State private var statusMessage: String?
    @State private var showingStatus = false

    private var isVisible: Bool { LiteParseImportGateStatus.status().isActive }

    var body: some View {
        if isVisible {
            Button {
                runImport()
            } label: {
                Image(systemName: "doc.badge.arrow.up")
            }
            .help("Import PDF → Markdown note (EdgeParse/unpdf, local — PDF only)")
            .accessibilityLabel("Import PDF as note")
            .alert("PDF Import", isPresented: $showingStatus) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusMessage ?? "")
            }
        }
    }

    @MainActor
    private func runImport() {
        guard let vaultURL = vaultSync.vaultURL else {
            statusMessage = "Connect a vault first, then import."
            showingStatus = true
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true // bulk
        panel.canChooseDirectories = false
        panel.prompt = "Import"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let urls = panel.urls

        Task { @MainActor in
            var imported = 0
            var lines: [String] = []
            for url in urls {
                let gainedSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if gainedSecurityScope {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let outcome = await LiteParsePDFImportController.importPage(
                    pdfPath: url.path,
                    vaultURL: vaultURL,
                    modelContext: modelContext,
                    graphState: graphState
                )
                switch outcome {
                case let .imported(_, title):
                    imported += 1
                    lines.append("✓ \(title)")
                case let .rejected(result):
                    lines.append("✗ \(url.lastPathComponent): \(reason(for: result))")
                }
            }
            statusMessage = "Imported \(imported)/\(urls.count).\n" + lines.joined(separator: "\n")
            showingStatus = true
        }
    }

    private func reason(for result: LiteParseImportResult) -> String {
        switch result {
        case .markdown: "ok"
        case .notWired: "PDF parser bridge is unavailable in this build."
        case let .unsupported(message): message
        case let .failed(message): message
        }
    }
}
