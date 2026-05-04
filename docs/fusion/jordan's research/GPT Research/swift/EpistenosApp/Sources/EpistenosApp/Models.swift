import Foundation
import SwiftData

@Model
final class Vault {
    @Attribute(.unique) var id: UUID
    var name: String
    var bookmarkData: Data
    var locked: Bool

    init(name: String, bookmarkData: Data, locked: Bool = true) {
        self.id = UUID()
        self.name = name
        self.bookmarkData = bookmarkData
        self.locked = locked
    }
}

@Model
final class VaultFile {
    var path: String
    var coherence: Double

    init(path: String, coherence: Double) {
        self.path = path
        self.coherence = coherence
    }
}

@Model
final class AgentLog {
    var timestamp: Date
    var event: String
    var provenanceHash: String

    init(timestamp: Date = Date(), event: String, provenanceHash: String) {
        self.timestamp = timestamp
        self.event = event
        self.provenanceHash = provenanceHash
    }
}

enum CompanionState: String, CaseIterable, Identifiable {
    case idle
    case thinking
    case gated
    case archived

    var id: String { rawValue }
}
