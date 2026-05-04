# N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer

You are a Claude Code session implementing **N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer** for the
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
3. `/Users/jojo/Downloads/Epistemos/docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md` — the contract you are bound by. Pay special attention to §4.7 (WRV gate) — N1 lives or dies by this.
4. `/Users/jojo/Downloads/Epistemos/docs/plan/01_DOCTRINE.md` — the fifth-position rulings. §6 #14 (no orphan scaffolding) is the rule N1 was conceived to honor.
5. `/Users/jojo/Downloads/Epistemos/docs/plan/02_BUILD_MATRIX.md` — Pro vs MAS gating. N1 ships in both targets.
6. `/Users/jojo/Downloads/Epistemos/docs/plan/03_EXECUTION_MAP.md` — the per-item entry for **N1** (anchor `#n1--prompt-tree-jspf--ptf--structureregistry-driven-prompt-composer`).
7. `/Users/jojo/Downloads/Epistemos/docs/plan/04_PHASES.md` — parallel-track entry/exit gates. N1 is parallel; it doesn't block any Phase 0–3 deliverable.
8. `/Users/jojo/Downloads/Epistemos/docs/plan/05_RESEARCH_INDEX.md` — every entry tagged for N1.

**Item-specific reads (also mandatory, after the above):**

- `/Users/jojo/Downloads/Epistemos/docs/STRUCTURING_AUDIT.md` — every input surface in the app. N1's composer validates against this catalog. Sections "Architecture invariants" and "Self-introspection" are load-bearing.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/StructureRegistry.swift` — the registry N1 extends with prompt-shape descriptors.
- `/Users/jojo/Downloads/Epistemos/agent_core/src/agent_loop.rs` — the existing prompt-assembly path. Understand it before replacing it. Do NOT delete it in this PR — both paths must coexist behind a feature flag.
- `/Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift` — the WRV anchor for N1. The first agent turn here MUST use the new composer end-to-end. If the composer ships without this wire, the PR fails the WRV gate.
- `/Users/jojo/Downloads/Epistemos/agent_core/src/prompt_caching.rs` — existing prompt-cache call sites for Anthropic. N1's `PromptCache.hints(for:)` must integrate with whatever's already wired here.
- `/Users/jojo/Downloads/Epistemos/Epistemos/Engine/AFMSessionPool.swift` — AFM `@Generable` is one of the four render targets. Understand the session-pool shape before adding the AFM render.

For each research file, quote at least one specific passage in your output that is
load-bearing for N1. This is your evidence the read happened.

**WebFetch mandates (verify current as of Apr 2026):**

- https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching — verify: 90 % discount on cached portions, 5-min TTL, 1024-token minimum, 4-breakpoint cap, `cache_control` syntax. If any of these have changed, surface to user before proceeding.
- https://platform.openai.com/docs/api-reference/responses (or current OpenAI Responses API URL) — verify: OpenAI's prompt caching mechanic (different from Anthropic; mostly automatic).

---

## Phase 2 — Verify the codebase (auto-research mandate)

Before asserting any file path, line number, function signature, or library version,
verify it. Use `Read`, `Grep`, or `Bash` (`find`, `wc`, `cargo tree`).

Specifically: the entry for **N1** in `03_EXECUTION_MAP.md` lists "Files to
touch (verified)" with line numbers. Those line numbers were verified at plan
authoring time but the file may have changed. **Re-verify each one** before treating
it as canonical.

If a path or line number has drifted: STOP and surface to the user (per
`00_AUTHORITY_AND_ANTI_DRIFT.md §5`). Do not silently rebase your work on the new
location — confirm with the user that the rebased target is still right.

---

## Phase 3 — Restate the task back

After Phase 1 and Phase 2, output this:

```
TASK CONTRACT
=============
Item: N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer
Phase: parallel
Targets: Both
Risk: Med

Files I will modify (verified above):
- (NEW) Epistemos/Engine/PromptTree.swift
- (NEW) Epistemos/Engine/PromptRenderer.swift
- (NEW) Epistemos/Engine/PromptCache.swift
- (NEW) Epistemos/Engine/PromptTreePersister.swift
- (MODIFY) Epistemos/App/ChatCoordinator.swift — wire first agent turn through PromptComposer.compose
- (MODIFY) Epistemos/Engine/StructureRegistry.swift — extend with prompt-shape descriptors
- (NEW) docs/PROMPT_AS_DATA_SPEC.md
- (NEW) EpistemosTests/PromptTreeTests.swift

Tests that must stay green:
- Existing chat / agent loop tests (`ChatCoordinatorTests`, `StreamingDelegateTests`)
- `swift test` 2,679-test floor
- New `PromptTreeTests` covering: composition, schema validation, cache-hint generation, per-provider rendering, PTF round-trip

Telemetry surface I will create:
- "Prompt shape" inspector in TraceInspectorView (DEBUG only initially)
- `cached_tokens_share` counter in `SessionInsight` (visible in cost dashboard W9.6)
- PTF directory browsable from Finder at `<vault>/.epistemos/prompts/<session>/<turn>/`

Definition of done (paraphrased from 03_EXECUTION_MAP.md):
- [ ] `Prompt` + `PromptNode` types with full Codable + Hashable conformance
- [ ] `PromptComposer.compose(...)` produces a typed `Prompt` from inputs
- [ ] `PromptRenderer` renders identical `Prompt` to Anthropic Messages, OpenAI Responses, AFM @Generable, MLX local-grammar
- [ ] `PromptCache.hints(for: Prompt)` returns `cache_control` markers; capped at Anthropic's 4-breakpoint limit
- [ ] PTF persistence writes to `<vault>/.epistemos/prompts/<session>/<turn>/` and round-trips cleanly
- [ ] WRV proof: ChatCoordinator first agent turn uses the composer; cached_tokens_share > 0 % after second turn
- [ ] StructureRegistry extended with at least 4 prompt-shape entries
- [ ] docs/PROMPT_AS_DATA_SPEC.md written; format spec + extension rules + provider compat matrix
- [ ] Both legacy and new paths coexist behind feature flag (`EPISTEMOS_PROMPT_TREE=1`)
- [ ] Unit tests pass; build green on both MAS and Pro targets

WRV plan (per 00_AUTHORITY_AND_ANTI_DRIFT.md §4.7):
- WIRED — ChatCoordinator first agent turn calls PromptComposer.compose; verify with:
         grep -rn 'PromptComposer.compose' Epistemos/App/ChatCoordinator.swift
- REACHABLE — User gesture: open Epistemos → start a new chat → send any message →
         the new code path runs (turn 1 fills the cache; turn 2 hits the cache)
- VISIBLE — User sees `cached_tokens_share` row in Settings → Agent → Spend showing
         the % of tokens served from cache. Also: TraceInspector "Prompt shape" tab
         shows the rendered tree for the most recent turn (DEBUG only).

Pre-flight reads complete: yes
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

**Implementation order** (follow exactly — each step is a checkpoint where you
should be able to build green):

1. **PromptTree types** (`Epistemos/Engine/PromptTree.swift`)
   - `Prompt` struct with the 8 canonical fields (version, id, identity, tools, memory, task, constraints, output_schema, cache_hints)
   - Sub-types: `IdentitySection`, `ToolSpec`, `MemorySection`, `TaskSection`, `ConstraintSection`, `OutputSchema`, `CacheHints`
   - Full `Codable + Sendable + Hashable` conformance
   - `PromptComposer` struct with `compose(...)` static factories per use case (chat turn, summarize note, search expand, etc.)
   - At least one composer for ChatCoordinator's needs

2. **PromptRenderer** (`Epistemos/Engine/PromptRenderer.swift`)
   - `enum RenderTarget { case anthropicMessages, openAIResponses, afmGenerable, mlxLocalGrammar }`
   - `PromptRenderer.render(_ prompt: Prompt, target: RenderTarget) -> RenderedPrompt`
   - Each target gets its own private rendering function. AFM @Generable is special — returns a Swift type, not bytes. Make `RenderedPrompt` an enum that captures both.
   - Round-trip property: `renderToAnthropic(prompt) → parse → equals prompt` (as much as the lossy provider format allows)

3. **PromptCache** (`Epistemos/Engine/PromptCache.swift`)
   - `PromptCache.hints(for: Prompt) -> [CacheBreakpoint]`
   - 4-breakpoint cap per Anthropic; pick the 4 stablest subtrees (identity, tools, ontology, output_schema) by default
   - Degrade silently for OpenAI / AFM / MLX (no-op return)
   - Track measured hit rate per session; if < 30 % after 5 turns, log a warning so the user knows their cache strategy isn't working

4. **PromptTreePersister** (`Epistemos/Engine/PromptTreePersister.swift`)
   - `persist(_ prompt: Prompt, sessionID: String, turnIndex: Int, vaultRoot: URL)`
   - Writes to `<vaultRoot>/.epistemos/prompts/<sessionID>/<turnIndex>/`
   - One JSON file per top-level field (identity.json, tools.json, etc.)
   - GC policy: keep last N=20 turns per session via NightBrain (file + scheduled job)

5. **StructureRegistry extension** — add at least 4 prompt-shape descriptors to `canonicalSchemas` in `Epistemos/Engine/StructureRegistry.swift`. Each descriptor maps a prompt subtree to its Swift type.

6. **ChatCoordinator wire** (`Epistemos/App/ChatCoordinator.swift`) — gate behind `EPISTEMOS_PROMPT_TREE=1` env var (or Settings → Agent → Advanced toggle if you prefer). When enabled, the first agent turn:
   - Composes a `Prompt` via `PromptComposer.compose(forChatTurn: ...)`
   - Persists via `PromptTreePersister.persist`
   - Renders via `PromptRenderer.render(...)` for the active provider
   - Sends through the existing transport (don't re-implement networking)
   - Records `cached_tokens_share` via the existing `SessionInsight` record path (already wired to W9.6 cost dashboard)

7. **Tests** — `EpistemosTests/PromptTreeTests.swift`:
   - `compose_includesAllRequiredSections`
   - `renderAnthropic_includesCacheControl`
   - `renderOpenAI_omitsCacheControl`
   - `renderAFM_returnsGenerableType`
   - `cacheHints_capsAtFour`
   - `cacheHints_picksStablestSubtrees`
   - `persist_writesPTFRoundTrip`
   - `structureRegistry_includesNewPromptSchemas`

8. **Docs** — `docs/PROMPT_AS_DATA_SPEC.md`:
   - Section 1: JSPF format (Swift types + JSON Schema mirror)
   - Section 2: PTF directory layout + GC rules
   - Section 3: Cache-hint heuristics
   - Section 4: Provider compat matrix (Anthropic / OpenAI / AFM / MLX local — what each supports)
   - Section 5: How to add a new prompt subtree
   - Section 6: Migration plan (legacy path → composer)

**Hard rules during implementation:**

- No scope creep. Per `01_DOCTRINE.md §6 #14`, this PR ships the foundation + ONE wired call site (ChatCoordinator first agent turn). Don't migrate other call sites in the same PR — that's a follow-up.
- No forbidden actions. No `try!`, no force unwraps, no `print()` in production paths.
- Telemetry surface is part of the implementation, not an afterthought.
- Memory budget per `00_AUTHORITY_AND_ANTI_DRIFT.md §8` (6 GB realtime). PTF on disk is tiny (KB per turn) but you should still GC.
- **Whenever you encounter a new term, library, version, API, or file path that is
  not verified in your context: STOP and verify before continuing.**

---

## Phase 5 — Verify

Run all SEVEN verification gates from `00_AUTHORITY_AND_ANTI_DRIFT.md §4`,
including the WRV gate from §4.7:

1. **Build green:**
   ```bash
   xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
   ```

2. **Test floor preserved:**
   ```bash
   swift test
   cargo test --manifest-path agent_core/Cargo.toml
   ```

3. **Lint clean:**
   ```bash
   swiftlint
   ```

4. **No-silent-behavior audit:** the new prompt-cache hit rate is visible in cost dashboard. The PTF directory is browsable from Finder. The TraceInspector has a Prompt shape tab. Document each before claiming done.

5. **Definition of done:** every checkbox above has a one-line proof.

6. **WRV gate — execute the proof:**
   - **W (Wired):**
     ```bash
     grep -rn 'PromptComposer.compose' /Users/jojo/Downloads/Epistemos/Epistemos/App/ChatCoordinator.swift
     ```
     Expected: at least one match in production code (not test, not scaffold).
   - **R (Reachable):** Walk through these gestures from a fresh launch:
     1. Open Epistemos
     2. Settings → Agent → Advanced → toggle "Prompt Tree (Beta)" on (or set `EPISTEMOS_PROMPT_TREE=1` env var)
     3. New chat → send "hello"
     4. New chat → send another message in the same session
     5. Settings → Agent → Spend → observe `cached_tokens_share` row showing > 0%
   - **V (Visible):** confirm the cached_tokens_share row renders the new value, not just a placeholder. If you can't launch the app, document the screenshot path that proves it.

7. **Update `docs/AGENT_PROGRESS.md`:** ONLY after all gates including WRV pass.

---

## Phase 6 — Output

Your final output for the task is:

1. **The diff itself** (don't summarize the diff — the user will read it via `git diff`).
2. **A PR description** in this format:

```markdown
## Summary
- Lock in JSPF + PTF prompt-as-data foundation (Prompt, PromptComposer, PromptRenderer, PromptCache, PromptTreePersister)
- Wire ChatCoordinator first agent turn to use it (WRV anchor)
- Extend StructureRegistry with 4 prompt-shape descriptors
- New docs/PROMPT_AS_DATA_SPEC.md format spec

## Items
- N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer

## Doctrine alignment
- 01_DOCTRINE.md §6 #1 (no silent behavior — every prompt audit-able), §6 #14 (no orphan scaffolding — N1 ships with one fully-wired call site or it doesn't ship), §2.5 (cognition layer = one substrate with read-only projections), §6 #5 (no silent fallback)
- 02_BUILD_MATRIX.md both targets
- 03_EXECUTION_MAP.md `#n1--prompt-tree-jspf--ptf--structureregistry-driven-prompt-composer`

## Research consulted
- docs/STRUCTURING_AUDIT.md
- Anthropic prompt cache docs (verified Apr 2026)
- agent_core/src/agent_loop.rs + prompt_caching.rs (existing path)
- AFMSessionPool.swift (AFM render target)

## Tests
- Pre-existing tests still green: yes (X tests passed)
- New tests added: PromptTreeTests (8 tests)

## Telemetry surface
- cached_tokens_share row in Settings → Agent → Spend
- TraceInspector "Prompt shape" tab (DEBUG only)
- PTF directory at <vault>/.epistemos/prompts/<session>/<turn>/

## WRV proof
- WIRED: `grep -rn 'PromptComposer.compose' Epistemos/App/ChatCoordinator.swift` → ChatCoordinator.swift:<line> calls PromptComposer.compose(forChatTurn: ...)
- REACHABLE: Settings → Agent → Advanced → toggle "Prompt Tree (Beta)" → start new chat → send 2 messages → cache hit visible
- VISIBLE: cached_tokens_share row shows > 0% after second turn

## Memory budget delta
+<X MB steady-state> (PTF on disk, in-memory composer state)

## [UNVERIFIED] residuals
<list any claims still tagged unverified, or "none">

## Out-of-scope findings
<filed in docs/APP_ISSUES_AUTO_FIX.md, not addressed in this PR>
```

3. **Do NOT push** to the remote unless the user explicitly asked. Same for any
   `gh pr create`. Surface that the work is ready locally; let the user decide.

---

## Item-specific notes

**The point of N1.** This was conceived specifically as a counter-pattern to
"AI scaffolds without wiring." If you build the foundation and stop short of
the ChatCoordinator wire, the PR is dead on arrival. The wire is the WRV proof.
The wire is the point.

**Don't migrate every call site in this PR.** Only the first ChatCoordinator agent
turn. Other prompt-assembly call sites (LocalAgentLoop, SubconsciousService,
NightBrain) get their own follow-up PRs after this one ships and bakes for a week.

**Feature flag is mandatory.** Both paths coexist. Users on the legacy path see
no change. Users with `EPISTEMOS_PROMPT_TREE=1` (or the Settings toggle) get the
new path. After 2 weeks of bake time + telemetry showing > 30% cache hit rate
without quality regressions, the flag flips default-on; legacy path is removed
in a separate cleanup PR.

**Cache-hit rate is the success metric.** If `cached_tokens_share` doesn't move
above 30 % after a few real chat sessions, the cache hints are wrong. Tune them
before claiming done.

**StructureRegistry is the introspection layer.** The local LLM should be able
to ask "what shapes do you send?" and get a real answer. Make the new prompt
descriptors first-class registry entries.

**Pro/MAS separation:** the composer + renderer are pure Swift, no Pro-only deps.
The PTF directory uses the existing vault root (already gated through security-
scoped bookmarks in MAS). No bleed.

---

# End task prompt

When you have completed Phase 6 successfully, end with the literal sentence:

> Task **N1** complete. Verification gates passed. PR description above. Awaiting user approval to push.

If at any point you stop and surface, end with:

> STOPPED at Phase <N>: <reason>. Awaiting user guidance.

Do not pad. Do not summarize unprompted. Do not propose follow-up work in the same
session. The contract ends here.
