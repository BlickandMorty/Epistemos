import Foundation

struct MarkEditEpdocDeltaChange: Equatable {
    let fromUTF16: Int
    let toUTF16: Int
    let insertedText: String
}

struct MarkEditEpdocTransaction: Equatable {
    let documentInstance: String
    let revision: Int
    let startUTF16Length: Int
    let endUTF16Length: Int
    let changes: [MarkEditEpdocDeltaChange]

    init(
        documentInstance: String,
        revision: Int,
        startUTF16Length: Int,
        endUTF16Length: Int,
        changes: [MarkEditEpdocDeltaChange]
    ) {
        self.documentInstance = documentInstance
        self.revision = revision
        self.startUTF16Length = startUTF16Length
        self.endUTF16Length = endUTF16Length
        self.changes = changes
    }

    init?(payload: [String: Any]) {
        guard payload["kind"] as? String == "transaction",
              let documentInstance = payload["documentInstance"] as? String,
              !documentInstance.isEmpty,
              let revision = Self.integer(payload["revision"]),
              let startUTF16Length = Self.integer(payload["startUTF16Length"]),
              let endUTF16Length = Self.integer(payload["endUTF16Length"]),
              let rawChanges = payload["changes"] as? [[String: Any]] else {
            return nil
        }
        let changes = rawChanges.compactMap { rawChange -> MarkEditEpdocDeltaChange? in
            guard let fromUTF16 = Self.integer(rawChange["fromUTF16"]),
                  let toUTF16 = Self.integer(rawChange["toUTF16"]),
                  let insertedText = rawChange["insertedText"] as? String else {
                return nil
            }
            return MarkEditEpdocDeltaChange(
                fromUTF16: fromUTF16,
                toUTF16: toUTF16,
                insertedText: insertedText
            )
        }
        guard changes.count == rawChanges.count else { return nil }
        self.init(
            documentInstance: documentInstance,
            revision: revision,
            startUTF16Length: startUTF16Length,
            endUTF16Length: endUTF16Length,
            changes: changes
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }
}

struct MarkEditEpdocCheckpoint: Equatable {
    let text: String
    let documentInstance: String
    let revision: Int

    init?(payload: [String: Any]) {
        guard let text = payload["text"] as? String,
              let documentInstance = payload["documentInstance"] as? String,
              !documentInstance.isEmpty,
              let revision = MarkEditEpdocCheckpoint.integer(payload["revision"]) else {
            return nil
        }
        self.text = text
        self.documentInstance = documentInstance
        self.revision = revision
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }
}

enum MarkEditEpdocDeltaApplyResult: Equatable {
    case accepted
    case ignoredDuplicate
    case ignoredStaleInstance
    case requiresCheckpoint
}

@MainActor
final class MarkEditEpdocDeltaMirror {
    private let storage: NSMutableString
    private(set) var documentInstance: String?
    private(set) var revision = 0
    private(set) var isSynchronized = true

    init(text: String) {
        storage = NSMutableString(string: text)
    }

    func resetDocument(text: String) {
        storage.setString(text)
        documentInstance = nil
        revision = 0
        isSynchronized = true
    }

    func replaceTextPreservingClock(_ text: String) {
        storage.setString(text)
        isSynchronized = true
    }

    func reconcile(text: String, documentInstance: String, revision: Int) {
        storage.setString(text)
        self.documentInstance = documentInstance
        self.revision = max(0, revision)
        isSynchronized = true
    }

    func invalidate() {
        isSynchronized = false
    }

    func apply(_ transaction: MarkEditEpdocTransaction) -> MarkEditEpdocDeltaApplyResult {
        if let documentInstance,
           transaction.documentInstance != documentInstance {
            return .ignoredStaleInstance
        }
        if transaction.revision <= revision {
            return .ignoredDuplicate
        }
        guard isSynchronized,
              transaction.revision == revision + 1,
              transaction.startUTF16Length == storage.length,
              transaction.startUTF16Length >= 0,
              transaction.endUTF16Length >= 0,
              !transaction.changes.isEmpty else {
            isSynchronized = false
            return .requiresCheckpoint
        }

        var previousTo = 0
        var expectedEndLength = transaction.startUTF16Length
        for change in transaction.changes {
            guard change.fromUTF16 >= previousTo,
                  change.toUTF16 >= change.fromUTF16,
                  change.toUTF16 <= transaction.startUTF16Length else {
                isSynchronized = false
                return .requiresCheckpoint
            }
            expectedEndLength -= change.toUTF16 - change.fromUTF16
            expectedEndLength += (change.insertedText as NSString).length
            previousTo = change.toUTF16
        }
        guard expectedEndLength == transaction.endUTF16Length else {
            isSynchronized = false
            return .requiresCheckpoint
        }

        for change in transaction.changes.reversed() {
            storage.replaceCharacters(
                in: NSRange(
                    location: change.fromUTF16,
                    length: change.toUTF16 - change.fromUTF16
                ),
                with: change.insertedText
            )
        }
        guard storage.length == transaction.endUTF16Length else {
            isSynchronized = false
            return .requiresCheckpoint
        }

        documentInstance = transaction.documentInstance
        revision = transaction.revision
        return .accepted
    }

    func checkpointText() -> String? {
        guard isSynchronized else { return nil }
        return storage.copy() as? String
    }
}
