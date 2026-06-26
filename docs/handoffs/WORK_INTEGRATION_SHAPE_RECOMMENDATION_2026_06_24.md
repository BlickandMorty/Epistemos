# Epistemos Work Foundation — Integration-Shape Recommendation (2026-06-24)

> Deep-research deliverable (owner asked: "the best option and why" for native-feel × usefulness).
> Method: 9-agent workflow — 3 approach analyses (native-port / WebKit-embed / hybrid) + a hard-constraints
> analyst + live web research → a 3-lens judge panel (native-feel / capability / shipping-reality) →
> synthesis. **All three lenses independently ranked the hybrid first** (native-feel lens 78, capability
> lens 86, shipping lens 78). Grounded in-repo (entitlements, `WorkOpenCodeShell.swift:78-91`,
> `EpdocEditorChromeView.swift`, `build-opencode-runtime.sh`). Companions: the OpenWork parity ledger +
> OPENWORK_OPENCHAMBER study handoff.

> **SUPERSEDED ON DONOR CHOICE (2026-06-24, owner+Codex canon `WORK_INTEGRATION_SHAPE_RESEARCH_2026_06_24.md`):**
> The *shape* below (native Swift shell + local runtime process + WKWebView + native bridge) is RATIFIED and
> correct. But this doc's "use OpenChamber AS the embed donor" is OVERRULED: canon makes **OpenWork the
> primary embed/full-clone donor** — embed its `apps/app` Vite UI (curated/pruned), run its `apps/server`
> headless API as the local Work runtime, drop `apps/desktop` (Electron). **OpenChamber becomes the PATTERNS
> donor** (mini-sessions, streaming, bootstrap, fetch-coalescing, permission-store) to fuse later. Also:
> persistence (MCP/skills/plugins/sessions/SQLite) stays in the RUNTIME PROCESS, not re-homed to native
> GRDB; the native shell bridges + owns presentation/identity. MAS is de-prioritized for Work (direct-dist
> + local runtime). Read §3's split as native-shell-vs-WebView-vs-runtime with those donor roles.

## 1. Recommendation
Adopt **Approach C — the contained hybrid**: a **native Swift shell that owns every identity, security,
and native-feel surface**, wrapped around **one long-lived, theme-tokened WKWebView** that hosts *only* the
heavy donor Work GUI (sessions, diff/worktree/review, workspace, MCP/skills/plugins panels, streaming),
with both the native shell and the embedded web surface driving the **same managed `opencode serve`
loopback HTTP/SSE server** via the OpenCode API. **Use OpenChamber as the embed donor** (its UI already
talks pure HTTP/WS to a runtime URL → drops into a WKWebView like-for-like), even though the AUTHORITATIVE
plan names OpenWork primary. On the native×useful frontier this is the single point where **both axes stay
high**: full ~107K–277K-LOC donor capability day-one (usefulness ≈ 9) while the load-bearing native
identity — landing/search blur+typewriter/ASCII reveal, model picker, recents, vault, permissions, OS
prompts — stays 100% Swift (native feel ≈ 7).

## 2. Why
- **Native-port (A) is dead on arrival:** no Swift SDK for the donors; both are 100% Electron + Node/Bun +
  React/TS with native `node-pty`/`better-sqlite3` addons; a hand-port of 107K–277K LOC is exactly the
  authority's documented failure mode ("kept the shell but dropped donor features"). Authority-rejected.
- **Pure-embed (B) ships but** lands native feel at ~4 ("theme-tinted, not native"), treats the WebView as
  the *primary* Work surface (the "pasted web app" the owner penalizes), and drags in the donor's heavy
  ~56K-LOC Express/Bun server + preload contract — a bigger, faster-rotting supply chain.
- **C wins on the hard constraints, verified in-repo:** the WKWebView host pattern already exists and is
  battle-tested (`EpdocEditorChromeView.swift`: nonPersistent store, custom `URLSchemeHandler`,
  `WKScriptMessageHandler` bridge, `dismantleNSView` teardown, `drawsBackground=false`, theme-token→CSS
  injection); the runtime is already vendored (`build-opencode-runtime.sh` pins Bun + opencode); the
  distribution split is forced by code (`WorkOpenCodeShell.swift:78-79` returns `InertWorkOpenCodeShell()`
  under `#if EPISTEMOS_APP_STORE`; direct-dist entitlements permit the loopback sidecar, MAS does not).
- **C's decisive edge over B is drift-resistance:** it integrates at the ONE seam both donors converge on —
  the `opencode serve` HTTP/SSE API (the `@opencode-ai/sdk` is "just a fetch wrapper" a native client can
  replicate). That makes it donor-agnostic (survives an OpenWork↔OpenChamber swap), upgrade-tolerant, and
  able to **drop the heavy donor Node/Express layer entirely**, leaving single-binary `opencode serve` as
  the only sidecar.
- **Consensus dissent to respect:** B and C are the *same* WKWebView-over-loopback mechanism, so C's feel
  advantage is **discipline-dependent, not structural**. Fork donor components instead of token-only
  theming, or let the donor's in-WebView session store shadow native recents, and C degrades into B (a
  themed web app with ghost/duplicate-session bugs the authority calls outright failures). The discipline
  (§5) is mandatory, not optional.

## 3. The native/web split
| Work surface | Tier | Why |
|---|---|---|
| Landing/search → chat reveal (blur + typewriter + ASCII) | **Native Swift** | Locked IP; motion does not cross the WebView boundary. |
| Model picker | **Native Swift** | Locked, non-prunable visible picker; core identity. |
| Recents / sessions list (source of truth) | **Native Swift** | Single source of truth — the strongest defense against stranding capability across the bridge; donor session store is a *mirror*. |
| Vault / keychain / permissions / OS prompts | **Native Swift** | Security surface; must be auditable Swift, never web-rendered. |
| Settings / theme / window chrome / menus / traffic lights | **Native Swift** | Native-feel polish (drag region, white-flash kill, native menu bar). |
| Sessions detail · diff/worktree/review · workspace · MCP/skills/plugins panels · streaming | **WKWebView** (OpenChamber `@openchamber/ui` SPA) | The big surface where HTML+CSS beats SwiftUI and where native-only attempts under-cloned; fenced to ONE panel so the pasted-web penalty is contained. Theme via injected CSS variables. |
| Terminal (PTY) | **Helper-process** (existing seam) | `WorkOpenCodeShell`/`WorkOpenCodeRuntime` already resolve the bundled launcher; SwiftTerm owns lifecycle. Re-point OpenChamber's WS terminal at this Epistemos-owned PTY. |
| `opencode serve` engine (sessions/MCP/permissions/persistence) | **Helper-process** (loopback, Pro-gated, VISIBLE) | The authoritative engine both donors drive; `127.0.0.1` only, token auth, visible via Work health row — never hidden per CLAUDE.md. |
| Donor Node/Express server layer | **Dropped** | Serve the static React build via custom `URLSchemeHandler` (Epdoc precedent) so the only sidecar is single-binary `opencode serve`. |

## 4. MAS vs direct-distribution
- **Direct-distribution (the live Work product):** full hybrid — bundled `opencode serve` on `127.0.0.1`
  as the explicit, Pro-gated, VISIBLE sidecar; WKWebView loads the OpenChamber SPA from a custom URL scheme
  and drives the loopback API; native shell owns identity/security. Only target whose entitlements permit a
  child process + `network.server`.
- **MAS / App Store:** Work is **honestly inert** (sandbox + hardened runtime forbid subprocess →
  `InertWorkOpenCodeShell`, SwiftTerm compiled out). State the cliff honestly; never a fake placeholder.
  Constant across B and C; acceptable per CLAUDE.md.

## 5. Capability-preservation plan (anti-omission) — the mandatory discipline
1. **Parity ledger as a CI gate** — enumerate every donor capability; CI fails on unreviewed donor-bundle
   content-hash change or `@opencode-ai/sdk` version drift (mirror `build-tiptap-bundle.sh`'s hash gate).
2. **Native = single source of truth** for sessions/recents/permissions; donor's in-WebView store is a
   read-through mirror over a narrow, versioned `WKScriptMessageHandler` contract; ghost/duplicate-session
   states are build-breaking.
3. **Token-only theming, never component forks** — inject Epistemos tokens as CSS variables; override donor
   Tailwind cards/gradients to the flat/no-gradient north star; never fork donor TSX (so upstream flows in).
4. **OpenChamber additions over OpenWork** — OpenChamber's thin preload + `runtime-fetch.ts` make the bridge
   shim small; OpenWork's fat Electron preload would force a whole IPC contract. Re-home the few
   Electron-only OpenWork capabilities (embedded BrowserView, auto-updater) natively or drop them.
5. **License hygiene** — exclude all donor `/ee` (FSL) from any vendored bundle.

## 6. First 3 build steps (small, reversible, OWNER-GREENLIT)
1. **Spike:** load OpenChamber's static `@openchamber/ui` build in the Epdoc WebView host
   (`EpdocEditorChromeView`) via a custom `URLSchemeHandler`, pointed at the already-bundled `opencode
   serve` (`WorkOpenCodeRuntime.bundledRuntimeURL`). Throwaway debug view, zero change to the shipping Work
   path. Proves the SPA renders + drives sessions over loopback with no Node server.
2. **Bridge contract + theme injection** — one namespaced `WKScriptMessageHandler` with a typed/validated
   command schema (session-select, model-select, permission-prompt, open-main/focus, file-grant) + weak
   handler refs + a `WKNavigationDelegate` permitting only the app origin; plus the token→CSS-variable theme
   bridge as one injected script. Additive, behind the spike flag.
3. **Vendor the OpenChamber static build into Resources, content-hash gated** (mirror
   `build-tiptap-bundle.sh`) + an `OpenChamberBundleHealthRow` in Settings; exclude `/ee`. Pure resource
   staging, no runtime behavior change until wired.

### Needs OWNER decision / visual proof before proceeding
- **Donor ratification:** approve **OpenChamber as the embed donor** over the AUTHORITATIVE plan's
  named-primary OpenWork (resolves a real plan tension; explicit owner call). [Reconciliation: OpenWork
  stays the *capability/behavior* donor whose config/MCP/skills/plugins are RE-HOMED natively — parity
  ledger rows 1-4 — while OpenChamber supplies the *embeddable GUI*.]
- **Visual proof:** side-by-side of the spike showing OpenChamber's diff/sessions surface (a) theme-tokened
  to Epistemos colors and (b) wrapped by the native blur+typewriter/ASCII landing transition — to confirm
  "contained web in native chrome" reads as Epistemos, before committing build effort.
- **Min-OS:** macOS 26+ (WWDC 2025 native SwiftUI `WebView`/`WebPage`) vs support macOS 14/15 (stay on
  `WKWebView`/`NSViewRepresentable`). Bounds the bridge API surface.

## 7. Honest risks & the runner-up
- **Native-feel ceiling on the busiest surface** (diff/sessions/workspace stay web — scroll inertia, native
  context menus, focus rings, and the locked motion IP do not cross the boundary). Mitigation: fence web to
  one panel; invest in chrome polish.
- **Maintainability (C's weakest dim)** — vendored donor JS + moving `opencode` API. Mitigation: the §5 CI
  gates + narrow versioned bridge. Without them C degrades into B.
- **State-duplication** — native+web views of one session. Mitigation: native single-source-of-truth + mirror.
- **MAS cliff** — honest gate state, never fake parity.
- **Runner-up: B (pure WebKit embed)** — choose B over C ONLY if execution discipline cannot be guaranteed
  (B's "carry the donor mostly as-is" loses less by accident), or if the step-1 spike shows OpenChamber's
  session model is too entangled to delegate to a native source of truth. **A (native-port) is never the
  near-term answer**; its only useful fragment (drive the opencode HTTP/SSE API directly from Swift,
  shrinking the web surface to rich-content panes) is **Phase 3 of C**.

**Bottom line:** Ship C — native Swift shell + one contained OpenChamber WKWebView + the existing loopback
`opencode serve`, donor Node layer dropped — direct-distribution + Pro-gated, honestly inert on MAS. The
only frontier point buildable now from in-repo precedents, drift-resistant at the single opencode seam, and
faithful to both the AUTHORITATIVE plan's "WebKit/native hybrid reskin" and CLAUDE.md's no-hidden-sidecar law.
