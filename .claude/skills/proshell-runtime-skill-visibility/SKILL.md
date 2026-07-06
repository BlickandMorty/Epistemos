---
name: proshell-runtime-skill-visibility
description: Surface runtime-visible Epistemos skills in ProShell without crossing protected Vault, Rust, or donor-web boundaries. Use when adding skill inventory, skill-library browsing, or runtime skill diagnostics to Work/OpenCode, Goose/OpenChamber, or shared-shell UI.
---

# ProShell Runtime Skill Visibility

Use this skill when a ProShell surface needs to show which skills the running agent can actually see.

## Method

1. Name the runtime skill root first: Work/OpenCode uses `<workspace>/.opencode/skills`; Goose ACP uses its own sources/skills contract. Do not show a global catalog as if it were runtime-visible.
2. Reuse the surface's existing provisioner or ACP source boundary. Do not edit protected Vault, graph, Rust, FFI, security, donor web, or build-system code to make a browser look complete.
3. Treat skill manifests as untrusted files. Read only top-level directories, require a regular single-link `SKILL.md`, open with no symlink following, cap bytes, normalize display text, and skip unreadable entries.
4. Keep the UI honest. Label provisioned/runtime-visible skills as visible to that runtime; do not claim they are evolution-gate-passed unless the gate result is actually available.
5. Keep the browser compact and native. Show the skill name, identifier, and short description; avoid long explanatory text or management actions unless the underlying mutation/install flow is real.
6. Pin the behavior with pure tests for manifest parsing, unsafe file skipping, source wiring, and the surface's empty state.

## Checks

- Run a source-only typecheck for the pure provisioner helper before broader tests.
- Run focused Work/Goose tests after confirming no other `xcodebuild` is active.
- Before staging, scan the diff for protected paths and confirm no Vault/Rust/FFI/pbxproj/build-script edits were made.
