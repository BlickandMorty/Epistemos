# OpenWork / OpenChamber Code Study Handoff — 2026-06-24

Purpose: preserve the source-grounded research for Claude or another agent. This note answers the owner question: should Epistemos clone OpenWork, OpenChamber, both, or neither for Work/OpenCode GUI hardening?

## Owner Intent

The owner wants Work to be deeply integrated into Epistemos, not a second pasted app. OpenCode should remain the hidden Work engine/TUI/backend where useful, but Epistemos should own the app ontology: recent chats, settings, permissions, vault/skills/MCP exposure, mini chat, graph chat, note boundaries, and native/pixel-flat presentation.

The important correction: "do not clone" was too blunt. The better rule is:

- Clone/vendor the donor source and study/carry the full capability architecture so no features are missed.
- Do not blindly transplant the donor UI as the final app ontology.
- Epistemos owns the visible product surface; donor code supplies complete behavior, persistence models, lifecycle patterns, and interaction contracts.

The past failure mode came from under-cloning: agents copied only a few visible pieces, then MCP persistence, skills, permissions, streaming, and session behavior fell through the cracks. For Work, the safer path is full-source clone/audit first, then deliberate Epistemos-native integration.

## Repos Studied

Temporary local clones:

- OpenWork: `/tmp/epistemos-opencode-donor-audit/openwork`
  - Remote: `https://github.com/different-ai/openwork.git`
  - Shallow HEAD studied: `dcc94b9`
- OpenChamber: `/tmp/epistemos-opencode-donor-audit/openchamber`
  - Remote: `https://github.com/openchamber/openchamber.git`
  - Shallow HEAD studied: `5494353`

Licensing:

- OpenWork root is MIT outside `/ee`; `/ee` is Functional Source License / Fair Source. Avoid `/ee` for Epistemos product code unless explicitly reviewed.
- OpenChamber is MIT.

## Recommendation

Best path:

1. Harden hidden OpenCode first.
2. Clone/vendor OpenWork as the primary Work capability donor.
3. Rebuild/render Work through Epistemos UI/WebKit/pixel-flat/native settings instead of treating OpenWork UI as final.
4. Mine OpenChamber second for mini-chat/session/streaming/runtime UX hardening.
5. Keep official OpenCode as behavior/API source of truth.

OpenWork should lead because the current pain is backend integration: MCP installs not persisting, skills/vault not discoverable, permissions/config not app-owned, and Work not feeling attached to Epistemos.

OpenChamber still has things Epistemos needs. It should not lead the architecture, but it is a strong parts donor for session-aware GUI behavior, mini chat, streaming, fetch coalescing, and startup health.

## Why Clone At All

Cloning is good when it means preserving the complete donor source, license, commit, tests, and behavior map. It prevents the agent from reimplementing only the obvious UI and missing hidden surfaces.

The instruction should be:

> Full-source clone for audit and capability parity; Epistemos-native re-ontology for product integration.

Bad cloning:

- Paste donor UI wholesale and call it Epistemos.
- Keep separate donor settings/recent chats/session model.
- Keep donor permissions/popovers detached from native Epistemos approvals.
- Ship `/ee` OpenWork code without license review.

Good cloning:

- Vendor source with commit/license evidence.
- Build a feature ledger from donor code.
- Port all relevant capabilities into Epistemos-owned state/settings/UI.
- Keep donor runtime hidden where appropriate.
- Use tests/screenshots to prove no donor capability was dropped.

## OpenWork Findings

OpenWork is the stronger first donor for persistence and OpenCode hardening.

Key files studied:

- `/tmp/epistemos-opencode-donor-audit/openwork/apps/server/src/runtime-opencode-config-store.ts`
  - Defines `RuntimeOpencodeConfig` with `default_agent`, `plugin`, `disabled_providers`, `mcp`, `permission.external_directory`, and `provider`.
  - Stores runtime OpenCode config per workspace in SQLite table `runtime_opencode_configs`.
  - Merges app-owned runtime config into persisted OpenCode config.
  - This maps directly to Epistemos needing app-owned MCP/plugins/providers/permissions that survive reopen.
- `/tmp/epistemos-opencode-donor-audit/openwork/apps/server/src/mcp.ts`
  - Lists global, project, and OpenWork-owned runtime MCPs.
  - Adds/removes/toggles MCP entries through runtime config.
  - Important for the owner's bug: "it says it installed an MCP, but after reopen I cannot use it."
- `/tmp/epistemos-opencode-donor-audit/openwork/apps/server/src/skills.ts`
  - Scans project `.opencode/skills`, project `.claude/skills`, global `~/.config/opencode/skills`, `~/.claude/skills`, `~/.agents/skills`, and `~/.agent/skills`.
  - Handles flat and grouped skill folders.
  - Supports create/update/delete of project skills.
  - This is directly relevant to Epistemos skills/vault discoverability.
- `/tmp/epistemos-opencode-donor-audit/openwork/apps/server/src/plugins.ts`
  - Lists config plugins, project/global plugin files, and runtime-added plugins.
  - Adds/removes plugin specs through runtime config.
- `/tmp/epistemos-opencode-donor-audit/openwork/apps/server/src/managed-opencode.ts`
  - Spawns `opencode serve` on loopback.
  - Generates random username/password env.
  - Waits for server startup and redacts secret env in execution snapshots.
  - Good lifecycle pattern; harden CORS/auth before use.
- `/tmp/epistemos-opencode-donor-audit/openwork/apps/app/src/react-app/domains/settings/pages/mcp-view.tsx`
  - Rich MCP/skill/plugin settings view.
  - Useful as a capability checklist, not final UI.
- `/tmp/epistemos-opencode-donor-audit/openwork/packages/openwork-ui-mcp/index.mjs`
  - OpenWork exposes its own UI through an MCP bridge. Interesting pattern for Epistemos UI controllability, but Electron-specific.

OpenWork root scripts show hardening tests for health, sessions, events, permissions, session error recovery, session scope, session switch, fs engine, and e2e. That is a positive signal for backend reliability.

OpenWork risk:

- It is a large monorepo with Electron, cloud/Den pieces, and `/ee` Fair Source code.
- Use it as a capability architecture clone and backend hardening donor, not a blind UI paste.

## OpenChamber Findings

OpenChamber is the stronger second donor for visible Work GUI behavior and session robustness.

Key files studied:

- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/lib/opencode/client.ts`
  - Uses official `@opencode-ai/sdk/v2`.
  - Maintains scoped clients by directory.
  - Has in-flight maps and caches for directory/config/provider/agent reads.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/lib/runtime-fetch.ts`
  - Rewrites `/api`, `/auth`, `/health` to active runtime URL.
  - Attaches runtime auth headers.
  - Sanitizes non-Latin-1 headers for browser fetch.
  - Coalesces identical concurrent GET reads so OpenCode does the work once during startup.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/sync/bootstrap.ts`
  - Global and per-directory bootstrap.
  - Phase 1 fetches only critical data so UI can render.
  - Phase 2 fetches commands, MCP status, LSP status, VCS, questions, permissions after first paint.
  - Avoids "loading forever" from one transient fetch failure.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/sync/session-actions.ts`
  - Robust session actions.
  - Waits briefly for connection recovery before failing send.
  - Resolves the correct directory for session replies and blocking permission/question requests.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/sync/streaming.ts`
  - Derives streaming state from session status and messages.
  - Scans only busy sessions.
  - Throttles stream heartbeat updates to 1Hz to avoid high-frequency store churn.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/stores/permissionStore.ts`
  - Persists per-session auto-accept settings.
  - Handles inherited session scope.
  - Mirrors auto-accept to the server to suppress permission notifications before client round-trip.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/stores/useMcpStore.ts`
  - MCP status/connect/disconnect/auth/test flows using the OpenCode SDK.
  - Good UX/runtime state donor.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/stores/useSkillsStore.ts`
  - Skills list/detail/create/update/delete client state.
  - Per-directory caching and in-flight dedup.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/apps/ElectronMiniChatApp.tsx`
  - Mini chat bootstraps a target session or draft.
  - Can switch an existing mini-chat window to another session in place.
  - Publishes presence via BroadcastChannel.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/ui/src/components/mini-chat/MiniChatLayout.tsx`
  - Mini chat header computes title, project, worktree branch, context usage, and open-main action.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/electron/main.mjs`
  - Mini-chat URL/session-window keying.
  - Prevents duplicate mini-chat windows for the same session/runtime.
  - Supports focus-main-window and switching a mini-chat surface to a selected session.
- `/tmp/epistemos-opencode-donor-audit/openchamber/packages/web/server/lib/opencode/lifecycle.js`
  - Managed OpenCode lifecycle with startup diagnostics.
  - Health restart logic skips restart while sessions are busy, but forces restart if busy state stays unhealthy for over two minutes.

OpenChamber risk:

- Electron/Bun/node-pty/browser stack is heavy.
- Its UI should not become the Epistemos ontology.
- Some desktop choices are not suitable as-is for a hardened native app, for example Electron mini-chat uses `sandbox: false`.

OpenChamber value:

- It has the exact session/mini-chat/runtime UX patterns Epistemos needs after backend persistence is solid.
- It is not optional if the goal is a robust GUI Work mode; it just should not be the architectural base.

## Concrete Build Direction For Claude

Treat the near-term Work project as three ledgers:

1. OpenCode hardening ledger
   - Process lifecycle.
   - Loopback auth.
   - PATH/env repair.
   - CWD/workspace selection.
   - Health probes/restart policy.
   - Recent sessions.
   - Epistemos vault/context exposure.

2. OpenWork capability parity ledger
   - Runtime OpenCode config DB or Epistemos equivalent.
   - MCP list/add/remove/toggle persisted by workspace.
   - Skills discovery from project, app vault, and global locations.
   - Plugin/provider/default-agent persistence.
   - Permissions/external directory config.
   - Native Epistemos settings tab for Work.

3. OpenChamber GUI robustness ledger
   - Runtime fetch bridge/coalescing.
   - Phased bootstrap.
   - Directory-scoped SDK clients.
   - Send/reconnect grace.
   - Streaming state throttling.
   - Permission/question routing.
   - Mini-chat same-session switching.
   - Session/window/recent-chat focus behavior.

Final product target:

- Work can be hidden terminal/TUI where appropriate, but Epistemos owns the visible chrome and state.
- Main chat, mini chat, and graph chat can access Work; note chat remains Act-only unless owner changes that.
- Recents are Epistemos recents, not donor recents.
- Settings are Epistemos settings with a Work tab that covers the real donor capabilities.
- Permissions become native Epistemos approval flows where possible.
- WebKit is acceptable for faster GUI iteration, but it should be an Epistemos shell around Work capability, not a pasted donor app.

## Short Answer

Yes: clone OpenWork after hardening hidden OpenCode. That is a good path if "clone" means full-source capability parity and not blind UI transplant.

No: Chamber is not useless. It contains important robustness patterns that OpenWork does not cover as strongly, especially mini-chat/session switching, streaming, phased bootstrap, and runtime fetch behavior.

Best order:

1. Harden OpenCode.
2. Full-source clone/vendor OpenWork and port its capability architecture.
3. Rebuild Work UI in Epistemos style/WebKit/native shell.
4. Fuse selected OpenChamber behavior where it improves robustness and UX.

