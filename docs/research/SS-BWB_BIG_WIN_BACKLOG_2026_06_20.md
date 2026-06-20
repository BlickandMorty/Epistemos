# SS-BWB — Big-Win Backlog (owner's INITIATIVE mandate, 2026-06-20)

Owner: *"this is your initiative role/control — research deliberately all the parts you think deserve research that I
skipped over, plus the ones I mentioned. multiple recursive research cycles on big wins / obvious wins — literally things
any sane person would obviously know needs a total revamp, upgrades, hardening, UI/UX upgrades, optimization, performance."*
This is the triage backlog of GENUINELY-NEW big-win candidates (survey-grounded), to be researched (deep slice) then coded.
EXCLUDES owner domains (dual-brain/M0, Companion→Osaurus) + already-sliced items (SS-AN/AD/SH/PERF2/ALIVE/GC/HW/TC/THX/QC/
LS/profiles/C-E/T/K/Q/J/M/N/O/P/EM/FM/HGT). Prioritized; highest-ROI cluster first.

## Highest-ROI cluster (broad, mechanical, touches every surface)
1. **Settings monolith** — `Views/Settings/SettingsView.swift` is **5,128 lines**, 6 tabs + ~25 subsections, with 3 sections
   literally labeled "(legacy)" (`agentControl`/`authority`/`overseer`) + "Experimental" entries shipped to users. Split +
   IA cleanup + gate/remove legacy. [L revamp + S harden for the legacy gating]
2. **Accessibility + Dynamic Type** — only **51/259** view files use any `accessibilityLabel/Value/Hint`; ~**1,208** hardcoded
   `system(size:)`/`systemFont(ofSize:)`. ~80% of views are VoiceOver-bare + Dynamic-Type-hostile. Blanket high-coverage win. [L harden/UX]
3. **Global command palette (⌘K) + keyboard shortcuts** — no `CommandPalette` exists; only 22 files use `keyboardShortcut`.
   A knowledge/agent app with no ⌘K + thin shortcuts is an obvious power-user gap. [M UX]

## User-visible UX / hardening wins
4. **Vault export / backup** — NO whole-vault export/backup anywhere (only narrow `fileExporter` for training/message/HTML).
   A local-first knowledge engine must let users export/back up their vault — trust/safety gap. [M UX/harden]
5. **Unified search/recall surface** — zero `.searchable`; recall scattered across `HologramSearchSidebar`,
   `VaultRecallProvenanceCard`, many Settings HealthRows. No single "search everything" entry. [M UX]
6. **Standardized error/empty/loading states** — only 9 `ContentUnavailableView`, 45/259 views with any `ProgressView`/
   `redacted`, ~17 ad-hoc inline `.red` error spots; `ToastOverlay` exists but underused. Hand-rolled per view. [M harden/UX]
7. **Chat error/retry UX** — `MessageBubble` shows `isError` as red text only; no first-class "retry message" affordance;
   thin catch/recovery. Reliability gap users hit constantly. [M UX/harden]
8. **Model picker / status discoverability** — picking spread across `InlineRuntimePickerPanel`(611)+`ModelAboutSheet`+
   `EpistemosRuntimePicker`; install/status thin. Consolidate "what's running / installed / switch". [M UX]
9. **First-run time-to-value** — `SetupAssistantView`(515) is a linear 5-step gate; model+agent steps front-load config
   before any value. Defer optional steps → activation win. (Cross-ref SS-C/E.) [S-M UX]
10. **Notify-on-complete** — `UNUserNotificationCenter` wired but barely used; long agent runs / background research can't
    notify on completion. Re-engagement/UX gap for an always-on agent app. [S UX]

## Refactor/decomposition wins (low feature risk, high maintainability — and they UNLOCK the UX work above)
11. **ChatInputBar monolith** — `Views/Chat/ChatInputBar.swift` **2,317 lines** + satellites; the most-used surface.
    Decompose → fewer bugs + unlock composer UX. [L revamp]
12. **Notes editor sprawl** — `CodeEditorView`(5,613)+`NoteDetailWorkspaceView`(4,097)+`NotesSidebar`(3,793) + THREE prose
    editors (`ProseTextView2`/`ProseEditorView`/`ProseEditorRepresentable2`)+`WebKitCodeEditorView`. Consolidate (TK2 stays
    non-invasive). [L revamp/harden]
13. **MiniChat divergence** — `Views/MiniChat/MiniChatView.swift` **2,721 lines** parallels the main chat stack → drift risk;
    shared-core consolidation hardens both. [M harden/revamp]

## Triage / sequencing
- Each is a future research slice (do deep file:line research before coding, per owner's recursive-research mandate).
- Suggested first deep-dives (highest leverage, owner would obviously want): #1 (settings split), #2 (a11y/Dynamic Type),
  #3 (command palette) — broad + mechanical + every-surface. Then the UX cluster (#4-#10).
- Biggest single-file offenders for decomposition: CodeEditorView 5613, SettingsView 5128, NoteDetailWorkspaceView 4097,
  NotesSidebar 3793, LandingView 2813, MiniChatView 2721, ProseTextView2 2532, ChatInputBar 2317.
- All NON-INVASIVE to TK2/Prose + Metal + the two owner scope-boundary domains; honest/test-backed/no-green-without-witness.
- The build loop pulls from this backlog AFTER the current owner-facing quick wins (SS-SH/GC/TC/THX/QC) — these are the
  "obvious revamps" the owner mandated; research each into its own SS-* slice as it's picked up.
