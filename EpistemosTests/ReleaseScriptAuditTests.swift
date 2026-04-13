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
}

private func loadReleaseScript(_ relativePath: String) throws -> String {
    try loadMirroredSourceTextFile(relativePath)
}
