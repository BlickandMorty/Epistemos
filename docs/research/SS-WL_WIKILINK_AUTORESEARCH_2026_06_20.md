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
