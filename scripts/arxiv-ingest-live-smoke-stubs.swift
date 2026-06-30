import CryptoKit
import Foundation
import SwiftData

@Model
final class SDPage {
    var id: String = UUID().uuidString
    var title: String = ""
    var emoji: String = ""
    var body: String = ""
    var format: String = "markdown"
    var filePath: String?
    var subfolder: String?
    var wordCount: Int = 0
    var lastSyncedBodyHash: String?
    var lastSyncedAt: Date?
    var needsVaultSync: Bool = false
    var frontMatterData: Data?

    init(title: String, emoji: String = "") {
        self.id = UUID().uuidString
        self.title = title
        self.emoji = emoji
    }

    var frontMatter: [String: String] {
        get {
            guard let frontMatterData,
                  let decoded = try? JSONDecoder().decode([String: String].self, from: frontMatterData)
            else {
                return [:]
            }
            return decoded
        }
        set {
            frontMatterData = try? JSONEncoder().encode(newValue)
        }
    }

    func saveBody(_ content: String) {
        NoteFileStorage.writeBody(pageId: id, content: content)
    }

    static func bodyHash(_ body: String) -> String {
        SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

@Model
final class SDFolder {
    var id: String = UUID().uuidString
    init() {}
}

@Model
final class SDPageVersion {
    var id: String = UUID().uuidString
    init() {}
}

final class GraphState {
    var needsRefresh = false
}

enum NoteFileStorage {
    private nonisolated(unsafe) static var bodies: [String: String] = [:]

    static func writeBody(pageId: String, content: String) {
        bodies[pageId] = content
    }

    static func readBody(pageId: String, mapped _: Bool = false, fast _: Bool = false) -> String {
        bodies[pageId] ?? ""
    }

    static func bodyExists(pageId: String) -> Bool {
        bodies[pageId] != nil
    }

    static func deleteBody(pageId: String) {
        bodies.removeValue(forKey: pageId)
    }
}
