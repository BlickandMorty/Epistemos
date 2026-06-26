import SwiftUI

// Lightweight markdown renderer for the Work transcript's assistant answers (clone-map #5/#6 — donor parity:
// OpenGUI/OpenCode render markdown; the owner's target "no raw …debris in assistant prose" means raw `**bold**`/fenced
// source should NOT show literally). Splits the text by fenced code blocks (triple-backtick): code → a flat mono
// bordered box (TUI), prose → AttributedString inline markdown (bold/italic/inline-code/links) over a JetBrainsMono
// base. Streaming-safe: an unclosed trailing fence renders as an in-progress code block; incomplete inline markdown
// shows literally until its closer streams in. Pure rendering; no raw protocol/JSON ever reaches it (the transcript
// reducer already cleaned it).
struct WorkMarkdownText: View {
    let text: String
    var theme: EpistemosTheme = .nativeDefault

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(Self.parse(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .prose(let value):
                    Text(Self.inlineMarkdown(value))
                        .font(WorkPixelFont.body(13))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(let value):
                    Text(value)
                        .font(WorkPixelFont.body(12))
                        .foregroundStyle(theme.mutedForeground)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(theme.border, lineWidth: 0.8))
                }
            }
        }
    }

    enum Segment: Equatable { case prose(String); case code(String) }

    /// Split into prose / fenced-code segments. A trailing open fence becomes an (in-progress) code segment.
    static func parse(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var inCode = false
        var buffer: [String] = []
        func flush(asCode: Bool) {
            let joined = buffer.joined(separator: "\n")
            if asCode {
                if !joined.isEmpty { segments.append(.code(joined)) }
            } else if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.prose(joined))
            }
            buffer = []
        }
        for line in text.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                flush(asCode: inCode)
                inCode.toggle()
            } else {
                buffer.append(line)
            }
        }
        flush(asCode: inCode)
        return segments
    }

    /// Inline-only markdown (bold/italic/inline-code/links), preserving whitespace/newlines; literal fallback on parse error.
    static func inlineMarkdown(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(string)
    }
}
