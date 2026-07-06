# ProShell Work Context Grounding Report

Cycle frontier: compound Prompt Forge with runtime skill visibility by carrying Work-visible skill identifiers through the existing Work context seam.

## Shipped

- Added bounded `runtimeSkillNames` to `WorkAppContextSnapshot`.
- Populated the names from `WorkSkillsProvisioner.provisionedSkills(...)` in `current(...)`.
- Exposed a `runtime-skills` row that feeds both the Work engines panel and Prompt Forge context snippets.
- Raised the Prompt Forge row priority for `runtime-skills` to match other engine/runtime facts.

## Boundary

- No protected Vault, graph, note/editor, Rust/FFI, security, donor web, pbxproj, or build-script edits.
- The context still carries only plain `Codable` values and does not import protected app state.

## Verification

- Passed: `swiftc -typecheck Epistemos/Work/WorkSkillsProvisioner.swift Epistemos/Work/WorkAppContextSnapshot.swift Epistemos/PromptForge/PromptForge.swift Epistemos/PromptForge/SystemPromptForge.swift`
- Passed: `git diff --check` over the scoped cycle files.
- Passed: scoped guardrail scan for forced execution, debug output, crash calls, and unfinished markers.
- Xcode focused tests remain blocked in this tool session by the same exit-143 interruption recorded in the prior cycle.
