import AppKit
import CryptoKit
import Foundation
import SwiftUI

nonisolated public struct HTMLWorkspaceChatContextSnapshot: Sendable, Equatable {
    public var workspaceID: String
    public var title: String
    public var contentHash: String
    public var sandboxPolicy: HTMLWorkspaceSandboxPolicy
    public var html: String
    public var css: String
    public var js: String
    public var dataJSON: String

    public init(
        workspaceID: String,
        title: String,
        contentHash: String,
        sandboxPolicy: HTMLWorkspaceSandboxPolicy,
        html: String,
        css: String,
        js: String,
        dataJSON: String
    ) {
        self.workspaceID = workspaceID
        self.title = title
        self.contentHash = contentHash
        self.sandboxPolicy = sandboxPolicy
        self.html = html
        self.css = css
        self.js = js
        self.dataJSON = dataJSON
    }
}

@MainActor
private struct HTMLWorkspaceDocumentRoot: View {
    @Binding var package: HTMLWorkspacePackage

    var body: some View {
        if let bootstrap = AppBootstrap.shared {
            HTMLWorkspaceDocumentThemedRoot(package: $package)
                .withAppEnvironment(bootstrap)
        } else {
            HTMLWorkspaceEditorView(package: $package, theme: nil)
        }
    }
}

@MainActor
private struct HTMLWorkspaceDocumentThemedRoot: View {
    @Environment(UIState.self) private var ui
    @Binding var package: HTMLWorkspacePackage

    var body: some View {
        HTMLWorkspaceEditorView(package: $package, theme: ui.theme.surfaceVariant(.other))
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
                dataJSON: snapshot.dataJSON
            ),
            sandboxPolicy: snapshot.manifest.sandboxPolicy,
            dataFeed: snapshot.manifest.dataFeed
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
        dataJSON: String = "{}"
    ) -> String {
        var data = Data()
        data.append(Data(indexHTML.utf8))
        data.append(0)
        data.append(Data(styleCSS.utf8))
        data.append(0)
        data.append(Data(scriptJS.utf8))
        data.append(0)
        data.append(Data(dataJSON.utf8))
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
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
        HTMLWorkspaceChatContextSnapshot(
            workspaceID: package.manifest.id,
            title: package.manifest.title,
            contentHash: Self.contentHash(
                indexHTML: package.indexHTML,
                styleCSS: package.styleCSS,
                scriptJS: package.scriptJS,
                dataJSON: package.dataJSON
            ),
            sandboxPolicy: package.manifest.sandboxPolicy,
            html: Self.truncated(package.indexHTML, maxCharacters: maxSourceCharacters),
            css: Self.truncated(package.styleCSS, maxCharacters: maxSourceCharacters),
            js: Self.truncated(package.scriptJS, maxCharacters: maxSourceCharacters),
            dataJSON: Self.truncated(package.dataJSON, maxCharacters: maxSourceCharacters)
        )
    }

    nonisolated private static func truncated(_ value: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0, value.count > maxCharacters else { return value }
        return String(value.prefix(maxCharacters))
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
            let rootView = HTMLWorkspaceDocumentRoot(package: binding)
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
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 720),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = contentController
            window.title = self.package.manifest.title.isEmpty
                ? "HTML Workspace"
                : self.package.manifest.title
            window.minSize = NSSize(width: 520, height: 360)
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
