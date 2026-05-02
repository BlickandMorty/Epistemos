import Foundation
import AppIntents
import CoreSpotlight

// MARK: - Brain Dump Entity
// Maps to QuarantineEntry. Used by custom intents for brain dump search and access.

struct BrainDumpEntity: AppEntity, Sendable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Brain Dump")
    }
    static var defaultQuery: BrainDumpEntityQuery {
        BrainDumpEntityQuery()
    }

    var id: String
    @Property(title: "Kind") var kind: String
    @Property(title: "Body") var body: String
    @Property(title: "Captured At") var capturedAt: Date
    @Property(title: "Anchor Context Kind") var anchorContextKind: String?
    @Property(title: "Anchor Context ID") var anchorContextId: String?

    init(
        id: String,
        kind: String,
        body: String,
        capturedAt: Date = .now,
        anchorContextKind: String? = nil,
        anchorContextId: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.body = body
        self.capturedAt = capturedAt
        self.anchorContextKind = anchorContextKind
        self.anchorContextId = anchorContextId
    }

    var displayRepresentation: DisplayRepresentation {
        let preview = body.isEmpty ? "Brain dump" : String(body.prefix(60))
        return DisplayRepresentation(title: "\(preview)")
    }
}

// MARK: - BrainDumpEntity + IndexedEntity

extension BrainDumpEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        let preview = body.isEmpty ? "Brain dump" : String(body.prefix(160))
        set.title = body.isEmpty ? "Brain Dump" : "Brain Dump: \(String(body.prefix(60)))"
        set.contentDescription = preview
        set.contentCreationDate = capturedAt
        set.contentModificationDate = capturedAt
        set.displayName = "Brain Dump"
        set.kind = "Epistemos Brain Dump"
        return set
    }
}

// MARK: - Brain Dump Entity Query

struct BrainDumpEntityQuery: EntityStringQuery {
    private static let matchingResultLimit = 20
    private static let suggestionLimit = 10

    @MainActor
    func entities(for identifiers: [String]) async throws -> [BrainDumpEntity] {
        let entries = QuarantineArchive.shared.snapshot()
        var results: [BrainDumpEntity] = []
        for id in identifiers {
            if let entry = entries.first(where: { $0.id == id }) {
                results.append(entry.toBrainDumpEntity())
            }
        }
        return results
    }

    @MainActor
    func entities(matching string: String) async throws -> IntentItemCollection<BrainDumpEntity> {
        let entries = QuarantineArchive.shared.snapshot()
        let trimmedQuery = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return IntentItemCollection(items: []) }

        let matched = entries.filter {
            Self.entryMatches($0, query: trimmedQuery)
        }
        .sorted { $0.capturedAt > $1.capturedAt }

        return IntentItemCollection(items: Array(matched.prefix(Self.matchingResultLimit).map { $0.toBrainDumpEntity() }))
    }

    @MainActor
    func suggestedEntities() async throws -> IntentItemCollection<BrainDumpEntity> {
        let entries = QuarantineArchive.shared.snapshot()
        let recent = entries
            .sorted { $0.capturedAt > $1.capturedAt }
            .prefix(Self.suggestionLimit)
        return IntentItemCollection(items: Array(recent.map { $0.toBrainDumpEntity() }))
    }

    private static func entryMatches(_ entry: QuarantineEntry, query: String) -> Bool {
        entry.body.localizedStandardContains(query)
            || entry.kind.rawValue.localizedStandardContains(query)
            || (entry.anchor?.contextKind.localizedStandardContains(query) ?? false)
            || (entry.anchor?.contextId.localizedStandardContains(query) ?? false)
    }
}

// MARK: - QuarantineEntry to BrainDumpEntity

extension QuarantineEntry {
    func toBrainDumpEntity() -> BrainDumpEntity {
        BrainDumpEntity(
            id: id,
            kind: kind.rawValue,
            body: body,
            capturedAt: Date(timeIntervalSince1970: capturedAt),
            anchorContextKind: anchor?.contextKind,
            anchorContextId: anchor?.contextId
        )
    }
}
