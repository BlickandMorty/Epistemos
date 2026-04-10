import Foundation
import Metal

enum Mamba2ForwardPassError: LocalizedError, Sendable {
    case diagnosticRequiresAppleSilicon

    var errorDescription: String? {
        switch self {
        case .diagnosticRequiresAppleSilicon:
            "The Mamba2 Metal diagnostic pass is available only on Apple Silicon builds."
        }
    }
}

struct Mamba2ForwardPassConfiguration: Sendable {
    var batchSize: Int = 1
    var sequenceLength: Int = 256
    var headCount: Int = 4
    var stateDimension: Int = 32
    var modelDimension: Int = 64
    var chunkLength: Int = 128
    var tileSize: Int = 1

    var chunkCount: Int {
        max(1, (sequenceLength + chunkLength - 1) / chunkLength)
    }

    var activationElementCount: Int {
        batchSize * sequenceLength * modelDimension
    }

    var decayElementCount: Int {
        batchSize * sequenceLength * headCount
    }

    var chunkStateElementCount: Int {
        chunkCount * headCount * stateDimension
    }

    var chunkDecayElementCount: Int {
        chunkCount * headCount
    }

    var tileCount: Int {
        max(1, (chunkCount + tileSize - 1) / tileSize)
    }

    var tileStateElementCount: Int {
        tileCount * headCount * stateDimension
    }

    var lMatrixElementCount: Int {
        batchSize * chunkCount * headCount * chunkLength * chunkLength
    }
}

struct Mamba2ForwardPassDiagnosticResult: Sendable {
    let configuration: Mamba2ForwardPassConfiguration
    let elapsedMS: Double
    let output: [Float]
    let chunkStates: [Float]
    let lMatrixPreview: [Float]
}

final class Mamba2ForwardPass {
    private let runtime: MetalRuntimeManager

    init(runtime: MetalRuntimeManager) {
        self.runtime = runtime
    }

    #if arch(arm64)
    func runDiagnosticPass(
        configuration: Mamba2ForwardPassConfiguration = .init()
    ) throws -> Mamba2ForwardPassDiagnosticResult {
        try runtime.ensureKernelsReady()

        let aLogValues = repeatingHalfArray(
            count: configuration.decayElementCount,
            pattern: [-0.22, -0.18, -0.14, -0.10]
        )
        let step1InputValues = repeatingHalfArray(
            count: configuration.batchSize * configuration.sequenceLength * configuration.headCount,
            pattern: [0.25, 0.5, 0.75, 1.0]
        )
        let step1WeightValues = repeatingHalfArray(
            count: configuration.headCount * configuration.modelDimension,
            pattern: [0.4, 0.15, -0.05, 0.2]
        )
        let step2InputValues = repeatingHalfArray(
            count: configuration.chunkCount * configuration.headCount * configuration.stateDimension,
            pattern: [0.1, 0.2, 0.3, 0.4]
        )
        let step2WeightValues = repeatingHalfArray(
            count: configuration.stateDimension * configuration.stateDimension,
            pattern: [0.6, 0.0, 0.1, 0.0]
        )
        let step4InputValues = repeatingHalfArray(
            count: configuration.batchSize * configuration.sequenceLength * configuration.headCount,
            pattern: [0.12, 0.24, 0.36, 0.48]
        )
        let step4WeightValues = repeatingHalfArray(
            count: configuration.headCount * configuration.modelDimension,
            pattern: [0.2, -0.05, 0.1, 0.3]
        )
        let gateValues = repeatingHalfArray(
            count: configuration.activationElementCount,
            pattern: [0.25, -0.2, 0.15, 0.45]
        )
        let chunkDecayValues = repeatingHalfArray(
            count: configuration.chunkDecayElementCount,
            pattern: [0.95, 0.9, 0.85, 0.8]
        )

        let aLog = try runtime.makeSharedBuffer(from: aLogValues, label: "mamba2.alog")
        let cumulativeDecay = try runtime.makeSharedBuffer(
            length: configuration.decayElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.cum_decay"
        )
        let decay = try runtime.makeSharedBuffer(
            length: configuration.decayElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.decay"
        )
        let lMatrix = try runtime.makeSharedBuffer(
            length: configuration.lMatrixElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.l_matrix"
        )

        let step1Input = try runtime.makeSharedBuffer(from: step1InputValues, label: "mamba2.step1_input")
        let step1Weights = try runtime.makeSharedBuffer(from: step1WeightValues, label: "mamba2.step1_weights")
        let yDiag = try runtime.makeSharedBuffer(
            length: configuration.activationElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.y_diag"
        )

        let step2Input = try runtime.makeSharedBuffer(from: step2InputValues, label: "mamba2.step2_input")
        let step2Weights = try runtime.makeSharedBuffer(from: step2WeightValues, label: "mamba2.step2_weights")
        let chunkStates = try runtime.makeSharedBuffer(
            length: configuration.chunkStateElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.chunk_states"
        )
        let chunkDecays = try runtime.makeSharedBuffer(from: chunkDecayValues, label: "mamba2.chunk_decays")
        let tileStates = try runtime.makeSharedBuffer(
            length: configuration.tileStateElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.tile_states"
        )
        let tileDecays = try runtime.makeSharedBuffer(
            length: configuration.tileCount * configuration.headCount * MemoryLayout<Float16>.stride,
            label: "mamba2.tile_decays"
        )

        let step4Input = try runtime.makeSharedBuffer(from: step4InputValues, label: "mamba2.step4_input")
        let step4Weights = try runtime.makeSharedBuffer(from: step4WeightValues, label: "mamba2.step4_weights")
        let yOff = try runtime.makeSharedBuffer(
            length: configuration.activationElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.y_off"
        )
        let merged = try runtime.makeSharedBuffer(
            length: configuration.activationElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.merged"
        )
        let gate = try runtime.makeSharedBuffer(from: gateValues, label: "mamba2.gate")
        let output = try runtime.makeSharedBuffer(
            length: configuration.activationElementCount * MemoryLayout<Float16>.stride,
            label: "mamba2.output"
        )

        guard let commandBuffer = runtime.makeCommandBuffer(label: "mamba2_diagnostic_forward_pass") else {
            throw MetalRuntimeManager.RuntimeError.commandBufferCreationFailed
        }

        let start = CFAbsoluteTimeGetCurrent()
        try runtime.encodeIntraChunkScan(
            commandBuffer: commandBuffer,
            aLog: aLog,
            cumulativeDecay: cumulativeDecay,
            batchSize: configuration.batchSize,
            sequenceLength: configuration.sequenceLength,
            headCount: configuration.headCount,
            chunkLength: configuration.chunkLength
        )
        try runtime.encodeChunkStateDecay(
            commandBuffer: commandBuffer,
            cumulativeDecay: cumulativeDecay,
            decay: decay,
            elementCount: configuration.decayElementCount
        )
        try runtime.encodeSegsumTiled(
            commandBuffer: commandBuffer,
            aLog: aLog,
            lMatrix: lMatrix,
            batchSize: configuration.batchSize,
            sequenceLength: configuration.sequenceLength,
            headCount: configuration.headCount,
            chunkLength: configuration.chunkLength
        )
        runtime.encodeMatmul(
            commandBuffer: commandBuffer,
            leftBuffer: step1Input,
            rightBuffer: step1Weights,
            resultBuffer: yDiag,
            rows: configuration.batchSize * configuration.sequenceLength,
            columns: configuration.modelDimension,
            inner: configuration.headCount,
            label: "mamba2.step1_matmul"
        )
        runtime.encodeMatmul(
            commandBuffer: commandBuffer,
            leftBuffer: step2Input,
            rightBuffer: step2Weights,
            resultBuffer: chunkStates,
            rows: configuration.chunkCount * configuration.headCount,
            columns: configuration.stateDimension,
            inner: configuration.stateDimension,
            label: "mamba2.step2_matmul"
        )
        try runtime.encodeInterChunkStatePassing(
            commandBuffer: commandBuffer,
            chunkStates: chunkStates,
            chunkDecays: chunkDecays,
            tileStates: tileStates,
            tileDecays: tileDecays,
            chunkCount: configuration.chunkCount,
            headCount: configuration.headCount,
            stateDim: configuration.stateDimension,
            tileSize: configuration.tileSize
        )
        runtime.encodeMatmul(
            commandBuffer: commandBuffer,
            leftBuffer: step4Input,
            rightBuffer: step4Weights,
            resultBuffer: yOff,
            rows: configuration.batchSize * configuration.sequenceLength,
            columns: configuration.modelDimension,
            inner: configuration.headCount,
            label: "mamba2.step4_matmul"
        )
        try runtime.encodeOutputMerge(
            commandBuffer: commandBuffer,
            diagonalOutput: yDiag,
            stateOutput: yOff,
            mergedOutput: merged,
            elementCount: configuration.activationElementCount
        )
        try runtime.encodeSiluGate(
            commandBuffer: commandBuffer,
            input: merged,
            gate: gate,
            output: output,
            elementCount: configuration.activationElementCount
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let elapsedMS = (CFAbsoluteTimeGetCurrent() - start) * 1000

        guard commandBuffer.status == .completed else {
            throw MetalRuntimeManager.RuntimeError.commandBufferFailed(
                commandBuffer.error?.localizedDescription ?? "unknown Metal runtime failure"
            )
        }

        let outputValues = runtime
            .readSharedBuffer(output, as: Float16.self, count: configuration.activationElementCount)
            .map(Float.init)
        let chunkStateValues = runtime
            .readSharedBuffer(chunkStates, as: Float16.self, count: configuration.chunkStateElementCount)
            .map(Float.init)
        let lMatrixPreview = runtime
            .readSharedBuffer(lMatrix, as: Float16.self, count: min(configuration.chunkLength, 16))
            .map(Float.init)

        return Mamba2ForwardPassDiagnosticResult(
            configuration: configuration,
            elapsedMS: elapsedMS,
            output: outputValues,
            chunkStates: chunkStateValues,
            lMatrixPreview: lMatrixPreview
        )
    }

    private func repeatingHalfArray(count: Int, pattern: [Float]) -> [Float16] {
        guard !pattern.isEmpty else { return Array(repeating: Float16.zero, count: count) }
        return (0 ..< count).map { index in
            Float16(pattern[index % pattern.count])
        }
    }
    #else
    func runDiagnosticPass(
        configuration: Mamba2ForwardPassConfiguration = .init()
    ) throws -> Mamba2ForwardPassDiagnosticResult {
        _ = configuration
        _ = runtime
        throw Mamba2ForwardPassError.diagnosticRequiresAppleSilicon
    }
    #endif
}
