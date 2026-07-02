import AppKit
import Foundation
import SwiftUI

extension HTMLWorkspaceEditorView {
    func saveDocument() {
        if let document = currentHTMLWorkspaceDocument() {
            document.save(nil)
        } else {
            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
        }
        statusText = "Save requested"
    }

    func captureSnapshot() {
        let name = "snapshot-\(Int(Date().timeIntervalSince1970)).html"
        do {
            package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: name), to: package)
            statusText = "Snapshot saved"
        } catch {
            statusText = failedStatus("Snapshot", error: error)
        }
    }

    func addRoute() {
        let nameField = NSTextField(string: "about.html")
        nameField.placeholderString = "about.html"

        let htmlTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
        htmlTextView.isRichText = false
        htmlTextView.isAutomaticQuoteSubstitutionEnabled = false
        htmlTextView.isAutomaticDashSubstitutionEnabled = false
        htmlTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        htmlTextView.string = """
        <main>
          <h1>New Route</h1>
        </main>
        """

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.documentView = htmlTextView

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.addArrangedSubview(NSTextField(labelWithString: "Route name"))
        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(NSTextField(labelWithString: "HTML"))
        stack.addArrangedSubview(scrollView)
        stack.setFrameSize(NSSize(width: 420, height: 230))
        nameField.frame.size.width = 420

        let alert = NSAlert()
        alert.messageText = "Add Route"
        alert.informativeText = "Create or replace a package-local routes/<name> HTML page."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = stack

        guard alert.runModal() == .alertFirstButtonReturn else {
            statusText = "Route unchanged"
            return
        }

        let name = normalizedRouteName(nameField.stringValue)
        let html = htmlTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !html.isEmpty else {
            statusText = "Route name and HTML required"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.setRoute(name: name, html: html), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedRouteName = name
            previewRouteName = name
            selectedPane = .routes
            layoutMode = .split
            statusText = "Route \(name) saved"
        } catch {
            statusText = failedStatus("Route", error: error)
        }
    }

    func removeRoute() {
        let routeNames = package.routes.keys.sorted()
        guard !routeNames.isEmpty else {
            statusText = "No routes to remove"
            return
        }

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        popUp.addItems(withTitles: routeNames)

        let alert = NSAlert()
        alert.messageText = "Remove Route"
        alert.informativeText = "Remove a package-local route from routes/."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = popUp

        guard alert.runModal() == .alertFirstButtonReturn,
              let name = popUp.selectedItem?.title,
              !name.isEmpty else {
            statusText = "Route unchanged"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.removeRoute(name: name), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedRouteName = sortedRouteNames.first
            if previewRouteName == name {
                previewRouteName = nil
            }
            selectedPane = .routes
            layoutMode = .split
            statusText = "Route \(name) removed"
        } catch {
            statusText = failedStatus("Route", error: error)
        }
    }

    private func normalizedRouteName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              URL(fileURLWithPath: trimmed).pathExtension.isEmpty else {
            return trimmed
        }
        return trimmed + ".html"
    }

    func addAsset() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            statusText = "Asset unchanged"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent
            package = try HTMLWorkspacePatchApplier.apply(
                .addAsset(HTMLWorkspaceAsset(name: name, data: data)),
                to: package
            )
            previewPackage = package
            liveDOMSnapshot = nil
            selectedPane = .assets
            layoutMode = .split
            statusText = "Asset \(name) added"
        } catch {
            statusText = failedStatus("Asset", error: error)
        }
    }

    func removeAsset() {
        let assetNames = package.assets.keys.sorted()
        guard !assetNames.isEmpty else {
            statusText = "No assets to remove"
            return
        }

        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        popUp.addItems(withTitles: assetNames)

        let alert = NSAlert()
        alert.messageText = "Remove Asset"
        alert.informativeText = "Remove a package-local asset from assets/."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.accessoryView = popUp

        guard alert.runModal() == .alertFirstButtonReturn,
              let name = popUp.selectedItem?.title,
              !name.isEmpty else {
            statusText = "Asset unchanged"
            return
        }

        do {
            package = try HTMLWorkspacePatchApplier.apply(.removeAsset(name: name), to: package)
            previewPackage = package
            liveDOMSnapshot = nil
            selectedPane = .assets
            layoutMode = .split
            statusText = "Asset \(name) removed"
        } catch {
            statusText = failedStatus("Asset", error: error)
        }
    }

    func restorePreviousSurface() {
        guard let name = restoreSnapshotName else {
            statusText = "No restore snapshot"
            return
        }
        do {
            clearPendingRegeneratePreview()
            package = try HTMLWorkspacePatchApplier.apply(.restoreSnapshot(name: name), to: package)
            previewRouteName = nil
            previewPackage = package
            liveDOMSnapshot = nil
            selectedPane = .html
            layoutMode = .split
            regenerateErrorText = nil
            statusText = "Previous surface restored from \(name)"
        } catch {
            statusText = failedStatus("Restore", error: error)
        }
    }

    func testAppBridge() {
        guard package.manifest.sandboxPolicy.allowAppBridge else {
            statusText = "App bridge disabled"
            return
        }
        consoleExpanded = true
        layoutMode = .split
        appBridgeProbeNonce &+= 1
        statusText = "App bridge probe requested"
    }

    func testConsoleCapture() {
        consoleExpanded = true
        layoutMode = .split
        consoleProbeNonce &+= 1
        statusText = "Console capture probe requested"
    }

    func testPythonRuntime() {
        guard package.manifest.sandboxPolicy.allowPythonRuntime else {
            statusText = "Python runtime disabled"
            return
        }
        consoleExpanded = true
        layoutMode = .split
        pythonProbeNonce &+= 1
        statusText = HTMLWorkspacePythonRuntime.isAvailable
            ? "Python runtime probe requested"
            : "Python runtime probe requested; \(HTMLWorkspacePythonRuntime.availabilityStatusText)"
    }

    func testRuntimeBridgeProbes() {
        consoleExpanded = true
        layoutMode = .split
        appBridgeProbeNonce &+= 1
        consoleProbeNonce &+= 1
        pythonProbeNonce &+= 1
        statusText = "Runtime bridge probes requested"
    }

    func insertAppBridgeDemo() {
        do {
            let updated = try HTMLWorkspaceAppBridgeDemoScaffold.apply(to: package)
            package = updated
            previewPackage = updated
            selectedPane = .js
            layoutMode = .split
            consoleExpanded = true
            statusText = "App bridge demo inserted"
        } catch {
            statusText = failedStatus("App bridge demo", error: error)
        }
    }

    func insertPythonDemo() {
        do {
            let updated = try HTMLWorkspacePythonDemoScaffold.apply(to: package)
            package = updated
            previewPackage = updated
            selectedPane = .js
            layoutMode = .split
            consoleExpanded = true
            statusText = HTMLWorkspacePythonRuntime.isAvailable
                ? "Python demo inserted"
                : "Python demo inserted; \(HTMLWorkspacePythonRuntime.availabilityStatusText)"
        } catch {
            statusText = failedStatus("Python demo", error: error)
        }
    }

    func importHTML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            statusText = "Import cancelled"
            return
        }
        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let imported = HTMLWorkspaceHTMLImporter.importSources(from: source)
            package.indexHTML = imported.html
            if !imported.css.isEmpty {
                package.styleCSS = imported.css
            }
            if !imported.js.isEmpty {
                package.scriptJS = imported.js
            }
            if !imported.dataJSON.isEmpty {
                package.dataJSON = imported.dataJSON
            }
            if package.manifest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                package.manifest.title == "Untitled HTML Workspace" {
                package.manifest.title = url.deletingPathExtension().lastPathComponent
            }
            statusText = "HTML imported"
        } catch {
            statusText = failedStatus("Import", error: error)
        }
    }

    func exportHTML() {
        guard let destination = chooseHTMLDestination() else {
            statusText = "HTML export cancelled"
            return
        }
        do {
            let html = HTMLWorkspacePreviewDocument.render(
                package: package,
                theme: previewTheme,
                resourceMode: .inlinePackageAssets
            )
            try Data(html.utf8).write(to: destination, options: [.atomic])
            statusText = package.routes.isEmpty ? "HTML saved" : "HTML saved (index route only)"
        } catch {
            statusText = failedStatus("HTML export", error: error)
        }
    }

    func exportSiteFolder() {
        guard let destination = chooseSiteFolderDestination() else {
            statusText = "Site export cancelled"
            return
        }
        do {
            let summary = try HTMLWorkspaceSiteFolderExporter.export(
                package: package,
                theme: previewTheme,
                to: destination
            )
            statusText = summary.statusText
        } catch {
            statusText = failedStatus("Site export", error: error)
        }
    }

    func exportPDF() {
        guard !isExportingPDF else { return }
        guard let destination = choosePDFDestination() else {
            statusText = "PDF export cancelled"
            return
        }
        isExportingPDF = true
        statusText = "Exporting PDF"
        let exportPackage = package
        Task { @MainActor in
            defer { isExportingPDF = false }
            do {
                let data = try await HTMLWorkspacePDFExporter.export(package: exportPackage, theme: previewTheme)
                try data.write(to: destination, options: [.atomic])
                statusText = exportPackage.routes.isEmpty ? "PDF saved" : "PDF saved (index route only)"
            } catch {
                statusText = failedStatus("PDF export", error: error)
            }
        }
    }

    func failedStatus(_ action: String, error: Error) -> String {
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return "\(action) failed" }
        return "\(action) failed: \(detail)"
    }

    var selectedPaneSourceSnippet: String {
        sourceSnippet(for: selectedPane)
    }

    func documentSurface(for pane: HTMLWorkspaceSourcePane) -> DocumentSurface {
        DocumentSurface(
            id: package.manifest.id,
            kind: .htmlWorkspace,
            title: package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title,
            fileURL: currentHTMLWorkspaceDocument()?.fileURL,
            currentSelection: sourceRange(for: pane),
            capabilities: [.read, .write, .patch, .exportHTML, .exportPDF, .importContent, .preview],
            contentHash: contentHash
        )
    }

    func sourceSnippet(for pane: HTMLWorkspaceSourcePane) -> String {
        let source = sourceText(for: pane)
        guard source.count > 4_000 else { return source }
        return String(source.prefix(4_000))
    }

    func sourceRange(for pane: HTMLWorkspaceSourcePane) -> DocumentSourceRange {
        DocumentSourceRange.fullDocumentRange(for: sourceText(for: pane))
    }

    func sourceText(for pane: HTMLWorkspaceSourcePane) -> String {
        switch pane {
        case .html: package.indexHTML
        case .css: package.styleCSS
        case .js: package.scriptJS
        case .data: package.dataJSON
        case .routes: routeManifestText
        case .dom: domOutlineText
        case .assets: assetManifestText
        }
    }

    private func choosePDFDestination() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title)).pdf"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseHTMLDestination() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title)).html"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseSiteFolderDestination() -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(safeFileName(package.manifest.title.isEmpty ? "HTML Workspace" : package.manifest.title))-site"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "HTML Workspace" : cleaned
    }

    func currentHTMLWorkspaceDocument() -> HTMLWorkspaceDocument? {
        let documents = NSDocumentController.shared.documents.compactMap { $0 as? HTMLWorkspaceDocument }
        return documents.first { $0.package.manifest.id == package.manifest.id }
            ?? NSDocumentController.shared.currentDocument as? HTMLWorkspaceDocument
    }

}
