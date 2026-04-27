import AppIntents
import Foundation
import SwiftUI

// MARK: - NotePreviewSnippet (W15.2)
//
// Wave 15 §"#2 SnippetIntent for inline note preview" — top-3 ROI
// item from the App Intents fused research synthesis. Once shipped,
// macOS 26 Spotlight + Siri results render a 3-line preview card
// inline (title + first ~200 chars of body) without launching the
// app, with an "Open" button that hands off to OpenNoteIntent.
//
// Verified canonical API (`AppIntents.swiftinterface` line 10573):
//
//   public protocol SnippetIntent : AppIntent
//     where Self.PerformResult : ShowsSnippetView
//
// Constraints (Wave 15 §"performance + concurrency contract"):
//   - perform() may re-run on dark-mode / state changes; MUST NOT
//     mutate any user-visible state.
//   - View must be `Sendable` + isolation-safe.
//   - Keep the snippet view pure presentation; any data needed
//     beyond the NoteEntity fields must be loaded inside perform().

struct NotePreviewSnippet: SnippetIntent {
    static let title: LocalizedStringResource = "Preview Note"
    static let description = IntentDescription(
        "Shows a 3-line inline preview of a note in Spotlight or Siri results — title + first ~200 chars of body, with an Open button."
    )

    @Parameter(title: "Note")
    var note: NoteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Preview \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        // The NoteEntity already carries title + content — no extra
        // disk read needed for the preview surface.
        let snippetBody: String = {
            guard let body = note.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !body.isEmpty else {
                return "(empty note)"
            }
            return String(body.prefix(220))
        }()
        return .result(view: NotePreviewSnippetView(
            title: note.title,
            snippet: snippetBody,
            updatedAt: note.updatedAt
        ))
    }
}

// MARK: - SwiftUI surface

@MainActor
private struct NotePreviewSnippetView: View {
    let title: String
    let snippet: String
    let updatedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            }
            Text(snippet)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(3)
            Text(updatedAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 360, alignment: .leading)
    }
}
