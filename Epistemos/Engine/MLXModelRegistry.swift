import Foundation

struct MLXModelSpec: Identifiable, Sendable, Codable, Equatable {
    let id: String
    let hfId: String
    let displayName: String
    let family: String
    let quantization: String
    let sizeGB: Double
}

enum MLXModelRegistry {

    static let models: [MLXModelSpec] = [
        // 0.8B — triage, compaction, quick answers
        MLXModelSpec(id: "qwen3.5-0.8b-q4", hfId: "mlx-community/Qwen3.5-0.8B-MLX-4bit",
                     displayName: "Qwen 3.5 0.8B Q4", family: "0.8B", quantization: "Q4", sizeGB: 0.7),
        MLXModelSpec(id: "qwen3.5-0.8b-q8", hfId: "mlx-community/Qwen3.5-0.8B-MLX-8bit",
                     displayName: "Qwen 3.5 0.8B Q8", family: "0.8B", quantization: "Q8", sizeGB: 1.1),
        // 2B — Librarian tasks
        MLXModelSpec(id: "qwen3.5-2b-q4", hfId: "mlx-community/Qwen3.5-2B-MLX-4bit",
                     displayName: "Qwen 3.5 2B Q4", family: "2B", quantization: "Q4", sizeGB: 1.8),
        MLXModelSpec(id: "qwen3.5-2b-q8", hfId: "mlx-community/Qwen3.5-2B-MLX-8bit",
                     displayName: "Qwen 3.5 2B Q8", family: "2B", quantization: "Q8", sizeGB: 2.8),
        // 4B — Writer/Builder tasks
        MLXModelSpec(id: "qwen3.5-4b-q4", hfId: "mlx-community/Qwen3.5-4B-MLX-4bit",
                     displayName: "Qwen 3.5 4B Q4", family: "4B", quantization: "Q4", sizeGB: 2.8),
        MLXModelSpec(id: "qwen3.5-4b-q8", hfId: "mlx-community/Qwen3.5-4B-MLX-8bit",
                     displayName: "Qwen 3.5 4B Q8", family: "4B", quantization: "Q8", sizeGB: 5.6),
        // 9B — complex analysis (high-memory Macs only)
        MLXModelSpec(id: "qwen3.5-9b-q4", hfId: "mlx-community/Qwen3.5-9B-MLX-4bit",
                     displayName: "Qwen 3.5 9B Q4", family: "9B", quantization: "Q4", sizeGB: 5.6),
    ]

    static var groupedByFamily: [(family: String, models: [MLXModelSpec])] {
        let grouped = Dictionary(grouping: models) { $0.family }
        return ["0.8B", "2B", "4B", "9B"].compactMap { family in
            guard let specs = grouped[family] else { return nil }
            return (family: family, models: specs)
        }
    }

    static func find(id: String) -> MLXModelSpec? {
        models.first { $0.id == id }
    }

    static func find(hfId: String) -> MLXModelSpec? {
        models.first { $0.hfId == hfId }
    }

    static func modelsForMemory(availableGB: Double) -> [MLXModelSpec] {
        models.filter { $0.sizeGB <= availableGB }
    }
}
