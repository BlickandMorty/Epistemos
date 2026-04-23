import Foundation
import SwiftData
import Testing
@testable import Epistemos

// MARK: - Phase R.2 Regression Tests
//
// These tests verify the UniFFI-bridged alias registry introduced in
// `agent_core/src/resources/alias_registry.rs` and wired into the Swift
// sidebar at `ModelInvolvementSheet.expandModelIDsForFetch`. They are
// the Swift-side arm of the split-brain tests called out in the plan
// (see `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §Phase R.9 and
// `docs/KNOWN_ISSUES_REGISTER.md` I-001).
//
// The Rust arm lives in `agent_core/src/resources/alias_registry.rs` and
// covers the registry mechanics directly (8 tests). The tests here
// cover the UniFFI boundary + the sidebar fetch expansion, which must
// be verified from Swift to catch Swift-side regressions (e.g. the
// binding being commented out, the helper not being called, or the
// fetch predicate forgetting to iterate the expanded set).

@Suite("Phase R.2 — Resource Alias Registry")
struct PhaseRResourceRegressionTests {

    // MARK: - Helpers

    private func makeChatContainer() throws -> ModelContainer {
        let schema = Schema([SDChat.self, SDMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - UniFFI boundary

    @Test("canonicalModelId FFI normalizes gpt-5.4 aliases to provider:model form")
    func canonicalModelIdNormalizesGpt54Aliases() async throws {
        // All three registered forms of GPT-5.4 must produce the same
        // canonical "openai:gpt-5.4" string.
        #expect(canonicalModelId(alias: "gpt-5.4") == "openai:gpt-5.4")
        #expect(canonicalModelId(alias: "openai:gpt-5.4") == "openai:gpt-5.4")
        #expect(canonicalModelId(alias: "gpt_5_4") == "openai:gpt-5.4")
    }

    @Test("canonicalModelId FFI returns nil for unregistered aliases")
    func canonicalModelIdReturnsNilForUnknown() async throws {
        #expect(canonicalModelId(alias: "totally-made-up-future-model-v99") == nil)
    }

    @Test("expandModelAliases FFI fans out all registered forms")
    func expandModelAliasesFansOutAllRegisteredForms() async throws {
        // Input form doesn't matter — output is the full set.
        let viaPlain = Set(expandModelAliases(alias: "gpt-5.4"))
        let viaPrefix = Set(expandModelAliases(alias: "openai:gpt-5.4"))
        let viaUnderscore = Set(expandModelAliases(alias: "gpt_5_4"))
        #expect(viaPlain == viaPrefix)
        #expect(viaPrefix == viaUnderscore)
        #expect(viaPlain.contains("gpt-5.4"))
        #expect(viaPlain.contains("openai:gpt-5.4"))
        #expect(viaPlain.contains("gpt_5_4"))
    }

    @Test("expandModelAliases FFI preserves unknown input as singleton")
    func expandModelAliasesPreservesUnknownInput() async throws {
        let out = expandModelAliases(alias: "future-model-v99")
        #expect(out == ["future-model-v99"])
    }

    // MARK: - Sidebar fetch expansion

    @Test("expandModelIDsForFetch unions all aliases across multiple inputs")
    @MainActor
    func expandModelIDsForFetchUnionsAllAliases() async throws {
        let expanded = ModelInvolvementContent.expandModelIDsForFetch(
            modelIDs: ["gpt-5.4", "claude-sonnet-4-6"]
        )
        // Both model families and all their known alias forms must appear.
        #expect(expanded.contains("gpt-5.4"))
        #expect(expanded.contains("openai:gpt-5.4"))
        #expect(expanded.contains("gpt_5_4"))
        #expect(expanded.contains("claude-sonnet-4-6"))
        #expect(expanded.contains("anthropic:claude-sonnet-4-6"))
    }

    @Test("expandModelIDsForFetch preserves unknown IDs verbatim")
    @MainActor
    func expandModelIDsForFetchPreservesUnknownIDs() async throws {
        let expanded = ModelInvolvementContent.expandModelIDsForFetch(
            modelIDs: ["totally-custom-local-model"]
        )
        #expect(expanded == ["totally-custom-local-model"])
    }

    // MARK: - End-to-end SwiftData regression (the I-001 scenario)

    @Test("gpt_5_4 sidebar shows full history across both stored ID forms")
    @MainActor
    func gpt54SidebarShowsFullHistoryAcrossBothStoredIDForms() throws {
        // This is the canonical I-001 regression. The bug: a chat
        // message saved with `authoredByModelID = "openai:gpt-5.4"`
        // (the prefixed form used by some provider-discovery code
        // paths) is invisible to a sidebar query that asks for
        // "gpt-5.4" (the plain form used by model-picker selection).
        //
        // With Phase R.2 wired, `loadContributions` expands the incoming
        // modelID set through the Rust `AliasRegistry` so both forms
        // match. This test fails if the wiring is ever removed or if
        // the default registry loses the gpt-5.4 seed.

        let container = try makeChatContainer()
        let context = ModelContext(container)

        let chat = SDChat(title: "Split-Brain Regression", chatType: "notes")
        context.insert(chat)

        // Message A: persisted with the plain form.
        let plainForm = SDMessage(role: "assistant", content: "Stored as plain gpt-5.4")
        plainForm.chat = chat
        plainForm.authoredByProviderID = "openai"
        plainForm.authoredByModelID = "gpt-5.4"
        plainForm.createdAt = Date(timeIntervalSince1970: 2)
        context.insert(plainForm)

        // Message B: persisted with the vendor-prefixed form.
        let prefixedForm = SDMessage(role: "assistant", content: "Stored as openai:gpt-5.4")
        prefixedForm.chat = chat
        prefixedForm.authoredByProviderID = "openai"
        prefixedForm.authoredByModelID = "openai:gpt-5.4"
        prefixedForm.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(prefixedForm)

        // Message C: persisted with the filename-safe underscore form.
        let underscoreForm = SDMessage(role: "assistant", content: "Stored as gpt_5_4")
        underscoreForm.chat = chat
        underscoreForm.authoredByProviderID = "openai"
        underscoreForm.authoredByModelID = "gpt_5_4"
        underscoreForm.createdAt = Date(timeIntervalSince1970: 3)
        context.insert(underscoreForm)

        // Unrelated: a different model that must NOT appear in the
        // gpt-5.4 results (guards against an over-broad expansion).
        let unrelated = SDMessage(role: "assistant", content: "Different model")
        unrelated.chat = chat
        unrelated.authoredByProviderID = "anthropic"
        unrelated.authoredByModelID = "claude-sonnet-4-6"
        unrelated.createdAt = Date(timeIntervalSince1970: 4)
        context.insert(unrelated)

        try context.save()

        // Query with ONLY the plain form. All three gpt-5.4 forms must
        // return; the claude message must NOT.
        let contributions = ModelInvolvementContent.loadContributions(
            modelIDs: ["gpt-5.4"],
            in: context
        )

        let fetchedIDs = Set(contributions.map(\.id))
        #expect(fetchedIDs.contains(plainForm.id))
        #expect(fetchedIDs.contains(prefixedForm.id))
        #expect(fetchedIDs.contains(underscoreForm.id))
        #expect(!fetchedIDs.contains(unrelated.id))
    }

    @Test("querying by the prefixed form returns plain-form records too")
    @MainActor
    func queryingByPrefixedFormReturnsPlainFormRecords() throws {
        // Same bug class, inverse direction: query uses "openai:gpt-5.4"
        // but the records were written as plain "gpt-5.4". This exercises
        // the expansion from the other direction.

        let container = try makeChatContainer()
        let context = ModelContext(container)

        let chat = SDChat(title: "Inverse Split-Brain", chatType: "notes")
        context.insert(chat)

        let plainForm = SDMessage(role: "assistant", content: "Stored as gpt-5.4")
        plainForm.chat = chat
        plainForm.authoredByProviderID = "openai"
        plainForm.authoredByModelID = "gpt-5.4"
        plainForm.createdAt = Date()
        context.insert(plainForm)

        try context.save()

        let contributions = ModelInvolvementContent.loadContributions(
            modelIDs: ["openai:gpt-5.4"],
            in: context
        )

        #expect(contributions.contains { $0.id == plainForm.id })
    }
}
