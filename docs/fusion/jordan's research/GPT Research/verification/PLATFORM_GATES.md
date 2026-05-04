# Platform Gates Not Executed in This Container

The container lacks `rustc`, `cargo`, Xcode, MLX, Metal runtime, LocalAuthentication UI, App Sandbox, App Group provisioning, and XPC packaging. The scaffold therefore distinguishes:

- **Executed portable gates:** inventory, E8 counts, Sherry 5-bit 3:4 packing, FWHT, softmax/KL, Metal entrypoint presence, Swift Touch ID/security bookmark source checks.
- **Deferred platform gates:** `cargo test --workspace`, `xcodebuild`, MLX custom kernels, XPC ProviderXPC, security-scoped bookmark runtime access, App Group shared container, KV-Direct Qwen3 benchmark.
