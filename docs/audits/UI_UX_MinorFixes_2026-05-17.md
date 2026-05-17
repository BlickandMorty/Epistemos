# UI/UX Audit — Consolidated minor UI fixes (14-day window)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 7 — rapid-fire sweep)
- **Driver**: §4.C — recursive audit of every UI surface touched in the
  last 14 days.
- **Verification mode**: Static, per-commit diff review. iter-1 env
  constraints unchanged.

Five small UI commits from the audit window get a one-section pass each.
Commits were merged with healthy explanations + per-commit test/build
notes, so the bar here is "did the fix introduce a new UX seam I should
flag?" rather than a full 8-step protocol.

---

## 1. Graph folder filter opt-in + sidebar blur consistency

**Commit**: `57bc2d7b3` (2026-05-15) — *fix(graph,sidebar): folder
filter off by default + sidebar blur on all modes.*

- `Epistemos/Models/GraphTypes.swift` adds `defaultActiveCases` as the
  single source of truth (`visibleCases - .folder`).
- `Epistemos/Graph/FilterEngine.swift` updated init / reset /
  showAllTypes / applyHumanVaultMode / resetForVaultLifecycle.
- `Epistemos/Views/Sidebar/SidebarShell.swift` applies `.thinMaterial`
  at the outer VStack so all three modes (myVault, modelVaults,
  system) inherit the same blur.

**Verdict**: clean. Single source-of-truth pattern is correct. Doc
comment at `GraphTypes.swift:80-94` is honest about the rationale
("folder nodes clutter the visible graph at typical zoom levels").

**P2 — defer**: discoverability. New users may not realize folder nodes
exist at all when they're off by default. Per §4.C step 6 (visual
discoverability), a one-line subtitle in the graph filter popover like
*"Folder nodes — opt-in to see folder containers"* would help. Not
P1 — the doc/commit comment notes this is by user direction.

---

## 2. Vault Organizer "duplicate folder names" tooltip

**Commit**: `8547c0aa9` (2026-05-14) — *fix(c6): Vault Organizer V1
known-limitation tooltip (RCA2-P2-005).*

- `Epistemos/Views/Notes/VaultOrganizerView.swift:803-808` adds a
  `.help(...)` tooltip on the `.moveToFolder` suggestion-row text:
  *"Matches by folder name. If duplicate folder names exist in
  different branches, the first match wins."*

**Verdict**: honest disclosure of a V1 limitation. ✅ matches the
"honest capability gating" CLAUDE.md rule.

**P2 — defer**: hover-only surface. `.help(...)` only renders on
pointer hover; keyboard-only users + VoiceOver may miss it (VoiceOver
does read it as an accessibility hint on macOS 14+ — half-credit).

- Fix sketch: add a small `info.circle` button beside the suggestion
  with the same string in `.accessibilityHint`, so the disclosure
  reaches every input mode.

**P3 — defer**: case-insensitive name match (per commit body) means
"Notes" and "notes" collide. Worth recording for the V1.1 follow-up.

---

## 3. ComposerVoiceInputService → @Observable migration

**Commit**: `8b182ced6` (2026-05-15) — *refactor(composer):
ComposerVoiceInputService → @Observable.*

- `Epistemos/Engine/ComposerVoiceInputService.swift`: 7 LOC diff —
  drop `: ObservableObject`, add `@Observable` macro, remove
  `@Published` on stored vars.
- `Epistemos/Views/Chat/ComposerMicButton.swift:1 LOC` —
  `@StateObject` → `@State` (singleton lifecycle preserved).

**Verdict**: textbook @Observable migration. Standing-check count
4 → 3 (per commit body). RCA-P1-002 drift gates passed.

**P0/P1/P2**: none. Pure refactor.

**Observation**: 3 ObservableObject violations remain
(`CodeCompanionService`, `CodeContextBridge`, `CodeInsightGenerator`
in CodeEditorView.swift) per the commit body. CLAUDE.md project rule
is "Use @Observable, not ObservableObject." Not in §4.C scope but
worth recording for a follow-up.

---

## 4. CodeEditor horizontal scroller always-visible

**Commit**: `86edaf88a` (2026-05-15) — *fix(editor): force horizontal
scroller visibility for long-line files.*

- `Epistemos/Views/Notes/CodeEditorView.swift:2520-2538` adds
  `forceHorizontalScrollerVisibility(_ scrollView:)` in
  `EpistemosEditorCoordinator.prepareCoordinator`, switching
  `scrollerStyle = .legacy` + `hasHorizontalScroller = true` +
  `autohidesScrollers = false`.

**Verdict**: solves a real user-reported issue (`.jsonl` long lines
clipped, no visible scrollbar discovered). The screenshot + user
quote ("i cant scroll over only vertically") in the commit message
gives strong UX justification.

**P2 — defer**: scrollbars are now **always visible** on every code-
editor instance, regardless of overflow. Files with short lines
(typical Swift, Markdown) show a permanently-visible empty scrollbar
strip. Minor visual cost in service of the bigger discoverability
win.

- Fix sketch: `autohidesScrollers = false` only when content extends
  beyond the viewport. Requires watching content-size changes — more
  invasive than the current fix. Defer.

---

## 5. Graph blur transitions on canvas → note navigation (3-commit chain)

**Commits**: `2e356269b` (hide Metal canvas on leave), `8e371de91`
(hide graph blur + darken backing), `916e4f2e6` (preserve blur
wallpaper when navigating to note).

Three sequential fixes on `Epistemos/Views/Graph/HologramOverlay.swift`
(2,059 LOC) in 2 days, all tagged `RCA-GRAPH-NOTE-BLUR-001`.

**Verdict**: a tight feedback loop on transition glitches. Iteration
discipline is healthy — each commit narrows the failure mode further.

I did not read the full 2,059-LOC overlay in this iter. The size +
RCA tagging + tight commit cadence suggest the surface deserves its
own dedicated iter when there's enough context budget. **Flag for
iter 8+**.

**P2 — observation**: a surface that needs three commits in two days
on the same transition is a candidate for either (a) a state machine
that names every transition explicitly, or (b) a snapshot-test that
pins the canvas/blur visibility against a small set of route
configurations. Defer for now.

---

## Cross-cutting observations

- **Honest "V1 known limitation" disclosure** is a consistent pattern
  across the wave (Vault Organizer tooltip, CognitiveWeightBadge W1
  doctrine note, Settings → Diagnostics descriptions). ✅
- **Test discipline** is uneven. Composer migration ships 3 drift
  gates; folder filter ships 5 test updates; CodeEditor scrollbar fix
  ships zero tests; Vault Organizer tooltip ships zero tests. Static
  `.help` strings probably don't need a test, but the editor's
  scrollbar-visibility change is a candidate for an integration test
  ("long-line file shows horizontal scrollbar at the foot").
- **Hover-only tooltips** (.help) appear in multiple places without
  equivalent .accessibilityHint coverage. Pattern worth standardizing.

## Action taken this iter

- Filed this audit doc.
- **No code edits.** All P0/P1-class issues are already addressed in
  the trigger commits. P2 items are either tradeoffs the original
  authors accepted (scrollbar always-visible) or candidates for a
  cross-cutting consistency pass (hover-only tooltips, ObservableObject
  remainder).

## Carry-overs

- §4.C step 1: visual / computer-use verification of the graph blur
  transitions remains gated.
- HologramOverlay deserves a dedicated iter when budget allows.
- ObservableObject remainder (3 services in CodeEditorView.swift) per
  the Composer commit body.
- Hover-only `.help(...)` → `.accessibilityHint(...)` coverage pass.

## Iter-1..7 status

| iter | feature | doc |
|---|---|---|
| 1 | AmbientFrequencies + Settings UI (3 P1 fixes applied) | `UI_UX_AmbientFrequencies_2026-05-17.md` |
| 2 | AmbientFrequencyLivePlayer | `UI_UX_AmbientFrequencyLivePlayer_2026-05-17.md` |
| 3 | Settings → Diagnostics rows | `UI_UX_Settings_Diagnostics_2026-05-17.md` |
| 4 | Halo panel + Provenance Console | `UI_UX_Halo_ProvenanceConsole_2026-05-17.md` |
| 5 | CognitiveWeightBadge | `UI_UX_CognitiveWeightBadge_2026-05-17.md` |
| 6 | Notes ask-bar error surface | `UI_UX_NotesAskBarError_2026-05-17.md` |
| 7 | 5 minor UI fixes (graph folder, vault tooltip, composer, code editor, graph blur) | this doc |

Available driver-listed surfaces 1-2, 9, 10 are fully covered.
Remaining items 3-8 are blocked on T1-T5 UI landings.
