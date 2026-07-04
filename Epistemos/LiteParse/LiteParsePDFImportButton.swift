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
    @State private var importTask: Task<Void, Never>?
    @State private var importProgress: ImportProgress?

    private struct ImportProgress: Equatable {
        var done: Int
        var total: Int
    }

    private var isVisible: Bool { LiteParseImportGateStatus.status().isActive }

    var body: some View {
        if isVisible {
            content
                .alert("PDF Import", isPresented: $showingStatus) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(statusMessage ?? "")
                }
        }
    }

    // #3 (audit 2026-07-03): a bulk import previously showed no progress and no cancel — one
    // slow/bad PDF stalled the whole batch with zero feedback. While importing, the button
    // becomes a live "done/total" spinner + Stop that cancels the remaining files.
    @ViewBuilder
    private var content: some View {
        if let progress = importProgress {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("\(progress.done)/\(progress.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "xmark",
                    role: .toolbarUtility,
                    chromePolicy: .alwaysSurface,
                    helpText: "Cancel import (\(progress.done) of \(progress.total) done)",
                    accessibilityLabel: "Cancel PDF import"
                ) {
                    importTask?.cancel()
                }
            }
        } else {
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
        }
    }

    @MainActor
    private func runImport() {
        guard importTask == nil else { return } // an import is already running
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

        importProgress = ImportProgress(done: 0, total: urls.count)
        importTask = Task { @MainActor in
            defer {
                importProgress = nil
                importTask = nil
            }
            var imported = 0
            var lines: [String] = []
            var cancelled = false
            for (index, url) in urls.enumerated() {
                if Task.isCancelled {
                    cancelled = true
                    break
                }
                importProgress = ImportProgress(done: index, total: urls.count)
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
            let header = cancelled
                ? "Cancelled — imported \(imported)/\(urls.count)."
                : "Imported \(imported)/\(urls.count)."
            statusMessage = Self.boundedStatusMessage(header + "\n" + lines.joined(separator: "\n"))
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
        let trimmed = normalizedDisplayText(bounded).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > maxFileNameDisplayCharacters else { return value }
        return String(value.prefix(maxFileNameDisplayCharacters - 3)) + "..."
    }

    private static func boundedStatusLine(_ line: String) -> String {
        bounded(line, limit: maxStatusLineCharacters, fallback: "PDF import status unavailable.")
    }

    private static func boundedStatusMessage(_ message: String) -> String {
        boundedStatusMessageText(message, limit: maxStatusMessageCharacters, fallback: "PDF import status unavailable.")
    }

    private static func bounded(_ raw: String, limit: Int, fallback: String) -> String {
        let bounded = String(raw.prefix(limit + 32))
        let trimmed = normalizedDisplayText(bounded).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > limit else { return value }
        guard limit > 3 else { return String(value.prefix(limit)) }
        return String(value.prefix(limit - 3)) + "..."
    }

    private static func boundedStatusMessageText(_ raw: String, limit: Int, fallback: String) -> String {
        let bounded = String(raw.prefix(limit + 32))
        let trimmed = normalizedStatusMessageText(bounded).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.isEmpty ? fallback : trimmed
        guard value.count > limit else { return value }
        guard limit > 3 else { return String(value.prefix(limit)) }
        return String(value.prefix(limit - 3)) + "..."
    }

    private static func normalizedDisplayText(_ value: String) -> String {
        normalizedDisplayText(value, preservesLineBreaks: false)
    }

    private static func normalizedStatusMessageText(_ value: String) -> String {
        normalizedDisplayText(value, preservesLineBreaks: true)
    }

    private static func normalizedDisplayText(_ value: String, preservesLineBreaks: Bool) -> String {
        var normalized = ""
        normalized.reserveCapacity(value.count)
        var previousWasInlineSeparator = false
        var previousWasLineBreak = false
        for scalar in value.unicodeScalars {
            if preservesLineBreaks, CharacterSet.newlines.contains(scalar) {
                if !previousWasLineBreak {
                    normalized.append("\n")
                }
                previousWasLineBreak = true
                previousWasInlineSeparator = false
            } else if CharacterSet.whitespacesAndNewlines.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
            {
                if !previousWasInlineSeparator {
                    normalized.append(" ")
                    previousWasInlineSeparator = true
                }
                previousWasLineBreak = false
            } else {
                normalized.unicodeScalars.append(scalar)
                previousWasInlineSeparator = false
                previousWasLineBreak = false
            }
        }
        return normalized
    }
}
