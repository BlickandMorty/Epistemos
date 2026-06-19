import Foundation

// DATA + FINETUNE part (5) MARKETPLACE: the in-memory registry of FineTunePacks
// with honest gating + dedup + a ProvenanceGate license check. MAS-safe — packs
// are DESCRIPTORS, never runtime code; importing/applying is a separate gated
// step. Pure, always-compiled, unit-tested.

enum FineTunePackRegistryError: Error, LocalizedError, Equatable {
    case emptyID
    case unlicensed(id: String)
    case duplicateID(String)

    var errorDescription: String? {
        switch self {
        case .emptyID: "A pack must have a non-empty id."
        case .unlicensed(let id): "Pack \(id) has no license — ProvenanceGate rejects unlicensed packs."
        case .duplicateID(let id): "A pack with id \(id) is already registered."
        }
    }
}

struct FineTunePackRegistry: Sendable, Equatable {
    private(set) var packs: [FineTunePack] = []

    init(_ packs: [FineTunePack] = []) {
        // Build via add(_:) so the same validation applies to seed data.
        for pack in packs { try? add(pack) }
    }

    /// Register a pack. ProvenanceGate: a pack with no license is rejected.
    /// Deduped by id (case-insensitive trim). Throws on empty/unlicensed/duplicate.
    @discardableResult
    mutating func add(_ pack: FineTunePack) throws -> FineTunePack {
        let id = pack.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw FineTunePackRegistryError.emptyID }
        guard !pack.license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FineTunePackRegistryError.unlicensed(id: id)
        }
        guard !packs.contains(where: { $0.id.caseInsensitiveCompare(id) == .orderedSame }) else {
            throw FineTunePackRegistryError.duplicateID(id)
        }
        packs.append(pack)
        return pack
    }

    /// Packs the current build/cert may HONESTLY surface — a Pro pack never
    /// appears in a MAS build, a Dev pack only on a dev cert. This is the
    /// browse/apply gate (owner #1: never offer what can't run here).
    func available(isPro: Bool, isDev: Bool) -> [FineTunePack] {
        packs.filter { pack in
            switch pack.gate {
            case .free: return true
            case .pro: return isPro || isDev
            case .dev: return isDev
            }
        }
    }

    func packs(ofKind kind: FineTunePackKind) -> [FineTunePack] {
        packs.filter { $0.kind == kind }
    }

    func pack(id: String) -> FineTunePack? {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        return packs.first { $0.id.caseInsensitiveCompare(id) == .orderedSame }
    }
}
