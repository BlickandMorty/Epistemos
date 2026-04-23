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

    // MARK: - Phase R.4 ContextAttachment converter

    @Test("legacy ContextAttachment (no resource metadata) has no manifest and no AttachedResource")
    func legacyContextAttachmentHasNoManifest() async throws {
        let legacy = ContextAttachment(
            kind: .note,
            targetId: "page-legacy",
            title: "Legacy Note"
        )
        #expect(!legacy.hasResourceManifest)
        #expect(legacy.toAttachedResource() == nil)
    }

    @Test("ContextAttachment with Live manifest converts to a Live AttachedResource")
    func contextAttachmentLiveManifestConverts() async throws {
        let uri = "vault://r4-ctx-live/note/Inbox/Live.md"
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "page-live",
            title: "Live Note",
            subtitle: nil,
            resourceURI: uri,
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )
        #expect(attachment.hasResourceManifest)
        guard let resource = attachment.toAttachedResource() else {
            Issue.record("live manifest should produce an AttachedResource")
            return
        }
        #expect(resource.mode == .live)
        #expect(attachedResourceAllows(attachment: resource, capability: .write))
    }

    @Test("ContextAttachment with Snapshot manifest converts to a Snapshot AttachedResource")
    func contextAttachmentSnapshotManifestConverts() async throws {
        let uri = "vault://r4-ctx-snap/note/Inbox/Snap.md"
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "page-snap",
            title: "Snapshot Note",
            subtitle: "inline snapshot body",
            resourceURI: uri,
            resourceMode: .snapshot,
            resourceCapabilities: ["Read"]
        )
        #expect(attachment.hasResourceManifest)
        guard let resource = attachment.toAttachedResource() else {
            Issue.record("snapshot manifest should produce an AttachedResource")
            return
        }
        #expect(resource.mode == .snapshot)
        #expect(resource.snapshotContent == "inline snapshot body")
        #expect(!attachedResourceAllows(attachment: resource, capability: .write))
    }

    @Test("ContextAttachment with partially-populated manifest is treated as legacy")
    func partialManifestFallsBackToLegacy() async throws {
        // URI without mode → insufficient; treat as legacy.
        let onlyURI = ContextAttachment(
            kind: .note,
            targetId: "page-partial-1",
            title: "Partial",
            resourceURI: "vault://partial/note/Inbox/P.md"
        )
        #expect(!onlyURI.hasResourceManifest)
        #expect(onlyURI.toAttachedResource() == nil)

        // Mode without URI → insufficient; treat as legacy.
        let onlyMode = ContextAttachment(
            kind: .note,
            targetId: "page-partial-2",
            title: "Partial Mode",
            resourceMode: .live
        )
        #expect(!onlyMode.hasResourceManifest)
        #expect(onlyMode.toAttachedResource() == nil)
    }

    @Test("ContextAttachment round-trips through JSONEncoder/Decoder preserving manifest")
    func contextAttachmentCodableRoundTrip() async throws {
        let original = ContextAttachment(
            kind: .note,
            targetId: "page-codable",
            title: "Codable",
            subtitle: nil,
            resourceURI: "vault://r4-codable/note/Inbox/C.md",
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ContextAttachment.self, from: encoded)
        #expect(decoded == original)
        #expect(decoded.resourceURI == original.resourceURI)
        #expect(decoded.resourceMode == .live)
        #expect(decoded.resourceCapabilities == ["Read", "Write"])
    }

    @Test("Legacy-shaped JSON (no resource fields) still decodes without the new keys")
    func legacyJSONDecodesWithoutResourceFields() async throws {
        let legacyJSON = #"""
        {"kind":"note","targetId":"old","title":"Old Note"}
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ContextAttachment.self, from: legacyJSON)
        #expect(decoded.kind == .note)
        #expect(decoded.targetId == "old")
        #expect(decoded.title == "Old Note")
        #expect(decoded.resourceURI == nil)
        #expect(decoded.resourceMode == nil)
        #expect(decoded.resourceCapabilities == nil)
        #expect(!decoded.hasResourceManifest)
    }
}
