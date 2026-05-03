import Testing
@testable import Epistemos

@Suite("Knowledge Fusion Adapter Deletion Sovereign Gate")
struct KnowledgeFusionAdapterDeletionSovereignGateTests {
    @Test("Adapter deletes require device owner authentication")
    func adapterDeletesRequireDeviceOwnerAuthentication() {
        #expect(
            KnowledgeFusionAdapterDeletionSovereignGate.requirement(for: .adapter(name: "Scope Rex"))
                == .deviceOwnerAuthentication
        )
    }

    @Test("Adapter delete reasons name the adapter and destructive action")
    func adapterDeleteReasonsNameAdapterAndDestructiveAction() {
        let reason = KnowledgeFusionAdapterDeletionSovereignGate.reason(for: .adapter(name: "Scope Rex"))
        let fallbackReason = KnowledgeFusionAdapterDeletionSovereignGate.reason(for: .adapter(name: "   "))

        #expect(reason.contains("Scope Rex"))
        #expect(reason.localizedCaseInsensitiveContains("permanently delete"))
        #expect(fallbackReason.contains("Untitled"))
    }

    @Test("Training history delete button routes through Sovereign Gate before deleting")
    func trainingHistoryDeleteButtonRoutesThroughSovereignGateBeforeDeleting() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let contextMenu = try section(
            from: ".contextMenu {",
            to: "    @MainActor"
        )
        #expect(contextMenu.contains("Button(\"Delete\", role: .destructive)"))
        #expect(contextMenu.contains("requestAdapterDeleteAuthorization(adapter)"))
        #expect(!contextMenu.contains("await vm.deleteAdapter(adapter)"))
        #expect(!source.contains("Button(\"Delete\", role: .destructive) { Task { await vm.deleteAdapter(adapter) } }"))

        let request = try section(
            from: "private func requestAdapterDeleteAuthorization(_ adapter: AdapterRecord) async",
            to: "    @ViewBuilder"
        )
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("KnowledgeFusionAdapterDeletionSovereignGate.requirement(for: target)"))
        #expect(request.contains("KnowledgeFusionAdapterDeletionSovereignGate.reason(for: target)"))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("await vm.deleteAdapter(adapter)"))

        let confirm = try #require(request.range(of: "AppBootstrap.shared?.sovereignGate.confirm("))
        let allowed = try #require(request.range(of: "guard outcome == .allowed else { return }"))
        let delete = try #require(request.range(of: "await vm.deleteAdapter(adapter)"))
        #expect(confirm.lowerBound < allowed.lowerBound)
        #expect(allowed.lowerBound < delete.lowerBound)
    }

    @Test("Knowledge Fusion adapter delete does not own LocalAuthentication")
    func knowledgeFusionAdapterDeleteDoesNotOwnLocalAuthentication() throws {
        for path in [
            "Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift",
            "Epistemos/KnowledgeFusion/UI/KnowledgeFusionAdapterDeletionSovereignGate.swift",
        ] {
            let source = try loadMirroredSourceTextFile(path)
            #expect(!source.contains("import LocalAuthentication"), "\(path) must route through Sovereign Gate")
            #expect(!source.contains("LAContext"), "\(path) must route through Sovereign Gate")
            #expect(!source.contains("canEvaluatePolicy"), "\(path) must route through Sovereign Gate")
            #expect(!source.contains("evaluatePolicy"), "\(path) must route through Sovereign Gate")
        }
    }
}
