# STRICT RE-CERT LOG (2026-06-22)

> Re-certification phase: IN PROGRESS. Every queue item gets a line here when touched.
> Format: `item · verdict · evidence · commit SHA`
>
> **Queue authority:** docs/WORK_QUEUE_2026_06_22.md (walk 0.1→0.32, then TIER 1…)
> **Driver:** docs/AGENT_LOOP_PROMPT_STRICT_RECERT_2026_06_22.md
> **Runtime PNG:** docs/research/osa_runtime_2026_06_22.png (capture per osa_runtime_PLACEHOLDER.md)

## Phase status
- Certified: 0
- Needs-owner (last resort): 0
- Fixed during recert: 0 (0.1 built-in source→cream/mono + schema-bump cascade landed & cream pixel-verified `#fbfaf5`; 0.1 still `[ ]` — D-gated on full D5 chrome + D2 landing)
- Iteration 1 (real cert walk) underway 2026-06-22 12:54; highest attempted 1.1; see `## Certification log` → Iteration 1
- STRICT RE-CERT COMPLETE: no (**FORBIDDEN while ANY queue box is still `[ ]`**)

## Certification log

_(Build-agent certification lines only — sole source of cert counts. Gap-fill / docs edits go under
`## Docs-maintenance` — excluded from counts.)_

### Iteration 1 (real cert walk begins — 2026-06-22 ~12:54; prior log = docs-gap-fill only, 0 prior certs)
- **STEP-0 RESET** · queue already all `[ ]` — nothing to revert. `## Certification log` was empty (0 prior certs).
- **baseline screencapture** · `/tmp/epi_iter1_act_20260622-1254.png` (3.05MB) **Read this iteration** @ 12:54 · running app pid 77113. **D2 = BROKEN** (Osaurus DEFAULT landing: "Good afternoon / How can I help you today?" + dino + What's configured?/Download a model/Add a provider/Install a plugin — owner's Epistemos LandingView NOT shown).
- **PIXEL-TRUTH CORRECTION (gate-e, my eyes were wrong)** · I first read the surface as "white = reskin not rendering." **Pixel sampling proves otherwise:** chat-surface region is dominantly `#fbfaf5` (cream, 178k px in baseline / 267k px post-build), with `#f6f5f0` secondary cream + `#1c1c1e` ink text — i.e. **cream IS rendering, in BOTH the pre-rebuild baseline AND post-rebuild.** It merely *looks* white because #fbfaf5 is ~4/255 off pure white. The driving theme is the **active custom theme `E9150305-…0001` "Epistemos"** (author Epistemos, isBuiltIn:false, primaryBackground #fbfaf5, primaryFont "SF Mono") loaded via `loadActiveTheme()` — already cream before my change. So the act background-color reskin (0.1/D5 background) is **NOT the broken part**; the broken parts are D2 (landing) + D1 (curve) + D3 (pill) + D4 (settings) + D5-chrome (picker/palette/38-tool panel).
- **0.1 Reskin@VENDORED SOURCE** · **SOURCE FIX APPLIED + cream RUNTIME-VERIFIED (pixel #fbfaf5); stays `[ ]` — D-gate on full D5 chrome + D2 landing still broken.**
  Root cause (deeper than prior attempts): the LIVE light theme is `CustomTheme.lightDefault` (CustomTheme.swift:804), NOT the vestigial `LightTheme` struct (Theme.swift:238) — `ThemeManager.init` (Theme.swift:579-631) instantiates `CustomizableTheme(config:)` from disk-installed built-ins. lightDefault was already `#ffffea` (pale yellow, not Osaurus original, not cream) yet the app rendered **white** → the disk-install cache (`ThemeConfigurationStore.installBuiltInThemesIfNeeded`:169-188) only force-reinstalls when `currentBuiltInThemeSchema` is bumped (line 173); otherwise the stale cached theme persists. **This is exactly the "reskin doesn't cascade" bug.**
  Fix: (1) `lightDefault.colors` → Epistemos cream/ink palette (#fbfaf5/#f4f3ee/#ecebe4 surfaces, #1c1c1e ink text+accent, CustomTheme.swift:812); (2) `lightDefault.typography` → `ThemeTypography(primaryFont: "SF Mono")` (monospace discipline); (3) version 1.1→1.2; (4) **`currentBuiltInThemeSchema` 5→6** (ThemeConfigurationStore.swift:17) so the cached disk theme force-reinstalls and the source edit actually cascades to the running app.
  5-gate status: (a) EXISTS ✓ CustomTheme.swift:812 · (b) ON-PLAN ✓ edits the VENDORED source per §1765 (cream/mono, not runtime applyCustomTheme) · (c) WIRED ✓ consumer = `ThemeManager.resolveBuiltInTheme`/init (Theme.swift:625-630) + `installBuiltInThemesIfNeeded` reinstalled disk built-in …0002 → `#fbfaf5` (verified `~/.osaurus/themes/…0002.json` mtime 13:02, schema UD=6) · (d) TESTED — pending (OsaurusCore theme tests) · (e) RUNTIME — **xcodebuild BUILD SUCCEEDED; relaunched build; `/tmp/epi_iter1_act_cream2_20260622-130336.png` Read + pixel-sampled = `#fbfaf5` cream surface + `#1c1c1e` ink (cream confirmed)**. NOT `[x]`: D-gate ties 0.1 to full D5 (picker/palette/38-tool panel, item 4.7) AND act still shows Osaurus default landing (D2) — both open. Net: built-in source now cream/mono + cascade fixed (benefits fresh/cleared theme); owner's running surface was already cream via active "Epistemos" theme.
- **0.31 reverse-addendum audit** · addendum `^#{1,3} ` headings = **129**; priority-keyword hits = **177**. Tail heading scan (§1158–§1780: GRAND CONVERGENCE→2.4, HELIOS salvage→2.2, BUILD-IT-HARDENED→2.8, ACT=OSAURUS/DEFINITIVE ACT-UI→0.17, RESKIN FIX→0.1, OWNER-REPORTED DEFECTS→0.8) — all indexed in 0.1–0.32 / TIER walks; VOID §607/§1485/§1507 superseded per in-file banners. **0 new unindexed headings this pass.**
- **1.1 (TIER 1 attempt — act-only tunnel DENIED)** · EXISTS ✓ OpenCode + bun vendored: `Epistemos/Resources/opencode-runtime/bin/{opencode,bun}` (opencode 1.17.9, bun 1.3.14, darwin-arm64); Work surfaces `WorkOpenCodeRuntime.swift`/`WorkOpenCodeShell.swift`/`WorkTerminalView.swift` + tests present. W1 full cert (launch PNG + W4 work harness) pending — TIER 1 genuinely attempted.
- **0.32 FULL-PLAN WITNESS (iter 1)** · Highest attempted item ID: **1.1** · Lowest still-`[ ]` item ID: **0.1** · Counts — T0: 0`[x]`/0`[~]`/32`[ ]` · T1: 0/0/9 · T2: 0/0/8 · T3: 0/0/2 · T4: 0/0/18 · T5: 0/0/4 · TIER 1+ attempted: **YES** (1.1 EXISTS confirmed) · Act-only tunnel: **DENIED (explicit)** · Forbidden end-claims avoided: **YES** · Notes: first real cert iteration; 0.1 built-in source fix landed (xcodebuild BUILD SUCCEEDED, cream pixel-verified `#fbfaf5`), committed this iteration. Pixel-truth correction: cream was already rendering via active "Epistemos" theme — real open act defects are D1/D2/D3/D4 + D5 chrome (not background color). TIER ADVANCE FLOOR satisfied (highest=1.1).

## Docs-maintenance

## Iteration log

### Gap-fill pass (docs only, 2026-06-22 — iteration 1–2)
- queue · REORDERED · 0.1–0.26 numeric walk order; added 0.17–0.26, 1.4, 2.5–2.6 · (docs commits)
- artifacts · NOTE · `osa_runtime_2026_06_22.png` — agent must capture baseline on first run if missing

### Gap-fill iteration 3 (docs only, 2026-06-22)
- queue · HARDENED · standing: FAVOR OSAURUS, owner-messages→plan, ~/Downloads corpus, NEVER-IDLE;
  added 2.7 agent-stack/dual-MLX, 2.8 BUILD-IT-HARDENED, 4.12 Prose+MD-V2, 4.13 loved assets;
  strengthened 0.5 per-surface screenshots · (this commit)
- strict-prompt · HARDENED · mirror 0.11–0.26; paragraphs A–G; FIRST ITERATION 0.1→0.26 numeric
- paste-ready · SYNCED · full 0.1→0.26 table + 14 non-negotiables
- addendum · VOID banners · §607 WORK ON HOLD, §1485 restore old UI, §1507 option-(b) → §1651
- stale-docs · SUPERSEDED · AGENT_DIRECTIVE_CHECK_PROMPT redirected to strict recert stack

### Gap-fill iteration 5 (docs only, 2026-06-22)
- reverse-audit · OPENCODE HEAVINESS was unindexed → added queue **1.8**
- 0.32 · HARDENED · mandatory witness block + forbidden end-claims (act-tunnel prevention)
- 0.31 · grep extended WORK/BEYOND keywords
- paste-ready · explicit NON-OPTIONAL tier tables 1.1→1.8, 2.1→2.8, 4.1→4.16
- standing · ACT-before-WORK priority scoped to TIER 0 only (does not skip TIER 1+ walk)

### Gap-fill iteration 6 (docs only, 2026-06-22)
- reverse-audit · ESCALATION P0-A/P0-B was implicit in 0.6 → **explicit** engine indicator + visible send errors + →plan refs
- 0.32 · HARDENED · highest attempted **item ID** required; INCOMPLETE if stopped before 1.1; extra forbidden deferral phrases
- paste-ready · added TIER 3 (3.1→3.2) + TIER 5 (5.1→5.3) NON-OPTIONAL tables; FIRST ACTION stop-before-1.1 rule
- 0.31 · grep extended **ESCALATION** keyword (queue + strict + paste)

### Gap-fill iteration 7 (docs only, 2026-06-22 — pass49 audit)
- pass49 P0-1 · **STEP-0 RESET** enforced: revert queue `[x]`/`[~]`→`[ ]`; STRICT_RECERT_LOG = sole cert record
- pass49 P0-2 · **TIER ADVANCE FLOOR:** every 3 iters highest attempted ≥1.1 or stall report; act IN PARALLEL with T1+
- pass49 P0-3 · **`[~]` CAP ≤2/phase:** 3rd halts owner; each `[~]` logs exact failing cmd+output
- reverse-audit · MAS VM sandbox substitute was standing-only → queue **5.4**; APP-WIDE ANIMATION → **4.6** expanded
- 0.31 · grep extended **🆕/🌟/RESEARCH** + paste hit count requirement
- paste-ready · 21 non-negotiables synced; TIER 5 walk 5.1→5.4; STEP-0/parallel/[~] cap added
- →plan anchors · fixed FUGU + Epistemos Picks headings to match addendum

### Gap-fill iteration 8 (docs only, 2026-06-22 — pass49 P0-4/P0-6 + reverse-audit)
- pass49 P0-4/P0-6 · **W/B/S ACCEPTANCE GATES** stub section added (W1–W5, B1–B3, S1–S5) in queue + strict prompt + paste
- pass49 P0-5 · **PHASE COMPLETE PRECONDITIONS** in strict prompt DONE bar + queue STANDING (xcodebuild + PNG Read + send-text)
- pass50 P0-B · **stub ≠ `[x]`** — 0.28/0.30 clarified; B3 + STANDING; honest stub uses `[ ] STUBBED(plan ref)`
- reverse-audit · indexed: ACT RESKIN GO DEEPER → **0.1**; FUGU CLONE THE CODE → **3.2**; BIG IDEA → **2.4**;
  INITIATIVE ADOPT PROVEN ENGINES → STANDING+FULL-CLONE; MARKET POSITION → STANDING research monitor
- sync fix · WALK ORDER + strict prompt pick order **5.3→5.4** (queue had 5.4; text still said 5.3)
- paste-ready · 22 non-negotiables (+ W/B/S gates #22); W/B/S table added

### Gap-fill iteration 9 (docs only, 2026-06-22 — pass50 remaining gaps)
- pass50 P0-A · **0.32 lowest still-[ ] item ID** witness field (pairs highest attempted; anti ATTEMPTED-vs-CERTIFIED gaming)
- pass50 P0-C · **1.7/0.29 work harness REQUIRED** — removed "when available / where harness exists"; aligned with W4
- pass50 P1-a · **send-text served-model == selected-model** assert in 0.4/0.23, strict MANDATORY PROOF, paste, placeholder
- pass50 P1-b · **gate-(c) WIRED distinct mount/route cite** — NOT same file:line as (a) EXISTS (queue bar + strict + paste)
- pass50 P1-c · **PNG freshness:** unique per-iter paths + timestamp log + Read-this-iteration rule (queue RUNTIME, paste #21, placeholder)
- reverse-audit · re-grep 🔒/DEFINITIVE/P0/MUST/🆕/🌟/RESEARCH (~64 section headers); **0 new unindexed** — SYSTEM-PROMPTS→4.2, NEVER-IDLE→STANDING, FUGU SEQUENCING→3.2 bundle, TRINITY subsections→3.1
- sync verify · STEP-0 / `[~]` cap / TIER floor / 0.32 (highest+lowest) / W/B/S / gate-c / harness / PNG synced across three docs

### Gap-fill iteration 10 (docs only, 2026-06-22 — CURSOR HANDOFF final hardening)
- pass51 P0-C · **4 missing queue rows:** **1.9** RustLSP→work tools · **1.3** Goose FULL clone mandate · **4.17**
  vault→GRAPH+LLM-wiki · **4.18** MD-V2 inversion+agent-edit provenance
- pass51 P0 · **0.31 full addendum heading diff** (not token-grep alone) · **discovery sweep ALL tiers** (not chat-only)
- pass51 P0 · **W-gate W5** = act↔work toggle+blur (Electron under 1.8) · **S-gate (e)** cites ARCHITECTURE_TIER_PROMOTION_CANON T4
- pass51 P1 · **gate-(d) linked to (c)** + **"0 skipped/ignored"** · **lowest still-[ ] must advance** vs prior iteration
- pass51 P1 · **Tolaria** canonical spelling (was Talaria drift) · external-doc →plan paths verified (CHAT_BACKEND + SUBSTRATE)
- pass51 P1 · **0.21 sole D4 owner** · strike **"one item minimum"** · paste **OsaurusChatView** disambiguation
- pass51 E · **STRICT_RECERT_LOG** split: `## Certification log` vs `## Docs-maintenance`
- reverse-audit · full heading diff sample: vault→GRAPH→**4.17** · RustLSP→**1.9** · MD-V2 inversion→**4.18** · Goose full-clone→**1.3** · all indexed

### Gap-fill iteration 10 (docs only, 2026-06-22 — CURSOR_HANDOFF A–E verify + strict/paste sync)
- handoff · **345495263 CURSOR_HANDOFF doc committed**; no uncommitted WORK_QUEUE/STRICT/PASTE in flight at tick 6
- A verify · lowest still-[ ] / stub≠[x] / W/B/S / harness REQUIRED / phase preconditions — **PASS** (queue + iter 8–9)
- B verify · model-id / gate-c distinct / PNG freshness — **PASS** (iter 9); **(d)↔(c) link + xfail** synced strict+paste this iter
- C verify · **1.9/4.17/4.18/1.3 full-clone** already in queue (pass51 prep); **Tolaria** spelling unified strict+paste;
  **0.31 heading-diff** already in queue; **CHAT_BACKEND + SUBSTRATE_BUILD_SEQUENCE** →plan paths verified on disk
- D verify · struck **"one item minimum"** → 0.32 lowest-open floor; **D4 sole owner 0.21** in strict+paste;
  **OsaurusChatView** disambiguation in paste (forbidden Epistemos ChatView unchanged)
- E verify · **## Certification log** / **## Docs-maintenance** headers landed in STRICT_RECERT_LOG; tier walks **1.9/4.18** synced paste+strict
- discovery · per-tier plan-section reconciliation added strict+paste (not chat-only)

### Gap-fill iteration 11 (docs only, 2026-06-22 — tick 7 final pre-launch verify)
- handoff · tick 7 opened with uncommitted WORK_QUEUE+STRICT (reconcile in flight) — deferred verify until **7ecc2b9ed** pass51 reconcile committed
- pre-launch · three-doc sync cross-check (tier walks 0.32/1.9/4.18, 22 non-negotiables, 0.21 D4 sole owner, OsaurusChatView, Tolaria, 0.31 heading-diff, gate-(d)↔(c), W/B/S, STEP-0/[~] cap/TIER floor, 0.32 witness) — **PASS**; no duplicate CURSOR handoff edits
- LOOP_GAP_AUDIT · iteration 11 pre-launch checklist appended

### Gap-fill iteration 12 (docs only, 2026-06-22 — tick 8 lightweight drift verify)
- drift · `git log -1` = **7dcc741b2**; WORK_QUEUE/STRICT/PASTE three-doc sync re-check (tier walks 0.32/1.9/4.18, 22 non-negotiables, 0.21 D4 sole owner, OsaurusChatView, Tolaria, gate-(d)↔(c), W/B/S, STEP-0/[~] cap/TIER floor, 0.32 witness, contradiction grep) — **no drift**; no duplicate CURSOR handoff edits
- LOOP_GAP_AUDIT · iteration 12 lightweight drift verify appended
