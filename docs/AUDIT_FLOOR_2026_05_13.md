# Audit Floor — 2026-05-13

Canonical reproducibility baseline for future research drops.
Closes RCA8-P1-001.

```text
audit_floor_commit:                 6546db9ef10cbe0419bccb859b3ee1b16370bfc4
audit_floor_commit_message:         docs(audit): close RCA8-P0-001 + RCA8-P0-002 — SwiftData in-memory recovery explicit + zero-inheritance subprocess launches
audit_floor_date:                   2026-05-13
audit_floor_branch:                 codex/research-snapshot-2026-05-08

swift_package_resolved_hash:        ea642677c5efe6a954e3e4f7673600f71ed76dfd067309743dc4eba549df1aaf  (sha256)

rust_lock_hashes:                   (sha256)
  agent_core/Cargo.lock:            1dbf8f4b7c4df883fd458d6c784366d20081a1749f7241bf9e50fdffbcf1b3b9
  epistemos-research/Cargo.lock:    87821b8587d729a7f366a1055e3947aa8fbbd147bd5c15a5ae0503c455e6190c
  omega-mcp/Cargo.lock:             5e4533815ded812a537512cc67d2fb960c755b66a8f8ffe332d882bda1722744
  epistemos-vault/Cargo.lock:       4340539ae336f7773cc9edd3a404175ceefa1a762b32138bd724dcc67850135e
  substrate-rt/Cargo.lock:          fc8be8272ec499fe18f36283485d09527c5ab615eecef6ce5c017c44645dcecf

project_yml_hash:                   04c3d8feb93372738483211321280ba147195f73c6f0b5be8f029638e89a209e  (sha256)

xcodebuild_schemes:                 Epistemos | Epistemos-AppStore
                                    (both schemes carry the EpistemosTests testable as of RCA2-P1-015 fix-pass)

cargo_workspaces:                   agent_core | epistemos-research | omega-mcp | epistemos-vault | substrate-rt

key_audit_artifacts_landed_today:   (paths)
  docs/MAS_RELEASE_MANIFEST_2026_05_13.md
  docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md
  docs/BUNDLE_WEIGHT_AUDIT_2026_05_13.md
  docs/AUDIT_FLOOR_2026_05_13.md             (this doc)

audit_register_state:               (as of audit floor commit)
  PATCHED entries:                  112
  TODO entries:                     100
  total entries (PATCHED + TODO):   212

mas_verification_state:             (per MAS_RELEASE_MANIFEST §"Verification commands")
  subprocess_path_string_scan:      0 matches (RCA3-P0-001 PATCHED)
  rust_dylib_symbol_audit:          0 matches (RCA4-P0-002 PATCHED)
  python_files_in_mas_bundle:       0 (RCA-P3-002 PATCHED)
  sandbox_entitlement:              app-sandbox YES in Release

manual_runtime_smokes_pending:      (will land before MAS submission)
  - first-window recovery (after force-quit during DB load)
  - clean install on macOS 26.3.1 sandboxed user account
  - Multi-vault import (R5 grant set + Settings parity)
  - Approval flow visibility (attach note A, edit note B; ApprovalModalView fires)
  - Cloud-provider key roundtrip (Keychain SecItemAdd + SecItemCopyMatching)
  - MLX local-model inference (Qwen 3.5 4-bit, M2 Pro 16GB hardware lock)

known_blockers:                     none for MAS submission as of audit floor

reproducibility_command_chain:
  1. git checkout 6546db9ef10cbe0419bccb859b3ee1b16370bfc4
  2. xcodebuild -resolvePackageDependencies -scheme Epistemos
  3. cargo build --manifest-path agent_core/Cargo.toml --features mas-build,lsp-runtime
  4. xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Release build
  5. xcodebuild -scheme Epistemos -destination 'platform=macOS' test
  6. cargo test --manifest-path agent_core/Cargo.toml
  7. bash omega_verify.sh --quick           # structural drift gate
  8. (manually re-run the 5 commands in MAS_RELEASE_MANIFEST §"Verification commands")
```

## How to use this baseline

When a new research drop arrives, the agent receiving it should:

1. Check out the audit floor commit (`git checkout 6546db9ef10cbe0419bccb859b3ee1b16370bfc4`).
2. Reproduce all hashes above (`shasum -a 256` on Package.resolved + each Cargo.lock + project.yml).
3. Run the 8-step reproducibility command chain.
4. Compare research-drop claims against the audit-floor baseline:
   - "this fixes X" → verify X was actually broken at the floor commit
   - "this measures Y" → record Y at the floor commit for comparison
   - "this adds dep Z" → verify Z's hash drift in lock files vs floor
5. Update audit register with research-drop findings BUT keep the floor immutable.

The floor is immutable. New audit floors are minted on every
substantive shipping batch (typically 1-2 weeks apart), not every
day.

## Substrate-version pin

V6.1 (CONFIRMED-PUBLIC 2026-05-06) is the canonical substrate.
- Floor `ac8c6d28` is the V6.1 immutable floor (see memory).
- This audit floor (`6546db9ef10cbe0419bccb859b3ee1b16370bfc4`) is
  one of the subsequent shipping floors; V6.1 kernels remain
  doctrine-targets, not implemented-here.

## Hardware lock

V6_2_HARDWARE_LOCK = M2Pro16Gb (Jojo's ship rig).
M2 Max is scale-validation only.
HELIOS V5 toggles default OFF.

## Cross-references

- `docs/MAS_RELEASE_MANIFEST_2026_05_13.md` — MAS-only feature
  inventory + verification commands
- `docs/TOOL_INVENTORY_TRUTH_TABLE_2026_05_13.md` — 4-surface
  normalized tool list
- `docs/BUNDLE_WEIGHT_AUDIT_2026_05_13.md` — measured bundle
  weights + target gating
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` —
  open + PATCHED audit register
