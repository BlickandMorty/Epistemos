# Work/OpenGUI Post-Isolation Deepening Plan - 2026-06-25

Purpose: this is the checklist for the next Work/OpenGUI deep-integration loop after the owner says the app-wide
deletion/refactor isolation is over. Until then, do not touch graph, chat, mini-chat, note chat, or note-editor
internals from the Work lane.

## Current Safe Boundary

- Work/OpenGUI can continue evolving inside `Epistemos/Work`, `EpistemosTests/Work*.swift`, Work docs, and the
  Epistemos-owned OpenGUI probe scripts.
- Visible copy should stay Epistemos-branded, while donor runtime contracts stay named as they are: OpenGUI, OpenCode,
  OpenWork, Goose, `opencode`, `openwork`, `opencode.json`, `.opencode`, MCP ids, storage ids, env vars, and protocol
  strings.
- The primary native Work route already roots tools and skills at the active Epistemos vault when one is available:
  native MCP uses the vault root, `epistemos-vault` stdio fusion uses the vault root, and `.opencode/skills` receives
  bundled, workspace, and app-vault skills. Provisioning is filtered to directories containing `SKILL.md`, so broad vault
  context does not accidentally expose unrelated files as OpenCode skills. Source priority is workspace first,
  app-vault second, bundled defaults last.
- A Work-owned context seam now exists: `WorkAppContextSnapshot`. It is deliberately plain data only: workspace path,
  vault path, native-tool registration, app mode, selected engine/model/agent, active Work session id, queue depth,
  managed skills count, and future optional note/graph/selection fields. It is visible in the native engines panel as
  `EPISTEMOS CONTEXT` without importing graph/chat/note UI types.
- The same snapshot is exposed to OpenCode through the app-owned native MCP tool `epistemos.context.snapshot`. This is
  the current safe model-facing context path; future graph/chat/note deepening should enrich the snapshot rather than
  creating a second prompt-only context channel.
- Future note/graph/selection fields on `WorkAppContextSnapshot` are already bounded at construction time, so post-
  isolation providers should pass concise summaries and rely on the seam to keep the MCP payload compact.
- Current full Xcode tests can fail outside the Work lane while graph/chat/note surfaces are being deleted or rewritten.
  Treat those as external blockers unless the failing file is under `Epistemos/Work` or `EpistemosTests/Work*.swift`.
- Current observed shared-chat blockers include `Epistemos/Views/Chat/*` compile errors for missing
  `ChatComposerOverlayCommand`, missing `ChatComposerKeyHandling`, changed `ComposerReferenceSearchResults` members, and
  a `ComposerCurrentAccessPlan` call/return mismatch. Earlier blockers included `Epistemos/State/AgentChatState.swift`
  references to `DisplayPacedTextBuffer` and `StreamingReasoningTraceBuffer`, plus `AppBootstrap.chatState` removal. These
  are not Work/OpenGUI fixes; keep them in the post-isolation/shared-app lane unless the owner explicitly reassigns them.

## Do Not Do During Isolation

- Do not restore `AppBootstrap.chatState`, `AgentChatState`, Chat sidebar, Graph state, note chat, mini-chat, or note
  editor types from Work just to make a build pass.
- Do not add compatibility shims in app/root/landing files for removed surfaces.
- Do not rename deep donor/runtime identifiers to Epistemos if OpenCode/OpenGUI/OpenWork/Goose expects those names.
- Do not remove Work controls to make the UI flatter. Hide secondary controls behind native panels/toggles only when the
  control remains reachable and guarded.

## Clone Research Baseline

These are the local OpenGUI/OpenCode seams Work can safely build around:

- Session lifecycle: `sessions.list`, `sessions.create`, `sessions.open`, canonical `harness:raw` session ids, and
  `messages` history. This is the right base for Work recents, child sessions, later mini-chat handoff, and session
  restore. Current no-model proof covers `sessions.create -> sessions.open -> messages` through the NDJSON sidecar.
- Turn control: `send`, `waitIdle`, and `abort`. This is the right base for Enter-send, Tab-to-queue, after-current-part,
  stop, and future app-orchestrated turns.
- Command dispatch: the NDJSON sidecar serializes commands and now recovers from queue-level rejection, so later Work
  commands can continue after a failed command path instead of leaving the bridge poisoned.
- Command-error recovery: no-model proof now covers a bad harness request followed by a valid `sessions.list` on the same
  sidecar process, so future note/graph/mini-chat commands can rely on explicit errors rather than bridge poisoning.
- Runtime resources: `loadResources` returns providers, models, agents, and commands. This is the right base for visible
  engine/model/agent controls and slash-command parity.
- Permission and question events: harness-level `permission.*` and `question.*` events are forwardable to native cards.
  This is the right base for future gated note/graph/file actions.
- Tool bridge: `epistemos-vault` stdio MCP gives vault resources/skills, while `epistemos-native` loopback MCP executes
  app-owned native tools including note/vault/graph/computer-use categories when the backing app APIs exist.
- Context bridge: `epistemos.context.snapshot` is the first read-only native context tool. It currently returns workspace,
  vault, app mode, selected engine/model/agent, active Work session, queue depth, native-tool state, and skill count; later
  graph/chat/note summaries should join this same payload.
- UI shape: OpenGUI is already simple enough that Work should keep controls reachable in a flat native shell instead of
  deleting functionality. The appification layer should be native chrome, theme tokens, context panel, and honest errors.

## Reconceptualization Targets

- Main Work chat: keep it as the primary OpenGUI/OpenCode session surface. It should own model/agent selection, queue,
  permission/question cards, recents, transcript, and native tool status.
- Mini-chat: reconceptualize as child Work sessions, not a separate chat engine. A mini-chat should be an attached
  `WorkSession.mini` tied to a parent `harness:raw` id, with optional floating chrome only after a real window hook is
  stable. It should inherit the parent context snapshot and have its own queue/history.
- Graph chat: reconceptualize as graph context and graph actions inside `epistemos-native`, not a separate prompt lane.
  The first layer should be read-only: graph focus, selected node, nearby nodes, edges, and a bounded summary. Mutation
  actions such as connect/tag/rewrite should require permission cards and owner API proof.
- Note chat: reconceptualize as current-note context plus note actions in the same Work session. The first layer should
  expose note title/path/id, selected text, visible excerpt, and backlinks/tags through the context snapshot. Editing
  actions should route through the real note owner API, not raw file writes, unless the note is explicitly vault-file
  backed and permissions allow it.
- App-wide chat handoff: reconceptualize as sending selected context into a Work session or creating a Work child session,
  not reviving deleted Chat/Act compatibility routes from Work. The app surface can provide a prompt/context bundle once
  its new route is stable.
- Vault/project context: keep the current split. Shell/file operations use the managed Work workspace; native tools and
  MCP resources root at the active Epistemos vault. This prevents OpenCode from treating the whole home directory as the
  project while still letting the agent see notes and skills.
- Skills: keep `.opencode/skills` as the OpenCode contract. App skills should be copied/provisioned into that path from
  bundled, workspace, and app-vault sources; do not rename it to `.epistemos/skills`. Only real skill directories with
  `SKILL.md` should be mirrored, and user/workspace skill names should win over bundled defaults.

## Priority Backlog

### Can Continue Inside Work/OpenGUI Now

- Keep hardening native Work controls: queue, after-current-part, edit, recents, permission/question cards, model/agent
  picker, slash commands, context panel, native MCP status, and honest transcript errors.
- Expand no-model probes around the existing sidecar commands: create/list/open/messages/loadResources, harness event
  forwarding, and permission/question route shape.
- Expand `epistemos.context.snapshot` only with values Work can own today. Current Work-owned values already include
  workspace, vault, native tool state, skills count, selected engine/model/agent, active Work session id, and queue state.
- Keep documenting foreground/deep naming decisions whenever a visible label or protected runtime name changes.

### Current Clone-Side Proofs To Build On

- Recents/session restore: `sessions.create`, `sessions.list`, `sessions.open`, and `messages` are now proven through the
  same NDJSON sidecar used by Swift, without model auth. This should be the base for Work recents, child Work sessions,
  and future mini-chat handoff.
- Picker resources: `loadResources` is proven against the bundled app resources and returns provider, model, agent, and
  command data. Deeper app integration should enrich or filter this panel rather than replacing it with a separate picker.
- Permission/question route: harness events are proven to subscribe at `harness.on("event")`; the dead
  `subscribeHarnessEvents` path should stay avoided. Future note/graph mutations should use this permission route instead
  of building a second confirmation system.
- Context route: `epistemos.context.snapshot` is proven in the native MCP core and loopback server. Future app context
  should enrich this one read-only tool first, then add narrower context tools only if the payload becomes too broad.
- Transcript route: live and reopened OpenGUI/OpenCode output is now projected into native Work parts with route guards
  and bounded text/diffs. Future note/graph/native-action outputs should reuse this transcript path rather than adding a
  second renderer or dumping raw JSON/logs into assistant prose.
- Runtime URL trust route: the native/fallback Work supervisors now accept child-process listening lines only when they
  describe HTTP loopback base URLs with explicit user-space ports. Future app-context servers and owner APIs should reuse
  that fail-closed shape instead of trusting arbitrary printed URLs.

### Wait For Rebuilt App Seams

- Current note/page context: needs the rebuilt note owner API for active page id, title, visible excerpt, selected text,
  and write/rewrite operations.
- Graph context: needs the rebuilt graph owner API for selected node, route, neighborhood, edge summaries, and graph
  mutation actions.
- Main chat/mini-chat handoff: needs the rebuilt app route for sending a selected prompt/context bundle into Work or
  creating a child Work session without reviving deleted compatibility routes.
- Note chat: needs the rebuilt note/chat contract; should become current-note context plus approved note actions in Work,
  not a second parallel engine.

### Proof Required Before Each Deepening Lands

- Source proof: the Work file imports stay inside `Epistemos/Work` boundaries and do not import deleted UI state.
- Static proof: parse, diff, whitespace, foreground/deep naming scan, and targeted source guards.
- No-model proof: native MCP `tools/list`/`tools/call`, sidecar create/list/open/messages/loadResources, and permission
  or question route shape.
- Owner proof: real model send/stream with auth, a context read, one note/vault action, one permission-card action, and
  transcript-visible failure behavior.

## Post-Isolation Deepening Sequence

1. Define a stable app-context seam.
   Extend the existing `WorkAppContextSnapshot` with a small Work-facing provider, ideally a protocol consumed by Work
   rather than direct references to app globals. The provider should return bounded values and avoid importing
   deleted/refactored UI types into the OpenGUI runtime layer.

2. Populate the context snapshot from live app state.
   When those surfaces exist again, include active vault path, selected project/workspace, active note/page id and title,
   current editor selection or visible excerpt, graph route/neighborhood summary, current app mode, recent Work sessions,
   and any user-selected model/tool policy. Keep the payload compact, redacted, and deterministic.

3. Expose context to OpenCode through app-owned MCP/resources.
   Build on the existing `epistemos.context.snapshot` tool first. Add narrower tools/resources only when useful, such as
   `epistemos.context.current_note`, `epistemos.context.graph_neighborhood`, and `epistemos.context.workspace`. Preserve
   existing `epistemos-vault` and `.opencode/skills` paths; do not replace the working fusion path.

4. Add app actions only after the owning surface is stable.
   Wire `note.create`, `note.edit`, selected-text rewrite, graph search/connect, mini-session handoff, and chat handoff
   through real owner APIs. Each action needs permission behavior, honest error reporting, and a no-model unit test before
   a real-model proof.

5. Add a compact native context panel.
   The first context panel now exists in `WorkEnginesPanelView`. Deepen it after isolation with active note, graph focus,
   selected text, current project, selected model/agent, native MCP status, and skills count. This panel should be flat
   and token-driven, not a new landing page or decorative dashboard.

6. Verify with three proof tiers.
   First, parse/source/foreground-name guards. Second, no-model loopback probes for native MCP, sidecar create/list,
   resources, and context tools. Third, owner-run real-model proof: send/stream, ask permission card, call a note/vault
   tool, call a graph/context tool, and confirm the transcript shows native errors instead of silent failures.

7. Remove fallback only after proof.
   The OpenWork WebView preview can be removed only after the native OpenGUI/OpenCode route has visual proof, real model
   send/stream proof, app-context tool proof, and permission/question card proof.

## Acceptance Checklist

- Work can answer "what app context do you have?" with the active Epistemos vault, current workspace, current note/page
  summary, graph focus summary, and available native tools.
- A real OpenCode turn can call an Epistemos vault/note tool and the result affects the real app data through approved
  APIs, not a detached scratch directory.
- A real OpenCode turn can read bounded graph/current-note context without importing or reviving deleted UI surfaces.
- A foreground/deep naming scan shows Epistemos on visible Work surfaces and donor names only in protected contracts.
- `xcrun swiftc -parse Epistemos/Work/*.swift EpistemosTests/Work*.swift`, scoped `git diff --check`, sidecar syntax
  checks, no-model probes, and owner live proof all pass before the fallback is removed.
