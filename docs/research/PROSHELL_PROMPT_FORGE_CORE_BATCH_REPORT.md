# ProShell Prompt Forge Core Batch

Date: 2026-07-06

## Scout

The new build prompt makes Prompt Forge canonical shared infrastructure. The safest first implementation seam is the native Work composer: it is in ProShell scope, has a direct Swift send/queue path, and already carries a safe `WorkAppContextSnapshot` made of plain public context values. The hosted OpenChamber SPA has no native Swift submit hook yet; editing the donor web code remains out of bounds.

## Forge

- Added `Epistemos/PromptForge/PromptForge.swift`, a deterministic shared prompt-upgrade core.
- Added `Epistemos/PromptForge/SystemPromptForge.swift`, an Epistemos-authored pattern library plus layered System Prompt Forge upgrader.
- Added `Epistemos/Work/WorkPromptForgeReviewView.swift`, a compact native review panel with accept, edit, retry, revert, and cancel controls.
- Wired `WorkEngineSurfaceView` so normal sends and queue actions review the upgraded prompt before delivery; slash commands stay direct.
- Added `EpistemosTests/PromptForgeTests.swift` for intent preservation, context citation, no-context honesty, retry variants, system-prompt layering, and Work source wiring.

## Temper

Four-lens review:

- Correctness: the original prompt is preserved verbatim inside the upgraded prompt; retry produces an alternate structure; slash commands bypass transformation.
- Security: context grounding consumes caller-supplied snippets only and explicitly refuses invented citations when no context is supplied.
- Memory/data leak: the review panel stores only bounded prompt strings and public app-context values.
- Robustness: prompt text, context snippets, selected context, and output are capped; clarifying questions are capped at three.

Open HIGHs: 0.

## Boundary

Touched paths are in shared shell / ProShell scope: `Epistemos/PromptForge/**`, `Epistemos/Work/**`, `EpistemosTests/**`, `.claude/skills/proshell-*`, and `docs/research/**`.

Protected edits: none.

## Verification Plan

Per the owner's pacing instruction, build/test checkpoints are intentionally batched. Source-only checks are run during coding; the consolidated Xcode checkpoint should cover `PromptForgeTests` and `WorkRuntimeSupervisorTests` when the existing external Xcode lane clears.

## Ascend

This makes Prompt Forge a real shared API rather than a surface-specific trick. The next frontier is an allowed OpenChamber host bridge or native overlay that presents the same review affordance to the hosted SPA without editing donor web code.
