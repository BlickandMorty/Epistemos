# UI Product Expression Plan

Date: 2026-04-25
Premise: minimum visible surface, maximum perceived capability. Add small affordances; never giant new sidebars. File type drives surface.

Severity: BLOCKER / HIGH / MEDIUM / LOW / DEFER.

## Capability surface table

| # | Capability | Current visibility | Proposed surface | UI copy | Risk | Implementation notes |
|---|---|---|---|---|---|---|
| U1 | Pro+Cloud has tools | invisible (and broken — see USER_WIRING_GAPS G1) | none — internal routing fix | n/a | LOW | Fix `PipelineService.shouldUseToolLoop` so Pro on cloud routes through Rust agent loop with `chat_pro` tier |
| U2 | Contextual Shadows recall | absent | subtle button in composer corner; panel with Notes+Chats tabs | "Related" | MEDIUM (perf) | See AMBIENT_RECALL_WIRING_PLAN.md |
| U3 | Raw Thoughts artifact | absent | sidebar entry under existing model vault tree (file-type-driven, no new sidebar silo); right-click on a chat → "Open run" | "Raw Thoughts" folder | LOW | Same vault tree; new file/folder kind |
| U4 | Line-count gutter (code) | absent visually (mentioned in code comment only) | toggle in editor toolbar context menu; right-side default | n/a (numeric only) | LOW | Reuse theme tokens; no per-frame allocation; gated by `EPISTEMOS_CODE_GUTTER` setting |
| U5 | Code editor 4k-line fluidity | works for <100KB, untested at 4k+ lines | none (perf, not UI) | n/a | MEDIUM | Wire syntax-core viewport path; commit benchmark; see PERFORMANCE_CONCURRENCY_AUDIT.md |
| U6 | Reasoning trail rendering | live in chat (ThinkingPopover) | already wired; verify per-provider (DD batch) | "Thinking…"/"Thought for Ns" pill | LOW | Already landed per Master Plan |
| U7 | Effective model badge | live in chat (`EffectiveModelBadge`) | keep | "GPT-5.4 · Pro · Cloud" | LOW | Already landed |
| U8 | "Why this model?" rationale popover | live in chat ([7235802f]) | keep | popover on badge tap | LOW | Already landed |
| U9 | Empty states (note, vault, search, chat) | partial | first-run guidance copy in each empty state; small "what you can do here" hint | one-liner per surface | LOW | Add in V1 polish pass |
| U10 | Permissions / saved grants | wired in `AgentControlSettingsView.activeGrantsSection` | link from Privacy pane → grants | "Manage what AI can do" | LOW | Already wired |
| U11 | App Store / Pro profile clarity | live in PrivacyDetailView (`:113-123`) | keep | per-profile copy | LOW | Already landed (S.6) |
| U12 | Quick Capture | partial (no top-level entry verified) | menu bar icon + global hotkey (`Cmd+Shift+Space` or distinctive); auto-route to current vault | "Capture a thought" | LOW | If shippable; otherwise hide for V1 behind feature flag |
| U13 | Voice/dictation in note | mic permission code exists | mic icon in composer | "Dictate" | LOW | Already partially built |
| U14 | Diagnostics panel | absent in Settings | hidden behind Settings → Advanced → Developer toggle | "Performance" | LOW | Surface signpost interval summaries + last benchmark deltas |
| U15 | Documents (.epdoc) | not built | DEFER. If pursued: file-type-driven (open `.epdoc` opens rich editor); same vault tree | "New Document" | LOW (DEFER) | Per claude work / gpt work / raw thoughts canon |
| U16 | Agent Command Center | partial | DEFER to V1.5 | "Command" / global shortcut | MEDIUM | Per PLAN_V2 §4.1 |
| U17 | Embedded terminal (Pro) | code exists in PTY | DEFER to Pro V1.5 | "Terminal" tab in Pro Agent surface | MEDIUM | Per Master Plan §GG.1 |
| U18 | Memory diff card | not built | DEFER to V1.5 | "Remembered N things" inline card | LOW (DEFER) | Per Master Plan §GG.3 |

## Recommended minimal V1 user surface

**Visible at all times**:
- Sidebar: Vault tree (existing); model vaults (existing); under each model vault: Prose / Raw Thoughts / Code (file-type-driven entries).
- Top toolbar: New (note/code/raw-thought/document — Documents grayed out for V1), Vault picker, Model picker, Search, Settings.
- Note editor: composer + AI button (existing) + Contextual Shadows recall button (new, only when results exist) + Code/Prose toggle if mixed-content note.
- Chat: composer + EffectiveModelBadge under each reply + ThinkingPopover + Recall button in composer.
- Settings: AI / Vault / Recall / Privacy / Developer (hidden by default).

**Invisible until earned**:
- Quick Capture (`Cmd+Shift+Space`) — menu bar icon optional.
- Reasoning trail expansion in chat — auto-expand on stream start, auto-collapse on first text token.
- Saved grants list — accessible from Privacy pane link only.

**Hidden in MAS, available in Pro**:
- Computer use (AX, screen capture, automation tools).
- Embedded terminal.
- Bash/PTY tools.

## UI copy guidelines

- "Related" — Contextual Shadows panel header.
- "Thinking…" — popover header during stream; collapses to "Thought for Ns" pill.
- "Raw Thoughts" — folder name for per-run artifacts.
- "Capture a thought" — Quick Capture window prompt.
- "Manage what AI can do" — Privacy → grants link copy.
- "Open run" — right-click on chat → opens corresponding Raw Thoughts run folder.

## Anti-clutter rules

1. No floating modal/popup that obscures the editor while typing.
2. No sidebar >200pt wide opened by default for a panel that's rarely used.
3. No "advanced" settings exposed at the top level.
4. No badges/pills that refresh per token or per second.
5. No empty states with marketing copy; one-liner hints only.

## Discoverability ladder

1. **Persistent**: composer + sidebar + toolbar.
2. **Contextual**: right-click menus, hover affordances, recall button on focus.
3. **Settings opt-in**: Quick Capture, voice, diagnostics, Document file type (when shipped).
4. **Direct-build / Pro-only**: terminal, computer use, ACC.

## Verdict

V1 surface stays small. The two new affordances are: Contextual Shadows recall button (composer-scoped) and Raw Thoughts entries (file-type-driven inside existing vault tree). Everything else is polish on existing surfaces. The user should open the app and immediately see: write, chat, search, graph, recall, privacy. Power lives one click deep, never on the front page.
