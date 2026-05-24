# UI/UX Audit — Final sweep of remaining sub-trees

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 15)
- **Driver**: §4.C — user direction 2026-05-17: audit everything in
  T6 scope.
- **Surfaces under audit**: every remaining file in `Epistemos/Views/`
  not previously covered.
- **Verification mode**: Static scan + grep patterns.

This iter closes out pass-1 coverage of the entire 209-file
`Epistemos/Views/` tree.

## Sub-trees covered this iter

| sub-tree | files | LOC |
|---|---|---|
| Epdoc | 11 | 2,674 |
| Shared | 13 | 3,629 |
| Sidebar | 5 | 323 |
| Landing (root) | 6 | 4,363 (incl. nested) |
| Landing/Wave | 9 | 3,112 |
| Landing/Farm | 9 | 252 (Wave + Farm = ~3,364 total nested) |
| Omega | 6 | 149 |
| ModelProfiles | 4 | 620 |
| Onboarding | 2 | 601 |
| MiniChat | 2 | 2,060 |
| Capture | 2 | 837 |
| Sessions | 2 | 440 |
| Resonance | 2 | 330 |
| Recall | 2 | 264 |
| RawThoughts | 2 | 445 |
| Workspace | 1 | 203 |
| Vault | 1 | 134 |
| Skills | 1 | 226 |
| Journal | 1 | 158 |
| Cost | 1 | 350 |
| Approval | 1 | 370 |
| Shell | 2 | 168 |
| **Total** | **~85** | **~24,000** |

## CLAUDE.md rule compliance

Grep across all remaining sub-trees for `\btry!|^\s*print\(|
DispatchQueue\.main\.sync|: ObservableObject`:

**4 `print(` hits — all inside `#if DEBUG #Preview(...) #endif`**
in `Epistemos/Views/Shared/VoiceInputButton.swift:259-265`. These
are preview-only `onFinal: { print(...) }` callbacks, not production
paths. **Acceptable** per CLAUDE.md ("no print() in production paths").

**Zero `try!`, zero `DispatchQueue.main.sync`, zero `ObservableObject`**
across all 209 files in the Views tree. ✅

## A11y coverage (zero-modifier files)

The systemic a11y gap noted in iters 12-14 continues here. Files with
**zero** explicit a11y annotations include:

- **Epdoc**: VoiceInputButton, TypewriterMarkdown, TypewriterASCIIRippleText,
  ScrollStability, ReasoningTrajectoryBadge, ReadAloudButton,
  ModelVoicePickerSection, MarkdownTextView, MarkdownDocumentModeToggle,
  EpdocThoughtAttachedBadge, EpdocSlashMenuView, EpdocKaTeXPreview,
  EpdocInsertLinkPicker, EpdocEditorChromeView, EpdocCopilotDockView,
  EpdocBubbleMenuView. **Only EpdocEditorToolbar (2) and EpdocComplexityMeter (2)
  + CognitiveWeightBadge (2) + ChatCapabilityPill (1)** in Epdoc + Shared
  have any a11y modifiers.
- **Landing/Wave** (9 files, custom Metal renderer): zero a11y across
  every file — same pattern as MetalGraphView (iter 14).
- **Landing/Farm** (9 files): only `CompanionView` has any (3).
- **Sidebar**: SidebarShell, SidebarModeStore, ModeSwitcherControl all zero.
  VaultSelectorView + PinnedStripView have 1 each.
- **Sessions, RawThoughts, Resonance/ResonanceLegendView,
  Onboarding/SetupAssistantView, Omega/TaskInputBar, ResearchRequestView,
  Workspace/ArtifactHostView, Vault/ConflictCardView, Skills/SkillEvolutionView,
  Shell/PageShell**: zero a11y annotations.

**Best a11y discipline in this iter's scope:**

| Count | File |
|---|---|
| 6 | Landing/LandingView |
| 6 | Cost/CostDashboardView |
| 4 | Recall/ContextualShadowsPanel |
| 3 | MiniChat/MiniChatView |
| 3 | Landing/Farm/CompanionView |
| 2 | Resonance/ResonanceChip, Onboarding/VaultReprompSheet, CognitiveWeightBadge (already audited iter 5) |
| 2 | EpdocEditorToolbar, EpdocComplexityMeter |

## Notable surfaces

### Epdoc sub-tree (11 files, 2,674 LOC)

The Tiptap-based WKWebView editor chrome (per CLAUDE.md "Swift Epdoc
(W7.17 — Tiptap chrome)"):

- **EpdocEditorChromeView.swift** — main editor frame; perf-tuned per
  the 2026-04-29 wave (WKProcessPool pooling, `dismantleNSView`,
  `nonPersistent` data store). Lazy `processPool` reset on memory
  pressure. Already in production-quality state per CLAUDE.md file
  map.
- **EpdocCopilotDockView.swift** — copilot dock.
- **EpdocKaTeXPreview.swift** — KaTeX math preview using a shared
  `WKProcessPool` per the perf wave.
- **EpdocSlashMenuView.swift**, **EpdocBubbleMenuView.swift**,
  **EpdocInsertLinkPicker.swift**, **EpdocBlockContext**, etc. —
  floating Tiptap UI pieces.

P2: zero a11y on every Epdoc surface except the toolbar / complexity
meter. WKWebView accessibility is largely the responsibility of the
embedded JS, but the SwiftUI chrome (slash menu, bubble menu, link
picker) is native SwiftUI and should announce.

### Shared sub-tree (13 files, 3,629 LOC)

Mostly cross-cutting helpers + the recently-audited CognitiveWeightBadge
(iter 5).

- **VoiceInputButton.swift** — macOS 26+ SpeechAnalyzer button per
  the iter-9 ComposerMicButton OS-gate audit. 4 DEBUG-only print()
  calls in `#Preview`.
- **ChatCapabilityPill.swift** — the capability pill referenced by
  RuntimeTruth + ChatInputBar.
- **MarkdownTextView.swift** — shared markdown text view.
- **TypewriterMarkdown.swift** + **TypewriterASCIIRippleText.swift** —
  animated text disclosures. Animated UI must respect "Reduce Motion."
  Worth verifying.
- **ScrollStability.swift** — scroll stability helpers.
- **ReasoningTrajectoryBadge.swift** — reasoning trajectory display.
- **ReadAloudButton.swift** — TTS button.

### Landing tree (6 root + 9 Wave + 9 Farm = 24 files, 7,727 LOC)

- **Wave** sub-tree is the animated Metal-rendered landing-page wave
  (atomic + atlas + choreography + haptics + performance policy).
  Zero a11y throughout — same pattern as MetalGraphView. The landing
  page is the first surface users see; if a VoiceOver user opens the
  app and lands here without an a11y-bridge, they can't navigate to
  the search bar.
- **Farm** sub-tree is the "AI Farm" / companion experience. 3 a11y
  on CompanionView; others zero.

### MiniChat sub-tree (2 files, 2,060 LOC)

- **MiniChatView.swift** (large) — 3 a11y modifiers. Sibling of
  ChatView.
- Worth a dedicated read in a later iter if time permits.

### Cost / Approval / Skills / Vault / Workspace / Journal / Shell

Mostly small single-view sub-trees. CostDashboardView (6 a11y mods)
is the strongest here. Others are functional one-off surfaces;
deferred unless flagged for sub-mission.

### Capture / RawThoughts / Recall / Resonance / Sessions / Onboarding

Mostly small. Recall/ContextualShadowsPanel (4 a11y) is the strongest;
Onboarding/SetupAssistantView (391 LOC) has zero — onboarding is a
high-impact a11y target since first-launch UX defines accessibility
trust.

## Findings summary

### P0 / P1

None.

### P2 — defer (cross-cutting)

- **Onboarding/SetupAssistantView.swift** (391 LOC, zero a11y) — high
  visibility surface; first-launch UX. Worth a dedicated a11y pass
  before broader rollout.
- **Landing/Wave** (Metal-rendered) — same a11y-bridge concern as
  MetalGraphView. Sub-mission scope.
- **Epdoc native chrome** — slash menu, bubble menu, link picker
  lack a11y annotations.
- **Typewriter animations** — verify "Reduce Motion" honored.

### P3 — observations

- **CompanionView in Landing/Farm** has 3 a11y mods — the
  highest-effort a11y in Landing. Good model for the broader
  consistency pass.
- `print()` in VoiceInputButton previews is DEBUG-only ✅.

## Action taken this iter

- Filed this audit doc.
- **No code edits.**

## Pass-1 coverage status — **COMPLETE**

| sub-tree | files | LOC | iter |
|---|---|---|---|
| Settings | 33 | 13,264 | 1, 3, 8, 12 |
| Notes | 43 | 33,941 | 6, 7, 9, 10, 13 |
| Chat | 25 | 10,269 | 9, 10, 14 |
| Graph | 18 | 10,863 | 4 (Halo), 11, 14 |
| Halo | 3 | 648 | 4 |
| Epdoc | 11 | 2,674 | this iter |
| Shared | 13 | 3,629 | 5, this iter |
| Sidebar | 5 | 323 | this iter |
| Landing (incl. Wave + Farm) | 24 | 7,727 | this iter |
| Omega | 6 | 149 | this iter |
| ModelProfiles | 4 | 620 | this iter |
| Onboarding | 2 | 601 | this iter |
| MiniChat | 2 | 2,060 | this iter |
| Capture | 2 | 837 | this iter |
| Sessions | 2 | 440 | this iter |
| Resonance | 2 | 330 | this iter |
| Recall | 2 | 264 | this iter |
| RawThoughts | 2 | 445 | this iter |
| Workspace | 1 | 203 | this iter |
| Vault | 1 | 134 | this iter |
| Skills | 1 | 226 | this iter |
| Journal | 1 | 158 | this iter |
| Cost | 1 | 350 | this iter |
| Approval | 1 | 370 | this iter |
| Shell | 2 | 168 | this iter |
| **Total** | **~206** | **~91k** | full pass-1 coverage |

Plus: `Epistemos/Engine/AmbientFrequency*.swift` (Engine in scope) —
audited iters 1, 2.

**Pass-1 complete.** Deeper per-file deep-reads on the largest files
(NoteDetailWorkspaceView remainder, NotesSidebar, CodeEditorView,
MetalGraphView, etc.) queued for pass-2 if user wants.

## Carry-overs (carry into pass-2)

Single dominant cross-cutting finding: **systemic accessibility gap.**

- ~150 of 209 files have zero explicit a11y annotations.
- Metal-rendered surfaces (MetalGraphView, Landing/Wave) need
  AccessibilityRepresentation bridges.
- A shared `diagnosticsRowAccessibility(...)` modifier could close
  the Settings + Notes + Chat + Graph health-row gap in one PR.
- AnyShapeStyle(Color.X) cleanup across 11 health rows (iter 12 CC-2).
- Onboarding/SetupAssistantView a11y pass (first-launch UX).

All P0/P1 issues currently shipped to main are addressed. The
iter-1 code change (3 P1 fixes + persistence test) is the only
land in this branch.
