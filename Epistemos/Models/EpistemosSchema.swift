import Foundation
import SwiftData

// MARK: - Schema V1
// The baseline schema — all models as they existed at initial release.

enum EpistemosSchemaV1: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SDPage.self, SDFolder.self, SDChat.self, SDMessage.self,
         SDPageVersion.self, SDGraphNode.self, SDGraphEdge.self]
    }
}

// MARK: - Schema V2
// Adds `isManual` flag to SDGraphNode and SDGraphEdge for user-created graph entities.

enum EpistemosSchemaV2: VersionedSchema {
    nonisolated(unsafe) static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SDPage.self, SDFolder.self, SDChat.self, SDMessage.self,
         SDPageVersion.self, SDGraphNode.self, SDGraphEdge.self]
    }
}

// MARK: - Migration Plan

enum EpistemosMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [EpistemosSchemaV1.self, EpistemosSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V1 → V2: lightweight migration.
    /// New properties `isManual` on SDGraphNode and SDGraphEdge have default values (false),
    /// so SwiftData handles the column addition automatically.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: EpistemosSchemaV1.self,
        toVersion: EpistemosSchemaV2.self
    )
}
