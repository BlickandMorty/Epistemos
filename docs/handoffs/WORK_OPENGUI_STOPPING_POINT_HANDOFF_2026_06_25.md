# Work/OpenGUI Stopping Point Handoff - 2026-06-25

## Status

Clean stopping point reached for the Work/OpenGUI lane. Nothing is in flight.

The clone is hardened enough to stop and accept a new directive without losing state. The native Work surface is
Epistemos-facing in foreground UI, the OpenGUI/OpenCode/OpenWork donor names remain protected where they are runtime
contracts, and the app-wide graph/chat/mini-chat/note surfaces were not touched in this closeout.

## Scope Boundary

Worked only in the Work/OpenGUI lane:

- `Epistemos/Work/*.swift`
- `EpistemosTests/Work*.swift`
- Work canon/handoff docs
- Epistemos-owned OpenGUI sidecar/probe scripts in `.research-clones/work/opengui`

Do not infer permission to edit deleted/refactored app-wide Chat, Graph Chat, MiniChat, Note Chat, note editor, or shared
navigation surfaces from this handoff. Those remain post-isolation work until the owner explicitly reopens them.

## What Is Hardened Now

- Primary route: native Epistemos Work chrome over the OpenGUI runtime sidecar, OpenCode-first, with OpenWork WebView kept
  only as fallback/preview until owner live proof passes.
- Branding: foreground Work copy is Epistemos-facing or neutral. OpenGUI/OpenCode/OpenWork/Goose names are kept only
  where they are real engine identities, diagnostics, tests, comments, config, storage, protocol, CLI, or migration
  contracts.
- Minimal UI: flat, compact, token-driven Work chrome with stable icon/control hit areas. Controls are hidden behind
  native side panels/toggles where appropriate, not removed.
- Engines/resources: provider/model/agent/command resources are decoded with blank-identity rejection and picker-safe
  defaults.
- Native MCP: `epistemos-native` registration is loopback-only, bearer-token gated, `/mcp`-only, HTTP-only, and requires
  an explicit user-space port. `tools/call` rejects blank tool names before executor dispatch. Context descriptors are
  appended idempotently.
- Vault/skills: `epistemos-vault` and `.opencode/skills` contracts are preserved; skills provisioning filters to real
  `SKILL.md` directories and does not rename the donor skill path.
- Context: `epistemos.context.snapshot` exposes the Work-owned app context boundary without importing deleted graph/chat
  or note UI types.
- Sessions: native session registry avoids implicit promote/demote/reparent on upsert. OpenGUI session ids remain
  canonical `harness:raw` ids.
- Transcript/replay: live and reopened output route by non-empty part/message ids; unrouteable chunks are ignored;
  huge text, errors, tool output, and file diffs are visibly bounded with `[truncated]`.
- Queue: queued prompts requeue on send failure and preserve text, mode, model, agent, and variant.
- Permission/question: event decoding requires non-empty session ids; card UI is compact, bounded, and theme-aware.
- Sidecar bridge: `ok:false` command replies now throw; command dispatch is recoverable; stderr/stdout drain separately
  so logs cannot poison the NDJSON channel.
- HTTP/SPA fallback: native MCP and SPA parsers reject malformed/duplicate/oversized request framing; responses include
  cache/security headers; custom-scheme asset lookup rejects decoded traversal/NUL paths.
- Final closeout patch: `WorkRuntimeSupervisor` and `WorkOpenWorkSupervisor` now accept child-process listening lines
  only for HTTP loopback base URLs with explicit user-space ports. The OpenWork preview additionally requires the expected
  worker port and normalizes the WebView URL to `localhost`.

## Latest Verification

Lightweight checks were used per owner request to stop doing broad test loops:

```bash
xcrun swiftc -parse Epistemos/Work/WorkRuntimeSupervisor.swift Epistemos/Work/WorkOpenWorkSupervisor.swift EpistemosTests/WorkRuntimeSupervisorTests.swift EpistemosTests/WorkOpenWorkSupervisorTests.swift
git diff --check -- Epistemos/Work/WorkRuntimeSupervisor.swift Epistemos/Work/WorkOpenWorkSupervisor.swift EpistemosTests/WorkRuntimeSupervisorTests.swift EpistemosTests/WorkOpenWorkSupervisorTests.swift
rg -n '[ \t]+$' Epistemos/Work/WorkRuntimeSupervisor.swift Epistemos/Work/WorkOpenWorkSupervisor.swift EpistemosTests/WorkRuntimeSupervisorTests.swift EpistemosTests/WorkOpenWorkSupervisorTests.swift
rg -n '(Text\(|Label\(|Button\(|Menu\(|navigationTitle|window|title:|message:|status|help\().*(OpenGUI|OpenCode|OpenWork|Goose|AgentClone|Agent!|clone)' Epistemos/Work Epistemos/Views/Settings/WorkCloneSettingsView.swift Epistemos/App/AppCoordinator.swift Epistemos/App/StatusBar.swift Epistemos/Resources/Localizable.xcstrings
git -C .research-clones/work/opengui status --short
git -C .research-clones/work/opengui diff --stat
```

Results:

- Swift parse passed for the final supervisor URL-trust patch.
- Scoped `git diff --check` passed.
- Touched-file trailing-whitespace scan returned no matches.
- Narrow foreground donor-name scan returned no actionable foreground leaks; matches were comments/internal source
  identifiers only.
- Official OpenGUI donor clone tracked diff is clean.
- `.research-clones/work/opengui` contains only Epistemos-owned untracked probe/sidecar scripts.

Full Xcode verification was not rerun at closeout. Earlier focused Xcode runs were blocked outside this lane by concurrent
chat deletion/refactor compile failures in shared app files. Do not fix those from the Work/OpenGUI lane unless reassigned.

## Files Touched In This Closeout Cycle

Core Work files:

- `Epistemos/Work/WorkEngineTranscript.swift`
- `Epistemos/Work/WorkSessionHistoryProjector.swift`
- `Epistemos/Work/WorkSlashCommandPopover.swift`
- `Epistemos/Work/WorkEnginesPanelView.swift`
- `Epistemos/Work/WorkToolMCPCore.swift`
- `Epistemos/Work/WorkOpenCodeRuntime.swift`
- `Epistemos/Work/WorkSessionRegistry.swift`
- `Epistemos/Work/WorkQuestionRequest.swift`
- `Epistemos/Work/WorkOpenGUISupervisor.swift`
- `Epistemos/Work/WorkWebSurfaceView.swift`
- `Epistemos/Work/WorkEngineSurfaceView.swift`
- `Epistemos/Work/WorkEngineResources.swift`
- `Epistemos/Work/WorkRuntimeSupervisor.swift`
- `Epistemos/Work/WorkOpenWorkSupervisor.swift`

Work tests:

- `EpistemosTests/WorkEngineTranscriptTests.swift`
- `EpistemosTests/WorkSessionHistoryProjectorTests.swift`
- `EpistemosTests/WorkCloneSettingsTests.swift`
- `EpistemosTests/WorkToolMCPCoreTests.swift`
- `EpistemosTests/WorkOpenCodeRuntimeTests.swift`
- `EpistemosTests/WorkOpenGUISupervisorTests.swift`
- `EpistemosTests/WorkOpenWorkSupervisorTests.swift`
- `EpistemosTests/WorkSessionRegistryTests.swift`
- `EpistemosTests/WorkQuestionRequestTests.swift`
- `EpistemosTests/WorkPromptQueueTests.swift`
- `EpistemosTests/WorkEngineResourcesTests.swift`
- `EpistemosTests/WorkRuntimeSupervisorTests.swift`

Docs:

- `docs/WORK_CANON_STATUS_2026_06_25.md`
- `docs/handoffs/WORK_OPENGUI_MASTER_GOAL_PROMPT_2026_06_25.md`
- `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`
- `docs/handoffs/WORK_OPENGUI_STOPPING_POINT_HANDOFF_2026_06_25.md`

## Do Not Rename

Keep these protected unless there is explicit migration proof:

`OpenGUI`, `OpenCode`, `OpenWork`, `Goose`, `opengui`, `opencode`, `openwork`, `OPENCODE_*`, `OPENWORK_*`,
`OPENGUI_*`, `EPISTEMOS_WORK_OPENCODE_V0`, `EPISTEMOS_WORK_GOOSE_V0`, `EPISTEMOS_OPENGUI_SIDECAR_ROOT`,
`OPENWORK_MANAGE_OPENCODE`, `OPENWORK_OPENCODE_BIN`, `opencode.json`, `.opencode`, `openwork.*`, `epistemos-native`,
`epistemos-vault`, harness ids, sidecar frame names, protocol names, CLI/import/package names, and hidden storage paths
such as `Epistemos/OpenGUIRuntime` and `Epistemos/WorkOpenGUI/workspace`.

## Remaining Gates

Owner-only:

- Command-R live visual witness with real model auth.
- Real send/stream through the native OpenGUI-backed Work surface.
- Ask-permission flip only after a permission card visibly renders and responds.

After owner proof:

- Remove OpenWork fallback/preview if native Work proves complete.
- Decide the warm `boxBackground` aesthetic only if it still conflicts with the app token system.

Post-isolation/deep integration:

- Rebuild context from future app-owned seams for current note/page, graph focus/neighborhood, main chat handoff, note
  actions, graph actions, and mini-session handoff.
- Route all of that through Work-owned context/MCP/action boundaries, not by importing deleted UI state.
- Follow `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`.

Deferred/non-clean:

- Live-diff threading and transcript rebasing.
- Owner-scoped worktree diffs.
- Floating/detached mini-session windows.
- Goose adapter after engine-order proof.

## Next Agent Start

Read in this order:

1. `docs/handoffs/WORK_OPENGUI_STOPPING_POINT_HANDOFF_2026_06_25.md`
2. `docs/WORK_CANON_STATUS_2026_06_25.md`
3. `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`
4. `docs/handoffs/WORK_OPENWORK_PARITY_LEDGER_2026_06_24.md`

Start from the new directive. Do not continue the previous infinite hardening loop unless the owner reopens it.
