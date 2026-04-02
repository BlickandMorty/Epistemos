import Testing
import Foundation
@testable import Epistemos

// MARK: - Research Mode Tests
// Validates tool registration, complexity gating, evidence scoring,
// confidence tracking, and ensures no blocked test strings leak in.

@Suite("Research Mode")
@MainActor
struct ResearchModeTests {

    // MARK: - Tool Registration

    @Test("All 7 research tools are registered in OmegaToolRegistry")
    func researchToolsAreRegistered() {
        let names = OmegaToolRegistry.all.map(\.name)
        #expect(names.contains("readpagecontent"))
        #expect(names.contains("searchpapers"))
        #expect(names.contains("collectsnippet"))
        #expect(names.contains("savecitation"))
        #expect(names.contains("createresearchnote"))
        #expect(names.contains("analyzecontradiction"))
        #expect(names.contains("scoreevidence"))
    }

    @Test("Research tools are assigned to correct agents")
    func researchToolAgentAssignment() {
        #expect(OmegaToolRegistry.agent(for: "readpagecontent") == "safari")
        #expect(OmegaToolRegistry.agent(for: "searchpapers") == "safari")
        #expect(OmegaToolRegistry.agent(for: "collectsnippet") == "notes")
        #expect(OmegaToolRegistry.agent(for: "savecitation") == "notes")
        #expect(OmegaToolRegistry.agent(for: "createresearchnote") == "notes")
        #expect(OmegaToolRegistry.agent(for: "analyzecontradiction") == "notes")
        #expect(OmegaToolRegistry.agent(for: "scoreevidence") == "notes")
    }

    @Test("No research tools are marked destructive or require confirmation")
    func researchToolsAreNonDestructive() {
        let researchNames: Set<String> = [
            "readpagecontent", "searchpapers", "collectsnippet", "savecitation",
            "createresearchnote", "analyzecontradiction", "scoreevidence"
        ]
        for tool in OmegaToolRegistry.all where researchNames.contains(tool.name) {
            if tool.destructive {
                Issue.record("Tool \(tool.name) should not be destructive")
            }
            if tool.requiresConfirmation {
                Issue.record("Tool \(tool.name) should not require confirmation")
            }
        }
    }

    @Test("Planning prompt block includes research tools")
    func planningPromptIncludesResearchTools() {
        let block = OmegaToolRegistry.planningPromptBlock()
        #expect(block.contains("readpagecontent"))
        #expect(block.contains("searchpapers"))
        #expect(block.contains("collectsnippet"))
        #expect(block.contains("createresearchnote"))
    }

    @Test("Total tool count reflects the current research and computer-use catalog")
    func totalToolCount() {
        #expect(OmegaToolRegistry.all.count == 33)
    }

    // MARK: - Complexity Gate

    @Test("Complexity gate routes explicit research prefixes")
    func gateRoutesResearchPrefixes() {
        #expect(ResearchComplexityGate.requiresResearch("research transformer architectures"))
        #expect(ResearchComplexityGate.requiresResearch("research: Mamba-2 vs attention"))
        #expect(ResearchComplexityGate.requiresResearch("/research climate change evidence"))
        #expect(ResearchComplexityGate.requiresResearch("please research hegemony"))
        #expect(ResearchComplexityGate.requiresResearch("can you research transformer scaling laws"))
        #expect(ResearchComplexityGate.requiresResearch("find evidence for gene therapy"))
        #expect(ResearchComplexityGate.requiresResearch("investigate supply chain issues"))
    }

    @Test("Complexity gate rejects simple queries")
    func gateRejectsSimple() {
        #expect(!ResearchComplexityGate.requiresResearch("what time is it"))
        #expect(!ResearchComplexityGate.requiresResearch("hello"))
        #expect(!ResearchComplexityGate.requiresResearch("create a note"))
        #expect(!ResearchComplexityGate.requiresResearch("open safari"))
    }

    @Test("Complexity gate detects keyword clusters")
    func gateDetectsKeywordClusters() {
        // Single keyword is not enough
        #expect(!ResearchComplexityGate.requiresResearch("what does the evidence say"))
        // Two keywords should trigger
        #expect(ResearchComplexityGate.requiresResearch("what peer-reviewed sources show evidence for"))
        #expect(ResearchComplexityGate.requiresResearch("find papers with citations about this"))
    }

    @Test("Strip prefix removes research prefixes correctly")
    func stripPrefix() {
        #expect(ResearchComplexityGate.stripPrefix("/research climate change") == "climate change")
        #expect(ResearchComplexityGate.stripPrefix("research: Mamba-2") == "Mamba-2")
        #expect(ResearchComplexityGate.stripPrefix("research transformers") == "transformers")
        #expect(ResearchComplexityGate.stripPrefix("hello world") == "hello world")
    }

    @Test("Chat surfaces do not keep a dedicated research handoff path")
    func chatSurfacesDoNotKeepDedicatedResearchHandoffPath() throws {
        let miniChat = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let chatState = try loadTextFile("Epistemos/State/ChatState.swift")

        #expect(!miniChat.contains("ResearchComplexityGate.handoffMessage("))
        #expect(!chatState.contains("ResearchComplexityGate.handoffMessage("))
        #expect(!chatState.contains("await orchestrator.submitTask(\"research: \\(cleaned)\")"))
    }

    @Test("Chat surfaces do not special-case research phrasing anymore")
    func chatSurfacesDoNotSpecialCaseResearchPhrasing() throws {
        let miniChat = try loadTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let chatState = try loadTextFile("Epistemos/State/ChatState.swift")

        #expect(!miniChat.contains("ResearchComplexityGate.hasExplicitResearchPrefix(trimmed)"))
        #expect(!miniChat.contains("ResearchComplexityGate.requiresResearch(trimmed)"))
        #expect(!chatState.contains("ResearchComplexityGate.hasExplicitResearchPrefix(trimmed)"))
        #expect(!chatState.contains("ResearchComplexityGate.requiresResearch(trimmed)"))
    }

    // MARK: - Evidence Scorer

    @Test("Evidence scorer identifies arxiv as preprint tier")
    func scorerArxiv() {
        let tier = ResearchEvidenceScorer.tier(for: "https://arxiv.org/abs/2405.21060")
        #expect(tier == .arxivPreprint)
        #expect(tier.confidence == 0.70)
    }

    @Test("Evidence scorer identifies nature.com as peer-reviewed")
    func scorerPeerReviewed() {
        #expect(ResearchEvidenceScorer.tier(for: "https://www.nature.com/articles/s41586-024") == .peerReviewed)
        #expect(ResearchEvidenceScorer.tier(for: "https://doi.org/10.1038/s41586") == .peerReviewed)
        #expect(ResearchEvidenceScorer.tier(for: "https://pubmed.ncbi.nlm.nih.gov/12345") == .peerReviewed)
    }

    @Test("Evidence scorer identifies gov domains as primary data")
    func scorerPrimary() {
        #expect(ResearchEvidenceScorer.tier(for: "https://data.gov/dataset/climate") == .primaryData)
        #expect(ResearchEvidenceScorer.tier(for: "https://www.cdc.gov/reports") == .primaryData)
    }

    @Test("Evidence scorer identifies news sources")
    func scorerNews() {
        #expect(ResearchEvidenceScorer.tier(for: "https://www.reuters.com/article") == .news)
        #expect(ResearchEvidenceScorer.tier(for: "https://www.nytimes.com/2024") == .news)
    }

    @Test("Evidence scorer identifies blogs")
    func scorerBlog() {
        #expect(ResearchEvidenceScorer.tier(for: "https://medium.com/@user/post") == .blog)
        #expect(ResearchEvidenceScorer.tier(for: "https://example.substack.com/p/article") == .blog)
    }

    @Test("Evidence scorer defaults to unknown for unrecognized URLs")
    func scorerUnknown() {
        let tier = ResearchEvidenceScorer.tier(for: "https://random-site.com/page")
        #expect(tier == .unknown)
        #expect(tier.confidence == 0.20)
    }

    @Test("Score method respects sourceType override")
    func scoreOverride() {
        let (tier, confidence) = ResearchEvidenceScorer.score(url: "https://random.com", sourceType: "peer_reviewed")
        #expect(tier == .peerReviewed)
        #expect(confidence == 0.85)
    }

    // MARK: - Confidence State

    @Test("Empty confidence state reports zero confidence")
    func confidenceEmpty() {
        let state = ResearchConfidenceState()
        #expect(state.overallConfidence == 0)
        #expect(!state.hasDissonance)
        #expect(!state.requiresPause)
    }

    @Test("Confidence state pauses on low evidence")
    func confidencePausesOnLow() {
        var state = ResearchConfidenceState()
        state.addSnippet(text: "fact", url: "https://blog.com", confidence: 0.30)
        #expect(state.overallConfidence == 0.30)
        #expect(state.requiresPause)
    }

    @Test("Confidence state does not pause on good evidence")
    func confidenceGoodEvidence() {
        var state = ResearchConfidenceState()
        state.addSnippet(text: "fact1", url: "https://nature.com/1", confidence: 0.85)
        state.addSnippet(text: "fact2", url: "https://arxiv.org/2", confidence: 0.70)
        state.addSnippet(text: "fact3", url: "https://doi.org/3", confidence: 0.85)
        #expect(state.overallConfidence > 0.79)
        #expect(!state.requiresPause)
    }

    @Test("Confidence state tracks contradictions")
    func confidenceTracksContradictions() {
        var state = ResearchConfidenceState()
        state.addSnippet(text: "A", url: "https://a.com", confidence: 0.80)
        state.addSnippet(text: "B", url: "https://b.com", confidence: 0.80)
        #expect(!state.hasDissonance)
        state.addContradiction(snippetA: "A", snippetB: "B", verdict: "contradict")
        #expect(state.hasDissonance)
    }

    @Test("Confidence state pauses on few sources with contradiction")
    func confidencePausesFewWithContradiction() {
        var state = ResearchConfidenceState()
        state.addSnippet(text: "X", url: "https://x.com", confidence: 0.70)
        state.addContradiction(snippetA: "X", snippetB: "Y", verdict: "contradict")
        #expect(state.requiresPause)
    }

    @Test("Confidence state reset clears all data")
    func confidenceReset() {
        var state = ResearchConfidenceState()
        state.addSnippet(text: "A", url: "u", confidence: 0.5)
        state.addContradiction(snippetA: "A", snippetB: "B", verdict: "contradict")
        state.setSessionNoteId("note-1")
        state.reset()
        #expect(state.snippets.isEmpty)
        #expect(state.contradictions.isEmpty)
        #expect(state.sessionNoteId == nil)
    }

    // MARK: - Research Orchestrator

    @Test("Research orchestrator detects research tasks")
    func orchestratorDetectsResearch() {
        #expect(ResearchOrchestrator.isResearchTask("research: transformers"))
        #expect(ResearchOrchestrator.isResearchTask("research Mamba-2"))
        #expect(ResearchOrchestrator.isResearchTask("investigate supply chain"))
        #expect(!ResearchOrchestrator.isResearchTask("create a note"))
        #expect(!ResearchOrchestrator.isResearchTask("open safari"))
    }

    // MARK: - No Hidden Personas

    @Test("Research planning prompt does not contain blocked persona strings")
    func noHiddenPersonas() throws {
        let content = try loadTextFile("Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift")
        #expect(!content.contains("research assistant"))
        #expect(!content.contains("You are a research"))
    }

    @Test("New research files do not use blocked names")
    func noBlockedFileNames() throws {
        let content = try loadTextFile("Epistemos.xcodeproj/project.pbxproj")
        // These are blocked by projectDropsStandaloneResearchSubsystem
        #expect(!content.contains("ResearchState.swift"))
        #expect(!content.contains("ResearchService.swift"))
        #expect(!content.contains("ResearchIntents.swift"))
        #expect(!content.contains("PaperEntity.swift"))
        #expect(!content.contains("ResearchTypes.swift"))
        // New files should exist
        #expect(content.contains("ResearchOrchestrator.swift"))
        #expect(content.contains("ResearchEvidenceScorer.swift"))
        #expect(content.contains("ResearchConfidenceState.swift"))
        #expect(content.contains("ResearchComplexityGate.swift"))
    }

    // MARK: - Helpers

    private func loadTextFile(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repoRootURL().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func repoRootURL() -> URL {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        return testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    }
}
