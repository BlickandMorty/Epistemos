---
role: claude-red-team
slice: tool-surface-policy-core-mas-pr1
brief: docs/fusion/deliberation/tool_surface_policy_core_mas_pr1_deliberation_2026_05_02.md
date: 2026-05-02
attacks_total: 2
p0_attacks: 0
p1_attacks: 1
p2_attacks: 1
p3_attacks: 0
verdict: brief-revise
usefulness: +1
usefulness_reason: Allow-list architecture is sound and previous fixes landed cleanly; one P1 surface remains before approval.
---

## Attacks

### P1 — `route_private` is a routing primitive on the Core/App Store allow-list

`coreAppStoreAllowedToolNames` includes `"route_private"`. In an agent planning surface, a tool whose name encodes *dispatch/routing* semantics is a logical bypass vector: a planner that surfaces `route_private` can instruct the agent to route to `bash_execute`, `hermes_subprocess`, `mcp_discover`, or any other blocked name as the *target* of the route, without naming those tools directly in the tool-call surface. The planning policy layer is supposed to suppress the appearance of forbidden surfaces; a routing primitive that can name any target restores visibility of those surfaces one hop away.

**Concrete attack path:** planning system surfaces `route_private(target="bash_execute", …)`; the Rust execution gate sees `route_private` (allowed by policy) and must resolve the target at runtime. Even if the Rust MAS preflight ultimately blocks execution, the planning policy layer has advertised a path to the blocked surface, violating the intent of the allow-list and the brief's requirement that forbidden surfaces *disappear* from visible planning.

**Required fix:** Either (a) remove `route_private` from the allow-list and accept that Core/App Store cannot use it, or (b) add documentation + a test asserting that `route_private` is a pure local-vault addressing primitive with no ability to name or dispatch to other tool names, and add that invariant to the policy comment block.

---

### P2 — No test exercises the `APP_SANDBOX_CONTAINER_ID` env-var override path in `isCoreAppStoreBuild`

The compile-flag path (`#if EPISTEMOS_APP_STORE || MAS_SANDBOX`) is not reachable in unit tests; the only runtime-testable path is the `#else` branch that reads `ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]`. The test suite never sets this var and then verifies that `.proResearch` is overridden to `.coreAppStore`. If `ProcessInfo.processInfo` access is mocked/stubbed in a future test-harness refactor, or if a build misconfigures the env var, the bypass-prevention guarantee becomes untested.

**Recommended fix:** Add a `@Test func sandboxEnvVarForcesDistributionToCoreAppStore()` that calls `isSurfacedToolName("bash_execute", distribution: .proResearch)` with `APP_SANDBOX_CONTAINER_ID` set in the process environment (or, if ProcessInfo is not injectable, extract `isCoreAppStoreBuild` to an overridable closure for test injection) and asserts the result is `false`.

---

## Brief verdict

The allow-list migration and previous bypass fixes are solid. One P1 (routing primitive leaks indirect surface visibility) must be resolved before approval; the P2 is a belt-and-suspenders test gap that should be addressed in the same pass. Recommend brief-revise: close the `route_private` allow-list question (remove or document+test the "no dispatch capability" invariant) and add the env-var override test.

CLAUDE-RETURN: role=RED-TEAM | slice=tool-surface-policy-core-mas-pr1 | round=39 | artifact=docs/fusion/fleet/tool-surface-policy-core-mas-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=0 | p1=1
