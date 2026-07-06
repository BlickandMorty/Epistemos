# HANDOFF → CODEX (2026-07-06) — session checkpoint + finish-off instructions

Written by the auditing Claude session at owner request (token limit). This is the single document
to resume from. Repo branch: `feat/goose-surface`. Everything below is committed.

## 1. What this session produced (all committed, pathspec-scoped)

**Four plan packages, each research-audited to build-ready** (pattern: wave → multi-auditor repo
juxtaposition → amendments bound into PLAN §-AMEND + BUILD_PROMPT addendum + per-file spine
headers → upstream supersessions → commit):

| # | Plan | Package | State |
|---|---|---|---|
| 1 | KEELSTONE `EPI-RP-07` (vault sync/truth/schema/release) | `docs/plans/keelstone/` | **BUILD IN FLIGHT** (separate agent; has landed AppSurface, macro scoping `8a1ca87d1`, AtomicVaultWriter routing `9df4927d3`) |
| 2 | LUMENLENS `EPI-RP-02` (4-lens editor + suggestion engine + Epdoc Notebook) | `docs/plans/lumenlens/` | build-ready; builds AFTER KEELSTONE 0–4 |
| 3 | KINDRED `EPI-RP-05` (companion; 1Code-only) | `docs/plans/kindred/` | build-ready; K4/K5 need LUMENLENS L1 |
| 4 | RECKONER `EPI-RP-09` (data layer; audited TODAY, #4) | `docs/plans/reckoner/` | build-ready; builds after LUMENLENS L1/L5 + KINDRED K6 |

**Each package contains:** `*_REVIEW_*.md` (audit verdict — READ FIRST), `PLAN_*` (+binding
§-AMEND), `BUILD_PROMPT_*` (+binding REPO REALITY ADDENDUM), `spine/` (code contracts with
binding `AUDIT AMENDMENT` headers — the headers OVERRIDE the body where they conflict).

**Governing docs:** `docs/prompts/RESEARCH_PROMPT_STANDARD.md` (registry: LUMENLENS/SIGILRY/
KINDRED/EMBERCATCH/KEELSTONE/LODESTAR/RECKONER + rubric) · `docs/prompts/INTEGRATION_FABRIC.md`
(F1–F6 contracts) · `docs/prompts/MASTER_PLAN_INDEX_2026_07_03.md` (updated).

**Major decisions locked this session (owner-reversible, all with supersession records):**
- Epdoc = default note view everywhere (`51d7c6a61`); note-creation modal removed.
- Two surfaces only: MAS/June + Experimental/1Code; OpenChamber vestige being excised by KEELSTONE.
- KEELSTONE Phase 4.5 (owner-mandated): vault `.md` = sole note body truth.
- Plan 9 RESHAPE: no Data room, no new chat; datasets = workspace tabs + note embeds + agent tools.
- Epdoc Notebook (P-AMEND 11/12): in-note tabs (sheets/chats) as REFERENCES in a Tier-B manifest;
  Lens-Fidelity Disclosure w/ robust preview+export popovers (P-AMEND 10).
- **RECKONER truth-flip ACCEPTED (#4, `f7f966a83`):** vault artifact (CSV / XLSX-.icalc +
  .dataset.md) = dataset truth; GRDB = derived cache. Charts = Swift Charts primary.
  Dual-zone/defined-names + record-level objects = explicit post-v1 DEFERRALS.

## 2. IMMEDIATE finish-off tasks for Codex (in order)

1. **Owner sends the KEELSTONE reprompt** (text in the #4 checkpoint message + encoded in
   `docs/plans/keelstone/BUILD_PROMPT_KEELSTONE.md` coordination item 4 / plan §15.10): dataset-
   artifact indexed-set extensibility + conflict delegation + soak extensions + AtomicVaultWriter
   Data overload. If owner asks Codex to verify instead: check the KEELSTONE agent's recent
   commits honor §15 (esp. 15.1 order, 15.5 body-truth Phase 4.5, 15.10).
2. **Supervise/verify KEELSTONE build progress** against its plan §8 tracker (witnessable bars,
   not compiles). Its work must demonstrate Phases 0–4 before LUMENLENS starts.
3. **When the owner returns SIGILRY research** (`docs/prompts/RESEARCH_PROMPT_PLAN_4_ICONS.md` is
   the brief they'll run): repeat THE AUDIT PATTERN — (a) read the wave fully; (b) fan out
   verification agents juxtaposing every claim against this repo + sibling plan docs (check:
   already-built reality, guard-test pins, gating flags, seam fidelity to KEELSTONE/LUMENLENS/
   KINDRED/RECKONER amendments, fabricated APIs — verify against live packages when possible);
   (c) bind fixes as §-AMEND + prompt addendum + spine headers; (d) write upstream supersessions
   for ANY contradiction with existing docs (never silent); (e) commit pathspec-scoped to
   `docs/plans/sigilry/`; (f) deliver a numbered checkpoint (#5) with links. Same for LODESTAR
   (#6), EMBERCATCH (#7).
4. **When LUMENLENS build starts:** paste `docs/plans/lumenlens/BUILD_PROMPT_LUMENLENS.md` to ONE
   agent. Addendum + P-AMEND 1–13 bind. KEELSTONE 0–4 must be demonstrated first — else stop.

## 3. Standing rules (violations have burned this repo before)
- **Pathspec-scoped commits ONLY**: `git commit --only -m "..." -- <files>`. Parallel agents
  pre-stage in the shared index; a bare commit once swept 52 foreign deletions. Check
  `git diff --cached --stat` count before every commit.
- **Never two xcodebuilds** (16GB machine; build.db corrupts → exit 65). Isolated DerivedData for
  verification builds. Reaching CodeSign with CODE_SIGNING_ALLOWED=NO = compile OK.
- **No git worktrees. Never `git add -A`. Never commit `.research-clones/`.** Commit after every
  change. xcodegen owns the pbxproj — never hand-edit; regen after project.yml changes.
- **Guard tests pin exact strings** (EpdocVisibilitySourceGuardTests, slash count 18/19 + ID set,
  NoteEditorLayoutTests:238 enum decl, AppStoreHardeningTests flag scoping): update pins
  DELIBERATELY in the same commit as the change they pin.
- **Surface gating:** `EPISTEMOS_APP_STORE` vs `EPISTEMOS_EXPERIMENTAL` (+`KINDRED_ENABLED`,
  Experimental-only) — target-scoped, never in shared base; AppSurface.swift #errors enforce.
- Read-before-edit; verify code/disk before asserting; spine headers + §-AMENDs override wave
  bodies; amendments are the binding layer.

## 4. Open owner decisions (do NOT resolve silently)
1. KINDRED landing/creation handoff: options a/b/c — recommendation (c); owner confirms before K7.
2. RECKONER truth-flip + charts inversion + dual-zone deferral: accepted by audit; owner can
   reverse any with one word (supersession blocks say where).
3. LUMENLENS L4 undo decision (retain-WebView vs documented v1 undo-loss) — decided at phase start.
4. Research order for remaining plans: SIGILRY next (K3 consumes its rig), then LODESTAR,
   EMBERCATCH.

## 5. Sequence map (the one the owner asked to re-orient by)
RESEARCH/AUDIT: ✅KEELSTONE ✅LUMENLENS ✅KINDRED ✅RECKONER → ⬜SIGILRY → ⬜LODESTAR → ⬜EMBERCATCH.
BUILD (one agent at a time): KEELSTONE (now) → LUMENLENS → KINDRED (K0–K3 may overlap LUMENLENS)
→ RECKONER → SIGILRY-assets feed K3 → LODESTAR/EMBERCATCH after the triad stabilizes.

## 6. Checkpoint commits of record
`51d7c6a61` Epdoc default · `a18c98bb4`+`ac3da90f4` #1 KEELSTONE · `8db63ca63` #2 LUMENLENS ·
`485e9afd1` #3 dual+KINDRED · `4d9d0e401`+`68b3023b7`+`2fca8e0d2` RECKONER reshape ·
`c0dcd431a` RECKONER brief · `656980f25` disclosure · `5e7ac8554`+`5b45275c7` notebook+embeds ·
`f7f966a83`+`07ddf42f4` #4 RECKONER audit. KEELSTONE agent's own: `8a1ca87d1`, `9df4927d3`, ….
