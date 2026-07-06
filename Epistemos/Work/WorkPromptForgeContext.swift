import Foundation

enum WorkPromptForgeContext {
    nonisolated static func snippets(
        from snapshot: WorkAppContextSnapshot?
    ) -> [PromptForgeContextSnippet] {
        guard let snapshot, !snapshot.isEmpty else { return [] }

        return snapshot.rows().compactMap { row in
            guard !row.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return PromptForgeContextSnippet(
                id: "work-\(row.id)",
                title: row.label,
                source: "Work app context",
                excerpt: row.value,
                priority: priority(for: row.id)
            )
        }
    }

    private nonisolated static func priority(for rowID: String) -> Int {
        switch rowID {
        case "selection":
            return 80
        case "workspace", "vault", "note", "note-path":
            return 60
        case "engine", "model", "agent", "runtime-skills":
            return 40
        case "native-tools", "skills", "mode", "session", "queue", "graph":
            return 20
        default:
            return 10
        }
    }
}
