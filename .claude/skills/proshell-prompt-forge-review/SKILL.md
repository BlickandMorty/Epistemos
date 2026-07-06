---
name: proshell-prompt-forge-review
description: Build visible Prompt Forge and System Prompt Forge flows in Epistemos shared shell or ProShell surfaces. Use when adding prompt-upgrade APIs, pattern-library/system-prompt upgrades, composer review UX, vault/app-context grounding, or pre-send prompt transformation guardrails.
---

# ProShell Prompt Forge Review

Use this skill when a user prompt or system prompt is upgraded before it reaches an agent.

## Method

1. Keep the upgrade visible. Never silently rewrite a prompt before model submission; show original and upgraded text with accept, edit, retry, revert, and cancel paths.
2. Preserve intent first. Keep the user's original nouns, constraints, and voice verbatim inside the upgraded prompt, then add structure around it.
3. Ground honestly. Consume only caller-supplied public app/vault context snippets; cite those snippets; if no context is supplied, say the upgrade is structure-only and never invent citations.
4. Apply techniques selectively. Match the scaffold to the task class: engineering, research, writing, or general. Avoid adding every prompting technique to every prompt.
5. Bound the prompt. Cap original text, context snippets, selected context, and final output. Prune low-priority context before truncating the user's original request.
6. Clarify only when it matters. Surface at most three questions, and only for ambiguity that would change the outcome.
7. Keep system-prompt upgrades authored and ethical. Use layered architecture and Epistemos-authored patterns; never copy proprietary or leaked system-prompt text.

## Checks

- Add pure tests for intent preservation, context citations, no-context honesty, retry variants, and system-prompt layering.
- Add source guards for composer wiring when the live surface is hard to drive in-process.
- Run source-only typechecks first for the pure core, then one consolidated Xcode checkpoint after the coding batch.
- Confirm touched paths stay in shared shell / ProShell scope and do not edit vault, graph, notes/editor, engine/FFI, MAS June, Experimental, security, pbxproj, or build scripts.
