---
name: june-native-capability-bridge
description: Use when exposing an existing MAS-safe native, vault, agent_core, or deterministic substrate capability to the June webview through the Tauri shim/bridge without making webview JavaScript the authority or weakening capability truth.
---

# June Native Capability Bridge

## Purpose

Use this skill when June already has a native or Rust capability and the missing work is the bridge from the vendored June SPA into that capability. The pattern turns an inert or empty Tauri-style command into a bounded, honest, MAS-safe native response while keeping secrets, file authority, tool admission, and mutation decisions on the native side.

Do not use this skill to add a sidecar, subprocess, stdio MCP, shell/terminal/code tool, hidden local server, unreviewed vault mutation path, or fake local model capability.

For native June chrome affordances, prefer presenting the existing native view/control directly instead of inventing a webview mirror. If the native view depends on app environment or SwiftData, inject `withAppEnvironment(bootstrap)` and `modelContainer(bootstrap.modelContainer)` at the presentation boundary.

Before changing toolbar/sidebar chrome, inventory the adjacent controls and preserve their behavior. Add a source guard for any nearby capability that could be accidentally deleted while adding the new native bridge.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `Epistemos/JuneAgent/JuneAgentBridge.swift`
4. `Epistemos/JuneAgent/JuneAgentGateway.swift`
5. The native source of truth for the capability being exposed
6. The vendored June caller in `/Users/jojo/dev/june-epistemos/src`

## Method

1. Identify the existing source of authority.
   - Prefer an already-built Swift/Rust API over creating a parallel implementation.
   - Confirm App Store legality: in-process only, no forbidden tool, no arbitrary network/config discovery, no secrets to JS.
   - If a capability is absent, return an honest empty/disabled/error shape rather than a decorative row.
   - For toolbar/sidebar buttons, reuse existing SwiftUI/AppKit presentation shells such as `AppKitPopover` or established utility views; do not make the webview own vault navigation or note mutation authority.
   - For detail reads that need SwiftData plus file IO, snapshot only Sendable primitives on `@MainActor`, then perform the body/file read through the existing async primitive API off the synchronous bridge path.

2. Match June's existing wire contract.
   - Read the TypeScript caller and schema before adding a command.
   - Return the shape the UI already parses.
   - Keep command names stable with the Tauri shim rather than inventing a second bridge namespace.

3. Validate hostile webview input before native work.
   - Validate Tauri-shim invoke envelopes first: safe nonnegative JS-integer `callId`, byte-bounded command name, and serializable bounded args.
   - Bound strings and arrays.
   - Reject path traversal, path-like names, control characters, oversized payloads, and ambiguous ids.
   - Use existing safe IO helpers for vault reads/writes.
   - Do not capture SwiftData `@Model` objects in detached tasks; pass only a small `Sendable` snapshot such as id, title, dates, folder id, inline body, and file path.

4. Keep mutation authority native and reviewed.
   - Read-only catalog/detail commands are safe when the native source is already admitted.
   - Enable/disable preferences may persist as non-secret preferences.
   - File mutations must go through existing reversible/reviewed effect, skill-evolution, or approval systems; never let the chat webview write arbitrary vault content directly.

5. Keep capability truth visible.
   - Local rows remain chat/compact-context unless a proven deterministic grammar/tool lane is actually admitted.
   - Cloud/agent rows may expose tools only through the real `agent_core` path.
   - If the bridge returns a row but the runtime cannot execute it, mark it disabled/read-only and make the UI outcome explicit.

6. Add source guards before heavy build checkpoints.
   - Guard that the command no longer returns the old no-op.
   - Guard that adjacent toolbar/sidebar controls still expose their previous native behavior.
   - Guard safe invoke `callId`, command-byte, and args-size validation before native dispatch.
   - Guard payload bounds and native source-of-truth calls.
   - Guard read-only or approval-gated mutation behavior.
   - Defer App Store build/runtime proof to a deliberate checkpoint on 16 GB machines.

## Review Checklist

- The bridge calls an existing native/Rust source of truth.
- Native chrome affordances reuse existing native views with explicit app environment/model-container injection when needed.
- Note/detail body reads use sendable snapshots plus async primitive body readers, never synchronous file loads on the webview invoke call stack.
- JavaScript receives no secrets, raw security-scoped roots, or durable authority.
- Invoke `callId` values are safe finite JS integers before `resolveInvoke` interpolation.
- Payload shape and length are validated before native IO.
- File mutations are read-only, approval-gated, or routed through a reversible native effect path.
- The UI's visible capability matches what the runtime can actually do.
- Streams remain bounded if the bridge opens a streaming path.
- Runtime proof plan names the exact MAS build task needed to close the loop.
