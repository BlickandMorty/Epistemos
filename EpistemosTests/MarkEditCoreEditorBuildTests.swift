import Foundation
import Testing

@Suite("MarkEdit CoreEditor build integration (Plan 2 Stage 5)")
nonisolated struct MarkEditCoreEditorBuildTests {
    @Test("CoreEditor bundle script builds from vendored MarkEdit and stages static resources")
    func coreEditorBundleScriptBuildsVendoredStaticResources() throws {
        let script = try loadMirroredSourceTextFile("build-coreeditor-bundle.sh")

        #expect(script.contains("LocalPackages/MarkEdit/CoreEditor"))
        #expect(script.contains("Epistemos/Resources/CoreEditor"))
        #expect(script.contains("yarn.lock"))
        #expect(script.contains("node \"$YARN_CLI\" install --immutable"))
        #expect(script.contains("node \"$YARN_CLI\" build"))
        #expect(script.contains("rsync -a --delete dist/ \"$DEST/\""))
        #expect(script.contains("dist/index.html"))
        #expect(script.contains("dist/chunks"))
        #expect(!script.contains("npm install"))
        #expect(!script.contains("npm run"))
    }

    @Test("project spec wires CoreEditor bundle after TipTap and mirrors the script")
    func projectSpecWiresCoreEditorBuild() throws {
        let projectYAML = try loadMirroredSourceTextFile("project.yml")

        #expect(projectYAML.contains("bash \\\"${SRCROOT}/build-tiptap-bundle.sh\\\" && bash \\\"${SRCROOT}/build-coreeditor-bundle.sh\\\""))
        #expect(projectYAML.contains("copy_file \"build-coreeditor-bundle.sh\""))
    }

    @Test("CoreEditor vendor config stays deterministic for build-time bundling")
    func coreEditorVendorConfigStaysDeterministic() throws {
        let package = try loadMirroredSourceTextFile("LocalPackages/MarkEdit/CoreEditor/package.json")
        let yarnrc = try loadMirroredSourceTextFile("LocalPackages/MarkEdit/CoreEditor/.yarnrc.yml")
        let viteConfig = try loadMirroredSourceTextFile("LocalPackages/MarkEdit/CoreEditor/vite.config.mts")

        #expect(package.contains(#""packageManager": "yarn@4.15.0""#))
        #expect(package.contains(#""build": "yarn lint && yarn codegen && vite build && vite build -c src/@light/vite.config.mts""#))
        #expect(yarnrc.contains("nodeLinker: node-modules"))
        #expect(yarnrc.contains("yarnPath: .yarn/releases/yarn-4.15.0.cjs"))
        #expect(viteConfig.contains("base: command === 'build' ? '/chunk-loader/' : ''"))
        #expect(viteConfig.contains("assetsDir: 'chunks'"))
    }

    @Test("Generated CoreEditor HTML points at staged chunks that the WK scheme loader can serve")
    func generatedCoreEditorHTMLReferencesExistingStagedChunks() throws {
        let html = try loadMirroredSourceTextFile("Epistemos/Resources/CoreEditor/index.html")
        let runtime = try loadMirroredSourceTextFile("Epistemos/Views/Notes/MarkEditCoreEditorRuntimeResources.swift")
        let references = Self.chunkReferences(in: html)

        #expect(!references.isEmpty)
        #expect(html.contains("/chunk-loader/chunks/"))
        #expect(runtime.contains(#".replacingOccurrences(of: "/chunk-loader/", with: "\(MarkEditCoreEditorBridge.chunkScheme)://")"#))
        #expect(runtime.contains("subdirectory: MarkEditCoreEditorBridge.resourceSubpath"))

        for reference in references {
            #expect(
                repoFileExists("Epistemos/Resources/CoreEditor/\(reference)"),
                "Missing CoreEditor resource: \(reference)"
            )
            #expect(
                repoFileExists("Epistemos/Resources/\(reference)"),
                "Missing fallback chunk resource: \(reference)"
            )
        }
    }

    private static func chunkReferences(in html: String) -> [String] {
        html.components(separatedBy: "\"")
            .filter { $0.hasPrefix("/chunk-loader/chunks/") }
            .map { String($0.dropFirst("/chunk-loader/".count)) }
    }

    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func repoFileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: repoRootURL.appendingPathComponent(relativePath).path
        )
    }
}
