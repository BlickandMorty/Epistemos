# Changelog

## Purpose

v0.1.0 scaffold: C1-C42 inventory, D1-D20 docs, ten-crate workspace, Metal kernels, Swift UI, verification harness, and KV-Direct gate report stub.

## Build-status truth table

| Layer | Status in this scaffold | Next proof obligation |
|---|---|---|
| Core math | Implemented CPU hot paths and unit-testable APIs | Compile with Rust toolchain and add proptest/criterion on macOS/Linux CI |
| MLX/Metal | MSL kernels and CPU golden references present | Run MLX custom-kernel smoke tests on Apple silicon |
| Runtime | Gate, agents, Hermes grants, self-tuning archive implemented as deterministic scaffolds | Bind to XPC/App Group/SwiftData on macOS |
| Swift UI | Vault manager, biometric gate, dashboards, Landing Farm v1.6 surfaces present | Build with Xcode and wire generated UniFFI Swift module |
| Benchmark | KL, recall, KV-Direct gate, and red-team harness stubs present | Run Qwen3-8B MLX 4-bit at 32k/128k context on target hardware |

## Engineering invariants

1. L1 is residual-first: store residual checkpoints; recompute K/V from residuals in the platform model harness.
2. Every token or event must have a `ResonanceSignature` before it crosses an agent or cloud boundary.
3. Hermes is non-authoritative: it receives leased `CapabilityGrant` values and all cloud claims return as Composite.
4. The portable core forbids unsafe code and external runtime assumptions.
5. UI animation is never proof of work; Simulation v1.6 uses event logs and reduce-motion fallback.

## Source anchors

See `docs/SOURCE_INDEX.md` for the internal canon and public sources checked during generation.
