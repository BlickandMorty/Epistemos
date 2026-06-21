import Testing
import Foundation

@testable import Epistemos

// SS-VIS (owner 2026-06-20: capabilities on every chat surface). The graph-tunnel chat mounts the
// shared AgentToolTogglePanel (558bea540); this wires its onRunSkill so a discovered skill runs from
// the graph chat too — primed into the "Ask this node" field with its `/identifier` invocation, parity
// with landing (7101b307c) / chat / mini-chat. These pin the wiring against a regression to browse-only.
@Suite("SS-VIS — run a skill from the graph chat")
struct SSVISGraphSkillRunTests {

    @Test("the graph chat panel passes a real onRunSkill handler (not the nil browse-only default)")
    func graphPanelGetsSkillHandler() throws {
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(graph.contains("onRunSkill:"))
        #expect(graph.contains("func runSkillFromGraphChat"))
    }

    @Test("the handler primes the graph chat input with the skill invocation, then closes the panel")
    func handlerPrimesGraphChatInput() throws {
        let graph = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramSearchSidebar.swift")
        #expect(graph.contains("inspectorState.chatInput = invocation"))
        #expect(graph.contains("showGraphToolPanel = false"))
    }
}
