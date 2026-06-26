# Transition And Model Picker IP Ledger - 2026-06-24

This ledger is an additive preservation lock for the full-clone/native-infusion
overhaul. It prevents the implementation loop from pruning the owner's best
Epistemos interaction IP while replacing Osaurus and donor chrome.

## Non-Prunable Interaction IP

Preserve these as first-class product behaviors:

- The blur reveal when moving from landing/search into the main chat surface.
- The typewriter/ASCII reveal that appears during the same transition.
- The combined blur + typewriter/ASCII moment, not one animation replacing the
  other.
- The equivalent reveal behavior when entering a chat view from another chat
  surface, including main chat, Act chat, mini chat, graph chat, and note chat
  where that transition exists.
- Click-anywhere-to-search as the entry gesture that leads into the reveal.
- Click-to-start-a-conversation as a preserved landing interaction primitive,
  rebuilt for the new app rather than restored from the old chat implementation.
- The search page as a real visible mode before the main chat opens.
- Landing-page mode toggles are allowed and likely useful: the user may switch
  between search/start-conversation/work/act style entry modes from landing, as
  long as the interaction still feels like Epistemos and does not become raw
  donor chrome.
- The model picker as a visible, useful, owner-style control.

## Landing Entry Preservation

The old landing interaction worked because the user could click into the page
and feel the app become a conversation, with a reveal into the search/chat
state. Preserve that product feeling without restoring the old chat surface.

Implementation guidance:

- Rebuild the interaction as a new landing entry state.
- Keep click-anywhere-to-search where it feels natural.
- Keep click-to-start-conversation as an available path, but make it route into
  the new Work/Act/chat surfaces rather than the retired old chat.
- Consider landing toggles or segmented controls for entry intent, such as
  Search, Act, Work, or Mini, if that makes the new architecture easier to
  understand.
- The toggle/control design should be compact and owner-style, not a donor app
  navigation bar.
- The reveal should connect to real routing state, selected model, and selected
  mode.

## Model Picker Preservation

The model picker must remain part of the owner UI language during Work and Act
replacement. It should not be hidden behind raw donor settings, command text, or
TUI-only controls.

Minimum preserved behavior:

- shows the currently selected model,
- can switch supported local/cloud/donor-backed models,
- stays connected to Work and Act runtime selection,
- remains available in the compact chat/input chrome where it previously felt
  good,
- can grow sections for OpenCode/OpenWork and native Swift-agent models without
  losing the Epistemos visual style.

## Regression Definitions

These are regressions:

- replacing the blur + typewriter/ASCII transition with a plain fade,
- keeping only blur or only typewriter/ASCII when the old interaction had both,
- making landing/search jump directly into chat with no reveal,
- preserving only the old implementation while losing the click-to-start
  product feeling in the new app,
- adding landing toggles that bypass the reveal or route to the wrong engine,
- removing the model picker because a donor app has its own settings screen,
- hiding model switching in slash commands only,
- using raw Osaurus/OpenWork/OpenChamber model UI instead of rehoming it into
  the Epistemos picker,
- preserving the animation as a decorative splash but disconnecting it from the
  real state transition.

## Verification Requirement

Any implementation claim that touches landing/search/chat transition or model
selection must include:

- code references for the transition and model picker paths,
- fresh runtime visual evidence, ideally a short screen recording or sequential
  screenshots for the animation states,
- proof that the selected model shown in the picker is the model used by the
  actual Work or Act request,
- proof that mini/main/graph/note chat entry points do not bypass the intended
  reveal unless intentionally documented.
- proof that landing entry toggles, if implemented, route to the selected
  Work/Act/search/chat mode and do not resurrect the old chat implementation.

This ledger is referenced by
`docs/handoffs/AUTHORITATIVE_FULL_CLONE_NATIVE_INFUSION_PLAN_2026_06_24.md` and
the Claude implementation prompt.
