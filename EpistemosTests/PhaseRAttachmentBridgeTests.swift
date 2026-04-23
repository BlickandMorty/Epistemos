import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.4 Attachment Bridge Regression Tests
//
// Covers the Swift side of the UniFFI-exposed attachment primitives
// wired up in `agent_core/src/resources/attachments.rs` (new
// `uniffi::Enum`/`uniffi::Record` derives) and the three factory
// functions added to `agent_core/src/resources/bridge.rs`:
//   - attachedResourceFromUi
//   - attachedResourceFromFinder
//   - attachedResourceFromPaste
//   - attachedResourceAllows
//
// Addresses I-004 (snapshot vs live ambiguity), I-005 (popover
// attachments don't grant live capabilities), I-006 (AI can't code/
// edit attached code files) at the FFI-surface layer. Swift-side
// integration into ChatState's attachment machinery is a follow-up.
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.4,
// docs/KNOWN_ISSUES_REGISTER.md I-004/5/6.

@Suite("Phase R.4 — Attachment Bridge")
struct PhaseRAttachmentBridgeTests {

    // MARK: - UI attachment — Live + Read/Write

    @Test("attachedResourceFromUi produces Live mode with Read+Write capabilities")
    func attachedResourceFromUiProducesLiveWithReadWrite() async throws {
        let uri = "vault://r4-ui-test/note/Inbox/Attached.md"
        let attachment = attachedResourceFromUi(
            resourceUri: uri,
            displayName: "Attached",
            version: nil
        )
        #expect(attachment != nil)
        guard let attachment else {
            Issue.record("attachment should not be nil for a valid URI")
            return
        }
        #expect(attachment.mode == .live)
        #expect(attachment.displayName == "Attached")
        #expect(attachment.grantedCapabilities.contains(.read))
        #expect(attachment.grantedCapabilities.contains(.write))
        #expect(!attachment.grantedCapabilities.contains(.delete))
    }

    // MARK: - Finder attachment — mirrors UI but distinct factory

    @Test("attachedResourceFromFinder preserves version + Live mode for code files")
    func attachedResourceFromFinderPreservesVersionAndLiveMode() async throws {
        let uri = "file:///tmp/r4-finder-example.swift"
        let attachment = attachedResourceFromFinder(
            resourceUri: uri,
            displayName: "Example.swift",
            version: "v-42-abc"
        )
        #expect(attachment != nil)
        guard let attachment else {
            Issue.record("attachment should not be nil for a valid file URI")
            return
        }
        #expect(attachment.mode == .live)
        #expect(attachment.version == "v-42-abc")
        #expect(attachedResourceAllows(attachment: attachment, capability: .write))
    }

    // MARK: - Paste attachment — Snapshot + Read-only

    @Test("attachedResourceFromPaste produces Snapshot with Read-only capability")
    func attachedResourceFromPasteProducesSnapshotReadOnly() async throws {
        let uri = "vault://r4-paste-test/note/Inbox/Pasted.md"
        let attachment = attachedResourceFromPaste(
            resourceUri: uri,
            displayName: "Pasted",
            snapshotContent: "Hello from a pasted snippet."
        )
        #expect(attachment != nil)
        guard let attachment else {
            Issue.record("attachment should not be nil")
            return
        }
        #expect(attachment.mode == .snapshot)
        #expect(attachment.snapshotContent == "Hello from a pasted snippet.")
        #expect(attachment.grantedCapabilities.contains(.read))
        #expect(!attachment.grantedCapabilities.contains(.write))
    }

    // MARK: - Capability enforcement

    @Test("attachedResourceAllows returns false for snapshot + write (the I-004/5 gate)")
    func snapshotAttachmentDeniesWriteCapability() async throws {
        let uri = "vault://r4-allows-test/note/Inbox/A.md"
        let snapshot = attachedResourceFromPaste(
            resourceUri: uri,
            displayName: "Snap",
            snapshotContent: "frozen body"
        )!
        #expect(!attachedResourceAllows(attachment: snapshot, capability: .write))
        #expect(attachedResourceAllows(attachment: snapshot, capability: .read))
    }

    @Test("attachedResourceAllows returns true for Live + Write (IDE-style)")
    func liveAttachmentAllowsWriteCapability() async throws {
        let uri = "vault://r4-allows-live-test/note/Inbox/B.md"
        let live = attachedResourceFromUi(
            resourceUri: uri,
            displayName: "Live",
            version: nil
        )!
        #expect(attachedResourceAllows(attachment: live, capability: .write))
        #expect(attachedResourceAllows(attachment: live, capability: .read))
    }

    // MARK: - FFI edge: invalid URIs

    @Test("all factory functions reject unparseable URIs and return nil")
    func factoriesRejectUnparseableURIs() async throws {
        #expect(attachedResourceFromUi(
            resourceUri: "not-a-uri",
            displayName: "x",
            version: nil
        ) == nil)
        #expect(attachedResourceFromFinder(
            resourceUri: "not-a-uri",
            displayName: "x",
            version: nil
        ) == nil)
        #expect(attachedResourceFromPaste(
            resourceUri: "not-a-uri",
            displayName: "x",
            snapshotContent: "body"
        ) == nil)
    }

    // MARK: - ResourceId enum variant round-trips

    @Test("vault-note URIs round-trip through the factory to the correct ResourceId variant")
    func vaultNoteURIRoundTripsToVaultNoteVariant() async throws {
        let uri = "vault://my-vault/note/Inbox/Test.md"
        guard let attachment = attachedResourceFromUi(
            resourceUri: uri,
            displayName: "Test",
            version: nil
        ) else {
            Issue.record("factory should yield an attachment")
            return
        }
        // ResourceId is a uniffi::Enum; pattern-match to confirm the
        // correct variant landed.
        switch attachment.resourceId {
        case .vaultNote(let vaultId, let noteId):
            #expect(vaultId == "my-vault")
            #expect(noteId == "Inbox/Test.md")
        default:
            Issue.record("expected .vaultNote variant, got \(attachment.resourceId)")
        }
    }

    @Test("file:// URIs round-trip to File variant")
    func fileURIRoundTripsToFileVariant() async throws {
        let uri = "file:///Users/jojo/projects/example/main.swift"
        guard let attachment = attachedResourceFromFinder(
            resourceUri: uri,
            displayName: "main.swift",
            version: nil
        ) else {
            Issue.record("factory should yield an attachment")
            return
        }
        switch attachment.resourceId {
        case .file(let absolutePath):
            #expect(absolutePath == "/Users/jojo/projects/example/main.swift")
        default:
            Issue.record("expected .file variant, got \(attachment.resourceId)")
        }
    }
}
