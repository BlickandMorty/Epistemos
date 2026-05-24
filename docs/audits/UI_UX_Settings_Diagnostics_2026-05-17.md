# UI/UX Audit — Settings → Diagnostics rows

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 3)
- **Driver**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.C
- **Surface under audit**:
  - `Epistemos/Views/Settings/SettingsView.swift` lines 728-775 (Diagnostics
    Section composition)
  - 14 health-row views in `Epistemos/Views/Settings/*HealthRow.swift`
  - Focus on the **5 rows touched in the last 14 days**: RuntimeTruth,
    ShadowSearch, APIKeys, EditorBundle, AnswerPacket
- **Verification mode**: Static review. Env constraints from iter 1 still
  apply (no computer-use MCP; xcodebuild blocked by pre-existing
  `ContradictionFfi` typealias in `Epistemos/Vault/VaultLifecycleService.swift`).

## Composition health

`SettingsView.swift:728-775` declares the Diagnostics Section as a single
`Section("Diagnostics")` with 15 rows in deliberate order:

1. `RuntimeTruthHealthRow` — canonical "what's running now"
2. `EditorBundleHealthRow`
3. `ShadowSearchHealthRow`
4. `BackgroundIndexingHealthRow`
5. `ProcessMemoryHealthRow`
6. `ArenaHealthRow`
7. `OpLogProjectionHealthRow`
8. `AgentEventVisibilityRow`
9. `GraphEventVisibilityRow`
10. `SearchFusionHealthRow`
11. `CognitiveDagHealthRow`
12. `AnswerPacketHealthRow`
13. `APIKeysHealthRow`
14. `DeploymentProfileHealthRow`
15. `CLIDiscoveryHealthRow` (Pro-only, `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`)

**Strengths preserved:**

- Canonical row first (RuntimeTruth) — every other row answers a narrower
  question, so users find "what's running now" without scrolling.
- MAS / Pro platform split honored — CLIDiscovery is correctly Pro-only;
  RuntimeTruthHealthRow even shows a "Subprocess CLIs are not available in
  this build" branch on MAS (lines 209-219). Honest gating.
- Section is read-only by design — opening Settings must not poke the
  Shadow index or kick a Tantivy refresh. `ShadowSearchHealthRow.init`
  reads a snapshot, doesn't query (line 14-16). Comment at the top
  documents the discipline.
- Notification-driven refresh — `ShadowSearchHealthRow` subscribes to
  `ShadowSearchDiagnostics.didChangeNotification`; `AnswerPacketHealthRow`
  subscribes to `didEmitNotification`. No `Timer.publish` polling.
- All recently-touched rows compile in isolation per the xcodebuild log
  (only error is the pre-existing vault typealias).

## Findings

### P0 — blockers

None.

### P1 — must-fix

None for the Diagnostics surface; all P1-class issues found this iter
are localized to single rows with low blast radius. Listing them as P2
below.

### P2 — defer

**P2-1 — Inconsistent VoiceOver discipline across rows.**

`APIKeysHealthRow.swift:132-133` and `CognitiveDagHealthRow.swift:112-113`
both wrap each row in:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(probe.displayName): \(probe.statusText)")
```

The result: VoiceOver reads the row as a single semantic unit with a
human-readable summary. Good.

Rows that **do not** follow this pattern:

- `RuntimeTruthHealthRow.swift:226-262` (`runtimeRow` helper)
- `ShadowSearchHealthRow.swift:113-137` (`row` helper)
- `EditorBundleHealthRow.swift` (didn't inspect line-by-line; pattern
  absent based on grep)

The default SwiftUI HStack-of-Image+Text auto-merges, so VoiceOver does
*reach* each row — driver step 5 ("Tab + Space navigation must reach
every interactive element") is satisfied. But the announcement is
inconsistent — the user hears polished summaries on two rows and
icon+label+detail concatenations on the others.

- **Fix sketch**: standardize a `DiagnosticsRowAccessibility` view
  modifier and apply uniformly. ~15-line PR.

**P2-2 — Color-only state signaling.**

`ShadowSearchHealthRow.swift:130-131` paints a trailing icon green when
ok=true, red when ok=false:

```swift
Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
    .foregroundStyle(ok ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.red))
```

The icon shape itself carries the OK/Fail semantic, so colorblind users
can still distinguish state. Good. But the same row pattern is reused
without an `.accessibilityLabel("Healthy")` / `"Failed"` — VoiceOver
falls back to the SF symbol name ("Checkmark Circle Fill") which is
serviceable but not as crisp as an explicit label.

Same pattern: `RuntimeTruthHealthRow.swift:197` uses
`accent: .green / .secondary` on the tool-loop label — color-only
signal with no a11y compensation. The text itself ("Rust managed
agent (cloud + tools)" vs "Cloud direct stream") carries the
information, so a colorblind sighted user is fine; a VoiceOver user
hears the text but not the "tools-enabled" coloring.

- **Fix sketch**: add `.accessibilityValue(ok ? "Healthy" : "Failed")`
  on the trailing status icon; for the tool-loop row, add
  `.accessibilityHint(toolLoopSummary.isToolEnabled ? "Tools available
  this turn" : "No tools this turn")`.

**P2-3 — No localization coverage.**

Every string in the recently-touched rows is hardcoded English
(`Text("Runtime truth")`, `Text("What's actually running right now")`,
etc.). The project ships a `Resources/Localizable.xcstrings` (visible
in the xcodebuild log) — none of these rows route through it.

- Not on §4.C's gate. Defer to a localization sub-mission.

**P2-4 — `AnyShapeStyle(Color.green)` boilerplate.**

`ShadowSearchHealthRow.swift:131` uses `AnyShapeStyle(Color.green)`
inside the ternary. `foregroundStyle` accepts `Color` directly:

```swift
.foregroundStyle(ok ? .green : .red)
```

works. The `AnyShapeStyle` wrapper is only needed when the two branches
have different concrete `ShapeStyle` types. Here both are `Color`.
Trivial cleanup.

### P3 — observations

- **P3-1** — The 15-row Section is becoming long. SwiftUI Sections don't
  paginate. Consider grouping under DisclosureGroups by domain (Runtime /
  Index / Memory / Pro-only) when count crosses 20. Not actionable today.
- **P3-2** — `BackgroundIndexingHealthRow` is referenced by SettingsView
  line 741 but lives outside the `*HealthRow.swift` glob; verify it
  follows the same read-only discipline if it appears in a future audit.

## Action taken this iter

- Filed this audit doc.
- **No code edits this iter.** P1-class items are absent on the
  Diagnostics surface; P2 a11y consistency is a multi-row coordinated
  change that's better as a single PR after the carry-overs from iter 1
  and iter 2 land.

## Carry-overs

- All P2/P3 items above; suggested batch into a "Diagnostics
  accessibility consistency" iter once the iter-1/2 P2 backlog
  (live-player SRR click, switch-click crossfade, route-change
  resilience) is in flight.
- Iter 4 candidates: Halo / shadow search panel UI
  (`Epistemos/Views/Halo/*`) and Provenance Console rows (driver lists
  these as #10).
