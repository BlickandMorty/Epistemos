import Foundation
import MLX
import MLXLMCommon
import Testing

@Test(
    .serialized,
    arguments: [
        ({ KVCacheSimple() }),
        ({ RotatingKVCache(maxSize: 32) }),
        ({ QuantizedKVCache() }),
        ({ KIVIKVCache(groupSize: 32, bits: 2, residualLength: 32) }),
        ({ ChunkedKVCache(chunkSize: 16) }),
        ({ ArraysCache(size: 2) }),
        ({ MambaCache() }),
    ])
func testCacheSerialization(creator: (() -> any KVCache)) async throws {
    try Device.withDefaultDevice(.cpu) {
        let cache = (0 ..< 10).map { _ in creator() }
        let keys = MLXArray.ones([1, 8, 32, 64], dtype: .bfloat16)
        let values = MLXArray.ones([1, 8, 32, 64], dtype: .bfloat16)
        for item in cache {
            switch item {
            case let arrays as ArraysCache:
                arrays[0] = keys
                arrays[1] = values
            case let quantized as QuantizedKVCache:
                _ = quantized.updateQuantized(keys: keys, values: values)
            default:
                _ = item.update(keys: keys, values: values)
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("safetensors")

        try savePromptCache(url: url, cache: cache, metadata: [:])
        let (loadedCache, _) = try loadPromptCache(url: url)

        #expect(cache.count == loadedCache.count)
        for (lhs, rhs) in zip(cache, loadedCache) {
            #expect(type(of: lhs) == type(of: rhs))
            #expect(lhs.metaState == rhs.metaState)
            #expect(lhs.state.count == rhs.state.count)
        }
    }
}

@Test(.serialized)
func testCacheListSerializationIsRejected() throws {
    let cache: [any KVCache] = [CacheList(MambaCache(), KVCacheSimple())]
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("safetensors")

    #expect(throws: (any Error).self) {
        try savePromptCache(url: url, cache: cache, metadata: [:])
    }
}

@Test
func testGenerateParametersDefaultToAffineKVScheme() {
    let parameters = GenerateParameters()

    #expect(parameters.kvScheme == .affine)
}

@Test(.serialized)
func testKIVIKVCacheFormsGroupedAndResidualState() {
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
    }
}

@Test(.serialized)
func testKIVIKVCacheSerializationRoundTrips() throws {
    try Device.withDefaultDevice(.cpu) {
        let cache: [any KVCache] = [KIVIKVCache(groupSize: 32, bits: 2, residualLength: 32)]
        let keys = MLXArray.ones([1, 2, 96, 64], dtype: .bfloat16)
        let values = MLXArray.ones([1, 2, 96, 64], dtype: .bfloat16)

        _ = cache[0].update(keys: keys, values: values)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("safetensors")

        try savePromptCache(url: url, cache: cache, metadata: [:])
        let (loadedCache, _) = try loadPromptCache(url: url)

        #expect(loadedCache.count == 1)
        #expect(type(of: loadedCache[0]) == type(of: cache[0]))
        #expect(loadedCache[0].metaState == cache[0].metaState)
        #expect(loadedCache[0].state.count == cache[0].state.count)
    }
}
