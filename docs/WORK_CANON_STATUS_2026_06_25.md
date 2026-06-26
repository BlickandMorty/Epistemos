# Work Canon Status - 2026-06-25

Read this first for Work/OpenGUI/OpenCode status, Act/Osaurus foreground naming, and tool-surface truth. The long ledger
remains the evidence trail, but this file is the compact canon so the current state is not buried.

## Naming Law

- Foreground product surface: `Epistemos Work`.
- Foreground Act surface: `Epistemos Act`.
- Neutral foreground words are allowed: runtime, engine, bridge, workspace, tools, sessions, permissions, questions.
- Engine names may appear when they are real picker entries, diagnostics, comments/tests, or explicit runtime identity.
- The reasoned preserve/rename map lives in `docs/donor-contracts/work-opengui/INDEX.md`; consult it before any branding
  pass that touches donor/runtime names.
- Do not rename protected contracts: `OpenGUI`, `OpenCode`, `OpenWork`, `Goose`, `opengui`, `opencode`, `openwork`,
  `OPENCODE_*`, `OPENWORK_*`, `EPISTEMOS_WORK_OPENCODE_V0`, `EPISTEMOS_WORK_GOOSE_V0`,
  `EPISTEMOS_OPENGUI_SIDECAR_ROOT`, `OPENWORK_MANAGE_OPENCODE`, `OPENWORK_OPENCODE_BIN`, `opencode.json`,
  `.opencode`, `openwork.*` localStorage keys, `epistemos-native`, `epistemos-vault`, sidecar frame names, tool names,
  `Epistemos/OpenGUIRuntime`, `Epistemos/WorkOpenGUI/workspace`, imports, protocol strings, bundle/TCC/Keychain names,
  and automation hotwords.
- Current Act lane boundary: deleted Osaurus bridge names must not return in app/root/landing source unless the owner
  explicitly reassigns that migration with tests. Keep real donor/runtime names only where they are still active package,
  import, storage, protocol, or diagnostic contracts.
- Tool names may remain generic or compatibility-prefixed when that preserves runtime contracts. Foreground prompts must
  describe them as Epistemos tools for the current turn and must not tell the user that Epistemos-specific tools are
  missing merely because a callable name is generic or legacy-compatible.

## Current Architecture

- Primary Work surface: native Epistemos Work chrome over the OpenGUI harness/runtime, OpenCode-first.
- Fallback: OpenWork WebView preview stays present until the owner live proof passes; it is app-branded but contract names
  remain intact under the hood.
- OpenGUI sidecar launch resolves bundled OpenCode/Bun from both structured source resources (`opencode-runtime/bin`) and
  flattened built-app resources (`Contents/Resources`), so development and app-bundle layouts work without renaming donor
  commands or protocols.
- Native app tools: Work native MCP now exposes Epistemos vault/note tools from the active vault-backed Rust catalog, with
  the old Omega registry only as fallback. The app-owned loopback `/mcp` socket is now test-proven for initialize,
  `tools/call`, JSON-RPC notification 202 handling, session id headers, and bearer-token rejection.
- Endpoint hardening: the shared Work MCP HTTP parser rejects malformed/negative declared `Content-Length` and classifies
  over-cap declared bodies as `tooLarge` so the native MCP and SPA loopback servers return 413 instead of a generic 400.
  MCP 405 responses advertise `Allow: POST`; the SPA loopback server test surface covers `GET`, `HEAD`, bodyless `HEAD`
  errors, `Allow: GET, HEAD` on 405, MIME, 404, deep-link fallback, bootstrap injection, and reskin injection.
- Work runtime/settings controls live inside Epistemos Settings; engine/runtime identities remain in picker,
  diagnostic, and protected contract contexts rather than becoming separate user-facing settings islands.
- Native context seam: `WorkAppContextSnapshot` is a Work-owned plain-value boundary for app context. Today it reports the
  managed workspace, active vault root, registered native-tool state, app mode, selected engine/model/agent, active Work
  session id, queue depth, and `.opencode/skills` count in the existing engines panel; future graph/chat/note fields must
  populate this seam rather than importing deleted app-wide UI state directly into Work.
- Native context MCP: the app-owned `epistemos-native` MCP surface now includes `epistemos.context.snapshot`, a read-only
  tool returning the current `WorkAppContextSnapshot` JSON so OpenCode can ask what Epistemos context is attached without
  depending on deleted graph/chat/note UI state.
- UI direction: flat, square, monospace/TUI-dense, theme-token driven. Controls are moved behind toggles or panels, not
  deleted.
- Embedded SPA reskin also removes decorative gradient utility/inline backgrounds while preserving real image backgrounds,
  so the fallback surface stays flat without breaking provider icons or other asset imagery.
- Foreground settings copy stays app-facing: raw smoke-test env vars are not shown in the Work settings UI, and unavailable
  engine rows report `not wired` rather than implying a future adapter timeline.
- Foreground composer copy stays app-facing: the native input placeholder says `Ask Epistemos Work...`; engine display
  names remain confined to the picker/helper path.
- Fallback preview copy stays app-facing: the details panel says `Epistemos Work surface` instead of exposing SPA jargon,
  while OpenWork storage/protocol names stay protected below the surface.
- Fallback bridge visibility now stays honest: the WebView details panel surfaces the native tools registration state
  (`registered`, `registration failed`, `native bridge unavailable`, etc.) instead of silently dropping the app-tool bridge
  when the OpenWork worker registration path fails.
- Fallback details UI hardening: the WebView preview side panel keeps surface/runtime/worker/SPA/native-tools/workspace
  details scrollable and middle-truncates long status/path values, so fallback diagnostics remain reachable without
  turning the preview into the primary route.
- Act foreground direction: Settings, chat routing, mini chat, pairing prompts, engine errors, and health copy should say
  `Epistemos Act` or `local Act engine` while `ActOsaurus`/`OsaurusCore` stays in source-level bridges, imports, tests,
  diagnostics, and compatibility seams.
- Tool-surface direction: `CapabilityManifestBuilder`, `LocalAgentPromptBuilder`, and the Rust agent runtime prompt now
  explicitly tell the model that current callable tools are Epistemos capabilities even when exact callable names are
  generic or compatibility-prefixed. No-tools turns are scoped to "this turn" and should answer directly, not invent a
  missing Epistemos-tools limitation.
- Local tool-call parser direction: when no tools are available, bare JSON must remain a direct model answer instead of
  being canonicalized into a fake tool call.
- Surface naming audit: static foreground `Text`, `Text(verbatim:)`, `Button`, `Label`, `LabeledContent`, `Picker`,
  `Toggle`, `Menu`, `ProgressView`, `MotionTitle`, title, headline/detail, help, accessibility, navigation, and window
  title strings in Work chrome, Settings entry points, and the app menu do not leak OpenGUI/OpenCode/OpenWork/Goose names.
- Foreground runtime/status copy now says `Epistemos Work`; stale `OpenCode runtime...` and `OpenCode engine...` phrasing
  is guarded out in source and string-catalog tests. Engine names are intentionally still visible in engine pickers and
  diagnostics because those are real selectable/debuggable runtime identities.
- Legacy Work status details now refer neutrally to `other app modes` instead of foregrounding stale Chat/Act coupling.
  The protected `EPISTEMOS_WORK_OPENCODE_V0` and `EPISTEMOS_WORK_GOOSE_V0` flags remain unchanged as diagnostics and
  compatibility contracts.
- Extra string-catalog pass removed the stale foreground key `Open Epistemos Work engine bench`; the guard now rejects that
  label while preserving deep `opencode`/`opencode.json` contract names.
- Latest foreground naming pass also removed the stale `Work terminal not wired yet` and `terminal runtime off (opt-in, Pro)`
  user-facing phrases. The legacy `EPISTEMOS_WORK_OPENCODE_V0` gate remains named for compatibility and diagnostics, but
  the landing Work readiness dot now follows real bundled-runtime presence rather than that old manual gate.
- Latest terminal theme pass removed the old cream/ink no-theme fallback assumption from the Work terminal host. The live
  terminal still derives from `EpistemosTheme`; the safety fallback now uses macOS system colors rather than fixed warm RGB.
- Work terminal launch-spec failures no longer get swallowed into an endless `Starting work terminal...` state; failures
  now render the same themed `Epistemos Work terminal unavailable` view with the concrete error.
- Deep naming audit: protected OpenGUI/OpenCode/OpenWork/Goose identifiers are intentionally still present and test-guarded.
  The latest foreground pass keeps Epistemos labels at the user surface while leaving sidecar commands, harness ids,
  environment variables, package/import names, storage ids, and protocol strings donor-compatible.
- Contract naming guard now also checks the reverse direction: Epistemos surface branding must not rename donor runtime
  contracts such as `opencode.json`, `OPENCODE_CONFIG`, `OPENWORK_MANAGE_OPENCODE`, `OPENWORK_OPENCODE_BIN`,
  `OPENGUI_OPENCODE_PORT`, and `openwork.server.*` storage keys. App-owned ids like `epistemos-native`,
  `epistemos-vault`, `EPISTEMOS_OPENGUI_SIDECAR_ROOT`, and visible `Epistemos Work` labels are allowed.
- Prompt composer ergonomics now match the native queue: Enter still sends immediately when idle and queues while busy;
  Tab stages the current prompt into the native queue without sending or hiding the existing queue-row controls.
- Prompt queue parity now includes the OpenGUI after-part mode: queue rows expose `Steer after current part` and
  `Queue (cancel steer)`, and the native surface converts live `part.started` / `message.finished` boundaries into a
  one-shot abort plus the existing idle drain. Send-now, interrupt, reorder, and remove remain reachable.
- Prompt queue edit parity is restored: native queue rows expose the donor edit affordance with inline text editing,
  Enter/checkmark save, xmark cancel, and trimmed non-empty updates through `WorkPromptQueue.edit`.
- Prompt queue reliability hardening: queued prompts removed for idle drain or send-now are requeued at the front if the
  send fails, preserving prompt mode/model/agent/variant metadata instead of silently losing queued user work.
- Session title hardening keeps recents/rail text compact: prompt-derived titles and titles returned by the
  OpenGUI/OpenWork session mappers are collapsed to one line and bounded while canonical `harness:raw` session ids remain
  unchanged.
- Minimalism/control guard: the native Work surface may stay flat, dense, and panel-driven, but recents, engine/model/agent
  pickers, slash commands, prompt queue controls, permission/question cards, cancel/send, engine panel, and live-diff
  refresh must remain reachable.
- Primary route guard: the app menu / `⌘4` `Open Epistemos Work` command now opens the native OpenGUI-backed
  `WorkEngineSurfaceWindowController`. The WebView/OpenWork fallback remains available only as the Settings preview until
  owner visual proof allows removal.
- Native action hardening: cancel, permission responses, question answers/skips, and interrupt aborts no longer silently
  swallow supervisor failures. User-action failures surface as native transcript errors so the Work surface stays honest
  without renaming or weakening the underlying OpenGUI/OpenCode contracts.
- Permission/question event hygiene: question requests now require the same non-empty session identity as permission
  requests, and permission/question cleared events ignore blank session ids instead of dismissing cards from malformed
  harness events.
- Native runtime-load hardening: selected-engine connect, engine capability load, recents load, and rail history replay
  failures now surface as native transcript errors. Late live-diff refresh stays best-effort to avoid noisy background
  error spam.
- Native tool-bridge hardening: the primary OpenGUI-backed Work surface now surfaces a transcript error when Epistemos
  native MCP provisioning fails, instead of silently starting OpenCode without the app-owned tool bridge.
- Skills integration hardening: the primary OpenGUI-backed Work surface now provisions bundled/workspace skills plus the
  active Epistemos app vault's `skills/` into the managed `.opencode/skills` workspace before starting the runtime, so the
  native Work path does not depend on the fallback OpenWork route to expose app skills.
- Post-isolation deepening boundary: `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` is the checklist for
  wiring richer app context after the owner lifts the current graph/chat/mini-chat/note isolation. Until then, Work should
  keep deepening only inside the Work/OpenGUI lane and should not restore or patch deleted app-wide surfaces.
- Act context boundary: `AgentCloneAppContextSnapshot` is now the app-owned
  plain-value boundary for the hosted AgentClone surface. RootView passes that
  snapshot into the Act host shell and derives the smaller
  `AgentCloneHostContext` bridge payload from it, keeping foreground Epistemos
  context separate from protected clone runtime names. Its model-visible
  summary/JSON omit the internal app-support storage path.
- App-context panel hardening: the native engines panel now has a compact `EPISTEMOS CONTEXT` section driven by
  `WorkAppContextSnapshot`, giving the clone a visible native context boundary without touching graph/chat/note internals.
  The sheet wraps this panel in a fixed-size `ScrollView` so added providers/context rows do not clip controls.
- App-context MCP hardening: `WorkToolMCPCore` now advertises and handles `epistemos.context.snapshot` when a Work context
  provider is attached, and `WorkNativeMCPHost` updates that provider before and after native MCP registration.
- Native MCP core endpoint hardening: `tools/call` now rejects missing/blank tool names before execution, and the
  Epistemos context snapshot descriptor is appended idempotently so future native catalogs cannot duplicate it.
- Native MCP registration trust hardening: `epistemos-native` registrations must be non-empty-token HTTP loopback
  `/mcp` URLs with an explicit user-space port, so OpenGUI/OpenCode/OpenWork config paths cannot accidentally point at
  port 0, port 80, a missing port, or a non-loopback host.
- OpenGUI bridge hardening: the Swift supervisor now drains sidecar stderr separately from the stdout NDJSON channel, so
  diagnostics cannot fill the pipe and deadlock the runtime bridge.
- OpenGUI startup honesty: the Swift supervisor now rejects an init reply with zero `connectedHarnessIds` and surfaces the
  sidecar init errors instead of entering a dead-but-running state.
- Legacy loopback fallback hardening: `WorkRuntimeSupervisor` now keeps draining `opencode serve` output after the
  listening line, so runtime logs cannot fill the pipe and stall the fallback server.
- OpenWork preview worker hardening: `WorkOpenWorkSupervisor` now keeps draining `openwork-server` output after the
  listening line, so worker logs cannot fill the pipe and stall the WebView fallback worker.
- Transcript/history safety hardening: live `LiveSessionEvent` text/tool chunks now require a non-empty part or message
  route before becoming native transcript parts, and live plus reopened-history text/diffs are bounded with a visible
  `[truncated]` marker. This keeps huge clone output from overwhelming the native Work UI without changing protected
  OpenGUI/OpenCode protocol names.
- Session registry structural hardening: session `upsert` no longer implicitly promotes, demotes, or reparents existing
  sessions with the same id. Mini sessions stay child sessions unless the explicit promote path is used.
- Slash-command UI hardening: the native slash-command popover keeps all engine commands reachable in a bounded scroll
  area with stable row height and tail truncation for long names/descriptions, preserving compact flatness without hiding
  command functionality.
- Engines/context panel UI hardening: engine/provider/capability/context rows now reserve stable compact heights, keep
  status/count badges fixed-size, and truncate long labels or path-like context values so the panel stays flat and
  readable across app/custom themes.

## Verification

- Full app build passed with derived data `/tmp/EpistemosWorkEndpointDD-20260625-0719`.
- Focused Work endpoint slice passed 63 tests in 6 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-30-58--0500.xcresult`.
- Stale API/button guard pass passed 12 tests in 3 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-47-16--0500.xcresult`.
- Fallback copy/reskin pass passed 5 tests:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_08-56-38--0500.xcresult`.
- Flatness/branding pass passed 9 tests in 2 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-06-51--0500.xcresult`.
- Combined foreground Work guard pass passed 25 tests in 4 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-16-23--0500.xcresult`.
- New foreground/deep naming guard passed 4 tests:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-24-25--0500.xcresult`.
- Final combined Work slice passed 26 tests in 4 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-31-07--0500.xcresult`.
- Expanded entry-point naming guard passed 4 tests in 1 suite:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-41-05--0500.xcresult`.
- Latest combined Work slice after the expanded guard passed 26 tests in 4 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-46-29--0500.xcresult`.
- Wide foreground naming guard passed 4 tests in 1 suite:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-54-56--0500.xcresult`.
- Latest combined Work slice after the wide foreground guard passed 26 tests in 4 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_09-59-35--0500.xcresult`.
- Integrated Work settings guard passed 5 tests in 1 suite:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.06.25_10-12-24--0500.xcresult`.
- Endpoint/reskin parser hardening passed 45 tests in 4 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_10-07-52--0500.xcresult`.
- Latest foreground naming + endpoint/reskin/runtime slice passed 66 tests in 7 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_10-15-43--0500.xcresult`.
- Broad Work/Workspace verification passed 215 tests in 30 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_10-25-09--0500.xcresult`.
- Post-endpoint-polish MCP/SPA loopback verification passed 34 tests in 2 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_10-38-14--0500.xcresult`.
- Post declared-Content-Length hardening static checks passed: the shared parser rejects an oversized declared body before
  waiting for bytes, both Work loopback servers pass their request cap into the parser, foreground donor-name scan remains
  clean, and `git diff --check` is clean. Full Swift verification remains blocked by unrelated compile failures outside
  the Work/OpenGUI lane.
- Post-endpoint-polish broad Work/Workspace verification passed 217 tests in 30 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_10-43-05--0500.xcresult`.
- Work OpenGUI supervisor pass after bundled runtime/Bun path hardening passed 17 tests in 1 suite:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.06.25_10-26-33--0500.xcresult`.
- Latest foreground naming + OpenGUI supervisor guard passed 22 tests in 2 suites:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.06.25_10-42-08--0500.xcresult`.
- Latest integrated foreground naming/catalog guard passed 5 tests in 1 suite:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_10-58-40--0500.xcresult`.
- Latest foreground naming + Work readiness guard passed 37 tests in 4 suites:
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.06.25_10-59-44--0500.xcresult`.
- Native MCP loopback socket verification passed 24 tests in 1 suite:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_11-11-20--0500.xcresult`.
- Native MCP transport/core/config slice passed 47 tests in 3 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_11-17-39--0500.xcresult`.
- Naming plus Native MCP transport/core/config slice passed 53 tests in 4 suites:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_11-28-13--0500.xcresult`.
- Corrected full Work/Workspace sweep passed 222 tests in 30 suites, including the foreground/deep naming guard, native
  MCP loopback socket, OpenGUI/OpenWork supervisors, SPA reskin/server/scheme handler, session ontology, terminal theme,
  tool summaries, and workspace restore coverage:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_11-46-54--0500.xcresult`.
- Prompt/contract-registry naming guard passed 6 tests in 1 suite after adding the donor-contract preserve/rename map:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_11-58-52--0500.xcresult`.
- Prompt queue shortcut guard passed 8 tests in 1 suite, including Tab-to-queue and Enter-still-submits source wiring:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_12-28-17--0500.xcresult`.
- Hidden storage + minimal-controls guard passed 8 tests in 1 suite, including protected OpenGUI storage paths and
  source-level proof that the flat native surface keeps the expected Work controls reachable:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_13-04-26--0500.xcresult`.
- Primary-route + foreground/deep naming guard passed 8 tests in 1 suite after the app menu was corrected to open the
  native Work surface while preserving the Settings WebView preview:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_13-36-02--0500.xcresult`.
- Native action-error + foreground/deep naming guard passed 8 tests in 1 suite after cancel/permission/question/interrupt
  paths were hardened against silent `try?` failures:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_13-45-18--0500.xcresult`.
- Post native-tool provisioning visibility static checks passed: the primary Work startup path now checks the
  `WorkOpenGUIProvisioner.provisionNativeMCP` result and surfaces a transcript error if the Epistemos tool bridge cannot
  be written, while still starting the engine with default tools. Full Swift verification remains blocked by unrelated
  compile failures outside the Work/OpenGUI lane.
- Post runtime-load hardening static checks passed for Work-only source hygiene: foreground donor-name scan clean,
  whitespace clean, `git diff --check` clean, and forbidden silent-failure strings found only inside negative guard
  assertions. At that checkpoint, re-running `WorkCloneSettingsTests` was blocked outside this lane by a shared app
  target compile failure (`Test-Epistemos-2026.06.25_13-59-55--0500.xcresult`).
- Post settings-copy appification static checks passed: Work settings no longer exposes the terminal smoke-test env var,
  engine unavailable rows say `not wired`, foreground donor-name scan is clean, and `git diff --check` is clean. Full
  Swift verification was blocked at that checkpoint by unrelated shared app target compile failures outside the
  Work/OpenGUI lane.
- Post OpenGUI-supervisor stderr-drain static checks passed: source guard confirms stderr draining and cancellation,
  foreground donor-name scan remains clean, and `git diff --check` is clean. Full Swift verification was blocked at that
  checkpoint by unrelated shared app target compile failures outside the Work/OpenGUI lane.
- Post OpenGUI zero-harness startup static checks passed: `initRuntime` now validates non-empty `connectedHarnessIds`, the
  pure helper carries sidecar init errors into the thrown message, and source guards reject losing that startup honesty.
  Full Swift verification remains blocked by unrelated compile failures outside the Work/OpenGUI lane.
- Post composer-placeholder naming check passed: `engineDisplayName` is only used for picker labels/helper logic, the input
  placeholder is `Ask Epistemos Work...`, foreground donor-name scan remains clean, and `git diff --check` is clean. Full
  Swift verification was blocked at that checkpoint by unrelated shared app target compile failures outside the
  Work/OpenGUI lane.
- Post fallback-preview label check passed: the WebView fallback details panel uses `Epistemos Work surface`, the stale
  `Epistemos Work SPA` label is guarded out, foreground donor-name scan remains clean, and `git diff --check` is clean.
  Full Swift verification was blocked at that checkpoint by unrelated shared app target compile failures outside the
  Work/OpenGUI lane.
- Post fallback native-tools visibility static checks passed: the WebView details panel includes `native tools` bridge
  registration status, foreground donor-name scan remains clean, and `git diff --check` is clean. Full Swift verification
  remains blocked by unrelated compile failures outside the Work/OpenGUI lane.
- Post legacy fallback runtime drain static checks passed: source guard confirms `WorkRuntimeListeningState` and output
  drain cancellation, foreground donor-name scan remains clean, and `git diff --check` is clean. Full Swift verification
  was blocked at that checkpoint by unrelated shared app target compile failures outside the Work/OpenGUI lane.
- Post OpenWork preview-worker drain static checks passed: source guard confirms `WorkOpenWorkListeningState` and output
  drain cancellation, foreground donor-name scan remains clean, and `git diff --check` is clean. Full Swift verification
  remains blocked by unrelated compile failures outside the Work/OpenGUI lane.
- Swift parse-only verification passed for the changed Work files and guard test:
  `WorkEngineSurfaceView.swift`, `WorkOpenGUISupervisor.swift`, `WorkRuntimeSupervisor.swift`, `WorkWebSurfaceView.swift`,
  `WorkEnginesPanelView.swift`, `WorkCloneSettingsView.swift`, and `WorkCloneSettingsTests.swift`. This is syntax-only;
  full Xcode type-check/test was blocked at that checkpoint by unrelated shared app target compile failures outside the
  Work/OpenGUI lane.
- Post-control broad Work/Workspace sweep passed 226 tests in 30 suites, covering Work/OpenGUI naming guards, native MCP,
  OpenGUI/OpenWork supervisors, SPA server/scheme/reskin, prompt queue, session ontology/history, terminal theme,
  Work surface style, and workspace restore:
  `/tmp/EpistemosWorkEndpointDD-20260625-0719/Logs/Test/Test-Epistemos-2026.06.25_13-16-43--0500.xcresult`.
- Built app resource check passed with `PATH=<Debug Epistemos.app>/Contents/Resources:$PATH`: bundled `opencode`
  reports `1.17.9`; bundled `bun` reports `1.3.14`.
- Live no-model OpenGUI harness-event probe passed against built app resources on `OPENGUI_OPENCODE_PORT=48232`:
  bundled `opencode serve` became healthy; event subscription is `harness.on("event", ...)`; cleanup left no matching
  `opencode serve --port 48232`.
- Live no-model OpenGUI resource probe passed against built app resources on `OPENGUI_OPENCODE_PORT=48233`:
  `loadResources()` returned `providersData`, `agentsData`, and `commandsData`; cleanup left no matching
  `opencode serve --port 48233`.
- Live no-model OpenGUI create/list probe passed against built app resources on `OPENGUI_OPENCODE_PORT=48234`:
  `sessions.create` returned an `opencode:` session id and `sessions.list` found it; cleanup left no matching
  `opencode serve --port 48234`.
- Refreshed no-model OpenGUI probes passed against the current built app resources after the naming/control guard:
  sidecar init/create/list passed on `OPENGUI_OPENCODE_PORT=48245`, `loadResources()` returned provider/agent/command
  data on `48246`, and harness-event subscription shape passed on `48247` with cleanup leaving no matching
  `opencode serve` processes.
- `og-create-list-probe.mjs` verifier hardening passed: syntax check clean; an expected bad-path sidecar init error exits
  nonzero instead of hanging; the valid built-resource create/list probe still passes on `OPENGUI_OPENCODE_PORT=48249`.
- Post-route-fix rebuilt sidecar probes passed against current built app resources: create/list passed on
  `OPENGUI_OPENCODE_PORT=48250`, `loadResources()` returned provider/agent/command data on `48251`, and cleanup left no
  matching `opencode serve` processes.
- Refreshed sidecar probe scripts passed syntax checks (`og-sidecar.mjs`, `og-create-list-probe.mjs`,
  `og-loadresources-probe.mjs`, `og-introspect-harness-events-probe.mjs`). Live no-model probes against current built app
  resources passed on fresh ports: create/list on `OPENGUI_OPENCODE_PORT=48260`, provider/agent/command resource loading
  on `48261`, and harness-event subscription shape on `48262`; cleanup left no matching `opencode serve` processes.
- Refreshed sidecar/probe hardening passed after a concurrent-probe startup flake: `og-sidecar.mjs` now fails session and
  resource commands with `harness not connected: <id>` when init connects zero harnesses, and
  `og-create-list-probe.mjs` now fails immediately when `opencode` is absent from `connectedHarnessIds`. Node syntax checks
  passed, a sequential create/list probe passed on `OPENGUI_OPENCODE_PORT=48274`, and cleanup left no matching
  `opencode serve --port 4827*` processes.
- Final foreground-name scan is clean for stale OpenCode/OpenWork fallback phrases and the old terminal labels across
  `Epistemos/Work`, `Epistemos/Views`, `Epistemos/Resources`, and `EpistemosTests` outside the guard file.
- Latest raw name scan was classified: remaining OpenGUI/OpenCode/OpenWork/Goose hits are protected source comments,
  type/protocol names, engine-picker labels, diagnostic truth, or test negative fixtures; no additional foreground
  rename was made.
- Latest foreground naming/protected-contract spot check stayed clean: visible Work/Settings/app-menu SwiftUI/AppKit string
  scan found no donor-name leaks, protected `opencode`/`openwork.*`/`OPENGUI_*` names and hidden OpenGUI storage paths
  remain in contract contexts, and the only Epistemos/OpenGUI hybrid hits are hidden path guards or Epistemos-owned
  probe/docs/comment names.
- Latest minimization spot check stayed aligned with the OpenCode-flat target: native Work shape hits are zero-radius
  borders/cards and required panels; no decorative orb/bokeh/shadow chrome was introduced, and engine/status/tool controls
  remain available through the header/panels rather than being removed. Source guard now rejects hiding/removing the core
  Work controls while preserving the flat target.
- Latest SPA flatness pass added a targeted gradient-flattening rule for OpenWork utility/inline gradients; source guard
  confirms the rule while keeping real background images available for icons/assets. Full Swift verification remains
  blocked by unrelated compile failures outside the Work/OpenGUI lane.
- Current Work-only broad static sweep passed: `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift`,
  foreground donor-name scan clean, scoped `git diff --check` clean, trailing-whitespace scan clean, official OpenGUI
  clone tracked diff clean, and Node syntax checks clean for the Epistemos-owned sidecar/probe scripts. Full Xcode
  build/test remains blocked outside this lane by the concurrent deletion sweep: `LocalPackages/osaurus/Packages/OsaurusCore`
  and `Epistemos/Views/Chat/ChatSidebarView.swift` are absent; latest focused Xcode retry also stops outside Work at
  `Epistemos/State/AgentChatState.swift:97` (`DisplayPacedTextBuffer` is missing). A prior focused retry also stopped at
  `Epistemos/Intents/Schemas/CognitiveIntents.swift:57` (`AppBootstrap` has no `chatState`). The older `bootstrap.loadChat`
  reference was not present in the latest Work-lane source check; re-check before claiming the shared app target is healthy.
- Master restart prompt refreshed: `docs/handoffs/WORK_OPENGUI_MASTER_GOAL_PROMPT_2026_06_25.md` now reflects the full
  Work/OpenGUI loop, strict lane boundary, protected naming law, Tab-to-queue requirement, current external blockers,
  current hardening baseline, no-model probe workflow, anti-breakage closeout cycle, and current blocker evidence.
- Multi-engine permission/question route hardened: the Work-owned OpenGUI sidecar now stamps forwarded harness events with
  the originating `harnessId`, native request models preserve it, and Work permission/question replies route back to that
  source harness instead of whichever engine is currently selected in the picker.
- Endpoint audit cycle completed for Work-owned local surfaces: native MCP keeps loopback-only routing, bearer auth,
  origin checks, request caps, JSON-RPC notification handling, and real loopback POST coverage; the SPA server keeps
  loopback GET/HEAD serving, MIME/path traversal guards, bootstrap seeding, and reskin injection coverage. A source guard
  now also protects the sidecar's source-`harnessId` stamping.
- Foreground/deep naming audit re-run: no unsafe over-rebrand found in the Work/OpenGUI lane. `Epistemos` is used for
  foreground Work copy, app-owned native MCP/tool IDs, app support paths, and tests; donor/runtime contracts remain under
  their real names (`opencode.json`, `OPENCODE_CONFIG`, `openwork.server.*`, `OPENWORK_*`, harness ids, picker entries).
- Session identity/reopen audit completed against donor OpenGUI runtime: `SessionHandle.id` is canonical `harness:raw`
  and `sessions.open(id)` accepts the listed/created id. Native Work recents now preserve that ID, align the picker and
  resources to the reopened session's owning engine without clearing the transcript, connect that engine if needed, and
  surface a native error if a recent lacks engine identity.
- After-part/edit queue hardening passed scoped source checks: the native queue exposes the after-current-part control
  and donor edit affordance, `WorkEngineSurfaceView` watches live `part.started` / `message.finished` events to trigger a
  one-shot abort, and idle drain sends the queued prompt without removing send-now/interrupt/reorder/remove controls.
  `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift`, scoped `git diff --check`, and
  trailing-whitespace scan passed.
- Focused Xcode retry after the queue/concurrency compile fix passed the Work compile slice, then failed outside this lane:
  `xcodebuild test ... -only-testing:EpistemosTests/WorkPromptQueueTests -only-testing:EpistemosTests/WorkToolMCPCoreTests
  -only-testing:EpistemosTests/WorkNativeMCPServerTests` stopped at
  `Epistemos/Intents/Schemas/CognitiveIntents.swift:57` (`AppBootstrap` has no `chatState`), xcresult
  `/tmp/EpistemosWorkFocusedDD-20260625-queue-tools/Logs/Test/Test-Epistemos-2026.06.25_15-08-05--0500.xcresult`.
  No non-Work source was changed for that blocker.
- Attached mini-session creation is now wired in native Work without Chat/Act coupling: the session rail passes
  `onNewMini: createMiniSession`, creates a real child OpenGUI session through `sessions.create`, records it as
  `WorkSession.mini`, focuses it in `WorkSessionStore`, and filters background stream events so another session cannot
  bleed into the active transcript. Floating detach/reattach chrome stays hidden unless a real window hook is supplied.
  Fast parse passed, and the focused Xcode retry type-checked the Work files before stopping outside Work at
  `Epistemos/State/AgentChatState.swift:97` (`DisplayPacedTextBuffer` is missing), xcresult
  `/tmp/EpistemosWorkFocusedDD-20260625-queue-tools/Logs/Test/Test-Epistemos-2026.06.25_15-13-30--0500.xcresult`.
- Latest built-resource no-model OpenGUI probes passed against
  `/tmp/EpistemosWorkFocusedDD-20260625-queue-tools/Build/Products/Debug/Epistemos.app/Contents/Resources`: bundled
  `opencode --version` is `1.17.9`, bundled `bun --version` is `1.3.14`, `omega_mcp_stdio` is executable, create/list
  passed on `OPENGUI_OPENCODE_PORT=48310`, resource loading passed on `48311`, harness-event subscription shape passed on
  `48312`, and cleanup left no matching `opencode serve --port 4831*` processes.
- Latest Work-only static sweep after terminal-theme cleanup passed: `xcrun swiftc -parse
  Epistemos/Work/*.swift EpistemosTests/Work*.swift`, foreground SwiftUI/AppKit donor-name scan clean, forbidden deep
  Epistemos-renames scan clean, protected contract scan classified as expected runtime/config/storage/protocol contexts,
  scoped `git diff --check` clean, scoped trailing-whitespace scan clean, official OpenGUI clone tracked diff clean, and
  Node syntax checks clean for `og-sidecar.mjs`, `og-create-list-probe.mjs`, `og-loadresources-probe.mjs`, and
  `og-introspect-harness-events-probe.mjs`.
- Current-turn no-model OpenGUI built-resource probes passed against
  `/tmp/EpistemosWorkFocusedDD-20260625-queue-tools/Build/Products/Debug/Epistemos.app/Contents/Resources`: bundled
  `opencode --version` is `1.17.9`, bundled `bun --version` is `1.3.14`, `omega_mcp_stdio` is executable, create/list
  passed on `OPENGUI_OPENCODE_PORT=48340`, resource loading passed on `48341`, harness-event subscription shape passed on
  `48342`, and cleanup left no matching `opencode serve --port 4834*` or sidecar processes.
- Terminal stuck-start hardening passed Work parse and source guard: `WorkTerminalHostView` now stores `resolveError`,
  catches `realShellSpec()` failures, renders `WorkTerminalUnavailableView(detail: resolveError, ...)`, and the guard
  rejects reintroducing `resolvedSpec = (try? await realShellSpec())`.
- Primary OpenGUI skills provisioning passed Work parse and source guards: `WorkSkillsProvisioner` can copy active app-vault
  skills into a managed Work workspace, and `WorkEngineSurfaceView` calls `WorkSkillsProvisioner.provisionAll(...,
  vaultRoot: epistemosVaultRoot)` before `supervisor.start(...)`.
- Native context seam source guards passed: `WorkAppContextSnapshot` stays a plain Work-owned model, counts managed
  `.opencode/skills`, exposes workspace/vault/native-tool state in the existing engines panel, and rejects direct imports
  of deleted graph/chat/note UI state.
- Native context MCP source guards passed: `epistemos.context.snapshot` appears in `tools/list`, returns the current
  snapshot through `tools/call`, and startup wires the snapshot through native MCP provisioning before OpenGUI starts.
  The snapshot now includes Work-native live state: selected engine/model/agent, active session id, and queue depth.
- Native context MCP loopback coverage is now present: `WorkNativeMCPServerTests` starts a loopback server with a
  `WorkAppContextStore`, verifies `tools/list` includes `epistemos.context.snapshot`, and verifies `tools/call` returns
  the attached Work context JSON.
- Current native context compile fixes: the Work-owned context store is explicitly `nonisolated`/lock-backed so
  `WorkNativeMCPServer` can serve `epistemos.context.snapshot` from its Sendable loopback request path without importing
  main-actor UI state. The engines context panel uses the existing `theme.resolved.foreground.color` token instead of a
  nonexistent foreground API.
- Focused Xcode retry for the context/MCP slice then got past those Work errors and stopped outside this lane:
  `xcodebuild test ... -only-testing:EpistemosTests/WorkAppContextSnapshotTests
  -only-testing:EpistemosTests/WorkToolMCPCoreTests -only-testing:EpistemosTests/WorkNativeMCPServerTests` failed in
  `Epistemos/State/AgentChatState.swift` because `DisplayPacedTextBuffer` and `StreamingReasoningTraceBuffer` are
  missing after the app-wide chat deletion/refactor sweep. No shared chat/app files were changed for that blocker.
  xcresult:
  `/tmp/EpistemosWorkSkillsDD-20260625/Logs/Test/Test-Epistemos-2026.06.25_16-01-17--0500.xcresult`.
- New no-model OpenGUI endpoint probe passed against built app resources on `OPENGUI_OPENCODE_PORT=48358`:
  `og-open-messages-probe.mjs` drove the exact NDJSON sidecar boundary through `init -> sessions.create ->
  sessions.open -> messages -> close`; it reopened the canonical `opencode:...` session id, read the messages payload
  without model auth, exited 0, and cleanup left no matching `opencode serve --port 48358` or sidecar processes.
- Source guard added for that endpoint proof: `WorkOpenGUISupervisorTests` now reads the Epistemos-owned sidecar/probe
  scripts and asserts that `sessions.open`, `messages`, canonical reopen validation, and `OPENGUI_OPENCODE_PORT` remain
  present. `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift`, scoped `git diff --check`, and
  `node --check og-open-messages-probe.mjs` passed after the guard.
- Current four-endpoint no-model probe pass also succeeded against the same built resources:
  create/list on `OPENGUI_OPENCODE_PORT=48360`, provider/agent/command `loadResources` on `48361`, harness-event
  subscription on `48362`, and create/open/messages history on `48363`. Cleanup left no matching
  `opencode serve --port 4836*` or sidecar processes, and the official OpenGUI clone still has no tracked donor-file
  diffs.
- Current foreground/deep naming and flatness scans classified cleanly. Remaining donor/runtime names are engine picker
  labels, diagnostic truth, comments, protected config/env/storage contracts, or negative test fixtures; hidden
  Epistemos/OpenGUI hybrid names remain migration-sensitive app-owned paths or sidecar override ids. Work visual styling
  hits remain square/token-driven controls, required cards, and targeted fallback gradient removal; no new decorative
  orb/bokeh/gradient chrome was introduced and no controls were removed for minimalism.
- Native context MCP reserved-name guard added: `WorkToolMCPCoreTests` now proves `epistemos.context.snapshot` does not
  fall through to the generic native executor when no context provider is attached; it returns a bounded unavailable
  payload with `isError: false`. Work parse and scoped `git diff --check` passed after this guard.
- Native context freshness guard added: `WorkCloneSettingsTests` now locks the `selectedModelID`, `selectedAgent`,
  `activeSessionID`, and `queue.count` change hooks that call `refreshAppContext()`, so the visible context panel and
  `epistemos.context.snapshot` MCP payload cannot silently stay on stale model/session/queue state. Work parse and scoped
  `git diff --check` passed after this guard.
- Native context panel path compaction hardened: workspace/vault paths now use middle ellipsis, preserving the project or
  vault tail in the small flat engines panel instead of hiding it behind prefix-only truncation. `WorkAppContextSnapshot`
  tests now assert bounded path rows with tail preservation; Work parse and scoped `git diff --check` passed.
- OpenGUI workspace `opencode.json` merge hardened: `WorkOpenGUIProvisioner` now builds the `epistemos-native` config
  entry through pure merge helpers, and `WorkOpenGUISupervisorTests` proves the merge preserves existing workspace config
  keys and user-installed MCP entries while reasserting only the native app-tools bridge. Work parse and scoped
  `git diff --check` passed.
- OpenGUI provisioning now ensures the managed workspace directory exists before writing `opencode.json`, so a future
  caller cannot silently lose the native tool bridge by passing a not-yet-created workspace path. `WorkSkillsProvisioner`
  source guards cover this, and Work parse/scoped `git diff --check` passed.
- Focused Xcode retry for `EpistemosTests/WorkSkillsProvisionerTests` compiled into the app target far enough to type-check
  Work files, then failed outside this lane at `Epistemos/Intents/Schemas/CognitiveIntents.swift` because `AppBootstrap`
  has no `chatState`; no shared app/chat files were changed for that blocker. xcresult:
  `/tmp/EpistemosWorkSkillsDD-20260625/Logs/Test/Test-Epistemos-2026.06.25_15-31-00--0500.xcresult`.
- Refreshed no-model OpenGUI probes passed against current built app resources
  (`/tmp/EpistemosWorkEndpointDD-20260625-0719/Build/Products/Debug/Epistemos.app/Contents/Resources`): create/list on
  `OPENGUI_OPENCODE_PORT=48290`, resource loading on `48291`, and harness-event subscription shape on `48292`; cleanup
  left no matching `opencode serve --port 4829*` processes.
- Final official OpenGUI clone delta check is clean: `.research-clones/work/opengui` has no tracked donor-file diffs at
  `e25cb97`; only the listed untracked Epistemos probe/sidecar scripts are present.
- Goose clone surface verification stayed intact after the flat/pixel/Epistemos foreground pass: left navigation remains
  present with chats, recent sessions/history, recipes, skills, apps, scheduler, extensions, settings, new chat, and
  side-panel access; foreground app name is `Epistemos`, but Goose userData/runtime contracts remain Goose-compatible.
- Goose clone focused UI/compat tests passed 21 tests in 6 Vitest files, plus Rust prompt/chat-mode checks:
  `NavigationPanel.test.tsx`, `NavigationContext.test.tsx`, `compatIdentity.test.ts`, `updateFeedConfig.test.ts`,
  `launcherSurface.test.ts`, `createSession.test.ts`, `cargo test -p goose test_build_system_prompt --lib`, and
  `cargo test -p goose chat_mode_skip_response_points_to_mode_not_missing_tools --lib`.
- Act foreground/deep-name guard passed 39 tests in 4 suites (`ActSurfaceOsaurusUIDirectionGuardTests`,
  `ActOsaurusSeamTests`, `SharedActComposerTests`, `WorkCloneSettingsTests`):
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.06.25_13-24-17--0500.xcresult`.
- Swift prompt/tool anti-regression guard passed 44 tests in 5 suites (`AgentCapabilityTruthCloseoutTests`,
  `ChatVaultLookupRoutingTests`, `HermesPromptBuilderTests`, `DeviceAgentServiceTests`, and
  `LocalAgentLoopTests/noToolsTurnsReturnBareJsonDirectly`):
  `/Users/jojo/Library/Developer/Xcode/DerivedData/Epistemos-ctkiyqxaarezsccbouumxcpfxvtl/Logs/Test/Test-Epistemos-2026.06.25_13-31-17--0500.xcresult`.
- Rust prompt/tool anti-regression guard passed 17 tests:
  `cd /Users/jojo/Downloads/Epistemos/agent_core && cargo test --test agent_runtime`.
- Act foreground string scan is clean for visible `Osaurus` leaks in SwiftUI/AppKit surfaces and Act transport errors.
  The deleted `ActOsaurus`/`OsaurusCore` bridge names now stay out of app/root/landing source and are guarded as removed;
  remaining mentions are limited to tests/docs that describe the deletion boundary.
- Current Act/AgentClone bridge check: RootView mounts `AgentCloneChatHostSurface` for Chat/Act, embeds
  `AgentClone.ContentView()` as the protected Swift-agent foundation, and injects Epistemos theme tokens; Landing submission selects `.act`, records the prompt in `AgentChatState`, and in non-App Store builds calls
  `AgentCloneBridge.submitPrompt(trimmed)` unconditionally so the visible AgentClone runner receives the prompt. AgentClone
  `ContentView` receives `epistemos.agentclone.submitPrompt`, writes the prompt into the active tab or root task input, and
  starts the existing AgentClone run path. Prompt submissions now carry a prompt id and stay in an AgentClone-owned pending
  buffer until consumed, so app-entrypoint prompts posted before `ContentView` subscribes are drained on appear instead of
  being lost.
- Current Act/AgentClone mode route: `WorkspaceModeSelection.select(_:)` now posts
  `epistemos.workspace.mode.didSelect`, and `HomeRouter` consumes that notification to update a mounted `workspaceMode`.
  Landing/app entrypoints that select `.act` now move the visible route instead of only changing persisted defaults.
  `WorkspaceModeSelectionTests` now also verifies the behavior directly by observing the same `UserDefaults` suite as the
  notification object and asserting the selected raw mode payload.
- Current Act/AgentClone context bridge: RootView builds `AgentCloneAppContextSnapshot` with Epistemos app name, home
  workspace, active vault root, app-support root, current mode, and presentation, then publishes the bounded
  `AgentCloneHostContext` derived from it when Chat/Act is active. AgentClone consumes
  `epistemos.agentclone.hostContext` and applies the preferred vault/workspace through its existing `projectFolder` seam
  only when the clone folder is empty, home, the same host-applied folder, or the new host folder. The same context summary
  now includes the presentation/surface label for side-panel and task-prefix grounding. This preserves manual
  clone project-folder selection and leaves deep contracts such as `agentProjectFolder` and `AGENT_PROJECT_FOLDER`
  unchanged. `ContentView` also applies any already-published `currentHostContext` on appear before draining pending
  prompts, so app grounding is not lost when RootView publishes context before the clone subscribes.
- Current Act/AgentClone storage bridge: RootView includes
  `appSupportRootPath` in `AgentCloneHostContext`, pointing at
  `Application Support/Epistemos/AgentClone`. AgentClone `SessionStore` now
  writes new JSONL session transcripts under that app-owned `sessions/` path
  and keeps `~/Documents/AgentScript/sessions` as a legacy import/read/delete
  fallback. Script/tool/skill/hook/memory roots remain donor-compatible until
  each has its own migration adapter and proof.
- Current Act/AgentClone foreground help resources are rebranded: bundled
  `Agent.help` HTML pages now use Epistemos/Epistemos Scripts/privileged helper
  wording, while exact compatibility paths and helper ids remain only as
  technical code-spanned facts. A donor-contract resource guard protects this.
- Current Act/AgentClone host-shell rails use foreground-neutral wording
  (`Swift agent foundation`, `Epistemos bridge`) instead of exposing donor
  module names in visible rail rows.
- Current Act/AgentClone host-shell rails preserve reachability: hiding a rail
  exposes restore controls on desktop, and compact layouts use real overlay
  session/context panels instead of inert buttons.
- The embedded AgentClone side panel now shows a compact `Epistemos context` readout when host context is present. This
  makes vault/workspace/mode grounding visible without adding a new app surface or removing any clone controls.
- The same host-context summary is also injected into the existing AgentClone task prefix as
  `[Epistemos context: ...]` for both main tasks and tab tasks, so the model sees the app grounding through the normal
  clone execution path rather than through a parallel custom runner.
- AgentChatState's generic streaming helpers were extracted into
  `Epistemos/State/AgentStreamingSupport.swift` after the old `ChatState.swift` deletion removed their former home. This
  preserves the Act/Landing session ledger without restoring deleted Chat, Note Chat, Graph Chat, or MiniChat surfaces.
  The seam is guarded in both `ActSurfaceOsaurusUIDirectionGuardTests` and
  `ChatDonorContractsTests`.
- Act post-isolation deepening is now tracked separately in
  `docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`. The plan maps MiniChat, Graph Chat, Note
  Chat, document context, graph context, note actions, and native app actions into future AgentClone-backed portals after
  the owner lifts the current isolation; this lane must not restore those deleted surfaces prematurely.
- The Act post-isolation plan now also records local source findings for later deepening: Work's bounded
  `WorkAppContextSnapshot`/`epistemos.context.snapshot` pattern, `AgentChatState` session metadata, `ThreadState`
  context attachments, `DocumentSurface` as a serializable attachment, and `VaultSyncService` read seams
  (`fetchNoteBodies(ids:)`, `findNotesByTitle(_:)`). It now tracks the initial
  `AgentCloneAppContextSnapshot` plus future native-action fields, but none of
  those app-wide graph/note/mini/native tools are implemented while isolation is
  active.
- The deleted Act settings pane and Osaurus notification bridge are not restored in this lane. Settings entrypoints use the
  existing Settings shell; no `.showActOsaurusSettings` compatibility notification is reintroduced.
- Current static hygiene after the bridge is clean for the scoped files: `git diff --check` passed, foreground Swift
  `Osaurus` user-facing string scan found no hits, and `Epistemos/Resources/Localizable.xcstrings` parses with no
  donor-name key/comment hits.
- Bridge drift was re-audited against the current deletion sweep: the old Osaurus compatibility route is now intentionally
  removed, and the donor-contract guard rejects reintroducing `submitActOsaurusPrompt`, `openActOsaurusSession`,
  `showActOsaurusSettings`, `ActOsaurusPromptRequest`, or the stale RootView metadata serializer.
- AgentClone provenance was refreshed to the current route: Landing selects `.act`, syncs `AgentChatState`, and calls
  `AgentCloneBridge.submitPrompt(trimmed)` directly; the previous `ActOsaurusPromptRequest` serialization note is now
  explicitly historical/invalid, and the ChatView2 route/panel/transcript records are classified as rejected historical
  experiments rather than current route truth. The Swift chat donor index and Act/AgentClone master loop prompt now carry
  the same classification so future loops do not revive `ChatRouteView`, and
  `testAgentCloneRouteDocumentationMatchesDirectRouteTruth` now guards that documentation route truth.
- Isolated AgentClone package builds passed from `LocalPackages/AgentClone`: the first build compiled
  `ContentView.swift` and `EpistemosAgentBridge.swift`; the second build passed after foreground copy cleanup in
  `ServicesPopover.swift`, `HeaderSectionView.swift`, `AgentViewModel.swift`, and `Colors.swift`.
- Embedded AgentClone foreground copy now avoids the stale visible labels `User Agent`, `Daemon Agent`,
  `Background Agents`, and `Agent Question`; protected `AgentScript` script/tool roots, legacy session fallback, bundle
  ids, keychain service names, package/module names, and remote repository names remain unchanged.
- Embedded AgentClone helper copy now says `User Helper` / `Privileged Helper` in the foreground service popover and
  `Epistemos user helper` / `Epistemos privileged helper` in visible errors, status rows, and model self-description; the
  old `User Agent` / `Launch Daemon` terms remain only in implementation comments and helper-service contracts.
- Swift chat donor-contract package baseline passed 69 tests after the AgentClone host route guard was corrected, the
  legacy-deletion guard was tightened to reject old Osaurus UI/import routes, and the landing guard now proves submissions
  select Act, call both `agentChat.submitAgentQuery(trimmed)` and `AgentCloneBridge.submitPrompt(trimmed)`, and reject
  hiding the bridge behind the currently-dead `isActSearchPage` branch. The latest guard also proves protected
  AgentClone runtime contracts were not over-renamed, including the new Epistemos-owned session path plus donor-session
  fallback, and the newest guard keeps `AgentChatState` streaming helpers in
  `AgentStreamingSupport.swift` without restoring old chat-state files:
  latest targeted rerun passed
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts --filter 'testActLandingRoutesDirectlyToAgentCloneFoundationWithoutOsaurusBridge|testAgentCloneHelpResourcesUseEpistemosForegroundNames|testAgentCloneRouteDocumentationMatchesDirectRouteTruth'`.
- Latest focused checks passed after the direct landing-to-AgentClone bridge, helper-copy cleanup, and left control-panel
  restoration: `swift build` in `LocalPackages/AgentClone`,
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts` (68 tests), `git diff --check` over scoped
  Act/AgentClone files, and foreground scans for stale `Osaurus`, `sidebar.right`, trailing panel transitions,
  `Background agent`, and visible `Daemon` labels.
- Latest focused checks passed after adding the Epistemos host-context bridge and side-panel context readout:
  `swift build` in `LocalPackages/AgentClone`,
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts` (68 tests), `jq empty` for AgentClone provenance,
  scoped `git diff --check`, stale foreground helper-name scans, deleted Osaurus bridge-name scans, and protected
  bridge/storage-name scans.
- Latest focused checks passed after adding model-visible host-context prompt grounding for main and tab tasks:
  `swift build` in `LocalPackages/AgentClone`,
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts` (68 tests), scoped `git diff --check`, and
  source guards for `hostContextSummary: epistemosHostContextSummary` in both execution paths.
- Clone-origin audit saved in `docs/handoffs/ACT_AGENTCLONE_CLONE_DELTA_AUDIT_2026_06_25.md`: upstream `Agent` has 251
  files, local `Sources/AgentClone` has 254 files, and the count increase is the expected Epistemos bridge/reskin/context
  additive files. The audit records protected deep contracts and the current verification baseline.
- `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift` was rewritten for the current worktree so it no longer
  loads deleted `ChatView`, `MiniChat`, `SharedActInference`, `Epistemos/ActOsaurus`, `ActCloneSettingsView`, or
  `LocalPackages/osaurus` files; it now guards the AgentClone route, landing-to-runner prompt bridge, embedded foreground
  copy, and rejection of deleted Osaurus compatibility names.
- Current Xcode package resolution succeeds after the concurrent project changes:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -resolvePackageDependencies`.
- Latest targeted Xcode test attempt for `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests` reached the shared app
  target but failed before running the lane guard because unrelated Graph/Farm sources do not compile
  (`DialogueNodeProfile`, `ContentPersonalitySignals`, `DialogueNodeInsight`, `DialogueMood`, `DialoguePortraitAsset`,
  `DialogueCareState`, `onSelectNode`/`onRevealNode`, and UUID/String mismatches). This is outside the Act/AgentClone lane
  and was not repaired here.
- Latest targeted Xcode mode-selection attempt with derived data
  `/tmp/EpistemosActAgentCloneDD-20260625-mode-notify` first exposed the missing generic streaming helpers in
  `AgentChatState`; those were extracted to `AgentStreamingSupport.swift`. The rerun then failed before tests because the
  build list still referenced deleted old-chat file `Epistemos/Views/Chat/AgentRunTimelineView.swift`. A fresh derived-data
  rerun with `/tmp/EpistemosActAgentCloneDD-20260625-mode-notify-fresh` got past that stale file but then failed before
  tests because the generated app target file list still includes deleted old-chat files
  `Epistemos/Views/Chat/AnswerPacketBadge.swift` and `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`, an outside-lane
  deletion/refactor cleanup that was not repaired here.

## Changed Files Inventory

Tracked modified app/test files:

- `Epistemos/App/EpistemosApp.swift` - discoverable `Open Epistemos Work` menu command now opens the primary native Work
  surface; the WebView fallback stays in Settings as the preview.
- `Epistemos/Views/Settings/SettingsView.swift` - foreground `Epistemos Work` settings tab label and description.
- `Epistemos/Views/Settings/WorkCloneSettingsView.swift` - Epistemos Work foreground copy, integrated settings wording,
  flat/square settings chrome, launch labels; terminal footer now avoids exposing the raw smoke-test env var.
- `Epistemos/Views/Settings/WorkOpenCodeShellHealthRow.swift` - neutral foreground runtime status copy.
- `Epistemos/Work/WorkBackendGateStatus.swift` - neutral secondary-engine status copy while preserving
  `EPISTEMOS_WORK_GOOSE_V0`; stale Chat/Act foreground coupling copy is removed.
- `Epistemos/Work/WorkOpenCodeRuntime.swift` - bundled runtime/resource fallback, persistent merge-preserving config, theme/LSP/fusion hardening.
- `Epistemos/Work/WorkOpenCodeShell.swift` - shell seam/env hardening for the bundled runtime; foreground inert error copy
  is Epistemos Work branded.
- `Epistemos/Work/WorkOpenCodeShellGateStatus.swift` - Epistemos Work terminal-runtime status copy while preserving
  `EPISTEMOS_WORK_OPENCODE_V0` as a legacy compatibility/diagnostic contract; stale Chat/Act foreground coupling copy is
  removed.
- `Epistemos/Work/WorkTerminalView.swift` - theme-aware terminal host/palette work; no-theme safety fallback now uses
  system colors instead of fixed cream/ink RGB, the no-vault comment matches the honest fusion-omission behavior, and
  launch-spec failures render a concrete themed unavailable state instead of a stuck spinner.
- `Epistemos/Resources/Localizable.xcstrings` - stale foreground Work/OpenCode strings cleaned to Epistemos Work/neutral
  runtime wording; removed the stale `Open Epistemos Work engine bench` key.
- `EpistemosTests/WorkCloneSettingsTests.swift` - foreground branding guard across Work chrome, Settings entry points, and
  app menu, plus protected deep-name guard; covers wider SwiftUI/AppKit foreground string surfaces and rejects
  separate-settings copy in the Work settings surface; now also guards stale foreground runtime/status phrases and the
  removed `Open Epistemos Work engine bench` catalog key while preserving protected `OPENCODE_CONFIG`/`opencode.json`;
  also rejects unsafe Epistemos-renames of donor contract names (`openwork.server.*`, `OPENWORK_*`, `OPENGUI_OPENCODE_PORT`),
  protects migration-sensitive hidden OpenGUI storage paths, and guards that flat/minimal Work chrome keeps the expected
  controls reachable; it also rejects regressions that silently swallow native permission/question/cancel action failures
  or selected-engine/resource/recents/history load failures, rejects composer-placeholder engine-name leaks, and guards
  out stale Chat/Act coupling in Work status details.
- `EpistemosTests/WorkOpenCodeRuntimeTests.swift` - runtime/config/env regression coverage.
- `EpistemosTests/WorkOpenCodeShellSeamTests.swift` - terminal-runtime seam/status coverage.
- `EpistemosTests/WorkTerminalViewTests.swift` - terminal theme guard now rejects fixed cream/ink fallback assumptions and
  launch-spec error swallowing.
- `EpistemosTests/WorkspaceModeSelectionTests.swift` - Work readiness now follows the real bundled runtime instead of the
  legacy manual gate or env flag, while ACT readiness stays on its shared route.

Observed unrelated dirty file left untouched:

- `Epistemos/Views/Settings/EpistemosPicksSectionView.swift` - Apple Intelligence availability copy change already present
  in the worktree; not part of the Work/OpenGUI branding pass.

Act/tool foreground integration files:

- `Epistemos/App/EpistemosApp.swift` - old Osaurus notification names and `ActOsaurusPromptRequest` remain deleted; app
  commands do not recreate the legacy Act bridge.
- `Epistemos/App/RootView.swift` - mounts `AgentCloneChatHostSurface` for Chat/Act and keeps
  Work on the separate native terminal route; builds `AgentCloneAppContextSnapshot` and derives the bounded
  `AgentCloneHostContext` bridge payload so the clone can inherit Epistemos workspace/vault context without importing
  graph/note/mini UI types.
- `Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift` - plain-value Epistemos context boundary for the
  hosted AgentClone shell.
- `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift` - Epistemos-owned Chat/Act shell that embeds
  `AgentClone.ContentView()` and adds native session/context rails without restoring old chat/backend routes or Overseer
  diagnostics as the standard chat panel.
- `Epistemos/Views/Landing/LandingView.swift` - landing submission selects Act, keeps the app-level `AgentChatState`
  session record, and in non-App Store builds calls `AgentCloneBridge.submitPrompt(trimmed)` so the visible AgentClone
  runner receives the prompt.
- `Epistemos/State/AgentStreamingSupport.swift` - generic streaming helper extraction for `AgentChatState`; keeps
  display-paced text buffering and reasoning-trace accumulation available without restoring deleted old-chat state files.
- `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` and `Epistemos/Views/Graph/HologramSearchSidebar.swift` - old
  graph/note chat submission paths remain deleted/neutralized; they do not post the Osaurus notification bridge.
- `EpistemosTests/SettingsCategoryTests.swift` - visible settings guard now matches the current Settings enum
  (`workClone` + `beyondClone`; no deleted `actClone`) while documenting that Act is routed through AgentClone.
- `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift` - source guard for the AgentClone-backed host route, landing-to-runner
  prompt bridge, foreground copy, `AgentChatState` streaming-support extraction, and rejection of deleted Osaurus
  notification names.
- `LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/HostContext.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/Views/ContentView/ContentView.swift`, and
  `Epistemos/Views/Landing/LandingView.swift` - current AgentClone prompt receiver and app entrypoint bridge; old direct
  `ChatView`/`ActEpistemosChatSurface` RootView routes remain removed by the concurrent surface rewrite. The embedded
  capability panel now opens from the left again and the chat column reserves that rail instead of covering the composer.
  The host-context bridge safely adopts the active Epistemos vault/workspace into AgentClone `projectFolder` without
  renaming storage/runtime keys or clobbering a manual project folder, and the side panel displays the current Epistemos
  context summary when available. `TaskUtilities.newTaskPrefix` also injects the host-context summary into the normal
  prompt prefix for both main tasks and tab tasks.
- `LocalPackages/AgentClone/Sources/AgentClone/Views/Header/ServicesPopover.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/Views/Header/HeaderSectionView.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/AgentViewModel.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/Colors.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/Init.swift`,
  `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/RunStop.swift`, and
  `LocalPackages/AgentClone/Sources/AgentClone/EpistemosReskin.swift` - safe foreground copy cleanup for the embedded
  Act/AgentClone chrome; visible startup copy now says `Advanced helpers unavailable — Epistemos runs in-process.`, while
  deep service names and automation storage remain donor-compatible.
- `LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift`,
  `docs/donor-contracts/swift-chat/INDEX.md`, and
  `docs/donor-contracts/swift-chat/agent-clone/provenance.json` - donor-contract route ledger aligned to the current
  AgentClone-backed host route and deleted Osaurus notification boundary.
- `Epistemos/Engine/CapabilityManifestBuilder.swift`, `Epistemos/LocalAgent/LocalAgentPromptBuilder.swift`,
  `Epistemos/LocalAgent/LocalAgentLoop.swift`, `Epistemos/Omega/Inference/DeviceAgentService.swift`,
  `agent_core/src/agent_runtime/prompt_format.rs`, and `agent_core/tests/agent_runtime.rs` - tool identity regression fix:
  generic/compat callable names are still presented as Epistemos tools for the turn, no-tools prompts are turn-scoped, and
  no-tools bare JSON remains a direct answer.
- `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift`, `EpistemosTests/ActOsaurusSeamTests.swift`,
  `EpistemosTests/AgentCapabilityTruthCloseoutTests.swift`, `EpistemosTests/HermesPromptBuilderTests.swift`,
  `EpistemosTests/DeviceAgentServiceTests.swift`, and `EpistemosTests/LocalAgentLoopTests.swift` - foreground/deep-name and
  tool-identity regression guards.

New Work source files in the app tree:

- `Epistemos/Work/WorkAppContextSnapshot.swift` - Work-owned plain-value context boundary for workspace, active vault,
  native tool registration, app mode, selected engine/model/agent, active Work session id, queue depth, managed skills
  count, and future graph/chat/note summaries without importing deleted app-wide UI state into the OpenGUI lane.
- `Epistemos/Work/WorkBlockCaretField.swift` - native flat block-caret input; Enter submits, Tab queues without inserting a
  tab or changing focus.
- `Epistemos/Work/WorkDiffText.swift`
- `Epistemos/Work/WorkEngineResources.swift`
- `Epistemos/Work/WorkEngineSurfaceView.swift` - native flat engine workbench surface; wires the block-caret Tab action to
  the queue-only path while preserving Enter send-now behavior, and surfaces cancel/permission/question action failures as
  transcript errors instead of silently dropping them; selected-engine connect, capability load, recents load, and rail
  history replay failures now surface the same way; native tool-bridge provisioning failure is also surfaced before engine
  startup continues with defaults; reopening recents preserves canonical OpenGUI session ids; live part boundaries drive
  the after-current-part queue mode; prompt-derived session titles are normalized before session creation; composer
  placeholder is Epistemos Work branded while picker labels keep engine identities.
- `Epistemos/Work/WorkEngineSurfaceWindowController.swift` - primary native Epistemos Work window controller for app menu
  and Settings launch.
- `Epistemos/Work/WorkEngineTranscript.swift`
- `Epistemos/Work/WorkEnginesPanelView.swift` - flat engine/capability/context panel; unavailable roster entries say
  `not wired` instead of making an adapter-timeline promise, and the `EPISTEMOS CONTEXT` section shows the Work-owned
  app-context seam without importing graph/chat/note internals.
- `Epistemos/Work/WorkMarkdownText.swift`
- `Epistemos/Work/WorkNativeMCPHost.swift`
- `Epistemos/Work/WorkNativeMCPServer.swift` - loopback MCP transport/parser hardening; rejects malformed/negative
  declared `Content-Length`, maps over-cap declared bodies to 413, advertises `Allow: POST` for method rejections; socket
  proof is now local, with only the live OpenCode-client handshake still owner-gated.
- `Epistemos/Work/WorkNativeToolExecutor.swift`
- `Epistemos/Work/WorkOpenGUIProvisioner.swift`
- `Epistemos/Work/WorkOpenGUISupervisor.swift` - Swift sidecar supervisor/wire contract; resolves bundled OpenCode/Bun
  across structured and flattened resources; preserves protected `opencode`/`OPENGUI_*` runtime names while surfacing
  Epistemos Work copy for user-visible failures; drains sidecar stderr so diagnostics cannot block stdout NDJSON; rejects
  zero-connected-harness init replies as startup failures.
- `Epistemos/Work/WorkOpenGUIWorkspace.swift`
- `Epistemos/Work/WorkOpenWorkProvisioner.swift`
- `Epistemos/Work/WorkOpenWorkSupervisor.swift` - fallback OpenWork worker supervisor; preserves protected
  `openwork-server`/`OPENWORK_*` contracts while keeping user-facing failures Epistemos Work branded, and continues
  draining worker output after startup so preview-worker logs cannot block the process.
- `Epistemos/Work/WorkPermissionCardView.swift`
- `Epistemos/Work/WorkPermissionRequest.swift`
- `Epistemos/Work/WorkPixelFont.swift`
- `Epistemos/Work/WorkPromptQueue.swift`
- `Epistemos/Work/WorkQuestionCardView.swift`
- `Epistemos/Work/WorkQuestionRequest.swift`
- `Epistemos/Work/WorkQueueListView.swift` - compact queue rows expose send-now, interrupt, after-current-part,
  visible interrupt/steer badges, edit, cancel-steer, reorder, and remove without adding foreground donor branding.
- `Epistemos/Work/WorkRuntimeSupervisor.swift` - loopback runtime supervisor; foreground unavailable copy is Epistemos Work
  branded while `opencode serve` details remain contract/runtime context; continues draining runtime output after startup
  so fallback logs cannot block the process.
- `Epistemos/Work/WorkSPAReskin.swift` - embedded SPA token reskin; forces Epistemos theme colors, monospace, square
  corners, no shadows, block caret, and targeted decorative-gradient removal without globally removing image assets.
- `Epistemos/Work/WorkSPASchemeHandler.swift`
- `Epistemos/Work/WorkSPAServer.swift` - loopback static/SPA bridge; `GET`/`HEAD` serving, bodyless `HEAD` errors,
  method rejection with `Allow: GET, HEAD`, over-cap declared request bodies mapped to 413, bootstrap injection, and
  reskin injection.
- `Epistemos/Work/WorkSession.swift` - Work session ontology plus compact one-line title normalization for native
  recents/rail display.
- `Epistemos/Work/WorkSessionHistoryProjector.swift`
- `Epistemos/Work/WorkSessionMapper.swift` - OpenWork and OpenGUI session-list mapping comments aligned to the current
  native recents path; mapper-returned titles are normalized before reaching the rail.
- `Epistemos/Work/WorkSessionRailView.swift` - session rail supports real attached child-session creation while hiding
  detach/reattach chrome when no real floating-window hook is wired.
- `Epistemos/Work/WorkSessionRegistry.swift`
- `Epistemos/Work/WorkSessionStore.swift` - store comments aligned to live OpenGUI recents plus OpenWork fallback.
- `Epistemos/Work/WorkSkillsProvisioner.swift` - provisions bundled/workspace skills and the active app vault's `skills/`
  into the runtime `.opencode/skills` workspace for the primary OpenGUI path; it now copies only valid skill directories
  containing `SKILL.md` so random vault files or helper folders cannot become OpenCode skills.
- `Epistemos/Work/WorkSlashCommandPopover.swift`
- `Epistemos/Work/WorkSurfaceStyle.swift`
- `Epistemos/Work/WorkToolInputSummary.swift`
- `Epistemos/Work/WorkToolMCPCore.swift` - native tool MCP core; includes `epistemos.context.snapshot` when Work context
  is attached, while preserving the vault/note/graph/computer-use catalog from the app tool tier.
- `Epistemos/Work/WorkWebSurfaceView.swift` - fallback/preview surface keeps app-facing labels (`Epistemos Work surface`)
  while preserving OpenWork loopback/storage contracts below the surface; its side panel now exposes native tool-bridge
  registration status so the fallback cannot silently lose the app-owned tool bridge.
- `Epistemos/Work/WorkWebSurfaceWindowController.swift` - documented as fallback/preview, not the primary Work entry.

New Work test files:

- `EpistemosTests/WorkAppContextSnapshotTests.swift` - source/value guard for the Work-owned context seam, managed skills
  counting, compact panel rows, and rejection of direct graph/chat/note UI-state imports.
- `EpistemosTests/WorkEngineResourcesTests.swift`
- `EpistemosTests/WorkEngineTranscriptTests.swift`
- `EpistemosTests/WorkMarkdownTextTests.swift`
- `EpistemosTests/WorkNativeMCPServerTests.swift` - malformed/negative/over-cap declared `Content-Length` parser
  coverage including 413 framing, MCP `Allow: POST` method-rejection coverage, and end-to-end loopback POST coverage for initialize,
  `tools/call`, `epistemos.context.snapshot`, JSON-RPC notification 202 handling, session id headers, and wrong-bearer
  rejection.
- `EpistemosTests/WorkNativeToolExecutorTests.swift`
- `EpistemosTests/WorkOpenGUISupervisorTests.swift` - NDJSON, event, permission/question, session, bundled PATH/Bun,
  unique-port, native-tool-root, model-selection, zero-connected-harness startup, and no-model open/messages endpoint
  wire guards.
- `EpistemosTests/WorkOpenWorkSupervisorTests.swift`
- `EpistemosTests/WorkPermissionRequestTests.swift`
- `EpistemosTests/WorkPromptQueueTests.swift` - queue model coverage plus Tab-to-queue, Enter-still-submits, and
  after-current-part/edit wiring guards.
- `EpistemosTests/WorkQuestionRequestTests.swift`
- `EpistemosTests/WorkRuntimeSupervisorTests.swift`
- `EpistemosTests/WorkSPAReskinTests.swift`
- `EpistemosTests/WorkSPASchemeHandlerTests.swift`
- `EpistemosTests/WorkSPAServerTests.swift` - loopback `HEAD`, bodyless `HEAD` error, over-cap declared request 413, and
  405 `Allow: GET, HEAD` method-rejection coverage.
- `EpistemosTests/WorkSessionHistoryProjectorTests.swift`
- `EpistemosTests/WorkSessionMapperTests.swift` - includes OpenGUI sidecar title normalization coverage.
- `EpistemosTests/WorkSessionRegistryTests.swift`
- `EpistemosTests/WorkSessionStoreTests.swift`
- `EpistemosTests/WorkSessionTests.swift` - includes compact title normalization coverage.
- `EpistemosTests/WorkSkillsProvisionerTests.swift` - skill copy/idempotency guards, invalid-source filtering, and primary
  native startup ordering.
- `EpistemosTests/WorkSurfaceStyleTests.swift` - Work surface token guards, including native error/stop color checks.
- `EpistemosTests/WorkToolInputSummaryTests.swift`
- `EpistemosTests/WorkToolMCPCoreTests.swift`

OpenGUI research clone additions at donor commit `e25cb97`:

- Official clone delta check: `.research-clones/work/opengui` has no tracked donor-file diffs (`git diff --stat` empty).
  The only clone-local changes are the untracked Epistemos probe/sidecar scripts below; no donor source, config, package,
  API, import, runtime path, or branding file has been renamed in the official clone.
- `.research-clones/work/opengui/epistemos-opengui-spike.mjs`
- `.research-clones/work/opengui/og-connect-probe.mjs`
- `.research-clones/work/opengui/og-create-list-probe.mjs` - no-model sidecar init/create/list proof; now fails fast and
  exits nonzero on sidecar errors or a zero-connected `opencode` init instead of hanging or surfacing a low-level
  undefined-harness error.
- `.research-clones/work/opengui/og-engines-probe.mjs`
- `.research-clones/work/opengui/og-error-recovery-probe.mjs` - no-model command-error recovery proof; a bad harness
  request returns a clean sidecar error and the next valid command on the same NDJSON bridge still succeeds.
- `.research-clones/work/opengui/og-introspect-harness-events-probe.mjs` - no-model event-subscription proof; port-scoped
  cleanup is exec-file based and validates `OPENGUI_OPENCODE_PORT`.
- `.research-clones/work/opengui/og-introspect-service-probe.mjs`
- `.research-clones/work/opengui/og-loadresources-probe.mjs` - no-model provider/agent/command resource proof; port-scoped
  cleanup is exec-file based and validates `OPENGUI_OPENCODE_PORT`.
- `.research-clones/work/opengui/og-open-messages-probe.mjs` - no-model sidecar endpoint proof for
  `sessions.create -> sessions.open -> messages`; validates canonical session reopen/history without model auth and uses a
  port-scoped `OPENGUI_OPENCODE_PORT`.
- `.research-clones/work/opengui/og-messages-fresh-probe.mjs`
- `.research-clones/work/opengui/og-messages-probe.mjs`
- `.research-clones/work/opengui/og-sidecar-drive.mjs`
- `.research-clones/work/opengui/og-sidecar.mjs` - Epistemos-owned sidecar script over official OpenGUI Runtime; NDJSON
  commands are serialized in arrival order, session/resource commands fail clearly when their harness is not connected,
  and port-scoped cleanup is exec-file based with validated `OPENGUI_OPENCODE_PORT`.

Docs:

- `docs/WORK_CANON_STATUS_2026_06_25.md` - this compact canon file.
- `docs/donor-contracts/work-opengui/INDEX.md` - reasoned preserve/rename registry for Work/OpenGUI donor contracts.
- `docs/handoffs/WORK_OPENGUI_MASTER_GOAL_PROMPT_2026_06_25.md` - refreshed restart goal prompt for the full
  Work/OpenGUI loop; includes lane boundary, protected naming law, Tab-to-queue, current blockers, current hardening
  baseline, no-model probe workflow, and anti-breakage closeout cycle.
- `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` - future checklist for richer app-context integration
  once the graph/chat/mini-chat/note deletion/refactor isolation is lifted.
- `docs/handoffs/ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md` - restart goal prompt for the scoped Act/AgentClone
  integration loop.
- `docs/handoffs/ACT_AGENTCLONE_CLONE_DELTA_AUDIT_2026_06_25.md` - read-only delta audit comparing the upstream Agent
  study clone with the local AgentClone package, including counts, expected adapted areas, protected deep names, and
  verification results.
- `docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` - future checklist for reconceptualizing
  MiniChat, Graph Chat, Note Chat, document context, graph context, and native app actions as AgentClone-backed portals
  after the current app-wide deletion/refactor isolation is lifted.
- `docs/handoffs/OWNER_RETURN_CHECKLIST_2026_06_24.md` - owner live proof checklist.
- `docs/handoffs/WORK_OPENWORK_PARITY_LEDGER_2026_06_24.md` - detailed evidence ledger.

## Latest Hardening Cycle - 2026-06-25

- Skills provisioning tightened inside the Work/OpenGUI lane: `WorkSkillsProvisioner.provisionSkills` now requires each
  source entry to be a directory containing `SKILL.md` before copying it into `.opencode/skills`. This preserves the deep
  OpenCode contract while preventing unrelated Epistemos vault files, docs, or helper folders from surfacing as engine
  skills.
- Skill source priority is now Epistemos/user-first: the workspace `skills/` directory is provisioned first, the active
  app vault's `skills/` fills missing names next, and bundled defaults fill only the remaining gaps. Existing
  `.opencode/skills` entries still are not clobbered.
- Guard added in `WorkSkillsProvisionerTests`: a real skill copies, `README.md` does not copy, a folder without
  `SKILL.md` does not copy, `isSkillDirectory` reports the same classification directly, and a workspace skill with the
  same name as an app-vault skill remains the one OpenCode sees.
- OpenGUI sidecar command-queue hardening added: the Epistemos-owned `og-sidecar.mjs` now recovers if the serialized
  command queue ever rejects, so a queue-level failure cannot poison all later Work commands. The command-surface comment
  also now lists lazy `connect`.
- Endpoint surface guard added in `WorkOpenGUISupervisorTests`: Swift and the sidecar are checked for the full Work
  command surface: `init`, `diagnose`, `connect`, `sessions.list`, `sessions.create`, `sessions.open`, `send`,
  `waitIdle`, `abort`, `respondPermission`, `respondQuestion`, `rejectQuestion`, `messages`, `loadResources`, and
  `close`.
- OpenGUI sidecar reply hardening: send, waitIdle, abort, permission/question replies, diagnose, session list, and
  messages now treat `ok:false` replies as surfaced errors instead of accepting them as successful endpoint calls.
- Verification passed: `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift` and scoped
  `git diff --check` over Work/tests/docs/probes both returned clean. `node --check` passed for `og-sidecar.mjs`,
  `og-create-list-probe.mjs`, `og-loadresources-probe.mjs`, `og-introspect-harness-events-probe.mjs`, and
  `og-open-messages-probe.mjs`.
- Fresh no-model endpoint probes passed against the existing Debug app resources at
  `/tmp/EpistemosWorkFocusedDD-20260625-queue-tools/Build/Products/Debug/Epistemos.app/Contents/Resources`:
  create/list on port 48410, `loadResources` on port 48411, harness-event subscription on port 48412, and
  `sessions.create -> sessions.open -> messages` on port 48413. Cleanup check found no lingering probe-owned
  `opencode serve --port 4841[0-3]` or `og-sidecar.mjs` processes.
- Foreground/deep naming scan rerun content-only: no visible Work/App/Settings labels matched donor names such as
  OpenGUI/OpenCode/OpenWork/Goose/Open Work. Reverse unsafe-rename scan found only protected contracts, app-owned
  logger/subsystem ids, Epistemos probe paths, and negative test fixtures; no donor protocol/config/storage name was
  changed to an unsafe Epistemos spelling.
- Flatness/theme scan rerun: the Work route has no positive-radius/shadow hits; visual hits are token-derived surfaces,
  zero-radius strokes, status dots, and real tool/permission/question cards. Rounded Settings rows found by the broader
  scan are outside the Work lane and were not touched.
- Managed OpenGUI/OpenCode port guard added: `WorkOpenGUISupervisor.processEnvironment` now exports
  `OPENGUI_OPENCODE_PORT` only for valid user-space TCP ports (`1025...65535`), and `freeTCPPort()` returns nil if the
  assigned value is outside that range. Tests cover valid, invalid, and privileged values.
- OpenGUI supervisor EOF hardening added: if the sidecar exits before ready, the ready continuation and any pending
  requests now fail immediately with a visible sidecar error instead of waiting for the timeout. If EOF happens while
  running, all pending requests fail immediately and status moves to stopped.
- OpenGUI no-model error-recovery probe added: `og-error-recovery-probe.mjs` intentionally requests `sessions.list` on
  an unconnected `missing-engine`, verifies the sidecar returns `harness not connected: missing-engine`, then immediately
  runs a valid `sessions.list` on `opencode` over the same NDJSON bridge.
- Fallback worker/server lifecycle hardening added: `WorkRuntimeSupervisor` and `WorkOpenWorkSupervisor` now install
  process termination handlers, so a bundled `opencode serve` or `openwork-server` child that exits during startup or
  after reporting ready moves the fallback surface to a visible failed state instead of staying falsely running.
- Work session rail promotion fixed: `WorkSessionStore.promote(id:)` now focuses a promoted mini session after it becomes
  a main tab, so the visible `Promote to tab` action does not leave focus on the old parent session.
- Transcript/tool-card hardening added: if `tool.input.updated` arrives before `tool.started`, the reducer now stores
  only sanitized allowlisted summary candidates and fills the native tool-card summary once the tool name arrives. Raw
  content fields such as write bodies and edit before/after strings are still never retained or rendered.
- Permission-card decoder hardening added: `WorkPermissionRequestDecoder` now rejects permission requests without a
  non-empty `sessionID`, avoiding a visible native permission card that cannot be replied to through the engine's
  `respondPermission` route.
- Question-card answer hardening added: multi-select answers now preserve the displayed option order instead of sending
  unordered `Set` output back to the engine.
- Model-picker label hardening added: single-provider resources stay compact with model-only labels, while multi-provider
  resources include `Provider · Model` labels so identical model names remain distinguishable without changing the
  underlying `providerID/modelID` runtime contract.
- App-context snapshot bound added: future note/graph/selection fields are length-limited when the
  `WorkAppContextSnapshot` is constructed, so the native `epistemos.context.snapshot` MCP payload stays compact after
  post-isolation context deepening.
- SPA fallback resolver hardening added: `WorkSPASchemeHandler.resolve` now resolves symlinks before the final root check,
  so a symlink inside the served SPA root cannot point the loopback fallback server at files outside the root.
- Permission/question card theme pass added: native permission and question cards now use the shared token-derived
  `WorkSurfaceStyle.toolCard` background instead of local black/white opacity fills.
- Native error/stop theme pass added: `WorkEngineSurfaceView` now uses `theme.coral` for runtime error text and the stop
  affordance instead of hardcoded `.red`, with `WorkSurfaceStyleTests` guarding the token usage.
- Foreground legacy-status copy pass added: `WorkBackendGateStatus` and `WorkOpenCodeShellGateStatus` now describe
  isolation as `other app modes` instead of foregrounding stale Chat/Act coupling. `WorkCloneSettingsTests` guards those
  stale phrases out while preserving `EPISTEMOS_WORK_GOOSE_V0` and `EPISTEMOS_WORK_OPENCODE_V0`.
- Loopback endpoint 413 pass added: `WorkMCPHTTPRequest.ParseResult` now has `tooLarge`, native MCP maps over-cap
  declared request bodies to HTTP 413, and the SPA loopback server does the same. Tests cover the shared parser and both
  response framers.
- Session title normalization pass added: `WorkSession.normalizedTitle` collapses whitespace and bounds titles, the native
  send path uses it before creating a session, and both OpenGUI/OpenWork session mappers apply it before rail/recents
  display. Tests cover prompt-derived and sidecar-returned titles.
- Sidecar frame-routing hardening added: `WorkOpenGUISupervisor.decodeFrame` now rejects reply frames without a non-empty
  `id`, session event frames without a non-empty `sessionId` or event JSON, and harness-event frames without event JSON
  instead of inventing blank ids/sessions. `messages(limit:)` now omits invalid limits and caps large limits before they
  cross into the sidecar command boundary.
- Work session registry parent hardening added: mini sessions now require an existing main parent before they enter
  `WorkSessionRegistry`, and registry initialization loads mains before minis so mixed persisted input order still
  restores valid children without allowing orphan rail rows.
- Native MCP transport framing hardening added: duplicate `Content-Length` headers now invalidate the request instead of
  allowing overwrite ambiguity, and MCP JSON/202 responses include `Cache-Control: no-store`.
- SPA loopback response-header hardening added: served HTML and error responses now use `Cache-Control: no-store`,
  static assets keep `no-cache`, and SPA loopback responses include `X-Content-Type-Options: nosniff`.
- SPA custom-scheme resolver hardening added: percent-encoded asset paths are decoded before lookup, encoded traversal is
  still checked against the resolved root, NUL paths are rejected, and custom-scheme responses now mirror the HTML
  `no-store` / asset `no-cache` / `nosniff` header split.
- Shared native MCP registration trust guard added: `WorkNativeMCPRegistration` now defines the non-empty bearer +
  `http` loopback `/mcp` rule, and OpenGUI `opencode.json` merge, OpenWork fallback registration body generation, and
  legacy OpenCode config merge all refuse unsafe native MCP registrations.
- Queue UI flatness pass added: the clear action is now a compact icon with a tooltip, and queue-row icon actions reserve
  stable 18x18 hit areas so minimal controls do not resize or shift while keeping edit/reorder/interrupt/steer/remove
  reachable.
- Session rail flatness pass added: visible rail symbols reserve stable dimensions, long session titles tail-truncate,
  and the new-mini affordance uses a compact fixed hit area while leaving detach/reattach/promote/close reachable.
- Main surface action flatness pass added: header/input icon actions now reserve stable compact hit areas and the send
  action has a tooltip, while new-session/settings/stop/send behavior remains unchanged.
- Permission/question card flatness pass added: ask-card icons/indicators reserve stable dimensions, long option text
  tail-truncates, decision labels stay single-line, and the question skip action is a compact icon with a tooltip.
- Engine resource decoder hardening added: default model ids are retained only when they point at a decoded provider/model
  pair, preventing the native picker from preselecting a stale model the engine did not advertise.
- Focused Xcode retry for `EpistemosTests/WorkOpenGUISupervisorTests` got through the Work-owned compile slice but the
  app target failed outside the Work/OpenGUI lane in `Epistemos/Views/Chat/*` after the concurrent chat deletion/refactor
  sweep. Exact blocker set in
  `/tmp/EpistemosWorkOpenGUI-20260625-ports/Logs/Test/Test-Epistemos-2026.06.25_16-28-05--0500.xcresult`:
  missing `ChatComposerOverlayCommand`, missing `ChatComposerKeyHandling`, changed
  `ComposerReferenceSearchResults` members, and a `ComposerCurrentAccessPlan` call/return mismatch. No Work files failed
  in that run; do not patch those shared Chat files from the Work loop.
- Later focused Xcode retry for the current Work session/native-MCP/SPA/settings slice was intentionally interrupted at
  the owner's request while still compiling dependencies and package targets. It produced no Work pass/fail verdict and
  should not be cited as either.
- Post sidecar frame-routing hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkOpenGUISupervisor.swift EpistemosTests/WorkOpenGUISupervisorTests.swift` and scoped
  `git diff --check` both returned clean.
- Post session-registry parent hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/WorkSession.swift
  Epistemos/Work/WorkSessionRegistry.swift EpistemosTests/WorkSessionRegistryTests.swift` and scoped `git diff --check`
  both returned clean.
- Post native-MCP transport framing static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkNativeMCPServer.swift EpistemosTests/WorkNativeMCPServerTests.swift` and scoped `git diff --check`
  both returned clean.
- Post SPA loopback header hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/WorkSPAServer.swift
  EpistemosTests/WorkSPAServerTests.swift` and scoped `git diff --check` both returned clean.
- Post SPA custom-scheme resolver hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkSPASchemeHandler.swift EpistemosTests/WorkSPASchemeHandlerTests.swift` and scoped
  `git diff --check` both returned clean.
- Post shared native-MCP trust guard static checks passed: `xcrun swiftc -parse Epistemos/Work/WorkOpenCodeRuntime.swift
  Epistemos/Work/WorkOpenGUIProvisioner.swift Epistemos/Work/WorkOpenWorkSupervisor.swift
  Epistemos/Work/WorkNativeMCPServer.swift EpistemosTests/WorkOpenCodeRuntimeTests.swift
  EpistemosTests/WorkOpenGUISupervisorTests.swift EpistemosTests/WorkOpenWorkSupervisorTests.swift` and scoped
  `git diff --check` both returned clean.
- Foreground naming scan rerun after the current hardening cycle: Work chrome/settings copy stays Epistemos-facing;
  donor names found in Work source are real engine picker/runtime identities, protected storage/runtime paths, or
  comments/tests. Broader Settings/App hits are unrelated cloud/provider labels or outside the Work lane.
- Foreground naming scan rerun after the latest UI/runtime patches: Work/Settings/App foreground labels remain
  Epistemos-facing; stale fallback/status phrases appear only inside negative guard assertions, and protected
  `opencode`/`openwork`/`epistemos-native`/`epistemos-vault` hits remain deep runtime/config/test contracts.
- Post queue UI flatness static checks passed: `xcrun swiftc -parse Epistemos/Work/WorkQueueListView.swift
  EpistemosTests/WorkPromptQueueTests.swift` and scoped `git diff --check` both returned clean.
- Post session rail flatness static checks passed: `xcrun swiftc -parse Epistemos/Work/WorkSessionRailView.swift
  EpistemosTests/WorkCloneSettingsTests.swift` and scoped `git diff --check` both returned clean.
- Post main-surface action flatness static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkEngineSurfaceView.swift EpistemosTests/WorkCloneSettingsTests.swift` and scoped `git diff --check`
  both returned clean.
- Post permission/question card flatness static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkPermissionCardView.swift Epistemos/Work/WorkQuestionCardView.swift
  EpistemosTests/WorkPermissionRequestTests.swift EpistemosTests/WorkQuestionRequestTests.swift` and scoped
  `git diff --check` both returned clean.
- Post engine resource decoder hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkEngineResources.swift EpistemosTests/WorkEngineResourcesTests.swift` and scoped `git diff --check`
  both returned clean.
- Engine resource decoder identity hardening: provider/model/agent/command ids and names are trimmed and blank
  provider/agent/command identities are rejected before they reach pickers or slash-command rows. Models keep the donor
  record-key fallback when a display name/id is missing.
- Post transcript/history replay hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkEngineTranscript.swift Epistemos/Work/WorkSessionHistoryProjector.swift
  EpistemosTests/WorkEngineTranscriptTests.swift EpistemosTests/WorkSessionHistoryProjectorTests.swift`, scoped
  `git diff --check`, and a source scan for the new route/bounds guards all returned clean.
- Post slash-command popover hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkSlashCommandPopover.swift EpistemosTests/WorkCloneSettingsTests.swift`, scoped `git diff --check`,
  and source guard scans for bounded scrolling/truncation all returned clean.
- Post engines/context panel hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkEnginesPanelView.swift EpistemosTests/WorkCloneSettingsTests.swift`, scoped `git diff --check`, and
  source guard scans for stable row sizing/fixed badges/path truncation all returned clean.
- Post MCP-core endpoint hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkToolMCPCore.swift EpistemosTests/WorkToolMCPCoreTests.swift`, scoped `git diff --check`, and source
  scans for blank tool-name rejection plus context descriptor idempotence all returned clean.
- Post native-MCP user-space port trust hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkOpenCodeRuntime.swift Epistemos/Work/WorkOpenGUIProvisioner.swift
  Epistemos/Work/WorkOpenWorkSupervisor.swift EpistemosTests/WorkOpenCodeRuntimeTests.swift
  EpistemosTests/WorkOpenGUISupervisorTests.swift EpistemosTests/WorkOpenWorkSupervisorTests.swift`, scoped
  `git diff --check`, and source scans for the port-range guard/rejection cases all returned clean.
- Post session-registry structural hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkSession.swift Epistemos/Work/WorkSessionRegistry.swift
  EpistemosTests/WorkSessionRegistryTests.swift`, scoped `git diff --check`, and source scans for the kind/parent
  upsert guards all returned clean.
- Post permission/question event hygiene static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkQuestionRequest.swift Epistemos/Work/WorkOpenGUISupervisor.swift
  EpistemosTests/WorkQuestionRequestTests.swift EpistemosTests/WorkOpenGUISupervisorTests.swift`, scoped
  `git diff --check`, and source scans for non-empty question/clear session ids all returned clean.
- Post fallback-details panel hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkWebSurfaceView.swift EpistemosTests/WorkCloneSettingsTests.swift`, scoped `git diff --check`, and
  source scans for details scrolling plus middle truncation all returned clean.
- Post queue send-failure preservation static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkPromptQueue.swift Epistemos/Work/WorkEngineSurfaceView.swift
  EpistemosTests/WorkPromptQueueTests.swift`, scoped `git diff --check`, and source scans for queued prompt requeue plus
  variant preservation all returned clean.
- Post sidecar `ok:false` reply hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkOpenGUISupervisor.swift EpistemosTests/WorkOpenGUISupervisorTests.swift`, scoped
  `git diff --check`, and source scans for `requireOK` coverage all returned clean.
- Post engine-resource identity hardening static checks passed: `xcrun swiftc -parse
  Epistemos/Work/WorkEngineResources.swift EpistemosTests/WorkEngineResourcesTests.swift`, scoped `git diff --check`,
  and source scans for trimmed non-empty resource identity handling all returned clean.
- Post EOF-hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift`,
  scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Fresh no-model error-recovery probe passed against the existing Debug app resources at
  `/tmp/EpistemosWorkFocusedDD-20260625-queue-tools/Build/Products/Debug/Epistemos.app/Contents/Resources` on port
  48420; cleanup check found no lingering `opencode serve --port 48420` or `og-sidecar.mjs` process.
- Post fallback lifecycle hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post session-rail promotion static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post transcript/tool-card hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post permission-card decoder hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post question-card answer-order hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post model-picker label hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post app-context snapshot bound static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post SPA symlink traversal hardening static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post permission/question card theme pass static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, and touched-file trailing-whitespace scan all returned clean.
- Post native error/stop theme, neutral app-mode copy, and loopback 413 static checks passed: `xcrun swiftc -parse
  Epistemos/Work/*.swift EpistemosTests/Work*.swift`, `node --check` for the Epistemos-owned sidecar/probe scripts,
  scoped `git diff --check`, touched-file trailing-whitespace scan, and a hardcoded red/stale-status scan all returned
  clean except for intentional negative guard assertions.
- Post session-title normalization static checks passed: `xcrun swiftc -parse Epistemos/Work/*.swift
  EpistemosTests/Work*.swift`, scoped `git diff --check`, touched-file trailing-whitespace scan, and stale raw-title
  source scan all returned clean.
- Raw trailing-whitespace scan over the full donor clone reports pre-existing tracked upstream OpenGUI docs/font license
  lines. No donor tracked files were edited; the clean scoped `git diff --check` is the relevant new-change guard.

## Stop Point - 2026-06-25

- Clean stopping point reached for the Work/OpenGUI lane. No Work/OpenGUI command, edit, or verification is in flight.
- Final in-lane patch before stopping: `WorkRuntimeSupervisor.parseListeningURL` and
  `WorkOpenWorkSupervisor.parseListeningURL` now fail closed unless child process output reports an HTTP loopback base URL
  on an explicit user-space port; the OpenWork preview helper additionally requires the expected worker port and
  normalizes the WebView-facing URL to `localhost`.
- Latest scoped checks passed:
  `xcrun swiftc -parse Epistemos/Work/WorkRuntimeSupervisor.swift Epistemos/Work/WorkOpenWorkSupervisor.swift
  EpistemosTests/WorkRuntimeSupervisorTests.swift EpistemosTests/WorkOpenWorkSupervisorTests.swift`,
  scoped `git diff --check`, and touched-file trailing-whitespace scan.
- Final narrow foreground naming scan over Work, Work Settings, app coordinator/status bar, and string catalogs had no
  actionable foreground donor-name leak. Hits were comments/internal source identifiers only.
- Official OpenGUI donor clone tracked diff remains clean. The only `.research-clones/work/opengui` status entries are
  Epistemos-owned untracked sidecar/probe scripts (`og-*.mjs`, `epistemos-opengui-spike.mjs`).
- Handoff for the next directive:
  `docs/handoffs/WORK_OPENGUI_STOPPING_POINT_HANDOFF_2026_06_25.md`.

## Remaining Gates

- Owner-only live proof: rebuild/run with Command-R, open Settings -> Advanced -> Epistemos Work -> Open Epistemos Work,
  render the surface, send/stream with real model auth, and verify permission/question cards when gated.
- Permission `ask` flip: only after the live card proof shows card rendering and response wiring.
- OpenWork fallback removal: only after the live OpenGUI/OpenCode proof passes.
- Post-isolation app context deepening: only after the owner explicitly allows Work or Act to touch the rebuilt
  graph/chat/note app seams; follow `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` for Work and
  `docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` for Act/AgentClone.
- Act/AgentClone current lane proof: `LocalPackages/AgentClone` builds and now has 6 no-model bridge/context tests; the
  donor-contract package passes 69 tests; foreground AgentClone quoted-literal scans are clean over `Views`,
  `DependencyChecker`, and `AgentApp.swift`; and the reverse guard proves protected deep contracts were not over-renamed.
  Bridge prompts now use AgentClone's normal `run()` / `runTabTask(tab:)` paths so busy app-entrypoint prompts queue
  through the clone; pre-mount app-entrypoint prompts now drain from the AgentClone pending buffer on `ContentView` appear;
  pre-mount host context is applied on `ContentView` appear; the Epistemos context summary includes both vault and
  workspace when both are present while preserving vault-first project-folder rooting; and clone JSONL session transcripts
  now have an Epistemos-owned active path with donor-session fallback. The post-isolation plan now tracks
  MiniChat, Graph Chat, Note Chat, document context, graph
  context, and native app actions as future AgentClone-backed portals. The targeted app Xcode guard is blocked before
  execution by outside-lane deletion/refactor failures, currently including generated app target file-list entries for
  deleted old-chat files `Epistemos/Views/Chat/AnswerPacketBadge.swift` and
  `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`, so that cleanup stays outside the Act lane until reassigned or cleared.
- Deferred/non-clean: live-diff threading, transcript rebasing, owner-scoped worktree diffs, floating/detached mini-session
  windows, and Goose adapter.
