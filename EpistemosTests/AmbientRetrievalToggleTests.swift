import Foundation
import Testing

@testable import Epistemos

@Suite("AmbientRetrievalToggle (W10.15)", .serialized)
@MainActor
struct AmbientRetrievalToggleTests {

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AmbientRetrievalToggleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test("Per-conversation overrides and default mode survive reload")
    func perConversationOverridesAndDefaultPersistAcrossReload() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            AmbientRetrievalToggle.shared.resetForTesting()
        }

        let toggle = AmbientRetrievalToggle.shared
        toggle.setUserDefaultsForTesting(defaults)
        toggle.defaultForNewConversations = true
        toggle.setEnabled(false, for: "strict-chat")
        toggle.setEnabled(true, for: "creative-chat")

        toggle.reloadFromUserDefaultsForTesting()

        #expect(toggle.isEnabled(for: "new-chat") == true)
        #expect(toggle.isEnabled(for: "strict-chat") == false)
        #expect(toggle.isEnabled(for: "creative-chat") == true)
    }

    @Test("Reset removes explicit override and falls back to persisted default")
    func resetRemovesOverrideAndPersistsFallbackBehavior() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            AmbientRetrievalToggle.shared.resetForTesting()
        }

        let toggle = AmbientRetrievalToggle.shared
        toggle.setUserDefaultsForTesting(defaults)
        toggle.defaultForNewConversations = true
        toggle.setEnabled(false, for: "draft-chat")

        #expect(toggle.isEnabled(for: "draft-chat") == false)

        toggle.reset("draft-chat")
        toggle.reloadFromUserDefaultsForTesting()

        #expect(toggle.isEnabled(for: "draft-chat") == true)
    }
}
