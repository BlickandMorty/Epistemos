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
    private static let maxStatusLines = 50
    private static let maxStatusLineCharacters = 320
    private static let maxStatusMessageCharacters = 8_000
    private static let maxFileNameDisplayCharacters = 180

    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(GraphState.self) private var graphState
    @Environment(\.modelContext) private var modelContext

    @State private var statusMessage: String?
    @State private var showingStatus = false

    private var isVisible: Bool { LiteParseImportGateStatus.status().isActive }

    var body: some View {
        if isVisible {
            ToolbarCapsuleButton(
                title: nil,
                systemImage: "doc.badge.arrow.up",
                role: .toolbarUtility,
                chromePolicy: .bareUntilPressed,
                helpText: "Import PDF → Markdown note (EdgeParse/unpdf, local — PDF only)",
                accessibilityLabel: "Import PDF as note"
            ) {
                runImport()
            }
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
                case let .imported(_, title, sourcePDFRelativePath):
                    imported += 1
                    appendStatusLine(
                        "✓ \(Self.displayName(title, fallback: "Imported PDF")) - Source PDF: \(Self.displayName(sourcePDFRelativePath, fallback: "source PDF"))",
                        to: &lines
                    )
                case let .rejected(result):
                    appendStatusLine("✗ \(Self.displayName(url.lastPathComponent)): \(reason(for: result))", to: &lines)
                }
            }
            if urls.count > Self.maxStatusLines {
                appendStatusLine(
                    "... \(urls.count - Self.maxStatusLines) more files omitted from this status.",
                    to: &lines,
                    allowOverflowMarker: true
                )
            }
            statusMessage = Self.boundedStatusMessage("Imported \(imported)/\(urls.count).\n" + lines.joined(separator: "\n"))
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

    private func appendStatusLine(
        _ line: String,
        to lines: inout [String],
        allowOverflowMarker: Bool = false
    ) {
        guard lines.count < Self.maxStatusLines || allowOverflowMarker else { return }
        lines.append(Self.boundedStatusLine(line))
    }

    private static func displayName(_ raw: String, fallback: String = "PDF") -> String {
        let bounded = String(raw.prefix(maxFileNameDisplayCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxFileNameDisplayCharacters else { return value }
        return String(value.prefix(maxFileNameDisplayCharacters - 3)) + "..."
    }

    private static func boundedStatusLine(_ line: String) -> String {
        bounded(line, limit: maxStatusLineCharacters, fallback: "PDF import status unavailable.")
    }

    private static func boundedStatusMessage(_ message: String) -> String {
        bounded(message, limit: maxStatusMessageCharacters, fallback: "PDF import status unavailable.")
    }

    private static func bounded(_ raw: String, limit: Int, fallback: String) -> String {
        let bounded = String(raw.prefix(limit + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > limit else { return value }
        guard limit > 3 else { return String(value.prefix(limit)) }
        return String(value.prefix(limit - 3)) + "..."
    }
}
