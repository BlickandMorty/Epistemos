---
name: june-replay-bundle-export
description: Use when adding, auditing, or hardening MAS June ReplayBundle or .epbundle export paths, AnswerPacket-to-bundle evidence, provenance artifact actions, or deterministic substrate export FFI that must return bounded bytes without sidecars, subprocess verifiers, webview file authority, or fabricated verification claims.
---

# June ReplayBundle Export

## Purpose

Use this skill when June needs to turn native provenance evidence into a portable `.epbundle` artifact. The pattern is: native evidence in, bounded `agent_core` FFI bytes out, user-mediated save outside Rust, and no "Verified" copy unless the native VRM/ACS substrate actually says so.

Do not use this skill to call `epistemos-trace` as a subprocess from MAS, let webview JavaScript choose arbitrary filesystem writes, mint empty bundles, fabricate vault citations, expose raw vault roots, or promote a local model/tool capability that is not admitted.

## Required Reads

1. `docs/research/DETERMINISTIC_SUBSTRATE_INFUSION.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `agent_core/src/provenance/replay.rs`
4. `agent_core/src/provenance/ledger.rs`
5. `agent_core/src/bridge.rs`
6. `Epistemos/JuneAgent/JuneAgentBridge.swift`
7. `Epistemos/JuneAgent/JuneAgentGateway.swift`
8. `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`

## Method

1. Keep Rust as the artifact authority.
   - Use `ReplayBundle::build` and `to_epbundle_bytes()`.
   - The FFI returns bytes or a bounded native error; it does not write files.
   - Never invoke the `epistemos-trace` CLI from MAS. Verification can be a developer/runtime proof, not a hidden product subprocess.

2. Build only honest non-empty bundles.
   - `ReplayBundle` must contain at least one real claim or mutation.
   - For a turn-completion export, use the emitted AnswerPacket id as evidence: one active claim that the turn emitted that packet, supported by `answer_packet:<id>`.
   - This is audit evidence, not correctness verification. UI copy should say `VRM evidence` or `Replay bundle`, not `Verified`.

3. Bound every web/native input.
   - Validate and cap bundle id, run/session id, packet id, and timestamps before building the bundle.
   - Strip or reject control characters.
   - Do not pass vault roots, raw prompts, raw outputs, secrets, or absolute proposal paths through the export FFI unless a future schema explicitly admits and redacts them.

4. Keep save authority native and user-mediated.
   - A future June UI action may request export for a known assistant turn.
   - Native Swift should resolve the stored AnswerPacket/session id, call the FFI, and then present a save/export flow.
   - Webview JavaScript should receive only status, filename suggestion, or user-visible error, not durable write authority.

5. Preserve MAS boundaries.
   - No sidecars, subprocesses, stdio MCP, shell tools, local servers, or arbitrary network access.
   - No local model load is needed for export.
   - Use the same sparse-checkpoint discipline as other June substrate work on 16 GB machines.

6. Verify narrowly first.
   - Rust focused test: exported bytes parse with `ReplayBundle::from_epbundle_bytes` and pass `verify_integrity`.
   - Rust negative test: missing/oversized identifiers fail closed.
   - Swift/web source guards come before a full App Store build.
   - Running MAS proof must show export from a real completed turn and a user-visible saved `.epbundle`.

## Review Checklist

- The export path returns canonical bytes from `ReplayBundle`, not ad hoc JSON.
- Empty bundles are impossible.
- Packet/session/bundle identifiers are bounded and sanitized.
- No raw prompt/output/vault root/secrets are added to the bundle without an admitted schema.
- UI copy does not say "Verified" unless native VRM/ACS evidence supports it.
- JavaScript does not get filesystem authority or secrets.
- No CLI verifier, subprocess, local server, or local model load is introduced.
- Focused Rust tests pass before any heavier App Store checkpoint.
