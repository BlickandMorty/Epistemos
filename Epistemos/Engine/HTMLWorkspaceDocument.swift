import AppKit
import Foundation
import SwiftUI

nonisolated public struct HTMLWorkspaceChatContextSnapshot: Sendable, Equatable {
    public var workspaceID: String
    public var title: String
    public var contentHash: String
    public var sandboxPolicy: HTMLWorkspaceSandboxPolicy
    public var generationProvenance: HTMLWorkspaceGenerationProvenance?
    public var html: String
    public var css: String
    public var js: String
    public var dataJSON: String
    public var routes: [String: String]

    public init(
        workspaceID: String,
        title: String,
        contentHash: String,
        sandboxPolicy: HTMLWorkspaceSandboxPolicy,
        generationProvenance: HTMLWorkspaceGenerationProvenance? = nil,
        html: String,
        css: String,
        js: String,
        dataJSON: String,
        routes: [String: String] = [:]
    ) {
        self.workspaceID = workspaceID
        self.title = title
        self.contentHash = contentHash
        self.sandboxPolicy = sandboxPolicy
        self.generationProvenance = generationProvenance
        self.html = html
        self.css = css
        self.js = js
        self.dataJSON = dataJSON
        self.routes = routes
    }
}

@MainActor
private struct HTMLWorkspaceDocumentRoot: View {
    @Binding var package: HTMLWorkspacePackage
    let document: HTMLWorkspaceDocument
    @State private var packageRevision = 0

    var body: some View {
        Group {
            if let bootstrap = AppBootstrap.shared {
                HTMLWorkspaceDocumentThemedRoot(
                    package: $package,
                    packageRevision: packageRevision
                )
                    .withAppEnvironment(bootstrap)
            } else {
                HTMLWorkspaceEditorView(
                    package: $package,
                    theme: nil,
                    externalRevision: packageRevision
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .htmlWorkspacePackageDidChange)) { notification in
            guard let changedDocument = notification.object as? HTMLWorkspaceDocument,
                  changedDocument === document else {
                return
            }
            packageRevision &+= 1
        }
    }
}

@MainActor
private struct HTMLWorkspaceDocumentThemedRoot: View {
    @Environment(UIState.self) private var ui
    @Binding var package: HTMLWorkspacePackage
    let packageRevision: Int

    var body: some View {
        HTMLWorkspaceEditorView(
            package: $package,
            theme: ui.theme,
            externalRevision: packageRevision
        )
            .preferredColorScheme(ui.preferredColorScheme)
    }
}

public final class HTMLWorkspaceDocument: NSDocument, @unchecked Sendable {
    public var package: HTMLWorkspacePackage

    public override init() {
        self.package = HTMLWorkspacePackage.defaultPackage()
        super.init()
    }

    nonisolated public override class var autosavesInPlace: Bool { true }

    nonisolated public override class var preservesVersions: Bool { true }

    nonisolated public override class func isNativeType(_ type: String) -> Bool {
        type == "com.epistemos.html-workspace"
    }

    nonisolated public override func canAsynchronouslyWrite(
        to url: URL,
        ofType typeName: String,
        for saveOperation: NSDocument.SaveOperationType
    ) -> Bool { false }

    nonisolated public override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard typeName == "com.epistemos.html-workspace" else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadCorruptFileError,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognised type: \(typeName)"]
            )
        }

        do {
            let decoded = try HTMLWorkspacePackage(fileWrapper: fileWrapper)
            MainActor.assumeIsolated { self.package = decoded }
        } catch {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileReadCorruptFileError,
                userInfo: [
                    NSLocalizedDescriptionKey: "Couldn't open HTML Workspace package",
                    NSUnderlyingErrorKey: error,
                ]
            )
        }
    }

    nonisolated public override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        guard typeName == "com.epistemos.html-workspace" else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteUnsupportedSchemeError,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognised type: \(typeName)"]
            )
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let (snapshot, existingFileURL) = MainActor.assumeIsolated {
            (self.package, self.fileURL)
        }
        try Self.validateNoStarterTemplateOverwrite(snapshot: snapshot, existingFileURL: existingFileURL)
        var copy = snapshot
        copy.manifest = HTMLWorkspaceManifest(
            id: snapshot.manifest.id,
            schemaVersion: snapshot.manifest.schemaVersion,
            createdAt: snapshot.manifest.createdAt,
            updatedAt: now,
            title: snapshot.manifest.title,
            contentHash: Self.contentHash(
                indexHTML: snapshot.indexHTML,
                styleCSS: snapshot.styleCSS,
                scriptJS: snapshot.scriptJS,
                dataJSON: snapshot.dataJSON,
                routes: snapshot.routes,
                assets: snapshot.assets
            ),
            sandboxPolicy: snapshot.manifest.sandboxPolicy,
            dataFeed: snapshot.manifest.dataFeed,
            generationProvenance: snapshot.manifest.generationProvenance
        )
        return try copy.makeFileWrapper()
    }

    nonisolated private static func validateNoStarterTemplateOverwrite(
        snapshot: HTMLWorkspacePackage,
        existingFileURL: URL?
    ) throws {
        guard snapshot.isStarterTemplateContent,
              let existingFileURL,
              FileManager.default.fileExists(atPath: existingFileURL.path),
              let existingPackage = existingPackage(at: existingFileURL),
              !existingPackage.isStarterTemplateContent else {
            return
        }

        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteUnknownError,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Refusing to overwrite an existing HTML Workspace with the starter template. Reopen the workspace or use Save As if this reset was intentional."
            ]
        )
    }

    nonisolated private static func existingPackage(at url: URL) -> HTMLWorkspacePackage? {
        guard let wrapper = try? FileWrapper(url: url, options: [.immediate]) else {
            return nil
        }
        return try? HTMLWorkspacePackage(fileWrapper: wrapper)
    }

    nonisolated static func contentHash(
        indexHTML: String,
        styleCSS: String,
        scriptJS: String,
        dataJSON: String = "{}",
        routes: [String: String] = [:],
        assets: [String: Data] = [:]
    ) -> String {
        HTMLWorkspacePackageContentHasher.hash(
            indexHTML: indexHTML,
            styleCSS: styleCSS,
            scriptJS: scriptJS,
            dataJSON: dataJSON,
            routes: routes,
            assets: assets
        )
    }

    public func setPackage(_ package: HTMLWorkspacePackage) {
        self.package = package
        updateChangeCount(.changeDone)
        notifyPackageDidChange()
    }

    public func loadOpenedPackage(_ package: HTMLWorkspacePackage, fileURL: URL) {
        self.package = package
        self.fileURL = fileURL
        self.fileType = "com.epistemos.html-workspace"
        updateChangeCount(.changeCleared)
        notifyPackageDidChange()
    }

    public func applyPatch(_ operation: HTMLWorkspacePatchOperation) throws {
        setPackage(try HTMLWorkspacePatchApplier.apply(operation, to: package))
    }

    public func chatContextSnapshot(maxSourceCharacters: Int = 16_000) -> HTMLWorkspaceChatContextSnapshot {
        let currentContentHash = Self.contentHash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: package.dataJSON,
            routes: package.routes,
            assets: package.assets
        )
        return HTMLWorkspaceChatContextSnapshot(
            workspaceID: package.manifest.id,
            title: package.manifest.title,
            contentHash: currentContentHash,
            sandboxPolicy: package.manifest.sandboxPolicy,
            generationProvenance: package.manifest.generationProvenance,
            html: Self.truncated(package.indexHTML, maxCharacters: maxSourceCharacters),
            css: Self.truncated(package.styleCSS, maxCharacters: maxSourceCharacters),
            js: Self.truncated(package.scriptJS, maxCharacters: maxSourceCharacters),
            dataJSON: Self.truncated(package.dataJSON, maxCharacters: maxSourceCharacters),
            routes: Self.truncatedRoutes(package.routes, maxCharacters: maxSourceCharacters)
        )
    }

    nonisolated private static func truncated(_ value: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0, value.count > maxCharacters else { return value }
        return String(value.prefix(maxCharacters))
    }

    nonisolated private static func truncatedRoutes(
        _ routes: [String: String],
        maxCharacters: Int
    ) -> [String: String] {
        guard maxCharacters > 0, !routes.isEmpty else { return [:] }
        var remaining = maxCharacters
        var result: [String: String] = [:]
        for name in routes.keys.sorted() {
            guard remaining > 0 else {
                result[name] = "[omitted: route context budget exhausted]"
                continue
            }
            let value = routes[name, default: ""]
            let truncatedValue = truncated(value, maxCharacters: remaining)
            result[name] = truncatedValue
            remaining -= truncatedValue.count
        }
        return result
    }

    nonisolated public override func makeWindowControllers() {
        MainActor.assumeIsolated {
            let binding = Binding<HTMLWorkspacePackage>(
                get: { self.package },
                set: { [weak self] newPackage in
                    guard let self else { return }
                    self.setPackage(newPackage)
                }
            )
            let rootView = HTMLWorkspaceDocumentRoot(package: binding, document: self)
            let hostingController = NSHostingController(rootView: rootView)

            let contentController: NSViewController
            if let uiState = AppBootstrap.shared?.uiState {
                contentController = NoteWindowThemeStyler.themedContentController(
                    hostingController: hostingController,
                    uiState: uiState
                )
            } else {
                contentController = hostingController
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1320, height: 820),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = contentController
            window.title = self.package.manifest.title.isEmpty
                ? "HTML Workspace"
                : self.package.manifest.title
            window.minSize = NSSize(width: 980, height: 620)
            window.center()
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.styleMask.insert([.resizable, .titled, .closable, .miniaturizable, .fullSizeContentView])
            window.tabbingMode = .preferred
            window.tabbingIdentifier = NoteWindowManager.noteTabbingIdentifier
            NoteWindowChrome.apply(to: window, toolbarIdentifier: "HTMLWorkspaceDocument")
            if let uiState = AppBootstrap.shared?.uiState {
                NoteWindowThemeStyler.apply(to: window, uiState: uiState)
            }
            window.setFrameAutosaveName("HTMLWorkspaceDocumentWindow.\(self.package.manifest.id)")

            let windowController = NSWindowController(window: window)
            self.addWindowController(windowController)
        }
    }

    private func notifyPackageDidChange() {
        NotificationCenter.default.post(
            name: .htmlWorkspacePackageDidChange,
            object: self,
            userInfo: ["workspaceID": package.manifest.id]
        )
    }
}

extension Notification.Name {
    static let htmlWorkspacePackageDidChange = Notification.Name("htmlWorkspacePackageDidChange")
}
