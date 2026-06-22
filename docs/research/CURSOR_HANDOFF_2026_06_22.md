# CURSOR HANDOFF — harden the Epistemos STRICT RE-CERT loop prompt (2026-06-22)

Consolidates 3 read-only research passes (auditor): structural (pass 49), adversarial red-team (pass 50),
completeness diff (pass 51). Cursor: use this to produce ONE robust prompt+queue+paste. Then the owner brings it
back to the auditor for a double-check before launch.

## OBJECTIVE — the prompt must guarantee 4 things
1. **DEEP CERTIFICATION FIRST.** Reset everything (trust NO prior done), then re-certify the **ENTIRE** plan —
   all tiers 0–5, all clones (Epistemos / act / work / beyond), substrate, IP, orchestrator, vault, EPDOC,
   distribution — to a strict 5-gate bar: (a) EXISTS file:line · (b) CORRECT & ON-PLAN (mandated approach, not
   near-miss) · (c) WIRED & REACHABLE · (d) REAL-STATE TESTED · (e) RUNTIME-PROVEN BY THE LOOP ITSELF.
2. **THEN CONTINUE CODING** the rest of the plan — recert and forward build are the same walk; don't stall, don't
   treat recert as terminal, don't declare the plan done prematurely.
3. **NO CONTEXT BLOAT.** Each loop re-reads only the small queue + the current item's ONE `→plan:` section —
   never the whole ~1800-line addendum. Status/evidence lives in the queue + STRICT_RECERT_LOG.
4. **DOES EVERYTHING IN THE PLAN.** The queue must index every plan directive; the reverse-audit must catch any
   un-indexed directive (nothing silently skipped).

## FILES TO UPDATE
- `docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md` (loop driver)
- `docs/WORK_QUEUE_2026_06_22.md` (the index/checklist)
- `docs/AGENT_LOOP_PASTE_READY_2026_06_22.md` (the launch paste block)

## ALREADY APPLIED — verify they hold, do NOT redo
- STEP-0 physical reset (revert all `[x]`/`[~]`→`[ ]`) — prompt:117
- `[~]` cap ≤2 — prompt:268
- Paste block names the forbidden file `Epistemos/Views/Chat/ChatView.swift` — paste:36
- Whole-plan / no-act-tunnel framing; all 4 clones named; TIER 1 now has 1.8 (the old "1.8 typo" was stale)

## MUST-FIX — open robustness holes

### A. Certification can be faked or scope-narrowed (P0 — highest leverage)
- **Done-bar keys off "ATTEMPTED" not "CERTIFIED"** (queue 0.32 §188-199): a loop can *attempt* 5.3, leave every
  TIER 1–5 box `[ ]`, and pass. FIX: witness records the **LOWEST still-`[ ]` item**; iteration INCOMPLETE unless
  it advanced vs last; "RE-CERT COMPLETE" FORBIDDEN while any box is `[ ]`.
- **"Honest stub" = `[x]`** (queue:178/188): work/beyond certify as "honestly stubbed" → whole clones certified
  UNBUILT. FIX: a stub is `[ ] STUBBED (plan ref)`, **never `[x]`**; COMPLETE requires ≥1 real runtime proof per
  in-scope clone (stubs excluded from the certified count).
- **Work send-path proof optional "when available"** (queue 1.7 §222, 0.29 §173); the mandatory-harness clause
  names only the **act** path (prompt:213-215) → the whole OpenCode/work engine certifies on compile. FIX:
  require a per-lane send-text harness for **every wired clone** (act, work, each beyond); strike "when available".
- **Only act has a concrete acceptance gate (D1–D5).** FIX: add explicit gates mirroring D1–D5:
  - **W1–W5 (work):** binary vendored & launches · real OpenCode TUI renders (PNG) · palette theme-responsive
    (PNG) · work send reaches OpenCode/Goose engine not act fallback (harness, model-asserted) · act↔work toggle +
    blur transition (PNG).
  - **B1–B3 (beyond):** tab renders (PNG) · each clone's stub-vs-wired state matches code (honest witness) ·
    **grep-proof Companion backend NOT on the beyond path** (companions.rs / CompanionCreationFlow off-limits).
  - **S-gate (substrate/orchestrator):** the runtime rubric below.
- **Build-green has no teeth for headless substrate/orchestrator** (TIER 2/3 — gate (e) collapses to
  `cargo test`). FIX: define (e) for non-UI = a **real-state integration test on the LIVE wired path** (e.g.
  AnswerPacket actually loaded on launch AND surfaced in a health row; TRINITY route actually selected AND logged
  in RunEventLog) — NOT an isolated unit test. Cite the test name + the runtime artifact it asserts (log line /
  health-row value / AnswerPacket field). Reference CLAUDE.md `ARCHITECTURE_TIER_PROMOTION_CANON` T4 (compiled-in-
  scope, reachable, visible, logged, AnswerPacket-visible) as the definition of green.
- **Phase can be "COMPLETE" without ever launching the app.** FIX: completion preconditions — (1) a green full
  `xcodebuild` of main this phase, (2) every surface in the clone matrix has a fresh PNG the loop has `Read` this
  phase, (3) the send-text harness produced a real reply this phase. List PNG paths + reply in the summary.

### B. Evidence forgery (P1)
- **Send-text accepts ANY non-empty reply** — no check the configured model answered (prompt:216). FIX: harness
  asserts **served-model id == selected-model id**; that assertion IS the proof (not the 80-char prose).
- **Gate-c WIRED uses the same file:line as gate-a EXISTS** → a definition-site behind a disabled flag / unmounted
  view passes "wired." FIX: (c) requires a **distinct consumer/mount/route citation**; for UI, the screenshot must
  show the element **reached by navigation**, not just present in source.
- **Stale PNG reuse:** ground truth is a fixed committed path with no freshness check → yesterday's broken
  baseline certifies today. FIX: per-iteration **uniquely-named, committed** PNG + capture timestamp in the log;
  forbid reusing a prior PNG for an `[x]`; re-capture the baseline at the START of each iteration.
- **(d) and (e) not linked** → a unit test on a helper + a screenshot of a different path both pass. FIX: (d) must
  assert the **same entry point** that (c) cites as the live path.
- **Skipped/xfail/weakened-assert evade gate-d + no-red** → FIX: (d) must cite the test **ran and asserted**
  ("0 skipped/ignored for this item"); fast gate fails on any newly-ignored/xfail test touching a certified item.

### C. Discovery / completeness (P1) — so it does EVERYTHING in the plan
- **Reverse-audit (0.31) greps a FIXED token set** → directives marked `🌟/🆕/✅/DIRECTIVE/PILLAR/REQUIRED` are
  undiscoverable. FIX: **diff the FULL addendum heading list against the queue index** (not a token grep); 0.31 is
  `[x]` only when the grep/diff output + any new rows are pasted in the log that iteration.
- **Discovery sweep is chat-only** (greps InferenceState/picker/chat) → blind to substrate/TRINITY/vault/Epdoc/
  distribution (most of the plan). FIX: add a per-tier plan-section→queue reconciliation alongside the chat grep.
- **4 buildable directives NOT indexed — add queue rows:**
  1. **vault→GRAPH population + LLM-wiki UI surfacing** (addendum:730/777) — 4.3 covers vault, not graph
     population / LLM-wiki UI.
  2. **RustLSP → work-agent code-intelligence tools** (addendum:133) — wire `agent_core::lsp_runtime`
     (hover/definition/diagnostics/edit) into the WORK stack; no queue row today.
  3. **EPDOC MD-V2 inversion** (md = source, html/json = projections) **+ agent-edit provenance** (addendum:206/
     777) — 4.4 is generic; the inversion + provenance nuances risk silent skip.
  4. **Goose = FULL vendored clone, NOT leaf-by-leaf port** (addendum:441, ‼️ CORRECTIONS #1) — 1.3 has the
     architecture but not the full-clone mandate.
- **Talaria vs Tolaria naming drift:** queue says "Talaria" (4.8/4.14/0.30); addendum says "Tolaria" (730) — a
  grep-based recert could miss the clone. FIX: unify the spelling.
- **Verify external-doc `→plan:` targets exist:** `CHAT_BACKEND_QUARANTINE` (0.10/4.9/4.10/4.11) and
  `SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md` (2.1) — if a file is missing, those items dangle. Confirm or fix.

### D. Contradictions at HEAD (P1)
- **"One item minimum per loop" (prompt:247) vs the full-walk hard gate** → strike "one item minimum"; the binding
  floor is the 0.32 hard gate (lowest-open advanced this iteration).
- **D4/Configuration has 3 homes** (0.21 vs 0.11/0.22 vs the matrix) → name **0.21 the sole owner**; 0.11/0.22
  reference it, don't duplicate the obligation.
- **Paste:35 still calls the Osaurus view "ChatView"** while prompt:76 forbids mounting "ChatView" → rename in the
  paste to **`OsaurusChatView` (vendored), never `Epistemos/Views/Chat/ChatView.swift`** (paste:36 already names
  the forbidden file; finish the disambiguation).

### E. No context bloat (owner priority)
- Keep the queue SMALL and re-read it fully each loop; read only the current item's ONE `→plan:` section — never
  the whole addendum.
- STRICT_RECERT_LOG: certification lines under a `## Certification log` header (the sole source of cert counts);
  gap-fill / docs-maintenance lines under a separate `## Docs-maintenance` header, EXCLUDED from counts.
- Each loop = re-read small queue + 1 plan section + act + log + commit. Don't accumulate context.

## ACCEPTANCE — the prompt is "robust" when ALL hold
- Cannot declare "RE-CERT COMPLETE" while any box is `[ ]`, or while any in-scope clone lacks ≥1 real runtime proof.
- Cannot certify on build-green: UI = fresh screenshot the loop Read; inference = model-id-asserted send-text;
  headless = live-path integration test citing a runtime artifact.
- Reset is physically enforced; the log (not the checkbox) is the source of truth.
- Reverse-audit diffs the full heading list vs the queue (nothing silently skipped); the 4 missing rows added.
- Walks the whole plan, recert FIRST then continue; small per-loop footprint (no bloat).
- Each clone (work/beyond/substrate) has its own concrete acceptance gate, not just act's D1–D5.

## DELIVERABLE
Cursor returns the updated `prompt + queue + paste`. The owner brings it back to the auditor to double-check
against this list before launching the build agent.
