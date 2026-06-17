# EPISTEMOS MASTER LOOP PROMPT (2026-06-17)

> **How to run this:** open a terminal in `/Users/jojo/Downloads/Epistemos`, run
> `claude`, and paste everything from the line `=== BEGIN LOOP ===` to the end.
> The prompt itself encodes the loop discipline. If you want it self-paced, run
> `/loop` first and paste it as the loop body. Do **not** add an interval — let
> it self-pace one slice at a time.
>
> This file is the source of truth for the backlog. The loop should re-read it
> at the top of each pass and update the "STATUS LEDGER" at the bottom as items
> land.

---

```
=== BEGIN LOOP ===

You are Claude Code working on Epistemos, a macOS-native PKM with on-device +
cloud AI. You are in a FOREVER LOOP. Your owner (Jordan, solo dev, M2 Pro 16GB)
has told you repeatedly: keep working and hardening, build + commit each slice,
and DO NOT stop to ask for permission or say "done and waiting." Only stop for a
genuinely destructive/irreversible action or an architecture fork you cannot
resolve from the code + docs.

────────────────────────────────────────────────────────────────────────
LOOP DISCIPLINE (every pass)
────────────────────────────────────────────────────────────────────────
1. RESEARCH-FIRST (CLAUDE.md rule): before touching anything, grep
   docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md, read the canonical source it
   names, then verify against current code + logs. Quick pass for simple edits,
   deep pass for architecture.
2. ONE SLICE = one focused change + its build + its commit. Never batch unrelated
   changes. Commit after EVERY change (the owner has lost work to an un-committed
   tree before — this is non-negotiable).
3. BUILD before commit:
   `xcodebuild -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | xcbeautify`
   Reaching CodeSign/link with 0 compile errors == compile OK. For tests:
   `xcodebuild build-for-testing -scheme Epistemos -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO`.
   Rust: `cargo test --manifest-path agent_core/Cargo.toml` (REAL execution —
   use it for backend hardening; never pkill cargo mid-run).
   NOTE: headless Swift TEST EXECUTION hangs — you can only COMPILE-verify Swift
   tests; the owner runs Product▸Test. So reason every test assertion to
   certainty before committing; a red unrunnable test is worse than none.
4. After each slice append one line to docs/AGENT_PROGRESS.md and tick the STATUS
   LEDGER in docs/EPISTEMOS_MASTER_LOOP_PROMPT_2026_06_17.md.
5. The owner is usually on an UN-rebuilt binary, so UI you can't see is risky.
   When you ship UI, ground it in the existing component (read the file), keep it
   behind the existing simplified-lineup flag where one exists, and never break
   the default local-only experience.

────────────────────────────────────────────────────────────────────────
NON-NEGOTIABLE HONESTY CONSTRAINTS (CLAUDE.md — these beat any task)
────────────────────────────────────────────────────────────────────────
• NEVER silently route to a model the user didn't pick. No hidden Qwen, no
  invisible fallback. If the selected local model can't run, surface a VISIBLE
  blocker (see P1.4) — never substitute silently.
• REAL APIs only. No fake features, no config UI for fields not wired to runtime.
• HONEST capability gating. Local models = chat + reasoning; multi-step tools via
  cloud or the Pro harness. Never fake agent capability for a local model.
• NO HIDDEN SIDECAR. GGUF/llama-cli is Pro-only + flag-gated
  (EPISTEMOS_LOCAL_GGUF_CLI_RUNTIME_V0), MAS-forbidden. In-process only on the
  MAS path. Runtime-plural / 70B is owner-gated.
• Keys in Keychain, NEVER UserDefaults. Stream every token. Preserve thinking
  blocks on tool_use. No try!, no force-unwrap, no print() in prod. Zero test
  regressions against the 2,679-test suite. Never commit model files.

────────────────────────────────────────────────────────────────────────
WHAT'S ALREADY DONE (do NOT redo — verify only if you touch it)
────────────────────────────────────────────────────────────────────────
Qwen removed from the picker + stored-selection migration onto the foundation
lineup; Fast/Think/Code tier source of truth (EpistemosFoundationLineup.swift);
mode buttons Fast/Think/Code; one-tap foundation-package install; Settings tier
display; icon-only collapsed model button; in-chat agent switcher (model popover
"Agents" section); Companion advanced config (custom system prompt + output
JSON); proven GGUF llama-cli runtime seam wired (Pro, flag-off); local
OpenAI/Ollama-compatible server (#46); VibeThinker-3B added as Think; Gemma
MLX/GGUF honest reconciliation; loop budgets raised 1/1/3 → 5/10/15; agentic
system-prompt manifest when tools present; main-chat context sidebar visible;
foundation-lineup regression tests.

────────────────────────────────────────────────────────────────────────
PRIORITY 1 — THE SIMPLE PICKER  (★ the owner keeps building and STILL sees the
ugly picker — this is the #1 broken thing. Fix it FIRST.)
────────────────────────────────────────────────────────────────────────
Current state (owner screenshot 2026-06-17): the popover still shows a "Runtime"
header, a "Routing → Fast → Gemma 4 12B QAT GGUF" row, a "Fallback on failure"
toggle, three separate Gemma model rows (E2B/E4B/12B each with "Agent OFF /
On-device model / info"), separate "Cloud Provider" + "Cloud Model" expanders,
and "Temporary Chat" — all in the main picker. The owner's words: "i dont want
taee see the messy model picker shit i literally want it ti be simple… it should
say fast and three efforts think and then code… it should not even have the
model… cloud can be like a toggle… when i send a query i can have a button that
says route to cloud model with the selected cloud one."

TARGET (the whole point):
  The default popover is THREE mode rows and almost nothing else:
     ⚡ Fast    — "Gemma 4, sized to the task"
     🧠 Think   — "VibeThinker reasoning"
     ⌘ Code    — "Gemma 4 12B coder"
  + one clean **Cloud** toggle (off by default).
  + a per-send **Route to cloud** button (only when a cloud provider is
    configured) that sends THIS query to the selected cloud model without
    changing the local default.
  Everything else (Runtime/Routing/Fallback/per-model rows/Cloud Provider+Model
  detail/Temporary Chat) moves behind a single collapsed "Advanced ▸" disclosure
  or into Settings. The model itself is NEVER shown as a required choice.

SLICES (build + commit each):
  P1.1  RootView.swift → LocalModelToolbarMenu.modelPopover: when
        EpistemosFoundationLineup.simplifiedLineupActive, render ONLY the three
        mode rows (Fast/Think/Code) + Cloud toggle. Move Runtime header, Routing
        row, Fallback toggle, the per-Gemma model rows, and Temporary Chat into a
        collapsed "Advanced ▸" DisclosureGroup (default closed). Keep the legacy
        full popover for the non-simplified flag.
  P1.2  Cloud as a single toggle: replace the "Cloud Provider / Cloud Model"
        twin expanders with one "Use cloud" Toggle bound to
        inference.setCloudModelsEnabled / activeAIProvider. When ON, show ONE
        compact "GPT-4o ▸" line that opens the provider/model detail (the
        existing pickerCloudSection) inside Advanced — not at top level.
  P1.3  Per-query "Route to cloud" button: add a button beside Send in
        Epistemos/Views/Chat/ChatInputBar.swift (sendButton area), visible only
        when a cloud provider is configured. It must route THIS turn to the
        preferred cloud model WITHOUT mutating the persistent local selection.
        onSubmit today carries only text → add a per-turn routing override:
        thread an optional `routeOverride: ChatModelSelection?` from
        ChatInputBar.onSubmit → ChatView → ChatCoordinator so one send can go
        cloud while the default stays local. Honest: if no cloud configured, no
        button.
  P1.4  Honesty blocker (#43): when the effective local selection can't actually
        run (dynamic free memory too low — mirror fittingLocalAgentTextModelID's
        localAgentModelFitsCurrentMemoryBudget for the primary chat model),
        DISABLE Send and show a one-line reason ("Not enough free memory for
        Gemma 4 12B — free memory, pick a smaller tier, or route to cloud").
        Never silently swap. Add a pure-logic helper + reasoned compile-verified
        test.
  P1.5  Fast "three efforts" = per-query complexity sizing: Fast auto-picks
        E2B (trivial) → E4B (medium) → 12B (hard) per query via
        OverseerComplexityRouter. Needs a streamGeneral seam that passes the
        per-turn sized model down. Keep the explicit within-tier pick override
        (already respected by effectiveLocalTextModelID(for:)).

────────────────────────────────────────────────────────────────────────
PRIORITY 2 — FULL AGENTIC CHAT (Codex / Claude-desktop parity)
"make my chat an actual codex or claude desktop app with full agentic behavior,
using local AND cloud models, diff + git access, skills/superpowers, mcps,
dependencies — all of it, accessible through the chat. agents + app search the
memory, give it all the control it can get." (OpenCode comes LATER, only once the
chat has everything.)
────────────────────────────────────────────────────────────────────────
The BACKEND already exists — agent loop, tools (agent_core/src/tools/registry.rs:
memory / knowledge.recall / skills / file_ops / web_fetch / shell / browser), MCP
backend (omega-mcp + MCPBridge), Companion system, AgentCommandCenterState tool
catalog (toolToggles / availableTools / toggleTool / refreshToolCatalog). The gap
is CHAT SURFACING. Build a "capability explorer" reachable from the composer:
  P2.1  In-chat TOOL TOGGLES: a compact panel (reuse AgentCommandCenterState)
        listing available tools with on/off, so the user sees + controls what an
        agent can do. Honest gating: tools that need cloud/Pro are labeled.
  P2.2  MEMORY access affordance: confirm memory + knowledge.recall tools are
        available to agents by default and surface a visible "Searching memory…"
        capability (the owner explicitly wants agents to search memory). Verify
        the tools actually read the app-side vault/Knowledge Core.
  P2.3  MCP MANAGEMENT UI in chat: add/enable/disable MCP servers via MCPBridge
        (Pro). Honest: only show servers actually wired.
  P2.4  In-chat SKILL creation + browser (agent_core/src/agent_runtime skills +
        procedural memory). Let the user create/run a skill from chat.
  P2.5  GIT + DIFF as tools (Pro): surface git status / diff / commit / branch as
        agent tools with the subprocess hardening in agent_core/src/security.rs.
        MAS build must not expose shell/git; Pro only.
  P2.6  Agent meta-builder (#47): extend the Companion (the tamagotchi — KEEP the
        fluid animation) with an osaurus-style Agent config (name, system prompt,
        tool selection, output schema). Foundation landed 2f3ae4a5c +
        CompanionCreationFlow advanced config. Only expose fields wired to
        runtime (no fake config).

────────────────────────────────────────────────────────────────────────
PRIORITY 3 — OSAURUS DEEP DIVE (cherry-pick, NEVER fork)
"so many things in osaurus that I know can be copied or cherry-picked… 400k of
swift." Adopt patterns natively (native Swift, MIT) — do NOT port the repo.
────────────────────────────────────────────────────────────────────────
  P3.1  Deep-read osaurus; write docs/OSAURUS_DEEP_DIVE_2026_06_17.md mapping
        every reusable pattern → where it lands in Epistemos (agent_core / Omega
        / Companion / local server). ~80% overlaps the existing stack; extract
        the 20% that's genuinely new.
  P3.2  Verify the local OpenAI/Ollama server (#46, ResponseWriters/OsaurusServer
        shape) is wired + MAS-safe (no subprocess from the notarized app).
  P3.3  Sentinel stream + dynamic-tool schema → fold into agent_core tool-call
        parsing where it beats the current path.
  P3.4  Containerization sandbox (Pro-only) for isolated tool execution — gate
        behind pro-build, never on the MAS path.

────────────────────────────────────────────────────────────────────────
PRIORITY 4 — MODEL SUBSTRATE POLISH
────────────────────────────────────────────────────────────────────────
  P4.1  unsloth for Gemma fine-tuning (#44): research + document an OFFLINE
        fine-tune lane (NOT runtime) that produces GGUF the existing llama-cli
        lane already runs. docs/ only until owner approves a model.
  P4.2  EAGLE3 speculative decoding (#49, llama.cpp #18039) for 2-3× GGUF
        speedup — research + a flag-gated draft-model seam in the GGUF runtime.
  P4.3  Grammar tool loop on-device validation (#41): FFI json_schema is wired
        (run_local_gguf_generation + with_json_schema); validate the local Pro
        tool loop end-to-end with `llama-cli --json-schema` honest Gemma tools.
  P4.4  Routing rules: make local-vs-cloud + complexity routing explicit and
        honest (TriageService / ConfidenceRouter / OverseerComplexityRouter) —
        a readable "why this route" the picker/diagnostics can show.

────────────────────────────────────────────────────────────────────────
PRIORITY 5 — ARCHITECTURE  (owner: the NON-large-model work is MORE important
than the 70B — do it FIRST, then the 70B.)
────────────────────────────────────────────────────────────────────────
Non-large-model architecture (pick from the canonical register, research-first):
  • Knowledge Core cutover (flag knowledgeCoreRuntimeV0): production-UI binding
    decision + content-subscription (see memory kc_cutover_slice3).
  • Cognitive DAG (Phase 8) + Provenance console + Halo + Simulation assets +
    Schema-First GenUI dispatcher + XPC mastery — per docs/fusion canon and the
    Substrate Track Register T0–T15. Each is a real, shippable, MAS-scoped slice;
    promote only to T4+ per ARCHITECTURE_TIER_PROMOTION_CANON (compiled in the
    right scope, reachable, visible, verified, logged, rollback-bound,
    AnswerPacket-visible).
THEN large-model:
  • P4/#17 70B System G custom runtime — already BUILT + owner-gated
    (agent_runtime_v2/system_g_runtime.rs + RealSystemGRunSeam.swift /
    RuntimeRouter / AnswerPacket / SovereignGate). Runtime acceleration stays a
    CANDIDATE until explicit owner approval + MAS/Pro boundary review +
    no-hidden-fallback proof + RunEventLog + AnswerPacket + rollback + harness
    witnesses land. Do NOT arm without the owner.

────────────────────────────────────────────────────────────────────────
KEY FILES
────────────────────────────────────────────────────────────────────────
Picker/UI:      Epistemos/App/RootView.swift (LocalModelToolbarMenu, modelPopover,
                splitToolbarControls, ChatBrainPickerMenu),
                Epistemos/Views/Chat/ChatInputBar.swift,
                Epistemos/Views/Settings/SettingsView.swift (LocalModelManagerSheet)
Lineup truth:   Epistemos/Engine/EpistemosFoundationLineup.swift,
                Epistemos/Engine/LocalModelInfrastructure.swift (GemmaQATRuntimeLadder),
                Epistemos/State/InferenceState.swift (effective/fitting model resolution)
Agentic:        agent_core/src/tools/registry.rs, agent_core/src/agent_loop.rs,
                Epistemos/State/AgentCommandCenterState.swift,
                Epistemos/Omega/MCPBridge.swift, Epistemos/App/ChatCoordinator.swift,
                Epistemos/State/Companion/CompanionState.swift,
                Epistemos/Views/Landing/Farm/CompanionCreationFlow.swift
Runtime seam:   agent_core/src/bridge.rs (run_local_gguf_generation),
                Epistemos/Bridge/LocalGgufRuntimeBridge.swift,
                Epistemos/Engine/LocalGgufCliRuntime / PipelineService.swift
Research index:  docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
Progress:        docs/AGENT_PROGRESS.md, docs/APP_ISSUES_AUTO_FIX.md

────────────────────────────────────────────────────────────────────────
START NOW. Begin with P1.1 (strip the picker to three mode rows + Cloud toggle,
Advanced disclosure for the rest). Build, verify, commit, then continue down the
list WITHOUT stopping to ask. Keep going until every priority is done, then
re-read this file and harden.
=== END LOOP ===
```

---

## STATUS LEDGER (the loop updates this)

| ID | Item | Status |
|----|------|--------|
| P1.1 | Picker → three mode rows + Advanced disclosure | ✅ DONE (2026-06-17) |
| P1.1b | Fix root cause: GGUF Gemma collapsed modes to Fast-only | ✅ DONE — `operatingModeCapabilities` offers Fast/Think/Code under simplified+foundation |
| P1.2 | Cloud as one clean toggle | ✅ DONE (folded into P1.1) |
| P1.3 | Per-query "Route to cloud" button + onSubmit override | ☐ TODO (next) |
| P1.4 | Honesty blocker: visible when local model can't run (#43) | ☐ TODO |
| P1.5 | Fast "three efforts" per-query complexity sizing | ☐ TODO |
| P2.1 | In-chat tool toggles | ☐ TODO |
| P2.2 | Agents search memory (verify + surface) | ☐ TODO |
| P2.3 | MCP management UI in chat | ☐ TODO |
| P2.4 | In-chat skill creation + browser | ☐ TODO |
| P2.5 | Git + diff as Pro tools | ☐ TODO |
| P2.6 | Agent meta-builder on Companion (#47) | ◐ foundation landed |
| P3.1 | osaurus deep-dive doc | ☐ TODO |
| P3.2–3.4 | osaurus server verify / sentinel stream / sandbox | ☐ TODO |
| P4.1 | unsloth fine-tune lane (research) (#44) | ☐ TODO |
| P4.2 | EAGLE3 spec decoding (#49) | ☐ TODO |
| P4.3 | Grammar tool loop on-device validation (#41) | ◐ FFI wired |
| P4.4 | Explicit honest routing rules | ☐ TODO |
| P5 | Non-large-model architecture, then 70B (#17) | ☐ TODO |
