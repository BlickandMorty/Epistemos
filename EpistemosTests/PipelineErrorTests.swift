import Testing
@testable import Epistemos

@Suite("PipelineError")
struct PipelineErrorTests {

    @Test("noLLMService has descriptive message")
    func noLLMServiceDescription() {
        let err = PipelineError.noLLMService
        #expect(err.errorDescription != nil)
        #expect(err.errorDescription!.contains("API key") || err.errorDescription!.contains("LLM"))
    }

    @Test("analysisFailure includes the message")
    func analysisFailureDescription() {
        let err = PipelineError.analysisFailure("Something went wrong")
        #expect(err.errorDescription == "Something went wrong")
    }
}

@Suite("PipelineStage")
struct PipelineStageTests {

    @Test("all 10 stages exist")
    func stageCount() {
        #expect(PipelineStage.allCases.count == 10)
    }

    @Test("stages have unique raw values")
    func uniqueRawValues() {
        let rawValues = PipelineStage.allCases.map { $0.rawValue }
        #expect(Set(rawValues).count == PipelineStage.allCases.count)
    }

    @Test("stages have display names")
    func displayNames() {
        for stage in PipelineStage.allCases {
            #expect(!stage.displayName.isEmpty, "\(stage) should have a display name")
        }
    }
}
