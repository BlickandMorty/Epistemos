# Source Index and Verification Anchors

This repository was generated from Jordan's Epistenos/Epistemos + Helios canon packet and verified against current public sources where the design depends on live platform or research claims.

## Internal canon anchors

- `Pasted markdown.md`: declares the build target, D1-D20 documentation inventory, C1-C42 code inventory, six phases, quality gates, and the explicit session answers: build all phases, run the KV-Direct gate and L1 implementation in parallel, and keep hot paths real while glue is stubbed.
- `helios v2.md` and `helios v3.md`: establish the residual-first Helios direction, the 12-week path, the KV-Direct gate, and the Rust + MLX + Metal substrate.
- `mac store edition(1).md` and `hermes(1).md`: establish the MAS-safe boundary: App Sandbox, XPC service, App Group, security-scoped bookmarks, and non-authoritative Hermes.

## Public anchors checked during generation

| Topic | Source | Design impact |
|---|---|---|
| KV-Direct | arXiv `2603.19664`, *The Residual Stream Is All You Need* | L1 is residual checkpoints plus K/V recomputation, not a lossy KV cache. |
| MLX unified memory | MLX docs: Unified Memory | The Swift/Rust/Metal memory path is specified around Apple silicon UMA; this scaffold does not pretend UMA is validated on Linux. |
| Apple MLX project | Apple Open Source MLX page | MLX supports Python, Swift, C, and C++ surfaces, matching the bridge strategy. |
| XPC services | Apple XPC and archived `Creating XPC Services` docs | Hermes is modeled as an isolated helper boundary, not as a child process. |
| App Sandbox and security-scoped files | Apple App Sandbox and security-scoped bookmark docs | Vault access uses user-selected directories and persistent bookmarks. |
| LocalAuthentication | Apple `LAPolicy.deviceOwnerAuthenticationWithBiometrics` | Swift biometric gate uses LAContext policy calls. |
| UniFFI Swift | Mozilla UniFFI Swift guide | Rust-to-Swift bridge is documented as a UniFFI surface, with a generated Swift API plan. |

## Honesty boundary

This scaffold includes real deterministic hot-path implementations for E8 generation, Babai-style rounding, CountSketch, sparse JL, FWHT, WBO-6 accounting, Sherry 3:4 sparse ternary pack/decode, KL measurement, recall measurement, and a deterministic event-log simulation replay. macOS-only compilation, MLX kernel execution, XPC, Touch ID, App Group containers, and SwiftData cannot be executed in this Linux container; they are supplied as code scaffolds and build instructions with explicit verification gates.
