import Testing
@testable import Epistemos

@Suite("Landing ASCII Wake Field")
struct LandingASCIIWakeFieldTests {
    @Test("landing greeting keeps neutral startup copy")
    func landingGreetingUsesNeutralRestingCopy() {
        #expect(LiquidGreeting.restingGreeting == "welcome back")
    }

    @Test("landing wake surface turns off once chat owns the screen")
    func landingWakeSurfaceTurnsOffWhenChatOwnsScreen() {
        #expect(
            LandingWakeSurfacePolicy.activeSurface(
                showLanding: false,
                showingBrief: false,
                showingSearch: false
            ) == nil
        )
        #expect(
            LandingWakeSurfacePolicy.activeSurface(
                showLanding: true,
                showingBrief: false,
                showingSearch: false
            ) == .landing
        )
        #expect(
            LandingWakeSurfacePolicy.activeSurface(
                showLanding: true,
                showingBrief: false,
                showingSearch: true
            ) == .search
        )
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

    @Test("landing wake field stays within the lighter real-time budget")
    func landingWakeFieldStaysWithinRealtimeBudget() {
        let configuration = LandingASCIIWakeFieldConfiguration()

        #expect(configuration.duration >= 0.8)
        #expect(configuration.duration <= 1.0)
        #expect(configuration.initialRadius >= 0.4)
        #expect(configuration.peakProgress >= 0.58)
        #expect(configuration.maxTrailCount <= 112)
        #expect(configuration.streamTailLength <= 2.6)
        #expect(configuration.streamBubbleStride >= 2)
        #expect(configuration.streamBubbleRadiusScale < 1)
        #expect(configuration.maxColumns <= 160)
        #expect(configuration.maxRows <= 48)
    }

    @Test("landing wake field targets smooth 60 fps refresh rate")
    func landingWakeFieldTargetsSmoothRefreshRate() {
        let configuration = LandingASCIIWakeFieldConfiguration()

        #expect(configuration.frameInterval <= (1.0 / 60.0) + 0.0001)
        #expect(configuration.idleFrameInterval >= (1.0 / 24.0) - 0.0001)
    }

    @Test("landing wake field tuning exposes bounded cursor physics controls")
    func landingWakeFieldTuningExposesBoundedCursorPhysicsControls() {
        let compact = LandingASCIIWakeFieldConfiguration.tuned(
            response: 0.1,
            spread: 0.1,
            trail: 0.1,
            opacity: 0.45,
            blur: 0.15
        )
        let expressive = LandingASCIIWakeFieldConfiguration.tuned(
            response: 0.9,
            spread: 0.9,
            trail: 0.9,
            opacity: 1.2,
            blur: 0.9
        )

        #expect(compact.frameInterval == expressive.frameInterval)
        #expect(compact.idleFrameInterval == expressive.idleFrameInterval)
        #expect(expressive.duration < compact.duration)
        #expect(expressive.maxRadius > compact.maxRadius)
        #expect(expressive.initialRadius > compact.initialRadius)
        #expect(expressive.streamTailLength > compact.streamTailLength)
        #expect(expressive.maxTrailCount > compact.maxTrailCount)
        #expect(expressive.streamBubbleRadiusScale > compact.streamBubbleRadiusScale)
        #expect(expressive.overlayOpacity > compact.overlayOpacity)
        #expect(expressive.scrambleShellOpacity > compact.scrambleShellOpacity)
        #expect(expressive.scrambleShellBlur > compact.scrambleShellBlur)
    }

    @Test("landing wake field tuning uses viscosity and turbulence upgrades")
    func landingWakeFieldTuningUsesViscosityAndTurbulenceUpgrades() {
        let baseline = LandingASCIIWakeFieldConfiguration.tuned(
            response: 0.5,
            spread: 0.5,
            trail: 0.5,
            viscosity: 0,
            turbulence: 0
        )
        let upgraded = LandingASCIIWakeFieldConfiguration.tuned(
            response: 0.5,
            spread: 0.5,
            trail: 0.5,
            viscosity: 1,
            turbulence: 1
        )

        #expect(upgraded.duration > baseline.duration)
        #expect(upgraded.maxRadius > baseline.maxRadius)
        #expect(upgraded.streamSwingMaxOffset > baseline.streamSwingMaxOffset)
        #expect(upgraded.streamSwingCycles > baseline.streamSwingCycles)
    }

    @Test("search wake field profile is cheaper than the landing hero profile")
    func searchWakeFieldProfileIsCheaperThanLandingHeroProfile() {
        let landing = LandingASCIIWakeFieldConfiguration.tuned(
            response: LandingWakeFieldPolicy.defaultResponse,
            spread: LandingWakeFieldPolicy.defaultSpread,
            trail: LandingWakeFieldPolicy.defaultTrail,
            viscosity: LandingWakeFieldPolicy.defaultViscosity,
            turbulence: LandingWakeFieldPolicy.defaultTurbulence,
            opacity: LandingWakeFieldPolicy.defaultOpacity,
            blur: LandingWakeFieldPolicy.defaultBlur
        )
        let search = landing.performanceTuned(for: .search)

        #expect(search.duration < landing.duration)
        #expect(search.maxTrailCount < landing.maxTrailCount)
        #expect(search.maxColumns < landing.maxColumns)
        #expect(search.maxRows < landing.maxRows)
        #expect(search.frameInterval > landing.frameInterval)
        #expect(search.streamTailLength < landing.streamTailLength)
    }

    @Test("blast samples scale with configured blast power")
    func blastSamplesScaleWithConfiguredBlastPower() {
        let origin = LandingASCIIWakeFieldEngine.TrailPoint(x: 4, y: 2)
        let soft = LandingASCIIWakeFieldEngine.blastTrailSamples(at: origin, blastPower: 12)
        let strong = LandingASCIIWakeFieldEngine.blastTrailSamples(at: origin, blastPower: 90)

        #expect(!soft.isEmpty)
        #expect(strong.count > soft.count)
        #expect(strong.allSatisfy { $0.point == origin })
        #expect(soft.allSatisfy { $0.point == origin })
        #expect(strong[0].radiusScale > soft[0].radiusScale)
        #expect(strong[0].ageOffset == 0)
        #expect(strong[1].ageOffset > strong[0].ageOffset)
    }

    @Test("default wake tuning stays bounded for the live cursor controls")
    func defaultWakeTuningStaysBoundedForLiveCursorControls() {
        let base = LandingASCIIWakeFieldConfiguration()
        let tuned = LandingASCIIWakeFieldConfiguration.tuned(
            response: LandingWakeFieldPolicy.defaultResponse,
            spread: LandingWakeFieldPolicy.defaultSpread,
            trail: LandingWakeFieldPolicy.defaultTrail,
            viscosity: LandingWakeFieldPolicy.defaultViscosity,
            turbulence: LandingWakeFieldPolicy.defaultTurbulence,
            opacity: LandingWakeFieldPolicy.defaultOpacity,
            blur: LandingWakeFieldPolicy.defaultBlur
        )

        #expect(tuned.duration < 1.9)
        #expect(tuned.maxRadius < 9.5)
        #expect(tuned.streamSwingMaxOffset < 1.25)
        #expect(tuned.duration > base.duration)
        #expect(tuned.maxRadius >= base.maxRadius)
        #expect(tuned.overlayOpacity > 0.4)
        #expect(tuned.scrambleShellOpacity > 0.15)
    }

    @Test("landing wake field converts external hover points into local geometry space")
    func landingWakeFieldConvertsExternalHoverPointsIntoLocalGeometrySpace() {
        let local = LandingASCIIWakeFieldEngine.localHoverLocation(
            from: CGPoint(x: 164, y: 141),
            in: CGRect(x: 40, y: 80, width: 300, height: 200)
        )

        #expect(local == CGPoint(x: 124, y: 61))
    }

    @Test("landing wake field maps hover points with content insets and clamps to the grid")
    func landingWakeFieldMapsHoverPointsWithInsetsAndClampsToGrid() {
        let point = LandingASCIIWakeFieldEngine.trailPoint(
            for: CGPoint(x: 90, y: 70),
            columns: 10,
            rows: 10,
            charWidth: 10,
            lineHeight: 10,
            horizontalInset: 20,
            verticalInset: 30
        )

        #expect(point.x == 7)
        #expect(point.y == 4)
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

    @Test("grid size clamps dense wake surfaces to the configured ceiling")
    func gridSizeClampsDenseWakeSurfaces() {
        let grid = LandingASCIIWakeFieldEngine.gridSize(
            for: CGSize(width: 3200, height: 1800),
            charWidth: 7,
            lineHeight: 12,
            configuration: LandingASCIIWakeFieldConfiguration(maxColumns: 150, maxRows: 40)
        )

        #expect(grid.columns == 150)
        #expect(grid.rows == 40)
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

    @Test("overlay text stays blank when only a resting hover point remains")
    func overlayTextStaysBlankForRestingHoverPoint() {
        let configuration = LandingASCIIWakeFieldConfiguration(duration: 1, maxRadius: 5, boundaryThickness: 1)
        let layout = LandingASCIIWakeFieldEngine.layout(
            vocabulary: ["ALPHA"],
            columns: 5,
            rows: 1,
            configuration: configuration
        )

        let overlay = LandingASCIIWakeFieldEngine.overlayText(
            layout: layout,
            now: 0.45,
            trails: [],
            configuration: configuration
        )

        #expect(overlay == layout.blankText)
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

}
