import Testing
@testable import Epistemos

@Suite("Adaptation Stabilizer")
struct AdaptationStabilizerTests {

    @Test("gradient norm check accepts within cap")
    func gradientNormAcceptsWithinCap() {
        let stabilizer = AdaptationStabilizer(gradientNormCap: 1.0)
        #expect(stabilizer.isGradientNormAcceptable(0.5))
        #expect(stabilizer.isGradientNormAcceptable(1.0))
        #expect(!stabilizer.isGradientNormAcceptable(1.1))
    }

    @Test("gradient norm rejects NaN and infinity")
    func gradientNormRejectsInvalid() {
        let stabilizer = AdaptationStabilizer()
        #expect(!stabilizer.isGradientNormAcceptable(.nan))
        #expect(!stabilizer.isGradientNormAcceptable(.infinity))
    }

    @Test("canary evaluation uses threshold multiplier")
    func canaryEvaluationThreshold() {
        let stabilizer = AdaptationStabilizer(canaryLossThresholdMultiplier: 2.0)
        #expect(stabilizer.evaluateCanary(baselineLoss: 1.0, currentLoss: 1.5))
        #expect(stabilizer.evaluateCanary(baselineLoss: 1.0, currentLoss: 2.0))
        #expect(!stabilizer.evaluateCanary(baselineLoss: 1.0, currentLoss: 2.1))
    }

    @Test("canary evaluation rejects zero baseline")
    func canaryRejectsZeroBaseline() {
        let stabilizer = AdaptationStabilizer()
        #expect(!stabilizer.evaluateCanary(baselineLoss: 0, currentLoss: 0.5))
    }

    @Test("anchor divergence computation")
    func anchorDivergence() {
        let stabilizer = AdaptationStabilizer()
        let current = [1.0, 2.0, 3.0]
        let anchor = [1.0, 2.0, 3.0]
        #expect(stabilizer.computeAnchorDivergence(currentWeightNorms: current, anchorWeightNorms: anchor) == 0)

        let diverged = [2.0, 3.0, 4.0]
        let div = stabilizer.computeAnchorDivergence(currentWeightNorms: diverged, anchorWeightNorms: anchor)
        #expect(div > 0)
    }

    @Test("EMA anchor update")
    func emaAnchorUpdate() {
        let stabilizer = AdaptationStabilizer(anchorEMAAlpha: 0.1)
        let anchor = [1.0, 1.0, 1.0]
        let newWeights = [2.0, 2.0, 2.0]
        let updated = stabilizer.updatedAnchorNorms(currentAnchor: anchor, newWeightNorms: newWeights)
        #expect(updated.count == 3)
        #expect(abs(updated[0] - 1.1) < 0.001)
    }

    @Test("checkpoint trimming respects max")
    func checkpointTrimming() {
        let stabilizer = AdaptationStabilizer(maxCheckpoints: 3)
        let checkpoints = (0..<5).map { i in
            AdapterCheckpoint(
                checkpointURL: URL(fileURLWithPath: "/tmp/cp\(i)"),
                updateIndex: i,
                canaryLoss: Double(i) * 0.5 + 0.1,
                anchorDivergence: 0.01,
                timestamp: Date()
            )
        }
        let trimmed = stabilizer.trimmedCheckpoints(checkpoints)
        #expect(trimmed.count == 3)
        #expect(trimmed.first?.updateIndex == 2)
    }

    @Test("best rollback target picks lowest canary loss")
    func bestRollbackTarget() {
        let stabilizer = AdaptationStabilizer()
        let checkpoints = [
            AdapterCheckpoint(checkpointURL: URL(fileURLWithPath: "/tmp/a"), updateIndex: 0, canaryLoss: 1.5, anchorDivergence: 0.1, timestamp: Date()),
            AdapterCheckpoint(checkpointURL: URL(fileURLWithPath: "/tmp/b"), updateIndex: 1, canaryLoss: 0.8, anchorDivergence: 0.05, timestamp: Date()),
            AdapterCheckpoint(checkpointURL: URL(fileURLWithPath: "/tmp/c"), updateIndex: 2, canaryLoss: 1.2, anchorDivergence: 0.08, timestamp: Date()),
        ]
        let best = stabilizer.bestRollbackTarget(checkpoints)
        #expect(best?.updateIndex == 1)
        #expect(best?.canaryLoss == 0.8)
    }

    @Test("default canary prompts cover expected categories")
    func defaultCanaryPrompts() {
        let prompts = AdaptationStabilizer.defaultCanaryPrompts
        #expect(prompts.count == 10)
        let categories = Set(prompts.map(\.expectedCategory))
        #expect(categories.contains("factual"))
        #expect(categories.contains("code"))
        #expect(categories.contains("summarization"))
        #expect(categories.contains("structured"))
    }

    @Test("canary outcome aggregation")
    func canaryOutcomeAggregation() {
        let stabilizer = AdaptationStabilizer(canaryLossThresholdMultiplier: 2.0)
        let results = [
            CanaryResult(prompt: AdaptationStabilizer.defaultCanaryPrompts[0], loss: 1.0, passed: true),
            CanaryResult(prompt: AdaptationStabilizer.defaultCanaryPrompts[1], loss: 1.5, passed: true),
            CanaryResult(prompt: AdaptationStabilizer.defaultCanaryPrompts[2], loss: 0.8, passed: true),
        ]
        let outcome = stabilizer.buildCanaryOutcome(results: results, baselineLoss: 1.0)
        #expect(outcome.allPassed)
        #expect(outcome.failedCount == 0)
        #expect(abs(outcome.averageLoss - 1.1) < 0.01)
    }
}
