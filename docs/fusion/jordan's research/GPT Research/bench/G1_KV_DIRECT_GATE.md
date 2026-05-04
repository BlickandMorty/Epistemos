# G1 KV-Direct Gate

## Acceptance bar

- Model: Qwen3-8B MLX 4-bit on Apple Silicon.
- Context: 32k and 128k prompts.
- Metrics: per-token KL, peak RAM, tokens/sec, token match under greedy decode.
- Pass condition: KL < 0.05, compression > 10x, peak memory inside configured target, no uncontrolled cloud escalation.

## This scaffold

The crate `helios-bench` includes the portable KL/recall metric surfaces and a CLI placeholder. The actual KV-Direct experiment requires the model and MLX runtime on macOS.
