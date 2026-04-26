import Foundation
import Testing

@testable import Epistemos

/// Wave 7.15 source-guard for the bidirectional RawThought ↔ .epdoc
/// cross-reference bridge.
@Suite("ThoughtAttachmentBridge (Wave 7.15)")
nonisolated struct ThoughtAttachmentBridgeTests {

    // MARK: - Attach + lookup

    @Test("attach is bidirectional + idempotent")
    func attachIsBidirectional() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-1", runID: "run-A")
        await #expect(bridge.documents(generatedBy: "run-A") == ["doc-1"])
        await #expect(bridge.runs(thatGenerated: "doc-1") == ["run-A"])

        // Idempotent — same edge twice doesn't double-count.
        await bridge.attach(documentID: "doc-1", runID: "run-A")
        await #expect(bridge.edgeCount() == 1)
    }

    @Test("Many docs per run + many runs per doc supported (the actual realistic shape)")
    func manyToMany() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentIDs: ["doc-A", "doc-B", "doc-C"], to: "run-1")
        await bridge.attach(documentID: "doc-A", runID: "run-2")
        await bridge.attach(documentID: "doc-B", runID: "run-3")

        await #expect(Set(bridge.documents(generatedBy: "run-1")) == ["doc-A", "doc-B", "doc-C"])
        await #expect(Set(bridge.runs(thatGenerated: "doc-A")) == ["run-1", "run-2"])
        await #expect(Set(bridge.runs(thatGenerated: "doc-B")) == ["run-1", "run-3"])
        await #expect(Set(bridge.runs(thatGenerated: "doc-C")) == ["run-1"])
    }

    @Test("contains pinpoints exact (doc, run) edges")
    func containsPair() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-A", runID: "run-1")
        await #expect(bridge.contains(documentID: "doc-A", runID: "run-1"))
        await #expect(!bridge.contains(documentID: "doc-A", runID: "run-2"))
        await #expect(!bridge.contains(documentID: "doc-X", runID: "run-1"))
    }

    // MARK: - Detach

    @Test("detach removes BOTH index sides + reports presence")
    func detachSymmetric() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-1", runID: "run-A")
        await bridge.attach(documentID: "doc-1", runID: "run-B")

        let removed = await bridge.detach(documentID: "doc-1", runID: "run-A")
        #expect(removed)
        await #expect(bridge.runs(thatGenerated: "doc-1") == ["run-B"],
                      "detach MUST remove from BOTH the forward and reverse index")
        await #expect(bridge.documents(generatedBy: "run-A").isEmpty)

        // Detach a non-existent edge → false, no crash
        let again = await bridge.detach(documentID: "doc-1", runID: "run-A")
        #expect(!again)
    }

    @Test("detachAll(documentID:) drops every edge touching the doc")
    func detachAllByDoc() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentIDs: ["doc-1"], to: "run-A")
        await bridge.attach(documentIDs: ["doc-1"], to: "run-B")
        await bridge.attach(documentIDs: ["doc-2"], to: "run-A")

        let dropped = await bridge.detachAll(documentID: "doc-1")
        #expect(dropped == 2)
        await #expect(bridge.runs(thatGenerated: "doc-1").isEmpty)
        await #expect(bridge.documents(generatedBy: "run-A") == ["doc-2"])
    }

    @Test("detachAll(runID:) drops every edge touching the run")
    func detachAllByRun() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentIDs: ["doc-1", "doc-2", "doc-3"], to: "run-X")
        await bridge.attach(documentID: "doc-1", runID: "run-Y")

        let dropped = await bridge.detachAll(runID: "run-X")
        #expect(dropped == 3)
        await #expect(bridge.documents(generatedBy: "run-X").isEmpty)
        await #expect(bridge.runs(thatGenerated: "doc-1") == ["run-Y"])
    }

    // MARK: - Snapshot serialization round-trip

    @Test("snapshot + restore round-trip preserves every edge")
    func snapshotRoundTrip() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-A", runID: "run-1")
        await bridge.attach(documentID: "doc-A", runID: "run-2")
        await bridge.attach(documentID: "doc-B", runID: "run-1")

        let snap = await bridge.snapshot()
        #expect(snap.edges.count == 3)

        // Snapshot edges MUST be sorted (so the JSON file is diff-friendly + reproducible)
        let sortedEdges = snap.edges.sorted()
        #expect(snap.edges == sortedEdges)

        // Restore into a fresh bridge → equivalent index
        let other = ThoughtAttachmentBridge()
        await other.restore(snap)
        await #expect(Set(other.runs(thatGenerated: "doc-A")) == ["run-1", "run-2"])
        await #expect(Set(other.documents(generatedBy: "run-1")) == ["doc-A", "doc-B"])
    }

    @Test("saveTo + loadFrom round-trip via temp file (atomic write)")
    func saveLoadRoundTrip() async throws {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-A", runID: "run-1")
        await bridge.attach(documentID: "doc-B", runID: "run-2")

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thought-bridge-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        try await bridge.saveTo(url: tmpURL)
        #expect(FileManager.default.fileExists(atPath: tmpURL.path))

        let other = ThoughtAttachmentBridge()
        try await other.loadFrom(url: tmpURL)
        await #expect(Set(other.runs(thatGenerated: "doc-A")) == ["run-1"])
        await #expect(Set(other.documents(generatedBy: "run-2")) == ["doc-B"])
    }

    @Test("loadFrom skips silently when the file doesn't exist (first-launch case)")
    func loadFromMissingFile() async throws {
        let bridge = ThoughtAttachmentBridge()
        let nonexistent = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).json")
        // MUST NOT throw — first launch is the canonical case
        try await bridge.loadFrom(url: nonexistent)
        await #expect(bridge.edgeCount() == 0)
    }

    // MARK: - Pruning dangling references

    @Test("prune(againstDocumentIDs:) drops edges whose doc id is no longer live")
    func pruneDanglingDocs() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-live", runID: "run-1")
        await bridge.attach(documentID: "doc-deleted", runID: "run-1")
        await bridge.attach(documentID: "doc-deleted", runID: "run-2")

        let removed = await bridge.prune(againstDocumentIDs: ["doc-live"])
        #expect(removed == 2,
                "two edges touched the deleted doc; prune MUST drop both")
        await #expect(bridge.runs(thatGenerated: "doc-deleted").isEmpty)
        await #expect(bridge.runs(thatGenerated: "doc-live") == ["run-1"])
    }

    @Test("prune(againstRunIDs:) drops edges whose run id is no longer live")
    func pruneDanglingRuns() async {
        let bridge = ThoughtAttachmentBridge()
        await bridge.attach(documentID: "doc-1", runID: "run-live")
        await bridge.attach(documentID: "doc-1", runID: "run-deleted")

        let removed = await bridge.prune(againstRunIDs: ["run-live"])
        #expect(removed == 1)
        await #expect(bridge.runs(thatGenerated: "doc-1") == ["run-live"])
    }
}
