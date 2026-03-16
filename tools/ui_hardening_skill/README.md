# UI Hardening Skill

Reusable audit and hardening harness for Epistemos UI risk areas:

- toolbar dynamics and legacy residue
- main chat scroll stability
- mini chat scroll stability
- notes/editor scroll stability
- layout churn and animation-driver conflicts
- dead UI code and architectural bloat
- accessibility regressions
- performance and profile evidence
- FFI and shader contract drift

## Quick start

```bash
tools/ui_hardening_skill/run_full_audit.sh
```

Targeted runs:

```bash
tools/ui_hardening_skill/run_scroll_audit.sh
tools/ui_hardening_skill/run_toolbar_audit.sh
tools/ui_hardening_skill/run_layout_churn_audit.sh
tools/ui_hardening_skill/run_dead_code_audit.sh
tools/ui_hardening_skill/run_accessibility_audit.sh
tools/ui_hardening_skill/run_perf_audit.sh
tools/ui_hardening_skill/run_ffi_shader_audit.sh
```

## Output locations

- Report bundles: `tools/ui_hardening_skill/reports/<timestamp>/`
- Profiles: `tools/ui_hardening_skill/profiles/`
- Snapshots / captured artifacts: `tools/ui_hardening_skill/snapshots/`
- Final audit writeups: `docs/audits/ui-hardening/`

## Environment flags

- `UI_HARDENING_SKIP_TESTS=1` skips `xcodebuild test`
- `UI_HARDENING_SKIP_BUILD=1` skips build steps
- `UI_HARDENING_SKIP_PROFILE=1` skips `xctrace` profiling

## Current automated suites

- `EpistemosTests/ScrollStabilityTests.swift`

The harness is intentionally conservative. It surfaces suspicious paths fast, writes plain-text reports, and leaves the final engineering judgment to the audit pass.
