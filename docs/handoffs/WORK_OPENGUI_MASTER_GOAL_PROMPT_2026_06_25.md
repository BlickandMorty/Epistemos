# Work/OpenGUI Master Goal Prompt - 2026-06-25

Use this as the copy/paste goal prompt for a future agent loop. It is specific to the current Epistemos Work/OpenGUI
integration and covers the whole process, not one ledger item.

```text
Continue the Epistemos Work / OpenGUI integration loop in /Users/jojo/Downloads/Epistemos until I explicitly say stop.

Primary objective:
Make Epistemos Work feel and behave like a native, minimal, theme-aware part of the Epistemos app while preserving every
runtime/API/storage/protocol contract that makes the feature work. The primary Work path is native Epistemos Work chrome
over the OpenGUI harness/runtime, OpenCode-first, with other engines layered under that architecture only when proven.
Do not remove controls, buttons, user abilities, diagnostics, or recoverability. If the foreground should stay minimal,
move details behind side panels, toggles, pickers, diagnostics, or settings, but keep the capability reachable.

Hard boundary:
Stay in the Work/OpenGUI/OpenCode lane unless I explicitly expand scope. Another agent may be deleting or rewriting other
surfaces. Do not edit Chat, Act, AgentClone, Osaurus, project package references, or unrelated app surfaces to make this
work look green. Read those areas only when needed to explain an external blocker.

Read first, then inspect the current worktree:
1. docs/WORK_CANON_STATUS_2026_06_25.md
2. docs/donor-contracts/work-opengui/INDEX.md
3. docs/handoffs/WORK_OPENWORK_PARITY_LEDGER_2026_06_24.md
4. docs/handoffs/OWNER_RETURN_CHECKLIST_2026_06_24.md
5. docs/handoffs/WORK_OPENGUI_MASTER_GOAL_PROMPT_2026_06_25.md
6. Current files and command output are authoritative. Do not trust old thread memory without re-checking.

Current known external blocker:
Full Xcode build/test can be blocked outside this lane by the concurrent deletion sweep. Current read-only blocker
evidence includes absent shared chat/Osaurus surfaces and the latest focused WorkOpenGUI supervisor Xcode retry:
`/tmp/EpistemosWorkOpenGUI-20260625-ports/Logs/Test/Test-Epistemos-2026.06.25_16-28-05--0500.xcresult`. That retry got
through Work-owned compilation, then stopped outside Work in `Epistemos/Views/Chat/*` because
`ChatComposerOverlayCommand`, `ChatComposerKeyHandling`, and several `ComposerReferenceSearchResults` members no longer
match the shared deletion/refactor state. Earlier retries also stopped outside Work at `AgentChatState` and
`AppBootstrap.chatState` references. Re-check before claiming the shared app target is healthy. Do not fix non-Work
blockers from this Work loop. Use Work-only parse/static/probe verification until the shared app target is restored.

Current Work baseline to preserve:
- App menu / Command-4 `Open Epistemos Work` opens `WorkEngineSurfaceWindowController`, the native OpenGUI-backed surface.
- Settings still offers `Open Epistemos Work preview` for the OpenWork WebView fallback.
- The fallback preview details panel must remain scrollable and app-branded while exposing native-tools registration
  state; do not remove it before native OpenGUI/OpenCode owner proof passes.
- Foreground UI is `Epistemos Work`; engine names remain only as real picker entries, diagnostics, protected contracts, or
  tests/comments.
- `Tab` in the block-caret input stages the current prompt into the native queue without submitting or moving focus.
  `Enter` still submits immediately when idle and queues while busy.
- Prompt queue controls remain reachable: edit, send-now, interrupt, steer after current part, cancel steer, move
  top/bottom, remove. After-part steering is wired to live part-boundary events and the existing idle drain, not a
  cosmetic label.
- Queued prompts removed for idle drain or send-now must be requeued at the front if sending fails, preserving
  mode/model/agent/variant metadata so queued user work is not silently lost.
- Queue icon controls reserve stable compact hit areas; preserve this while keeping the queue flat and minimal.
- Engine/model/agent pickers, slash commands, recents/session rail, transcript, live-diff refresh, permission cards,
  question cards, native tools, and fallback details remain reachable.
- Slash commands must stay reachable while compact: use a bounded scroll popover with stable rows and truncation, never
  a clipped unbounded overlay or a shortened command subset.
- Engine resource defaults must only preselect decoded provider/model pairs; stale default ids should fall back to the
  first decoded model instead of being sent to the engine.
- Engine resource decoding should trim and reject blank provider/agent/command identities before they reach pickers or
  slash commands. Keep the donor model record-key fallback for models with missing display names.
- Header/input icon actions should reserve compact fixed hit areas so send/stop/settings/new-session do not shift layout.
- Permission/question ask cards should stay compact and stable: fixed icon/indicator dimensions, single-line decision
  labels, tail-truncated long options, and no removed permission/question actions.
- Permission/question request and cleared events must carry non-empty session identity before they mutate native cards.
  Blank or malformed harness events should not create or dismiss cards.
- Engines/context panel rows should keep compact fixed heights, fixed-size status/count values, and truncation for long
  engine/provider/context labels so app context can deepen without breaking the flat layout.
- Reopening a recent session preserves the canonical `harness:raw` OpenGUI id, aligns the picker/resources to that owning
  engine, and does not clear the reopened transcript.
- Recents/rail titles are display-safe: prompt-derived titles and engine-returned titles are collapsed to one line and
  bounded, while canonical engine session IDs remain unchanged.
- Permission/question replies route to the request's source `harnessId` when present, not whichever picker row is selected.
- Attached mini sessions are Work-local and wired through OpenGUI `sessions.create`; detached/floating mini windows remain
  deferred until a real non-Work window hook exists.
- Mini sessions must have an existing main Work parent before entering the registry; mixed persisted input order is okay
  because registry initialization loads mains before minis, but orphan rail rows are rejected.
- Session upserts must not implicitly promote, demote, or reparent existing session ids. Use the explicit promote path
  when a mini should become a main tab.
- Session rail symbols and new-mini controls reserve stable compact dimensions, and long titles tail-truncate; keep
  detach/reattach/promote/close reachable.
- Native tool bridge failure is visible: the primary Work surface surfaces a transcript error if Epistemos native MCP
  provisioning fails before engine startup continues with defaults.
- Native MCP registration trust is centralized on `WorkNativeMCPRegistration`: only non-empty bearer tokens with `http`
  loopback `/mcp` URLs may be written into OpenGUI `opencode.json`, the OpenWork fallback worker body, or the legacy
  OpenCode config. Keep the protected `opencode.json` / `.opencode` contracts intact.
- Native app context bridge exists: `WorkAppContextSnapshot` feeds the engines panel and the read-only
  `epistemos.context.snapshot` native MCP tool. It currently exposes Work-owned workspace/vault/native-tool/skill count,
  selected engine/model/agent, active Work session, and queue depth without importing graph/chat/note UI state.
- Legacy Work status copy uses neutral `other app modes` phrasing. Do not reintroduce foreground Chat/Act coupling in
  Work status details just to describe isolation.
- Skills provisioning preserves the OpenCode `.opencode/skills` contract but filters source entries: only directories
  containing `SKILL.md` copy into the managed runtime, so unrelated Epistemos vault files or helper folders cannot appear
  as engine skills. Workspace skills run first, the active app-vault skills fill gaps, and bundled defaults fill only
  remaining missing names.
- Fallback WebView details show native tool registration status.
- OpenGUI startup rejects zero connected harnesses; no dead-but-running state when `connectedHarnessIds` is empty.
- Sidecar stderr and long-lived runtime/worker output are drained so pipes cannot deadlock the bridge.
- Shared Work HTTP parser rejects malformed/negative declared `Content-Length` and maps over-cap declared bodies to 413
  through the native MCP and SPA loopback servers.
- Native MCP transport rejects duplicate `Content-Length` headers and emits `Cache-Control: no-store` on JSON/202
  responses.
- SPA fallback loopback responses use `no-store` for injected HTML/errors, keep static assets at `no-cache`, and emit
  `X-Content-Type-Options: nosniff`.
- SPA custom-scheme fallback decodes percent-encoded asset paths before lookup, rejects encoded traversal/NUL paths after
  decoding, and mirrors the same HTML/asset cache plus `nosniff` header split.
- OpenGUI sidecar/probes fail clearly when a requested harness is not connected.
- OpenGUI sidecar command dispatch is serialized and recoverable: a queue-level rejection emits an error frame and the
  next command still runs. Source guards cover every Swift/sidecar command endpoint in the Work surface.
- Sidecar command wrappers should treat `ok:false` replies as errors for user-visible actions and data loads; do not let
  failed endpoint replies look successful.
- OpenGUI sidecar frame decoding is route-safe: replies without non-empty request ids, session events without non-empty
  session ids/event JSON, and harness events without event JSON are ignored instead of being routed to blank ids.
- OpenGUI transcript history requests omit invalid message limits and cap very large limits before they cross the
  sidecar command boundary.
- Native transcript reduction is route-safe: live text/tool chunks without a non-empty part id or message id are ignored
  instead of being merged into a synthetic bucket.
- Live and replayed transcript payloads are bounded before native rendering: huge answer/tool/error text and file diffs
  use a visible `[truncated]` marker, and per-tool replayed diffs are capped before they can overwhelm the Work surface.
- The managed OpenGUI/OpenCode port is exported only when it is a valid user-space TCP port; invalid or privileged values
  are omitted so the sidecar falls back honestly instead of inheriting a bad port.
- No-model clone endpoint proofs currently cover create/list, loadResources, harness-event subscription, and
  `sessions.create -> sessions.open -> messages` over the same NDJSON sidecar boundary Swift uses. They also cover
  command-error recovery: a bad harness request returns a clean sidecar error and the next valid command still runs.
- Embedded SPA reskin is theme-token driven, square, monospace, no shadows, targeted no-gradient, block-caret, and does
  not globally remove real image assets.
- Official `.research-clones/work/opengui` donor files should have no tracked diffs. Epistemos-owned probe scripts may be
  untracked there.

Branding and naming law:
Foreground product surface should say `Epistemos Work`, or neutral app-facing words such as runtime, engine, workspace,
tools, sessions, recents, transcript, permissions, questions, bridge, or details. Hide donor names from normal foreground
chrome unless the name is the real engine identity the user must choose or debug.

Run this classification before every rename:
1. Foreground label/copy/window/menu/settings text: prefer `Epistemos Work` or neutral copy.
2. Real engine picker entry or diagnostic: keep `OpenCode`, `Codex`, `Claude Code`, `Goose`, etc. if that is the actual
   selectable/debuggable runtime identity.
3. Runtime/API/config/storage/protocol/import/CLI/package name: do not rename unless you have precise source proof,
   migration code, and tests proving it still works.
4. Epistemos-owned wrapper id: Epistemos naming is allowed if no donor protocol depends on the old name.

Do not rename protected deep contracts by default:
`OpenGUI`, `OpenCode`, `OpenWork`, `Goose`, `opengui`, `opencode`, `openwork`, `OPENCODE_*`, `OPENWORK_*`,
`OPENGUI_*`, `EPISTEMOS_WORK_OPENCODE_V0`, `EPISTEMOS_WORK_GOOSE_V0`, `EPISTEMOS_OPENGUI_SIDECAR_ROOT`,
`OPENWORK_MANAGE_OPENCODE`, `OPENWORK_OPENCODE_BIN`, `opencode.json`, `.opencode`, `openwork.*` localStorage keys,
`epistemos-native`, `epistemos-vault`, sidecar frame names, harness ids, tool names, imports, protocol strings, CLI
command names, bundle ids, TCC/Keychain names, automation hotwords, resource paths, and migration-sensitive hidden storage
paths such as `Epistemos/OpenGUIRuntime` and `Epistemos/WorkOpenGUI/workspace`.

UI direction:
The target is the flat OpenCode-like visual shown by the owner: mostly flat main cover/surface, compact controls, square
edges, monospace density, app theme tokens/custom theme support, no decorative cards inside cards, no marketing/hero
layout, no one-off warm RGB boxes, no needless hiding/removal. Advanced details can live in side panels or settings.
Controls should be real and useful, not fake placeholders.

Integration direction:
- Native Work surface drives OpenGUI runtime through the Swift sidecar supervisor.
- OpenCode is first proven engine; other engines should join through the same picker/adapter architecture.
- OpenWork remains fallback/preview until owner live proof passes; remove fallback only after that proof.
- Epistemos vault/native app tools must reach the engine through the native MCP bridge.
- Native MCP `tools/call` should reject missing/blank tool names before execution, and app-owned tool descriptors such as
  `epistemos.context.snapshot` should be appended idempotently if future native catalogs grow.
- Native MCP registrations written into OpenGUI/OpenCode/OpenWork config must be `http` loopback `/mcp` URLs with a
  non-empty bearer token and an explicit user-space port. Reject missing ports, port 0, privileged ports, non-loopback
  hosts, non-HTTP schemes, and non-`/mcp` paths.
- Runtime failures must be visible and honest, not swallowed.
- Live model-auth proof remains owner-gated. No code-complete claim should pretend that owner-only witness has run.

Loop process:
1. Inspect `git status --short` and relevant Work files before editing.
2. Identify the next highest-value Work/OpenGUI gap: naming, theme, runtime, sidecar protocol, endpoint parser, native MCP,
   session/recents, queue, permission/question, transcript/diff, fallback, or verification coverage.
3. Before changing a name, classify it with the naming law. If a rename could break runtime behavior, keep the donor name
   and document why.
4. Make one scoped hardening change at a time. Do not refactor unrelated app areas.
5. Add or update guards for every nontrivial boundary.
6. Run focused parse/static/tests after each meaningful change. Run broad Work-only checks after groups of changes.
7. Update docs/WORK_CANON_STATUS_2026_06_25.md with compact current truth, commands, results, blockers, and changed file
   inventory. Do not bury canon state only in long ledgers.
8. Leave unrelated dirty files alone. Do not revert user/other-agent changes. Do not commit unless explicitly instructed.

Focused Work-only checks that are safe while the shared app target is blocked:
- `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift`
- Foreground donor-name scan over Work chrome, Work settings, and app menu.
- Protected deep-name scan/guards for donor runtime contracts.
- `git diff --check` on touched Work/test/docs/probe files.
- trailing-whitespace scan on touched Work/test/docs/probe files.
- `node --check` for Epistemos-owned OpenGUI probe scripts.
- `.research-clones/work/opengui` tracked diff check.

Broad Xcode Work sweep when the shared app target is healthy:
`test_args=("${(@f)$(rg --files EpistemosTests | sed -n 's#^EpistemosTests/\(Work[^/]*Tests\)\.swift#-only-testing:EpistemosTests/\1#p; s#^EpistemosTests/\(Workspace[^/]*Tests\)\.swift#-only-testing:EpistemosTests/\1#p' | sort -u)}") && xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosWorkEndpointDD-$(date +%Y%m%d-%H%M) "${test_args[@]}"`

No-model OpenGUI live probes against built app resources:
Use unique `OPENGUI_OPENCODE_PORT` values and confirm cleanup leaves no matching `opencode serve` processes.
- `node --check og-sidecar.mjs`
- `node --check og-create-list-probe.mjs`
- `node --check og-loadresources-probe.mjs`
- `node --check og-introspect-harness-events-probe.mjs`
- `node --check og-open-messages-probe.mjs`
- `node --check og-error-recovery-probe.mjs`
- `env PATH=<Debug Epistemos.app>/Contents/Resources:$PATH OPENGUI_OPENCODE_PORT=<port> node og-create-list-probe.mjs`
- `env PATH=<Debug Epistemos.app>/Contents/Resources:$PATH OPENGUI_OPENCODE_PORT=<port> node og-loadresources-probe.mjs`
- `env PATH=<Debug Epistemos.app>/Contents/Resources:$PATH OPENGUI_OPENCODE_PORT=<port> node og-introspect-harness-events-probe.mjs`
- `env PATH=<Debug Epistemos.app>/Contents/Resources:$PATH OPENGUI_OPENCODE_PORT=<port> node og-open-messages-probe.mjs`
- `env PATH=<Debug Epistemos.app>/Contents/Resources:$PATH OPENGUI_OPENCODE_PORT=<port> node og-error-recovery-probe.mjs`

Anti-breakage closeout cycle:
- Re-run foreground UI scans for stale donor names in Work chrome, Settings, app menu, and string catalogs.
- Re-run protected-name scans proving no unsafe Epistemos renames landed in runtime contracts.
- Re-run hidden storage/path guards.
- Re-run control-reachability guards so minimalism did not remove recents, queue, pickers, permissions, questions,
  diffs, transcript, send/cancel, native tools, or fallback details.
- Re-run sidecar/probe syntax and no-model probes when runtime/sidecar code changes.
- Re-run broad Work parse/static checks.
- If Xcode is healthy, run focused tests and broad Work/Workspace sweep; record test counts and xcresult paths.
- Record exact commands and evidence in docs/WORK_CANON_STATUS_2026_06_25.md.

Owner-live gates:
Only the owner can complete the model-auth visual witness. Required proof: rebuild/run with Command-R, open
Settings -> Advanced -> Epistemos Work -> Open Epistemos Work, create/send/stream a real OpenCode session, verify
engine/model picker, prompt queue including Tab-to-queue, recents rail, transcript, diffs, native tools, and
permission/question cards after an intentional ask-permission flip. Do not remove OpenWork fallback before this passes.

Stop rule:
Keep the loop active until I explicitly say stop. If the full objective is not proven complete, do not redefine success
around the subset already done. Continue with the next highest-value Work/OpenGUI hardening, verification, or canon update.

Current stop marker:
The owner asked for a stopping point on 2026-06-25. Stop at
`docs/handoffs/WORK_OPENGUI_STOPPING_POINT_HANDOFF_2026_06_25.md` unless a newer directive reopens the Work/OpenGUI loop.
```
