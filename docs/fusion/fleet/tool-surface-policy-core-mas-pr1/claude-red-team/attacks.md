---
role: claude-red-team
slice: tool-surface-policy-core-mas-pr1
brief: docs/fusion/deliberation/tool_surface_policy_core_mas_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 1
p0_attacks: 0
p1_attacks: 0
p2_attacks: 1
p3_attacks: 0
verdict: brief-approved
usefulness: +1
usefulness_reason: Allowlist-first gate with compile+runtime double lock is the correct MAS posture; no bypass surface found.
---

## Attacks

### A-1 (P2) — `sandboxEnvironmentForcesCoreAppStorePolicy` test fidelity depends on `ProcessInfo` snapshot semantics

**Location:** `EpistemosTests/ToolSurfacePolicyTests.swift` — `sandboxEnvironmentForcesCoreAppStorePolicy`

**Mechanism:** `NSProcessInfo.environment` on Darwin is lazily created and cached after first access. The test calls `setenv("APP_SANDBOX_CONTAINER_ID", …)` at mid-run and then reads through `isCoreAppStoreBuild`, which calls `ProcessInfo.processInfo.environment[key]`. If any earlier test (or the Swift Testing runner itself) has already materialized the `environment` dictionary snapshot before this test body runs, the `setenv` will not be reflected, `isCoreAppStoreBuild` returns `false`, the distribution resolves to `.proResearch`, and `bash_execute` stays visible — causing the test to fail for the right reason or pass vacuously if compile flags (`EPISTEMOS_APP_STORE` / `MAS_SANDBOX`) are active in the test target.

**Impact:** Low in production. The real sandbox always has `APP_SANDBOX_CONTAINER_ID` set before process launch, so the snapshot contains it from the first read. The risk is entirely test-side: if the test is currently green only because compile flags force `isCoreAppStoreBuild = true`, the `APP_SANDBOX_CONTAINER_ID` runtime branch is untested and a silent regression could slip through if the compile flag is removed or a non-MAS CI lane is added.

**Distinguishes from P1:** No attacker path exists. Production behavior is correct; this is a test-coverage fidelity concern only.

**Suggested fix (non-blocking):** Inject `isCoreAppStoreBuild` as a closure parameter or a `@TestingOverride` seam so the test never depends on `ProcessInfo` snapshot ordering. Alternatively, assert in the test that `ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]` actually equals the value just set (i.e., verify the reflection before asserting policy behavior), and document the compile-flag assumption.

---

## Brief verdict

No P0 or P1 attacks found. The allowlist architecture is sound:

- Allowlist-first guard fires before the switch, so any unnamed tool is blocked in coreAppStore regardless of future switch additions.
- `resolvedDistribution` correctly overrides any caller-supplied distribution when `isCoreAppStoreBuild` is true — the sandbox lock cannot be weakened by passing `.proResearch` explicitly.
- Case canonicalization (`lowercased()`) applied before both the allowlist lookup and the switch eliminates case-variant bypasses.
- `think` and `image_generate` are double-blocked (allowlist absence + switch `return false`) — redundant but harmless.
- `route_private` (previous P1) confirmed absent from `coreAppStoreAllowedToolNames`. ✓
- Serialized suite annotation prevents cross-test `setenv` leakage races between the new tests themselves. ✓

Single P2 (test fidelity) noted; does not block ship.

CLAUDE-RETURN: role=RED-TEAM | slice=tool-surface-policy-core-mas-pr1 | round=39 | artifact=docs/fusion/fleet/tool-surface-policy-core-mas-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=0
