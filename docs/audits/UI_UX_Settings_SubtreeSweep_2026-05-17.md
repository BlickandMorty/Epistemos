# UI/UX Audit — Settings sub-tree sweep (consolidated)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 12)
- **Driver**: §4.C — user direction 2026-05-17: drop the 14-day window
  filter, audit everything in T6 scope.
- **Surface under audit**: all 33 files in `Epistemos/Views/Settings/`
  (13,264 LOC total).
- **Coverage to date**: iters 1, 3, 8 covered AmbientFrequencySettingsView,
  the Diagnostics Section composition, RuntimeTruth + ShadowSearch +
  APIKeys + AnswerPacket + CognitiveDag + EditorBundle +
  BackgroundIndexing + ProvenanceConsole. This iter sweeps the
  remaining 24 files.
- **Verification mode**: Static scan + grep-driven pattern detection +
  spot-reads of medium-size files. iter-1 env constraints unchanged.

## Cross-cutting findings (evidence-backed)

### CC-1 — Accessibility coverage is concentrated in 7 files; absent from 20.

Grep for `accessibilityLabel|Value|Hint|Element` across all 33 files:

| Count | File |
|---|---|
| 33 | SettingsView.swift (mostly `.accessibilityAction`/`.accessibilityHidden` in the umbrella) |
| 13 | AgentControlSettingsView.swift |
| 4 | OverseerSettingsView.swift |
| 2 | PrivacyDetailView.swift, CognitiveDagHealthRow.swift, APIKeysHealthRow.swift |
| 1 | HELIOSv5SettingsView.swift |
| **0** | VoicePreferencesSection, StructuredSurfacesView, SkillsSettingsView, ShadowSearchHealthRow, SettingsSurfaceComponents, SearchFusionHealthRow, RuntimeTruthHealthRow, ProvenanceConsoleView, ProcessMemoryHealthRow, PerformanceSettingsSection, OpLogProjectionHealthRow, OmegaSettingsDetailView, ModelVaultsSettingsView, IMessageDriverSettingsView, GraphEventVisibilityRow, EditorBundleHealthRow, DeploymentProfileHealthRow, CognitiveSettingsSection, CLIDiscoveryHealthRow, AmbientFrequencySettingsView, AnswerPacketHealthRow, ArenaHealthRow, AgentSectionDetailView, AgentEventVisibilityRow |

Even files I praised in earlier iters (RuntimeTruthHealthRow, ShadowSearchHealthRow) have zero explicit a11y modifiers — SwiftUI's auto-merging covers the basic case but inconsistency hurts VoiceOver users sweeping through the Diagnostics list.

**Verdict**: this is a **systemic P2** worth a dedicated single-PR
sweep that introduces a shared modifier like:

```swift
extension View {
    func diagnosticsRowAccessibility(label: String, value: String, isHealthy: Bool) -> some View {
        accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityValue("\(value), \(isHealthy ? "healthy" : "needs attention")")
    }
}
```

And applies it across the row helpers. Estimated PR: ~50 LOC across 15 files.

### CC-2 — `AnyShapeStyle(Color.green / .red / .orange)` boilerplate.

11 health rows use the same `AnyShapeStyle(Color.X)` wrapper inside a
ternary — verified via:

```
ArenaHealthRow, AnswerPacketHealthRow, APIKeysHealthRow,
CognitiveDagHealthRow, CLIDiscoveryHealthRow, EditorBundleHealthRow,
GraphEventVisibilityRow, OpLogProjectionHealthRow,
ProcessMemoryHealthRow, SearchFusionHealthRow, ShadowSearchHealthRow
(also AgentEventVisibilityRow)
```

`foregroundStyle` accepts `Color` directly when both branches are
the same concrete `ShapeStyle` type. Trivial cleanup. ~12 lines across 12 files.

### CC-3 — `ObservableObject` usage is **zero** in `Epistemos/Views/**`.

Confirmed via `grep -lE "ObservableObject\b" Epistemos/Views/**/*.swift`
— no matches. The `8b182ced6` + `3a0856cd7` migration wave fully
closed standing-check #4. ✅

## Per-file notes (24 not previously audited)

Highlights only — no findings beyond CC-1/CC-2 unless flagged.

- **AgentControlSettingsView.swift** (1,095 LOC) — large; deferred to
  iter 13 for deeper read. Quick scan: 13 explicit a11y modifiers — by
  far the strongest a11y discipline in the sub-tree.
- **AgentEventVisibilityRow.swift** (83) — health-row pattern; CC-1, CC-2.
- **AgentSectionDetailView.swift** (190) — health/visibility detail
  pop-out; CC-1.
- **ArenaHealthRow.swift** (99) — clean health-row pattern; CC-1, CC-2.
  Snapshot details include path + bridge budgets + materialization
  state. Honest disclosure ("does not create a memory authority lane").
- **AuthoritySettingsView.swift** (357) — deferred to iter 13.
- **ChannelsSettingsView.swift** (1,120) — largest non-umbrella;
  deferred to iter 14.
- **CLIDiscoveryHealthRow.swift** (178) — gate at file-level `#if !
  (EPISTEMOS_APP_STORE || MAS_SANDBOX)` strips CLI path strings from
  the MAS binary (RCA3-P0-001 closure). Strong honest-gating. CC-1, CC-2.
- **CognitiveSettingsSection.swift** (81) — 4 toggle sections (Capture,
  Friction, Night Brain, SSM State Persistence) + embedded
  VoicePreferencesSection. Privacy language is exemplary ("No
  keystroke logging and no hidden cloud sync are involved here.").
  No interactive a11y annotations.
- **DeploymentProfileHealthRow.swift** (123) — RCA13 P1-021 honesty
  row (MAS vs Pro + per-profile capability deltas). CC-1, CC-2.
- **GraphEventVisibilityRow.swift** (121) — sibling of
  AgentEventVisibilityRow; same pattern.
- **HELIOSv5SettingsView.swift** (121) — 1 a11y annotation; legacy
  feature surface.
- **IMessageDriverSettingsView.swift** (1,052) — large; deferred to
  iter 14. Sensitive (iMessage permission + driver toggle).
- **ModelVaultsSettingsView.swift** (453) — deferred to iter 13.
- **OmegaSettingsDetailView.swift** (12) — trivial wrapper; nothing to audit.
- **OpLogProjectionHealthRow.swift** (130) — health-row pattern; CC-1, CC-2.
- **OverseerSettingsView.swift** (330) — 4 a11y modifiers; deferred to iter 13.
- **PerformanceSettingsSection.swift** (169) — two-axis design
  (`StartupMode` × `IdleMemoryMode`) with @AppStorage persistence.
  Honest about wiring status ("UI shipped + flags persisted. The
  actual behavioral wiring lands as their respective issues
  complete"). Clean. CC-1.
- **PrivacyDetailView.swift** (204) — 2 a11y modifiers; privacy
  surface — sensitive copy.
- **ProcessMemoryHealthRow.swift** (211) — health-row pattern; CC-1, CC-2.
- **SearchFusionHealthRow.swift** (179) — health-row pattern, RRF
  Phase 6 obs row. CC-1, CC-2.
- **SettingsSurfaceComponents.swift** (30) — shared bits
  (SettingsDescriptionCard / SettingsDescriptionText). Pure layout.
- **SettingsView.swift** (3,763) — umbrella; **Diagnostics section
  already audited in iter 3**. Other sections (Notes, Chat, Workspaces,
  Performance, etc.) span thousands of lines — too large to deep-read
  here. Spot-checks across the file show strong a11y discipline (33
  modifiers, mostly `.accessibilityAction(named:)` for sovereign-gate
  flows). Worth a dedicated iter (or splitting the file).
- **SkillsSettingsView.swift** (631) — deferred to iter 13.
- **StructuredSurfacesView.swift** (345) — structured A2UI surface
  toggles. 0 a11y; deferred to iter 13.
- **VoicePreferencesSection.swift** (139) — W11.4 Apple-native voice
  surfaces with Auto/Manual mode. 0 a11y annotations on toggles;
  surface is small enough to refine in the cross-cutting sweep.

## Findings summary

### P0 / P1

None.

### P2 — defer (cross-cutting)

- **CC-1** — apply a `diagnosticsRowAccessibility(...)` modifier
  across the 20 a11y-zero files in this sub-tree. Single PR.
- **CC-2** — strip `AnyShapeStyle(Color.X)` wrappers across the 11
  health rows. Single PR.
- **CC-3** — closed (ObservableObject = 0 in Views).

### Per-file P2s

- Several large files (AgentControlSettingsView 1095, ChannelsSettings
  1120, IMessageDriver 1052, SettingsView 3763, SkillsSettings 631,
  ModelVaults 453) **deferred for dedicated iter 13-14+ deep reads.**
  The umbrella (SettingsView) could be a candidate for a Phase-2
  split into per-section files.

## Action taken this iter

- Filed this audit doc.
- **No code edits.** P2s are cross-cutting and deserve dedicated
  consistency PRs.

## Carry-overs

- iter 13: Settings medium files — Authority, ModelVaults, Overseer,
  Structured.
- iter 14: Settings large files — Channels, AgentControl,
  IMessageDriver, Skills, SettingsView umbrella sections beyond
  Diagnostics.
- iter 15+: Notes (43 files), Chat (25), Graph (18), Epdoc (11),
  Shared (13), Halo (already done), Onboarding/Capture/RawThoughts/etc.

## Coverage update

Settings sub-tree: 12 of 33 files deep-audited across iters 1-12.
Sweep + cross-cutting findings cover the remaining 20+ at the
pattern-level. Deeper reads of the 6 largest files queued.
