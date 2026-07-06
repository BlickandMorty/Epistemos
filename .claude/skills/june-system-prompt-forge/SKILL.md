---
name: june-system-prompt-forge
description: Use when adding, auditing, hardening, or extending MAS June system-prompt upgrades, behavior-layer composition, Pattern Library settings, visible system-prompt diff/review UX, native persistence, active-vault grounding, or local/cloud lane-guarded instruction assembly.
---

# June System Prompt Forge

## Purpose

Use this skill to build a visible, reviewable behavior-layer upgrade for June without weakening MAS boundaries. The pattern applies when a user or product surface edits June's system prompt, applies reusable behavior patterns, saves a behavior layer, or composes that layer into local/cloud instructions.

Do not use this skill for `Epistemos/ExperimentalAgent/**`, 1Code, Pro sidecars, stdio MCP, shell/terminal/code tools, hidden servers, or local tool claims.

## Required Reads

1. `docs/prompts/PROMPT_PLAN_1_MAS_JUNE.md`
2. `docs/research/JUNE_MAS_CONNECTION_AUDIT.md`
3. `docs/research/SYSTEM_PROMPT_FIELD_STUDY.md`
4. `.claude/skills/june-prompt-forge/SKILL.md`
5. `.claude/skills/june-native-capability-bridge/SKILL.md`
6. `Epistemos/JuneAgent/JuneAgentBridge.swift`
7. `Epistemos/JuneAgent/JuneAgentGateway.swift`
8. `/Users/jojo/dev/june-epistemos/src/components/settings/AgentSettingsSection.tsx`

## Method

1. Keep the behavior layer explicit.
   - Add a named native command set such as `system_prompt_forge_settings`, `system_prompt_forge_preview`, `system_prompt_forge_save`, and `system_prompt_forge_reset`.
   - Show Original and Upgraded behavior before saving.
   - Include `mode`, `groundingStatus`, `changeSummary`, `patternsApplied`, `citations`, and the upgraded text.
   - Never silently mutate the runtime system prompt from a text field.

2. Compose patterns, do not copy prompts.
   - Write original, MAS-safe pattern bodies.
   - Preserve the user's custom behavior inside a clearly labeled intent block.
   - Structure upgrades into identity, capability honesty, tool contract, refusal framing, output contract, priority budget, user intent, pattern library, and vault grounding.
   - Learn architecture from field studies, but never copy proprietary system-prompt text.

3. Reuse Prompt Forge grounding.
   - Prefer the existing `JunePromptForge().previewPayload(...)` citation path for active-vault grounding.
   - Keep vault scans bounded, security-scoped, relative-path cited, and off `@MainActor`.
   - If no note matches, say so and instruct the runtime not to invent citations.

4. Keep authority native.
   - Validate all bridge payload strings and arrays before native work.
   - Keep preview assembly in `Task.detached(priority: .userInitiated)` when vault grounding is involved.
   - Persist accepted behavior natively with atomic writes under Application Support or another admitted app-owned store.
   - Do not put secrets, provider keys, security-scoped roots, or durable mutation authority in JavaScript.

5. Guard local and cloud differently.
   - Local runtime layer must override custom behavior: chat-tier only, compact context, no tools, no vault mutation, no web, no background jobs, no function calling.
   - Cloud runtime layer may be agentic only through configured providers, MAS-approved in-process tools, permission prompts, and vault citations.
   - If accepted custom behavior conflicts with lane truth, lane truth wins.

6. Wire the settings UI.
   - Add the surface inside the existing Agent settings area.
   - Use pattern toggles, a custom prompt editor, Preview, Save, Reset, and a diff/review display.
   - Do not add a marketing page or hidden background rewrite.
   - Keep text responsive and bounded in compact settings panels.

7. Verify in layers.
   - Web typecheck: `NODE_OPTIONS=--max-old-space-size=1024 ./node_modules/.bin/tsc --noEmit`.
   - Focused web regression: `NODE_OPTIONS=--max-old-space-size=1024 ./node_modules/.bin/vitest run src/test/app-settings.test.tsx -t "System Prompt Forge"`.
   - Native source guard: extend `EpistemosTests/AppStoreJuneHardeningTests.swift`.
   - Native build/runtime checkpoint: defer to a deliberate App Store build checkpoint on 16 GB machines; never start multiple `xcodebuild`s or local models.

## Review Checklist

- Preview is visible before save.
- Pattern bodies are original and reusable.
- Accepted behavior is persisted atomically outside webview JS.
- Vault grounding reuses the bounded Prompt Forge citation path.
- Local runtime composition explicitly denies tools/function calling.
- Cloud runtime composition names MAS approval and citation obligations.
- Source guards prove bridge commands, off-main preview, atomic persistence, and gateway composition.
- Tests remain OOM-conscious: focused first, broad build/test only at a planned checkpoint.
