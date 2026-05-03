```yaml
---
slice: tool-surface-policy-core-mas-pr1
date: 2026-05-02
reviewer: Claude Red Team
verdict: BLOCKED
severity_high: 3
severity_medium: 2
severity_low: 2
attacks_total: 7
---
```

# Red Team Attack Packet — ToolSurfacePolicy Distribution PR

## ATTACK-01 · Sovereign Bypass via Explicit `.proResearch` Parameter (HIGH)

**Vector:** Any call site — including those executing inside an App Store build — can pass `distribution: .proResearch` explicitly. The compile-time gate in `resolvedDistribution` is only reached when `.currentBuild` is passed. The public `Distribution` enum and the public `isSurfacedToolName`/`surfacedTools` parameters provide a direct bypass handle.

**Exploit path:**
```swift
// In an EPISTEMOS_APP_STORE build, this still returns true:
ToolSurfacePolicy.isSurfacedToolName("bash_execute", distribution: .proResearch)
```

Any planning surface, agent bridge, or test helper that accidentally (or maliciously) passes `.proResearch` leaks the full gateway list into a sandboxed binary. The distribution parameter should be internal-only or the public interface should enforce the build-time ceiling.

**Required fix:** Make `Distribution` `internal` (or `fileprivate`) and remove the `distribution` parameter from the public API. Expose only the compile-resolved variant externally. Tests that need to probe both distributions should use `@testable import` and call the internal resolver.

---

## ATTACK-02 · Default-Allow Posture Creates Persistent New-Tool Leak (HIGH)

**Vector:** The hidden list is an explicit-deny set. Any tool added to `agent_core` that is Pro-only will automatically surface in Core/App Store builds until a human manually adds it to `coreAppStoreHiddenToolNames`. There is no compilation link between the Rust tool registry and the Swift deny list — they drift silently.

**Current confirmed gaps in the deny list** (names found in agent_core file map / CLAUDE.md but absent from the set):

| Missing name | Source |
|---|---|
| `code_execution` | `agent_core/src/tools/` — runs arbitrary Python/Node/Ruby/shell |
| `web_fetch` | `agent_core` web_fetch tool distinct from `web_search` |
| `docker` / `docker_run` | Pro/Research Docker surface |
| `hermes_*` (any Hermes gateway tools) | Hermes subprocess orchestration |
| `tirith` | CLAUDE.md subprocess spawn site |
| `media_say` / `say` | `agent_core` media `say` spawn site |
| `osascript` | iMessage/Apple-events spawn site |
| `memory` / `memory_search` / `memory_store` | vault memory tools |
| `workspace_search` | CLAUDE.md JSON-compaction site |
| `file_write` / `file_edit` | arbitrary write surface in sandbox |

**Required fix:** Add a `#if DEBUG` exhaustive-match compile-time assert or a test that cross-checks the deny list against a canonical `knownProResearchToolNames` constant (maintained in parallel with agent_core). Or invert to allowlist posture: explicitly enumerate the ~6 tools Core/App Store may show and deny everything else.

---

## ATTACK-03 · Compile-Time Flag Reliability — No Runtime Fallback (HIGH)

**Vector:** `resolvedDistribution` relies entirely on `#if EPISTEMOS_APP_STORE || MAS_SANDBOX` being set at build time. If the App Store build is produced without these flags (misconfigured CI, custom scheme, developer build for App Store testing), the binary silently resolves to `.proResearch` and exports the full gateway surface. There is no runtime check against sandbox entitlements, `ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]`, or any App Store receipt.

**Exploit path:** Strip the flag from the scheme → gateway tools visible to Core users with no compile error, no test failure, no runtime warning.

**Required fix:** Add a secondary runtime guard:
```swift
private static var isKnownSandboxed: Bool {
    ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
}
```
Fallback: if `isKnownSandboxed` is true, force `.coreAppStore` regardless of compile flag.

---

## ATTACK-04 · Test Coverage Gap — 13 of 32 Deny-List Names Untested (MEDIUM)

**Vector:** The new test `coreAppStoreHiddenGatewayToolsDisappearFromVisibleToolSurfaces` checks 19 names but omits 13 that are in `coreAppStoreHiddenToolNames`:

```
imessage, imessage_contacts, channel_contacts,
apple_notes, apple_reminders, apple_calendar, apple_mail,
skill_manage, custom_tool_manage, trajectory_export,
inline_partner, nightbrain_trigger, image_generate
```

A refactor that accidentally drops any of these from the set would not be caught.

**Required fix:** The test should iterate `coreAppStoreHiddenToolNames` exhaustively (expose as `internal` for `@testable` access) rather than hardcoding a partial list.

---

## ATTACK-05 · `think` Hidden in Core but Not Tested as Hidden in `.proResearch` (MEDIUM)

**Vector:** The `proResearch` test does not include `think` in its input set, so no test verifies that `think` stays hidden even in Pro/Research distribution. A future refactor that accidentally removes the `think` case from the switch (or reorders the guard/switch) could surface it in Pro mode without failing any test.

**Required fix:** Add `think` to the `proResearch` test's input list and assert it is absent from the filtered output.

---

## ATTACK-06 · Case-Sensitivity Assumption — No Canonicalization (LOW)

**Vector:** `coreAppStoreHiddenToolNames.contains(toolName)` is case-sensitive. If any upstream source (Rust FFI, JSON decode, agent_core bridge) delivers tool names with inconsistent casing (e.g. `"Bash_Execute"`, `"TERMINAL"`), the deny-list lookup silently misses and the tool surfaces in a Core build.

**Required fix:** Canonicalize via `toolName.lowercased()` before the `contains` check, and store the set in lowercase.

---

## ATTACK-07 · Policy Is Planning-Only with No Stated Execution Enforcement (LOW)

**Vector:** The patch comment says "visible planning surfaces." There is no execution-layer enforcement visible in this diff. If `isSurfacedToolName` is the sole gate and it is bypassed (Attack-01) or misconfigured (Attack-03), hidden tools are not just visible — they are executable. The audit trail for "this tool was hidden but the agent called it anyway" does not exist in this slice.

**Observation (not a blocker by itself):** The PR description should explicitly state whether a separate execution enforcement layer exists and where it lives. If this is the only gate, it must be hardened against all bypass paths above before merge.

---

## Summary

| ID | Title | Severity | Blocks merge? |
|---|---|---|---|
| ATTACK-01 | Sovereign bypass via explicit `.proResearch` param | HIGH | YES |
| ATTACK-02 | Default-allow posture + confirmed missing tool names | HIGH | YES |
| ATTACK-03 | No runtime sandbox fallback | HIGH | YES |
| ATTACK-04 | Partial test coverage of deny list | MEDIUM | YES |
| ATTACK-05 | `think` not tested hidden in proResearch | MEDIUM | NO (advisory) |
| ATTACK-06 | Case-sensitivity assumption | LOW | NO (advisory) |
| ATTACK-07 | Execution enforcement not stated | LOW | NO (advisory) |

CLAUDE-RETURN: BLOCKED — three HIGH findings must be resolved before this slice merges. Minimum: (1) make `Distribution` internal and remove the bypass handle from the public API, (2) expand the deny list to cover the confirmed missing names or invert to allowlist posture, (3) add a runtime sandbox-entitlement fallback. ATTACK-04 test gap should also be fixed in the same PR.
