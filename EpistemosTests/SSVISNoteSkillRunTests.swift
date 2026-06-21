import Testing
import Foundation

@testable import Epistemos

// SS-VIS skill-run parity (owner 2026-06-20): the note chat is the last of the five chat surfaces to
// gain skill-run. NoteDetailWorkspaceView mounts the shared AgentToolTogglePanel (d08e15d7a); this
// wires its onRunSkill so a discovered skill runs from the note chat too — primed into the note ask
// field (noteChatState.inputText) with its `/identifier` invocation, parity with landing (7101b307c) /
// graph (0dcc19047) / chat / mini-chat. Pinned against a regression to browse-only.
@Suite("SS-VIS — run a skill from the note chat")
struct SSVISNoteSkillRunTests {

    @Test("the note chat panel passes a real onRunSkill handler (not the nil browse-only default)")
    func notePanelGetsSkillHandler() throws {
        let note = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(note.contains("onRunSkill:"))
        #expect(note.contains("func runSkillFromNoteChat"))
    }

    @Test("the handler primes the note ask field with the skill invocation, then closes the panel")
    func handlerPrimesNoteChatInput() throws {
        let note = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(note.contains("noteChatState.inputText = invocation"))
        #expect(note.contains("showNoteToolPanel = false"))
    }
}
