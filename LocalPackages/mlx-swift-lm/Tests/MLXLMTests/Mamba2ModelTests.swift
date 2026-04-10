import Foundation
import MLXLMCommon
@testable import MLXLLM
import Testing

@Test("type registry creates a standalone mamba2 model from config")
func typeRegistryCreatesMamba2Model() async throws {
    let configuration =
        """
        {
            "bos_token_id": 0,
            "chunk_size": 256,
            "conv_kernel": 4,
            "eos_token_id": 0,
            "expand": 2,
            "head_dim": 64,
            "hidden_act": "silu",
            "hidden_size": 2560,
            "initializer_range": 0.1,
            "layer_norm_epsilon": 1e-05,
            "model_type": "mamba2",
            "n_groups": 1,
            "num_heads": 80,
            "num_hidden_layers": 64,
            "pad_token_id": 0,
            "rescale_prenorm_residual": false,
            "residual_in_fp32": true,
            "rms_norm": true,
            "state_size": 128,
            "tie_word_embeddings": true,
            "time_step_floor": 0.0001,
            "time_step_limit": [0.0, Infinity],
            "time_step_max": 0.1,
            "time_step_min": 0.001,
            "time_step_rank": 256,
            "use_bias": false,
            "use_cache": true,
            "use_conv_bias": true,
            "vocab_size": 50288
        }
        """

    let model = try await LLMTypeRegistry.shared.createModel(
        configuration: Data(configuration.utf8),
        modelType: "mamba2"
    )

    #expect(model is Mamba2Model)
}

@Test("mamba2 configuration round-trips infinity time-step limits")
func mamba2ConfigurationRoundTripsInfinityTimeStepLimit() throws {
    let configuration =
        """
        {
            "model_type": "mamba2",
            "vocab_size": 50288,
            "hidden_size": 2560,
            "num_hidden_layers": 64,
            "num_heads": 80,
            "head_dim": 64,
            "state_size": 128,
            "conv_kernel": 4,
            "n_groups": 1,
            "expand": 2,
            "layer_norm_epsilon": 1e-05,
            "use_bias": false,
            "use_conv_bias": true,
            "tie_word_embeddings": true,
            "residual_in_fp32": true,
            "hidden_act": "silu",
            "time_step_limit": [0.0, Infinity]
        }
        """

    let decoded = try JSONDecoder.json5().decode(
        Mamba2Configuration.self,
        from: Data(configuration.utf8)
    )

    let encoded = try JSONEncoder().encode(decoded)
    let payload = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    let limits = try #require(payload["time_step_limit"] as? [Any])

    #expect(limits.count == 2)
    #expect(limits[0] as? Float == 0.0 || limits[0] as? Double == 0.0)
    #expect(limits[1] as? String == "Infinity")
}
