# SS-FOLLOWON — Next-increment backlog harvested from loop commit bodies (2026-06-20)

Owner: *"I want things like this [Epdoc mini-chat noted as a possible further increment] and beyond to be
added to the plan — if there are more suggestions like this, make sure they will be in the plan."* So every
"honest pending / next increment / deferred / not-faked" note a loop commit makes must be CAPTURED here +
in the ledger as an open `[ ]` item — not left to rot in git history. These are real, owner-wanted follow-ons
(the loop deferred them as safe-increments per NO-RISK-DEFERRAL, not as owner-gates). Harvested 2026-06-20.

## Captured follow-ons (each is an open ledger item; build them — do not drop)
- **SS-VIS — Epdoc/code mini-chat capability panel** (558bea540): mount the SAME `AgentToolTogglePanel` on the
  Epdoc/code editor mini-chat composer — the last sweep surface. Verify its env-injection first (no crash).
- **SS-VIS — start-with-a-tool / cowork-mode handoff** (735940b7a): an explicit handoff that flips operating
  mode = act before `submitLandingSearch()`, so "start off using a tool/cowork" actually enters the mode.
- **SS-VIS — cowork-panel parity** (735940b7a): cowork surface reaches the same parity as tools across surfaces.
- **SS-GE (A) — document-node INLINE edit (no detached utility)** (9573a79fa): `.document`/.epdoc + `.proseNote`
  nodes still bounce to the detached utility window; owner wants to EDIT all surfaces inline in BOTH graphs
  (tunnel + embedded/mini overlay) with NO detached utility. The risky core of SS-GE (A) — still open.
- **SS-GE (C) — Metal-renderer new appearance control + Laboratory-toggle discoverability** (68077ed69): wire a
  NEW appearance control through the Metal renderer + a discoverability pass to surface the Laboratory toggles.
- **SS-2S — visible-render default-ON flip** (888761277): `EPISTEMOS_PROSE_INLINE_IMAGE_V0` is default-OFF; after
  geometry tuning + the async/remote increment, flip it default-on so the owner SEES images without a flag.
- **SS-2S — async + downsampled + remote image load** (888761277): replace the sync first-draw load with an
  async + downsampled load via `NoteImageProcessor.loadDisplayImage` + remote `http(s)` support (needs solving
  the non-Sendable layout-state-across-actors issue — deferred, not faked).
- **SS-LT — full-path runtime hardening** (ce66a8d64): beyond the prompt-affordance fix, harden parse robustness
  + tier surfacing + Eidos readiness across the live local multi-tool path (the parts that were owner-verified).
- **SUBSTRATE — RuntimeRouter LIVE authoritative flip** (5a3943454): once `parityRate` is solid, consume the
  STAGE-2 selection contract at the `compile()` marker site (flip `EPISTEMOS_RUNTIMEROUTER_LIVE_V0`) so the
  router lane becomes authoritative live. Parity-gated; the contract + tests already landed.

## Standing rule (added to SS-CLEAN)
Every loop commit that writes an "honest pending / next increment / deferred / not-faked / owner-flip" note
must have that note captured as an open `[ ]` ledger item (+ here) in the SAME or the next monitor pass — so
no deferred-but-real work is lost to git history. The last-auditor harvests these each fire. Cross-ref
SS-CLEAN Owner-Request Coverage Sweep + NUANCE-COMPLETENESS gate.
