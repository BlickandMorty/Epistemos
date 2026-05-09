import Testing
@testable import Epistemos

@MainActor
@Suite("Omega retired orchestrator gate")
struct OmegaRetiredOrchestratorTests {
    @Test("retired orchestrator submitTask fails closed instead of silently accepting work")
    func retiredOrchestratorSubmitTaskFailsClosed() async {
        let orchestrator = OrchestratorState()

        await orchestrator.submitTask("  inspect files  ")

        let message = "Omega task execution is retired; use unified chat."
        #expect(orchestrator.currentTaskDescription == "inspect files")
        #expect(!orchestrator.isExecuting)
        #expect(!orchestrator.isPlanning)
        #expect(!orchestrator.isModelLoading)
        #expect(orchestrator.planningError == message)
        #expect(orchestrator.executionLog.count == 1)
        #expect(orchestrator.executionLog.first?.success == false)
        #expect(orchestrator.executionLog.first?.error == message)
    }

    @Test("retired orchestrator source labels compatibility state honestly")
    func retiredOrchestratorSourceUsesCompatibilityNaming() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Omega/Orchestrator/OrchestratorState.swift")

        #expect(source.contains("retired compatibility shim"))
        #expect(source.contains("Retired Omega Compatibility State"))
        #expect(source.contains("retiredExecutionMessage"))
        #expect(source.contains(".fail(Self.retiredExecutionMessage"))
        #expect(!source.localizedCaseInsensitiveContains("stub"))
        #expect(!source.localizedCaseInsensitiveContains("no-op"))
    }

    @Test("retired Omega companion views stay empty and unmounted")
    func retiredOmegaCompanionViewsStayUnmounted() throws {
        let retiredViewPaths = [
            "Epistemos/Views/Omega/ExecutionProgressView.swift",
            "Epistemos/Views/Omega/ConfirmationSheet.swift",
            "Epistemos/Views/Omega/ResearchRequestView.swift",
            "Epistemos/Views/Omega/TaskInputBar.swift",
        ]

        for path in retiredViewPaths {
            let source = try loadMirroredSourceTextFile(path)
            #expect(source.contains("Retired compatibility view"), "\(path) must identify retired compatibility status")
            #expect(source.contains("EmptyView()"), "\(path) must not render dead Omega UI")
            #expect(!source.localizedCaseInsensitiveContains("stub"), "\(path) must not use stale stub labels")
        }

        let inputBar = try loadMirroredSourceTextFile("Epistemos/Views/Omega/TaskInputBar.swift")
        #expect(!inputBar.contains("TextField("))
        #expect(!inputBar.contains("Button("))
        #expect(!inputBar.contains("Enter a task"))

        let sourceRoot = try sourceMirrorURL(for: "Epistemos")
        let sourceFiles = try Self.swiftSourceFiles(under: sourceRoot)
        let retiredViewNames = [
            "ExecutionProgressView",
            "ConfirmationSheet",
            "ResearchRequestView",
            "TaskInputBar",
        ]

        let mounts = try sourceFiles.flatMap { fileURL -> [String] in
            let relativePath = fileURL.path
                .replacingOccurrences(of: sourceRoot.path + "/", with: "Epistemos/")
            if retiredViewPaths.contains(relativePath) {
                return []
            }

            let source = try String(contentsOf: fileURL, encoding: .utf8)
            return retiredViewNames.compactMap { viewName in
                source.contains("\(viewName)(") ? "\(relativePath):\(viewName)" : nil
            }
        }

        #expect(mounts.isEmpty,
                "Retired Omega companion views must stay unmounted; mounts: \(mounts.sorted())")
    }

    private static func swiftSourceFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(fileURL)
            }
        }
        return files
    }
}
