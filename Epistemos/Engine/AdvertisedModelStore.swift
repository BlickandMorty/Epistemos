import Foundation

/// reqs 6/7 (owner 2026-06-19, "the stack") — the OWNER-CONTROLLED set of model
/// IDs that appear in the model picker. The full catalog stays installable
/// (req 5 INSTALL-ANY) and every model stays retained (req 2 KEEP-ALL); this set
/// only controls picker VISIBILITY. Canon is the DEFAULT (req 7), NOT a cap — the
/// owner adds/removes any model and their choice is the source of truth.
///
/// This enum is the PURE policy core (no I/O, no `UserDefaults`, no
/// `InferenceState`) so the semantics are unit-testable on their own — mirroring
/// the existing pure-policy enums (`LocalChatModelMemoryGate`,
/// `EpistemosFastEffortSizing`). `AdvertisedModelStore` below binds it to live
/// persistence.
nonisolated enum AdvertisedModelPolicy {
    /// The effective advertised set: the persisted owner selection if one exists,
    /// otherwise the canon defaults (req 7 — canon is the default, not a cap).
    ///
    /// The result is intersected with the full catalog so a stale persisted id (a
    /// model later removed from the catalog) never lingers as a phantom advertised
    /// entry, order is preserved (the owner's chosen ordering / canon order), and
    /// duplicates are collapsed. An EMPTY persisted selection is honored verbatim
    /// (the owner explicitly cleared the picker) — only `nil` (never customized)
    /// falls back to canon.
    static func effectiveAdvertised(
        persisted: [String]?,
        canonDefaults: [String],
        fullCatalog: Set<String>
    ) -> [String] {
        let chosen = persisted ?? canonDefaults
        var seen = Set<String>()
        return chosen.filter { fullCatalog.contains($0) && seen.insert($0).inserted }
    }

    /// Add a model to the advertised set (idempotent, append-preserving order).
    /// The caller starts from the current EFFECTIVE set, so the first toggle away
    /// from default-canon persists the whole canon set plus the addition (the
    /// owner's first edit doesn't silently drop the canon models).
    static func advertising(_ id: String, in current: [String]) -> [String] {
        guard !current.contains(id) else { return current }
        return current + [id]
    }

    /// Remove a model from the advertised set (order-preserving for the rest).
    static func unadvertising(_ id: String, in current: [String]) -> [String] {
        current.filter { $0 != id }
    }

    /// Toggle a model's advertised membership.
    static func toggling(_ id: String, in current: [String]) -> [String] {
        current.contains(id) ? unadvertising(id, in: current) : advertising(id, in: current)
    }

    /// Whether an id is advertised in the given effective set.
    static func isAdvertised(_ id: String, in current: [String]) -> Bool {
        current.contains(id)
    }
}

/// Live binding of `AdvertisedModelPolicy` to `UserDefaults`. Thin I/O wrapper:
/// reads/writes the persisted owner selection and supplies the canon default
/// (the foundation Fast/Think/Code GGUF lineup). Model IDs only — no secrets —
/// so `UserDefaults` is the correct store (API keys stay in the Keychain).
///
/// Not `Sendable` (it holds `UserDefaults`); constructed at the use site (the
/// Settings "stack" UI + the picker visibility filter). The testable semantics
/// live in `AdvertisedModelPolicy`.
nonisolated struct AdvertisedModelStore {
    /// Versioned persistence key so a future schema change is a clean migration.
    static let persistenceKey = "epistemos.advertisedModelIDs.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The canon DEFAULT advertised set when the owner hasn't customized: the
    /// foundation Fast/Think/Code GGUF models (the ship lineup), in ladder order
    /// — so the picker is never empty out of the box (req 7).
    static var canonDefaults: [String] {
        EpistemosFoundationLineup.models.map(\.id)
    }

    /// The persisted owner selection, or `nil` when never customized (→ canon).
    var persistedSelection: [String]? {
        defaults.stringArray(forKey: Self.persistenceKey)
    }

    /// Whether the owner has customized the advertised set (vs running on canon).
    var isCustomized: Bool {
        persistedSelection != nil
    }

    /// The effective advertised set, pruned against the full installable catalog.
    func effectiveAdvertised(fullCatalog: Set<String>) -> [String] {
        AdvertisedModelPolicy.effectiveAdvertised(
            persisted: persistedSelection,
            canonDefaults: Self.canonDefaults,
            fullCatalog: fullCatalog
        )
    }

    /// Whether `id` is advertised, resolved against the full catalog.
    func isAdvertised(_ id: String, fullCatalog: Set<String>) -> Bool {
        AdvertisedModelPolicy.isAdvertised(
            id,
            in: effectiveAdvertised(fullCatalog: fullCatalog)
        )
    }

    /// Persist the owner's advertised selection verbatim (order preserved).
    func setAdvertised(_ ids: [String]) {
        defaults.set(ids, forKey: Self.persistenceKey)
    }

    /// Toggle `id`'s membership and persist. Starts from the current effective set
    /// so the first toggle keeps the canon models alongside the change.
    func toggleAdvertised(_ id: String, fullCatalog: Set<String>) {
        let current = effectiveAdvertised(fullCatalog: fullCatalog)
        setAdvertised(AdvertisedModelPolicy.toggling(id, in: current))
    }

    /// Clear the owner override → fall back to canon defaults.
    func resetToCanonDefaults() {
        defaults.removeObject(forKey: Self.persistenceKey)
    }
}
