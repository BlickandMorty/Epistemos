# Command Palette Redesign — Typewriter-as-Placeholder

## Goal

Transform the command palette from a compact search bar into a mini landing page. The typewriter greeting animates directly inside the search field as an animated placeholder. On first keypress it fast-retracts, the real input takes over, and action chips dissolve. Clearing back to empty restores the typewriter.

## Architecture

Two visual states sharing a single search bar container:

**Idle** (searchText empty, no pending input):
- Typewriter animates inside the search bar area (compact LiquidGreeting, ~22pt RetroGaming font)
- Action chips visible below: New Note, Quick Idea, Vault Briefing, Daily Brief
- Real TextField is present but invisible (opacity 0) — ready to capture keystrokes

**Active** (searchText non-empty or retract in progress):
- Typewriter receives "retract now" signal → fast-deletes at ~15ms/char (3x normal speed)
- Once typewriter text is empty, it hides and real TextField becomes visible with the captured keystroke
- Action chips blur-dissolve out
- Results list appears below (existing behavior)

**Return to idle** (searchText cleared back to empty):
- TextField hides, typewriter resumes cycling
- Chips fade back in

## Components

### LiquidGreeting changes
- Add `compact: Bool` parameter (default false)
- Compact mode: 22pt font instead of 44pt, no minHeight constraint
- Add `retractNow` binding: when set to true, immediately fast-delete current text at 15ms/char, then call a completion
- After retract completes, pause animation until `retractNow` is reset to false

### CommandPaletteOverlay changes
- Width: 640px (up from 520px)
- Idle state: ZStack with LiquidGreeting (compact) + hidden TextField in the search bar area
- On keypress: set `retractNow = true`, buffer the keystroke
- After retract completes: show TextField, insert buffered keystroke, focus it
- Clear-to-empty: hide TextField, reset `retractNow = false`, typewriter resumes
- Add chip row below search bar (dissolves with blurReplace on active state)
- Chips: New Note, Quick Idea, Vault Briefing, Daily Brief (reuse landingChip style from LandingView)

### CommandPaletteWindowController changes
- Panel initial contentRect width: 600 → 720 (includes 40px shadow padding each side)
- Panel minSize: 520×80 → 600×80
- Panel maxSize: 680×780 → 740×780

## Files to modify

| File | Change |
|------|--------|
| `Epistemos/Views/Landing/LiquidGreeting.swift` | Add `compact` mode + `retractNow` binding |
| `Epistemos/Views/Landing/CommandPaletteOverlay.swift` | Wider frame, typewriter-as-placeholder, action chips, dissolve transitions |
| `Epistemos/Views/Landing/CommandPaletteWindowController.swift` | Bump panel dimensions |

No new files.
