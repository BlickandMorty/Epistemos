---
name: proshell-work-prompt-context-builder
description: Extract Work Prompt Forge context assembly into small pure builders. Use when prompt-context rows, priorities, citations, or runtime capability facts are embedded in a large SwiftUI Work/OpenCode surface.
---

# ProShell Work Prompt Context Builder

Use this skill when Work prompt grounding needs to stay testable and out of view code.

## Method

1. Keep the large SwiftUI surface orchestration-only. It may call a builder, but it should not own row-priority switches or snippet construction.
2. Put row-to-snippet mapping in a Work-owned pure type that accepts `WorkAppContextSnapshot` and emits `PromptForgeContextSnippet`.
3. Preserve existing row semantics. Do not change context labels, IDs, source strings, or priority buckets unless the behavior change is intentional and tested.
4. Test the builder directly with runtime skills, selected context, and high-priority rows. Keep a source guard that prevents the priority switch from drifting back into the view.
5. Re-run the Prompt Forge core typecheck plus the Work context helper typecheck before staging.

## Checks

- `swiftc -typecheck Epistemos/PromptForge/PromptForge.swift Epistemos/PromptForge/SystemPromptForge.swift Epistemos/Work/WorkSkillsProvisioner.swift Epistemos/Work/WorkAppContextSnapshot.swift Epistemos/Work/WorkPromptForgeContext.swift`
- Confirm `WorkEngineSurfaceView.swift` does not grow and remains below 1000 lines.
- Boundary-scan staged files for protected paths before committing.
