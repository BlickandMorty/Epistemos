import Foundation
import Testing

@testable import Epistemos

@Suite("SDMessage")
struct SDMessageTests {
    @MainActor
    @Test("content block encode failures clear stale blobs")
    func contentBlockEncodeFailuresClearStaleBlobs() {
        let message = SDMessage(role: "assistant", content: "old")
        message.setContentBlocks([.text("stable")])
        #expect(message.decodedContentBlocks() == [.text("stable")])

        message.setContentBlocks([
            .toolUse(
                id: "tool-1",
                name: "demo",
                input: ["value": .double(.nan)]
            )
        ])

        #expect(message.contentBlocksData == nil)
        #expect(message.decodedContentBlocks() == nil)
        #expect(message.content.isEmpty)
    }

    @MainActor
    @Test("analysis encode failures clear stale analysis blobs while keeping scalar updates")
    func analysisEncodeFailuresClearStaleAnalysisBlobsWhileKeepingScalarUpdates() {
        let message = SDMessage(role: "assistant", content: "analysis")
        message.updateAnalysis(
            dualMessage: DualMessage(
                rawAnalysis: "ok",
                uncertaintyTags: [],
                modelVsDataFlags: [],
                laymanSummary: nil,
                reflection: nil,
                arbitration: nil
            ),
            truthAssessment: TruthAssessment(
                overallTruthLikelihood: 0.9,
                signalInterpretation: "strong",
                weaknesses: [],
                improvements: [],
                blindSpots: [],
                confidenceCalibration: "good",
                dataVsModelBalance: "balanced",
                recommendedActions: []
            ),
            confidence: 0.9,
            evidenceGrade: .a,
            mode: .local
        )
        #expect(message.dualMessageData != nil)
        #expect(message.truthAssessmentData != nil)

        message.updateAnalysis(
            dualMessage: DualMessage(
                rawAnalysis: "bad",
                uncertaintyTags: [],
                modelVsDataFlags: [],
                laymanSummary: nil,
                reflection: nil,
                arbitration: ArbitrationResult(
                    consensus: false,
                    votes: [
                        EngineVote(
                            engine: .synthesis,
                            position: .neutral,
                            reasoning: "nan",
                            confidence: .nan
                        )
                    ],
                    disagreements: [],
                    resolution: "retry"
                )
            ),
            truthAssessment: TruthAssessment(
                overallTruthLikelihood: .nan,
                signalInterpretation: "bad",
                weaknesses: [],
                improvements: [],
                blindSpots: [],
                confidenceCalibration: "bad",
                dataVsModelBalance: "bad",
                recommendedActions: []
            ),
            confidence: 0.2,
            evidenceGrade: .d,
            mode: .api
        )

        #expect(message.dualMessageData == nil)
        #expect(message.truthAssessmentData == nil)
        #expect(message.confidenceScore == 0.2)
        #expect(message.evidenceGrade == EvidenceGrade.d.rawValue)
        #expect(message.inferenceMode == InferenceMode.api.rawValue)
    }
}
