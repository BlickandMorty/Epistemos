# PLAN 2 — Editor canonical build prompt (paste to a build agent)

> The editor canonical plan, hardened. Thermonuclear-strict, hard gates, FULL clone of MarkEdit (settings and all).
> Can run in PARALLEL with Plan 1 (Goose, Codex) and Plan 3 (capabilities) — boundaries below.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — NEVER STOP until I (the owner) type "stop". This is a continuous loop, not a one-shot. Work the build sequence stage by stage; after each stage immediately continue to the next. When the whole build sequence is complete, DO NOT declare "done" and DO NOT idle — keep looping: (a) run a full-app thermonuclear pass and fix what it finds, (b) harden the weakest/thinnest area, (c) build the next owed/unspecced item, (d) re-verify everything still green, then repeat. There is always a next hardening pass. Only the owner's "stop" ends the loop. Commit at every clean point.

You are building PLAN 2 = the Epistemos editor canonical plan. Build it deeply hardened, contradiction-free, with NOTHING lost — and whatever is cloned must be FULLY cloned (settings and all, 100% capability).

READ FIRST (this is the canon — the PLAN doc wins over any codepack on conflict):
  - docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md  (THE plan — §0 owner decisions, §10 build sequence, §12 finalization audit, §13 recovered editor surfaces, §14 MarkEdit full-clone completeness)
  - Codepacks (real code + file:line): MARKEDIT_EMBED_CODEPACK, COMMAND_REGISTRY_CODEPACK, NATIVE_CONTROLS_CODEPACK, MD_SOURCE_OF_TRUTH_CODEPACK, AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK, TOLARIA_ONTOLOGY_UPGRADE_CODEPACK, GOOSE_MINICHAT_CODEPACK (all docs/research/*_2026_06_27.md)
  - Research provenance: docs/research/TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS, Code Standards). RESEARCH-FIRST: read before editing; verify current code/disk before asserting; tag [VERIFIED-CODE].

LOCKED owner decisions (do NOT relitigate): L1 markdown-on-disk = source of truth (staged EPISTEMOS_MD_SOURCE_OF_TRUTH flip; canonical writer = the JS getMarkdown() full-fidelity bridge, never the lossy projector). L2 note-width = binary toggle 720px/`max-width:none` AND a slider. L3 code editor v2 = MarkEdit CoreEditor; DELETE the 3 old code-editor files ONLY after a manual real-app verify (types+highlights+saves), commit separately, code-editor scope only — NEVER touch Epdoc note editor or frozen TK2/Prose. **L3-CHROME: MarkEdit replaces the code EDITOR engine, not the chrome wholesale — chrome is MODE-SPLIT over ONE shared CoreEditor engine (an `isMarkdownDocument` branch in `CodeEditorView`). MD files → MarkEdit's chrome VERBATIM (perfectly like the standalone MarkEdit.app: its toolbar/panels/Previewer/Settings; Epistemos additions are additive only, never subtractions). CODE files → keep Epistemos's own good `CodeEditorView` chrome (it may look "slightly different on top" — intended) INCLUDING the Live-Preview/HTML preview button (`HTMLWorkspacePreviewView` — "the preview button like html has on the old code editor"), which is LOAD-BEARING and must survive the swap (engine-agnostic; MD mode uses MarkEdit's own Previewer). Canonical = MARKEDIT_EMBED_CODEPACK §3 + plan §4/L3-CHROME.** Grammar = Obsidian/GFM (`> [!KIND]` / ```chart / [[wikilink]]`). @tiptap/markdown pinned 3.24.0 (P0: confirm it resolves on npm first). Provenance = Swift AgentNoteEditProvenance spine (NOT the read-only Rust ledger). Vendor MarkEdit under LocalPackages/MarkEdit/ (NOT vendor/).

BUILD SEQUENCE (per the plan §10, dependency-ordered): (1) ontology core; (2) CommandRegistry + Cmd+K palette + the caretChanged.marks read-back; (3) note-editor revamp (Tolaria CSS/chrome + width toggle+slider + Find/Replace) + add @tiptap/markdown + the L1 markdown flip; (4) note AI-diff (prosemirror-changeset); (5) MarkEdit embed + code-editor v2 — ONE CoreEditor engine, MODE-SPLIT chrome (L3-CHROME): CODE files keep Epistemos chrome + the preview button; MD files get MarkEdit's chrome verbatim — then delete old files after manual verify; (6) Views + types + incremental crawl; (7) Goose minichat note-context PLUMBING (the LIVE agent surface is Plan-1/Phase-0-gated — build plumbing only); (8) the §13 recovered surfaces (graph inline-edit, home-graph tunnel, the 2 data-loss fixes, instant-recall/NSPopover, HTML Workspace AI-artifact, web clipper, PDF viewer).

FULL-CLONE requirement (owner: "literally clone it, don't add manually — settings and all, nothing less"):
  - METHOD = LITERAL FULL-SOURCE CLONE (MARKEDIT_EMBED_CODEPACK §0a). You CANNOT drop the whole .app in — macOS allows ONE @main/NSApplicationMain + ONE shared NSDocumentController per binary, and Epistemos already has both (two = won't compile / crash). So: `git clone` the ENTIRE MarkEdit source into LocalPackages/MarkEdit/ via a DETERMINISTIC SCRIPT; DELETE only the 4 un-coexistable shell items (its @main/AppDelegate/Application, its AppDocumentController, its .xcodeproj, its 2 .appex); mount its one top-level EditorViewController in an Epistemos window. The clone is mechanical (no cherry-picking); the ONLY hand-written part is the VC-mount seam (§2–§3). ZERO editing/settings capability lost.
  - COMPLETENESS GATE: enumerate MarkEdit's Modules products + Settings panes from the REAL cloned source; assert EVERY one is vendored + reachable in Epistemos (under a mode). Per §14 vendor ALL 11 Modules incl. the 3 missing (FileDrop, Previewer, TextBundle); decide Scripting/Shortcuts (vendor or explicitly drop); flip the full Settings UI live; the ONLY allowed loss is the 2 MAS-hostile .appex (state it). A pane/feature in MarkEdit but absent in Epistemos = a FAIL. No silent capability drop.
  - EPISTEMOS EQUIVALENTS — every dropped item maps to one so NO function is lost, and HARVEST MarkEdit's hardening (do NOT blind-drop): @main/AppDelegate → port its launch setup into EpistemosApp/AppBootstrap · AppDocumentController → register MarkEdit's doc-types with the existing EpistemosDocumentController · .xcodeproj → HARVEST MarkEdit's build settings + Info.plist (document-type/UTI declarations, NSServices) + entitlements into project.yml/Info.plist/entitlements (adopt MAS-safe keys, reject MAS-hostile temporary-exception/executable) so the embed is AS HARDENED as the standalone MarkEdit · 2 .appex → Epistemos's own Finder/QuickLook extensions later. A MarkEdit capability that lived in a dropped item must reappear via its Epistemos equivalent OR be explicitly stated as a loss (only the 2 .appex Finder bits).
  - Do NOT bundle a subprocess MarkEdit.app (separate window + subprocess = violates no-sidecar/App-Store + can't share vault/theme).

THERMONUCLEAR DISCIPLINE (run the skill above, recurring — each build stage + a full pass periodically):
  - Honest, real findings only: correctness bugs, dead/stale code, honesty-constraint violations, perf, arch drift, contradictions.
  - DELETION GUARDRAIL: deeply harden/dedupe/refactor, but DELETION IS A LAST RESORT. NEVER delete new/in-progress/owner-requested code (the L3 code-editor deletion is the ONE sanctioned deletion, and only post-verify). When uncertain, KEEP + flag. Commit deletions separately.
  - NO CONTRADICTIONS: before marking a stage done, grep the plan + codepacks for any claim that contradicts it; fix the source.

HARD GATES / FORBIDDEN:
  × Touching the frozen TK2/Prose editor's behavior, or Epdoc, when doing the CODE-editor swap (L3 scope guard).
  × Deleting the old code editor before a MANUAL real-app verify of v2.
  × Shipping a "Verified"/canonical-md path through the LOSSY projector (use the JS getMarkdown bridge).
  × Editing .xcodeproj directly (xcodegen project.yml only); committing model files; importing nonexistent SDKs (no Anthropic/OpenAI Swift SDK).
  × Build-green ≠ done. PROVEN-DONE bar: real-state · live in-app · migrates existing data · end-to-end · witnessed (Swift Testing @Test compile-verify + a manual run for UI/runtime; per memory, headless app-hosted test runs crash-loop — push logic into pure helpers + mirror-witness).
  × Zero regressions against the test suite.

PARALLELISM / NO-COLLISION (other agents build Plan 1 + Plan 3 in this repo concurrently):
  - You OWN: Epdoc/code-editor/Prose surfaces, js-editor/ bundle, MarkEdit embed (LocalPackages/MarkEdit/), the markdown/ontology/command-registry Swift, HTML Workspace, wikilinks, web clipper, PDF *viewer*.
  - Do NOT touch: Epistemos/Goose/* + Epistemos/Agent/* (Plan 1) · the Plan-3 capability files (PDF→md parser/EdgeParse, provenance moat, vault-as-MCP, browser, Apple-native shared views, extensibility, landing buttons). The Goose minichat is a shared seam: build the note-context PLUMBING; the live agent surface is Plan 1's and Phase-0-gated.
  - The PDF split: Plan 3 owns the PDF→md PARSE + the source_pdf storage contract; YOU own the PDFKit PDFView VIEWER that consumes the resolved source_pdf URL. Don't re-invent the storage.

Commit at clean points (main-only, never lose work). When unsure, RESEARCH-FIRST then act. Stop only when I say stop OR the plan's build sequence is complete with PROVEN-DONE evidence.
```
