import Foundation
import Testing

@Suite("Stash 6 Non-Chat Donor Closeout")
struct Stash6NonChatDonorCloseoutTests {
    private func loadRepoTextFile(_ relativePath: String) throws -> String {
        var cursor = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        for _ in 0..<8 {
            let agents = cursor.appendingPathComponent("AGENTS.md")
            let editorManifest = cursor.appendingPathComponent("js-editor/package.json")
            if FileManager.default.fileExists(atPath: agents.path),
               FileManager.default.fileExists(atPath: editorManifest.path) {
                return try String(
                    contentsOf: cursor.appendingPathComponent(relativePath),
                    encoding: .utf8
                )
            }

            let parent = cursor.deletingLastPathComponent()
            guard parent.path != cursor.path else { break }
            cursor = parent
        }

        throw CocoaError(.fileNoSuchFile)
    }

    @Test("phase two deck preserves addressable neural substrate dispatch rules")
    func phaseTwoDeckPreservesAddressableNeuralSubstrateDispatchRules() throws {
        let deck = try loadMirroredSourceTextFile("docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md")

        #expect(deck.contains("13 parallel Codex/Claude terminals"))
        #expect(deck.contains("docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md"))
        #expect(deck.contains("Every PR touching local inference, model routing"))
        #expect(deck.contains("Neural Substrate check"))
        #expect(deck.contains("F-Sparse-Runtime-Split"))
        #expect(deck.contains("F-KV-Direct-Gate"))
        #expect(deck.contains("F-70B-Local-Cocktail"))
    }

    @Test("research index preserves shadow projection and neural substrate addenda")
    func researchIndexPreservesShadowProjectionAndNeuralSubstrateAddenda() throws {
        let index = try loadMirroredSourceTextFile("docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md")

        #expect(index.contains("2026-05-24 Candidate Addendum — Shadow Projection + Research Construction"))
        #expect(index.contains("2026-05-24 Canon Target — Addressable Neural Substrate"))
        #expect(index.contains("Epistemos turns a dense model into an addressable neural substrate"))
        #expect(index.contains("F-KV-Direct-Gate"))
    }

    @Test("current lattice explainer is newer than the stash six donor")
    func currentLatticeExplainerIsNewerThanStashSixDonor() throws {
        let explainer = try loadRepoTextFile("artifacts/lattice-coordinate-explainer/index.html")

        #expect(explainer.contains("§3K Addressable Neural Substrate"))
        #expect(explainer.contains("NeuralSubstrateAddressSet"))
        #expect(explainer.contains("layers, rank-one components, KV pages, adapters"))
        #expect(explainer.contains("The SSM/router calls the right active assembly"))
    }

    @Test("stash six non-chat recovery is closed without raw HTML downgrade")
    func stashSixNonChatRecoveryIsClosedWithoutRawHTMLDowngrade() throws {
        let doc = try loadMirroredSourceTextFile("docs/audits/STASH6_NONCHAT_DONOR_CLOSEOUT_2026_05_26.md")

        #expect(doc.contains("No stash was popped, dropped, checked out, or bulk-applied."))
        #expect(doc.contains("not restored"))
        #expect(doc.contains("would be a downgrade"))
        #expect(doc.contains("closed for current product recovery"))
    }
}
