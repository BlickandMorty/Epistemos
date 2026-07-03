# Prompt/Plan Upgrade Audit (2026-06-29)

> 🔴 **SUPERSEDED-IN-FRAME 2026-07-02 (OpenChamber pivot).** This audit reconciled the plans to the PRE-pivot world (Goose reskin / Option 1 / Goose-only). That world is gone: Agent surface = OpenChamber (Pro) / June+goose-in-process (MAS); goose = one engine. The live plan/prompt reconciliation replacing this audit was done 2026-07-02 (PROMPT_PLAN_* override headers + `docs/_archive/pre-openchamber-2026-07-02/`). Use the audit's method, not its pre-pivot conclusions. Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.

Purpose: prevent future build agents from following stale pre-upgrade wording after the 2026-06-29 native-unification
and Goose Option-1 decisions.

## Binding New Canon
- Plan 1 is past the old Goose §7 gate. It is on Phase 1, Option 1: native frame only; chat and every non-Models Goose
  route stay in the Goose WebView and are reskinned. No native chat and no further route migration.
- One unified Apple-native look applies across AppKit, WKWebView bodies, and Goose: SF Pro, shared shadcn Apple tokens,
  Liquid Glass native chrome, transparent web bodies over glass, and the verified SwiftUI spring values.
- Plan 2 builds editor surfaces and note-context plumbing only. It does not build a native SwiftUI Goose minichat or
  separate native chat UI.
- Plan 2's MarkEdit embed is a full-source clone with settings/features user-reachable before final acceptance.
  Any "settings inert" wording is historical first-slice language only.
- Plan 2 keeps the old code editor as a v1-legacy fallback. Do not delete `WebKitCodeEditorView` or dormant
  code-editor scaffolds unless the owner later approves a separate cleanup.
- Markdown Source is a lens, not the only/default markdown view. Agents must verify current routing first; fixed
  historical line numbers like `CodeEditorView.swift:706` are not authority.
- Plan 3 is mostly shipped/staged. Build-order text now means verify/harden when the item already exists.

## Findings Fixed In This Pass
- `PROMPT_PLAN_3_CAPABILITIES.md` said to write OWED browser-use/Voice/meeting-STT/logo codepacks even though those
  codepacks exist and the Plan 3 canon lists the work as shipped/staged. The prompt now says to write a codepack only
  if missing; otherwise harden the shipped/staged follow-up.
- `PROMPT_PLAN_3_CAPABILITIES.md` omitted `PLAN_3_BROWSER_USE_CODEPACK`, `PLAN_3_VOICE_CODEPACK`,
  `PLAN_3_MEETING_STT_CODEPACK`, and `PLAN_3_WHOLE_APP_LOGOS_CODEPACK` from READ FIRST. They are now listed.
- `PLAN_3_CAPABILITIES_2026_06_28.md` had an incomplete top codepack status list. It now includes arXiv, browser-use,
  Voice, meeting/STT, and whole-app logos.
- `PROMPT_PLAN_3_CAPABILITIES.md` still said browser-use "Needs a vendor codepack." The vendor codepack exists; the
  prompt now directs agents to extend it only for new gaps and continue signed Pro packaging/UI/MCP hardening.
- `PROMPT_PLAN_3_CAPABILITIES.md` still implied owed codepacks after build-order completion. It now says owner stop
  only; completion rolls into hardening, shipped/staged codepack follow-ups, and re-verification.
- `PROMPT_PLAN_2_EDITOR.md`, `EDITOR_CANONICAL_PLAN_2026_06_27.md`, and `GOOSE_MINICHAT_CODEPACK_2026_06_27.md`
  carried old Phase-0/sign-off/native-minichat language. They now say Plan 2 owns note-context plumbing only and the
  live surface is Plan 1's Goose WebView/reskin.
- `TOLARIA_SUPERSEDE_RESEARCH_2026_06_27.md` still carried stale research-log recommendations: native minichat,
  Phase-0 live-chat gates, deleting the old code editor, inert MarkEdit settings, and `update_note` wording. It now
  opens with a 2026-06-29 supersession notice and rewrites the affected pass summaries/falsifier specs to match the
  current Plan 2 canon.
- `AI_INSTRUCTIONS_AND_GRAMMAR_CODEPACK_2026_06_27.md` pointed at the old minichat sender. It now points at any
  note-aware Goose sender supplied by Plan 1 plus Plan-2 context plumbing.
- `MARKEDIT_EMBED_CODEPACK_2026_06_27.md` and the editor plan used fixed "today line 706" wording for the markdown
  Source route. They now say to verify current code first, then wire/harden if still missing.
- `MARKEDIT_EMBED_CODEPACK_2026_06_27.md` also allowed first-slice "settings inert" and "removed old editor" wording.
  It now says settings must become reachable and the v1 WebKit editor is retained as a legacy fallback.
- `PLAN_2_AGENT_HANDOFF_AUDIT_2026_06_29.md` was added as the final Agent 2 handoff. It summarizes all Plan 2
  doc changes, stale traps, owner-visible editor acceptance criteria, and native/theme research Agent 2 must preserve.
- The MarkEdit visual-fidelity docs no longer exempt MD from app theming. MD preserves MarkEdit layout/chrome/settings,
  but auto-maps Epistemos light/dark/accent into the MarkEdit source surface.
- Plan 3 prompt/doctrine wording around the PDF viewer now states the boundary precisely: Plan 3 owns parse +
  `source_pdf` handoff/affordance; Plan 2 owns the PDFKit viewer.
- `PROMPT_PLAN_1_GOOSE.md` had Step 1/3 headings that could be read as resurrecting Phase 0 before new work. It now
  clarifies those are ongoing proof obligations, not a sign-off pause.

## Still Historical, Do Not Resurrect
- `PLAN_3_OBSCURA_TIER1_CODEPACK` remains a historical filename for the lite human-driven Browser tab. Product name is
  Browser. Do not rebuild the cut Obscura native automation robot.
- `SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` contains old federation/local-model/native-route
  research in dead or superseded sections. Only use the live sections named by the Plan 1 prompt, and obey the
  2026-06-29 Option-1 override.
- Any old line that says ColBERT, HF/BYOM/local model-management, three-engine Chat/Act/Work, Osaurus, DeerFlow, or
  Obscura native robot is current Plan 3 work is stale unless it is explicitly marked CUT/historical.
- Any old line that says the old code editor should be deleted is stale. It is v1 legacy fallback.
- Any old line that says MarkEdit settings can stay inert is stale. Settings must be reachable before final acceptance.
- Any old line that says `.md` must always route away from MarkEdit Source is stale. `.md` gets Note/Source/Prose
  lenses, with Source reachable by explicit lens toggle.
- Any old line that says Prose/TK2 is frozen is stale only for the narrow Prose-lens addition; existing Prose behavior
  must still not be broken.

## Quick Grep Checklist For Future Agents
Before marking a prompt-driven stage done, grep touched docs and comments for:

```text
Phase-0 gated|§7 sign-off|native minichat|native SwiftUI chat|separate native chat UI|native chat|OWED codepack|Needs a vendor codepack|delete old code editor|delete the 3 old|settings inert|present-but-inert|CodeEditorView.swift:706|routes .md to Prose|MD path stays on MarkEdit|Prose frozen|Obscura native|ColBERT|HF/BYOM|local model-management|three-engine|Osaurus|DeerFlow
```

If a match is in live instructions rather than historical/CUT context, fix the source before implementing.
