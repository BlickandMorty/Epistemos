import AppIntents
import CoreSpotlight
import Foundation

// MARK: - NoteEntity + IndexedEntity (W14.1)
//
// Wave 14 / App Intents deep-research §"#1 Add IndexedEntity to
// Note, Chat, Thought" — biggest unexplored Apple-native moat per
// the agent's ROI ranking. Once `NoteEntity` conforms to
// `IndexedEntity`, macOS automatically:
//   1. Generates a "Find Note" action surfacing in Spotlight on
//      macOS 26 — the user types Cmd+Space, "Find note about LLM
//      context windows", and Spotlight returns matching notes
//   2. Indexes Note content into Core Spotlight via the
//      `attributeSet` returned below — full-text search hits Note
//      title + body even before the user types "find note about"
//   3. Eligible for Apple Intelligence semantic search routing on
//      macOS 26+
//
// Verified canonical API (`AppIntents.swiftinterface` line 11479):
//
//   public protocol IndexedEntity : AppEntity {
//     var attributeSet: CSSearchableItemAttributeSet { get }
//     @available(macOS 15.4, ...) var hideInSpotlight: Bool { get }
//   }
//
// We supply a content-rich `attributeSet` mapping NoteEntity fields
// to the canonical Spotlight attribute keys; `hideInSpotlight`
// defaults to `false` (notes ARE visible to Spotlight).
//
// Donation: the call sites that mutate notes (NotesSidebar create,
// VaultIndexActor, etc.) should call
// `IndexedEntity.donate()` after each mutation so Core Spotlight
// stays current. Wave 14 follow-up commit wires that up.

extension NoteEntity: IndexedEntity {

    public var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = title
        set.contentDescription = content ?? ""
        // Surfaces a 1-line snippet next to the title in Spotlight
        // results. Truncate to 160 chars so the snippet fits without
        // wrapping in the system result row.
        if let body = content {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            set.contentDescription = String(trimmed.prefix(160))
        }
        set.contentCreationDate = createdAt
        set.contentModificationDate = updatedAt
        // displayName is what Spotlight shows in the "kind" pill on
        // the result row. Keeping it short + unique helps the user
        // distinguish Epistemos notes from Mail / Notes / Files
        // results in mixed-source searches.
        set.displayName = title
        set.kind = "Epistemos Note"
        return set
    }
}
