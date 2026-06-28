# PLAN 2 — Editor canonical build prompt (paste to a build agent)

> The editor canonical plan, hardened. Thermonuclear-strict, hard gates, FULL clone of MarkEdit (settings and all).
> Can run in PARALLEL with Plan 1 (Goose, Codex) and Plan 3 (capabilities) — boundaries below.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

Do not stop until I say stop. You are building PLAN 2 = the Epistemos editor canonical plan. Build it deeply hardened, contradiction-free, with NOTHING lost — and whatever is cloned must be FULLY cloned (settings and all, 100% capability).

READ FIRST (this is the canon — the PLAN doc wins over any codepack on conflict):
  - docs/research/EDITOR_CANONICAL_PLAN_2026_06_27.md  (THE plan — §0 owner decisions, §10 build sequence, §12 finalization audit, §13 recovered editor surfaces, §14 MarkEdit full-clone completeness)
  - Codepacks (real code + file:line): MARKEDIT_EMBED_CODEPACK, COMMAND_REGISTRY_CODEPACK, NATIVE_CONTROLS_CODEPACK, MD_SOURCE_OF_TRUTH_CODEPACK, AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK, TOLARIA_ONTOLOGY_UPGRADE_CODEPACK, GOOSE_MINICHAT_CODEPACK (all docs/research/*_2026_06_27.md)
  - Research provenance: docs/research/TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS, Code Standards). RESEARCH-FIRST: read before editing; verify current code/disk before asserting; tag [VERIFIED-CODE].

LOCKED owner decisions (do NOT relitigate): L1 markdown-on-disk = source of truth (staged EPISTEMOS_MD_SOURCE_OF_TRUTH flip; canonical writer = the JS getMarkdown() full-fidelity bridge, never the lossy projector). L2 note-width = binary toggle 720px/`max-width:none` AND a slider. L3 code editor v2 = MarkEdit CoreEditor; DELETE the 3 old code-editor files ONLY after a manual real-app verify (types+highlights+saves), commit separately, code-editor scope only — NEVER touch Epdoc note editor or frozen TK2/Prose. Grammar = Obsidian/GFM (`> [!KIND]` / ```chart / [[wikilink]]`). @tiptap/markdown pinned 3.24.0 (P0: confirm it resolves on npm first). Provenance = Swift AgentNoteEditProvenance spine (NOT the read-only Rust ledger). Vendor MarkEdit under LocalPackages/MarkEdit/ (NOT vendor/).

BUILD SEQUENCE (per the plan §10, dependency-ordered): (1) ontology core; (2) CommandRegistry + Cmd+K palette + the caretChanged.marks read-back; (3) note-editor revamp (Tolaria CSS/chrome + width toggle+slider + Find/Replace) + add @tiptap/markdown + the L1 markdown flip; (4) note AI-diff (prosemirror-changeset); (5) MarkEdit embed + code-editor v2 (then delete old files after manual verify); (6) Views + types + incremental crawl; (7) Goose minichat note-context PLUMBING (the LIVE agent surface is Plan-1/Phase-0-gated — build plumbing only); (8) the §13 recovered surfaces (graph inline-edit, home-graph tunnel, the 2 data-loss fixes, instant-recall/NSPopover, HTML Workspace AI-artifact, web clipper, PDF viewer).

FULL-CLONE requirement (owner: "the full thing, settings and all, nothing less"):
  - MarkEdit = the COMPLETE app embedded. Per §14: vendor ALL 11 Modules products INCLUDING the 3 missing ones — FileDrop, Previewer, TextBundle — declared in project.yml; decide Scripting/Shortcuts (vendor or explicitly drop); flip the full Settings UI live (not just inert behind the flag); the only allowed loss is the 2 MAS-hostile .appex (state it). No silent capability drop.
  - Verify against the real MarkEdit source you vendor — if a pane/feature exists in MarkEdit, it must be reachable in Epistemos (under a mode), not dropped.

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
