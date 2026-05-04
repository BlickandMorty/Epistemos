# Epistenos Cognitive Operating System Scaffold

This is the first build packet for the Epistenos/Epistemos Helios substrate: a ten-crate Rust workspace, Metal kernel pack, Swift UI shell, D1-D20 documentation set, and verification harness.

## What is real now

- Hot-path CPU implementations: E8 shell generation, Babai-style rounding, CountSketch, sparse JL, FRP/FWHT, Sherry 3:4 sparse ternary packing, WBO-6 accounting, KL and recall metrics.
- Platform scaffolds: MLX kernel registry, Metal kernels, SwiftUI vault manager, biometric gate, Simulation v1.6 Landing Farm, Hermes capability boundary, UniFFI-facing Rust API.
- Verification: `python3 tools/verify_hotpath.py` checks the required inventory and portable mathematical invariants.

## What requires macOS/Apple Silicon

- Xcode Swift build, SwiftData, LocalAuthentication UI prompts, App Sandbox, App Group containers, XPC service packaging, MLX custom Metal kernels, and the KV-Direct Qwen3 gate.

## First commands

```bash
python3 tools/verify_hotpath.py
bash scripts/verify.sh
```

If Rust is installed, `scripts/verify.sh` also runs `cargo test --workspace`.
