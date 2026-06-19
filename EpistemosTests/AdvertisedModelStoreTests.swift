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
}
