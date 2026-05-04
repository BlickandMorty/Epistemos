# Epistemos Pro — A unified architectural doctrine

## 1. Unified thesis

Epistemos Pro is a native macOS cognitive workspace whose load-bearing claim is **provenance, not generation**: every model output is a derived artifact of a typed graph that the app — not the model — owns. A Rust core (`substrate-core`) is the single source of truth for artifacts, sessions, claims, and events; a Swift 6 shell renders a closed palette of ~25 native components driven by an A2UI-v0.9 catalog the Rust core publishes; cloud agents (Claude Code, Codex, Gemini, Kimi) are **routable providers** subprocess-spawned through their official non-interactive flags; Hermes Agent is **both** an embedded faculty (subprocessed via ACP, not the chat CLI) **and** one of those routable providers; Apple Foundation Models and MLX-Swift Qwen3-4B / Qwen3.5-35B-A3B form a three-tier local strategy that handles single-turn tool use, bounded ReAct, and structured-output tasks before any cloud call; a deterministic Research Kernel and a Cognitive AutoResearch engine share one claim ledger and one source-scoring contract; and a Metal renderer subscribes to a `GraphEventStream` from Rust, not to NotificationCenter. Nothing in the architecture relies on runtime SwiftUI codegen, hidden chain-of-thought reconstruction, or unverified vendor primitives. The doctrine is opinionated to the point of being intolerant: deviations from the canonical envelope, the permission ladder, the audit-loop status vocabulary, or the performance contract are treated as defects, not preferences.

---

## 2. Decisive answers to the 14 unification questions

**Q1 — Hermes vs. cloud coding agents.** Hermes is **one team among many**, not the meta-orchestrator. The Epistemos Agent Runtime (Rust) is the top-level router. Hermes earns a privileged position only as the **default Co-op Mode foreman** when the user explicitly invokes Co-op (because Hermes already has a mature multi-channel cron + delegation surface and ACP). In single-shot or Chat-mode runs, the Epistemos router decides; Hermes is just a provider with `provider_kind = HermesAcp`. This avoids the "Hermes wraps everything" failure mode where Epistemos would inherit Hermes' Python-and-bash shape.

**Q2 — Unified UI palette and envelope.** **A2UI v0.9** (`https://a2ui.org/specification/v0.9-a2ui/`) is the canonical envelope, with a single Epistemos catalog (`https://epistemos.app/catalogs/v1/native.json`) generated from a `schemars`-derived internally-tagged enum in `substrate-core`. The same envelope drives PKM surfaces (scratchpad, todo, planner, thinking display, note views, graph nodes) and Hermes pass-through (Hermes commands materialize as `AgentToolCall` and `SkillInvocation` variants in the catalog). MCP Apps SEP-1865 (`ui://`, HTML-in-iframe) is supported as an **input adapter only** — when a third-party MCP server returns `ui://`, we render it in a sandboxed `WKWebView` with the SEP-1865 postMessage dialect; we never emit `ui://` for our own surfaces. AG-UI is adopted as the **transport** for streaming agent state inside Hermes pass-through; A2UI rides inside AG-UI events. Streaming is `updateComponents` + `updateDataModel`; partial JSON is healed at the catalog boundary.

**Q3 — Cognitive Artifact System vs. Hermes session subgraph.** **One graph, two layers, one identity scheme.** ArtifactKind nodes (`ProseNote`, `Document`, `RawThought`, `Source`, `Code`, `Run`, `Output`, `Claim`, `Skill`) and Hermes session nodes (`HermesSession`, `HermesTurn`, `HermesToolCall`, `HermesSkillInvocation`, `HermesMemory`) live in the same SQLite-backed graph with the same ULID identity space and the same edge taxonomy (`links_to`, `derived_from`, `generated_by`, `produced_during`, `references`, `validated_by`, `superseded_by`, `contradicted_by`, `loop_emitted`). A `HermesSession` is just a `Run` with `run_kind = HermesAcp`. Skills are first-class `Skill` nodes; Hermes loads them by **materializing graph nodes into `~/.hermes/skills/<name>/SKILL.md` in a sync-daemon-controlled directory listed in `skills.external_dirs`**, since the FS loader is hard-wired (verified at hermes-agent.nousresearch.com/docs/user-guide/features/skills).

**Q4 — Deep Deliberation vs. Co-op Mode.** Deep Deliberation is **a special-cased Co-op Mode configuration with three differences**: (a) mandatory role taxonomy (Optimist/Pessimist/Neutral × Moderator/Clerk/Researcher/Skeptic/Contrarian/Synthesist/Domain/Jury), (b) a `DeliberationProtocol` that gates turn order and forces every assertion through the claim ledger before it can become a vote, (c) mandatory final artifact set (transcript, claims.json, disagreements.md, jury-votes.json, final-verdict.md, minority-reports.md, start-new-session.md). Both run on the same orchestrator (`agent_runtime::CoOp`), the same claim ledger (`research_kernel::ClaimLedger`), and the same scoring (`research_kernel::Scoring`). Team overlays (Research/Oracle/Geometry/Code/Critic/Memory/Automation/Editorial) are **orthogonal capability groups**, not protocols; Deep Deliberation can summon any team overlay as a Domain Expert.

**Q5 — Cognitive AutoResearch vs. Research Kernel.** AutoResearch is **a scheduler, not an engine**. Every nightly Deeper Thoughts run, every weekly consolidation, and every user-invoked Scout/Standard/Deep/Ultra run is a configured invocation of the Research Kernel's deterministic 10-stage SOAR pipeline against a different `ResearchWorld` (a typed scope: vault subset, time range, predicate filter). One `ClaimLedger`, one `SourceScoring`, one `AuditPass`, one `BeliefDriftDetector`. AutoResearch contributes only the cron, the ResearchWorld scope contracts, the keep/promote/archive rules, and the start-new-session.md compositor.

**Q6 — Instant Recall as a unified subsystem.** Instant Recall is **a single Rust actor (`instant_recall::Actor`)** exposing one async API: `recall(query, gates, budget) -> RecallBundle`. Every consumer (chat composer, agent runtime, AutoResearch, Deliberation, Hermes ACP bridge) calls the same function with different gate weights (semantic / situational / action). It is not a notification stream; it is a request/response service with a hot in-memory ANN index plus FTS5 fallback, recomputed incrementally on graph mutations. Performance budget below.

**Q7 — Worktree-based engineering operations.** **Both internal dogfooding tool and shipped feature**, gated behind a Pro-only "Agent Workbench" view. Same Rust crate (`agent_runtime::worktree`), same orchestrator. Workbench surfaces missions, lanes, diffs, and merge gates as A2UI components; the same primitives are used internally to coordinate Claude Code / Codex / Kimi / Cursor when the user (or AutoResearch) launches a multi-agent engineering task.

**Q8 — Ultra Mode pipeline.** Ultra Mode wraps the same three-pass design (Extraction → Analysis → Synthesis+Audit) around a fan-out runner (`browser_runner::UltraFan`) that drives `chromiumoxide` against the user's existing Chrome profile (cookie reuse) for Claude Deep Research, Gemini Deep Research, and ChatGPT Deep Research **only when no programmable API exists** (Anthropic) or when the user prefers the Pro UX surface; otherwise it uses the official APIs (`o3-deep-research-2025-06-26`, Gemini Interactions API `deep-research-max-preview-04-2026`, Exa `exa-research-pro`, Perplexity `sonar-deep-research`). All five returns flow into the **same** ClaimLedger; the Synthesis+Audit pass is one Research Kernel invocation that cross-reads them.

**Q9 — Runtime architecture.**
- **Agent loop lives in Rust core via UniFFI**, exposed both as `agent_runtime::run_turn` (in-process) and as MCP tools (`epistemos-mcp`) for external clients. Not duplicated.
- **Hermes-as-subprocess talks to substrate-core over stdio MCP**: Hermes spawns `epistemos-mcp` as a child (per its `mcp_servers:` config in `~/.hermes/config.yaml`), and Epistemos spawns `hermes acp` (NOT `hermes chat`) as a child for the embedded-faculty channel. ACP JSON-RPC 2.0 over stdio (Content-Length framed) is the canonical Hermes channel because `hermes chat -q --quiet` does not emit a structured event stream.
- **Swift coordinates with Rust via UniFFI** for control plane (sessions, mutations, A2UI payloads) and **a hand-written `extern "C"` SPSC ring buffer** for the GraphEvent hot path. Token streams stay on UniFFI callback interfaces (50–100 tok/s is far below UniFFI's overhead floor).
- **GraphEventStream → Metal at 120fps:** Rust emits `GraphEvent { kind, node_id, edge_id, timestamp_ns }` into the SPSC ring; a Swift `GraphEventStream` actor drains the ring on a `MTKView`-attached display link, batches events per frame, and feeds a `MetalRenderer` whose pipeline state is precompiled at app launch (no main-thread compilation).
- **Cancellation:** `⌘.` posts to a single `CancellationToken` that owns: (a) every in-flight `tokio::task` via `tokio::sync::watch`, (b) every subprocess via `Child::kill_on_drop(true)` plus explicit SIGINT-then-SIGTERM-after-150ms ladder, (c) every UniFFI callback via the shared `CancellationToken::is_cancelled()` polled in inner loops, (d) MLX streams via `.stop` return from `didGenerate`. Budget: <200ms. UniFFI does not auto-propagate Swift `Task.cancel()` (verified at mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html), so we expose `cancel()` explicitly.
- **OSSignposter**: every hot path is bracketed (`recall.gate`, `agent.turn`, `provider.stream_token`, `graph.mutate`, `metal.frame`, `mcp.dispatch`, `acp.session_update`, `kernel.stage`); Instruments templates ship with the dev build.
- **Mutation envelopes**: every graph write produces a `MutationEnvelope { affected_node_ids, affected_edge_ids, scope }`; subscribers register interest by `(NodeKind, ScopeFilter)` and only get woken when the envelope intersects their predicate. NotificationCenter is forbidden in render and recall paths.

**Q10 — Performance contract.** Enumerated in §14.

**Q11 — Module layout.** Enumerated in §17.

**Q12 — Safety/security.** Enumerated in §15.

**Q13 — Audit-loop discipline.** Enumerated in §19.

**Q14 — Slice ordering.** Enumerated in §18.

---

## 3. Complete runtime architecture

```
                        ┌─────────────────────────────────────────────────┐
                        │                  SwiftUI shell                  │
                        │  Two-mode UI (Chat/Agent) · Effort axis · Cmd.  │
                        └─────────────────────────────────────────────────┘
                                          │ A2UI envelope (UniFFI)
                                          ▼
        ┌──────────────────────────────────────────────────────────────────────┐
        │              SchemaViewRegistry (Swift, 25 components)               │
        │   NoteCard · BacklinkList · GraphView · ScratchPad · TodoBoard ·     │
        │   PlannerLane · ThinkingDisplay · ClaimLedgerCard · DiffReview ·     │
        │   AgentToolCall · SkillInvocation · CitationRail · DriftBadge · ...  │
        └──────────────────────────────────────────────────────────────────────┘
                                          ▲
                                          │ A2UI updateComponents/updateDataModel
                                          │
   GraphEvent SPSC ring ◀────────┐        │              token-stream callbacks
   (extern "C" zero-copy)        │        │              (UniFFI callback iface)
            │                    │        │                       │
            ▼                    │        │                       ▼
   ┌────────────────┐    ┌───────────────────────────────────────────────┐
   │ MetalRenderer  │    │              Rust substrate-core               │
   │ (120fps,       │    │  ┌────────────┐  ┌──────────────────────────┐ │
   │  precompiled   │◀───┤  │ entity_    │  │      agent_runtime       │ │
   │  pipelines)    │    │  │ graph      │  │ ┌─────────┐ ┌──────────┐ │ │
   └────────────────┘    │  │ (ULIDs,    │◀─┤ │ router  │ │ co_op    │ │ │
                         │  │ edges,     │  │ └─────────┘ └──────────┘ │ │
                         │  │ FTS5)      │  │ ┌─────────┐ ┌──────────┐ │ │
                         │  └────────────┘  │ │delib_   │ │ worktree │ │ │
                         │  ┌────────────┐  │ │protocol │ │          │ │ │
                         │  │ providers  │  │ └─────────┘ └──────────┘ │ │
                         │  │ ┌────────┐ │  └──────────────────────────┘ │
                         │  │ │claude  │ │  ┌──────────────────────────┐ │
                         │  │ │codex   │ │  │      research_kernel     │ │
                         │  │ │gemini  │ │  │  10-stage SOAR pipeline  │ │
                         │  │ │kimi    │ │  │  ClaimLedger · Scoring   │ │
                         │  │ │hermes_ │ │  │  AuditPass · DriftDetect │ │
                         │  │ │  acp   │ │  └──────────────────────────┘ │
                         │  │ │mlx_*** │ │  ┌──────────────────────────┐ │
                         │  │ │found_  │ │  │ autoresearch (scheduler) │ │
                         │  │ │  models│ │  │  daily/weekly cron       │ │
                         │  │ └────────┘ │  └──────────────────────────┘ │
                         │  └────────────┘  ┌──────────────────────────┐ │
                         │  ┌────────────┐  │     instant_recall       │ │
                         │  │ tools +    │  │  semantic+situational    │ │
                         │  │ permission │  │  +action gates · ANN     │ │
                         │  │ ladder     │  └──────────────────────────┘ │
                         │  └────────────┘  ┌──────────────────────────┐ │
                         │  ┌────────────┐  │    mcp_server (epist-)   │ │
                         │  │ hermes_    │  │    mcp_client (consumes  │ │
                         │  │ bridge     │  │      user's servers)     │ │
                         │  └────────────┘  └──────────────────────────┘ │
                         │  ┌─────────────────┐ ┌──────────────────────┐│
                         │  │ browser_runner  │ │   persistence (GRDB  ││
                         │  │ (chromiumoxide, │ │   FTS5 + .epdoc pkg  ││
                         │  │  Lightpanda)    │ │   + events.jsonl)    ││
                         │  └─────────────────┘ └──────────────────────┘│
                         │  ┌─────────────────────────────────────────┐ │
                         │  │  telemetry (OSSignposter bridge)        │ │
                         │  └─────────────────────────────────────────┘ │
                         └──────────────────────────────────────────────┘
                              │                                        │
                              ▼                                        ▼
                ┌───────────────────────────────┐    ┌────────────────────────────┐
                │ Subprocess providers (stdio)   │    │ External MCP/CLI surfaces  │
                │  · claude -p --output-format    │    │ Claude Desktop / ChatGPT / │
                │    stream-json                 │    │ Cursor / Zed consume       │
                │  · codex exec --json           │    │ epistemos-mcp via stdio    │
                │  · gemini -p --output-format   │    │ Streamable HTTP            │
                │    json                        │    │                            │
                │  · hermes acp (JSON-RPC 2.0)   │    │ Hermes spawns epistemos-   │
                │  · MLX-Swift (in-proc)         │    │ mcp as a child per its     │
                │  · FoundationModels (in-proc)  │    │ mcp_servers: config        │
                └───────────────────────────────┘    └────────────────────────────┘
```

Crate tree given in §17.

---

## 4. The unified schema-driven UI palette

The catalog is a single Rust enum, internally tagged on `component`, derived via `schemars`. The catalog URI is pinned per release.

```rust
// substrate-core/src/ui/catalog.rs
#[derive(Serialize, Deserialize, JsonSchema)]
#[serde(tag = "component", rename_all = "PascalCase")]
pub enum EpistemosComponent {
    // PKM core
    ScratchPad      { id: ULID, body_ref: DataPath, autosave_interval_ms: u32 },
    TodoBoard       { id: ULID, lanes: Vec<DataPath>, drift_overlay: bool },
    PlannerLane     { id: ULID, horizon: PlannerHorizon, items: DataPath },
    NoteCard        { id: ULID, title: DynamicString, body_ref: DataPath, tags: Vec<String>, status: NoteStatus },
    DocumentHost    { id: ULID, epdoc_path: PathRef, readonly: bool },
    BacklinkList    { id: ULID, source: DataPath, dedup: bool },
    GraphView       { id: ULID, root_node: DataPath, depth: u8, layout: GraphLayout },
    CitationRail    { id: ULID, claims: DataPath, scoring: ClaimScoringMode },
    // Cognition
    ThinkingDisplay { id: ULID, run_id: DataPath, mode: ThinkingMode /* observable_only */ },
    ClaimLedgerCard { id: ULID, ledger: DataPath, filter: ClaimFilter },
    DriftBadge      { id: ULID, note_id: DataPath, status: DriftStatus },
    DeliberationView{ id: ULID, run_id: DataPath, role_filter: Option<RoleSet> },
    JuryVoteTally   { id: ULID, run_id: DataPath },
    // Agentic
    AgentToolCall   { id: ULID, provider: ProviderKind, tool: String, args_ref: DataPath, state: ToolCallState },
    SkillInvocation { id: ULID, skill_node: DataPath, source: SkillSource },
    DiffReview      { id: ULID, worktree: PathRef, hunks: DataPath, decision: DiffDecision },
    WorktreeLane    { id: ULID, mission_id: DataPath, agent: ProviderKind, status: LaneStatus },
    LoopProfileEditor { id: ULID, profile_id: DataPath },
    // Research
    SourceScoreList { id: ULID, sources: DataPath },
    ContradictionMap{ id: ULID, claims: DataPath },
    ResearchBriefHost{ id: ULID, brief_node: DataPath },
    // Bootstrap & state
    BootstrapStatus { id: ULID, stages: DataPath /* CLI discovery, MLX preload, ... */ },
    PermissionPrompt{ id: ULID, request: DataPath /* maps to permission ladder */ },
    KillSwitchOverlay{ id: ULID, in_flight: DataPath },
    // External UI bridge
    McpAppFrame     { id: ULID, ui_uri: String, csp: CspPolicy }, // sandboxed WKWebView for SEP-1865 input
}
```

**Streaming behavior.** The Rust core emits `A2UIMessage::UpdateComponents { surface_id, additions, replacements, removals }` and `A2UIMessage::UpdateDataModel { surface_id, patch }` as JSON Patch deltas. Token streams flow through `DynamicString` data paths, so a `ThinkingDisplay` or `NoteCard.body_ref` can fill in token-by-token without re-rendering the component tree. Partial JSON heals at the catalog boundary using A2UI v0.9's prompt-generate-validate loop; failures emit `VALIDATION_FAILED { surfaceId, path, code, message }` back to the LLM.

**Accessibility.** Every component emits `accessibility: { label, traits, hint }` in its A2UI payload. SwiftUI registry maps these to `.accessibilityLabel`, `.accessibilityAddTraits`, `.accessibilityHint`. Dynamic Type is honored via `@ScaledMetric` on every typography token. VoiceOver order is dictated by adjacency-list children order (deterministic).

**Closed palette discipline.** No component is added without (a) Props struct in this enum, (b) SwiftUI registry entry, (c) catalog version bump, (d) snapshot test, (e) signpost coverage. The LLM cannot emit any other component; unknown `component` values are dropped at the Rust deserializer with a structured `VALIDATION_FAILED`.

---

## 5. Unified entity/graph model

**Identity.** ULIDs everywhere (`ulid::Ulid` in Rust, monotonic-per-millisecond, 26-char Crockford). Generational slotmap keys are an in-memory cache layer keyed by ULID; they never escape `substrate-core`. ULIDs are stable across compactions and exports.

**Persistence.** SQLite via GRDB (Swift side never writes — only reads via UniFFI). Tables:

| Table | Purpose | Key indexes |
|---|---|---|
| `nodes` | typed node rows; `kind` enum | `(kind, updated_at DESC)`, `(kind, status)` |
| `edges` | typed edges with `(src_ulid, dst_ulid, kind)` PK | `(src, kind)`, `(dst, kind)` |
| `node_blobs` | large bodies (ProseMirror JSON, code), content-hashed | `content_sha256` |
| `readable_blocks` | flattened blocks for FTS5 (external-content) | FTS5 virtual table `readable_blocks_ft` |
| `events` | append-only event log mirror of `events.jsonl` per run | `(run_ulid, seq)` |
| `claims` | claim ledger rows | `(run_ulid, score DESC)` |
| `sources` | source scoring rows | `(domain, score)` |
| `runs` | every agent/research/deliberation run | `(kind, started_at)` |
| `mutation_envelopes` | recent envelopes for replay | `(timestamp DESC)` |

**Node kinds (unified).**
`ProseNote, Document(.epdoc), RawThought, Source, Code, Run, Output, Claim, Skill, LoopProfile, Mission, Worktree, AgentVault, HermesSession, HermesTurn, HermesToolCall, HermesSkillInvocation, ToolDefinition, ProviderConfig, ResearchWorld, Brief, Council, Jury, Verdict`.

**Edge kinds.**
`links_to, derived_from, generated_by, produced_during, references, validated_by, contradicted_by, superseded_by, loop_emitted, scoped_to, voted_on, dissented_on, escalated_to, mounted_into`.

**Provenance discipline.** No node may be modified in place except `status`, `updated_at`, and projection-only fields (`readable_blocks` regen). All semantic changes create a descendant node with `derived_from` and `produced_during` edges. `Document` (.epdoc) is the only canonical body store; `readable_blocks` is a strict projection that can be rebuilt at any time. Raw Thoughts (`RawThought` nodes) are append-only and never edited or merged in place; consolidation produces new `ProseNote` or `Brief` descendants with backlinks.

**.epdoc package.** `FileWrapper`-based directory: `document.json` (ProseMirror canonical), `assets/<sha256>.<ext>`, `metadata.plist` (ULID, kind, schema version), `history/<ulid>.steps.jsonl` (optional). Block IDs live in `paragraph.attrs.id` (a ProseMirror plugin assigns ULIDs lazily on first encounter and preserves them through transactions).

---

## 6. Provider matrix

| Provider | Integration path | Role | Capability ceiling | Escalation triggers | Hard no's |
|---|---|---|---|---|---|
| **Apple Foundation Models** | `import FoundationModels`; `LanguageModelSession`; `@Generable`/`@Guide` | Tier 1: classification, tagging, schema-bound short responses | ~3B 2-bit on-device, ~30 tok/s (iPhone 15 Pro reference, Mac unverified); ≤4K useful context | Schema fail, length cap, availability `.unavailable` | Don't use for code synthesis; don't expose raw token deltas (snapshot API only) |
| **MLX-Swift Qwen3-4B-Instruct-2507-4bit** | `MLXLLM.LLMModelFactory`; `AsyncStream<Generation>` | Tier 1–2: ReAct with validators, Instant Recall ranking, draft generation | 4-bit, ~2.5GB; Qwen3 chat template understands tool blocks; **no native JSON-grammar** | Validator fail twice, complexity heuristic, user picks Deep | Don't ship runtime code execution from this tier; don't do MoE loading on <32GB |
| **MLX-Swift Qwen3.5-35B-A3B (4-bit)** | Same factory; MoE supported in mlx-swift-lm | Tier 2 planner on 32GB+ machines; AutoResearch synthesis tier | ~19.5GB peak weights; comparable quality to mid-tier cloud | Long-horizon plan, cloud unavailable, user override | Not loaded on 16GB; don't enable SSD expert streaming (SwiftLM fork is unverified) |
| **Anthropic Claude Code CLI** | `claude -p "<prompt>" --output-format stream-json`; Agent SDK with `settingSources: ["project"]`; **`--bare` flag UNVERIFIED** | Routable provider for code-heavy and long agentic loops; Co-op Code Team default | 200K ctx (Sonnet 4.6 1M beta); strongest agentic-search lane | None — terminal tier for code | Don't pass `--dangerously-skip-permissions`; don't bypass managed `disableBypassPermissionsMode`; don't write `.claude/settings.local.json` without manifest hash check |
| **OpenAI Codex CLI** | `codex exec --json`; `codex mcp serve` for inverse direction; `~/.codex/config.toml` with `[mcp_servers.*]` and `sandbox_mode = "workspace-write"` | Routable provider for engineering ops; Worktree Lane default | Profiles, granular approvals, AGENTS.md as project context | None — terminal for engineering | Don't use `danger-full-access`; don't disable default secret scrubbing in `shell_environment_policy` |
| **Google Gemini CLI** | `gemini -p --output-format json`; `~/.gemini/settings.json` with `mcpServers`, `coreTools` allowlist, `sandbox: "sandbox-exec"` | Routable provider for long-context architecture passes | 1M+ ctx (Gemini 3 Pro family); powers Gemini Deep Research API | None — terminal for long-context | Don't use `coreTools` denylist style (use `excludeTools`); don't trust unverified `--output-format stream-json` until `gemini --help` confirms |
| **Kimi K2.6** (HTTP) | `https://api.kimi.ai/v1` (OpenAI-compatible); `kimi-k2.6` | Routable provider for cost-efficient long-context architecture/audit | 256K ctx, automatic context caching, JSON mode, $web_search built-in | None — terminal for cost-sensitive long-context | Don't rely on advertised tool semantics without per-tool integration test; verify pricing at platform.kimi.ai before relying on aggregator numbers |
| **Hermes Agent (embedded faculty)** | Spawn `hermes acp` subprocess; ACP JSON-RPC 2.0 over stdio (Content-Length framed); Epistemos implements ACP client | Embedded faculty: skills, cron, multi-channel, delegation; default Co-op foreman | 18+ provider routing; SQLite FTS5 session DB; memory provider plugin | Hermes returns `error` or budget warning; user invokes Cloud Crossfire | **Do not** spawn `hermes chat -q` for streaming (no structured stdout); **do not** replace the FS skill loader without forking; **do not** rely on per-skill provider routing (doesn't exist — use `auxiliary.*`/`delegation.*` slots instead); **no E2B integration** |
| **Hermes Agent (routable provider)** | `provider_kind = HermesAcp`; same ACP channel | One of many routable agents | Same as above | Same as above | Same as above |

---

## 7. Unified research pipeline

One pipeline. Four depths. One ledger.

```
                ┌─────────────────── Scout ───────────────────┐
                │ Local Qwen3-4B + FTS5 + Instant Recall      │
                │ 1 pass · 30s budget · no external calls     │
                └──────────────────────┬──────────────────────┘
                                       │
                ┌─────────────── Standard ────────────────────┐
                │ Local 35B-A3B planner → Kimi/Sonnet exec    │
                │ 3-pass (Extract/Analyze/Synthesize+Audit)   │
                │ 5-min budget · ≤5 sources · ≤20 claims      │
                └──────────────────────┬──────────────────────┘
                                       │
                ┌──────────────── Deep ───────────────────────┐
                │ + Exa research-pro · Perplexity sonar-deep- │
                │   research · Gemini Interactions API         │
                │ + Deliberation jury (Local Council)          │
                │ 30-min budget · contradiction map mandatory  │
                └──────────────────────┬──────────────────────┘
                                       │
                ┌──────────────── Ultra ──────────────────────┐
                │ + browser_runner fan-out (chromiumoxide):    │
                │   claude.ai Research, Gemini Deep Research,  │
                │   ChatGPT Deep Research with profile reuse   │
                │ + Cloud Crossfire deliberation               │
                │ 2–8h budget · grand-jury synthesis           │
                └──────────────────────────────────────────────┘
```

**Three-pass discipline (every depth).**
1. **Extraction** — claims-only LLM call. Output: `Vec<RawClaim>` validated against `schemars`-derived schema. No prose. No analysis.
2. **Analysis** — math/SOAR/contradiction. Runs the 10-stage SOAR kernel: `S(tate)→O(perator)→A(pply)→R(esult)` × `(statistical, causal, Bayesian, meta-analytical, adversarial)` passes. Pure Rust where possible (Bayesian update, meta-analysis aggregation); LLM only for adversarial review.
3. **Synthesis+Audit** — final brief with mandatory `AuditPass` recursion: `PASS|PARTIAL|BLOCKED|DRIFT|REGRESSION|UNKNOWN`. Brief is rejected if any required claim is `UNKNOWN`.

**One ClaimLedger.** Every claim, regardless of which provider produced it, lands in `claims` with `(run_ulid, claim_ulid, text, evidence_refs, contradiction_refs, scores: {clarity, evidence, contradiction_resolution, novelty, actionability, recall_value, risk_of_slop})`. Source scoring is per-domain in `sources` and shared across runs.

---

## 8. Cognitive AutoResearch protocol

**Cadence.**
- **Daily nightly run** (default 02:00 local). Scope: last 24h `RawThought` + active `ProseNote` + recent `Run` outputs. Budget: 20 min cloud equivalent; default Local Council unless **Deeper Synthesis** toggle enabled. **Cloud Research** toggle enables web access via Exa/Perplexity.
- **Weekly consolidation** (day 7, default Sunday 03:00). Scope: 7-day rolling window. Budget: 60 min. Mandatory: prune, merge, promote, regenerate `start-new-session.md`.

**ResearchWorld scope.** Every run is bounded by a `ResearchWorld { tags, kinds, time_window, predicate, max_nodes, max_tokens_in, max_tokens_out, providers_allowed, web_allowed, sandbox_mode }`. The scope is itself a graph node (`scoped_to` edge), so re-runs are reproducible.

**Permissions.** All AutoResearch runs honor the standard permission ladder. Web access requires explicit `web_allowed: true`. Subprocess runs require `Bash` allow list per the cloud provider's settings (we never bypass).

**Multi-score keep/promote rule.**
- `keep` if `score.evidence ≥ 0.6 ∧ score.contradiction_resolution ≥ 0.5 ∧ score.risk_of_slop ≤ 0.3`.
- `promote` (descendant `ProseNote`) if `keep ∧ score.actionability ≥ 0.7 ∧ score.novelty ≥ 0.5`.
- `archive` (status flip, never deletion) otherwise. `derived_from` to original.

**Original notes are never overwritten.** Consolidation produces new descendants with `derived_from`, `superseded_by` (when applicable), and `validated_by` edges. `superseded_by` triggers Belief Drift status change (§12).

**`start-new-session.md` generation.** Weekly run composes a markdown packet: top 5 promoted notes, open contradictions, drift-flagged notes, active missions, suggested research world for next week. This file is the ONE thing the next session loads as warm context — not the entire vault.

**Karpathy autoresearch mapping.** AutoResearch reuses the bounded-experiment loop pattern (`https://github.com/karpathy/autoresearch`): time-boxed cycle (5-min Local, 20-min Hybrid, 60-min Cloud), single editable asset per loop (the candidate brief node), scalar metric (composite score above), `git`-style revert via `superseded_by` rather than file revert. No "promote" stage exists in Karpathy's original; we add it.

---

## 9. Deep Deliberation protocol

**System prompt (canonical).**
> *"You are part of a deliberation council. Be bold in exploration: argue strongly for what the evidence and your priors actually suggest. Be strict in validation: any claim that cannot be cited from the ClaimLedger or supported by a graph node is provisional and must be marked so. You are not here to be agreeable. You are here to be correct. Disagreement is data; surface it."*

**Role taxonomy (orthogonal axes).**

| Stance axis | Function axis |
|---|---|
| Optimist | Moderator |
| Pessimist / Critic / Audit | Clerk |
| Neutral / Researcher | Researcher |
|  | Skeptic |
|  | Contrarian |
|  | Synthesist |
|  | Domain Expert (any Co-op team overlay) |
|  | Jury |

**Modes.**

| Mode | Providers | Web | Use |
|---|---|---|---|
| Local Council | Qwen3-4B + 35B-A3B + FoundationModels | no | Cheap, private, fast iteration |
| Hybrid Council | Local + 1 cloud (Sonnet or Kimi) | optional | Default for Deep depth |
| Cloud Crossfire | All four cloud providers (Claude, Codex, Gemini, Kimi) + Hermes | yes | Ultra depth |
| Browser Witness | Cloud Crossfire + browser_runner Deep Research outputs as exhibits | yes | Maximum evidence |
| Grand Jury / Congregation | Cloud Crossfire + every Co-op team overlay as Domain Expert | yes | Major decisions only |

**Claim scoring.** Same `ClaimLedger` and same 7-axis scores as the Research Kernel. Votes are scored claims, not opinions. Minority reports preserved verbatim; never silently dropped.

**Output artifacts (mandatory).**
`transcript.jsonl`, `claims.json`, `disagreements.md`, `jury-votes.json`, `final-verdict.md`, `minority-reports.md`, `start-new-session.md`. All written as graph nodes with `produced_during` edges to the council `Run` and `voted_on`/`dissented_on` edges to participating roles.

---

## 10. Hermes integration protocol

**Landing handoff.** Double-click on the Hermes pixel-art logo on the landing pane triggers a `HermesHandoff` actor sequence: (1) black surface fade-in 200ms, (2) ASCII wave Metal shader 600ms (precompiled pipeline), (3) "HERMES AGENT" pixel-art type-on 400ms with a fixed-rate timer (no LLM), (4) glare-pass shader on the logo 250ms, (5) crossfade to a `DocumentHost` whose root is a `HermesSession` node, with `BootstrapStatus` overlay reporting ACP handshake progress. Total budget: ≤1.6s. Animation runs even when ACP handshake is slower; the chat surface accepts input only after `BootstrapStatus.ready = true`.

**Schema-driven pass-through for `/` and `@`.** Pressing `/` opens a command palette populated from two sources: (a) Epistemos-native commands registered against the catalog, (b) Hermes skills enumerated via ACP `session/skills_list` (or, if that doesn't exist on the released ACP surface — verify — we use Hermes' `skills_list` tool by sending a synthetic `session/prompt` early in the session, cached). `@` opens the graph node selector.

When the user picks a Hermes command, we send it as `session/prompt` to the ACP session, with the slash-command body as user content. Hermes responds with a stream of `session/update` notifications. Each notification is mapped at the `hermes_bridge` Rust crate to A2UI envelope messages: text becomes `NoteCard.body_ref` updates; tool_use blocks become `AgentToolCall` components with `provider = HermesAcp`; tool_result blocks update the same component's `state`. We **do not** run runtime SwiftUI codegen; we only ever map into the closed catalog. Anything Hermes emits that doesn't map (raw markdown, mermaid fences, `MEDIA:` directives) renders inside `DocumentHost` (markdown view), not as new components.

**Skills-as-nodes.** Skills live in the graph as `Skill` nodes with `(name, description, frontmatter, body, version, author, license, scopes)`. A `hermes_bridge::SkillSync` daemon materializes any `Skill` node tagged `hermes:active` to `~/.epistemos/hermes-skills/<name>/SKILL.md`, listed in Hermes' `skills.external_dirs` config (verified at hermes-agent.nousresearch.com/docs/user-guide/features/skills). Edits to the graph node trigger atomic re-write; Hermes' built-in `notifications/tools/list_changed` reload is honored. **We do not fork the FS loader**; we cooperate with it. (UNVERIFIED — would require source-code reading: whether a graph-backed Python plugin loader could be implemented as a Hermes plugin without forking; cheapest experiment: implement a plugin that registers MCP tools from the graph and a context_engine plugin that injects skill descriptions, skipping the FS scanner entirely.)

**Loop profiles.** A `LoopProfile` node holds `(dsl_source, schedule, scope_predicate, budget, scoring)`. The DSL is a thin Rust-evaluated mini-language that compiles to: (a) a Hermes cron entry materialized to `~/.hermes/cron/jobs.json` via the `cronjob` tool, (b) optionally a DSPy/GEPA Atropos `BaseEnv` subclass when the user enables learning. The body of a loop profile is execute_code-runnable Python with access to `epistemos-mcp` graph tools. Mapping to Atropos: a loop profile's scoring fn becomes the env's reward; the prompt generator pulls from the scope predicate's typed graph nodes (`RawThought`, `ImplementationPlan`, `Recall`, `Synthesis`).

**Session subgraph rendering.** Every ACP `session/update` containing a tool call emits a `GraphEvent` of kind `node_pulse(node_id)` (for `get_node`/`graph.get_node`), `edge_flash(edge_id)` (for `traverse`), `node_phase_in(node_id)` (for `create_node`), `glare(node_id)` (for `create_edge` to a high-importance node). Metal shaders for these four primitives are precompiled at app launch.

**Hermes Agent vault.** A directory `~/.epistemos/agents/hermes/` containing `memory/`, `runs/`, `sources/`, `reports/`, `skills/` (sync mirror), `loop_profiles/`, `persona.md`. Mirrored as graph nodes under an `AgentVault { agent: Hermes }` parent.

**Computer use + WKWebView browser.** Exposed to Hermes via an Epistemos MCP server (`epistemos-browser-mcp`, `mcp_browser_action`) that wraps `ScreenCaptureKit`, `AXUIElement`, and a built-in `WKWebView`. Hermes calls `mcp_epistemos_browser_*` tools; user approval ladder gates every action.

**Hermes as faculty AND provider.** Two routes through the same `provider::hermes_acp` module: faculty mode keeps the ACP session alive across many Epistemos turns (long-lived); provider mode opens a fresh session per turn (stateless). Both share the `HermesSession` node taxonomy.

---

## 11. Instant Recall subsystem

**Triggers.** Debounced text input in any `ScratchPad`/`NoteCard.body_ref`/chat composer (250ms quiet); cursor stop in editor (400ms); explicit `⌘K`; agent turn boundary; AutoResearch step boundary; Deliberation role-change; Hermes ACP `session/update` boundary.

**Gates and weights.**
```rust
pub struct RecallGates {
    pub semantic: f32,     // ANN cosine over `node_blobs` embeddings (default 0.5)
    pub situational: f32,  // recency, current run scope, active mission (0.3)
    pub action: f32,       // overlap with current draft's likely action verbs (0.2)
}
```
Scores are normalized; combined ranking pulls top-K with a per-kind cap (e.g., ≤3 RawThoughts, ≤2 Sources, ≤2 ProseNotes). Index is hot in-memory (HNSW) plus FTS5 fallback for substring/CJK and zero-result rescue.

**Performance budget.** p50 ≤ 30ms, p99 ≤ 80ms for a 50K-node vault on M3 Pro. Recall results return as a `RecallBundle { nodes, citations, scopes, signpost_id }` and stream into the consumer's prompt as a typed context block (not free text).

**Single API for all consumers.**
```rust
pub trait RecallConsumer {
    fn recall(&self, query: RecallQuery, gates: RecallGates, budget: RecallBudget)
        -> impl Future<Output = Result<RecallBundle>> + Send;
}
```
Chat, agent runtime, AutoResearch, Deliberation, and Hermes bridge all call the same function with different `RecallGates`.

---

## 12. Belief drift / semantic drift

**Note status taxonomy.** `Current | UsefulButOld | Contradicted | NeedsAudit | Superseded | Deprecated | Speculative | Historical`.

**Detection algorithms.**
1. **Embedding drift**: cosine distance between a note's stored embedding and the centroid of its 30-day descendant cluster exceeds 0.35 → flag `NeedsAudit`.
2. **Contradiction edge ingest**: any new `contradicted_by` edge → flag `Contradicted`.
3. **Supersedure edge ingest**: any new `superseded_by` edge → flag `Superseded`.
4. **Time + topical drift**: notes older than 180 days whose topical cluster has shifted (Jensen-Shannon divergence over tag distribution) → flag `UsefulButOld`.
5. **External-source recency**: notes citing a `Source` whose canonical URL has changed semver/version-tagged content → `NeedsAudit`.

**Integration with weekly consolidation.** Every weekly AutoResearch run iterates flagged notes and either confirms the flag (status sticks), produces a descendant resolution note (status flips to `Superseded`/`Current`), or escalates to a user-visible review queue. Flags themselves are graph edges (`drift_flagged`) so history is preserved.

---

## 13. Worktree-based engineering operating model

**Mission.** A `Mission` node with `(title, scope_md, deliverables, agents_assigned, budget, success_predicate)`. Compiled at run start to a `mission.md` file dropped at the repo root; AGENTS.md and CLAUDE.md frontmatter point to it.

**Lane.** A `WorktreeLane` is a `git worktree` directory (`~/.epistemos/worktrees/<mission_ulid>/<lane_ulid>/`) plus an assigned provider (`ClaudeCode | Codex | Kimi | Cursor | GeminiCli | HermesAcp`). Each lane runs in its own subprocess with its own permission policy, its own `settings.json/config.toml/GEMINI.md` derived from the manifest.

**Diff review.** Every lane completion emits `git diff --no-color` into a `DiffReview` component; user (or automated reviewer agent) approves/rejects per hunk; approved hunks are re-committed against a canonical merge worktree.

**Merge gates.** A merge requires: (a) all lanes report `PASS` per audit-loop vocabulary, (b) tests green in the merge worktree, (c) no `DRIFT` or `REGRESSION` from baseline, (d) audit-first coding philosophy: every merged change traces back to a research-validated claim or implementation plan.

**Memory commits.** On merge, the orchestrator writes `LessonLearned` nodes (kind: `RawThought` with `tag: lesson`) into the originating mission's `AgentVault`, with `produced_during → Run`. Future missions citing the same scope predicate retrieve these as recall context.

**User-shipped Agent Workbench.** Same primitives, surfaced as the catalog components `WorktreeLane`, `DiffReview`, `MissionCard` (added to palette). The internal-vs-shipped boundary is purely UI exposure; the orchestrator is identical.

---

## 14. Deterministic performance contract

| Constraint | Mechanism | Signpost |
|---|---|---|
| No hot-path serialization >100Hz | GraphEvent SPSC ring (extern "C", zero-copy) | `graph.event_emit` |
| No main-thread Metal pipeline compilation | All MTLPipelineState built in `applicationDidFinishLaunching` | `metal.precompile` |
| No string-keyed dispatch in inner loops | Component dispatch via `repr(u8)` enum + Swift `Int` registry | `ui.dispatch` |
| No allocation in render frames | Per-frame arena pre-allocated; `inout` buffer reuse for A2UI patches | `metal.frame` |
| Every optimization signposted with p99 budget | `#[instrument]` Rust macro emits OS log markers; Instruments template asserts | per-symbol |
| Summary-first UI materialization | `NoteCard.body_ref` initially returns 200-char teaser; full body hydrates on `.onAppear` + visible region | `ui.hydrate` |
| Append-only Raw Thoughts as separate traffic class | `events.jsonl` writer is a dedicated `tokio::task` with bounded `mpsc` (capacity 4096); back-pressure drops to a slow-buffer file before blocking | `raw_thought.write` |
| Cancellation <200ms | `CancellationToken` polled every inner-loop iteration; subprocess SIGINT then SIGTERM ladder | `cancel.kill` |
| MLX inference cancellation between tokens | `didGenerate` returns `.stop` on `CancellationToken.is_cancelled()` | `mlx.token` |
| Recall p99 ≤ 80ms / 50K nodes | HNSW in-memory + FTS5 fallback; budget aborts early | `recall.gate` |
| Bootstrap ⌘N → ready ≤ 5s | CLI discovery cache + parallel manifest write + warm MLX | `bootstrap.total` |

p99 budget assertions are encoded as test-time signpost-interval thresholds; CI runs an Instruments template against scripted scenarios and fails the build on regression.

---

## 15. Safety / security model for Pro

1. **Permission ladder.** `Allow | Ask | Deny` per-tool, per-scope (`Bash(cmd-pattern)`, `Read(path-glob)`, `Edit(path-glob)`, `WebFetch(domain:...)`, `mcp__server__tool`). Decisions captured in `permissions.allow|ask|deny` and propagated to every spawned CLI's settings file from the unified manifest. Decisions auditable in graph as `PermissionDecision` events.
2. **Approval policies per provider.** Claude Code: `permissions.defaultMode = "default"` (we never ship `bypassPermissions` to users; `disableBypassPermissionsMode = "disable"` is set in managed settings on Pro). Codex: `approval_policy = "on-request"` default, `granular` for advanced; `sandbox_mode = "workspace-write"` default; **never** `danger-full-access` without explicit user opt-in dialog. Gemini: `coreTools` allowlist + sandbox-exec.
3. **Kill switch ⌘. ownership chain.** Single `CancellationToken` rooted at the active session; UI keystroke goes straight to Rust core via UniFFI; Rust fans out cancellation to subprocesses, MLX streams, MCP requests, browser_runner, ACP sessions. No silent best-effort.
4. **MCP trust model.** User MCP servers consumed in client mode are sandboxed via the spawned subprocess's own permission boundary; we surface a `PermissionPrompt` on first invocation per server. We never auto-allow project-scoped `.mcp.json` servers; `enabledMcpjsonServers` is empty by default and explicit per-server opt-in.
5. **Secret separation.** Tokens/keys live in macOS Keychain; UniFFI exposes `provider::credentials::get(provider_id)` only inside the Rust core; never logged. `shell_environment_policy.exclude` is `["*KEY*", "*SECRET*", "*TOKEN*", "*PASSWORD*", "*CREDENTIAL*"]` for every spawned CLI and verified post-spawn by inspecting the process env.
6. **Browser automation discipline.** chromiumoxide-driven sessions are launched with an explicit user-data-dir (default: a copy of the user's profile, not the original — the original is locked when Chrome is open) and a visible debug overlay (`BootstrapStatus` shows live URL + every CDP method invoked). User can pause/cancel mid-session.
7. **File write verification.** Every `Edit`/`Write` tool call goes through `tools::verified_write(path, expected_pre_hash, new_bytes) -> Result<()>` which: re-reads the pre-hash, refuses the write on mismatch, writes atomically via `tempfile::persist`. Path traversal blocked at the manifest layer (`additionalDirectories`); symlinks resolved and re-validated.
8. **No silent canonical artifact overwrites.** Projection writes (`readable_blocks`) are atomic and idempotent; canonical bodies (`Document` .epdoc) are never overwritten by projection logic — only by `DocumentHost` editor commits with explicit ProseMirror transactions.
9. **No CoT reconstruction.** Only **observable** thinking blocks (Claude `thinking` content, OpenAI `agent_reasoning` deltas where the model itself emits them) are stored, with a visible source-attribution marker. `RawThought` ingestion never speculates about model hidden state.
10. **No credential bypass for browser deep-research runs.** If chromiumoxide cannot attach to a profile (Chrome locked, login expired), Ultra Mode aborts that lane and reports `BLOCKED` — never auto-relogin.

---

## 16. Bootstrap / new session flow (⌘N → ready, ≤5s)

```
t=0ms     ⌘N pressed
t=20ms    UI shell paints empty Two-mode chrome (no model dependency)
t=30ms    Rust core starts; CLI discovery cache loaded from ~/.epistemos/cache/cli_discovery.json
t=50ms    parallel:
            · CLI re-verify (fork+exec each: claude --version, codex --version, gemini --version, hermes --version)
            · MLX model preload (mmap weights from ~/.epistemos/models/qwen3-4b-4bit/)
            · FoundationModels.availability check
            · GRDB pool open; FTS5 sanity query
            · MCP client warmup (spawn user's existing servers in parallel; degrade gracefully on timeout)
t=400ms   manifest compile:
            · CLAUDE.md + .claude/settings.json + .mcp.json + .claude/skills/*
            · .codex/config.toml + AGENTS.md
            · .gemini/settings.json + GEMINI.md
            · ~/.hermes/config.yaml mcp_servers: entry pointing at epistemos-mcp
            · skill sync: graph Skill nodes with hermes:active → materialize to ~/.epistemos/hermes-skills/
t=800ms   provider handshakes (one ping each, 200ms timeout)
t=1.2s    permission policy hydration; ledger nodes loaded for active session
t=1.5s    A2UI initial UpdateComponents emitted; user can type
t=2-5s    ACP Hermes session ready (if requested); MLX token-stream ready
```

If any non-critical stage exceeds budget, the `BootstrapStatus` overlay reports `PARTIAL` and the session opens in degraded mode (e.g., chat works, Ultra Mode disabled until the slow stage finishes).

Manifest hash is recorded at write time in each generated file's leading comment; if the user has edited a generated file, regeneration is gated by an explicit prompt — never silent.

---

## 17. File / module layout

```
epistemos/
├── crates/
│   ├── substrate-core/                  # Single-source-of-truth: graph, A2UI catalog, ULID, .epdoc
│   │   ├── src/entity_graph/{nodes.rs, edges.rs, status.rs, mutations.rs}
│   │   ├── src/ui/{catalog.rs, a2ui.rs, dispatch.rs}
│   │   ├── src/identity/{ulid.rs, slotmap.rs}
│   │   ├── src/cancellation.rs
│   │   └── src/lib.rs
│   ├── persistence/                     # GRDB-bound writes from Rust; FTS5; events.jsonl; .epdoc IO
│   │   ├── src/{schema.rs, migrations.rs, fts.rs, blobs.rs, epdoc.rs, events_log.rs}
│   ├── agent_runtime/                   # Router, Co-op, worktree, deliberation protocol
│   │   ├── src/{router.rs, two_mode.rs, effort.rs, co_op.rs, deliberation.rs, worktree.rs, mission.rs}
│   ├── providers/                       # Subprocess + in-process adapters
│   │   ├── src/{claude_code.rs, codex.rs, gemini.rs, kimi.rs, hermes_acp.rs, mlx.rs, foundation_models.rs, common.rs}
│   ├── tools/                           # Tool registry, permission ladder, verified_write, sandbox shims
│   │   ├── src/{registry.rs, permission_ladder.rs, verified_write.rs, browser_action.rs, screen_capture.rs, ax_element.rs}
│   ├── mcp_server/                      # epistemos-mcp (stdio + Streamable HTTP), Apps SEP-1865 input adapter
│   │   ├── src/{stdio.rs, streamable_http.rs, oauth.rs, apps_input_adapter.rs, tools_export.rs}
│   ├── mcp_client/                      # Consumes user's ~/.claude/mcp.json, ~/.codex/, ~/.hermes/ servers
│   │   ├── src/{discovery.rs, transport.rs, sampling.rs, elicitation.rs, tasks.rs}
│   ├── research_kernel/                 # 10-stage SOAR, ClaimLedger, Scoring, AuditPass
│   │   ├── src/{stages/{state.rs, operator.rs, apply.rs, result.rs}, passes/{statistical.rs, causal.rs, bayesian.rs, meta_analysis.rs, adversarial.rs}, claim_ledger.rs, scoring.rs, audit_pass.rs}
│   ├── autoresearch/                    # Daily/weekly scheduler, ResearchWorld scopes, keep/promote
│   │   ├── src/{scheduler.rs, research_world.rs, rules.rs, start_new_session.rs}
│   ├── deliberation/                    # Role taxonomy, modes, jury, transcript writer
│   │   ├── src/{roles.rs, modes.rs, claim_voting.rs, artifacts.rs}
│   ├── instant_recall/                  # ANN+FTS5 recall actor, gates
│   │   ├── src/{actor.rs, ann.rs, gates.rs, situational.rs, action_overlap.rs}
│   ├── hermes_bridge/                   # ACP client, skill sync, loop profile compiler, GraphEvent mapper
│   │   ├── src/{acp_client.rs, skill_sync.rs, loop_profile.rs, command_palette.rs, event_mapper.rs}
│   ├── browser_runner/                  # Ultra Mode chromiumoxide fan-out + Lightpanda for ephemeral
│   │   ├── src/{ultra_fan.rs, profile_reuse.rs, anti_detect.rs, witness_capture.rs}
│   ├── drift_detector/                  # Belief drift detection
│   │   ├── src/{embedding_drift.rs, contradiction_ingest.rs, time_topical.rs, source_recency.rs}
│   ├── telemetry/                       # OSSignposter bridge, p99 assertions, Instruments templates
│   └── ffi/                             # UniFFI exports + extern "C" SPSC ring for GraphEvent
│       ├── src/{lib.rs, graph_event_ring.rs, scaffolding.rs}
│       └── epistemos.udl
├── swift/
│   ├── EpistemosApp/                    # SwiftUI shell, two-mode UI, Effort axis, command palette
│   ├── EpistemosUI/                     # SchemaViewRegistry + 25 components
│   │   ├── Components/{NoteCard.swift, GraphView.swift, ScratchPad.swift, ...}
│   │   ├── Registry/{Dispatch.swift, A2UIDecoder.swift, DataPath.swift}
│   ├── EpistemosMLX/                    # MLX-Swift session manager, KV cache, structured-output adapter
│   ├── EpistemosFoundation/             # FoundationModels session wrappers, Tool conformances
│   ├── EpistemosCapture/                # ScreenCaptureKit + AXUIElement wrappers (called via tools crate)
│   ├── EpistemosMetal/                  # MetalRenderer, GraphEventStream actor, precompiled pipelines
│   ├── EpistemosDocument/               # WKWebView ProseMirror host, .epdoc package IO
│   ├── EpistemosTreeSitter/             # SwiftTreeSitter + Neon hookups for source views
│   └── EpistemosRustBridge/             # UniFFI generated + extern "C" SPSC ring consumer
└── manifests/
    ├── catalog/v1/native.json           # generated from substrate-core
    └── slices/                          # acceptance criteria per slice (§18)
```

---

## 18. The 21-slice implementation roadmap

Each slice is "done" only when its acceptance criteria pass under the audit-loop discipline (§19).

| Slice | Name | Acceptance criteria |
|---|---|---|
| 0 | Instrumentation/perf gates | OSSignposter symbols defined; Instruments template ships in repo; CI fails build on p99 regression for `metal.frame`, `recall.gate`, `bootstrap.total` |
| 1 | Raw Thoughts persistence | Append-only `events.jsonl` per run; bounded mpsc with back-pressure; replay reconstructs identical run state; signposted; never blocks UI |
| 2 | Typed Artifact Graph | All node + edge kinds defined; ULID identity; `MutationEnvelope` emitted on every write; FTS5 projection exists; round-trip serialization green |
| 3 | .epdoc package + Document editor | WKWebView ProseMirror host loads/saves .epdoc; block-level ULIDs assigned; FileWrapper IO atomic; ProseMirror JSON canonical preserved across reload |
| 4 | Search projections | `readable_blocks_ft` populated by GRDB-synthesized triggers; `Block.matching(FTS5Pattern...)` returns ranked results; tokenizer set to `unicode61` + trigram fallback |
| 5 | Agent Runtime + provider abstraction | All 4 cloud providers + 2 local tiers spawn correctly; `claude -p --output-format stream-json`, `codex exec --json`, `gemini -p --output-format json` confirmed via `--help`; token streams reach Swift via UniFFI callback |
| 6 | Tool registry + permission ladder | Allow/Ask/Deny rules from manifest applied to every spawned CLI; `verified_write` blocks unverified mutations; first-call user prompts surface `PermissionPrompt` component |
| 7 | MCP server (epistemos-mcp) | stdio + Streamable HTTP; OAuth 2.1 PKCE flow; `tools/`, `resources/`, `prompts/`, `sampling/`, `elicitation/`, `tasks/` per spec 2025-11-25; Claude Desktop / ChatGPT can list tools |
| 8 | MCP client | Discovers `~/.claude/mcp.json`, `~/.codex/config.toml`'s `[mcp_servers.*]`, `~/.gemini/settings.json` `mcpServers`, `~/.hermes/config.yaml` `mcp_servers:`; sandboxed spawn; per-server permission prompt |
| 9 | Schema-driven UI registry + 25-component palette | Every component has a Props struct, registry entry, snapshot test, accessibility labels; A2UI catalog publishes; Vercel-style RSC explicitly rejected |
| 10 | Hermes Agent embedded faculty | `hermes acp` spawned; ACP JSON-RPC 2.0 over stdio with Content-Length framing; skills-as-nodes sync to `~/.epistemos/hermes-skills/`; loop profile DSL compiles to `~/.hermes/cron/jobs.json`; GraphEvent → Metal mapping for pulse/flash/phase_in/glare |
| 11 | Instant Recall | Single actor; HNSW + FTS5; gates configurable; p50 ≤ 30ms / p99 ≤ 80ms on 50K nodes; consumed by chat, agent runtime, AutoResearch, Deliberation, Hermes bridge |
| 12 | Two-mode UI (Chat/Agent) + Effort axis | Modes toggle without state loss; Effort (Auto/Quick/Deep) routes through router; cancellation budget enforced |
| 13 | Co-op Mode + worktree orchestrator | Mission → Lanes → Diffs → Merge gates; per-lane subprocess with derived settings; `LessonLearned` nodes commit on merge |
| 14 | Deep Deliberation / Research Jury | All 5 modes; mandatory artifacts; minority reports preserved; voting against ClaimLedger, never against opinion |
| 15 | Research Kernel + depth toggle | 10-stage SOAR pipeline runs; three-pass discipline enforced (`Extraction → Analysis → Synthesis+Audit`); `AuditPass` recursion mandatory; Scout/Standard/Deep budgets respected |
| 16 | Cognitive AutoResearch Engine | Daily 02:00 + weekly Sunday 03:00 cron; `ResearchWorld` scope reproducible; keep/promote/archive per multi-score rule; `start-new-session.md` regenerated weekly |
| 17 | Belief Drift detection | All 5 algorithms operational; `drift_flagged` edges written; weekly run iterates flags; review queue surfaces `DriftBadge` |
| 18 | Ultra Mode browser runner | chromiumoxide drives Chrome with profile-copy reuse; Claude/Gemini/ChatGPT Deep Research flows complete; Witness exhibits captured; Lightpanda used only for unauthed ephemeral fetches |
| 19 | Agent Vaults | Per-agent directory + mirrored graph subtree; cross-session memory compounding measurable on a benchmark mission |
| 20 | Editorial pipelines | Master Editorial Manager + Substack/X/WordPress/Website adapters; descendants only, never overwriting source notes |
| 21 | Audit-first coding workflow surfaces | Research → Audit → Code → Audit → Memory enforced as a Mission template; UI surfaces every gate; merge blocked on missing gate |

There is no time pressure. A slice that fails audit re-enters the queue. Nothing called "done" is undone in a later slice without a Mission.

---

## 19. Audit-loop discipline

Every slice and every PR before merge runs a recursive audit pass that produces one of:

| Status | Meaning | Action |
|---|---|---|
| **PASS** | Plan, repo reality, logs, tests all align; no overclaim; no drift | Merge / mark slice done |
| **PARTIAL** | Slice partially complete; what's missing precisely enumerated | Re-queue with named gaps |
| **BLOCKED** | External dependency or unverified assumption blocks completion | Open experiment ticket per §20 |
| **DRIFT** | Implementation diverged from canonical plan; descendant nodes don't match parent's `derived_from` chain | Halt; produce divergence report; reconcile or supersede |
| **REGRESSION** | Previously passing test/budget now fails | Revert or fix-forward with provenance edge |
| **UNKNOWN** | Insufficient evidence to call any of the above | Block merge; gather raw logs |

**Discipline:** canonical plan first; repo reality second; logs/tests as evidence; no overclaims; narrow patches only; no contamination from generated artifacts (`readable_blocks`, `start-new-session.md`, manifest files) into the audit's evidence set; raw logs are the truth — summaries are derivative.

---

## 20. The three riskiest bets (and the cheapest experiments to de-risk each)

**Bet 1 — A2UI v0.9 as canonical envelope when no upstream Swift renderer exists.** v0.9 status flagged "actively evolving"; we own a SwiftUI renderer no one else has written.
Experiment: build a minimal `SchemaViewRegistry` with 5 components (`NoteCard`, `ScratchPad`, `BacklinkList`, `GraphView`, `AgentToolCall`); drive from a recorded A2UI session JSONL captured from the v0.9 reference React renderer; measure parity. ~3 days. Decision rule: if parity ≥ 95% on the 5 components, scale to 25; if not, fall back to a custom schemars-derived envelope (still internally tagged enum) and ship adapters for A2UI/MCP-Apps as inputs.

**Bet 2 — UniFFI for everything except the GraphEvent SPSC ring.** BoltFFI is 0.1.x with 3 contributors; rewriting 94K lines is unjustified by current evidence. But the GraphEvent hot path during heavy agent activity (~10k events/s synthetic) may still drop frames under UniFFI's RustBuffer allocation pressure.
Experiment: wire one GraphEvent path twice — once via UniFFI callback interface, once via a hand-written `extern "C"` SPSC ring backed by `crossbeam::queue::ArrayQueue` and a `CFRunLoopSource`. Synthetic burst at 10k events/s under Instruments Time Profiler + Allocations at 120fps UI load. ~2 days. Decision rule: keep UniFFI if dropped-frame rate is zero; adopt SPSC ring for *that single path* if not. Never migrate the whole codebase. BoltFFI stays watch-listed only.

**Bet 3 — Hermes ACP as primary embedded-faculty channel.** ACP is documented but the released subprocess automation surface is younger than the Claude Code/Codex equivalents; some session-protocol details (whether `session/skills_list` exists, whether an external Python plugin can replace the FS skill loader without forking) remain unverified.
Experiment: write a 200-line Rust ACP client that spawns `hermes acp`, opens a session, sends one `session/prompt`, receives streaming `session/update`s, exercises one `tools/call` and one `fs/read_text_file` callback. Measure latency, error modes, and whether tool-call payloads map cleanly to the catalog. ~2 days. Decision rule: if ACP works as documented for these basic flows, commit. If not, fall back to dual mode: `hermes mcp serve` (Hermes-as-MCP-server consumed via mcp_client) for Hermes-as-faculty, and OpenAI-compatible HTTP API (`/v1/responses`) for Hermes-as-provider — both are documented and stable, at the cost of losing some session-update richness.

---

## 21. Explicit hard no's

The unified architecture rejects, without negotiation:

- **Tauri / Electron.** Native macOS only.
- **Runtime SwiftUI codegen** from LLM output. Apple App Store guidelines aside, the 12–25% compile failure rate is fatal in interactive use.
- **Hidden chain-of-thought reconstruction.** Only observable thinking content — what the model itself emits as `thinking` blocks or `agent_reasoning_delta` — is ingested. We never speculate about hidden state.
- **Free-form model debate without artifacts.** Every Deliberation turn produces a ClaimLedger entry; every vote is against a claim, not against vibes.
- **NotificationCenter for graph or render invalidation.** Mutation envelopes only; subscribers register narrow predicates.
- **String-keyed dispatch in hot paths.** Component dispatch via `repr(u8)` enums; tool dispatch via `ToolId` newtype; no `HashMap<String, _>` lookups per frame or per token.
- **Mac App Store sandbox compromises.** Pro is direct-download, Developer ID + Hardened Runtime + notarized; we never compile under the MAS sandbox so we never have to soften the agent runtime, browser_runner, or worktree orchestrator to fit.
- **Premature BoltFFI migration.** Single hot-path pilot only; 94K-line rewrite without measured frame drops on UniFFI is forbidden.
- **`hermes chat -q` for streaming.** No structured stdout protocol exists; ACP is the only correct subprocess channel for embedded faculty.
- **`claude --bare`** as a documented dependency. The flag is unverified; do not rely on it. Use `claude -p --output-format stream-json` (verified) and `--no-session-persistence`.
- **`danger-full-access` Codex sandbox** for any user-visible flow.
- **Per-skill provider routing in Hermes.** Doesn't exist; use `auxiliary.{vision, web_extract, compression, ...}` and `delegation.*` slots in `~/.hermes/config.yaml`.
- **Forking Hermes' FS skill loader** before exhausting cooperative paths (graph→`~/.epistemos/hermes-skills/` sync daemon listed in `skills.external_dirs`; Hermes plugin that registers MCP tools from the graph).
- **MCP Apps SEP-1865 `ui://` HTML iframes** as our native rendering surface. We accept them as inputs; we do not emit them.
- **Anthropic "Deep Research API" assumption.** No programmable model exists as of April 2026 — claude.ai Research is a product feature. Ultra Mode reaches it only via chromiumoxide; never via a fictional API endpoint.
- **Silent overwrites of canonical .epdoc bodies** by projection logic. Projections are write-only into projection tables.
- **Generated-artifact contamination of audits.** Manifest-generated files (`CLAUDE.md`, `settings.json`, `config.toml`, `GEMINI.md`, `start-new-session.md`) are excluded from the evidence set.
- **MoE 35B-A3B loaded on <32GB machines.** Tier downgraded automatically.
- **Browser automation that bypasses the user's authentication state.** chromiumoxide attaches to a *copy* of the profile; never the live profile while Chrome is running; Ultra lanes report `BLOCKED` when login expired.
- **Vercel AI SDK RSC** as a UI envelope. Officially paused; not portable to Swift.
- **Adopting A2UI's "prompt-first" mode without our own structured-output backstop.** We always pair A2UI prompt-embedding with `schemars`-derived JSON Schema constraints at the provider layer; LLMs that support structured output (Foundation Models `@Generable`, OpenAI Responses, Gemini schema, MLX-via-MLX-Structured) get hard constraints, not just prompts.

---

*This doctrine is the canonical specification. Deviations require a Mission node, an audit pass, and a superseded_by edge to this document. Build the spine. Then the cathedral.*