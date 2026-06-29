import Foundation
import Testing

@Suite("MarkEdit full chrome wiring guards (Plan 2)")
nonisolated struct MarkEditFullChromeWiringTests {
    @Test("Epistemos supplies the removed MarkEdit shell compatibility seam")
    func epistemosSuppliesRemovedMarkEditShellCompatibilitySeam() throws {
        let shim = try loadMirroredSourceTextFile("Epistemos/MarkEdit/MarkEditShellCompatibility.swift")
        let vendorManifest = try loadMirroredSourceTextFile("LocalPackages/MarkEdit/EPISTEMOS_VENDOR_MARKEDIT.txt")
        let appDelegateURL = try sourceMirrorURL(
            for: "LocalPackages/MarkEdit/MarkEditMac/Sources/Main/Application/AppDelegate.swift"
        )
        let documentControllerURL = try sourceMirrorURL(
            for: "LocalPackages/MarkEdit/MarkEditMac/Sources/Main/AppDocumentController.swift"
        )

        #expect(vendorManifest.contains("MarkEditMac/Sources/Main/Application"))
        #expect(vendorManifest.contains("MarkEditMac/Sources/Main/AppDocumentController.swift"))
        #expect(!FileManager.default.fileExists(atPath: appDelegateURL.path))
        #expect(!FileManager.default.fileExists(atPath: documentControllerURL.path))

        #expect(shim.contains("#if canImport(MarkEditKit)"))
        #expect(shim.contains("typealias AppDelegate = EpistemosAppDelegate"))
        #expect(shim.contains("enum AppDocumentController"))
        #expect(shim.contains("suggestedFilename"))
        #expect(shim.contains("suggestedTextEncoding"))
        #expect(shim.contains("extension EpistemosAppDelegate"))
        #expect(shim.contains("mainExtensionsMenu"))
        #expect(shim.contains("formatHeadersMenu"))
        #expect(shim.contains("textFormatMenu"))
        #expect(shim.contains("func createNewFile("))
    }

    @Test("project.yml wires MarkEdit full chrome source and module products")
    func projectYMLWiresMarkEditFullChromeSourceAndModuleProducts() throws {
        let project = try loadMirroredSourceTextFile("project.yml")

        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditMac/Sources"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditMac/Resources"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditMac/Base.lproj"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditMac/mul.lproj"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditMac/AppShortcuts.xcstrings"))

        #expect(project.contains("MarkEditCore:"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditCore"))
        #expect(project.contains("MarkEditKit:"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditKit"))
        #expect(project.contains("MarkEditModules:"))
        #expect(project.contains("path: LocalPackages/MarkEdit/MarkEditMac/Modules"))

        for product in [
            "AppKitControls",
            "AppKitExtensions",
            "FileDrop",
            "FileVersion",
            "FontPicker",
            "Previewer",
            "SettingsUI",
            "Statistics",
            "TextBundle",
            "TextCompletion",
        ] {
            #expect(project.contains("product: \(product)"))
        }
    }

    @Test("CoreEditor build script stages resources for Epistemos and verbatim MarkEdit chunk loaders")
    func coreEditorBuildScriptStagesResourcesForBothChunkLoaders() throws {
        let script = try loadMirroredSourceTextFile("build-coreeditor-bundle.sh")
        let markEditChunkLoader = try loadMirroredSourceTextFile(
            "LocalPackages/MarkEdit/MarkEditMac/Sources/Editor/EditorChunkLoader.swift"
        )

        #expect(script.contains(#"DEST="${ROOT_DIR}/Epistemos/Resources/CoreEditor""#))
        #expect(script.contains(#"ROOT_CHUNKS_DEST="${ROOT_DIR}/Epistemos/Resources/chunks""#))
        #expect(script.contains(#"rsync -a --delete dist/ "$DEST/""#))
        #expect(script.contains(#"rsync -a --delete dist/chunks/ "$ROOT_CHUNKS_DEST/""#))
        #expect(markEditChunkLoader.contains(#"Bundle.main.url(forResource: "\(host)/\(url.path())", withExtension: nil)"#))
    }
}
