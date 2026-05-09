import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Sidebar Mode Store")
struct SidebarModeStoreTests {
    @Test("mode persists across store instances")
    func modePersistsAcrossStoreInstances() {
        let suiteName = "com.epistemos.tests.SidebarModeStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SidebarModeStore(defaults: defaults)
        #expect(store.currentMode == .myVault)

        store.select(.modelVaults)

        let restored = SidebarModeStore(defaults: defaults)
        #expect(restored.currentMode == .modelVaults)
    }

    @Test("invalid persisted mode falls back to My Vault")
    func invalidPersistedModeFallsBackToMyVault() {
        let suiteName = "com.epistemos.tests.SidebarModeStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("not-a-sidebar-mode", forKey: SidebarModeStore.modeKey)

        let store = SidebarModeStore(defaults: defaults)
        #expect(store.currentMode == .myVault)
    }
}
