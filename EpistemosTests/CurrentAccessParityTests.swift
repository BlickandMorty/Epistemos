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

    @Test("no active vault surfaces an honest connect-a-vault grant row")
    func noActiveVaultSurfacesHonestRow() {
        let withoutVault = ComposerCurrentAccessPlan(
            vaultURL: nil,
            contextAttachments: [],
            fileAttachments: []
        )
        let noVaultRow = withoutVault.rows.first { $0.id == "vault:none" }
        #expect(noVaultRow?.title == "No active vault")
        #expect(noVaultRow?.detail == "Connect a vault to enable Read + Search + Halo recall")
        #expect(noVaultRow?.isRevocable == false)

        // When a vault IS active, there is NO synthetic no-vault row — the real vault grant is shown instead.
        let vaultURL = URL(fileURLWithPath: "/tmp/epistemos-current-access-vault")
        let withVault = ComposerCurrentAccessPlan(
            vaultURL: vaultURL,
            contextAttachments: [],
            fileAttachments: []
        )
        #expect(!withVault.rows.contains { $0.id == "vault:none" })
        #expect(withVault.rows.first?.detail == "Read + Search active vault")
    }

    @Test("settings grant surface is labeled as resource grants")
    func settingsGrantSurfaceUsesScopedLabel() throws {
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        #expect(settingsSource.contains("Text(\"Stored Resource Grants\")"))
        #expect(!settingsSource.contains("Text(\"Active Grants\")"))
    }

    @Test("resource grant model and settings do not list shell approval as an active grant")
    func resourceGrantModelAndSettingsExcludeShellApprovalRows() throws {
        let currentAccessPlan = try loadMirroredSourceTextFile("Epistemos/Views/Chat/ComposerCurrentAccessPlan.swift")
        let settingsSource = try loadMirroredSourceTextFile("Epistemos/Views/Settings/AgentControlSettingsView.swift")

        for source in [currentAccessPlan, settingsSource] {
            #expect(!source.contains("Shell / external tools"))
            #expect(!source.contains("shell-approval"))
        }
    }
}
