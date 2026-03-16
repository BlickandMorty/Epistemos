# Control System Audit — 2026-03-15

Scope: recursive audit of user-visible control families in the macOS app, normalized by repeated control family rather than listing every identical menu row separately.

## CONTROL_INVENTORY

| File | Control Name | Current Implementation | Category | Recommended Replacement | Risk | Performance Concerns | ASCII |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Epistemos/App/RootView.swift` | Chat history toolbar control | `AnchoredPopoverButton` | D | Keep anchored popover; shared toolbar disclosure grammar is correct | Low | Popover content stays isolated from main body layout | No |
| `Epistemos/App/RootView.swift` | Home / Library / Settings switcher | segmented `Picker` | C | Preserve native segmented control | Low | None | No |
| `Epistemos/App/RootView.swift` | Active model / provider selector | `Menu` | D | Preserve native menu; no inline toggles | Low | Menu is lazily realized by AppKit | No |
| `Epistemos/Views/Chat/ChatView.swift` | Research control cluster | `ExpandingModeButton` + `AnchoredPopoverButton` | D | Implemented; primary arm button plus anchored options popover | Medium | Stable width slot avoids toolbar jitter; local phase task only | Yes |
| `Epistemos/Views/Chat/ChatView.swift` | Export chat | `Button` | A | Preserve button | Low | None | No |
| `Epistemos/Views/Chat/ChatInputBar.swift` | Incognito mode | `ExpandingModeButton` | B | Implemented; persistent session state should read as selected mode button | Low | Stable width slot; no parent-wide invalidation | No |
| `Epistemos/Views/Chat/ChatInputBar.swift` | Attach / send / stop | buttons | A | Preserve buttons | Low | None | No |
| `Epistemos/Views/Chat/ChatSidebarView.swift` | Chat filters | `ModeChipGroup` | C | Implemented; mutually exclusive filter chips | Low | Selection state local to sidebar | No |
| `Epistemos/Views/Landing/LandingView.swift` | Landing research control | `ResearchModeControl` | D | Implemented; same grammar as chat toolbar | Low | Stable width slot in composer toolbar | Yes |
| `Epistemos/Views/Landing/LandingView.swift` | Provider selector | `Menu` pill | D | Preserve menu semantics; restyle only if moved into shared disclosure shell later | Low | Menu does not invalidate landing body | No |
| `Epistemos/Views/Landing/LandingView.swift` | Quick action chips | capsule buttons | A | Preserve buttons; continue to align density with toolbar capsules in future pass | Low | Static controls | No |
| `Epistemos/Views/Landing/CommandPaletteOverlay.swift` | Palette research control | `ResearchModeControl` | D | Implemented; matches landing and chat | Low | Stable slot; no global recompute | Yes |
| `Epistemos/Views/Landing/CommandPaletteOverlay.swift` | Palette incognito | `ExpandingModeButton` | B | Implemented; selected mode grammar | Low | Stable slot; local hover state only | No |
| `Epistemos/Views/Graph/GraphFloatingControls.swift` | Semantic clustering | `ExpandingModeButton` | B | Implemented; selected mode button with ASCII arm/active badge | Medium | Stable slot; mutation stays in `GraphState` only on click | Yes |
| `Epistemos/Views/Graph/GraphFloatingControls.swift` | Freeze / Resume physics | `ExpandingModeButton` | B | Implemented; binary tool state with explicit selected grammar | Medium | Stable slot; no hover-driven model writes | Yes |
| `Epistemos/Views/Graph/GraphFloatingControls.swift` | Force settings | `AnchoredPopoverButton` | D | Implemented; attached settings popover is the correct desktop pattern | Low | Popover content stays off hot render path until opened | No |
| `Epistemos/Views/Graph/GraphFloatingControls.swift` | Minimize / reset / rebuild / close | `ToolbarCapsuleButton` | A | Implemented; shared compact utility button grammar | Low | None | No |
| `Epistemos/Views/Graph/GraphFloatingControls.swift` | Node type filters | custom `FilterPill` buttons | B | Preserve for now; later migrate to shared multiselect chip if a second consumer appears | Medium | Repeated pills in overlay; cheap but custom | No |
| `Epistemos/Views/Graph/HologramSearchSidebar.swift` | Notes / Query tabs | `ModeChipGroup` | C | Implemented; shared mode chips | Low | Local selection only | No |
| `Epistemos/Views/Graph/GraphForceSettings.swift` | Performance Mode | native `Toggle(.switch)` | B | Preserve toggle; true persistent rendering preference | Low | Form-only state | No |
| `Epistemos/Views/Graph/GraphForceSettings.swift` | Physics presets | custom preset button grid | C | Next pass: shared mode-chip grid or segmented-adjacent preset row | Medium | Grid redraw is cheap; no urgent churn | No |
| `Epistemos/Views/Graph/GraphForceSettings.swift` | Advanced / Experimental disclosure | inline disclosure buttons | D | Preserve as disclosure buttons; optionally wrap in shared disclosure style later | Low | Section expansion only local | No |
| `Epistemos/Views/Graph/GraphForceSettings.swift` | Laboratory feature toggles | native `Toggle(.switch)` | B | Preserve toggles; these are real persistent booleans | Low | Form-only state | No |
| `Epistemos/Views/Graph/HologramNodeInspector.swift` | Profile / Editor inspector mode | segmented `Picker` | C | Preserve native segmented control | Low | None | No |
| `Epistemos/Views/Graph/HologramNodeInspector.swift` | Raw / Formatted editor display | custom pill buttons | C | Next pass: move to `ModeChipGroup` | Medium | Local state only | Selective |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Preview / Editor mode | `ExpandingModeButton` | C | Implemented; two-state mode tool with stable slot | Medium | Stable width avoids toolbar strip snapping | Yes |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Backlinks | `AnchoredPopoverButton` | D | Implemented; anchored popover is correct semantic form | Low | Popover content only built when opened | No |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Chat history | `AnchoredPopoverButton` | D | Implemented; replaces raw hide/show toggle feel | Low | Fixed popover width avoids resize churn | No |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Format / More menus | `Menu` | D | Preserve menu grammar; no inline clutter | Low | Lazy menu content | No |
| `Epistemos/Views/Notes/NotesSidebar.swift` | Vault connection | `Menu` icon button | D | Preserve menu semantics; future pass can wrap in shared disclosure shell | Low | None | No |
| `Epistemos/Views/Notes/NotesSidebar.swift` | Dirty changes panel trigger | icon button + `.popover` | D | Next pass: swap to `AnchoredPopoverButton` if promoted into top control family | Low | Popover already isolated | No |
| `Epistemos/Views/Notes/NotesSidebar.swift` | Sidebar utility icons | icon buttons | A | Preserve buttons; unify metrics only if promoted into shared primitive later | Low | Hot path in sidebar rows should stay simple | No |
| `Epistemos/Views/Settings/SettingsView.swift` | Display mode / SOAR / output token preferences | native `Toggle` / checkbox | B | Preserve toggles; these are true persistent preferences | Low | Form-only state | No |
| `Epistemos/Views/Settings/SettingsView.swift` | Provider / theme / format selectors | `Picker` | C | Preserve native pickers | Low | None | No |
| `Epistemos/Views/Library/LibraryView.swift` | Favorite / remove / citation actions | buttons + context menus | A/B | Preserve semantics; future pass should only normalize row button styling | Medium | Avoid row-level hover state that invalidates full lists | No |
| `Epistemos/Views/MiniChat/MiniChatView.swift` | Mini chat utility controls | mixed icon buttons | A | Future pass: map onto `ToolbarCapsuleButton` where space permits | Medium | Compact window makes width reservation tighter | No |
| `Epistemos/Views/Notes/DiffSheetView.swift` | Compare mode switch | segmented `Picker` | C | Preserve segmented control | Low | None | No |
| `Epistemos/App/EpistemosApp.swift` | Menu bar / command menu actions | native `Button` menu items | A | Preserve native command grammar | Low | System-owned | No |

## CONTROL_SYSTEM_SPEC

### Metrics

| Token | Toolbar | Content |
| --- | --- | --- |
| Height | `28pt` | `32pt` |
| Corner radius | `10pt` | `12pt` |
| Horizontal padding | `8...10pt` | `10...12pt` |
| Icon size | `13pt` | `14pt` |
| Label spacing | `6pt` | `6pt` |
| Font | `13pt semibold` | `13pt semibold` |
| Min hit target | `28x28pt` | `32x32pt` |
| Max label reserve | `92pt` | `104pt` |
| Popover width | `220...300pt` | `240...340pt` |

### Button hierarchy

- `Primary action`: strongest filled accent tint, reserved for destructive-absent commit actions.
- `Toolbar utility`: compact icon or icon+label capsule for immediate actions.
- `Mode chip`: mutually exclusive selection grammar with stable selected state.
- `Secondary ghost`: low-emphasis utility capsule for explanatory or support actions.
- `Inline disclosure`: anchored popover/menu launcher with chevron affordance.

### Interaction behavior

| Behavior | Spec |
| --- | --- |
| Hover | `0.12s` ease; subtle flat fill increase. Expanding controls may reveal label on hover. |
| Press | `0.08s` ease; scale to `0.988`, slightly denser fill. |
| Selection / active | `0.18s` ease; accent-tinted soft fill, restrained stroke, selected accessibility trait. |
| Expansion | `0.18s` ease; no spring. Stable width slots are reserved at callsites where toolbar jitter matters. |
| Popover open | `0.16s` ease; attached at `.bottom` with top arrow for toolbar usage. |
| Disabled | opacity `0.48`, tertiary foreground, no custom hover emphasis. |
| ASCII frame cadence | `45ms` per frame; deterministic width, monospaced rendering. |
| Reduced motion | ASCII badges fall back to static frames; no continuous hover animation requirements. |

### ASCII motion rules

- Apply only to mode activation, arming, active, and cooling transitions.
- Never apply ASCII churn to every hover.
- Frames are precomputed and width-padded in `ASCIIControlAnimationSet`.
- Badge width is fixed (`7` chars for toolbar status set) to prevent text jitter.
- Animation state is local to the control, not published into shared app state.

### Toolbar vs content variants

- Toolbar controls stay compact, frequently icon-first, and should reserve width only when adjacent layout sensitivity requires it.
- Content controls may show labels by default, use slightly taller metrics, and tolerate broader horizontal padding.
- Native toggles are allowed only in settings/forms or true persistent graph preference rows.

## File-by-file patch plan

### Implemented in this pass

- `Epistemos/Theme/NativeButtonStyles.swift`
  - Added shared control tokens and primitives: `ToolbarCapsuleButton`, `ExpandingModeButton`, `ModeChipGroup`, `AnchoredPopoverButton`, `NativeToolbarToggle`.
  - Added stable-width helpers so toolbar groups can reserve layout without widening every capsule globally.
- `Epistemos/Theme/PhysicsModifiers.swift`
  - Added reusable ASCII control state layer: `ASCIIControlPhase`, `ASCIIControlAnimationSet`, `ASCIIStateBadge`, `ASCIITransitionLabel`.
- `Epistemos/State/ChatState.swift`
  - Added `ChatQueryMode` bridge so research mode reads as explicit semantic state instead of a stray boolean.
- `Epistemos/Views/Chat/ChatView.swift`
  - Replaced research toggle/hint behavior with unified research control cluster plus anchored popover.
- `Epistemos/Views/Chat/ChatInputBar.swift`
  - Replaced incognito icon toggle with shared expanding mode control.
- `Epistemos/Views/Chat/ChatSidebarView.swift`
  - Replaced ad hoc dual filters with `ModeChipGroup`.
- `Epistemos/Views/Landing/LandingView.swift`
  - Reused `ResearchModeControl` in landing search composer.
  - Replaced the single-line landing `TextField` with a multiline growing composer and a dedicated second control row.
- `Epistemos/Views/Landing/CommandPaletteOverlay.swift`
  - Reused `ResearchModeControl`; replaced incognito with shared expanding mode control.
- `Epistemos/Views/Graph/GraphFloatingControls.swift`
  - Replaced semantic / freeze toggles with expanding mode controls.
  - Replaced force settings with anchored popover.
  - Replaced utility icons with shared capsule buttons.
- `Epistemos/Views/Graph/HologramSearchSidebar.swift`
  - Replaced custom tab pills with `ModeChipGroup`.
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`
  - Replaced preview mode icon toggle and backlinks/chat history icons with shared control family.
- `Epistemos/App/RootView.swift`
  - Replaced chat history trigger with anchored toolbar popover control.
- `EpistemosTests/ThemePairTests.swift`
  - Added control-system tests for tokens, ASCII widths, sidebar mode semantics, and chat query mode bridge.

### Deferred to the next control pass

- `Epistemos/Views/Graph/GraphForceSettings.swift`
  - Migrate preset grid and disclosure rows into the shared control family without disturbing slider density.
- `Epistemos/Views/Graph/HologramNodeInspector.swift`
  - Replace raw/formatted custom pills with `ModeChipGroup`.
- `Epistemos/Views/Notes/NotesSidebar.swift`
  - Optionally promote the dirty-changes trigger to `AnchoredPopoverButton` if it becomes part of the top interaction family.
- `Epistemos/Views/MiniChat/MiniChatView.swift`
  - Align utility icons with the new toolbar capsule metrics if compact-window ergonomics stay intact.
- `Epistemos/Views/Library/LibraryView.swift`
  - Normalize row action styling only after verifying no list performance regression.

## Intentionally preserved toggle semantics

- `Epistemos/Views/Settings/SettingsView.swift`
  - `Regular Mode`
  - `SOAR Engine`
  - `Auto-detect Edge of Learnability`
  - `Adaptive Thresholds`
  - `Verbose Logging`
  - `Limit output tokens` checkbox
- `Epistemos/Views/Graph/GraphForceSettings.swift`
  - `Performance Mode`
  - laboratory feature switches such as `Fluid Wake Physics`, `Crystalline Angular Tension`, `Orbital Hierarchies`

Reason: these are actual persistent booleans with clear on/off meaning, not contextual tool arming states.

## Performance notes

- Hover and press state stays local to the control primitives; no shared observable hover model was introduced.
- ASCII badge frames are precomputed and padded once, so runtime animation does not allocate variable-width strings.
- ASCII control animation uses deterministic short frame sets instead of per-frame generated text.
- Popover content stays lazy behind `popover(isPresented:)`; large surfaces such as chat history and graph forces are not created until opened.
- Stable width reservation is applied at the callsite wrapper level for the few toolbars that needed it, rather than globally widening every shared control.
- No `AnyView` erasure was introduced in hot control paths.
- Business state changes still occur only on semantic actions, not on hover or press.

## Before vs after summary

- Research controls
  - Before: mixed flask toggles and inline explanatory clutter.
  - After: icon-first arm button plus anchored options popover, shared across chat, landing, and command palette.
- Landing composer
  - Before: single-line search field with controls competing on the same line.
  - After: a growing multiline composer with the prompt row above a softer secondary control row, aligned to the main chat grammar.
- Chat and palette state controls
  - Before: ad hoc pills and icon toggles with inconsistent selected-state language.
  - After: explicit mode chips for mutually exclusive filters and expanding mode buttons for persistent tool states.
- Graph overlay controls
  - Before: mixed prototype pills, raw toggles, and detached settings behavior.
  - After: one compact toolbar family with selected capsules, anchored settings, and restrained utility buttons.
- Note toolbar controls
  - Before: one-off icon controls with uneven state disclosure.
  - After: preview mode, backlinks, and chat history all use the same desktop control grammar.
- Root toolbar history
  - Before: plain toolbar button with custom-feeling popover behavior.
  - After: shared anchored disclosure control consistent with the rest of the app.
