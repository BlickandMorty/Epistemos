```yaml
p0_attacks:
  - id: P0-01
    title: "UI-only gate — tool catalog not filtered"
    severity: P0
    description: >
      `isBuiltInAgentContextProviderVisible` hides tokens from the @mention
      picker but does NOT touch the tool catalog loader. Safari/Terminal/
      Automation tools remain loaded into the active catalog for .coreAppStore
      builds. Any prompt that names these tools directly (or via a jailbreak
      string) can still invoke them at the execution layer. Context-provider
      visibility is a UX affordance, not a security boundary.
    canon_ref: "MASTER_RESEARCH_INDEX §12 — bounded execution, no shell/Automation"
    exploit: >
      User types a prompt referencing @terminal or the model's own tool
      registry returns terminal as an available tool_use name. The filter
      is entirely bypassed because it sits only in refreshContextProviders,
      not in ToolCatalogLoader or the Rust agent_core dispatch path.

  - id: P0-02
    title: "deepseekR1 .agent mode leak into App Store via supportsStructuredToolCalling"
    severity: P0
    description: >
      The test change makes `deepseek.supportedOperatingModes` conditional on
      `LocalToolGrammar.supportsStructuredToolCalling`. If that flag evaluates
      true in a .coreAppStore build (e.g., because it reads a runtime flag or
      schema that is present in the MAS binary), DeepSeek R1 gains .agent
      mode. The test does not assert which distribution profile is active when
      it runs, so CI green does not prove the App Store binary is safe.
    canon_ref: "MASTER_RESEARCH_INDEX §12 — no background agents, bounded execution"
    exploit: >
      App Store reviewer launches the app. LocalToolGrammar.supportsStructuredToolCalling
      returns true (it is not gated by ToolSurfacePolicy). DeepSeek R1's
      supportedOperatingModes includes .agent. Agent mode surfaces appear
      in the UI; execution is unbounded.

  - id: P0-03
    title: "Runtime resolution — no compile-time #if guard for App Store surfaces"
    severity: P0
    description: >
      The entire filter pivots on `ToolSurfacePolicy.resolvedDistribution(toolSurfaceDistribution)`.
      The diff shows no `#if APPSTORE` compile-time exclusion of the Pro
      code paths. The App Store binary therefore ships with Safari/Terminal/
      Automation provider code fully compiled in. If resolvedDistribution
      returns anything other than .coreAppStore for any reason (feature flag,
      UserDefaults override, scheme mismatch, entitlement-check race),
      the filter is disabled silently with no fallback.
    canon_ref: "MASTER_RESEARCH_INDEX §12, §6 — Pro/Research gateway surfaces must not exist in MAS binary"
    exploit: >
      A UserDefaults key set by a previous Pro build, a TestFlight entitlement
      difference, or a unit-test harness that injects .proResearch causes
      resolvedDistribution to return .proResearch on an App Store binary.
      All five agents become visible and invocable.

p1_attacks:
  - id: P1-01
    title: "No test covers .currentBuild default resolution path"
    severity: P1
    description: >
      Both new tests inject explicit .coreAppStore or .proResearch.
      The production init uses `.currentBuild` as the default. The mapping
      logic inside `ToolSurfacePolicy.resolvedDistribution` is not exercised
      by any test in this diff. A regression there would silently ship
      the wrong profile to every production user.

  - id: P1-02
    title: "vault / AllNotes / CurrentGraph providers unconditionally added"
    severity: P1
    description: >
      The test for .coreAppStore asserts `tokens.contains("AllNotes")` and
      `tokens.contains("CurrentGraph")`, confirming these providers are added
      in a separate branch of refreshContextProviders that is NOT filtered
      by isBuiltInAgentContextProviderVisible. If AllNotes or CurrentGraph
      represent agentic vault-sweep operations (bulk read, semantic search
      over all notes), they should be audited against the App Store bounded-
      execution profile before being confirmed safe.

  - id: P1-03
    title: "String-match filter is case-sensitive and id-aliasing is unverified"
    severity: P1
    description: >
      `isBuiltInAgentContextProviderVisible` matches on the raw `id` string
      ("notes", "file"). The agents tuple is constructed in the same function
      so aliasing is low-risk today, but: (a) the function accepts any String
      and has no exhaustive switch with a compiler-enforced enum, (b) a future
      contributor adding `("Vault", "vault")` to the agents list would silently
      pass the filter because "vault" is not in the explicit allowlist — it
      falls to `default: return false`, which hides it in App Store but also
      hides it in Pro. The inversion (allowlist for App Store, passthrough for
      Pro) creates a maintenance asymmetry where new agents are accidentally
      hidden everywhere until explicitly added to the allowlist.

  - id: P1-04
    title: "Automation filtered from @mention but AppleScript path not audited"
    severity: P1
    description: >
      Filtering "automation" from the context-provider picker does not audit
      whether the iMessageDriver or OmegaPermissions still expose an
      AppleScript/osascript execution path callable from agent tool_use in
      .coreAppStore mode. The diff does not touch those layers.

  - id: P1-05
    title: "toolSurfaceDistribution not propagated to refreshSkillCatalog / refreshToolCatalog"
    severity: P1
    description: >
      `refreshCatalogs()` calls `refreshSkillCatalog()` and presumably
      `refreshToolCatalog()`. These loaders are not shown to receive or
      consult `toolSurfaceDistribution`. If the skill/tool catalogs load
      Pro-only entries (Bash, WebFetch, Terminal skill) regardless of
      distribution, the context-provider filter is cosmetic and the agent
      can execute those skills when scheduled by the Rust loop.

  - id: P1-06
    title: "Test mutation of deepseek mode expectation silently expands App Store capability surface"
    severity: P1
    description: >
      The old assertion `deepseek.supportedOperatingModes == [.thinking]`
      was a hard invariant that caught regressions. The new conditional
      assertion accepts either [.thinking] or [.thinking, .agent] depending
      on a runtime flag. This weakens the test as a regression detector: if
      .agent mode is incorrectly added to the App Store build, the test
      still passes. A separate test asserting the invariant per distribution
      profile is needed.
```

---

## Summary

**3 P0 blockers, 6 P1 issues.**

The patch's fundamental design flaw is that it gates a **UI affordance** (the @mention picker) rather than the **execution boundary** (tool catalog, dispatch, Rust agent_core). Canon §12 requires bounded execution for App Store — no shell, no Automation, no CLI. Hiding tokens from the picker while keeping those tools compiled into the catalog and available to the agent loop satisfies neither the letter nor the spirit of that requirement.

The highest-risk path is P0-01 + P1-05 together: Safari/Terminal/Automation remain in the tool catalog, the Rust agent_core can receive and execute tool_use calls for them, and nothing in this diff prevents that. P0-02 is independently dangerous because it allows agent mode for a local model in a bounded-execution profile if one runtime flag flips.

Recommended remediation before merge:

1. Add distribution-aware filtering inside `ToolCatalogLoader` / `refreshSkillCatalog` — the execution layer, not just the picker.
2. Gate `LocalToolGrammar.supportsStructuredToolCalling` by `ToolSurfacePolicy` or add an explicit `.coreAppStore` branch that excludes `.agent` from local model modes.
3. Add a `.currentBuild` resolution test that exercises the actual entitlement/scheme detection logic.
4. Replace the weakened deepseek mode test with two separate tests: one per distribution profile.

---

CLAUDE-RETURN: role=RED-TEAM | slice=command-center-tool-surface-policy-pr1 | round=42 | artifact=docs/fusion/fleet/command-center-tool-surface-policy-pr1/claude-red-team/attacks.md | usefulness=+1 | p0=3 | p1=6
