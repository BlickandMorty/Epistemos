# SS-WL — WikiLink-driven auto-research for local + cloud models (2026-06-20)

Owner: *"things like Google's take on Karpathy's wiki link and the original wiki link — anything that references
wikilink / auto-research, I want those. Particularly because I really want that to be useful for my models, local AND
cloud, and I believe wikilink is one of the best ways to make that happen. So pour that in, and logic/auto-research could
be supported as launching overnight or just a feature of the app. Deep these things, add to the ledgers / plan as a
dedicated cycle of implementations."* **NEW feature** (deep research → dedicated build cycle). NON-INVASIVE; outside the
Companion→Osaurus boundary.

## Concept (grounded)
A `[[wikilink]]` is a first-class, resolvable knowledge edge: writing `[[Concept]]` in a note/chat/Epdoc links to (and,
if missing, can spawn) a node for that concept. "Karpathy/Google's take" = using wikilink graphs as the substrate an LLM
traverses + auto-fills: an UNRESOLVED `[[link]]` becomes an auto-research task — the model researches the target
(local-first, cloud when escalated) and writes a stub/expansion back, so the knowledge graph self-completes over time.
This makes both local and cloud models materially more useful: the link graph is durable, inspectable context (feeds the
Model Vault `active_context.md` / `concept_index.md` — cross-ref SS-MV) rather than ephemeral chat.

## Current state (what exists / what's missing)
- **No real wikilink parser / resolver.** Grep for `[[ ... ]]` parsing returns mostly `[[String: Any]]` Swift-type false
  positives; no `WikiLinkParser` / `resolveLink` / backlink index exists. `InstantRecallService.swift` does recall but not
  `[[link]]` resolution.
- **`AutoresearchLoop` is NOT this.** `KnowledgeFusion/Autoresearch/AutoresearchLoop.swift` is a **QLoRA training-experiment**
  loop (`trainer: QLoRATrainer`, `tracker`, `evaluator`, `trainingBudget`, `runOneIteration(modelPath:dataPath:…)`) — model
  fine-tuning experiments, unrelated to wikilink knowledge research. Reuse its scheduling/cancellation SHAPE, not its body.
- **Scheduling primitives exist to build on:** `KnowledgeFusion/Alignment/TrainingScheduler.swift`, `FSRSDecayState`, the
  background-activity entitlement (the macOS "Epistemos can run in the background" toast in the screenshots) — an overnight
  batch can ride these.

## Proposed build (dedicated cycle — research each sub-part into its own slice as picked up)
1. **WikiLink parser + resolver + backlink index** [M] — parse `[[Target]]` / `[[Target|alias]]` in notes, Epdoc, and
   chat; resolve to an existing note/concept or mark UNRESOLVED; maintain a backlink index. Pixel-art autocomplete on `[[`.
   (Wire into the existing Prose/Epdoc editors NON-INVASIVELY — TK2/Prose stays non-invasive.)
2. **Auto-research task from an unresolved link** [M] — an unresolved `[[link]]` (or an explicit "research this") enqueues a
   research task: local-first model researches the target, writes a stub/expansion note + provenance. Honest capability
   gating (local fast/think; cloud agent/liveAgent). Reuse SS-CR-correct routing; never fake caps.
3. **Overnight / on-demand runner** [M] — a batch runner (background-activity entitlement) processes the unresolved-link
   queue overnight or on demand; surfaced as an app feature with honest status (queued / researching / written), cancel,
   and a log. Bounded + rollback-safe; no hidden subprocess (in-process MLX / cloud URLSession only).
4. **Feed the Model Vault** [S-M] — researched results enrich `active_context.md` / `concept_index.md` so models
   (local + cloud) carry the link graph as context (depends on SS-MV injection landing first).
5. **Provenance + honesty** — every auto-written node tagged with its source (which model, when, evidence). Surface in the
   note + the System tab. No silent fabrication; mark low-confidence stubs as such.

## Constraints / order
Build on SS-MV (per-model injection must work first so the researched context actually reaches the model). NON-INVASIVE to
TK2/Prose + Metal + the two owner scope-boundary domains. Honest/test-backed/no-green-without-witness. Dedicated cycle
AFTER the SS-MV repair + the current owner-facing quick wins (SS-SH/GC/DD/THX/TC/QC). Each sub-part = its own SS-* slice +
tests when the loop picks it up.

---

## GitHub / fork research — best-of-breed combination (owner 2026-06-20: "go deep into the forks, 100% implement the best parts in the best combination, for an in-use feature AND an overnight training feature")

### What the owner's reference IS: Karpathy's "LLM Wiki" pattern (+ Google/community iterations)
The "original wikilink + Google's take on Karpathy's wikilink" = **Karpathy's LLM Wiki** pattern. Canonical mechanics
([gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)):
- **3 layers:** raw sources (IMMUTABLE) → wiki (LLM-maintained `.md`, interlinked) → schema (a CLAUDE.md-style config that
  makes the LLM a *disciplined* maintainer). Maps cleanly to Epistemos vault notes → Model Vault → instructions.md.
- **`index.md`** (catalog, one-line summary per page) + **`log.md`** (append-only ingest/query/maintenance record).
- **Ingest:** read source → write summary page → update index → revise relevant entity/concept pages → append log;
  ~10–15 pages cross-referenced per source. **Query:** read index first → synthesize w/ citations → SAVE valuable answers
  as permanent pages (not lost to chat).
- **Contradiction handling:** flag (don't silently overwrite); keep an audit trail of what was believed when.
- **⭐ LINT step:** periodic health check for stale claims, orphan pages, missing cross-refs, contradictions — *this is
  exactly the owner's anti-messiness/muddiness discipline*; cross-ref **SS-CLEAN**.

### Repos studied (deep, incl. forks)
- **Implementation to mine — [nashsu/llm_wiki](https://github.com/nashsu/llm_wiki)** (Tauri/Rust + React desktop; closest
  to Epistemos's Rust core). Best implementable ideas: (a) **two-step CoT ingest** (analyze → then generate) for quality +
  source traceability; (b) **SHA256 incremental cache** to skip unchanged sources (big token savings); (c) **persistent
  ingest queue** — serial (no concurrent LLM calls), crash-recovery, folder auto-watch, 3× retry → the backbone of the
  OVERNIGHT runner; (d) **4-signal relevance** (direct-link ×3.0, source-overlap ×4.0, Adamic-Adar ×1.5, type-affinity ×1.0);
  (e) **wikilink + YAML `sources[]` frontmatter hybrid** (human nav + programmatic cascade/cleanup); (f) Louvain community
  detection + "isolated page / sparse community" insights; (g) Obsidian-compatible export (no lock-in).
- **Typed-edge fix — [penfieldlabs "What Karpathy's LLM Wiki Is Missing"](https://dev.to/penfieldlabs/what-karpathys-llm-wiki-is-missing-and-how-to-fix-it-1988)**:
  plain `[[wikilink]]` carries 1 bit ("connected"). Fix = **typed wikilinks** (`obsidian-wikilink-types`, `@`-syntax, ~24
  relationship types: `supersedes`/`contradicts`/`causes`/`supports`/`evolution_of`/`prerequisite_for`…) synced to YAML, +
  AI-discovered relationships (a "Vault Linker" pass), + persistent KG with hybrid keyword+semantic+graph search.
  **⭐ Epistemos ALREADY HAS this substrate** — `agent_core/src/cognitive_dag/` has 10 `EdgeKind`s incl. `Contradicts` +
  `DerivesFrom`, resonance propagation, TruthCache. BEST COMBINATION = map typed wikilinks onto the EXISTING cognitive_dag
  EdgeKinds instead of reinventing (NOTE: cognitive_dag/companions.rs is boundary — touch only the wikilink-relevant edges,
  not companion code).
- **In-use parser (study for SYNTAX + resolution; implement NATIVELY in Swift/Rust, not JS):**
  [flowershow/remark-wiki-link](https://github.com/flowershow/remark-wiki-link) (Obsidian-style: `[[Page]]`, `[[Page|alias]]`,
  `[[Page#section]]`, `[[Page#section|alias]]`, `![[embed]]` w/ image/media/pdf + dims; **unresolved → `new` class** =
  the auto-research hook; resolution via permalinks map / urlResolver / `shortestPossible` Obsidian ambiguity); maintained
  forks [rgruner/markdown-it-wikilinks-plus](https://github.com/rgruner/markdown-it-wikilinks-plus) (ESM/CJS/TS, `[[/Path/Page]]`),
  [C1200/remark-wikilinks](https://github.com/C1200/remark-wikilinks), [boehs/markdown-it-wikilinks](https://github.com/boehs/markdown-it-wikilinks).
  Backlink/transclusion CLI reference: [anuna/zetl](https://codeberg.org/anuna/zetl) (bidirectional graph + transclusion panel).

### Best-combination spec (the two features the owner wants, kept SEPARATE so they don't muddy)
- **(I) IN-USE FEATURE** (live, synchronous, in the editor/chat): native `[[wikilink]]` parser w/ the full flowershow syntax
  set + `new`/unresolved styling + `shortestPossible` resolution + **typed edges** (`@type` → cognitive_dag EdgeKind) +
  bidirectional **backlink index** + `[[`-autocomplete (pixel-art). Wire into Prose/Epdoc NON-INVASIVELY. No network on the
  hot path — resolution is local/instant.
- **(II) OVERNIGHT TRAINING/RESEARCH FEATURE** (async, batched, background-activity entitlement): the Karpathy ingest +
  lint workflow driven by nashsu's **persistent queue** (serial, SHA256-cached, crash-recovery, 3× retry) — unresolved
  `[[links]]` + a "Vault Linker" relationship-discovery pass become auto-research tasks (local-first per SS-CR routing),
  writing summary/entity pages + typed edges + `log.md` entries + feeding Model Vault `active_context`/`concept_index`
  (SS-MV). 4-signal relevance + Louvain clustering for surfacing. Honest provenance on every auto-written node.
- **Keep them un-muddy:** the in-use parser is pure + synchronous + offline; the overnight runner is the ONLY thing that
  calls models / mutates the graph in batch. Shared seam = the parser's AST + the backlink index (one source of truth),
  never two divergent link implementations. This separation IS the anti-muddiness contract — see **SS-CLEAN**.

Sources: Karpathy gist; nashsu/llm_wiki; penfieldlabs critique; flowershow/remark-wiki-link + maintained forks; zetl.
