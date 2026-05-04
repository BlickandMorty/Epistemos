# Conversation Export — Epistemos Hardening & Agent Marketplace Brainstorm

**Exported:** 2026-04-06

---

## Initial Request — Hardening Prompt for Kimi Code

**User:**
> please turn this into a detailed easy executable prompt for kimi code to start building:
> 
> when i select a node i only want the labels of that node and its children nodes to show labels all other deselected nodes should have no label like they should dissapear when focus a node.
> 
> # issues with app:
> - add graph feature to inspect a node creates a full screen visualizer of the node if the node has nested nodes it will be different it will show all connections in a full view will unfocus all surrounding nodes they become invisible and the whole screen becomes that node or those connected cluster of nodes or nested nodes.  
> - When i delete a header the collapse indicator/toggle remains and i can only get rid of it by closing the app or switching to preview mode then back again.
> ## Graph:
> - The modes and labels flicker. they do not fade like they are supposed to and the performance and quality has regressed.
> - select a node and it should only have that node and its neighboring nodes label visible. 
> - improve. the selection focus. i need the old blur and dim i used to have but with the updated physics of my graph now. 
> - the light mode is still glitchy and buggy
> - i need to add the feature where the inspector panel can be pinned to the right side. 
> - simplify so create a plan to simplify the app by cutting the things i cant ship rn like agents pick a stack of local models as default add the new features, and deeply harden things and create the binary to make the app super super small. 
> - clean up the ui of the settings, graph, chats/model selector, etc.
> - add those specific hardening things i was supposed to add to app.
> - add graph support for adding a node directly and start working in it, etc.
> - add wikilinks and chat links so when a chat links a note it should be reflected on the graph vice versa with linking notes to other notes, etc.
> - find all crashes aswell
> - refer to the chatgpt pinned chat with how i should wrap up the release.
> - continue working on goose migration behind the scenes and researching agentic methods and models. continue researching models etc. stay in the tech and ai loop. 
> - baymax sdk. research baymax and ai integration using that method.
> 
> # crashes:
> ⚠️ Crash Analysis: FFI Memory Deallocation Failure
> 
> TL;DR: Your app crashed due to a memory management failure at the Swift/Rust boundary. Rust attempted to free a pointer that was either unallocated or already freed by Swift.
> 
> The stack trace clearly shows an abort() triggered by the system allocator (Signal 6). The exact error is ❌ ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED.
> 
> This happens on Thread 3 during a background async task. Specifically, EmbeddingService.swift (Line 215) calls into the Rust function graph_engine_recompute_semantic_neighbors. As that Rust execution concludes (or unwinds from a panic, as catch_unwind is in the trace), Rust attempts to run the drop trait to deallocate a Vec—likely a Vec<(u32, u32, f32)>.
> 
> You have a DOUBLE FREE or an ALLOCATOR MISMATCH. Because memory is crossing the Foreign Function Interface (FFI), ownership is getting confused. If Swift takes ownership of this data to use within the app, Rust must not clean it up; you must convert the Vector using into_raw() or std::mem::forget. Conversely, if Swift allocated that memory block and passed it in, Rust's allocator cannot legally free it.
> 
> TL;DR: The root issue is an FFI memory ownership conflict at line 215 of EmbeddingService.swift where Rust attempts to drop a Vector it doesn't exclusively own.
> 
> 💥 Epistemos Crash Analysis: Memory Allocation Error
> 
> TL;DR: The app crashed due to a severe memory management error where it attempted to free memory that was not currently allocated. This occurred at the Swift-Rust boundary during a graph engine computation.
> 
> The crash was triggered by a SIGABRT exception on Thread 11. The underlying system specifically flagged the error ___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED. This definitively points to a Double Free or an invalid pointer release.
> 
> The exact point of failure is located in your Rust backend, specifically within the graph_engine_recompute_semantic_neighbors function. The crash happens when Rust's drop checker attempts to clean up memory by dropping a Vec<(u32, u32, f32)>.
> 
> Because the call trace originates from closure #2 in EmbeddingService.computeAndPush(store:) in Swift, this is almost certainly an ownership issue across the Foreign Function Interface (FFI).
> 
> MEMORY LEAK/PANIC WARNING: You must strictly audit the memory ownership handoff between Swift and Rust. Ensure that Swift and Rust are not both attempting to manage, retain, or release the exact same pointer.

---

## Assistant Response — Kimi Code Execution Prompt

**Assistant:**
> This is the right kind of job for Kimi Code. Its own docs describe it as a terminal-first coding agent that can analyze a whole repo, plan multi-step work, execute commands, and iterate across files, which fits a graph/UI/FFI hardening pass like this.
> 
> One correction first: I could verify Kimi Code, but I could **not** confidently verify a single clear official "Baymax SDK" target from the web results. "Baymax" is overloaded across unrelated projects, so I turned that part into a **research-first identification task** instead of a blind implementation command.

### Generated Prompt for Kimi Code:

```md
# EPISTEMOS — SHIP-FOCUSED GRAPH / UI / FFI HARDENING EXECUTION PROMPT
# For Kimi Code
# Goal: start building immediately, reduce scope intelligently, fix regressions, harden for release, and preserve the premium feel of the app.

You are acting as a principal macOS systems engineer, Swift/Rust FFI engineer, graph UI specialist, and release hardening lead.

You are working on a native macOS app called **Epistemos** with a Swift + Rust architecture. Your job is not to brainstorm vaguely. Your job is to:
1. inspect the repo deeply,
2. map the current implementation,
3. define a shippable cut,
4. fix the highest-risk regressions and crashes first,
5. improve graph focus/labels/inspector behavior,
6. harden the app,
7. leave the codebase cleaner, smaller, and more stable than you found it.

Do not give me a fluffy plan and stop. Start executing.

---

## PRIMARY DIRECTIVE

This is a **ship-first cleanup and implementation pass**.

Prioritize:
1. **stability**
2. **correctness**
3. **graph UX clarity**
4. **UI cleanup**
5. **smaller shippable scope**
6. **binary size / app footprint discipline**
7. **future-facing research tracks only when they do not block release**

Do **not** let speculative agent systems, broad platform ambitions, or nonessential architecture work delay the shipping path.

If something is not realistically shippable now, cut it from the active release scope and move it into a clearly labeled deferred backlog with rationale.

---

## CORE PRODUCT PRINCIPLE

When a user focuses a node, the graph should feel like attention itself has narrowed.

That means:
- only the selected node's label and the labels of its relevant local context should remain visible,
- all unrelated labels should disappear,
- focus should feel calm, intentional, cinematic, and readable,
- surrounding graph content should dim/blur/de-emphasize smoothly,
- there should be no flicker,
- animations should feel premium and physically coherent.

---

# SECTION 1 — FIRST ACTIONS (MANDATORY)

Before changing code, do the following:

### 1.1 Inspect and map the codebase
Read and map all code relevant to:
- graph rendering
- graph labels
- graph physics / simulation
- selection/focus state
- inspector panel behavior
- node creation/editing flows
- note linking / wikilinks / chat links
- light mode theming
- settings UI
- chat/model selector UI
- EmbeddingService.swift
- Rust graph engine FFI boundary
- semantic neighbor recomputation
- crash-prone async/background tasks
- release build configuration / binary size / package dependencies

### 1.2 Produce these files first
Create these documents before major edits:

- `SHIP_SCOPE_V1.md`
- `SYSTEM_AUDIT_GRAPH_UI_FFI.md`
- `CRASH_REPRO_AND_OWNERSHIP_AUDIT.md`
- `IMPLEMENTATION_PLAN_EXECUTABLE.md`
- `DEFERRED_TRACKS.md`

These must be concise, technical, and actionable.

### 1.3 In SHIP_SCOPE_V1.md
Define:
- what is in scope for this release
- what is explicitly out of scope
- what is deferred
- what must be fixed before shipping
- what can wait

Be ruthless. If "agents" are not ready, cut them from active release scope.
If large speculative AI features are half-real, unstable, or confusing, reduce or hide them for now.

---

# SECTION 2 — HIGH-PRIORITY PROBLEMS TO SOLVE

## 2.1 Graph label visibility behavior
Implement this exact behavior:

### Desired behavior
When a node is selected:
- show the label for the selected node
- show labels only for:
  - its children
  - its nested nodes
  - its immediately connected/neighboring nodes if that relationship is part of the current graph model
- hide labels for all other deselected/unrelated nodes

When nothing is selected:
- use the current default overview behavior, but improve readability and consistency

When selection changes:
- labels should transition smoothly
- unrelated labels should fade out cleanly
- relevant labels should fade in
- no flicker
- no rapid re-layout jitter
- no sudden alpha popping unless reduced motion mode requires it

### Important
Do not solve this with hacks that merely toggle visibility every frame.
Implement a clear label visibility policy driven by graph focus state.

Create a label visibility architecture that separates:
- node selection state
- focus neighborhood computation
- label presentation state
- animation state

---

## 2.2 Full-screen "Inspect Node / Cluster" graph mode
Add a graph feature to inspect a node in a dedicated full-screen visualizer mode.

### Desired behavior
When the user selects "inspect node":
- the app enters a focused visualization mode for that node
- if the node has nested nodes, children, or a local cluster, show that cluster in a full-screen or immersive focused graph view
- unrelated surrounding nodes should become invisible or fully de-emphasized
- the screen should feel like it has "become" that node / cluster
- exiting the mode should restore the previous graph state without corruption

### Implementation requirements
- preserve navigation state
- preserve selection state
- preserve camera/viewport state if relevant
- do not destroy the main graph model just to render this
- avoid recomputing the entire universe if a subgraph projection can be derived
- design this as a focused subgraph visualization pipeline, not a brute-force hack

---

## 2.3 Graph flicker / fade regression
Current issue:
- graph modes and labels flicker
- fades are not behaving correctly
- performance and visual quality have regressed

You must identify:
- whether flicker comes from animation state churn
- whether labels are being recreated too often
- whether graph updates are invalidating too much state
- whether SwiftUI view identity / diffing is unstable
- whether Metal / rendering timing changed
- whether the physics update loop and presentation loop are stepping on each other

Deliver:
- root cause analysis
- exact fix
- before/after explanation
- regression test strategy

---

## 2.4 Selection focus visuals
Restore and improve the old focus quality:
- bring back the old blur/dim quality that made focus feel rich and intentional
- keep the improved/new graph physics
- do not regress interaction quality to get the visual effect back

This needs to feel like:
- clearer focus hierarchy
- stronger visual depth
- lower cognitive clutter
- elegant emphasis, not cheap opacity tricks

---

## 2.5 Light mode bugs
Audit and fix light mode comprehensively.

That means:
- colors
- materials
- contrast
- label readability
- graph visibility
- selection affordances
- inspector readability
- settings UI
- chat/model selector UI
- edge/link visibility
- hover/focus states

Do not just fix the most obvious bug.
Run a real light mode audit and leave it coherent.

---

## 2.6 Inspector panel pinning
Add the feature where the inspector panel can be pinned to the right side.

Requirements:
- stable layout behavior
- no view jumpiness
- no accidental overlay corruption
- pin/unpin state persistence if appropriate
- keyboard and mouse interactions remain sane
- it should feel native to macOS

---

## 2.7 Header deletion bug
Bug:
- when a header is deleted, the collapse indicator/toggle remains
- it only clears after closing the app or switching preview modes

Find the actual invalidation/state-sync bug and fix it properly.

Do not patch this with a forced refresh unless that is truly the cleanest correct fix.
Investigate:
- stale UI state
- orphaned collapse metadata
- derived view model not updating
- cache invalidation bug
- editor model / preview model mismatch

Add a regression test if possible.

---

## 2.8 Add graph support for direct node creation and immediate editing
I want users to be able to:
- add a node directly in the graph
- immediately start working in it
- edit it naturally without awkward mode switching
- have that node become a real first-class note/entity

Requirements:
- clean creation flow
- good default placement
- immediate naming/editability
- correct persistence
- correct graph update
- no weird temporary phantom state

---

## 2.9 Wikilinks and chat links reflected in graph
Add or complete support so that:
- note-to-note wikilinks show up in the graph
- chat-to-note links show up in the graph
- graph relationships reflect note links accurately
- if the graph is the source of a link, the note system reflects it too where appropriate

Design the linking model carefully:
- define canonical link identity
- define source/target rules
- define sync/update behavior
- avoid duplicate edges from multiple ingestion paths
- avoid broken graph state from deleted targets

This must work as a coherent data model, not a bunch of disconnected visual tricks.

---

# SECTION 3 — CRASHES / FFI / MEMORY OWNERSHIP (TOP PRIORITY)

We have a reported crash:

- allocator abort
- `___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED`
- likely double free / invalid free / allocator mismatch
- occurs at Swift/Rust boundary
- connected to:
  - `EmbeddingService.swift`
  - line ~215
  - `graph_engine_recompute_semantic_neighbors`
  - background async task
  - Rust dropping `Vec<(u32, u32, f32)>` or related returned/bridged memory

Treat this as a **critical stop-ship bug**.

## 3.1 FFI audit task
Perform a full ownership audit for every Swift <-> Rust memory handoff involved in:
- semantic neighbor recomputation
- graph engine results
- buffers / vectors / slices returned across FFI
- async callbacks
- panic/unwind boundaries
- cleanup/destructor paths

## 3.2 Verify all of the following
- who allocates each buffer
- who owns it after handoff
- who is allowed to free it
- whether Rust is dropping memory Swift still references
- whether Swift is freeing Rust-owned memory incorrectly
- whether `Vec`/slice exposure is unsound
- whether `catch_unwind` is masking an ownership bug
- whether there is allocator mismatch
- whether raw pointer lifetime is outliving the originating allocation
- whether background task concurrency is causing duplicate cleanup

## 3.3 Required outcome
Refactor the FFI boundary so memory ownership is explicit and impossible to misunderstand.

Prefer:
- explicit create/free APIs
- raw-pointer contracts with one owner
- clear bridge structs
- no ambiguous shared ownership
- no hidden deallocation side effects
- no "Swift copies this maybe, Rust frees later maybe" nonsense

If needed:
- redesign the FFI for safer ownership semantics
- introduce dedicated Rust free functions
- convert outgoing vectors with `into_raw_parts`-style ownership transfer or equivalent safe pattern
- avoid Rust dropping memory after transferring ownership
- ensure Swift never frees memory it did not allocate unless using an explicit Rust-provided free function

## 3.4 Crash validation
After fixing:
- reproduce prior crash path if possible
- run debug + release
- run with sanitizers where meaningful
- run repeated stress test loops
- run concurrent recomputation attempts
- verify no double free
- verify no use-after-free
- verify no panic/unwind invalidation

Document all findings in:
`CRASH_REPRO_AND_OWNERSHIP_AUDIT.md`

---

# SECTION 4 — RELEASE SIMPLIFICATION / CUTS

I want the app simplified for shipping.

## 4.1 Simplify aggressively
Create a shipping plan that:
- cuts features that are not ready
- hides unfinished systems
- defaults to a clear local-model stack
- removes or defers unstable agent surfaces
- reduces confusion in settings and model selection
- strengthens the core app identity

## 4.2 Local model defaults
Propose a sensible default local model stack for now.

Do not overbuild model routing.
Choose a minimal, coherent default set that supports:
- chat
- note interaction
- maybe one stronger reasoning option if already stable
- predictable UX

If model complexity is hurting clarity, reduce it.

## 4.3 Binary size / app footprint
Audit what is inflating the binary/app size and reduce it where possible without breaking the product.

Investigate:
- unused dependencies
- duplicate assets
- unnecessary debug artifacts
- dead code paths
- over-linked frameworks
- packaging waste
- unneeded bundled models/resources

Produce a small but realistic footprint plan.
Do not destroy capability just to chase a fake tiny-number fantasy, but do shrink the app meaningfully.

---

# SECTION 5 — UI CLEANUP

Audit and improve:
- settings UI
- graph UI
- chats UI
- model selector UI
- inspector UI

Targets:
- cleaner hierarchy
- less clutter
- fewer half-baked controls
- clearer grouping
- better defaults
- more consistent spacing
- native-feeling interaction patterns
- preserve premium feel

Do not redesign the app into something generic.
Refine it.

---

# SECTION 6 — HARDENING

Add the hardening work the app was supposed to get.

You must identify what hardening already exists, what is missing, and what must be added now.

Areas to harden:
- crash handling
- FFI boundaries
- concurrency isolation
- background task cancellation
- state invalidation
- view model ownership
- graph update scheduling
- persistence safety
- link/index consistency
- editor/preview synchronization
- release build settings
- logging/diagnostics
- graceful failure behavior
- startup safety
- migration safety

Deliver:
- hardening checklist
- implementation of high-priority missing protections
- verification steps

---

# SECTION 7 — CRASH DISCOVERY

Find additional crashes.

Not just obvious compile errors.
I want active crash hunting.

Do all of the following:
- inspect existing crash-prone code paths
- add targeted logging where needed
- create reproducible scenarios
- test rapid graph selection changes
- test node deletion / creation / relinking
- test editor changes while graph updates
- test light/dark mode switching
- test inspector pin/unpin
- test semantic recomputation loops
- test note/chat linking mutations
- test opening/closing heavy graph views
- test focused inspect mode enter/exit repeatedly

Create:
- `CRASH_HUNT_REPORT.md`

For each crash/risk:
- repro steps
- root cause
- severity
- fix status
- follow-up if deferred

---

# SECTION 8 — RELEASE DISCIPLINE

Use a ship-first release discipline.

That means:
- stop expanding the vision during implementation
- stabilize the core product
- keep future architecture documented but separate
- do not let "agent dreams" derail the release
- prefer a smaller coherent product over a sprawling unstable one

If you find half-built or misleading product surfaces:
- either finish them properly now,
- hide them,
- or cut them from the release path.

No fake completeness.

---

# SECTION 9 — GOOSE MIGRATION / AGENTIC RESEARCH / MODEL RESEARCH

Continue the goose migration and agent/model research only as **parallel non-blocking tracks**.

That means:
- do not let them delay the current release work
- do not wire half-finished agent systems into the shipping build
- instead create a structured deferred track with:
  - current status
  - blockers
  - opportunities
  - next concrete steps

Create this in:
- `DEFERRED_TRACKS.md`

Include sections for:
- goose migration
- agentic methods research
- current model landscape tracking
- possible future integrations

---

# SECTION 10 — BAYMAX RESEARCH TASK

There is a request to research "Baymax SDK" and AI integration using that method.

Do not assume what "Baymax" refers to.

Your task:
1. identify what Baymax SDK / framework / project is actually intended
2. search the repo/docs/notes for internal references
3. determine whether this is:
   - an SDK,
   - an architecture pattern,
   - a research reference,
   - a third-party integration,
   - or a mistaken/ambiguous name
4. only after identification, propose whether it is relevant to Epistemos

If unclear:
- document ambiguity
- present likely candidates
- recommend whether to defer

Do **not** implement a random Baymax-related integration blindly.

---

# SECTION 11 — IMPLEMENTATION ORDER

Execute in this order unless repo inspection proves a better dependency chain:

## Phase 1 — Audit and scope
- map code
- define ship scope
- define deferred scope
- reproduce crash
- identify graph label/focus architecture
- identify UI cleanup targets

## Phase 2 — Critical stability
- fix FFI memory ownership crash
- fix header deletion/collapse stale state bug
- identify and fix major graph flicker regression
- fix light mode correctness issues that break usability

## Phase 3 — Core graph UX
- implement selected-node local-label visibility behavior
- restore/improve blur/dim focus
- add focused inspect-node/cluster mode
- add pinned inspector panel
- add direct graph node creation/edit flow

## Phase 4 — Data coherence
- wire wikilinks/note links/chat links into graph coherently
- fix sync/persistence/indexing issues
- add regression coverage where practical

## Phase 5 — UI simplification and hardening
- clean settings / graph / chat / model selector UI
- reduce scope
- hide incomplete features
- harden lifecycle/concurrency/state handling
- optimize binary/app footprint

## Phase 6 — validation
- build debug and release
- run manual verification flows
- run stress tests
- update docs with what changed and what remains

---

# SECTION 12 — ENGINEERING RULES

## 12.1 Do not break existing good behavior
If an older behavior was better, preserve or restore the quality without reintroducing old architectural weaknesses.

## 12.2 Prefer root-cause fixes
No shallow patching unless clearly justified.

## 12.3 Avoid fake progress
Do not produce long status messages without code movement.

## 12.4 Keep state architecture clean
Avoid scattered booleans and ad hoc UI toggles.
Centralize focus/selection/label visibility state properly.

## 12.5 Respect Swift/Rust boundaries
No ambiguous ownership.
No unsafe lifetime assumptions.
No allocator confusion.

## 12.6 Preserve native quality
This is a native app.
Interactions should feel deliberate, smooth, and macOS-appropriate.

---

# SECTION 13 — REQUIRED DELIVERABLES

By the end of this pass, I want:

### Docs
- `SHIP_SCOPE_V1.md`
- `SYSTEM_AUDIT_GRAPH_UI_FFI.md`
- `CRASH_REPRO_AND_OWNERSHIP_AUDIT.md`
- `IMPLEMENTATION_PLAN_EXECUTABLE.md`
- `CRASH_HUNT_REPORT.md`
- `DEFERRED_TRACKS.md`
- `RELEASE_HARDENING_CHECKLIST.md`

### Product outcomes
- node label visibility behavior fixed
- inspect node / cluster focused mode implemented or scaffolded properly with working core flow
- header deletion stale collapse indicator bug fixed
- graph flicker/fade regression fixed
- focus blur/dim restored/improved
- light mode stabilized
- inspector right-side pinning implemented
- direct graph node creation/edit flow working
- note/chat/wiki links coherently reflected in graph
- FFI memory crash fixed or isolated with a hard proof and safe remediation path
- UI cleaner and more shippable
- release scope simplified

---

# SECTION 14 — REQUIRED VERIFICATION

After implementation, provide a verification section with:

## Manual test matrix
Include exact steps and expected results for:
- selecting a node
- changing node selection rapidly
- deselecting nodes
- focused inspect mode entry/exit
- inspector pin/unpin
- deleting headers
- adding nodes from graph
- creating wikilinks
- creating chat-note links
- graph sync correctness
- light mode
- dark mode
- semantic recompute background tasks
- reopening the app
- release build smoke test

## Technical verification
- compile status
- warnings introduced/removed
- sanitizer findings if run
- crash repro status before/after
- perf/regression notes
- known remaining risks

---

# SECTION 15 — OUTPUT STYLE

Work in this style:
- concise
- technical
- honest
- no hand-waving
- no fake confidence
- no giant speculative redesign unless justified by repo reality

When blocked:
- state the exact blocker
- show what you inspected
- propose the next best move
- keep moving on other non-blocked tasks

---

# FINAL INSTRUCTION

Start now.

First:
1. inspect the repo,
2. create the required audit/scope docs,
3. identify the graph label/focus architecture,
4. reproduce and audit the FFI crash path,
5. then begin implementation in the required order.

Do not wait for me unless absolutely necessary.
Do not ask broad planning questions you can answer by reading the code.
Make the app more stable, more focused, more native, and more shippable.
```

---

## User Follow-up — Export Request + Agent Marketplace Brainstorm

**User:**
> can u turn thi entire convo into a md like export the entire thread data into a md or txt
> 
> and i am also trying to implement a marketplace for agents but i want the default models to be fine tuned already i want the best local models for specific things like tool calling and coding, writing, etc. i want to use the new gemma 4 in all of its new advancements, etc. but i ofc want to use a custom one on hugging face or one of the users online.

---

## Brainstorm Section — Agent Marketplace + Fine-Tuned Local Model Strategy

### The Vision

A two-tier AI system:
1. **Default Stack**: Curated, fine-tuned local models shipped with the app — optimized for specific tasks (tool calling, coding, writing, reasoning)
2. **Marketplace**: Users can discover, download, and use custom models from Hugging Face or community creators

### Core Philosophy

- **Ship-First**: The default stack must be flawless before marketplace complexity
- **Task-Optimized**: Different tasks need different model capabilities — one size doesn't fit all
- **Local-First**: Everything runs on-device by default, cloud only as explicit opt-in
- **Composable**: Agents can mix models — coding model for code, writing model for prose, etc.

### Default Model Stack Proposal

```
┌─────────────────────────────────────────────────────────────┐
│                  EPISTEMOS DEFAULT STACK                    │
├─────────────────┬─────────────────┬─────────────────────────┤
│ Task            │ Model           │ Size / Notes            │
├─────────────────┼─────────────────┼─────────────────────────┤
│ General Chat    │ Gemma 4 4B/9B   │ Balanced, fast          │
│ Tool Calling    │ Gemma 4 4B-IT   │ Fine-tuned for tools    │
│ Coding          │ Qwen 2.5 Coder  │ 7B or 14B variant       │
│                 │   or Gemma 4    │                         │
│ Writing/Prose   │ Gemma 4 9B      │ Long context, creative  │
│ Reasoning       │ Gemma 4 27B     │ Deep analysis mode      │
│ Embeddings      │ Nomic Embed     │ Small, fast, quality    │
│                 │   or BGE-M3     │                         │
└─────────────────┴─────────────────┴─────────────────────────┘
```

### Gemma 4 Specific Advantages

From Google's Gemma 4 announcement (March 2025):
- **Native multimodal**: Vision + text in one model
- **Long context**: 128K tokens standard
- **Efficient**: Runs well on consumer hardware
- **Tool use**: Native function calling capabilities
- **Knowledge cutoff**: Recent, can be further fine-tuned

Integration strategy:
- Use Gemma 4 as the primary backbone
- Fine-tune variants for specific Epistemos tasks
- Leverage native tool calling for graph operations

### Agent Marketplace Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    AGENT MARKETPLACE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  Curated     │    │  Community   │    │   Custom     │       │
│  │  Agents      │    │  Agents      │    │   Import     │       │
│  │  (Official)  │    │  (HF/Local)  │    │  (User HF)   │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             ▼                                   │
│                   ┌─────────────────┐                           │
│                   │  Agent Manifest │                           │
│                   │  (JSON spec)    │                           │
│                   └────────┬────────┘                           │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                │
│         ▼                  ▼                  ▼                │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐           │
│  │  Required   │   │  Model      │   │  Tool       │           │
│  │  Models     │   │  Config     │   │  Bindings   │           │
│  │  (auto-dl)  │   │  (routing)  │   │  (native)   │           │
│  └─────────────┘   └─────────────┘   └─────────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Agent Manifest Format

```json
{
  "manifest_version": "1.0",
  "agent": {
    "id": "epistemos.coder-agent",
    "name": "Code Companion",
    "description": "Specialized agent for code analysis and generation",
    "version": "1.2.0",
    "author": "Epistemos Team",
    "license": "MIT"
  },
  "models": {
    "primary": {
      "repository": "unsloth/gemma-4-9b-it-code",
      "quantization": "Q4_K_M",
      "context_length": 32768,
      "fallback": "local/qwen-2.5-coder-7b"
    },
    "embedding": {
      "repository": "nomic-ai/nomic-embed-text-v1.5"
    }
  },
  "capabilities": {
    "tools": ["graph_query", "note_search", "code_interpreter"],
    "modalities": ["text", "code"],
    "max_tokens_per_response": 4096
  },
  "routing": {
    "trigger_patterns": [
      {"pattern": "```\\w+", "confidence": 0.9, "action": "activate"},
      {"pattern": "write.*code|fix.*bug|refactor", "confidence": 0.8}
    ],
    "auto_select": true
  },
  "system_prompt": "You are a coding assistant integrated into Epistemos...",
  "fine_tuning": {
    "adapter": "lora",
    "weights_path": "adapters/code-agent-lora.gguf"
  }
}
```

### Model Routing Logic

```swift
// Pseudocode for intelligent model routing
enum TaskType {
    case chat, code, writing, reasoning, toolUse, embedding
}

struct ModelRouter {
    let defaultStack: [TaskType: ModelConfiguration]
    let userOverrides: [String: ModelConfiguration]
    let marketplaceAgents: [AgentConfiguration]
    
    func route(_ task: Task) -> ModelSession {
        // 1. Check if a marketplace agent claims this task
        if let agent = marketplaceAgents.first(where: { $0.shouldHandle(task) }) {
            return agent.createSession()
        }
        
        // 2. Check user overrides
        if let override = userOverrides[task.id] {
            return ModelSession(configuration: override)
        }
        
        // 3. Fall back to default stack
        let taskType = classify(task)
        return ModelSession(configuration: defaultStack[taskType]!)
    }
    
    private func classify(_ task: Task) -> TaskType {
        // Use lightweight classifier or regex patterns
        // Could also use a tiny on-device model for this
    }
}
```

### Hugging Face Integration

```
┌────────────────────────────────────────────────────────────┐
│              HUGGING FACE INTEGRATION                       │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Search & Discovery                                         │
│  ├── Filter: gguf, mlx, coreml compatible                  │
│  ├── Sort: downloads, trending, epistemos-verified         │
│  └── Preview: model card, benchmarks, sample outputs       │
│                                                             │
│  Download & Management                                      │
│  ├── Resume-able downloads                                 │
│  ├── Quantization selection (Q4, Q5, Q6, Q8)               │
│  ├── Auto-conversion to MLX (Apple Silicon optimized)      │
│  └── Storage management (cache, cleanup)                   │
│                                                             │
│  Verification                                               │
│  ├── SHA256 checksum verification                          │
│  ├── Epistemos compatibility badge                         │
│  └── Community ratings & reviews                           │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### Fine-Tuning Pipeline (Future)

```
┌─────────────────────────────────────────────────────────────┐
│              ON-DEVICE FINE-TUNING                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User provides:                                              │
│  ├── Example conversations (10-100 samples)                 │
│  ├── Preferred output style                                 │
│  └── Specific domain (legal, medical, etc.)                 │
│                                                              │
│  Pipeline:                                                   │
│  1. Validate training data                                   │
│  2. Select base model (Gemma 4 4B or 9B)                    │
│  3. LoRA adapter training (QLoRA for efficiency)            │
│  4. Evaluate on validation set                              │
│  5. Package as agent manifest                               │
│  6. Optional: Share to marketplace                          │
│                                                              │
│  Output: Personalized agent with ~50MB LoRA adapter         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Phases

**Phase 1: Default Stack Hardening** (Current Focus)
- Ship with 2-3 carefully selected models
- Gemma 4 4B/9B for general use
- One coding-optimized model
- Perfect the routing between them

**Phase 2: Custom Model Import** (Next)
- Allow users to add their own GGUF/MLX models
- Simple file picker + metadata form
- No marketplace yet, just personal use

**Phase 3: Curated Marketplace** (Later)
- Official Epistemos agents
- Verified community agents
- Hugging Face integration

**Phase 4: Full Ecosystem** (Future)
- Agent builder UI
- Fine-tuning on device
- Revenue sharing for creators

### Technical Considerations

**Model Format Strategy:**
- **MLX** (Apple Silicon): Best performance, native to macOS
- **GGUF** (llama.cpp): Universal compatibility, good fallback
- **Core ML**: For specific optimized use cases

**Storage & Memory:**
- Models stored in `~/Library/Application Support/Epistemos/Models/`
- LRU cache for loaded models
- Memory pressure handling
- Background download with progress

**Security:**
- Sandboxed model execution
- Verified signatures for marketplace agents
- User consent for network-trained models

---

## Summary

This document captures:
1. The full Kimi Code execution prompt for hardening the app
2. A comprehensive brainstorm for an Agent Marketplace with fine-tuned local models
3. Gemma 4 integration strategy
4. Hugging Face custom model support
5. Phased implementation approach

The key insight: **harden the default stack first**, then layer on marketplace complexity. Ship a flawless core experience before building the ecosystem.
