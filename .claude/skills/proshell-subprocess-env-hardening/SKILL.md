---
name: proshell-subprocess-env-hardening
description: Harden Epistemos Pro/OpenChamber subprocess launch seams. Use when editing ProAgent, Goose, Work, or ActGoose code that spawns child processes, builds child environments, bridges provider credentials, resolves bundled binaries, allocates loopback ports, supervises web/agent runtimes, or diagnoses crash/zombie/orphan behavior.
---

# ProShell Subprocess Env Hardening

Use this skill to make an Epistemos Pro/OpenChamber child-process seam bounded, honest, and source-guarded without crossing into protected engine, security, build-system, MAS, Experimental, vault, graph, or notes/editor paths.

## Workflow

1. Re-state the exact child boundary: parent Swift host, child binary, env keys, loopback port, auth secret, current directory, stdout/stderr capture, teardown owner, and user-visible degraded state.
2. Read the local owner file and its closest precedent before editing. For ProAgent process/env seams, compare against `Epistemos/Goose/GooseRuntimeSupervisor.swift` and `Epistemos/Work/WorkRuntimeSupervisor.swift`.
3. Treat inherited environment as hostile input. Allowlist keys, reject NULs, cap value sizes, require absolute path-like values, cap PATH entries and total PATH length, dedupe entries, prepend only the child binary directory and deliberate canonical/user tool dirs.
4. Keep secrets one boundary wide. Keychain/provider secrets may enter only the intended child env; never leak them to WebView JavaScript, diagnostics, placeholder copy, or broad inherited env.
5. Bind loopback services with both address and capability proof: loopback host, ephemeral or explicitly justified port, readiness endpoint semantics, bounded timeout, and an authenticated route when the child can perform shell/code actions.
6. Make teardown identity-based. Track current `Process` identity, untrack on termination, kill surviving siblings after required-child death, and keep crash-durable orphan cleanup where a previous app instance can leak children.
7. Add a focused regression test. Prefer direct tests for pure helpers; use source guards for lifecycle invariants that are hard to execute without spawning real bundled runtimes.

## Checks

- Run the narrowest relevant Swift test first, for example:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ProAgentRuntimeSupervisorTests test CODE_SIGNING_ALLOWED=NO`
- Before any Xcode invocation, confirm no other `xcodebuild` is active.
- Inspect `git diff --name-only` and verify touched paths are in the Pro/OpenChamber or shared-shell scope only.
- Do not hand-edit `Epistemos.xcodeproj/project.pbxproj`, build scripts, protected data/core paths, MAS June, or Experimental lanes.
