//
//  Mamba2.swift
//  mlx-swift-lm
//
//  Ported from Hugging Face Mamba2 and adapted to the existing MLX SSM primitives.

import Foundation
import MLX
import MLXLMCommon
import MLXNN

public struct Mamba2Configuration: Codable, Sendable {
    public let modelType: String
    public let vocabSize: Int
    public let hiddenSize: Int
    public let numHiddenLayers: Int
    public let numHeads: Int
    public let headDim: Int
    public let stateSize: Int
    public let convKernel: Int
    public let nGroups: Int
    public let expand: Int
    public let layerNormEpsilon: Float
    public let useBias: Bool
    public let useConvBias: Bool
    public let tieWordEmbeddings: Bool
    public let residualInFP32: Bool
    public let hiddenAct: String
    public let timeStepLimitMin: Float
    public let timeStepLimitMax: Float

    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case vocabSize = "vocab_size"
        case hiddenSize = "hidden_size"
        case numHiddenLayers = "num_hidden_layers"
        case numHeads = "num_heads"
        case headDim = "head_dim"
        case stateSize = "state_size"
        case convKernel = "conv_kernel"
        case nGroups = "n_groups"
        case expand
        case layerNormEpsilon = "layer_norm_epsilon"
        case useBias = "use_bias"
        case useConvBias = "use_conv_bias"
        case tieWordEmbeddings = "tie_word_embeddings"
        case residualInFP32 = "residual_in_fp32"
        case hiddenAct = "hidden_act"
        case timeStepLimit = "time_step_limit"
        case timeStepLimitMin = "time_step_limit_min"
        case timeStepLimitMax = "time_step_limit_max"
    }

    private static func decodeTimeStepBound(_ value: StringOrNumber?) -> Float? {
        guard let value else { return nil }
        if let numeric = value.asFloat() {
            return numeric
        }
        guard case .string(let stringValue) = value else { return nil }
        switch stringValue.lowercased() {
        case "inf", "+inf", "infinity", "+infinity":
            return .infinity
        case "-inf", "-infinity":
            return -.infinity
        default:
            return Float(stringValue)
        }
    }

    private static func encodeTimeStepBound(_ value: Float) -> StringOrNumber {
        guard value.isFinite else {
            return .string(value.sign == .minus ? "-Infinity" : "Infinity")
        }
        return .float(value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelType = try container.decodeIfPresent(String.self, forKey: .modelType) ?? "mamba2"
        vocabSize = try container.decode(Int.self, forKey: .vocabSize)
        hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        numHiddenLayers = try container.decode(Int.self, forKey: .numHiddenLayers)
        numHeads = try container.decode(Int.self, forKey: .numHeads)
        headDim = try container.decode(Int.self, forKey: .headDim)
        stateSize = try container.decode(Int.self, forKey: .stateSize)
        convKernel = try container.decodeIfPresent(Int.self, forKey: .convKernel) ?? 4
        nGroups = try container.decodeIfPresent(Int.self, forKey: .nGroups) ?? 1
        expand = try container.decodeIfPresent(Int.self, forKey: .expand) ?? 2
        layerNormEpsilon =
            try container.decodeIfPresent(Float.self, forKey: .layerNormEpsilon) ?? 1e-5
        useBias = try container.decodeIfPresent(Bool.self, forKey: .useBias) ?? false
        useConvBias = try container.decodeIfPresent(Bool.self, forKey: .useConvBias) ?? true
        tieWordEmbeddings =
            try container.decodeIfPresent(Bool.self, forKey: .tieWordEmbeddings) ?? true
        residualInFP32 =
            try container.decodeIfPresent(Bool.self, forKey: .residualInFP32) ?? true
        hiddenAct = try container.decodeIfPresent(String.self, forKey: .hiddenAct) ?? "silu"

        if let limits = try container.decodeIfPresent([StringOrNumber].self, forKey: .timeStepLimit)
        {
            timeStepLimitMin = Self.decodeTimeStepBound(limits.first) ?? 0.0
            timeStepLimitMax =
                Self.decodeTimeStepBound(limits.dropFirst().first)
                ?? (Self.decodeTimeStepBound(limits.first) ?? .infinity)
        } else {
            timeStepLimitMin =
                try container.decodeIfPresent(Float.self, forKey: .timeStepLimitMin) ?? 0.0
            timeStepLimitMax =
                try container.decodeIfPresent(Float.self, forKey: .timeStepLimitMax)
                ?? .infinity
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modelType, forKey: .modelType)
        try container.encode(vocabSize, forKey: .vocabSize)
        try container.encode(hiddenSize, forKey: .hiddenSize)
        try container.encode(numHiddenLayers, forKey: .numHiddenLayers)
        try container.encode(numHeads, forKey: .numHeads)
        try container.encode(headDim, forKey: .headDim)
        try container.encode(stateSize, forKey: .stateSize)
        try container.encode(convKernel, forKey: .convKernel)
        try container.encode(nGroups, forKey: .nGroups)
        try container.encode(expand, forKey: .expand)
        try container.encode(layerNormEpsilon, forKey: .layerNormEpsilon)
        try container.encode(useBias, forKey: .useBias)
        try container.encode(useConvBias, forKey: .useConvBias)
        try container.encode(tieWordEmbeddings, forKey: .tieWordEmbeddings)
        try container.encode(residualInFP32, forKey: .residualInFP32)
        try container.encode(hiddenAct, forKey: .hiddenAct)
        try container.encode(
            [
                Self.encodeTimeStepBound(timeStepLimitMin),
                Self.encodeTimeStepBound(timeStepLimitMax),
            ],
            forKey: .timeStepLimit
        )
    }
}

private func applyMamba2Mask(_ hiddenStates: MLXArray, mask: MLXArray?) -> MLXArray {
    guard let mask else { return hiddenStates }
    let expandedMask = expandedDimensions(mask, axis: -1)
    return MLX.where(expandedMask, hiddenStates, MLXArray.zeros(like: hiddenStates))
}

private class Mamba2RMSNormGated: Module {
    @ParameterInfo(key: "weight") var weight: MLXArray
    let eps: Float
    let groupSize: Int

    init(dimensions: Int, eps: Float, groupSize: Int) {
        self.eps = eps
        self.groupSize = groupSize
        self._weight.wrappedValue = MLXArray.ones([dimensions])
        super.init()
    }

    func callAsFunction(_ x: MLXArray, gate: MLXArray?) -> MLXArray {
        var states = x
        if let gate {
            states = states * silu(gate)
        }

        let shape = states.shape
        var groupedShape = Array(shape.dropLast())
        groupedShape.append(-1)
        groupedShape.append(groupSize)

        let grouped = states.reshaped(groupedShape)
        let identityWeight = MLXArray.ones([groupSize])
        let normed = MLXFast.rmsNorm(grouped, weight: identityWeight, eps: eps)
        return weight * normed.reshaped(shape)
    }
}

private class Mamba2Mixer: Module {
    let numHeads: Int
    let hiddenSize: Int
    let ssmStateSize: Int
    let convKernelSize: Int
    let intermediateSize: Int
    let numGroups: Int
    let headDim: Int
    let timeStepLimit: (Float, Float)
    let convDim: Int

    @ModuleInfo(key: "conv1d") var conv1d: Conv1d
    @ModuleInfo(key: "in_proj") var inProj: Linear
    @ModuleInfo(key: "out_proj") var outProj: Linear
    @ModuleInfo(key: "norm") var norm: Mamba2RMSNormGated

    @ParameterInfo(key: "dt_bias") var dtBias: MLXArray
    @ParameterInfo(key: "A_log") var aLog: MLXArray
    @ParameterInfo(key: "D") var D: MLXArray

    init(_ args: Mamba2Configuration) {
        self.numHeads = args.numHeads
        self.hiddenSize = args.hiddenSize
        self.ssmStateSize = args.stateSize
        self.convKernelSize = args.convKernel
        self.intermediateSize = args.numHeads * args.headDim
        self.numGroups = args.nGroups
        self.headDim = args.headDim
        self.timeStepLimit = (args.timeStepLimitMin, args.timeStepLimitMax)
        self.convDim = intermediateSize + 2 * numGroups * ssmStateSize

        self._conv1d.wrappedValue = Conv1d(
            inputChannels: convDim,
            outputChannels: convDim,
            kernelSize: convKernelSize,
            groups: convDim,
            bias: args.useConvBias
        )

        let projectionSize = intermediateSize + convDim + numHeads
        self._inProj.wrappedValue = Linear(hiddenSize, projectionSize, bias: args.useBias)
        self._outProj.wrappedValue = Linear(intermediateSize, hiddenSize, bias: args.useBias)
        self._dtBias.wrappedValue = MLXArray.ones([numHeads])
        self._aLog.wrappedValue = MLX.log(MLXArray(0 ..< numHeads).asType(.float32) + 1)
        self._D.wrappedValue = MLXArray.ones([numHeads])

        let groupSize = intermediateSize / max(1, numGroups)
        self._norm.wrappedValue = Mamba2RMSNormGated(
            dimensions: intermediateSize,
            eps: args.layerNormEpsilon,
            groupSize: groupSize
        )

        super.init()
    }

    private func applyConv(_ input: MLXArray, mask: MLXArray?, cache: MambaCache?) -> MLXArray {
        let convInput = applyMamba2Mask(input, mask: mask)
        let batch = convInput.dim(0)

        var convState = cache?[0]
        if convState == nil {
            let cachedSteps = max(0, convKernelSize - 1)
            convState = MLXArray.zeros([batch, cachedSteps, convDim], dtype: convInput.dtype)
        }

        let padded = concatenated([convState!, convInput], axis: 1)
        if let cache {
            let end = padded.dim(1)
            let start = max(0, end - max(0, convKernelSize - 1))
            cache[0] = padded[0..., start ..< end, 0...]
        }

        return silu(conv1d(padded))
    }

    func callAsFunction(_ hiddenStates: MLXArray, mask: MLXArray?, cache: MambaCache?) -> MLXArray {
        let projected = inProj(applyMamba2Mask(hiddenStates, mask: mask))
        let splits = MLX.split(
            projected,
            indices: [intermediateSize, intermediateSize + convDim],
            axis: -1
        )
        let gate = splits[0]
        let convInput = splits[1]
        let dt = splits[2]

        let convOutput = applyConv(convInput, mask: mask, cache: cache)
        let convSplits = MLX.split(
            convOutput,
            indices: [intermediateSize, intermediateSize + numGroups * ssmStateSize],
            axis: -1
        )

        var hidden = convSplits[0]
        var B = convSplits[1]
        var C = convSplits[2]

        hidden = hidden.reshaped([hidden.dim(0), hidden.dim(1), numHeads, headDim])
        B = B.reshaped([B.dim(0), B.dim(1), numGroups, ssmStateSize])
        C = C.reshaped([C.dim(0), C.dim(1), numGroups, ssmStateSize])

        let previousState = cache?[1]
        let (y, nextState) = ssmUpdate(
            hiddenStates: hidden,
            ALog: aLog,
            B: B,
            C: C,
            D: D,
            dt: dt.reshaped([dt.dim(0), dt.dim(1), numHeads]),
            dtBias: dtBias,
            state: previousState,
            timeStepLimit: timeStepLimit,
            mask: mask
        )

        if let cache {
            cache[1] = nextState
        }

        return outProj(norm(y.flattened(start: 2), gate: gate))
    }
}

private class Mamba2Block: Module {
    let residualInFP32: Bool

    @ModuleInfo(key: "norm") var norm: RMSNorm
    @ModuleInfo(key: "mixer") var mixer: Mamba2Mixer

    init(_ args: Mamba2Configuration) {
        self.residualInFP32 = args.residualInFP32
        self._norm.wrappedValue = RMSNorm(dimensions: args.hiddenSize, eps: args.layerNormEpsilon)
        self._mixer.wrappedValue = Mamba2Mixer(args)
        super.init()
    }

    func callAsFunction(_ hiddenStates: MLXArray, ssmMask: MLXArray?, cache: KVCache?) -> MLXArray {
        let residual = residualInFP32 ? hiddenStates.asType(.float32) : hiddenStates
        let mixed = mixer(norm(hiddenStates), mask: ssmMask, cache: cache as? MambaCache)
        return residual + mixed
    }
}

private class Mamba2Backbone: Module {
    @ModuleInfo(key: "embeddings") var embeddings: Embedding
    @ModuleInfo(key: "layers") var layers: [Mamba2Block]
    @ModuleInfo(key: "norm_f") var normF: RMSNorm

    init(_ args: Mamba2Configuration) {
        self._embeddings.wrappedValue = Embedding(
            embeddingCount: args.vocabSize,
            dimensions: args.hiddenSize
        )
        self._layers.wrappedValue = (0 ..< args.numHiddenLayers).map { _ in Mamba2Block(args) }
        self._normF.wrappedValue = RMSNorm(
            dimensions: args.hiddenSize,
            eps: args.layerNormEpsilon
        )
        super.init()
    }

    func callAsFunction(_ inputs: MLXArray, cache: [KVCache]? = nil) -> MLXArray {
        var hidden = embeddings(inputs)
        let cacheArray: [KVCache?] =
            cache?.map(Optional.some) ?? Array(repeating: nil, count: layers.count)
        let firstCache = cacheArray.first ?? nil
        let ssmMask = createSSMMask(h: hidden, cache: firstCache as? MambaCache)

        for (index, layer) in layers.enumerated() {
            hidden = layer(hidden, ssmMask: ssmMask, cache: cacheArray[index])
        }

        return normF(hidden)
    }
}

public class Mamba2Model: Module, LLMModel, KVCacheDimensionProvider {
    public let vocabularySize: Int
    public let kvHeads: [Int]

    @ModuleInfo(key: "backbone") private var backbone: Mamba2Backbone
    @ModuleInfo(key: "lm_head") var lmHead: Linear?

    let configuration: Mamba2Configuration

    public init(_ args: Mamba2Configuration) {
        self.configuration = args
        self.vocabularySize = args.vocabSize
        self.kvHeads = Array(repeating: 0, count: args.numHiddenLayers)
        self._backbone.wrappedValue = Mamba2Backbone(args)

        if !args.tieWordEmbeddings {
            self._lmHead.wrappedValue = Linear(args.hiddenSize, args.vocabSize, bias: false)
        }

        super.init()
    }

    public func callAsFunction(_ inputs: MLXArray, cache: [KVCache]?) -> MLXArray {
        var out = backbone(inputs, cache: cache)
        if let lmHead {
            out = lmHead(out)
        } else {
            out = backbone.embeddings.asLinear(out)
        }
        return out
    }

    public func newCache(parameters: GenerateParameters?) -> [KVCache] {
        (0 ..< configuration.numHiddenLayers).map { _ in MambaCache() }
    }

    public func sanitize(weights: [String: MLXArray]) -> [String: MLXArray] {
        var sanitized = [String: MLXArray]()
        for (key, value) in weights {
            if key.contains("conv1d.weight"), value.dim(-1) != 1 {
                sanitized[key] = value.swappedAxes(1, 2)
            } else {
                sanitized[key] = value
            }
        }
        return sanitized
    }
}

extension Mamba2Model: LoRAModel {
    public var loraLayers: [Module] {
        backbone.layers
    }
}
