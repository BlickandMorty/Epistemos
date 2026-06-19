import Foundation

// DATA + FINETUNE part (5) MARKETPLACE — the SHARE verb (owner: "browse/import/apply/
// share"). Exports a pack DESCRIPTOR to a portable, versioned, copy-pasteable string
// and parses one back, RE-VALIDATING it through the ProvenanceGate (a shared pack must
// still carry a license + id — no license, no entry). MAS-safe: descriptors only,
// never runtime code, never the pack's bytes. Pure + unit-tested.
enum FineTunePackShareError: Error, LocalizedError, Equatable {
    case notAShare
    case malformed
    case unlicensed

    var errorDescription: String? {
        switch self {
        case .notAShare:
            "That isn't a shared Epistemos pack (expected an \"epistemos-pack:v1:\" string)."
        case .malformed:
            "The shared pack is malformed and couldn't be read."
        case .unlicensed:
            "The shared pack has no license — the ProvenanceGate rejects unlicensed packs."
        }
    }
}

enum FineTunePackShare {
    /// Versioned envelope so a share is recognizable + forward-compatible.
    static let prefix = "epistemos-pack:v1:"

    /// Whether a string looks like a shared pack (so import can route it to `parse`).
    static func isShare(_ string: String) -> Bool {
        string.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(prefix)
    }

    /// Export a pack to a portable, copy-pasteable share string: the version prefix
    /// followed by the compact pack JSON. Honest empty on the (unreachable for a valid
    /// pack) encode failure.
    static func export(_ pack: FineTunePack) -> String {
        guard
            let data = try? JSONEncoder().encode(pack),
            let json = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return prefix + json
    }

    /// Parse a shared pack back, re-validating through the ProvenanceGate. Throws an
    /// honest error when the string isn't a share, is malformed, or is unlicensed.
    static func parse(_ shared: String) throws -> FineTunePack {
        let trimmed = shared.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { throw FineTunePackShareError.notAShare }
        let json = String(trimmed.dropFirst(prefix.count))
        guard
            let data = json.data(using: .utf8),
            let pack = try? JSONDecoder().decode(FineTunePack.self, from: data)
        else {
            throw FineTunePackShareError.malformed
        }
        // ProvenanceGate re-validation: a shared pack must still be identified + licensed.
        guard !pack.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FineTunePackShareError.malformed
        }
        guard !pack.license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FineTunePackShareError.unlicensed
        }
        return pack
    }
}
