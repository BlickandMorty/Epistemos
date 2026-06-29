# Affordance-bridge security review — web-driven native surface (2026-06-29)

Adversarial security review of `GooseWebNativeAffordanceBridge.swift` — the privileged native surface
the embedded Goose Web UI calls into (`window.webkit.messageHandlers.epistemosGooseNative`) to open
URLs, launch/host MCP "app" guest WebViews, and read/write files. Because untrusted-ish web content
drives it, bugs here are security-critical. Prior-loop fixes (C1, #13/#24, #23, #14) were verified
**correct and not regressed**.

## Findings → status

| # | Sev | Finding | Status |
|---|-----|---------|--------|
| H1 | HIGH | `openDirectoryInExplorer` handed any directory to `NSWorkspace.open` — a `.app`/`.workflow`/`.scptd`/document-package bundle IS a directory, so it **LAUNCHED the app** (reopening the LSOpen handler-launch threat #13/#24 closed); no scope check | ✅ FIXED `6c111def3`: confine to consented scope (`isPathAllowed`), reject bundles (`isApplication`/`isPackage`), REVEAL in Finder via `selectFile` (never launches) |
| M1 | MED | the MCP-app guest nav delegate allowed ANY loopback host (port-blind) vs the main surface's registered-port pin → SSRF top-frame pivot to other local services (local model server / notebook-with-token / admin panel) | ✅ FIXED: bridge shares the view's `GooseTrustedLoopbackOrigins`; guest delegate pins to registered ports (`isAllowed`) |
| M3 | MED | `launchApp` accepted a non-loopback `uri`, built the window, then the guest delegate silently cancelled it → blank "dead" window (**maps to the owner's "Apps loading failures"**) | ✅ FIXED: resolve + validate the content source (`isAllowedAppOrigin`) BEFORE creating any webview/window → a rejected uri throws an honest `missingAppContent` with nothing created/leaked |
| L1 | LOW | `closeApp`/`closeAllApps` leaked `appGuestNavDelegates[name]` (relied on `windowWillClose`) | ✅ FIXED: explicit removal in both |
| L2 | LOW | `launchApp` reuse guard used `isVisible` → built a duplicate for a MINIMIZED window, orphaning the prior webview | ✅ FIXED: reuse + `deminiaturize` |
| M2 | MED | default scoped root is the WHOLE home dir + production constructs with no args → `readFile`/`writeFile` across `~` (`.ssh`, `LaunchAgents`, dotfiles). Amplifies any goose-UI XSS into full-home read+write | ⏳ DEFERRED (task #18): trust-model decision — narrowing the default risks breaking the WebUI's legitimate cross-project file ops; needs the owner's call on the right working scope. Residual risk is bounded: the bridge is only reachable from the port-pinned trusted goose origin |
| M4 | MED | `listGitWorktreeDirs` blocks `@MainActor` up to 3s (`semaphore.wait`) and can pipe-deadlock on >64KB git output (drains the pipe only after the wait) → UI beachball + dishonest empty result | ✅ FIXED `561e94bd4`: drain the stdout pipe CONCURRENTLY (background queue + `GooseAffordanceDataBox`, semaphore-synchronized) → no deadlock, and the wait now completes as soon as git exits (collapsing the block to git's real fast runtime). Fully eliminating the brief residual block needs the async-replyHandler reroute (risks the feature-presence ledger) — that part stays deferred |
| L3/L4/L5 | LOW | `getBinaryPath` PATH enumeration (info disclosure); final-component TOCTOU (standard, no symlink-creation affordance); guest has no `didReceive` challenge handler (relates to the deferred goosed-TLS cert-pin, task #16) | ⏳ DEFERRED |

## Verified CORRECT (not regressed)
- openExternal allowlist (#13/#24): `shouldOpenExternalURL` lowercases scheme + allowlist; `openExternal`
  re-parses the SAME rawURL with the same constructor — no parser differential; fails closed.
- recent-dirs (C1): display-only, no scope grant.
- git env (#23): minimal PATH/HOME/LANG, fixed args, no shell, validated `expandedPath`.
- guest sandbox (#14): `.nonPersistent()`, NO script handlers (guest can't reach the native bridge or
  `getSecretKey`), `file:` collapses `..` via `standardizedFileURL`; `isPathAllowed` requires BOTH the
  standardized AND symlink-resolved path inside a root with a `/`-boundary (robust vs `..`,
  prefix-sibling, symlink-escape).

Build green; GOLDEN RULE clean. The fixes are additive guards on a web-driven surface; no working
affordance behavior changes for legitimate (loopback, in-scope) inputs.
