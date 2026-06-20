# SS-EDGE — Epdoc as the decisive editor: take over Obsidian / Logseq / Notion / Roam (2026-06-20)

Owner: *"One concern is I'm missing the boat with Obsidian. I'm not competing with it — but if I become better than it,
the others become add-ons / deeply integrated. The app needs to compete with all of them so people actually start using
it over Obsidian, and especially Notion (a really rich text editor with a lot of moving parts — the block stuff). Add
that to the app Doc, markdown-FIRST, really robust + dynamic + rich, but super fast, highly optimized, almost as minimal
as the Prose editor, with all the bells & whistles + native Apple feel (pixel-art). Make sure the research on those
services is robust enough to completely take over Logseq/Obsidian/Notion/Roam."* THESIS slice — ties the locked plan
together; does NOT duplicate it. Cross-ref **EPDOC_MD_V2_BUILD_SEQUENCE_2026_06_20.md** (the ordered build), **SS-EM/SS-O/
SS-FM/SS-IR/SS-P** (the Epdoc slices), **COMPETITOR_SUPERSESSION_2026_06_19.md** (the capability matrix), SS-WL (wikilinks),
SS-HW (HTML projection). NEVER touch TK2/Prose (its own surface).

## The thesis (what "take over" means here)
Epdoc becomes the ONE editor that is simultaneously: (a) **markdown-first** like Obsidian/Logseq (the `.md` is the durable,
portable, plain-text source of truth — already LOCKED in EPDOC_MD_V2: md canonical, JSON/HTML/package are *dynamic
projections*), (b) **block-rich + dynamic** like Notion (slash menu, drag-handle reorder, callouts, toggles, tables,
embeds), (c) **networked/outliner-capable** like Logseq/Roam (wikilinks + backlinks + block-refs + transclusion), yet
(d) **as fast + minimal as the Prose editor** and (e) **native Apple / pixel-art**. The others stop being competitors:
Obsidian-style vaults import cleanly (standard md), and their plugin-style features ship as deeply-integrated app
capabilities, not bolt-ons. The moat = md-first ownership + the three-engine fusion (Chat/Act/Work over one vault) that no
rival spans (COMPETITOR_SUPERSESSION "killer differentiators").

## Competitor intel (2026, web-validated) — what each is sticky for, and how we beat it
- **Obsidian** — document/file-based, local `.md`, ~1000+ community plugins (largest ecosystem), graph, $4/mo sync. Sticky =
  local ownership + plugin breadth + long-form. BEAT: we are ALSO local md (no lock-in, clean import) + ship the high-value
  "plugins" as first-class integrated features (graph ✓, backlinks, canvas, Bases-style tables) + add what they can't:
  in-process local+cloud agents over the same vault. (Their plugin breadth is the one true edge — counter with the
  skills/tools marketplace, COMPETITOR_SUPERSESSION.)
- **Logseq / Roam** — outliner; every bullet is a referenceable **block**; block-refs, transclusion, daily journals,
  queries; Roam adds multiplayer. Sticky = networked block thinking. BEAT: add **block-level addressing + block-refs +
  transclusion** to Epdoc (the matrix's "behind on outliner/transclusion" gap) WITHOUT abandoning document-first — support
  both modes over md.
- **Notion** — cloud-only, proprietary block model, databases/table views, rich embeds, collaboration. Sticky = blocks +
  databases + rich. BEAT: match the block richness + slash menu + (Bases-style) table/DB views, but **md-first + local +
  fast** instead of cloud-proprietary. This is the owner's core ask: Notion's "moving parts" with markdown as truth.
- **Anytype/Reflect/Mem** — local+E2E sync, voice/clipping. Note GAPS (web clipper, multi-device sync) from the matrix.

## The decisive architecture decision (md-first vs Tiptap's JSON-first default)
Tiptap (headless ProseMirror; used by NYT/Guardian/Atlassian) is the right rich engine, BUT its docs RECOMMEND **JSON** as
the storage source of truth (`editor.getJSON()`; `@tiptap/markdown` parses md↔JSON). Epistemos deliberately **INVERTS**
this: `content.md` is canonical, `content.pm.json` + HTML become derived `projections/` (EPDOC_MD_V2 Phase 3). This is the
differentiator vs Notion (no proprietary blob) AND vs a naive Tiptap app (no JSON lock-in). Hard requirement: a robust,
lossless, round-trip md serializer (EPDOC_MD_V2 Phase 2) so every Notion-grade block (callout/toggle/table/embed/wikilink/
math/code) has a stable md representation + extension-fenced fallback for blocks md can't natively express — never lose
fidelity, never let JSON silently become the truth. One writer; no CRDT (would invert md-first).

## Speed + minimalism (non-negotiable, owner)
"All the bells & whistles" must NOT cost the Prose editor's snappiness. Reuse the existing perf hardening (shared
`WKProcessPool`, non-persistent data store, dismantle/teardown — see the 2026-04-29 perf wave). Lazy-load heavy blocks
(KaTeX/tables/embeds) ; block richness is opt-in via slash, not always-mounted ; the default doc opens as fast as Prose.
Native Apple feel = macOS-26 skin (EPDOC_MD_V2 Phase 6), pixel-art chrome, SF-native controls.

## What this slice ADDS to the existing plan (not a re-plan)
EPDOC_MD_V2 already sequences repair→serializer→flip-to-md→frontmatter→recall→rich-UI→wikilinks. SS-EDGE adds the explicit
COMPETITIVE-PARITY-AND-BEYOND checklist the rich-UI + wikilink phases must hit to actually take over the rivals:
1. **Block richness (Notion-parity):** slash menu, drag-handle reorder, callouts, toggles/collapsibles, tables, columns,
   embeds, dividers, code w/ syntax — each with a lossless md projection. (EPDOC_MD_V2 Phase 6.)
2. **Networked thinking (Logseq/Roam-parity):** wikilinks + backlinks panel + **block-refs + transclusion** + unresolved-
   link auto-research (SS-WL). (EPDOC_MD_V2 Phase 7 + SS-WL.)
3. **Bases-style table/DB views** over frontmatter/tags (SS-FM) — the Notion-database answer, md-backed.
4. **Clean import/export** of standard Obsidian/Logseq vaults (no lock-in; lowers switching cost — the "they become
   add-ons" play).
5. **Graph + canvas** parity (fix the broken P7.2 canvas — COMPETITOR_SUPERSESSION).
Anti-muddiness (SS-CLEAN): one md serializer + one wikilink/backlink seam shared with SS-WL; no divergent editor cores.
Each item = test-backed (round-trip fidelity tests for every block) + user-facing end-to-end. Sequenced INSIDE EPDOC_MD_V2;
this slice is the acceptance bar, not a parallel track.

Sources: Obsidian/Logseq/Notion/Roam 2026 comparisons; Tiptap/ProseMirror + @tiptap/markdown docs; existing EPDOC_MD_V2 +
COMPETITOR_SUPERSESSION + SS-EM/O/FM/IR/P + SS-WL.
