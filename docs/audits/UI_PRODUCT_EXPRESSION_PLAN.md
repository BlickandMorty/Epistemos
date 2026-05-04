# UI Product Expression Plan

Date: 2026-04-28

Verdict: The app has more capability than the visible surface communicates. Do not add a giant new navigation scheme. Surface stable capability through the existing shell, command palette, settings, contextual controls, and file-type routing.

## Capability Surface Table

| Capability | Current visibility | Proposed surface | UI copy | Risk | Implementation notes |
|---|---|---|---|---|---|
| Prose writing | Visible and core | Keep as primary editor | Existing copy | LOW | Protected path. Do not replace with rich document editor |
| Contextual Shadows | V0 button/panel exists behind `EPISTEMOS_AMBIENT_RECALL_V0` and is mounted in note/chat workspaces | Subtle notes-first affordance during active typing | Related | HIGH | Keep default-off until runtime click/SLA proof; do not show Chats until real chat hits exist |
| Raw Thoughts | Browsable under model vault tree when `EPISTEMOS_RAW_THOUGHTS_V0` is enabled | Keep in existing vault/model tree, plus "Open run" from chat/agent result | Raw Thoughts | MEDIUM | Must not expose fabricated hidden chain-of-thought |
| Documents `.epdoc` | Built as NSDocument/Tiptap shell, not fully product-proven | File-type-driven "New Document" only after save/open/index smoke passes | New Document | HIGH | Do not call absent; current gap is proof and polish |
| Search/readable blocks | Built substrate | Search results should show artifact kind and block target | Existing search copy | MEDIUM | Verify `.epdoc` and Raw Thoughts feed readable blocks |
| Graph typed artifacts | Graph exists; typed artifact expansion partial | Graph filters for Notes, Documents, Runs, Code when data exists | Existing graph copy | MEDIUM | Avoid block-node explosion |
| Chat/model badge | Visible | Keep | Existing model badge | LOW | Ensure provider claims match actual route |
| Quick Capture | Partial/unclear reachability | Menu/shortcut only if end-to-end save is proven | Capture | MEDIUM | Hide behind flag otherwise |
| Code editor line gutter | Gutter/line count logic exists, UX and perf unproven | Editor setting or toolbar toggle; no extra copy in gutter | Numeric only | MEDIUM | Must not fight theme or allocate per frame |
| Code editor 4k-line smoothness | Not a UI feature; performance target unproven | No new surface; add benchmark and diagnostics | n/a | HIGH | Must prove 4k-line scroll/typing with syntax colors |
| Privacy/MAS profile | Settings privacy pane exists | Keep exact MAS-safe wording and link saved grants | Privacy | HIGH | No cloud/telemetry overclaim |
| Computer use | Direct-build code, MAS stubs | Hide in MAS; direct-build or developer setting only | Automation | HIGH | ScreenCaptureKit/AX/CGEvent are not MAS V1 surface |
| Diagnostics | Partial | Settings -> Advanced -> Developer, hidden by default | Diagnostics | LOW | Useful for signpost summaries after core gates |

## Recommended Minimal V1 Surface

- Sidebar: existing vault tree and model vault grouping; Raw Thoughts appears only when the feature flag and run data exist.
- Main toolbar: existing write/search/graph/settings controls; avoid extra permanent panels.
- Note editor: existing prose surface plus contextual Related button when recall hits exist.
- Chat composer: existing model badge and message bar plus contextual Related button when recall hits exist.
- Graph: keep existing controls; add type filters only after typed artifacts are indexed.
- Settings: AI, Models, Vault, Privacy, Recall, Advanced. Experimental controls stay in Advanced.
- Documents: if `.epdoc` smoke passes, expose as file type and "New Document"; otherwise keep hidden from V1 user surface.

## Capability Copy Rules

- Use "Related" for Contextual Shadows.
- Use "Raw Thoughts" only for observable provider/app-owned run surfaces.
- Use "Document" for `.epdoc` artifacts; do not call them "Notes v2".
- Use "Local" and "Cloud" only when the actual route matches.
- Use "Automation" or "Computer Use" only in direct-build/developer surfaces.
- No visible copy should promise hidden chain-of-thought, autonomous web control, or telemetry-free cloud providers.

## Anti-Clutter Rules

1. No permanent recall sidebar.
2. No second tree/sidebar for Documents.
3. No Raw Thoughts top-level noise when no runs exist.
4. No giant hero/marketing explanation in the app shell.
5. No code-editor controls that shrink the editor or conflict with the theme.
6. No MAS-visible control for disabled direct-build-only automation.

## Empty States Needed

| Surface | Empty state |
|---|---|
| Recall panel | "No related notes yet" plus index status if index missing |
| Raw Thoughts | Hidden when no runs; if opened directly, "Runs will appear here after agent/model work" |
| Documents | If enabled, "Create a document" with no promise of DOCX/PDF until exports exist |
| Search | Show artifact-kind filters and "No results" without implying full vault reindex |
| Code editor | Show file-too-large or highlighting-disabled state if performance guard disables expensive work |

## Implementation Notes

- Prefer command palette and context menus for advanced actions.
- Prefer settings toggles for experimental systems.
- Prefer file-type routing for Documents and Code.
- Keep Prose, Raw Thoughts, Documents, Code, Sources, and Outputs distinct.
- Surface no new UX until the routing path has a test or smoke proof.

## P0/P1 Product Expression Findings

| Finding | Priority | Required fix |
|---|---:|---|
| Contextual Shadows appears partially wired but not runtime-proven end to end | P1 | State/source proof is green; add live click and typing-latency proof before default-on |
| `.epdoc` is built but old docs still claim absent | P1 | Update ship gate and patch queue to current state |
| Code line gutter target is not performance-proven | P1 | Add benchmark and theme-safe toggle before treating it as shipped polish |
| MAS privacy copy must stay exact | P0 | Verify Settings copy against entitlements and PrivacyInfo before submit |
