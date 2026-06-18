import Foundation

/// R-OKF — projects a vault note / Knowledge Core entry into the **Open
/// Knowledge Format** (Google Cloud, Apache-2.0): a directory of markdown files
/// with YAML frontmatter, one concept per file, the only REQUIRED field being
/// `type`. The Epistemos vault is already markdown-with-frontmatter, so this is
/// an interop/export projection, not a migration.
///
/// Pure + `nonisolated` so the format contract is unit-testable without the
/// SwiftData `@Model` (which is MainActor-bound). Callers map their note model
/// onto `OKFExporter.Note` (plain primitives; dates pre-formatted as ISO-8601
/// strings so the projection is deterministic — no clock reads inside).
///
/// Founding-Thesis fit: human-readable + git-diffable + portable, the same
/// determinism/provenance ethos as ClaimLedger and the Cognitive DAG.
nonisolated enum OKFExporter {
    /// One concept, ready to project. `type` is the single OKF-required field;
    /// everything else is optional and omitted from the frontmatter when empty.
    struct Note: Equatable, Sendable {
        var type: String
        var title: String?
        var tags: [String]
        var body: String
        var created: String?
        var updated: String?

        init(
            type: String = "note",
            title: String? = nil,
            tags: [String] = [],
            body: String = "",
            created: String? = nil,
            updated: String? = nil
        ) {
            self.type = type
            self.title = title
            self.tags = tags
            self.body = body
            self.created = created
            self.updated = updated
        }
    }

    /// The OKF markdown for a note: YAML frontmatter (type first, then any set
    /// fields) + a blank line + the body. Always ends with a trailing newline.
    static func markdown(for note: Note) -> String {
        var lines: [String] = ["---"]
        // `type` is required by OKF — never omitted; defaults to "note".
        let type = note.type.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("type: \(yamlScalar(type.isEmpty ? "note" : type))")
        if let title = note.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            lines.append("title: \(yamlScalar(title))")
        }
        let tags = note.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !tags.isEmpty {
            lines.append("tags: [\(tags.map(yamlScalar).joined(separator: ", "))]")
        }
        if let created = note.created, !created.isEmpty {
            lines.append("created: \(yamlScalar(created))")
        }
        if let updated = note.updated, !updated.isEmpty {
            lines.append("updated: \(yamlScalar(updated))")
        }
        lines.append("---")
        lines.append("")
        lines.append(note.body)
        var out = lines.joined(separator: "\n")
        if !out.hasSuffix("\n") { out += "\n" }
        return out
    }

    /// A filesystem-safe `.md` filename derived from the title (or `fallback`).
    static func fileName(for note: Note, fallback: String = "untitled") -> String {
        let base = note.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return slug(base?.isEmpty == false ? base! : fallback) + ".md"
    }

    // MARK: - Mapping from a vault page

    /// Map a vault page's primitives (read off the MainActor `@Model` by the
    /// caller) into an OKF `Note`. Pure + deterministic — the caller passes the
    /// already-loaded body and the page dates; nothing here reads the clock or
    /// touches the model. `isJournal` selects the OKF `type` (`journal` vs
    /// `note`) — the one required field.
    static func note(
        title: String,
        body: String,
        tags: [String],
        isJournal: Bool,
        createdAt: Date?,
        updatedAt: Date?
    ) -> Note {
        Note(
            type: isJournal ? "journal" : "note",
            title: title,
            tags: tags,
            body: body,
            created: createdAt.map(iso8601),
            updated: updatedAt.map(iso8601)
        )
    }

    /// Deterministic UTC ISO-8601 (`yyyy-MM-ddTHH:mm:ssZ`) for frontmatter dates.
    static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    // MARK: - YAML scalar emission

    /// Emit a YAML scalar: plain when it's safe, double-quoted (with escapes)
    /// otherwise. Conservative — anything with YAML-significant punctuation
    /// (`:`, `,`, brackets, quotes, leading indicators) gets quoted so the
    /// frontmatter always round-trips.
    private static func yamlScalar(_ raw: String) -> String {
        let plainSafe = raw.range(of: "^[A-Za-z0-9 _./@+-]+$", options: .regularExpression) != nil
        let leadingIndicator = raw.first.map { "!&*[]{}#|>%@`\"',?:- ".contains($0) } ?? true
        if plainSafe && !leadingIndicator {
            return raw
        }
        let escaped = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// Lowercase kebab slug: letters/digits kept, every other run collapsed to a
    /// single dash, trimmed. Empty → `untitled`.
    private static func slug(_ raw: String) -> String {
        var out = ""
        var lastDash = false
        for ch in raw.lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastDash = false
            } else if !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "untitled" : trimmed
    }
}
