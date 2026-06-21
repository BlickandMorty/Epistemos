import Testing
import Foundation

@testable import Epistemos

// SS-CLEAN regression guard (2026-06-21). An SS-VIS-sweep slice once added a second agent tool panel to
// the mini-chat HEADER when its COMPOSER (MiniChatInputBar.toolPanelButton) already had the canonical
// one with skill-run — two "Agent tools" buttons in one window (commit 3475ea82e removed the duplicate).
// This pins the fix: mini-chat must mount exactly ONE AgentToolTogglePanel, so a future change can't
// silently re-introduce the duplicate. Counting the mount is deterministic + robust to wording changes.
@Suite("SS-CLEAN — mini-chat has exactly one agent tool panel (no header duplicate)")
struct SSCleanMiniChatDedupGuardTests {

    @Test("MiniChatView mounts exactly one AgentToolTogglePanel — the composer's, no header duplicate")
    func miniChatHasSingleToolPanel() throws {
        let mini = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        let mounts = mini.components(separatedBy: "AgentToolTogglePanel(").count - 1
        #expect(
            mounts == 1,
            "mini-chat should mount exactly one tool panel (the composer's canonical one with skill-run); found \(mounts)"
        )
    }

    @Test("the canonical mini-chat panel keeps its skill-run wiring (runSkillFromPanel)")
    func miniChatComposerPanelRunsSkills() throws {
        let mini = try loadMirroredSourceTextFile("Epistemos/Views/MiniChat/MiniChatView.swift")
        #expect(mini.contains("runSkillFromPanel"))
    }
}
