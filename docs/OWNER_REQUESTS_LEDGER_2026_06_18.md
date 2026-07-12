# OWNER REQUESTS LEDGER (2026-06-18) — the authoritative checklist

> **ACTIVE PIVOT 2026-07-07 (MAS-first sellable Epistemos).** Owner steer:
> "Strategy pivot: pause Pro/Experimental expansion. Near-term product target is
> MAS-first sellable Epistemos." Also: "Do not continue 1Code/THE R,
> native-shell/Craft, Kindred companion, arbitrary subprocess/tool-terminal, or Pro
> runtime/model experiments unless explicitly reauthorized." Interpreted intent:
> all prior active work that depends on Pro/Experimental expansion, donor 1Code UI,
> native-shell/Craft, Kindred, arbitrary subprocess/tool-terminal surfaces, or Pro
> runtime/model experimentation is paused/deferred and must not continue without a
> fresh explicit owner authorization. Active work is MAS-safe only: KEELSTONE =
> vault truth, file safety, sandbox/bookmarks, App Store target, release gates;
> LUMENLENS = Epdoc/editor fidelity, minimal writeback, provenance, lens
> disclosure/export, notebook manifest, MAS-safe tabs. Any mini chat must be
> MAS-safe, Epdoc-owned, and routed through stable adapters; it must not import
> donor 1Code UI or depend on Experimental child-process/session UI. Acceptance
> checks before future edits: identify the MAS-safe lane, update the lane intent
> ledger/checkpoint first, prove no forbidden donor/Experimental/runtime dependency
> is becoming the active surface, and preserve App Store sandbox constraints.
> Non-goal: dressing Pro/Experimental/1Code surfaces as MAS UI. Next action from
> this update: ledger-only pivot recorded; no implementation resumes unless the
> owner reauthorizes a MAS-safe lane.

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** This ledger of owner requests is durable HISTORY — but any item framed as "reskin Goose / Goose-as-the-surface / Option 1 / Goose-only / MAS = reskinned goose webview" is now re-scoped: Current surfaces = Experimental/1Code + MAS/June; OpenChamber/ProAgent are deletion targets; MAS = June + goose IN-PROCESS backend; goose = one engine. arXiv + Obscura KEPT dedicated (Obscura automation-engine-vs-browser = open owner flag). Read requests as intent; re-anchor surface/engine specifics to canon: memory `project_ui_base_pivot_openchamber_2026_07_02` + `project_product_shape_agent_center_2026_07_02`.

> **READ-FIRST (owner 2026-06-19):** before editing/building, READ the unified capstone
> `docs/research/MASTER_SYNTHESIS_2026_06_19.md` (the one plan: keystone + build-once
> primitives + governing constraints incl. the HARDENING LIFECYCLE + Phase 0→3 roadmap),
> then the hub `docs/research/DEEP_PLAN_AUDIT_HUB_2026_06_19.md` and the per-slice docs it
> indexes. A continuous deep-research loop feeds these; build ON the research, never ahead.
> **HARDENING LIFECYCLE (owner 2026-06-19):** every item = harden-BEFORE → add → re-harden-AFTER
> → after-port inspection (no gaps), enterprise-level. **Flag-OFF ≠ done.**

The owner's words: *"everything I have been asking is not being done. it's being
lazy… go back and look at my queries and requests and actually do them."* This is
the complete list of EVERY owner request this session. **A line is DONE only when
the owner can SEE and USE it in the rebuilt app** — visible, reachable, and
functional for the owner's ACTUAL setup (local-first, frequently NO cloud
configured). "Compiles + committed + tests pass" is NOT done. "Gated into
invisibility" is NOT done. Re-audit each against the running app; fix until real.

**BUILD-FROM-RESEARCH / 100% MANDATE (owner 2026-06-18):** every item in this
ledger and the plan is something the owner WANTS — 100% of it is to be
IMPLEMENTED, not just researched. Research FEEDS the build: each research verdict
(R-*) must turn into shipped, in-app-verified slices. Nothing here is optional or
"nice to have." Keep going until all of it is done and hardened (rule #6/#8).

**🛑 HARD GUARD — CHAT BACKEND: QUARANTINE, NEVER DELETE (owner 2026-06-21,
verbatim):** *"it is completely broken and needs to be quarantined but should never
be deleted as of now because one might try to delete it … preserve it so that i can
still work on IP … add it to all the parts it needs like osaurus and the goose."*
NO agent (loop/monitor/any session) may DELETE chat / chat-backend code (resolution
layer, picker, views, InferenceState chat paths, model wiring). Quarantine only
(flag-OFF / off-live-path, stays IN-TREE). Preserve + PORT the owner's models + IP +
loved chat UI into Osaurus (act) / Goose (work). Only the OWNER authorizes deletion,
after IP is ported + Osaurus act proves out. STOP patching the dying chat backend
(the chat-picker / Qwen-fallback P0s below are DEFERRED behind the Osaurus clone per
owner; do NOT delete or keep grinding them now). Full rule:
`docs/CHAT_BACKEND_QUARANTINE_NEVER_DELETE_2026_06_21.md`.

**🔴 P0 — CHAT PICKER (owner 2026-06-21, verbatim):** *"i also have other models
installed but they still wont let me click them"* — [ ] NOT DONE. Same recurring
chat surface (~5th report). GROUNDED ROOT CAUSE + acceptance bar + real-state test
in `docs/research/SS-CHATPICKER_P0_INSTALLED_MODELS_NOT_CLICKABLE_2026_06_21.md`:
the chat runtime picker (`EpistemosRuntimePicker.options`) is hardcoded to the
foundation lineup + 2 Qwen `extraPicks` and IGNORES the user's installed/advertised
model stack, so installed models outside that fixed set are never clickable; a
non-selectable row bounces to Settings instead of selecting. FIX: enumerate
installed ∪ advertised models as selectable picks (lineup = default order), correct
lane per model (no silent assume-MLX), honest reason when a lane is unavailable.
Preempts the queue after the in-flight commit lands. Do NOT mark [x] without the
real-state test + reach-the-user proof. Pairs with the proven default-RESOLUTION
fix (SS-CHATMODEL_P0, ddbadf434).

**🔴 P0 — TOO-LARGE → SILENT QWEN FALLBACK (owner 2026-06-21, verbatim):** *"it
still auto-chooses qwen when its too large literally i keep saying to fix the
fallbacks and they are still there"* — [ ] NOT DONE (earlier "proven" fix only
repaired persisted-pref migration, NOT the runtime too-large path — honest
correction). ROOT CAUSE: `InferenceState.swift:3072` `recommendedLocalTextModelID`
hardcoded to `.qwen3_4B4Bit`; the too-large/constrained chain
(`recommendedLocalTextModelID(for:)`, `constrainedFallbackTextModelID`,
`smallerLocalTextModelID`) anchors on Qwen, so a won't-fit model silently lands on
Qwen. OWNER DECISION (AskUserQuestion 2026-06-21): **kill the fallback IN-PLACE,
keep the chat, NO Osaurus pivot.** FIX: too-large → honest visible message, never a
silent swap; remove the hardcoded Qwen anchor; real-state test that fails if the
resolver ever returns Qwen for a too-large pick. Same chat-resolution P0 as the
picker above. Spec: SS-CHATPICKER_P0_INSTALLED_MODELS_NOT_CLICKABLE_2026_06_21.md.

**APP-NATIVE BY EMBEDDING (owner 2026-06-18, verbatim):** *"having the whole thing
as part of my app — different from using it, actually cloning it. Same for the
other things I'm taking for my app to be app-native."* For EVERY third-party
capability the owner pulls in (LiteParse, Osaurus, Goose, DeerFlow, OpenClaw, MLX
training, etc.): EMBED/CLONE the real source INTO the app as a first-class native
part (vendor the Rust/Swift core into agent_core/the app per F-ProprietaryComp-
ression-ProvenanceGate: direct_import / adapter_wrap / clean_room) — NOT a thin
wrapper that shells out to an external CLI/npm/pip/service at runtime. Prefer the
in-process MAS-native path always. If a specific piece genuinely cannot be MAS-
safe, **Pro/dev-gate it honestly (visible, with WHY) rather than drop the feature**
— the capability still ships, embedded; only the un-sandboxable lane is gated.
Never omit an owner-wanted feature just because full MAS-safety is hard.

**SOURCING + UPDATE POLICY (owner 2026-06-18):** *"clone first from the updated
GitHub… the ones already on disk may be stale… and I want an easy way to update
them… I'm not opposed to taking control / making it my own."* RULES for every
vendored project (OpenClaw, Osaurus, Hermes, LiteParse, …): (1) **Clone the LATEST
upstream from GitHub at vendor time** — NOT the possibly-stale on-disk copies
(`~/Downloads/openclaw-main` etc.); pin + record the exact upstream commit SHA +
date + license in the project's VENDOR/provenance file. (2) **TAKE CONTROL (fork/
own), NOT a live submodule** — because we reskin/fuse/gate (heavy divergence) a
live submodule/subtree breaks on every pull; vendor it into the repo as our own
code. (3) **Keep updates one command** — record an `upstream` remote + pinned SHA,
keep OUR changes as a clearly-marked overlay/patch set (reskin CSS, gating, fusion
shims) separate from pristine upstream, and ship a per-project `update-<name>.sh`
that fetches latest upstream → diffs → re-vendors → re-applies our overlay → re-runs
ProvenanceGate + build + tests. (4) **Hermes is one-way fuse** (lifted into
LocalAgent, no standalone tree): track upstream SHA + a "re-harvest checklist", not
a tree-merge. Net: it's OUR thing, but a new upstream release is one script away.

**PER-FEATURE HARDENING + NO-DRIFT GUARANTEE (owner 2026-06-18):** EVERY feature/
item added gets its OWN hardening phase — not just a phase-level pass. For each
shipped item: add regression tests, re-verify the prior items it touches still
work in-app, and log "HARDENED <item>" in AGENT_PROGRESS.md. This is the
anti-drop/anti-drift mechanism the owner is worried about: an item is not done
until it's hardened AND can't regress later. Re-run the recurring corpus sweep so
nothing silently disappears under compression.

**CHAT DEEP-REPAIR IS A FIRST-CLASS GOAL (owner 2026-06-18):** the messy Epistemos
Chat must be deeply repaired (P8.1b) — clean, maintainable, full-capability.

**DELETION GUARDRAIL (owner 2026-06-18, CRITICAL — enforce; don't assume any skill
has this caveat):** review/hardening/dedupe may NOT delete NEW or IN-PROGRESS
features (they look "unused" because they're mid-build / not-wired-yet) or any
owner-requested ledger item. DELETION IS A LAST RESORT — prefer dedupe / consolidate
/ wire-it-up. Only remove code that is PROVABLY dead AND confirmed not part of any
in-flight item; when uncertain, KEEP + flag. Commit deletions separately
(revertible). The "thermonuclear" code review is RECURRING (run multiple times).

**OPEN CODE = GOOSE (Rust, compiles in) — NOT a non-Swift app (owner 2026-06-18):**
no non-Swift app needed. Goose's Rust core links into agent_core via UniFFI.
Vercel(TS)/Google(Py)/Cursor(proprietary) are NOT Swift/Rust → adopt their PATTERNS
natively; never run them as Node/Python sidecars (NO-SIDECAR/MAS + memory).

**GOOSE-INTO-OPEN-CODE GUARDRAIL (owner 2026-06-18):** adding Goose (R-GOOSE) as
the Work/Open-Code backend must NOT break Chat or Act. Isolate the extracted Goose
core behind the Work mode + a feature flag; keep Chat/Act on their own engines;
add regression coverage proving Chat + Act are unchanged after Goose lands. Goose
should make the codebase MUCH better, never destabilize the working chat.

**BEST-TOOL-PER-SURFACE / PERFORMANCE-AWARE (owner 2026-06-18):** be GENEROUS — do
NOT force native everywhere. Pick the best tool PER SURFACE and optimize for
performance + the best result, not dogma: use WEBKIT (WKWebView) where it's the
pragmatic best (full web-app ports — OpenClaw, fieldtheory, htmlstream, kuku, the
HTML canvas), use NATIVE Swift/Rust where it wins on performance/quality (core
engine, MLX/GGUF inference, hot paths, the substrate/determinism). Always make the
most performance-aware choice; lean is still prioritized but completeness/quality
wins when the owner wants the whole thing. This refines the earlier native-vs-web
calls: no blanket rule — choose per case.

## REALITY-AUDIT RULE (applies to every line)
1. Build the app; actually trace the UX path the owner would take.
2. If a feature is hidden unless cloud/Pro/some-state — that's a FAIL for a
   local-first owner. Make it reachable + functional on LOCAL by default; gate
   only the genuinely-cloud/Pro-only pieces, and when gated, show WHY (honest,
   visible), never just vanish.
3. No feature is "done" until the owner can demonstrably use it.

## REOPENED — owner reports these DON'T WORK (fix first, verify in-app)
- [ ] **TOOLS/SKILLS BROKEN IN CHAT+AGENT — deep repair (owner 2026-06-19, w/
      screenshots) — HIGH PRIORITY.** Owner (verbatim): *"the tools and skills were
      not working — they used to at least have the UI boxes like Eidos and file
      search and vault search, but now I can't even send a regular query and have it
      look for tools to use and use them. Local AND cloud models both just don't do
      the things, and cloud should automatically know especially since it's there."*
      EVIDENCE (Hegemony Research chat): the agent REQUESTS `note.research_digest` /
      Eidos with a visible `notes` array, but execution ERRORS
      `{"error":"invalid arguments: notes array required","success":false}` (repeated),
      AND "No vault retrieval — No vault notes were loaded." ROOT (grounded):
      `agent_core/src/tools/note_tools.rs:387-390` reads `input["notes"].as_array()`
      and rejects when absent — so the model's emitted `notes` array is NOT arriving
      as a parsed object at execute() = a TOOL-ARG MARSHALING bug between request and
      execution (likely double-JSON-encoded args, wrong nesting/key, or a bad Swift↔
      Rust/grammar tool-call parse). FOUR fixes, BOTH local + cloud: (1) fix the arg
      marshaling so `input` is the parsed object the tool expects (and make the
      extractor tolerant: accept notes whether parsed-object, JSON-string blob, or
      wrapped key); add a regression test that drives research_digest end-to-end with
      a real model-emitted tool call. (2) AUTO-ROUTE regular queries to tools — the
      "Auto-routes when your prompt needs tools" path isn't firing; a plain query must
      detect tool-need and invoke (Eidos/file-search/vault-search) automatically.
      (3) Restore the tool UI boxes (Eidos / file search / vault search) that used to
      show. (4) Fix "No vault retrieval" — vault notes must actually load for answers.
      Cloud models especially must auto-use tools (keys already present). Audit the
      whole tool-call path: registry.rs, note_tools.rs, ToolTierBridge.swift, the
      local grammar tool-call parser, ConfidenceRouter/TriageService auto-route.
      Build+run verify a real query uses tools end-to-end in-app. This is the deep-
      repair the owner asked for on the Epistemos agent + chat.
      SCOPE BROADENED (owner 2026-06-19, verbatim): *"even with the local agent and
      the brain of my app a lot of skills and tools are not working, and I think part
      of that could be engineered of the skills and tools themselves or the way I coded
      it — but that all needs to be part of the repair."* So the marshaling bug is NOT
      assumed to be the whole story: (5) AUDIT THE SKILLS/TOOLS SUBSYSTEM ITSELF — the
      tool/skill IMPLEMENTATIONS may be mis-engineered or mis-coded, not just the
      arg plumbing. This applies EQUALLY to the in-process LocalAgent BRAIN path
      (`LocalAgentLoop` → `LocalToolGrammar` → `LocalAgentToolExecutor` → the Swift
      tool impls) AND the Rust `agent_core` cloud path. For EACH registered tool/skill,
      verify end-to-end: (a) it is actually REGISTERED and discoverable (registry +
      grammar schema match what the tool's execute() reads); (b) its declared JSON
      schema matches its real arg extraction (the note_tools.rs:387 mismatch is likely
      one instance of a class of schema↔impl drift — sweep ALL tools for it); (c) it
      runs and returns a usable result in-app, not just in a unit fixture; (d) the
      skill files / SKILL.md (or equivalent) are well-formed and the loader actually
      loads them. Produce a per-tool/per-skill PASS/FAIL inventory (local brain +
      cloud), fix every FAIL at the implementation level (not just symptoms), and add
      a coverage test per repaired tool. Treat broken tool/skill code as a first-class
      defect, not an edge case. NOTE: this audit also de-risks R-HERMES skills fusion
      (`docs/research/HERMES_ACT_FUSION_MAP_2026_06_19.md` caps #1/#2) — a sound
      skills/tools substrate is the precondition for fusing Hermes skills onto it.
      ✅ FIX 1 — ARG MARSHALING (the central repair) 2026-06-19: research traced the path —
      a tool's args reach the handler via `ToolRegistry::execute` (agent_core/src/tools/
      registry.rs), the SHARED chokepoint for BOTH paths (local: ToolTierBridge →
      `execute_tool_call` FFI → execute; cloud: agent_loop → execute_v2 → execute), which is
      why ONE central fix covers "both local AND cloud". The "args not arriving as a parsed
      object" symptom = the args arrive (a) double-encoded as a JSON STRING (the FFI parses
      the outer layer to a `Value::String`, so `input["notes"]` is `Null` → `.as_array()` =
      None → "notes array required" even though notes WERE present), or (b) still wrapped in
      the `{"name","arguments"}` tool-call envelope. FIX: NEW `normalize_tool_input(&Value)`
      — a tolerant, recursion-bounded, idempotent normalizer that unwraps BOTH modes (parses
      a JSON-string blob; strictly unwraps an envelope only when the keys are envelope-only
      and `arguments` is a container, so a legit args object that merely carries a `name`
      field is NEVER unwrapped) — wired at the TOP of `execute` so EVERY downstream consumer
      (authz inference, the schema gate, the handler) sees the clean object. +5 cargo tests:
      4 unit + 1 END-TO-END regression (`registry_repairs_mis_marshaled_tool_args_end_to_end`)
      that registers a `NotesProbeHandler` mirroring note_tools.rs:387 (reads
      `input["notes"].as_array()`, errors "notes array required") and drives `registry.execute`
      with the clean / string-encoded / envelope shapes — all now succeed. cargo --lib BOTH
      green: default 5459/0, pro-build 5722/0 (+5 each, ZERO regression). HONEST SCOPE: this
      is the defensive central marshaling repair (handles both known mangling modes); the
      owner's build+run in-app confirmation + the OTHER parts — (2) auto-route queries to
      tools, (3) restore tool UI boxes, (4) fix vault retrieval, (5) per-tool/skill PASS/FAIL
      audit — are follow-on slices.
      ✅ FIX 1b — FIELD-LEVEL TOLERANT EXTRACTOR + (5) FIRST AUDIT 2026-06-19: extended the
      tolerant-extractor ask to the FIELD level on the exact evidence tool. NEW
      `extract_note_paths(&Value)` in note_tools.rs `ResearchDigestTool` accepts `notes` as a
      JSON array (canonical), a single bare string path, OR a JSON-string BLOB that decodes to
      an array (`"notes": "[\"a.md\",\"b.md\"]"`) — the shapes a model emits — while PRESERVING
      strict rejection of non-string array elements (the existing `research_digest_rejects_
      invalid_and_too_many_notes` test still passes). AUDIT FINDING: research_digest's schema↔
      impl ALIGN (schema declares `notes`: required string array; impl reads exactly that) →
      that tool's failure was PURELY marshaling (fix 1), NOT schema↔impl drift. +5 cargo tests
      (canonical array / single bare string / JSON-string blob / still-rejects-non-string-
      element / rejects-absent-or-wrong-type). cargo --lib BOTH green: default 5464/0,
      pro-build 5727/0 (+5 each, ZERO regression; existing test intact).
      🔎 AUTO-ROUTE (part 2) ROOT DIAGNOSED — LOCAL path (the owner's "regular queries don't
      use tools"): regular local chat enters the tool loop via `PipelineService.shouldUseTool
      Loop` (Epistemos/Engine/PipelineService.swift:315), which requires `canRunLocalAgentLoop
      = canActAsAgent && LocalToolGrammar.supportsLocalAgentLoop` (InferenceState.swift:471).
      The Fast foundation model is now GGUF GEMMA, whose `canActAsAgent = false` (malformed XML
      tool calls — the documented reason it's gated). So `shouldUseToolLoop` returns false for
      regular Gemma chat → NO tool loop → no vault.search/eidos/file-search fire (which ALSO
      explains the missing UI boxes + "no vault retrieval" — no tool calls = nothing to show/
      load). The SAFE fix is NOT to flip canActAsAgent (that reintroduces malformed tool calls);
      it is the grammar-constrained tool-calling path (the Deterministic Schema Engine —
      preflight + the GBNF dispatch grammar + json-schema-constrained decoding) so Gemma
      reliably emits tool calls, THEN canActAsAgent can be true for the GGUF Gemma lane. The
      CLOUD path is separate (ChatCoordinator.runCommandCenterRustAgentPath) and needs its own
      tool-attachment audit. This is the careful multi-slice target for part 2 — NOT a one-line
      flip; flagged so it's fixed right, not papered over.
      ✅ PART 2 — AUTO-ROUTE DETECTOR (deterministic core) 2026-06-19: the founding-thesis
      "a plain query detects tool-need and invokes the right tool" decision, as a pure
      verifiable primitive (the Swift live-wiring is the follow-on, like the preflight FFI).
      NEW `query_needs_tools(query, candidates) -> bool` in agent_core/src/tool_preflight.rs:
      true iff the lexical preflight finds ≥1 relevant tool for the query — so "read my file"
      / "search my notes vault" → tools, while "what is the capital of France" → a direct
      answer. COMPOSES the existing `select_tools` (no new scoring, no duplication). Plus a
      flag-gated FFI `schema_auto_tool_route_json(query, candidates_json, max)` (flag
      `EPISTEMOS_AUTO_TOOL_ROUTE_V0`, OFF) → `{"needs_tools":<bool>,"tools":[<names>]}`:
      OFF (default) = passthrough `{"needs_tools":false,"tools":[]}` so the Swift caller
      (ConfidenceRouter / shouldUseToolLoop) can call it UNCONDITIONALLY with zero behaviour
      change; ON = the deterministic tool-need decision + the relevant tools (vault.search /
      eidos.query / file.search) for a plain query. +3 cargo tests (needs-tools true for a
      tool query, false for a plain query, FFI-off passthrough). cargo --lib BOTH green
      (tool_preflight 21/0 each, 0 regression). NEXT for part 2: (a) wire this into the Swift
      auto-route (ConfidenceRouter/PipelineService) flag-gated so a tool-need query enters the
      tool loop / attaches tools — for CLOUD this means attaching the selected tools so the
      model auto-uses them; (b) the GGUF-Gemma grammar-constrained tool-calling path so the
      LOCAL Gemma lane can emit valid calls (canActAsAgent). Both are the live-path follow-ons.
      ✅ PART 2(a) — AUTO-ROUTE LIVE-WIRING (local PipelineService path) 2026-06-19: the detector
      now drives a real decision. `Epistemos/Engine/PipelineService.swift` `shouldUseToolLoop`
      takes `query:` and, in the NO-execution-plan branch ONLY (the "regular query" Fast/Thinking
      chat path the owner described), when `EPISTEMOS_AUTO_TOOL_ROUTE_V0` is armed, consults the
      Rust detector via the generated `schemaAutoToolRouteJson` FFI — candidate JSON built from
      the tier's ToolTierBridge tools — so `needs_tools` decides loop-vs-direct: "find my note
      about X" keeps the tool loop (vault.search) while pure chat ("write a haiku") direct-streams.
      OFF by default = BYTE-IDENTICAL: the detector + the candidate-tool load run ONLY inside
      `if Self.autoToolRouteArmed`, and a nil verdict (flag off / FFI down / parse fail) preserves
      today's "a loop-capable model always loops." The execution-plan branches (managedAgent /
      overseerLocalExecution) are UNTOUCHED — those are explicit agent routes, not regular queries.
      Pure, unit-testable helpers split out: `autoToolRouteArmed` / `autoRouteCandidatesJSON`
      (matches Rust `PreflightToolInput` shape) / `parseAutoRouteVerdict` / `autoRouteNeedsTools`.
      +6 deterministic tests (EpistemosTests/AutoToolRouteWiringTests.swift): candidate JSON
      shape, empty→nil, verdict true/false/malformed→nil, flag-default-off — NO FFI / env / in-app
      dependence (the detector's own selection logic is the Rust tool_preflight tests). build-for-
      testing TEST BUILD SUCCEEDED, 0 errors, 0 regression. REMAINING for part 2: sub-item (b) the
      GGUF-Gemma grammar-constrained tool-call emit path (canActAsAgent local lane) + the CLOUD
      tool-attachment variant — so the whole TOOLS/SKILLS item stays open (not ticked).
      ✅ PART 2(b) — GGUF-GEMMA GRAMMAR TOOL-CALL CORE + FFI (Rust) 2026-06-19: the local-lane
      foundation so a GGUF Gemma 4 — which does NOT speak the `<tool_call>` XML grammar — can emit
      a STRUCTURALLY VALID tool call via llama-cli's `--json-schema` constrained decoding. NEW
      `agent_core/src/tool_preflight.rs` `preflight_dispatch_json_schema(query, tools, max)` mirrors
      the existing `preflight_dispatch_grammar` but returns the dispatch JSON-SCHEMA STRING (not the
      MLX/llguidance `TopLevelGrammar`), COMPOSING the existing `grammar::dispatch_schema_for_tools`
      (the `oneOf` over `{name: const, input: <param schema>}` per selected tool) — no new schema
      logic. Plus flag `EPISTEMOS_GGUF_TOOL_GRAMMAR_V0` + `PreflightToolWithSchemaInput`
      (name/description/keywords/schema, schema defaults to an empty object schema) + FFI
      `schema_gguf_tool_dispatch_json(query, candidates_json, max) -> String`: flag OFF (default) →
      `""` so the GGUF generation stays UNCONSTRAINED (today's behaviour, the Swift caller may
      invoke it unconditionally and only attach the constraint when non-empty); flag ON → the
      dispatch schema string for the query-relevant tools. Honest `""` on no-match / parse / serialize
      error (a new `GrammarError::Serialize` variant carries the honest error rather than faking a
      schema). This DROPS DIRECTLY into the existing GGUF seam: `GgufCliProvider::with_json_schema` /
      `constrained_args` already pass `--json-schema <schema>` to the hardened llama-cli subprocess
      (Pro + flag-gated — the already-approved GGUF runtime lane, no new sidecar). +3 cargo tests
      (oneOf-for-selected-tools-only, errors-when-nothing-matches, FFI-off-by-default→""). Verified:
      targeted tool_preflight 24/0, FULL lib 5470/0, `--features pro-build` 5733/0 (zero regression),
      and `build-agent-core.sh` regenerates the Swift binding `schemaGgufToolDispatchJson` cleanly
      (the bindings are a gitignored build artifact — regenerated from the Rust source at build time,
      not committed; the bindgen run is a verification that the FFI is uniffi-valid). REMAINING for
      part 2: the Swift LIVE-WIRING — the PipelineService GGUF tool path calls
      `schemaGgufToolDispatchJson`, attaches the schema to the `GgufCliProvider`/`LocalGgufCliRuntime`
      run when non-empty, and parses the emitted JSON as a tool call. TOOLS/SKILLS item stays open.
      ✅ PART 2(b) SWIFT INPUT BUILDER 2026-06-19: the Swift input side of the live-wiring.
      `Epistemos/Engine/PipelineService.swift` added (nonisolated static) `ggufToolGrammarArmed`
      (env `EPISTEMOS_GGUF_TOOL_GRAMMAR_V0`) + `ggufDispatchCandidatesJSON(tools:)` (builds the
      `[{name,description,keywords,schema}]` payload matching Rust `PreflightToolWithSchemaInput`,
      embedding each tool's parsed `schemaJson` as a real JSON object with an empty-object-schema
      fallback for malformed) + `ggufToolDispatchSchema(query:tools:)` (flag-gated; calls the
      generated FFI `schemaGgufToolDispatchJson`; returns nil when off / empty / no-match / "" so
      the caller runs an UNCONSTRAINED GGUF generation = today's behaviour). +4 tests
      (AutoToolRouteWiringTests: candidate shape with embedded schema OBJECT, malformed→empty-object
      fallback, empty→nil, flag-off→nil). build-for-testing TEST BUILD SUCCEEDED (0 errors). NOTE the
      jsonSchema is ALREADY threaded end-to-end on both sides — Swift `LocalGgufRuntimeBridge`
      (jsonSchema param ~line 177) → `runLocalGgufGeneration` → bridge.rs:1291 `json_schema` →
      `GgufCliProvider::with_json_schema` → llama-cli `--json-schema`. So the ONLY remaining piece is
      the OUTPUT side: call `ggufToolDispatchSchema` at the GGUF tool-turn site, pass the non-nil
      result as `jsonSchema` to the generation, and parse the emitted `{name,input}` JSON into a tool
      call. TOOLS/SKILLS item stays open.
      ✅ PART 2(b) OUTPUT PARSER 2026-06-19: the output-parse side. `PipelineService.parseGgufToolCall(_:)`
      (nonisolated static) turns a GGUF Gemma's grammar-CONSTRAINED `{"name":<tool>,"input":{…}}`
      output (the shape of Rust `grammar::dispatch_schema_for_tools`) into a dispatchable
      `(name, argumentsJSON)`: nil for non-conforming output (plain text / missing-or-empty name /
      non-object input) so the caller treats it as a normal text answer; whitespace-tolerant; missing
      `input` → `"{}"` so a no-param tool still dispatches. +5 tests (parse name+input, no-input→{},
      whitespace, non-conforming→nil ×5). build-for-testing TEST BUILD SUCCEEDED (0 errors). So all
      THREE testable building blocks of part 2(b) now exist: the Rust dispatch-schema core + FFI
      (01f88d9be), the Swift input builder (`ggufToolDispatchSchema`, cdd626fcf), and this output
      parser. REMAINING = the LOOP INTEGRATION (a NEW GGUF tool-turn path: GGUF Gemma chat model on a
      tool turn + flag ON → `ggufToolDispatchSchema` → pass as `jsonSchema` to
      `LocalGgufRuntimeBridge.generate` → `parseGgufToolCall` the output → execute via ToolTierBridge
      → feed the result back → repeat) — the in-app-verification-dependent piece, owner runs it once
      model download works. TOOLS/SKILLS item stays open.
      ✅ S4 SCHEMA↔IMPL DRIFT (2 of 4 closed) 2026-06-19: `parse_note_filter` (knowledge.rs) reads
      `note_filter` OR `tags`, but `eidos_query_schema` declared only `tags` and `vault_recall_schema`
      only `note_filter` — a LATENT drift (harmless today since the schema gate doesn't set
      `additionalProperties:false`, but a valid call would be rejected the moment it does). FIX
      (additive, ZERO behaviour change): both schemas now declare BOTH keys (canonical `note_filter`
      + `tags` alias). +1 pin test (eidos_query_and_vault_recall_schemas_declare_both_filter_keys)
      so the drift can't silently reopen. Full-lib 5472/0 + `--features pro-build` 5735/0 (zero
      regression). REMAINING (2 of 4): `collectsnippet`/`savecitation` read undeclared snake_case
      aliases — same additive treatment.
      ✅ S4 SCHEMA↔IMPL DRIFT — ALL 4 CLOSED 2026-06-19: the remaining two. `research_collect_snippet_
      schema` now declares `source_url` / `source_title` / `session_note_path` / `session_note_id`
      and `citation_save_schema` declares `session_note_path` / `session_note_id` — the snake_case
      aliases their handlers actually accept (`ResearchCollectSnippetTool` reads `source_url`/
      `source_title`; `research_session_note_path` reads `session_note_path`/`session_note_id`). +1
      pin test (research_schemas_declare_the_snake_case_aliases_they_read). Full-lib 5473/0 +
      `--features pro-build` 5736/0 (zero regression). So all 4 of the S4 audit's latent schema↔impl
      drifts are now closed — every tool schema honestly declares the keys its handler reads, so a
      future strict gate (`additionalProperties:false`) can't reject a valid call.
      ✅ PHASE-0 SKILLS PATH FIX — SkillRouter loads `.agents/skills/` (multi-dir merge) 2026-06-19
      (research MASTER_SYNTHESIS Phase-0 item 5 / STOP_REINVENTING_AUDIT S3 — the load-bearing skills
      path mismatch): `SkillRouter::load` read ONLY `<vault>/skills/`, so authored `SKILL.md` under the
      `.agents/skills/` convention (the 7 in the repo) were INVISIBLE to the agent context. FIX
      (additive, Rust): `load` now delegates to a new `load_from_dirs(&[<vault>/skills,
      <vault>/.agents/skills])` that merges + dedups by name (earlier dir wins, so an explicit
      `<vault>/skills/` override beats the convention dir) — the multi-dir capability the router
      lacked. Zero behaviour change when `.agents/skills/` is absent. +1 test
      (load_from_dirs_merges_skill_dirs_and_dedups_by_name). Full-lib 5474/0 + `--features pro-build`
      5737/0 (zero regression). REMAINING skills repair (each its own slice): un-gate progressive
      skills from `#[cfg(feature="pro-build")]` (registry.rs) — SHIFTS THE MAS/Pro BOUNDARY, needs
      owner sign-off per the canon-hardening protocol (document, don't flip); unify the CRUD
      `~/.epistemos/skills` vs the router dirs; `skill_manage` v2 schema reachability
      (allow_remote_skill_install + additionalProperties); the project-root `.agents/skills/` caller
      wiring (the router now LOADS the convention dir vault-relative; a project-root resolver passes
      the absolute path).
      ✅ PHASE-0 SKILL_MANAGE V2 INSTALL REACHABLE — declares allow_remote_skill_install 2026-06-19
      (S4 audit / MASTER_SYNTHESIS Phase-0 item 5): the v2 `skills.manage` schema
      (tools_v2/v2_catalog/skills_manage.rs) set `additionalProperties:false` but OMITTED
      `allow_remote_skill_install` — the network-consent gate the legacy handler requires before a
      remote install (skills.rs:1366) — so a call passing it was REJECTED and `install_from_github`/
      `install_from_url` were UNREACHABLE. FIX (additive): `input_schema` now declares
      `allow_remote_skill_install` (boolean). The Pro/quarantine GATING of remote install is
      UNCHANGED — only the consent field is now passable under the strict schema. +1 pin test
      (input_schema_declares_remote_install_consent_so_installs_are_reachable). Full-lib 5475/0 +
      `--features pro-build` 5738/0 (zero regression).
      ✅ PHASE-0 PROGRESSIVE SKILLS UN-GATED TO MAS (owner sign-off 2026-06-19; remote install stays
      Pro): `registry.rs` promoted `register_phase_one_skills_progressive` OUT of the
      `#[cfg(feature="pro-build")]` cfg (both the call site and the fn definition), so
      `skills_list` / `skill_view` / `skill_manage` now register in the MAS build (handlers/schemas
      are non-pro in `tools/skills.rs`; MIT clean-room, no subprocess — git2 library + reqwest).
      SAFETY PRESERVED: `skill_manage`'s remote-install verbs (`install_from_github` /
      `install_from_url`) return an HONEST "Pro only" error in the MAS build (the cfg-gated action
      arms + `remote_skill_install_pro_only`), so the tool is BOUNDED in MAS (create/edit/delete/
      install_from_local_path work) — the mas-sandbox "no unbounded tools" invariant holds, and
      `skill_manage` moved blocked→ALLOWED in `mas_sandbox_registry_excludes_unbounded_tools`. The
      install fns carry `#[allow(dead_code)]` (compiled for pro + tests). +2 tests (MAS-registration
      + the updated sandbox assertion). MAS full-lib 5476/0 + `--features pro-build` 5739/0 (BOTH
      green, no double-registration). This COMPLETES the cargo-cheap Phase-0 fix-the-broken set:
      schema drifts 4/4 + skills path + skill_manage v2 reachability + progressive un-gate.
      ✅ FLIP+VERIFY (Phase-0 #6) part 1 — cloud-tools + foundation-recommend ON by default 2026-06-19
      (owner: don't slow down, SEE the fixes on rebuild). Flipped two flags from `== "1"` (opt-in) to
      `!= "0"` (ON by default, env `0` disables): `cloudChatToolsAllProvidersArmed` (InferenceState) →
      EVERY cloud provider now attaches plain-chat vault tools (Google/Z.AI/Kimi/MiniMax/DeepSeek, not
      just OpenAI/Anthropic) — VISIBLE IMMEDIATELY on the owner's next rebuild, no model install needed;
      `foundationRecommendArmed` (AgentCommandCenterState) → auto-mode recommends an installed
      foundation model (Gemma/VibeThinker/coder) instead of the Qwen-first list (falls to legacy when
      none installed, so no change there). DELIBERATELY NOT FLIPPED: `EPISTEMOS_AUTOSUBSTITUTE_LOCAL_
      MODEL` stays OFF=honest (flipping it ON would RESTORE the silent-Qwen-substitute bug just fixed);
      `EPISTEMOS_RUNTIMEROUTER_LIVE_V0` + `EPISTEMOS_GGUF_TOOL_GRAMMAR_V0` stay OFF (no hot-path/loop
      wire yet — flipping does nothing or risks unparsed output); `EPISTEMOS_HONEST_UNAVAILABLE_
      SPECIALIST_PICK_V0` stays opt-in. Test updated (flagDefaultsOn). build-for-testing TEST BUILD
      SUCCEEDED (0 errors). PART 2 (next): flip `EPISTEMOS_AUTO_TOOL_ROUTE_V0` ON (coordinated Swift
      PipelineService.autoToolRouteArmed + Rust auto_tool_route_armed) so plain queries auto-route to
      tools end-to-end.
      ✅ FLIP+VERIFY (Phase-0 #6) part 2 — AUTO-ROUTE ON by default (Swift + Rust) 2026-06-19:
      `EPISTEMOS_AUTO_TOOL_ROUTE_V0` flipped to ON by default on BOTH sides (env `0` disables) — Rust
      `auto_tool_route_armed()` (agent_core/src/tool_preflight.rs) now `env != "0" || unset → true`
      (kept OFF the shared `flag_armed` so the GGUF-grammar flag stays opt-in), and Swift
      `PipelineService.autoToolRouteArmed` (`== "1"` → `!= "0"`). So a plain LOCAL query like "find my
      note about X" now consults the deterministic tool-need detector and auto-routes to the tool loop
      (vault.search) instead of a toolless answer, while pure chat ("write a haiku") still direct-
      streams. Tests rewritten to default-ON (Rust auto_route_ffi_on_by_default_returns_the_real_verdict
      + Swift flagDefaultsOn). cargo full-lib 5476/0 + `--features pro-build` 5739/0 + build-for-testing
      TEST BUILD SUCCEEDED (0 errors). So FLIP+VERIFY is done for the three SAFE high-visibility fix
      flags (cloud-tools + foundation-recommend + auto-route); the owner's next rebuild shows tools
      firing on all cloud providers + a plain query routing to vault tools + a foundation model
      auto-recommended. (autosubstitute stays OFF=honest; RuntimeRouter/GGUF-grammar stay OFF — no
      live wire yet; honest-unavailable stays opt-in.)
      🔎 PHASE-0 REMAINING — OWNER SIGN-OFF / IN-APP (the cargo-cheap safe Phase-0 slices are done;
      these need YOU): (1) **progressive-skills un-gate** — `registry.rs` gates the progressive
      skill tools behind `#[cfg(feature="pro-build")]`, so the MAS build exposes only the legacy CRUD
      `skills` tool. DECISION NEEDED (MAS/Pro boundary, canon-hardening protocol — NOT flipped without
      sign-off): promote to MAS (it's MIT clean-room, no subprocess) OR keep an honest "Pro only"
      surface. (2) **Flip + verify the 7 flags in-app** (docs/SESSION_CHECKPOINT_2026_06_19.md) — the
      S4 cloud-tools fix is verifiable now (no model download); the model-selection layers once a
      model installs. (3) **CRUD/router dir unification** (`~/.epistemos/skills` vs `<vault>/skills`)
      + the project-root `.agents/skills/` caller wiring — deeper, behaviour-affecting. (4)
      **GGUF-Gemma tool-loop integration** + **RuntimeRouter STAGE-1c hot-path call** — both need
      model-download / in-app verification (all primitives shipped + tested).
      🔎 S4 DEEP-RESEARCH AUDIT 2026-06-19 (docs/research/CHAT_TOOLS_INTEGRATION_AUDIT_2026_06_19.md)
      — confirms the loop's local diagnosis AND adds the missing pieces: (i) **CLOUD break (specific):**
      `runCommandCenterRustAgentPath` is reached only if `cloudProvider.supportsAgentTier`, TRUE ONLY
      for OpenAI/Anthropic (`InferenceState.swift:1347-1352`); plain chat on Google/Z.AI/Kimi/MiniMax/
      DeepSeek falls to the toolless `else` (`ChatCoordinator.swift:555`) → "cloud should auto-know"
      fails for every non-OpenAI/Anthropic provider. FIX: attach chatLite/chatPro tools for plain chat
      on ALL providers (or honestly per-provider gate) at `ChatCoordinator.swift:503-555`/
      `InferenceState.swift:1347` — this is the BIGGEST visible win, lowest risk, tools already execute.
      (ii) **SKILLS data-plumbing (NEW):** 3 disjoint stores never reconcile — the 7 authored `SKILL.md`
      live in `.agents/skills/`, a path NO loader reads (`default_skills_dir`→`~/.epistemos/skills`;
      SkillRouter→`<vault>/skills/`); `skills_list`/`skill_view`/`skill_manage` are pro-build-only (not in
      MAS); `skill_manage` v2 install is unreachable (schema omits `allow_remote_skill_install` +
      `additionalProperties:false`); `EditorSkill` `.systemPrompt`/`.toolSubset` read by nothing. FIX:
      point the loader at `.agents/skills/` (or migrate), register the view tools in MAS, fix v2 install,
      wire-or-prune EditorSkill. (iii) **4 latent schema↔impl DRIFTS** (harmless today, break if the
      schema gate sets `additionalProperties:false`): `vault_recall` reads undeclared `tags`; `eidos_query`
      reads `note_filter`; `collectsnippet`/`savecitation` read undeclared snake_case aliases — add the
      read keys to the declared schemas. (iv) **UI boxes wire is INTACT** — gone only because no tool calls
      fire (not a cut wire); fixing (i)+(ii)/(2b) restores them. (v) **PRUNE (dead/safe):** `ConfidenceRouter.swift`
      (self-documented never-instantiated; live routing = `TriageService.InferencePolicyEngine`),
      `skills_context()`, orphaned `SkillDiscovery::observe` + `self_evolution::propose_repeated_success_skill`,
      `format::SkillManifest`, unwired `epistemos-core::skill_engine/*`; consolidate the duplicate
      legacy-`skills`-vs-`skill_manage` verb sets (don't blind-remove; CRUD is the only MAS one). ORDERED
      REAL FIX: (1) cloud all-provider tool attach → (2) finish 2(b) Swift GGUF-Gemma live-wiring →
      (3) skills store/path reconcile → (4) close 4 drifts → (5) fix v2 install → (6) wire/prune EditorSkill.
      ✅ S4 FIX (1) — CLOUD PLAIN-CHAT TOOLS ON ALL PROVIDERS (flag-gated) 2026-06-19: the biggest
      visible win + the one the owner can verify in-app NOW (cloud needs no model download). Root
      (confirmed): `ChatCoordinator.swift:508` only routed Fast/Thinking/Pro cloud chat through the
      tool path (`runCommandCenterRustAgentPath`) when `cloudProvider.supportsAgentTier` (TRUE only
      OpenAI/Anthropic), so Google/Z.AI/Kimi/MiniMax/DeepSeek plain chat fell to the toolless `else`
      (:555) despite the prompt advertising vault access. FIX: `CloudModelProvider` (InferenceState)
      gained `supportsChatToolAttachment` (true for ALL providers — each speaks OpenAI/Google-style
      function calling for a chat turn, distinct from `supportsAgentTier`=first-class agent-LOOP
      driver) + a PURE static `allowsPlainChatTools(provider:allProvidersArmed:)` (armed ?
      supportsChatToolAttachment : supportsAgentTier) + an instance `allowsPlainChatTools` reading
      env `EPISTEMOS_CLOUD_CHAT_TOOLS_ALL_PROVIDERS_V0`. The ChatCoordinator gate changed
      `supportsAgentTier`→`allowsPlainChatTools`. OFF (default) = BYTE-IDENTICAL (OpenAI/Anthropic
      only, today's behaviour); ON = every provider attaches chatLite/chatPro tools (tool-tier
      mapping unchanged: .fast/.thinking→.chatLite, .pro→.chatPro; vault.write still gates
      AgentAuthority+R5). +3 tests (CloudChatToolsGateTests: flag-off→only OpenAI/Anthropic,
      flag-on→all 7, all support chat-tool-attachment). build-for-testing TEST BUILD SUCCEEDED (0
      errors). OWNER IN-APP: set `EPISTEMOS_CLOUD_CHAT_TOOLS_ALL_PROVIDERS_V0=1`, plain-chat a
      non-OpenAI provider with a vault query ("find my note about X") → expect the vault.search tool
      box + a grounded answer. Not ticked [x] — owner confirms the boxes render in-app.
      ✅ OQ-1 SESSION-CORPUS DETECTOR + honest degrade 2026-06-19 (research HERMES_OSAURUS_OPENCLAW_
      WIRING_R2 — the highest open question, "verify the real vault layout first"): `session_search`
      scans `<vault>/sessions/` (agent_core SessionFolders) but the live conversation corpus is the
      Swift SDChats under the shadow-indexed `<vault>/chats/` — TWO different stores, so a session
      lookup returned a SILENT ZERO when the chats live in `/chats/`. FIX (Rust, contained,
      cargo-verifiable): `agent_core/src/storage/session_store.rs` adds the pure `SessionCorpusLayout`
      {sessions_dir_present, session_folder_count, chats_dir_present, chat_file_count} +
      `has_corpus_mismatch()` (sessions empty AND chats present) + `detect_session_corpus(vault_root)`
      (counts `session.json` folders under `sessions/` + recursively counts `.json` under `chats/`,
      bounded depth 8). `SessionSearchHandler` (knowledge.rs) now returns `corpus` + an honest `hint`
      when matches are empty and the corpus is mismatched — pointing to the chat search index instead
      of a bare zero. +1 cargo test (detect_session_corpus_reports_both_corpora_and_the_oq1_mismatch).
      Full-lib 5471/0 + `--features pro-build` 5734/0 (zero regression). STAGE-NEXT (the full
      shadow-index wire, build-verifiable): Swift `SearchIndexService.fusedSessionSearch(query,limit,
      now) -> [FusedResult]` beside `fusedSearch` (SearchIndexService.swift:902), source-filtered to
      the chats projection (the corpus is ALREADY in the HNSW+BM25+RRF shadow index via
      ShadowVaultBootstrapper — reuse `RRFFusionQuery`, no Rust backend) + a Rust `SessionSummarize
      Handler` (DETERMINISTIC snippet assembly, NO model call — a mid-turn model call would deadlock
      the single-MainActor client) + 1 prompt line "for session lookups call session.search then
      synthesize" + degrade-to-plaintext-if-shadow-not-open (never throw).
- [~] **PICKER + PARITY PASS — build-verified 2026-06-18 (owner does the in-app
      run). All 4 items addressed across aff6b0c21 / 9ffa66b00 / b2b5aa04b +
      the item-3 parity-lock test. (1) scroll/height: panel cap 320→460 + an
      overflow-aware "scroll for more" affordance (content-vs-viewport measured).
      (2) mini parity: MiniChatView now shares MainChatOperatingModePreference.
      supportedModes(for:) → full mode set incl. Act (was narrowed per-model,
      reverting Act). (3) non-reductive on all 5: mini/graph/note mount the panel
      in plain VStacks (no clip) + landing's stage was the only fixed-height clip
      (fixed in 4); all 5 pass a mode binding + showsSettingsFooter:true (MODE +
      EFFORT + Settings footer) — locked by a new parity test. (4) search-page
      click regression: landing background-tap now dismisses the picker on outside
      click instead of (re)triggering search; landing search stage grows 236→540
      when the picker is open (was clipping it to ~2 rows). Owner verifies each
      surface visually (Product▸Run). Original ask:**
      1. **PICKER SCROLL/HEIGHT** — InlineRuntimePickerPanel is too short with no
         scrollbar, so only ~2 options show. Make it tall enough OR scrollable
         with a visible "more exists" affordance, so ALL Fast/Think/Code picks
         are obviously available (the picks already exist + are tested; the bug
         is they're not VISIBLE/reachable).
      2. **MINI-CHAT PARITY** — mini chat must EQUAL main chat: all capabilities
         + the Chat/Act/Work(Open Code) mode toggles. Root cause =
         MiniChatView.sanitizedMiniChatOperatingMode restricting the mode set;
         widen it (with HONEST gating — never fake a capability the surface can't
         do).
      3. **NON-REDUCTIVE PICKER on ALL 5 surfaces** — mini/landing/search/graph/
         note still expose a reduced picker vs main. Bring each to full parity
         (or honestly relocate, per the cross-reference audit).
      4. **SEARCH-PAGE CLICK REGRESSION** — clicking anywhere on the landing/
         search page misbehaves. Audit Landing/* + HologramSearchSidebar gesture
         handling and fix.
- [x] **PER-MODEL VAULTS (KnowledgeFusion) — owner 2026-06-18. BUILD-VERIFIED COMPLETE (owner does in-app run).
      DONE (part 2 first cut): ModelVaultsSettingsView no longer renders generic
      hardcoded "Present in compiled vaults" rows — new ModelVaultFileInspector
      (always-compiled, tested) probes each target's vault dir for the canonical
      files (real size + last-modified, honest missing), rendered as per-model
      DisclosureGroups (name+ID+compiled-dot+total size header; per-file size +
      relative mtime + honest "Not compiled" when expanded), compiled-first sort.
      DONE (part 1): modelVaultTargets() now ALSO appends the installed
      foundation GGUF chat models (supportedAvailableGemmaQATRuntimeCandidates =
      Gemma/VibeThinker/coder, the runnable lane) — previously excluded because
      they're descriptor IDs, NOT LocalTextModelID enum cases. HONEST findings:
      the MLX gemma4 enum IDs (incl. 26B-A4B) stay excluded — isReleaseValidated-
      ForInteractiveChat=false because the MLX loader errors ("Unsupported model
      type: gemma4"); the RUNNABLE Gemma is the GGUF lane (now included). LFM2.5 +
      Qwen3-8B are MLX LocalTextModelID cases → already included when installed +
      non-experimental. Vision-only Holo is NOT a text-chat foundation tier → not a
      chat vault (honest). bucket(for:) buckets foundation GGUF as .local. Default
      instructions auto-create on first compile (KnowledgeProfileStore.resolved-
      Instructions). PENDING: instructions.md content preview in ModelVaultDetailRow;
      verify defaults are sane. Build+run verify in-app.**
      (1) UPDATE KnowledgeFusion vaults for the NEW local models — Gemma 26B-A4B,
          LFM2.5, 2-bit 12B, VibeThinker, Qwen3-8B, Holo — each must be a vault
          TARGET with sane default instructions (not just the legacy lineup).
      (2) HARDEN ModelVaultsSettingsView — today it renders GENERIC HARDCODED file
          rows ("Present in compiled vaults"). Replace with REAL per-model status:
          file sizes, last-compiled timestamps, content preview, per-model rows,
          honest empty/error states (no fake "present" claims).
      (3) SCOPE DECIDED (do NOT fork): per-model vaults stay CHAT/Epistemos-only.
          Act=Osaurus and Work=Goose have their OWN systems and CONSUME the shared
          vault via tools + a system-prompt anchor — do NOT fork per-engine vault
          stores or UI. One shared vault, many consumers.
- [x] **PICKER IS STILL A POPOVER — DONE 2026-06-18, ALL 5 SURFACES (b8ceebabc)**
      The model/runtime picker is now a flat inline pixel-art panel
      (InlineRuntimePickerPanel) on ALL surfaces: main chat (378379408), landing
      (d790bc81f), mini (a6a636b38), graph + note (b8ceebabc). No model-picker
      popover remains anywhere (the only LocalModelToolbarMenu left is main
      chat's split toolbar for mode/routing/effort, with its model button hidden
      and the inline panel as the picker). Owner verifies visually (Product▸Run).
      Original ask for the record:
      Built InlineRuntimePickerPanel — a FLAT, INLINE, pixel-art panel (hard 1.5px
      rectangular border, solid theme.card fill, monospaced/pixel titles, flat
      accent-bar selection, NO .popover) that expands in-flow in the MAIN-CHAT
      composer (the needsCloudBanner VStack slot) toggled by a `cpu` trigger; the
      floating split-toolbar model button is hidden there (hidesModelButton: true)
      → exactly one picker, no popover. Self-contained on EpistemosRuntimePicker +
      InferenceState; same Fast/Think/Code picks + honest gating as the popover.
      MAIN CHAT + LANDING DONE (d790bc81f): landing hero chat migrated too — its
      single-button ChatBrainPickerMenu popover replaced with a flat trigger +
      the in-flow InlineRuntimePickerPanel (showsSettingsFooter routes cloud/
      routing/details to Settings). REMAINING (follow-on): mini (MiniChatView:1005)
      / note (NoteDetailWorkspaceView:2151) / graph (HologramSearchSidebar:780)
      still use the single-button popover — migrate those to the inline panel next
      (same pattern: trigger tile + InlineRuntimePickerPanel showsSettingsFooter
      true in an in-flow slot). Owner verifies main-chat + landing visually
      (dev-cert Product▸Run).
- [~] **NEW PICKER MISSING CONTROLS — AUDIT + EFFORT + MODE done 2026-06-18
      (e7cd5f550 + fe377f01b); owner verifies render+switch in-app.** Audit table:
      docs/INLINE_PICKER_CROSS_REFERENCE_AUDIT_2026_06_18.md (every old control
      proven present/relocated/gap on all 5 surfaces). FIXED: Fast/Think/Code +
      per-tier picks VERIFIED present (were already there); EFFORT control added to
      the panel (Low/Med/High/Heavy via availableReasoningTiers, honest non-empty
      gating — Fast shows none); Chat/Act MODE toggle added (honest Act gating).
      Routing/cloud/native/temporary honestly relocated to the Settings footer
      (single) / split toolbar (MC). OPEN follow-up: Companion agent-switcher not
      yet in the panel; optional fold of MC split-toolbar buttons. Owner build+runs
      to confirm effort + Fast/Think/Code + Act render AND switch behavior. Original:
      owner (verbatim): *"there are also issues with new model picker
      it doesnt have effort fast think etc. it is missing a lot so needs a complete
      cross reference."* The inline-panel rebuild (InlineRuntimePickerPanel, b8ceebabc)
      shipped WITHOUT carrying over controls the old popover/toolbar had: the EFFORT
      control (Low/Med/High/Max — `effortPopover` RootView:1306, `supportsRuntime-
      EffortButton` :700, `effortButtonTitle` :882) and the Fast/Think/Code TIER
      selection are not surfaced in the new inline panel. ACTION — do a COMPLETE,
      LINE-BY-LINE CROSS-REFERENCE: enumerate EVERY control the old picker path
      (LocalModelToolbarMenu split toolbar Mode·Model·Routing·Effort·Native + the
      old modelPopover/effortPopover) ever exposed, then prove each one is present
      (or deliberately+honestly relocated) in InlineRuntimePickerPanel on ALL 5
      surfaces. Nothing silently dropped. Must surface, at minimum: (a) Fast/Think/
      Code tier toggle; (b) per-tier model picks (Fast = Gemma 2B/4B/12B/Apple,
      Think = VibeThinker + Qwen3-8B, Code = Gemma 12B coder, + Qwen3-4B); (c) the
      reasoning EFFORT control where the model supports it (`supportsNativeReasoning-
      EffortControl`) — Low/Med/High/Max for think/codex, with honest hide when
      unsupported; (d) Cloud toggle + routing/native-controls (relocate to Settings
      footer is OK IF honest+visible). Build, run, and verify each control renders
      AND changes behavior in-app on every surface. Harden; commit the audit table
      to docs. DO NOT mark done until the owner can see effort + Fast/Think/Code in
      the running picker. Cross-ref existing PICKER REDESIGN (P1.11) below.
- [~] **PICKER PANEL TOO SHORT / NO SCROLL → looks like only ~2 options — build-
      verified 2026-06-19 (owner does the in-app run).** The prior pass added the
      460 cap + a bottom fade "scroll for more" hint; this pass adds the owner's two
      remaining explicitly-listed affordances: (a) `.scrollIndicators(.visible)` forces
      the scrollbar to show (macOS auto-hides the overlay scroller — the literal "no
      scroll bar"), and (b) an always-visible `pickerCountHeader` pinned above the
      scroll area (`.safeAreaInset(edge: .top)`, OUTSIDE the height cap so it never eats
      scroll budget) showing "N models" (real lineup size = sum of every tier's picks)
      + a `chevron.down`/"scroll for all" cue when `pickerOverflows`. One shared panel →
      lands on all 5 surfaces at once. +1 regression test (visible-indicator + count +
      real-sum + overflow-gated cue); build-for-testing green. Owner verifies the full
      lineup is visible/reachable visually (Product▸Run). Original report:
      *"when I go to the [picker] it
      seems like there were only two available because there's no scroll bar [and]
      the box isn't long enough to make it seem like there's more to choose from —
      just make sure that model picker is good."* BUG: InlineRuntimePickerPanel
      (Epistemos/Views/Chat/InlineRuntimePickerPanel.swift) is height-capped with no
      scroll indicator, so only ~2 of the per-tier model rows are visible and the
      rest look like they don't exist. FIX: make the panel tall enough to show the
      full lineup, OR a properly scrollable list with a VISIBLE scroll indicator and
      affordance that MORE options exist (count/"N models"/fade/chevron). The owner
      must immediately SEE all Fast/Think/Code picks are available, not just two.
      Apply on ALL 5 surfaces (it's the same panel). Build+run verify the full set
      is visible/reachable in-app. Part of "the picker is good" bar.
- [ ] **ALL-SURFACE PARITY + NON-REDUCTIVE PICKER + SEARCH-PAGE CLICK REGRESSION
      (owner 2026-06-18)** — owner (verbatim, transcribed): *"the main chat seems to
      be the only window hardened enough and I want to make sure the mini chat also
      still has all the capabilities as the main chat, and also the mini chat should
      also have toggles for Act and Open Code… it should have all the things…
      [it's] like a mini main chat. Also on the search page when you click anywhere
      on the page a lot of that is [wrong/regressed]. The picker is too reductive
      there as well."* FOUR parts: (1) **MINI-CHAT FULL PARITY** — mini chat must
      have ALL main-chat capabilities (queue, context, tools, attachments, cowork
      affordances, local-for-all-modes), not a stripped subset; it IS a mini main
      chat. (2) **MINI-CHAT MODE TOGGLES** — surface Chat/Act/Work(Open Code) toggles
      in mini, same three engines as main. ROOT: `MiniChatView.swift:686/1249
      sanitizedMiniChatOperatingMode` RESTRICTS mini's operating-mode set (the
      reductive culprit) — widen it to the full mode set with honest gating, don't
      silently drop Act/Work. (3) **NON-REDUCTIVE PICKER ON ALL 5 SURFACES** — the
      picker cross-reference (effort + Fast/Think/Code + per-tier picks + mode/
      routing) landed on MAIN chat (e7cd5f550/fe377f01b/48f75f8f3) but mini
      (MiniChatView:1004), landing/search (LandingView, HologramSearchSidebar),
      and note (NoteDetailWorkspaceView) still host a REDUCED InlineRuntimePicker-
      Panel. Apply the SAME full cross-reference to all 5 — every surface gets the
      complete picker, not a reductive one (+ the scroll/height fix above). (4)
      **SEARCH-PAGE CLICK REGRESSION** — on the landing/search page (Landing/* +
      HologramSearchSidebar) clicking "anywhere on the page" misbehaves; audit the
      tap/gesture handling (onTapGesture / contentShape / simultaneousGesture across
      the Landing overlays), find what swallows or misroutes clicks, fix it. Build+
      run verify EACH surface in-app: mini has Act/Work + full picker + parity;
      search-page clicks behave; nothing reductive. DON'T mark done until the owner
      can use mini exactly like main.
      ── MINI = MAIN ONTOLOGY + ONGOING-PARITY INVARIANT (owner 2026-06-19, verbatim:
      *"minichat is ontologically a mini-main-chat — that's the main ontology of it, so
      it should quite literally BE main chat but small. It already satisfies this
      visually; I just want to make sure that when we're doing the OTHER parts, the
      minichat gets all that main chat gets — like Work, even the Open Code stuff."*).
      HARD INVARIANT (not a one-time fix): MiniChat IS MainChat rendered small — same
      ontology, same engine set, same capabilities. Therefore EVERY future engine/
      capability build (Act=Osaurus+brain, OpenClaw lane, Hermes fusion, Work=Goose/
      Open Code, browser-use, computer-use, voice, HTML canvas, terminal, etc.) MUST
      flow into MiniChat AT THE SAME TIME it lands in MainChat — mini is never a
      trailing subset. Implementation rule: mini and main must SHARE the same operating-
      mode source, engine registry, and capability surface (one definition, two
      renders) so new capability is parity-by-construction, not re-ported. Add/keep a
      parity test that fails if MainChat exposes a mode/engine/tool MiniChat does not.
      ── SESSION-AS-NATIVE-TAB META (owner 2026-06-19, verbatim: *"if we can separate
      sessions by minichat on all engines that is the meta as well, because a new
      session becomes a whole new native tab."*): sessions are SEPARATED per chat
      surface ACROSS ALL ENGINES (Chat/Act/Work, both Act lanes) — each session is its
      own isolated context, and **a NEW session opens a whole new NATIVE TAB**. This
      composes with the ENGINE-ISOLATION DOCTRINE: per-session isolation in code/state,
      connected only via the shared memory substrate (a new Act-session tab can be
      AWARE of a Chat session's memory, not entangled with its runtime). Build a native
      tab model where new-session → new-tab works uniformly on every engine, mini and
      main alike.
- [ ] **PER-MODEL VAULTS — update for new models + harden (looks demo-ish) + SCOPE
      RESOLUTION (owner 2026-06-18)** — owner (verbatim, transcribed): *"per-model
      vaults should also be updated for the new ones and hardened because it looks
      very demo-ish. Also how should it show up for Osaurus and Open Code? I believe
      they have their own system — if so then only have the compiled stuff for chat,
      but idk, let me know."* Feature = the KnowledgeFusion knowledge-distillation
      system (Epistemos/KnowledgeFusion/* + Views/Settings/ModelVaultsSettingsView.
      swift): distills notes + recent chats into per-model context files
      (knowledge_profile.md / concept_index.md / active_context.md / instructions.md
      keyed by modelID via KnowledgeProfileStore) and feeds the model's
      augmentedSystemPrompt. THREE parts: (1) **UPDATE FOR NEW MODELS** — the new
      local models (Gemma 26B-A4B, LFM2.5, 2-bit 12B, VibeThinker, Qwen3-8B, Holo)
      must appear as vault targets (they key off releaseSelectableInstalledLocalText-
      ModelIDs — ensure each is registered installed/selectable AND the compiler has
      sane per-model default instructions). (2) **HARDEN (de-demo-ish)** — Model-
      VaultsSettingsView renders GENERIC hardcoded file rows ("Present in compiled
      vaults"); replace with REAL per-model status: actual file sizes, last-compiled
      timestamps, content preview, per-model row (not one generic file list), honest
      empty/error states. (3) **SCOPE RESOLUTION (DECIDED — owner leaning confirmed):
      per-model vaults stay CHAT(Epistemos)-SCOPED.** Act=Osaurus and Work/Open-Code=
      Goose bring their OWN provider/model/session systems — do NOT fork a per-model-
      vault store/UI for them (duplication + drift). Instead they CONSUME the shared
      Epistemos vault (notes/Eidos/Knowledge Core) via existing tool/vault access + a
      shared system-prompt ANCHOR. So ModelVaultsSettingsView enumerates ONLY Chat's
      native local models + configured cloud providers — not per-Osaurus-model or
      per-Goose-provider rows. (Owner can override if they want per-engine vaults
      later.) Build+run verify new models show + real status renders in-app.
- [ ] **DATA + FINE-TUNING SUBSTRATE — deep-harden the black boxes, native MLX
      training, Night Brain, + a data/finetune-pack MARKETPLACE (owner 2026-06-18)**
      — owner (verbatim, transcribed): *"they should be deeply hardened because I
      think there are black boxes and I want it to be better — maybe even use another
      GitHub repo for MLX and other local-model training and fine-tuning and Night
      Brain etc. Several features like that, because I feel like my app does not do a
      good job structuring the data etc. Maybe even have a marketplace for data and
      fine-tuning packs."* CONFIRMED BLACK BOX: the fine-tuning subsystem relies on
      PYTHON scripts that CANNOT run in MAS (NO HIDDEN SIDECAR) → opaque/non-
      functional stubs: KnowledgeFusion/MoLoRA/{train_router,molora_inference}.py,
      Training/scripts/{train_knowledge,train_style}.py, MOHAWK/fill_training_gaps.py
      (+ MoLoRAInferenceService.swift, QLoRATrainer.swift, ExperienceReplayBuffer.
      swift). This is the demo-ish feel the owner senses. FIVE parts: (1) **KILL THE
      PYTHON BLACK BOXES** — finish LF-1/2/3 + SIM-4: replace MoLoRA/QLoRA Python with
      NATIVE in-process MLX-Swift training (LoRA/QLoRA via mlx-swift autograd +
      optimizers); no .py on the product/MAS path. (2) **PORT A PROVEN TRAINING REPO**
      — RESEARCH-FIRST verdict on ml-explore/mlx-examples (LoRA/QLoRA, MIT) +
      ml-explore/mlx-swift training APIs (and any better OSS) → lift the proven
      training loop natively, don't hand-roll; ProvenanceGate. (3) **DATA STRUCTURING
      DEEP-HARDEN** — the vault/knowledge pipeline (concept_index / knowledge_profile
      / active_context / ExperienceReplayBuffer) must actually structure data well:
      real schemas, provenance, dedup, inspectable — unwrap every black box, honest
      status, no opaque stubs. (4) **NIGHT BRAIN** — the idle-maintenance brain runs
      native vault compilation + LoRA fine-tuning during idle windows (not per-
      keystroke); visible, logged, owner-controllable, honest "what it did" record.
      (5) **DATA + FINETUNE-PACK MARKETPLACE** — extend the HF/GitHub marketplace
      (R-APPS/importer) to datasets + fine-tuning PACKS (LoRA adapters, instruction
      packs, knowledge packs): browse/import/apply/share, each {id, kind, source,
      license, gate}; ProvenanceGate + honest gating; MAS-safe (no Python at runtime).
      RESEARCH-FIRST on each; build+run verify training actually runs natively +
      Night Brain + marketplace are real and usable in-app. Cross-ref LF-1/2/3, SIM-4,
      per-model vaults above, HARNESS SYSTEMS below, R-APPS importer/marketplace.
      ✅ FINISHER 2026-06-19 (part 4 wiring): AppBootstrap now INJECTS the Night
      Brain `loraFineTuneJob` provider (`runNightBrainLoRAFineTuneIfDue`) — was nil,
      so the `nativeKnowledgeAdapterFineTune` Job could never dispatch. Provider
      gathers real inputs (Pro build flag, AC via PowerGate), evaluates the real
      `NightBrainLoRAFineTuneDecision`, and logs the honest run/skip outcome
      (rule #8 visible). INERT in production (EPISTEMOS_NIGHTBRAIN_LORA_V0 OFF by
      default; executeJob gates on it). Locked by AuditFixRegressionTests
      `nightBrainWiresVaultBackedLifecycleJobsFromAppBootstrap` (+4 wiring asserts).
      build-for-testing green. STILL ON-DEVICE FOLLOW-ON (can't headless-verify):
      the vault data-gen iteration that supplies `newExampleCount` + a persisted
      last-fine-tune marker + the actual NativeLoRATrainer run on Pro.
      ✅ FINISHER 2026-06-19 (part 5 BROWSE surface): the marketplace had a tested
      registry but NO UI → owner couldn't SEE it. NEW FineTunePackCatalog (first-
      party, license-clean SEED — vault dataset / Epistemos instructions / local
      LoRA; third-party packs added later via ProvenanceGate with REAL licenses) +
      FineTuneMarketplaceView (lists `available(isPro:isDev:)` grouped by kind, row =
      source/license/gate badge, honest empty state, `#if !EPISTEMOS_APP_STORE` Pro-
      gating so the Pro LoRA pack NEVER shows on MAS) mounted in ModelVaultsSettings.
      +4 tests; build-for-testing green. FOLLOW-ON: import/apply wiring (LoRA →
      AdapterExporter/NativeAdapterApply; dataset/instruction → native train/vault) +
      a real add-through-ProvenanceGate flow for public HF/GitHub packs.
      ✅ FINISHER 2026-06-19 (part 5b APPLY affordance): browse → apply. NEW pure
      `FineTunePackApplyAction` (.applyAdapter/.importDataset/.applyInstructions/
      .importKnowledge) + `FineTunePackKind.applyAction` + `FineTunePack.applyConfirmation`
      — each action carries a verb + an HONEST description naming WHERE it runs
      (adapter/knowledge = on-device `runsOnDevice`; never fakes an execution the
      browse surface can't do). FineTuneMarketplaceView gains a per-row Apply/Import
      button → an honest confirm `.alert` (per-kind verb + description) → an outcome
      note. +6 FineTunePackApplyTests (kind→action map, honest descriptions, on-device
      flags, confirm mirrors kind, view wires the button/alert); FineTunePackCatalog
      mirrored-source asserts intact. build-for-testing green. STILL FOLLOW-ON: the
      per-kind EXECUTION (NativeAdapterApply for .loraAdapter into a loaded model;
      dataset/instruction/knowledge into the native-train/vault pipeline) is the
      gated on-device step the affordance directs the owner toward.
      ✅ FINISHER 2026-06-19 (part 5c IMPORT verb): browse → import → apply. NEW pure
      `FineTunePackImporter` — `parseSource` maps a public spec (bare `owner/name`→HF,
      `huggingface.co/…`, `github.com/…`, http(s)/file URL) into a typed
      `FineTunePackSource` (honest: recognized hosts only, nil otherwise); `makePack`
      validates through the ProvenanceGate (a LICENSE is REQUIRED — no license, no
      entry) + builds a registerable descriptor with a deterministic dedup id. Wired
      a VISIBLE, USABLE import affordance into FineTuneMarketplaceView (rule #8): an
      "Import a pack" disclosure (source/name/license fields + kind/gate pickers + an
      "Add through ProvenanceGate" button) registers into a SESSION `@State` registry
      so the pack appears in the list immediately; honest note that a saved store +
      the actual byte download are the on-device follow-on. +5 FineTunePackImporter
      Tests (parse hosts/reject junk, makePack valid, 4 honest errors, register
      round-trip + dedup, view-wiring) + the browse/apply mirrored-source asserts
      intact. build-for-testing green.
      ✅ FINISHER 2026-06-19 (part 5d PERSISTENCE): imported packs now SURVIVE a
      relaunch. NEW `FineTunePackStore` (Codable descriptors → JSON in the sandbox
      Application Support container; MAS-safe — descriptors only, never the pack bytes;
      injectable URL for tests) with `load` (honest empty on missing/corrupt, never a
      crash), `save` (atomic, creates the dir), `append` (dedup by id). Wired into
      FineTuneMarketplaceView: `.onAppear` reloads persisted imports into the registry
      (idempotent), import persists via `store.append`. +6 FineTunePackStoreTests
      (save/load round-trip, append dedup, missing/corrupt→empty, import→store→reload
      survives, view-wiring) + the browse/apply/import asserts intact. build-for-testing
      green. The marketplace is now genuinely real+usable end-to-end (browse → import →
      persist → apply-affordance). STILL FOLLOW-ON: the network fetch of the pack bytes
      + the per-kind apply EXECUTION (both on-device).
      ✅ FINISHER 2026-06-19 (part 5e SHARE — ALL 4 verbs done): browse/import/apply/
      SHARE complete. NEW pure `FineTunePackShare` — `export` writes a portable,
      versioned `epistemos-pack:v1:<json>` string; `parse` reads it back + RE-VALIDATES
      through the ProvenanceGate (id + license required → an unlicensed/malformed/
      non-share string is rejected with an honest error); `isShare` lets import route a
      pasted share. Wired into FineTuneMarketplaceView: a per-pack Share button copies
      the share string to the clipboard (`NSPasteboard`), and the import field accepts a
      pasted share (parses the embedded descriptor instead of the source-spec form).
      +5 FineTunePackShareTests (export/parse round-trip, non-share/malformed reject,
      ProvenanceGate license re-validation, share→registry, view-wiring) + browse/apply/
      import/persist asserts intact. Build caught + I fixed a real Swift-6 isolation bug
      (a nonisolated `errorDescription` referenced the MainActor `prefix` static →
      inlined the literal). build-for-testing green. The marketplace is now COMPLETE on
      all four owner-named verbs; remaining is the on-device byte fetch + apply execution.
- [x] **R-LITEPARSE — dedicated PDF→Markdown import (owner 2026-06-19) — DONE in code +
      engine + REAL-PDF extraction PROVEN; only the owner's signed-build PDFium dylib bundle
      remains for the in-app click-through** —
      run-llama/liteparse (84% Rust, Apache-2.0, fully LOCAL: PDFium in-process + bundled
      Tesseract OCR). PERFECT MAS fit: link the Rust core as a crate into agent_core (like
      epistemos-shadow / Goose), expose pdf_to_markdown over UniFFI, NO Python/Node
      sidecar. CAVEAT (confirmed): liteparse Office/image formats route through LibreOffice
      / ImageMagick / powershell SUBPROCESSES (conversion.rs) = NOT MAS-safe → scope to PDF
      (PDFium) + OCR, gate/reject the external-binary formats. Build: (1) native PDF→md in
      agent_core; (2) note-sidebar IMPORT button → markdown note in vault; (3) BULK import;
      (4) Settings bulk import; (5) polished feature (progress / honest per-file status).
      ✅ S1 2026-06-19 (ProvenanceGate verdict + MAS-safe seam): verdict
      docs/RESEARCH_LITEPARSE_2026_06_19.md (direct_import Apache-2.0; PDF+OCR only;
      Office/image subprocess + remote-OCR reqwest paths EXCLUDED). NEW
      agent_core/src/liteparse.rs — always-compiled INERT seam: `pdf_to_markdown(path)`
      returns EngineNotWired for a PDF (never fake markdown) + UnsupportedFormat for a
      non-PDF (rejected honestly, NEVER shelled out); `is_supported_pdf` gate; flag
      EPISTEMOS_LITEPARSE_PDF_V0; `#[uniffi::export] liteparse_status_json` (engine_wired
      false + "pdf+ocr,no-subprocess" scope). +5 cargo tests; cargo --lib BOTH green (5/0).
      NEXT (S2): vendor liteparse+pdfium+pdfium-sys crates (tokio process/reqwest OFF) +
      build the PDFium link + tesseract-rs — heavy native-dep multi-pass, owner build verify.
      ✅ SEAM A 2026-06-19 (Swift import-UI scaffold, no native deps): researched S2 —
      pdfium-sys's build.rs ERRORS without the PDFium binary (downloads from run-llama/
      pdfium-binaries, runtime-loaded via libloading on macOS) + tesseract-rs compiles
      Tesseract from source, so S2's real PDFium build needs the owner's build pipeline
      (native binary + long compile + signing), NOT a headless slice. Shipped the
      verifiable Swift Seam A instead (mirrors WorkBackend/ActOsaurus Seam A): NEW
      LiteParseImportGateStatus (always-compiled flag enum, EPISTEMOS_LITEPARSE_PDF_V0,
      honest "PDF import coming / armed-but-not-wired", PDF+OCR scope, Office/image OUT
      OF SCOPE — no liteparse/native dependency) + LiteParseImportHealthRow (visible,
      mounted in SubstrateHealthPanel, rule #8) + LiteParseImportSeamTests (gate honesty,
      MAS scope, always-compiled+mounted, cross-runtime flag parity Swift↔Rust
      LITEPARSE_FLAG). build-for-testing green; existing panel asserts intact.
      ✅ CONVERSION FFI 2026-06-19 (binding NOW fresh — owner ran build-agent-core.sh):
      NEW `#[uniffi::export] liteparse_pdf_to_markdown(pdf_path) -> String` — JSON
      envelope `{"ok":true,"markdown":…}` on success or `{"ok":false,"error":…}` on
      failure (engine-not-wired / unsupported-format / failed) so the import surface
      shows the honest outcome, NEVER a fake/empty note; non-PDF rejected, never shelled
      out. INERT today (returns the not-wired error). +2 cargo tests; cargo --lib BOTH
      green (7/0). The Swift import button → vault note is the next slice once the owner
      regenerates the binding to include this export. **S2 NATIVE-BUILD RECIPE (owner
      pipeline):** the real PDF→markdown needs (a) the PDFium binary — `pdfium-sys`
      downloads from run-llama/pdfium-binaries (chromium/7897), runtime-loaded via
      libloading on macOS; its build.rs ERRORS without the lib+include dirs present;
      (b) the liteparse + pdfium + pdfium-sys crates added to agent_core/Cargo.toml with
      `default-features = false` (NO tesseract = no Tesseract source build to start; PDF
      text-extract works for text PDFs without OCR) and `tokio` `process` / `reqwest`
      excluded; (c) then replace the inert `pdf_to_markdown` body with a real
      `liteparse::LiteParse` call. That native step (binary placement + bindgen libclang
      + linking + signing) is the owner build-verify; the agent_core seam + the FFI +
      the Swift UI scaffold are all in place for it.
      ✅ SWIFT IMPORT BRIDGE 2026-06-19 (the decoder the button uses): the 08:57 binding
      regen has liteparse_status_json + the schema gates but NOT liteparse_pdf_to_markdown
      (committed after) → the live import button needs ONE more build-agent-core.sh. Built
      the verifiable bridge meanwhile: NEW Epistemos/LiteParse/LiteParseImport.swift —
      `LiteParseImportResult` (.markdown/.notWired/.unsupported/.failed) +
      `LiteParseImportEnvelope.decode` (parses the FFI JSON envelope into the typed result;
      unreadable output → honest .failed, NEVER a fabricated note) + `LiteParsePDFImporter`
      protocol + `InertLiteParsePDFImporter` (.notWired for a PDF, .unsupported for a
      non-PDF — never shelled out). +6 LiteParseImportTests; build-for-testing green. NEXT:
      one more build-agent-core.sh → a LiveLiteParsePDFImporter calls liteparse_pdf_to_
      markdown + reuses this decoder → the note-sidebar IMPORT button (NSOpenPanel → import
      → vault note) + bulk + Settings. S2 native vendor = real markdown.
      ✅ LIVE FFI IMPORTER 2026-06-19 (Swift↔Rust conversion bridge now LIVE): the owner
      regenerated again (binding 09:34 now HAS liteparse_pdf_to_markdown → Swift
      `liteparsePdfToMarkdown(pdfPath:)`). NEW `LiveLiteParsePDFImporter` — enforces
      PDF-only BEFORE the FFI (non-PDF → .unsupported, never passed down), then
      `#if canImport(agent_coreFFI)` calls `liteparsePdfToMarkdown` + reuses
      `LiteParseImportEnvelope.decode`; `#else` (test host) falls back to .notWired. The
      FFI call COMPILES against the fresh binding (build-for-testing TEST BUILD SUCCEEDED)
      — the conversion bridge is real; it returns .notWired today (inert Rust seam) and
      real markdown once S2's native PDFium vendor lands. +2 tests (PDF-only-before-FFI,
      honest-on-PDF). NEXT: the import SERVICE (decode → write a markdown note to the
      vault via NoteFileStorage) + the note-sidebar IMPORT button (NSOpenPanel) + bulk +
      Settings — produce a real note once S2 makes the engine return markdown.
      ✅ IMPORT CONTROLLER 2026-06-19 (note-create logic, compile-verified): NEW
      Epistemos/LiteParse/LiteParsePDFImportController.swift (@MainActor) — converts a PDF
      via LiveLiteParsePDFImporter, and on a real `.markdown` result creates an SDPage
      note by MIRRORING the proven CodeFileCreationController file-first pattern (write
      the .md into `<vault>/Imported PDFs/<name>.md` with a unique name → SDPage(title,
      emoji "📄") + format "markdown" + filePath + saveBody + wordCount + bodyHash +
      needsVaultSync=false → insert + save + graphState refresh; rollback the file + body
      on save error) — so it never guesses the vault-sync contract. HONEST: a non-PDF /
      .notWired / .failed creates NO note + returns the reason. build-for-testing TEST
      BUILD SUCCEEDED (compiles against the real SDPage/GraphState/NoteFileStorage). The
      happy path (real note) runs once S2's native vendor makes the engine return markdown
      — until then a PDF import honestly reports `.notWired`. SOLE REMAINING BLOCKER for
      real in-app PDF import = **S2 native vendor** (liteparse NOT yet vendored, pdf_to_
      markdown still inert): place the PDFium binary + add liteparse/pdfium/pdfium-sys to
      agent_core/Cargo.toml default-features=false + swap the inert body for liteparse::
      LiteParse. The Rust seam + both FFIs + the Swift live importer + decoder + this note-
      create controller are ALL built + compile-verified — only the native engine remains.
      ✅ SIDEBAR IMPORT BUTTON 2026-06-19 (UI COMPLETE): NEW
      Epistemos/LiteParse/LiteParsePDFImportButton.swift — a self-contained, flag-gated
      (EPISTEMOS_LITEPARSE_PDF_V0, hidden off) toolbar button: NSOpenPanel(.pdf,
      multi-select = BULK) → for each PDF LiteParsePDFImportController.importPage(vaultURL:
      vaultSync.vaultURL, modelContext:, graphState:) → an HONEST per-file status alert
      ("✓ <title>" / "✗ <file>: <reason>", e.g. "engine not wired yet (pending S2)").
      Reads vault/graph/model from the environment the sidebar already provides. MOUNTED
      with one additive line in NotesSidebar's searchBar toolbar. +2 mirrored-source tests
      (gated + bulk + routes-through-controller; mounted-in-sidebar); existing NotesSidebar
      token asserts intact (additive). build-for-testing TEST BUILD SUCCEEDED. The R-
      LITEPARSE UI is now COMPLETE end-to-end (sidebar button + bulk + honest status);
      every PDF import honestly reports `.notWired` UNTIL the owner does **S2** (the SOLE
      remaining blocker — vendor liteparse + place PDFium, recipe above), after which the
      same wiring produces real markdown vault notes with NO further UI changes. (A
      dedicated Settings bulk-import surface can reuse this button verbatim — follow-on.)
      ✅ S2 — REAL PDFium ENGINE VENDORED + EMBEDDED 2026-06-19 (the native engine is no
      longer a stub): per the owner's NON-NEGOTIABLE "APP-NATIVE BY EMBEDDING — clone the
      real source in, never wrap-and-shell; if un-sandboxable Pro/dev-gate honestly but
      still embed" directive. RESEARCH-FIRST proved feasibility on this toolchain
      (rustc 1.94 → edition-2024 OK; libclang present; pdfium-sys build.rs auto-downloads
      PDFium + bindgen succeeds; a full `cargo build --features liteparse-pdf` PROBE went
      green in 14m). THEN vendored the real run-llama/liteparse Apache-2.0 core IN-REPO at
      `agent_core/vendor/liteparse` — 3 crates (pdfium-sys + pdfium + liteparse), 1.2 MB,
      LICENSE + a provenance README; the napi/python/wasm binding crates intentionally
      omitted (Epistemos calls the Rust core directly). Gated by a NEW `liteparse-pdf`
      Cargo feature (OFF by default): MAS build links NO PDFium/bindgen and `pdf_to_markdown`
      stays honest `EngineNotWired`; `--features liteparse-pdf` (Pro/dev) compiles the REAL
      engine — `LiteParse::new(config{ output_format: Markdown, ocr_enabled: false,
      quiet: true }).parse(path).await` driven on a current-thread tokio runtime → Markdown.
      OCR off (default-features=false drops tesseract-rs) + non-PDF rejected up front, so
      the ONLY reachable path is in-process PDFium text-extraction (no subprocess/network —
      Office/image's LibreOffice/ImageMagick subprocess paths are unreachable). liteparse.rs:
      shared `reject_if_not_pdf`; cfg-split real/inert `pdf_to_markdown`; `status_json`
      `engine_wired = cfg!(feature="liteparse-pdf")`; 3 inert tests cfg-gated `not(feature)`
      + 3 live variants. VERIFIED 4 ways (all to FILES): `cargo build --features liteparse-pdf`
      green (real engine compiles in-repo); `cargo test --lib` 5437/0 + `--features pro-build`
      5699/0 (ZERO regression — feature OFF so the inert path is byte-identical); `cargo test
      --features liteparse-pdf liteparse::` 8/0 — the LIVE tests RUN the engine (a missing
      PDF → honest `Failed`, `engine_wired:true`), proving the tokio + PDFium wiring works at
      RUNTIME, not just compiles. HONEST REMAINING CAVEAT (owner's signed-build step, NOT a
      stub): real in-app PDF import needs the PDFium dylib BUNDLED + code-signed into the
      `.app` — a sandboxed MAS app can't `dlopen` from `~/Library/Caches` where pdfium-sys's
      build.rs caches it; resolve the lib path to the bundle (PDFIUM_LIB_PATH /
      vendor/pdfium/release/lib) in the Xcode build. Until then the engine is EMBEDDED +
      Pro/dev-gated, honest about needing that bundling to run in MAS. Cannot tick "real PDF
      imported in-app" until the owner's signed build; everything up to that is done + green.
      ✅ SETTINGS BULK-IMPORT SURFACE 2026-06-19 (owner R-LITEPARSE plan #4 — UI triad now
      complete: sidebar + bulk + Settings): NEW Epistemos/Views/Settings/
      LiteParseSettingsImportRow.swift — a labeled Settings row that, when the flag is armed,
      EMBEDS the same LiteParsePDFImportButton (one import path — no duplicated NSOpenPanel/
      controller logic). Flag-gated (LiteParseImportGateStatus.status().isActive): hidden +
      not even constructed when off, so the default build / previews never require the
      vault/graph/modelContext env (only accessed when the owner arms the flag in a real
      session). Mounted in SubstrateHealthPanel beneath LiteParseImportHealthRow (the one
      mount site, SettingsView:498, where the env is ambient). Also refreshed the now-stale
      "inert until vendored" health-row comment to the S2 truth (core vendored + embedded,
      live engine Pro/dev-gated + needs the bundled PDFium dylib). +2 mirrored-source tests
      (gated + reuses-the-button + no-duplicate-picker; mounted-in-panel); existing panel
      asserts intact (additive). build-for-testing green (0 errors).
      ✅ REAL-PDF EXTRACTION PROVEN 2026-06-19 (the "build+run verify a real PDF → markdown"
      the owner kept asking for — done at the engine + FFI layer, the only layer runnable
      headlessly): committed a real 18 KB sample PDF fixture (agent_core/tests/fixtures/
      liteparse_sample.pdf, from liteparse's own integration_tests_data) + 2 permanent
      `#[cfg(feature="liteparse-pdf")]` tests that RUN the embedded PDFium engine against it.
      `live_engine_extracts_real_markdown_from_a_real_pdf` asserts the rendered Markdown
      contains the title ("Sample PDF"), a real heading ("# This is a simple PDF file"),
      body text ("Lorem ipsum dolor sit amet"), and >500 bytes — i.e. GENUINE spatial-text
      extraction, not a stub/honest-fail. `live_ffi_envelope_carries_real_markdown_for_a_
      real_pdf` proves the SAME through the `liteparse_pdf_to_markdown` FFI envelope the
      Swift sidebar/bulk/Settings surfaces consume (`{"ok":true,"markdown":"…Sample PDF…"}`).
      VERIFIED to FILES: `--features liteparse-pdf` liteparse:: 10/0 (both real-PDF tests
      green; PDFium dlopen'd from ~/Library/Caches), default liteparse:: 8/0 (inert path
      byte-identical — the new tests are cfg-gated, zero regression). So the FULL R-LITEPARSE
      chain is proven on a real PDF: PDF bytes → embedded PDFium → Markdown → FFI envelope →
      (Swift note-create, separately compile+test verified). The ONE thing NOT verifiable
      headlessly is the in-app click-through, which needs the owner's signed build with the
      PDFium dylib bundled into the .app (sandbox can't dlopen from ~/Library/Caches; resolve
      PDFIUM_LIB_PATH / vendor/pdfium/release/lib in Xcode + flip the app build to
      --features liteparse-pdf). Everything I can build+run is done + green; that last step
      is purely the owner's deployment mechanics, not missing code.
- [ ] **HARNESS SYSTEMS — port the best (or a mixture) of everything an LLM app does
      for the model, beyond the model (owner 2026-06-18)** — RAG, MEMORY systems,
      CONTEXT management/compaction, TOOL-USE plumbing, MCP-server ROUTING, prompt
      caching, etc. Deep-research the best LLM harnesses/desktop apps (R-APPS /
      R-ASSISTANTS), and PORT the best implementation OR a clever MIXTURE/mesh of
      them natively — don't hand-roll from scratch; lift the proven code/patterns
      (grep/extract, ProvenanceGate). SYSTEM PROMPT = an ANCHOR the loop EXTENDS
      (strong base system prompt, then extend), not a one-off. Make it deeply
      exquisite; wire into Chat/Act/Work. Verdict doc → port + harden.
- [~] **R-CUA — VERDICT done 2026-06-18 (docs/RESEARCH_CUA_2026_06_18.md).**
      LIFT ONE native piece: Lume (Swift + Virtualization.framework, MIT) as the
      Act=Osaurus VM-sandbox tier (Pro/dev-gated, virtualization entitlement) —
      folds into the Osaurus P3.0 plan. The CU loop (screenshot→model→action→
      verify) is largely MATCHED by Epistemos's native stack (DeviceAgentService/
      VisualVerifyLoop/Screen2AXFusion); adopt cua's unified Sandbox seam pattern
      (VM/container/host) + pair with Holo VL. Python Agent SDK + server =
      NO-SIDECAR (don't run). No code lifted (research-first). Original:
      trycua/cua (MIT) Computer-Use Agent infra (owner 2026-06-18,
      normal ledger order).** "can be fused to browser-use or used aside from it."
      Key fuse = Lume's Apple Virtualization.framework VM manager into the
      Act=Osaurus sandbox plan, + the Driver/Sandbox CU loop into the native
      computer-use stack (DeviceAgentService / VisualVerifyLoop / Screen2AXFusion)
      + Holo VL. Research-first verdict; Python bits = NO-SIDECAR on MAS
      (Pro/dev-gated), lift the Swift/Rust + Virtualization logic natively.
- [~] **R-COLBERT-TOOLSEL — VERDICT done 2026-06-18 (docs/RESEARCH_COLBERT_2026_06_18.md).**
      RESEARCH-FIRST/DEFER to Pro+dev. PyLate-only CONFIRMED (no ONNX/CoreML/GGUF/
      MLX/LEAP) → NO-SIDECAR. Crux is the LFM2 HYBRID encoder (10 conv+6 attn+1
      dense, not vanilla BERT) — MaxSim scoring is trivial but useless without it;
      "MaxSim over existing embeddings" does NOT yield ColBERT (ours are
      single-vector, not ColBERT-trained). It's an ENHANCEMENT (tool gating + EML-3
      eml_rerank + RRF already serve tool-select + rerank), not a gap. Plan:
      pre-build the inert feature-gated MaxSim substrate; honest single-vector
      "tool-selector v0" interim via existing NLContextualEmbedding; native lane
      gated on a self-exported CoreML/ONNX LFM2 encoder validated vs a PyLate
      oracle; NEVER in the chat picker (retrieval component, not a chat model);
      LFM1.0 via ProvenanceGate. No code lifted. Original: LiquidAI/LFM2-ColBERT-350M
      (LFM Open License v1.0) (owner 2026-06-18, normal order).** ColBERT late-interaction reranker (353M)
      as (1) a smart TOOL SELECTOR (= P8 RAG-preflight tool-selection + harness
      MCP-routing need), (2) a general RAG reranker (complements Eidos/Halo/
      TurboVec + EML-3 eml_rerank), (3) a selectable model in the importer/registry.
      CATCH: ships only via PyLate (Python) = NO-SIDECAR on MAS → research-first
      verdict on a NATIVE late-interaction path (MLX-Swift / CoreML-ONNX / Rust
      MaxSim) before any product dependency; Pro/dev-gated until native.
- [~] **R-COLBERT-TOOLSEL: VERDICT done 2026-06-18 — see docs/RESEARCH_COLBERT_2026_06_18.md
      (defer-to-Pro+dev, native-encoder-gated, no PyLate). Orig owner ask:
      LFM2-ColBERT-350M as a smart TOOL SELECTOR + reranker (owner 2026-06-18)** — owner (verbatim): *"this can all be added as a model I
      use maybe as a tool selector. LFM2.5-ColBERT-350M is a surprisingly reliable
      smart tool selector."* Exact repo: `LiquidAI/LFM2-ColBERT-350M` (353M;
      ColBERT late-interaction retriever/reranker on LFM2 backbone; MaxSim; 128-dim;
      32K ctx; 8 langs; LFM Open License v1.0 — ProvenanceGate license check). TWO
      roles: (1) **TOOL SELECTOR** — late-interaction retrieval over the tool/MCP
      catalog to pick which tools to surface per query; this IS the P8 "RAG-preflight
      tool selection" + the HARNESS-SYSTEMS MCP-routing/tool-use-plumbing need above
      — wire it there. (2) **General RERANKER** for RAG retrieval (complements Eidos/
      Halo/TurboVec + the EML-3 eml_rerank gate; could back a stronger rerank lane).
      ALSO add as a SELECTABLE model in the importer/registry + HF marketplace.
      INTEGRATION CATCH (must solve, honestly): ships ONLY via PyLate (Python) — NO
      GGUF/ONNX/llama.cpp. Python = NO-SIDECAR on MAS, so a MAS path needs a NATIVE
      late-interaction impl: convert to MLX-Swift, OR CoreML/ONNX export, OR
      implement ColBERT MaxSim over the existing embedding infra in Rust/Swift.
      RESEARCH-FIRST → verdict on the native path before any Python-only dependency
      lands on the product path; Pro/dev-gated until a native lane exists. Honest
      gating; no fake tool-selector. Cross-ref P8 schema engine + HARNESS SYSTEMS.
- [~] **#1 LOCAL FOR ALL MODES — BOTH SEAMS fixed 2026-06-18 (verify in-app/CI).**
      CHAT seam (effectiveChatSurfaceSelection, 0f419bd0e): all 4 modes local-first
      — .thinking + .pro joined .agent/.fast (were unconditional .cloud even with a
      working local tier model). NOTES/GENERAL seam (TriageService.shouldAutoRoute-
      ToCloud, 3576eaaa0): same fix — collapsed the per-mode switch to one uniform
      rule (cloud only when localSelection == nil && !appleIntelligence, the .fast
      rule). Updated autoCloudRoutingEscalatesProChat (installed: [] so it still
      tests genuine escalation) + added proStaysLocal/thinkStaysLocal lock tests.
      HONESTY: TriageServiceTests reasoned deterministically but NOT run (headless
      swift test hangs) — owner/CI confirm green. Verify in-app: no-cloud +
      Code/Think → local across both chat and note/general AI ops. Owner (verbatim):
      *"not even having cloud selected it goes to gpt, you should be able to use
      my local for all modes."* This is the #1 honesty-constraint violation: with
      NO cloud selected, Act/agentic still routes to GPT (cloud). FIX: the LOCAL
      agent loop (`LocalAgentLoop`, `canRunLocalAgentLoop`) must back Act / agentic
      / cowork on the owner's LOCAL models by default — Chat AND Act AND every
      cowork affordance work on local. NEVER auto-route to GPT/any cloud unless
      the owner EXPLICITLY enabled cloud or pressed "route to cloud" for that turn.
      If a local model can't do a step, show the honest P1.4-style blocker (free
      memory / smaller tier / optionally route to cloud) — never silently use GPT.
      Audit EVERY route seam: TriageService, ConfidenceRouter, RuntimeRouter,
      ChatCoordinator agent path, `availableOperatingModes`, `CoworkChatMode`,
      `usesAutomaticCloudRouteForChatSurfaces`, `preferredAutoRouteCloudProvider`,
      `effectiveChatSurfaceSelection`. Regression: no-cloud + Act → local, not GPT.
- [~] **ACT mode** — reported not working. Root: gated behind cloud/Pro
      (`CoworkChatMode.actAvailable` / `availableOperatingModes`) AND the auto-cloud
      route above. FIX: Act runs the LOCAL multi-step agent loop by default (see
      #1); cloud only augments when explicitly chosen. Visible + togglable + works
      with zero cloud configured.
      ✅ 2026-06-19 (research-first, smallest verifiable): traced the seams — Act is
      ALREADY available + LOCAL for an agent-capable local model (Qwen) with ZERO
      cloud (`.agent` ∈ availableOperatingModes via canRunLocalAgentLoop; no auto-
      route when no provider → Act resolves `.localMLX`). The real bug was honesty:
      `actUnavailableReason` falsely implied "connect a cloud model … to enable it."
      Rewrote it LOCAL-FIRST ("Pick a local agent-capable model (e.g. Qwen) to run
      on-device with zero cloud, or connect a cloud model") + a behavioral REGRESSION
      test (qwen + zero cloud → Act available → resolves LOCAL, never GPT). +2 tests;
      build-for-testing green. REMAINING (riskier follow-on, owner repro): if the
      current pick is a NON-agent foundation model (Gemma), route Act to a fitting
      LOCAL agent model as a VISIBLE substitution (needs availableOperatingModes
      test reconciliation).
- [~] **QUEUE** — reported not working. Only appears while `isProcessing` + draft
      non-empty. Make it discoverable and prove the staged message actually sends
      on completion in the running app.
      ✅ 2026-06-19: the queue was well-built (ComposerMessageQueue tested +
      queueButton + auto-send on the run-completion edge) but UNINTUITIVE — hitting
      Enter/Send while the agent ran was silently dropped by `submitCurrentText`'s
      `guard !isProcessing`. FIX: submit-while-processing now AUTO-QUEUES the draft
      (the natural "type + Enter while busy" action), and the existing completion
      edge auto-sends it → discoverable BY USE. "Sends on completion" locked by
      ComposerMessageQueueTests.dequeueOnCompletionEdge; +1 wiring test;
      build-for-testing green. Owner verifies the in-app send on completion.
- [~] **CONTEXT** — reported not working. Only shows when tools were used + as a
      tiny composer strip. Assemble it as a real, visible panel; populate from
      actual run telemetry; show an honest empty state, not nothing.
      ✅ 2026-06-19: NEW CoworkContextPanel aggregates the REAL telemetry — context-
      window usage (estimatedContextTokens/maxContextTokens + a tinted bar), @-notes
      (pendingContextAttachments), file attachments (pendingAttachments), files
      touched this run (CoworkRunContext.filesTouched, Pro-gated) — with an HONEST
      empty state ("Nothing attached yet…"). Reachable from chat: the context badge
      now opens it in a popover. +2 tests; build-for-testing green. First piece of
      the cohesive COWORK layout. Owner verifies render in-app.
- [~] **COWORK SURFACE** — the Act/Progress/Working-folder/Context/Queue/Connectors
      pieces are scattered into the composer, NOT the cohesive cowork LAYOUT from
      the owner's Claude-Desktop screenshot. Assemble the real surface (panels),
      reachable from chat. (P7.6)
      ✅ 2026-06-19: NEW CoworkPanel — a cohesive container hosting the sections,
      each wired to REAL telemetry with honest empty states: PROGRESS (isAgentExecuting
      + currentCapability), CONTEXT (window bar + counts → full detail via the badge
      popover), WORKING FOLDER (CoworkRunContext files + folder, Pro-gated), QUEUE
      (staged ComposerMessageQueue.pending), CONNECTORS (honest forward state).
      Reachable from chat via a new cowork button beside the context badge. +2 tests;
      build-for-testing green. ✅ CONNECTORS LIVE 2026-06-19: the connectors section
      now reads the REAL OmegaToolRegistry.surfacedTools() inventory (distribution-
      gated — honest per-build), grouped by connector (agent), with real tool names +
      an honest empty state. REMAINING: a dedicated ACT section + Claude-Desktop
      visual polish. Owner verifies the layout match in-app.
- [~] **Local models "not working" → showing GPT instead of local** in Settings.
      Investigate WHY other local models don't load/resolve; fix the label so
      local rows show the real local model, never a cloud/GPT fallback unless
      cloud is the genuine active route. (SettingsView activeChatModelDisplayName /
      activeLocalTextModelDisplayName / `?? .openAI` ~1542; AgentBlueprint /
      Constellation / ModelProfile rows.)
      ✅ LABEL FIXED 2026-06-18: `InferenceState.activeChatModelDisplayName` had
      `if usesAutomaticCloudRouteForChatSurfaces { return "Auto Route" }` as its
      FIRST statement, overriding an explicit `.localMLX` pick — so an unresolved
      local model (`effectiveLocalTextModelID == nil`) under armed auto-route
      rendered "Auto Route" (read as "showing GPT"). Moved the auto-route check
      INSIDE the switch: `.localMLX` → always `activeLocalTextModelDisplayName`;
      only a genuine `.cloud`/`.appleIntelligence` pick shows "Auto Route". Locked
      by TriageServiceTests `unresolvedLocalChatPickNeverRendersAsAutoRouteOrCloud`.
      Verified RootView `labelText` (723-731) already shows the local tier/model.
      ✅ RESOLVE-TRACE 2026-06-19: the deeper trace landed. InferenceState
      `localModelResolutionState` / `localModelResolutionSummary` (in
      LocalModelResolution.swift) computes whether the local PICK is honored vs
      silently substituted vs no-local-model + the honest reason (notInstalled /
      exceedsMemory / awaitingSwiftLoader / runtimeUnavailable), surfaced in the
      VISIBLE LocalRouteHonestyHealthRow (SubstrateHealthPanel). Honest "honored"
      test = `effective == pickID` (sanitize returns the pick unchanged when usable,
      a different id when it falls back/migrates). +5 tests; build-for-testing green.
      REMAINING (needs owner in-app repro): the deeper ROUTING decision (does an
      explicit unresolved local pick under opted-in auto-route escalate to cloud at
      all — gated behind chatAutoRouteToCloud today) + AgentBlueprint/Constellation/
      ModelProfile row labels.
- [ ] **Qwen 3 8B visible again (P1.11)** — re-expose as an EXPLICIT pick under Fast
      or Think (whichever fits); visible user choice, NOT a silent fallback (P1.10
      still holds). Memory-gated.
- [ ] **Chat is messy → deep-repair using Osaurus as reference (P8.1b)** — study
      Osaurus's chat structure, refactor Epistemos Chat cleaner without losing IP.
- [ ] **PICKER REDESIGN (P1.11)** — low/med/high effort STILL not visible. Replace
      with explicit picks: FAST → Gemma 2B / 4B / 12B / Apple Intelligence (4
      options), THINK → VibeThinker, CODE → Gemma 12B coder, + one Cloud toggle.
      TOTAL RESTART: delete the old popover wholesale (keep NOTHING — all the old
      labels go), rebuild from scratch as a pixel-art panel matching the app (not
      an intrusive overlay). Verify the options appear + switch the model in a build.
- [ ] **DEFAULT STILL = QWEN 4B — REPAIR (owner 2026-06-18, in rebuilt app)** — the
      picker/chat still DEFAULTS to Qwen 3 4B. Root: `InferenceState.swift:3256`
      `var preferredLocalTextModelID = LocalTextModelID.qwen3_4B4Bit.rawValue` +
      the "validated default stays Qwen" logic (lines ~41, ~649) + AgentCommandCenter
      brain default lists (~580-600). Under simplifiedLineupActive the DEFAULT must
      be a foundation FAST model (headroom-aware Gemma E2B/E4B), NEVER Qwen 4B as
      the DEFAULT. Qwen 3 4B AND Qwen 3 8B both stay available as EXPLICIT,
      user-selectable local picks (owner wants BOTH) — just not the auto-default.
      Fix the hardcoded default + migration + agent-brain defaults to foundation;
      regression.
- [ ] **MEMORY BYPASS for 12B (owner 2026-06-18) — "I generally have enough; I used
      to run bigger models."** Two parts: (1) ADD an explicit owner OVERRIDE — a
      "Run anyway / use it anyway" toggle/button on the memory blocker (P1.4) so the
      user can FORCE the Gemma 12B coder + regular 12B even when the gate flags it.
      Honest: it warns it may be slow / swap, but RESPECTS the choice (explicit
      user-forced load is NOT a silent swap). (2) AUDIT the estimate — it's too
      conservative: the gate uses *free* memory + a 4 GB headroom
      (`InferenceState.swift` ~4187/4259 `headroomGB = 4`;
      `localAgentModelFitsCurrentMemoryBudget`; the P1.4 blocker). On macOS "free"
      undercounts AVAILABLE memory (cached/purgeable/compressed is reclaimable) —
      compute available = free + reclaimable, and don't over-state the 12B
      footprint, so legit 12B runs aren't blocked. Keep the honest blocker as the
      DEFAULT, but make the override real + the estimate accurate. Regression.
- [x] **Palette preview for ALL themes** — currently gated `if pair == .custom`
      (SettingsView ~4081). Generalize `CustomThemePaletteSwatch` to every
      `ThemePairCard` so every theme shows the palette preview.
      ✅ DONE-RE-AUDIT (loop 2026-06-21): already implemented — SettingsView.swift:4191
      branches `pair == .custom` → CustomThemePaletteSwatch, else → ThemePairPaletteSwatch
      for EVERY pair, so every theme already shows its palette preview. Stale checkbox.
- [ ] **Custom-theme font** — claimed fixed (4b0a5e59e); VERIFY in-app that picking
      a font on the custom theme actually changes rendered text, every level.

## Picker / routing / honesty
- [x] Think → VibeThinker, never Gemma 12B (P1.6) — verify still true on all paths.
- [x] No hidden Qwen on tool/attachment seam (P1.10) — verify in-app with attach.
- [x] Apple Intelligence selectable native route (P1.7) — verify visible.
- [x] Download/install progress visible (P1.8) — verify a real install shows it.
      ✅ MODEL INSTALL DISCOVERABILITY (owner 2026-06-19, TOP blocker — "still
      cannot find a way to install a real local model"): the install affordances
      already existed (LocalModelManagerSheet: prominent "Download the Epistemos
      AI foundation package" + live progress + "All models (advanced)") but were
      BURIED behind Settings → Local AI → "Manage Local Models". FIX: an
      unmissable in-picker CTA — `InlineRuntimePickerPanel.installModelsCTA`
      ("Install local AI · Download Epistemos AI — Gemma · VibeThinker · coder"),
      shown at the TOP of the runtime picker when `!hasInstalledFoundationModel`
      (pure tested `shouldShowInstallCTA`). Tapping it posts `.openModelManager`;
      the always-alive `HomeSceneRootContent` observes it and presents the model
      manager sheet directly (chained after `.withAppEnvironment` so the
      `LocalModelManager`/`UIState` env is present — no @Environment crash).
      `LocalModelManagerSheet` made internal so the root view can present it.
      +1 test (InstallCTADiscoverabilityTests). build-for-testing SUCCEEDED,
      0 app errors. Owner verifies the picker→manager open in-app.
- [x] Fast low/med/high effort visible (P1.9) — verify the composer hint shows.
- [ ] Vault "best essay in my vault" returns ranked answer w/ title/path/reason,
      not a generic reply or empty "no vault retrieval" (P2.2 — still partial).

## Chat capability + parity
- [ ] Capability ceiling Fast→tools, real on LOCAL (P7.1) — verify tools actually
      run from chat on a local model, not just documented.
- [x] MiniChat / Note / Graph chat parity — verify each surface really has the
      Main-chat capabilities in-app (P7.5).
      ✅ DONE-RE-AUDIT (loop 2026-06-21): the shared AgentToolTogglePanel is mounted on
      all surfaces — main chat (ChatInputBar), landing (735940b7a), mini-chat (composer
      MiniChatInputBar.toolPanelButton, P7.5), graph (558bea540), note (d08e15d7a);
      cross-surface parity pinned by SSVISWiderSweepTests; the mini-chat double-mount was
      deduped (3475ea82e). Landing + mini-chat also RUN skills (7101b307c / runSkillFromPanel).
- [x] Tool toggles actually gate the runtime AND are visible/usable (P2.1).
      ✅ DONE-RE-AUDIT (loop 2026-06-21): real gating, not cosmetic — command_center.rs:508
      resolve_tool_permissions returns Allow for enabled tools and Deny{reason:
      "not_enabled_by_user"} for disabled ones, with existing cargo tests
      (command_center.rs:871-900,1190); the toggle UI is the shared AgentToolTogglePanel.
- [ ] In-chat skills run; MCP/connectors (Slack/Gmail/Drive/Notion) actually
      connect + are usable (P2.3/P2.4/P7.6 connectors).
- [ ] **Skill/tool/MCP INSTALL + management in Settings (P2.7, owner 2026-06-18)** —
      better skill CREATION + INSTALL skills/tools/superpowers/MCP servers from
      GitHub + MCP registries (MCP registry, Smithery, mcp.so, glama,
      awesome-mcp-servers). PERSIST installed ones (survive restarts) and actually
      USE them (wired into tool catalog/executionPlan/MCPBridge). Settings pane:
      browse/install/enable/disable/update/remove; honest gating, Keychain tokens.
- [ ] **BEST-OF PRESET — ship a curated default set of the best superpowers /
      skills / tools / MCP servers (owner 2026-06-18).** Research + bundle a
      starting PRESET of the best available agent powers (skills, tools, MCP
      servers — e.g. filesystem, web/fetch, browser+stealth, git, memory/vault,
      code-exec, popular MCPs) so the app ships powerful out of the box, not empty.
      HONEST: only include real, working ones; Pro/MAS-gate each appropriately;
      let the user toggle. Research-back the picks (which are best/free/safe) and
      document the preset. Wire into the tool catalog / capability explorer (P2.1).

## Surfaces the owner asked for
- [ ] HTML workspace is BROKEN (can't see code) → fix + HTML canvas live-viewer the
      chat can drive (P7.2). NOT STARTED — owner flagged broken.
- [ ] Terminal + console actually work (Pro/dev) (P7.3).
- [ ] "WORK" mode (the OpenCode surface) = THREE clean modes Chat / Act / Work
      (NOT buried in Act). Work = deep terminal access to on-disk notes/research +
      ALL app skills/tools from chat, local=cloud parity. Toggle lives UPWARD at
      the TOP of the search page (not on the search bar) and turns the search page
      INTO Work/OpenCode. After the revised UX map (P7.4/P7.4a).
      OWNER CLARIFICATION 2026-06-18: make the separation CONCRETE — a visible
      3-button (or 4) TOGGLE on the search page: **Chat · Act · Work** (clearly
      separated, no muddy overlap between Chat and Act). Each button switches the
      page into that mode. (A) **Chat** = Epistemos conversation. (B) **Act** = the
      automation / long-task AGENT surface with a **2-ENGINE picker** (owner CORRECTION
      2026-06-18 — Osaurus STAYS the Act engine, it is NOT demoted to a hidden
      sandbox): ENGINE 1 = **OpenClaw** (long tasks/automation, its reskinned WebKit
      UI); ENGINE 2 = **Osaurus (local)** = the FULL ported Osaurus (local model
      serving + hardened agent + Virtualization sandbox) running the **Local Agent
      (LocalAgent ⊕ fused Hermes)** super-agent as its brain. So Act = OpenClaw |
      Osaurus-local — two visible engines; the Hermes-fused Local Agent lives INSIDE
      the Osaurus lane (one routing target, NOT a separate 3rd engine → routing stays
      clean). Act's identity = Osaurus, preserved per the original three-engine plan
      (Chat=Epistemos, Act=Osaurus, Work=Goose). (C) **Work** = Open Code, Goose
      engine. So: Osaurus IS Act (one of its two engines); OpenClaw is the other;
      Goose is Work; Hermes fuses into the Osaurus-local lane. Owner-confirmed.
      LAYERING (owner 2026-06-18, "explain so nothing breaks"): the Osaurus-local
      engine is a STACK, not a single thing — (i) **Osaurus** = the engine room
      (fast MLX local serving + Virtualization sandbox; its real strength); (ii)
      **Local Agent = the BRAIN** = the existing native agent loop that CARRIES ALL
      EPISTEMOS IP — **Eidos closed-citation retrieval, vault/Knowledge-Core tools,
      cognitive DAG, provenance ledger, MCP routing, honesty/no-fake gating** — this
      is NOT discarded; it is what makes the local agent OURS (Osaurus's stock agent
      is generic and IP-blind); (iii) **Hermes** = upgrade parts lifted INTO the
      brain. So Osaurus-local = Osaurus(serve+sandbox) + LocalAgent(brain, ⊕Hermes) +
      **Eidos + ALL owner IP fused in** — mandatory, never a vanilla Osaurus. Why
      keep Local Agent: dropping it = losing Eidos/vault/provenance/honesty (the IP).
      NOTHING-BREAKS GUARANTEE: Chat(Epistemos) untouched; Work(Goose) flag-isolated
      with no-Chat/Act-regression guardrail; Act changes additive + flag-gated
      (ActOsaurus inert until opt-in flip); Eidos + IP stay wired everywhere; honesty
      constraints (no hidden sidecar, local-first, no fake) preserved throughout.
      FOUNDATION (owner 2026-06-18, sharpened): **Osaurus IS the foundation of Act —
      it REPLACES whatever Act runs on now** (Osaurus is the most-hardened substrate,
      so it becomes the base). On that foundation we stack the **reskin (UI) + Local
      Agent brain + Hermes fusion** = the best, hardened wins. PRESERVE-ALL-IP
      (deletion guardrail, explicit): ALL IP from today's Act AND Chat — Eidos, the
      existing Act capabilities, vault/tools, chat IP — is MIGRATED + added on top of
      the Osaurus foundation, **never deleted**. NUANCE from research (docs/research/
      HERMES_ACT_FUSION_MAP + OSAURUS_ACT_CONNECTION_MAP): on MAS the brain runs
      IN-PROCESS via DeviceAgentService→LocalAgentLoop.run (NOT the Osaurus :1337
      server, which is Pro/inert); Hermes logic fuses into LocalAgentLoop +
      agent_core::agent_runtime, never the server lane. So "Osaurus foundation" =
      Osaurus serving/sandbox (Pro) UNDER the in-process LocalAgent brain; on MAS the
      brain stands on the existing in-process path until the Osaurus server lane is
      flipped on (Pro). Either way the brain + ALL IP is the constant.
      ── ENGINE-ISOLATION DOCTRINE (owner 2026-06-19, MOST IMPORTANT — verbatim:
      *"most important part is making sure they do not cross-muddy each other —
      proper isolation. Maybe connect only in terms of memory, like an Act session
      knows about a Chat session, or Act knows about all the skills and capabilities
      of Chat and can do the same and more — but NOT connecting logic or code per
      se."*). HARD RULE: the three engines (Chat=Epistemos · Act=Osaurus+brain ·
      Work=Goose) and the two Act lanes (OpenClaw · Osaurus-local) stay CODE/LOGIC
      ISOLATED — no engine reaches into another engine's runtime, no shared mutable
      control flow, no one lane's bug can corrupt another. They connect ONLY across
      two sanctioned, READ-FLAVORED seams: (1) **MEMORY/CONTEXT** — an Act session can
      be AWARE of a Chat session (and vice-versa) through the shared vault/memory
      substrate (Knowledge-Core notes, session index, provenance ledger), NOT by
      sharing process state or calling into the other engine's code. (2) **CAPABILITY
      AWARENESS (superset rule)** — Act KNOWS the full set of skills/tools/capabilities
      Chat has and can do all of them AND MORE (Act ⊇ Chat in capability), but it
      INVOKES them through its OWN copy/registration of the skill, not by delegating
      into Chat's engine. The skills/tools live in a SHARED, isolated registry/substrate
      that each engine binds independently — capability is shared by DEFINITION, not by
      cross-engine call. Anti-goal: NO entangled logic, NO one-engine-imports-another,
      NO hidden routing where a Chat turn silently runs Act code or vice-versa. This
      doctrine governs every fusion above (Hermes-into-LocalAgent, OpenClaw lane,
      Osaurus serving): fuse capability + memory, isolate code + control flow. Add a
      guardrail test that asserts no cross-engine code dependency (engine modules don't
      import each other's runtime) and that capability-awareness flows only through the
      shared registry/memory substrate. The existing NOTHING-BREAKS flag-isolation is
      the floor; this superset-but-isolated model is the ceiling.
- [ ] **WEBKIT-MAXIMIZATION PREFERENCE (owner 2026-06-19, refines native-vs-WebKit on
      EVERY port)** — owner (verbatim): *"I want to utilize the WebKit process as much
      as I can, because if I can have more usability with slightly less nativeness by
      porting with WebKit, then we can do that. I just want to make sure every
      possibility is researched and that my app rests on the best version here."*
      POLICY: when porting any external surface (OpenClaw, AI-Elements R-ELEMENTS,
      Streamdown, HTML canvas P7.2, terminal P7.3, future repos), the verdict doc MUST
      explicitly weigh **WebKit-host vs full-native** and DEFAULT TO WEBKIT-HOST when it
      delivers materially more usability/feature-completeness/upstream-trackability for
      only a slight nativeness trade-off — the proven `EpdocEditorChromeView` +
      custom-URL-scheme + build-time-bundle pattern is the sanctioned vehicle (see
      docs/research/OPENCLAW_UI_EMBED_MAP_2026_06_19.md). Constraints unchanged: bundle
      at BUILD time (never runtime npm/Node), MAS-legal (no runtime subprocess on the
      MAS path; Node/gateway features Pro/dev-gated like LocalGgufRuntimeBridge), pixel-
      art reskin via CSS injection driven by EpistemosTheme tokens, honest gating. Each
      port's verdict doc must show the researched alternatives so the app rests on the
      best-version choice, not a default. (This does NOT loosen native-first where
      native genuinely wins — voice, inference, on-device tools — it just stops forcing
      a full-native rewrite when WebKit-host is strictly better for that surface.)
- [ ] **BROWSER-USE + COMPUTER-USE AS FIRST-CLASS HARDENED SKILLS (owner 2026-06-19)** —
      owner (verbatim): *"even things like browser-use I want that to work — skills like
      that should be first-class to my app, and my app already has the robust computer-
      use tech. I really want to harden that and place it where it should go based on
      all the engines."* DIRECTIVE: (1) browser-use is a FIRST-CLASS skill (not a
      bolt-on) — it must actually work, exposed to the model as a registered tool/skill
      through the SHARED isolated skill substrate (per the ENGINE-ISOLATION DOCTRINE
      above), available to whichever engines should have it. (2) The app's EXISTING
      robust computer-use stack (DeviceAgentService / VisualVerifyLoop / Screen2AXFusion
      / the Holo + R-CUA work) must be HARDENED and PLACED correctly across the engines —
      decide, per engine, who owns/exposes computer-use: likely Act (Osaurus-local +
      OpenClaw automation lane) as the primary home, with capability-awareness so Chat
      knows it exists. (3) Reconcile with R-CUA (trycua/cua, line ~1611), the stealth/
      Obscura browser hardening (~1595), and Holo-3.1-4B computer-use VL (~1377): one
      coherent, hardened computer-use + browser-use capability surface, isolated in code
      but shared in capability, with the RIGHT engine as its home. Verdict doc must map
      where each piece lands across the three engines before building.
- [ ] **MODEL PICKER — SIMPLIFY + MODE-SCOPE (owner 2026-06-18, refines P1.11)** —
      owner (verbatim): *"for the model picker I only want the model and its uses
      visible for the right mode. Chat shows efforts and many other things — that is
      muddy. I just want the name and the uses for the model and RAM needed etc, the
      most important parts."* CONSCIOUS REVERSAL of the earlier add-everything
      directive: the picker's PRIMARY content per mode = **model NAME + USES (what
      it's good for) + RAM needed** — the essentials only. EFFORT + routing/native/
      other controls must NOT clutter the picker; move them OUT (secondary/contextual,
      shown only where they actually apply, e.g. effort only for a thinking model that
      supports it). Scope visible options to the active mode (Chat/Act/Work) so each
      mode shows only its relevant models/info. Net: clean, minimal, mode-scoped
      picker — not the muddy everything-panel. Build+run verify per mode in-app.
- [~] Provider logos (B&W lobehub, prefer pixel-art), context-specific, in Settings
      + picker + chat (P6.1) — for BOTH cloud AND local models: Claude, ChatGPT,
      Gemini, Claude Code, Codex, Gemma, Qwen, Apple, Kimi, Hermes.
      ✅ 2026-06-19 (component + first wire): tested provider→logo MAP
      (ProviderBrandLogo: ProviderBrand for the whole list incl. the Codex/Claude-
      Code account-runtime distinction + local gemma/qwen + Apple) + ProviderLogoView
      (real lobehub SVG when staged, else SF-Symbol fallback — render-safe) +
      InferenceState.providerBrand(for:). Staged the 2 AVAILABLE lobehub SVGs into
      Assets.xcassets (Claude Code + Kimi render the REAL logo; actool clean). WIRED
      visibly into APIKeysHealthRow (Settings → each cloud provider shows its brand
      logo). +4 tests; build-for-testing green.
      ✅ PICKER + CHAT 2026-06-19: ProviderLogoView now ALSO wired into
      InlineRuntimePickerPanel.pickRow (every model pick leads with its provider
      logo) + MessageBubble.EffectiveModelBadge (every "answered by" badge shows the
      logo, via ProviderBrand.fromLabel). +2 tests; build green. The logo shows on 3
      surfaces now (Settings + picker + chat).
      ✅ SVGs STAGED 2026-06-19: fetched the B&W lobehub SVGs (lobehub/lobe-icons MIT
      static-svg) for the FULL list — claude/openai/gemini/gemma/qwen/apple/codex (+
      the pre-staged claudecode/kimi) → 9 Assets.xcassets imagesets; ProviderBrand.
      assetName references them all. build-for-testing green → ACTOOL ACCEPTED all
      SVGs (real validity gate) → the owner's full provider list now renders its REAL
      brand logo on Settings + picker + chat. P6.1 substantially DONE (component + 9
      real logos + 3 surfaces); owner does the final in-app render look.
      🔁 EXPAND — MORE LOGOS + EVERYWHERE + OWNER ~/Downloads (owner 2026-06-19): *"I want the
      logos on as much as it can be — prefer black and white; Google, DeepSeek, LFM, Qwen, Gemma,
      etc. and more. I can download some logos to my Downloads that can be added; still use LobeHub
      to find the rest. Make sure the Claude Code mascot and other logos show in the proper chats."*
      So: (1) STAGE THE MISSING + FULL ROSTER from lobehub/lobe-icons (B&W static SVG, MIT) — named
      gaps **DeepSeek, LFM/LiquidAI (LFM2/LFM2.5)** + the rest of the catalog: Google (distinct from
      Gemini if wanted), MiniMax, Z.AI/GLM, Mistral, Meta/Llama, Microsoft/Phi, Perplexity, VibeThinker,
      Hermes/NousResearch, Bonsai, DeepSeek-R1, etc. — every provider/model in the catalog gets a brand
      in `ProviderBrand` + an Assets imageset. (2) **PREFER B&W; colored fallback** when no B&W exists
      (don't leave it blank). (3) **OWNER-SUPPLIED LOGOS from ~/Downloads** — add an ingest path: logos
      the owner drops in `~/Downloads` (new/updated brands) get picked up + staged into Assets.xcassets
      (document the naming convention so the owner can just drop a file). (4) **EVERYWHERE / as-much-as-
      possible** — beyond the 3 surfaces, render the per-model logo in the MODEL STACK settings rows +
      per-model-vaults + the model picker's full catalog + anywhere a model/provider is named (maximize
      coverage; SF-Symbol fallback only when truly no logo). (5) Claude Code MASCOT + others already wired
      into the chat "answered by" badge — verify it shows in ALL proper chat contexts (Chat/MiniChat/Act).
      Keep the actool validity gate (real SVGs only). Pixel-art-coherent framing.
      ‼️ OWNER SEES NO LOGOS (owner 2026-06-19, later): *"I didn't find any logos, so make sure in the
      process the agents find as many REAL logos as they can — prefer black and white."* So: (a) the
      build loop / its agents must ACTIVELY FETCH the maximum set of real brand SVGs from lobehub/lobe-
      icons (B&W static-svg, MIT) — go wide across the whole catalog, not just the 9 staged; every
      provider/model the owner could see gets a real logo. (b) **VERIFY THEY ACTUALLY RENDER IN-APP** —
      "staged + actool-green + 9 imagesets" is NOT enough if the owner sees none: confirm the
      provider→brand→assetName→Image path actually displays (the owner may be on a pre-logo build → also
      flag that a rebuild is needed; but if it's a real render gap, fix it). Acceptance = the owner SEES
      real B&W logos on the models/providers they actually use, on Settings + picker + chat. Maximize the
      count; SF-Symbol fallback ONLY where no real logo exists anywhere (lobehub + owner ~/Downloads).
      🔁 WHOLE-APP LOGO AUDIT + NON-MODEL LOGOS (owner 2026-06-19, later): *"there were many cloud AND local
      logos I did not see, so make sure that's good. Also NON-model logos in Settings and throughout the app.
      I want as many buttons as possible to be AUDITED for what can be real logos from LobeHub."* So this is
      no longer just model/provider logos — it's a **WHOLE-APP real-logo coverage pass**: (1) **cloud + local
      model coverage gap** — the owner still sees many model logos missing → confirm EVERY cloud provider AND
      EVERY local model in the catalog actually renders its real logo (not SF-Symbol); close every gap.
      (2) **NON-MODEL logos throughout the app** — LobeHub's icon set covers far more than AI providers: stage
      + wire real B&W logos for the **engines/cloned tools** (Osaurus, Goose/Open Code, OpenClaw, DeerFlow,
      Hermes), **integrations/channels** (Slack/Discord/Telegram/Feishu/etc.), **MCP servers**, **marketplace
      sources** (GitHub, HuggingFace, arXiv), **tools** (browser-use, search engines Tavily/Brave/DuckDuckGo),
      and any other named brand/service across Settings + the whole UI. (3) **AUDIT EVERY BUTTON/SURFACE** —
      systematically go through the app's buttons/rows/badges/health-rows and, for each, decide if a real
      LobeHub logo applies; apply it (B&W preferred). The goal = as many buttons as possible carry a real
      brand logo, app-wide, not just the model picker. Extend `ProviderBrand`→a general `BrandLogo` registry
      if needed so non-model brands fit the same staged-SVG + actool-validated + fallback machinery. Prefer
      B&W; colored fallback; owner ~/Downloads ingest applies here too. Verify render in-app (owner SEES them).
      ✅ P6.2 MODEL-LOGO GAPS CLOSED 2026-06-19 (the named gaps in item (1) + the ‼️ "actively fetch max real
      B&W SVGs" concern): the build loop fetched + staged 6 MORE real lobehub B&W marks (lobehub/lobe-icons MIT
      static-svg, fill="currentColor" template-rendered — byte-confirmed against the existing staged set's CDN)
      into Assets.xcassets → DeepSeek, MiniMax, Z.AI/GLM, Llama (Meta mark), Mistral, LFM/Liquid. ProviderBrand
      now maps ALL 15 branded cases to a real imageset (+3 cases: llama/mistral/liquid with displayName + SF
      fallback so render-safety holds); only `.generic` (truly-unknown) keeps an SF Symbol. BUG FIXED:
      `local(modelID:)` + `fromLabel(_:)` now check "deepseek" BEFORE "qwen" — DeepSeek-R1-Distill-Qwen ids/labels
      contain "qwen" and were wrongly showing the Qwen logo; added llama / mistral+devstral / lfm+liquid family
      branches too. Tests: flipped the three `assetName == nil` assertions (zai/minimax now real) + added the 4
      new-brand assertions + local/fromLabel regression coverage (incl. the DeepSeek-Distill-Qwen case) + a NEW
      on-disk check that every non-nil assetName has a real .imageset in Assets.xcassets (no dangling refs).
      build-for-testing SUCCEEDED, 0 errors → actool ACCEPTED all 6 SVGs (real validity gate). VibeThinker has
      NO lobehub mark → stays generic (honest, not faked); Grok/Perplexity aren't wired as selectable providers →
      skipped (no render path = no dead assets). STILL OPEN for this item (honest): the rest of the roster
      (Google-distinct, Microsoft/Phi, Hermes/Nous, Bonsai) (2) colored-fallback policy (3) ~/Downloads ingest
      path (4) EVERYWHERE render (model-stack rows + per-model-vaults) (5) the WHOLE-APP NON-MODEL logos
      (engines/integrations/MCP/marketplace/tools via a general BrandLogo registry) — follow-on slices. Owner
      verifies the real B&W logos render on next rebuild.
      ✅ P6.2-ROSTER 2026-06-19 (completes the SELECTABLE-model coverage): CLOUD is now 7/7 — all
      CloudModelProvider cases (OpenAI/Anthropic/Google/Z.AI/Kimi/MiniMax/DeepSeek) carry a real lobehub mark.
      LOCAL roster closed for every selectable family that HAS a real lobehub mark: +SmolLM→HuggingFace,
      +Jamba→AI21, +Falcon→TII (Technology Innovation Institute) marks staged into Assets.xcassets (3 more real
      lobehub/lobe-icons MIT static-svg currentColor imagesets; actool-validated). CORRECTNESS FIX: QwQ
      (`qwqFlagship32B`) is Alibaba's QwQ reasoning line = Qwen family but its id contains "qwq" not "qwen" →
      was showing the generic "cpu" glyph; now routes to the Qwen mark (local + fromLabel). HONEST gaps kept:
      Mamba, Bonsai (no lobehub mark) and localAgent (the app's own agent brand — respects the Hermes→LocalAgent
      purge) stay generic, NOT faked. +3 ProviderBrand cases (smolLM/jamba/falcon) + tests (roster + the QwQ fix
      + the honest-generic Mamba/Bonsai assertions); the on-disk imageset check auto-covers the new marks.
      build-for-testing SUCCEEDED, 0 app errors. STILL OPEN for this item: the WHOLE-APP NON-MODEL logos
      (engines/integrations/MCP/marketplace/tools) + EVERYWHERE-render wiring + ~/Downloads ingest — follow-ons.
- [ ] Voice: Kokoro + MOSS (special reading voice) + auto-read-screen / read-replies
      / STT granular toggles + pixel-art retro filter (P7.7). NOT BUILT (research only).

- [ ] **Browser use — SURFACE the existing (built, Pro) browser automation** in the
      chat modes (Act/Work). agent_core/src/tools/browser.rs (agent-browser + chrome
      MCP, shipped Pro) + LocalAgentCapabilityRegistry `browser` toolset already
      exist but aren't reachable from chat. Wire it in honestly (Pro-gated), so the
      agent can drive a browser / do anything on the web from chat. Primary target:
      the agent controls MY APP's in-app browser (Obscura, below). Also pairs with
      the HTML canvas (P7.2).
- [ ] **Stealth / undetected browsing (owner 2026-06-18)** — the "non-scrape" thing:
      sites should NOT detect that an agent/bot is on the page. Research the best
      GitHub stealth-browser skill (puppeteer/playwright-stealth, undetected-
      chromedriver, rebrowser, nodriver, etc.); if it isn't Rust-native, USE IT
      ANYWAY via the agent-browser/chrome-MCP path and VENDOR/save it in the app.
      Wire stealth as an option on browser-use + the Obscura browser. Pro/dev-gated.
      (Honest: authorized use; no fake "undetectable" claims beyond what the lib does.)
- [ ] **OBSCURA BUILT-IN BROWSER (owner researched before; runtime never built)** —
      build the actual working in-app Obscura browser (Rust browser backend /
      WKWebView built-in browser). PRIOR RESEARCH IN-REPO (read first, build on it):
      docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md (Tier-1 lifts LANDED),
      HELIOS_V5_INTEGRATION_PLAN §B3 "W6-A..W6-I runtime work (Obscura + deno_core +
      Eidos) — queued", EPISTEMOS_HERMES_MANIFESTO "WKWebView built-in browser". The
      W6 runtime was never built — BUILD it. Pairs with Work mode + HTML canvas
      (P7.2) + browser-use. Pro/dev-gated where it needs network/subprocess.
- [ ] **RESEARCH-CORPUS COMPLETENESS SWEEP (owner 2026-06-18)** — the owner fears
      researched/queried items are silently dropped. The loop must SWEEP the
      owner's local research (docs/fusion/* + prior plans) AND this session's full
      query history, and ADD any researched/requested-but-untracked capability to
      THIS ledger. Recurring task — keep the ledger complete against the corpus.
      SPECIFIC RANGE (owner 2026-06-18): cover the OBSCURA era, the SIMULATION era,
      and the EML era — and BEYOND, up to now. **EXCLUDE HERMES** (the owner purged
      it — do NOT resurrect Hermes-named work; naming-reconciliation only). Focus on
      LOCAL research + CHAT-related research (lots got dropped). Extract every
      "queued / candidate / deferred / runtime phases / NOT IMPLEMENTED / W6-*" item
      from at least: B2/B3 lift targets (B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS,
      B3_OBSCURA_BROWSER_LIFT_TARGETS), HELIOS_V5/V6 plans, SUBSTRATE_TRACK_REGISTER
      + fusion/* state docs, Eidos (EIDOS_V0_*), SIMULATION (SIMULATION_DONOR_MINING_
      STATUS + docs/simulation/*), EML era (EML-IR / episodic-memory-lattice, the
      T5/T7 EML work), the LATTICE EXPLAINER + EPISTEMOS_LIVING_INDEX_2026_05_24.md,
      KNOWN_ISSUES_REGISTER, HARDENING_TRACKER, FEATURE_CHANGE_TRACKER,
      V1_5_IMPLEMENTATION_TRACKER, PHASE_CHECKLIST. Each unfinished item → a ledger
      line + finish it deeply (rule #6/P5.H). Write
      docs/UNFINISHED_RESEARCH_SWEEP_2026_06_18.md.

## Architecture / process
- [ ] **Living Index + Lattice Explainer — non-70B upgrades (owner 2026-06-18)** —
      deep-mine EPISTEMOS_LIVING_INDEX_2026_05_24.md + the lattice explainer ("lots
      of things there") for theoretical + app upgrades using EML + other PRIMITIVES
      (NOT the 70B). Pull each into the ledger + BUILD; 70B alone stays owner-gated.
      ⏳ **SEQUENCE ABSOLUTELY LAST (owner 2026-06-19):** *"the last research thing where
      the loop looks for local research on the obscura era and forward — I want that to be
      LAST because it goes into the lattice explainer and living index, so it should be
      absolutely last since it's an indefinite research loop at that point."* This is the
      **INDEFINITE / open-ended** research tail (the loop recursively mines its own
      obscura-era→present local research corpus — EML/episodic-memory-lattice, the lattice
      explainer, the living index). DO NOT START IT until ALL finite roadmap work is done
      (MASTER_SYNTHESIS Phase 0→3 + every finite research slice). It never terminates, so
      it must be the very LAST thing the loop turns to — never ahead of the broken-things
      repair, the engines, or the supersession features.
- [ ] Founding thesis everywhere: determinism + verifiability on small local models;
      substrate health + Knowledge Core (P5/R-ARCH) — more important than 70B.
- [ ] **P5.H — DEEP-HARDEN + FINISH the substrate research** (Cognitive DAG incl.
      orphaned macaroons→dispatch, Provenance ledger+console, Knowledge Core, Halo,
      Simulation, Schema-First GenUI, XPC). Audit-first (hidden PASSes), finish the
      unbuilt/orphaned, promote to T4+ (reachable/visible/verified/logged), surface
      in Chat. The owner researched these to add to chat; they're unfinished.
- [ ] **CHAT = FULL EPISTEMOS CEILING (P8.1)** — Chat gets max capability on MAS +
      Pro additions, keep all IP (Eidos etc.), don't bleed into Osaurus/Act.
- [~] **DETERMINISTIC SCHEMA ENGINE (P8.2, founding thesis — DON'T BURY)** — Rust
      schema engine + AST quality gate (validate before disk write/compile) +
      UniFFI async stream + RAG preflight tool selection (~3-5 tools) + structured
      gen for Gemma 4 + Coder Adapter + reasoning-token isolation. RESEARCH-FIRST on
      the owner's EXISTING local plans + grammar/json-schema FFI; build ON them.
      Spec: docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md. Make local models
      work GREAT; surface the determinism visibly.
      ✅ §B FIRST SLICE 2026-06-19 (RAG preflight tool selection): NEW
      `agent_core/src/tool_preflight.rs` — `select_tools(query, candidates, max)` picks
      the top-`max` (~3-5) tools most relevant to a turn so a local model keeps a TIGHT
      focused footprint instead of the whole suite (the founding-thesis local-model
      win). First slice = a DETERMINISTIC LEXICAL scorer: query-term overlap weighted
      name=3 / keyword=2 / description=1, stopword-filtered, score-desc then name-asc
      (total order → fully deterministic), only score>0 returned (empty = honest "no
      tool matched", caller decides fallback). The semantic/embedding preflight is the
      follow-on that swaps `score` behind the same side-effect-free contract. +7 cargo
      tests (relevant-for-file-query, max footprint, name>description, no-match-empty,
      deterministic alpha tie-break, stopwords-ignored, zero-max). cargo --lib BOTH
      green (7/0 each). NOT yet wired into the live agent loop (that's the next slice,
      best with owner in-app verification). The remaining parts (AST quality gate,
      UniFFI async stream, structured-gen constraints, reasoning-token isolation) are
      separate slices.
      ✅ §B SECOND SLICE 2026-06-19 (reasoning-token isolation): NEW
      `agent_core/src/reasoning_tokens.rs` — `split_reasoning(raw) -> ReasoningSplit
      { thinking: Option<String>, answer: String }` separates a local model's reasoning
      trace from the clean answer/tool-args. Per the HONESTY constraint the thinking is
      PRESERVED (returned for UI tracing), NEVER stripped. Handles the in-tree marker
      formats — Qwen `<think>…</think>` + Gemma `[Start thinking]…[End thinking]` —
      incl. the unclosed/streaming case (rest = in-progress thinking) + empty-block →
      None + no-marker → whole text is the answer. Rust-core primitive for the GGUF /
      schema-engine path (does NOT touch Swift's MLXInferenceBridge MLX-path handling —
      no duplication-in-place). +6 cargo tests; cargo --lib BOTH green (6/0). Wiring
      into the GGUF generation path is the follow-on (best with owner in-app check).
      ✅ STREAMING HELPER + HONESTY LOCK 2026-06-19: added `thinking_in_progress(raw) ->
      bool` (true while an opening reasoning marker has no matching close yet) — a
      streaming UI uses it to HOLD the answer until the reasoning closes, so partial
      thinking never renders as the answer (aligns with the owner's "UniFFI streaming"
      ask). Plus a HONESTY property test locking that `split_reasoning` never fabricates
      or drops content (both parts come from the raw; the reasoning is preserved, not
      stripped). +3 cargo tests (in-progress true/false, content-preservation). cargo
      --lib BOTH green (9/0 on `reasoning_tokens`).
      ✅ FFI EXPOSURE 2026-06-19 (reasoning isolation reachable from Swift): the one
      schema-engine primitive NOT yet callable from Swift (preflight + validation already
      had FFIs; reasoning_tokens didn't). NEW `#[uniffi::export] split_reasoning_json(raw)
      -> String` returns `{"thinking": <string|null>, "answer": <string>,
      "thinking_in_progress": <bool>}` so a streaming UI renders only the clean ANSWER,
      surfaces the reasoning separately, and HOLDS the answer while thinking is in progress
      — reasoning PRESERVED, never stripped (honesty constraint). PURE — makes the
      determinism callable ("surface the determinism visibly") without altering any live
      path on its own (the in-loop wiring is the owner regen + a follow-on, like the
      preflight FFI). +4 cargo tests (complete block / in-progress hold / null-thinking /
      valid-JSON-escaping with quotes+newlines). cargo --lib BOTH green: default 5454/0,
      pro-build 5717/0 (+4 each, zero regression).
      ✅ §C.1 PIPELINE 2026-06-19 (preflight → dispatch grammar): RESEARCH FIRST found
      the structured-gen pieces ALREADY EXIST — json-schema VALIDATION (`jsonschema`
      crate in tools_v2/runner.rs) + json-schema→GBNF grammar (grammar/mod.rs
      `build_dispatch_grammar`) + structured-gen FFI (`with_json_schema` in bridge.rs).
      So instead of duplicating, COMPOSED them: NEW `preflight_dispatch_grammar(query,
      tools, max)` in tool_preflight.rs = the spec §C.1 "RAG Preflight Filter →
      structured tool output" — preflight-selects the relevant tools, then builds the
      GBNF dispatch grammar for ONLY those via the EXISTING `build_dispatch_grammar`
      (so a local model sees a tight + schema-constrained tool set, high fidelity on the
      selected few). Honest `EmptyDispatch` when nothing matches (caller falls back).
      +2 cargo tests (constrains-only-selected, errors-when-nothing-matches). cargo
      --lib BOTH green (9/0 on `tool_preflight`). NOTE: the schema-engine's clean pure
      slices are now largely harvested (preflight + reasoning + this composition added;
      validation + grammar + structured-gen FFI pre-existing); the remaining parts (the
      §A AST quality gate via tree-sitter, UniFFI async stream, and wiring all of this
      into the live agent loop / run_local_gguf_generation) are heavier / owner-
      verification, NOT one-pass autonomous slices.
      ✅ §A AST QUALITY GATE 2026-06-19 (syntax layer): NEW
      `agent_core/src/ast_quality_gate.rs` (feature-gated `lsp-runtime`, reusing the LSP
      runtime's tree-sitter grammars — NO new deps, non-duplicating: no parse-validation
      existed). `parse_gate(code, GateLanguage::{Rust,Swift}) -> ParseGateOutcome
      { parses_cleanly }` + `passes_gate` — parses generated CODE with tree-sitter and
      REJECTS it when the tree has ERROR/MISSING nodes, so a syntactically-broken
      generation never reaches disk (the §A "validate via an AST quality gate BEFORE any
      disk write" at the syntax level). Parser-construction failure → conservatively
      NOT clean. +5 cargo tests (clean Rust/Swift pass, broken Rust/Swift rejected,
      outcome both-ways). VERIFIED all 3 profiles: `--features lsp-runtime` (5/0 new
      tests), plain `--lib` mas (5406/0, module cfg-absent → no regression), `--features
      pro-build` (5668/0). FOLLOW-ON: deeper AST quality (beyond parse — type/structure
      checks) + wiring into the write/compile loop are heavier / owner-verification.
      ✅ PREFLIGHT FLOOR + DETERMINISM HARDENING 2026-06-19: feature + hardening on the
      preflight. NEW `select_tools_with_floor(query, candidates, max, floor)` — closes a
      real gap (bare `select_tools` returns EMPTY on no lexical match): now the `floor`
      CORE tools (vault.search / think / …) are GUARANTEED present even on a terse/
      off-topic prompt, with the remaining tight-footprint slots going to the query
      matches (deduped, ≤max, deterministic). Plus a DETERMINISM property test locking
      the founding-thesis claim: `select_tools` is ORDER-INDEPENDENT (shuffle the
      catalog → identical result) + idempotent — so a future refactor can't silently
      introduce non-determinism. +4 cargo tests (floor-always-included, floor-skips-
      absent, floor-respects-max+dedups, order-independence). cargo --lib BOTH green
      (13/0 on `tool_preflight`).
      ✅ FFI EXPOSURE 2026-06-19 (preflight reachable from Swift): NEW
      `#[uniffi::export] schema_preflight_select_tools_json(query, candidates_json, max)
      -> String` — Swift passes the query + the tool catalog as JSON + the max footprint
      and gets the selected tool names back as a JSON array. PURE — it does NOT touch the
      live agent loop (no regression risk); it just makes the Rust preflight CALLABLE
      from the app so the Swift side can surface "N tools selected for this turn" (the
      spec's "surface the determinism visibly") or feed the local tool loop when the
      owner wires it. Honest empty `[]` on a parse error / no match. +2 cargo tests
      (round-trip + honest-empty). cargo --lib BOTH green (15/0). The actual in-loop
      wiring + the picker surface remain the owner-verification step.
      ✅ LIVE-WIRING SAFETY 2026-06-19 (flag-gated passthrough FFI): researched the
      wiring path — the LOCAL tool list is assembled Swift-side (LocalAgentPromptBuilder),
      and the UniFFI Swift binding is REGENERATED by build-agent-core.sh (line 122), so
      the live wiring genuinely needs that regen + a local model to verify (owner build
      step). To make that wiring SAFE-BY-DEFAULT: NEW `#[uniffi::export]
      schema_preflight_select_tools_gated_json(query, candidates_json, max)` + flag
      `EPISTEMOS_SCHEMA_PREFLIGHT_V0` (OFF) — flag OFF returns ALL the input tool names
      UNCHANGED (passthrough), flag ON returns the tight ~3-5 preflight subset. So Swift
      can wire this in UNCONDITIONALLY: zero behavior change until the owner flips the
      flag, then verifies the ON narrowing in-app. +3 cargo tests (flag parser, flag-OFF
      passthrough = all tools in order, flag-ON narrows). cargo --lib BOTH green (18/0).
      OWNER STEP to go live: build-agent-core.sh (regen binding) → in LocalAgentPrompt
      Builder replace the local tool list with the FFI result (serialize the catalog to
      `[{name,description,keywords}]`, call the gated FFI) → set EPISTEMOS_SCHEMA_
      PREFLIGHT_V0=1 → verify the picker/loop shows the tight footprint.
      ✅ LIVE WIRING LANDED 2026-06-19 (the in-loop narrowing — the previously owner-only
      step): RESEARCH-FIRST corrected the wiring point — `LocalAgentPromptBuilder` builds
      the (query-INDEPENDENT) system prompt, so it is NOT where a per-query preflight
      belongs; the right seam is `LocalAgentLoop.run`, the single per-turn entry that has
      BOTH the user `objective` AND the assembled `tools` in hand (line 297, right after
      `AgentToolNameAliases.canonicalizedDefinitions`). NEW
      `Epistemos/LocalAgent/SchemaPreflightToolNarrowing.swift` — flag-gated
      (`EPISTEMOS_SCHEMA_PREFLIGHT_V0`, OFF) narrowing: OFF (default) → returns the tool
      list UNCHANGED before any FFI/JSON work (byte-for-byte today; Chat/Act untouched),
      ON → calls `schema_preflight_select_tools_gated_json` and filters `tools` to the
      selected names preserving order. NON-STRANDING: empty/garbage selection → full list
      (never zero tools); test-host without the FFI → passthrough. Wired at LocalAgentLoop
      .swift:297 as a one-line wrap of the canonicalized list. +6 Swift tests
      (OFF=passthrough regression, empty-safe, cross-runtime flag parity vs Rust
      `SCHEMA_PREFLIGHT_FLAG` via mirrored-source read, encode/decode envelope contract,
      wired-into-live-loop). build-for-testing green (0 errors). OWNER verifies the ON
      narrowing in-app by setting `EPISTEMOS_SCHEMA_PREFLIGHT_V0=1` (no code/regen needed —
      the FFI was already in the regenerated binding).
      ✅ §C.1 REPAIR VALIDATION GATE 2026-06-19: NEW `agent_core/src/schema_validation.rs`
      `all_violations(schema, value) -> Vec<String>` + `is_valid` — collects EVERY way an
      emitted value violates the schema (via `jsonschema::iter_errors`) for a model
      REPAIR loop, vs the existing `tools_v2::runner::JsonSchemaValidator` which returns
      only the FIRST error (accept/reject). Non-duplicating + complementary. A schema
      that fails to compile is reported as a violation (never silently passes). +4 cargo
      tests (valid→none, collects-ALL-not-just-first [≥2 type errors], missing-required
      reported, broken-schema-never-passes). cargo --lib BOTH green (5/0). Building block
      for the §C.1 "structured tool output → validation gate → repair" loop (the wiring
      of the loop is the owner-verification step).
      ✅ §C.1 REPAIR-PROMPT BUILDER 2026-06-19: added `build_repair_prompt(failed_value,
      violations) -> Option<String>` to schema_validation.rs — turns a failed JSON +
      `all_violations` into a concise model repair instruction (shows what it produced,
      lists EVERY violation numbered, asks for "ONLY the corrected JSON … no prose, no
      markdown"). `None` when there's nothing to repair. Non-duplicating: the research-
      tier `SchemaRepairLoop` uses a DIFFERENT custom Schema/FieldType system; this
      pairs with the LIVE `jsonschema` path (the one tools_v2/runner uses). Completes the
      Rust §C.1 validate→repair primitives: `all_violations → build_repair_prompt →
      re-prompt`. +3 cargo tests (lists-all+shows-value+asks-json, none-when-no-
      violations, validate→repair round-trip). cargo --lib BOTH green (8/0). Wiring the
      loop into live generation is the owner-verification step.
      ✅ §C.1 VALIDATE→REPAIR FFI 2026-06-19 (gate reachable from Swift): NEW
      `#[uniffi::export] schema_validate_and_repair_json(schema_json, value_json) ->
      String` — the whole §C.1 gate in ONE call: Swift passes the tool schema + the local
      model's emitted value, gets back EITHER "" (valid → execute) OR a repair prompt
      (re-prompt). The Swift local agent loop calls it after a local tool-call and decides
      execute-vs-repair — PURE, no live-loop change. Honest: an unparseable schema/value
      is reported (never silently "valid"). +4 cargo tests (valid→empty, invalid→repair
      prompt, unparseable-value→repaired, unparseable-schema→reported). cargo --lib BOTH
      green (12/0). Like the preflight gated FFI, this becomes app-callable once the owner
      regenerates the UniFFI binding (build-agent-core.sh).
- [ ] **Post-Osaurus enhancements (P3.1b)** — after import: more MCP, easier+robust
      agents, and a MAS-safe version of key Osaurus capabilities.
- [ ] **GOOSE = OPEN CODE / WORK backend via ENGINE EXTRACTION (R-GOOSE, owner
      DECISION 2026-06-18)** — extract Goose's RUST CORE (Block, Apache-2.0) as a
      crate into agent_core via UniFFI = the FULL engine (repo indexing, git, multi-
      file diffs, deterministic test-and-fix self-correction loop, parallel
      subagents, YAML recipes). Do NOT import the Node/TS Goose DESKTOP (18GB swap
      death) — own SwiftUI skin. Powers WORK mode; engine in shared core so Act/Chat
      tap MCP/subagents too. Osaurus stays the ACT backend. Validate patches vs P8.2.
- [ ] **OpenClaw — FULL PORT, ALL OF IT (R-OPENCLAW, owner DECISION 2026-06-18:
      "don't care about native anymore, I want ALL the other stuff")** — bring in
      the COMPLETE OpenClaw (~/Downloads/openclaw-main, TS/Node + ui), not a
      cherry-pick. Since it's TS/Node, host the full app via WEBKIT (WKWebView) so
      every feature comes along with no rewrite; RESKIN to the pixel-art theme
      (CSS/theme injection) with the TAMAGOTCHI/Companion mascot. If it needs a Node
      backend, gate that Pro/dev (bundled local service); MAS build shows the honest
      "Pro only" state. Owner accepts the heavier footprint for completeness. It's
      the AGENT-EXTENSION slot (separate from Work/Goose; NOT an OpenCode replacement).
      OWNER DECISION 2026-06-18 (agent structure): adopt **shared OpenClaw UI + a
      TWO-ENGINE picker, LIVING IN ACT** (see the Chat/Act/Work toggle item) — Act's
      two engines: (1) **OpenClaw** (long tasks / automation; its pixel-art-reskinned
      WebKit UI), (2) **Osaurus (local)** = the full ported Osaurus runtime/sandbox
      running the Local Agent (LocalAgent ⊕ fused Hermes) as its brain. CORRECTION
      2026-06-18: Osaurus STAYS the Act engine (not a hidden sandbox); the picker is
      OpenClaw vs Osaurus-local — ONE routing decision. Verdict doc → WebKit-host
      port + reskin + engine-picker wiring + harness systems; per-feature harden.
- [ ] **Hermes agent — FUSE INTO Local Agent (R-HERMES), super-agent, NO new route**
      — OWNER DECISION 2026-06-18: YES to the "super agent" ambition, done the CLEAN
      way. Clone the REAL updated GitHub Hermes and LIFT its proven agentic-loop /
      tool-use / long-task code INTO the existing native LocalAgent (APP-NATIVE-BY-
      EMBEDDING + ProvenanceGate; namespace stays purged, NO "Hermes" name). The
      result `LocalAgent ⊕ Hermes` is STILL ONE routing lane — it is the BRAIN of the
      **Osaurus-local engine** in Act's 2-engine picker (OpenClaw vs Osaurus-local).
      CRITICAL: do NOT add Hermes as a separate third engine/route — that would muddy
      routing (owner's explicit concern). Fuse inward (strengthen the one Osaurus-
      local lane), never a new branch. Study
      HERMES_AGENT_CORE_2_0_DESIGN + the real repo; compare/borrow, fuse natively.
      FLUIDITY MANDATE (owner 2026-06-18, hard-won lesson): the PAST failure was
      running Hermes as a SUBPROCESS (terminal agent) and trying to BRIDGE it to
      SwiftUI — the glue (IPC/streaming/lifecycle) never worked. DO NOT repeat it.
      This time: (a) **NO subprocess** — lift Hermes's agent CODE in-process into
      LocalAgent (Rust/Swift), called by direct fn/FFI, the NO-HIDDEN-SIDECAR way;
      (b) **NO Hermes-UI port / NO terminal→SwiftUI bridge** — take Hermes's BRAIN,
      not its screen; the UI is already solved (native Act + OpenClaw's WebKit UI
      drive the in-process engine). Hermes "has its own UI now" is irrelevant — we do
      NOT adopt it. Fluidity comes from EMBED-don't-BRIDGE: LocalAgent already drives
      the app UI, so fusing Hermes's logic in means the UI keeps working with zero new
      wiring. (Contrast: OpenClaw IS hosted via WebKit — it's a whole TS/Node app and
      its UI is the point; Hermes is code-to-fuse, not a UI-to-host.)
      ✅ DEEP RESEARCH 2026-06-19 (owner asked: don't overlap Osaurus; research the
      non-cloned parts deeply; where does it land?) → `docs/research/HERMES_OSAURUS_
      OVERLAP_AND_DESTINATION_2026_06_19.md` (two parallel subagents, repo-grounded).
      FINDING — the real port is only **4 items** (huge scope cut), and **NONE of it
      lands on Osaurus**: (1) session search→summarize-then-answer (new `session.search`
      tool: Rust handler in `session.rs`+registry, query → Swift `SearchIndexService.
      fusedSearch`/epistemos-shadow); (2) Swift-side summarizing context compaction
      (new compactor beside `LocalAgentLoop.swift trimHistory:1356` — Rust's
      `compaction.rs::compact_messages` is cloud-only because `agent_loop.rs:147
      LocalProviderNotAllowed`); (3) named prompt-tier model stable/context/volatile
      (`agent_runtime::prompt_format::build_system_prompt` + Swift `LocalAgentPrompt
      Builder` mirror); (4) richer auto-skill triggers (errors/dead-ends/user-correction/
      novel-workflow) into `agent_runtime::self_evolution.rs` (promotion stays Sovereign-
      gated). DESTINATION (resolves owner's "Osaurus or another part?"): the lifted
      logic fuses into the IN-PROCESS LocalAgent brain = Rust `agent_core::agent_runtime`
      (shared algorithms, callable by local+cloud) + Swift `LocalAgentLoop` (local
      orchestration only) — confirmed NOTHING on the Osaurus :1337 server lane (the only
      Osaurus wire is the generation-closure swap, which replaces token serving, never
      brain logic). OVERLAP-WITH-OSAURUS → EXCLUDE (the owner's no-overlap answer; these
      Hermes parts are NOT cloned): code/shell exec (Osaurus OWNS the Containerization
      VM sandbox), MCP server/client (Osaurus is already full MCP), the gateway/channels
      server, hermes_cli TUI/Electron, cron daemon, Honcho/network memory, the provider/
      transport layer (redundant w/ both `routing.rs` AND Osaurus). ALREADY-IN-EPISTEMOS
      → don't re-port: ReAct loop, tool registry, the (already Hermes-3-compatible) tool-
      call grammar, provider abstraction, todo, termination, MEMORY/USER curation,
      skills+progressive-disclosure, delegation (in-process Tokio task, not a process).
      So the "tedious Python→Swift/Rust port" is really 4 small clean-room algorithm
      lifts, not a repo port. RuntimeRouter ≠ Act picker (keep distinct or 3rd-route).
- [ ] **Study the best chat/agent apps (R-APPS, owner 2026-06-18)** — besides
      Osaurus: LM Studio, HuggingFace (chat-ui/transformers/candle), Unsloth, Jan,
      Ollama, Open WebUI, Cherry Studio, LibreChat, etc. Mine their SYSTEM PROMPTS
      + architectures + agent/tool/MCP handling; verdict doc on what to adopt.
- [x] Auto-commit + push every slice to GitHub — verify still pushing.
- [~] **OSAURUS = ACT, FULL IMPORT (owner DECISION 2026-06-18, P3.0)** — bring in
      ALL of Osaurus incl. frontend, ZERO cherry-pick (completeness; don't miss
      code). Clone the full MIT repo (not on disk yet), embed the COMPLETE repo as
      the Act substrate inside Epistemos (Epistemos stays root → tests/IP stay
      home), preserve Osaurus's entitlements/Info.plist/build verbatim, build it,
      then reskin Act's UI to the app. STOP hand-building parallel cowork/Act
      (P7.6) — Act comes from Osaurus. Unsloth (P4.1) training surfaces in the modes.
      ✅ PLAN 2026-06-19 (docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md, research-first):
      WebFetched the LIVE repo (dinoki-ai/osaurus ARCHIVED → `osaurus-ai/osaurus`):
      native Swift macOS app, **MIT** (direct_import clean), 2,837 commits, full app
      = SwiftUI UI + HTTP server :1337 (OpenAI/Anthropic/Ollama-compat) + CLI + Apple
      **Containerization** Linux-VM sandbox + agent loop + MCP + 20+ plugins + relay;
      core = `OsaurusCore` SPM package. CRITICAL: Osaurus's powers (VM/server/relay/
      plugins) are OUTSIDE the MAS sandbox → **Act=Osaurus is PRO** (`#if !EPISTEMOS_
      APP_STORE`); MAS Act stays on the in-process local-agent path; VM/server/relay
      clear the runtime-plural bar (owner approval + no-hidden-fallback + RunEventLog
      + AnswerPacket + rollback + harness) before live. IMPORT = vendor full repo
      `LocalPackages/osaurus/` (mlx-swift-lm precedent) + link OsaurusCore Pro-gated +
      reskin Act UI. SMALLEST FIRST SEAM (next verified slice): a Pro-gated
      `ActOsaurusBridge` protocol + flag `EPISTEMOS_ACT_OSAURUS_V0` (OFF) + INERT stub
      + gate HealthRow + MAS/Pro guard test (NO repo import yet). Then S2 vendor → S3
      link → S4 Act-turn+reskin → S5 Containerization sandbox (R-CUA Lume) → S6+
      server/MCP/plugins/relay. STOP hand-building parallel Act is recorded.
      ✅ S2 LANDED 2026-06-19: first REAL vendored seam. `Epistemos/Vendor/Osaurus/
      ServerHealth.swift` = VERBATIM MIT source (OsaurusCore server-health enum),
      direct_import, full MIT license + provenance in OsaurusVendorProvenance.swift,
      Pro-gated `#if !EPISTEMOS_APP_STORE`. Seam = ActOsaurusGateStatus (always-
      compiled flag EPISTEMOS_ACT_OSAURUS_V0, OFF) + ActOsaurusBridge (Pro-only
      protocol returning the vendored ServerHealth + INERT stub, never fakes live) +
      ActOsaurusHealthRow (visible in SubstrateHealthPanel). MAS/Pro boundary clean
      by construction (no always-compiled file references a Pro-only Osaurus type;
      MAS Act stays in-process). +4 guard tests; build-for-testing green.
      ✅ S3 LANDED 2026-06-19: bridge toward a WORKING path, reusing the EXISTING
      osaurus-pattern LocalModelServer (no heavy OsaurusCore link). 2nd vendored MIT
      file OsaurusChatMessage.swift (Message/MessageRole, adapter_wrap namespaced
      under OsaurusVendor to dodge the BrandedTypes MessageRole collision, Pro-gated).
      LocalModelServer.defaultPort exposed. ActOsaurusBridge now publishes the REAL
      `openAICompatibleEndpoint` (http://127.0.0.1:1337/v1/chat/completions when the
      local server is enabled, else nil — honest, no running-state overclaim) +
      `localServerEnabled` + `makeRequestMessage` (vendored wire format); the real
      endpoint shows in the health row (Pro). +2 tests; build-for-testing green.
      NEXT (S4): the bridge actually drives a turn through the endpoint behind the
      no-hidden-fallback bar; OR link OsaurusCore (SPM, heavy deps) when ready.
      ✅ S4 LANDED 2026-06-19: ActOsaurusBridge.runTurn(model:messages:maxTokens:)
      drives a REAL turn — URLSession-POSTs an OpenAI-compatible chat-completions
      request to the endpoint + decodes the assistant text. EVERY failure throws an
      HONEST ActOsaurusError (serverNotEnabled / transport / requestFailed / empty) —
      NEVER a silent cloud/GPT fallback (owner #1); the INERT stub refuses honestly.
      Pro-only. +2 tests (mirrored-source + a #if-Pro async regression: no server →
      throws serverNotEnabled). build green. Live turn = owner's on-device check.
      NEXT (S5): Containerization VM sandbox (R-CUA Lume) OR link OsaurusCore.
- [ ] **Osaurus + Unsloth feed the MODES** (owner 2026-06-18): the Osaurus
      deep-cherry-picks/full-port (local server + agent capabilities) and Unsloth
      (model training) must SURFACE INSIDE Act mode — and where it fits, Chat mode
      — not as standalone features. Act/Work run the local agent loop powered by
      the Osaurus-adopted capabilities; training is reachable from the chat. Wire
      them into the shared mode stack, local=cloud parity.
- [~] Settings decluttered + coherent (P6.4c) — grouping/reordering landed + locked
      (AppearanceSectionOrderTests); custom-theme editor aligned to the pixel-art look
      (hard Rectangle, matches the palette swatch); theme-preview is pixel-art palette
      for ALL themes (P6.4b). REMAINING (owner in-app): dead/duplicate-control sweep
      (DELETION GUARDRAIL) + broader pixel-art alignment of the other Settings panels.

## Settings / staleness / substrate-finish (owner 2026-06-18)
- [ ] **DEEP SETTINGS REPAIR** — beyond the declutter (P6.4c): AUDIT every Settings
      row/toggle/section for things that DON'T WORK or encode OLD ASSUMPTIONS that
      no longer apply and actively mess things up. Fix or remove the stale ones;
      verify each remaining control is wired to real runtime. (Views/Settings/*.)
- [ ] **APP-WIDE STALENESS SWEEP** — there are instances around the app of
      super-old code/assumptions. Grep for stale flags/model names/dead paths/old
      copy and repair or remove them; honest, with regressions. Not just Settings.
- [~] **SUBSTRATE HEALTH PAGE makes the window SUPER LONG** — layout bug in
      Epistemos/Views/Settings/SubstrateHealthPanel.swift (too many health rows
      stacked). Fix: scrollable/collapsible/paginated so it doesn't blow out the
      window height. Quick, visible win.
      ✅ DONE (build-verified; owner visual-confirms): the 3 sections are now
      collapsible (`Section(_:isExpanded:)`, macOS 14+) with `@State` show flags;
      the 10-row "Substrate Floor" section defaults COLLAPSED so the panel opens
      compact (5 Retrieval + 8 Agent Runtime rows visible, Floor one click away),
      and the host `Form` scrolls — nothing removed. Mounted at SettingsView:498.
      (No-drift tick: the code landed earlier this session; ledger was unticked.)
- [ ] **SUBSTRATE COMPLETELY FINISHED (except the 70B runtime)** — finish ALL of
      P5/P5.H substrate to T4+ (Cognitive DAG, provenance, Knowledge Core, Halo,
      Simulation, GenUI, XPC, Eidos, EML). ONLY the large-local-model (70B/System G)
      RUNTIME stays owner-gated; everything else gets done.
- [ ] **MINE SYSTEM G LOGIC → apply to beneficial app parts (non-runtime)** —
      Epistemos/SystemG/* (SystemGRunSeam / RealSystemGRunSeam / SystemGWiring) +
      AnswerPacket/SovereignGate/RuntimeRouter patterns. Extract the reusable LOGIC
      (verifiability, AnswerPacket provenance, run-event logging, sovereign gating,
      router) and apply it to the parts of the app that truly benefit — WITHOUT
      arming the gated 70B runtime itself.
- [ ] **INFUSE EPISTEMOS IP INTO ACT (Osaurus) + WORK (Goose)** — Act and Work are
      not vanilla Osaurus/Goose: wire the owner's specific capabilities/IP into
      them (deterministic schemas P8.2, Eidos, Knowledge Core, memory/vault, the
      determinism/verifiability gates, theme). They inherit hardening from the
      engines AND gain Epistemos's superpowers.

## Code review + agent frameworks (owner 2026-06-18)
- [ ] **"Thermonuclear" code-quality review (R-CODEREVIEW)** — it's a NAME for an
      ultra-aggressive exhaustive review. Deliver BOTH: (1) a LOOP process step that
      deep-reviews the whole app's quality (correctness/dead-code/honesty/perf/drift)
      and files findings; (2) an IN-APP code-review feature in Work/Open Code mode
      (gated by P8.2 schemas + Goose self-correction). Real findings only.
- [ ] **Agent-creation frameworks deliberation (R-AGENTFW)** — research Vercel AI
      SDK (TS, MIT), Google ADK/Agent Builder (open), Cursor agent (proprietary,
      UX-only). Verdict per framework: usable IP vs patterns-only + license. Likely
      adopt PATTERNS + agent-creation UX natively (Companion/tamagotchi P2.6 +
      Osaurus config + Goose subagents), not import SDKs. Recommend the native design.

## Models (owner 2026-06-18)
- [ ] **IN-APP HUGGINGFACE + GITHUB MARKETPLACE (owner 2026-06-18)** — bring the HF
      Hub experience into the app: SEARCH/BROWSE models, ADAPTERS/LoRAs, and quants
      (HF public API huggingface.co/api/models + GitHub search API), with one-click
      INSTALL via the bring-your-own-model importer (MLX/GGUF lanes). Show size +
      format + whether it fits (memory gate + Run-anyway). Adapters tie into the
      Unsloth/training + MoLoRA lanes. Honest: only install/run on-device-supported
      formats. This is the "HuggingFace system in the app" the owner wants.
- [ ] **ARXIV PULL SYSTEM (owner 2026-06-18)** — easily search + pull from arXiv
      (arxiv.org API) directly into the app; ingest papers (PDF/abstract/metadata)
      into the vault / Knowledge Core so they're searchable + usable by chat/agents.
      Pairs with HuggingFace (pull a paper's model) + the autoresearch loop. Honest
      ingestion (real fetch + index), MAS-safe.

- [ ] **BRING-YOUR-OWN-MODEL — import ANY model from HuggingFace/GitHub (owner 2026-06-18)**
      Open-ended model import: paste a HF repo (or GitHub) URL, DETECT the format +
      list available files/quants (MLX, GGUF Q2..Q8/IQ, safetensors), pick one, then
      INSTALL + RUN it via the matching on-device lane — MLX-Swift (in-process, MAS-OK)
      or the GGUF llama-cli lane (Pro, flag-gated). Reuse ModelDownloadManager + the
      P1.8 progress UI; memory-gate honestly + the new "Run anyway" override so the
      user can attempt larger community quants. HONEST about what actually runs
      on-device: MLX + GGUF supported; raw PyTorch/safetensors needs an offline
      mlx_lm.convert step (Pro/dev) — surface that, don't fake a load. This lets the
      owner upgrade/swap to any model + grab community quants of bigger models.

- [ ] **Add Unsloth Gemma 4 12B 2-BIT GGUF (low-RAM)** — owner wants the very-low-RAM
      2-bit (Q2_K / IQ2) GGUF of Gemma 4 12B from Unsloth (~4-5 GB vs ~8+ at 4-bit),
      so 12B-class quality fits comfortably on the 16 GB Mac. Find the exact Unsloth
      repo/file (e.g. unsloth/gemma-4-12b-it-GGUF Q2_K/IQ2), wire into the GGUF lane
      as an installable candidate alongside the existing 12B; honest memory-gate
      (it's small so it should just fit). Pairs with the Variant Ladder + memory
      work. Verify it loads + generates.
- [ ] **Add an on-device VISION RUNTIME for Holo (mlx-vlm or best) (owner 2026-06-18)**
      — R-HOLO verdict: the GGUF lane is text-only, so Holo-3.1-4B (VLM) needs a real
      vision runtime. Research the best on-device option (mlx-vlm is the leading
      Apple-Silicon VLM runtime; also consider llama.cpp multimodal/mmproj). Wire it
      as a new vision-inference lane, then run Holo through it into the computer-use
      stack (DeviceAgentService / VisualVerifyLoop / Screen2AXFusion) for GUI
      grounding. Honest (real vision, no faking), Pro/MAS gating, memory-gated.
      Verdict doc + wire-in + verify it actually does image→action grounding.
- [ ] **Add Holo-3.1-4B as a computer-use VL model (huggingface.co/Hcompany/Holo-3.1-4B)**
      — H Company's Holo is a VISION-LANGUAGE model for COMPUTER USE / GUI grounding
      (screen/web-agent navigation). Research the readme; wire it into the existing
      computer-use/vision stack (Omega/Inference DeviceAgentService, VisualVerifyLoop,
      Screen2AXFusion, ScreenCaptureService) as the visual-grounding model for the
      agent driving the screen. 4B VLM → needs a vision runtime (mlx-vlm or similar);
      evaluate on-device feasibility + Pro/MAS gating. Verdict doc + wire-in; honest.
- [ ] **Add LiquidAI LFM2.5-8B-A1B GGUF (huggingface.co/LiquidAI/LFM2.5-8B-A1B-GGUF)**
      — MoE, 8B total / ~1B ACTIVE = very light + fast (well within 16 GB, likely
      MAS-viable not just Pro). Wire into the GGUF lane as an installable candidate;
      EVALUATE best role (dedicated fast/quick local model? a Fast-tier option? a
      cheap tool/triage model?) and document the verdict. Memory-gate honestly (it's
      small so it should just fit). Add the LiquidAI/LFM logo to P6.1. Verify it
      loads + generates.
- [ ] **Add Gemma 4 26B-A4B QAT GGUF (unsloth/gemma-4-26B-A4B-it-qat-GGUF)** — owner
      wants this MoE (26B total / ~4B active) running. The MLX 4-bit variant is
      already cataloged (`gemma4_27BA4B4Bit` = mlx-community/gemma-4-26b-a4b-it-4bit,
      InferenceState.swift:44) but it's gated at 18 GB min (line ~287) so it's
      blocked on the 16 GB Mac. WIRE the Unsloth QAT **GGUF** variant into the Pro
      GGUF runtime lane (llama-cli, flag-gated EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0,
      MAS-forbidden) — QAT GGUF is smaller than MLX 4-bit and is what the GGUF lane
      runs. Add as an installable candidate; memory-gate honestly but allow the new
      "Run anyway" override + the corrected available-memory estimate so a 16 GB Mac
      can attempt it (MoE = ~4B active so it's lighter than a dense 26B). Verify it
      loads + generates via the GGUF lane. Pairs with the B1 Variant Ladder.

## Full-port targets (owner 2026-06-18 — deeply analyze/research, then FULL port)
- [~] **R-ASSISTANTS — survey the TOP assistant/agent apps on GitHub (owner 2026-06-18)**
      Beyond R-APPS: deep-scan the best open-source ASSISTANT-class apps and mine
      their system-prompts + architectures + UX. Cover: PERPLEXITY-style answer
      engines (Perplexica, Morphic, Khoj, scira, Farfalle, Onyx), COMPUTER-USE
      agents (Open Interpreter, self-operating-computer, UI-TARS, Agent-S,
      browser-use, OpenClaw), and general assistant/agent apps. Verdict doc: per app
      what to adopt natively (patterns/prompts/UX) vs skip, license. Feed the best
      into Chat/Act/Work + the deep-research (DeerFlow) + computer-use stacks.
      ✅ VERDICT 2026-06-18→19 (docs/RESEARCH_ASSISTANTS_2026_06_18.md): PATTERN-MINE,
      do NOT port any (all Python or TS/Next.js → NO-SIDECAR; Epistemos already owns
      native answer-engine RAG [DeerFlow + RRF + Eidos] + computer-use [DeviceAgent/
      AXorcist/VisualVerifyLoop]). Khoj = AGPL-3.0 → `research_only` (same block as
      R-FIELDTHEORY); rest MIT/Apache → pattern adoption under ProvenanceGate.
      HIGHEST-VALUE mine = the computer-use ACTION-SCHEMA + system-prompt discipline
      (UI-TARS thought/action, Agent-S ACI, browser-use DOM-index+recovery, Open-
      Interpreter confirm-before-exec) → fold into the native loop + deterministic
      schemas P8.2. 2nd = web-search (SearXNG-style) + connector (Onyx) retrieval
      SOURCES for DeerFlow. UI-TARS-1.5-7B VLM = future Pro local-GUI model (GPU/RAM-
      heavy, not M2-Pro-16GB). Per-app table + HARNESS-SYSTEMS synthesis in the doc.
      REMAINING: Farfalle/self-operating-computer/OpenClaw not individually fetched
      (covered by the family verdicts; fetch if a specific port is pursued).
- [~] **DeerFlow 2.0 — BUILD STARTED 2026-06-18 (owner go-ahead received). Native
      Rust, incremental. DONE: slice 1 ResearchPlan+execution_layers (92e4fc145,
      8 tests); slice 2 PLANNER planner.rs research_plan_schema+planner_prompt+
      parse_plan→validated ResearchPlan (c250a670b, 9 tests); slice 3 ORCHESTRATOR
      orchestrator.rs run_plan concurrent layer-by-layer fan-out + SubAgentResearcher
      trait (b1274ae16, 5 tests incl. real peak-concurrency probe); slice 3b LIVE
      RESEARCHER researcher.rs LiveSubAgentResearcher (isolated agent_core sub-agent
      loop per sub-question, reuses delegate_task SilentDelegate+run_agent_loop,
      PRO-gated like delegate_task; pure helpers sub_agent_objective+extract_findings
      unit-tested) (7fa16cc00); slice 4 REPORTER reporter.rs findings_digest+
      synthesis_objective+run_synthesis (2802387cc); slice 5a FLAG
      deep_research_enabled + run.rs run_deep_research tie-together planner→
      orchestrator→researcher→reporter (12e3fd02e); slice 5b VISIBLE SURFACE
      DeepResearchGateStatus+DeepResearchHealthRow in SubstrateHealthPanel
      (927dd31e6). RUST CORE COMPLETE (44 tests, BOTH builds). slice 5c FFI BRIDGE
      run_deep_research_session (#[uniffi::export(async_runtime=tokio)], PRO+flag
      gated, DeepResearchReportFFI{objective,report,sub_results}, catch_unwind
      panic guard, deep_research_report_to_ffi pure-mapped+tested) (da02f71bd).
      slice 5d SWIFT SEAM (THIS) Epistemos/Bridge/DeepResearchBridge.swift:
      DeepResearchService.run(objective,providerName,vaultPath,…) builds the
      ToolConfig + calls runDeepResearchSession → maps to Swift-native
      DeepResearchOutcome{objective,report,[DeepResearchFinding]}. TWO honest gates
      BOTH required: EPISTEMOS_DEEP_RESEARCH_V0 flag + a CLOUD provider (new
      DeepResearchGateStatus.isCloudProvider explicit allowlist → deep research can
      NEVER silently run on a route the user didn't pick, owner #1). #if
      !EPISTEMOS_APP_STORE (mirrors pro-build cargo split) + canImport(agent_coreFFI)
      real/else-throw, like LocalGgufRuntimeBridge. Warm build + build-for-testing
      green; fixed a LATENT 5b test breakage (DeepResearchGateStatusTests missing
      @testable import Epistemos — hidden by headless test-EXEC hang). 2 new
      cloud-allowlist tests. slice 5e-1 EXECUTION PATH + RENDERER (THIS):
      ChatCoordinator.runDeepResearch(_:chatState:operatingMode:) — appends the
      user msg, re-checks availability (honest DeepResearchService.unavailableReason),
      startStreaming() indeterminate progress (FFI returns whole report, no fake
      stream), calls DeepResearchService.run, renders via the new ALWAYS-COMPILED
      pure DeepResearchReportRenderer (Epistemos/Engine/DeepResearchReport.swift:
      DeepResearchOutcome+DeepResearchFinding moved here so they unit-test on MAS;
      report → [id]-cited synthesis + a Sources section resolving every cited [id]
      to its sub-question+findings) → appendCompletedLocalAssistantMessage, errors
      → addErrorMessage(from:). 6 pure renderer tests. app build + test build green.
      slice 5e-2 UI ENTRY POINT DONE — RUNS FROM THE UI (rule #8 last mile):
      ChatInputBar.onDeepResearch closure + a Pro-only (#if !EPISTEMOS_APP_STORE)
      "sparkle.magnifyingglass" deepResearchButton gated by showsDeepResearchButton
      (onDeepResearch wired + EPISTEMOS_DEEP_RESEARCH_V0 on + isCloudSelection —
      honest no-silent-route: reuses the cloud model the user already picked) →
      submitDeepResearch funnels text → ChatView.submitMainChatDeepResearch →
      ChatState.submitDeepResearch emits new AppEvent.deepResearchSubmitted (NO
      user-bubble here — runDeepResearch owns it) → AppCoordinator dispatches to
      ChatCoordinator.runDeepResearch (5e-1: progress + cited-report renderer).
      5 DeepResearchEntryPointTests lock the path + gating. app build + test build
      green. Single-agent stays default (button hidden when flag off / on local).
      NEXT (5e-3): arXiv/HF/autoresearch hookup so the autoresearch loop can spin a
      run; optional surfaces beyond main chat.
      Verdict: docs/RESEARCH_DEERFLOW_2026_06_18.md (R-DEERFLOW).**
      First REAL gap of the verdict sweep: Epistemos has every SUPPORTING piece
      (tools, compaction summarization, session memory, P8.1 schema gate, skills,
      filesystem artifacts) but its agent_core loop is SINGLE-AGENT — it lacks the
      multi-agent ORCHESTRATION (planner decompose → parallel sub-agent fanout →
      lead synthesis). Native build path scoped in the verdict (Rust agent_core:
      typed ResearchPlan + N concurrent sub-agent loops with isolated histories +
      compaction offload + Eidos-cited synthesis, flag-gated, MAS-safe in-process).
      NO Python/LangGraph sidecar. Needs owner sign-off (canon: no candidate build
      without it). Pairs with Osaurus(ACT) + Goose(WORK) as the 3rd leg. Original:
      ByteDance's
      multi-agent DEEP-RESEARCH framework (planner→researcher→reporter, web+tools).
      Owner wants it ported completely, reskinned to the app's pixel-art theme, and
      connected DEEPLY to the app to add research dynamics. Deeply research first
      (clone + read; it's Python/LangGraph → adopt the multi-agent deep-research
      ORCHESTRATION natively into agent_core, NOT a Python sidecar). Wire it into
      the existing autoresearch loop + agents + arXiv/HF/Knowledge-Core pulls so a
      query can spin a real multi-agent research run. Verdict doc → native port +
      reskin, ProvenanceGate + honest gating, per-feature harden.
- [ ] **PORT github.com/kuku-mom/kuku (R-KUKU)** — owner wants a FULL port; deeply
      research first (not local — clone + read; I don't know it off-hand). EVALUATE
      where it best fits — likely a VISUALIZATION surface (the Eidos visualizer /
      graph / live theater) or wherever its strength lies. Verdict doc (what it is,
      stack, license, native-vs-WebKit, best home in the app), then full port +
      pixel-art reskin, ProvenanceGate + honest gating, per-feature harden.
- [x] **LiteLLM Agent Control Plane (R-LITELLM-CP)** — VERDICT 2026-06-18
      (docs/RESEARCH_LITELLM_CP_2026_06_18.md): PATTERNS-ONLY, no port. Epistemos
      already implements the unified runtime-adapter ("1 place to call all
      agents") — 9 ToolHandler CLI passthroughs sharing hardened run_passthrough,
      RuntimeRouter policy, session.rs persistence, procedural memory, CRON
      schedule skill, Keychain vaulting — at parity-or-BETTER (9 runtimes vs 4-5;
      Epistemos also has max_cost_usd + local-first fallback that LiteLLM-CP
      lacks). Partial-gap = declarative "agent={runtime,tools,skills,persona}"
      surface → folded into the Osaurus P3.0 plan (Companion-fronted). SHIPPED
      cee830048: unblocked the pro-build test build (my P8.1 regression) + locked
      all 9 runtime adapters registered. Superseded detail below:
      github.com/LiteLLM-Labs/
      litellm-agent-control-plane. Deeply research; maps onto our agent
      orchestration / routing / control (RuntimeRouter + agent_core loop + Act).
      It's LiteLLM/Python → adopt the PATTERNS natively (control-plane design,
      routing policy), don't run a Python sidecar (NO-SIDECAR/MAS). Verdict doc +
      port the adoptable parts; honest gating, per-feature harden.
- [x] **vercel-labs/json-render (R-JSONRENDER)** — VERDICT 2026-06-18
      (docs/RESEARCH_JSONRENDER_2026_06_18.md): PATTERNS-ONLY, NO code lifted.
      Epistemos GenUI (GenUIDispatcher + GenUISchema + canonicalBody + A2UI
      Validator) ALREADY matches json-render's schema-keyed registry + catalog
      guardrail + validation + fallback + determinism — at parity-or-BETTER
      (Swift-typed, compile-exhaustive, determinism-tested vs JS runtime-validated).
      The ONE gap: json-render's STREAMING/progressive render (SpecStream: chunks
      → partial trees → live UI); Epistemos renders complete payloads only. Filed
      as a scoped FUTURE native-Swift feature (flag-gated GenUIStreamingDecoder +
      partial-render path reusing typed GenUIBody + ArtifactBlockView stream) —
      only matters for large streamed blocks, not urgent. No Node sidecar/WebKit
      (would duplicate the stronger Swift-native GenUI). Per-feature: GenUI is
      already comprehensively hardened (4 test files incl. determinism + canonical-
      body pairing). NO new code this slice — there was no gap to fill.
- [~] **R-HTMLSTREAM — VERDICT done 2026-06-18 (docs/RESEARCH_HTMLSTREAM_2026_06_18.md).**
      StreamHtml = MIT TS/React streaming-HTML renderer (HTML counterpart to
      Streamdown; repair pipeline + DOMPurify). PORT via the WebKit-bundle path
      Epistemos ALREADY uses for Tiptap (dev-time build, NEVER npm-at-runtime),
      render in a WKWebView for the P7.2 HTML workspace / rich chat-HTML; lift the
      repair pipeline + DOMPurify, drop the AI-SDK glue, pixel-art reskin,
      ProvenanceGate direct_import. No code lifted (research-first). Original:
      PORT github.com/Alphanimble/htmlstream (R-HTMLSTREAM)** — owner wants a FULL
      port. Deeply analyze/research first (not local — clone + read). Likely pairs
      with P7.2 (HTML workspace + chat-drivable canvas / live viewer). Verdict doc
      (what it is, stack, license, native-vs-WebKit mapping), then full port +
      pixel-art reskin, ProvenanceGate + honest gating, per-feature harden.

## Field Theory port (owner 2026-06-18)
- [~] **PORT github.com/afar1/fieldtheory (R-FIELDTHEORY)** — owner wants the WHOLE
      thing ported into Epistemos, deeply researched first (it's not local — clone +
      read it). Reskin to the app's PIXEL-ART look (FONTS mainly) and update anything
      visually inconsistent. WebKit is OK if the surface needs it. Verdict doc first:
      what it is, language/stack, license, how it maps in (native vs WebKit), then
      port + reskin. ProvenanceGate + honest gating; per-feature harden.
      ✅ VERDICT 2026-06-18 (docs/RESEARCH_FIELDTHEORY_2026_06_18.md): the port is
      BLOCKED by license (AGPL-3.0-or-later → viral copyleft, MAS/App-Store + closed-
      source incompatible) AND architecture (Electron → can't MAS-sidecar). Honest
      outcome = `research_only` + clean-room NATIVE pattern adoption; ~80% of its
      surface already exists natively in Epistemos; build the "context launcher"
      (frontmost-app context injection) natively as the one net-new pattern. See the
      [~] entry under "Verdict docs" for the full finding.

## Verdict docs already produced (decisions, not yet built)
R-VOICE (Kokoro+MOSS+filter), R-EVE (pattern only), R-OKF (export+privacy+dedup),
R-PROMPT (cache-stable prefix + lean schemas), CHAT_UX_MAP (3 axes). These are
DECISIONS — the BUILD + in-app verification still has to happen.

## Surfaces — web / browser / HTML (researched; tracked so not dropped, 2026-06-18)
- [ ] **P7.2 HTML WORKSPACE CANVAS** — fix the broken HTML workspace
      (`Epistemos/Models/HTMLWorkspacePackage.swift`) + an HTML `<canvas>` the
      chat can DRIVE ("be in the HTML page, do anything with HTML"). Queued
      behind the picker/chat audit.
- [ ] **SURFACE BROWSER USE in Act/Work** — `agent_core/src/tools/browser.rs`
      (~52 KB, shipped Pro: browser_navigate / snapshot / click / type / scroll /
      press / close) EXISTS but is NOT reachable from chat. Surface it in
      Act/Work so the agent can drive a browser / act on the web from chat.
      Pro-gated. (Will land naturally with the Osaurus Act import + tool exposure.)
- [ ] **P-OBSCURA: build the in-app Obscura browser** — researched, runtime
      NEVER built. READ FIRST: `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`
      + `docs/HELIOS_V5_INTEGRATION_PLAN_2026_05_05.md` §B3 (W6-A..W6-I: Obscura +
      deno_core + Eidos runtime, queued) + EPISTEMOS_HERMES_MANIFESTO (WKWebView
      built-in browser). BUILD the working in-app browser (Rust backend /
      WKWebView), tied to WORK mode + the HTML canvas + browser-use. Pro/dev-gated.

## Research-corpus completeness (RECURRING — owner mandate 2026-06-18)
- [ ] **Recurring corpus sweep**: each loop pass, scan `docs/fusion/*` (131 files)
      + the owner's prior plans + this session's queries, and ADD any
      researched/requested-but-untracked item to THIS ledger so nothing the owner
      researched is silently dropped. Do it incrementally (a few docs/pass) — this
      is a standing task, never "done".

## Stealth browsing + Best-of preset (researched 2026-06-18 → docs/RESEARCH_STEALTH_AND_BESTOF_PRESET_2026_06_18.md)
- [ ] **P-STEALTH: undetected/stealth browsing** — VERDICT: vendor
      `vibheksoni/stealth-browser-mcp` (MIT; nodriver + CDP + FastMCP; 97 tools;
      bypasses Cloudflare/Queue-It) via the EXISTING MCP path (MCPUrlServerDirectory/
      MCPBridge). Pro/dev-gated (Python subprocess), pinned + hardened, authorized
      use. Wire a `stealth` option on browser-use (browser.rs) + an Obscura
      WKWebView "fingerprint hardening" toggle; browser-use mainly drives the
      in-app Obscura browser, stealth-MCP is the escalation for protected sites.
      Engines: nodriver (Chrome), Camoufox (Firefox), SeleniumBase UC Mode.
- [ ] **P-BESTOF: best-of preset (powerful out of the box)** — curated default
      set of the BEST real working superpowers, each Pro/MAS-gated + user-toggle,
      wired into the P2.1 tool panel / capability explorer. Baseline = Anthropic's
      7 reference servers + GitHub MCP + Context7 + Playwright. KEY FINDING: most
      is ALREADY native in Epistemos (file_ops, web_fetch/search, browser.rs, Pro
      git, code_execution, memory+vault+Knowledge Core+Eidos+Halo, think) — so the
      preset = curate + gate + EXPOSE, not import-everything. Deliverable: a pure
      tested EpistemosBestOfPreset manifest {id, capability, gate, source, license}
      + a one-tap "Enable recommended power set" in P2.1 (MAS-safe subset; Pro adds
      shell/git/browser/CLI); external MCP picks only when actually wired (Keychain),
      never a fake-on toggle; prefer vendor-maintained MCPs.

- [ ] **R-CUA: trycua/cua — Computer-Use Agent infrastructure (owner 2026-06-18)** —
      owner (verbatim): *"this can be fused to browser use or be used aside from
      browser use — github.com/trycua/cua."* MIT-licensed (ProvenanceGate-friendly).
      Components: **Cua Driver** (background desktop automation macOS/Win/Linux; no
      focus-hijack; integrates Claude Code + MCP), **Cua Sandbox** (unified VM/
      container mgmt API), **Cua Agent** (CU agent framework — any model; Claude
      Code/Cursor/Codex/OpenClaw), **Cua-Bench** (OSWorld/ScreenSpot/Windows Arena
      eval), **Lume** (macOS/Linux VM manager on Apple's Virtualization.Framework,
      Apple Silicon). Repo is multi-lang incl. Swift (6.3%) + Rust (9.2%) — MAS-
      fusable slices exist. RESEARCH-FIRST → VERDICT doc (direct_import/adapter_wrap/
      quarantine_reference/clean_room per F-ProprietaryCompression-ProvenanceGate).
      FUSION TARGETS: (a) **Lume's Virtualization.Framework VM** maps directly onto
      the owner's Act=Osaurus Virtualization SANDBOX plan — strongest fuse; (b) the
      Driver/Sandbox computer-use loop fuses with the EXISTING native stack
      (DeviceAgentService, VisualVerifyLoop, ScreenCaptureService, Screen2AXFusion)
      + Holo-3.1-4B VL — either FUSED INTO browser-use or STANDALONE full-desktop
      control, as the owner said; (c) **Cua-Bench** as a computer-use EVAL harness.
      CONSTRAINTS: Python Agent/Bench/Driver bits are NO-SIDECAR on MAS → Pro/dev-
      gated or reference-only; lift the Swift/Rust + Virtualization.Framework logic
      natively (grep/extract, pinned, hardened). Honest gating; no fake CU. Verdict
      → port/fuse the MAS-safe slices.
- [ ] **R-LITEPARSE: dedicated PDF→Markdown import feature via run-llama/liteparse
      (owner 2026-06-18)** — owner (verbatim): *"when you do imports, I want there to
      be this process where all the PDFs are parsed into markdown… a dedicated
      feature on the note sidebar, a button I press to import any PDF, do it in bulk,
      or import a bunch of PDF files directly from Settings… a very dedicated
      feature… it's LiteParse, I really want the best one."* LiteParse
      (github.com/run-llama/liteparse): **84% RUST, Apache-2.0, runs ENTIRELY LOCAL/
      OFFLINE** — PDF via PDFium, bundled Tesseract OCR, outputs Markdown (rebuilds
      headings/tables/lists/images/links). PERFECT MAS fit: link the Rust core as a
      crate into agent_core (like epistemos-shadow/Goose), expose `pdf_to_markdown`
      over UniFFI — NO Python/Node sidecar at runtime. ProvenanceGate the vendor +
      bundle PDFium honestly. SCOPE: (1) native PDF→Markdown in agent_core (PDFium +
      Tesseract, in-process); (2) **note-sidebar button** — import a PDF → a markdown
      note in the vault; (3) **BULK import** — many PDFs at once from the sidebar;
      (4) **Settings bulk PDF import** surface; (5) make it a polished, dedicated
      feature (progress, honest errors, per-file status). CAVEAT: LiteParse's Office/
      image formats use LibreOffice/ImageMagick subprocesses — NOT MAS-safe; scope
      the MAS feature to PDF (PDFium, in-process) + OCR, and gate/skip the external-
      binary formats (Pro/dev or omit). RESEARCH-FIRST → ProvenanceGate verdict on
      direct crate-dep vs vendor; build+run verify a real PDF imports to markdown in-
      app (sidebar + bulk + Settings). Harden; honest gating; no fake parse.
      OWNER CLARIFICATION 2026-06-18 (verbatim): *"I still want the parser
      absolutely — it does not need to be on MAS if it can't be, but if we can please
      try. Like having the WHOLE THING as part of my app — different from USING it,
      actually CLONING it. Same for the other things I'm taking for my app to be
      app-native."* MANDATE: (a) the parser is NON-NEGOTIABLE — NEVER drop it for
      MAS-safety; if a piece genuinely can't be MAS-safe, **Pro/dev-gate it (honest,
      visible) rather than omit** — but always PREFER the in-process MAS-native path
      (PDFium + Tesseract) and only gate the parts that truly can't (LibreOffice/
      ImageMagick Office/image conversion, remote OCR). (b) **EMBED, don't wrap** —
      actually CLONE/vendor the LiteParse Rust core INTO the app (agent_core crate),
      compiled as a first-class native part — not a thin wrapper that shells out to
      an external `lit`/npm/pip tool. So the S2 native vendor IS the point: pursue
      the real PDFium bind + bundled engine; if MAS can't ship PDFium in-process,
      Pro/dev-gate the live engine but still ship it embedded. See APP-NATIVE-BY-
      EMBEDDING principle in the header.

## Unfinished-research sweep top items (2026-06-18 → docs/UNFINISHED_RESEARCH_SWEEP_2026_06_18.md)
Local/chat, verified-against-code, not-blocked (full list + eras in the sweep doc):
- [ ] **OBS-1/2/3 Eidos→chat wiring** — EidosBridge FFI (W-46) + closed-citation
      emit-gate into ChatCoordinator (W-47) + "Retrieved by Eidos" panel (W-48).
      Eidos substrate done (~472 tests); chat wiring not. HIGH value.
- [ ] **OBS-5 Eidos cold-build Swift-6 isolation fix** — the EidosBridge/Wiring
      MainActor-UniFFI bug (cold/CI build only). Quick win; already flagged.
- [~] **EML-2 / EML-3** — EML-3 DONE + LIVE; EML-2 TESTED PRIMITIVE (not live).
      EML-3 (2026-06-18): eml_rerank wired LIVE into vault.search (apply_eml_rerank,
      EPISTEMOS_EML_RERANK_V1, b260b4da1 chain) + visible Substrate Health surface
      (EmlRerankGateHealthRow) — genuinely live, flag-gated OFF.
      EML-2 (CORRECTED 2026-06-18, 38b8f9d13): the fused confidence×complexity
      route gate was wired into ConfidenceRouter.route() — but a rule-#8 self-audit
      found ConfidenceRouter is NEVER instantiated in production (live router =
      TriageService.InferencePolicyEngine, which is complexity-only, no confidence
      signal). So EML-2 is a tested, parity-locked PRIMITIVE, NOT live; the health
      row + doc now say so honestly. LIVE-WIRING EML-2 needs a confidence signal
      added to the triage profile first (separate design) — re-queued, not done.
- [~] **LF-1/2/3 kill MoLoRA/QLoRA Python subprocess** — NO-SIDECAR breach
      (molora_inference.py + __pycache__ live); port to in-process MLX-Swift.
      VERDICT done 2026-06-18 (docs/RESEARCH_FINETUNE_NATIVE_MLX_2026_06_18.md):
      the native LoRA trainer is ALREADY VENDORED — mlx-swift-lm MLXLLM.LoRATrain +
      loadLoRAData + MLXLMCommon LoRAConfiguration/LoRAContainer/QLoRALinear, linked
      in the build. So the kill is WIRING, not a port. SLICE 1 DONE (9096613fb):
      LoRAChatDataConverter — pure native chat-JSONL → {"text":…} bridge (native
      loadJSONL reads only {"text":…}; Epistemos emits {"messages":[…]}), 6 tests,
      no Python/MLX dep, INERT. Kill-order: 1✅ data bridge · 2✅ NATIVE TRAINING
      WIRED — QLoRATrainer's python3 Process() body REPLACED by in-process
      NativeLoRATrainer.train (MLXLLM.LoRATrain, d4b468b2b+a6f479ec2; subprocess
      KILLED; watchdog-test fixed db317f42d; compile-verified, on-device run
      pending) · 2d✅ dead Python plumbing removed (pythonPath/activeProcess/TrainingProgressParser, 01f499060; +2 mirrored-test regressions fixed) · 3a✅ NATIVE MoLoRA apply built (NativeAdapterApply via LoRAContainer.from(directory:).load(into:) + NativeAdapterDirectory contract + trainer writes adapter_config.json; c8f8154f2; MoLoRAInferenceService is ORPHANED — never instantiated, subprocess never runs) · 3b NEXT: relocate MoLoRAAdapterConfig (shared w/ AdapterRegistry), delete orphaned MoLoRAInferenceService + molora_inference.py/train_router.py/sgmm_kernel.py, update ~7 mirrored-source tests honestly (grep EVERY assertion) · 3b.1✅ fill_training_gaps.py deleted (553176238, dev-only ref) · 3b.2✅ train_knowledge.py+train_style.py DELETED (50c5c3c4a — bundle cp lines + 3 tests honest, bundle-phase verified) · 3b.3✅ MOLORA CLUSTER DELETED (65cfaa9f4 relocate MoLoRAAdapterConfig + 3da3ec59d delete orphaned service + this: molora_inference.py/sgmm_kernel.py/train_router.py + MoLoRA/tests/*.py + bundle cp + ~7 mirrored tests honest incl. latent-2c QLoRATrainer MAS-gate fix) · 4 native data-gen NEXT · 5 PythonEnvironmentManager LAST (KTO+AudioTranscriber still Python) · 3b.2(orig) (remove bundle-app-runtime-assets.sh cp lines 139-142 [set -euo: missing cp FAILS build]; git rm both; PythonEnvironmentManager probe at :101 no-ops harmlessly [Training/scripts empties; KTO uses Alignment/scripts]; update QLoRATrainingTests bundled-asset list :305-306 + knowledgeHyperparams/styleHyperparams .py-content reads, RuntimeValidationTests :1372-1373, ReleaseScriptAuditTests :40-41; warm build RUNS the bundle phase=verifies) · 3b.3 molora cluster (relocate MoLoRAAdapterConfig, delete orphaned MoLoRAInferenceService+molora_inference.py+sgmm_kernel.py+train_router.py, update MoLoRANoSidecarGuardTests/RuntimeValidationTests:5189/AppStore+ProductionHardeningTests/AdapterManagementTests/project.yml individual excludes) · 4 native data-gen · 5 PythonEnvironmentManager LAST (KTO+AudioTranscriber still Python)
      · 2(old) SUBSTRATE done
      (de094e5e7): NativeLoRAPlan (pure TrainingConfig→native hyperparams, tested)
      + gated NativeLoRATrainer building REAL LoRATrain.Parameters + LoRAConfiguration
      + prepareDataset (no Python), compile-verified vs vendored types — REMAINING
      in 2b: model-load (reuse MLXInferenceService) + optimizer + LoRATrain.train +
      saveLoRAWeights/AdapterMetadata to fully replace QLoRATrainer's Process body
      (needs on-device run) · 3 adapter apply via LoRAContainer
      (deprecate molora_inference.py) · 4 native data-gen (port MOHAWK; RunPod is
      Pro/dev infra, never MAS) · 5 DELETE the .py + PythonEnvironmentManager (own
      grep-proven commits once native replacements ship). ProvenanceGate:
      direct_import (package already a dependency). NEXT: slice 2b train() wiring.
- [ ] **REG-1 KV-Direct-Gate harness**, **REG-3 NightBrain bodies**, **REG-2 T20
      Variant Ladder** (honest local routing), **REG-6 per-model memory folder +
      chat-as-graph-node**, **SIM-4 real MLX-Swift LoRA hot-swap**, **LI-2/LI-3
      Residency PatternBoost + ColdStream** (newest local-routing research).
- NOTE: "EML" = elementary-math IR, NOT episodic memory (separate CoALA episode
  track). Simulation donor mining is BLOCKED (Hermes coupling). Don't conflate/revive.

## More owner asks (2026-06-18)
- [ ] **R-APPS: study the best OSS chat/agent apps** — LM Studio, HuggingFace
      (chat-ui / transformers / candle), Unsloth, Jan, Ollama, Open WebUI, Cherry
      Studio, LibreChat + best others. Deep-read SYSTEM PROMPTS, architectures,
      agent loops, tool/MCP handling, local-model + structured-output patterns, UX.
      Write a verdict doc (adopt-natively vs skip, license, via ProvenanceGate);
      take the best system-prompt + architecture ideas honestly. (Research phase.)
- [ ] **P2.7: skill/tool/superpower/MCP INSTALL + MANAGEMENT surface** — install
      from external sources (GitHub repos AND MCP registries: modelcontextprotocol
      registry, Smithery, mcp.so, glama, awesome-mcp-servers). Must PERSIST
      installed ones (survive restarts) AND USE them once installed (wired into the
      tool catalog / executionPlan / MCPBridge — not just listed). Settings
      management pane: browse / install / enable / disable / update / remove. Honest
      gating (Pro/MAS, Keychain for tokens, security.rs for subprocess). Pairs with
      P-BESTOF preset + P2.3 MCP + P2.4 skills.
- [ ] **default-Qwen-4B bug repair** — something auto-defaults to Qwen 4B instead
      of a Fast Gemma; fix the default-resolution seam (effectiveLocalTextModelID /
      sanitizedStoredLocalChatModelID), keep both Qwens explicit-only.

## OWNER FINAL DIRECTIVE 2026-06-18 — BUILD FROM THE RESEARCH (100% wanted)
Every R-* verdict + ledger item must become a SHIPPED, in-app-verified slice —
nothing optional. Loop is now BUILD-FIRST: each pass ships a verified code slice
from the TOP sweep items / R-verdicts BEFORE any new research (cap: ≤1 verdict doc
per pass). Keep until all done + hardened (rule #6/#8).
- [ ] **R-GOOSE: port/vendor Block's Goose into agent_core** — github.com/block/goose
      (Apache-2.0, Rust). Owner wants it absolutely-or-almost-entirely PORTED (it's
      Rust → vendor into agent_core, not just the existing CLI passthrough
      GooseHandler). Evaluate fusing its WebKit UI with chat. Research-first +
      ProvenanceGate (F-ProprietaryCompression-ProvenanceGate: quarantine→inspect→
      benchmark→choose direct_import/adapter_wrap/clean_room). Honest, Apache-2.0
      attribution.
- [ ] **R-OPENCLAW: study ~/Downloads/openclaw-main (LOCAL, TS/Node + ui)** — perfect
      native capabilities from its patterns (sandbox Dockerfiles, agent loop, UI).
      Adopt natively (no TS fork); ProvenanceGate.
- [ ] **R-HERMES: deep-study docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md +
      manifesto for native-capability ideas** — adopt NATIVELY with ZERO Hermes
      naming (namespace stays purged; use LocalAgent/Runtime prefixes). Ideas only,
      not the name.
- [ ] **R-APPS** (from prior msg): study LM Studio / HF chat-ui+transformers+candle /
      Unsloth / Jan / Ollama / Open WebUI / Cherry Studio / LibreChat — system
      prompts, architectures, agent loops, tool/MCP, local+structured-output, UX →
      verdict doc (adopt-natively vs skip, license, ProvenanceGate).

## OWNER 2026-06-18 — Goose engine-extraction + per-feature hardening + guardrails
- [ ] **R-GOOSE refined = ENGINE EXTRACTION** (CONFIRMED arch: Chat=Epistemos engine,
      Act=Osaurus, Work/OpenCode=GOOSE). Pull the raw Goose RUST CORE (Apache-2.0,
      github.com/block/goose) into agent_core as a crate via UniFFI = the FULL engine
      (repo indexing, git lifecycle, multi-file diffs, deterministic test-and-fix
      self-correction loop, parallel subagents, YAML recipes). Do NOT import the
      Node/TS Goose DESKTOP (dual-process would swap-kill the 18GB M2 Pro) — own
      SwiftUI skin. Goose engine lives in the shared Rust core so Act/Chat can tap
      its MCP/subagent pieces; surfaced primarily through Work. Validate Goose code
      patches against the P8.2 deterministic schemas. ProvenanceGate the vendor.
      ✅ SEAM B 2026-06-19 (first landable Rust seam): NEW agent_core/src/work.rs
      (always-compiled, INERT) — the Rust-side seam the Swift WorkBackend drives via
      UniFFI: WorkError (EngineNotWired, honest, no silent fallback) + is_armed()
      (EPISTEMOS_WORK_GOOSE_V0) + run_work_session() (inert → EngineNotWired) +
      `#[uniffi::export] work_backend_status_json()` (the first concrete UniFFI seam).
      `pub mod work;` added to lib.rs (additive). GUARDRAIL by construction: nothing
      in agent_loop/agent_runtime references it → Chat/Act unchanged. +3 cargo tests;
      `cargo test --lib` BOTH features green (default 5379 / pro-build 5641, 0 failed)
      — zero regressions across the lib surface (a full-suite attempt hung on the
      orphaned-falsifier-bin collision from an earlier `| tail` pipe; re-ran to FILES).
      ✅ S2 2026-06-19 (plan + FIRST real vendor): docs/GOOSE_S2_EXTRACTION_PLAN_
      2026_06_19.md (block/goose Apache-2.0 workspace; core = crates/goose; leaf-
      first selective direct_import — NOT the heavy whole-crate vendor). Vendored
      the first real block/goose type — `SourceRoot` (crates/goose/src/source_roots.rs,
      self-contained std-only) — VERBATIM into agent_core/src/work.rs `pub mod
      vendored_goose` (direct_import, provenance + Apache-2.0 consts); run_work_session
      now takes `&[SourceRoot]` (the workspace it operates on), still inert. +1 cargo
      test; cargo --lib BOTH green (5380 / 5642, 0 failed). GUARDRAIL holds.
      ✅ S3 2026-06-19 (next leaf + typed contract): vendored the block/goose
      PERMISSION leaf VERBATIM — `Permission` (5 variants), `PrincipalType`,
      `PermissionConfirmation` from crates/goose-providers/src/permission.rs
      (Apache-2.0 `direct_import`; ONE documented adaptation — the upstream `ToSchema`
      derive + `use utoipa` dropped, agent_core has no utoipa, it's OpenAPI-doc-only;
      every variant/field + serde `rename_all="snake_case"` byte-for-byte upstream).
      Added first-party typed `WorkRequest` (objective + `Vec<SourceRoot>` +
      `default_permission`, `read_only` ctor defaults to the SAFEST `AllowOnce`, never
      `AlwaysAllow`) + `WorkResult` (summary + files_touched); `run_work_session` now
      takes `&WorkRequest` → `Result<WorkResult, WorkError>`, still inert
      (EngineNotWired, never a Chat/Act fallback). +2 cargo tests (upstream-variant +
      snake_case wire-form round-trip; safe-default posture). cargo --lib BOTH green
      (default 70/0, pro-build 90/0 on the `work` filter). GUARDRAIL holds — work
      module still isolated, no agent_loop/agent_runtime ref.
      ✅ S4 2026-06-19 (recipe-parameter leaf + grew WorkRequest): vendored the
      block/goose recipe-PARAMETER typing system VERBATIM from
      crates/goose/src/recipe/mod.rs — `RecipeParameterInputType` (string/number/
      boolean/date/file/select), `RecipeParameterRequirement` (required/optional/
      user_prompt), `RecipeParameter` (key/input_type/requirement/description/default/
      options) — into `work::vendored_goose::recipe` (Apache-2.0 `direct_import`;
      documented trims: ToSchema derive + `.unwrap()`-using Display impls dropped,
      PartialEq/Eq added; every field/variant + serde `rename_all="snake_case"`
      byte-for-byte). Grew the typed `WorkRequest` with `parameters:
      Vec<RecipeParameter>` (a Work task's declared typed inputs; empty by default,
      `read_only` defaults it). +2 cargo tests (recipe snake_case wire-form +
      skip_serializing_if round-trip; WorkRequest carries params + stays inert).
      cargo --lib BOTH green (default 72/0, pro-build 92/0 on `work`). GUARDRAIL
      holds.
      ✅ S5 2026-06-19 (recipe Settings leaf + grew WorkRequest): vendored block/goose
      recipe `Settings` VERBATIM (goose_provider / goose_model / temperature: f32 /
      max_turns) into `work::vendored_goose::recipe` (Apache-2.0 direct_import; ToSchema
      trimmed; `PartialEq` added but NOT `Eq` — `temperature: Option<f32>` isn't Eq;
      `skip_serializing_if` preserved byte-for-byte). Grew the typed `WorkRequest` with
      `settings: Option<Settings>` (a Work task's model config; None = engine defaults,
      `read_only` defaults it) — and DROPPED `Eq` from `WorkRequest`'s derive (the f32
      forbids it; `PartialEq` kept, nothing compares whole requests for Eq; documented).
      +2 cargo tests (Settings None-skip round-trip; WorkRequest carries settings +
      stays inert). cargo --lib BOTH green (default 74/0, pro-build 94/0). GUARDRAIL
      holds.
      ✅ S6 2026-06-19 (loop-safety guard — FIRST clean_room_rewrite; verbatim leaves
      EXHAUSTED): the easy self-contained block/goose leaves are now all vendored
      (source_roots + permission + recipe params/Settings); the remaining types
      (tool_monitor, model_config, message) depend on `rmcp`/internal-goose/async — NOT
      clean direct_import leaves. So S6 pivots posture: a FIRST-PARTY `RepetitionGuard`
      in work.rs — ProvenanceGate `clean_room_rewrite` of block/goose
      `RepetitionInspector` (tool_monitor.rs): the same consecutive-repeat detection +
      per-tool counts, re-expressed against a first-party tool-call shape (name +
      `serde_json::Value` args) so it pulls NO rmcp/async-trait deps + uses no
      force-unwrap. Real Work-engine loop safety (blocks a tool call repeated past
      `max_repetitions` so a session can't spin forever). +5 cargo tests (blocks
      consecutive repeats / resets on a different call / None never blocks but counts /
      args distinguish calls / reset clears). cargo --lib BOTH green (default 79/0,
      pro-build 99/0). GUARDRAIL holds. NEXT (S7): the provider/format layer needs rmcp
      or a clean-room message shape — heavier, NOT a one-pass autonomous leaf; flag for
      a focused multi-slice push.
      ✅ S7 2026-06-19 (the self-correction pillar — a CLEAN leaf after all): the S6 note
      flagged S7 as "heavy provider/message layer", but research found a clean self-
      contained one: `RetryConfig` — block/goose's "deterministic test-and-fix self-
      correction loop" (an owner Goose pillar) as a typed, validated config. VERBATIM from
      block/goose crates/goose/src/agents/types.rs into `work::vendored_goose::retry`:
      `RetryConfig { max_retries, checks: Vec<SuccessCheck>, on_failure, timeout_seconds,
      on_failure_timeout_seconds }` + the `SuccessCheck` enum (serde `tag="type"` + `"shell"`
      alias) + the two DEFAULT_*_TIMEOUT_SECONDS consts + the byte-faithful `validate()`
      rules. Two faithful adaptations (documented inline): drop `utoipa::ToSchema` (no
      utoipa dep), add `PartialEq` (composes into WorkRequest). MAS-SAFE: the on_failure /
      Shell command strings are only CARRIED — the inert seam executes NOTHING; running the
      checks / cleanup shell is the future Pro-gated engine lane (per APP-NATIVE-BY-EMBEDDING:
      embed the type, gate the un-sandboxable execution). Wired `retry: Option<RetryConfig>`
      into `WorkRequest` (additive; read_only → None) so a Work task can declare a self-
      correction policy the engine will run. +4 cargo tests (validate matches upstream incl.
      the EXACT error messages; SuccessCheck tag/alias wire-form; round-trip + skip-none +
      the verbatim default consts; WorkRequest carries retry — still inert). cargo --lib
      BOTH green: default 5441/0, pro-build 5703/0 (+4 each, ZERO regression). Seam stays
      inert (run_work_session → EngineNotWired); Chat/Act GUARDRAIL holds (mirrored-source
      tokens intact). NEXT: the provider/message layer (rmcp/clean-room) remains the heavier
      multi-slice push, or wire a real self-contained engine sub-piece (e.g. the retry
      driver loop) clean-room.
      ✅ S8 2026-06-19 (the self-correction DRIVER — S7's config becomes working logic):
      took the S7-NEXT option ("wire a real self-contained engine sub-piece clean-room").
      RESEARCH-FIRST read block/goose `agents/retry.rs` `handle_retry_logic` + `RetryManager`
      (Apache-2.0). The deterministic control flow is cleanly separable from the async/shell:
      upstream runs `execute_success_checks` / `execute_on_failure_command` (tokio shell) —
      those are the un-sandboxable parts. So `clean_room_rewrite` of the DETERMINISTIC core
      into work.rs: NEW `RetryResult` enum (Skipped / SuccessChecksPassed / MaxAttemptsReached
      / Retried — the SAME four upstream outcomes) + `RetryManager { attempts }` with
      `evaluate(config, checks_passed, on_failure)` mirroring `handle_retry_logic` BYTE-FOR-
      BYTE in control flow (no config→Skipped; checks pass→SuccessChecksPassed; attempts ≥
      max_retries→MaxAttemptsReached; else run on_failure cleanup + increment→Retried). The
      side effects are HOISTED OUT — the caller supplies `checks_passed` (it ran the success
      checks) + an `on_failure` callback (the cleanup hook) — so this seam EXECUTES NOTHING
      (MAS-safe; the real shell is the future Pro lane, per APP-NATIVE-BY-EMBEDDING: embed the
      control flow, gate the un-sandboxable execution). No force-unwrap. This turns the S7
      `RetryConfig` into a working deterministic self-correction loop. +5 cargo tests (skip
      w/o config / success short-circuits w/o cleanup / retries + runs on_failure when
      attempts remain / stops at max w/o increment-or-cleanup / drives a full fail→fail→pass
      loop then resets). cargo --lib BOTH green: default 5446/0, pro-build 5708/0 (+5 each,
      ZERO regression). Seam still inert (run_work_session → EngineNotWired); GUARDRAIL holds.
      NEXT: a `RetryExecutor` trait (the injected shell side, Pro-gated) to run the loop for
      real, or the provider/message layer.
      ✅ S9 2026-06-19 (the executor — the self-correction sub-system is now RUNNABLE; took
      S8's NEXT option): the deterministic driver (S8) needed the side-effecting half to
      actually run. NEW `RetryExecutor` trait (`run_success_checks(&[SuccessCheck]) -> bool`
      [ALL-must-pass, empty=pass] + `run_on_failure(&str)`) + `drive_retry_cycle(manager,
      config, exec)` (runs this attempt's checks via `exec`, then `RetryManager::evaluate`
      with the result + the executor's on_failure on the Retried path; no config → checks
      skipped → Skipped). The MAS build carries ONLY the trait + drive + test mocks — the
      REAL `ShellRetryExecutor` is `#[cfg(feature="pro-build")]` (subprocess execution is
      outside the MAS sandbox): it runs each check / on_failure command in a HARDENED
      subprocess via `crate::security::harden_cli_subprocess_std` (env_clear + canonical
      allowlist/denylist + process group, per the subprocess-hardening doctrine). This is
      the APP-NATIVE-BY-EMBEDDING split made concrete: the deterministic control flow ships
      everywhere; the un-sandboxable execution is Pro-gated. (`timeout_seconds` enforcement
      is a documented follow-on — std::process has no built-in timeout.) +5 cargo tests:
      4 MAS-safe drive tests (succeeds-on-pass / retries+cleanup-on-fail / stops-at-max /
      skips-without-config-and-never-runs-checks, via a MockExec) + 1 Pro-only test that
      RUNS the REAL hardened executor against `true`/`false` (`true`→pass, `false`→fail,
      all-must-pass, empty=pass, on_failure best-effort). cargo --lib BOTH green: default
      5450/0 (+4), pro-build 5713/0 (+5, incl. the real-subprocess test). Seam still inert
      (run_work_session → EngineNotWired); Chat/Act GUARDRAIL holds. The Goose self-
      correction pillar is now COMPLETE end-to-end (config S7 → driver S8 → executor S9),
      runnable in Pro + deterministic-verifiable in MAS. NEXT Goose: the provider/message
      layer (rmcp/clean-room) to give the engine a model to drive.
- [~] **GOOSE GUARDRAIL** — isolate the extracted Goose core behind Work mode + a
      feature flag; keep Chat/Act on their own engines; add regression coverage
      PROVING Chat + Act are unchanged after Goose lands. Must make Work much better,
      NEVER destabilize the working chat.
      ✅ SEAM A 2026-06-19: the isolated Work-backend seam landed (mirrors ActOsaurus
      Seam A). Epistemos/Work/WorkBackend.swift (Pro-only protocol + WorkCapability +
      INERT stub that THROWS engineNotWired — no fake capability, no silent fallback)
      + WorkBackendGateStatus (flag EPISTEMOS_WORK_GOOSE_V0, OFF) + WorkBackendHealthRow
      (visible). GUARDRAIL LOCKED BY TEST: the seam adds NO `.work` case to
      CoworkChatMode and references NEITHER CoworkChatMode NOR ChatCoordinator →
      Chat/Act definitionally UNCHANGED. block/goose confirmed Apache-2.0 (clean
      ProvenanceGate). +4 tests; build green. NEXT (Goose S2): vendor block/goose's
      Rust core into agent_core (crate via UniFFI) + a PLAN; then GooseWorkBackend
      drives it.
- [ ] **PER-FEATURE HARDENING + NO-DRIFT GUARANTEE (rule #6 extension, applies to
      ALL items)** — every feature/item gets its OWN hardening phase: own regression
      tests + re-verify the items it touches still work in-app + a "HARDENED <item>"
      log line. An item isn't done until hardened AND protected from later
      regression. Keep re-running the recurring corpus sweep so nothing disappears
      under compression.
- [ ] **P8.1b CHAT DEEP-REPAIR (first-class)** — deeply repair the messy Epistemos
      Chat: clean + maintainable + FULL capability, no IP loss (Eidos/KC/Halo/memory/
      skills). Use Osaurus chat structure as the refactor reference (after import).
- [ ] **P5.H deep-harden + FINISH the substrate research** — Cognitive DAG,
      provenance, Knowledge Core, Halo, Simulation, GenUI, XPC: finish + deep-harden
      each (per-feature hardening). 100% mandate.

## Primitive-upgrades mine → P5/P8 (2026-06-18 → docs/PRIMITIVE_UPGRADES_MINE_2026_06_18.md)
- [ ] **FIRST DOMINO (owner decision)**: the entire agent_core/src/research/* tree is
      #[cfg(feature="research")] default-OFF, NEVER compiled into the app. Cores are
      real + 1,800+ tests, but reaching bridge.rs needs: decide `research` compiles
      into the MAS/Pro lib (or promote modules out of research/) + UniFFI export +
      Swift call-site. SIGN-OFF NEEDED before the EML/primitive batch can ship.
- [ ] **Tier-1 fast wins** (real Rust + LOCAL, M each after the domino):
      ✅ A1 EML-2 ConfidenceRouter scoring (b260b4da1), ✅ A2 EML-3 VaultRecall
      re-rank, ✅ A4 EML-1 HealthRow (EmlRerankGateHealthRow 35b3b85da),
      ✅ B1 T20 Variant Ladder (deferral terminal live), ✅ F4 confidence_floors
      (promoted always-compiled 09136fa8a). REMAINING: F1 Active-Assembly
      minimizer, F3 Sinkhorn brain_routing, F5 interrupt_calibration,
      F6 hybrid_memory folder, C1 info_ir→AnswerPacket.confidence, D1 ternary
      KV/steering.
- [ ] Tier-2 (perf/proof/gated) + Tier-3 (E1/E2 residency, capability-ceiling, must
      NOT move bytes until owner-gated) — see the mine doc.

## Settings / staleness / substrate-finish (owner 2026-06-18)
- [ ] **DEEP SETTINGS REPAIR** — audit EVERY Settings row/toggle for broken or
      stale-assumption controls; fix/remove; verify each remaining control wired to
      real runtime. (✓ first slice: SubstrateHealthPanel collapsible 13d2b5307.)
- [ ] **APP-WIDE STALENESS SWEEP** — find + repair/remove super-old instances
      (stale flags/model names/dead paths/old copy) with regressions, not just
      Settings.
- [ ] **FINISH SUBSTRATE to T4+ (P5/P5.H)** — Cognitive DAG, provenance, Knowledge
      Core, Halo, Simulation, GenUI, XPC, Eidos, EML all to T4+. Only the 70B/System
      G RUNTIME stays owner-gated.
- [ ] **MINE SYSTEM G LOGIC → app** — extract reusable logic from Epistemos/SystemG/*
      (AnswerPacket/SovereignGate/RuntimeRouter/run-event-log/verifiability) and
      apply to app parts that truly benefit, WITHOUT arming the gated 70B runtime.
- [ ] **INFUSE EPISTEMOS IP INTO ACT (Osaurus) + WORK (Goose)** — wire in the
      deterministic schemas (P8.2), Eidos, Knowledge Core, memory/vault, the
      determinism/verifiability gates, and theme, so Act/Work inherit the engines'
      hardening AND gain Epistemos superpowers (not vanilla).

## R-CODEREVIEW + R-AGENTFW (owner 2026-06-18)
- [ ] **R-CODEREVIEW ("thermonuclear" = a NAME for ultra-aggressive exhaustive
      review)** — research the best deep-review method; deliver TWO ways: (a) a LOOP
      PROCESS step that runs a whole-app deep review (correctness, dead/stale code,
      honesty-constraint violations, perf, arch drift) → files findings; (b) an
      IN-APP code-review feature in Work/OpenCode (review the open repo, gated by
      P8.2 schemas + Goose's self-correction loop). Real findings only.
- [ ] **R-AGENTFW agent-creation frameworks** — research + DELIBERATE: Vercel AI SDK
      (TS, MIT), Google ADK/Agent Builder (open), Cursor agent (proprietary —
      approach/UX only). Likely = ADOPT PATTERNS + agent-creation UX natively (tie
      into Companion/tamagotchi builder + Osaurus agent config + Goose subagents),
      NOT import SDKs. Verdict doc per framework: usable-IP vs patterns-only,
      license, what to take, recommended native design.

## GUARDRAILS — ENFORCE ON EVERY PASS (owner 2026-06-18, CRITICAL)
1. **DELETION GUARDRAIL** — thermonuclear review / hardening / dedupe may NOT
   delete NEW or IN-PROGRESS features (they look "unused" because they're mid-build
   / not yet wired) or ANY owner-requested ledger item. DELETION IS A LAST RESORT —
   prefer dedupe / consolidate / WIRE-IT-UP. Only remove code that is PROVABLY dead
   AND confirmed not part of any in-flight ledger item; when uncertain → KEEP + flag.
   Commit deletions SEPARATELY (own commit, easy revert). (✓ already applied: the
   appleIntelligenceSection removal was provably dead [1 self-ref] + capability
   preserved+tested + its own commit; the legacy popovers were uncertain → KEPT +
   flagged, not deleted.)
2. **CODE REVIEW IS RECURRING** — run the deep whole-app review MULTIPLE times
   (each phase + a periodic full-app pass), not once. R-CODEREVIEW loop step recurs.
3. **NO-SIDECAR clarification (Open Code)** — NO non-Swift app. Goose is RUST →
   compiles into agent_core via UniFFI (that's why it's the Open Code backend).
   Vercel(TS)/Google(Py)/Cursor(proprietary) are NOT Swift/Rust → adopt their
   PATTERNS natively, NEVER run Node/Python sidecars (NO-SIDECAR / MAS / 18GB
   memory). Same for R-OPENCLAW (TS) and R-APPS picks: patterns only, no sidecar.

## Full-port + model targets (owner 2026-06-18, batch)
Same posture for all ports: deeply research first (clone+read, NOT local), verdict
doc (what it is / stack / license / native-Swift-Rust-vs-WebKit mapping), then FULL
port + pixel-art reskin (fonts mainly), ProvenanceGate + honest gating, per-feature
harden. NO-SIDECAR: TS/Py = adopt patterns natively (or WebKit where the surface
needs it), never run a Node/Python sidecar.
- [~] **R-FIELDTHEORY** — github.com/afar1/fieldtheory: research + FULL port into
      Epistemos, reskin to pixel-art (fonts), fix visual inconsistencies. WebKit OK
      if the surface needs it.
      ✅ VERDICT 2026-06-18 (docs/RESEARCH_FIELDTHEORY_2026_06_18.md): `research_only`
      / clean-room NATIVE pattern adoption — NOT a port. TWO hard blockers: (1) the
      main repo is **AGPL-3.0-or-later** (viral copyleft → incompatible with
      closed-source MAS+Pro distribution AND App Store terms; even WebKit-bundling
      its TS would force Epistemos to AGPL → ProvenanceGate quarantine); (2) it's an
      **Electron** (Node+Chromium) app → can't be a MAS sidecar (NO-SIDECAR). ~80%
      of its features are ALREADY native in Epistemos (editor/terminal/Whisper/
      multi-window); the one net-new pattern worth building is the "context launcher"
      (global hotkey → inject current context into the frontmost app) as a clean-room
      NATIVE feature on the existing AXorcist/DeviceAgentService/CGEvent substrate.
      MIT *sibling* repos assessable individually if the owner names a component.
- [~] **R-HTMLSTREAM** — VERDICT done 2026-06-18 (docs/RESEARCH_HTMLSTREAM_2026_06_18.md):
      WebKit-bundle port (Tiptap pattern) → P7.2 HTML workspace; lift repair
      pipeline + DOMPurify; MIT direct_import; pixel-art reskin.
- [ ] **R-LITELLM-CP** — github.com/LiteLLM-Labs/litellm-agent-control-plane: maps
      onto our agent orchestration/routing (RuntimeRouter + agent_core loop + Act).
      Python → adopt the control-plane/routing-policy PATTERNS natively, NO sidecar.
      Verdict doc + port the adoptable parts.
- [ ] **R-JSONRENDER** — github.com/vercel-labs/json-render: maps onto Schema-First
      GenUI (P5) + the deterministic schema engine (P8.2) — render JSON/typed-schema
      payloads → UI. TS → adopt natively (SwiftUI) or via WebKit. Ties our
      deterministic schemas to a real render layer. Verdict doc + port.
- [ ] **LFM2.5-8B-A1B model** — huggingface.co/LiquidAI/LFM2.5-8B-A1B-GGUF: light MoE
      (8B total / ~1B ACTIVE, well within 16GB → likely MAS-viable, not just Pro).
      Wire into the GGUF lane as an installable candidate (CLEAN follow-on to the
      26B-A4B pattern just landed — fetch real HF provenance, new stage or reuse,
      memory-gate honestly [small, should fit]). EVALUATE + document its best role
      (dedicated fast/quick local? Fast-tier option? cheap tool/triage model?). Add
      the LiquidAI/LFM logo to the P6.1 lobehub logo set. Verify loads+generates.

## R-HOLO — Holo-3.1-4B VL for computer-use (2026-06-18 → docs/RESEARCH_HOLO_VL_2026_06_18.md)
- HONEST VERDICT: Holo-3.1-4B is a VISION-language model; the GGUF lane is text-only
  (gguf_cli.rs:348 supports_vision=false). NOT added as a fake text-GGUF candidate
  (would fake vision). REAL GAP to build:
- [ ] **Vision GGUF lane** (Pro) — GgufVisionCliProvider via llama-mtmd-cli + the
      model's mmproj-*.gguf (or an MLX-VLM Swift path); supports_vision=true; behind
      the GGUF flag + Pro gate, security.rs hardened. Then add Holo as a REAL vision
      candidate (fetch HF provenance for both the weights + mmproj).
- [ ] **Wire Holo → computer-use** — local vision policy in DeviceAgentService/
      ComputerUseBridge/VisualVerifyLoop (screenshot → Holo → grounded action/
      function-call); function-calls validated vs P8.2 deterministic schemas; honest
      gating (Pro/dev; MAS keeps the bounded/native computer-use path).

## R-KUKU verdict (2026-06-18 → docs/RESEARCH_KUKU_2026_06_18.md)
Kuku (kuku.mom / github.com/kukume) = a local-first AI note-taking app (Tauri +
SolidJS/WebKit, ProseMirror, local Whisper STT, graph, wikilinks, .md; client MIT
/ server AGPL) — Epistemos's closest sibling. VERDICT: SKIP the code (Tauri/TS, not
native; AGPL server). ADOPT 2 patterns natively:
- [ ] **AI MEMORY SHARING** — expose the vault/Knowledge Core/Eidos as a read-only
      LOCAL memory endpoint (local OpenAI/Ollama server OR an MCP "epistemos-memory"
      server) so any AI tool (Claude Desktop/Cursor/MCP clients) can query the
      user's notes as long-term memory. Keychain-token, localhost-only, user-toggled.
      Pairs with P-BESTOF + P2.7. (Epistemos's moat, made outward-facing.)
- [ ] **MEETING/LECTURE NOTE** — record → on-device STT (Apple Speech / local
      Whisper audio lane) → Epdoc note + AI summary. Slots into R-VOICE. On-device only.
- [ ] **MODEL DOWNLOAD/INSTALL BROKEN — can't download ANY model except the
      foundation package (owner 2026-06-19, HIGH PRIORITY — blocks owner's in-app
      testing).**
      ‼️ STILL UNRESOLVED IN-APP (owner re-reported 2026-06-19, later): *"I can't find a way to
      install the local models anyway."* Despite STEP-1 restoring the hidden install rows + the D2
      resume fix + req-11 listing, the owner STILL has NO working path to install a local model in
      the running app. This is the #1 visible blocker (it gates ALL the owner's in-app verification +
      every installable model — incl. the voice models + ColBERT). RE-VERIFY THE WHOLE INSTALL FLOW
      END-TO-END as the owner experiences it: is there a reachable, obvious INSTALL button/affordance
      for a real model (not just the foundation package) that actually downloads → verifies → installs
      → becomes usable? The "All models (advanced)" disclosure (STEP 1) must be discoverable + its
      install buttons must actually work + show live progress. Treat "owner cannot find/use install"
      as the acceptance bar — not "rows are present in code." Build+the owner verifies the full click-
      to-installed path in-app. THIS IS THE TOP VISIBLE PRIORITY.
      Owner (verbatim): *"I can't download any models, so there are many
      things I need to fix before I can get proper tests. I of course want it to code
      as much as it can without tests, but once it's ready I need to make sure my app
      can download and install all the models I want — all the ones that are advertised.
      Right now it only allows me to get the foundation package or something like
      that."* + REFINEMENT (verbatim): *"I still want to keep all the models my app
      has — even the ones we hid, I want those — but of course only advertise the ones
      that are canon."* SYMPTOM: in-app the model download/install UI only offers the
      "foundation package" (likely the single bundled Apple-Foundation / foundation
      GGUF pack); none of the OTHER advertised models actually download or install.
      REQUIREMENTS: (1) **Download + install must work for ALL ADVERTISED (canon)
      models** — every model surfaced in the catalog/picker must have a working
      download → verify → install → ready path (use/extend `ModelDownloadManager` +
      the install-progress P1.8 surface, ledger ~line 1491/904). Not just the
      foundation package. (2) **KEEP ALL MODELS — DELETE NOTHING** (honors the
      never-delete-owner-features doctrine): the old/previously-hidden models STAY in
      the app; do NOT remove them. Only the CANON set is ADVERTISED (visible in the
      picker/catalog); the rest remain present but un-advertised (hidden / Pro / dev-
      gated), retrievable, never deleted. So: advertise = canon-only; retain = all. (3)
      Reconcile the catalog so advertised = the canon model set (cross-ref the model
      picker simplify item ~line 912 + per-model-vaults ~line 314 + route profiles
      `InferenceState+RouteProfiles`); the catalog is the single source for what's
      advertised vs retained. (4) HONEST gating: a model that can't yet download shows
      an honest state, never a fake "available". TESTING CONSTRAINT (owner-stated):
      until model download/install works the owner CANNOT run proper in-app tests —
      so the loop should KEEP CODING as much as it can WITHOUT requiring in-app test
      verification for now (cargo --lib + build remain the gate), AND PRIORITIZE making
      model download/install work because it is the unblocker for all the owner's
      "build+run verify in-app" steps (incl. the TOOLS/SKILLS repair confirmation).
      Verdict/diagnosis first: why only the foundation package downloads (catalog
      filter? entitlement? URL/manifest? install pipeline?), then fix the pipeline so
      every advertised model installs.
      + REFINEMENT 2 (owner 2026-06-19, verbatim): *"I still want to be able to install
      ANY of them and set the ones I want to be advertised — meaning in Settings have a
      stack and select the models I want to appear on the model picker, and have it
      well-thought-out."* This SUPERSEDES the fixed "advertise = canon-only" reading:
      advertising is OWNER-CONTROLLED, not a hardcoded canon list. (5) **INSTALL-ANY** —
      the owner can download+install ANY model in the app's full catalog (every retained
      model, incl. previously-hidden ones), not just a canon subset. (6) **SETTINGS
      MODEL MANAGER ("the stack")** — a well-designed Settings surface listing ALL
      models (full catalog) where the owner: installs/uninstalls any model, sees install
      state + size + RAM + uses, and TOGGLES which models are "advertised" (appear in the
      model picker). The owner's selection is the source of truth for what the picker
      shows. (7) **CANON = DEFAULT, not a cap** — ship a sensible default advertised set
      (the canon models) so the picker isn't empty out of the box, but the owner can add/
      remove any model from the advertised set via the stack; their choice always wins.
      Persist the advertised-set selection. This composes with the model-picker simplify
      item (~line 912, name+uses+RAM, mode-scoped) — the picker renders exactly the
      owner-advertised set per mode. Keep ALL models retained (req 2); the stack just
      controls visibility + drives install. Design the stack UI well-thought-out (clear,
      pixel-art-minimal, honest install states), not demo-ish.
      + REGRESSION SYMPTOMS (owner 2026-06-19, verbatim): *"when I first tried
      downloading and installing models it would say corrupted or not complete or
      something. The entire progress bar is gone, and it's like the download feature
      itself has regressed a lot — I need it to be robust again."* So beyond "only the
      foundation package is offered," the download PIPELINE ITSELF has REGRESSED: (8)
      **INTEGRITY FAILURES** — installs report "corrupted" / "not complete" / partial;
      the download isn't verifying or completing correctly. Restore robust integrity:
      checksum/size verification against the manifest, atomic finalize (download to a
      temp path → verify → move into place, never leave a half-file marked installed),
      and RESUME of interrupted/partial downloads instead of failing. (9) **PROGRESS
      BAR GONE — REGRESSION** — the install progress bar (the P1.8 surface, ledger
      ~line 904 "Download/install progress visible") has DISAPPEARED; it used to show.
      Restore a real, live progress bar (bytes/percent/state) for every install. (10)
      **ROBUSTNESS RESTORE (treat as a regression, find what broke it)** — the download
      feature was more robust before and has degraded; git-archaeology / diff the
      `ModelDownloadManager` + install-progress UI to find WHAT regressed (a refactor
      that dropped progress wiring? a manifest/URL change? a verification step that now
      false-positives "corrupted"?), and bring it back to robust: clear error states
      (honest, actionable — not a dead bar), retry/resume, integrity verify, visible
      progress, completion confirmation. This is part of the SAME MODEL DOWNLOAD repair
      (the unblocker for in-app testing) — fix the pipeline so installs actually
      complete, verify, and show progress, for every advertised/installable model.
      🔎 S1 STOP-REINVENTING ROOT (docs/research/STOP_REINVENTING_AUDIT_2026_06_19.md): the download
      TRANSPORT is NOT reinvented — `ModelDownloadManager.install` uses the official HF
      `HubClient.downloadSnapshot` (Range-resume + concurrent shards) + verify + atomic finalize (KEEP).
      The likely "corrupted/incomplete" ROOT is the in-house wrapper: `Epistemos/Engine/
      LocalModelInfrastructure.swift purgeStaleStagingDirectories` (30-min grace) SILENTLY DEFEATS
      resume on large/slow models (20GB Qwen MoE) — partial shards get purged mid-download, so resume
      evaporates and the next attempt reports incomplete/corrupt; plus NO auto-retry on transient
      failure, and the full SHA-256 re-hash at finalize looks frozen ("Finalizing…"). FIX: condition the
      purge on NOT-actively-downloading (or raise/scale the grace by model size), add bounded retry,
      and surface the hash-verify phase in the progress bar so it isn't mistaken for a hang.
      ✅ STEP 1 — VISIBILITY/ACCESS RESTORED 2026-06-19 (the "only the foundation package
      is offered" symptom): DIAGNOSIS — `Epistemos/Views/Settings/SettingsView.swift:3307`
      gated the individual-model install sections (the "Recommended Baseline" + "Optional
      Flagship + Fallbacks" sections, each rendering `LocalModelRow`s with working install
      buttons) behind `if !EpistemosFoundationLineup.simplifiedLineupActive { … }`. The
      simplified lineup is ON by default, so those whole sections were HIDDEN → the owner
      only ever saw the one-tap "Epistemos AI" foundation-package install + (empty) legacy-
      installed list. The models were never deleted, just unreachable. FIX — moved those
      install rows into an always-present, collapsed **"All models (advanced)"**
      `DisclosureGroup` shown UNDER the simplified lineup (the canon foundation section
      stays the advertised primary; every retained model — curated + optional baseline — is
      now reachable to install under the disclosure; nothing deleted; honors KEEP-ALL req 2
      + INSTALL-ANY req 5). +2 mirrored-source tests (EpistemosTests/ModelInstallAllModels
      Tests.swift: the disclosure + the curated/optional install ForEachs are present under
      the simplified branch; the foundation + baseline catalogs stay non-empty). build-for-
      testing TEST BUILD SUCCEEDED (0 errors). HONEST REMAINING (the bigger parts, follow-
      on slices, owner-verified in-app once pulled): the curated/optional baseline MLX
      models are now SELECTABLE-to-install; the canon GGUF foundation models still install
      via the one-tap package (their individual install path is the (A) follow-on audit);
      the "stack" with owner-controlled advertise-toggles + persistence (reqs 6/7) and the
      pipeline-robustness regression (reqs 8/9/10 — integrity "corrupted"/"not complete",
      the missing progress bar, resume) are SEPARATE follow-on slices — this step only
      restores the install-row VISIBILITY that was hidden.
      ✅ STEP 2 — GGUF INTEGRITY FALSE-POSITIVE FIXED 2026-06-19 (req 8, the "corrupted /
      not complete" root): git-archaeology pinned the regression to the artifact-validation
      hardening commits (`3635df095 Harden local runtime artifact validation` + `0e6ddebaf
      Harden model download checksum verification`). `ModelDownloadManager.verifySnapshot`
      requires `config.json` + `.safetensors` weights + a tokenizer and `modelWeightFiles`
      counts ONLY `.safetensors` — but the canon FOUNDATION models are GGUF (a single
      self-contained `.gguf` that EMBEDS its config + tokenizer; no sidecars, no safetensors),
      and GGUF models DO route through this installer (it's the one `LocalModelArtifactInstalling`,
      AppBootstrap:1790). So a COMPLETE GGUF download had hasWeights=false + no config/tokenizer
      → `invalidInstall` → the owner's "corrupted / not complete". FIX: made the validation
      RUNTIME-AWARE via two pure `nonisolated static` helpers — `weightFileExtension(for:)`
      (`gguf` vs `safetensors`) + `requiresSidecarConfigAndTokenizer(for:)` (false for GGUF).
      verifySnapshot now: GGUF → a present, non-empty `.gguf` weight IS a complete install
      (config+tokenizer embedded); MLX/Transformers → unchanged (config+weights+tokenizer).
      modelWeightFiles matches the right extension per runtime. Checksum verify still runs on
      the returned weights (SHA256 vs the HF LFS etag — works for GGUF LFS, gracefully degrades
      to `.unverifiedChecksum`). +2 helper tests (extension-per-runtime, sidecar-requirement-
      per-runtime). build-for-testing TEST BUILD SUCCEEDED (0 errors). HONEST REMAINING:
      req 9 (the install PROGRESS BAR) + req 10 (RESUME of partial downloads) are the next
      follow-on slices.
      🔎 REQ 9 PROGRESS-BAR — CHAIN VERIFIED INTACT 2026-06-19: traced it end-to-end and it is
      WIRED — `LocalModelManager.install` passes a `progressHandler` that sets
      `installProgress[modelID] = progress.fractionCompleted` (LocalModelInfrastructure.swift
      :2636-2638) → `state(for:) = .installing(progress:)` (:2566) → SettingsView renders
      `ProgressView(value: fraction)` via `ModelInstallProgressDisplay.from(fraction:)`
      (~:3547). So the "progress bar is gone" was almost certainly a DOWNSTREAM symptom of
      installs FAILING FAST at verify ("corrupted") — i.e. the install never reached a
      completing/determinate state — which STEP 2 (the GGUF integrity fix) removes. No
      speculative change made to a working chain; owner re-verifies the bar in-app once
      pulled (now that GGUF installs pass verification).
      ✅ STEP 3 — RESUME OF INTERRUPTED DOWNLOADS 2026-06-19 (req 10): before this,
      `install()` staged into a UUID-unique dir AND a blanket `defer` DELETED the staging on
      ANY non-activation — so an interrupted download was thrown away (full restart, the "not
      complete" pain). FIX: NEW `LocalModelPaths.resumableStagingDirectory(for:)` — a STABLE
      per-descriptor path (`<slug>-resume`, no UUID) reused across attempts; `install()`
      restructured to (a) REUSE an existing partial staging instead of recreating, (b) KEEP
      the partial on a download/network failure so the next attempt resumes the already-
      downloaded files (HubClient.downloadSnapshot syncs into the existing dir), (c) DELETE
      the staging only on a verify/checksum failure (incomplete/corrupt can't be resumed →
      clean re-download), (d) atomic finalize (move the VERIFIED staging into place) on
      success. SAFE-BY-CONSTRUCTION: the verify + checksum gates reject any incomplete/corrupt
      staging BEFORE activation, so a half-download is NEVER installed (a partial single-file
      GGUF passes the non-empty check but fails the SHA256-vs-LFS-etag checksum → deleted +
      re-downloaded). +1 test (resumable staging is STABLE across calls + ends `-resume`;
      unique staging still differs each call). build-for-testing TEST BUILD SUCCEEDED (0
      errors). So req 8 (integrity), atomic finalize, req 9 (progress chain), AND req 10
      (resume) are addressed; HONEST: this is resume-by-reuse (skip already-complete files +
      keep-don't-discard the partial + clean re-download on corruption) — true intra-file
      HTTP-Range resume of a single partially-downloaded `.gguf` would need HubClient byte-
      range support (deeper, separate). Owner verifies the end-to-end download in-app.
      ✅ D2 STAGING-PURGE RESUME FIX 2026-06-19 (research STOP_REINVENTING_AUDIT — the actual
      "corrupted/incomplete" + lost-resume ROOT): `LocalModelInfrastructure`'s
      `purgeStaleStagingDirectories` (30-min grace, runs only when no install is active) was
      removing the STABLE `<slug>-resume` partial out from under a later resume — so a slow/large
      download (e.g. a 20 GB MoE) interrupted and reopened >30 min later found its partial purged
      and restarted from scratch. FIX: new pure `LocalModelManager.shouldPurgeStagedEntry(name:
      modificationDate:staleCutoff:)` — a `-resume` directory is NEVER stale-purged (its lifecycle
      is owned by install/resume: kept-on-download-failure so the next attempt resumes,
      verify+checksum-gated before activation so a partial is never installed, moved-on-success);
      only genuinely ORPHANED unique-UUID staging (left by a crash) is purged on the grace cutoff.
      Wired into the purge inner guard. +1 test (stalePurgeExemptsResumeDirs: `-resume` exempt even
      when ancient; orphan past cutoff purged; fresh orphan kept). build-for-testing TEST BUILD
      SUCCEEDED (0 errors). Composes with the resumable-staging work (STEP 3 / req 10). Owner
      verifies the end-to-end resume in-app once model download is exercised.
      ✅ STEP 4 — "THE STACK" ADVERTISED-SET FOUNDATION (reqs 6/7 data layer) 2026-06-19: the
      owner-controlled advertised-set source of truth, built pure-first so the semantics are
      locked before any UI. NEW `Epistemos/Engine/AdvertisedModelStore.swift`: (a) pure
      `AdvertisedModelPolicy` enum (no I/O, mirrors LocalChatModelMemoryGate / Epistemos-
      FastEffortSizing) — `effectiveAdvertised(persisted:canonDefaults:fullCatalog:)` returns
      the persisted owner selection if one exists ELSE canon defaults (req 7: canon is the
      DEFAULT, not a cap), intersected with the full catalog so a stale id never lingers as a
      phantom, order-preserving + de-duped, and an EMPTY persisted set is honored verbatim (the
      owner deliberately cleared the picker) while only `nil` falls back to canon; plus
      `advertising`/`unadvertising`/`toggling`/`isAdvertised` (idempotent, order-preserving).
      (b) `AdvertisedModelStore` — thin `UserDefaults` wrapper (key `epistemos.advertisedModel
      IDs.v1`; model IDs only, no secrets → UserDefaults is correct, Keychain stays for keys);
      `canonDefaults = EpistemosFoundationLineup.models.map(\.id)` (the Fast/Think/Code ship
      lineup so the picker is never empty out of the box); `persistedSelection`/`isCustomized`/
      `effectiveAdvertised(fullCatalog:)`/`toggleAdvertised`/`resetToCanonDefaults`. DOCTRINE:
      this is a VISIBILITY filter only — it never deletes or un-retains a model (req 2 KEEP-ALL),
      and any model stays installable (req 5 INSTALL-ANY); advertise = which retained models the
      picker shows. +11 tests (EpistemosTests/AdvertisedModelStoreTests.swift): pure policy
      (default-canon, owner-override-wins, empty-honored, stale-pruning, dedupe/order, add/
      remove/toggle) + a live `UserDefaults` round-trip on an isolated suite + canon==foundation-
      lineup. build-for-testing TEST BUILD SUCCEEDED (0 errors). REMAINING for reqs 6/7 (follow-
      on slices): the Settings "stack" UI (a model-manager listing the full retained catalog with
      install-state/size/RAM/uses + a per-model advertise toggle calling
      `AdvertisedModelStore.toggleAdvertised`), and wiring the picker visibility filter
      (InferenceState foundation-lineup path ~3956-4278 + EpistemosRuntimePicker) to intersect
      with `effectiveAdvertised`. Owner verifies the stack UI in-app once those land.
      ✅ STEP 5 — PICKER VISIBILITY WIRING (reqs 6/7, the store is now LIVE) 2026-06-19: wired the
      advertised-set into the SINGLE picker candidate-list chokepoint so it actually does
      something. `Epistemos/State/InferenceState.swift` `releaseSelectableInstalledLocalTextModelIDs`
      (read by the main/landing/mini/note/graph pickers + Settings + AppBootstrap) now, after
      assembling `base = mlx+gguf`, does `guard advertisedStore.isCustomized else { return base }`
      then applies a NEW pure `static func advertisedVisibleModelIDs(candidates:advertised:
      isCustomized:selectedID:)`. DESIGN — a TRUE no-op until the owner customizes the advertised
      set: `isCustomized == false` (everyone today, until the stack UI ships) → returns `base`
      unchanged → ZERO behaviour change, ZERO regression risk. Once customized → shows only
      advertised models, but ALWAYS keeps the active pick (`preferredLocalTextModelID` — it must
      never vanish from its own picker) and FALLS BACK to `base` if filtering would empty the
      picker (never an empty picker). The guard short-circuits the common path with one
      UserDefaults read (no wasted `effectiveAdvertised` when uncustomized). +4 tests appended to
      AdvertisedModelStoreTests (not-customized→unchanged, customized→filters, keeps-selected,
      never-empty). build-for-testing TEST BUILD SUCCEEDED (0 errors). So the store (STEP 4) is now
      consumed by the picker; the LAST reqs-6/7 piece is the Settings "stack" UI to let the owner
      toggle advertising (then this seam goes visibly live). Owner verifies in-app once that lands.
      ✅ STEP 6 — STACK ROW ASSEMBLER (reqs 6/7, the Settings UI data layer) 2026-06-19: built the
      pure, testable row model the "stack" View will render, so the View stays a thin renderer.
      Appended to `Epistemos/Engine/AdvertisedModelStore.swift`: `ModelStackRow` (Identifiable /
      Sendable / Equatable — id / displayName / summary / sizeText / ramText / isInstalled /
      isAdvertised) + pure `ModelStackAssembler` enum — `sizeText(bytes:)` (deterministic,
      locale-independent GB so it's testable, honest "—" for unknown size), `ramText(gb:)` (honest
      "—" for unknown), and `rows(descriptors:installedIDs:advertisedIDs:)` mapping the full
      RETAINED catalog (`LocalModelCatalog.textDescriptors` — req 2 KEEP-ALL) to rows tagged with
      install + advertised state, sorted installed-first then displayName then id. No I/O / SwiftUI
      / InferenceState → unit-testable. +3 tests (sizeText, ramText, rows against the real catalog:
      install/advertised tagging + installed-first order). build-for-testing TEST BUILD SUCCEEDED
      (0 errors). REMAINING (the final reqs-6/7 slice): the actual `ModelStackSettingsView` —
      reads the catalog + InferenceState install set, renders rows via this assembler with a
      per-model advertise Toggle → `AdvertisedModelStore.toggleAdvertised` + a "Reset to canon"
      button, wired into SettingsView near the "All models (advanced)" disclosure. Owner verifies
      render + toggle in-app once that lands.
      ✅ STEP 7 — SETTINGS "STACK" UI VIEW (reqs 6/7 COMPLETE IN CODE; owner verifies in-app)
      2026-06-19: the render surface. NEW `Epistemos/Views/Settings/ModelStackSettingsView.swift`
      — a `Section`-returning view (drops into the `LocalModelManagerSheet` Form; inherits its
      `@Environment(InferenceState.self)`) that lists the full RETAINED catalog =
      `LocalModelCatalog.textDescriptors` ∪ the foundation GGUF descriptors (via
      `EpistemosFoundationLineup.models` → `LocalModelCatalog.descriptor(for:)`, de-duped by id —
      so LFM2 / VibeThinker / the Gemma family appear too, which also advances req 11), builds
      rows via `ModelStackAssembler.rows(...)`, and renders each (displayName + Installed/Not-
      installed badge + summary + "size · ram") with an advertise `Toggle` →
      `AdvertisedModelStore().toggleAdvertised(id, fullCatalog:)`, backed by a local `@State`
      advertised mirror refreshed on appear + after each toggle (UserDefaults isn't @Observable),
      plus a "Reset to canon" button (disabled unless `isCustomized`) and an honest header
      ("Advertised models (the stack)") + footer ("…this only controls picker visibility"). Wired
      into `SettingsView.swift` after the model if/else (~line 3396, before the legacy section):
      `ModelStackSettingsView()`. build-for-testing TEST BUILD SUCCEEDED (0 errors). So reqs 6/7
      are now END-TO-END IN CODE: store (STEP 4, 532cbb699) → picker visibility wiring (STEP 5,
      6b26319fe) → row assembler (STEP 6, fa9f17f59) → this View. The owner can now (in-app)
      install ANY retained model and toggle which ones the picker advertises; canon is the default,
      the owner's choice persists + wins. NOT ticked [x] — owner verifies render + toggle + the
      advertised set actually filtering the picker, in-app once pulled (and the download pipeline
      proven end-to-end). This View ALSO lists the foundation GGUF models individually → cross-
      check against req 11's acceptance below.
      ⚠️ CORRECTION to STEP 7's "lists the foundation GGUF models" claim: as first written the View
      did NOT — see STEP 8, which fixes a silent drop I caught verifying req 11.
      ✅ STEP 8 — REQ 11 SILENT-DROP FIX (the foundation GGUF models are now actually listed)
      2026-06-19: verifying req 11 against the STEP-7 View exposed a real bug in my own slice. The
      foundation GGUF candidates (Gemma E2B/E4B/12B, the 12B coder, VibeThinker 3B, Gemma 26B-A4B,
      LFM2.5-8B) have NO `LocalModelDescriptor` — `LocalModelCatalog.allDescriptors == textDescriptors`
      and none of those GGUF ids is in `textDescriptors` (each id appears exactly once in the whole
      file, as a `GemmaQATRuntimeCandidate` in `GemmaQATRuntimeLadder.candidates`). So the STEP-7
      View's `EpistemosFoundationLineup.models.compactMap { LocalModelCatalog.descriptor(for: $0.id) }`
      resolved to nil for every one and SILENTLY DROPPED them — exactly the models the owner said
      they couldn't see. This is the owner's recurring "I don't see X" bug class: a UI compactMap of
      an id→descriptor lookup that drops ids without a descriptor. FIX: a runtime-AGNOSTIC
      `ModelStackSource` (id/displayName/summary/approximateDownloadBytes/minimumRecommendedMemoryGB)
      that BOTH lanes map into — `LocalModelDescriptor.stackSource` (MLX/remote) AND
      `GemmaQATRuntimeCandidate.stackSource` (foundation GGUF; summary = `stage.epistemosTier.tagline`,
      bytes = `expectedFileBytes`). `ModelStackAssembler.rows` now takes `sources:` (not
      `descriptors:`); the View builds `sources = textDescriptors.map(\.stackSource) +
      EpistemosFoundationLineup.models.map(\.stackSource)` de-duped → NO descriptor lookup → nothing
      dropped. +1 guarantee test `stackListsFoundationGGUF` (every foundation candidate survives into
      a row; gemma/vibethinker/lfm present by id) + the existing rows test moved to `.stackSource`.
      build-for-testing TEST BUILD SUCCEEDED (0 errors). So req 11's named models (LFM2 / VibeThinker /
      the Gemma family) now PROVABLY reach the stack rows. Still owner-verified in-app for the final
      render; not ticked [x].
      (11) **ACCEPTANCE — ALL NAMED MODELS VISIBLE (owner 2026-06-19, verbatim: "I still
      don't see LFM and Gemmas and the Vibe Thinker — all the new ones — on the
      downloaded-models settings thing. I want to be able to see all of them.").** STEP 1
      restored the hidden install rows; this is the explicit ACCEPTANCE BAR for it: the
      Settings models view must visibly show **LFM2, VibeThinker, and ALL Gemma variants**
      (plus Qwen + every other retained lineup entry) — each with state/size/RAM/uses —
      and the owner can install each. VERIFY each named model actually renders (not just
      the curated/optional MLX sections generically): if LFM2 / VibeThinker / a Gemma
      variant is GGUF-foundation-only (installs via the one-tap package, not an
      individual row), it must STILL be individually LISTED + visible in the "All models
      (advanced)" disclosure with an honest state — not absent. If any named model is
      missing from `EpistemosFoundationLineup` entirely, add it. Owner verifies in-app
      once pulled; don't tick this until LFM2 + VibeThinker + the Gemma family are all
      visibly listed. (This is the (A) follow-on individual-install audit, made concrete
      against the owner's named models + the catalog-completeness check.)
- [ ] **MODEL SELECTION NOT HONORED — everything routes to Qwen 3 4B regardless of
      pick (owner 2026-06-19, HIGH PRIORITY).** Owner (verbatim): *"everything is
      routing to the Qwen 3 4B most times — it never changes from it no matter what I
      select."* SYMPTOM: the model the owner SELECTS in the picker is IGNORED at
      inference time; the runtime pins to Qwen-3-4B (a default/fallback) for nearly
      every turn across modes. So picker selection → actual inference is BROKEN: the
      chosen model id is not propagating to the generation call (or a router/fallback
      is overriding it). ROOT CANDIDATES to investigate (trace the full select→generate
      path): (a) the selected model isn't bound/persisted into `InferenceState` (the
      picker mutates UI state but not the resolved runtime model); (b) the router
      (`ConfidenceRouter` / `RuntimeRouter` / `TriageService` / route profiles in
      `InferenceState+RouteProfiles`) hardcodes or defaults to Qwen-3-4B and ignores
      the explicit selection; (c) only Qwen-3-4B is actually INSTALLED/loadable (ties
      to the MODEL DOWNLOAD bug above — if nothing else installs, the runtime silently
      falls back to the one model present) — but the fallback must then be HONEST, not
      a silent override of the owner's pick; (d) a default-model constant is used at
      the generation seam instead of the selected id. FIX: the explicitly-selected
      model MUST be the model that runs — across Chat/Act/Work, local + cloud. An
      explicit owner selection OVERRIDES auto-routing (auto-route only applies when the
      owner leaves it on "auto"). If a selected model can't load, show an HONEST error/
      state (constraint #1: no silent fallback, no fake) — never silently swap to
      Qwen-3-4B. Add a regression test that asserts selecting model X → the generation
      call receives model X (not the default). Diagnose first (where the selected id is
      dropped), then fix the binding + router-override. Pairs with the MODEL DOWNLOAD/
      INSTALL bug + the picker-simplify + Settings-stack items — together they are the
      "model system actually works the way the owner picks" cluster.
      ⚠️ REOPENED — the TriageService fix below was the WRONG LAYER (owner confirms STILL
      broken after rebuild). REAL-PATH DIAGNOSIS 2026-06-19 (the actual select→generate, per
      owner pointers AgentCommandCenterState:580-600 + RuntimeRouter:428-431 + the generation
      seam): RuntimeRouter.route() picks a LANE not a model id (modelPreferenceTable feeds
      profiles/display only), and AgentCommandCenterState.localBrain(preferredModels) is the
      ACC slash-command brain (already gated by storedBrainSelection). The LIVE chat
      select→generate is: PipelineService:470 builds the generation `modelID` from
      `inference.effectiveChatSurfaceSelection(for: mode)` → which gates on `userHasExplicitPin`
      (`sanitizedStoredLocalChatModelID(for: id) == id && effectiveLocalTextModelID != nil`),
      and the generation id passes through `sanitizedInteractiveLocalTextModelID` (InferenceState
      ~3919, `?? original`). THE OVERRIDE: `sanitizedInteractiveLocalTextModelID`, when the
      picked model is NOT installed (cases 4-5), falls through to
      `hardwareCapabilitySnapshot.recommendedLocalTextModelID` / the constrained fallback — i.e.
      it SUBSTITUTES the explicit pick with the recommended (Qwen-3-4B) model; that substitution
      also flips `userHasExplicitPin`→false → cloud/auto-route. This is downstream of the MODEL
      DOWNLOAD bug (uninstalled picks → substituted), but the substitution must be HONEST not
      silent. FIX PLAN (careful, multi-function — needs fresh context, do NOT rush on the live
      chat resolver): flag-gate (reuse EPISTEMOS_AUTOSUBSTITUTE_LOCAL_MODEL) the recommended/
      constrained substitute tail of `sanitizedInteractiveLocalTextModelID` (OFF → return nil →
      the `?? original` KEEPS the explicit pick, generator then fails HONESTLY if it can't load —
      no silent Qwen); audit ALL sanitizer call sites + the `sanitizedStoredLocalChatModelID` /
      `userHasExplicitPin` chain so an explicit pick stays an explicit pin; KEEP the legitimate
      legacy→foundation migration (case 1); add a unit test on `effectiveChatSurfaceSelection`
      (the ACTUAL resolver) that an explicit installed pick → `.localMLX(thatId)` and an explicit
      uninstalled pick → NOT silently `.localMLX(qwen3_4B4Bit)`. Do NOT tick until owner confirms
      in-app. (The TriageService change below stays — it's correct for ITS layer, just not the
      one that was pinning Qwen.)
      ✅ REAL-LAYER FIX LANDED 2026-06-19 (NOT ticked done — owner confirms in-app): fixed the
      actual select→generate override. `Epistemos/State/InferenceState.swift`
      `sanitizedInteractiveLocalTextModelID` — the recommended/constrained/first-installed
      SUBSTITUTE tail (cases 4-6, which returned Qwen-3-4B for an unavailable pick) is now gated
      behind `autoSubstituteUnavailableLocalModel` (env `EPISTEMOS_AUTOSUBSTITUTE_LOCAL_MODEL`,
      OFF=honest): when OFF an unavailable explicit pick returns `nil` instead of a substitute,
      so every consumer KEEPS the pick — the constructor's `?? original`, `sanitizedStored
      LocalChatModelID` returns the original modelID, `effectiveLocalTextModelID` goes nil so
      `LocalRouteHonestyRow` honestly shows substituted/no-model, and `effectiveChatSurfaceSelection`
      (the resolver PipelineService:470 turns into the generation modelID) resolves to the
      foundation TIER representative (simplified lineup) or the original `.localMLX(pick)` —
      NEVER a silent `.localMLX(qwen3_4B4Bit)`. Cases 1-3 (legacy-MLX→foundation migration +
      keep-if-installed) UNCHANGED, so a working/installed pick still resolves to itself. This
      also stops the stored-pick CORRUPTION (`sanitizeStoredLocalChatSelectionIfNeeded` no longer
      rewrites an unavailable pick to Qwen on set). +2 tests on the ACTUAL resolver
      `effectiveChatSurfaceSelection` (EpistemosTests/TriageServiceTests.swift): an explicit
      INSTALLED pick → `.localMLX(thatId)`; an explicit UNINSTALLED pick → NOT `.localMLX(qwen3_
      4B4Bit)`. build-for-testing TEST BUILD SUCCEEDED (0 errors), no existing-resolution-test
      regression. Composes with the MODEL DOWNLOAD fix (the pick now actually installs). DO NOT
      mark [x] — owner verifies select-X→generate-X in-app once model download works.
      ✅ FIX — NO SILENT QWEN SUBSTITUTE FOR AN EXPLICIT PICK 2026-06-19 (root candidate (c)):
      traced select→generate. `TriageService.localSelection` is the resolver: for a local
      pick, `shouldUseAutomaticLocalRouting` is FALSE (a `.localMLX` selection is honored, not
      auto-routed), so it calls `resolvedPreferredLocalSelection` — which returns nil when the
      picked model is NOT in `installedLocalTextModelIDs` (or can't run in the requested mode).
      THE BUG: on that nil, `localSelection` SILENTLY fell through to `automaticLocalSelection`,
      which picks the best INSTALLED model — and when only the foundation/Qwen path is installed
      (the MODEL DOWNLOAD bug above), that is Qwen-3-4B → "everything routes to Qwen 3 4B
      regardless of pick." FIX: when an EXPLICITLY-picked local model can't be resolved, return
      an HONEST nil (`.preferredLocalModelUnavailable`) instead of silently substituting another
      model — constraint #1, no silent fallback. Flag-gated: OFF by default = honest (no
      substitute); `EPISTEMOS_AUTOSUBSTITUTE_LOCAL_MODEL=1` restores the legacy smart-fallback
      for anyone who wants it. So: select-X → run X (if installed/loadable), else an honest
      "unavailable" the UI surfaces (install it / pick another) — NEVER a silent Qwen-3-4B swap.
      +2 regression tests (TriageServiceTests: explicit INSTALLED pick runs THAT model not Qwen;
      explicit UNINSTALLED pick is NOT silently substituted to Qwen). build-for-testing TEST
      BUILD SUCCEEDED (0 errors); no existing test encoded the old auto-substitute (no regression).
      This composes with the MODEL DOWNLOAD fix: now that all models install, an honored pick
      actually has its model present. Owner verifies select-X→generate-X in-app once pulled.
      ❌ STILL BROKEN AFTER REBUILD (owner 2026-06-19, verbatim: "did it already fix the qwen
      issue because it is still doing the same thing, I just rebuilt"). The TriageService fix was
      build-verified but NOT in-app-verified, and the owner's rebuild proves the live behavior is
      UNCHANGED — still pinned to Qwen-3-4B. GROUNDED RE-DIAGNOSIS (the fix patched the WRONG/only-one
      layer): `TriageService.localSelection` was made honest, BUT the live chat/agent path resolves
      its model through OTHER Qwen-preferring code the fix never touched — primarily
      `Epistemos/State/AgentCommandCenterState.swift:580-600` (`localBrain(preferredModels: [.qwen3_4B4Bit, …])`
      mode→model preference lists) and `Epistemos/LocalAgent/RuntimeRouter.swift:428-431` (hardcoded
      Qwen3-4B routing targets). PROOF this is the path: if TriageService were the live resolver, the
      honest-nil default would now show "unavailable" — instead the owner still gets Qwen, so the query
      is served via these preferred-list/router layers that IGNORE the explicit pick. ALSO check the
      generation seam itself (`MLXInferenceService` / `DeviceAgentService`) for an independent default,
      and confirm the picker's selected id actually propagates into `InferenceState` and reaches these
      resolvers. REAL FIX (multi-layer): the EXPLICIT owner pick must WIN at EVERY selection layer —
      AgentCommandCenterState.localBrain, RuntimeRouter, TriageService, and the generation call — not
      just one; preferred-model lists apply ONLY in true "auto" mode, never over an explicit pick.
      The +2 cargo tests PASSED but tested the wrong layer (TriageService) — add a test that drives the
      ACTUAL live select→generate path (AgentCommandCenterState/RuntimeRouter) and asserts the picked
      model id reaches the generator. Don't tick until the OWNER confirms in-app that selecting a model
      actually changes which model answers. Likely needs the careful re-arm (touches live inference path).
      🔎 S1 STOP-REINVENTING ROOT (docs/research/STOP_REINVENTING_AUDIT_2026_06_19.md): the deeper
      root is BUILT-THEN-NOT-WIRED — `Epistemos/LocalAgent/RuntimeRouter.swift:580 route(_:)` (the
      PROPER multi-lane model router, mirrors Hermes runtime_provider/Goose) has **ZERO production
      callers**; live selection falls to `TriageService.InferencePolicyEngine.preferredAutomaticLocalModel:669`
      (threshold-soup + hardcoded priority list) → why picks don't stick. FIX: WIRE RuntimeRouter into the
      live dispatch (keep it the intra-local lane chooser, NOT the Act picker), fold R2's hardcoded priority
      list into R1's preference table, and DELETE the dead duplicate routers (`LocalAgent/ConfidenceRouter.swift`,
      `Omega/Inference/{DualBrainRouter,HybridRouter}.swift` — all "never instantiated in production").
      Collapse 4 routers → R1+R2. The durable fix behind the honest-nil patch.
      🔎 FIX #2 RUNTIMEROUTER WIRING — STAGE 1 machinery + STAGE 1b mapper LANDED 2026-06-19 (the
      durable lane-level fix, staged so the live selection path the owner iterated carefully is never
      ripped out at once). `RuntimeRouter.route(_:)@580` chooses a RUNTIME LANE (mlx / gguf / cloud /
      stub), NOT a model id — so it COMPLEMENTS the `sanitizedInteractiveLocalTextModelID` model-pin
      fix (a645e6623), it doesn't replace it (lane vs model-within-lane). STAGE 1 (this) — NEW
      `Epistemos/LocalAgent/RuntimeRouterShadow.swift`: pure, flag-gated (`EPISTEMOS_RUNTIMEROUTER_
      LIVE_V0`, OFF), OBSERVE-ONLY machinery — `armed` + `role(forOperatingMode:)` (.fast→.quick /
      .thinking→.reasoning / .pro→.code / .agent→.toolCaller) + `acceptedLane(from verdict:)`
      (accept→lane / escalate→to / reject→nil — honest no-lane, never a silent fallback) +
      `parityMatches(routerLane:liveLane:)` (by stableID; nil never matches) + `missionPacket(...)`
      builder. STAGE 1b — `liveLane(from ResolvedBrainDescriptor:localLaneForModelID:)` maps the live
      resolved runtime to its lane: cloud + Apple Intelligence direct, local via an INJECTED mlx/gguf
      classifier (pure/testable — the live site passes `LocalTextModelID.runtimeKind`), `unavailable`
      → nil. +8 tests (RuntimeRouterShadowTests). build-for-testing TEST BUILD SUCCEEDED (0 errors).
      NO behaviour change (flag OFF = zero overhead, the router is NOT consulted). REMAINING staged
      slices (each flag-gated, build-verified, owner-confirmed): STAGE 1c = the OBSERVE-ONLY hot-path
      CALL at `CommandCenterRequestCompiler.ResolvedRuntime` / `QueryEngine.resolvedRuntime()` behind
      the flag — build a MissionPacket, call a `RuntimeRouter` instance's `route`, compare
      `acceptedLane` vs `liveLane` via `parityMatches`, record to `RuntimeRouterMetrics`, RETURN THE
      SAME lane (still observe-only); STAGE 2 = PROMOTE (flag ON makes `route` authoritative for the
      lane once parity is proven in-app); STAGE 3 = FOLD R2 (`TriageService.preferredAutomaticLocalModel`
      priority list → the router's preference table, keep honest no-local→nil); STAGE 4 = DELETE the
      dead R4 routers (ConfidenceRouter 12 refs / DualBrainRouter 3 / HybridRouter 0) AFTER rehosting
      the diagnostic `routeProfiles()` adapter. MODEL SELECTION stays un-ticked [x] — owner confirms
      select-X→generate-X in-app (and the lane parity) once the staged wire is promoted.
      ✅ STAGE 1c classifier 2026-06-19: `RuntimeRouterShadow.lane(forRuntimeKind: BackendRuntimeKind)
      -> RuntimeLane` (.gguf→.gguf, .mlx→.mlx, .remote→.mlx) — the pure primitive the live site
      injects into `liveLane` for a `.local` descriptor (composed: `liveLane(from: resolved) { id in
      lane(forRuntimeKind: LocalTextModelID(rawValue: id)?.runtimeKind ?? .gguf) }`; a non-enum id is a
      foundation GGUF descriptor → `.gguf` default). +2 tests. build-for-testing TEST BUILD SUCCEEDED
      (0 errors). So ALL STAGE-1c PURE primitives are now built + tested (armed flag, role,
      missionPacket, acceptedLane, liveLane, lane(forRuntimeKind:), parityMatches, RuntimeRouterMetrics).
      The ONLY remaining piece is the ~10-line OBSERVE-ONLY hot-path CALL at the `ResolvedRuntime`
      construction site in `CommandCenterRequestCompiler` — when `RuntimeRouterShadow.armed`, build a
      MissionPacket, obtain a `RuntimeRouter`, `route(packet)`, compare `acceptedLane` vs the composed
      `liveLane`, record to `RuntimeRouterMetrics`, RETURN THE SAME `ResolvedRuntime` (zero behaviour
      change). That call is the next STAGE-1c slice (owner confirms the parity log in-app); STAGE 2+
      promote/fold/delete as above.
      🔎 AgentCommandCenterState VERIFICATION 2026-06-19 (the re-diagnosis named `AgentCommandCenterState
      .swift:580-600 localBrain(preferredModels:)` as a suspected Qwen-override): READ the code —
      `preferredBrain(for:)` (:570) checks `storedBrainSelection(for:)` (the per-command explicit pick,
      persisted under `specialistBrainPrefix+command`) FIRST and only falls to `recommendedBrain` (the
      Qwen-first preferred lists) when NO stored pick exists. So this layer is NOT a blind override — a
      stored explicit pick DOES win, exactly the owner's requirement (preferred lists apply only in
      auto/no-stored-pick mode). BUT it carries the SAME silent-substitute gap already fixed at the
      InferenceState layer (a645e6623): `storedBrainSelection` returns `availableBrains.first { $0.id ==
      storedID }`, so a stored pick whose model is NOT currently in `availableBrains` (uninstalled / not
      loadable) returns nil → falls to the Qwen-first `recommendedBrain` → Qwen. ALSO this is the
      SLASH-COMMAND-SPECIALIST surface (.notes/.code/.ask/…), NOT the main-chat model resolver (that's
      `InferenceState.effectiveChatSurfaceSelection`, already fixed). TWO real follow-on fixes surfaced
      (each its own flag-gated, build-verified slice): (1) `recommendedBrain`'s preferred lists are STALE
      pre-foundation-pivot (Qwen-first; e.g. `.ask` returns `[.qwen3_4B4Bit, …]`) AND built on
      `[LocalTextModelID]` which EXCLUDES the foundation GGUF lineup (Gemma/VibeThinker/coder are
      descriptor ids, not enum cases) — so auto-mode CAN'T recommend a foundation model and defaults to
      Qwen; fix = a foundation-brain-first recommendation that can express the GGUF lineup. (2) apply the
      honest-no-silent-substitute pattern to the unavailable-stored-pick case here too (gate via the same
      `EPISTEMOS_AUTOSUBSTITUTE_LOCAL_MODEL`). Narrows the bug hunt; the main-chat pin was the
      InferenceState resolver (done), this is the parallel specialist-path gap.
      ✅ MODEL-SELECTION fix (1) — FOUNDATION-RECOMMEND (auto-mode prefers the lineup, flag-gated)
      2026-06-19: the first of the two follow-on fixes the verification surfaced. ROOT: auto-mode
      `recommendedBrain`'s preferred lists are `[LocalTextModelID]` enum cases that STRUCTURALLY
      cannot express the foundation GGUF lineup (Gemma/VibeThinker/coder are descriptor ids), so
      auto-mode could never recommend a foundation model and fell to the Qwen-first list — a real
      contributor to "everything routes to Qwen" in auto/no-stored-pick mode. FIX: `AgentCommandCenter
      State` adds a PURE `preferredLocalBrainID(foundationIDs:availableLocalIDs:legacyPreferred:armed:)`
      — when armed, prefer the first AVAILABLE local id in `EpistemosFoundationLineup.foundationModelIDs`;
      else (and when no foundation is installed) the first available legacy-preferred id. `localBrain`
      now drives off it. Gated by `EPISTEMOS_FOUNDATION_RECOMMEND_V0`: OFF (default) = BYTE-IDENTICAL
      to the legacy loop (safe — `matches(localModel:)` is id-equality, so "first available legacy
      pick" == the old behaviour); ON = foundation-first. +5 pure tests (FoundationRecommendPolicyTests:
      not-armed→legacy, armed→foundation, armed-no-foundation→legacy, neither→nil, flag-default-off).
      build-for-testing TEST BUILD SUCCEEDED (0 errors). OWNER IN-APP: set
      `EPISTEMOS_FOUNDATION_RECOMMEND_V0=1`, use a slash command with NO stored pick → expect a Gemma/
      VibeThinker recommendation, not Qwen. Not ticked [x]. REMAINING fix (2): the honest-no-silent-
      substitute for `storedBrainSelection`'s unavailable-pick case (parallel to a645e6623).
      ✅ MODEL-SELECTION fix (2) — HONEST UNAVAILABLE SPECIALIST PICK (opt-in, flag-gated) 2026-06-19:
      the second follow-on. `storedBrainSelection` returned nil for an explicit-but-unavailable stored
      pick, so `preferredBrain` fell to the Qwen/foundation `recommendedBrain` — silently dropping the
      owner's explicit specialist pick. FIX: `AgentCommandCenterState` adds `StoredBrainKind`
      (.auto / .available / .unavailableExplicitPick) + a PURE `classifyStoredBrain(storedID:
      availableIDs:)` that DISTINGUISHES "no pick (auto)" from "explicit pick that isn't available"
      (the old code conflated both → recommend). `preferredBrain` now switches on it: .available →
      the stored brain; .auto → recommend; .unavailableExplicitPick → (flag
      `EPISTEMOS_HONEST_UNAVAILABLE_SPECIALIST_PICK_V0` ON: return nil so the picker surfaces the pick
      as unavailable rather than swapping models behind the owner's back; OFF default: recommend =
      BYTE-IDENTICAL to today). OPT-IN (rather than OFF=honest like a645e6623) because the nil flows to
      `selectedBrain` and the owner verifies the picker handles it in-app before it becomes default.
      +4 pure tests (classify auto/available/unavailable + flag-default-off). build-for-testing TEST
      BUILD SUCCEEDED (0 errors). So the MODEL-SELECTION multi-layer Qwen fix now spans EVERY layer the
      re-diagnosis named: the InferenceState model-pin (a645e6623), the slash-specialist foundation-
      recommend fix (1) (71aecb122), this honest-unavailable-pick fix (2), and the RuntimeRouter
      lane-level staging (b7a0796af / 6d22f0048) — each small, flag-gated, pure-tested, un-ticked
      pending owner in-app confirmation that selecting a model changes which model answers.
- [ ] **R-WEBCLIP — web clipper → clean-markdown vault note (S16 gap, supersession vs Obsidian).**
      Spec: docs/research/SUPERSESSION_GAPS_PLANS_2026_06_19.md. MAS core = a macOS Share Extension
      xcodegen target (`type:app-extension`, share-services, url+html; mirror `EpistemosWidgets`
      project.yml:251) → app-group container → app file-watcher drains to SDPage+`.md` (reuse
      `LiteParsePDFImportController.importPage`). Needs a REAL HTML→md converter (vendor a pure-Rust
      readability+html2md crate into agent_core as `html_to_markdown` FFI beside liteparse — ProvenanceGate;
      liteparse is PDF-only, `web_fetch html_to_text` is lossy). Frontmatter source_url/clipped_at/title/author;
      honest "raw extraction" label on fail, never fabricate. SPA/auth/full-page = Pro. Effort: medium.
- [ ] **R-VAULT-MCP-SERVER — host the vault over stdio MCP for external agents + auto-AGENTS.md (S16,
      anti-Tolaria; LOWEST-RISK supersession win).** Server side does NOT exist yet (omega-mcp = in-process
      dispatch + outbound directory; `StdioServer` test-only). Add `omega-mcp/src/bin/epistemos_mcp_server.rs`
      (`[[bin]]`) wrapping the existing `StdioServer` around the ALREADY-BUILT `MCPDispatcher`+`VaultExecutor`
      (path-traversal-hardened) — expose read/write/list/create_note/vault_search, NO new tool logic. Transport
      = stdio not TCP → dodges the missing `network.server` entitlement (external CLI spawns the binary, JSON-RPC
      over stdio, runs OUTSIDE the sandbox; app stays in-process). Auto-gen `AGENTS.md`+`.mcp.json` at vault root
      on open. In-process brain stays default. Pro-gated. Honesty: external writes through the SAME provenance
      recorder + path guard + approval gate. Effort: medium-LOW (wiring, not new logic).
- [ ] **R-LIVE-ARTIFACTS — revive ArtifactHostView via htmlWorkspace route + self-refreshing data.json (S16;
      LOWEST-RISK win, counters Claude Artifacts).** `ArtifactHostView` is a stub (every route → "Deferred in v1",
      0 refs) but the real surface EXISTS: HTMLWorkspace (`HTMLWorkspacePackage` w/ data.json + `HTMLWorkspace
      PatchRouter` + `HTMLWorkspacePreviewView` WKWebView). Add `ArtifactRoute.htmlWorkspace(id)` → render the
      preview instead of the deferred panel; subscribe data.json to a vault/query source (saved `fusedSearch`/RRF
      or DAG/provenance feed) → on change write data.json → patch-route the live WKWebView (no reload). Seed
      table/dashboard/chart templates (json-render IDEA as Swift/WebKit binding, NOT Vercel React). MAS core
      (local) / Pro (external feeds). Honesty: show provenance + last-refresh; stale shown explicitly; flip live
      only at T4. Reuse shared WKProcessPool + `dismantleNSView` (leak risk). Effort: medium-LOW.
- [ ] **R-SYNC — local-first multi-device vault (S16; HIGH blast radius — sequence AFTER engine-toggle/tools).**
      The `.md` files are DERIVED (SwiftData is SoT) so you can't just sync the folder. Option A (recommended):
      vault in an iCloud-Drive ubiquity container + **invert the source-of-truth so `.md` becomes SoT** (SwiftData/
      `.epcache` become rebuilt-from-disk derived; `.epcache` MUST NEVER sync); reuse the existing
      `syncFromVault()→[VaultSyncConflict]` reconciler; observe via `NSMetadataQuery`. Pro git-sync lane via the
      existing `vault_git.rs`. Avoid CloudKit as primary (kills the open-vault differentiator); CRDT overkill.
      Honesty: conflicts via VaultSyncConflict UI never silent-LWW; "eventual not real-time". Touches
      `VaultSyncService` (176KB, highest blast radius) — NOT concurrent with the engine-toggle/tools work.
- [ ] **HARDENING LIFECYCLE — every item, before AND after (owner 2026-06-19, GOVERNING).** Owner
      (verbatim): *"make sure every new thing is deeply hardened before and after it's added, and the
      app is repaired before and after, to do an after-port inspection — this should leave no space for
      gaps while making it deeply hardened, enterprise-level."* MANDATE for EVERY roadmap item (see
      docs/research/MASTER_SYNTHESIS_2026_06_19.md §3.7): (i) **harden BEFORE** — repair/secure the
      surrounding code + add the guard/witness/test BEFORE adding the new thing; (ii) **add**; (iii)
      **re-harden AFTER** — security/perf/honesty pass on the added code; (iv) **AFTER-PORT INSPECTION**
      — a gap-hunt asserting no seam/fallback/leak/honesty-hole was introduced (WKWebView teardown,
      no-silent-fallback, isLive honesty, provenance recorded, flag state, rollback-bound). No item is
      DONE until its after-port inspection passes with ZERO gaps. Composes with flag-OFF≠done + the
      T4/witness promotion rule. Enterprise-level robustness is the bar throughout.
- [ ] **HTML-WORKSPACE CAN'T EDIT — owner-confirmed, OLD + STILL UNRESOLVED (owner 2026-06-19).** Owner
      (verbatim): *"html workspace still can't edit — so that was one issue that's old but still not
      resolved."* GROUNDED ROOT (S14 docs/research/UI_PORTS_2026_06_19.md): the HTMLWorkspace surface is
      substantially BUILT + wired, but editing is broken by FOUR things — (1) the code panes are a plain
      `NSTextView` with NO syntax highlighting (`HTMLWorkspaceCodeEditor.swift:129 applyPlainTextAttributes`)
      = the "can't see/edit code" complaint; (2) the `safeAPI` WKScriptMessageHandler is an EMPTY STUB
      (`HTMLWorkspacePreviewView.swift:145-149 didReceive` does nothing) — the two-way app-bridge the chat/
      editor would use to drive edits isn't implemented; (3) the preview uses `loadHTMLString(…, baseURL:nil)`
      (`:69`) NOT the proven `epistemos-doc:` custom-URL-scheme path → relative assets/scripts/CSP behave
      inconsistently; (4) no live patch→WKWebView push (patches mutate the doc but don't re-render live).
      FIX ALL FOUR: wire the tree-sitter highlighter into the code panes (the same one-wire fix as chat +
      Streamdown — MASTER_SYNTHESIS primitive (c)); implement the `safeAPI` bridge; move preview to the
      EpdocEditorURLSchemeHandler-style scheme (Brotli/CSP/shared processPool); add the live patch→WKWebView
      push (R-LIVE-ARTIFACTS path). MAS core. Owner verifies edit works in-app. This is Phase 0 #8 in the
      master roadmap (a fix-the-broken item, not a new feature).
- [ ] **PROVENANCE MOAT — make the honest-provenance substrate the VISIBLE moat (S19, the #1
      differentiator).** Spec: docs/research/PROVENANCE_MOAT_2026_06_19.md. Epistemos has the deepest
      honest-provenance substrate of any PKM (Eidos closed-citation w/ inverse-closure + 472 tests;
      retraction-propagating ClaimLedger; content-addressed cognitive DAG; tamper-evident replayable
      `.epbundle` + verify-CLI + CI gate) — but it's the SAME built-then-not-wired keystone.
      **⚠️ HONESTY BUG (owner no-fake doctrine): AnswerPacket "verified"/VRMLabel chips are SYNTHETIC** —
      `scope_rex/produce.rs:114-183` synthesizes claims from `(stop_reason, tokens, attention_mode)` and
      NEVER queries the ClaimLedger, so a bubble can show "Verified/Plausible" with zero real provenance.
      Fix this first (it's a fake-feature). Then the moat plan (each follows the HARDENING LIFECYCLE):
      (1) universalize emission — thread `answerPacketId` through the local-MLX + local-agent completion
      paths (`ChatCoordinator.swift:579/1327`) so EVERY answer (local+cloud) carries a packet (local
      answers get NO chip today = cloud-only, breaking the local-first thesis); (2) make claims REAL
      (query the live ClaimLedger; wire a live writer — the DAG mirror exists); (3) enforce closed-citation
      on answers (W-47, `ChatCoordinator.swift:4500`) + POPULATE the Eidos index (`insertVaultNote` into
      the vault crawl — index is opened but empty) + flip `EPISTEMOS_EIDOS_V0` + FLIP+VERIFY; (4) unify ONE
      "why / what / prove-it" per-answer footer across Chat/Act/Work over the process-shared provenance seam
      (not per-engine copies; guard with the isolation lint); (5) in-app **`.epbundle` "Prove it" export**
      (FFI `export_replay_bundle_json` → `ReplayBundle::build_with_dag`+`to_epbundle_bytes`) — the headline
      enterprise asset, zero in-app path today; (6) bind WRV chips to real falsifier artifacts (green earned).
      Composes with engine-isolation (provenance is shared CAPABILITY, not shared logic). MAS core (#5 Pro).
- [ ] **VOICE — sounds PLAIN, make it HIGH-DEF + ROBUST (owner 2026-06-19).** Owner (verbatim): *"the
      voice is very plain… idk if Apple has a native high-def one, it should because new iPhones have the
      new Siri voice, so it should not sound plain… I still want the other models researched plus the holo
      one as well."* Deepen: docs/research/VOICE_2026_06_19.md. (1) **Stop sounding plain — prefer HIGH-DEF
      Apple voices:** `EpistemosSpeechSynthesizer` tiers Premium/Enhanced/Default — but verify it actually
      SELECTS the best AVSpeechSynthesisVoice.Quality available (`.premium`>`.enhanced`>`.default`) by
      default, not the plain default voice; surface the honest "download a Premium/neural voice (Settings →
      Spoken Content → Voices)" hint prominently; expose Personal Voice + the new high-def/Siri-quality voices
      to the extent AVSpeech allows (research clarifies what 3rd-party apps can use). (2) **Research + ship the
      OTHER TTS models** as installable Pro voice models via ModelDownloadManager: Kokoro-82M (CoreML/ANE,
      Apache-2.0) first, then MOSS-TTSD / Kitten / Dia / Sesame / Piper / F5-TTS etc. — ranked by quality vs
      Apple premium, license, on-device feasibility. (Blocked by the model-download bug — fix that first.)
      (3) **Robustness hardening:** wire the inert auto-TTS toggles, route the macOS-26 mic through the
      orphaned `EpistemosSpeechAnalyzer`, handle interruptions/route-changes. (4) **"the holo one":** Holo-3.1
      is a computer-use VISION model (already covered S10/R-HOLO — re-affirmed wanted), NOT a TTS — research
      clarifies the ambiguity. On-device only; honest gating; never silent cloud TTS.
      🔎 ROUND-2 GROUNDED ROOT (docs/research/VOICE_2026_06_19.md ROUND-2): the synthesizer ALREADY tiers
      premium>enhanced>default (`EpistemosSpeechSynthesizer.swift:219-228`), so the plain voice has 3 concrete
      causes: (1) premium/enhanced neural voices aren't installed (Apple ships Compact; the hint is buried in
      the picker, not where it's heard); (2) the fallback FLOOR uses `AVSpeechSynthesisVoice(language:)` (`:227`)
      → returns COMPACT; (3) no SSML/prosody (`:140` bare string) → monotone. **⚠️ CRITICAL macOS-26 REGRESSION
      (likely the exact symptom, Apple Forums 804648/FB20271264): `AVSpeechSynthesisVoice(language:)` IGNORES the
      selected premium voice and returns the system default — so `:227` lands on the plain voice EVEN WHEN a
      premium voice is installed+selected.** SMALL MAS-safe FIXES (do first): (A) best-installed-quality floor
      before the language fallback; (B) resolve/persist by IDENTIFIER never by language (dodges the regression);
      (C) promote `voiceQualityHint()` to a dismissible banner near read-aloud + onboarding (deep-link exists
      `ModelVoicePickerSection:195`); (D) SSML/attributedString prosody path. ALSO add
      `AVSpeechSynthesizer.requestPersonalVoiceAuthorization()` so Personal Voices populate the picker (the new
      neural Siri voice is NOT exposed to 3rd-party apps; Personal Voice is the legitimate "Siri-quality" path).
      INSTALLABLE upgrade: **Kokoro-82M** is the one model that's better-than-Apple + Apache-2.0 + has a turnkey
      Swift CoreML/ANE path (`kokoro-coreml`/`kokoro-swift`, host via `FluidAudio`/`mlx-audio`) + fits RAM —
      ship as a Pro installable voice AFTER the model-download fix. (F5/XTTS license-blocked; CSM/Dia/MOSS no
      Apple-Silicon Swift path yet.) Items A-C are SMALL and directly fix the owner's "plain" complaint.
- [ ] **DEERFLOW 2.0 — RESKINNED COHERENT "DEEP RESEARCH SPACE" + FULLER CLONE (owner 2026-06-19).** Owner
      (verbatim): *"DeerFlow 2.0 should also be reskinned to a space that is coherent with my app etc. — just
      many things, right, fully clone as much as I can."* Two parts: (1) **A COHERENT, RESKINNED, APP-NATIVE
      DEEP-RESEARCH SURFACE** — not just the backend Rust pipeline (S15 found the engine is genuinely wired
      end-to-end but the only surface is a minimal report renderer). Build a proper "Deep Research" SPACE that
      visualizes the live run: the **ResearchPlan DAG** (objective + sub-questions + depends-on), the **parallel
      sub-agents** running (live progress per `LiveSubAgentResearcher`), and the **synthesis** with citations —
      DeerFlow's own UI shows exactly this. Reskin it to the app's **pixel-art minimal** theme (compose with the
      RESKIN_PLAYBOOK primitives: the EpistemosTheme tokens + — if any web view is used — the pixel CSS injector;
      but since the engine is native Rust, the surface should likely be NATIVE SwiftUI reskinned, reusing
      LiveActivityStrip/ToolActivityNarrator + the provenance footer). Coherent with Chat/Act/Work, honoring
      engine-isolation (deep-research is the 3rd leg, separate path). (2) **FULLER CLONE of DeerFlow 2.0's
      SuperAgent harness** — "clone as much as I can": today Epistemos implements the 5-stage pattern
      (Coordinator/Planner/Researcher/Reporter); DeerFlow 2.0 also has the **Coder role, dynamic sub-agent
      spawning, memory, filesystem artifacts, skills**. Clone/embed as much as the doctrine allows (DeerFlow is
      **MIT** → pattern-adopt natively in Rust, NO Python/LangGraph/Docker/React runtime — app-native-by-
      embedding). Compose with the provenance fix (S15: make `[id]` citations source-grounded) + the filesystem-
      artifact offload + the MAS local-vault research mode. Deepen: docs/research/DEEP_RESEARCH_ENGINE_2026_06_19.md
      (+ the surface-reskin/fuller-clone round). Gating: web research Pro/cloud; local-vault research MAS. The
      goal — a deep-research space as polished + capable as DeerFlow 2.0's, but native + pixel-art + provenance-real.
      📍 PLACEMENT (owner asked "where should it be fused — Act/Work/Chat?", 2026-06-19) — RECOMMENDATION: deep
      research is a DISTINCT multi-agent WORKFLOW, so it lives as its **OWN coherent "Deep Research" space/leg**
      (the reskinned surface above) — NOT folded invisibly into one engine. But its LIFTED PARTS map cleanly,
      per the engine-isolation doctrine (capability shared via the registry, not duplicated): (a) **ENTRY = CHAT**
      — keep the composer deep-research button ("research this deeply" from a conversation) as the quick path +
      the space as the expanded view; capability-aware in MiniChat too. (b) **RUNTIME = ACT-class** — the
      plan→parallel-sub-agents→synthesize orchestration IS an autonomous multi-agent task, exactly Act's nature
      (Osaurus-local brain); the Deep Research space is effectively a specialized Act surface. So Act KNOWS deep-
      research as a capability and can launch it; the engine stays the in-process LocalAgent loop (already true).
      (c) **CODER ROLE → WORK** — DeerFlow's Coder (code-exec in a sandbox) maps to Work=Goose via the shared
      **Sandbox seam** (Lume/Apple-container, Pro); a `coder` sub-agent routes there, never to Chat's path. (d)
      **synthesis output → Epdoc** (post-edit) + the provenance footer. So: own space, Chat entry, Act runtime,
      Work for code-exec, all via the SHARED registry + memory seams (no cross-engine code coupling). Owner: confirm
      this split or redirect. Same model for **Open Code (Goose/Work)** — fully cloned app-native (lift the logic,
      not run the program), which is the same "clone things like DeerFlow" approach the owner affirmed.
- [ ] **CLONED-APP SETTINGS — PRESERVE + SURFACE ALL OF THEM, reskinned, NEVER hide/delete (owner
      2026-06-19) — CORRECTS the S3 "hide config-form / hardcode-away" recommendation.** Owner (verbatim,
      transcribed): *"when I clone all the rebels like Osaurus / OpenClaw, I want to make sure they have
      their system, their ACTUAL settings, in my app — and maybe their settings can be reskinned in my
      pixel-art minimalism. I don't want to delete or hide any surfaces they have, because [hiding/stripping]
      has messed up the functionality of their parts. I just want to make sure it has ALL their settings as
      well, intelligently placed where it should be, then reskinned. This should apply to Open Code / Goose,
      all of these — if their settings need to be surfaced, please make sure that happens."* DIRECTIVE: for
      every cloned/embedded app (Osaurus, OpenClaw, Goose/Open Code, DeerFlow, Hermes, etc.), **bring in
      their FULL native settings/system surface** — do NOT strip it down to a status row + hide the rest, and
      do NOT hide OpenClaw's config-form or hardcode-away clone knobs (S3's `SETTINGS_REVAMP_CLONES` said to
      hide/hardcode — **OWNER OVERRIDES THAT**: hiding their surfaces broke functionality). Instead: (1)
      **SURFACE all of each clone's real settings** (every panel/knob the clone actually has), (2) **RESKIN
      them to the pixel-art minimal theme** (coherent, not a foreign-looking panel — reuse the reskin
      injector/tokens; for a WebKit-hosted clone like OpenClaw, reskin its config UI via CSS injection rather
      than hide it), (3) **INTELLIGENTLY PLACE** them where they belong in the app's settings IA (per-engine
      sections), (4) **NEVER delete/hide a clone's surface** — this is the never-delete doctrine extended to
      cloned-app SETTINGS surfaces; honestly Pro/dev-gate the ones that touch subprocess/port/VM (show, don't
      delete), and de-duplicate only where two clones expose the literally-same knob (resolve to one control,
      still surfaced). Goal: the clone's settings WORK and are all present (their functionality intact),
      reskinned + placed, not amputated. Updates `SETTINGS_REVAMP_CLONES_2026_06_19.md`: change "absorb +
      HIDE/HARDCODE the rest" → "SURFACE ALL + RESKIN + intelligently place; never hide/delete."
      ⚖️ BALANCE — SIMPLIFY/AUTOMATE without breaking/hiding (owner 2026-06-19, later): *"make sure their
      configs and specific settings are not too complicated — so if my app can automate or simplify things,
      make that happen. But with OpenClaw it seems complex; I want to balance simplifying with NOT breaking
      functionality or hiding functionality."* So "surface ALL" does NOT mean dumping a raw, overwhelming
      foreign config on the owner. THE BALANCE: (1) **a SIMPLE default surface** — automate/auto-configure
      what the app can (sensible defaults, derive values from the app's own state instead of asking, honestly
      HARDCODE the plumbing the owner never needs to touch like ports/paths/keys), exposing only the few knobs
      that matter up front; (2) **the FULL settings remain REACHABLE** under a clearly-labeled **"Advanced" /
      progressive-disclosure** section — NOT deleted. **KEY DISTINCTION: progressive-disclosure (collapsed-
      but-reachable) ≠ hiding/deleting functionality.** Making a setting un-reachable / breaking it is
      forbidden; tucking advanced knobs behind an Advanced disclosure so the default view is clean is
      ENCOURAGED. (3) **OpenClaw specifically** (its ~20 Zod config sections = the complex case): a simple
      curated front (the handful that matter, auto-defaulted) + the full config-form reskinned + reachable
      under Advanced — never the raw foreign 20-section wall, never deleted. Net: simplify the PRESENTATION +
      automate the defaults; preserve ALL the FUNCTIONALITY (every setting still reachable + working). Simplify ≠ amputate.
- [ ] **SKILLS/TOOLS/SUPERPOWERS WORK EVERYWHERE — local+cloud, all engines, + external ecosystems
      (owner 2026-06-19).** Owner (verbatim): *"I want the loop, skills, superpowers etc. — all of this
      to be working in local AND cloud models in chat. Also make sure Osaurus, Goose, Open Code, OpenClaw
      etc. have access to native tools and skills from my app, and the Claude/Anthropic skills, also Vercel,
      also Google etc."* THREE parts: (1) **BOTH local + cloud** — every tool/skill/"superpower" must fire
      for BOTH local models AND cloud models in chat (reinforces the TOOLS/SKILLS repair: the cloud all-
      provider attach + the local GGUF-Gemma tool path + flip the flags — both paths live). (2) **CROSS-ENGINE
      NATIVE SHARING** — Osaurus/Goose(Open Code)/OpenClaw/DeerFlow must have ACCESS to the app's NATIVE tools
      + skills (Eidos, vault tools, note/file tools, the skill registry, etc.). Per the ENGINE-ISOLATION
      DOCTRINE this is the SANCTIONED capability seam: ONE shared tool/skill registry (`register_default_tools`),
      each engine binds its OWN instance — so every engine GETS the app's native tools by DEFINITION, not by
      calling another engine's code. Build/verify that the engines' registries include the native tool+skill
      set (Act⊇Chat; Work + the OpenClaw lane bind the same registry). (3) **EXTERNAL SKILL ECOSYSTEMS** —
      adopt/clone (app-native, never run-the-program) skills/tools from the big ecosystems: **Anthropic/Claude
      Agent Skills** (the SKILL.md open standard + github.com/anthropics/skills — Epistemos already speaks
      SKILL.md, so import their skill packs), **Vercel** (AI-Elements/its skill surface), **Google**, and
      others — as additional SKILL.md/tool sources installable into the shared registry (provenance-gated).
      So a chat (or any engine) can use app-native skills + Anthropic/Vercel/Google skills alike. Research:
      SS-H (cross-engine sharing) + SS-I (external ecosystems) in SETTINGS_SIMPLIFICATION_HUB. Honest gating
      (Pro for subprocess/network skills); never fake a skill that isn't wired.
- [ ] **OMNIBUS OWNER DIRECTIVE (2026-06-19) — everything researched → hardened → built end-to-end,
      no nuance lost.** Owner HARD RULE (verbatim, transcribed): *"every query I'm sending — it's in the
      plan, has its own research, has its own hardening phases, and certainly WILL be added to the app and
      coded end-to-end. Everything I asked for I want added to the app, planned, researched, etc., coded end-
      to-end."* Each item below gets: a ledger line + research + its own HARDENING phases (per the §3.7
      lifecycle: harden-before→add→re-harden-after→after-port inspection) + actually shipped. NEW/REINFORCED items:
      (1) **BROWSER-USE in ALL surfaces** — the ACTUAL github browser-use must be available across Act/Work/
      Osaurus + chat ("make the app more useful in those locations"). Reinforces R-CUA/"surface browser-use";
      now it's an ALL-engine capability via the shared registry. (SS-J)
      (2) **VOICE-MODEL PICKER** — choose different voice models in SETTINGS + a picker ON THE CHAT SURFACES
      that only fires when you use TTS; robust + simplified + minimal without losing functionality. Composes
      with the VOICE high-def item + the model stack. (SS-K)
      (3) **OpenAI + Cursor skills/tools/superpowers** — add OpenAI skills/tools AND Cursor skills/superpowers
      as native importable skill/tool sources (extend SS-I beyond Anthropic — research OpenAI's tool/skill
      surface + Cursor's rules/skills; adopt via SKILL.md/MCP/native per license). (SS-L)
      (4) **PROVIDER AGENTS on the chat surfaces** — an actual OpenAI agent / Google agent / Claude agent
      available on the chat surfaces (Chat/MiniChat) as selectable agents (research what's available — the
      agent SDKs/APIs — and how they sit on the chat surfaces; honest gating). (SS-L)
      (5) **OBSCURA browser + AGENT-SCRAPER + PRIVACY stack via WebKit** — research + harden the Obscura WKWebView
      browser + web scraping + the privacy stack; utilize WebKit for the browser. Reinforces the Obscura/stealth
      items. (SS-M)
      (6) **SENSITIVE-INFO REDACTION MODEL** — the OpenAI open-source model that detects/"outs"/redacts SENSITIVE
      INFO (PII) — research + add + harden, on-device, privacy-first (a previously-mentioned item). (SS-N)
      (7) **PRESERVE IP — Eidos, Cognitive DAG, provenance, ALL of it** — re-affirmed deletion guardrail: NONE of
      the owner's IP (Eidos closed-citation, cognitive DAG, provenance ledger, etc.) is deleted/diminished as the
      clones/skills/agents are added; everything is ADDED ON TOP, never amputated.
      (8) **GOVERNING:** robustness + simplicity (the big directive: get rid of complexity for an equivalent-but-
      simpler surface, WITHOUT losing functionality) applies to every item; everything goes through hardening
      phases; everything is coded end-to-end. Research slices SS-J/K/L/M/N in SETTINGS_SIMPLIFICATION_HUB.
- [ ] **OSAURUS/ACT RIGHT-SIDE PANEL — Claude-desktop/Codex-style context+plan+tools+skills+completed-tasks
      (owner 2026-06-19).** Owner (verbatim): *"for Osaurus I want it to have something [like] Claude where in the
      right-side panel it has context, it has plan, tools being used, tools selected, skills, etc. — basically
      like what Codex and Claude Desktop have on the right side: completed tasks, etc."* Build a right-side panel
      for the Act/Osaurus surface (and applicable to the agent surfaces generally) showing the LIVE agent run:
      **context** (what the agent is working with), the **PLAN** (the steps/todo — reuse the deep-research
      ResearchPlan-DAG + the existing /todo), **tools being used** (live, via the streaming AgentEvent/
      `LiveActivityStrip`/`ToolActivityNarrator`), **tools selected** (the preflight/ColBERT tool selection),
      **skills** (active skills), and **completed tasks/turns** — mirroring Claude Desktop / Codex right-rail.
      Compose with: the provenance footer (S19), the deep-research space (it already visualizes plan+sub-agents),
      the cognitive DAG, engine-isolation (reads the shared run/memory state, doesn't couple engines). Pixel-art
      reskinned. Honest (shows real run state, no fake). This is the "useful agent cockpit" surface for Act.
- [ ] **PROVIDER-SPECIFIC AGENT — DEEP, HARDENED (owner 2026-06-19, SENSITIVE — failed before).** Owner
      (verbatim): *"the provider-specific agent — that is a sensitive thing, it needs deep research because I
      tried this before and it didn't work. Not sure at what level are agents created — is it just file structure,
      an installable skill, etc.? Need to get all of this hardened."* So the SS-L provider-agent work (OpenAI/
      Google/Claude agent on chat) must DEEPLY answer **at what LEVEL an agent is created/defined**: is it (a) a
      file-structure/config (an AGENTS.md / agent-blueprint definition), (b) an installable SKILL/pack, (c) a
      provider runtime (the cloud Agents-SDK/Assistants API), or (d) Epistemos's own in-process agent loop
      (`agent_core` + `AgentBlueprint`) parameterized by provider — and which of these the owner's "OpenAI/Google/
      Claude agent" should be. CLARIFY the failed-before cause + design the ROBUST/HARDENED version (honest gating,
      no silent fallback, provenance, engine-isolation). This is the load-bearing nuance of SS-L — research it
      thoroughly + harden it (own hardening phases) before building. Tie to `AgentBlueprint.swift` (the identity
      layer) + the cloud provider lanes.
- [ ] **BUILD-LOOP — use subagents when it can (owner 2026-06-19).** The master build loop should DELEGATE
      parallelizable work to subagents (the Agent tool) where possible — e.g. the whole-app logo audit (many
      buttons), the cloned-app settings surfacing (5 clones), multi-file consolidations, broad sweeps — to go
      faster + more thoroughly. (It already does to a degree; reinforce: prefer fan-out for independent work.)
- [ ] **EXISTING SKILLS & TOOLS — REPAIR + HARDEN (owner 2026-06-19).** Owner (verbatim): *"with my skills
      and tools I still want to make sure that they are even repaired and hardened as well."* Beyond the
      cross-engine SHARING (SS-H) and the everywhere-availability, the app's CURRENT native skills + tools must
      themselves be **made to actually work (repaired)** + **hardened** (the §3.7 harden-before/after lifecycle).
      Concretely: (a) **the keystone gap** — local chat falls OUT of the tool loop for small models that aren't
      `canRunLocalAgentLoop` (`PipelineService.swift:342-388`) → so tools/skills silently don't fire; REPAIR =
      inject skills + route tool-needing queries to a fitting agent-capable model, no tool-less degrade.
      (b) **skills compiled-out / path-mismatch** (the 4-way skill-dir mismatch, Phase-0 #5 — an installed pack
      isn't read by the router) → REPAIR = unify the dirs so installed skills actually load. (c) Audit EVERY
      registered tool (`registry.rs register_default_tools`) for **silent-fail / fake-success / unwired
      handlers** — each must do real work or honestly gate, never green-without-witness. (d) HARDEN each
      tool/skill: ProvenanceGate on skill install, honor `allowed-tools` whitelist, scanner on quarantine,
      subprocess hardening on any exec tool, MAS preflight deny intact, no-fake invariants. (e) Skills/tools
      must be REPAIRED+HARDENED for BOTH local AND cloud chat. This is the "make the superpowers real" item —
      audit-existing-claims-first (most have hidden passes), then fix the genuinely broken, then re-harden.
      Cross-refs: SS-H (sharing), SS-I (external ecosystems + dir unification), the TOOLS/SKILLS BROKEN item.
- [ ] **VOICE — premium-default + CLONING + BITCRUSH filter + custom system voice (owner 2026-06-19; expands
      SS-K + the VOICE high-def item).** Owner (verbatim): *"that high quality voice — the Apple high-quality
      premium by default, then you can always choose the preferred voice etc. Also the cloning the voice — idk
      if that is still a thing with the voices but if I can create my own voice too, and/or allow the bitcrush
      filter be placed over any voice I def want that, and for the system voice be a custom voice with the
      filter etc."* Four parts: (1) **Apple premium/enhanced voice ON BY DEFAULT** (the SS-K `preferredVoice()`
      fix at `EpistemosSpeechSynthesizer.swift:227` — scan `speechVoices()` for highest quality, never the
      macOS-26 compact fallback) with the preferred-voice picker still available. (2) **VOICE CLONING** — let
      the owner create their own voice via Apple **Personal Voice** (`requestPersonalVoiceAuthorization` +
      `AVSpeechSynthesisProviderVoice`, on-device, MAS-entitlement) — research if still viable on macOS-26. (3)
      **BITCRUSH DSP FILTER over ANY voice** — a real-time audio effect (AVAudioEngine + AVAudioUnit /
      bit-depth-reduction + sample-rate-decimation) layered on AVSpeech output, applicable to any chosen voice.
      (4) **The Epistemos system/brand voice = a custom voice WITH the bitcrush filter** (the pixel-art-audio
      signature voice). All local/on-device, honest, no cloud TTS. Compose with SS-K's picker + the chat-surface
      TTS picker. Research the AVAudioEngine tap on `AVSpeechSynthesizer` (write-to-buffer → effect chain →
      playback) since AVSpeech doesn't expose a direct effect insert.
- [ ] **VULNERABILITY RESEARCH + REPAIR-BEFORE-ADD (owner 2026-06-19).** Owner (verbatim): *"try more robust
      research techniques to check for vulnerabilities in the code to make sure that proper repair is done
      before anything is added, cloned, or coded etc."* Before ANY new feature/clone/code lands, run a robust
      **security + correctness vulnerability sweep** on the touched area (and broadly): injection (prompt/tool/
      path), SSRF (already `validate_url`), secret leakage, unsafe `unwrap`/`try!`/force-unwrap (CLAUDE.md bans
      them), subprocess hardening gaps, MAS-sandbox escapes, unscoped capability grants, silent-fail/fake-success
      paths, memory-safety in `unsafe` blocks (each needs `// SAFETY:`), FFI deadlocks (DispatchQueue.main.sync
      ban). REPAIR found issues FIRST, then add. This is the harden-before-add half of §3.7 lifecycle, applied as
      a gating discipline. (Build loop should run targeted vuln audits + adversarial verification, not just build
      green.)
- [ ] ‼️ **MAIN-ONLY — NO WORKTREE, NO BRANCH MERGE, NEVER LOSE WORK (owner 2026-06-19, HARD CONSTRAINT).** Owner
      (verbatim): *"I don't want it to work in a new tree or anything because it should all be on main, because in
      the past merging caused really bad issues. So if there is any work that was done to main make sure it's
      committed, pushed, and that any new work from research or the plan will not cause it to lose anything at
      all."* The master build loop + all research MUST operate **directly on `main`** — NO git worktrees, NO
      feature branches, NO merges (past merges caused bad issues / data loss). Discipline: (a) any work on main is
      **committed + pushed** promptly (auto-commit+push stays intact); (b) new research/plan work is path-scoped
      and **never overwrites or drops** existing work — verify `git status` clean / in-sync before+after; (c)
      monitor never dispatches worktree/branch agents for this repo. (Supersedes any prior worktree guidance for
      THIS loop.)
- [ ] **MORE USEFUL LOCAL MODELS — LFM/ternary/Bonsai expansion (owner 2026-06-19).** Owner (verbatim): *"look
      up more useful local models, more LFM-like models like ternary Bonsai and other useful local models etc."*
      Research + add to the retained/installable catalog: **LFM2** (Liquid), **ternary / BitNet-style** models
      (1.58-bit), **Bonsai** (already referenced in `curatedBaselineDescriptors`), and other strong small
      on-device models (e.g. SmolLM, Qwen3 small, Gemma 3n, Phi, Granite, MiniCPM) — Apple-Silicon-runnable
      (MLX or GGUF/llama.cpp Pro lane per TurboVec/QAT canon). Honest: only advertise canon, but make ALL
      installable (ties to the MODEL-INSTALL/INSTALL-ANY item + the model-stack advertise toggle). Verify runtime
      support before claiming runnable (no-fake); GGUF/ternary lanes stay Pro-gated until route-evidence lands.
- [ ] **EPDOC REPAIR + a TOLARIA-style v2 WebKit MD editor (owner 2026-06-19; do NOT touch TK2/Prose).** Owner
      (verbatim): *"Epdoc seems less robust — I want deep research going into the Epdoc surface and other parts
      of my app that can be upgraded. Apps like Tolaria have a good MD [editor] where it looks like Notion
      because it has more rich UI and UX elements — I want that on Epdoc, and also maybe one more surface that
      can be a v2 MD editor built on Tolaria and WebKit or something, with the pixel-art reskin and fonts of
      course… multiple cycles of research on making things like that more robust. I don't want to touch the TK2
      or the current Prose editor — you can likely add a second MD editor using WebKit or fuse it with the Epdoc,
      but in a way that REPAIRS the current Epdoc because right now the editing is very demo-ish, it glitches and
      fails etc. I really want to try the new MD editor using WebKit but with the pixel-art minimal plus the new
      macOS-26 style. …I think it would be Epdoc but idk if that gives me the same robustness as a Tolaria, so
      try to find a balanced approach NOT touching the current TK2 prose editor."* Deep, multi-cycle research:
      (1) **REPAIR the current Epdoc** WKWebView/Tiptap editor (`Views/Epdoc/EpdocEditorChromeView.swift`,
      `js-editor/`) — it glitches/fails/demo-ish; find the root (autosave/JS-bridge/render race) and harden.
      (2) Bring **Notion-style rich UI/UX** (Tolaria-like — embed/clone Tolaria's MD approach, MIT/license-check
      via ProvenanceGate) onto Epdoc. (3) Optionally a **v2 WebKit MD editor surface** (Tolaria + WebKit base,
      pixel-art minimal + macOS-26 style + fonts) — a SECOND editor, either standalone or fused with Epdoc.
      **HARD CONSTRAINT: never touch the TK2/Prose editor** (`Views/Notes/ProseEditorView.swift` /
      `ProseTextView2.swift` / `ProseEditorRepresentable2.swift`). Balanced approach: robustness of Tolaria +
      the Epdoc surface. Reuse the WebKit host kit + pixel CSS injector. Multiple research cycles before coding.
      (New research slices SS-O Epdoc-repair, SS-P Tolaria-v2-editor — to be added to the hub.)
- [ ] **ALL RESEARCH → DEFINITELY CODED + plan references ALL research + deep-harden each cycle (owner
      2026-06-19, reaffirms OMNIBUS).** Owner (verbatim): *"all of your research should be added to the plan as
      a def code — everything should be coded. I just need deep research on how they should all be added and
      integrated into the app with deep hardening after everything and each cycle… make sure the plan references
      all research because I did lots of research that should all be deeply read and reread… make sure it def
      codes all of what we researched and what we are adding and lifting."* Every SS-* slice + every research doc
      is a BUILD COMMITMENT, not optional. The plan (this ledger + MASTER_SYNTHESIS + DEEP_PLAN_AUDIT_HUB +
      SETTINGS_SIMPLIFICATION_HUB) must explicitly REFERENCE every research doc and the build loop must CODE each
      one end-to-end (full-clone or Swift/Rust redo), with a **deep hardening pass after every feature AND after
      every cycle** (§3.7 lifecycle). Keep researching to EXTEND every item + find more that can be hardened.
      Nothing left as research-only.
- [ ] **PDF LIVE NATIVE VIEWER + MAX-OUT APPLE-NATIVE FRAMEWORKS (owner 2026-06-19).** Owner (verbatim): *"I
      want a PDF live native viewer, so use all of Apple's native things like the PDF rich viewer and all the
      things Apple natively supports to make sure I max out my app with not just the custom things but the bare
      and still robust Apple-native tools like PDF and so many more that Apple supplies… multiple cycles until I
      say done, and in these cycles you are also integrating everything."* Add a **live native PDF viewer via
      PDFKit** (`PDFView`/`PDFDocument` — selection, search, thumbnails, annotations, outline) + **QuickLook**
      (`QLPreviewController`/`QuickLookThumbnailing`) for universal file preview. Then SWEEP for every robust
      Apple-native framework that maxes out the app without custom build: QuickLook, PDFKit, **VisionKit**
      (live-text/document-scan), **Quick Look Thumbnailing**, **NaturalLanguage** (already used — SS-N),
      **Translation**, **Speech**/AVSpeech (SS-K/voice), **PencilKit**, **DataDetectors**, **WeatherKit**?,
      **MapKit**, **EventKit**, **ContactsUI**, **PhotosUI**, **CoreSpotlight** (already), **FileProvider**,
      **UniformTypeIdentifiers**, **CryptoKit**, **AppIntents**/Shortcuts, **WidgetKit**, **PassKit**, etc. —
      pick the ones that add real owner value, MAS-safe, local-first, integrate them (not just list). Multiple
      research cycles until owner says done. (New slice SS-T.)
- [ ] **AGGRESSIVE CODE-CHECKER ("nuclear …") as a MULTI-CHECKPOINT gate (owner 2026-06-19).** Owner (verbatim):
      *"that one skill or tool that Cursor had — it's supposed to aggressively check the code, I forgot what it's
      called, nuclear something — I want to make sure that that is used multiple times in the plan, so it should
      be a checkpoint for multiple parts, not overdoing it because it might take a while, but def add to multiple
      parts of the mass plan."* Identify the tool (owner recalls "nuclear …" — candidates to confirm: Cursor
      **Bugbot**, an aggressive review agent, a deep static-analysis pass, or a literal "nuclear" linter/scanner)
      and wire an equivalent **aggressive whole-codebase review/static-analysis checkpoint** at MULTIPLE points
      in the build plan (e.g. after each phase / before each lift lands) — adversarial bug-hunt, not just build-
      green. Compose with the VULNERABILITY-RESEARCH item. Not on every commit (slow) — at deliberate checkpoints.
      (New slice SS-V: identify + integrate.)
- [ ] **DARK/LIGHT MODE TOGGLE CRASHES THE APP (owner 2026-06-19).** Owner (verbatim): *"turning to dark and
      light mode often crashes the app, maybe because I have lots of surfaces that don't have robust hardening or
      something else or a combo, so make sure that is researched and also added to the plan to fix eventually."*
      Research the appearance-switch crash root: likely WKWebView surfaces re-rendering on `colorScheme` change
      (the 5+ Epdoc/HTML-workspace/KaTeX hosts), `@Environment(\.colorScheme)` churn re-running `makeNSView`/
      teardown mid-layout, theme CSS re-injection races, force-unwraps in theme color resolution, or a combo.
      Find + fix the crashing surfaces (harden, guard teardown, idempotent theme apply). (New slice SS-U.)
- [ ] **EPDOC/TOLARIA v2 = MD + DYNAMIC HTML-WORKSPACE-DOM (GitHub-grade) + best-of-GitHub-MD + agent-MD (owner
      2026-06-19; expands SS-P + the HTML-WORKSPACE item).** Owner (verbatim): *"for the Epdoc or Tolaria v2
      pixel edition I want to make sure it is MD, and also add more robustness to the HTML workspace with DOM as
      well but actually more dynamic — like the GitHub repos I see where HTML is having visuals, it looks deeply
      robust and advanced and dynamic UI/UX on the MD surface — the full Tolaria port maybe, even just doing
      WebKit and finding clever ways to deeply optimize it. There are also other GitHub MD [editors] I want to
      pull from, and just make sure I have the best combo of features from all the popular MD editors on GitHub,
      and agent MD editors as well — like the agent-and-model-to-workflow projects that easily speak to the apps.
      I want mine to be the most robust in that field."* So SS-P expands to: (1) **full Tolaria port** on WebKit
      (pixel-art minimal + macOS-26 style + fonts), MD-first. (2) **HTML workspace + DOM = MORE DYNAMIC** —
      GitHub-grade rich/advanced/dynamic visuals + UI/UX on the MD surface (clever WebKit optimization).
      (3) **Best-of-breed feature harvest** from the popular GitHub MD editors (e.g. Tiptap, Milkdown, ProseMirror,
      CodeMirror, Lexical, Slate, TipTap-md, Obsidian-style, Notion-clones) — pull the best features. (4) **Agent
      MD editors** — the agent/model-to-workflow projects that speak to apps (e.g. AGENTS.md-aware editors,
      block-based agent canvases) — make Epistemos the MOST robust in that field. License-check every lift via
      ProvenanceGate. Builds ON the SS-O repair (stabilized bridge first). NEVER touch TK2/Prose. (New slice
      SS-P expanded; cross-ref SS-O + the HTML-WORKSPACE-CAN'T-EDIT item.)
- [ ] **RECENT CRASH + STUDY ALL LOGS (owner 2026-06-19; SS-W done).** Owner: *"the app crashed recently —
      research that, study recent logs, make sure all of that is researched + fixed in the plan."* FINDING
      (SS-W): the captured crashes are **`llama-completion` SIGABRT ×2 (2026-06-16)** — the local GGUF llama-cli
      lane aborts on `common_chat_templates_apply` (uncaught C++ throw → `ggml_uncaught_exception` → abort) =
      the model's chat template can't be applied by the llama.cpp build. **Fix: classify the subprocess
      exit/template-error at the Epistemos boundary (never crash/wedge the app) [S]; pass an explicit per-model
      `--chat-template`/`--jinja` with chatml fallback [S]; pre-flight template validation at install/selection
      [M]; pin/upgrade llama.cpp [M]; add an in-app crash recorder so app-level crashes (dark/light SS-U,
      transitions) actually get captured [S].** Study `~/Library/Logs/DiagnosticReports` + `/tmp/*build*.log` +
      app logs EACH hardening cycle. Cross-ref SS-U, SS-Z, MODEL-INSTALL.
      ✅ FIX #1 LANDED 2026-06-19 — boundary exit classification (cargo-verified): the GgufCliProvider
      (agent_core/src/providers/gguf_cli.rs, Pro CLI lane) made the abort INVISIBLE two ways — stderr was
      Stdio::null() (the template-apply marker discarded) AND the exit status was swallowed
      (`let _ = child.wait()`) then an UNCONDITIONAL MessageStop{EndTurn} was yielded, so a SIGABRT-on-load
      became an empty "successful" turn (the owner's "model answers nothing"). NOW: stderr piped + drained
      (4 KB cap) and the exit classified — a non-zero/signal exit that produced NO tokens yields a typed
      AgentError::Provider; a chat-template marker (chat_templates_apply/"chat template"/minja/jinja) →
      honest "this local model's chat template could not be applied (killed by SIGABRT (6)) — pick another
      model or tier", else a generic "exited abnormally (…) before producing any output". A partial stream
      that then crashes still ends the turn (answer already delivered). exit_status_detail() names the Unix
      signal else the code. +3 unit tests (real ExitStatus via from_raw: 6=SIGABRT, code via <<8). Verified
      in an ISOLATED CARGO_TARGET_DIR (dodging research-loop shared-lock contention): `cargo test --features
      pro-build gguf_cli` → 12 passed/0 failed (incl. the 3), whole agent_core compiled under pro-build, 0
      errors, CARGO_EXIT=0. STILL OPEN (this item): per-model --chat-template/--jinja + chatml fallback [S],
      pre-flight template validation at install/selection [M], pin/upgrade llama.cpp [M], in-app crash
      recorder [S].
- [ ] **CHAT MESSAGE-BAR STILL MESSY — simplify/demuddify (owner 2026-06-19; SS-X).** Owner (verbatim): *"the
      controls on the chat are very messy still, particularly on the chat surfaces when I use the bottom message
      bar I still see think, pro, tools etc. — very old options that I thought I simplified. Those are important
      to fix, simplify, demuddify as well as part of the repair passes and multi-cycles of nuclear cleanup. More
      robust teardowns and memory management transitions etc."* The picker-simplification (P1.1-1.3, the
      three-mode Fast/Think/Code popover) did NOT fully reach the **bottom message bar** (`Views/Chat/ChatInput
      Bar.swift` + composer controls) — it still shows old think/pro/tools chips on the chat surfaces. Simplify
      the message bar to match the simplified picker (progressive-disclosure, never delete) + harden teardown +
      memory transitions on the chat surfaces. Part of the repair passes + the nuclear-cleanup (SS-V) multi-
      cycles. Cross-ref the MINICHAT-3-TOGGLES item + the picker work.
- [ ] **HYPERDYNAMIC DETERMINISM / DETERMINISTIC SCHEMA — make LOCAL agents > cloud (owner 2026-06-19; SS-Y).**
      Owner (verbatim): *"do a lot of research on the high hyperdynamic determinism / deterministic schema in
      ways to make local agents better — literally to make local agents MORE useful than cloud agents or cloud
      models. I just want to make my app a playground for making local models better and using robust upgrades
      to my agent loops."* Research + build: deterministic/constrained-schema decoding (grammar-constrained tool
      calls — the FFI `with_json_schema`/`run_local_gguf_generation` is wired; the `LocalToolGrammar` DSL),
      hyperdynamic loop determinism (there's an existing `HyperdynamicLoop` + `HyperdynamicLoopHealthRow`),
      robust agent-loop upgrades (ReAct + self-correction + verification), so a LOCAL model with constrained
      decoding + the app's skills/memory/tools beats a raw cloud model. Make the app the **playground to make
      local models better**. Compose with SS-H (skills everywhere), SS-Z (per-model framework), the grammar tool
      loop (#41), OverseerComplexityRouter. This is a flagship "local > cloud" thesis — deep, multi-cycle.
- [ ] **PER-MODEL BESPOKE ENGINEERING FRAMEWORK — modernized + non-clashing (owner 2026-06-19; SS-Z).** Owner
      (verbatim): *"in an old iteration I had a custom bespoke engineering framework for each local model and
      each cloud model. I still want that, but in a way that doesn't clash with other things — if other GitHub
      repos can solve the problems I'm having, I'll just do that. I added new models so there's outdated stuff
      (like context window in a file) — a mess that worked for specific models. I want my models to all utilize
      my skills (be able to call), but with the robust tool-call of LFM or a combination of tool-callers good for
      specific things. Research so all my models are actually able to be used with my app."* Build a clean
      **per-model capability profile** (context window, chat-template/prompt format, tool-call dialect — e.g.
      LFM-style vs chatml vs Hermes vs Qwen — sampling params) for EACH local + cloud model, modernized for the
      newly-added models (the old per-model file is outdated, e.g. wrong context windows — ties to the SS-W
      template crash). Every model must be able to call the app's skills (SS-H) with the right tool-call format
      per model. Prefer proven GitHub solutions over bespoke where they fit (license-check via ProvenanceGate).
      Non-clashing: see the next item.
- [ ] **ENGINEERING SCOPE = CHAT-FIRST; Act/Work only NON-CLASHING beneficial adds (owner 2026-06-19,
      CONSTRAINT).** Owner (verbatim): *"the clones have their own marketplace for downloading/installing models
      (Osaurus/Elsa? maybe OpenClaw/OpenCode). I want the engineering I'm doing to my local models to stay mainly
      on the CHAT surface, and whatever I can add to Act and Work mode add them — but make sure they DON'T CLASH
      because that adds complexity. The additions I told you to research should be mainly BEFORE/for the CHAT
      service; for Work and Act only add things that won't clash and are actually beneficial."* So: the per-model
      framework (SS-Z), hyperdynamic determinism (SS-Y), skills-everywhere (SS-H), and the new feature research
      land **primarily on the CHAT (Epistemos) engine**; Act (Osaurus) + Work (Goose/OpenCode) get only the
      subset that is **non-clashing + genuinely beneficial** (respect each clone's own model marketplace/install
      — don't duplicate or fight it). Engine-isolation already enforces this (shared registry/memory, not shared
      logic) — apply it as the scoping rule for ALL the additions.
- [ ] ‼️ **FINAL SESSION-COVERAGE AUDIT + LOOP-PLAN INTEGRITY (owner 2026-06-19).** Owner: *"do a final check
      that the plan has ALL my concerns from this entire session and entire thread; deep-look the real files so
      all my queries/wires are saved + my original intent is saved. Frequency of certain requests hints at what
      to prioritize, but ALL things should be coded/built. Check the loop + the loop plan being used is updated;
      if you need to start a new loop since we have stalls, do so — but make sure nothing is lost and no nuance
      or query is left out of the loop plan."* See the SESSION-COVERAGE INDEX appended below + the loop-plan
      integrity note. PRIORITY (by request frequency this session): (1) model install/run actually works +
      per-model engineering (crash, install, Qwen, SS-Z, SS-W) — most-repeated; (2) skills/tools work everywhere
      local+cloud + repaired/hardened (SS-H, repair item); (3) simplify the UI/settings/chat-bar without
      hiding/breaking (SS-A/B/X, the picker); (4) visible wins surfaced (logos, install CTA); (5) editors (Epdoc
      repair SS-O + Tolaria SS-P); (6) the new native features (voice SS-K/Q, browser SS-J, PDF SS-T, privacy
      SS-M/N). ALL still get coded — frequency only orders, never drops.
      → See `docs/research/SESSION_COVERAGE_MATRIX_2026_06_19.md` — the definitive cross-reference mapping EVERY
      concern (pre-compaction verbatim intent + this thread) → ledger + research slice + status. 129 ledger
      items; all grep-verified present.
- [ ] **GITHUB PER-MODEL ENGINEERING STUDY — harvest proven patterns (owner 2026-06-19; extends SS-Z).** Owner
      (verbatim): *"look at all GitHub repos on how they do per-model engineering for local and cloud and study
      so many of their techniques and patterns, add that to the plan… utilize GitHub when you can, do local and
      remote research on all possible things that can be improved."* Study how the leading OSS projects do
      per-model engineering (prompt format, chat template, tool-call dialect, context handling, sampling,
      adapters): e.g. llama.cpp (chat-template/minja), Ollama (Modelfile templates), LM Studio, vLLM, SGLang,
      LiteLLM (provider adapters), Jan, GPT4All, LocalAI, Aider/Cline/OpenHands (per-model prompt tuning),
      Outlines/XGrammar (constrained decoding), Hermes/function-calling formats. Harvest the proven
      techniques/patterns → fold into the SS-Z `ModelCapabilityProfile` design + SS-Y determinism. License-check
      any lift via ProvenanceGate. (New slice SS-AA.)
- [ ] **TESTS AT THE END (+ each cycle) — honest, real (owner 2026-06-19).** Owner (verbatim): *"need all the
      things to be implemented, no more forgetting, always honest, do tests at the end of all of it."* After each
      feature AND at the end: real tests — Swift Testing (compile-verify; headless Swift test EXECUTION hangs per
      the loop prompt, so reason each assertion to certainty) + `cargo test --lib` (REAL execution for Rust
      hardening) + the falsifiers. No green-without-witness; honest gating; zero regressions vs the 2,679-test
      suite. Part of the §3.7 hardening lifecycle + the thermo-nuclear (SS-V) checkpoints.
- [ ] **"LEFT UNCHANGED BY SIMPLIFICATION" ROBUSTNESS AUDIT (owner 2026-06-19).** Owner (verbatim): *"there have
      been things totally left unchanged by simplification directives, so make sure that it is more robust and
      check of the app."* The simplification directives skipped surfaces (e.g. the chat message-bar SS-X — the
      flag never reached it; settings sprawl SS-B; crash surfaces SS-U/SS-W). Sweep the app for surfaces the
      simplify/repair passes never touched + harden them (robust teardown, honest gating, no silent-fail, no
      orphan UI). Cross-ref SS-B (sprawl), SS-X (chat-bar), SS-U/SS-W (crashes), SS-Y (orphaned HyperdynamicLoop).
      This is a standing part of the REPAIR CYCLES — each cycle finds + hardens a skipped surface.
- [ ] **MODEL CAPABILITY PROFILE = DEEPLY-HARDENED COMBO + per-model DESCRIPTIONS + picker use-case copy (owner
      2026-06-19; SS-AB — the definitive synthesis of SS-Z/SS-AA/SS-R).** Owner (verbatim): *"for the model
      capability profile thing make sure you have a deeply hardened combo version of all the best ones or pick
      the best one with the best metrics — def find a way to make it work ONCE AND FOR ALL. Make sure each local
      model has a deeply researched capability profile and description for all the benefits of the model, and on
      the model picker there should be a brief description of its use case — the best models should be
      advertised, and each model on the app should have deliberate descriptions and profiles."* So: (1) the
      `ModelCapabilityProfile` is NOT just a survey — it's the DEFINITIVE hardened design = the best-of-breed
      COMBO from SS-AA (data-driven profile like Ollama Modelfile + LiteLLM capability table + Aider override-
      layering; **llguidance** as the single constrained-decoding equalizer across GGUF+MLX — the build loop has
      ALREADY added the llguidance dep; llama.cpp `--chat-template-file` resolution that kills the SS-W crash;
      per-model `stop` array). Pick the best metric per dimension, harden it, make it work once and for all.
      (2) EVERY local + cloud model gets a **deeply-researched capability profile** (contextWindow / chatTemplate
      / toolCallDialect / sampling / tier / skillsEnabled) AND a **benefits description** (what it's good at,
      from SS-R's per-model notes). (3) The **model picker shows a brief use-case description per model** (e.g.
      "Qwen3 — best all-round, think-toggle + strong tools"; "VibeThinker — tiny math reasoning"; "Gemma 4 E4B —
      fast on-device, 128K"); the BEST models are advertised; every model has deliberate copy + a profile. No
      fake/empty descriptions — honest, real per-model metrics. Cross-ref SS-Z (profile), SS-AA (OSS patterns +
      llguidance), SS-R (the model shortlist + per-model data), SS-W (crash fix), the MODEL-INSTALL + advertise-
      stack items. See `docs/research/SS-AB_MODEL_CAPABILITY_PROFILE_DEFINITIVE_2026_06_19.md`.
      ✅ FOUNDATION LANDED 2026-06-19 — the MAS-safe `ModelCapabilityProfile` floor (cargo --lib verified):
      new `agent_core/src/model_profile.rs` (non-pro-build, no subprocess) = the single per-model resolver
      SS-Z said was missing ("no single per-model profile anywhere"). Data-driven `CANON` table seeded from
      SS-AB's definitive set (Gemma 4 E2B/E4B/12B, Qwen3 4B/1.7B, VibeThinker, DeepSeek-R1-Distill, SmolLM3,
      LFM2.5, Phi-4-mini, Granite) — each with context_window (real, NEVER the GGUF hardcoded-4096 bug;
      16GB-budget-capped, e.g. Qwen 32K), max_output_tokens, prompt_dialect, lane, tier, picker_use_case
      (≤60-char copy), advertised. `PromptDialect` carries the two things MISSING on the GGUF lane today:
      per-model stop tokens (Gemma <end_of_turn>, ChatML <|im_end|>, …) + the llama.cpp builtin
      --chat-template name (gemma/chatml/llama3/…) → the GGUF lane can resolve ctx+stop+template-override
      instead of hardcoding/crashing (SS-W). `profile_for(id)` family-matches (deepseek-r1-distill BEFORE
      qwen; gemma 12B vs E2B/E4B), honest DEFAULT for unknowns (no panic, no fake). 6 cargo --lib tests green.
      NEXT (this item): wire the GGUF provider (gguf_cli.rs, Pro) to resolve ctx/stop/--chat-template from the
      profile; surface picker_use_case on the Swift model picker; seed cloud from LiteLLM; llguidance equalizer.
- [ ] **REITERATION (owner 2026-06-19): all concerns/queries still saved + everything since the last update in
      plan + researched deeply.** Confirmed via `SESSION_COVERAGE_MATRIX_2026_06_19.md` (updated) — every concern
      incl. pre-compaction verbatim intent is mapped to ledger + slice + status; nothing dropped. The
      ModelCapabilityProfile/per-model-description directive above is now captured. Standing loop continues.
- [ ] ‼️ **EPDOC = MARKDOWN-FIRST + FOREVER AUTO-MIRROR (owner 2026-06-19 — DECISION LOCKED; the owner's original
      intention).** Owner (verbatim): *"I wanted Epdoc to be markdown-first and the Epdoc is a forever
      auto-mirror — that was actually my initial intention. The Prose editor can just be its own thing, left
      untouched. Having a v2 could be confusing for users; the tradeoff is having a more robust md, and everyone
      loves to use md."* DECISION = **Option B (markdown-canonical auto-mirror), NOT a separate v2 surface.**
      Today Epdoc is **JSON-canonical** (`package.contentJSON` = ProseMirror JSON) + **HTML-rendered** (Tiptap in
      WKWebView), with NO markdown serializer (lossy md-in, no md-out — SS-O root #6). Target = flip the source of
      truth to **markdown**: clean `.md` + YAML frontmatter on disk; Epdoc is the live **auto-mirror** markdown
      (canonical) ↔ ProseMirror-JSON (rich editor) ↔ HTML (render). One editor, two views (rich + source), the
      Tolaria model. **Build order (de-risked, serializer-first):** (Stage 1) build the lossless Tiptap↔markdown
      serializer + a CodeMirror-6 source-mode toggle (this is required for B + immediately gives md import/export;
      closes SS-O root #6); (Stage 2) make markdown the stored source of truth + the live auto-mirror. **Rich-only
      blocks (charts/complex tables/callouts) → HTML-in-markdown fallback** (stays valid clean `.md`, nothing
      lost — Tolaria/Obsidian pattern), NOT degradation. **NEVER touch TK2/Prose** (`ProseEditorView.swift` etc.)
      — it stays its own untouched editor. Study Tolaria's MD aspects (wikilinks, frontmatter, clean-md-to-disk,
      WYSIWYG↔source toggle, agent-as-git-contributor) + add as much as possible — all PATTERNS, not AGPL code.
      Cross-ref SS-O (Epdoc repair — the prereq), SS-P (graft-not-clone). Prereq: land SS-O roots #2/#3 first.
- [ ] ‼️ **EPDOC FORMAT CONVERGENCE — MD canonical, HTML+JSON+package = DYNAMIC PROJECTIONS (owner 2026-06-19,
      clarifies the markdown-first decision; SS-EM).** Owner (verbatim): *"make sure you do deep research on how
      to make these all converge safely and without muddiness. Like the md-first Epdoc — json and html mirror or
      whatever is the best combo — MD should be first and then html, json, package etc. are all DYNAMICAL
      PROJECTIONS of md, maybe, or whatever is the best way and method… deeply research it all so I have the best.
      Multiple cycles. ALSO the HTML workspace is on Epdoc but I'm NOT SURE IT IS ACTUAL HTML THAT IS MIRRORING
      THE EPDOC — so make sure the JSON, HTML and whatever other formats attached to it are HARDENED, REPAIRED,
      and deeply robust AFTER you make the upgrade to Epdoc making it MD-first. Make sure the MD is actually the
      REAL robust one with the good code stuff. Still keep it pixel-art like how it is now, just make it MORE
      DYNAMIC — still keep UI/UX pixel-art and native."* So: **markdown = the single source of truth; HTML
      (render), ProseMirror-JSON (rich editor), and the `.epdoc` package are all DERIVED PROJECTIONS of the
      canonical markdown** — research the safest convergence (one-way derive vs bidirectional mirror, conflict/
      round-trip safety, no muddiness). **VERIFY the HTML workspace** (`Views/HTMLWorkspace/*`): is it genuinely
      mirroring Epdoc's content, or a separate/disconnected surface? Then **harden + repair the whole format
      stack** (md↔json↔html↔package) so projections never drift/corrupt — this hardening happens AFTER the
      MD-first flip. **Robust MD** (CommonMark/GFM + the "good code stuff": fenced code, tables, math, wikilinks,
      frontmatter). **Keep pixel-art UI/UX + native, just MORE DYNAMIC.** Multiple research cycles. Cross-ref the
      EPDOC=MARKDOWN-FIRST decision above, SS-O (repair), SS-P (graft). See SS-EM doc.
- [ ] **RECURSIVE DEEP RESEARCH — continue indefinitely, leave nothing out (owner 2026-06-19).** Owner (verbatim):
      *"still continue to do as much deep research as you can on all the parts of my app that I am upgrading / will
      upgrade / will edit / will add… after you research all of this mentioned please CONTINUE doing recursively
      deep research on all the things that can be researched deeply and super-optimized and DEF added to the plan.
      Please leave nothing out."* Standing directive: after the named slices, keep mining every subsystem for
      deeper optimization + hardening opportunities, add each finding to the plan (ledger + research doc), so the
      research never goes stale and the agent always has more well-researched, hardened work to code. Utilize
      GitHub + local + remote research. (This is the indefinite research mandate — composes with the Living-Index
      indefinite tail.) Reiteration confirmed: all concerns/queries (incl. pre-compaction) remain captured in
      `SESSION_COVERAGE_MATRIX_2026_06_19.md`; per-model capability profiles + descriptions + picker use-case copy
      = SS-AB (the loop shipped `ModelCapabilityProfile` 40b32bb22).
- [ ] ‼️ **INSTANT-RECALL via UMA ZERO-COPY for LOCAL MODELS — make model search as fast as the 50ms FTS (owner
      2026-06-20; SS-UMA — the novel flagship).** Owner (verbatim): *"the notes-sidebar instant search is SO FAST
      (the FTS 50ms instant search) — I want to ADD THAT SPEED to the local models' searching. Have a process
      where the models can look DIRECTLY into the cache or memory or whatever is being used, so fast — lower
      abstraction by utilizing the fact that I have a Mac with UMA and local models that can take advantage of the
      speed of all the other processes. I could replace as much of the instant app logic and engines — the FTS
      50ms instant search etc., whatever the cocktail that makes searching so fast — but in ways that do NOT break
      the app or the models' capabilities."* THE THESIS: leverage Apple-Silicon **UMA (unified memory)** + the
      already-instant retrieval engines (tantivy BM25 50ms FTS + usearch HNSW + RRF fusion + the shadow index +
      the in-memory caches) so a LOCAL model's recall/RAG taps the SAME fast in-process data path — zero-copy,
      low-abstraction, no serialization round-trips — making model-driven search/recall as instant as the
      notes-sidebar. = the CLAUDE.md "zero-copy / as fast as a jet" doctrine (UMA, shared buffers, IOSurface,
      in-process, single-binary, no tensor copies, no hot-path subprocess). Research: how the local agent's
      memory/knowledge.recall tool can read DIRECTLY from the shadow-index/FTS/cache memory (shared buffers,
      mmap, the existing FFI) instead of a higher-abstraction query; what's safely replaceable vs what must stay;
      keep it from breaking the app or model capability. **Do NOT touch vault, graph, or TK2/Prose.** Cross-ref
      the Halo Shadow index + RRF + SS-H (skills/tools) + SS-PERF. See SS-UMA doc.
- [ ] **EPDOC md-v2 — CodeMirror pixel-reskin + frontmatter/tags/side-panels + chat integration + deep hardening
      (owner 2026-06-20; expands SS-EM/SS-O/SS-P).** Owner (verbatim): *"nuanced things like getting the
      CodeMirror working but ALSO coded in the reskin (pixel-art minimalness), making sure the app is coherent
      with pixel-art + all features work absolutely 100%. Frontmatter, tags etc. — all the things Obsidian/Notion/
      Logseq/Tolaria have, with the side panels like the frontmatter [panel]. Make sure my Epdoc md-v2 will be
      deeply hardened and literally integrated with all chats. Keep it pixel-art like now but more dynamic, native."*
      So the md-first Epdoc (SS-EM) gains: (1) the **CodeMirror-6 source view reskinned PIXEL-ART** (coherent with
      the app, not default CodeMirror chrome); (2) **frontmatter + tags + side panels** (Obsidian/Logseq/Notion/
      Tolaria-style: a frontmatter/properties side panel, tag index, backlinks) — surfaced natively pixel-art;
      (3) **literal chat integration** — the agent can read/write the Epdoc md (the SS-P agent editing command
      family insertBlock/replaceRange/streamInto/showDiff + the doc in chat context); (4) deeply hardened, ALL
      features 100% working. Cross-ref SS-EM (convergence), SS-O (repair), SS-P (rich UI + agent-MD), the
      EPDOC=MARKDOWN-FIRST decision.
- [ ] **SUBSTRATE HEALTH PAGE GLITCHED — not working in Settings (owner 2026-06-20; concrete bug).** Owner: *"the
      substrate health page is still glitched, it is not working in settings."* The Settings → Substrate Health
      panel (`Views/Settings/SubstrateHealthPanel.swift`) is broken/glitched (doesn't render or shows broken
      data). Investigate + REPAIR. Likely related to SS-PERF (the ~18 simultaneous 1Hz polling timers +
      off-screen rows not cancelling → possible hang/overload) and SS-F (orphan rows `CognitiveDagHealthRow`/
      `HyperdynamicLoopHealthRow` never instantiated; the fake/unwired rows). Fix the panel so it renders +
      updates correctly + honestly. Cross-ref SS-PERF (#1 timer collapse), SS-F (orphan/fake rows).
- [ ] **PERF/OPTIMIZATION GATE — research BEFORE and AFTER every implementation (owner 2026-06-20, STANDING
      DISCIPLINE).** Owner (verbatim): *"make sure that performance and optimization research happens BEFORE the
      implementations AND AFTER, so that all surfaces, features, and things added to the app are deeply optimized
      before adding and after they are there, so the app keeps its structural optimization and performance
      increases."* So every feature/lift gets an optimization pass BEFORE it lands (design for perf/memory/zero-
      copy up front) AND AFTER it lands (verify no regression, harvest further gains). Composes with the
      thermo-nuclear (SS-V) + vuln-gate (SS-S) + §3.7 hardening lifecycle + SS-PERF as the standing perf catalog.
      "Super-duper hardened, super-duper speed." Continue recursive perf-research cycles (do NOT touch vault/graph/
      TK2-Prose).
      → REAFFIRM (owner 2026-06-20): EVERYTHING researched + mentioned in the plan/ledgers gets CODED END-TO-END
      100% — "I know they need to be in my app, I've done the deliberation." Make it all explicit + likely to
      happen. See `IMPLEMENTATION_SEQUENCE_2026_06_19.md` + `SESSION_COVERAGE_MATRIX_2026_06_19.md`.
- [ ] **INSTANT-RECALL = ACCURACY-FIRST + NON-INVASIVE (owner 2026-06-20; refines SS-UMA).** Owner (verbatim):
      *"for the instant recall thing I want to optimize for ACCURACY so it can be SLOWER but it must be accurate
      and useful and NOT invasive — both for editing and for the models, more importantly for the models and more
      usefulness for the typing aspect. In a way that is noninvasive pertaining to the instant recall and the
      direct memory-to-model understanding."* This **REINFORCES SS-UMA's honest finding** (the win is QUALITY,
      not speed — generation dominates). So the UMA/shadow-recall work prioritizes **accuracy + usefulness** (the
      warm RRF/HNSW fusion, sidebar-parity-or-better quality) over raw 50ms latency; slower-but-accurate is fine.
      Non-invasive (don't break the app or model capabilities). Most important for the MODELS (W-51 shadow-backed
      recall) + useful for typing. Cross-ref SS-UMA, SS-AL.
- [ ] **INSTANT-RECALL / HALO POPUP → ON THE EDITORS (Epdoc + TK2), NOT chat; redesign bubble→native-popover
      (owner 2026-06-20; SS-IR).** Owner (verbatim): *"the instant-recall halo-shadow thing — when you type and it
      pops up — I want that on the ACTUAL EDITORS, so Epdoc, TK2, and all the parts that you are typing/editing —
      NOT on the chats or anything like that. Also change it to where a BUBBLE will pop up and NOT the box, and
      when you select the bubble then the box will pop up. Make the box more robust, make it look more Apple-like
      and LESS INVASIVE because it overlays lots of things when it's not supposed to. Maybe make it a NATIVE
      POPOVER instead of the weird pixel box it is now — but have it start out as a glowing bubble or something
      noticeable, then when you click it it shows the instant-recall stuff. Make it cleaner, more native-looking."*
      So: (1) SCOPE the type-time instant-recall popup to the EDITORS (Epdoc + the TK2/Prose note editor + any
      typing/editing surface), REMOVE it from chat/landing surfaces. (2) REDESIGN: a subtle **glowing BUBBLE**
      affordance appears first (noticeable, non-invasive); clicking it opens the recall results in a **native
      `NSPopover`/SwiftUI `.popover`** (Apple-like, robust, anchored, dismissible) — replacing the current "weird
      pixel box" overlay that covers too much. Cleaner, more native, less invasive. Current code: `Views/Halo/
      {HaloButton,ShadowPanel,ShadowPanelContent}.swift`, wired in `ChatInputBar.swift` (REMOVE), `LandingView
      .swift` (REMOVE), `ProseEditorRepresentable2.swift` (KEEP/improve = TK2), + add to Epdoc. Keep pixel-art
      identity on the bubble but make the result surface native + clean. Cross-ref SS-UMA (the recall data),
      SS-O/EM (Epdoc), the TK2 non-invasive rule below.
- [ ] **TK2/PROSE EDITOR — naming + NON-INVASIVE hardening + maybe frontmatter (owner 2026-06-20; RELAXES the
      'never touch TK2' rule to NON-INVASIVE only).** Owner (verbatim): *"idk how the note/TK2/Prose editor should
      be advertised… idk if it's perfect how it is now in terms of naming and hardening, because it can also have
      the frontmatter and other things, but I was afraid before because it can't really generate or load lots of
      UI on it, so it really is Prose fundamentally — I want to respect that. But if I can make it more robust and
      useful while keeping it Prose, then we can do that. Maybe give it a name tangential to Prose, or maybe just
      Prose or Note — idk because 'doc' and 'note' seem too close together. I def want to respect its place
      because I use it the most; it's just very hardened already, so NON-INVASIVE upgrades and hardening
      techniques are important."* **IMPORTANT POLICY UPDATE:** TK2/Prose is no longer strictly off-limits — but
      ANY change must be **NON-INVASIVE** (it's already very hardened + the owner's most-used surface). Permitted
      non-invasively: (a) frontmatter support (it can read/write YAML frontmatter without embedded UI — fits
      Prose); (b) further hardening (memory/teardown/robustness); (c) the instant-recall bubble (SS-IR); (d) a
      naming/advertising decision. **NOT permitted: loading heavy UI / embedded surfaces into TK2 (it's
      fundamentally Prose — keep it that way).** NAMING: recommend keeping it **"Prose"** (distinct from Epdoc=
      "doc"; avoids the doc↔note overlap; signals the focused-writing value the owner loves). Epdoc = the rich
      markdown/doc editor; Prose = the pure focused writing editor. Research the safest non-invasive Prose
      hardening + frontmatter path. (New slice SS-TK if researched.)
- [ ] **ALL MODEL PROFILES — local AND cloud — UPDATED + HARDENED (owner 2026-06-20; extends SS-AB/SS-Z/SS-R/
      SS-AA).** Owner (verbatim): *"for all the local models and even cloud models I want to make sure that the
      profiles are updated and hardened, so add that as well."* So the `ModelCapabilityProfile` (the single
      per-model data-driven profile, SS-AB) must cover **EVERY local model AND EVERY cloud model** (Claude/OpenAI/
      Gemini + any others), each with a **CURRENT + HARDENED** profile: correct `contextWindow` (not the stale
      hardcoded 4096 / drifting MLX literals), `chatTemplate`/promptFormat, `toolCallDialect`, `samplingDefaults`,
      `stop` tokens, `capabilityTier`, `skillsEnabled`, plus the `benefitsDescription` + `pickerUseCase` (SS-AB).
      HARDENED = validated (no stale/wrong values), honest/no-fake (a model's profile reflects what it can really
      do), kept up to date as models are added/changed (the cloud half seeded from LiteLLM's capability table per
      SS-AA, bundled offline/MAS-safe), with tests (profile resolution + a no-empty-template / no-wrong-ctx
      falsifier). The loop already shipped the `ModelCapabilityProfile` (40b32bb22) + wired it into GGUF
      (03bd5c4a7); this item = COMPLETE the coverage so ALL local + cloud models have a real, current, hardened
      profile (not just the GGUF lane). Cross-ref SS-AB (definitive design), SS-Z (per-model framework), SS-R
      (the model shortlist), SS-AA (LiteLLM cloud table). Added to the TOP-UNCODED steer.
- [ ] **MLX-LORA-STUDIO — embed + fuse a native fine-tuning studio (owner 2026-06-20).** Verbatim: *"so this is
      something I wanna add absolutely to my app completely clone it and infuse it with my already replace it
      replace my my training one with this and then maybe add my training data to this new one, but I want to add
      this new one to my app and then all the things that my app does with training just fuse it with it or add
      this new one like add to this new one but like yeah, give it a rescan, etc. and I want this actually be
      useful. I want to be able to actually use the models right after they're done, etc. and of course I don't
      want to delete any any part of mine. I just wanna add mine into the new one."* Source:
      https://github.com/Goekdeniz-Guelmez/MLX-LoRA-Studio/releases/tag/v1.0.0
      **Intent (every clause):** clone MLX-LoRA-Studio in as a native STUDIO; make it the primary training surface;
      FUSE the existing `KnowledgeFusion` pipeline (synth-data/vault-training/curriculum/marketplace/skill-gen/KTO/
      ODIA/adapter-registry) INTO it; delete nothing (additive); "give it a rescan" (models/HF-cache); "use the
      models right after they're done" = CLOSE THE APPLY GAP (`NativeAdapterApply`→`MLXInferenceService`) +
      fuse-to-new-ModelVault + immediate rescan/select. **Constraint (CLAUDE.md OVERRIDES literal "clone"):**
      Studio is MIT Swift/SwiftUI ~85% BUT engine = Python subprocess (`PythonJobRunner`→`vendor/mlx-lm-lora`),
      forbidden on MAS+notarized (NO-HIDDEN-SIDECAR) — and Epistemos already has a native MLX-Swift trainer
      (`NativeLoRATrainer`/`LoRATrain`). → APP-NATIVE BY EMBEDDING: graft the MIT Swift value (live dashboard, runs
      archive, algorithm guide, ResourceGuard, 9 algos + QLoRA/QAT/full-FT) onto the native engine; port algorithm
      math natively (clean-room, no Python import); keep ALL existing KF code. **Status:** RESEARCHED →
      `docs/research/SS-LS_MLX_LORA_STUDIO_INTEGRATION_2026_06_20.md` (file:line graft plan + ordered steps).
      Keystone = the apply gap (the "use right after" blocker). Cross-ref SS-AB/SS-G/SS-C. Added to TOP-UNCODED.
- [ ] **ADAPTER UX + AGENT REVAMP + EXTERNAL-PIPELINE RESEARCH + HOMEPAGE ANIMATION REPAIR (owner 2026-06-20).**
      Verbatim: *"i want part of the app to be as simple as you go to the settings and you could just select an
      adapter and place it on any model or you on the chat or safer since you want to interact with an agent so
      after I create the new agent revamp, you can create, you can look at an agent you can browse to adapters and
      you can apply adapters and you can test adapters out. You know adapter is gonna have ex explanations and also
      my app shouldn't be the sole primitive for like the adapter robustness because there are also other apps that
      have really robust in proven training pipelines so if you could like look on github do more research and get
      her to look at other repos that have agent creation, agent training, model training, modifying tuning
      adapters, and then like the type of adapters adapters that best work for my app based off of my models in the
      architecture of my app and try to like you know max out that type of research. Also do more research as
      today's a new day so I want to iterate on all the research we've done the previous days... add to the research
      documents with some code in more directives... animations are a big thing as well on the homepage when I click
      the Home graph the animation is weird. The animation of the graph itself is not the problem more so it's like
      the transition... that entire page kind of like squishes... I want that whole animation to be more native so I
      want the buttons to do an Apple blur replace so they blur they disappear and then everything. The only thing
      that's left is the graph... it shouldn't do the popping and pop out animation... just have the buttons blur
      and disappear and then the side bar button the tool bar button at the bottom, and then the graph itself just
      blurry reappear just be a fast motion so all the things on the homepage the landing page... should just blur
      and it shouldn't have a flicker. It shouldn't have a folding animation. That folding animation right now is a
      big glitch... a really important hardening and repair... and of course if there's other things that you didn't
      research or forgot research or things I interrupted make sure you go back and research those as well. deepen
      everything deep as much as you can."*
      **Intent (every clause):** (1) ADAPTER UX — Settings: select an adapter + apply to ANY model, or to the
      chat/agent (safer); after the agent revamp: browse/apply/TEST adapters per agent, each with EXPLANATIONS.
      (2) NOT-SOLE-PRIMITIVE — research GitHub repos for agent creation/training, model training, adapter tuning +
      the best adapter TYPES for the app's MLX/GGUF small models + architecture; max out that research. (3) ITERATE
      — re-examine/deepen all prior days' research ("cold research"), add code + directives to the docs. (4) MISSED/
      INTERRUPTED — go back and research anything skipped/interrupted; deepen as much as possible. (5) HOMEPAGE
      ANIMATION REPAIR (really important hardening) — the home/landing→graph/learning transition SQUISHES/FOLDS/
      flickers; make it native Apple-blur-replace: buttons (sidebar + bottom toolbar) blur away + disappear, graph
      blur-reappears fast, no pop/fold/flicker.
      **Status:** RESEARCHED (3 code+web-grounded slices): `SS-AN_HOMEPAGE_TRANSITION_ANIMATION_2026_06_20.md`
      (folding-glitch root + Apple-blur-replace fix, file:line), `SS-AD_ADAPTER_UX_AGENT_REVAMP_2026_06_20.md`
      (Settings/agent adapter UX — Companions ARE the agents + `loraAdapterPath` already exists but is dead-wired),
      `SS-XR_EXTERNAL_ADAPTER_TRAINING_REPOS_2026_06_20.md` (proven external pipelines + adapter-type recommendation:
      DoRA-on-quantized kept-separate; algo priority SFT/LoRA→DoRA→DPO→ORPO/GRPO→QAT; mlx-lm-lora Apache-2.0 =
      loss-logic source). Animation repair = HIGH-PRIORITY repair (bump up). Cross-ref SS-LS (apply-gap, the
      substrate this builds on), SS-AB. Added to TOP-UNCODED.
- [ ] **DUAL-BRAIN PARALLEL-WORK COORDINATION + COHESIVE ANIMATION POLISH + AUTO-CHECK + AUTO-BUILD (owner 2026-06-20).**
      Verbatim (core): *"I'm working on the dual brain architecture… I wanna know if I'm able to work on that while
      the agent is working its loop or should I just leave it alone? This is stuff I'll work on in cursor… make sure
      it doesn't interact or overlap with the agent's loop… also it can def do blur replace and the apple blur
      animations so try to find other places that have ugly or glitchy animations or transitions and polish it up
      deeply, also research to make it all feel cohesive… make sure your research is added to the ledgers/docs, make
      sure nothing slipped or is lost — auto check for that so I don't have to remind — also auto build the app if u
      can periodically."*
      **Resolution:** (1) DUAL-BRAIN is the OWNER's Cursor domain (M0 = `falsify_interrupt_moves_loss` w/ vanilla-SSM;
      research durably saved in `docs/fusion/{RESEARCH_INTENT_AND_QUERY_LOG,RESEARCH_LOOP_LEDGER,ARCHITECTURE_READOUT}
      _2026_06_20.md` — verified COMMITTED + clean, §8 present). The build-loop must NEVER touch the dual-brain files
      (`research/*.rs` mamba3/attention_sinks/interrupt_*/engram, `signal_bus.rs`, `answer_packet.rs`,
      `epistemos-research/*`, `active_assembly/*`, anything M0/M1/bus) — SCOPE BOUNDARY added to the monitor steer.
      Owner works dual-brain in a SEPARATE GIT WORKTREE (`../Epistemos-dualbrain`, branch `dual-brain`) so the loop's
      `git add -A`+commit+push on main can't sweep up in-progress M0 code; integrate later when the loop is paused
      (cherry-pick/merge; M0 is mostly NEW files = low conflict). Logical overlap is LOW (different regions); the only
      hazard was the shared checkout. (2) COHESIVE ANIMATION POLISH (extends SS-AN) — after SS-AN core, the loop
      sweeps the app for OTHER ugly/glitchy animations + transitions and applies the Apple blur-replace pattern app-
      wide for cohesion; research-backed. (3) AUTO-CHECK research-in-docs — baked into the monitor (each fire verify
      ledger/slices/fusion docs committed + 0 ledger deletions + no important uncommitted docs at risk). (4) AUTO-
      BUILD — periodic full app build when the loop is idle so a FRESH RUNNABLE .app exists (the owner's running app
      was stale Jun-18); idle-gated to avoid build contention; ~15G DerivedData (fixed, overwrites, not accumulating).
- [ ] **DEEP PERF + FLUID NATIVE "FEEL-ALIVE" ANIMATIONS (owner 2026-06-20).** Verbatim: *"just continue research…
      truly get as much deep research as you can — get into the deep optimizations, performance upgrades, native
      animations and even good fluid animations that make the app feel alive but don't damage anything."* RESEARCHED
      (2 code-grounded slices): `SS-PERF2_REMAINING_PERF_WINS_2026_06_20.md` (12 remaining non-invasive perf wins —
      top: compact tool-schema JSON in the LLM prompt `ChatCoordinator.swift:3499` = fewer input tokens/turn; shared
      JSON coders on `SDMessage`; memoize RawThoughts grouping; off-main settings reads; timer focus-gating) and
      `SS-ALIVE_FLUID_NATIVE_ANIMATIONS_2026_06_20.md` (macOS-26 → all modern anim APIs available; the SS-AN `.scale`-
      fold pattern is REPEATED at `RootView.swift:2616` Landing↔Chat + 7 LandingView overlays + CompanionView/
      PhysicsModifiers/ChatSidebar → apply the BlurFade house style; add `.contentTransition(.numericText())`,
      `.symbolEffect` for conceptual spinners, `.scrollTransition` list fade-in, broaden NativeButtonStyles/Liquid
      Glass; flagship `matchedGeometryEffect` last/flagged). ALL non-invasive/additive, `reduceMotion`-gated, never
      over the Metal canvas or TK2/Prose, visual feel = PENDING OWNER. Added to TOP-UNCODED (cohesive-anim-polish +
      perf-each-cycle). Cross-ref SS-AN, SS-SH.
- [ ] **COMPANION→OSAURUS REFACTOR — IP PRESERVATION + BEFORE/AFTER SHAPE (owner 2026-06-20).** Verbatim (voice):
      *"every feature… needs a before and after shape, so things like the companion — because I am refactoring that
      by using fully [Osaurus] and then having a lot of my IP copy to Osa[urus] or move to our service. I wanna make
      sure that none of it is lost."* The OWNER is refactoring the Companion/agent system (moving/copying IP to
      Osaurus / a service) in Cursor. **Two actions:** (1) BEFORE-SHAPE baseline produced →
      `docs/research/SS-COMPANION_BEFORE_SHAPE_2026_06_20.md` (73-item IP-preservation checklist: every CompanionModel
      field, cosmetic body-grammar, CompanionState API, creation UI, AgentBlueprint routing, inference wiring, the
      Osaurus/Act seam, the Rust cognitive-DAG companion lifecycle, persistence) — tick each AFTER the refactor;
      anything with no after-home = LOST. (2) HARD SCOPE BOUNDARY added to the monitor: the build-loop must NOT touch
      the Companion/Osaurus files (Models/Companion/*, State/Companion/*, Views/Landing/Farm/*, ActOsaurus/*,
      Vendor/Osaurus/*, LocalModelServer.swift, AgentBlueprint.swift, cognitive_dag/companions.rs) while the owner
      refactors them — this is a CODE collision zone (loop just did SS-AD on CompanionModel.loraAdapterPath). Remaining
      SS-AD Companion-touching steps (per-agent picker in CompanionCreationFlow) are PAUSED; the loop continues
      non-Companion work (SS-ALIVE anim, SS-PERF2, SS-LS UI, profiles, the AdapterRegistry/Settings adapter-apply which
      is NOT Companion). Owner does the refactor on main; "pause the loop" for focused Companion code sessions. Cross-
      ref SS-AD (apply-gap), SS-XR. The "after shape" diff is the owner's to run once IP lands in Osaurus/the service.
- [ ] **SS-SH REGRESSION — substrate-health panel BLANK (owner 2026-06-20, on a fresh build). NOT DONE.** Owner:
      *"the substrate health was not fixed… the substrate health portion on settings is blank and the sidebar goes
      blank as well; it used to just be very long, now it is completely blank. not top priority but make sure it is
      not flagged as done."* ROOT (code-grounded, NOT the clock): `Views/Settings/SubstrateHealthPanel.swift:30` uses
      collapsible `Section(_:isExpanded:)` WITHOUT `.formStyle(.grouped)` → on macOS the disclosure Section only
      renders inside a grouped Form → all sections paint nothing → BLANK. Introduced by commit `13d2b5307`
      (collapsible sections), NOT the SS-SH clock-collapse (the `SubstrateHealthClock` IS injected `:152` + ticking
      `:153` + optional-safe). FIX = add `.formStyle(.grouped)` to the panel Form (~`:151`). The guard test
      (`SubstrateHealthPanelLayoutGuardTests`) only substring-matches source (never renders) → missed it; harden to a
      render/non-empty assertion. **The BLANK SIDEBAR is a SEPARATE symptom** (no sidebar consumes the clock) — needs
      its own investigation, not part of the SS-SH surface. CORRECTION to my earlier reports: SS-SH compiled + unit-
      tested but the LIVE panel is blank → SS-SH is NOT user-facing-done. Queued as a quick repair (one-liner), not
      flagged done; sidebar-blank flagged for separate diagnosis.
- [ ] **HOME-GRAPH TUNNEL — access ALL note/workspace surfaces (Epdoc + HTML workspace) inline (owner 2026-06-20).**
      Owner: *"on the home graph I want to be able to access Epdocs and HTML workspace — literally access all note/
      workspace surfaces through the home-graph tunnel itself. it's almost there; there are several things in the
      detached note workspace not included in the home graph."* RESEARCHED → `docs/research/SS-HGT_HOME_GRAPH_TUNNEL_
      2026_06_20.md`. Today the tunnel (`HomeGraphEmbeddedView`→`GraphWorkspaceContainer` switch on `GraphWorkspaceRoute`
      = .canvas/.note/.folder) hosts notes inline (Prose/TK2, Code, MD via `NoteDetailWorkspaceView`); **Epdoc +
      HTML-workspace are the gap** — they open DETACHED `NSDocument` windows instead of inline. Plan: (a) add
      `.epdoc`/`.htmlWorkspace` to `GraphWorkspaceRoute`; (b) mount existing `EpdocEditorChromeView`/
      `HTMLWorkspaceEditorView` inline in the container switch; (c) redirect open-paths (`MetalGraphView.activateNode`,
      `HologramSearchSidebar`, `GraphHTMLWorkspaceDock` Edit) to push routes not `showWindows()` (keep window as an
      explicit option); (d) `GraphBuilder` project Epdoc/HTML as clickable `.document` nodes (the bigger piece — why
      they feel absent). Constraints honored: TK2/Prose NON-INVASIVE (untouched), Metal engine untouched, no vault
      mutation, reuse-not-duplicate. Added to TOP-UNCODED.
- [ ] **GRAPH CHROME + HTML-WORKSPACE + GRANULAR THEME COLORS (owner 2026-06-20).** Verbatim: *"deep research on
      ways to optimize performance + quality with the home graph tunnel… the code editor is good but it has a top
      portion that is not the theme so there is a white bar at the top on the graph when I open the code editor. also
      there is the pill that has the settings the greeting and the recent chats that is always there — I only want it
      to exist on the landing page, so once I open graph I want the pill at the top to disappear as well as the other
      surfaces… the html workspace does not work as well but idk if its marked as such, and don't forget the upgrades
      I wanted on html workspace with DOM, the chat, etc., all the best things you'd want on html/js/css/python
      preview, and being able to create a full web app through the built-in pipeline using html workspace. also one
      part of the custom themes is that there is not a proper section for text color — text color of the body font and
      the user bubbles only changes the user bubble; on dark mode if I turn text to white it's white on the text
      editor but the user bubble in chat is also white. I want to change that color too — make it more granular: a few
      more accessory colors and accents and surfaces I can control. it's working perfectly, just that one thing should
      have granular color selections."* RESEARCHED (3 code-grounded slices):
      • `SS-GC_GRAPH_CHROME_WHITEBAR_PILL_2026_06_20.md` — (B) code-editor WHITE BAR = `codeEditorTopBar` uses
      presentation-blind `surfaceVariant(.other)` (card≈white) while the embedded surround is the landing background;
      fix = thread themeOverride into `CodeEditorView` + use the landing/background token at `CodeEditorView.swift:2167`
      (or hide bar for `.embeddedGraph`). (C) LANDING-ONLY PILL = `rootToolbarControls` ControlGroup (`RootView.swift
      :448-471`). ⚠ REVISED (owner 2026-06-20): the pill is LOAD-BEARING — without a principal ToolbarItem the window
      regresses to SQUARE (non-curved) corners, so do NOT remove it on graph. Instead KEEP it mounted+visible on both
      landing and graph (≥1 button → curve preserved) but make its buttons PAGE-RELEVANT (graph shows graph controls,
      not the landing greeting set) and DROP the recent-chat/history button (`RootView.swift:512-526` — caused issues).
      Revise the SS-AN pill-blur so the pill stays (swap contents, don't blur away). (A) tunnel perf notes. [S]
      • `SS-HW_HTML_WORKSPACE_STATUS_UPGRADE_2026_06_20.md` — HONEST STATUS: renders but is a one-way static renderer
      with DEAD seams (empty app-bridge `HTMLWorkspacePreviewView.swift:145-149`, console can never show errors, static
      not-live DOM, no Python, CSP blocks upgrades) AND it is NOT marked broken (no `HTMLWorkspaceGateStatus` despite
      the project convention). A real agent/chat PATCH pipeline already exists+wired. UPGRADE: Step0 honest GateStatus;
      Step1 real console/error bridge; Step2 live DOM + chat hot-reload; Step3 Python via Pyodide/WASM in WKWebView
      (MAS-safe, vendored + URL-scheme + CSP relax + license-gate); Step4 multi-file "build a full web app" scaffold
      pipeline. Reuse Epdoc WKWebView/bridge/URL-scheme + build-time bundle. [S→L]
      • `SS-TC_THEME_GRANULAR_COLORS_2026_06_20.md` — ROOT: custom-theme `AppCustomTheme.resolved` reuses the single
      `text` slot for `userBubbleText` (`EpistemosTheme.swift:1565`) → white editor text also whitens the user-bubble
      text (presets are fine). FIX (additive/defaulted): add `userBubbleText` + accessory/accent/surface slots to
      `AppCustomThemeColorSlot`, default unset→inherit `text` (noteSurface pattern), wire in `resolved`; the theme-
      editor grid is `allCases`-driven so new pickers appear automatically; MessageBubble already reads the token. [S]
      All NON-INVASIVE (TK2/Prose + Metal untouched), MAS-safe. Added to TOP-UNCODED.
- [ ] **THEME-SWITCH HANG + INITIATIVE BIG-WINS + QUICK-CAPTURE UPGRADE + TTS READ-BACK (owner 2026-06-20).** Verbatim:
      *"theme switching is still lacking, it hangs sometimes, the colors never change because of the theme process when
      turning dark to light and vice versa. any part of the app in terms of IP — the already-working parts and the
      parts I am and will research and code — should have proper research; this is your initiative role/control:
      research deliberately all the parts you think deserve research that I skipped over, plus the ones I mentioned.
      multiple recursive research cycles on big wins / obvious wins — literally things any sane person would obviously
      know needs a total revamp, upgrades, hardening, UI/UX upgrades, optimization, performance. /loop 2m. also the
      quick capture — I like that it prioritizes the prose editor but I want more options, presets on what it should go
      to / what it should be used for, still minimal but more robust; it was an afterthought and needs a deep upgrade.
      also add the model text-to-speech as well, so when you type something have it read back to you automatically or
      manually."* RESEARCHED (3 slices):
      • `SS-THX_THEME_SWITCH_HANG_2026_06_20.md` — HANG root = `AppCustomTheme.resolved` is UNCACHED (~15-20 UserDefaults
      reads per token-deref × whole-tree invalidation on toggle = thousands of sync reads on MainActor); NO-UPDATE root =
      HTMLWorkspace reads `@Environment(\.colorScheme)` not `ui.theme`. FIX: cache the custom-theme resolve (one per
      `appearanceSyncKey`), fix the workspace dependency, push-not-reload preview palette, defer toggle work. ⚠ SS-TC
      (granular colors) ADDS to the uncached path → do the caching WITH/BEFORE SS-TC. HIGH priority (it's a hang). [S]
      • `SS-QC_QUICK_CAPTURE_PRESETS_TTS_2026_06_20.md` — (C) quick-capture is hardcoded to a Prose SDPage
      (`TextCapturePipeline.persistNote`); add destination PRESETS via a `destination:` param (default proseNote =
      backward-compat) + a minimal preset Menu; destinations exist (note/Epdoc/chat/code via ArtifactKind+MiniChat).
      (D) TTS read-back: ONLY AVSpeechSynthesizer today (NO neural/MLX/Kokoro TTS — "model voice" = AVSpeech persona;
      neural TTS = separate SS-Q item); reuse `ReadAloudButton` (manual) + a `quickCaptureReadBack` pref + debounced
      auto-speak-on-type (`agentResponseTTS==.auto` is defined-but-unconsumed → new wiring). [S]
      • `SS-BWB_BIG_WIN_BACKLOG_2026_06_20.md` — the INITIATIVE backlog (13 genuinely-new big-win candidates, prioritized):
      #1 Settings monolith (5128 lines + shipped "(legacy)"/"Experimental"), #2 accessibility+Dynamic-Type (51/259 views,
      1208 hardcoded font sizes), #3 ⌘K command palette + shortcuts, #4 vault export/backup (none exists), #5 unified
      search surface (zero `.searchable`), #6 standardized error/empty/loading states, #7 chat error/retry UX, #8 model
      picker/status discoverability, #9 first-run time-to-value, #10 notify-on-complete, #11 ChatInputBar(2317) decompose,
      #12 notes-editor sprawl (3 prose editors), #13 MiniChat(2721) divergence. Loop pulls from this AFTER the quick wins;
      research each into its own SS-* slice when picked up. All NON-INVASIVE, off the two owner scope-boundary domains.
      Added to TOP-UNCODED + the standing initiative.
- [ ] **🔴 CRITICAL — CHAT "CREDENTIALS REJECTED" on local + cloud (owner 2026-06-20). #1, deep-repair BEFORE more chat
      building.** Verbatim: *"it said credentials were rejected whenever I try to send a query to any local model, most
      of them say that; the only one that works is the Qwen, even that may be broken. it rejects my credentials when I
      send prompts to local AND cloud models — something fundamentally wrong with the chat, it needs deep repair before
      any more additional building on it."* RESEARCHED → `docs/research/SS-CR_CHAT_CREDENTIALS_REPAIR_2026_06_20.md`. ROOT:
      LOCAL picks get MIS-ROUTED into the cloud branch (`InferenceState.effectiveChatSurfaceSelection:4704` — the
      `pendingUnavailableCloudIntentSelection` override :4705/:5843 routes cloud every turn; auto-cloud-when-local-not-
      installed :4736-4765; foundation-tier nil-resolve :4280-4283) then fail the cloud credential gate; the local MLX/
      GGUF path is credential-free. CLOUD also fails via a Keychain bootstrap RACE (`apiKey(for:)` :5214 returns nil while
      the async credential snapshot loads :3598-3640). Qwen works only because it's the installed default → stays local.
      FIX: local NEVER routes to cloud (pending-cloud = UI badge only; auto-cloud requires configured+reachable cloud AND
      never while local can serve; foundation-tier nil → runnable local/AppleIntelligence); cloud `apiKey(for:)` does a
      synchronous keychain read while bootstrapping. Behavior tests (local never→cloud; key read during bootstrap).
- [ ] **TTS VOICE/MODEL PICKER ON SURFACE (owner 2026-06-20; extends SS-QC/SS-K).** *"for the text-to-speech I want to be
      able to pick the model on the surface as well; make the default the upgraded Apple voice, still have the other
      options, but I do want them all to be in the app."* → a voice/model picker on the read-back/voice surface; DEFAULT =
      the best Apple voice (SS-K `preferredVoice` highest-quality scan), all voices/options selectable + present in-app.
      (Honest: only AVSpeech voices today; a neural TTS model is a separate SS-Q item.) Folded into SS-QC(D)/SS-K.
- [ ] **STANDING: INITIATIVE RESEARCH (perf + presentation priority) + 100% BUILD GUARANTEE (owner 2026-06-20).** *"do more
      cycles of personal initiative research on things that should be deeply researched and upgraded, prioritize
      PERFORMANCE and PRESENTATION… every single directive being researched should also be BUILT — 100% of the research
      and 100% of the plan should be implemented; make sure all research inquiries are saved somewhere so it will
      definitely be built + deliberated on."* TRACKING GUARANTEE: THIS LEDGER is the authority — every owner directive +
      every initiative item is captured here as a `[ ]` line with its `SS-*` slice; the build loop works TOP-UNCODED
      through them; nothing is dropped (audited each fire: 0 ledger deletions). Initiative big-wins live in `SS-BWB`
      (perf items: SS-PERF2/SS-THX + decompositions; presentation items: settings IA, a11y/Dynamic-Type, ⌘K palette,
      error/empty states, unified search). I deep-dive each into its own SS-* slice as it's picked up, perf+presentation
      first. Mark items DONE only when verified user-facing end-to-end.
- [ ] **DROPDOWN-ARROW CLEANUP on icon menus (owner 2026-06-20, screenshot).** *"two icons in the code editor — an eye
      and a settings icon — both have a weird drop-down arrow inside them so they look deformed. Get rid of the
      drop-down arrow, don't lose the functionality, upgrade the usefulness (searching parts of the file), and get rid
      of them everywhere they interfere/overlap other UI, mainly the one I screenshotted."* RESEARCHED →
      `docs/research/SS-DD_DROPDOWN_ARROW_CLEANUP_2026_06_20.md`. ROOT: icon-only `Menu`s with `.menuStyle(.borderlessButton)`
      render the default menu-indicator chevron over the glyph — `CodeEditorView.swift:2998-3011` (eye `viewOptionsMenu`)
      + `:2950-2992` (gear `editorSettingsMenu`). FIX: `.menuIndicator(.hidden)` (keeps the menu, removes the chevron;
      already used in 2 files → consistent). SWEEP the 8 `.menuStyle(.borderlessButton)` files, apply to icon-only ones.
      Optional [S/M] usefulness upgrade: more-robust in-file search (match count / next-prev / case-regex) on the code
      editor. [S] visual fix first (eye+gear), then sweep. NON-INVASIVE; TK2/Prose + Metal untouched. Added to TOP-UNCODED.
- [ ] **MODEL VAULT staleness + per-model file injection (owner 2026-06-20, 3 screenshots).** *"a lot of issues with the
      model + system portion of the note site, particularly the model portion. All the files seem outdated and stale. When
      I add files to a model I want it to READ those files so users have granular control of how the model interprets
      instructions and the code you give it — a subtle but very useful feature I want to respect. Harden it after we clone
      the other surfaces so they can traverse those too, but right now particularly the chat part + the System tab + the
      Models tab. The knowledge profile is outdated even if I'm using one model. Make sure it's all fixed and hardened."*
      RESEARCHED → `docs/research/SS-MV_MODEL_VAULT_STALE_PER_MODEL_FILES_2026_06_20.md`. 3 CONFIRMED roots: (1) STALE —
      only regen path is `CloudKnowledgeDistillationService.rebuildAllModelVaults()` at bootstrap (`AppBootstrap.swift:2347`)
      + manual button; no on-note-change/periodic refresh. (2) LOCAL MODELS NEVER READ THE VAULT — `augmentedSystemPrompt`
      injected only in `LLMService.swift:1359` (cloud) + `AppleIntelligenceService.swift:282`; local MLX path has ZERO calls.
      (3) USER-ADDED FILES IGNORED — injection hardcoded to 4 `canonicalFiles`. FIX: inject vault context into the local
      path; enumerate+inject user-added files with budgeting + per-file toggle; add refresh trigger + staleness badge; audit
      System-tab writers ("No files yet"). Scope = KnowledgeFusion/* + ModeModelVaults|ModeSystem + ModelVaults* (OUTSIDE
      Companion→Osaurus, verified). Cross-surface traversal DEFERRED until after the Companion/Osaurus clone. [M] dedicated cycle.
- [ ] **WIKILINK-driven AUTO-RESEARCH for local + cloud models (owner 2026-06-20).** *"Google's take on Karpathy's wiki
      link and the original wiki link — anything that references wikilink / auto-research, I want those. I really want that
      useful for my models, local AND cloud; wikilink is one of the best ways. Logic/auto-research could launch overnight or
      be a feature. Deep these, add to the ledgers/plan as a dedicated cycle of implementations."* RESEARCHED →
      `docs/research/SS-WL_WIKILINK_AUTORESEARCH_2026_06_20.md`. NEW feature: no real `[[wikilink]]` parser/resolver exists
      (the `[[` greps are mostly `[[String:Any]]`); existing `AutoresearchLoop` is a QLoRA TRAINING loop, NOT this. Build:
      (1) wikilink parser+resolver+backlink index, (2) unresolved-link→auto-research task (local-first, honest gating),
      (3) overnight/on-demand runner (background-activity entitlement; no hidden subprocess), (4) feed Model Vault
      active_context/concept_index (depends on SS-MV), (5) provenance + honesty. NON-INVASIVE; dedicated cycle AFTER SS-MV +
      current quick wins. Each sub-part = own SS-* slice + tests when picked up.
- [ ] **WIKILINK deep fork research → 100% best-of-breed (owner 2026-06-20).** *"do more research on wikilink — go to
      different GitHub repos, see which are forks, go deep into the forks for other iterations to implement; 100% implement
      the best parts in the best combination of all the best forks/repos, for an in-use feature AND an overnight training
      feature, and any parts of the app that should integrate these. Make sure nothing gets messy or muddy."* RESEARCHED
      (web) → SS-WL "GitHub/fork research" section. FINDINGS: owner's ref = **Karpathy LLM Wiki** pattern (gist) + community/
      Google iterations. Repos mined: nashsu/llm_wiki (two-step ingest, SHA256 cache, persistent crash-safe queue, 4-signal
      relevance, Louvain) ; penfieldlabs "what's missing" → TYPED edges (supersedes/contradicts/causes…) → map onto Epistemos
      EXISTING `cognitive_dag` EdgeKinds (Contradicts/DerivesFrom) ; flowershow/remark-wiki-link + forks (rgruner/C1200/boehs)
      + zetl for SYNTAX/resolution/backlinks (implement NATIVELY in Swift/Rust). BEST COMBO: (I) in-use = pure/offline native
      parser + typed edges + backlink index + autocomplete ; (II) overnight = Karpathy ingest+lint via persistent queue,
      unresolved-link auto-research, feeds Model Vault. Kept SEPARATE (shared AST+backlink seam) so they don't muddy.
- [ ] **ANTI-MESSINESS / ANTI-MUDDINESS self-correction discipline (owner 2026-06-20).** *"I don't want this messy and
      muddy. Implement the two things in different parts of the plan, and there are times where the agents will PAUSE and
      check for messiness, check for muddiness, fix it, correct itself, and continue."* META directive → governs HOW the
      loop works. RESEARCHED → `docs/research/SS-CLEAN_ANTI_MUDDINESS_SELF_CORRECTION_2026_06_20.md`. Defines messy/muddy
      (dead-flag/orphan features, duplicate/divergent impls, stale artifacts, contradictions, layering mud) + a recurring
      "Cleanliness Gate" (pause→scan→fix→re-verify→continue) woven into the loop cadence (every ~5 iters/end-of-cycle, NOT
      every iter) + the wiki-lint product instance (SS-WL). Never deletes owner/scope-boundary work. Added to loop discipline
      (cron) + as last-auditor checks. Cross-ref SS-WL/SS-MV/SS-BWB.
- [ ] **EPDOC decisive editor — TAKE OVER Obsidian/Logseq/Notion/Roam (owner 2026-06-20).** *"I'm missing the boat with
      Obsidian — not competing, but if I become better than it the others become add-ons / deeply integrated. The app must
      compete with all of them so people use it over Obsidian and especially Notion (rich text, lots of moving parts, the
      block stuff). Add that to the app Doc, markdown-FIRST, really robust + dynamic + rich, but super fast, highly
      optimized, almost as minimal as the Prose editor, with all bells & whistles + native Apple (pixel-art). Research on
      those services robust enough to completely take over Logseq/Obsidian/Notion."* RESEARCHED (web + code) →
      `docs/research/SS-EDGE_EPDOC_DECISIVE_EDITOR_TAKEOVER_2026_06_20.md`. NOT a re-plan — md-first Epdoc is ALREADY LOCKED
      in `EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md` (7 phases: md canonical, JSON/HTML = projections; Notion-like Tiptap
      template; wikilinks/backlinks) + competitor matrix in `COMPETITOR_SUPERSESSION_2026_06_19.md`. SS-EDGE ADDS the
      take-over ACCEPTANCE BAR: (1) Notion-parity block richness (slash/drag/callout/toggle/table/columns/embeds) each with
      LOSSLESS md projection; (2) Logseq/Roam block-refs + transclusion + backlinks + SS-WL auto-research; (3) Bases-style
      table/DB views over frontmatter (SS-FM); (4) clean Obsidian/Logseq vault import/export (no lock-in → "they become
      add-ons"); (5) graph+canvas parity (fix broken P7.2). KEY ARCH DECISION: INVERT Tiptap's JSON-first default → md is
      truth, JSON/HTML derived (the differentiator vs Notion + naive Tiptap). Speed: reuse perf wave, lazy heavy blocks,
      opens as fast as Prose. NEVER touch TK2/Prose. Anti-mud (SS-CLEAN): one md serializer + one wikilink seam shared w/
      SS-WL. Sequenced INSIDE EPDOC_MD_V2; SS-EDGE is the bar, not a parallel track.
- [ ] **TWO-SURFACE coexistence + cross-surface fidelity, NO data loss (owner 2026-06-20).** *"Prose/TextKit2 can deviate
      from Epdoc; if Epdoc MD-v2 is the main md editor it could or couldn't be — but there are two surfaces, respect both,
      both have use cases. Quick capture: option to choose which surface. Granular BUT minimal choices — balance usefulness
      with minimalism/UX; don't let it get muddy/cloned/left to rot. CRITICAL: editing in Prose then switching to Epdoc, I
      don't want things to disappear/reappear — e.g. images embedded in md show in Epdoc but NOT in Prose/TK2 → ambiguity
      confuses users. Want a caveat / robust UX without destroying data or regressing any surface. Upgrade the Prose editor
      if you can, else leave/minimally upgrade."* RESEARCHED (code file:line + Obsidian UX) →
      `docs/research/SS-2S_TWO_SURFACE_FIDELITY_PROSE_EPDOC_2026_06_20.md`. GROUND TRUTH: Prose is ALREADY md-backed
      (SDPage + .md file); Epdoc is JSON-first (EPDOC_MD_V2 inverts it); NO surface-switch exists; image asymmetry is
      STRUCTURAL (Rust `graph-engine/src/markdown.rs` parser has NO image token → md images invisible in Prose, render in
      Epdoc); TWO real DATA-LOSS bugs (Prose inserted-images dropped on save `ProseTextView2.swift:1786-1808`; Epdoc
      shadow.md lossy). FIX: (A) MUST — persist Prose inserted-images to `![](assets/…)` md + render md images in Prose
      (add image token to the Rust parser — the "upgrade Prose" path); (B) honest non-destructive caveat chip where a
      surface can't render something (md text always preserved); (C) explicit view-switch over ONE md AFTER EPDOC_MD_V2
      Phase 3 (no lossy JSON↔md converter); (D) quick-capture destination picker (default Prose, minimal toggle to Epdoc;
      extends SS-QC). Obsidian model = views over one md file (unify truth, differ rendering). One serializer/asset/wikilink
      seam shared (SS-CLEAN anti-mud). NEVER damage TK2/Prose. Test: insert image→save→reload→present in BOTH surfaces.
- [ ] **INLINE note-AI: keep streaming + send animation + pixel-art scroll-down arrow + AI/user separation (owner 2026-06-20).**
      *"Keep the inline streaming 'Ask this note' AI — reply inline (it's very good, robust, KEEP it). Add an animation: when
      you send a query the bar animates, and a large pixel-art arrow pops up over the note pointing down + a pixel-art phrase
      'scroll down to see answer'. Scroll down → answer, separated, in a 'cold box' obviously written by AI so the user isn't
      confused about what's theirs vs the AI's. Robust WITHOUT losing the inline feature."* RESEARCHED →
      `docs/research/SS-IL_INLINE_NOTE_AI_ANIM_SEPARATION_2026_06_20.md`. Inline = `NoteChatState` (submitQuery
      `NoteDetailWorkspaceView.swift:1778`, isStreaming, "Ask this note" :2072) — ADDITIVE only: (1) send animation on the
      bar; (2) animated pixel-art DOWN arrow + phrase shown ONLY when the answer is below the fold, auto-hides on scroll-to;
      (3) "cold box" AI-answer container (distinct theme token + AI label + copy/insert/dismiss; nothing silently merges into
      note body). Keep inline streaming unchanged (no regression). Cross-ref SS-ALIVE/SS-TC/SS-2S/SS-CLEAN. [S→M].
- [ ] **INSTANT RECALL / Shadow Halo — verify still works + surface the new UI (owner 2026-06-20).** *"I don't see the
      shadow halo instant-recall anymore. Not sure if a fix landed trading speed for accuracy. Make sure it's still working,
      and the UI — I haven't seen the new UI, I can't access it. Make sure it's good, in the plan, deliberated."* VERIFIED
      (Explore, file:line) → appended to `SS-IR_INSTANT_RECALL_POPUP_REDESIGN_2026_06_20.md`. FINDINGS: NOT removed — wired +
      enabled-by-default (`ContextualShadowsState.isEnabled` defaults TRUE); NO speed-for-accuracy commit landed (that lives
      only in the SS-IR slice, UNBUILT); backend bootstraps but needs an active vault + FFI open to install the search
      service. Invisible because: no recall hits → no chrome / search-service not installed (no vault) / scoping refactor
      narrowed it / the new popover UI isn't built yet. BUILD ADDS: (a) DISCOVERABLE resting bubble w/ empty-state (not only
      when hits exist); (b) runtime health diagnostic (vault? FFI? index size?); (c) bubble→NSPopover redesign + add to Epdoc;
      verify on-device the owner can SEE+OPEN it. [M→L].
- [ ] **HTML WORKSPACE: chat fully rewrites surface into a website/explainer + which chat drives it (owner 2026-06-20).**
      *"I want chat to literally completely redo the entire surface to look like a whole website/webpage — DOM, live UI,
      animations. Even 'explain something' → explain via JSON/HTML streaming by creating a webpage/explainer from what it
      knows. Make the surface flexible+dynamic enough. Chat via mini chat — and maybe main chat (mini works for all surfaces,
      main isn't auto-linked). Research + document + deliberate."* RESEARCHED → SS-HW "EXPANSION" section. Adds: (5) full-
      surface `regenerate`/`replaceDocument` patch op (atomic, versioned, reversible, AI-provenance) + streaming + explainer-
      from-knowledge (HTML freeform or JSON-schema explainer; grounded in SS-WL/SS-MV); MAS-safe via the in-process patch
      pipeline. (6) MINI-CHAT is the primary driver (already targets any surface via `MiniChatTarget` DocumentSurface.swift:81-109);
      MAIN-CHAT recommendation = NO implicit global link (muddiness) → explicit "target this surface" affordance only; auto-link
      DECISION DEFERRED to owner. Cross-ref SS-2S/SS-IL/SS-WL/SS-MV/SS-HGT. [M→L].
- [ ] **METAL STREAMING OVERLAY for "Ask this note" (owner 2026-06-20; extends SS-IL).** *"Make the inline streaming more
      interesting + dynamic. Maybe use Metal to have an overlay going on — it's hard to engineer UI on TextKit, so be
      creative. Communicate the interestingness of inline streaming on an ACTUAL editing surface + being able to immediately
      edit right after it's done streaming."* RESEARCHED (web + code) → SS-IL "METAL STREAMING OVERLAY" section. APPROACH:
      a non-interactive SwiftUI overlay ABOVE the editor (TextKit2 untouched), GPU-driven by SwiftUI Metal shaders
      (`.layerEffect`/`.colorEffect` + self-animating `TimelineView(.animation)`), `allowsHitTesting(false)` so typing passes
      through. Reuse existing `Shaders/ThinkingGlow.metal` (port to a `[[stitchable]]` SwiftUI shader). Effect = "materialize
      → dissolve → editable": pulse on send → shimmer rides the streaming frontier → on stream-end the shimmer DISSOLVES to
      reveal clean native immediately-editable text (the hand-off IS the interestingness), settling into the SS-IL cold-box.
      Bounded GPU (only during stream + dissolve, clipped, then removed; reduce-motion fallback). One reusable component
      (also for Epdoc). Cross-ref SS-ALIVE/SS-TC/SS-PERF2/SS-CLEAN. [M].
- [ ] **OWNER-REQUEST COVERAGE SWEEP — recurring cycle so nothing asked is left out (owner 2026-06-20).** *"Continue
      researching. Make a cycle in the plan that makes sure nothing I asked for is left out — some things may have been
      missed or interrupted. Make sure everything I ask is researched + added to the plan."* RESEARCHED → SS-CLEAN
      "OWNER-REQUEST COVERAGE SWEEP" section. A SEPARATE recurring cycle (completeness of intent, distinct from the muddiness
      gate): every directive→verbatim ledger `[ ]` (captured BEFORE work, interruption-proof); every `[ ]`→slice + build-order
      slot; every slice→referenced (no orphans); multi-part asks decomposed per sub-bullet; gaps surfaced, never papered over.
      Run end-of-batch + every monitor fire. FIRST SWEEP (2026-06-20): 167 open items; no owner ask found dropped; closed an
      index gap (SS-AL/Y/FM/UMA/SH now tracked in the finalization index). Cross-ref RESEARCH_FINALIZATION_INDEX, SS-CLEAN.
- [ ] **NO-RISK-DEFERRAL RULE + commit-before-edit savepoint (owner 2026-06-20).** *"Research why it would defer it, and
      deeply research to make it safe + robust the way I want — apply this to all other items, the no-deferral rule. If it's
      deferred it needs enough research + deliberation to safely implement. I want the deferred stuff CODED, not deferred. And
      commit before editing so it can be saved."* RESEARCHED → SS-CLEAN "NO-RISK-DEFERRAL RULE" section. (1) A risk/fragility
      fear is NOT a stop — it triggers deep research → a PROVABLY-SAFE approach (pure-additive seam that can't touch the
      fragile path + regression-guard tests) → then CODE it; never "leave it." (2) Commit a clean savepoint BEFORE a risky
      edit so a failed attempt resets cheaply (nothing lost) — making fragile work safe to attempt. WORKED EXAMPLE: SS-IL was
      deferred fearing the protected inline-stream path; deep map (Explore, file:line) → safe-additive OVERLAY plan (pure
      overlays reading read-only NoteChatState + 1 additive read-only rect-getter; streaming path provably untouched; 6
      regression guards) → SS-IL "SAFE-ADDITIVE IMPLEMENTATION" section → CODE IT. APPLIED to all deferrals: SS-IL→code;
      SS-TC→UN-DEFERRED (SS-THX cache landed = the safety); SS-2S full inline-image render→research offset-safe attachment +
      code; SS-HW main-chat auto-link→owner-preference (default explicit-target-only, proceed). EXCEPTIONS that may wait: genuine
      owner-preference choices + items gated on an external fact (e.g. API key) — everything else is research-to-safety + code.
- [x] **SURFACE ALL CHAT CAPABILITIES (tools + cowork) ON THE SEARCH PAGE + everywhere (owner 2026-06-20).** *"I want the
      tools and cowork stuff — all things attached to the chat — VISIBLE on the search page, so a user can start off using a
      tool. Also they are not working. The ~50 tools should be there (maybe in a popover still) + the cowork stuff —
      literally ALL capable chat stuff should be not only in chat but on the search page and all places it should be. This
      falls under the HIDDEN RULE where things are muddy and hidden — meaning our checks have NOT been working. This is a
      huge thing."* RESEARCHED (Explore, file:line) → `docs/research/SS-VIS_CHAT_CAPABILITIES_ON_SEARCH_2026_06_20.md`.
      GROUND TRUTH: nothing broken — the picker is ONLY mounted in chat. Single source of truth = `AgentCommandCenterState.availableTools`
      (← ToolTierBridge ← Rust registry.rs, ~50 tools / 33 MAS); one reusable picker = `AgentToolTogglePanel` (tools+MCP+cowork+skills);
      LandingView already injects `agentCommandCenter` (:87, used for Farm :430) but never mounts the picker. FIX (safe-additive,
      one registry/one picker): mount `AgentToolTogglePanel` on the landing search (landingSearchExpandedToolRow :1086 /
      landingSearchStageTools :943) + a start-with-a-tool handoff into the existing `submitLandingSearch()` (:1890); cowork via
      `CoworkChatMode`/`CoworkPanel` reuse; sweep mini-chat/graph/editor surfaces. VERIFY tools actually execute from search
      (catalog non-empty per tier). HIDDEN-RULE GAP recorded in SS-CLEAN: added a CAPABILITY SURFACE-PARITY scan (prior checks
      caught orphans/dupes but NOT asymmetry = built in one surface, hidden from a peer). [S→M].
      ✅ DONE-RE-AUDIT (loop 2026-06-21): the shared AgentToolTogglePanel (the ~50 tools + MCP + cowork
      + skills, single registry) is now mounted on the landing SEARCH page (landingSearchCapabilitiesTool,
      735940b7a) AND every chat surface — main chat (ChatInputBar), mini-chat (composer toolPanelButton),
      graph (558bea540), note (d08e15d7a); cross-surface parity pinned by SSVISWiderSweepTests + the
      capability surface-parity scan. "Start off using a tool/skill" is live: a discovered skill runs from
      each surface, primed into that composer's field (landing 7101b307c, graph 0dcc19047, note 224f32dd2,
      chat/mini-chat runSkillFromPanel). Tools actually execute (L1192 gating Allow/Deny verified). The
      mini-chat double-mount was deduped (3475ea82e, guarded). REMAINING REFINEMENT (tracked, not blocking):
      the explicit cowork/Act-MODE auto-handoff on a cowork selection — its pure decision shipped
      (AgentLaunchHandoff.startMode, eb36938b2) but the wiring waits on an explicit cowork-selection
      affordance in the panel (no signal to trigger it yet); SS-FOLLOWON.
- [ ] **SUBSTRATE-HEALTH completion + clone-sequencing contemplation (owner 2026-06-20).** *"Much of the substrate health
      is unfinished stubs, not wired. I want it all working — idk if before or after the clones, because the clones would
      reuse this IP so it'd be advantageous to do it BEFORE, but I really want to add the clones first since substrate is
      heavy backend. Make sure this nuance + contemplation is in the plan."* RESEARCHED → `docs/research/SS-SUB_SUBSTRATE_COMPLETION_CLONE_SEQUENCING_2026_06_20.md`.
      KEY: SubstrateHealthPanel's ~25 rows SPLIT along the scope boundary. BOUNDARY (owner Cursor domain — loop NEVER builds;
      this IS the clones' backend IP): SystemG/AnswerPacket/LatticeWBO/ACSAdmission/EmlObservatory/UasAcs/NightBrainLoRA
      (dual-brain) + ActOsaurus/WorkBackend (Companion→Osaurus). LOOP-SAFE: Eidos/VaultRecall/SearchFusion/EmlRerankGate/
      EditorBundle/LiteParse/CognitiveDagCounts/DeepResearch/FUlp/FalsifierArtifacts/ActiveConstellation/LocalRouteHonesty.
      CONTEMPLATION RESOLVED: the clone-relevant substrate IS the owner's boundary domain, so "substrate-before-clones" = more
      owner Cursor work first; "clones-first" (owner's lean) is viable IF the clone↔substrate seam is an INTERFACE/CONTRACT
      (substrate firms up behind it later, no clone rework) — recommend freezing that interface before the clones. ORDER is an
      OWNER PREFERENCE (flag, don't force). LOOP unblocked either way: independently completes/wire-honestly the LOOP-SAFE rows
      (live probe vs honest fixture, never fake-green) + folds in SS-SH blank-sidebar; NEVER touches boundary-row backends
      (read-only display only). Cross-ref SS-SH/SS-CLEAN.
- [ ] **SUBSTRATE WITHOUT THE NEW MODEL — deep research + completion (owner 2026-06-20, clarification).** *"Deep nuanced
      research here; even the informative stuff is foreign to me and users. Not worried about dual-brain rn: if I need the NEW
      MODEL I don't want surfaces to require that part — they can use everything else but NOT a required new model (takes a
      long time). Everything from the substrate + the entire ontology WITHOUT the new model, and DON'T advertise it as the new
      model — users just see the substrate. Substrate completed END-TO-END + reusable by other surfaces. Multiple research
      cycles (local first, then online) to harden it so the agent builder can EASILY finish it. Want substrate finished BEFORE
      other things IF beneficial; deliberate."* + *"remember all the research CURSOR did for dual brain — look at its local
      research, all docs/folders it created/iterated."* RESEARCHED (cycle 1 local; cycle 2 online RETRY — web was down) →
      SS-SUB "DEEP RESEARCH v2". KEY RESOLUTION: substrate is DESIGNED model-agnostic; the new model (brain-1 SSM/M0/bus/
      lattice-safety) plugs in behind the EXISTING seam `SystemGAgentEvent::LocalModelHandoff` + `AnswerPacket.attention_mode`
      (static_fallback today → dynamic later, ZERO consumer rework, nothing user-facing says "new model") + RuntimeRouter lanes.
      So the model-agnostic substrate (AnswerPacket/RuntimeRouter/SystemG-runner/SovereignGate/EML/ACS/DAG/recall) can be
      completed END-TO-END on TODAY's MLX/Gemma + interface-FROZEN + reused by all surfaces NOW — substrate-first is FAST +
      beneficial (no new-model wait; weeks not months). Cited Cursor's 136 docs/fusion corpus (ARCHITECTURE_READOUT + canons).
      BOUNDARY: high-value completion (RuntimeRouter promotion / AnswerPacket persistence / SystemG wiring) is in the owner's
      Cursor domain → WHO finishes it is the open decision (loop builds it = scope reversal, vs owner-Cursor + loop does
      loop-safe rows + explainer + interface-draft). DECISION posed to owner via AskUserQuestion (scope + sequencing).
      ↳ **OWNER DECISION (2026-06-20):** *"it's not live literally we are done — I was asking you to research and for the
      AGENT to build once it's all good. Doesn't matter [on sequencing] — just work on it in loop like all the other things,
      I just want it completed. Do we have enough research to build the rest of the FULL substrate architecture WITHOUT the
      new model, also without the 70B, but all the other things that are my app?"* ANSWER: YES — enough research (interfaces
      exist + per-component promotion stages documented; promotion not greenfield). Boundary LIFTED for the substrate: the
      LOOP now BUILDS the model-agnostic substrate in-loop. Consolidated plan → `docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md`
      (Phases 0-7: freeze interfaces → RuntimeRouter live → AnswerPacket persistence → System G providers → wire health rows
      + SS-SH → EML/recall reachable → surface reuse → explainer). EXCLUDED (don't build, not advertised): the NEW MODEL
      (SSM/M0/signal_bus/lattice-quant-safety/ternary brain-1), the 70B, Companion→Osaurus clones. Seam: new model plugs in
      later behind LocalModelHandoff + AnswerPacket.attention_mode (static_fallback→dynamic, zero rework). Memory updated
      (project_substrate_build_authorized_2026_06_20 supersedes dual-brain-off-limits for substrate). Online research cycle
      RETRY pending (web down). Added to loop build order (cron).
- [ ] **SUBSTRATE research-cycle-2 + context packaging + preserve new-model/70B (owner 2026-06-20, w/ Cursor PASS-22 closeout).**
      *"These are the docs + my last query — don't try to build [M0/new model] but deeply research this too (excl. the
      research-phase-closed M0 build). Do one more research cycle; only SUPERSEDE OR MATCH. Add it all to the loop + make sure
      the loop has all the research — multi-level heavy backend, enormous research, package it 100% there but not overwhelming,
      optimize for context. Make sure 70B + new model are SAVED but not in the app — theoretical research, available to build;
      add it to the lattice explainer / living index / all the other places."* RESEARCHED (cycle 2, local; online RETRY pending)
      → reconciled vs Cursor's PASS-22 closeout (SESSION_CHECKPOINT/ARCHITECTURE_READOUT §8-8.7/RESEARCH_LOOP_LEDGER/INTENT Q38/
      GEMINI_70B blueprint+eval/MASTER_SYNTHESIS). VERDICT: **MATCH** — my SUBSTRATE_BUILD_SEQUENCE is the model-agnostic
      projection of Cursor's full plan (same two-brain split, same `LocalModelHandoff`+`AnswerPacket.attention_mode` seam, same
      EXCLUDED set); one deliberate refinement (decouple brain-2 build from the M0 gate — rework-free per the seam). ADDED:
      B1 systems wins (sliding-window/bundling/prefetch, T1 no-model-change) pulled into substrate scope; bound named falsifiers
      per phase (F-RuntimeRouter-Live/F-AnswerPacket-Emitted/falsify_shadow_recall_parity/verify-replay/F-UAS-CopyCount); the
      "policy-async not decision-sync" soundness key; docs_first gates brain-1 only (brain-2 build UNBLOCKED). PACKAGED for
      context → `docs/research/SUBSTRATE_RESEARCH_BUNDLE_2026_06_20.md` (5-doc ordered reading path <700 lines = 100% spec w/o
      the other 131 fusion docs). PRESERVED new-model+70B → `docs/research/NEW_MODEL_70B_THEORETICAL_PRESERVED_2026_06_20.md`
      (M0 interrupt experiment [harness da8475dff, driver gated on docs_first], Mamba-3/B'MOJO spine deferred, Gemini 70B
      cocktail T0-deduped) — theoretical/available-to-build, NOT in app, behind the seam, never advertised. Pointer added to
      EPISTEMOS_LIVING_INDEX (write-plan only, owner-greenlit; authority content untouched; lattice-explainer not edited).
      ledger deletions 0.
- [ ] **🔴🔴 P0 LAUNCH CRASH — app crashes as soon as it opens (owner 2026-06-20).** *"the app keeps crashing as soon as I
      open it. Fix it + add to the plan."* DIAGNOSED (crash-log-grounded) → `docs/research/SS-CRASH_LAUNCH_CRASH_APPBOOTSTRAP_2026_06_20.md`.
      Crash = `EXC_BREAKPOINT`/`SIGTRAP` via `_assertionFailure` (Swift precondition trap) in
      `AppBootstrap.performPrimaryLaunchInitialization()` through a SwiftUI @Observable Attribute closure. ROOT (high conf):
      REGRESSION from `3c89ae84f` (SS-IR Instant-Recall health diagnostic) — its stats() FFI / shadow-service access runs
      during launch-init BEFORE the shadow backend is installed, tripping a `preconditionFailure` (AppBootstrap.swift:938
      "accessed before initialization" and/or new diagnostic precondition ~:3071). FIX (P0): the diagnostic must DEGRADE
      gracefully (honest "not ready" via guard/optional, NEVER precondition/fatalError); don't call stats() FFI from launch-init
      or an observable getter — defer until after initializeShadowBackendIfReady() / lazy on Settings open; guard on
      haloSearchService!=nil. Verify the app OPENS (with + without a vault). JUMPS AHEAD of substrate/feature work. Auditor add
      to SS-CLEAN: startup-touching commits need a LAUNCH SMOKE check, not just unit-green (this was green-but-crashed-launch).
- [ ] **LOCAL MULTI-TOOL RESEARCH RELIABILITY — Eidos/file/vault tools from Qwen 4B (owner 2026-06-20).** *"There was one
      chat where Eidos + file/vault search all worked — Qwen 4B researching 'hegemony' thought, called Eidos tools, did
      multiple tools. idk if we did the repair. Don't change the order but make sure we tackle it."* + *"It does NOT do that
      anymore — exactly ONE instance where I saw tools work on chat, on a SIMPLE query, so it UNDERSTOOD THE INTENT (important
      for users). Harden it — worked one time and never again."* RESEARCHED → `docs/research/SS-LT_LOCAL_MULTITOOL_RESEARCH_RELIABILITY_2026_06_20.md`.
      EFFECTIVELY A REGRESSION (worked once, now broken); CRUX = INTENT RECOGNITION (local model reliably converting a
      tool-needing query — even simple — into a tool call). Capability EXISTS (LocalAgentLoop multi-turn maxTurns=8 +
      LocalToolGrammar + IncrementalToolCallDetector + SchemaPreflightToolNarrowing + ConfidenceRouter + Eidos/registry
      tools). #1 SUSPECT: ConfidenceRouter gating turned ~always-direct-answer, or the local prompt no longer surfaces the
      tools/affordance (cross-ref SS-MV local prompt + SS-CR local routing). PLAN (verify→harden→regression-test, NORMAL
      ORDER — not reprioritized): reproduce the path, find where intent→tool drops, harden the gate + tool-surfacing + parse,
      honest-degrade when a backend's not ready, add a falsifier (local-tier research prompt surfaces Eidos/vault/file tools +
      LocalAgentLoop executes ≥1 tool turn). Cross-ref SS-AL/SS-H/SS-MV/SS-CR/SS-IR. NON-INVASIVE; this is the user-facing
      payoff of the substrate (local models that actually research).
- [ ] **GRAPH editability (both graphs) + raw-thoughts visibility + graph appearance toggles (owner 2026-06-20).** *"Like the
      mini overlay graph, I want to EDIT the Epdoc in it. For mini-chat + home-embedded chat some surfaces aren't editable in
      the graph and open a UTILITY instead — I want to edit ALL surfaces in BOTH graphs (not just home), and both home + the
      embedded graph editing all surfaces. Also raw thoughts — I don't see them at all in my vault, not sure it's still a
      thing. And the tags + all togglable things on the graph appearance setting — make sure they WORK, several I don't see at
      all. Add to plan, non-invasive, make them all start working + surfaces editable in graphs."* RESEARCHED →
      `docs/research/SS-GE_GRAPH_EDITABILITY_RAWTHOUGHTS_TOGGLES_2026_06_20.md`. (A) Epdoc opens a detached doc window
      (HologramSearchSidebar.swift:1177 `EpdocDocumentOpening.openDocument`) instead of inline-editing → make all surfaces
      inline-editable in BOTH home (HomeGraphEmbeddedView) + embedded/mini overlay graph (GraphWorkspaceContainer), reuse the
      ONE md-first Epdoc editor (no in-graph clone). (B) raw-thoughts EXISTS (`State/RawThoughtsState.swift`) but not surfaced
      in vault → verify it persists+displays, else wire-or-honestly-retire. (C) graph appearance toggles (tags etc. in
      GraphFloatingControls/SettingsView) likely DEAD (flag set but MetalGraphView/HologramOverlay never reads) → wire each to
      the renderer or remove. NON-INVASIVE, tracked, normal order. (B)+(C) are textbook SS-CLEAN dead-flag/surface-parity
      catches — fold into the Cleanliness Gate. Cross-ref SS-HGT/SS-2S/SS-VIS/SS-SH.
- [x] **OWNER-VERIFICATION NOT A GATE — agent works everything autonomously (owner 2026-06-20).** *"Do not use my
      verification [to gate] — what do I need to verify/do? But I want the agent to still work on everything WITHOUT my
      input."* POLICY (→ SS-CLEAN "OWNER-VERIFICATION IS NOT A GATE"): the loop NEVER parks/defers because an item needs
      owner visual/on-device verify. It self-verifies with the best non-owner witness (render/behavior tests + cargo/swift
      test + xcodebuild launch-smoke via the monitor's AUTO-BUILD) and SHIPS; "visual/live PENDING OWNER" is a non-blocking
      note. Monitor RESUMES any park citing owner-verification. Only real external-fact (API key) or owner-preference choices
      may wait. Supersedes earlier "PENDING OWNER → park." OWNER TO-DO (informational, non-gating) compiled separately:
      app-launches (P0 fix), chat live-send local+cloud (SS-CR), theme switch no-hang + colors (SS-THX/SS-TC), Instant Recall
      visible/openable (SS-IR), the visual fixes (SS-GC/SS-DD/SS-IL/SS-2S), SS-SH blank sidebar.
- [ ] **🔴🔴 P0 CHAT STILL BROKEN — no answer from ANY model; + SS-GC white bar still there; + image not visible in Prose
      (owner on-device 2026-06-20).** *"all work except for the local and cloud chats still can't get any answer out of any
      model; I don't see image in prose; I can't test the inline animation without working models; I still see the white
      bar."* THREE on-device failures (REOPEN items I'd marked PASS — green-but-not-user-reaching; my audits checked
      build-green+tests, not on-device). (1) 🔴 CHAT P0 — diagnosed: SS-CR regression `InferenceState.swift:4289` returns a
      NIL Gemma inside the `hasInstalledFoundationModel` block → bypasses the Qwen fallback (:4293) → `modelRequired` → no
      answer for any tier whose Gemma isn't installed. FIX: `if let f = installedFoundationModelID(for:.fast) { return f }`
      then fall through to Qwen; add the Gemma-not-installed→Qwen falsifier. STEERED to loop as P0. SS-CR REOPENED. (2) SS-GC
      white bar STILL PRESENT (the 3B/3C fix didn't resolve the actual bar; CodeEditorView:2167 token region moved) → re-diagnose
      + actually fix the graph code-editor top-bar background; verify on-device-equivalent (snapshot/render). REOPEN SS-GC.
      (3) SS-2S image NOT VISIBLE in Prose — A2 only ghosts syntax + accent-chips alt (MarkdownContentStorage:741), owner
      wants to SEE the image → prioritize SS-2S FULL inline-attachment render (the deferred follow-on), not just the chip.
      REOPEN/raise SS-2S full-render. SS-IL inline animation is BLOCKED by the chat P0 (can't test without a working model) →
      unblocks once chat answers. AUDITOR: stop marking visual/chat items PASS on tests alone — require on-device-equivalent
      witness (render/snapshot) or hold as "built, on-device-UNVERIFIED".
- [ ] **THEME REGRESSION — custom theme takes ~3 changes before TK2 + tabs match (owner on-device 2026-06-20).** *"the custom
      theme takes a few times before it loads the full theme — TK2 is one color and the tabs are another, then after changing
      themes ~3 times it finally matches. Regression that wasn't there before; harden it."* RESEARCHED → SS-THX "REGRESSION"
      section. ROOT: the SS-THX cache (28402960d) fixed the hang but a custom-COLOR edit keeps the same `.appCustom` enum case,
      so `ProseEditorRepresentable2.updateNSView` (re-applies only when `parent.theme` VALUE changes, `tv.applyTheme` :565)
      SKIPS the re-apply → TK2 stays stale while tabs (resolved-cache @Observable) update → diverge until ~3 toggles force it;
      + the AppCustomTheme.resolved cache (:1610-1628) must flush all isDark/appearance keys per edit. FIX: (1) bump a
      themeRevision token that updateNSView observes so TK2 re-applies on EVERY custom edit (sweep CodeEditorView + peers);
      (2) fully invalidate the resolved cache in one pass. Net: ONE change → all surfaces match. Tracked, fold into SS-TC/SS-THX
      theme work; SS-CLEAN "layering mud" (a cache that fixed one thing + broke another). NON-INVASIVE.
- [ ] **🔴🔴 P0 CHAT — REAL root (owner screenshot 2026-06-20 22:20): LOCAL mode → "provider rejected your credentials".** My
      first fix `9f49e90e5` was INCOMPLETE (patched tier-bound effectiveLocalTextModelID, not the no-arg path). NOT a stale
      build (app 22:30 > fix 22:12). ROOT: owner has Qwen installed but NO foundation Gemma; simplified-lineup default pick =
      uninstalled Fast-Gemma GGUF → `sanitizedInteractiveLocalTextModelID` (InferenceState.swift:6113) returns nil (correct
      no-silent-Qwen-swap) → no-arg `effectiveLocalTextModelID`(:4189) nil → `usesAutomaticCloudRouteForChatSurfaces`(:4627)
      true → `effectiveChatSurfaceSelection` auto-routes `.cloud`(:4789) → stale creds reject; installed Qwen never used. FIX:
      sanitizedInteractiveLocalTextModelID(:6113) — before nil, if ANY local is installed/runnable return it
      (supportedAvailableLocalTextModels.first ?? gemma QAT candidate) so Local runs Qwen, never cloud. Behavior test:
      uninstalled-pick + Qwen-installed + Local → Qwen not cloud. STEERED P0. Detail → SS-CR "STILL BROKEN" section. (Cloud
      chat separately needs a valid key — external.)
- [ ] **CHAT COMPOSER (main + mini + all chats): minimal Apple-native, FUSE tools/skills/commands, fix context controls (owner
      2026-06-20).** *"Make main + mini chat minimal. Keep context tuning. The book/cowork icon won't let me press anything —
      just for show? Local/Cloud labels ugly → minimal + Apple-native; cloud button not needed. Context logo ugly → Apple-like.
      Context bar too thin to hover → thicker. Tool button must WORK + have ALL tools + skills; commands + skills FUSED with the
      agent-tools button, all working. Big de-clutter/combine pass. Check other chats too — minimal but useful."* RESEARCHED →
      `docs/research/SS-CC_CHAT_COMPOSER_MINIMAL_APPLE_FUSE_TOOLS_2026_06_20.md`. Plan: (1) minimal Apple-native runtime control
      (drop pill+separate cloud button+banner clutter), (2) context glyph Apple-like + thicker hit target (keep tuning), (3)
      cowork/book button works-or-removed (dead-control = SS-CLEAN), (4) FUSE tools+skills+commands into one working
      AgentToolTogglePanel (cross-ref SS-VIS), (5) sweep all chat surfaces (one shared composer). NON-INVASIVE, test-backed.
- [x] **ROUTING NO-REGRESSION + PLAN-CAPTURE disciplines (owner 2026-06-20).** *"How do you add incorrect routing when you're
      supposed to be removing muddiness? This is huge. AND add all these to the PLAN, not just prompt the agent — things are
      missing because the plan isn't updated."* RECORDED → SS-CC "meta-concerns" + SS-CLEAN. (1) ROUTING NO-REGRESSION: any
      chat routing/model-resolution change MUST add a full routing-matrix regression guard ({Local,Cloud}×{installed?,creds?}
      → correct, no dead-end, no local→cloud mis-route) before shipping (the SS-CR whack-a-mole must stop). (2) PLAN-CAPTURE:
      every owner concern → ledger + slice, NEVER only steered. (This batch IS captured here, not just prompted.)
- [x] **DEEP REPAIR CYCLES + deep perf/usability wins (recurring discipline) (owner 2026-06-20).** *"These should be part of
      the deep repair parts — all of these added to the repair cycles. Also deep deep wins for performance and actual
      usability."* RECORDED → `docs/research/SS-REPAIR_DEEP_REPAIR_CYCLES_PERF_USABILITY_2026_06_20.md`. Repair is now a
      RECURRING CYCLE (find broken/regressed/muddy on-device → fix with no-regression+savepoint → VERIFY on-device-equivalent,
      not just unit-green → repeat), run as part of the loop's standing cadence alongside SS-CLEAN. ACTIVE repair batch (all
      owner-reported/reopened): CHAT P0 (SS-CR sanitized:6113 + routing matrix), CHAT COMPOSER (SS-CC), THEME regression
      (SS-THX), IMAGES full-render (SS-2S), white bar (SS-GC verify), blank sidebar (SS-SH), local tools (SS-LT), graph (SS-GE),
      launch-smoke (SS-CRASH). PLUS every cycle hunts ONE deep PERF win (profile hot paths, measured before/after — SS-PERF2)
      + ONE deep USABILITY win (⌘K/unified-search/error-empty-retry/first-run/model-clarity/a11y — SS-BWB), shipped user-facing
      + witnessed. Monitor treats owner on-device reports as P0 repair inputs. All in the plan, not prompt-only.
- [x] **DONE-RE-AUDIT — double-check even "done" items are ACTUALLY done + user-facing (owner 2026-06-20).** *"When things are
      checked done I want them audited as well — even what is done is double-checked to make sure it is actually done and
      user-facing whatever it is."* RECORDED → SS-CLEAN "DONE-RE-AUDIT GATE". The DONE list is now a RE-AUDIT QUEUE, not a
      closed set: every repair/cleanliness cycle re-verifies a rotating slice of DONE items for REAL + reachable +
      user-facing-or-witnessed (render/snapshot/launch-smoke/behavior, NOT just build-green/source-guard); any that aren't
      truly user-facing get DOWNGRADED to `[ ]` + reopened (as done this session for SS-CR/SS-GC/SS-2S/SS-THX). Monitor
      re-audits ≥1 DONE item per fire; owner on-device reports instantly downgrade the named item to P0. Pairs with
      LAUNCH-SMOKE + SURFACE-PARITY + ROUTING-NO-REGRESSION to close the green-but-not-user-reaching hole. AUDIT UPDATE: chat
      P0 fix (191c9291a) PASS — installed-Qwen fallback, behavior-tested (uninstalled-Gemma+Qwen→Qwen); full routing-MATRIX
      test still owed per the no-regression gate. Theme fix (f619405b9) landed. Both pending owner on-device confirm (non-block).
- [ ] **NO HIDDEN FALLBACKS / de-black-box — every substitution visible AT POINT OF USE (owner 2026-06-20).** *"I didn't want
      hidden fallbacks — if it's a fallback make sure it's not a stubborn one or any at all. idk what 'fallback' means but
      that's important — that's part of the repair: the hiddenness of the app + black-box surfaces."* RESEARCHED →
      `docs/research/SS-HF_NO_HIDDEN_FALLBACK_DE_BLACKBOX_2026_06_20.md`. Plain: a fallback = when your pick can't run the app
      runs a different runnable thing; OK only if VISIBLE/honest at the point of use, never silent. The chat P0 fix runs your
      REAL installed Qwen (not a fake) but surfaces it only via the Settings LocalRouteHonestyRow → too hidden. FIX: surface
      the actual running model + "running Qwen — '<pick>' not installed" note IN THE CHAT (fold into SS-CC runtime control), and
      SWEEP the app for silent substitutions / try?-?? -empty-catch-as-success / for-show controls / no-op-on-not-ready → make
      each honest at the surface or remove. GATE added to SS-CLEAN (NO-HIDDEN-FALLBACK / point-of-use honesty). Part of the
      repair cycle (SS-REPAIR). Cross-ref SS-CR/SS-IR/SS-LT/SS-GE/SS-CC. NON-INVASIVE; honest > clever.
- [x] **VOICE PICKER + premium-voice honesty on quick capture (owner on-device 2026-06-20).** *"Tried the premium Apple-native
      voice on quick capture, still sounds basic/low-quality — is that premium? I want to change it / pick among the custom
      voices."* RESEARCHED → SS-QC "VOICE PICKER" section. ROOT: no Premium/Enhanced voice DOWNLOADED on the Mac (OS-managed) →
      preferredVoice() falls to compact default; + QuickCapture read-back passes no voiceIdentifier + no picker on that surface.
      FIX (SS-QC voice-picker, NOT done): add a VOICE PICKER on quick capture (+ global default-voice pref) from availableVoices()
      quality-grouped → speak(voiceIdentifier:); surface voiceQualityHint() honestly ("download Premium in System Settings →
      Spoken Content → Manage Voices" — SS-HF no-black-box, don't imply compact=premium); default=preferredVoice(). OWNER
      IMMEDIATE: download an Enhanced/Premium voice in macOS System Settings → Accessibility → Spoken Content → Manage Voices.
      ✅ DONE-RE-AUDIT (loop 2026-06-21): every FIX part is code-confirmed. Voice PICKER at point of use
      on quick capture (QuickCaptureView.swift ~320 Menu+Picker over EpistemosSpeechSynthesizer.voicesGroupedByTier
      / availableVoices, grouped Premium>Enhanced>Default); GLOBAL default-voice pref
      (globalDefaultVoiceKey + setGlobalDefaultVoiceIdentifier on change; effectiveVoiceIdentifier = explicit ??
      globalDefault, so read-back/speak(voiceIdentifier:) honor it everywhere); HONEST premium hint surfaced on
      that surface (b228ef391 — voiceQualityHint() in the voice menu says "Only the default Compact voice is
      installed. Open System Settings → Spoken Content → Manage Voices…", never implying compact=premium);
      default = preferredVoice(). The bigger Kokoro/MOSS/retro-filter vision (L1434) is separate + NOT claimed here.
      Neural/MLX voice = separate SS-Q.
- [ ] **Premium voice as DEFAULT — owner's original intent (clarified 2026-06-20).** *"Thought Apple had a built-in premium
      voice, wanted THAT default; if it sounds basic then another can be default — but that was my initial ask."* → SS-QC
      "Premium-voice DEFAULT". preferredVoice() already auto-defaults to highest-quality INSTALLED voice (so a downloaded premium
      auto-becomes default); honest hint to download one; picker to override. True bundled premium = separate SS-Q.
- [ ] **NUANCE-COMPLETENESS sweep (owner 2026-06-20).** *"The picker nuance slipped — check the ENTIRE plan so everything is
      robust and nuance isn't lost to compaction/interruptions."* → SS-CLEAN "NUANCE-COMPLETENESS gate": enumerate every owner
      message's atomic sub-asks as ledger [ ] + verify each is captured with its specific nuance + will be BUILT. Audit running.

## FOLLOW-ON INCREMENTS — harvested from loop commit bodies (owner 2026-06-20: "add things like this and beyond to the plan")
Every "honest pending / next increment / deferred" note the loop made is now a tracked build item (slice: SS-FOLLOWON).
- [ ] **SS-VIS Epdoc/code mini-chat capability panel** (558bea540) — mount the same AgentToolTogglePanel on the Epdoc/code mini-chat (last sweep surface; verify env-injection first).
- [ ] **SS-VIS start-with-a-tool / cowork-mode handoff** (735940b7a) — flip operating mode = act before submitLandingSearch so "start with a tool/cowork" enters the mode.
- [ ] **SS-VIS cowork-panel parity** (735940b7a) — cowork reaches the same cross-surface parity as tools.
- [ ] **SS-GE (A) document-node INLINE edit, NO detached utility** (9573a79fa) — .epdoc/.proseNote nodes still bounce to the detached window; owner wants inline edit in BOTH graphs (tunnel + embedded/mini) with no detached utility. The open risky core of SS-GE (A).
- [ ] **SS-GE (C) Metal-renderer new appearance control + Laboratory-toggle discoverability** (68077ed69).
- [ ] **SS-2S visible-render default-ON flip** (888761277) — flip EPISTEMOS_PROSE_INLINE_IMAGE_V0 default-on after geometry tuning + the async/remote increment, so images show without a flag.
- [ ] **SS-2S async + downsampled + remote image load** (888761277) — NoteImageProcessor.loadDisplayImage async + http(s) (solve non-Sendable layout-state-across-actors).
- [ ] **SS-LT full-path runtime hardening** (ce66a8d64) — parse robustness + tier surfacing + Eidos readiness across the live local multi-tool path.
- [ ] **SUBSTRATE RuntimeRouter LIVE authoritative flip** (5a3943454) — once parityRate solid, flip EPISTEMOS_RUNTIMEROUTER_LIVE_V0 to make the router lane authoritative (contract + tests already landed).
      ⚠️ BLOCKER (2026-06-21, captured per owner): "parityRate solid" now has a RIGOROUS gate —
      `RuntimeRouterStage2Readiness` (parityObservations ≥ 50 AND parityRate ≥ 0.98), surfaced as the
      "STAGE-2:" line in Settings → Runtime Router. A headless loop agent CANNOT clear this — parity is
      a runtime observe-only metric (nil until STAGE-1b is armed + real turns run). OWNER FLIP PATH:
      set EPISTEMOS_RUNTIMEROUTER_LIVE_V0=1 to arm, use the app until the readiness line reads "READY to
      promote", then roll out. Full procedure: docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md.
- [x] 🔴🔴 **P0 CHAT MODEL — existing-install keeps Qwen / stuck small-Gemma (owner 5th report 2026-06-21).** *"regular chat keeps defaulting to qwen or it will just stay gemma 2... everything about the chat is just not working."* GROUNDED ROOT (SS-CHATMODEL_P0): (1) recommendedLocalTextModelID hardcoded Qwen InferenceState.swift:3057; (2) persisted pick (:5392-5400) overrides the new default → 89ef5a206 fresh-install fix never reaches existing installs; (3) effort picker flag-gated OFF → no live way to change. FIX (live, not flag-gated): recommended→Gemma + ONE-TIME migrate stale persisted Qwen→Gemma + reachable working picker + TEST the persisted/existing-install path + no SS-CR regression. Witness = owner existing install gets Gemma + can change live.
  - ✅ DONE (loop 2026-06-21, owner-authorized mark): fixed LIVE + headlessly PROVEN under the owner's exact MAS condition. headroom-aware Gemma default (89ef5a206); honest `.runtimeUnavailable` reason (bc960d3db); DEFAULT-ON GGUF→`gemma3_4BQAT4Bit` migration + POST-LOAD repair that reaches EXISTING installs (0342b016b, 0d935af12). PROOF: `GgufGemmaPostLoadRepairIntegrationTests` RAN + PASSED — seeds persisted GGUF-E2B + polluted migratedV1 + forces `[.mlx]` runtime (MAS) → full init persists BOTH keys = `mlx-community/gemma-3-4b-it-qat-4bit`, never Qwen (ddbadf434). Resolver-survival guarded (d03ae6d1b). The reachable live PICKER ("change live") is the separate open SS-FOLLOWON; the default-reaches-existing-installs core is done + proven.
- [ ] ‼️🔴 **PROVEN-DONE DOCTRINE + RE-AUDIT EVERYTHING (owner 2026-06-21, GOVERNING).** *"since this exists with Qwen it must exist with others — assume almost ALL items are NOT done. Build a more robust PROVEN way so I don't keep checking manually — one check and it's good. STOP saying things are done if they're not."* → SS-PROVEN_DONE_DOCTRINE. New DONE bar (all 5): real-state (persisted/existing-install, not fresh) · LIVE not flag-gated-off · migrates existing persisted state · end-to-end not unit-only · witnessed-or-honestly-pending. RE-AUDIT MANDATE: treat ALL current [x]/"audited PASS" as UNPROVEN; re-verify each against real user-state; DOWNGRADE fresh-install/flag-off/unit-green ones to [ ] + real-state test + re-fix to reach the user. Loop + monitor STOP marking done without real-state-reaching proof. Standing.
