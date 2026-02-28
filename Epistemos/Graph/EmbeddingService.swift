import Accelerate
import Foundation
import NaturalLanguage

// MARK: - Sendable Helpers

/// Value-type snapshot of node data for cross-isolation transfer.
private struct EmbeddingNodeSnapshot: Sendable {
    let id: String
    let text: String
}

/// Wraps an OpaquePointer for safe cross-isolation transfer.
/// The pointer is only dereferenced back on MainActor (never on the background thread).
private struct SendablePointer: @unchecked Sendable {
    let pointer: OpaquePointer?
    init(_ pointer: OpaquePointer?) { self.pointer = pointer }
}

// MARK: - EmbeddingService
// Generates word embeddings using Apple NLEmbedding and pushes them to the Rust engine
// for SIMD-accelerated cosine similarity, KNN search, and semantic attraction force.
//
// Heavy computation (NLEmbedding + vector math) runs on a background thread via
// Task.detached. Only the FFI push hops back to MainActor since the engine pointer
// is not thread-safe.

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

        // Snapshot node data for background processing (pure-value copy, no shared refs).
        let nodeSnapshots: [EmbeddingNodeSnapshot] = store.nodes.values.map { node in
            var text = node.label
            if let abstract = node.metadata.abstract, !abstract.isEmpty {
                text += " " + abstract
            }
            if let theme = node.metadata.clusterTheme, !theme.isEmpty {
                text += " " + theme
            }
            return EmbeddingNodeSnapshot(id: node.id, text: text)
        }
        guard nodeSnapshots.count >= 2 else { return }

        // Wrap engine pointer for safe cross-isolation transfer.
        // Only dereferenced back on MainActor in the completion block.
        let engineWrapper = SendablePointer(engineHandle)

        // Heavy compute on background thread — NLEmbedding word lookups + vector math.
        // Task.detached escapes @MainActor isolation so this doesn't block rendering.
        computeTask = Task.detached(priority: .utility) { [weak self] in
            guard let nlEmbedding = NLEmbedding.wordEmbedding(for: .english) else {
                await MainActor.run { Log.app.error("EmbeddingService: NLEmbedding unavailable") }
                return
            }

            let dim = nlEmbedding.dimension
            var newEmbeddings: [String: [Float]] = [:]
            var floatBuffer = [Float](repeating: 0, count: dim)

            for snapshot in nodeSnapshots {
                guard !Task.isCancelled else { return }

                let words = snapshot.text.lowercased()
                    .components(separatedBy: .alphanumerics.inverted)
                    .filter { $0.count > 1 }

                var sumVector = [Float](repeating: 0, count: dim)
                var count = 0

                for word in words {
                    if let vec = nlEmbedding.vector(for: word) {
                        vDSP.convertElements(of: vec, to: &floatBuffer)
                        vDSP.add(sumVector, floatBuffer, result: &sumVector)
                        count += 1
                    }
                }

                if count > 0 {
                    var scaled = [Float](repeating: 0, count: dim)
                    vDSP.multiply(1.0 / Float(count), sumVector, result: &scaled)
                    newEmbeddings[snapshot.id] = scaled
                }
            }

            guard !Task.isCancelled else { return }

            // Hop back to MainActor for state update + FFI push.
            // Engine pointer accessed ONLY here — never leaves MainActor isolation.
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.embeddings = newEmbeddings
                self.dimension = dim

                guard let engine = engineWrapper.pointer else { return }
                for (uuid, vector) in newEmbeddings {
                    vector.withUnsafeBufferPointer { buf in
                        guard let base = buf.baseAddress else { return }
                        uuid.withCString { cUuid in
                            graph_engine_set_node_embedding(engine, cUuid, base, UInt32(dim))
                        }
                    }
                }

                graph_engine_recompute_semantic_neighbors(engine, 8, 0.3)

                Log.app.info("EmbeddingService: pushed \(newEmbeddings.count) embeddings (dim=\(dim)) to Rust")
            }
        }
    }

    /// Get embedding for a specific node (for hybrid search).
    func embedding(for nodeId: String) -> [Float]? {
        embeddings[nodeId]
    }
}
