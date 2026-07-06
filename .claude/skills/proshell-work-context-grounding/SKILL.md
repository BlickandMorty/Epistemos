---
name: proshell-work-context-grounding
description: Ground Work/OpenCode prompts and native MCP context in plain Work-owned runtime facts. Use when adding app-context rows, Prompt Forge snippets, or context snapshot fields that describe the running Work surface without importing protected graph, note, vault, or app-state internals.
---

# ProShell Work Context Grounding

Use this skill when Work needs to pass app/runtime facts into Prompt Forge, native MCP, or an agent prompt.

## Method

1. Keep the seam Work-owned and plain. `WorkAppContextSnapshot` should carry simple `Codable` values, not graph, note, chat, vault, or app-state objects.
2. Source facts from canonical Work helpers. Runtime skills come from `WorkSkillsProvisioner`; engine/model/session facts come from the Work surface state; native tool availability comes from the actual MCP registration path.
3. Bound every new field before JSON serialization. Cap list length, item length, path length, and free-text length; dedupe lists before exposing them.
4. Make rows reusable. Anything added to `rows()` automatically feeds the engine panel and Prompt Forge context; assign Prompt Forge priority only when the row materially changes the model's answer.
5. Be honest about capability. Use names such as runtime-visible, registered, or not registered; do not imply a protected subsystem, evolution gate, or tool can run unless the Work seam has evidence.
6. Pin the contract with source tests for serialization, rows, bounding, and forbidden imports.

## Checks

- Run `swiftc -typecheck` over the Work context model and any pure helpers it calls.
- Scan the Work context file for forbidden imports or references to protected graph/chat/note app state.
- Run focused Work context tests when Xcode is available; if Xcode is blocked, record the blocker and keep source evidence explicit.
