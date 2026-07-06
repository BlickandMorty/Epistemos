---
name: experimental-vault-context-assembly
description: >
  Give the embedded 1Code (Experimental) agent knowledge-retrieval context assembly —
  pull the RIGHT notes from the user's Epistemos vault into the agent's context via the
  app's real RRF index (tantivy BM25 + usearch HNSW), instead of repo-grep. Use when
  building any feature that must retrieve/rank/inject the user's knowledge (grounded
  answers, "what did we decide", graph-walk context) into the web composer or the engine.
  Composes `experimental-provenance-writeback` (the web→native `epistemos` round-trip).
  Class: web prompt → native `vault:search-ranked` → app RRF/graph → ranked, cited context.
---

# Experimental: RRF/graph-aware context assembly for the embedded agent

## Why (the moat)
Field study `docs/research/AGENT_APP_FIELD_STUDY.md`: every standalone agent assembles
context by repo-grep / a workspace index; none retrieves from a durable personal knowledge
base. Epistemos owns a real RRF index (`epistemos-shadow`: tantivy BM25 + usearch HNSW +
RRF fusion, on disk at `<vault>/.epcache/shadow`, crawled by `ShadowVaultBootstrapper`).
This class routes that retrieval into the agent surface — the context axis the field cannot
follow.

## The pattern (compose the Cycle-1 round-trip)
1. **Native retrieval handler (Swift, Coordinator `didReceive` ASYNC path** — search is
   async, `reply()` is sync). Add `case "vault:search-ranked"`:
   ```swift
   guard let search = AppBootstrap.shared?.contextualShadowsState.haloSearchService
   else { return (["hits": [], "unavailable": true], nil) }
   let hits = await search.search(text: query, domain: .notes, limit: limit)  // [ShadowHit]
   // map hit.title / hit.snippet (strip <b>…</b>) / hit.score / hit.source → JSON
   ```
   `haloSearchService` is the live `ShadowSearchServicing` (RRF). It returns [] honestly
   when recall isn't live (no vault / index unbuilt) — never fake.
2. **Web retrieval lib (NEW overlay).** `rankedVaultSearch(query,limit)` posts to the
   reply-capable `epistemos` handler (NOT the shim); `formatGroundedContext` renders the
   hits as a `> [[title]] — snippet` block with a cite instruction.
3. **Web delivery.** Read/write the composer through the editor handle
   (`AgentsMentionsEditorHandle.getValue()/setValue()`) — no editor-internals coupling.
   Honest-gate the whole feature on `window.webkit.messageHandlers.epistemos` existing.

## Two retrieval mechanisms — pick by vault layout (Cycle-6 lesson)
The shadow RRF index (`haloSearchService`) only crawls `<vault>/notes/**` + `<vault>/chats/**`. Many
vaults keep content elsewhere (`docs/`, root, `application/`…), so the shadow index UNDER-COVERS them
and retrieval/cite-check silently return empty on REAL notes. Two mechanisms, composable:
- **Shadow RRF** (native `vault:search-ranked`): best RANKING (BM25+HNSW), but `notes/`-scoped.
- **Whole-vault fs** (NEW backend `epistemosVault.search` / `noteExists`, `src/main/lib/epistemos-vault-fs.ts`):
  read-only scan of `EPISTEMOS_VAULT_ROOT` (the SAME root the supervisor injects into the agent's vault
  MCP) — coverage-complete regardless of layout, but substring not RRF. Never touches the vault engine.
- **Pattern:** try shadow first; if it returns <2 hits, fall back to whole-vault fs and merge (dedupe by
  title, shadow first for its real scores). This is why `rankedVaultSearch` now covers any vault layout.
- **Diagnosis tip (cost a cycle):** if search returns empty, check `process.env.EPISTEMOS_VAULT_ROOT` and
  whether the notes live under `notes/` (shadow) or elsewhere (needs whole-vault fs) — don't assume the
  index is "broken."

## Reuse targets (later cycles compose THIS)
- Cross-session memory: swap `.notes` retrieval for the graph (`graph.traverse` /
  `graph.search_semantic`) to pull "what we decided last time".
- Auto-grounding: run `rankedVaultSearch` at SEND time in the transport, not just a button.
- Observability: the search already emits provenance events (`AgentProvenanceActor`
  `search-index-service` / `shadow-search-service`) — surface them in a console.

## Verification (DoD — running app)
Never two `xcodebuild`s (DB-lock collision corrupts the Rust dylib → undefined-symbol
link fail; recover with `build-agent-core.sh`). Prove live: click "Vault" in the composer
with a real prompt → the composer rewrites with ranked `[[note]]` citations from the vault;
send → the agent reasons over them. Heed the Keychain-prompt-storm hazard (set ACL / Always-
Allow before UI drives). Every fork edit → a `PATCH_LEDGER.md` row.
