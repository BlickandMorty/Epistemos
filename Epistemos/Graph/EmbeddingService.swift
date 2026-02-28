import Foundation
import NaturalLanguage

// MARK: - EmbeddingService
// Generates word embeddings using Apple NLEmbedding and pushes them to the Rust engine
// for SIMD-accelerated cosine similarity, KNN search, and semantic attraction force.
//
// Runs async on a background task — doesn't block rendering or physics.

@MainActor
final class EmbeddingService {

    /// Cached embeddings (node UUID → float vector).
    private(set) var embeddings: [String: [Float]] = [:]

    /// Embedding dimension (from NLEmbedding — typically 512).
    private(set) var dimension: Int = 0

    private var computeTask: Task<Void, Never>?

    /// Compute embeddings for all graph nodes and push to the Rust engine.
    /// Call after commitGraphData() when the graph has been loaded.
    func computeAndPush(store: GraphStore, engineHandle: OpaquePointer?) {
        computeTask?.cancel()
        computeTask = Task { [weak self] in
            guard let self else { return }

            // Compute on the current actor (MainActor) — NLEmbedding is fast (ms-scale)
            let nodes = Array(store.nodes.values)
            guard nodes.count >= 2 else { return }

            guard let nlEmbedding = NLEmbedding.wordEmbedding(for: .english) else {
                Log.app.error("EmbeddingService: NLEmbedding unavailable")
                return
            }

            let dim = nlEmbedding.dimension
            self.dimension = dim
            var newEmbeddings: [String: [Float]] = [:]

            for node in nodes {
                guard !Task.isCancelled else { return }

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

                var sumVector = [Float](repeating: 0, count: dim)
                var count = 0

                for word in words {
                    if let vec = nlEmbedding.vector(for: word) {
                        for (i, v) in vec.enumerated() {
                            sumVector[i] += Float(v)
                        }
                        count += 1
                    }
                }

                if count > 0 {
                    let scale = 1.0 / Float(count)
                    newEmbeddings[node.id] = sumVector.map { $0 * scale }
                }
            }

            guard !Task.isCancelled else { return }

            self.embeddings = newEmbeddings

            // Push to Rust engine
            guard let engine = engineHandle else { return }
            for (uuid, vector) in newEmbeddings {
                vector.withUnsafeBufferPointer { buf in
                    guard let base = buf.baseAddress else { return }
                    uuid.withCString { cUuid in
                        graph_engine_set_node_embedding(engine, cUuid, base, UInt32(dim))
                    }
                }
            }

            // Recompute KNN pairs for semantic force (top-8 neighbors, threshold 0.3)
            graph_engine_recompute_semantic_neighbors(engine, 8, 0.3)

            Log.app.info("EmbeddingService: pushed \(newEmbeddings.count) embeddings (dim=\(dim)) to Rust")
        }
    }

    /// Get embedding for a specific node (for hybrid search).
    func embedding(for nodeId: String) -> [Float]? {
        embeddings[nodeId]
    }
}
