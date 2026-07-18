import Foundation
import Testing

@Suite("MarkEdit full chrome wiring guards (Plan 2)")
nonisolated struct MarkEditFullChromeWiringTests {
    @Test("Epistemos physically removes the retired MarkEdit shell compatibility seam")
    func epistemosRemovesRetiredMarkEditShellCompatibilitySeam() throws {
        let project = try loadMirroredSourceTextFile("project.yml")
        let generatedProject = try loadMirroredSourceTextFile("Epistemos.xcodeproj/project.pbxproj")
        let shimURL = try sourceMirrorURL(for: "Epistemos/MarkEdit/MarkEditShellCompatibility.swift")
        let vendorManifest = try loadMirroredSourceTextFile("LocalPackages/MarkEdit/EPISTEMOS_VENDOR_MARKEDIT.txt")
        let appDelegateURL = try sourceMirrorURL(
            for: "LocalPackages/MarkEdit/MarkEditMac/Sources/Main/Application/AppDelegate.swift"
        )
        let documentControllerURL = try sourceMirrorURL(
            for: "LocalPackages/MarkEdit/MarkEditMac/Sources/Main/AppDocumentController.swift"
        )

        #expect(vendorManifest.contains("MarkEditMac/Sources/Main/Application"))
        #expect(vendorManifest.contains("MarkEditMac/Sources/Main/AppDocumentController.swift"))
        #expect(!FileManager.default.fileExists(atPath: shimURL.path))
        #expect(!project.contains("MarkEdit/MarkEditShellCompatibility.swift"))
        #expect(!generatedProject.contains("MarkEdit/MarkEditShellCompatibility.swift"))
        #expect(!FileManager.default.fileExists(atPath: appDelegateURL.path))
        #expect(!FileManager.default.fileExists(atPath: documentControllerURL.path))
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

    @Test("CoreEditor build and runtime scripts keep one canonical source tree plus MarkEdit flat chunk fallback")
    func coreEditorBuildScriptStagesResourcesForBothChunkLoaders() throws {
        let script = try loadMirroredSourceTextFile("build-coreeditor-bundle.sh")
        let bundler = try loadMirroredSourceTextFile("bundle-app-runtime-assets.sh")
        let markEditChunkLoader = try loadMirroredSourceTextFile(
            "LocalPackages/MarkEdit/MarkEditMac/Sources/Editor/EditorChunkLoader.swift"
        )

        #expect(script.contains(#"DEST="${ROOT_DIR}/Epistemos/Resources/CoreEditor""#))
        #expect(script.contains(#"rsync -a --delete dist/ "$DEST/""#))
        #expect(!script.contains("ROOT_CHUNKS_DEST"))
        #expect(bundler.contains("CORE_EDITOR_CHUNKS_SOURCE_DIR=\"$SRCROOT/Epistemos/Resources/CoreEditor/chunks\""))
        #expect(bundler.contains("CORE_EDITOR_CHUNKS_BUNDLE_DIR=\"$RESOURCES_DIR/chunks\""))
        #expect(bundler.contains("rsync -a --delete \"$CORE_EDITOR_CHUNKS_SOURCE_DIR/\" \"$CORE_EDITOR_CHUNKS_BUNDLE_DIR/\""))
        #expect(markEditChunkLoader.contains(#"Bundle.main.url(forResource: "\(host)/\(url.path())", withExtension: nil)"#))
        #expect(markEditChunkLoader.contains("url.lastPathComponent"))

        let project = try loadMirroredSourceTextFile("project.yml")
        let epistemosChunkLoader = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift"
        )
        #expect(project.contains("CoreEditor/chunks/**"))
        #expect(project.contains("Resources/CoreEditor/chunks/**"))
        #expect(epistemosChunkLoader.contains("Bundle.main.url(forResource: filename, withExtension: nil)"))
        #expect(epistemosChunkLoader.contains(#"Bundle.main.url(forResource: "index", withExtension: "html")"#))
    }

    @Test("built app bundle includes CoreEditor HTML and flat chunk fallback resources")
    func builtAppBundleIncludesCoreEditorHTMLAndFlatChunkFallbackResources() throws {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") else {
            throw MarkEditFullChromeWiringTestError.missingBundleResource("index.html")
        }

        let html = try String(contentsOf: indexURL, encoding: .utf8)
        #expect(html.contains(#"window.config = "{{EDITOR_CONFIG}}";"#))

        let chunkReferences = Self.chunkReferences(in: html)
        #expect(!chunkReferences.isEmpty)
        #expect(chunkReferences.contains { $0.hasSuffix(".js") })
        #expect(chunkReferences.contains { $0.hasSuffix(".css") })
        #expect(chunkReferences.contains { $0.hasSuffix(".woff2") })

        for reference in chunkReferences {
            let filename = URL(fileURLWithPath: reference).lastPathComponent
            guard Bundle.main.url(forResource: filename, withExtension: nil) != nil else {
                throw MarkEditFullChromeWiringTestError.missingBundleResource(filename)
            }
        }
    }

    private static func chunkReferences(in html: String) -> [String] {
        let marker = "/chunk-loader/"
        var references = Set<String>()
        var remainder = html[...]

        while let markerRange = remainder.range(of: marker) {
            let start = markerRange.upperBound
            let tail = remainder[start...]
            let end = tail.firstIndex { character in
                character == "\"" ||
                    character == "'" ||
                    character == ")" ||
                    character.isWhitespace
            } ?? tail.endIndex
            references.insert(String(tail[..<end]))
            remainder = tail[end...]
        }

        return references.sorted()
    }
}

private enum MarkEditFullChromeWiringTestError: Error, CustomStringConvertible {
    case missingBundleResource(String)

    var description: String {
        switch self {
        case .missingBundleResource(let resource):
            return "Missing MarkEdit CoreEditor bundle resource: \(resource)"
        }
    }
}
