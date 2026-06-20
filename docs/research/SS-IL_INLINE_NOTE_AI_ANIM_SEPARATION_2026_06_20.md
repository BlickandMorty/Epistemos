# SS-IL — Inline note-AI ("Ask this note"): KEEP inline streaming + send animation + pixel-art scroll-down arrow + AI/user separation (2026-06-20)

Owner: *"Keep the inline streaming of the 'Ask this note' AI feature — when I'm on the Prose editor and ask the AI
something I still want it to reply inline; that inline feature is very good, robust, KEEP it. But add an animation: when
you send a query the bar can do an animation, and there can be a large pixel-art arrow that pops up over the note pointing
down + a pixel-art phrase like 'scroll down to see answer' / 'scroll down for AI'. Then you scroll down and see the answer,
separated — maybe in a 'cold box' or some box obviously written by AI. There should be separation so the user doesn't get
confused about what's theirs vs the AI's. Make that robust WITHOUT losing the inline feature."* Code-grounded, NON-INVASIVE
(additive UI over the existing note-chat; never alters TK2/Prose text internals).

## Current state (file:line)
The inline "Ask this note" feature is `NoteChatState` (`Epistemos/State/NoteChatState.swift`), driven from
`NoteDetailWorkspaceView.swift`: composer + placeholder "Ask this note" (`:2072`), `submitQuery(...)` (`:1778`),
`isStreaming` with persistence on stream-end (`:1074-1076`), toolbar status phase (`:2061`), env-injected into the editor
(`:1015`, `:1374`). It streams a reply tied to the page. So the inline streaming pipeline EXISTS and works — this slice is
purely ADDITIVE chrome + clearer separation; do NOT refactor the streaming path.

## What to build (additive, pixel-art, 120 Hz)
1. **Send animation on the bar [S].** On `submitQuery`, animate the composer/ask-bar (e.g. a pixel-art pulse / scanline /
   "sending" shimmer) keyed off `isStreaming` true→false. Reuse existing animation tokens (cross-ref SS-ALIVE) so it feels
   cohesive; no jank, respects reduce-motion.
2. **Pixel-art "scroll down for the answer" affordance [S→M].** When an answer arrives BELOW the current viewport (i.e. the
   freshly-streamed AI block is off-screen), show a large animated pixel-art DOWN arrow overlaid on the note + a pixel-art
   phrase ("scroll down to see answer" / "scroll for AI"). It bobs/pulses, is dismissible, and auto-hides once the answer
   block scrolls into view (observe scroll offset vs the answer block's frame). Non-blocking overlay (`.overlay`), never
   covers the caret/active edit region. Only shows when the answer is actually below the fold — if the answer is already
   visible, skip the arrow.
3. **Separated AI answer box ("obviously AI") [M].** Render the AI answer in a visually distinct, clearly-AI container —
   a "cold box": different surface tint (use the theme's AI/assistant token, NOT the note body color), a pixel-art AI
   glyph/label ("AI"), a subtle border/wash, and clear top/bottom delimiters so it reads as separate from the user's prose.
   This kills the "is this mine or the AI's?" confusion. The box is non-editable-as-prose (it's a response artifact), with
   actions (copy / insert-into-note / dismiss) so the user EXPLICITLY chooses to merge AI text into their content — nothing
   silently becomes part of the note body. Cross-ref SS-2S (AI/user separation is the same anti-confusion principle as the
   cross-surface caveat) + SS-TC (the AI box gets its own color slot; coordinate with the granular-color work).
4. **Robustness / keep-inline contract.** The inline streaming stays exactly as-is functionally; this is overlay + container
   styling only. Persisted note-chat messages (`NoteChatState.persistMessages`) unchanged. No regression to streaming
   latency. Reduce-motion + accessibility labels on the arrow/box.

## Notes
- The "cold box" separation also future-proofs the two-surface story (SS-2S): an AI answer is a distinct, attributable
  block, so if a note later opens in Epdoc it can become a typed/attributed block rather than ambiguous inline text.
- Tests: behavior/render — (a) arrow shows only when the answer block is below the viewport and hides when scrolled to;
  (b) AI answer renders in the distinct container with the AI label; (c) inline streaming still completes + persists
  unchanged (no-regression guard).
Order [S→M], NON-INVASIVE; single targeted swift build. Cross-ref SS-ALIVE, SS-TC, SS-2S, SS-CLEAN (one answer-container
component, not cloned per surface).
