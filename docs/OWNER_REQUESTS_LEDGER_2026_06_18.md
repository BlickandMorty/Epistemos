# OWNER REQUESTS LEDGER (2026-06-18) — the authoritative checklist

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
- [ ] **Palette preview for ALL themes** — currently gated `if pair == .custom`
      (SettingsView ~4081). Generalize `CustomThemePaletteSwatch` to every
      `ThemePairCard` so every theme shows the palette preview.
- [ ] **Custom-theme font** — claimed fixed (4b0a5e59e); VERIFY in-app that picking
      a font on the custom theme actually changes rendered text, every level.

## Picker / routing / honesty
- [x] Think → VibeThinker, never Gemma 12B (P1.6) — verify still true on all paths.
- [x] No hidden Qwen on tool/attachment seam (P1.10) — verify in-app with attach.
- [x] Apple Intelligence selectable native route (P1.7) — verify visible.
- [x] Download/install progress visible (P1.8) — verify a real install shows it.
- [x] Fast low/med/high effort visible (P1.9) — verify the composer hint shows.
- [ ] Vault "best essay in my vault" returns ranked answer w/ title/path/reason,
      not a generic reply or empty "no vault retrieval" (P2.2 — still partial).

## Chat capability + parity
- [ ] Capability ceiling Fast→tools, real on LOCAL (P7.1) — verify tools actually
      run from chat on a local model, not just documented.
- [ ] MiniChat / Note / Graph chat parity — verify each surface really has the
      Main-chat capabilities in-app (P7.5).
- [ ] Tool toggles actually gate the runtime AND are visible/usable (P2.1).
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
      testing).** Owner (verbatim): *"I can't download any models, so there are many
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
