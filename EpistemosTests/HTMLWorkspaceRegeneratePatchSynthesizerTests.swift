import Foundation
import Testing

@testable import Epistemos

@Suite("HTML Workspace full-surface regenerate synthesis")
nonisolated struct HTMLWorkspaceRegeneratePatchSynthesizerTests {
    @Test("regenerate loading preview is transient, escaped, and not persisted as the package")
    func regenerateLoadingPreviewIsTransientEscapedAndNotPersisted() {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Proof")
        let loading = HTMLWorkspaceRegeneratePreview.loadingPackage(
            from: package,
            instruction: "Explain <script>alert(1)</script> as an animated dashboard"
        )

        #expect(loading.manifest.id == package.manifest.id)
        #expect(loading.manifest.title == "Regenerating Proof")
        #expect(loading.manifest.contentHash != package.manifest.contentHash)
        #expect(loading.indexHTML.contains("data-regenerate-preview"))
        #expect(loading.indexHTML.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!loading.indexHTML.contains("<script>alert(1)</script>"))
        #expect(loading.styleCSS.contains("regenerate-preview-pulse"))
        #expect(loading.styleCSS.contains("var(--epistemos-workspace-bg"))
        #expect(loading.styleCSS.contains("var(--epistemos-workspace-card"))
        #expect(loading.styleCSS.contains("var(--epistemos-workspace-accent"))
        #expect(!loading.styleCSS.contains("linear-gradient"))
        #expect(!loading.styleCSS.contains("border: 1px"))
        #expect(loading.scriptJS.isEmpty)
        #expect(loading.dataJSON.contains(#""status":"regenerating""#))
        #expect(loading.routes.isEmpty)
        #expect(loading.assets.isEmpty)
        #expect(package.indexHTML != loading.indexHTML)
    }

    @Test("regenerate sheet exposes target workspace and hash before replace")
    func regenerateSheetExposesTargetWorkspaceAndHashBeforeReplace() throws {
        let sheet = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerateSurface.swift")
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(sheet.contains("let workspaceID: String"))
        #expect(sheet.contains("let expectedContentHash: String"))
        #expect(sheet.contains("@Binding var streamedText: String"))
        #expect(sheet.contains("@Binding var contextQuery: String"))
        #expect(sheet.contains("@Environment(UIState.self) private var ui"))
        #expect(sheet.contains("let hasPendingPreview: Bool"))
        #expect(sheet.contains("let hasVaultContext: Bool"))
        #expect(sheet.contains("let isRefreshingContext: Bool"))
        #expect(sheet.contains("let contextStatusText: String?"))
        #expect(sheet.contains("let contextItems: [HTMLWorkspaceRegenerateContextItem]"))
        #expect(sheet.contains("let canRestorePreviousSurface: Bool"))
        #expect(sheet.contains("let onRefreshContext: () -> Void"))
        #expect(sheet.contains("let onClearContext: () -> Void"))
        #expect(sheet.contains("let onFocusContextItem: (HTMLWorkspaceRegenerateContextItem) -> Void"))
        #expect(sheet.contains("let onRunPreset: (HTMLWorkspaceRegeneratePreset) -> Void"))
        #expect(sheet.contains("let onApplyPreview: () -> Void"))
        #expect(sheet.contains("let onRestorePreviousSurface: () -> Void"))
        #expect(sheet.contains("Label(\"Apply Preview\", systemImage: \"checkmark.circle\")"))
        #expect(sheet.contains("Label(\"Revert\", systemImage: \"clock.arrow.circlepath\")"))
        #expect(sheet.contains("Label(isRegenerating ? \"Streaming\" : \"Stream Preview\", systemImage: \"wand.and.sparkles\")"))
        #expect(sheet.contains("Label(\"Vault Context\", systemImage: \"tray.full\")"))
        #expect(sheet.contains("TextField(\"Search vault context\", text: $contextQuery)"))
        #expect(sheet.contains("Label(isRefreshingContext ? \"Searching\" : \"Add Context\", systemImage: \"magnifyingglass.circle\")"))
        #expect(sheet.contains("ForEach(contextItems)"))
        #expect(sheet.contains(".onDrag"))
        #expect(sheet.contains("NSItemProvider(object: item.dragPayload as NSString)"))
        #expect(sheet.contains("nonisolated struct HTMLWorkspaceRegenerateContextItem"))
        #expect(sheet.contains("HTMLWorkspaceRegeneratePreset.Family.allCases"))
        #expect(sheet.contains("FlowLayout(spacing: 6)"))
        #expect(sheet.contains("Label(\"Advanced response paste fallback\", systemImage: \"terminal\")"))
        #expect(sheet.contains("Label(\"Copy Prompt\", systemImage: \"doc.on.doc\")"))
        #expect(sheet.contains("Label(\"Preview Response\", systemImage: \"eye\")"))
        #expect(sheet.contains("Label(\"Apply Response\", systemImage: \"checkmark.circle\")"))
        #expect(!sheet.contains("Label(\"Preview Stream\", systemImage: \"eye\")"))
        #expect(!sheet.contains("Label(\"Show Current\", systemImage: \"arrow.uturn.backward.circle\")"))
        #expect(!sheet.contains("Label(\"Apply Stream\", systemImage: \"checkmark.circle\")"))
        #expect(!sheet.contains("Label(isRegenerating ? \"Regenerating\" : \"Regenerate\", systemImage: \"wand.and.sparkles\")"))
        #expect(sheet.contains("let onCopyPrompt: () -> Void"))
        #expect(sheet.contains("let onRestorePreview: () -> Void"))
        #expect(sheet.contains("TextEditor(text: $streamedText)"))
        #expect(sheet.contains(#"Label("Target", systemImage: "scope")"#))
        #expect(sheet.contains("Text(\"\\(workspaceID.prefix(10)) / \\(expectedContentHash.prefix(10))\")"))
        #expect(sheet.contains("MarkdownPreviewSurfaceStyle.flatBackground(for: theme.surfaceVariant(.other))"))
        #expect(sheet.contains(".textFieldStyle(.plain)"))
        #expect(sheet.contains(".foregroundStyle(theme.error)"))
        #expect(!sheet.contains(".textFieldStyle(.roundedBorder)"))
        #expect(!sheet.contains("GroupBox"))
        #expect(!sheet.contains(".foregroundStyle(.red)"))
        #expect(editor.contains("workspaceID: package.manifest.id"))
        #expect(editor.contains("expectedContentHash: package.currentContentHash"))
        #expect(editor.contains("streamedText: $regenerateStreamText"))
        #expect(editor.contains("contextQuery: $regenerateContextQuery"))
        #expect(editor.contains("contextStatusText: regenerateContextStatusLine"))
        #expect(editor.contains("isRefreshingContext: isRefreshingRegenerateContext"))
        #expect(editor.contains("hasPendingPreview: pendingRegeneratePatchResponse != nil && pendingRegenerateExpectedContentHash != nil"))
        #expect(editor.contains("hasVaultContext: package.manifest.dataFeed != nil"))
        #expect(editor.contains("contextItems: HTMLWorkspaceRegenerateContextItem.items(from: package)"))
        #expect(editor.contains("canRestorePreviousSurface: package.manifest.generationProvenance?.reversibleSnapshotName != nil"))
        #expect(editor.contains("onCopyPrompt: copyRegeneratePrompt"))
        #expect(editor.contains("onRefreshContext: refreshRegenerateVaultContext"))
        #expect(editor.contains("onClearContext: clearRegenerateVaultContext"))
        #expect(editor.contains("onFocusContextItem: focusRegenerateContextItem"))
        #expect(editor.contains(".onDrop(of: [UTType.plainText], isTargeted: nil, perform: handlePreviewContextDrop)"))
        #expect(editor.contains("onRunPreset: runRegeneratePreset"))
        #expect(editor.contains("onApplyPreview: applyPendingRegeneratePreview"))
        #expect(editor.contains("onPreviewStream: previewRegenerateStreamText"))
        #expect(editor.contains("onApplyStream: applyRegenerateStreamText"))
        #expect(editor.contains("onRestorePreview: restorePreviewAfterRegenerate"))
        #expect(editor.contains("onRestorePreviousSurface: restorePreviousSurface"))
        #expect(editor.contains("Label(\"Revert Surface\", systemImage: \"clock.arrow.circlepath\")"))
        #expect(editor.contains(".help(\"Revert to previous surface\")"))
        #expect(editor.contains("@State private var regenerateContextQuery = \"\""))
        #expect(editor.contains("@State private var regenerateContextTask: Task<Void, Never>?"))
        #expect(editor.contains("@State private var regenerateContextRefreshNonce = 0"))
        #expect(editor.contains("@State private var pendingRegeneratePatchResponse: String?"))
        #expect(editor.contains("@State private var pendingRegenerateExpectedContentHash: String?"))
        #expect(editor.contains("private var regenerateContextStatusLine: String?"))
        #expect(editor.contains("private func refreshRegenerateVaultContext()"))
        #expect(editor.contains("VaultSyncService.searchFullAsync") || editor.contains("vaultSync.searchFullAsync"))
        #expect(editor.contains("HTMLWorkspaceDataFeedRenderer.render(feed: feed, results: results)"))
        #expect(editor.contains("private func clearRegenerateVaultContext()"))
        #expect(editor.contains("private func focusRegenerateContextItem(_ item: HTMLWorkspaceRegenerateContextItem)"))
        #expect(editor.contains("keep its provenance visible and do not invent missing details"))
        #expect(editor.contains("private func handlePreviewContextDrop(_ providers: [NSItemProvider]) -> Bool"))
        #expect(editor.contains("private func applyDroppedPreviewContext(_ payload: String)"))
        #expect(editor.contains("Use this dropped read-only context as a primary source"))
        #expect(editor.contains("beginRegenerateSurface(instructionOverride: regenerateInstruction)"))
        #expect(editor.contains("private func runRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset)"))
        #expect(editor.contains("if preset.family == .vaultData"))
        #expect(editor.contains("private func runVaultDataRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset)"))
        #expect(editor.contains("beginRegenerateSurface(instructionOverride: preset.instruction)"))
        #expect(editor.contains("private func applyPendingRegeneratePreview()"))
        #expect(editor.contains("pendingRegeneratePatchResponse = patchResponse"))
        #expect(editor.contains(#"statusText = "Regenerate preview ready""#))
        #expect(editor.contains(#"statusText = "Regenerate preview applied""#))
        #expect(!editor.contains(#"statusText = "Regenerated surface""#))
        #expect(editor.contains("private func copyRegeneratePrompt()"))
        #expect(editor.contains("HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt("))
        #expect(editor.contains(#"statusText = "Regenerate prompt copied""#))
        #expect(editor.contains("private func previewRegenerateStreamText()"))
        #expect(editor.contains("private func applyRegenerateStreamText()"))
        #expect(editor.contains("HTMLWorkspaceRegenerateApplication.apply("))
        #expect(editor.contains("HTMLWorkspaceRegeneratePreview.candidatePackage("))
    }

    @Test("regenerate presets expose required one-click categories")
    func regeneratePresetsExposeRequiredOneClickCategories() {
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .layout).map(\.title) == [
            "Dashboard",
            "Landing page",
            "Docs page",
            "Single-column article",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .addThing).map(\.title) == [
            "Add chart",
            "Add search box",
            "Add table",
            "Add nav",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.presets(in: .vaultData).map(\.title) == [
            "Notes -> cards",
            "Recent captures",
            "Related notes",
        ])
        #expect(HTMLWorkspaceRegeneratePreset.all.count == 11)
        #expect(HTMLWorkspaceRegeneratePreset.all.allSatisfy { $0.instruction.contains("Regenerate") })
    }

    @Test("regenerate prompt includes verified data feed context and honest degradation")
    func regeneratePromptIncludesVerifiedDataFeedContextAndHonestDegradation() {
        var package = HTMLWorkspacePackage.defaultPackage(title: "Context Proof")
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "substrate provenance", limit: 2)
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Research Note",
                    snippet: "substrate provenance witness",
                    rank: 0.87
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: "Turn notes into cards",
            package: package,
            expectedContentHash: contentHash(for: package)
        )

        #expect(prompt.contains("Verified Epistemos context:"))
        #expect(prompt.contains("vault_search.query: substrate provenance"))
        #expect(prompt.contains("vault_search.provenance: VaultSyncService.searchFullAsync"))
        #expect(prompt.contains("- Research Note [page-1] rank 0.87: substrate provenance witness"))
        #expect(prompt.contains("grounding_rule: preserve real data provenance"))

        let emptyPrompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: "Use related notes",
            package: HTMLWorkspacePackage.defaultPackage(title: "No Context"),
            expectedContentHash: "hash"
        )
        #expect(emptyPrompt.contains("vault_search: not attached"))
        #expect(emptyPrompt.contains("do not invent vault notes, graph links, captures, or chats"))
    }

    @Test("regenerate context items decode feed results as draggable read-only sources")
    func regenerateContextItemsDecodeFeedResultsAsDraggableReadOnlySources() {
        var package = HTMLWorkspacePackage.defaultPackage(title: "Drag Context")
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "drag context", limit: 2)
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(pageId: "note-a", title: "Alpha Note", snippet: "alpha snippet", rank: 0.9),
                SearchResult(pageId: "note-b", title: "Beta Note", snippet: "beta snippet", rank: 0.7),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )

        let items = HTMLWorkspaceRegenerateContextItem.items(from: package)

        #expect(items.map(\.pageID) == ["note-a", "note-b"])
        #expect(items.first?.title == "Alpha Note")
        #expect(items.first?.dragPayload.contains("Vault note: Alpha Note [note-a]") == true)
        #expect(items.first?.dragPayload.contains("alpha snippet") == true)
        #expect(HTMLWorkspaceRegenerateContextItem.items(from: .defaultPackage()).isEmpty)
    }

    @Test("regenerate preview package swaps reset stale route selection")
    func regeneratePreviewPackageSwapsResetStaleRouteSelection() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")

        #expect(editor.contains("previewRouteName = nil\n        previewPackage = HTMLWorkspaceRegeneratePreview.loadingPackage("))
        #expect(editor.contains("previewRouteName = nil\n        previewPackage = candidate"))
        #expect(editor.contains("previewRouteName = nil\n        liveDOMSnapshot = nil\n        previewPackage = package"))
        #expect(editor.contains("previewRouteName = nil\n            previewPackage = result.package"))
        #expect(editor.components(separatedBy: "previewRouteName = nil").count >= 5)
    }

    @Test("copyable regenerate prompt includes system prompt and target hash")
    func copyableRegeneratePromptIncludesSystemPromptAndTargetHash() {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Prompt Proof")
        let expectedHash = contentHash(for: package)
        let prompt = HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt(
            instruction: "Turn this into a live explainer",
            package: package,
            expectedContentHash: expectedHash
        )

        #expect(prompt.contains("System:"))
        #expect(prompt.contains(HTMLWorkspaceRegeneratePromptBuilder.systemPrompt))
        #expect(prompt.contains("User:"))
        #expect(prompt.contains("Regenerate this HTML Workspace as one complete live site."))
        #expect(prompt.contains("id: \(package.manifest.id)"))
        #expect(prompt.contains("expected_content_hash: \(expectedHash)"))
        #expect(prompt.contains("do not create a route named assets"))
        #expect(prompt.contains("routes/assets/<name>"))
        #expect(prompt.contains("Turn this into a live explainer"))
        #expect(prompt.contains("in-surface add-context picker/filter"))
    }

    @Test("complete streamed regenerate response can preview before final apply")
    func completeStreamedRegenerateResponseCanPreviewBeforeFinalApply() throws {
        let package = HTMLWorkspacePackage.defaultPackage(title: "Preview Source")
        let expectedHash = contentHash(for: package)
        let streamedResponse = """
        ```html
        <main id="stream-preview-proof"><h1>Streaming Preview Proof</h1></main>
        ```
        ```css
        #stream-preview-proof { display: grid; }
        ```
        ```javascript
        document.body.dataset.streamPreview = 'true';
        ```
        ```json
        {"preview":true}
        ```
        """

        let preview = try #require(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: streamedResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ))

        #expect(preview.indexHTML.contains("Streaming Preview Proof"))
        #expect(preview.styleCSS.contains("display: grid"))
        #expect(preview.scriptJS.contains("streamPreview"))
        #expect(preview.dataJSON == #"{"preview":true}"#)
        #expect(preview.manifest.id == package.manifest.id)
        #expect(preview.manifest.generationProvenance?.operation == .regenerate)
        #expect(preview.manifest.generationProvenance?.reversibleSnapshotName == nil)
        #expect(package.indexHTML != preview.indexHTML)
    }

    @Test("incomplete or wrong-target stream does not update the preview candidate")
    func incompleteOrWrongTargetStreamDoesNotUpdatePreviewCandidate() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let incompleteResponse = """
        ```html
        <main><h1>Only HTML So Far</h1></main>
        ```
        """

        #expect(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: incompleteResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ) == nil)

        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Wrong Workspace",
            html: "<main><h1>Wrong Workspace</h1></main>",
            css: "main { display: grid; }",
            js: "",
            dataJSON: "{}",
            provenanceOperation: .regenerate
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: "not-\(package.manifest.id)",
            expectedContentHash: expectedHash,
            operations: [.replaceDocument(replacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let wrongWorkspaceResponse = """
        ```epistemos-html-workspace-patch
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        #expect(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: wrongWorkspaceResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ) == nil)
    }

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
        let routeReplacement = ["about.html": "<main><h1>About Regenerate</h1></main>"]
        let assetReplacement = ["hero.txt": Data("asset regenerate proof".utf8)]
        let sourceReplacement = HTMLWorkspaceDocumentReplacement(
            title: "Patch Block Proof",
            html: "<main><h1>Patch Block Proof</h1></main>",
            css: "main { color: rebeccapurple; }",
            js: "document.body.dataset.patchBlock = 'true';",
            dataJSON: #"{"patchBlock":true}"#,
            routes: routeReplacement,
            assets: assetReplacement,
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
        #expect(synthesizedReplacement.routes == routeReplacement)
        #expect(synthesizedReplacement.assets == assetReplacement)
    }

    @Test("returned patch block workspace and hash metadata survive synthesis")
    func returnedPatchBlockWorkspaceAndHashMetadataSurviveSynthesis() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let replacement = HTMLWorkspaceDocumentReplacement(
            html: "<main><h1>Wrong Target Proof</h1></main>",
            css: "main { display: grid; }",
            js: "",
            dataJSON: "{}",
            provenanceOperation: .regenerate
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: "wrong-workspace",
            expectedContentHash: "wrong-hash",
            operations: [.replaceDocument(replacement)]
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
            expectedContentHash: contentHash(for: package)
        )
        let parsed = try HTMLWorkspacePatchCommandParser.parse(patchResponse)

        #expect(parsed.batches.first?.workspaceID == "wrong-workspace")
        #expect(parsed.batches.first?.expectedContentHash == "wrong-hash")
        #expect(throws: HTMLWorkspaceRegenerateApplicationError.self) {
            _ = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: contentHash(for: package)
            )
        }
    }

    @Test("returned patch block may use tolerant fence labels")
    func returnedPatchBlockMayUseTolerantFenceLabels() throws {
        let package = HTMLWorkspacePackage.defaultPackage()
        let expectedHash = contentHash(for: package)
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Tolerant Fence",
            html: "<main><h1>Tolerant Fence Proof</h1></main>",
            css: "main { display: grid; }",
            js: "",
            dataJSON: "{}",
            provenanceOperation: .replaceDocument
        )
        let batch = HTMLWorkspacePatchCommandBatch(
            workspaceID: package.manifest.id,
            expectedContentHash: expectedHash,
            operations: [.replaceDocument(replacement)]
        )
        let data = try JSONEncoder.epdocCanonical.encode(batch)
        let response = """
        ```EPISTEMOS-HTML-WORKSPACE-PATCH json
        \(String(decoding: data, as: UTF8.self))
        ```
        """

        let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
            from: response,
            package: package,
            expectedContentHash: expectedHash
        )
        let preview = try #require(HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: patchResponse,
            basePackage: package,
            expectedContentHash: expectedHash
        ))

        #expect(preview.manifest.title == "Tolerant Fence")
        #expect(preview.indexHTML.contains("Tolerant Fence Proof"))
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
        package.currentContentHash
    }
}

private enum RegeneratePatchSynthesizerTestError: Error {
    case expectedReplaceDocument
}
