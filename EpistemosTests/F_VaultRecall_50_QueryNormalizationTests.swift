import Testing
@testable import Epistemos

struct FVaultRecall50QueryNormalizationTests {
    @Test("vault command boilerplate is not required as FTS terms")
    func vaultCommandBoilerplateIsNotRequiredAsFTSTerms() {
        let query = SearchIndexService.sanitizeFTS5Query(
            "Pull my notes on The Recentering of Virtue please"
        )

        #expect(query == "\"recentering\"* \"of\"* \"virtue\"*")
    }

    @Test("original note title queries keep title signal")
    func originalNoteTitleQueriesKeepTitleSignal() {
        let query = SearchIndexService.sanitizeFTS5Query(
            "original note titled GRAPH_REPORT"
        )

        #expect(query == "\"graph\"* \"report\"*")
    }

    @Test("all boilerplate queries keep a nonempty fallback")
    func allBoilerplateQueriesKeepNonemptyFallback() {
        let query = SearchIndexService.sanitizeFTS5Query("show my notes please")

        #expect(query == "\"show\"* \"my\"* \"notes\"* \"please\"*")
    }
}
