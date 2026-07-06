# ProShell Runtime Skill Visibility Report

Cycle frontier: make the user skill substrate visible inside Work without claiming a broader evolution-kernel integration.

## Shipped

- Added a Work-owned `WorkProvisionedSkill` inventory model.
- Extended `WorkSkillsProvisioner` with a read-only `.opencode/skills` manifest inventory.
- Replaced Work context skill counting with the same safe inventory used by the UI.
- Added a compact Runtime Skills section to the Work engines panel.

## Boundary

- No protected Vault, graph, Rust, FFI, security, donor web, pbxproj, or build-script edits.
- The browser shows runtime-visible/provisioned skills only. It does not claim the skills are evolution-gate-passed because that gate result is not exposed to Work today.

## Review

- Four-lens check: the helper requires top-level skill directories, regular single-link `SKILL.md`, no symlink-following manifest open, bounded manifest bytes, and normalized display strings.
- Thermonuclear check: logic lives in the canonical Work provisioner; `WorkEngineSurfaceView.swift` was not expanded further.

## Verification

- Passed: `swiftc -typecheck Epistemos/Work/WorkSkillsProvisioner.swift Epistemos/Work/WorkAppContextSnapshot.swift`
- Passed: `git diff --check` over the scoped cycle files.
- Passed: scoped guardrail scan for forced execution, debug output, crash calls, unfinished markers, and unused path-carrying fields.
- Blocked: focused Xcode checkpoint for `WorkSkillsProvisionerTests` + `WorkAppContextSnapshotTests` was attempted twice and was interrupted by the tool session with exit 143 before tests completed. A detached retry could not be kept alive by this shell environment.
