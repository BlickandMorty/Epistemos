import Foundation
import SwiftData

// MARK: - Epistemos Schema
// Single schema definition for all SwiftData models.
// SwiftData handles lightweight migrations (adding defaulted properties) automatically.
// No explicit VersionedSchema or MigrationPlan needed — they cause "Duplicate version
// checksums detected" crashes when schema versions reference identical compiled model types.

enum EpistemosSchema {
    static var models: [any PersistentModel.Type] {
        [SDPage.self, SDFolder.self, SDChat.self, SDMessage.self,
         SDPageVersion.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self,
         SDNoteInsight.self, SDWorkspace.self, SDModelProfile.self,
         CompanionModel.self]
    }
}
