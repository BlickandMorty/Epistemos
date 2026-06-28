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
}
