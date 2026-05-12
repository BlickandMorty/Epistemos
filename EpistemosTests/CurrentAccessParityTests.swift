import Foundation
import Testing
@testable import Epistemos

@Suite("Current Access parity")
struct CurrentAccessParityTests {
    @Test("attached live file write scope is exact")
    func attachedFileAllowsOnlyThatFile() {
        let fileA = "file:///tmp/epistemos-current-access-a.txt"
        let fileB = "file:///tmp/epistemos-current-access-b.txt"
        let attachment = ContextAttachment(
            kind: .file,
            targetId: "file-a",
            title: "A.txt",
            resourceURI: fileA,
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )

        let plan = ComposerCurrentAccessPlan(
            vaultURL: nil,
            contextAttachments: [attachment],
            fileAttachments: []
        )

        #expect(plan.canWriteResource(fileA))
        #expect(!plan.canWriteResource(fileB))
        #expect(plan.rows.first?.detail == "Read + Edit attached file")
    }

    @Test("snapshot attachments are read-only in the visible plan")
    func snapshotAttachmentCannotBeMutated() {
        let resourceURI = "vault://current-access-snapshot/note/Inbox/Snapshot.md"
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "snapshot-note",
            title: "Snapshot",
            subtitle: "Frozen text",
            resourceURI: resourceURI,
            resourceMode: .snapshot,
            resourceCapabilities: ["Read"]
        )

        let plan = ComposerCurrentAccessPlan(
            vaultURL: nil,
            contextAttachments: [attachment],
            fileAttachments: []
        )

        #expect(!plan.canWriteResource(resourceURI))
        #expect(plan.rows.first?.detail == "Read attached note snapshot")
        #expect(!plan.summaryText.contains("Edit"))
    }

    @Test("tool summary is sourced from compiled allowed provider tools")
    func chipMatchesCompiledAllowedToolNames() {
        let plan = ComposerCurrentAccessPlan(
            vaultURL: nil,
            contextAttachments: [],
            fileAttachments: [],
            compiledAllowedToolNames: ["web.search"]
        )

        #expect(plan.allowedToolNames == Set(["web.search"]))
        #expect(plan.summaryText == "Web search")
    }

    @Test("composer and settings grant surfaces are labeled as resource grants")
    func resourceGrantSurfacesUseScopedLabel() throws {
        let composerSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        #expect(composerSource.contains("Text(\"Stored Resource Grants\")"))
        #expect(settingsSource.contains("Text(\"Stored Resource Grants\")"))
        #expect(!composerSource.contains("Text(\"Current Access\")"))
        #expect(!settingsSource.contains("Text(\"Active Grants\")"))
    }

    @Test("resource grant surfaces do not list shell approval as an active grant")
    func resourceGrantSurfacesExcludeShellApprovalRows() throws {
        let composerSource = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ChatInputBar.swift")
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        for source in [composerSource, settingsSource] {
            #expect(!source.contains("Shell / external tools"))
            #expect(!source.contains("shell-approval"))
        }
    }
}
