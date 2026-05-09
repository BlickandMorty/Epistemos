import Testing
import CoreGraphics
import AppKit
@testable import Epistemos

@Suite("Runtime Capability And Performance Policies")
struct RuntimeCapabilityAndPerformancePolicyTests {
    @Test("mamba2 warms the custom runtime but keeps agent mode hidden until fully validated")
    func mamba2CustomRuntimeProfileAndReleaseGating() throws {
        let model = LocalTextModelID.mamba2_2B4Bit
        let profile = try #require(model.ssmRuntimeProfile)

        #expect(profile.warmsCustomMetalRuntime == CustomSSMRuntimeSupport.isAvailable)
        #expect(profile.chunkLength == 128)
        #expect(profile.recommendedHeapSizeBytes >= 16 * 1_024 * 1_024)
        #expect(model.agentToolTier == .readOnly)
        #expect(!model.canActAsAgent)
        #expect(!model.supportsAgentMode)
    }

    @Test("cloud model identifiers stay unique across providers")
    func cloudModelIdentifiersAreUnique() {
        let rawValues = CloudTextModelID.allCases.map(\.rawValue)
        let vendorPairs = CloudTextModelID.allCases.map { "\($0.provider.rawValue):\($0.vendorModelID)" }

        #expect(Set(rawValues).count == rawValues.count)
        #expect(Set(vendorPairs).count == vendorPairs.count)
    }

    @Test("graph interaction policy relaxes rendering pressure while interacting")
    func graphInteractionPolicyAdjustsForActiveGestures() {
        let idleWait = GraphInteractionRenderPolicy.inFlightWaitMilliseconds(
            isInteracting: false,
            lowPowerMode: false
        )
        let activeWait = GraphInteractionRenderPolicy.inFlightWaitMilliseconds(
            isInteracting: true,
            lowPowerMode: false
        )

        #expect(activeWait > idleWait)
        #expect(
            GraphInteractionRenderPolicy.selectedNodePublishDistance(isInteracting: true)
                > GraphInteractionRenderPolicy.selectedNodePublishDistance(isInteracting: false)
        )
        #expect(
            GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames(isInteracting: true)
                > GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames(isInteracting: false)
        )
    }

    @Test("large graph overlay caps drawable scale without changing mini mode")
    func graphDrawableResolutionPolicyCapsOnlyLargeOverlays() {
        let fullScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let miniScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 360, height: 360),
            backingScale: 2.0,
            isMiniMode: true,
            lowPowerMode: false,
            qualityLevel: 0
        )

        #expect(fullScale < 2.0)
        #expect(fullScale >= 1.0)
        #expect(miniScale == 2.0)
    }

    @Test("drawable resolution policy preserves native scale under budget")
    func graphDrawableResolutionPolicyLeavesSmallViewsNative() {
        let scale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 600, height: 400),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let drawableSize = GraphDrawableResolutionPolicy.drawableSize(
            boundsSize: CGSize(width: 600, height: 400),
            scale: scale
        )

        #expect(scale == 2.0)
        #expect(drawableSize == CGSize(width: 1_200, height: 800))
    }

    @Test("voice input pulse avoids repeatForever and pauses when hidden")
    func voiceInputPulseAvoidsRepeatForeverAndPausesWhenHidden() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Shared/VoiceInputButton.swift")

        #expect(!source.contains("repeatForever("))
        #expect(source.contains("TimelineView(.animation(minimumInterval: 1.0 / 30.0))"))
        #expect(source.contains("accessibilityReduceMotion"))
        #expect(source.contains("ui.windowOccluded"))
    }

    @Test("cinematic fullscreen budget matches mini-like pixel pressure")
    func graphDrawableResolutionPolicyUsesMiniLikeCinematicBudget() {
        let cinematicScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let performanceScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 2
        )
        let cinematicSize = GraphDrawableResolutionPolicy.drawableSize(
            boundsSize: CGSize(width: 1_512, height: 982),
            scale: cinematicScale
        )
        let cinematicPixels = cinematicSize.width * cinematicSize.height

        #expect(cinematicScale < performanceScale)
        #expect(cinematicPixels <= 1_610_000)
        #expect(cinematicPixels >= 1_500_000)
    }

    @Test("fullscreen drawable cap does not force a fractional CAMetalLayer contents scale")
    func fullscreenDrawableCapKeepsLayerContentsScaleNative() {
        let drawableScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: CGSize(width: 1_512, height: 982),
            backingScale: 2.0,
            isMiniMode: false,
            lowPowerMode: false,
            qualityLevel: 0
        )
        let layerScale = GraphDrawableResolutionPolicy.layerContentsScale(backingScale: 2.0)

        #expect(drawableScale < 2.0)
        #expect(layerScale == 2.0)
    }

    @Test("code editor policy hides semantic refresh work until the sidebar is visible")
    func codeEditorPolicyGatesSemanticSidebarWork() {
        #expect(CodeEditorPerformancePolicy.shouldRefreshSemanticContext(isSidebarVisible: true))
        #expect(!CodeEditorPerformancePolicy.shouldRefreshSemanticContext(isSidebarVisible: false))
    }

    @Test("code editor release path disables unfinished sidecars by default")
    func codeEditorReleasePolicyDisablesUnfinishedSurfaces() {
        #expect(!CodeEditorReleasePolicy.semanticSidebarEnabled)
        #expect(!CodeEditorReleasePolicy.aiPartnerEnabled)
    }

    @Test("experimental runtime flags default off")
    func experimentalRuntimeFlagsDefaultOff() throws {
        let suiteName = "EpistemosRuntimeFeatureFlags.default.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let flags = EpistemosRuntimeFeatureFlags.load(
            userDefaults: userDefaults,
            environment: [:]
        )

        #expect(flags == .disabled)
        #expect(!flags.deterministicKnowledgeCoreRuntime)
        #expect(!flags.borrowedKnowledgeRows)
        #expect(!flags.rawThoughtsBulkLane)
        #expect(!flags.staticArtifactRouting)
        #expect(!flags.graphEdgePrefetch)
    }

    @Test("experimental runtime flags are explicit opt-ins")
    func experimentalRuntimeFlagsAreExplicitOptIns() throws {
        let suiteName = "EpistemosRuntimeFeatureFlags.optIn.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set(true, forKey: EpistemosRuntimeFeatureFlags.Key.deterministicKnowledgeCoreRuntime)
        userDefaults.set(true, forKey: EpistemosRuntimeFeatureFlags.Key.borrowedKnowledgeRows)
        userDefaults.set(true, forKey: EpistemosRuntimeFeatureFlags.Key.rawThoughtsBulkLane)
        userDefaults.set(true, forKey: EpistemosRuntimeFeatureFlags.Key.staticArtifactRouting)
        userDefaults.set(true, forKey: EpistemosRuntimeFeatureFlags.Key.graphEdgePrefetch)

        let flags = EpistemosRuntimeFeatureFlags.load(
            userDefaults: userDefaults,
            environment: [
                EpistemosRuntimeFeatureFlags.EnvironmentKey.borrowedKnowledgeRows: "0",
                EpistemosRuntimeFeatureFlags.EnvironmentKey.graphEdgePrefetch: "disabled",
            ]
        )

        #expect(flags.deterministicKnowledgeCoreRuntime)
        #expect(!flags.borrowedKnowledgeRows)
        #expect(flags.rawThoughtsBulkLane)
        #expect(flags.staticArtifactRouting)
        #expect(!flags.graphEdgePrefetch)
    }

    @Test("code editor policy increases debounce windows for larger files")
    func codeEditorPolicyScalesForLargeFiles() {
        let smallOutline = CodeEditorPerformancePolicy.outlineRefreshDelayMilliseconds(characterCount: 1_200)
        let largeOutline = CodeEditorPerformancePolicy.outlineRefreshDelayMilliseconds(characterCount: 48_000)
        let smallInsight = CodeEditorPerformancePolicy.insightRefreshDelayMilliseconds(characterCount: 1_200)
        let largeInsight = CodeEditorPerformancePolicy.insightRefreshDelayMilliseconds(characterCount: 48_000)

        #expect(largeOutline > smallOutline)
        #expect(largeInsight > smallInsight)
    }

    @Test("code editor line metrics counts edge cases without splitting buffers")
    func codeEditorLineMetricsCountsWithoutIntermediateArrays() {
        #expect(CodeEditorLineMetrics.lineCount("") == 1)
        #expect(CodeEditorLineMetrics.lineCount("let value = 1") == 1)
        #expect(CodeEditorLineMetrics.lineCount("let a = 1\nlet b = 2") == 2)
        #expect(CodeEditorLineMetrics.lineCount("let a = 1\n") == 2)
        #expect(CodeEditorLineMetrics.lineCount("let a = \"🧠\"\r\nlet b = \"漢字\"") == 2)
    }

    @Test("code editor line metrics stays inside a 4k line component budget")
    func codeEditorLineMetricsHas4kLineComponentBudget() {
        let line = "func renderRow(_ row: Int) { _ = row &* 31 }"
        let text = (0..<4_000).map { "\($0): \(line)" }.joined(separator: "\n")
        let clock = ContinuousClock()
        var measuredLineCount = 0

        let elapsed = clock.measure {
            for _ in 0..<50 {
                measuredLineCount = CodeEditorLineMetrics.lineCount(text)
            }
        }

        #expect(measuredLineCount == 4_000)
        #expect(elapsed < .seconds(1), "4k-line metric scan regressed: \(elapsed)")
    }

    @Test("right-side code gutter width scales only at digit boundaries")
    func codeLineGutterWidthPolicyIsStableForLargeFiles() {
        let gutterFont = NSFont.monospacedDigitSystemFont(
            ofSize: CodeLineGutterPolicy.gutterFontSize(forBodyPointSize: 14),
            weight: .regular
        )
        let width99 = CodeLineGutterView.preferredWidth(
            digitCount: CodeLineGutterPolicy.digitCount(for: 99),
            font: gutterFont
        )
        let width4k = CodeLineGutterView.preferredWidth(
            digitCount: CodeLineGutterPolicy.digitCount(for: 4_000),
            font: gutterFont
        )
        let width10k = CodeLineGutterView.preferredWidth(
            digitCount: CodeLineGutterPolicy.digitCount(for: 10_000),
            font: gutterFont
        )

        #expect(CodeLineGutterPolicy.digitCount(for: 4_000) == 4)
        #expect(width4k > width99)
        #expect(width10k > width4k)
        #expect(width4k <= 48, "4k-line gutter must stay compact enough to avoid fighting the editor canvas")
    }

    @Test("right-side code gutter computes only visible line range for 4k-line files")
    func codeLineGutterVisibleRangeStaysBoundedForLargeFiles() throws {
        let lineHeight: CGFloat = 17
        let viewport = NSRect(x: 0, y: 0, width: 48, height: 680)

        let topRange = try #require(CodeLineGutterView.visibleLineRange(
            lineCount: 4_000,
            lineHeight: lineHeight,
            topInset: 0,
            scrollOffset: 0,
            dirtyRect: viewport
        ))
        #expect(topRange.lowerBound == 1)
        #expect(topRange.upperBound <= 42)

        let midRange = try #require(CodeLineGutterView.visibleLineRange(
            lineCount: 4_000,
            lineHeight: lineHeight,
            topInset: 0,
            scrollOffset: -(lineHeight * 1_500),
            dirtyRect: viewport
        ))
        #expect(midRange.lowerBound >= 1_500)
        #expect(midRange.upperBound < 1_550)
        #expect(midRange.count <= 42, "gutter must draw viewport-sized line ranges, not all 4k lines")
    }

    @Test("code indentation guide avoids full-line array allocation on 4k-line refresh")
    @MainActor
    func codeIndentationGuideRefreshAvoidsFullLineArrayAllocation() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/SegmentedIndentationGuideView.swift")
        #expect(!source.contains("components(separatedBy: .newlines)"))
        #expect(!source.contains("trimmingCharacters(in: .whitespaces)"))

        let line = "        if value > 0 { render(value) }"
        let text = (0..<4_000).map { "\($0): \(line)" }.joined(separator: "\n")
        let view = SegmentedIndentationGuideView(frame: NSRect(x: 0, y: 0, width: 180, height: 700))
        let clock = ContinuousClock()

        let elapsed = clock.measure {
            for _ in 0..<20 {
                view.updateFromText(text, cursorLine: 2_000)
            }
        }

        #expect(elapsed < .seconds(1), "4k-line indentation guide refresh regressed: \(elapsed)")
    }

    @Test("code editor applies initial line count to installed gutter")
    func codeEditorAppliesInitialLineCountToGutter() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains("coordinator.applyLineGutterState(totalLines: totalLines, cursorLine: cursorLine)"))
        #expect(source.contains("func applyLineGutterState(totalLines: Int, cursorLine: Int)"))
        #expect(source.contains("updateGutterLineCount(totalLines)"))
        #expect(source.contains("gutterView?.updateActiveLine(cursorLine)"))
    }

    @Test("code syntax chunker never treats UTF-8 byte offsets as String character offsets")
    func codeSyntaxChunkerKeepsUnicodeChunksOnCharacterBoundaries() {
        let line = "let thought = \"🧠 漢字 café\" // syntax preview"
        let text = (0..<512).map { "\($0): \(line)" }.joined(separator: "\n")
        let chunks = CodeSyntaxChunker.utf8AlignedChunks(in: text, maxBytes: 257)

        #expect(chunks.count > 1)
        #expect(chunks.first?.range.lowerBound == text.startIndex)
        #expect(chunks.last?.range.upperBound == text.endIndex)
        #expect(chunks.first?.utf8LowerBound == 0)
        #expect(chunks.last?.utf8UpperBound == text.utf8.count)

        var expectedLower = text.startIndex
        var expectedByteOffset = 0
        for chunk in chunks {
            #expect(chunk.range.lowerBound == expectedLower)
            #expect(chunk.utf8LowerBound == expectedByteOffset)

            let chunkText = String(text[chunk.range])
            #expect(chunkText.utf8.count == chunk.utf8UpperBound - chunk.utf8LowerBound)
            #expect(chunkText.utf8.count <= 257 || chunkText.count == 1)

            expectedLower = chunk.range.upperBound
            expectedByteOffset = chunk.utf8UpperBound
        }
    }

    @Test("large code inspector highlighting uses Unicode-safe off-main chunk preparation")
    func codeInspectorHighlightingAvoidsByteOffsetStringIndexing() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")

        #expect(source.contains("CodeSyntaxChunker.utf8AlignedChunks"))
        #expect(source.contains("Task.detached(priority: .utility)"))
        #expect(source.contains("computeTokenSpans("))
        #expect(!source.contains("offsetBy: chunk.start"))
        #expect(!source.contains("offsetBy: chunk.end"))
    }

    @Test("AppBootstrap computer-use services stay lazy at startup")
    func appBootstrapKeepsComputerUseChainLazyAtStartup() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")
        let environment = try loadMirroredSourceTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(source.contains("private var _screenCapture: ScreenCaptureService?"))
        #expect(source.contains("var screenCapture: ScreenCaptureService {"))
        #expect(source.contains("private var _screen2AXFusion: Screen2AXFusion?"))
        #expect(source.contains("var screen2AXFusion: Screen2AXFusion {"))
        #expect(source.contains("private var _ambientCapture: AmbientCaptureService?"))
        #expect(source.contains("var ambientCapture: AmbientCaptureService {"))
        #expect(!source.contains("screenCapture: screenCapture,\n            perception: screen2AXFusion"))
        #expect(!environment.contains(".environment(bootstrap.screen2AXFusion)"))
    }

    @Test("AppBootstrap cloud knowledge distillation stays lazy until NightBrain runs")
    func appBootstrapKeepsCloudKnowledgeDistillationLazyUntilJobRuns() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(source.contains("private var _cloudKnowledgeDistillationService: CloudKnowledgeDistillationService?"))
        #expect(source.contains("var cloudKnowledgeDistillationService: CloudKnowledgeDistillationService {"))
        #expect(source.contains("cloudKnowledgeJob: { [weak self] in"))
        #expect(source.contains("await MainActor.run(body: {"))
        #expect(source.contains("self?.cloudKnowledgeDistillationService"))
        #expect(!source.contains("cloudKnowledgeJob: { [cloudKnowledgeDistillationService] in"))
    }

    @Test("semantic cluster parallel path avoids unsafe mutable buffer capture")
    func semanticClusterParallelPathAvoidsUnsafeMutableBufferCapture() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Graph/SemanticClusterService.swift")

        #expect(!source.contains("withUnsafeMutableBufferPointer"))
        #expect(!source.contains("nonisolated(unsafe) var slots"))
        #expect(source.contains("private nonisolated final class SemanticEmbeddingSlots"))
    }

    @Test("vault lifecycle does not re-add redundant unchecked FFI Sendable shims")
    func vaultLifecycleAvoidsRedundantUncheckedFfiSendableShims() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Vault/VaultLifecycleService.swift")

        #expect(!source.contains("extension VaultFactFfi: @unchecked Sendable"))
        #expect(!source.contains("extension ContradictionFfi: @unchecked Sendable"))
        #expect(!source.contains("extension SessionFolderInfoFfi: @unchecked Sendable"))
        #expect(!source.contains("extension SkillRegistryEntryFfi: @unchecked Sendable"))
    }

    @Test("LSP routing task does not await synchronous actor helpers")
    func lspRoutingTaskAvoidsRedundantSynchronousAwaits() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/LSPClient.swift")

        #expect(!source.contains("await self.routeIncoming(msg)"))
        #expect(!source.contains("await self.failAllPending(.transportClosed)"))
    }

    @Test("speech analyzer route-change observer avoids MainActor static logger capture")
    func speechAnalyzerRouteObserverAvoidsMainActorStaticLoggerCapture() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")

        #expect(source.contains("let routeChangeLog = Self.log"))
        #expect(source.contains("routeChangeLog.info(\"audio route changed"))
        #expect(!source.contains("Self.log.info(\"audio route changed"))
    }

    @Test("speech analyzer live stream uses start API without double-binding input sequence")
    func speechAnalyzerLiveStreamAvoidsDoubleBoundInputSequence() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/EpistemosSpeechAnalyzer.swift")

        #expect(source.contains("let analyzer = SpeechAnalyzer(modules: [transcriber])"))
        #expect(source.contains("SpeechAnalyzer.bestAvailableAudioFormat"))
        #expect(source.contains("try await analyzer.prepareToAnalyze(in: analyzerFormat)"))
        #expect(source.contains("SpeechAnalyzerAudioBufferConverter"))
        #expect(source.contains("AVAudioConverter(from: inputFormat, to: outputFormat)"))
        #expect(source.contains("try await analyzer.start(inputSequence: inputStream)"))
        #expect(source.contains("inputCont.yield(input)"))
        #expect(!source.contains("yield(AnalyzerInput(buffer: buffer))"))
        #expect(!source.contains("self?.inputContinuation?.yield"))
        #expect(!source.contains("SpeechAnalyzer(\n            inputSequence: inputStream"))
        #expect(!source.contains("analyzer.analyzeSequence(inputStream)"))
    }

    @Test("epdoc WebKit surfaces do not use deprecated WKProcessPool")
    func epdocWebKitSurfacesAvoidDeprecatedProcessPool() throws {
        let chromeSource = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let katexSource = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocKaTeXPreview.swift")
        let appSource = try loadMirroredSourceTextFile("Epistemos/App/EpistemosApp.swift")

        #expect(!chromeSource.contains("WKProcessPool("))
        #expect(!chromeSource.contains(".processPool"))
        #expect(!katexSource.contains(".processPool"))
        #expect(!appSource.contains("resetPoolIfIdle"))
        #expect(chromeSource.contains("isIdleForMemoryPressure"))
        #expect(appSource.contains("webViewIdle"))
    }

    @Test("Spotlight indexing uses async CoreSpotlight APIs for indexing")
    func spotlightIndexingUsesAsyncCoreSpotlightAPIs() throws {
        let spotlightSource = try loadMirroredSourceTextFile("Epistemos/Engine/SpotlightIndexer.swift")
        let vaultIndexSource = try loadMirroredSourceTextFile("Epistemos/Sync/VaultIndexActor.swift")

        #expect(spotlightSource.contains("try await CSSearchableIndex.default().indexSearchableItems([item])"))
        #expect(spotlightSource.contains("try await CSSearchableIndex.default().indexSearchableItems(items)"))
        #expect(vaultIndexSource.contains("try await CSSearchableIndex.default().indexSearchableItems(items)"))
        #expect(!spotlightSource.contains("indexSearchableItems([item]) { error in"))
        #expect(!spotlightSource.contains("indexSearchableItems(items) { error in"))
        #expect(!vaultIndexSource.contains("indexSearchableItems(items) { error in"))
    }

    @Test("Hologram overlay animation completions are Sendable")
    func hologramOverlayAnimationCompletionsAreSendable() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Graph/HologramOverlay.swift")

        #expect(source.contains("completion: (@Sendable () -> Void)? = nil"))
        #expect(!source.contains("completion: (() -> Void)? = nil"))
        #expect(!source.contains("completion: () -> Void"))
    }

    @Test("code gutter theme tokens remain transparent and subordinate to body text")
    func codeLineGutterThemeTokensStaySubtle() {
        for theme in EpistemosTheme.allCases {
            let tokens = theme.editorGutterTokens()

            #expect(tokens.background.alphaComponent == 0)
            #expect(tokens.foreground.alphaComponent < tokens.activeForeground.alphaComponent)
            #expect(tokens.separator.alphaComponent > 0)
        }
    }
}
