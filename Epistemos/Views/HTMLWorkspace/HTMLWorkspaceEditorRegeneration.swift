import AppKit
import SwiftUI

extension HTMLWorkspaceEditorView {
    var regenerateContextStatusLine: String? {
        regenerateContextStatusText
            ?? HTMLWorkspaceDataFeedStatus.detailLine(for: package)
            ?? HTMLWorkspaceDataFeedStatus.compactLine(for: package)
    }

    var restoreSnapshotName: String? {
        let name = package.manifest.generationProvenance?.reversibleSnapshotName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        guard package.snapshots[name] != nil else { return nil }
        return name
    }

    var restorePreviousSurfaceHelpText: String {
        guard let restoreSnapshotName else {
            return "No named restore snapshot available"
        }
        return "Revert to snapshot \(restoreSnapshotName)"
    }

    var regenerateContextItems: [HTMLWorkspaceRegenerateContextItem] {
        HTMLWorkspaceRegenerateContextItem.items(from: package)
    }

    var canApplyPendingRegeneratePreview: Bool {
        pendingRegeneratePatchResponse != nil
            && pendingRegenerateExpectedContentHash == package.currentContentHash
    }

    private static let appStoreRegenerateParkedStatus =
        "HTML Workspace regenerate is parked in the App Store build. Use MAS June / Epdoc Assist."

    private func parkRegenerateForAppStoreBuild() {
        regenerateTask?.cancel()
        regenerateTask = nil
        isRegenerating = false
        regenerateSheetPresented = false
        clearPendingRegeneratePreview()
        regenerateStreamText = ""
        regenerateErrorText = nil
        regenerateContextStatusText = Self.appStoreRegenerateParkedStatus
        statusText = Self.appStoreRegenerateParkedStatus
    }

    func openRegenerateSheet() {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        parkRegenerateForAppStoreBuild()
        #else
        regenerateErrorText = nil
        regenerateStreamText = ""
        if let feedQuery = package.manifest.dataFeed?.normalizedQuery, !feedQuery.isEmpty {
            regenerateContextQuery = feedQuery
        } else if regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            regenerateContextQuery = package.manifest.title
        }
        regenerateContextStatusText = HTMLWorkspaceDataFeedStatus.detailLine(for: package)
            ?? HTMLWorkspaceDataFeedStatus.compactLine(for: package)
        clearPendingRegeneratePreview()
        regenerateSheetPresented = true
        #endif
    }

    func refreshRegenerateVaultContext() {
        let query = regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            regenerateContextStatusText = "Workspace context query required"
            statusText = "Workspace context query required"
            return
        }

        let requiredContextKind = HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: query)
        attachRegenerateVaultContext(
            query: query,
            requiredContextKind: requiredContextKind
        )
    }

    func attachRegenerateVaultContext(
        query: String,
        requiredContextKind: String?,
        readyStatus: String? = nil,
        continueAfterAttach: (@MainActor () -> Void)? = nil
    ) {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: query, limit: HTMLWorkspaceDataFeed.defaultLimit)
        regenerateContextQuery = feed.normalizedQuery
        regenerateContextTask?.cancel()
        clearPendingRegeneratePreview()
        regenerateContextRefreshNonce &+= 1
        let refreshNonce = regenerateContextRefreshNonce
        isRefreshingRegenerateContext = true
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
            feed: feed,
            error: "Feed pending",
            requiredContextKind: requiredContextKind
        )
        stampPackageContentRevision()
        regenerateContextStatusText = "Workspace context pending"
        statusText = "Refreshing workspace context"

        if HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource(requiredContextKind) {
            let attachedStatus = attachStandaloneRegenerateContext(feed: feed, requiredContextKind: requiredContextKind)
            regenerateContextStatusText = attachedStatus
            statusText = readyStatus ?? attachedStatus
            continueAfterAttach?()
            return
        }

        guard let vaultSync = AppBootstrap.shared?.vaultSync else {
            package.dataJSON = HTMLWorkspaceDataFeedRenderer.staleRender(
                feed: feed,
                error: "Vault feed unavailable",
                requiredContextKind: requiredContextKind
            )
            stampPackageContentRevision()
            isRefreshingRegenerateContext = false
            regenerateContextTask = nil
            regenerateContextStatusText = "Vault feed unavailable"
            statusText = "Vault feed unavailable"
            continueAfterAttach?()
            return
        }

        regenerateContextTask = Task { @MainActor in
            defer {
                if regenerateContextRefreshNonce == refreshNonce {
                    isRefreshingRegenerateContext = false
                    regenerateContextTask = nil
                }
            }

            let results = await vaultSync.searchFullAsync(
                query: feed.normalizedQuery,
                limit: feed.effectiveLimit
            )
            guard !Task.isCancelled, regenerateContextRefreshNonce == refreshNonce else { return }
            let contextResults = HTMLWorkspaceDataFeedContextSources.results(
                for: requiredContextKind,
                searchResults: results,
                modelContainer: AppBootstrap.shared?.modelContainer,
                limit: feed.effectiveLimit,
                query: feed.normalizedQuery
            )
            package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
                feed: feed,
                contextResults: contextResults,
                requiredContextKind: requiredContextKind
            )
            stampPackageContentRevision()
            regenerateContextStatusText = "Workspace context attached: \(contextResults.count) \(contextResults.count == 1 ? "result" : "results")"
            statusText = readyStatus ?? regenerateContextStatusText
            continueAfterAttach?()
        }
    }

    func clearRegenerateVaultContext() {
        regenerateContextTask?.cancel()
        regenerateContextTask = nil
        regenerateContextRefreshNonce &+= 1
        isRefreshingRegenerateContext = false
        clearPendingRegeneratePreview()
        package.manifest.dataFeed = nil
        package.dataJSON = HTMLWorkspaceDataFeedStatus.clearedDataJSON(from: package.dataJSON)
        stampPackageContentRevision()
        regenerateContextStatusText = "Workspace context cleared"
        statusText = "Workspace context cleared"
    }

    func focusRegenerateContextItem(_ item: HTMLWorkspaceRegenerateContextItem) {
        guard !isRegenerating,
              !isRefreshingRegenerateContext,
              isCurrentRegenerateContextItem(item) else {
            regenerateErrorText = nil
            statusText = "Pick a current Epistemos workspace context item"
            return
        }
        regenerateErrorText = nil
        let directive = """
        Use this focused read-only workspace context item as a primary source; keep provenance visible and do not invent missing details.
        \(selectedPreviewTargetDirective())
        Context:
        \(boundedRegenerateContext(item.promptPayload))
        """
        let current = regenerateInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            regenerateInstruction = directive
        } else if !current.contains(item.contextID) {
            regenerateInstruction = current + "\n" + directive
        }
        regenerateContextStatusText = "Focused \(item.title)"
        statusText = "Workspace context item focused"
    }

    func isCurrentRegenerateContextItem(_ item: HTMLWorkspaceRegenerateContextItem) -> Bool {
        regenerateContextItems.contains { $0.contextID == item.contextID }
    }

    func refreshPreviewContextShortcut(_ shortcut: HTMLWorkspaceRegenerateContextShortcut) {
        guard !isRegenerating else { return }
        regenerateErrorText = nil
        regenerateContextQuery = shortcut.query
        regenerateContextStatusText = "Loading \(shortcut.title) context"
        statusText = "Loading \(shortcut.title) context"
        refreshRegenerateVaultContext()
    }

    func startRegenerateWithContextDirective(_ directive: String, status: String) {
        regenerateErrorText = nil
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        parkRegenerateForAppStoreBuild()
        #else
        let current = regenerateInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        regenerateInstruction = current.isEmpty ? directive : current + "\n" + directive
        regenerateSheetPresented = true
        regenerateContextStatusText = status
        statusText = status
        beginRegenerateSurface(instructionOverride: regenerateInstruction)
        #endif
    }

    func selectedPreviewTargetDirective() -> String {
        guard let inspection = selectedElementInspection else {
            return "Target: update the current preview surface as a whole."
        }

        let selector = boundedRegenerateTarget(inspection.selector)
        let textPreview = inspection.textPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textPreview.isEmpty else {
            return "Target: update the selected preview element/section \(selector) first."
        }
        return "Target: update the selected preview element/section \(selector) first. Current text: \(boundedRegenerateTarget(textPreview))"
    }

    func selectedRegenerateSurfaceContext() -> String? {
        guard let inspection = selectedElementInspection else { return nil }
        var lines = [
            "selected_surface.selector: \(boundedRegenerateTarget(inspection.selector))",
            "selected_surface.tag: \(boundedRegenerateTarget(inspection.tagName))",
        ]
        if let elementID = inspection.elementID, !elementID.isEmpty {
            lines.append("selected_surface.id: \(boundedRegenerateTarget(elementID))")
        }
        if !inspection.classes.isEmpty {
            lines.append("selected_surface.classes: \(inspection.classes.map { boundedRegenerateTarget($0) }.joined(separator: ", "))")
        }
        let textPreview = inspection.textPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        if !textPreview.isEmpty {
            lines.append("selected_surface.text: \(boundedRegenerateTarget(textPreview))")
        }
        return lines.joined(separator: "\n")
    }

    func boundedRegenerateTarget(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 240 else { return trimmed }
        return String(trimmed.prefix(237)) + "..."
    }

    func boundedInspectorSelectorStatus(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 96 else { return trimmed }
        return String(trimmed.prefix(93)) + "..."
    }

    func boundedRegenerateContext(_ value: String) -> String {
        guard value.count > 1_200 else { return value }
        return String(value.prefix(1_200)) + "\n[truncated]"
    }

    func beginRegenerateSurface() {
        beginRegenerateSurfaceAttachingContextIfNeeded(instructionOverride: nil)
    }

    func runRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset) {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        parkRegenerateForAppStoreBuild()
        #else
        regenerateInstruction = preset.instruction
        if preset.family == .vaultData {
            runVaultDataRegeneratePreset(preset)
            return
        }
        beginRegenerateSurfaceAttachingContextIfNeeded(instructionOverride: preset.instruction)
        #endif
    }

    func runVaultDataRegeneratePreset(_ preset: HTMLWorkspaceRegeneratePreset) {
        let query = preset.contextQuery(
            typedQuery: regenerateContextQuery,
            packageTitle: package.manifest.title
        )
        guard !query.isEmpty else {
            regenerateContextStatusText = "Workspace context query required"
            statusText = "Workspace context query required"
            return
        }
        let contextualInstruction = preset.instruction(contextQuery: query)

        regenerateContextQuery = query
        regenerateInstruction = contextualInstruction
        attachRegenerateVaultContext(
            query: query,
            requiredContextKind: preset.requiredContextKind,
            readyStatus: "Workspace context ready"
        ) {
            beginRegenerateSurface(instructionOverride: contextualInstruction)
        }
    }

    func attachStandaloneRegenerateContext(
        feed: HTMLWorkspaceDataFeed,
        requiredContextKind: String?
    ) -> String {
        let contextResults = HTMLWorkspaceDataFeedContextSources.results(
            for: requiredContextKind,
            searchResults: [],
            modelContainer: AppBootstrap.shared?.modelContainer,
            limit: feed.effectiveLimit,
            query: feed.normalizedQuery
        )
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            contextResults: contextResults,
            requiredContextKind: requiredContextKind
        )
        stampPackageContentRevision()
        isRefreshingRegenerateContext = false
        regenerateContextTask = nil
        return "Workspace context attached: \(contextResults.count) \(contextResults.count == 1 ? "result" : "results")"
    }

    func beginRegenerateSurfaceAttachingContextIfNeeded(instructionOverride: String?) {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        parkRegenerateForAppStoreBuild()
        #else
        guard !isRegenerating else { return }
        let sourceInstruction = instructionOverride ?? regenerateInstruction
        let instruction = sourceInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            beginRegenerateSurface(instructionOverride: instructionOverride)
            return
        }

        let query = regenerateContextQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let requiredContextKind = HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: query)
        guard shouldAttachRegenerateContextBeforeStreaming(query: query, requiredContextKind: requiredContextKind) else {
            beginRegenerateSurface(instructionOverride: instructionOverride)
            return
        }

        attachRegenerateVaultContext(
            query: query,
            requiredContextKind: requiredContextKind,
            readyStatus: "Workspace context ready"
        ) {
            beginRegenerateSurface(instructionOverride: instructionOverride)
        }
        #endif
    }

    func shouldAttachRegenerateContextBeforeStreaming(
        query: String,
        requiredContextKind: String?
    ) -> Bool {
        guard !query.isEmpty else { return false }
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: query, limit: HTMLWorkspaceDataFeed.defaultLimit)
        guard let currentFeed = package.manifest.dataFeed,
              currentFeed.source == feed.source,
              currentFeed.normalizedQuery == feed.normalizedQuery,
              currentFeed.effectiveLimit == feed.effectiveLimit,
              let envelope = HTMLWorkspaceRegenerateContext.dataFeedEnvelope(from: package.dataJSON, matching: currentFeed) else {
            return true
        }
        guard envelope.epistemos.stale == false else {
            return true
        }
        return (envelope.epistemos.requiredContextKind ?? "") != (requiredContextKind ?? "")
    }

    func beginRegenerateSurface(instructionOverride: String?) {
        #if EPISTEMOS_APP_STORE || MAS_SANDBOX
        parkRegenerateForAppStoreBuild()
        #else
        guard !isRegenerating else { return }
        let sourceInstruction = instructionOverride ?? regenerateInstruction
        let instruction = sourceInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            regenerateErrorText = "Enter a regenerate request."
            return
        }
        regenerateInstruction = instruction

        let sourcePackage = package
        let expectedHash = sourcePackage.currentContentHash
        let prompt = HTMLWorkspaceRegeneratePromptBuilder.prompt(
            instruction: instruction,
            package: sourcePackage,
            expectedContentHash: expectedHash,
            selectedSurfaceContext: selectedRegenerateSurfaceContext()
        )

        regenerateTask?.cancel()
        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        clearPendingRegeneratePreview()
        previewRouteName = nil
        previewPackage = HTMLWorkspaceRegeneratePreview.loadingPackage(
            from: sourcePackage,
            instruction: instruction,
            selectedSurfaceContext: selectedRegenerateSurfaceContext()
        )
        liveDOMSnapshot = nil
        layoutMode = .split
        regenerateStreamText = ""
        regenerateErrorText = nil
        isRegenerating = true
        statusText = "Regenerating surface"

        regenerateTask = Task { @MainActor in
            defer {
                isRegenerating = false
                regenerateTask = nil
            }
            do {
                var response = ""
                var previewCandidateHash: String?
                let workspaceURL = currentHTMLWorkspaceDocument()?.fileURL
                for try await chunk in gooseRegenerator.streamRegeneration(
                    systemPrompt: HTMLWorkspaceRegeneratePromptBuilder.systemPrompt,
                    prompt: prompt,
                    workspaceURL: workspaceURL
                ) {
                    guard !Task.isCancelled else { throw CancellationError() }
                    response += chunk
                    regenerateStreamText = response
                    // Re-synthesizing a candidate is expensive (whole-response fenced-block scan +
                    // JSON decode + package content hash) and runs on @MainActor. A new candidate
                    // can only appear once a fenced block closes, which is exactly when a ``` marker
                    // arrives — so gate the reparse on that instead of running it on every chunk
                    // (previously O(n^2) over the stream). The post-stream parse below stays
                    // authoritative, so a split-fence chunk at worst delays one live-preview tick.
                    if chunk.contains("```"),
                       let candidate = HTMLWorkspaceRegeneratePreview.candidatePackage(
                        from: response,
                        basePackage: sourcePackage,
                        expectedContentHash: expectedHash
                    ),
                       candidate.manifest.contentHash != previewCandidateHash {
                        previewCandidateHash = candidate.manifest.contentHash
                        previewPackage = candidate
                        liveDOMSnapshot = nil
                    }
                }

                let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                    from: response,
                    package: sourcePackage,
                    expectedContentHash: expectedHash
                )
                _ = try HTMLWorkspaceRegenerateApplication.apply(
                    patchResponse,
                    to: package,
                    expectedContentHash: expectedHash
                )
                if let candidate = HTMLWorkspaceRegeneratePreview.candidatePackage(
                    from: response,
                    basePackage: sourcePackage,
                    expectedContentHash: expectedHash
                ) {
                    previewPackage = candidate
                }
                pendingRegeneratePatchResponse = patchResponse
                pendingRegenerateExpectedContentHash = expectedHash
                previewRouteName = nil
                liveDOMSnapshot = nil
                selectedPane = .html
                layoutMode = .split
                regenerateErrorText = nil
                statusText = "Regenerate preview ready"
            } catch is CancellationError {
                restorePreviewAfterRegenerate()
                statusText = "Regenerate stopped"
            } catch {
                restorePreviewAfterRegenerate()
                regenerateErrorText = error.localizedDescription
                statusText = failedStatus("Regenerate", error: error)
            }
        }
        #endif
    }

    func clearPendingRegeneratePreview() {
        pendingRegeneratePatchResponse = nil
        pendingRegenerateExpectedContentHash = nil
    }

    func expirePendingRegeneratePreviewIfNeeded(for newPackage: HTMLWorkspacePackage) {
        guard let expected = pendingRegenerateExpectedContentHash,
              expected != newPackage.currentContentHash else { return }
        clearPendingRegeneratePreview()
        regenerateErrorText = "Regenerate preview is stale because the workspace changed."
        statusText = "Regenerate preview expired"
    }

    func copyRegeneratePrompt() {
        let instruction = regenerateInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else {
            regenerateErrorText = "Enter a regenerate request."
            return
        }

        let prompt = HTMLWorkspaceRegeneratePromptBuilder.clipboardPrompt(
            instruction: instruction,
            package: package,
            expectedContentHash: package.currentContentHash,
            selectedSurfaceContext: selectedRegenerateSurfaceContext()
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        regenerateErrorText = nil
        statusText = "Regenerate recovery prompt copied"
    }

    func restorePreviewAfterRegenerate() {
        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        previewRouteName = nil
        liveDOMSnapshot = nil
        previewPackage = package
        clearPendingRegeneratePreview()
    }

    func previewRegenerateStreamText() {
        guard !isRegenerating else { return }
        let response = regenerateStreamText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else {
            regenerateErrorText = "No regenerate response to preview."
            return
        }
        clearPendingRegeneratePreview()

        let sourcePackage = package
        let expectedHash = sourcePackage.currentContentHash
        guard let candidate = HTMLWorkspaceRegeneratePreview.candidatePackage(
            from: response,
            basePackage: sourcePackage,
            expectedContentHash: expectedHash
        ) else {
            regenerateErrorText = "Stream must contain a complete regenerate response for the visible workspace and current hash."
            statusText = "Regenerate preview unavailable"
            return
        }

        do {
            let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                from: response,
                package: sourcePackage,
                expectedContentHash: expectedHash
            )
            _ = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: expectedHash
            )
            pendingRegeneratePatchResponse = patchResponse
            pendingRegenerateExpectedContentHash = expectedHash
        } catch {
            regenerateErrorText = error.localizedDescription
            statusText = failedStatus("Regenerate preview", error: error)
            return
        }

        previewUpdateTask?.cancel()
        previewUpdateTask = nil
        previewRouteName = nil
        previewPackage = candidate
        liveDOMSnapshot = nil
        selectedPane = .html
        layoutMode = .split
        regenerateErrorText = nil
        statusText = "Regenerate preview ready"
    }

    func applyPendingRegeneratePreview() {
        guard !isRegenerating else { return }
        guard let patchResponse = pendingRegeneratePatchResponse,
              let expectedHash = pendingRegenerateExpectedContentHash else {
            regenerateErrorText = "No regenerate preview to apply."
            return
        }
        guard expectedHash == package.currentContentHash else {
            clearPendingRegeneratePreview()
            regenerateErrorText = "Regenerate preview is stale because the workspace changed."
            statusText = "Regenerate preview expired"
            return
        }

        do {
            let result = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: expectedHash
            )
            clearPendingRegeneratePreview()
            package = result.package
            previewRouteName = nil
            previewPackage = result.package
            liveDOMSnapshot = nil
            selectedPane = .html
            layoutMode = .split
            regenerateErrorText = nil
            regenerateSheetPresented = false
            statusText = "Regenerate preview applied; Revert available"
        } catch {
            regenerateErrorText = error.localizedDescription
            statusText = failedStatus("Regenerate apply", error: error)
        }
    }

    func applyRegenerateStreamText() {
        guard !isRegenerating else { return }
        let response = regenerateStreamText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else {
            regenerateErrorText = "No regenerate response to apply."
            return
        }

        let expectedHash = package.currentContentHash
        do {
            let patchResponse = try HTMLWorkspaceRegeneratePatchSynthesizer.patchResponse(
                from: response,
                package: package,
                expectedContentHash: expectedHash
            )
            let result = try HTMLWorkspaceRegenerateApplication.apply(
                patchResponse,
                to: package,
                expectedContentHash: expectedHash
            )
            clearPendingRegeneratePreview()
            package = result.package
            previewRouteName = nil
            previewPackage = result.package
            liveDOMSnapshot = nil
            selectedPane = .html
            layoutMode = .split
            regenerateErrorText = nil
            regenerateSheetPresented = false
            statusText = "Regenerate stream applied; Revert available"
        } catch {
            regenerateErrorText = error.localizedDescription
            statusText = failedStatus("Regenerate apply", error: error)
        }
    }
}
