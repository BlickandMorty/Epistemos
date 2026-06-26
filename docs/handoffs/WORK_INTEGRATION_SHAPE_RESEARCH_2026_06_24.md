# Work Integration Shape Research - 2026-06-24

This is research canon, not an implementation plan.

Question: for the OpenWork/OpenChamber/Agents Work surface, should Epistemos
vendor the donor app into the product tree, run it as an external process, wrap
it in WebKit, or port it natively?

Owner correction: Work is not expected to be Mac App Store distributed. Act may
still need MAS-friendly architecture, but Work can optimize more heavily for
usefulness, real features, and fast iteration while preserving as much native
feel as possible.

## Short Answer

Best current shape:

> Epistemos native shell + controlled Work runtime process + WKWebView Work
> surface + native bridge/permissions/settings/recents/model picker.

Do not pure-Swift-port OpenWork/OpenChamber now. Do not ship raw Electron as the
final Work UI. Do not dump donor source wholesale into the main Xcode tree as
product code before pruning/license gates.

Keep full donor clones for study under `.research-clones/`. For product work,
build a curated Work runtime bundle from the donor, signed/notarized for direct
distribution, and mount its UI through Epistemos-owned native chrome.

## Why This Is The Best Trade-Off

The owner wants two things that fight each other:

- native-feeling Epistemos UI,
- full donor usefulness without losing hidden surfaces.

A pure native Swift port maximizes native feel but recreates the old failure
mode: agents miss donor features because the donor topology is not visible.

A raw Electron/full donor app maximizes feature preservation but creates a
second app inside Epistemos: donor chrome, donor settings, donor recents, donor
permission semantics, and weaker native feel.

The hybrid shape preserves both:

- Swift owns the app ontology: landing/search, blur/typewriter transition,
  recents, model picker, permissions, settings, vault selection, mini sessions,
  window chrome, and session identity.
- WebKit owns the high-churn Work surface where donor React/web code is already
  strongest: transcripts, panes, diffs, worktrees, streaming cards, tool
  visualizations, file views, and future multi-agent surfaces.
- A controlled local runtime owns the agent/server work: OpenCode/OpenWork/OMP
  execution, MCP, skills, plugins, sessions, persistent DB, tool state, and
  websocket/SSE streams.

## Apple / Runtime Evidence

Apple's WebKit architecture is already process-separated: `WKProcessPool`
documents that WebKit renders web views in separate processes rather than in
the app process. That helps isolate crashes and memory pressure compared with
embedding a whole Electron app as the outer shell.

Apple's `WKURLSchemeHandler` supports custom resource schemes for web content.
That is useful if Epistemos wants to serve static Work assets from the app
bundle without a localhost static server.

Apple's XPC documentation frames XPC services as useful for stability and
privilege separation. It also notes that XPC services are managed by `launchd`,
launched on demand, can restart after crashes, and can be sandboxed separately.
That is the right long-term native boundary if a Work helper becomes
security-sensitive.

For direct macOS distribution, Apple's notarization documentation still matters:
hardened runtime and helper signing/notarization should be treated as product
requirements even when Work is not MAS-bound.

References:

- Apple `WKWebView`: https://developer.apple.com/documentation/webkit/wkwebview
- Apple `WKProcessPool`: https://developer.apple.com/documentation/webkit/wkprocesspool
- Apple `WKURLSchemeHandler`: https://developer.apple.com/documentation/webkit/wkurlschemehandler
- Apple XPC services: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html
- Apple notarization: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Apple helper tool embedding: https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app

## Donor Shape Evidence

Local clones show the donor apps are web/runtime monorepos:

- OpenWork root package has `apps/app` Vite UI, `apps/desktop` Electron shell,
  `apps/server` headless API, `apps/opencode-router`, and orchestrator pieces.
- OpenWork `apps/server/package.json` is MIT and builds a server binary with
  OpenCode SDK, SQLite, config, MCP, skills, plugins, portable files, and
  workspace/session routes.
- OpenWork `apps/desktop/package.json` is an Electron shell with sidecar
  preparation scripts, node-pty, better-sqlite3, and OpenCode SDK.
- OpenWork `/ee` exists and is about 20M locally. It must remain pruned or
  license-reviewed.
- OpenChamber is also web/electron/server shaped: `packages/web` exposes a
  server/bin, `packages/electron` builds the desktop shell, and the UI package
  contains the mini-chat/session/streaming behavior to harvest.
- OpenGUI and Paseo are broader multi-agent web/desktop/runtime systems. They
  reinforce the same conclusion: Work-class features are web/runtime-first
  today, not SwiftUI-first.

Implication: a native Swift rewrite before the parity ledger is premature. The
donor architecture wants a runtime process and a web surface.

## Integration Options

### Option A - Pure Swift Native Port

Benefits:

- Best native feel.
- Best long-term control.
- Best MAS compatibility if constrained to Foundation Models/MCP Swift and
  sandboxed native services.

Costs:

- Slowest.
- Highest chance of missing donor capabilities.
- Requires rebuilding complex web surfaces: streaming transcript, panes,
  diff/review UI, file browser, terminal/pty, MCP/skills stores, mini sessions,
  permission routing, and worktree flows.

Verdict: good long-term cleanup target for selected surfaces, not the current
OpenWork full-clone path.

### Option B - Raw Electron / Donor App Mounted Whole

Benefits:

- Fastest way to see all donor features.
- Lowest chance of forgetting hidden surfaces.
- Donor tests and runtime assumptions stay intact.

Costs:

- Least native.
- Duplicates app shell/chrome/settings/recents.
- Higher memory and process overhead.
- Harder to make permissions/model picker/landing transitions feel like
  Epistemos.
- Risks "two apps inside one app" again.

Verdict: useful as internal debug/reference, not final Epistemos Work.

### Option C - WKWebView + Local Runtime Process

Benefits:

- Keeps donor React/web surfaces with much less shell bloat than Electron.
- Lets Epistemos own native chrome, transitions, recents, permissions, model
  picker, and session identity.
- Keeps Work runtime crash-isolated from the main app.
- Fastest practical way to preserve features and still feel native.
- Direct-distribution friendly if helper/runtime is signed/notarized.

Costs:

- Still has web memory/process overhead.
- Requires careful local API security: loopback bind, random port, bearer token,
  origin allowlist, process lifecycle, crash recovery, logs, and no ghost
  daemons.
- Needs bridge design so donor UI does not own final permissions/settings.

Verdict: best near/mid-term answer.

### Option D - WKWebView Static Assets + Native/XPC Backend

Benefits:

- More native and more secure than a generic Node/Bun server.
- Custom scheme can load static assets without localhost for frontend files.
- XPC can become a strong native boundary for sensitive operations.

Costs:

- Harder to adapt existing OpenWork/OpenChamber code quickly.
- JS/Node/Bun runtime pieces still need a process unless rewritten.
- XPC is awkward for web-native streaming unless carefully bridged.

Verdict: good future hardening direction after the WebKit/runtime version works.

## Recommended Work Runtime Topology

Use this mental model:

```text
Epistemos SwiftUI shell
  owns: windows, native toolbar, recents, model picker, permissions,
        landing/search reveal, mini-session identity, settings, vault picker

WKWebView Work surface
  owns: visible Work canvas/transcript/panes/file views/diffs/tool rendering
        after Epistemos theme injection/reskin

WorkRuntimeSupervisor
  owns: launch/stop/restart/health/logs/ports/tokens/update checks

OpenWork/OpenCode local runtime process
  owns: OpenCode integration, MCP, skills, plugins, sessions, sqlite,
        filesystem/workspace APIs, streaming event source
```

## Runtime Transport Guidance

Preferred first version:

- Launch a bundled, signed Work runtime process on demand.
- Bind only to `127.0.0.1` on an ephemeral port.
- Generate a per-launch bearer token.
- Store no long-lived secrets in the web surface.
- Restrict CORS/origin to the Work web origin.
- Kill/reap the runtime on app quit unless the owner enables background mode.
- Stream events over WebSocket or SSE, but normalize them into Epistemos
  session events for recents/model picker/permissions.

Static assets:

- If the donor UI can be built as static assets, prefer loading static assets
  via `WKURLSchemeHandler` or bundled resources.
- If the UI assumes an HTTP origin, start with loopback HTTP for compatibility
  and later migrate static asset loading to a custom scheme.

Native bridge:

- Use a message bridge for privileged UI requests: permission prompts, file
  picker, vault selection, reveal-in-Finder, native notifications, model picker
  changes, and mini-session focus/open-main.
- Do not let raw donor browser prompts or donor settings be the product UI.

## Native Feel Requirements

Native feel should come from what Swift owns:

- actual Epistemos window chrome,
- native toolbar/pills,
- owner model picker,
- native recents,
- native permissions and approval sheets,
- native vault/folder picker,
- native mini-session/window management,
- landing click-to-search and click-to-start conversation,
- blur reveal + typewriter/ASCII transition,
- native settings with a Work tab,
- native process health and install/repair UI.

The WebKit surface should be themed and quiet, but it does not need to pretend
to be a SwiftUI list. It should be a Work canvas inside Epistemos.

## Performance Requirements

For speed and memory:

- One Work runtime per active workspace unless there is a proven need for more.
- One shared `WKProcessPool` for Work web views.
- Reuse/prewarm a small number of WKWebViews instead of constantly creating and
  destroying them.
- Virtualize long transcripts and file lists.
- Coalesce duplicate startup/runtime fetches. OpenChamber has donor patterns
  for this.
- Back-pressure streaming updates so React does not rerender for every tiny
  token if batching is possible.
- Keep raw donor telemetry/update checks disabled unless explicitly adopted.
- Avoid Electron as the outer shell; WebKit gives the web surface without
  Chromium-shell duplication.

## Security / Hardening Requirements

Even outside MAS:

- Sign and notarize the main app and bundled helpers.
- Use hardened runtime.
- Bind local servers to loopback only.
- Use per-launch tokens.
- Make runtime logs redacted by default.
- Never expose arbitrary filesystem APIs to the web view.
- Pass security-scoped or owner-approved workspace roots through the native
  shell.
- Treat permissions as native Epistemos approvals, not donor browser prompts.
- Keep `/ee`, AGPL, GPL, and no-license code out of product artifacts unless
  explicitly approved.

## What Claude Should Do With This

Claude should not choose between "fully native" and "raw donor app." The current
best decision is:

1. Keep full clones in `.research-clones/` for exhaustive feature inventory.
2. Continue the OpenWork full-clone inventory/prune loop.
3. Build toward a curated Work runtime artifact, not raw source dumped into the
   Xcode project.
4. Embed the Work UI through WKWebView inside Epistemos native chrome.
5. Let the native shell own model picker, recents, permissions, settings,
   vaults, and mini-session identity.
6. Use OpenChamber patterns for mini sessions, streaming, bootstrap, fetch
   coalescing, and permission stores.
7. Keep Electron only as reference/debug, not final shell.
8. Later, migrate sensitive runtime pieces to XPC/native helpers if needed.

## Final Recommendation

For Work:

> Use WebKit plus a controlled local runtime process. This gives the most
> usefulness while preserving native feel. It is the right bridge between full
> clone and final Epistemos ontology.

For Act:

> Keep the MAS-friendly native direction separate: Foundation Models, MCP Swift
> SDK, Swarm/SwiftedMind patterns, and no heavyweight Work sidecar.

For product code:

> Full clone for study; curated runtime artifact for shipping; native shell for
> Epistemos identity.
