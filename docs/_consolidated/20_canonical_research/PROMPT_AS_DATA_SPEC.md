# Prompt-As-Data Spec — JSPF + PTF

**Status:** v0.1 (2026-04-27). Foundation shipped under `EPISTEMOS_PROMPT_TREE=1`
feature flag. Default-on cutover gated on ≥30% measured cache-hit rate over a
two-week bake window without quality regressions.

**Authority:** subordinate to `docs/architecture/PLAN_V2.md`, `CLAUDE.md`, and
`docs/MASTER_BUILD_PLAN.md`. Per `01_DOCTRINE.md §6 #14` (no orphan scaffolding),
this format ships only with at least one wired call site (ChatCoordinator first
agent turn).

**Item ID:** N1 (per `docs/MASTER_BUILD_PLAN.md §7` Bucket N).

---

## §1 — JSPF (JSON-Schema Prompt Format) — Swift types

The canonical Prompt is a typed value (`Codable + Sendable + Hashable`) defined in
`Epistemos/Engine/PromptTree.swift`. All sub-sections are nonisolated to satisfy
Swift 6.2 default-actor-isolation when accessed from non-MainActor contexts (e.g.
`PromptTreePersister`, an `actor`).

```swift
nonisolated public struct Prompt: Codable, Sendable, Hashable {
    public var version: Int                    // schema version (start at 1)
    public var id: String                      // stable; doubles as cache key
    public var identity: IdentitySection?      // system role / persona
    public var tools: [ToolSpec]               // tool definitions this turn
    public var memory: MemorySection?          // recent chats + notes + ontology
    public var task: TaskSection               // the active objective
    public var constraints: [ConstraintSection]// hard rules + capability gates
    public var outputSchema: OutputSchema?     // expected response shape
    public var cacheHints: CacheHints          // which subtrees are cacheable
}
```

The 8 stable subtrees are catalogued in `PromptSubtree`:

```swift
nonisolated public enum PromptSubtree: String, CaseIterable {
    case identity, tools, memory, ontology, task, constraints, outputSchema
}
```

**Mirror to JSON Schema:** the Codable conformance produces a deterministic JSON
that maps 1:1 to the on-disk PTF files (§2). Pretty-printed + sortedKeys +
withoutEscapingSlashes is the canonical format for diffability.

---

## §2 — PTF (Prompt Tree Format) — directory layout

A `Prompt` flattens to a directory at:

```
<vault>/.epistemos/prompts/<sessionID>/<turnIndex>/
├── manifest.json       — Prompt envelope (version + id + cacheHints)
├── identity.json       — IdentitySection if present
├── tools.json          — [ToolSpec]
├── memory.json         — MemorySection if present
├── task.json           — TaskSection (always)
├── constraints.json    — [ConstraintSection]
└── output_schema.json  — OutputSchema if present
```

**Filename stability:** `PromptNode.Filename` is a closed enum. Renames require
a JSPF version bump + migration. Adding new subtrees requires a version bump too;
the compose factories in `PromptComposer` evolve by adding new factories rather
than mutating existing ones.

**Round-trip guarantee:** `PromptTreePersister.persist(...)` then
`PromptTreePersister.load(...)` produces a `Prompt` that's `Hashable`-equal to
the original. Verified by `PromptTreeTests.persist_writesPTFRoundTrip`.

**GC policy:** the persister keeps the last 20 turns per session by default
(`PromptTreePersister.recentTurnsKept`). NightBrain or an on-demand
`gcStaleTurns(...)` call prunes older turns. The active session's most recent
turn is never pruned regardless.

**Privacy:** PTF lives under the vault directory. In MAS the vault is
security-scoped via NSOpenPanel bookmarks; the persister never reaches outside
the granted scope. In Pro the vault is unrestricted but follows the same path
discipline.

---

## §3 — Cache-hint heuristics

The Anthropic Messages API permits up to **4** `cache_control` breakpoints per
request, with a 5-minute ephemeral TTL (or 1-hour with a beta header). Cached
prefix tokens get a ~90% discount on input billing. **The initial cache write
costs ~25% MORE than uncached input** — so a subtree should only be marked
cacheable if it'll be reused at least twice within the 5-minute window.

The composer's default plan (`CacheHints.chatDefault`) marks the four stablest
subtrees:

| Priority | Subtree       | Stability             | Why cacheable                              |
|----------|---------------|-----------------------|--------------------------------------------|
| 1        | `identity`    | per-session stable    | Heaviest stable block; system role/persona |
| 2        | `tools`       | per-session stable    | Tool registry rarely changes mid-session   |
| 3        | `ontology`    | per-vault stable      | Concept graph evolves slowly               |
| 4        | `outputSchema`| per-task stable       | Schema mostly fixed for a task type        |

Memory (`recentChats` + `relevantNotes`) is intentionally **not** cacheable in
the default plan — it churns turn-by-turn, and marking it would invalidate the
cache after every send. Per the Relocation Trick (§5), memory moves to the user
message tail instead.

`PromptCache.hints(for: prompt, target: .anthropicMessages)` filters to subtrees
that are actually present in the Prompt (a missing subtree gets no breakpoint —
no wasted slot) and caps at 4.

For OpenAI / AFM / MLX, hints return empty: OpenAI auto-caches matching prefixes
and the on-device targets don't bill per token.

---

## §4 — Provider compatibility matrix

| Provider                       | Cache mechanism       | Render target           | Notes                                  |
|--------------------------------|-----------------------|-------------------------|----------------------------------------|
| Claude Sonnet 4.6 / Opus 4.6   | `cache_control`+TTL   | `.anthropicMessages`    | 4 breakpoints; Relocation Trick wins   |
| OpenAI / Codex                 | Automatic on prefix   | `.openAIResponses`      | No explicit markers; cache transparent |
| Apple Foundation Models (3B)   | KV cache reuse        | `.afmGenerable`         | Returns instructions + registered id   |
| Local Qwen / Hermes (MLX)      | KV cache + grammar    | `.mlxLocalGrammar`      | No billing; KV cache reuse via session |
| Perplexity Sonar Pro           | Automatic on prefix   | `.openAIResponses` (compat shape) | No tool calls; objective-only path |

The renderer never silently degrades — `RenderTarget` is a closed enum (per
`01_DOCTRINE.md §6 #4`) so adding a new provider requires explicit catalog
update + tests.

---

## §5 — The Relocation Trick (Anthropic-specific)

**Source:** ProjectDiscovery published a case study (Apr 2026) documenting a
59% cost reduction when relocating dynamic content to the prompt tail. The
Gemini deep-research dossier (`/Users/jojo/Downloads/final v3/`) corroborated
this with detailed mechanics; the existing `agent_core/src/prompt_caching.rs`
already implements a 4-breakpoint plan for the messages array.

**Mechanic:** Anthropic's prefix cache evaluates token hashes linearly. A
single token change mid-prefix invalidates everything downstream. So:

- **Wrong:** mash recent chats + memory + ontology + task into one big system
  block. Cache hit rate observed in production: ~7%.
- **Right:** keep identity + tools + ontology + outputSchema in the system
  block (cache_control: ephemeral). Move recent chats + memory.relevantNotes
  into a user message wrapped in `<session-context>` XML. Put the actual
  user objective last, tagged cache_control: ephemeral. Cache hit rate: ~84%.

The XML framing is critical — without it, the model frequently misinterprets
relocated context as a new user command requiring an immediate response. The
renderer applies framing automatically via `anthropicSessionContextBlock(...)`.

**Activation:** `prompt.cacheHints.applyRelocationTrick` (default `true` for
chat turns via `CacheHints.chatDefault`). When `false`, the renderer falls
back to the legacy monolithic shape — useful for parity tests + callers that
prefer a single user message.

**v1 scope note:** the foundation PR (this commit) wires the composer + the
renderer's relocation logic but does NOT yet touch the agent_core message
assembly path that actually sends the user-message tail. The Relocation Trick's
full cache-hit-rate gain lands in a follow-up PR that wires the rendered
`.anthropic(systemBlocks:messages:)` directly to the Rust SSE handler. v1
gives you JSPF + PTF + the system-prefix renderer; v2 gives you the cache
savings.

---

## §6 — How to add a new prompt subtree

1. Add a new field to `Prompt` (and its sub-types if needed).
2. Bump `Prompt.version` and write a migration in `PromptTreePersister.load(...)`
   that reads old envelopes and fills the new field with a default.
3. Add a case to `PromptSubtree` so the cache-hint plan can target it.
4. Decide cacheability: if stable, add to `CacheHints.chatDefault.stableSubtrees`
   and adjust the renderer's anthropicSystemPrefix order.
5. Add a `PromptNode.Filename` case + persist + load helpers.
6. Add a StructureRegistry entry pointing at the new subtree.
7. Add a unit test that exercises the new field through compose →
   render → persist → load.

Renaming an existing field is a breaking JSPF change — bump version + write
migration.

---

## §7 — Migration plan (legacy path → composer)

The composer + persister + renderer ship **alongside** the legacy
`baseSystemPromptParts.joined(...)` path in `ChatCoordinator.swift`. Both paths
coexist behind `EPISTEMOS_PROMPT_TREE=1`. Phased migration:

- **Phase 0 (this PR):** foundation + ChatCoordinator first agent turn wired
  behind feature flag. Default OFF. PTF directory appears at
  `<vault>/.epistemos/prompts/...` whenever the flag is on. Rust SSE handler
  unchanged — it still receives a String systemPrompt.

- **Phase 1 (in progress — Settings toggle ✅ shipped 1ab15596):**
  - ✅ Settings toggle for the feature flag (`Epistemos/State/PromptTreePreferences.swift` + footer row in `StructuredSurfacesView`).
  - ⚠️ Wire `RenderedPrompt.anthropic(systemBlocks:messages:)` into the Rust SSE handler so the Relocation Trick actually flows through to Anthropic — **blocked** on the substrate gap discovered in commit `1f6c575d`: `agent_core/src/session_insights.rs` is an orphan source file (never declared in lib.rs). Either integrate it OR pivot to the existing `ReasoningTrajectoryMetricsFFI` path in `agent_core/src/bridge.rs`. See `docs/plan/03_EXECUTION_MAP.md` "N1 Phase 1" entry for the discovery context.
  - ⚠️ `cached_tokens_share` parsing on the Anthropic response → Settings → Agent → Spend (W9.6 dashboard) — gated on the substrate fix above.

- **Phase 2 (follow-up PR):** wire LocalAgentLoop, SubconsciousService, and
  NightBrain to use the composer for their own prompt-assembly call sites.

- **Phase 3 (default-on cutover):** after two weeks of bake time confirming
  ≥30% cache-hit rate without quality regressions, flip the flag default-on.
  Telemetry stays for one more week. Then a separate PR removes the legacy
  string-joining path.

---

## §8 — WRV proof (this commit)

Per `00_AUTHORITY_AND_ANTI_DRIFT.md §4.7`, every PR includes a WRV proof block:

- **WIRED:** `grep -rn 'PromptComposer.compose' Epistemos/App/ChatCoordinator.swift`
  → ChatCoordinator.swift:2214 calls PromptComposer.compose(forChatTurn:) in a
  production code path (not test, not scaffold). Also: line 2235 calls
  PromptTreePersister.shared.persist; line 2256 calls
  PromptRenderer.anthropicSystemPrefix.

- **REACHABLE:** From a fresh app launch:
  1. Set `EPISTEMOS_PROMPT_TREE=1` in the launch environment (or via Xcode
     scheme env vars, or via Settings → Agent → Advanced toggle once that
     surface lands)
  2. Open Epistemos
  3. Start any chat (no special mode required)
  4. Send any message
  → On the agent invocation path, `PromptComposer.compose` runs, the resulting
  `Prompt` is persisted to `<vault>/.epistemos/prompts/<session>/0/`, the
  rendered system prefix replaces `baseSystemPrompt`, and an OSLog "N1 prompt
  tree active" line is emitted (visible in Console.app under com.epistemos
  category=ChatCoordinator).

- **VISIBLE:**
  - PTF directory at `<vault>/.epistemos/prompts/<session>/<turnIndex>/`
    browsable from Finder. Each file is pretty-printed JSON with sorted keys.
  - StructureRegistry's 5 N1 entries (prompt_root, prompt_identity,
    prompt_tools, prompt_memory, prompt_task) appear in Settings → Agent →
    Structures (the inspector wired in commit `33995d25`).
  - OSLog line on every render: `N1 prompt tree active session=<id> promptId=<hash>`.

NOT WRV_EXEMPT. N1 is foundational behavior that must be observable.

---

## §9 — Tests

Eight tests in `EpistemosTests/PromptTreeTests.swift`:

1. `compose_includesAllRequiredSections` — composer fills every section from typed inputs
2. `renderAnthropic_includesCacheControl_with4BreakpointCap` — system + objective tagged ephemeral; ≤4 breakpoints
3. `renderAnthropic_appliesRelocationTrick` — dynamic content moved to `<session-context>` user message
4. `renderOpenAI_omitsCacheControl` — no Anthropic-specific fields
5. `renderAFM_returnsGenerableSchema` — AFM render returns instructions + registered schema id
6. `cacheHints_capsAtFour` — 5 requested → 4 returned; memory drops as expected
7. `persist_writesPTFRoundTrip` — persist → load → Hashable-equal Prompt
8. `structureRegistry_includesNewPromptSchemas` — 5 entries registered with full maturity

Run via: `swift test --filter PromptTree`.

---

## §10 — Changelog

- 2026-04-27 — v0.1 — Initial spec. Foundation + ChatCoordinator first-turn
  wire shipped under `EPISTEMOS_PROMPT_TREE=1`. Relocation Trick + Rust SSE
  bridge + cached_tokens_share telemetry: follow-up PR.
