# Inline picker cross-reference audit (owner 2026-06-18, REOPENED)

Owner: *"the new inline model picker is MISSING the effort control and the
Fast/Think/Code structure — needs a complete cross reference."* Below: every
control the OLD picker/toolbar exposed, proven present / honestly relocated /
GAP, on ALL 5 surfaces. Surfaces: **MC**=main chat (split toolbar +
InlineRuntimePickerPanel), **LA**=landing, **MI**=mini chat, **NO**=note ask
bar, **GR**=graph sidebar (LA/MI/NO/GR = single-button, `showsSettingsFooter:
true`).

## The old controls (source of truth)
- Split toolbar (MC only, `LocalModelToolbarMenu.splitToolbarControls`): Mode
  button (`modePopover`), Model button (`modelPopover`), Routing button
  (`routingPopover`), Effort button (`effortPopover`, only when
  `supportsRuntimeEffortButton` = cloud model + non-empty tiers), Native Controls
  button (`nativeControlsPopover`, cloud only).
- Single-button picker (LA/MI/NO/GR, `simplifiedRuntimePopover`): depth toggle
  (Chat/Act), `foundationPickerSection` (Fast/Think/Code + per-tier picks), cloud
  toggle, Advanced disclosure (routing, models, cloud setup, Temporary Chat),
  Open Settings. **NOTE: the single-button picker NEVER had an effort control**
  (effort was main-chat-split-toolbar-only).

## Cross-reference table

| Old control | Old location | MC | LA | MI | NO | GR | Status |
|---|---|---|---|---|---|---|---|
| **Fast/Think/Code tier headers** | foundationPickerSection | ✅ panel | ✅ panel | ✅ panel | ✅ panel | ✅ panel | PRESENT — `ForEach(EpistemosModelTier.allCases)` renders each tier section (InlineRuntimePickerPanel.swift:48) |
| **Per-tier model picks** | foundationPickerSection | ✅ panel | ✅ panel | ✅ panel | ✅ panel | ✅ panel | PRESENT — `pickRow` per `EpistemosRuntimePicker.options(for:tier:)` |
| **Pick sets operating mode** | selectRuntimePick | ✅ | ✅ | ✅ | ✅ | ✅ | PRESENT — `operatingModeForTier` (fast→.fast, think→.thinking, code→.pro) on select |
| **Honest install/memory gate** | foundationPickerSection | ✅ | ✅ | ✅ | ✅ | ✅ | PRESENT — `option.isSelectable`/`blockedReason`, blocked → Settings |
| **Effort (Low/Med/High/Heavy)** | effortPopover (MC split toolbar) | ⮕ split-toolbar effort button (cloud) | ❌→✅ | ❌→✅ | ❌→✅ | ❌→✅ | MC: relocated to the split-toolbar effort button (unchanged). LA/MI/NO/GR: never had it; **ADDED to the panel this slice** (shown when `availableReasoningTiers(for: mode)` non-empty = Think/Code/Act). |
| **Mode / Chat·Act depth** | depthToggle (single) / mode button (MC) | ⮕ split-toolbar mode button | ✅→ | ✅→ | ✅→ | ✅→ | MC: split-toolbar mode button (unchanged). LA/MI/NO/GR: tier picks set Fast/Think/Code; **ADDED a Chat/Act MODE toggle to the panel this slice** (CoworkChatMode, honest Act-availability gating with the real reason when no agent route). ACT now reachable. |
| **Routing** | routingPopover / Advanced | ⮕ split-toolbar routing button | ⮕ Settings | ⮕ Settings | ⮕ Settings | ⮕ Settings | MC: split-toolbar button. Single: relocated to the panel's "Cloud, routing & model details — Settings" footer. |
| **Cloud toggle** | cloudToggleSection | ⮕ split toolbar / Settings | ⮕ Settings | ⮕ Settings | ⮕ Settings | ⮕ Settings | Relocated to Settings footer (single) / split toolbar (MC). |
| **Native controls** | nativeControlsPopover (cloud) | ⮕ split-toolbar native button | ⮕ Settings | ⮕ Settings | ⮕ Settings | ⮕ Settings | MC: split-toolbar button. Single: Settings footer. |
| **Agents (Companion switch)** | agentSwitcherSection (modelPopover) | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ | GAP — the in-chat agent switcher (activate a Companion) is not in the panel. Follow-up (Companion activation lives in the Landing farm + is a separate surface; relocate honestly or add). |
| **Temporary Chat** | Advanced disclosure | ⮕ split toolbar / Settings | ⮕ Settings | ⮕ Settings | ⮕ Settings | ⮕ Settings | Relocated. |

## This slice (2026-06-18)
- **FIXED — Effort**: added an EFFORT section to InlineRuntimePickerPanel (shown
  when `showsSettingsFooter` and `availableReasoningTiers(for: mode)` is
  non-empty), so LA/MI/NO/GR now have the Low/Medium/High/Heavy reasoning-effort
  control for Think/Code/Act — at parity with the main-chat split-toolbar effort
  button (Fast correctly shows none — `availableReasoningTiers(.fast) == []`).
- **VERIFIED — Fast/Think/Code**: present on all 5 surfaces (tier headers + picks
  render; selecting sets the tier's operating mode + pins the model). Owner
  build+runs to confirm they render + switch behavior in-app.

## Second slice (2026-06-18) — ACT toggle
- **FIXED — Mode/Chat·Act**: added a MODE (Chat/Act) toggle to the panel
  (CoworkChatMode), so LA/MI/NO/GR can reach Act again. Act is disabled with the
  honest `actUnavailableReason` when no agent route exists (never fakes agent
  capability for a local model).

## Documented follow-up GAPS (next slices)
1. **Agent (Companion) switcher** not in the panel — relocate honestly (Companion
   activation also lives in the Landing farm).
2. **Fold MC split-toolbar buttons into the panel** (owner-flagged optional) —
   if confirmed, hide the MC mode/routing/effort/native buttons + surface all in
   the panel, removing the split toolbar.

## Net status after both slices
Fast/Think/Code (+ per-tier picks) ✅ all 5 · Effort ✅ all 5 (MC split toolbar;
LA/MI/NO/GR panel) · Mode/Chat·Act ✅ all 5 · Routing/Cloud/Native/Temporary →
Settings footer (single) / split toolbar (MC) · Companion switcher = open
follow-up. Owner build+runs to confirm effort + Fast/Think/Code + Act render +
switch in-app.
