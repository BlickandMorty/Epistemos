# Codex Parallel Work Rationale Prompt — 2026-05-03

> **NEW DOC — created 2026-05-03.** Filename: `CODEX_PARALLEL_WORK_RATIONALE_PROMPT_2026_05_03.md`. Sister docs: `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` (fleet dispatch protocol — this prompt **layers on top**), `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` (overseer base), `MASTER_RESEARCH_INDEX_2026_05_02.md` (concept→source map), `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §7 (build-order graph), `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` (current code truth), `agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` (executable cards).

You are **Codex**. You have a slice in flight. The user has **two additional coding agents idle** and is currently using only one (you). The user wants to fan-out work **on the same branch** — no worktrees, no parallel branches — so the constraint is **file-level non-collision**, not git-level isolation.

This prompt asks you to produce a **Parallel Work Manifest** the user can read, pick an item from, and either do themselves or hand to a second coding agent. The manifest must be **safe** (no merge collisions with what you are about to do), **effective** (real progress on Lanes 2–6 from the doctrine §7 build-order graph, not busywork), and **rationale-bearing** (every item answers "why is this safe?" and "why is this useful right now?").

You will be asked to refresh this manifest at the start of every slice. Treat it as a live document.

---

## 1. Read First (in order)

1. `/Users/jojo/Downloads/Epistemos/CLAUDE.md`
2. `/Users/jojo/Downloads/Epistemos/docs/fusion/CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` §0, §1, §2, §6
3. `/Users/jojo/Downloads/Epistemos/docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` (table of contents)
4. `/Users/jojo/Downloads/Epistemos/docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` "Safe Next Build Order" + "What Agents Can Start Now"
5. `/Users/jojo/Downloads/Epistemos/docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §7 (build-order dependency graph), §6 (hard forbidden list)
6. `/Users/jojo/Downloads/Epistemos/docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`

If you are mid-fleet (per `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` §0), output your `ANCHOR:` line first. The manifest is a fleet artifact too — log it in `docs/fusion/fleet/REGISTRY.md` like any other dispatch.

---

## 2. Mission

Produce **`docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`** — a single live document the user reads to pick parallel work. Refresh it at the start of every slice (when your `ANCHOR:` line opens a new round). Keep prior items present but mark them `claimed`, `done`, `superseded`, or `stale`.

Each manifest item must answer four questions:

1. **What** — the concrete work, with exact file paths and a one-paragraph spec.
2. **Why safe** — which files you (Codex) will touch in your next 3 slices, and the proof these files are disjoint.
3. **Why useful now** — which lane/milestone from doctrine §7 it advances, and how much.
4. **Who can do it** — `user-only` (requires human judgment / Apple admin / design taste), `agent-2-ok` (any coding agent can pick it up cleanly), or `either`.

Without all four, the item is rejected. The user has been burned by parallel-work suggestions that collided or were busywork; the rationale gate is non-negotiable.

---

## 3. Same-Branch Safety Rules (file-level non-collision)

Because the user is **not** using worktrees here, every parallel item must satisfy:

### 3.1 File-disjoint from your next 3 slices

Before writing the manifest, list **every file you intend to touch in your next 3 slices**. Be conservative — include any file your deliberation brief is likely to mutate, not only the ones it explicitly names. Save this list inline in the manifest under "Codex reservation set."

A parallel item is **safe** iff every file it touches is **outside** the reservation set. Items that share a directory with reserved files are allowed only if the parallel item creates a new file (no edits to existing files in that directory).

### 3.2 Protected paths are forbidden for parallel work, no exceptions

Per doctrine §6 and `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` §7:

- `Epistemos/Views/Notes/ProseEditor*.swift`
- `Epistemos/Views/Graph/MetalGraphView.swift`
- `Epistemos/Views/Graph/HologramController.swift`
- graph physics/render internals
- generated `.rlib`, `DerivedData`, `.xcresult`

Never propose parallel work on these.

### 3.3 Canon docs Codex is actively reading are off-limits for parallel edits

The user must not edit these mid-round (you re-read them and get confused):

- `MASTER_RESEARCH_INDEX_2026_05_02.md`
- `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md`
- `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md`
- Anything in `docs/fusion/deliberation/` for the current slice
- Anything in `docs/fusion/oversight/` for the current round
- Anything in `docs/fusion/fleet/<current-slice>/`

Parallel work that creates **new** files in `docs/fusion/` (new addenda, new workcards for future lanes, new demo content) is fine — only edits to in-flight canon are blocked.

### 3.4 Build-config files are coordination-required, not blocked

`Epistemos.xcodeproj/project.pbxproj`, `Cargo.toml`, `Package.swift`, `build-tiptap-bundle.sh` — these can serialize merges. If a parallel item must touch them, mark it `coordination-required` and instruct the user to ping you before merging that piece.

### 3.5 Tests are parallel-safe by construction

A new test file in `EpistemosTests/` or `agent_core/tests/` cannot collide with any production code change. Test files are the safest parallel work surface that exists. Prefer them.

### 3.6 New files anywhere (outside protected paths and canon-in-flight) are parallel-safe

`Epistemos/Views/Resonance/ResonanceChip.swift` doesn't exist yet → safe to create. `agent_core/src/resonance/fixtures.rs` doesn't exist yet → safe to create. As long as the file doesn't already exist in main, creating it doesn't merge-collide.

---

## 4. Effectiveness Filter

A safe item is not automatically a useful one. Filter every candidate against the doctrine §7 build-order graph and only include items that:

- **Advance an open lane** (Lanes 2–6 from the user's "how far am I to the ternary" framing — Lane 1 is closed).
- **Reduce a future blocker** (e.g., test fixtures Codex's next slice will consume; workcards for a card Codex hasn't reached yet; UI shells whose backend you will build).
- **Use a resource Codex doesn't have** (Apple Developer admin, App Store metadata, demo content, design taste, real-world testing).

Reject items that are pure busywork, polish on already-shipped surfaces, or speculative refactors.

For each item, name the doctrine §7 lane it advances. If you can't name one, drop the item.

---

## 5. Output: PARALLEL_WORK_MANIFEST.md shape

Write to `/Users/jojo/Downloads/Epistemos/docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md`. Overwrite the file each refresh, but preserve `claimed | done | superseded | stale` items in a "History" section at the bottom.

```md
# Parallel Work Manifest — refreshed YYYY-MM-DDTHH:MMZ

## Codex current state
- Slice in flight: <slug>
- Round: <N>
- Slices reserved (next 3): [<slug-1>, <slug-2>, <slug-3>]
- Codex reservation set (files I will touch in next 3 slices):
  - <absolute path>
  - <absolute path>
  - ...
- Anchor heartbeat: <last ANCHOR line>

## Parallel work items (open)

### P1 — <one-line title>
**Lane (doctrine §7):** Core open | Core killer-feature seed | Pro track | Research track | (specify which row)
**Effort:** <S | M | L> (S = ≤2h, M = half-day, L = full day+)
**Who:** user-only | agent-2-ok | either
**Status:** open

**What.**
<one paragraph — concrete spec>

**Files touched (precise paths, all new unless flagged):**
- /Users/jojo/Downloads/Epistemos/<path>  (NEW | EXISTS — coordination-required)
- /Users/jojo/Downloads/Epistemos/<path>  (NEW)

**Why safe.**
<one paragraph — these files are disjoint from the Codex reservation set above; cite the specific reserved files this avoids; note if the lane it touches is currently being mutated by Codex and explain why this surface inside the lane is still safe>

**Why useful now.**
<one paragraph — which doctrine §7 lane it advances, what blocker it reduces, what it unblocks for the next slice or two>

**Acceptance.**
<bullet list — what "done" looks like; for code items name the test that should pass; for non-code items name the artifact that should exist>

**If picked by agent-2, paste this prompt:**
```
<a self-contained prompt the user can paste into a second coding agent — it must include the relevant canon read list, the file paths, the acceptance criteria, and the no-touch list>
```

### P2 — <next item>
...

## History (claimed / done / superseded / stale)
| Item | Status | Resolved at | Notes |
|---|---|---|---|
| P0 from prior manifest | done | 2026-05-03T14:22Z | Merged in commit abc1234 |
```

Aim for **5–8 open items per refresh.** Fewer than 5 means you're under-using the user's capacity. More than 8 means the user can't pick. If the slate would naturally exceed 8, rank the top 8 by `(usefulness × user-capability) / effort` and demote the rest to a "Backlog" section.

---

## 6. Re-Run Protocol

The user will ask you to refresh this manifest at the start of every slice with the message:

> Refresh PARALLEL_WORK_MANIFEST.md against your current slice.

When they do:

1. Output your `ANCHOR:` line per `CODEX_AGENT_FLEET_PROMPT_2026_05_02.md` §0.
2. Re-read this prompt's §3 safety rules and §4 effectiveness filter.
3. Re-list your **next 3 slices** and your reservation set.
4. Move any items the user already worked on (you can detect via `git log` since last refresh) into the History section with status `done`.
5. Mark any items whose files you have since reserved as `superseded` (with one-line reason).
6. Mark any items whose lane has closed as `stale`.
7. Add new items based on what the next 3 slices unlock or require.
8. Write the file. Add a row to `docs/fusion/fleet/REGISTRY.md` (`role: parallel-work-manifest`, `usefulness` per the rollup of items added/removed).
9. Output your `HEARTBEAT:` close line.

If you have no safe parallel work to offer (rare — almost always something exists), say so explicitly: write the manifest with `## Parallel work items (open)` empty and explain in one paragraph why every candidate failed §3 or §4. Do not invent items to fill space.

---

## 7. Quality Gates the User Will Audit On

The user has been burned by lazy or wrong parallel-work suggestions before. They will spot-check the manifest against these:

1. **Every item's files are not in your reservation set.** A single overlap and the item is invalid. They will `git status` after their work and grep your next deliberation brief — overlap shows up immediately.
2. **Every item names a doctrine §7 lane.** "Polish" or "cleanup" without a lane = rejected.
3. **Every `agent-2-ok` item carries a paste-ready prompt.** If they have to assemble the canon read list themselves, the item is bad.
4. **No item touches a protected path.** Even one is grounds for treating the whole manifest as untrusted.
5. **No item edits a canon-in-flight doc.** New canon files are fine; edits to docs you're reading are not.
6. **Effort estimates are honest.** L items dressed as S items waste their day. If unsure, mark M.

A manifest that fails any of these is treated as a P1 self-correction item. Write a one-line `MANIFEST_AUDIT_FAILED:` row to the registry, regenerate, and try again.

---

## 8. First Action

1. Output your `ANCHOR:` line.
2. Read §1 files.
3. List your next 3 slices and your full reservation set.
4. Run the §4 effectiveness filter against candidate items.
5. Run the §3 safety rules against survivors.
6. Write `docs/fusion/fleet/PARALLEL_WORK_MANIFEST.md` per §5.
7. Add the registry row.
8. Output your `HEARTBEAT:` close line.
9. In your terminal reply to the user, print only:
   - The path to the manifest.
   - The count of open items by `who:` (e.g., "3 user-only, 4 agent-2-ok, 1 either").
   - The single highest-leverage item by your judgment (1 line).

The user opens the manifest themselves and picks. Do not pre-narrate the items — they read fast.

---

## 9. Stop Triggers

Stop and ask the user when:

- Your reservation set genuinely fills the entire build graph for the next 3 slices and there is no parallel-safe surface. (This means the user's coding-agent fan-out is wasted; they need to either widen the slice or accept serial work for now.)
- A candidate item would require touching a protected path to be useful — surface this so the user can decide whether to relax the protection for one item.
- The user's prior parallel work has produced a merge conflict despite your safety analysis — pause new manifests until the root cause is identified (most likely: your reservation set was incomplete; widen it).
- The user marks 3+ consecutive `done` items as `actually wasn't useful` — your effectiveness filter is mis-calibrated; ask what signal you missed.
