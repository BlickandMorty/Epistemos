# SS-HW — HTML Workspace: honest status + upgrade to a real web-app builder (2026-06-20)

Owner: *"the html workspace does not work as well but idk if its marked as such… don't forget the upgrades I wanted on
html workspace with DOM, the chat, etc. — all the best things you'd want on HTML/JS/CSS/Python preview, and being able
to create a full web app through the built-in pipeline using html workspace."* Code-grounded + web. MAS-safe (NO runtime
subprocess), license-gated, reuse-not-rebuild.

## CURRENT STATUS — compiles + renders, but a one-way static renderer with DEAD seams, and NOT marked broken
**Works:** `com.epistemos.html-workspace` is a real `NSDocument` (`Engine/HTMLWorkspaceDocument.swift:62,74,140`, registered
in both Info.plists); multi-file HTML/CSS/JS/Data editing (`HTMLWorkspaceEditorView.swift:265-291,319`); WKWebView preview
(`HTMLWorkspacePreviewView.swift:8,25` rendering `HTMLWorkspacePreviewDocument.render` `HTMLWorkspacePackage.swift:837`
with CSP + theme-guard + `window.HTMLWorkspace` DOM helper `:895-947`); 220ms debounced live-ish preview (`:865`);
export/import/PDF/snapshot. **Agent/chat patch pipeline EXISTS + wired** — `HTMLWorkspacePatchRouter` parses
` ```epistemos-html-workspace-patch ` fences + applies (`:317,450,199`), invoked from chat (`MiniChatView.swift:2192,2425`),
context-packed (`ChatCoordinator.swift:4529`), with content-hash concurrency + unsafe-source rejection. DOM outline
(read-only text from source) `HTMLWorkspaceDOMOutline:466`.
**DEAD/limited (file:line):** (1) app-bridge handler is EMPTY — `HTMLWorkspacePreviewView.swift:145-149` receives messages,
does nothing. (2) `safeAPIEnabled` defaults false + hardcoded false at both call sites (`GraphWorkspaceContainer.swift:528`,
editor never passes it `:335`); header shows "Safe API"/"No bridge" for a no-op. (3) console panel (`:376-400`) can NEVER
show errors — no JS captures `window.onerror`/`console.error` to post back (the handler is the empty stub). (4) "DOM
inspection" is static regex of source HTML, not the live runtime DOM; no picker/styles. (5) NO Python. (6) CSP
`offlineDefault` (`HTMLWorkspacePackage.swift:265-277`) = `default-src 'none'; connect-src 'none'; script-src
'unsafe-inline'` → blocks WASM/connect/external libs. (7) persistence (localStorage/IndexedDB/messageHandlers) blanket-
banned by the patch validator (`HTMLWorkspacePatchRouter.swift:247`). (8) capability grid (`:453`) cosmetic.
**HONESTY GAP:** there is NO `HTMLWorkspaceGateStatus` — the codebase has the convention (`ActOsaurusGateStatus`,
`WorkBackendGateStatus`, `DeepResearchGateStatus`, etc.) but HTML workspace is shipped silently as if complete, with
T0/T1 dead seams. Per ARCHITECTURE PROMOTION CANON it should be honestly marked.

## UPGRADE PLAN (smallest first; MAS-safe; reuse Epdoc WKWebView/bridge/URL-scheme + build-time-bundle + GateStatus + provenance)
- **Step 0 — Honesty [S]:** add `HTMLWorkspaceGateStatus.swift` (mirror `ActOsaurusGateStatus`), mark app-bridge/Python/
  live-DOM `deferred`/`research`; stop rendering the dead "Safe API"/console affordances (`HTMLWorkspaceEditorView.swift:361,373`).
- **Step 1 — Real console + error bridge [S]:** implement the empty handler (`HTMLWorkspacePreviewView.swift:145-149`) —
  inject a userscript capturing `window.onerror`+`console.{error,warn}` → `postMessage` → `recordConsoleError`
  (`HTMLWorkspacePackage.swift:961`, already plumbed to UI); enable `safeAPIEnabled` for the editor's own diagnostics-only
  preview (`:335`). Reuse the Epdoc bridge (`EpdocEditorChromeView.swift:611-612`). Bonus: runtime errors feed back into
  chat → the agent self-corrects.
- **Step 2 — Live DOM + chat-edit hot-reload [M]:** replace static outline with a live `evaluateJavaScript` DOM query +
  element-picker; extend the patch router (`HTMLWorkspacePatchRouter.swift:450`) with a "live apply to WKWebView" fast
  path (no full doc round-trip).
- **Step 3 — Python via Pyodide/WASM, MAS-safe [M-L]:** run CPython in-browser via **Pyodide WASM in the existing WKWebView**
  (the ONLY MAS-safe Python path — no subprocess). VENDOR Pyodide into `Resources/` at build (never fetch at runtime;
  reuse the `build-tiptap-bundle.sh` model) + serve via a `WKURLSchemeHandler` (reuse `EpdocEditorChromeView.swift:630`
  `setURLSchemeHandler` — WKWebView blocks `.wasm` from `file://`). Add a 3rd `HTMLWorkspaceSandboxPolicy` "python" preset
  relaxing CSP to `script-src 'wasm-unsafe-eval' 'unsafe-eval'` + a `connect-src`/scheme entry for the local Pyodide URL.
  License-gate via the provenance pattern (`Vendor/Osaurus/OsaurusVendorProvenance.swift`; Pyodide = MPL-2.0/Apache-2.0/PSF).
- **Step 4 — "Build a full web app" scaffold pipeline [L]:** extend `HTMLWorkspacePackage` (`:320`) from the fixed
  index/style/main/data quad to a multi-file/multi-route model (it already has `assets:[String:Data]` `:326`); add scaffold
  templates (reuse `EpdocBlockTemplateStore`); add `addFile`/`addRoute` patch ops (extend `HTMLWorkspacePatchCommand`
  `:67`); relax the persistence ban per-sandbox-mode (`:247`) so generated apps use localStorage/IndexedDB. All edits flow
  through the existing in-process chat/patch pipeline — MAS-safe by construction.

Reuse: WKWebView+bridge+URL-scheme (Epdoc `EpdocEditorChromeView.swift:610-647`); build-time bundle (`build-tiptap-bundle.sh`);
GateStatus (`ActOsaurusGateStatus`); provenance (`OsaurusVendorProvenance`); agent edit pipeline (`HTMLWorkspacePatchRouter`,
exists — extend, don't rebuild). Cross-ref SS-EM/SS-O (Epdoc), SS-HGT (host inline in the graph tunnel). Sources: Pyodide
bundler/offline docs + CSP `wasm-unsafe-eval` (WKWebView local .wasm needs URL-scheme handler) + WKWebView CSP hardening.
