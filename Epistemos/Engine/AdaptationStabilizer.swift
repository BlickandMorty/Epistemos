import Foundation

// MARK: - Canary Validation

nonisolated struct CanaryPrompt: Sendable, Equatable {
    let prompt: String
    let expectedCategory: String
}

nonisolated struct CanaryResult: Sendable {
    let prompt: CanaryPrompt
    let loss: Double
    let passed: Bool
}

nonisolated struct CanaryValidationOutcome: Sendable {
    let results: [CanaryResult]
    let averageLoss: Double
    let allPassed: Bool
    let failedCount: Int
}

// MARK: - Adapter Checkpoint

nonisolated struct AdapterCheckpoint: Sendable, Equatable {
    let checkpointURL: URL
    let updateIndex: Int
    let canaryLoss: Double
    let anchorDivergence: Double
    let timestamp: Date
}

// MARK: - AdaptationStabilizer

nonisolated struct AdaptationStabilizer: Sendable {

    static let defaultCanaryPrompts: [CanaryPrompt] = [
        CanaryPrompt(prompt: "What is the capital of France?", expectedCategory: "factual"),
        CanaryPrompt(prompt: "Summarize this paragraph in two sentences.", expectedCategory: "summarization"),
        CanaryPrompt(prompt: "Write a Python function that sorts a list.", expectedCategory: "code"),
        CanaryPrompt(prompt: "Explain photosynthesis to a 10-year-old.", expectedCategory: "explanation"),
        CanaryPrompt(prompt: "Convert this to JSON: name=Alice, age=30", expectedCategory: "structured"),
        CanaryPrompt(prompt: "What are the pros and cons of remote work?", expectedCategory: "reasoning"),
        CanaryPrompt(prompt: "Fix this bug: for i in range(10) print(i)", expectedCategory: "code"),
        CanaryPrompt(prompt: "Translate to Spanish: The weather is nice today.", expectedCategory: "translation"),
        CanaryPrompt(prompt: "List three uses of machine learning in healthcare.", expectedCategory: "factual"),
        CanaryPrompt(prompt: "Rewrite formally: hey can u help me with this thing?", expectedCategory: "style"),
    ]

    let canaryPrompts: [CanaryPrompt]
    let canaryLossThresholdMultiplier: Double
    let gradientNormCap: Double
    let anchorEMAAlpha: Double
    let maxCheckpoints: Int

    init(
        canaryPrompts: [CanaryPrompt] = AdaptationStabilizer.defaultCanaryPrompts,
        canaryLossThresholdMultiplier: Double = 2.0,
        gradientNormCap: Double = 1.0,
        anchorEMAAlpha: Double = 0.1,
        maxCheckpoints: Int = 5
    ) {
        self.canaryPrompts = canaryPrompts
        self.canaryLossThresholdMultiplier = canaryLossThresholdMultiplier
        self.gradientNormCap = gradientNormCap
        self.anchorEMAAlpha = anchorEMAAlpha
        self.maxCheckpoints = maxCheckpoints
    }

    // MARK: - Gradient Norm Check

    func isGradientNormAcceptable(_ norm: Double) -> Bool {
        norm <= gradientNormCap && norm.isFinite && !norm.isNaN
    }

    // MARK: - Canary Validation

    func evaluateCanary(
        baselineLoss: Double,
        currentLoss: Double
    ) -> Bool {
        guard baselineLoss > 0, currentLoss.isFinite, !currentLoss.isNaN else {
            return false
        }
        return currentLoss <= baselineLoss * canaryLossThresholdMultiplier
    }

    func buildCanaryOutcome(
        results: [CanaryResult],
        baselineLoss: Double
    ) -> CanaryValidationOutcome {
        let avgLoss = results.isEmpty ? 0 : results.map(\.loss).reduce(0, +) / Double(results.count)
        let failedResults = results.filter { !$0.passed }
        let allPassed = failedResults.isEmpty && evaluateCanary(baselineLoss: baselineLoss, currentLoss: avgLoss)

        return CanaryValidationOutcome(
            results: results,
            averageLoss: avgLoss,
            allPassed: allPassed,
            failedCount: failedResults.count
        )
    }

    // MARK: - Anchor Divergence

    func computeAnchorDivergence(
        currentWeightNorms: [Double],
        anchorWeightNorms: [Double]
    ) -> Double {
        guard currentWeightNorms.count == anchorWeightNorms.count,
              !currentWeightNorms.isEmpty else {
            return 0
        }

        var sumSquaredDiff: Double = 0
        for (current, anchor) in zip(currentWeightNorms, anchorWeightNorms) {
            let diff = current - anchor
            sumSquaredDiff += diff * diff
        }
        return (sumSquaredDiff / Double(currentWeightNorms.count)).squareRoot()
    }

    // MARK: - EMA Anchor Update

    func updatedAnchorNorms(
        currentAnchor: [Double],
        newWeightNorms: [Double]
    ) -> [Double] {
        guard currentAnchor.count == newWeightNorms.count else {
            return newWeightNorms
        }
        let alpha = anchorEMAAlpha
        return zip(currentAnchor, newWeightNorms).map { anchor, current in
            alpha * current + (1.0 - alpha) * anchor
        }
    }

    // MARK: - Rollback Log Management

    func trimmedCheckpoints(_ checkpoints: [AdapterCheckpoint]) -> [AdapterCheckpoint] {
        if checkpoints.count <= maxCheckpoints {
            return checkpoints
        }
        return Array(checkpoints.suffix(maxCheckpoints))
    }

    func bestRollbackTarget(_ checkpoints: [AdapterCheckpoint]) -> AdapterCheckpoint? {
        checkpoints
            .filter { $0.canaryLoss > 0 }
            .min(by: { $0.canaryLoss < $1.canaryLoss })
    }
}
