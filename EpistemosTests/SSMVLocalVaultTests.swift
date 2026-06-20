import Testing
import Foundation

@testable import Epistemos

// SS-MV (2, owner 2026-06-20): LOCAL models never read their model vault — augmentedSystemPrompt
// was injected only on the cloud (LLMService) + Apple Intelligence paths, ZERO on local. This
// wires it into BOTH local chat paths (TriageService.localStreamOrFallback +
// localGenerateOrFallback) under the .compact budget, guarded (no vault → original prompt).
@Suite("SS-MV local model-vault injection")
struct SSMVLocalVaultTests {

    @Test("a model WITH a vault augments the system prompt under .compact (the local-path mechanism)")
    func compactBudgetIncludesVault() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssmv-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let store = KnowledgeProfileStore(baseDirectory: tempRoot)

        let modelID = "ssmv-test-model"
        let vault = CompiledModelVault(
            modelID: modelID,
            displayName: "SS-MV Test",
            knowledgeProfile: "PROFILE_MARKER_42",
            conceptIndex: "concept-index",
            activeContext: "active-context",
            instructions: "INSTRUCT_MARKER_42",
            metadata: ModelVaultMetadata(
                modelID: modelID, displayName: "SS-MV Test", compiledAt: Date(),
                noteCount: 3, conceptCount: 2, activeNoteCount: 1, tokenEstimate: 100
            )
        )
        try await store.save(vault)

        let augmented = try await store.augmentedSystemPrompt(
            existingPrompt: "USER_BASE_PROMPT", modelID: modelID, budget: .compact)
        let text = try #require(augmented)
        // The local path now sends the vault context AND the user's prompt to the model:
        #expect(text.contains("USER_BASE_PROMPT"))
        // …and the vault context was prepended (longer than the bare prompt), regardless of
        // which sections .compact selects.
        #expect(text.count > "USER_BASE_PROMPT".count)
        // The 4 canonical compiled files are vault context, NOT "Attached Files".
        #expect(!text.contains("# Attached Files"))
    }

    @Test("a user-ADDED file in the model vault dir is read into the prompt (SS-MV 3)")
    func userAddedFileIsRead() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssmv3-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let modelID = "ssmv3-model"

        // Drop a user file into the model's vault dir — NO compiled vault needed.
        let dir = await store.modelVaultDirectoryURL(for: modelID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "PROJECT_RULE_X: always use tabs"
            .write(to: dir.appendingPathComponent("my_rules.md"), atomically: true, encoding: .utf8)

        let augmented = try await store.augmentedSystemPrompt(
            existingPrompt: "BASE_PROMPT", modelID: modelID, budget: .compact)
        let text = try #require(augmented)
        #expect(text.contains("# Attached Files"))
        #expect(text.contains("my_rules.md"))
        #expect(text.contains("PROJECT_RULE_X"))   // the model can READ the user's file
        #expect(text.contains("BASE_PROMPT"))
    }

    @Test("a model with NO vault returns the prompt unchanged (the guarded fallback)")
    func noVaultReturnsUnchanged() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssmv-none-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let store = KnowledgeProfileStore(baseDirectory: tempRoot)
        let augmented = try await store.augmentedSystemPrompt(
            existingPrompt: "ONLY_THIS", modelID: "no-vault-model", budget: .compact)
        #expect(augmented?.contains("ONLY_THIS") == true)
    }

    @Test("both local chat paths are wired to inject the vault (TriageService)")
    func localPathsWired() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/TriageService.swift")
        #expect(src.contains("func vaultAugmentedLocalSystemPrompt"))
        // 1 definition + the stream path + the generate path = ≥3 occurrences.
        let uses = src.components(separatedBy: "vaultAugmentedLocalSystemPrompt").count - 1
        #expect(uses >= 3)
        #expect(src.contains("budget: .compact"))
    }
}
