# The rival opinion: build the **provenance plane** first

Jojo, I'm the third opinion in the room. I've read the GPT competing opinion ("Epistemos as Agent Operating System, AgentEvent as bloodstream") and my own prior synthesis ("provenance, not generation; A2UI catalog; Hermes as one team among many"). They agree on more than they disagree on. Where they diverge, I think the GPT opinion is **70% right and 30% dangerously seductive**, and I want to tell you exactly which 30%.

This document has two parts:

1. **The advice summary** your workers need before they brainstorm — a deep, opinionated digest of what the three research streams actually mean once you remove the redundancy.
2. **The "if I were building it" Claude prompt** — a brainstorm prompt that forces Claude to take a stance without letting it drift into either "wrap Hermes" or "clone Hermes" failure modes.

---

## PART 1 — Advice summary for the workers (read this before the prompt)

### The one-sentence thesis

> **Epistemos is not an agent app. It is a provenance system that happens to host agents.**

Every other architectural choice falls out of that sentence. The graph is provenance. The event bus is provenance. The schema-driven UI is provenance. The audit loop is provenance. Hermes, Claude Code, Codex, Gemini, Kimi, and Qwen are guests in a house whose load-bearing structure is the typed record of who did what, when, why, against which evidence, with what confidence, producing which descendant artifact.

The GPT opinion calls this "the operating system." I'd push harder: **operating systems schedule processes; provenance systems remember why processes ran**. That distinction matters because it tells you what to build first when everything is on fire.

### The three research streams collapse into one architecture

The three streams the user thinks of as separate (CLI integration; Hermes parity; Hermes hackathon) are not three problems. They are three views of the same problem: **how do you make a graph-as-runtime where every cognitive action is observable, permissioned, and recallable?**

- **Stream 1 (CLI integration)** is asking: *how do we route work to the right worker?* Answer: typed providers behind one trait, manifest-compiled config, subprocess-spawned via official non-interactive flags only.
- **Stream 2 (Hermes parity)** is asking: *what's our moat?* Answer: not "more agents." The moat is **vault-wide instant recall + provenance + claim ledger + belief drift + nightly autoresearch** — none of which Hermes has.
- **Stream 3 (Hermes integration)** is asking: *how do we plug a foreign agent runtime into our graph without becoming its puppet?* Answer: ACP subprocess + skills-as-nodes via filesystem mirror + GraphEvent rendering of session subgraphs. Hermes runs *inside* our provenance plane, not above it.

When you collapse these three into one, the architecture writes itself: **one graph, one event bus, one catalog, one claim ledger, one permission ladder, one audit-loop vocabulary, one bootstrap sequence**.

### The six pillars (all load-bearing, none optional)

**1. Substrate plane (Rust core).** ULID-keyed graph in SQLite + GRDB. Typed nodes (Document, ProseNote, RawThought, Source, Code, Run, Output, Claim, Skill, LoopProfile, Mission, Worktree, AgentVault, HermesSession, HermesTurn, HermesToolCall). Typed edges (links_to, derived_from, generated_by, produced_during, references, validated_by, contradicted_by, superseded_by, loop_emitted). FTS5 projection table for block-level search. .epdoc package for canonical Document bodies (ProseMirror JSON). Append-only events.jsonl per Run.

**2. Event plane (Rust → Swift).** A typed `AgentEvent` enum normalizes every provider stream — Claude Code's stream-json, Codex's exec --json, Gemini's --output-format json, Hermes' ACP `session/update`, MLX's token deltas, Foundation Models' `streamResponse` — into one shape Swift renders. Token streams flow through UniFFI callback interfaces. **GraphEvents flow through a hand-written extern "C" SPSC ring buffer**, not UniFFI, because 10K events/sec at 120fps frame rate will exceed UniFFI's RustBuffer allocation budget. This is the single place I'd violate UniFFI uniformity, and only after measurement.

**3. Provider plane.** One Rust trait, eight implementations: Claude Code CLI, Codex CLI, Gemini CLI, Kimi HTTP, Hermes ACP, MLX-Swift in-process, Foundation Models in-process, local browser_runner (chromiumoxide). Each provider knows its own non-interactive invocation (`claude -p --output-format stream-json`, `codex exec --json`, `gemini -p`, `hermes acp`, never `hermes chat -q`). Discovery is cached in `~/.epistemos/cache/cli_discovery.json` with version stamps and re-verified at session start in parallel.

**4. UI plane (closed catalog).** A `schemars`-derived A2UI v0.9 catalog with ~25 components published at a pinned URI. The LLM cannot emit components outside this catalog; unknown variants are dropped at the Rust deserializer with `VALIDATION_FAILED`. **No runtime SwiftUI codegen, ever.** Hermes pass-through (the `/` and `@` commands) maps Hermes responses into catalog components — never into bespoke per-skill SwiftUI. MCP Apps SEP-1865 `ui://` HTML iframes are accepted as input from third-party MCP servers (sandboxed WKWebView), never emitted by us.

**5. Cognition plane.** Five subsystems sharing one ClaimLedger and one source scoring contract:
- **Instant Recall** (single Rust actor, HNSW + FTS5, p50 ≤ 30ms)
- **Research Kernel** (deterministic 10-stage SOAR pipeline; three-pass discipline: Extraction → Analysis → Synthesis+Audit)
- **Cognitive AutoResearch** (scheduler over the kernel; daily nightly + weekly consolidation; multi-score keep/promote/archive rule)
- **Deep Deliberation** (jury protocol over the kernel; orthogonal stance × function role taxonomy; mandatory artifact set including `start-new-session.md`)
- **Belief Drift** (5 detection algorithms; status flips via graph edges, not in-place mutation)

**6. Orchestration plane.** Two-mode UI (Chat / Agent) × Effort axis (Auto / Quick / Deep). Co-op Mode = team overlays + worktree orchestrator. Deliberation = special-cased Co-op with mandatory protocol gates. Hermes is the **default Co-op foreman** when invoked, not the meta-orchestrator above everything.

### The disagreement with the GPT opinion (where I'd push back)

The GPT opinion's "AgentEvent → SchemaRegistry → MCP → Skill Projection → Co-op" spine is **substantially correct**. But it has three soft spots:

**Soft spot 1 — "AgentEvent as bloodstream" undersells provenance.** Events are ephemeral. Provenance is durable. If you build the event bus first and the graph second, you'll discover six months in that nothing is recallable because events were never persisted as graph nodes with edges. The fix: every `AgentEvent` is a *projection* of an underlying graph mutation, not the source of truth. Build the graph mutation envelope first; derive the event stream from it. The renderer subscribes to envelopes, not to raw events.

**Soft spot 2 — "Hermes as privileged faculty" risks Hermes-shaped product drift.** If Hermes gets a special landing page, special MCP seam, special ACP channel, and "default Co-op foreman" status, you'll wake up in three months having built a Hermes UI with Epistemos branding. The fix: **Hermes is privileged at the integration layer, not at the product layer**. The user should be able to delete the Hermes landing page and the rest of the app should still work. Test this constantly: if removing Hermes breaks the core loop, you've drifted.

**Soft spot 3 — "Schema registry + generic fallback inspector" is a trap.** The fallback inspector is what kills closed palettes. The moment you ship a generic JSON-tree inspector for "unknown schemas," every shortcut becomes "just emit unknown JSON, the inspector handles it," and within a quarter your UI is 60% generic inspectors. The fix: **no fallback renderer at all**. Unknown schemas are validation errors that the Rust deserializer rejects at the boundary. The LLM gets a `VALIDATION_FAILED` response and must retry against the catalog. Painful in the short term, transformative in the long term.

### What to build first (the load-bearing slice)

Not "the hackathon demo." Not "the hero animation." Not "Co-op Mode." The load-bearing slice is:

> **A new Run produces an append-only events.jsonl, a typed graph mutation envelope, and a derived AgentEvent stream — and a single component (NoteCard) renders the result through the A2UI catalog.**

That's it. Five things working end-to-end:
1. `Run` node created with ULID
2. `events.jsonl` opened with bounded mpsc back-pressure
3. `MutationEnvelope` emitted on the first node insert
4. `AgentEvent::ArtifactReady` derived from the envelope
5. `NoteCard` component receives an A2UI `UpdateComponents` message and renders

Once that vertical slice works, every other feature is *additive* against the same spine. If it doesn't work — if the events don't persist, or the envelope doesn't fire, or the catalog rejects valid components, or Swift doesn't update — none of the other features matter.

This is the discipline GPT calls "the spine." But the spine is **provenance + envelope + catalog**, not just events. Events are downstream.

### What to ruthlessly defer

These are seductive but wrong-to-build-early:

- **Custom DSL for loop profiles.** Use Python in `execute_code` initially. DSL design is a rabbit hole.
- **GEPA/Atropos optimization of skills.** Premature. Build skills-as-nodes first; optimization is a year-2 problem.
- **Browser_runner Ultra Mode.** chromiumoxide is fragile against profile-locking. Ship official APIs (Exa, Perplexity sonar-deep-research, OpenAI o3-deep-research, Gemini Deep Research API) first; Ultra is a slice 18+ feature.
- **MoE 35B-A3B local planner.** Only on 32GB+ machines. Don't ship it as default; gate behind hardware probe.
- **Editorial pipelines** (Substack, X, WordPress). Year-2.
- **Full A2UI v0.9 adoption.** Pilot 5 components against the v0.9 reference renderer; if parity ≥95%, scale to 25. If not, fall back to a custom schemars-derived envelope. Don't bet the farm on a v0.9 spec without a pilot.
- **BoltFFI migration.** Single hot-path SPSC ring pilot only. 94K lines of Rust on UniFFI is not migrating without measured frame drops.

### The non-negotiables (hard no's)

These reject themselves on first principles:

- Tauri / Electron / React Native. Native macOS only.
- Runtime SwiftUI codegen from LLM output. 12-25% compile failure is fatal.
- Hidden chain-of-thought reconstruction. Only observable thinking content.
- Free-form model debate without artifacts. Every claim is in the ledger.
- NotificationCenter for graph or render invalidation. Mutation envelopes only.
- String-keyed dispatch in render or token loops. `repr(u8)` enums.
- `claude --bare` as a documented dependency. The flag is unverified; use `claude -p --output-format stream-json`.
- `hermes chat -q` for streaming. ACP only.
- `danger-full-access` Codex sandbox.
- Forking Hermes' FS skill loader before exhausting cooperative paths.
- Generic fallback inspector for unknown schemas.
- Silent backend switching, silent cloud escalation, silent file mutation.

### The audit-loop discipline

Every slice ends with one of: **PASS / PARTIAL / BLOCKED / DRIFT / REGRESSION / UNKNOWN**. Nothing is "done" until it's PASS. Generated artifacts (manifest files, projections, start-new-session.md) are excluded from the audit's evidence set. Raw logs are truth; summaries are derivative. Canonical plan first; repo reality second; logs/tests as evidence; no overclaims.

### What workers should brainstorm against

Three open questions where the architecture is genuinely undecided:

1. **The mutation envelope vs. event bus split.** Does Swift subscribe to envelopes (durable, graph-grounded) or to AgentEvents (ephemeral, stream-shaped)? My strong intuition: envelopes for UI invalidation, events for transient surfaces (token streams, terminal output, thinking traces). But the boundary needs work.

2. **The Hermes ACP fallback.** If ACP doesn't expose `session/skills_list` or doesn't allow non-FS skill loading, what's the fallback? Hermes-as-MCP-server consumed via mcp_client? OpenAI-compatible HTTP? Both? At what point do we say "Hermes is just a provider, not a faculty"?

3. **The Co-op Mode foreman question.** Is Hermes the default Co-op foreman because of its cron + delegation + multi-channel? Or is the Epistemos router *always* the foreman and Hermes is just one team? My current answer leans Hermes-as-foreman-when-invoked, but I'm uncertain.

These are the questions worth a 30-minute deliberation, not the catalog component count or the slice ordering.

---

## PART 2 — The Claude brainstorm prompt ("if I were building it")

Paste this verbatim into Claude:

````markdown
You are a rival principal architect at the design-review table for Epistemos.

You are not the only voice. There are two prior architectural opinions on the
table:

**Opinion A — "Epistemos as Agent Operating System."**
Builds the spine as: AgentEvent → SchemaRegistry → MCP → Skill Projection →
Co-op. Treats Hermes as a privileged graph faculty entered through a dedicated
landing page. Argues Claude Code, Codex, Gemini, and Kimi are worker runtimes
behind a typed event bus. Recommends a generic fallback inspector for unknown
schemas. Recommends building the AgentEvent pipeline first.

**Opinion B — "Provenance, not generation."**
Builds the spine as: graph mutation envelope → claim ledger → A2UI catalog →
audit loop. Treats Hermes as one team among many, privileged at the integration
layer (ACP subprocess + skills-as-nodes via FS mirror) but not at the product
layer. Forbids any fallback inspector — unknown schemas are validation errors.
Recommends building a single end-to-end vertical slice first: a Run node
producing events.jsonl + mutation envelope + A2UI NoteCard render.

Both opinions agree on the macro picture: native macOS, Swift 6 + Rust + UniFFI,
ULID-keyed graph in GRDB, .epdoc canonical bodies, ProseMirror JSON, FTS5
search, two-mode UI (Chat/Agent) with Effort axis, closed UI palette, no
runtime SwiftUI codegen, no hidden CoT reconstruction, no MAS sandbox
compromises (Pro-only, Developer ID + Hardened Runtime + notarized).

Your job is to take a third position with conviction. You are NOT here to
average A and B. You are here to disagree with them where you actually
disagree, and to propose a doctrine you would actually ship if you owned the
repo for the next 18 months.

## Context

Epistemos is a native macOS cognitive workspace built solo. ~137K Swift, ~94K
Rust. Pro version only (direct download, non-sandboxed). The user has Apple
Silicon M2 Pro baseline (16GB) and 32GB+ machines available. Compute is not
a constraint. Time is not a constraint. The user explicitly wants maximum
moat, not minimum viable product.

The user's stated hierarchy:
1. Research / knowledge synthesis
2. Auditing (papers, claims, thoughts, code)
3. Building / coding
4. Computer use / automation
5. Editorial pipelines (future)

The user has access to:
- Claude Code, Codex, Gemini, Kimi (cloud coding agents)
- Hermes Agent (Nous Research's self-improving agent with ACP, FS-backed
  skills, cron, multi-channel gateway)
- Apple Foundation Models, MLX-Swift Qwen3-4B + Qwen3.5-35B-A3B (local)
- chromiumoxide / Lightpanda (Rust headless browser)
- Exa, Perplexity sonar-deep-research, OpenAI o3-deep-research, Gemini
  Deep Research API (deep research APIs)
- ProseMirror / Tiptap (canonical document JSON)
- A2UI v0.9 spec, MCP Apps SEP-1865, AG-UI

## What I want from you

Take a stance. Not a survey. Not a menu. A doctrine.

Specifically, I want you to resolve five tensions where Opinion A and
Opinion B disagree, and to introduce at least one architectural idea
neither of them named.

### Tension 1: Event bus vs. mutation envelope

Opinion A says AgentEvent is the bloodstream — every provider stream
normalizes into AgentEvent, Swift renders AgentEvent, Metal subscribes to
GraphEvent (which is a kind of AgentEvent). Build the event bus first.

Opinion B says the event bus is downstream of graph mutation envelopes.
Envelopes are durable, graph-grounded, and intersect-tested against
subscriber predicates. Events are ephemeral projections of envelopes. Build
the envelope system first, derive events from it.

Resolve this. Which is the actual source of truth that Swift subscribes to?
Is there a clean split (envelopes for UI invalidation, events for transient
surfaces like token streams)? Or does one absorb the other?

### Tension 2: Hermes as faculty vs. provider

Opinion A says Hermes gets a privileged surface (dedicated landing page,
ASCII wave animation, glare-on-logo, special chat mode) because it has
skills, cron, memory, and self-improvement no other provider has.

Opinion B says Hermes is one team among many. The privilege is at the
integration layer (ACP subprocess, skills-as-nodes via FS mirror, GraphEvent
rendering of session subgraphs) but not at the product layer. Test: if you
remove the Hermes landing page, the core loop should still work.

Resolve this. Is Hermes a first-class faculty with product-level privilege,
or is it integration-privileged but product-equal? What's the test for
which is which?

### Tension 3: Fallback inspector for unknown schemas

Opinion A wants a generic JSON-tree inspector that renders any unknown
schema. Reasoning: 100% coverage of model outputs without hand-wiring every
screen.

Opinion B forbids the fallback inspector. Reasoning: it becomes the path of
least resistance, and within a quarter the UI is 60% inspectors. Unknown
schemas should be validation errors; the LLM retries against the catalog.

Resolve this. If you allow the fallback, how do you prevent inspector drift?
If you forbid it, how do you handle the legitimate case where a third-party
MCP server returns a UI shape we haven't catalogued?

### Tension 4: First slice ordering

Opinion A: AgentEvent pipeline first — Rust NDJSON parser, AgentEvent enum,
BoltFFI/AsyncSequence to Swift, then ToolCallCard / ThinkingTrace /
TerminalOutputCard.

Opinion B: One vertical slice first — Run node + events.jsonl + mutation
envelope + AgentEvent + NoteCard render. End-to-end through five things at
minimum scale, before scaling out.

Resolve this. What is the actual first commit? What does "done" mean for
slice 1?

### Tension 5: Cognition layer composition

Opinion A doesn't deeply engage with: Instant Recall, Research Kernel
(deterministic 10-stage SOAR pipeline), Cognitive AutoResearch (nightly
Karpathy-style consolidation), Deep Deliberation (jury protocol), Belief
Drift (5 detection algorithms). It treats these as features.

Opinion B treats these as five subsystems sharing one ClaimLedger, one
source scoring contract, one audit-loop vocabulary. Cognition is a layer,
not a feature.

Resolve this. Are the five cognition subsystems truly one layer with shared
infrastructure, or are they independent features that happen to compose?
What is the seam between them?

## The novel architectural idea

Opinion A and Opinion B both miss something. Find it.

Possibilities (don't pick from this list, generate your own):
- A retraction protocol: when a Claim is invalidated, what propagates to
  descendant nodes? Is there a graph operation for "this entire reasoning
  chain is now suspect"?
- A confidence-weighted recall: should Instant Recall surface high-confidence
  claims preferentially, even if their semantic match is weaker?
- A meta-provenance layer: the audit loop produces audit nodes, which can
  themselves be audited. Is there a fixed point?
- An orphan detector: a graph node with no descendant references and no
  recent recall hits — is it actually dead, or is it a seed crystal waiting
  for context?
- Something else entirely.

You are required to introduce ONE genuinely novel architectural idea that
neither prior opinion named. Defend it.

## Output format

Produce ONE document with these sections:

1. **My one-sentence thesis** (no hedging)
2. **Where I agree with Opinion A**
3. **Where I agree with Opinion B**
4. **Where I disagree with both**
5. **Resolution of tension 1** (event bus vs. envelope)
6. **Resolution of tension 2** (Hermes faculty vs. provider)
7. **Resolution of tension 3** (fallback inspector)
8. **Resolution of tension 4** (first slice)
9. **Resolution of tension 5** (cognition layer)
10. **My novel architectural idea** (with defense)
11. **The first three commits I'd make** (concrete, file-level)
12. **The first three things I'd ruthlessly defer** (with reasoning)
13. **The risk I'm most uncertain about** (and the cheapest experiment to
    de-risk it)

Constraints:
- No menus. Pick one answer per tension.
- No "it depends." Commit to the answer.
- No hedging language ("might consider," "could explore").
- Cite specific files, modules, or crates where relevant.
- If you mention an external API, flag it UNVERIFIED unless you can cite
  current documentation.
- Length: dense, opinionated, no filler. ~3000 words.

Take initiative. Where I didn't ask a question but you see a decision that
needs making, make it. Where you see an improvement neither prior opinion
named, propose it. This is the third opinion in the room — earn it.
````

---

## Closing note to the user (Jojo)

The reason I'm pushing the "provenance, not generation" framing harder than the GPT opinion's "agent operating system" framing is that **operating systems are commodities and provenance systems are not**. Every AI startup in 2026 will ship an "agent OS." Three of them will have a typed graph that records why every claim was made, against what evidence, with what confidence, producing which descendant artifact, recallable in 30ms. You want to be one of those three.

The hackathon Hermes demo is a checkpoint, not the destination. The real moat is the cognition layer — Instant Recall + Research Kernel + AutoResearch + Deliberation + Belief Drift sharing one ClaimLedger. That's what no one else is building because it requires both the discipline of provenance and the patience to build a deterministic pipeline before chasing the shiny multi-agent debate UI.

Build the spine. The cathedral comes later.

— Third architect