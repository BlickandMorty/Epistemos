import Foundation
import NaturalLanguage

// MARK: - SemanticClusterService
// Computes on-device embeddings for graph nodes using Apple NLEmbedding,
// then runs k-means clustering to assign semantic cluster IDs.
// Disconnected notes about the same topic will cluster together,
// complementing the Louvain topology-based clustering in Rust.
//
// Wave 4.2 — Epistemos v2 roadmap.

@MainActor
enum SemanticClusterService {

    // MARK: - Public API

    /// Compute semantic cluster IDs for all graph nodes.
    /// Returns a dictionary mapping node UUID → cluster ID.
    /// Nodes without embeddings are assigned cluster 0.
    static func computeClusters(store: GraphStore) -> [String: UInt32] {
        let nodes = Array(store.nodes.values)
        guard nodes.count >= 4 else {
            // Too few nodes to cluster meaningfully
            return Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, UInt32(0)) })
        }

        // 1. Compute embeddings for each node
        let embeddings = computeEmbeddings(for: nodes)

        // Filter to nodes that got valid embeddings
        let validPairs: [(String, [Float])] = nodes.compactMap { node in
            guard let vec = embeddings[node.id], !vec.isEmpty else { return nil }
            return (node.id, vec)
        }

        guard validPairs.count >= 4 else {
            return Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, UInt32(0)) })
        }

        // 2. Run k-means
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

    // MARK: - Embedding Computation

    /// Compute averaged word embeddings for each node using Apple NLEmbedding.
    /// Uses the node label (+ body snippet for notes via metadata).
    private static func computeEmbeddings(for nodes: [GraphNodeRecord]) -> [String: [Float]] {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            Log.app.error("SemanticClusterService: NLEmbedding unavailable for English")
            return [:]
        }

        let dimension = embedding.dimension

        var result: [String: [Float]] = [:]
        for node in nodes {
            // Build text to embed: label + abstract/description if available
            var text = node.label
            if let abstract = node.metadata.abstract, !abstract.isEmpty {
                text += " " + abstract
            }
            if let theme = node.metadata.clusterTheme, !theme.isEmpty {
                text += " " + theme
            }

            // Tokenize and average word vectors
            let words = text.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count > 1 }

            var sumVector = [Float](repeating: 0, count: dimension)
            var count = 0

            for word in words {
                if let vec = embedding.vector(for: word) {
                    for (i, v) in vec.enumerated() {
                        sumVector[i] += Float(v)
                    }
                    count += 1
                }
            }

            if count > 0 {
                let scale = 1.0 / Float(count)
                result[node.id] = sumVector.map { $0 * scale }
            }
        }

        return result
    }

    // MARK: - K-Means Clustering

    /// Simple k-means clustering on float vectors.
    /// Returns an array of cluster assignments (0-based) parallel to `vectors`.
    private static func kmeans(vectors: [[Float]], k: Int, maxIterations: Int) -> [Int] {
        let n = vectors.count
        guard n > 0, k > 0 else { return [] }
        let dim = vectors[0].count

        // Initialize centroids with k-means++ seeding
        var centroids = kmeansppInit(vectors: vectors, k: k)
        var assignments = [Int](repeating: 0, count: n)

        for _ in 0..<maxIterations {
            // Assignment step: assign each vector to nearest centroid
            var changed = false
            for i in 0..<n {
                var bestCluster = 0
                var bestDist = Float.infinity
                for c in 0..<k {
                    let dist = squaredDistance(vectors[i], centroids[c])
                    if dist < bestDist {
                        bestDist = dist
                        bestCluster = c
                    }
                }
                if assignments[i] != bestCluster {
                    assignments[i] = bestCluster
                    changed = true
                }
            }

            if !changed { break }

            // Update step: recompute centroids
            var sums = [[Float]](repeating: [Float](repeating: 0, count: dim), count: k)
            var counts = [Int](repeating: 0, count: k)
            for i in 0..<n {
                let c = assignments[i]
                counts[c] += 1
                for d in 0..<dim {
                    sums[c][d] += vectors[i][d]
                }
            }
            for c in 0..<k {
                if counts[c] > 0 {
                    let scale = 1.0 / Float(counts[c])
                    centroids[c] = sums[c].map { $0 * scale }
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
        // Pick first centroid randomly
        centroids.append(vectors[Int.random(in: 0..<n)])

        for _ in 1..<k {
            // Compute distance from each point to nearest centroid
            var distances = [Float](repeating: Float.infinity, count: n)
            var totalDist: Float = 0
            for i in 0..<n {
                for c in centroids {
                    let d = squaredDistance(vectors[i], c)
                    distances[i] = min(distances[i], d)
                }
                totalDist += distances[i]
            }

            // Weighted random selection proportional to squared distance
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

    /// Squared Euclidean distance between two vectors.
    private static func squaredDistance(_ a: [Float], _ b: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<min(a.count, b.count) {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sum
    }
}
