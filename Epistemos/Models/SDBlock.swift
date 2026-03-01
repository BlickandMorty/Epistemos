import Foundation
import SwiftData

// MARK: - SDBlock
// A block (bullet point / paragraph) within an SDPage.
// Every indented line in a note becomes a first-class entity with a stable UUID,
// enabling block references ((id)), graph integration, and block-level AI extraction.
//
// Design: Denormalized `pageId` and `parentBlockId` strings (no @Relationship).
// Same pattern as SDPageVersion — avoids #Predicate traversal issues and cascade coupling.
// Content stored inline in SQLite (blocks are 1-3 lines, not full documents).

@Model
final class SDBlock {
    #Index<SDBlock>([\.id], [\.pageId], [\.parentBlockId], [\.order])

    // MARK: - Identity
    var id: String = UUID().uuidString

    // MARK: - Ownership
    /// The SDPage this block belongs to. Denormalized string for fast #Predicate queries.
    var pageId: String = ""

    // MARK: - Hierarchy
    /// Parent block ID for nested outlining. nil = top-level block on the page.
    var parentBlockId: String?
    /// Sort position among siblings. Multiplied by 1000 for fractional insertions
    /// (e.g., inserting between order=2000 and order=3000 → new block at order=2500).
    var order: Int = 0
    /// Indentation depth (0 = top-level, 1 = one indent, etc.).
    /// Denormalized from parent chain for O(1) rendering.
    var depth: Int = 0

    // MARK: - Content
    /// The markdown text for this block (one bullet/paragraph, typically 1-3 lines).
    var content: String = ""

    // MARK: - State
    /// Whether children are visually collapsed in the editor.
    var isCollapsed: Bool = false

    // MARK: - Timestamps
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Init

    init() {}

    init(pageId: String, content: String, depth: Int, order: Int, parentBlockId: String? = nil) {
        self.id = UUID().uuidString
        self.pageId = pageId
        self.content = content
        self.depth = depth
        self.order = order
        self.parentBlockId = parentBlockId
        self.createdAt = .now
        self.updatedAt = .now
    }
}
