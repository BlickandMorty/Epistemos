---
name: experimental-submission-enhance
description: >
  Add a submission-time LLM enhance step to the embedded 1Code (Experimental) surface — a
  one-shot small-model transform (Prompt Forge, system-prompt upgrade, summarize, classify)
  that runs through the SAME Claude SDK the chat uses so it reuses the user's real auth, and
  composes vault grounding for the Epistemos edge. Use when building any renderer feature
  that needs a fast, honest, in-app model call whose result the user reviews before it takes
  effect. Class: renderer trigger → tRPC mutation → SDK one-shot (small model) → parsed
  structured result → diff/accept UX. Composes `experimental-vault-context-assembly`.
---

# Experimental: submission-time LLM enhance (Prompt Forge class)

## When to use
Any feature that transforms user text with a model IN the surface and shows the result for
review: Prompt Forge (upgrade the composer prompt), System Prompt Forge (upgrade a system
prompt), auto-title, summarize-selection, classify-intent. The reusable spine behind
Cycle-3 Prompt Forge.

## The pattern
1. **Backend enhance module (NEW `src/main/lib/epistemos-<feature>.ts`).** A pure function
   `enhance(input, getQuery)` that runs `getQuery()` (the cached `@anthropic-ai/claude-agent-sdk`
   `query`) ONE-SHOT with a small model and a strict output contract:
   ```ts
   const FORGE_MODEL = "claude-haiku-4-5"  // fast/small — must feel instant
   const iterator = query({ prompt: userMessage, options: {
     model: FORGE_MODEL, maxTurns: 1, allowedTools: [],   // pure text, no tools/MCP
     systemPrompt,
     ...(claudeBinaryPath && { pathToClaudeCodeExecutable: claudeBinaryPath }),
   }})
   ```
   Collect `assistant` text blocks (+ the `result` message); parse a delimited format
   (`<<<UPGRADED>>>…<<<CHANGED>>>…<<<END>>>`). **On ANY error, return the input unchanged —
   never lose or silently mangle the user's text.**
2. **⚠️ LOAD-BEARING (this is the trap that cost a cycle):** you MUST pass
   `pathToClaudeCodeExecutable: getBundledClaudeBinaryPath()` (from `./claude/env`, which
   honors the supervisor's `EPISTEMOS_CLAUDE_BINARY`). WITHOUT it the SDK can't spawn the
   user's `claude` CLI and every call silently falls back to the input — looks shipped, does
   nothing. The chat sets this (claude.ts:2073); a new enhance path must too.
3. **tRPC router (NEW `routers/epistemos-<feature>.ts`, registered in routers/index.ts).**
   A `mutation` with a zod-validated input; its own cached SDK loader.
4. **Renderer client (NEW `lib/…`).** Optionally ground first (compose
   `experimental-vault-context-assembly`: `rankedVaultSearch` → pass notes as `grounding`,
   instruct the model to `[[cite]]` them), then `trpcClient.epistemos<Feature>.enhance.mutate`.
5. **Diff/accept UX (NEW `ui/…`).** Show original→result + a "what changed" list; Accept /
   Retry / Revert. Never apply silently — the user chooses. Honest-gate on the host.

## Verification (DoD — deterministic FIRST, then live)
- **Prove it headless before the app build** (this is how the binary-path bug was caught):
  boot the headless backend with `EPISTEMOS_CLAUDE_BINARY=<user claude>` and POST the tRPC
  mutation; assert the result is actually transformed (not == input) and cites the vault note.
  Deterministic, no keychain/UI friction — worth more than a screenshot for the core.
- Then verify the diff UX live in the running app.
- Never two `xcodebuild`s. Every fork edit → a `PATCH_LEDGER.md` row.

## Proven (Cycle 3)
"make the login better" + a retrieved auth note → a structured upgrade citing
`[[AUTH_DESIGN_2026]]`, 5 tracked changes, model `claude-haiku-4-5`, grounded=true.
