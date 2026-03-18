import Testing
@testable import Epistemos

@Suite("Landing ASCII Wake Field")
struct LandingASCIIWakeFieldTests {
    @Test("landing greeting keeps neutral startup copy")
    func landingGreetingUsesNeutralRestingCopy() {
        #expect(LiquidGreeting.restingGreeting == "welcome back")
    }

    @Test("greeting ripple keeps rich glyphs while staying calmer than default")
    func greetingRippleStaysCalmerThanDefault() {
        let defaultConfiguration = ASCIIRippleConfiguration()
        let configuration = LiquidGreeting.greetingRippleConfiguration

        #expect(configuration.duration < defaultConfiguration.duration)
        #expect(configuration.waveThreshold < defaultConfiguration.waveThreshold)
        #expect(configuration.duration >= 0.33)
        #expect(configuration.duration <= 0.35)
        #expect(configuration.waveThreshold >= 1.6)
        #expect(configuration.waveThreshold <= 1.68)
        #expect(configuration.spread <= 1.3)
        #expect(configuration.characterMultiplier >= 2)
        #expect(configuration.characters.count >= 10)
        #expect(configuration.characters.contains("█"))
        #expect(configuration.characters.contains("▒"))
        #expect(configuration.characters.allSatisfy { !$0.isLetter && !$0.isNumber })
    }

    @Test("landing greeting tuning increases ripple intensity and glyph variety")
    func landingGreetingTuningIncreasesRippleIntensityAndGlyphVariety() {
        let calm = LiquidGreeting.tunedRippleConfiguration(intensity: 0.15, variety: 0.1)
        let vivid = LiquidGreeting.tunedRippleConfiguration(intensity: 0.9, variety: 0.95)

        #expect(vivid.characters.count > calm.characters.count)
        #expect(vivid.characterMultiplier >= calm.characterMultiplier)
        #expect(vivid.waveThreshold < calm.waveThreshold)
        #expect(vivid.spread > calm.spread)
        #expect(vivid.duration >= calm.duration)
    }

    @Test("landing greeting pace tuning keeps faster and calmer typing ranges bounded")
    func landingGreetingPaceTuningStaysBounded() {
        let fastRange = LiquidGreeting.tunedCharacterDelayRange(pace: 0.15)
        let calmRange = LiquidGreeting.tunedCharacterDelayRange(pace: 0.9)
        let fastPause = LiquidGreeting.tunedPauseRange(pace: 0.15)
        let calmPause = LiquidGreeting.tunedPauseRange(pace: 0.9)

        #expect(fastRange.lowerBound < calmRange.lowerBound)
        #expect(fastRange.upperBound < calmRange.upperBound)
        #expect(fastPause.lowerBound < calmPause.lowerBound)
        #expect(fastPause.upperBound < calmPause.upperBound)
    }

    @Test("landing greeting reveal stays brisk while hold time is calmer")
    func landingGreetingRevealStaysBriskWhileHoldTimeIsCalmer() {
        #expect(LiquidGreeting.greetingCharacterDelayRange.upperBound <= 48)
        #expect(LiquidGreeting.greetingShortPauseMilliseconds >= 1200)
        #expect(LiquidGreeting.greetingPauseRange.lowerBound >= 2000)
        #expect(LiquidGreeting.greetingPauseRange.upperBound >= 2600)
    }

    @Test("landing greeting pulses ripple at visible typing milestones")
    func landingGreetingPulsesRippleAtVisibleMilestones() {
        #expect(LiquidGreeting.shouldPulseGreetingRipple(atTypedCharacterCount: 2, totalCount: 12))
        #expect(LiquidGreeting.shouldPulseGreetingRipple(atTypedCharacterCount: 4, totalCount: 12))
        #expect(!LiquidGreeting.shouldPulseGreetingRipple(atTypedCharacterCount: 5, totalCount: 12))
        #expect(LiquidGreeting.shouldPulseGreetingRipple(atTypedCharacterCount: 8, totalCount: 12))
        #expect(LiquidGreeting.shouldPulseGreetingRipple(atTypedCharacterCount: 12, totalCount: 12))
    }

    @Test("landing greeting sometimes morphs instead of fully retyping")
    func landingGreetingSometimesMorphsInsteadOfFullyRetyping() {
        #expect(!LiquidGreeting.shouldMorphGreetingTransition(ordinal: 1, from: "HELLO", to: "WORLD"))
        #expect(!LiquidGreeting.shouldMorphGreetingTransition(ordinal: 2, from: "HELLO", to: "WORLD"))
        #expect(LiquidGreeting.shouldMorphGreetingTransition(ordinal: 3, from: "HELLO", to: "WORLD"))
    }

    @Test("landing greeting morph frames never fully erase the phrase")
    func landingGreetingMorphFramesNeverFullyEraseThePhrase() {
        let frames = LiquidGreeting.morphFrames(from: "HELLO", to: "WORLD")

        #expect(!frames.isEmpty)
        #expect(frames.last == "WORLD")
        #expect(frames.allSatisfy { !$0.isEmpty })
        #expect(!frames.contains("H"))
        #expect(!frames.contains(""))
    }

    @Test("landing wake surface avoids static dash artifacts")
    func landingWakeSurfaceAvoidsStaticDashArtifacts() {
        let configuration = LandingASCIIWakeFieldConfiguration()

        #expect(configuration.surfaceCharacters.allSatisfy { $0 != "─" && $0 != "—" && $0 != "-" })
    }

    @Test("landing wake field hides the resting surface by default")
    func landingWakeFieldHidesRestingSurfaceByDefault() {
        let configuration = LandingASCIIWakeFieldConfiguration()

        #expect(configuration.restingSurfaceOpacity == 0)
    }

    @Test("landing wake field balances responsiveness with a longer stream")
    func landingWakeFieldBalancesResponsivenessWithLongerStream() {
        let configuration = LandingASCIIWakeFieldConfiguration()

        #expect(configuration.duration >= 1.05)
        #expect(configuration.duration <= 1.3)
        #expect(configuration.initialRadius >= 0.5)
        #expect(configuration.peakProgress >= 0.6)
        #expect(configuration.maxTrailCount >= 140)
        #expect(configuration.streamTailLength >= 3)
        #expect(configuration.streamBubbleStride >= 2)
        #expect(configuration.streamBubbleRadiusScale < 1)
    }

    @Test("landing wake field targets smooth 60 fps refresh rate")
    func landingWakeFieldTargetsSmoothRefreshRate() {
        let configuration = LandingASCIIWakeFieldConfiguration()

        #expect(configuration.frameInterval <= (1.0 / 60.0) + 0.0001)
    }

    @Test("landing wake field tuning exposes bounded cursor physics controls")
    func landingWakeFieldTuningExposesBoundedCursorPhysicsControls() {
        let compact = LandingASCIIWakeFieldConfiguration.tuned(
            response: 0.1,
            spread: 0.1,
            trail: 0.1
        )
        let expressive = LandingASCIIWakeFieldConfiguration.tuned(
            response: 0.9,
            spread: 0.9,
            trail: 0.9
        )

        #expect(compact.frameInterval == expressive.frameInterval)
        #expect(expressive.duration < compact.duration)
        #expect(expressive.maxRadius > compact.maxRadius)
        #expect(expressive.initialRadius > compact.initialRadius)
        #expect(expressive.streamTailLength > compact.streamTailLength)
        #expect(expressive.maxTrailCount > compact.maxTrailCount)
        #expect(expressive.streamBubbleRadiusScale > compact.streamBubbleRadiusScale)
    }

    @Test("normalized vocabulary uppercases, trims, and deduplicates")
    func normalizedVocabularyUppercasesAndDeduplicates() {
        let vocabulary = LandingASCIIWakeFieldEngine.normalizedVocabulary(
            from: ["  Brown Essays  ", "brown essays", "", " Knowledge Graph "]
        )

        #expect(vocabulary == ["BROWN ESSAYS", "KNOWLEDGE GRAPH"])
    }

    @Test("layout fills the requested grid and preserves newline structure")
    func layoutFillsRequestedGrid() {
        let layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: ["EPISTEMOS", "RESEARCH"],
            columns: 6,
            rows: 3,
            configuration: LandingASCIIWakeFieldConfiguration()
        )

        #expect(layout.columns == 6)
        #expect(layout.rows == 3)
        #expect(layout.hiddenCharacters.count == 20)
        #expect(layout.surfaceCharacters.count == 20)
        #expect(layout.blankCharacters.count == 20)
        #expect(layout.hiddenText.split(separator: "\n", omittingEmptySubsequences: false).count == 3)
    }

    @Test("overlay text reveals hidden characters inside the wake radius")
    func overlayTextRevealsHiddenCharactersInsideWake() {
        let configuration = LandingASCIIWakeFieldConfiguration(duration: 1, maxRadius: 5, boundaryThickness: 1)
        let layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: ["ALPHA"],
            columns: 5,
            rows: 1,
            configuration: configuration
        )
        let trails = [LandingASCIIWakeTrail(column: 2, row: 0, startTime: 0)]

        let overlay = LandingASCIIWakeFieldEngine.overlayText(
            layout: layout,
            now: 0.45,
            trails: trails,
            configuration: configuration
        )

        #expect(overlay.contains("A") || overlay.contains("L") || overlay.contains("P") || overlay.contains("H"))
    }

    @Test("interpolated trail path fills gaps between hover samples")
    func interpolatedTrailPathFillsHoverGaps() {
        let points = LandingASCIIWakeFieldEngine.interpolatedPath(
            from: .init(x: 0, y: 0),
            to: .init(x: 2, y: 0),
            maxStep: 0.4
        )

        #expect(points == [
            .init(x: 0.4, y: 0),
            .init(x: 0.8, y: 0),
            .init(x: 1.2, y: 0),
            .init(x: 1.6, y: 0),
            .init(x: 2, y: 0),
        ])
    }

    @Test("stream path extends behind short cursor moves")
    func streamPathExtendsBehindShortCursorMoves() {
        let points = LandingASCIIWakeFieldEngine.streamPath(
            from: .init(x: 1.6, y: 0),
            to: .init(x: 2, y: 0),
            maxStep: 0.4,
            tailLength: 1.2
        )
        let expected: [LandingASCIIWakeFieldEngine.TrailPoint] = [
            .init(x: 0.8, y: 0),
            .init(x: 1.2, y: 0),
            .init(x: 1.6, y: 0),
            .init(x: 2, y: 0),
        ]

        #expect(points.count == expected.count)
        for (point, expectedPoint) in zip(points, expected) {
            #expect(abs(point.x - expectedPoint.x) < 0.0001)
            #expect(abs(point.y - expectedPoint.y) < 0.0001)
        }
    }

    @Test("active wake detection ignores expired trails")
    func activeWakeDetectionIgnoresExpiredTrails() {
        let configuration = LandingASCIIWakeFieldConfiguration(duration: 1)
        let trails = [
            LandingASCIIWakeTrail(column: 0, row: 0, startTime: 0),
            LandingASCIIWakeTrail(column: 1, row: 0, startTime: 1.4),
        ]

        #expect(LandingASCIIWakeFieldEngine.hasActiveTrails(trails, now: 1.8, configuration: configuration))
        #expect(!LandingASCIIWakeFieldEngine.hasActiveTrails(trails, now: 2.6, configuration: configuration))
    }

    @Test("pruned trails remove expired wake samples")
    func prunedTrailsRemoveExpiredWakeSamples() {
        let configuration = LandingASCIIWakeFieldConfiguration(duration: 1)
        let trails = [
            LandingASCIIWakeTrail(column: 0, row: 0, startTime: 0),
            LandingASCIIWakeTrail(column: 1, row: 0, startTime: 0.9),
            LandingASCIIWakeTrail(column: 2, row: 0, startTime: 1.3),
        ]

        let pruned = LandingASCIIWakeFieldEngine.prunedTrails(trails, now: 1.8, configuration: configuration)

        #expect(pruned == [
            LandingASCIIWakeTrail(column: 1, row: 0, startTime: 0.9),
            LandingASCIIWakeTrail(column: 2, row: 0, startTime: 1.3),
        ])
    }

    @Test("next trail cleanup delay targets the earliest active expiration")
    func nextTrailCleanupDelayTargetsEarliestActiveExpiration() {
        let configuration = LandingASCIIWakeFieldConfiguration(duration: 1)
        let trails = [
            LandingASCIIWakeTrail(column: 0, row: 0, startTime: 0.4),
            LandingASCIIWakeTrail(column: 1, row: 0, startTime: 1.1),
            LandingASCIIWakeTrail(column: 2, row: 0, startTime: 1.7),
        ]

        let delay = LandingASCIIWakeFieldEngine.nextTrailCleanupDelay(trails, now: 1.85, configuration: configuration)

        #expect(delay != nil)
        #expect(abs((delay ?? 0) - 0.25) < 0.0001)
    }

    @Test("resolved trails precompute bounded active wake states")
    func resolvedTrailsPrecomputeBoundedActiveWakeStates() {
        let configuration = LandingASCIIWakeFieldConfiguration(
            duration: 1,
            initialRadius: 1.8,
            maxRadius: 1.8,
            endRadius: 1.8
        )
        let trails = [
            LandingASCIIWakeTrail(x: 2.2, y: 1.2, startTime: 0, radiusScale: 1),
            LandingASCIIWakeTrail(x: 4, y: 1, startTime: 1.4, radiusScale: 1),
        ]

        let resolved = LandingASCIIWakeFieldEngine.resolvedTrails(
            trails,
            now: 0.5,
            configuration: configuration,
            columns: 5,
            rows: 3
        )

        #expect(resolved.count == 1)
        if let trail = resolved.first {
            #expect(trail.minColumn == 0)
            #expect(trail.maxColumn == 4)
            #expect(trail.minRow == 0)
            #expect(trail.maxRow == 2)
            #expect(trail.revealRadius < trail.radius)
        }
    }

    @Test("clamped trail samples stay on grid and dedupe neighbors")
    func clampedTrailSamplesStayOnGridAndDedupeNeighbors() {
        let samples = LandingASCIIWakeFieldEngine.clampedTrailSamples(
            [
                .init(point: .init(x: -2, y: 1), radiusScale: 1),
                .init(point: .init(x: -2, y: 1), radiusScale: 1),
                .init(point: .init(x: 3.6, y: 1.4), radiusScale: 1),
                .init(point: .init(x: 9, y: 6), radiusScale: 0.56),
            ],
            columns: 5,
            rows: 4
        )

        #expect(samples == [
            .init(point: .init(x: 0, y: 1), radiusScale: 1),
            .init(point: .init(x: 3.6, y: 1.4), radiusScale: 1),
            .init(point: .init(x: 4, y: 3), radiusScale: 0.56),
        ])
    }

    @Test("stream trail emits bubble droplets beside the ribbon")
    func streamTrailEmitsBubbleDropletsBesideRibbon() {
        let configuration = LandingASCIIWakeFieldConfiguration(
            streamTailLength: 2.4,
            streamBubbleStride: 2,
            streamBubbleOffset: 1.0,
            streamBubbleBacktrack: 0.5,
            streamBubbleRadiusScale: 0.56
        )
        let samples = LandingASCIIWakeFieldEngine.streamTrailSamples(
            from: .init(x: 0, y: 0),
            to: .init(x: 4, y: 0),
            configuration: configuration
        )
        let bubbleSamples = samples.filter { $0.radiusScale < 1 }

        #expect(!bubbleSamples.isEmpty)
        #expect(bubbleSamples.contains { abs($0.point.y) > 0.4 })
        #expect(bubbleSamples.allSatisfy { $0.radiusScale < 1 })
    }

    @Test("stream trail swells and swings on long fast drags")
    func streamTrailSwellsAndSwingsOnLongFastDrags() {
        let configuration = LandingASCIIWakeFieldConfiguration(
            streamTailLength: 3.6,
            streamLongDragDistance: 4,
            streamVelocityReference: 24,
            streamCoreRadiusBoost: 0.9,
            streamBubbleRadiusScale: 0.56,
            streamBubbleFastScaleBoost: 0.4,
            streamSwingMaxOffset: 0.9,
            streamSwingCycles: 1.25,
            streamHeadAgeBoost: 0.12
        )
        let samples = LandingASCIIWakeFieldEngine.streamTrailSamples(
            from: .init(x: 0, y: 0),
            to: .init(x: 7, y: 0),
            eventDelta: 0.05,
            configuration: configuration
        )

        #expect(samples.contains { abs($0.point.y) > 0.2 && $0.radiusScale >= 1 })
        #expect((samples.last?.radiusScale ?? 1) > 1.6)
        #expect((samples.last?.ageOffset ?? 0) >= 0.1)
    }

    @Test("fast drags use a larger interpolation step to avoid trail crowding")
    func fastDragsUseLargerInterpolationStepToAvoidTrailCrowding() {
        let configuration = LandingASCIIWakeFieldConfiguration(
            streamLongDragDistance: 4.8,
            streamVelocityReference: 26
        )

        let slowStep = LandingASCIIWakeFieldEngine.streamInterpolationStep(
            distance: 3.2,
            eventDelta: 0.35,
            configuration: configuration
        )
        let fastStep = LandingASCIIWakeFieldEngine.streamInterpolationStep(
            distance: 3.2,
            eventDelta: 0.05,
            configuration: configuration
        )

        #expect(slowStep >= 0.4)
        #expect(fastStep > slowStep)
    }

    @Test("wake keeps a thicker scramble shell before fully revealing text")
    func wakeKeepsAThickerScrambleShellBeforeFullyRevealingText() {
        let configuration = LandingASCIIWakeFieldConfiguration(
            duration: 1,
            initialRadius: 5,
            maxRadius: 5,
            endRadius: 5,
            boundaryThickness: 0.4
        )
        let layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: ["AAAAAAAAAAA"],
            columns: 11,
            rows: 1,
            configuration: configuration
        )
        let trails = [LandingASCIIWakeTrail(x: 5.6, y: 0, startTime: 0)]

        let overlay = LandingASCIIWakeFieldEngine.overlayText(
            layout: layout,
            now: 0.5,
            trails: trails,
            configuration: configuration
        )

        let scrambledCharacter = Array(overlay)[10]
        #expect(scrambledCharacter != " ")
        #expect(scrambledCharacter != layout.hiddenCharacters[10])
    }

    @Test("wake radius expands, then closes back toward the cursor")
    func wakeRadiusExpandsThenContracts() {
        let configuration = LandingASCIIWakeFieldConfiguration(
            duration: 1,
            initialRadius: 0.42,
            maxRadius: 8,
            growthExponent: 1.3,
            peakProgress: 0.76,
            endRadius: 0.35,
            contractionExponent: 0.7
        )

        let early = LandingASCIIWakeFieldEngine.radius(progress: 0.1, configuration: configuration)
        let middle = LandingASCIIWakeFieldEngine.radius(progress: 0.5, configuration: configuration)
        let peak = LandingASCIIWakeFieldEngine.radius(progress: 0.76, configuration: configuration)
        let late = LandingASCIIWakeFieldEngine.radius(progress: 0.9, configuration: configuration)
        let end = LandingASCIIWakeFieldEngine.radius(progress: 1, configuration: configuration)

        #expect(early > 0.75)
        #expect(middle > early)
        #expect(peak > middle)
        #expect(late < peak)
        #expect(end < late)
        #expect(abs(end - configuration.endRadius) < 0.001)
    }

    @Test("overlay text stays blank when no wake is active")
    func overlayTextStaysBlankWithoutWake() {
        let configuration = LandingASCIIWakeFieldConfiguration()
        let layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: ["ALPHA"],
            columns: 5,
            rows: 2,
            configuration: configuration
        )

        let overlay = LandingASCIIWakeFieldEngine.overlayText(
            layout: layout,
            now: 2,
            trails: [],
            configuration: configuration
        )

        #expect(overlay == layout.blankText)
    }
}
