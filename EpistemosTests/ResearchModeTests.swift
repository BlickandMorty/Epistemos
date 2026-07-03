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
        #expect(names.contains("web.extract"))
        #expect(names.contains("research.search_papers"))
        #expect(names.contains("research.collect_snippet"))
        #expect(names.contains("citation.save"))
        #expect(names.contains("note.research_digest"))
        #expect(names.contains("knowledge.contradiction_check"))
        #expect(names.contains("knowledge.evidence_score"))
    }

    @Test("Research tools are assigned to correct agents")
    func researchToolAgentAssignment() {
        #expect(OmegaToolRegistry.agent(for: "web.extract") == "safari")
        #expect(OmegaToolRegistry.agent(for: "research.search_papers") == "safari")
        #expect(OmegaToolRegistry.agent(for: "research.collect_snippet") == "notes")
        #expect(OmegaToolRegistry.agent(for: "citation.save") == "notes")
        #expect(OmegaToolRegistry.agent(for: "note.research_digest") == "notes")
        #expect(OmegaToolRegistry.agent(for: "knowledge.contradiction_check") == "notes")
        #expect(OmegaToolRegistry.agent(for: "knowledge.evidence_score") == "notes")
        #expect(OmegaToolRegistry.agent(for: "readpagecontent") == "safari")
        #expect(OmegaToolRegistry.agent(for: "collectsnippet") == "notes")
    }

    @Test("No research tools are marked destructive or require confirmation")
    func researchToolsAreNonDestructive() {
        let researchNames: Set<String> = [
            "web.extract", "research.search_papers", "research.collect_snippet",
            "citation.save", "note.research_digest",
            "knowledge.contradiction_check", "knowledge.evidence_score"
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
        #expect(block.contains("web.extract"))
        #expect(block.contains("research.search_papers"))
        #expect(block.contains("research.collect_snippet"))
        #expect(block.contains("note.research_digest"))
        #expect(!block.contains("readpagecontent"))
        #expect(!block.contains("searchpapers"))
        #expect(!block.contains("collectsnippet"))
        #expect(!block.contains("createresearchnote"))
    }

    @Test("D2 graph tools are registered in OmegaToolRegistry")
    func d2GraphToolsAreRegistered() {
        let names = Set(OmegaToolRegistry.all.map(\.name))
        for name in [
            "graph.search_semantic",
            "graph.search_fulltext",
            "graph.get_node",
            "graph.traverse",
            "graph.create_node",
            "graph.create_edge",
            "graph.commit_session",
        ] {
            #expect(names.contains(name))
        }
    }

    @Test("Total tool count reflects the current research, computer-use, and D2 graph catalog")
    func totalToolCount() {
        #expect(OmegaToolRegistry.all.count == 56)
    }

    // MARK: - No Hidden Personas

    @Test("Research planning prompt does not contain blocked persona strings")
    func noHiddenPersonas() throws {
        let content = try loadTextFile("agent_core/src/prompts.rs")
        #expect(content.contains("RESEARCH_PROMPT"))
        #expect(!content.contains("research assistant"))
        #expect(!content.contains("You are a research"))
    }

    // Omega-removal migration: "New research files do not use blocked names" removed
    // — it asserted the deleted ResearchOrchestrator / ResearchEvidenceScorer /
    // ResearchConfidenceState / ResearchComplexityGate.swift files still exist.

    // MARK: - Helpers

    private func loadTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
