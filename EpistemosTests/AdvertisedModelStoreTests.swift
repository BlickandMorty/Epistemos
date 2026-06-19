import Testing
import Foundation
@testable import Epistemos

/// reqs 6/7 — "the stack" (owner 2026-06-19): the owner-controlled, persisted set
/// of model IDs that appear in the picker. These tests pin the pure policy
/// semantics (default-canon, owner-override, stale pruning, add/remove/toggle)
/// and the live UserDefaults round-trip — deterministic, no in-app run.
@Suite("Advertised-model stack policy + store")
struct AdvertisedModelStoreTests {

    // MARK: - Pure policy (no I/O)

    @Test("nil persisted → canon defaults (canon is the DEFAULT, not a cap — req 7)")
    func defaultsToCanonWhenNeverCustomized() {
        let eff = AdvertisedModelPolicy.effectiveAdvertised(
            persisted: nil,
            canonDefaults: ["a", "b", "c"],
            fullCatalog: ["a", "b", "c", "d"]
        )
        #expect(eff == ["a", "b", "c"])
    }

    @Test("persisted owner selection overrides canon (owner choice always wins)")
    func persistedOverridesCanon() {
        let eff = AdvertisedModelPolicy.effectiveAdvertised(
            persisted: ["d", "a"],
            canonDefaults: ["a", "b", "c"],
            fullCatalog: ["a", "b", "c", "d"]
        )
        #expect(eff == ["d", "a"])
    }

    @Test("empty persisted selection is honored (owner deliberately cleared the picker)")
    func emptyPersistedHonored() {
        let eff = AdvertisedModelPolicy.effectiveAdvertised(
            persisted: [],
            canonDefaults: ["a", "b"],
            fullCatalog: ["a", "b"]
        )
        #expect(eff.isEmpty)
    }

    @Test("stale ids not in the catalog are pruned (no phantom advertised entries)")
    func stalePruned() {
        let eff = AdvertisedModelPolicy.effectiveAdvertised(
            persisted: ["a", "GONE", "b"],
            canonDefaults: [],
            fullCatalog: ["a", "b"]
        )
        #expect(eff == ["a", "b"])
    }

    @Test("duplicates collapse, first-seen order preserved")
    func dedupeOrderPreserved() {
        let eff = AdvertisedModelPolicy.effectiveAdvertised(
            persisted: ["b", "a", "b"],
            canonDefaults: [],
            fullCatalog: ["a", "b"]
        )
        #expect(eff == ["b", "a"])
    }

    @Test("advertising is idempotent + append-order (req 5 INSTALL-ANY → advertise-any)")
    func advertisingIdempotent() {
        #expect(AdvertisedModelPolicy.advertising("c", in: ["a", "b"]) == ["a", "b", "c"])
        #expect(AdvertisedModelPolicy.advertising("a", in: ["a", "b"]) == ["a", "b"])
    }

    @Test("unadvertising removes the id, keeps the rest in order")
    func unadvertisingRemoves() {
        #expect(AdvertisedModelPolicy.unadvertising("a", in: ["a", "b", "c"]) == ["b", "c"])
        #expect(AdvertisedModelPolicy.unadvertising("z", in: ["a", "b"]) == ["a", "b"])
    }

    @Test("toggling flips membership both ways")
    func togglingFlips() {
        #expect(AdvertisedModelPolicy.toggling("a", in: ["a", "b"]) == ["b"])
        #expect(AdvertisedModelPolicy.toggling("c", in: ["a", "b"]) == ["a", "b", "c"])
    }

    // MARK: - Live store (UserDefaults round-trip)

    private func isolatedStore() throws -> AdvertisedModelStore {
        let suite = "test.advertised.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return AdvertisedModelStore(defaults: defaults)
    }

    @Test("store: uncustomized → canon, persists owner selection, toggles, resets")
    func storeRoundTrip() throws {
        let store = try isolatedStore()
        let catalog: Set<String> = ["x", "y", "z"]

        // Uncustomized out of the box (→ canon defaults under the hood).
        #expect(store.isCustomized == false)

        // Owner sets a selection → persists + becomes effective + filters honestly.
        store.setAdvertised(["y", "x"])
        #expect(store.isCustomized == true)
        #expect(store.effectiveAdvertised(fullCatalog: catalog) == ["y", "x"])
        #expect(store.isAdvertised("y", fullCatalog: catalog) == true)
        #expect(store.isAdvertised("z", fullCatalog: catalog) == false)

        // Toggle removes the present one, persisted.
        store.toggleAdvertised("y", fullCatalog: catalog)
        #expect(store.effectiveAdvertised(fullCatalog: catalog) == ["x"])

        // Reset clears the override → back to uncustomized/canon.
        store.resetToCanonDefaults()
        #expect(store.isCustomized == false)
    }

    @Test("canon defaults ARE the foundation Fast/Think/Code lineup ids (ship-safe default)")
    func canonDefaultsAreFoundation() {
        #expect(AdvertisedModelStore.canonDefaults == EpistemosFoundationLineup.models.map(\.id))
    }

    // MARK: - Picker visibility filter (InferenceState.advertisedVisibleModelIDs)

    @Test("not customized → candidates unchanged (canon default = today's picker, no regression)")
    func visibleNotCustomized() {
        #expect(
            InferenceState.advertisedVisibleModelIDs(
                candidates: ["a", "b", "c"], advertised: ["a"], isCustomized: false, selectedID: nil
            ) == ["a", "b", "c"]
        )
    }

    @Test("customized → only advertised candidates are shown")
    func visibleCustomizedFilters() {
        #expect(
            InferenceState.advertisedVisibleModelIDs(
                candidates: ["a", "b", "c"], advertised: ["a", "c"], isCustomized: true, selectedID: nil
            ) == ["a", "c"]
        )
    }

    @Test("the active pick is ALWAYS kept even if not advertised (it must never vanish)")
    func visibleKeepsSelected() {
        #expect(
            InferenceState.advertisedVisibleModelIDs(
                candidates: ["a", "b", "c"], advertised: ["a"], isCustomized: true, selectedID: "b"
            ) == ["a", "b"]
        )
    }

    @Test("filtering that would empty the picker falls back to the full list (never empty)")
    func visibleNeverEmpty() {
        #expect(
            InferenceState.advertisedVisibleModelIDs(
                candidates: ["a", "b"], advertised: ["zzz"], isCustomized: true, selectedID: nil
            ) == ["a", "b"]
        )
    }

    // MARK: - Stack-row assembler (the Settings "stack" data layer)

    @Test("size text is deterministic GB, honest for unknown sizes")
    func stackSizeText() {
        #expect(ModelStackAssembler.sizeText(bytes: 2_100_000_000) == "2.1 GB")
        #expect(ModelStackAssembler.sizeText(bytes: 0) == "—")
        #expect(ModelStackAssembler.sizeText(bytes: 50_000_000) == "<0.1 GB")
    }

    @Test("RAM text is honest for unknown requirement")
    func stackRamText() {
        #expect(ModelStackAssembler.ramText(gb: 6) == "~6 GB RAM")
        #expect(ModelStackAssembler.ramText(gb: 0) == "—")
    }

    @Test("rows tag install + advertised state and sort installed-first, against the real catalog")
    func stackRowsRealCatalog() throws {
        let sources = LocalModelCatalog.textDescriptors.map(\.stackSource)
        let target = try #require(sources.first)
        let rows = ModelStackAssembler.rows(
            sources: sources,
            installedIDs: [target.id],
            advertisedIDs: [target.id]
        )
        #expect(rows.count == sources.count)
        let targetRow = try #require(rows.first { $0.id == target.id })
        #expect(targetRow.isInstalled == true)
        #expect(targetRow.isAdvertised == true)
        #expect(targetRow.displayName == target.displayName)
        // installed-first: the installed target sorts ahead of any uninstalled row.
        let targetIndex = try #require(rows.firstIndex { $0.id == target.id })
        let firstUninstalled = rows.firstIndex { !$0.isInstalled }
        if let firstUninstalled {
            #expect(targetIndex < firstUninstalled)
        }
    }

    @Test("req 11 — the foundation GGUF models (Gemma/VibeThinker/LFM/coder) ARE listed as rows")
    func stackListsFoundationGGUF() throws {
        // The req-11 guarantee: the foundation GGUF candidates have NO LocalModel-
        // Descriptor, so they must reach the stack via GemmaQATRuntimeCandidate.
        // stackSource — NOT silently dropped by a descriptor-only lookup.
        let foundationSources = EpistemosFoundationLineup.models.map(\.stackSource)
        #expect(!foundationSources.isEmpty)
        let rows = ModelStackAssembler.rows(
            sources: foundationSources,
            installedIDs: [],
            advertisedIDs: []
        )
        #expect(rows.count == foundationSources.count)
        // Each foundation model's id survives into a row (none dropped).
        let rowIDs = Set(rows.map(\.id))
        for source in foundationSources {
            #expect(rowIDs.contains(source.id))
        }
        // Sanity: the owner's named families are present by id substring.
        let allIDs = rowIDs.joined(separator: " ").lowercased()
        #expect(allIDs.contains("gemma"))
        #expect(allIDs.contains("vibethinker"))
        #expect(allIDs.contains("lfm"))
    }
}
