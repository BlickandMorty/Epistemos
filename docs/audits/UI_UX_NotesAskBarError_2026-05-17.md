# UI/UX Audit — Notes ask-bar runtime error surface

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 6)
- **Driver**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.C —
  recursive audit of UI in the 14-day window.
- **Trigger commit**: `af78d5f3a` (2026-05-14) — *fix(notes): surface ask
  bar runtime errors*.
- **Surfaces under audit**:
  - `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift:1837-1916` (ask-bar
    composition + `toolbarAskPlaceholder` computed property)
  - `Epistemos/State/NoteChatState.swift:60` (`var error: String?`),
    `:280` (clear on submit), `:378` (set on streaming catch), `:819`
    (clear on reset)
- **Verification mode**: Static. Env constraints from iter 1 still apply.

## What this fix does

Before `af78d5f3a`, the ask-bar's placeholder was a hardcoded "Ask this
note". Streaming failures set `NoteChatState.error` (line 378) but no
view rendered it — runtime errors were silently lost to the log.

The fix introduces `toolbarAskPlaceholder` (NoteDetailWorkspaceView.swift:1840-1842):

```swift
private var toolbarAskPlaceholder: String {
    noteChatState.error ?? "Ask this note"
}
```

So the ask-bar's placeholder now reads the error when present, falling
back to the default when not.

This is an additive, low-risk first cut at error surfacing.

## Findings

### P0 — blockers

None.

### P1 — must-fix

None at the regression / blast-radius bar. The fix is an improvement
over the previous "silently lost" state. The placeholder-as-error
pattern has UX limitations (P2-1 below) but is honest about its
constraints.

### P2 — defer

**P2-1 — Placeholder-as-error has three known limitations.**

1. **Disappears the moment the user types.** SwiftUI text-field
   placeholders only render while `text.isEmpty == true`. As soon as
   the user starts typing in the ask bar, the error placeholder
   vanishes — though `noteChatState.error` is still set in state. The
   user has to clear the field to see the error again.

2. **Looks like a hint, not an error.** Placeholders inherit
   `.tertiary` / `.placeholder` foreground, the same dim treatment
   used for "Ask this note" suggestions. No red/orange tint, no
   warning glyph, no badge. A user glancing at the bar can easily
   mis-read the error as a prompt.

3. **VoiceOver only announces on focus.** Placeholder text is read
   when the field receives focus. If the field is already focused at
   the moment of error (a streaming failure mid-typing), VoiceOver
   does not re-announce the placeholder change.

   These are general macOS text-field constraints, not bugs in the
   fix — but worth recording.

- **Fix sketch**: render a dedicated error indicator (small `Label`
  with `exclamationmark.triangle.fill` + the error string, tinted
  red/orange) below or beside the ask bar when
  `noteChatState.error != nil`. The bar's `AssistantToolbarAskBar`
  initializer would need a new optional `errorMessage:` parameter.
  Deferred because (a) the ask bar is rendered inside a toolbar
  context with tight vertical budget, (b) the additive change spans
  the AssistantToolbarAskBar component itself (outside the trigger
  commit's scope), and (c) xcodebuild verification is blocked on the
  pre-existing `ContradictionFfi` main-broken state — I don't want to
  ship a layout change without a clean build.

**P2-2 — Error clears on next submit but not on input edit.**

`NoteChatState.error` is cleared at line 280 (on `submitQuery`) and
line 819 (on reset). If the user reads the error in the placeholder,
deletes their input, and pauses, the error placeholder reappears.
That's actually a defensible UX choice — the user can re-read the
error before retrying. No fix needed; record this for later UX
iteration if a dedicated error surface lands.

### P3 — observations

- **P3-1** — `UserFacingChatError.message(from:)` at line 377 is the
  user-visible error formatter. Verify this strips raw exception
  text / provider-internal codes; if it leaks anything sensitive
  (e.g., API key prefixes, tunnel URLs), it would now reach the ask
  bar UI. Out of scope for this iter; flag for a security-review
  pass.

- **P3-2** — The fix doesn't add a test. `NoteEditorLayoutTests.swift`
  was modified in the trigger commit (per `git show --stat`); worth
  reading to see if the placeholder behavior is now pinned. Brief
  check at the file showed +4/-1 lines — a layout test, not an error
  behavior test. Test coverage gap.

## Action taken this iter

- Filed this audit doc.
- **No code edits** — the placeholder-as-error pattern is an
  intentional incremental shipping move; refining it requires editing
  `AssistantToolbarAskBar` (a shared component) and committing a
  layout change without xcodebuild verification. Deferred per
  conservative-edit policy.

## Carry-overs

- P2-1 dedicated error indicator pattern (label + glyph + tint below
  ask bar) — propose under a dedicated UI iter or after the
  `ContradictionFfi` main-broken state clears.
- P3-1 audit `UserFacingChatError.message(from:)` for sensitive-info
  leakage to UI surfaces.
- P3-2 add a `NoteChatState.error` lifecycle test (set on catch,
  cleared on submit, reset path, etc.).
