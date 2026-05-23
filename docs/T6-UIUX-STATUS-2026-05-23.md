# T6 UI/UX Worktree Status - 2026-05-23

Terminal: T4 worktree and auxiliary branch salvage
Status branch: `salvage/t6-uiux-status-2026-05-23`
Donor worktree inspected: `/Users/jojo/Downloads/Epistemos-t6-uiux`
Donor branch: `codex/t6-uiux-2026-05-16`
Donor head: `775137b831`
Preservation tag: `preserve/T6-uiux-2026-05-20-snapshot`

## Decision

T6 is stopped, not active. Do not mine code from it now.

The branch has no commits after 2026-05-22. Its last branch commit is
`775137b831` from 2026-05-17T12:17:00-05:00:

```text
775137b831 2026-05-17T12:17:00-05:00 fix(ui): clarify Gain vs Master volume in live-player chain order
```

## Worktree State

`git status --short --branch` in `/Users/jojo/Downloads/Epistemos-t6-uiux`
shows the branch in sync with origin:

```text
## codex/t6-uiux-2026-05-16...origin/codex/t6-uiux-2026-05-16
```

The dirty files are generated build artifacts under `syntax-core/target/...`,
matching `docs/WORKTREE_PRESERVATION_2026_05_20.md`. No source-file dirt was
found in the status output. The worktree was inspected only; no cleanup was
performed.

## Scope Against Main

Diff status from `origin/main..codex/t6-uiux-2026-05-16`:

```text
A 30
D 392
M 120
```

Representative additive files:

```text
Epistemos/Shaders/LandingWave.metal
Epistemos/Views/Landing/SessionIntelligenceOverlay.swift
Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift
EpistemosTests/LandingWaveChoreographyTests.swift
docs/audits/UI_UX_Audio_AudiophileUpgrade_2026-05-17.md
docs/audits/UI_UX_Halo_ProvenanceConsole_2026-05-17.md
```

Representative modified files:

```text
Epistemos/Engine/AmbientFrequencyLivePlayer.swift
Epistemos/Views/Chat/LiveActivityStrip.swift
Epistemos/Views/Chat/ProcessDisclosureViews.swift
Epistemos/Views/Settings/ProvenanceConsoleView.swift
Epistemos/Views/Landing/LandingView.swift
Epistemos/Views/Settings/SettingsView.swift
```

The large `D` count is from comparing an older UI branch to current main, not
from a safe deletion proposal. It confirms that wholesale merge or broad
cherry-pick would be unsafe.

## Donor-Mining Test

| Test | Result | Evidence |
| --- | --- | --- |
| Unique vs main? | Yes | T6 contains UI polish, audio-chain, accessibility, provenance, and LandingWave work absent from main. |
| Pure-additive? | Mostly no | The useful UI work is primarily modifications to existing Swift views, project files, and tests. |
| Compiles without old architecture? | No proof | No build was run; branch is old and broad against post-Hermes main. |
| Preserves doctrine? | Deferred/risky | `docs/MAY16_ARCHEOLOGY_2026_05_23.md` says most T6 work is modifications and LandingWave fork-drift. |
| Spine class | Mostly tangential; some spine-adjacent | Accessibility and provenance-console polish are useful but not spine-critical. |

## WRV Classification

`stopped`, `status-only`, `no-code-mined`, `deferred-ui-refactor`, `not-current-wired`.

## Recommendation

Leave the T6 worktree alone. Keep the preservation tag. Future UI/refactor work
can manually re-evaluate small ideas from T6, especially accessibility details,
the Ambient Frequency audio-chain controls, Halo persistence, and Provenance
Console pagination. Do not wholesale merge or cherry-pick broad T6 files.
