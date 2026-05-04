# Verification Report

Generated: 2026-05-03

## Executed portable gates

Command:

```bash
cd /mnt/data/epistenos_os_scaffold
python3 tools/verify_hotpath.py
bash scripts/verify.sh
```

Results:

| Gate | Result |
|---|---:|
| D1-D20 required docs present | PASS |
| C1-C42 required code surfaces present | PASS |
| E8 norm-2 shell count | 240 PASS |
| E8 norm-4 shell count | 2160 PASS |
| Sherry 3:4 sparse ternary 5-bit packing | PASS |
| FWHT golden vector | PASS |
| Softmax sums to one and identical-logit KL is zero | PASS |
| Metal kernel entrypoint presence | PASS |
| Swift LAContext biometric gate source present | PASS |
| Swift security-scoped bookmark source present | PASS |

## Explicitly not executed here

This Linux container does not have `rustc`, `cargo`, Xcode, MLX, Metal runtime, SwiftData, LocalAuthentication UI prompts, App Sandbox/App Group provisioning, or XPC packaging. The Rust/macOS/platform gates are therefore marked as deferred, not passed.

## Artifacts

- `verification/hotpath_verification.json`
- `verification/verify_sh_output.txt`
- `verification/PLATFORM_GATES.md`
