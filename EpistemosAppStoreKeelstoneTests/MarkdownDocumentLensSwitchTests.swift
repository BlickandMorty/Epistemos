import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX
#error("KEELSTONE App Store lens-switch tests must compile with EPISTEMOS_APP_STORE and MAS_SANDBOX.")
#endif

private actor MarkdownDocumentWriteGate {
    private var didStart = false
    private var didRelease = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func markStarted() {
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitUntilStarted() async {
        guard !didStart else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func waitUntilReleased() async {
        guard !didRelease else { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func release() {
        didRelease = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

@Suite("KEELSTONE Markdown Document Lens Switching", .serialized)
@MainActor
struct MarkdownDocumentLensSwitchTests {
    @Test("stale Document teardown cannot unregister a replacement surface")
    func staleDocumentTeardownCannotUnregisterReplacementSurface() async {
        let registry = MarkdownDocumentSurfaceSaveRegistry.shared
        let pageID = "appstore-document-registry-\(UUID().uuidString)"
        let staleToken = UUID()
        let replacementToken = UUID()
        var flushedOwner = ""

        registry.register(pageId: pageID, token: staleToken) {
            flushedOwner = "stale"
            return true
        }
        registry.register(pageId: pageID, token: replacementToken) {
            flushedOwner = "replacement"
            return true
        }
        registry.unregister(pageId: pageID, token: staleToken)

        let flushed = await registry.flush(pageId: pageID)
        registry.unregister(pageId: pageID, token: replacementToken)

        #expect(flushed == true)
        #expect(flushedOwner == "replacement")
    }

    @Test("reactivated Document coordinator survives its delayed stale teardown")
    func reactivatedDocumentCoordinatorSurvivesDelayedTeardown() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let pageID = "appstore-document-reactivation-\(UUID().uuidString)"

        coordinator.beginSurfaceAppearance()
        coordinator.configure(
            pageId: pageID,
            title: "Reactivated Document",
            markdown: "# Reactivated\n",
            theme: .light,
            noteRelativePath: "notes/reactivated-document.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        guard let staleRegistration = coordinator.currentSurfaceRegistration() else {
            Issue.record("Expected the first Document registration")
            return
        }

        coordinator.beginSurfaceAppearance()
        coordinator.configure(
            pageId: pageID,
            title: "Reactivated Document",
            markdown: "# Reactivated\n",
            theme: .light,
            noteRelativePath: "notes/reactivated-document.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { _ in true }
        )
        guard let activeRegistration = coordinator.currentSurfaceRegistration() else {
            Issue.record("Expected the reactivated Document registration")
            return
        }

        coordinator.unregisterSurface(staleRegistration)
        let flushed = await MarkdownDocumentSurfaceSaveRegistry.shared.flush(pageId: pageID)
        coordinator.unregisterSurface(activeRegistration)

        #expect(staleRegistration != activeRegistration)
        #expect(flushed == true)
    }

    @Test("App Store early Document edit survives lens switch before load-settled echo")
    func earlyDocumentEditSurvivesLensSwitchBeforeLoadSettledEcho() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let initialMarkdown = "# Initial\n"
        let editedMarkdown = "# Initial\n\nTyped before switching lenses.\n"
        let editedJSON = Data(
            #"{"type":"doc","content":[{"type":"heading","attrs":{"level":1},"content":[{"type":"text","text":"Initial"}]},{"type":"paragraph","content":[{"type":"text","text":"Typed before switching lenses."}]}]}"#.utf8
        )
        var snapshotRequests = 0
        var editStarts = 0
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-early-document-edit",
            title: "Initial",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/appstore-early-document-edit.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            onEditStarted: {
                editStarts += 1
            },
            saveMarkdown: {
                savedMarkdown.append($0)
                return true
            }
        )
        coordinator.controller.installEditorDispatch { _ in }
        coordinator.controller.installMarkdownSnapshotProvider {
            snapshotRequests += 1
            return editedMarkdown
        }
        coordinator.controller.handleBridgeMessage(.editorReady)

        // The user can type after WebKit has ended its local load transaction
        // but before the coalesced load-settled message reaches Swift.
        coordinator.controller.handleBridgeMessage(
            .contentDidChange(json: editedJSON),
            epoch: 1
        )

        let flushed = await coordinator.flushPendingMarkdown()

        #expect(flushed)
        #expect(editStarts == 1)
        #expect(snapshotRequests == 1)
        #expect(savedMarkdown == [editedMarkdown])
    }

    @Test("concurrent Document flushes preserve edit order and newest dirty state")
    func concurrentDocumentFlushesPreserveNewestEdit() async {
        let coordinator = MarkdownDocumentSurfaceCoordinator()
        let gate = MarkdownDocumentWriteGate()
        let initialMarkdown = "# Initial\n"
        let firstMarkdown = "# Initial\n\nFirst edit.\n"
        let secondMarkdown = "# Initial\n\nSecond edit wins.\n"
        var savedMarkdown: [String] = []

        coordinator.configure(
            pageId: "appstore-document-write-order",
            title: "Write Order",
            markdown: initialMarkdown,
            theme: .light,
            noteRelativePath: "notes/write-order.md",
            isEditable: true,
            isActive: true,
            provenanceStore: nil,
            saveMarkdown: { markdown in
                savedMarkdown.append(markdown)
                if markdown == firstMarkdown {
                    await gate.markStarted()
                    await gate.waitUntilReleased()
                }
                return true
            }
        )

        coordinator.controller.onMarkdownChanged(firstMarkdown, nil)
        let firstFlush = Task { @MainActor in
            await coordinator.flushPendingMarkdown()
        }
        await gate.waitUntilStarted()

        coordinator.controller.onMarkdownChanged(secondMarkdown, nil)
        let joinedFlush = Task { @MainActor in
            await coordinator.flushPendingMarkdown()
        }
        await gate.release()

        #expect(await firstFlush.value)
        #expect(await joinedFlush.value)
        #expect(savedMarkdown == [firstMarkdown, secondMarkdown])
        #expect(coordinator.controller.toolbarModel.isDirty == false)
    }
}
