---
name: june-prompt-forge
description: Use when adding, auditing, hardening, or extending MAS June submit-time prompt upgrades, system-prompt upgrades, pattern-library composition, visible prompt review/diff UX, active-vault grounding, or any pre-engine transformation that must preserve intent, stay on-device where possible, and keep local/cloud capability truth.
---

# June Prompt Forge

## Purpose

Use this skill to build a visible, honest, vault-grounded prompt transformation before June sends a turn to the engine. The pattern applies to user Prompt Forge, System Prompt Forge, Pattern Library composition, and future pre-submit transforms that must not silently rewrite the user's intent.

Do not use this skill for `Epistemos/ExperimentalAgent/**`, 1Code, Pro sidecars, stdio MCP, shell tools, or hidden cloud rewrites.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `docs/research/PROMPT_UPGRADING_FIELD_STUDY.md` for user prompt upgrades.
4. `docs/research/SYSTEM_PROMPT_FIELD_STUDY.md` for system-prompt/pattern upgrades.
5. `Epistemos/JuneAgent/JuneAgentGateway.swift`
6. `/Users/jojo/dev/june-epistemos/src/components/agent/AgentWorkspace.tsx`

## Method

1. Preserve the boundary first.
   - Keep MAS June in-process only.
   - Never add a subprocess, local server, stdio MCP, terminal, code execution, AppleScript, or Pro-only tool.
   - Keep local models chat-tier; prompt upgrades may be local/on-device, but local model rows must not become tool-capable.

2. Make transformation explicit.
   - Add a named preview RPC before the engine RPC, such as `prompt.forge_preview`.
   - Validate payload shape and length before processing.
   - Return a review payload; do not mutate `prompt.submit` silently.
   - Include `originalText`, `upgradedText`, `mode`, `groundingStatus`, `changeSummary`, `clarifyingQuestions`, and `citations`.

3. Ground honestly.
   - Prefer `AppBootstrap.shared?.vaultSync.vaultURL` only when `vaultSync.isWatching == true`.
   - Snapshot the active vault URL on the main actor, then scan/assemble off the main actor.
   - Balance `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`.
   - Use bounded file counts, byte counts, citation counts, and excerpt lengths.
   - Cite relative vault paths only; never expose raw security-scoped roots.
   - If no note matches, say so and tell the engine not to invent citations.

4. Keep review UX mandatory.
   - Show Original and Upgrade before sending.
   - Show what changed, local/cloud mode, grounding status, citations, and at most 3 clarifying questions.
   - Show the selected-engine context strategy so local lower-context rewrites are visible instead of silent.
   - Provide Accept, Edit, Retry, and Revert.
   - Only Accept/Revert should call the engine submit path.
   - Skip slash commands and tagged issue-report flows unless the command itself opts in; avoid corrupting command semantics.

5. Harden the crossing.
   - Run vault scanning and prompt assembly off `@MainActor`.
   - Cross back through a typed `Sendable` payload.
   - Keep JSON-RPC reply IDs bounded/typed before crossing async work.
   - Do not put secrets, provider keys, receipts, or full vault roots in the review payload.
   - Keep stream buffers bounded if the transform feeds an agent loop.

6. Budget for the selected engine.
   - Resolve the selected model before assembly.
   - Treat local Apple/GGUF rows as compact-context engines; reduce input length, scanned files, citation count, and excerpt size against the model's context window.
   - Preserve richer structure for cloud models only when their context window supports it.
   - Never let vault grounding exhaust the local model's answer budget.

7. Verify in layers.
   - Web: `./node_modules/.bin/tsc --noEmit` in `/Users/jojo/dev/june-epistemos`.
   - Web regression: `./node_modules/.bin/vitest run src/test/agent-workspace.test.tsx src/test/model-privacy.test.ts`.
   - Stage web bundle: `./build-june-web.sh` from `/Users/jojo/Downloads/Epistemos`.
   - Native source guard: add/extend `EpistemosTests/AppStoreJuneHardeningTests.swift`.
   - Native checkpoint: run the App Store scheme only when no other `xcodebuild` is active.
   - Runtime proof: in the sandboxed MAS build, submit an underspecified prompt, inspect the review, accept an upgrade with a vault citation, and confirm the engine receives the upgraded prompt.

## Review Checklist

- The user can see and reject the upgrade before any engine call.
- The upgrade preserves the user's nouns, constraints, tone, and deliverable.
- Ambiguity produces concise clarifying questions instead of confident guessing.
- Vault citations are bounded, relative-path, and never fabricated.
- Local/on-device/cloud mode is labeled plainly.
- Slash commands, issue reports, and tool-control prompts are not rewritten accidentally.
- No main-actor disk scan, unbounded buffer, force unwrap, `try!`, production `print()`, or secret-in-JS path is introduced.
