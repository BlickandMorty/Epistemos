# UI/UX Audit — CognitiveWeightBadge (4-tier Semantic Gravity chip)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 5)
- **Driver**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.C —
  recursively audit every feature touched in the last 14 days.
- **Surface under audit**:
  - `Epistemos/Views/Shared/CognitiveWeightBadge.swift` (138 LOC)
  - Wired into Halo ShadowRow at `Epistemos/Views/Halo/ShadowPanelContent.swift`
    (commit 3176f52e0 — 2026-05-15)
- **Verification mode**: Static review. iter-1 env constraints unchanged.

## Strengths (preserve)

CognitiveWeightBadge is exemplary §B.6 W1 craft.

- **Four tiers each carry independent shape, color, fill, and outline
  cues** — colorblind users can distinguish state by shape alone
  (`circle.dotted` / `circle.fill` / `shield.lefthalf.filled` /
  `shield.fill`). WCAG 1.4.1 honored.
- **Accessibility surface is complete**:
  - `.help(weight.class.accessibilityDescription)` for hover (line 59)
  - `.accessibilityLabel(weight.class.accessibilityDescription)` for
    VoiceOver (line 60)
  - `.accessibilityValue("raw score \(rawScore)")` so power users
    debugging hear the underlying weight (line 61)
- **W1 doctrine honored**: the file header (lines 8-17) explicitly notes
  that PolicyGrade is *advisory* in W1 and that no UI element claims
  enforcement — no LOCK icon, no "ENFORCED" label, no irreversible
  styling. The slightly thicker outline (1.0 vs 0.5) is the only
  policy-tier emphasis, and that's noted in the code comment at
  lines 102-106.
- **Visual rhythm consistent**: all four variants share the same
  `Capsule(style: .continuous)` shape, padding, font weights, and icon
  size. Lines up cleanly in row layouts (a stated design goal in the
  doc comment).
- **`#Preview("All four tiers")`** renders all classes side-by-side
  for inspection (lines 117-138).

## Findings

### P0 / P1

None. The component meets §4.C steps 5 (a11y), 6 (visual + WCAG), and
step 7 (no persistent state to fail across relaunch — it's a pure
rendering of an input value).

### P2 — defer

**P2-1 — Dark-mode contrast spot-check on `.policyGrade`.**

`.policyGrade` uses `Color.orange` foreground over `Color.orange.opacity(0.12)`
fill. On dark mode the system `Color.orange` is brighter (~#FF9500) and
the 0.12 fill darkens against the panel background, so contrast should
remain comfortable. Worth verifying once computer-use is wired.

- Not P1: no clear contrast violation in light mode. Dark mode warrants
  a visual sweep, not a code change.

**P2-2 — No Dynamic Type scaling on the badge fonts.**

The badge uses fixed `font(.system(size: 9))` for the icon and
`size: 10` for the label (lines 44, 46). At high Dynamic Type sizes
the badge stays the same physical size while surrounding text grows —
the chip looks tiny relative to its row. macOS surfaces use Dynamic
Type less aggressively than iOS, but a fixed point size dodges the
system convention.

- Fix sketch: scale via `.dynamicTypeSize(.xSmall ... .xxxLarge)`
  modifier or switch to `.font(.caption2)` which respects user
  preferences. Defer — Halo ShadowRow itself likely also pegs sizes.

**P2-3 — Color tokens are direct system colors, not theme-routed.**

The opacity-laddered backgrounds (Color.primary.opacity(0.04), Color.blue.opacity(0.08),
Color.purple.opacity(0.10), Color.orange.opacity(0.12)) bypass the
project's theme system (Platinum / ChonkyPixels / oledSoft mentioned
in `git log` over the audit window). When the user picks a custom
theme, the badge stays system-default. Not strictly wrong — the badge
intentionally carries a global semantic signal — but worth a
once-over by the theming sub-mission.

### P3 — observations

- **P3-1**: `weight.class.shortLabel` and `accessibilityDescription`
  live on `CognitiveWeightClass` in
  `Epistemos/Models/CognitiveWeight.swift`; this audit covers only the
  view layer.
- **P3-2**: Component is `public struct CognitiveWeightBadge` — open
  for reuse in any new surface that loads a CognitiveWeight-tagged
  resource (composer attachments, Provenance Console rows). Good
  reusability.

## Action taken this iter

- Filed this audit doc.
- **No code edits.** No P0/P1. P2 items are layered into theming /
  Dynamic-Type / dark-mode-pass sub-missions.

## Carry-overs

- P2-1 dark-mode contrast spot-check; computer-use gated.
- P2-2 Dynamic Type scaling — pair with a Halo ShadowRow density
  pass.
- P2-3 theme-route the color tokens.

## Iter recap

iters 1-5 complete. Surfaces covered:

| iter | feature | audit doc |
|---|---|---|
| 1 | AmbientFrequencyAudioGenerator + Settings UI | `UI_UX_AmbientFrequencies_2026-05-17.md` |
| 2 | AmbientFrequencyLivePlayer | `UI_UX_AmbientFrequencyLivePlayer_2026-05-17.md` |
| 3 | Settings → Diagnostics rows | `UI_UX_Settings_Diagnostics_2026-05-17.md` |
| 4 | Halo panel + Provenance Console | `UI_UX_Halo_ProvenanceConsole_2026-05-17.md` |
| 5 | CognitiveWeightBadge | this doc |

Pending on other terminals landing UI: F-VaultRecall-50 (T4),
AgentBlueprint (T2), per-model badges (T2), UAS-ACS visualizer (T3),
EML-IR diagnostic row (T5), Tri-Fusion mutation surface (T1).
