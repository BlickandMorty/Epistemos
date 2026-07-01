import AppKit
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum TextExportDiagnostics {
    static let maxFailureMessageCharacters = 240
    static let maxFileNameCharacters = 180
    private static let maxDomainCharacters = 80

    static func externalFailureMessage(_ error: Error, fallback: String = "Write failed") -> String {
        let nsError = error as NSError
        return boundedFailureMessage(
            "\(fallback) (domain=\(safeDomain(nsError.domain)) code=\(nsError.code))",
            fallback: fallback
        )
    }

    static func boundedFailureMessage(_ message: String, fallback: String = "Write failed") -> String {
        let bounded = String(message.prefix(maxFailureMessageCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard trimmed.count > maxFailureMessageCharacters else { return trimmed }

        let suffix = "..."
        let end = trimmed.index(
            trimmed.startIndex,
            offsetBy: max(0, maxFailureMessageCharacters - suffix.count)
        )
        return String(trimmed[..<end]) + suffix
    }

    static func displayFileName(_ fileName: String) -> String {
        let bounded = String(fileName.prefix(maxFileNameCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "file" }
        guard trimmed.count > maxFileNameCharacters else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxFileNameCharacters - 3)
        return String(trimmed[..<end]) + "..."
    }

    private static func safeDomain(_ domain: String) -> String {
        let bounded = String(domain.prefix(maxDomainCharacters + 32))
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Error" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Error"
        }
        guard trimmed.count <= maxDomainCharacters else {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxDomainCharacters)
            return String(trimmed[..<end])
        }
        return trimmed
    }
}

@MainActor
enum TextExportSupport {
    static func save(_ content: String, suggestedFilename: String, contentType: UTType) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try write(content, to: url)
        } catch {
            presentWriteFailure(error, destination: url)
        }
    }

    static func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func presentWriteFailure(_ error: Error, destination: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't Save File"
        alert.informativeText = """
        Epistemos couldn't save "\(TextExportDiagnostics.displayFileName(destination.lastPathComponent))".

        \(TextExportDiagnostics.externalFailureMessage(error))
        """
        alert.addButton(withTitle: "OK")

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
}

struct AssistantResponseChrome<Content: View>: View {
    @Environment(UIState.self) private var ui

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        if theme.assistantBubbleBackgroundHex != nil {
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    theme.assistantBubbleBackground,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(theme.border.opacity(0.85), lineWidth: 0.8)
                )
        } else {
            content
        }
    }
}
