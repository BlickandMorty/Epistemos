import Foundation
import Testing

@Suite("Plan 3 Apple-native codepack")
struct AppleNativeCodepackPlan3Tests {
    @Test("codepack keeps Apple-native work in Plan 3 shared views")
    func codepackKeepsSharedViewScope() throws {
        let codepack = try loadMirroredSourceTextFile(
            "docs/research/PLAN_3_APPLE_NATIVE_CODEPACK_2026_06_28.md"
        )

        for required in [
            "Plan 3 builds shared components only",
            "Plan 2 owns editor/sidebar/pdf viewer integration",
            "Epistemos/Views/Shared/FilePreview.swift",
            "Epistemos/Views/Shared/LiveTextImageView.swift",
            "Epistemos/Views/Shared/FileThumbnail.swift",
            "FilePreviewController",
            "LiveTextImageView",
            "FileThumbnailView",
            "Consumer Handoff"
        ] {
            #expect(codepack.contains(required), "Missing Apple-native codepack string: \(required)")
        }
    }

    @Test("codepack forbids Plan 1 and Plan 2 implementation drift")
    func codepackForbidsCrossPlanImplementationDrift() throws {
        let codepack = try loadMirroredSourceTextFile(
            "docs/research/PLAN_3_APPLE_NATIVE_CODEPACK_2026_06_28.md"
        )

        for requiredBoundary in [
            "Do not edit NotesSidebar",
            "Do not edit ProseInlineImage",
            "Do not edit HTMLWorkspace",
            "Do not build PDFView",
            "Do not add Python, subprocess, Chromium, or browser-use runtime dependencies to the MAS path",
            "Do not touch `Epistemos/Goose/*` or `Epistemos/Agent/*`"
        ] {
            #expect(codepack.contains(requiredBoundary), "Missing Apple-native boundary: \(requiredBoundary)")
        }

        for staleInstruction in [
            "Wiring (real edits)",
            "Verified surfaces to wire into",
            "NotesSidebar.swift",
            "DocumentRow.contextMenu",
            "HTMLWorkspaceRow",
            "ProseInlineImageSupport.swift",
            "ProseInlineImageLayout.swift",
            "SearchIndexService.swift",
            "1-3-line edits",
            "1–3-line edits",
            "GooseSurfaceWindowController",
            "WorkWebSurfaceWindowController"
        ] {
            #expect(!codepack.contains(staleInstruction), "Apple-native codepack kept stale cross-plan instruction: \(staleInstruction)")
        }
    }
}
