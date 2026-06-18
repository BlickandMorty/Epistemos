# R-JSONRENDER verdict — vercel-labs/json-render vs Epistemos GenUI (2026-06-18)

**Verdict: PATTERNS-ONLY (NO-SIDECAR). Epistemos GenUI already matches the core
pattern. Adopt ONE missing pattern natively — streaming/progressive render — as a
future Swift feature. Do NOT port the TS/React lib.**

## What json-render is
A Vercel generative-UI framework (TypeScript + React, multi-renderer:
Vue/Svelte/Solid/RN/PDF/ink). AI emits JSON constrained to a developer-defined
**catalog**; a **registry** maps component types to implementations; a
**Renderer** walks a flat `{ root, elements{} }` spec. Zod validates props.
Expression binding (`$state`/`$cond`/`$template`) drives reactive props.

## Side-by-side vs Epistemos GenUI (Epistemos/Engine/GenUIDispatcher.swift,
## Models/GenUI/GenUIPayload.swift, A2UI/Catalog.swift + Validator.swift)

| json-render pattern | Epistemos GenUI today | Gap? |
|---|---|---|
| Schema-keyed component registry (`defineRegistry`) | `GenUIDispatcher.render(_:)` — exhaustive `switch payload.schema` → 16 typed renderers | ✅ matched |
| Catalog = AI-output guardrail (AI can only use catalog components) | `A2UI/Catalog.swift` + `GenUISchema` enum (16 fixed schemas) + `bodyMatchesSchema` pairing | ✅ matched (stronger — Swift-typed, compile-exhaustive) |
| Zod prop validation | `A2UI/Validator.swift` + `GenUIPayload` Codable typed bodies | ✅ matched |
| Fallback for unknown types | `FallbackGenUIView` (raw JSON + copy, never crashes) | ✅ matched (Epistemos's is explicit; json-render's is undocumented) |
| Determinism / replayable | `registeredSchemas` returns SORTED array (Set iteration is randomized) + GenUIPayloadDeterminismTests | ✅ matched (stronger) |
| **Streaming `SpecStream` — chunks → partial trees → progressive UI** | `render(_:)` takes a COMPLETE `GenUIPayload`; no partial/streaming path | ❌ **GAP** |
| Flat `{root, elements{}}` ref-spec (dedup/streaming-friendly) | Typed `GenUIBody` enum (one payload = one block) | ➖ different shape; Epistemos's typed enum is the safer model — not a gap |
| Expression binding `$state`/`$cond` | none (Epistemos GenUI is static-render, not interactive-reactive) | ➖ deliberate — Epistemos GenUI is for assistant OUTPUT blocks, not interactive forms; actionPanel handles actions via typed `GenUIAction` |

## The one actionable pattern: streaming/progressive GenUI render
json-render's `createSpecStreamCompiler().push(chunk)` renders a partial tree as
tokens arrive. Epistemos renders a GenUI card only once the COMPLETE block is
parsed from the assistant stream. For large blocks (a big `searchResultSet`,
`table`, or `provenanceTrace` streaming in), progressive render would feel more
responsive — the card fills in live instead of popping in at the end.

**Native Swift adoption (NOT a port), future feature:**
- A `GenUIStreamingDecoder` that accepts partial JSON fragments and emits a
  best-effort partial `GenUIPayload` (e.g., rows decoded so far for a table),
  reusing the existing typed `GenUIBody` cases.
- `GenUIDispatcher` gains a partial-render path: each typed renderer already
  takes a `GenUIPayload`; a partial payload renders the known prefix + a
  "streaming…" affordance.
- Gate behind a flag; the complete-payload path stays the default (zero
  behavior change until proven). Pairs with the existing
  ArtifactBlockView streaming pipeline.

## Why not port
json-render is TS/React (+ Node tooling). NO-SIDECAR forbids a Node sidecar; a
WebKit embed would duplicate the Swift-native GenUI we already have (which is
typed, compile-exhaustive, and determinism-tested — stronger than the JS
runtime-validated version). The ONLY thing worth lifting is the streaming-render
IDEA, implemented natively.

## Recommendation
1. Close R-JSONRENDER: Epistemos GenUI is at parity-or-better on registry,
   validation, fallback, determinism.
2. File the streaming/progressive GenUI render as a scoped future feature
   (flag-gated, native Swift, reuses typed `GenUIBody` + ArtifactBlockView
   stream). Not urgent — only matters for large streamed blocks.
3. No code lifted from the repo (clean — nothing entered the ProvenanceGate).
