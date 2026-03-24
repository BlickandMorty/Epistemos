import Foundation
import SwiftData

// MARK: - Workspace Model
// Persists workspace snapshots — either the auto-saved "last session" or named workflows.
// snapshotData holds a JSON-encoded WorkspaceSnapshot capturing all open windows and state.

@Model
final class SDWorkspace {
    var id: String = UUID().uuidString
    var name: String = ""
    var isAutoSave: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var snapshotData: Data = Data()
    var summary: String = ""
    var userNote: String = ""
    var lastSummaryAt: Date?

    init(name: String, isAutoSave: Bool = false) {
        self.id = UUID().uuidString
        self.name = name
        self.isAutoSave = isAutoSave
        self.createdAt = Date()
        self.updatedAt = Date()
        self.snapshotData = Data()
        self.summary = ""
        self.userNote = ""
        self.lastSummaryAt = nil
    }
}

// MARK: - Workspace Snapshot Types
// Codable structs that describe the full workspace state at a point in time.

struct WorkspaceSnapshot: Codable {
    var activePanel: String
    var activeChatId: String?
    var showChatSidebar: Bool
    var showLanding: Bool

    var openNoteTabs: [NoteTabSnapshot]
    var activeNoteTabPageId: String?

    var openMiniChatIds: [String]

    var notesBrowserVisible: Bool
    var settingsVisible: Bool

    var graphOverlay: GraphOverlaySnapshot

    var expandedFolderIds: [String]
    var isJournalExpanded: Bool
    var isIdeasExpanded: Bool

    var activityDigest: ActivityDigest?

    /// Total notes in the vault at snapshot time (for accurate Time Machine diffs).
    var totalNoteCount: Int?
    /// IDs of all pages in the vault at snapshot time (for accurate added/removed detection).
    var allPageIds: [String]?
}

struct ActivityDigest: Codable {
    var editedNotes: [EditedNoteSummary]
    var chatMessageCount: Int
    var sessionDurationMinutes: Int

    struct EditedNoteSummary: Codable {
        var pageId: String
        var title: String
        var changedParagraphCount: Int
        var totalParagraphs: Int
    }
}

struct NoteTabSnapshot: Codable {
    var rootPageId: String
    var currentPageId: String
    var breadcrumbs: [BreadcrumbSnapshot]
    var forwardStack: [BreadcrumbSnapshot]
    var cursorPosition: Int?
    var scrollFraction: Double?
    /// Word count at snapshot time (for accurate Time Machine display).
    var wordCount: Int?
}

struct BreadcrumbSnapshot: Codable {
    var pageId: String
    var title: String
}

struct GraphOverlaySnapshot: Codable {
    enum Visibility: String, Codable {
        case hidden, full, minimized
    }
    var visibility: Visibility
    var selectedNodeId: String?
}
