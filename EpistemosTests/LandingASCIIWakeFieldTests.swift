import Testing
@testable import Epistemos

@Suite("Landing ASCII Wake Field")
struct LandingASCIIWakeFieldTests {
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
            now: 0.9,
            trails: trails,
            configuration: configuration
        )

        #expect(overlay.contains("A") || overlay.contains("L") || overlay.contains("P") || overlay.contains("H"))
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
