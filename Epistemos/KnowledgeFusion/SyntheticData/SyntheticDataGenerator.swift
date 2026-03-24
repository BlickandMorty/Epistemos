import Foundation

// MARK: - Progress Reporting

nonisolated struct SyntheticDataProgress: Sendable {
    let phase: SyntheticDataPhase
    let chunksProcessed: Int
    let totalChunks: Int
    let pairsGenerated: Int
    let pairsAccepted: Int
    let pairsDiscarded: Int

    var fractionComplete: Double {
        guard totalChunks > 0 else { return 0 }
        return Double(chunksProcessed) / Double(totalChunks)
    }
}

nonisolated enum SyntheticDataPhase: String, Sendable {
    case generating = "Generating training pairs..."
    case curating = "Curating and classifying..."
    case writing = "Writing JSONL files..."
    case complete = "Complete"
}

// MARK: - Result

struct SyntheticDataResult: Sendable {
    let trainingFiles: [TrainingPairCategory: URL]
    let evalFile: URL?
    let totalGenerated: Int
    let totalAccepted: Int
    let totalDiscarded: Int
    let totalDuplicates: Int
    let categoryBreakdown: [TrainingPairCategory: Int]
    let evalHeldOutCount: Int
}

// MARK: - SyntheticDataGenerator

/// Orchestrates the full synthetic data pipeline for a batch of TextChunks.
/// Input: [TextChunk] from Phase 1 (Data Ingestion)
/// Output: JSONL training files (knowledge/style/tool) + eval holdout
///
/// Research paper: "Synthetic Data Generation Pipeline" section.
/// Uses Instruction Backtranslation (Self-Instruct methodology).
actor SyntheticDataGenerator {

    private let backtranslator: InstructionBacktranslator
    private let curator: QualityCurator
    private let outputDirectory: URL

    init(
        inferenceProvider: KFInferenceProvider,
        outputDirectory: URL,
        qualityThreshold: Int = 3,
        evalHoldoutRatio: Double = 0.10
    ) {
        self.backtranslator = InstructionBacktranslator(inferenceProvider: inferenceProvider)
        self.curator = QualityCurator(
            qualityThreshold: qualityThreshold,
            evalHoldoutRatio: evalHoldoutRatio
        )
        self.outputDirectory = outputDirectory
    }

    /// Run the full pipeline on a batch of chunks.
    /// Calls progressHandler after each chunk for UI updates.
    func generate(
        chunks: [TextChunk],
        progressHandler: (@Sendable (SyntheticDataProgress) -> Void)? = nil
    ) async throws -> SyntheticDataResult {
        guard !chunks.isEmpty else {
            return SyntheticDataResult(
                trainingFiles: [:],
                evalFile: nil,
                totalGenerated: 0,
                totalAccepted: 0,
                totalDiscarded: 0,
                totalDuplicates: 0,
                categoryBreakdown: [:],
                evalHeldOutCount: 0
            )
        }

        // Step 1: Generate pairs from all chunks
        var allPairs: [GeneratedPair] = []
        allPairs.reserveCapacity(chunks.count * 3)

        for (index, chunk) in chunks.enumerated() {
            do {
                let pairs = try await backtranslator.backtranslate(chunk: chunk)
                allPairs.append(contentsOf: pairs)
            } catch {
                // Per-chunk errors don't abort the pipeline
                continue
            }

            progressHandler?(SyntheticDataProgress(
                phase: .generating,
                chunksProcessed: index + 1,
                totalChunks: chunks.count,
                pairsGenerated: allPairs.count,
                pairsAccepted: 0,
                pairsDiscarded: 0
            ))
        }

        // Step 2: Curate (quality filter, dedup, classify, holdout)
        progressHandler?(SyntheticDataProgress(
            phase: .curating,
            chunksProcessed: chunks.count,
            totalChunks: chunks.count,
            pairsGenerated: allPairs.count,
            pairsAccepted: 0,
            pairsDiscarded: 0
        ))

        let curationResult = curator.curate(pairs: allPairs)

        // Step 3: Write JSONL files
        progressHandler?(SyntheticDataProgress(
            phase: .writing,
            chunksProcessed: chunks.count,
            totalChunks: chunks.count,
            pairsGenerated: allPairs.count,
            pairsAccepted: curationResult.accepted.count,
            pairsDiscarded: curationResult.discardedCount
        ))

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let trainingFiles = try curator.writeJSONL(
            pairs: curationResult.accepted,
            outputDirectory: outputDirectory,
            timestamp: timestamp
        )

        let evalFile = try curator.writeEvalJSONL(
            pairs: curationResult.evalHeldOut,
            outputDirectory: outputDirectory,
            timestamp: timestamp
        )

        progressHandler?(SyntheticDataProgress(
            phase: .complete,
            chunksProcessed: chunks.count,
            totalChunks: chunks.count,
            pairsGenerated: allPairs.count,
            pairsAccepted: curationResult.accepted.count,
            pairsDiscarded: curationResult.discardedCount
        ))

        return SyntheticDataResult(
            trainingFiles: trainingFiles,
            evalFile: evalFile,
            totalGenerated: allPairs.count,
            totalAccepted: curationResult.accepted.count,
            totalDiscarded: curationResult.discardedCount,
            totalDuplicates: curationResult.duplicateCount,
            categoryBreakdown: curationResult.categoryBreakdown,
            evalHeldOutCount: curationResult.evalHeldOut.count
        )
    }
}
