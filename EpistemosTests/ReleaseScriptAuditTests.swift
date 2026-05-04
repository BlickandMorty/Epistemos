import Foundation
import Testing

@Suite("Release Script Audit")
struct ReleaseScriptAuditTests {
    @Test("public release preflight checks shipping bundle requirements")
    func publicReleasePreflightChecksShippingBundleRequirements() throws {
        let script = try loadReleaseScript("scripts/release/release_preflight.sh")

        #expect(script.contains("libepistemos_core.dylib"))
        #expect(script.contains("libomega_mcp.dylib"))
        #expect(script.contains("libomega_ax.dylib"))
        #expect(script.contains("model_manifest.json"))
        #expect(script.contains("RetroGaming.ttf"))
        #expect(script.contains("KnowledgeFusion/Training/scripts/train_knowledge.py"))
        #expect(script.contains("KnowledgeFusion/Training/scripts/train_style.py"))
        #expect(script.contains("KnowledgeFusion/Alignment/scripts/train_kto.py"))
        #expect(script.contains("KnowledgeFusion/MoLoRA/molora_inference.py"))
        #expect(script.contains("KnowledgeFusion/MoLoRA/sgmm_kernel.py"))
        #expect(script.contains("KnowledgeFusion/MOHAWK/eval_bfcl.py"))
        #expect(script.contains("KnowledgeFusion/MOHAWK/embodied_data/bfcl_eval_macos.jsonl"))
        #expect(script.contains("Contents/PlugIns"))
        #expect(script.contains("codesign --verify --deep --strict"))
    }

    @Test("release scripts cover build dmg and notarization stages")
    func releaseScriptsCoverBuildDMGAndNotarizationStages() throws {
        let build = try loadReleaseScript("scripts/release/build_release_app.sh")
        let dmg = try loadReleaseScript("scripts/release/create_release_dmg.sh")
        let notarize = try loadReleaseScript("scripts/release/notarize_release_dmg.sh")

        #expect(build.contains("xcodebuild"))
        #expect(build.contains("Developer ID Application"))
        #expect(build.contains("codesign"))
        #expect(build.contains("release_preflight.sh"))
        #expect(build.contains("PACKAGE_ARGS=()"))
        #expect(build.contains("<xcode-managed default>"))
        #expect(dmg.contains("hdiutil create"))
        #expect(dmg.contains("hdiutil convert"))
        #expect(dmg.contains("codesign"))
        #expect(dmg.contains("spctl"))
        #expect(notarize.contains("xcrun notarytool submit"))
        #expect(notarize.contains("xcrun stapler staple"))
        #expect(notarize.contains("xcrun stapler validate"))
        #expect(notarize.contains("xcrun notarytool log"))
        #expect(!notarize.contains("mapfile -t AUTH_ARGS"))
    }

    @Test("Tiptap bundle script prunes production-only duplicate editor assets")
    func tiptapBundleScriptPrunesProductionDuplicateAssets() throws {
        let script = try loadReleaseScript("build-tiptap-bundle.sh")

        #expect(script.contains("prune_production_editor_bundle"))
        #expect(script.contains("name '*.br'"))
        #expect(script.contains("plain=\"${compressed%.br}\""))
        #expect(script.contains("rm -f \"$plain\""))
        #expect(script.contains("vendor/katex/fonts"))
        #expect(script.contains("name '*.ttf'"))
        #expect(script.contains("name '*.woff'"))
        #expect(script.contains("EPISTEMOS_TIPTAP_DEVELOPMENT"))
    }

    @Test("runtime asset bundler preserves the canonical Editor resource tree")
    func runtimeAssetBundlerPreservesCanonicalEditorResourceTree() throws {
        let script = try loadReleaseScript("bundle-app-runtime-assets.sh")

        #expect(script.contains("EDITOR_SOURCE_DIR=\"$SRCROOT/Epistemos/Resources/Editor\""))
        #expect(script.contains("EDITOR_BUNDLE_DIR=\"$RESOURCES_DIR/Editor\""))
        #expect(script.contains("bundle_editor_resources"))
        #expect(script.contains("rsync -a --delete \"$EDITOR_SOURCE_DIR/\" \"$EDITOR_BUNDLE_DIR/\""))
        #expect(script.contains("find \"$EDITOR_SOURCE_DIR\" -type f -print0"))
        #expect(script.contains("rm -f \"$RESOURCES_DIR/$(basename \"$source_file\")\""))
        #expect(script.contains("bundle_editor_resources\n\nif is_app_store_build"))
    }

    @Test("xcodebuild helper mirrors explicit local sweep overrides into hosted test fallback")
    func xcodebuildHelperMirrorsLocalSweepOverrideFile() throws {
        let script = try loadReleaseScript("scripts/xcodebuild_epistemos.sh")

        #expect(script.contains("EPI_LOCAL_MODEL_SWEEP_MODELS"))
        #expect(script.contains("/tmp/epi-local-model-sweep-models.txt"))
        #expect(script.contains("cleanup_model_sweep_override"))
        #expect(script.contains("cleanup_xcodebuild_wrapper_state"))
        #expect(script.contains("trap cleanup_xcodebuild_wrapper_state EXIT"))
    }

    @Test("xcodebuild helper cleans stale DerivedData Epistemos test apps around local model sweeps")
    func xcodebuildHelperCleansSweepTestAppProcesses() throws {
        let script = try loadReleaseScript("scripts/xcodebuild_epistemos.sh")

        #expect(script.contains("LocalModelReleaseSweepTests"))
        #expect(script.contains("cleanup_deriveddata_epistemos_processes"))
        #expect(script.contains("DerivedData"))
        #expect(script.contains("Epistemos\\.app\\/Contents\\/MacOS\\/Epistemos"))
    }

    @Test("xcodebuild helper resolves packages before the main build invocation")
    func xcodebuildHelperResolvesPackagesBeforeBuild() throws {
        let script = try loadReleaseScript("scripts/xcodebuild_epistemos.sh")

        #expect(script.contains("resolve_package_dependencies"))
        #expect(script.contains("resolve_args"))
        #expect(script.contains("-resolvePackageDependencies"))
    }

    @Test("xcodebuild helper package resolution mode does not crash when extra args stay empty")
    func xcodebuildHelperPackageResolutionModeDoesNotCrashWhenExtraArgsStayEmpty() throws {
        let result = try runMirroredScript(
            "scripts/xcodebuild_epistemos.sh",
            arguments: [
                "-project", "Epistemos.xcodeproj",
                "-scheme", "Epistemos",
                "-derivedDataPath", "DerivedData",
                "-resolvePackageDependencies",
            ],
            stubCommands: [
                "xcodebuild": """
                #!/bin/bash
                printf 'xcodebuild:%s\\n' "$*" >> "$TMP_CAPTURE"
                exit 0
                """
            ]
        )

        #expect(result.terminationStatus == 0, "stderr: \(result.stderr)")
        #expect(!result.stderr.contains("unbound variable"), "stderr: \(result.stderr)")
        #expect(result.invocationLog.contains("xcodebuild:-project Epistemos.xcodeproj -scheme Epistemos -derivedDataPath"))
        #expect(result.invocationLog.contains("-resolvePackageDependencies"))
    }

    @Test("run_swift_tests entrypoint does not crash when package args stay empty")
    func runSwiftTestsEntrypointDoesNotCrashWhenPackageArgsStayEmpty() throws {
        let result = try runMirroredScript(
            "scripts/run_swift_tests.sh",
            stubCommands: [
                "xcodebuild": """
                #!/bin/bash
                printf 'xcodebuild:%s\\n' "$*" >> "$TMP_CAPTURE"
                exit 0
                """
            ]
        )

        #expect(result.terminationStatus == 0, "stderr: \(result.stderr)\nstdout: \(result.stdout)")
        #expect(!result.stderr.contains("unbound variable"), "stderr: \(result.stderr)")
        #expect(result.invocationLog.contains("xcodebuild:build-for-testing"))
        #expect(result.invocationLog.contains("xcodebuild:test-without-building"))
    }

    @Test("ci_test entrypoint does not crash when package args stay empty")
    func ciTestEntrypointDoesNotCrashWhenPackageArgsStayEmpty() throws {
        let result = try runMirroredScript(
            "scripts/ci_test.sh",
            stubCommands: [
                "cargo": """
                #!/bin/bash
                printf 'cargo:%s\\n' "$*" >> "$TMP_CAPTURE"
                if [ "${1:-}" = "test" ]; then
                    echo 'test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out'
                fi
                exit 0
                """,
                "xcodebuild": """
                #!/bin/bash
                printf 'xcodebuild:%s\\n' "$*" >> "$TMP_CAPTURE"
                exit 0
                """
            ]
        )

        #expect(result.terminationStatus == 0, "stderr: \(result.stderr)\nstdout: \(result.stdout)")
        #expect(!result.stderr.contains("unbound variable"), "stderr: \(result.stderr)")
        #expect(result.invocationLog.contains("cargo:build --quiet"))
        #expect(result.invocationLog.contains("cargo:test"))
        #expect(result.invocationLog.contains("xcodebuild:build-for-testing"))
        #expect(result.invocationLog.contains("xcodebuild:test-without-building"))
    }

    @Test("notarize release dmg entrypoint stays portable on macOS bash 3.2")
    func notarizeReleaseDMGEntrypointStaysPortableOnMacOSBash32() throws {
        let result = try runMirroredScript(
            "scripts/release/notarize_release_dmg.sh",
            stubCommands: [
                "xcrun": """
                #!/bin/bash
                printf 'xcrun:%s\\n' "$*" >> "$TMP_CAPTURE"
                if [ "${1:-}" = "notarytool" ] && [ "${2:-}" = "submit" ]; then
                    printf '{"id":"submission-123"}'
                fi
                exit 0
                """,
                "spctl": """
                #!/bin/bash
                printf 'spctl:%s\\n' "$*" >> "$TMP_CAPTURE"
                exit 0
                """
            ],
            environment: ["EPISTEMOS_NOTARY_PROFILE": "AuditProfile"],
            argumentsBuilder: { tempDirectory in
                let dmgURL = tempDirectory.appendingPathComponent("Epistemos.dmg")
                FileManager.default.createFile(atPath: dmgURL.path, contents: Data())
                return [dmgURL.path, tempDirectory.appendingPathComponent("logs").path]
            }
        )

        #expect(result.terminationStatus == 0, "stderr: \(result.stderr)\nstdout: \(result.stdout)")
        #expect(!result.stderr.contains("mapfile: command not found"), "stderr: \(result.stderr)")
        #expect(result.invocationLog.contains("xcrun:notarytool submit"))
        #expect(result.invocationLog.contains("xcrun:notarytool log"))
        #expect(result.invocationLog.contains("xcrun:stapler staple"))
        #expect(result.invocationLog.contains("spctl:-a -vv -t open"))
    }

    @Test("xcodebuild helper hardens package plugin and result bundle defaults for release verification")
    func xcodebuildHelperHardensPluginAndResultBundleDefaults() throws {
        let script = try loadReleaseScript("scripts/xcodebuild_epistemos.sh")

        #expect(script.contains("export DISABLE_SWIFTLINT=1"))
        #expect(script.contains("-disableAutomaticPackageResolution"))
        #expect(script.contains("-onlyUsePackageVersionsFromResolvedFile"))
        #expect(script.contains("-skipPackagePluginValidation"))
        #expect(script.contains("-skipMacroValidation"))
        #expect(script.contains("-hideShellScriptEnvironment"))
        #expect(script.contains("-collect-test-diagnostics"))
        #expect(script.contains("\"never\""))
        #expect(script.contains("-resultBundlePath"))
        #expect(script.contains("build/xcode-results"))
    }

    @Test("swift verification entrypoints route through the repo xcodebuild wrapper")
    func swiftVerificationEntrypointsRouteThroughRepoXcodebuildWrapper() throws {
        let scripts = try [
            loadReleaseScript("scripts/ci_test.sh"),
            loadReleaseScript("scripts/run_all_tests.sh"),
            loadReleaseScript("scripts/run_swift_tests.sh"),
            loadReleaseScript("scripts/run_quick_test.sh"),
            loadReleaseScript("scripts/run_performance_tests.sh"),
            loadReleaseScript("scripts/run_memory_leak_tests.sh"),
            loadReleaseScript("scripts/run_stability_tests.sh"),
            loadReleaseScript("scripts/run_chaos_tests.sh"),
            loadReleaseScript("scripts/run_reliability_quality_gates.sh"),
            loadReleaseScript("scripts/verify/omega_verify.sh"),
        ]

        for script in scripts {
            #expect(script.contains("scripts/xcodebuild_epistemos.sh"))
            #expect(script.contains("CODE_SIGNING_ALLOWED=NO"))
            #expect(script.contains("-derivedDataPath"))
        }
    }

    @Test("release workflow fails closed when dmg creation breaks")
    func releaseWorkflowFailsClosedWhenDMGCreationBreaks() throws {
        let workflow = try loadReleaseScript(".github/workflows/release.yml")

        #expect(workflow.contains("create-dmg"))
        #expect(!workflow.contains("\"build/Epistemos.app\" || true"))
        #expect(workflow.contains("softprops/action-gh-release@v2"))
    }

    @Test("release workflow uses the repo xcodebuild wrapper instead of a stale pinned Xcode path")
    func releaseWorkflowUsesRepoXcodebuildWrapper() throws {
        let workflow = try loadReleaseScript(".github/workflows/release.yml")

        #expect(workflow.contains("./scripts/xcodebuild_epistemos.sh"))
        #expect(!workflow.contains("DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer"))
        #expect(!workflow.contains("| xcpretty --color"))
    }

    @Test("ci workflow uses the repo xcodebuild wrapper for deterministic Swift verification")
    func ciWorkflowUsesRepoXcodebuildWrapperForSwiftVerification() throws {
        let workflow = try loadReleaseScript(".github/workflows/ci.yml")

        #expect(workflow.contains("./scripts/xcodebuild_epistemos.sh"))
        #expect(workflow.contains("-resolvePackageDependencies"))
        #expect(workflow.contains("build-for-testing"))
        #expect(workflow.contains("test-without-building"))
        #expect(workflow.contains("-derivedDataPath .derived-data-ci"))
        #expect(!workflow.contains("DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer"))
        #expect(!workflow.contains("| xcpretty --color"))
    }

    @Test("release workflow gates signing and notarization directly on secrets")
    func releaseWorkflowGatesSigningAndNotarizationDirectlyOnSecrets() throws {
        let workflow = try loadReleaseScript(".github/workflows/release.yml")

        #expect(workflow.contains("if: ${{ secrets.DEVELOPER_ID_APPLICATION != '' }}"))
        #expect(workflow.contains("if: ${{ secrets.APPLE_ID != '' && secrets.NOTARIZATION_PASSWORD != '' && secrets.TEAM_ID != '' }}"))
        #expect(workflow.contains("xcrun stapler staple"))
        #expect(!workflow.contains("if: env.DEVELOPER_ID_APPLICATION != ''"))
        #expect(!workflow.contains("if: env.APPLE_ID != '' && env.NOTARIZATION_PASSWORD != ''"))
        #expect(!workflow.contains("if: env.APPLE_ID != ''"))
    }

    @Test("release workflow provisions universal rust targets and agent core bindings")
    func releaseWorkflowProvisionsUniversalRustTargetsAndAgentCoreBindings() throws {
        let workflow = try loadReleaseScript(".github/workflows/release.yml")

        #expect(workflow.contains("targets: aarch64-apple-darwin, x86_64-apple-darwin"))
        #expect(workflow.contains("cargo build --target \"$target\" --release"))
        #expect(workflow.contains("bash build-agent-core.sh"))
    }

    @Test("strict verify gate targets localhost model transport residue without flagging valid cloud paths")
    func strictVerifyGateTargetsLegacyLocalTransportOnly() throws {
        let script = try loadReleaseScript("scripts/audit/verify.sh")

        #expect(script.contains("LocalSidecarClient"))
        #expect(script.contains("mlx-openai-server"))
        #expect(script.contains("http://127\\.0\\.0\\.1(?::[0-9]+)?/v1/"))
        #expect(!script.contains("|http://127\\.0\\.0\\.1|"))
        #expect(!script.contains("|/v1/models|"))
        #expect(!script.contains("|DeepSeek|"))
    }

    @Test("strict verify uses no-sign local Xcode validation")
    func strictVerifyUsesNoSignXcodeValidation() throws {
        let script = try loadReleaseScript("scripts/audit/verify.sh")

        #expect(script.contains("CODE_SIGNING_ALLOWED=NO"))
        #expect(script.contains("-configuration Release"))
        #expect(script.contains("strict-concurrency=complete"))
        #expect(script.contains("-only-testing:EpistemosTests/RuntimeValidationTests"))
        #expect(script.contains("RUNTIME_TEST_RESULT_BUNDLE_PATH"))
        #expect(script.contains("-derivedDataPath '${DERIVED_DATA_PATH}'"))
        #expect(script.contains("-resultBundlePath '${RUNTIME_TEST_RESULT_BUNDLE_PATH}'"))
        #expect(script.contains("xcresulttool get object --legacy"))
    }

    @Test("audit preflight isolates hosted tests from the bundle it verifies")
    func auditPreflightIsolatesHostedTestsFromBundleVerification() throws {
        let script = try loadReleaseScript("scripts/audit/release_preflight.sh")

        #expect(script.contains("TEST_DERIVED_DATA_PATH"))
        #expect(script.contains("TEST_APP_PATH"))
        #expect(script.contains("-derivedDataPath \"$TEST_DERIVED_DATA_PATH\""))
        #expect(script.contains("codesign --verify --deep --strict --verbose=4 \"$APP_PATH\""))
        #expect(!script.contains("-derivedDataPath \"$DERIVED_DATA_PATH\" \\\n    -destination 'platform=macOS' \\\n    test"))
    }

    @Test("mlx swift lm stays vendored in repo with the epistemos runtime patches")
    func mlxSwiftLMPackageStaysVendoredAndPatched() throws {
        let projectYAML = try loadReleaseScript("project.yml")
        let pbxproj = try loadReleaseScript("Epistemos.xcodeproj/project.pbxproj")
        let chatSession = try loadReleaseScript("LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/ChatSession.swift")
        let llmModelFactory = try loadReleaseScript("LocalPackages/mlx-swift-lm/Libraries/MLXLLM/LLMModelFactory.swift")

        #expect(projectYAML.contains("path: LocalPackages/mlx-swift-lm"))
        #expect(!projectYAML.contains("url: https://github.com/ml-explore/mlx-swift-lm"))
        #expect(pbxproj.contains("XCLocalSwiftPackageReference \"LocalPackages/mlx-swift-lm\""))
        #expect(!pbxproj.contains("XCRemoteSwiftPackageReference \"mlx-swift-lm\""))
        #expect(pbxproj.contains("relativePath = \"LocalPackages/mlx-swift-lm\";"))
        #expect(pbxproj.contains("productName = MLXLMCommon;"))
        #expect(pbxproj.contains("productName = MLXLLM;"))
        #expect(pbxproj.contains("productName = MLXVLM;"))
        #expect(chatSession.contains("public func extractKVCache() async -> [KVCache]?"))
        #expect(chatSession.contains("public func injectKVCache(_ kvCache: [KVCache]) async -> Bool"))
        #expect(chatSession.contains("CacheList<"))
        #expect(llmModelFactory.contains("\"mamba2\": create(Mamba2Configuration.self, Mamba2Model.init)"))
    }

    @Test("vendored mlx swift lm cache injection avoids non sendable captures")
    func mlxSwiftLMCacheInjectionAvoidsNonSendableCaptures() throws {
        let chatSession = try loadReleaseScript("LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/ChatSession.swift")

        #expect(chatSession.contains("let injectedCache = SendableBox(kvCache)"))
        #expect(chatSession.contains("c = .kvcache(injectedCache.consume())"))
    }

    @Test("reliability quality gates script supports DERIVED_DATA_ROOT and protected-folder defaulting")
    func reliabilityQualityGatesScriptSupportsDerivedDataRootAndProtectedFolderDefaulting() throws {
        let script = try loadReleaseScript("scripts/run_reliability_quality_gates.sh")

        #expect(script.contains("set -euo pipefail"))
        #expect(script.contains("scripts/xcodebuild_epistemos.sh"))
        #expect(script.contains("CODE_SIGNING_ALLOWED=NO"))
        #expect(script.contains("-derivedDataPath"))
        #expect(script.contains("RESULT_ROOT="))
        #expect(script.contains("DERIVED_DATA_ROOT="))
        #expect(script.contains("DERIVED_DATA_ROOT:-${protected_root_default}"))
        #expect(script.contains("\"${home_real}/Downloads\"|\"${home_real}/Downloads\"/*"))
        #expect(script.contains("\"${home_real}/Desktop\"|\"${home_real}/Desktop\"/*"))
        #expect(script.contains("\"${home_real}/Documents\"|\"${home_real}/Documents\"/*"))
        #expect(script.contains("${TMPDIR:-/tmp}/epistemos-reliability-derived-data/${timestamp}"))
        #expect(!script.contains("\"${TMPDIR:-/tmp}/epistemos-reliability-derived-data\""))
        #expect(script.contains("mkdir -p \"${DERIVED_DATA_ROOT}\""))
        #expect(script.contains("local derived_data=\"${DERIVED_DATA_ROOT}/derived-data-${name}\""))
        #expect(script.contains("'OTHER_LDFLAGS=$(inherited) -Wl,-no_compact_unwind'"))
        #expect(script.contains("run_gate tsan \\"))
        #expect(script.contains("-enableThreadSanitizer YES"))
        #expect(script.contains("run_soak_repeat_gate()"))
        #expect(script.contains("for iteration in 1 2 3 4 5 6 7 8; do"))
        #expect(script.contains("=== soak_repeat iteration ${iteration}/8 ==="))
        #expect(!script.contains("-test-iterations 8"))
        #expect(!script.contains("-test-repetition-relaunch-enabled YES"))
        #expect(!script.contains("-run-tests-until-failure"))
        #expect(script.contains("Artifacts: ${out_dir}"))
        #expect(script.contains("DerivedData: ${DERIVED_DATA_ROOT}"))
    }

    @Test("syntax core viewport highlighter stays warning free around unused rope helpers")
    func syntaxCoreViewportHighlighterStaysWarningFree() throws {
        let highlight = try loadReleaseScript("syntax-core/src/highlight.rs")

        #expect(!highlight.contains("let rope_bytes"))
        #expect(!highlight.contains("struct RopeChunkIter"))
        #expect(!highlight.contains("fn new(rope: &'a Rope, start: usize, end: usize)"))
    }
}

private func loadReleaseScript(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}

private struct MirroredScriptRunResult {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String
    let invocationLog: String
}

private func runMirroredScript(
    _ relativePath: String,
    arguments: [String] = [],
    stubCommands: [String: String],
    environment overrides: [String: String] = [:],
    argumentsBuilder: ((URL) throws -> [String])? = nil
) throws -> MirroredScriptRunResult {
    let fileManager = FileManager.default
    let tempDirectory = fileManager.temporaryDirectory
        .appendingPathComponent("release-script-audit-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: tempDirectory) }

    let invocationLogURL = tempDirectory.appendingPathComponent("command-invocations.log")
    for (name, contents) in stubCommands {
        let url = tempDirectory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    let resolvedArguments = try argumentsBuilder?(tempDirectory) ?? arguments
    process.arguments = [try sourceMirrorURL(for: relativePath).path] + resolvedArguments

    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = "\(tempDirectory.path):/usr/bin:/bin:/usr/sbin:/sbin"
    environment["TMP_CAPTURE"] = invocationLogURL.path
    for (key, value) in overrides {
        environment[key] = value
    }
    process.environment = environment
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdout = String(
        data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let stderr = String(
        data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let invocationLog = (try? String(contentsOf: invocationLogURL, encoding: .utf8)) ?? ""

    return MirroredScriptRunResult(
        terminationStatus: process.terminationStatus,
        stdout: stdout,
        stderr: stderr,
        invocationLog: invocationLog
    )
}
