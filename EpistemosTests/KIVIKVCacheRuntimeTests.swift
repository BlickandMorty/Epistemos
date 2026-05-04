import Foundation
import MLX
import MLXLMCommon
import Testing

@Suite("KIVI KV Cache Runtime")
struct KIVIKVCacheRuntimeTests {
    private func deterministicTensor(shape: [Int], scale: Float, bias: Float) -> MLXArray {
        let count = shape.reduce(1, *)
        let values = (0 ..< count).map { index in
            (Float((index * 7) % 23) - 11.0) * scale + bias
        }
        return MLXArray(values).reshaped(shape)
    }

    private func maxAbsoluteDifference(_ lhs: MLXArray, _ rhs: MLXArray) -> Float? {
        let lhsValues = lhs.asArray(Float.self)
        let rhsValues = rhs.asArray(Float.self)
        guard lhsValues.count == rhsValues.count else { return nil }

        var maxDifference: Float = 0
        for (lhsValue, rhsValue) in zip(lhsValues, rhsValues) {
            maxDifference = max(maxDifference, abs(lhsValue - rhsValue))
        }
        return maxDifference
    }

    private func fullPrecisionAttention(
        queries: MLXArray,
        keys: MLXArray,
        values: MLXArray,
        scale: Float
    ) -> MLXArray {
        let scores = matmul(queries * scale, keys.swappedAxes(-1, -2))
        return matmul(softmax(scores, axis: -1), values)
    }

    @Test("forms grouped quantized state plus residual window inside the app harness")
    func formsGroupedStateAndResidualWindow() {
        Device.withDefaultDevice(.cpu) {
            let cache = KIVIKVCache(groupSize: 32, bits: 2, residualLength: 32)
            let keys = MLXArray.ones([1, 2, 96, 64], dtype: .bfloat16)
            let values = MLXArray.ones([1, 2, 96, 64], dtype: .bfloat16)

            let (cachedKeys, cachedValues) = cache.update(keys: keys, values: values)

            #expect(cache.offset == 96)
            #expect(cachedKeys.dim(2) == 96)
            #expect(cachedValues.dim(2) == 96)
            #expect(cache.state.count == 8)
            #expect(cache.metaState == ["KIVI", "96", "32", "2", "32"])
            #expect(cache.state[6].dim(2) == 32)
            #expect(cache.state[7].dim(2) == 32)
        }
    }

    @Test("round-trips prompt-cache serialization inside the app harness")
    func roundTripsPromptCacheSerialization() throws {
        try Device.withDefaultDevice(.cpu) {
            let cache: [any KVCache] = [KIVIKVCache(groupSize: 32, bits: 2, residualLength: 32)]
            let keys = MLXArray.ones([1, 2, 96, 64], dtype: .bfloat16)
            let values = MLXArray.ones([1, 2, 96, 64], dtype: .bfloat16)

            _ = cache[0].update(keys: keys, values: values)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("safetensors")
            defer { try? FileManager.default.removeItem(at: url) }

            try savePromptCache(url: url, cache: cache, metadata: [:])
            let (loadedCache, _) = try loadPromptCache(url: url)

            #expect(loadedCache.count == 1)
            #expect(type(of: loadedCache[0]) == type(of: cache[0]))
            #expect(loadedCache[0].metaState == cache[0].metaState)
            #expect(loadedCache[0].state.count == cache[0].state.count)
        }
    }

    @Test("causal mask blocks future residual keys")
    func causalMaskBlocksFutureResidualKeys() {
        Device.withDefaultDevice(.cpu) {
            let queries = MLXArray([0.0 as Float, 0.0 as Float]).reshaped([1, 1, 2, 1])
            let keys = MLXArray([0.0 as Float, 0.0 as Float]).reshaped([1, 1, 2, 1])
            let values = MLXArray([10.0 as Float, 20.0 as Float]).reshaped([1, 1, 2, 1])

            let output = kiviScaledDotProductAttention(
                queries: queries,
                quantizedKeyTrans: nil,
                residualKeys: keys,
                quantizedValues: nil,
                residualValues: values,
                scale: 1,
                mask: .causal
            )
            let flat = output.asArray(Float.self)

            #expect(abs(flat[0] - 10.0) < 0.001)
            #expect(abs(flat[1] - 15.0) < 0.001)
        }
    }

    @Test("attention stays within deterministic tolerance after grouped flush")
    func attentionStaysWithinDeterministicToleranceAfterGroupedFlush() throws {
        try Device.withDefaultDevice(.cpu) {
            let groupSize = 32
            let residualLength = 32
            let headDimension = 32
            let attentionScale = 1 / sqrt(Float(headDimension))
            let kivi = KIVIKVCache(
                groupSize: groupSize,
                bits: 2,
                residualLength: residualLength
            )
            let reference = KVCacheSimple()
            let prefillKeys = deterministicTensor(shape: [1, 1, 64, headDimension], scale: 0.01, bias: 0.02)
            let prefillValues = deterministicTensor(shape: [1, 1, 64, headDimension], scale: 0.012, bias: -0.015)
            let stepKeys = deterministicTensor(shape: [1, 1, 1, headDimension], scale: 0.009, bias: 0.01)
            let stepValues = deterministicTensor(shape: [1, 1, 1, headDimension], scale: 0.011, bias: 0.005)
            let queries = deterministicTensor(shape: [1, 1, 1, headDimension], scale: 0.008, bias: -0.01)

            _ = kivi.update(keys: prefillKeys, values: prefillValues)
            _ = reference.update(keys: prefillKeys, values: prefillValues)

            #expect(kivi.state.count == 8)

            let kiviOutput = kivi.attention(
                queries: queries,
                keys: stepKeys,
                values: stepValues,
                scale: attentionScale,
                mask: .none
            )
            let (referenceKeys, referenceValues) = reference.update(keys: stepKeys, values: stepValues)
            // Arithmetic tolerance only; model-level quality and default-on behavior
            // still require separate Qwen-family perplexity validation.
            let referenceOutput = fullPrecisionAttention(
                queries: queries,
                keys: referenceKeys,
                values: referenceValues,
                scale: attentionScale
            )

            let maxDifference = try #require(maxAbsoluteDifference(kiviOutput, referenceOutput))
            #expect(maxDifference < 0.035, "KIVI max abs diff \(maxDifference) exceeded 2-bit tolerance")
        }
    }
}
