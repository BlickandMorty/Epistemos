import Accelerate
import Foundation

// MARK: - SemanticClusterService
// Computes legacy fallback semantic clusters using the shared embedding lookup boundary,
// then runs k-means clustering to assign semantic cluster IDs.
// Disconnected notes about the same topic will cluster together,
// complementing the Louvain topology-based clustering in Rust.
//
// All vector math uses Apple Accelerate (vDSP + BLAS) to offload
// computation to the AMX coprocessor on Apple Silicon.
//
// Wave 4.2 — Epistemos v2 roadmap.

@MainActor
enum SemanticClusterService {

    // MARK: - Public API

    /// Compute semantic cluster IDs for all graph nodes.
    /// Returns a dictionary mapping node UUID → cluster ID.
    /// Nodes without embeddings are assigned cluster 0.
    static func computeClusters(
        store: GraphStore,
        embeddingLookup: any TextEmbeddingLookup
    ) -> [String: UInt32] {
        let nodes = Array(store.nodes.values)
        guard nodes.count >= 4 else {
            return Dictionary(nodes.map { ($0.id, UInt32(0)) }, uniquingKeysWith: { first, _ in first })
        }

        // 1. Compute embeddings for each node
        let embeddings = computeEmbeddings(for: nodes, embeddingLookup: embeddingLookup)

        // Filter to nodes that got valid embeddings
        let validPairs: [(String, [Float])] = nodes.compactMap { node in
            guard let vec = embeddings[node.id], !vec.isEmpty else { return nil }
            return (node.id, vec)
        }

        guard validPairs.count >= 4 else {
            return Dictionary(nodes.map { ($0.id, UInt32(0)) }, uniquingKeysWith: { first, _ in first })
        }

        // 2. Run k-means (AMX-accelerated distance computation)
        let k = max(2, min(validPairs.count / 3, Int(sqrt(Double(validPairs.count)))))
        let vectors = validPairs.map { $0.1 }
        let assignments = kmeans(vectors: vectors, k: k, maxIterations: 30)

        // 3. Build result mapping
        var result: [String: UInt32] = [:]
        for (i, (nodeId, _)) in validPairs.enumerated() {
            result[nodeId] = UInt32(assignments[i])
        }

        // Assign unembedded nodes to cluster 0
        for node in nodes where result[node.id] == nil {
            result[node.id] = 0
        }

        Log.app.info("SemanticClusterService: clustered \(validPairs.count) nodes into \(k) clusters")
        return result
    }

    // MARK: - Embedding Computation (AMX-accelerated)

    /// Compute averaged word embeddings for each node using the shared fallback lookup.
    /// Vector accumulation uses vDSP (routes through NEON SIMD on Apple Silicon).
    private static func computeEmbeddings(
        for nodes: [GraphNodeRecord],
        embeddingLookup: any TextEmbeddingLookup
    ) -> [String: [Float]] {
        let dimension = embeddingLookup.dimension
        guard dimension > 0 else {
            Log.app.error("SemanticClusterService: fallback embedding lookup unavailable")
            return [:]
        }

        var result: [String: [Float]] = [:]

        for node in nodes {
            var text = node.label
            if let abstract = node.metadata.abstract, !abstract.isEmpty {
                text += " " + abstract
            }
            if let theme = node.metadata.clusterTheme, !theme.isEmpty {
                text += " " + theme
            }

            let words = text.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count > 1 }

            var sumVector = [Float](repeating: 0, count: dimension)
            var count = 0

            for word in words {
                if let vec = embeddingLookup.vector(for: word), vec.count == dimension {
                    // AMX/NEON vectorized: sumVector += vec
                    vDSP.add(sumVector, vec, result: &sumVector)
                    count += 1
                }
            }

            if count > 0 {
                // AMX/NEON vectorized: sumVector *= (1/count)
                var scaled = [Float](repeating: 0, count: dimension)
                let scale = 1.0 / Float(count)
                vDSP.multiply(scale, sumVector, result: &scaled)
                result[node.id] = scaled
            }
        }

        return result
    }

    // MARK: - K-Means Clustering (AMX-accelerated via BLAS)

    /// K-means clustering using cblas_sgemm for distance computation.
    /// The N×K distance matrix is computed in one AMX-accelerated matmul.
    private static func kmeans(vectors: [[Float]], k: Int, maxIterations: Int) -> [Int] {
        let n = vectors.count
        guard n > 0, k > 0 else { return [] }
        let dim = vectors[0].count

        // Flatten vectors to contiguous array for BLAS (row-major: N × D)
        var flat = [Float](repeating: 0, count: n * dim)
        for (i, vec) in vectors.enumerated() {
            flat.replaceSubrange((i * dim)..<((i + 1) * dim), with: vec)
        }

        var centroids = kmeansppInit(vectors: vectors, k: k)
        var flatCentroids = [Float](repeating: 0, count: k * dim)
        var assignments = [Int](repeating: 0, count: n)

        // Precompute squared norms of vectors (constant across iterations)
        var vecNormsSq = [Float](repeating: 0, count: n)
        for i in 0..<n {
            vecNormsSq[i] = vDSP.sumOfSquares(Array(flat[(i * dim)..<((i + 1) * dim)]))
        }

        for _ in 0..<maxIterations {
            // Flatten centroids for BLAS
            for (c, centroid) in centroids.enumerated() {
                flatCentroids.replaceSubrange((c * dim)..<((c + 1) * dim), with: centroid)
            }

            // AMX-accelerated: cross = -2 * V × C^T  (N×K matrix)
            // dist(i,c) = ||v_i||² + ||c_c||² + cross[i,c]
            var cross = [Float](repeating: 0, count: n * k)
            // Transpose centroids (K×D → D×K) then multiply V(N×D) * CT(D×K) = cross(N×K).
            var centroidsT = [Float](repeating: 0, count: dim * k)
            vDSP_mtrans(flatCentroids, 1, &centroidsT, 1, vDSP_Length(dim), vDSP_Length(k))
            vDSP_mmul(
                flat, vDSP_Stride(1),
                centroidsT, vDSP_Stride(1),
                &cross, vDSP_Stride(1),
                vDSP_Length(n), vDSP_Length(k), vDSP_Length(dim)
            )
            // Scale by -2
            var negTwo: Float = -2.0
            vDSP_vsmul(cross, 1, &negTwo, &cross, 1, vDSP_Length(n * k))

            // Centroid squared norms
            var centNormsSq = [Float](repeating: 0, count: k)
            for c in 0..<k {
                centNormsSq[c] = vDSP.sumOfSquares(centroids[c])
            }

            // Assignment step: argmin over distance
            var changed = false
            for i in 0..<n {
                var bestC = 0
                var bestDist = Float.infinity
                for c in 0..<k {
                    let dist = vecNormsSq[i] + centNormsSq[c] + cross[i * k + c]
                    if dist < bestDist {
                        bestDist = dist
                        bestC = c
                    }
                }
                if assignments[i] != bestC {
                    assignments[i] = bestC
                    changed = true
                }
            }

            if !changed { break }

            // Update centroids using vDSP
            var sums = [[Float]](repeating: [Float](repeating: 0, count: dim), count: k)
            var counts = [Int](repeating: 0, count: k)
            for i in 0..<n {
                let c = assignments[i]
                counts[c] += 1
                vDSP.add(sums[c], vectors[i], result: &sums[c])
            }
            for c in 0..<k {
                if counts[c] > 0 {
                    let scale = 1.0 / Float(counts[c])
                    vDSP.multiply(scale, sums[c], result: &centroids[c])
                }
            }
        }

        return assignments
    }

    /// K-means++ initialization: choose initial centroids that are spread apart.
    private static func kmeansppInit(vectors: [[Float]], k: Int) -> [[Float]] {
        let n = vectors.count
        guard n > 0, k > 0 else { return [] }

        var centroids: [[Float]] = []
        centroids.append(vectors[Int.random(in: 0..<n)])

        for _ in 1..<k {
            var distances = [Float](repeating: Float.infinity, count: n)
            var totalDist: Float = 0
            for i in 0..<n {
                for c in centroids {
                    let d = vDSP.distanceSquared(vectors[i], c)
                    distances[i] = min(distances[i], d)
                }
                totalDist += distances[i]
            }

            var threshold = Float.random(in: 0..<totalDist)
            var selected = 0
            for i in 0..<n {
                threshold -= distances[i]
                if threshold <= 0 {
                    selected = i
                    break
                }
            }
            centroids.append(vectors[selected])
        }

        return centroids
    }
}
