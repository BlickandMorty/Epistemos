import Foundation
import Testing

@testable import Epistemos

@Suite("HTML Workspace full-surface regenerate synthesis")
nonisolated struct HTMLWorkspaceRegeneratePatchSynthesizerTests {
    @Test("streamed Goose fenced blocks synthesize and apply a regenerate replacement")
    func streamedGooseFencedBlocksSynthesizeAndApplyRegenerateReplacement() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        Rebuilt the workspace as requested.

        ```html
        <main id="regenerate-proof"><h1>Regenerate Proof</h1></main>
        ```

        ```css
        #regenerate-proof { display: grid; gap: 12px; }
        ```

        ```javascript
        document.body.dataset.regenerated = 'true';
        ```

        ```json
        {"regenerated":true,"count":45}
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: streamedResponse,
            package: package,
            expectedContentHash: expectedHash
        )
        let parsed = try HTMLWorkspacePatchCommandParser.parse(patchResponse)

        let batch = try #require(parsed.batches.first)
        #expect(batch.workspaceID == package.manifest.id)
        #expect(batch.expectedContentHash == expectedHash)

        let operation = try #require(batch.operations.first)
        let replacement = try extractReplacement(from: operation)
        #expect(replacement.provenanceOperation == .regenerate)
        #expect(replacement.html.contains("Regenerate Proof"))
        #expect(replacement.css.contains("display: grid"))
        #expect(replacement.js.contains("dataset.regenerated"))
        #expect(replacement.dataJSON.contains(#""count":45"#))

        let updated = try HTMLWorkspacePatchApplier.apply(operation.patchOperation(), to: package)
        #expect(updated.indexHTML == replacement.html)
        #expect(updated.styleCSS == replacement.css)
        #expect(updated.scriptJS == replacement.js)
        #expect(updated.dataJSON == replacement.dataJSON)
        #expect(updated.manifest.generationProvenance?.operation == .regenerate)
    }

    @Test("regenerate application applies one full-surface replacement to the visible package")
    func regenerateApplicationAppliesVisiblePackageReplacement() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        ```html
        <main id="visible-regenerate-proof"><h1>Visible Regenerate Proof</h1></main>
        ```
        ```css
        #visible-regenerate-proof { min-height: 100vh; }
        ```
        ```javascript
        document.body.dataset.visibleRegenerate = 'true';
        ```
        ```json
        {"visible":true}
        ```
        """
        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: streamedResponse,
            package: package,
            expectedContentHash: expectedHash
        )

        let result = try HTMLWorkspaceRegenerateApplication.apply(
            patchResponse,
            to: package,
            expectedContentHash: expectedHash
        )

        #expect(result.appliedOperations == 1)
        #expect(result.package.indexHTML.contains("Visible Regenerate Proof"))
        #expect(result.package.styleCSS.contains("min-height: 100vh"))
        #expect(result.package.scriptJS.contains("visibleRegenerate"))
        #expect(result.package.dataJSON == #"{"visible":true}"#)
        #expect(result.package.manifest.generationProvenance?.operation == .regenerate)
        #expect(result.package.manifest.generationProvenance?.reversibleSnapshotName?.hasPrefix("pre-replace-") == true)
    }

    @Test("regenerate application refuses stale current package before overwriting")
    func regenerateApplicationRefusesStaleCurrentPackage() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        ```html
        <main><h1>Stale Proof</h1></main>
        ```
        ```css
        main { display: block; }
        ```
        ```javascript
        document.body.dataset.staleProof = 'true';
        ```
        ```json
        {"stale":false}
        ```
        """
        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: streamedResponse,
            package: package,
            expectedContentHash: expectedHash
        )
        var editedPackage = package
        editedPackage.indexHTML += "\n<section>User edit while Goose streamed.</section>"

        #expect(throws: HTMLWorkspaceRegenerateApplicationError.self) {
            _ = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: editedPackage,
                expectedContentHash: expectedHash
            )
        }
    }

    @Test("returned replaceDocument patch block is normalized to regenerate provenance")
    func returnedReplaceDocumentPatchBlockIsNormalizedToRegenerateProvenance() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let sourceReplacement = HTMLWorkspaceDocumentReplacement(
            title: "Patch Block Proof",
            html: "<main><h1>Patch Block Proof</h1></main>",
            css: "main { color: rebeccapurple; }",
            js: "document.body.dataset.patchBlock = 'true';",
            dataJSON: #"{"patchBlock":true}"#,
            provenanceOperation: .replaceDocument
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedHash,
            operations: [.replaceDocument(sourceReplacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: response,
            package: package,
            expectedContentHash: expectedHash
        )
        let parsed = try HTMLWorkspacePatchCommandParser.parse(patchResponse)
        let operation = try #require(parsed.batches.first?.operations.first)
        let synthesizedReplacement = try extractReplacement(from: operation)

        #expect(synthesizedReplacement.title == "Patch Block Proof")
        #expect(synthesizedReplacement.provenanceOperation == .regenerate)
    }

    @Test("returned patch block must be exactly one full-surface replacement")
    func returnedPatchBlockMustBeExactlyOneFullSurfaceReplacement() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let sourceReplacement = HTMLWorkspaceDocumentReplacement(
            html: "<main><h1>Extra Operation Proof</h1></main>",
            css: "main { display: grid; }",
            js: "document.body.dataset.extraOperation = 'true';",
            dataJSON: #"{"extraOperation":true}"#,
            provenanceOperation: .regenerate
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedHash,
            operations: [
                .replaceDocument(sourceReplacement),
                .replaceCSS("body { color: red; }"),
            ]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        #expect(throws: HTMLWorkspaceRegeneratePatchSynthesizer.Error.self) {
            _ = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                from: response,
                package: package,
                expectedContentHash: expectedHash
            )
        }
    }

    private func extractReplacement(from operation: HTMLWorkspacePatchCommand) throws -> HTMLWorkspaceDocumentReplacement {
        guard case .replaceDocument(let replacement) = operation else {
            throw RegeneratePatchSynthesizerTestError.expectedReplaceDocument
        }
        return replacement
    }

    private func contentHash(for package: HTMLWorkspacePackage) -> String {
        HTMLWorkspaceDocument.contentHash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: package.dataJSON,
            routes: package.routes
        )
    }
}

private enum RegeneratePatchSynthesizerTestError: Error {
    case expectedReplaceDocument
}
