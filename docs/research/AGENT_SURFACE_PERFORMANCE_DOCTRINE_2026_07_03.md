# Agent-Surface Performance Doctrine (2026-07-03)

**Read-first canon for BOTH agent builds** (Plan 1-PRO OpenChamber + Plan 1-MAS June/goose).
Performance is a **shipping gate, not a polish pass** — the owner specifically loves that
the current goose surface "opens instantly" and wants that felt-speed preserved and
**hardened into the repos on both the web side and the app side** as the surfaces are
built. This doctrine makes the optimization explicit, measurable, and per-phase-enforced.

Model: mirrors `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` (a shared doctrine both plans
cite). Budgets are contracts in `docs/perf-budgets.toml` `[agent_surface]`.

**Two sides, both mandatory:**
- **Web side** = the vendored OpenChamber SPA (Pro) — TypeScript/React/Vite, served in the
  WKWebView. Also any WKWebView the app ships (editors/KaTeX/Browser tab).
- **App side** = native Swift (both builds) — the WKWebView host + supervisor (Pro), and
  the native SwiftUI surfaces + `agent_core` + llama.cpp (MAS).

---

## §1 THE INSTANT-OPEN RECIPE (the felt-speed spine — already in the plans)

The current goose surface's instant open is a **6-part recipe**, reverse-engineered from
`Epistemos/Goose/GooseWebSurfaceView.swift` + `GooseRuntimeSupervisor.swift`, and written
into **Plan 1-PRO §13** and **Plan 1-MAS §12**. Do not re-derive; build from those. Summary:

1. Eager WebView created in `init()`, **placeholder loaded immediately** (`GooseWebSurfaceView.swift:85-94`).
2. **Spawn servers/runtime OFF the main actor** (`Task.detached(.userInitiated)`) — notarized-binary
   signature validation blocks inline @MainActor spawn for hundreds of ms–s (real hang fix,
   `GooseRuntimeSupervisor.swift:421-427`).
3. Lazy start on first `.task` appear, not app launch (`:109`).
4. Poll-wait for `.running`, placeholder shown in parallel (`:345-347, :446-472`).
5. **KEEP THE WEBVIEW / RUNTIME + MODEL WARM across tab switches** — the "instant re-open"
   (`:42, :147-149, :295-309`). Never tear down the WebView / never unload the GGUF model on
   tab-switch; only pause.
6. Non-persistent data store + in-RAM asset serving (`GooseWebSurfaceSupport.swift:32, :44-49`).

Per-architecture translation is in the two plan sections (Pro ports all 6 + optional eager
pre-warm; MAS drops #1, leans on Apple FM zero-load + warm GGUF).

---

## §2 WEB-SIDE OPTIMIZATION (Pro OpenChamber SPA — the layer the plans didn't yet cover)

The Pro agent surface is a full React SPA in a WebView. The build agent works **inside the
vendored fork**, so these are its responsibilities there (all as `epistemos/` overlay or
patch-ledger entries, never silent upstream edits):

1. **Ship the PRODUCTION build, verified.** Serve the minified, tree-shaken, terser'd Vite
   production bundle — never the dev bundle. Confirm in Web Inspector that no dev/HMR
   runtime is present. Sourcemaps external, not inlined.
2. **Code-split + lazy-load heavy panels.** OpenChamber's workspace has chat/diff/git/
   terminal/files/plan/diagram panels. First paint needs only chat + composer; `React.lazy`
   + dynamic-import the heavy ones (terminal/ghostty-web, diff editor, diagram, git). Don't
   pay their JS/parse cost until opened.
3. **Bundle-size budget (contract).** `[agent_surface].pro_web_bundle_kb_max` — gate the
   gzipped initial JS+CSS. Watch it on every upstream merge; OpenChamber bloat is a
   regression to catch, not absorb. Tighten the number as you measure.
4. **No-remount navigation (also a correctness rule).** Panel/tab switches are React state,
   not route remounts; **never reload the SPA URL** — it reboots the app and kills the live
   session (already canon in the pill-nav rule). The React tree stays mounted; the WebView
   stays alive (§1.5).
5. **Virtualize long lists.** The session sidebar (all-chats) and long transcripts MUST be
   windowed (react-virtual or the donor's own virtualization). Never render all rows/messages
   — a 5k-session sidebar or 2k-message thread renders only what's visible.
6. **Isolate streaming render.** The SSE `message.part.delta` → state path must NOT re-render
   the whole transcript per token. Put the streaming message in its own memoized component,
   subscribe with **narrow selectors** (the Zustand store-slice-by-change-frequency pattern),
   and batch deltas (rAF/coalesce) so 60/s token streams don't thrash the tree.
   `transcript_frame_ms_p99` gates this.
7. **Service worker + self-updater OFF** (already in the plans) — a cached SW fights the
   vendored bundle (the Step-0 stale-bundle trap) and double-fetches.
8. **Web memory discipline.** Shared `WKProcessPool`; `WKWebsiteDataStore.nonPersistent()`;
   tear down heavy panels' DOM when hidden; cap in-memory message/file/diff caches (dual
   ceiling: N items OR M bytes, like the app-side caches already do).
9. **Self-host + subset fonts, no CDN** (CSP requires it anyway); reserve space to avoid
   layout shift; inline critical CSS.
10. **Off-main-thread heavy work.** Syntax highlighting, large-diff computation, markdown of
    huge messages → Web Workers, never the main thread; keep scroll/stream at 120fps.
11. **Time-to-first-token is the real "fast agent" metric.** Optimistically render the user's
    message instantly on send; stream the reply the moment the first delta arrives.
    `first_token_ms_max` gates it.

(These also apply to the app's other WKWebViews — editors/KaTeX/Browser — where relevant.)

---

## §3 APP-SIDE / NATIVE OPTIMIZATION (both builds)

Extends the existing native perf infrastructure (don't reinvent — see §6):

1. **Everything expensive off the main actor** — process spawn, `agent_core` init, GGUF
   model load, FFI hot paths. `@MainActor` inline spawn is the documented hang (§1.2).
2. **Keep the expensive thing warm** — WebView alive (Pro) / GGUF model + agent_core session
   resident (MAS) across Agent tab-switches. `mas_model_retained_on_switch = 1` is an
   invariant. Unload only under real memory pressure, never on tab-switch.
3. **Shared `WKProcessPool` + non-persistent store** (Pro) — collapse N WebContent processes
   into one (the app already does this for editors: `EpdocWebViewShared.processPool`).
4. **Memory-pressure handlers** — the app already routes `DispatchSourceMemoryPressure` into
   Rust FFI relief + Swift cache release (`EpistemosApp.swift`, `respondToMemoryPressure`).
   Wire the new surfaces' caches (transcript, model, three child processes on Pro) into the
   same handler. Pro supervises 3 children on a 16 GB machine — enforce per-child memory
   ceilings + backoff (Plan 1-PRO §7 Phase 5).
5. **Lazy-init services** — follow the `AppBootstrap` computed-getter pattern (already used
   for capture/vision/insight services); don't eagerly build the agent stack for users who
   never open Agent (except the optional Pro server pre-warm, Plan 1-PRO §13).
6. **Binary-size budgets stay green** — `[binary]` ceilings (libagent_core ≤16 MB, etc.) are
   contracts; the new FFI surface must not blow them.

---

## §4 BUDGETS + MEASUREMENT (make it enforceable, not aspirational)

Budgets live in `docs/perf-budgets.toml` `[agent_surface]` (target-only until measured —
the CI parser skips the section today). **Wiring the measurement is a phase gate**, not
optional:
- **Web side:** capture SPA mount→paint, bundle size, first-token, transcript frame time via
  the Web Inspector timeline + a lightweight in-page perf mark; assert bundle KB in the
  vendored build's CI.
- **App side:** `os_signpost` intervals around open/spawn/first-token (the app already uses
  signposts, e.g. `Sig.storage.beginInterval`); surface them in a diagnostic HealthRow like
  `SearchFusionHealthRow`/`EditorBundleHealthRow` so the owner can SEE cold-open / warm-reopen
  / first-token live in Settings → Diagnostics.
- Once a producer exists, extend `scripts/check-perf-budgets.sh` to enforce the
  `[agent_surface]` keys (mirror how it consumes `[runtime]`). Budgets are CONTRACTS:
  tightening is free; loosening needs a `# loosened YYYY-MM-DD: <reason>` trailer.

---

## §5 PERF IS A PER-PHASE GATE (deeply hardened as they build — the point of this doc)

Every phase in both plans ends with a perf check, not just a functional one. Add to each
plan's phase-acceptance:
- **Warm re-open feels instant** (≤`warm_reopen_ms_max`) and **click→placeholder ≤100ms**
  (never a blank/hang) — from Phase 0/1 onward, because the recipe (§1) is built in first.
- **No full-transcript re-render per token** (Pro) / **model stays warm across tab-switch**
  (MAS) — verified the phase it lands.
- **Bundle budget green** on every vendored-upstream merge (Pro).
- **Memory stable** under a launch→use→switch→idle soak; no leak, no runaway child process.
Regression discipline: a perf regression blocks the phase commit the same way a broken build
does. "Works but janky" is not done.

---

## §6 REFERENCES (extend these, don't duplicate)

- Budgets: `docs/perf-budgets.toml` (`[agent_surface]` new; `[binary]`/`[runtime]` existing).
- Existing native perf infra: `docs/PERF_BASELINE.md`, `docs/PERF_HANDOFF_TO_CODEX_2026-04-29.md`,
  `docs/research/SS-PERF_PERFORMANCE_MEMORY_2026_06_19.md`, `docs/research/SS-PERF2_REMAINING_PERF_WINS_2026_06_20.md`,
  and the perf-hardening waves in `CLAUDE.md` (2026-04-28/29: shared process pool, memory-pressure
  FFI, idle model unload, lazy-init services, bounded caches).
- Instant-open recipe (source of truth): Plan 1-PRO §13 + Plan 1-MAS §12 (+ the goose files
  they cite).
- Look-and-feel canon (perf must not break it): `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.
