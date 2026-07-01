import AppKit
import SwiftUI

struct WebClipperSheet: View {
    let theme: EpistemosTheme
    let onCreate: (WebClipCaptureDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var sourceURL = ""
    @State private var captureText = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var fieldBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.42 : 0.64)
    }

    private var editorBackground: Color {
        theme.resolved.card.color.opacity(theme.isDark ? 0.30 : 0.52)
    }

    private var mutedText: Color {
        theme.resolved.mutedForeground.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            fields
            footer
        }
        .padding(20)
        .frame(width: 620, height: 520)
        .background(MarkdownPreviewSurfaceStyle.flatBackground(for: theme))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .foregroundStyle(theme.resolved.accent.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clip Web Page")
                    .font(.headline)
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(sourceURLPreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(mutedText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                pasteClipboard()
            } label: {
                Label("Paste Clipboard", systemImage: "doc.on.clipboard")
            }
            .disabled(isCreating)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.resolved.foreground.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .disabled(isCreating)

            TextField("Source URL", text: $sourceURL)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.resolved.foreground.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .disabled(isCreating)

            if hasInvalidSourceURL {
                Text("Use an http or https source URL.")
                    .font(.caption)
                    .foregroundStyle(theme.error)
                    .lineLimit(1)
            }

            TextEditor(text: $captureText)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.resolved.foreground.color)
                .scrollContentBackground(.hidden)
                .background(
                    editorBackground,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(isCreating)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(theme.error)
                    .lineLimit(2)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(isCreating)
            Spacer()
            Button {
                createClip()
            } label: {
                Label(isCreating ? "Creating" : "Create Clip", systemImage: "plus")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isCreating || hasInvalidSourceURL || captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var sourceURLPreview: String {
        let trimmed = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No source URL" }
        return WebClipperMarkdownBuilder.normalizedSourceURL(trimmed) ?? "Invalid source URL"
    }

    private var hasInvalidSourceURL: Bool {
        let trimmed = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && WebClipperMarkdownBuilder.normalizedSourceURL(trimmed) == nil
    }

    private func createClip() {
        guard !isCreating else { return }
        guard !hasInvalidSourceURL else {
            errorMessage = "Use an http or https source URL."
            return
        }
        isCreating = true
        errorMessage = nil
        let normalizedSourceURL = WebClipperMarkdownBuilder.normalizedSourceURL(sourceURL) ?? ""
        let draft = WebClipCaptureDraft(
            title: title,
            sourceURL: normalizedSourceURL,
            html: captureText,
            plainText: captureText,
            capturedAt: Date()
        )

        Task { @MainActor in
            do {
                try await onCreate(draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }

    private func pasteClipboard() {
        let pasteboard = NSPasteboard.general
        let html = pasteboard.string(forType: NSPasteboard.PasteboardType.html)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = pasteboard.string(forType: NSPasteboard.PasteboardType.URL)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? text.flatMap(Self.firstURL(in:))
        let normalizedURL = url.flatMap(WebClipperMarkdownBuilder.normalizedSourceURL)

        if let html, !html.isEmpty {
            captureText = html
        } else if let text, !text.isEmpty {
            captureText = text
        }

        if sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let normalizedURL {
            sourceURL = normalizedURL
        }

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let textTitle = text?.components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            title = String(textTitle.prefix(WebClipperMarkdownBuilder.maxTitleCharacters))
        }
    }

    private static func firstURL(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = detector?.firstMatch(in: text, range: range),
              let url = match.url?.absoluteString
        else {
            return nil
        }
        return url
    }
}
