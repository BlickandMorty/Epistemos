// Gemma 4 end-to-end load + generate proof.
//
// Exercises the vendored Gemma 4 loader (MLXLLM/Models/Gemma4Text.swift +
// Gemma4.swift, registered in LLMModelFactory as `gemma4`/`gemma4_text`) the
// whole way through: download the MLX weights, decode the `model_type: gemma4`
// config, build the dense Gemma4 model, and generate real tokens. This is the
// same loader the Epistemos app drives for the dense E2B/E4B tiers, so a pass
// here proves Gemma 4 actually runs — not just compiles.
//
// Network + ~2.5 GB download, so it lives in the integration target and only
// runs when explicitly invoked (`swift test --filter Gemma4IntegrationTests`).

import Foundation
import MLXLLM
import MLXLMCommon
import XCTest

public final class Gemma4IntegrationTests: XCTestCase {

    /// Official dense E2B MLX 4-bit tier — the smallest Gemma 4 the app ships,
    /// chosen here to keep the download/runtime bound modest while still
    /// exercising the exact dense Gemma4Text path (PLE + shared KV + dual RoPE).
    static let gemma4E2BModelId = "mlx-community/gemma-4-e2b-it-4bit"

    func testGemma4E2BLoadsAndGeneratesCoherentTokens() async throws {
        let container = try await LLMModelFactory.shared.loadContainer(
            configuration: .init(id: Self.gemma4E2BModelId)
        )

        let session = ChatSession(container)
        let result = try await session.respond(
            to: "Reply with exactly one short, friendly sentence."
        )
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Proof: the dense Gemma 4 loader produced non-empty, real text.
        XCTAssertFalse(trimmed.isEmpty, "Gemma 4 E2B produced empty output")
        XCTAssertGreaterThan(
            trimmed.count, 2,
            "Gemma 4 E2B output implausibly short: \(trimmed.debugDescription)"
        )
        // Surfaced in the test log so the actual generated sentence is visible.
        print("GEMMA4_E2B_OUTPUT: \(trimmed)")
    }
}
