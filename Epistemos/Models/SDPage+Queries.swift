import Foundation
import SwiftData

// MARK: - SDPage Query Descriptors
// Pre-built FetchDescriptors for common access patterns.
// These are the "Relational Brain" queries — O(log n) via #Predicate,
// replacing v2's O(n) array scanning over notePages: [NotePage].
//
// Usage in views:
//   @Query(SDPage.activePagesDescriptor) private var pages: [SDPage]
// Or dynamically:
//   let results = try modelContext.fetch(SDPage.searchDescriptor(query: "Quantum"))

extension SDPage {

    // MARK: - Active Pages

    /// Non-archived pages sorted by most recently updated.
    /// No fetchLimit — body is @Attribute(.externalStorage) so metadata is cheap.
    /// A 5000-page vault loads ~5MB of metadata (titles, tags, dates, IDs).
    static var activePagesDescriptor: FetchDescriptor<SDPage> {
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.folder]
        return descriptor
    }

    // MARK: - Pinned Pages

    /// Pinned, non-archived pages sorted by sort order.
    static var pinnedPagesDescriptor: FetchDescriptor<SDPage> {
        FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.isPinned && !$0.isArchived },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
    }

    // MARK: - Journal Entries

    /// Journal entries sorted by journal date (newest first).
    static var journalDescriptor: FetchDescriptor<SDPage> {
        FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.isJournal && !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    // MARK: - Search

    /// Title-only search — no body access, uses SQLite index.
    /// Body search is handled separately on VaultIndexActor (background).
    static func searchDescriptor(query: String) -> FetchDescriptor<SDPage> {
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate {
                $0.templateId == nil
                    && $0.title.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return descriptor
    }

    // MARK: - By Research Stage

    /// Find pages by research pipeline stage — impossible in v2, trivial in v3.
    /// Stage 0 = unprocessed, 1-5 = pipeline stages (discovery through synthesis).
    static func byStageDescriptor(stage: Int) -> FetchDescriptor<SDPage> {
        FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.researchStage == stage && !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }

    // MARK: - Recent Pages (Limited)

    /// Most recently updated pages, with a limit for dashboard/widget display.
    static func recentDescriptor(limit: Int) -> FetchDescriptor<SDPage> {
        var descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    // MARK: - Templates

    /// All template pages (hidden from normal views, available for "new from template").
    static var templatesDescriptor: FetchDescriptor<SDPage> {
        FetchDescriptor<SDPage>(
            predicate: #Predicate { $0.templateId != nil },
            sortBy: [SortDescriptor(\.title)]
        )
    }
}

// MARK: - SDChat Query Descriptors

extension SDChat {

    /// All chats sorted by most recently updated.
    static var recentChatsDescriptor: FetchDescriptor<SDChat> {
        FetchDescriptor<SDChat>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }

    /// Chats filtered by type.
    static func byTypeDescriptor(type: String) -> FetchDescriptor<SDChat> {
        FetchDescriptor<SDChat>(
            predicate: #Predicate { $0.chatType == type },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }
}

// MARK: - SDFolder Query Descriptors

extension SDFolder {

    /// Top-level folders (no parent) sorted by sort order.
    static var topLevelFoldersDescriptor: FetchDescriptor<SDFolder> {
        FetchDescriptor<SDFolder>(
            predicate: #Predicate { $0.parent == nil },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
    }
}

