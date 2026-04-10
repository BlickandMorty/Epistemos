import Foundation

nonisolated enum CustomSSMRuntimeSupport {
    static let halfScalarStride = 2

    static var isAvailable: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }
}

nonisolated struct SSMRuntimeProfile: Sendable, Equatable {
    let layers: Int
    let heads: Int
    let stateDimension: Int
    let headDimension: Int
    let chunkLength: Int
    let tileSize: Int
    let warmsCustomMetalRuntime: Bool

    nonisolated var stateBytes: Int {
        layers * heads * stateDimension * headDimension * CustomSSMRuntimeSupport.halfScalarStride
    }

    nonisolated var recommendedHeapSizeBytes: Int {
        max(stateBytes * 3, 16 * 1_024 * 1_024)
    }
}

extension LocalTextModelID {
    nonisolated var ssmRuntimeProfile: SSMRuntimeProfile? {
        switch self {
        case .lfm25_350M:
            SSMRuntimeProfile(
                layers: 24,
                heads: 16,
                stateDimension: 16,
                headDimension: 64,
                chunkLength: 64,
                tileSize: 2,
                warmsCustomMetalRuntime: false
            )

        case .lfm25_1BInstruct, .lfm25_1BThinking, .lfm25_VL1B:
            SSMRuntimeProfile(
                layers: 48,
                heads: 32,
                stateDimension: 64,
                headDimension: 64,
                chunkLength: 128,
                tileSize: 1,
                warmsCustomMetalRuntime: false
            )

        case .mamba2_2B4Bit:
            SSMRuntimeProfile(
                layers: 64,
                heads: 32,
                stateDimension: 64,
                headDimension: 64,
                chunkLength: 128,
                tileSize: 1,
                warmsCustomMetalRuntime: CustomSSMRuntimeSupport.isAvailable
            )

        case .jamba3B:
            SSMRuntimeProfile(
                layers: 32,
                heads: 32,
                stateDimension: 16,
                headDimension: 64,
                chunkLength: 128,
                tileSize: 1,
                warmsCustomMetalRuntime: false
            )

        default:
            nil
        }
    }
}
