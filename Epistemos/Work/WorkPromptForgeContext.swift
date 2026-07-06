import Foundation

enum WorkPromptForgeContext {
    nonisolated static func snippets(from snapshot: WorkAppContextSnapshot) -> [PromptForgeContextSnippet] {
        snapshot.rows(pathLimit: 120, textLimit: 220).map { row in
            PromptForgeContextSnippet(
                id: "work-\(row.id)",
                title: row.label,
                source: "Work context",
                excerpt: row.value,
                priority: priority(for: row.id))
        }
    }

    nonisolated static func priority(for rowID: String) -> Int {
        switch rowID {
        case "note", "note-path", "graph", "selection":
            80
        case "vault", "workspace":
            60
        case "engine", "model", "agent", "runtime-skills":
            40
        default:
            20
        }
    }
}
