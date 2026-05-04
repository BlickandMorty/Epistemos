# Task Prompt Template

**How to use this file.** This is the canonical template for any agent session that
implements an item from `03_EXECUTION_MAP.md`. To use:

1. Copy this entire file to a new file at `prompts/<ITEM_ID>_<short_name>.md`.
2. Replace every `{{...}}` slot with the item-specific value.
3. Paste the resulting prompt into a fresh Claude Code session as the first message.
4. The session is now bound by this contract for the duration of the task.

**The slots:**
- `{{ITEM_ID}}` — e.g. `W9.25`, `R14`, `D1`
- `{{ITEM_TITLE}}` — e.g. `Grammar masking (mlx-swift-structured)`
- `{{ITEM_PHASE}}` — e.g. `1`, `2`, `parallel`
- `{{ITEM_TARGETS}}` — e.g. `Both`, `MAS only`, `Pro only`
- `{{ITEM_RISK}}` — e.g. `Low`, `Medium`, `High`
- `{{EXECUTION_MAP_ANCHOR}}` — e.g. `#w925--grammar-masking` (the anchor in `03_EXECUTION_MAP.md`)
- `{{REQUIRED_RESEARCH_LIST}}` — bullet list of file paths the agent must read first; pulled from `05_RESEARCH_INDEX.md` reverse index
- `{{ITEM_SPECIFIC_NOTES}}` — anything the user wants to add (e.g. "I tried this last session and got stuck on X")

If a slot doesn't apply, write `n/a` — do NOT delete the slot heading. The template's
shape is the contract.

---

# Begin task prompt

You are a Claude Code session implementing **{{ITEM_ID}} — {{ITEM_TITLE}}** for the
Epistemos repo at `/Users/jojo/Downloads/Epistemos/`. You operate under the strict
anti-drift contract in `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md`. Read it. Obey it.

Today's date: **2026-04-27** (or later — verify current date if the session is
resumed).

---

## Phase 1 — Pre-flight reads (MANDATORY, in this exact order)

Before writing or editing any code, you must `Read` each of the following files in
full. Not skim. Read in full. If a file is too long for one Read call, read it in
segments and summarize the load-bearing constraints to yourself in your output.

After reading, you MUST output a one-paragraph summary of the constraints you
extracted from each, before you do anything else. This is the proof you read them.

**Required reads (in order):**

1. `/Users/jojo/Downloads/Epistemos/docs/architecture/PLAN_V2.md` — the architectural authority. Highest tier. If this contradicts anything else, this wins.
2. `/Users/jojo/Downloads/Epistemos/CLAUDE.md` — code standards, provider matrix, file map, "DO NOT" list.
3. `/Users/jojo/Downloads/Epistemos/docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` — the contract you are bound by.
4. `/Users/jojo/Downloads/Epistemos/docs/plan/01_DOCTRINE.md` — the fifth-position rulings.
5. `/Users/jojo/Downloads/Epistemos/docs/plan/02_BUILD_MATRIX.md` — Pro vs MAS gating.
6. `/Users/jojo/Downloads/Epistemos/docs/plan/03_EXECUTION_MAP.md` — the per-item entry for **{{ITEM_ID}}** (anchor `{{EXECUTION_MAP_ANCHOR}}`).
7. `/Users/jojo/Downloads/Epistemos/docs/plan/04_PHASES.md` — phase {{ITEM_PHASE}} entry/exit gates.
8. `/Users/jojo/Downloads/Epistemos/docs/plan/05_RESEARCH_INDEX.md` — the entries for {{ITEM_ID}} in §E reverse index.

**Item-specific research reads (also mandatory, after the above):**

{{REQUIRED_RESEARCH_LIST}}

For each research file you read, quote at least one specific passage in your output
that is load-bearing for {{ITEM_ID}}. This is your evidence the read happened.

---

## Phase 2 — Verify the codebase (auto-research mandate)

Before asserting any file path, line number, function signature, or library version,
verify it. Use `Read`, `Grep`, or `Bash` (`find`, `wc`, `cargo tree`).

Specifically: the entry for **{{ITEM_ID}}** in `03_EXECUTION_MAP.md` lists "Files to
touch (verified)" with line numbers. Those line numbers were verified at plan
authoring time but the file may have changed. **Re-verify each one** before treating
it as canonical:

```
# Example
Read <path> at the cited line number; confirm the symbol is still there.
Grep for the symbol; confirm there's only one match in the expected file.
```

If a path or line number has drifted: STOP and surface to the user (per
`00_AUTHORITY_AND_ANTI_DRIFT.md §5`). Do not silently rebase your work on the new
location — confirm with the user that the rebased target is still right.

---

## Phase 3 — Restate the task back

After Phase 1 and Phase 2, output this:

```
TASK CONTRACT
=============
Item: {{ITEM_ID}} — {{ITEM_TITLE}}
Phase: {{ITEM_PHASE}}
Targets: {{ITEM_TARGETS}}
Risk: {{ITEM_RISK}}

Files I will modify (verified above):
- ...

Tests that must stay green:
- ...

Telemetry surface I will create:
- ...

Definition of done (paraphrased from 03_EXECUTION_MAP.md):
- [ ] ...

WRV plan (per 00_AUTHORITY_AND_ANTI_DRIFT.md §4.7):
- WIRED — the new code will be called from <production caller path>; I will
         verify post-implementation with: grep -rn '<NewSymbol>' <dirs>
- REACHABLE — user gesture sequence: <step 1> → <step 2> → ... → <new code runs>
- VISIBLE — user will see <UI element> at <UI location> when feature is active.
         (or) WRV_EXEMPT: <category> — <justification>; cross-check against
         03_EXECUTION_MAP.md exempt list.

Pre-flight reads complete: yes / no
[UNVERIFIED] markers found: <count>
STOP-triggers encountered: none / list

Proceeding to implementation? (will pause for user OK if any STOP trigger or
[UNVERIFIED] needs resolution, or if WRV plan cannot be filled in)
```

If you have any STOP triggers, `[UNVERIFIED]` claims, or open questions: **stop
here**. Do not implement. Wait for the user to resolve.

If clean: proceed to Phase 4.

---

## Phase 4 — Implement

Implement only what is in the task contract. Do not implement what isn't.

**Hard rules during implementation:**

- No scope creep (per `00_AUTHORITY_AND_ANTI_DRIFT.md §9`). Out-of-scope findings
  go to `docs/APP_ISSUES_AUTO_FIX.md`, not to your branch.
- No forbidden actions (per `00_AUTHORITY_AND_ANTI_DRIFT.md §6`). No `try!`, no
  force unwraps, no `print()` in production paths, no `DispatchQueue.main.sync` in
  UniFFI callbacks, etc.
- Telemetry surface is part of the implementation, not an afterthought (per
  `00_AUTHORITY_AND_ANTI_DRIFT.md §7`).
- Memory budget per `00_AUTHORITY_AND_ANTI_DRIFT.md §8` (6 GB realtime). If your
  change adds steady-state memory > 50 MB, declare it in the PR description and
  surface to user.

**Whenever you encounter a new term, library, version, API, or file path that is
not verified in your context: STOP and verify before continuing.** Use `WebFetch`
for official docs, `Read` for repo files, `Grep` for symbols. Do not assert from
memory. Memory drift is the #1 source of agent hallucination in this codebase.

---

## Phase 5 — Verify

Run all SEVEN verification gates from `00_AUTHORITY_AND_ANTI_DRIFT.md §4`,
including the WRV gate from §4.7:

1. **Build green:**
   ```bash
   xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
   ```
   For Pro target add `-configuration ReleasePro` (verify scheme name).
   For MAS target add `-configuration ReleaseMAS`.

2. **Test floor preserved:**
   ```bash
   swift test                                              # 2,679-test floor
   cargo test --manifest-path agent_core/Cargo.toml
   cargo test --manifest-path epistemos-core/Cargo.toml
   cargo test --manifest-path epistemos-shadow/Cargo.toml
   # If item is hardening (W9.21, W9.22): TSan stress run
   ```

3. **Lint clean:**
   ```bash
   swiftlint
   cargo clippy --all-targets -- -D warnings
   ```

4. **No-silent-behavior audit:** every new code path that activates a non-default
   behavior MUST emit an `AgentEvent` AND surface in the UI. Document where in your
   output before claiming done.

5. **Definition of done:** the item-specific checklist from `03_EXECUTION_MAP.md`
   is fully checked. Each checkbox has a one-line proof — a test name, a grep line,
   a screenshot description.

6. **WRV gate — execute the proof:**
   - **W (Wired):** run the grep command from your Phase 3 contract; paste the
     output. At least one match must be in a non-test, non-scaffold production
     file. If the grep returns zero hits or only test/scaffold hits: the feature
     is unwired. STOP. Do not proceed. Surface to user.
   - **R (Reachable):** manually walk the user gesture sequence from your Phase 3
     contract on a fresh launch of the app (or describe how to do so if you cannot
     launch the app). Record the result. Document the screenshot or terminal
     output that proves the new code path ran.
   - **V (Visible):** confirm the UI element from your Phase 3 contract is
     actually rendered when the feature is active. If the visible surface is a
     telemetry field, run a grep showing that field's emit site is reached during
     a real session, not just a test.
   - If the item is `WRV_EXEMPT`: write the exemption justification and cite the
     line in `03_EXECUTION_MAP.md` standing rules that lists this item as exempt.
     If the item is not in the exempt list, you cannot self-grant exemption — STOP.

7. **Update `docs/AGENT_PROGRESS.md`:** ONLY after all gates including WRV pass.
   Append today's date and a one-line summary.

---

## Phase 6 — Output

Your final output for the task is:

1. **The diff itself** (don't summarize the diff — the user will read it via `git diff`).
2. **A PR description** in this format:

```markdown
## Summary
<2–3 bullet points — what changed, why>

## Items
- {{ITEM_ID}} — {{ITEM_TITLE}}

## Doctrine alignment
- 01_DOCTRINE.md §<sections>
- 02_BUILD_MATRIX.md row references
- 03_EXECUTION_MAP.md `{{EXECUTION_MAP_ANCHOR}}` definition of done

## Research consulted
<bullet list of files in /Advice, /final, /final v2 and any WebFetch URLs>

## Tests
- Pre-existing tests still green: yes
- New tests added: <list with names>
- TSan / miri (if applicable): <result>

## Telemetry surface
<where the user will see the new behavior>

## WRV proof
- WIRED: <grep command + output showing non-test caller>
- REACHABLE: From a fresh app launch: <step 1> → <step 2> → <step N> → <new code runs>
- VISIBLE: User sees <element type> at <UI location> when feature is active.
- (or) WRV_EXEMPT: <category> — <justification, cross-checked against 03_EXECUTION_MAP.md standing rules>

## Memory budget delta
<+X MB steady-state, or zero>

## [UNVERIFIED] residuals
<list any claims still tagged unverified, or "none">

## Out-of-scope findings
<filed in docs/APP_ISSUES_AUTO_FIX.md, not addressed in this PR>
```

3. **Do NOT push** to the remote unless the user explicitly asked. Same for any
   `gh pr create`. Surface that the work is ready locally; let the user decide.

---

## Item-specific notes

{{ITEM_SPECIFIC_NOTES}}

---

# End task prompt

When you have completed Phase 6 successfully, end with the literal sentence:

> Task **{{ITEM_ID}}** complete. Verification gates passed. PR description above. Awaiting user approval to push.

If at any point you stop and surface, end with:

> STOPPED at Phase <N>: <reason>. Awaiting user guidance.

Do not pad. Do not summarize unprompted. Do not propose follow-up work in the same
session. The contract ends here.
