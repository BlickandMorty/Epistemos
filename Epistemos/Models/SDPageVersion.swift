import Foundation
import SwiftData

// MARK: - SDPageVersion
// Lightweight snapshot of a note at a point in time.
// Captured on meaningful saves (significant body changes) — not every keystroke.
// Body stored inline in SQLite (external storage silently returns partial data).
// Versions are capped per page (max 50) to keep storage bounded.
//
// Design note: `pageId` is a denormalized string rather than a @Relationship to SDPage.
// This is intentional — SwiftData's #Predicate can't traverse optional relationships reliably,
// and a relationship would couple version lifecycle to page lifecycle (cascade deletes
// would wipe history). The indexed pageId string allows efficient queries without coupling.

@Model
final class SDPageVersion {
    #Index<SDPageVersion>([\.pageId], [\.createdAt])

    var id: String = UUID().uuidString
    var pageId: String = ""
    var title: String = ""
    var body: String = ""
    var wordCount: Int = 0
    var createdAt: Date = Date.now

    init(pageId: String, title: String, body: String, wordCount: Int) {
        self.id = UUID().uuidString
        self.pageId = pageId
        self.title = title
        self.body = body
        self.wordCount = wordCount
        self.createdAt = .now
    }
}
