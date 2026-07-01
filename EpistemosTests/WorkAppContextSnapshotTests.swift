import Foundation
import Testing
@testable import Epistemos

@Suite("Work app context snapshot")
struct WorkAppContextSnapshotTests {
    private func tmp() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("work-context-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeManagedSkill(workspace: URL, name: String) {
        let skill = WorkSkillsProvisioner.skillsDestination(workspace: workspace)
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try? "skill".write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    @Test("current snapshot reports workspace vault native tool status and managed skills")
    func currentSnapshot() {
        let workspace = tmp(); defer { try? FileManager.default.removeItem(at: workspace) }
        let vault = tmp(); defer { try? FileManager.default.removeItem(at: vault) }
        makeManagedSkill(workspace: workspace, name: "alpha")
        makeManagedSkill(workspace: workspace, name: "beta")

        let snapshot = WorkAppContextSnapshot.current(
            workspace: workspace,
            vaultRoot: vault,
            nativeToolsAvailable: true,
            selectedEngine: "opencode",
            selectedModelID: "provider/model",
            selectedAgent: "build",
            activeWorkSessionID: "opencode:ses_1",
            queuedPromptCount: 2)

        #expect(snapshot.workspacePath == workspace.standardizedFileURL.path)
        #expect(snapshot.vaultPath == vault.standardizedFileURL.path)
        #expect(snapshot.managedSkillsCount == 2)
        #expect(snapshot.nativeToolsAvailable)
        #expect(snapshot.appMode == "work")
        #expect(snapshot.selectedEngine == "opencode")
        #expect(snapshot.selectedModelID == "provider/model")
        #expect(snapshot.selectedAgent == "build")
        #expect(snapshot.activeWorkSessionID == "opencode:ses_1")
        #expect(snapshot.queuedPromptCount == 2)
    }

    @Test("rows are compact stable labels for the existing native Work panel")
    func rows() {
        let snapshot = WorkAppContextSnapshot(
            workspacePath: "/Users/example/Projects/VeryLongProjectNameThatNeedsToBeShortenedForThePanel",
            vaultPath: "/Users/example/EpistemosVault",
            managedSkillsCount: 4,
            nativeToolsAvailable: false,
            appMode: "work",
            selectedEngine: "opencode",
            selectedModelID: "huggingface/Qwen",
            selectedAgent: "build",
            activeWorkSessionID: "opencode:ses_abc",
            queuedPromptCount: 3,
            activeNoteTitle: "Current note",
            graphFocusSummary: String(repeating: "graph ", count: 40))

        let rows = snapshot.rows(pathLimit: 36, textLimit: 42)
        #expect(rows.map(\.id).contains("workspace"))
        #expect(rows.map(\.id).contains("vault"))
        #expect(rows.map(\.id).contains("engine"))
        #expect(rows.map(\.id).contains("model"))
        #expect(rows.map(\.id).contains("agent"))
        #expect(rows.map(\.id).contains("session"))
        #expect(rows.map(\.id).contains("native-tools"))
        #expect(rows.first { $0.id == "native-tools" }?.value == "not registered")
        #expect(rows.first { $0.id == "skills" }?.value == "4")
        #expect(rows.first { $0.id == "queue" }?.value == "3")
        let workspaceRow = rows.first { $0.id == "workspace" }?.value
        #expect(workspaceRow?.contains("...") == true)
        #expect(workspaceRow?.hasSuffix("Panel") == true)
        #expect((workspaceRow?.count ?? 0) <= 36)
        #expect(rows.first { $0.id == "graph" }?.value.hasSuffix("...") == true)
    }

    @Test("snapshot serializes for the native MCP context tool")
    func jsonStringAndStore() {
        let snapshot = WorkAppContextSnapshot(
            workspacePath: "/work",
            vaultPath: "/vault",
            managedSkillsCount: 1,
            nativeToolsAvailable: true,
            selectedEngine: "opencode",
            activeWorkSessionID: "opencode:ses_1")
        let json = snapshot.jsonString()
        #expect(json.contains(#""workspacePath":"\/work""#) || json.contains(#""workspacePath":"/work""#))
        #expect(json.contains(#""managedSkillsCount":1"#))
        #expect(json.contains(#""selectedEngine":"opencode""#))
        #expect(json.contains(#""activeWorkSessionID":"opencode:ses_1""#))

        let store = WorkAppContextStore()
        #expect(store.snapshot == nil)
        store.snapshot = snapshot
        #expect(store.snapshot == snapshot)
    }

    @Test("future context fields are bounded before they reach the MCP snapshot JSON")
    func futureContextFieldsAreBounded() {
        let snapshot = WorkAppContextSnapshot(
            graphFocusSummary: String(repeating: "g", count: 800),
            currentSelectionPreview: String(repeating: "s", count: 800))

        #expect(snapshot.graphFocusSummary?.count == 600)
        #expect(snapshot.graphFocusSummary?.hasSuffix("...") == true)
        #expect(snapshot.currentSelectionPreview?.count == 600)
        #expect(snapshot.currentSelectionPreview?.hasSuffix("...") == true)
        #expect(snapshot.jsonString().count < 1400)
    }

    @Test("context seam stays Work-owned and does not import deleted graph chat note UI state")
    func sourceStaysPlainWorkModel() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Work/WorkAppContextSnapshot.swift")
        #expect(source.contains("struct WorkAppContextSnapshot"))
        #expect(source.contains("Codable"))
        #expect(source.contains("String((value ?? \"\").prefix(limit + 32))"))
        #expect(source.contains("String(trimmed.prefix(limit - 3)) + \"...\""))
        #expect(source.contains("String(value.prefix(limit + 32))"))
        #expect(source.contains("String(bounded.prefix(limit - 3)) + \"...\""))
        #expect(!source.contains("ChatState"))
        #expect(!source.contains("GraphState"))
        #expect(!source.contains("NoteChat"))
        #expect(!source.contains("MiniChat"))
        #expect(!source.contains("AppBootstrap.shared"))
    }
}
