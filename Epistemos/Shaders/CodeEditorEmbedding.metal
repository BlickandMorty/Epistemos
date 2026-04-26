// CodeEditorEmbedding.metal
//
// GPU-accelerated batch cosine similarity + L2 normalization kernels for
// the code editor's semantic-search embedding pipeline.
//
// Wave 4.1 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md`,
//  cross-ref dpp §4.1 Sprint 3 deep perf).
//
// These kernels were previously embedded as a Swift string in
// `Epistemos/Views/Notes/CodeEditorView.swift` and compiled at runtime
// via `device.makeLibrary(source:options:)` — a multi-millisecond cost
// paid on every CodeEditorView instantiation. Lifting them into a
// standalone `.metal` file lets Xcode's Metal build phase compile them
// once at app-build time into `default.metallib`, which the runtime
// loads via `device.makeDefaultLibrary()` in microseconds.
//
// Build flags applied automatically by Xcode (release config):
//   -O3 -ffast-math
// (see Build Settings → Metal Compiler / Optimization Level)

#include <metal_stdlib>
using namespace metal;

/// GPU-accelerated batch cosine similarity for the embedding-search hot
/// path. One thread per document; computes dot product + per-vector norms
/// in a single unrolled loop.
kernel void cosineSimilarityBatch(
    device const float* query     [[buffer(0)]],
    device const float* documents [[buffer(1)]],
    device float* output          [[buffer(2)]],
    constant uint& dim            [[buffer(3)]],
    constant uint& numDocs        [[buffer(4)]],
    uint gid                      [[thread_position_in_grid]]
) {
    if (gid >= numDocs) return;

    float dotProduct = 0.0;
    float queryNorm = 0.0;
    float docNorm = 0.0;

    // Unrolled loop for common embedding dimensions (768, 1024, 1536).
    #pragma unroll(4)
    for (uint i = 0; i < dim; i++) {
        float q = query[i];
        float d = documents[gid * dim + i];
        dotProduct += q * d;
        queryNorm += q * q;
        docNorm += d * d;
    }

    float similarity = 0.0;
    if (queryNorm > 0.0 && docNorm > 0.0) {
        similarity = dotProduct / (sqrt(queryNorm) * sqrt(docNorm));
    }

    output[gid] = similarity;
}

/// L2 normalization for embedding preprocessing. One thread per vector;
/// two unrolled passes (sum-of-squares, then divide).
kernel void batchNormalize(
    device const float* input     [[buffer(0)]],
    device float* output          [[buffer(1)]],
    constant uint& dim            [[buffer(2)]],
    constant uint& numVectors     [[buffer(3)]],
    uint gid                      [[thread_position_in_grid]]
) {
    if (gid >= numVectors) return;

    float sumSquares = 0.0;
    uint offset = gid * dim;

    #pragma unroll(4)
    for (uint i = 0; i < dim; i++) {
        float val = input[offset + i];
        sumSquares += val * val;
    }

    float norm = sqrt(sumSquares);
    float invNorm = (norm > 0.0) ? (1.0 / norm) : 0.0;

    #pragma unroll(4)
    for (uint i = 0; i < dim; i++) {
        output[offset + i] = input[offset + i] * invNorm;
    }
}
