> SCOPE NOTE (2026-07-02, owner /loop instruction): work on EVERYTHING EXCEPT the Goose part of the app. Goose lane (Epistemos/Goose/, Epistemos/ActGoose/, goosed, ACP bridge, Goose flags, goose web bundle) is OUT OF SCOPE for modification this run — document boundary facts only. Phase 6 applies to the app's own non-Goose Rust crates for AUDIT; Goose-owned Rust is untouched. This file is the verbatim content of "EPISTEMOS_HARDENING_DIRECTIVE (2).md" (the owner-saved original), placed at the canonical path the directive references.

# EPISTEMOS — ENTERPRISE HARDENING DIRECTIVE (v2)

<!--
HOW TO USE (Jojo):
1. Save at repo root as EPISTEMOS_HARDENING_DIRECTIVE.md and commit it.
2. Open Claude Code with Fable at high effort (xhigh if available) in the repo.
3. Paste the KICKOFF MESSAGE below as your first message.
4. After the run completes, open a FRESH session and paste Appendix A
   (the independent verifier prompt). Fresh context matters: the agent that
   patched the code should not be the one grading it.
-->

## KICKOFF MESSAGE (paste this into Claude Code)

> I'm preparing Epistemos for enterprise users and Mac App Store review — people
> need to trust this app with their meetings, research, and browsing, so the
> bar is: no known critical breakage left unpatched or undocumented, and no
> unverified claims of completion. Read EPISTEMOS_HARDENING_DIRECTIVE.md at the
> repo root in full, then read
> /Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md in full.
> Execute the directive phase by phase, starting with Phase 0. Do not ask me
> broad clarifying questions before inspecting the repository — inspect first.
> Present your Phase 0 findings and Phase 1–2 plan at the first checkpoint,
> then work autonomously through the remaining phases, pausing only at the
> checkpoints the directive defines.

---

<role_and_mission>
You are acting as a principal-level engineer running a full enterprise-readiness
audit and hardening pass on Epistemos: a staff security engineer, a Swift 6.2
strict-concurrency specialist, a Rust systems auditor, a WebView/IPC hardening
specialist, and an AppKit platform engineer in one. Your mandate covers the
entire app: Swift/AppKit frontend, Rust core (Goose agent runtime), Metal
rendering, WKWebView-hosted web UI (JS/CSS/HTML), the Swift↔Rust bridge, and
cloud LLM transport. Assume a hostile security reviewer and Apple App Review
will both examine the result.

Your mission is not to make suggestions. It is to inspect, audit the completed
Plan 1–3 work against reality, harden, implement safe fixes, integrate the
features into one product, and leave behind a verifiable report. This is
defensive hardening of my own application: the deliverables are audits, fixes,
tests, and reports — never exploit code or attack tooling. When you find a
vulnerability, describe the failure scenario plainly, fix it, and prove the fix
with a test or a reproducible check.
</role_and_mission>

<context>
Epistemos is a Mac-native app targeting Mac App Store distribution: AppKit
shell, Rust core built on the Goose agent framework, Metal-rendered knowledge
graph, WKWebView UI surfaces, cloud-only LLM inference. Prior work was executed
as Plan 1, Plan 2, and Plan 3, which claim to be complete. Feature surfaces
that must ship integrated and trustworthy: meetings, arXiv, and the browser.

"Enterprise-grade" here means: builds clean under Swift 6 language mode with
strict concurrency; zero data races; least-privilege sandbox and entitlements;
a hardened, schema-validated, origin-checked bridge; a Rust core with no
reachable panics, no unjustified unsafe, and a deny-by-default tool surface;
feature flags that fully gate their features in both directions; and the three
features working end-to-end inside one cohesive, theme-aware, minimal
pixel-art-inspired shell. Boringly reliable, least-privilege, understandable,
testable, recoverable, honest.
</context>

<required_reading>
Read in full, in this order, before any code changes:
1. This file.
2. /Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md — the
   review methodology. Treat "thermo-nuclear" as a demand for severe honesty,
   not cosmetic criticism: find the hidden fragility. Apply it in every audit
   phase. If a specific prescription conflicts with what this codebase needs,
   follow the skill's intent (maximum rigor) and record the deviation in
   DECISIONS.md.
3. CLAUDE.md, PROGRESS.md, and every sprint/plan file for Plans 1–3.
</required_reading>

<operating_rules>
These rules override convenience in every phase.

1. EVIDENCE OR IT DIDN'T HAPPEN. Before reporting progress, audit each claim
   against a tool result from this session: build output, test output, a diff,
   a grep sweep with counts, runtime inspection. Never say "fixed," "secure,"
   "hardened," "native," "optimized," or "integrated" without evidence. Work
   not yet verified is labeled UNVERIFIED, explicitly. If tests fail, say so
   with the output. Do not hide brokenness — undocumented breakage is the one
   unforgivable state.

2. READ THE CODE, NOT THE COMMENTS. Plans 1–3 claim completion; trust nothing.
   Never make claims about code you have not opened. Do not accept "done"
   checkboxes unless the app actually supports the claim.

3. ROOT CAUSE ONLY. No suppressions as fixes: no new @unchecked Sendable,
   nonisolated(unsafe), try?, force casts, or .unwrap()/.expect() in reachable
   Rust paths, no warning silencing, no shims that merely quiet errors, no
   hard-coding behavior to satisfy tests — unless accompanied by a written
   justification comment at the site plus a DECISIONS.md entry. Prefer deleting
   code to adding code. Dead code, dead flags, and dead branches get removed.

4. EXHAUSTIVE ENUMERATION. When auditing a pattern (every Task {}, every
   message handler, every #if DEBUG, every unsafe block), enumerate every
   instance with rg sweeps and report the count, not a sampling.

5. GIT SAFETY. First action in the repo is git status; record branch, worktree
   state, and any uncommitted human work before touching anything. Never use
   git reset --hard, force pushes, --no-verify, destructive cleanup, mass
   deletion, or broad reformatting across unrelated files. Never overwrite or
   discard uncommitted human work. Never delete or weaken a test to make a
   phase pass; if a test is wrong, fix it with written justification.

6. STOP THE LINE — WITH CLASSIFICATION. If the app does not build or tests are
   red, classify each failure first: pre-existing app defect, environment/
   toolchain issue, signing/provisioning issue, dependency issue, regression
   caused by this session, or unknown. App defects and session regressions are
   stop-the-line: fixing them is the only permitted work until green.
   Environment/signing issues you cannot fix locally get isolated, documented,
   and worked around explicitly — never silently ignored. Brokenness never
   crosses a phase boundary undocumented.

7. NO OVER-ENGINEERING. Don't add features, abstractions, or configurability
   beyond what the task requires. Validate at system boundaries (user input,
   web content, FFI, network, subprocess); trust internal invariants. Prefer
   small, correct, testable changes over giant rewrites — but do not preserve
   bad architecture just because it exists.

8. BANNED RATIONALIZATIONS. Never leave code in a state justified by any of
   these: "it probably works" / "this warning is harmless" (without proof) /
   "this is temporary" (without a tracked follow-up) / "it's secure because
   it's local" / "the bridge only receives trusted input" / "the user won't
   click that" / "the feature is off but only hidden visually" / "the plan
   said it was done" / "we can clean this later" (on security-sensitive code).

9. AUTONOMY AND CHECKPOINTS. Work autonomously. Pause for me only when the
   work genuinely requires it: a destructive or irreversible action, missing
   credentials, a real scope change, or a product decision with no clearly
   better option. Defined checkpoints: end of Phase 0 (findings + plan for
   Phases 1–2), end of Phase 3 (concurrency migration summary), end of
   Phase 10 (UI direction sign-off with screenshots). Otherwise proceed.
   Before ending any turn, check your last paragraph: if it is a plan, a
   question you can answer yourself, or a promise about work not yet done, do
   that work now.

10. STATE ON DISK. Maintain HARDENING_AUDIT.md as the running tracker
    (findings with IDs and severities, files touched, commands run, results,
    verification status — updated as you go, not at the end), plus PROGRESS.md
    (phase, work done, evidence pointers, next step) and LESSONS.md
    (corrections, confirmed approaches, codebase gotchas, one lesson per
    entry). Update before any long operation and at every phase boundary. You
    have ample context; do not stop, summarize, or suggest a new session on
    account of context limits — save state and continue.

11. SUBAGENT STRATEGY. Delegate independent read-only audit sweeps to parallel
    subagents and keep working while they run. Natural slices: (a) security /
    threat model / entitlements, (b) Swift concurrency, (c) Rust / Goose /
    tool surface / any local server, (d) WebView / bridge / JS-CSS-HTML,
    (e) native UX / cohesion, (f) performance / Metal. Require evidence from
    each. At the end of each implementation phase, dispatch a fresh-context
    verifier subagent that sees only the diff and that phase's exit criteria
    and tries to prove the fixes incomplete; fix the gaps and re-verify before
    moving on.

12. FINAL SUMMARIES ARE FOR A READER WHO SAW NONE OF IT. Between tool calls,
    terse shorthand is fine. Phase reports and the final report open with the
    outcome in plain sentences, then evidence. Every file, commit, and flag
    named in its own clause.
</operating_rules>

<phase_0 name="Ground truth">
Goal: establish what is actually true about the app today.
- git status; record branch, worktree, uncommitted work. Record Xcode and
  Swift toolchain versions. Target Swift 6.2+ semantics on the current stable
  toolchain; note (don't chase) anything newer available.
- Map build systems: Xcode workspace/projects/schemes, SwiftPM manifests,
  Cargo workspace and crates, JS tooling and scripts, Metal shader files and
  asset pipeline, WebView configuration points, entitlements, Info.plist,
  signing, existing CI config, test/lint/build commands.
- Build debug AND release for the Swift app; capture the complete warning
  inventory to a file. cargo fmt --check, cargo clippy --all-targets
  --all-features, cargo test --workspace, cargo audit if available; capture
  output. Run the safest baseline checks before editing anything.
- Run the full test suites (Swift + Rust). Record pass/fail counts. If red,
  classify per Rule 6 and act accordingly.
- Write ARCHITECTURE_BASELINE.md: module/target graph; actor topology (what is
  MainActor, what is nonisolated, what actors exist); every FFI surface
  (UniFFI functions, callbacks, streams); the complete JS bridge catalog
  (every WKScriptMessageHandler / WKScriptMessageHandlerWithReply name with
  payload shape and direction); every WKWebView instance and its
  configuration; every entitlement with its stated reason; privacy strings;
  every network endpoint the app or Rust core contacts; ANY local server,
  socket, or listening port opened by the Rust side (this is critical — find
  it if it exists); every feature flag and compilation condition.
- One manual end-to-end smoke pass (launch, graph, meeting, arXiv, browser,
  agent round-trip): record what works, what's broken, what's half-wired.
Exit criteria: baseline captured, ARCHITECTURE_BASELINE.md complete, smoke
results recorded, failures classified. CHECKPOINT: findings + Phase 1–2 plan.
</phase_0>

<phase_1 name="Forensic audit of Plans 1–3">
Goal: verify claimed work against reality.
- Find every artifact connected to Plans 1–3: docs, TODOs, commits, branches,
  checklists. For each plan: what it claimed, what files changed, what
  behavior exists now, what tests prove it, what is incomplete, brittle,
  duplicated, or overfit, and whether it introduced security risk, UI
  inconsistency, debt, or concurrency bugs.
- Classify every claimed deliverable VERIFIED / PARTIAL / MISSING / REGRESSED
  with file:line evidence. Apply the thermo-nuclear skill to the code these
  plans touched.
- Patch obvious breakage from plan work now; everything else becomes a tracked
  work item assigned to the owning phase below. Remove or consolidate dead
  code, fake integrations, and duplicate abstractions the plans left behind,
  safely.
Exit criteria: PLAN_AUDIT.md with the classification table and evidence.
</phase_1>

<phase_2 name="Threat model and trust boundaries">
Goal: an explicit map every later phase references.
- Write THREAT_MODEL.md covering the assets: meeting audio/transcripts/notes,
  arXiv queries/cached papers/downloads, browser history/cookies/page content,
  agent commands and tool access, bridge messages, Swift↔Rust FFI traffic,
  local files and security-scoped bookmarks, secrets/tokens/env vars, logs and
  crash data, entitlements and privacy prompts.
- Enumerate every trust boundary with an ID (B1, B2, …): web UI ↔ native
  bridge; browser webview ↔ everything; page/arXiv/transcript content ↔ agent;
  Swift ↔ Rust FFI; agent ↔ tools; agent/app ↔ network; app ↔ filesystem; any
  local server ↔ local processes and webviews. For each: trusted side,
  untrusted side, data crossing, allowed operations, denied operations,
  validation required, logging/redaction rules, and how it will be verified
  (test, runtime guard, or documented manual check).
- From here on, every security finding and fix in HARDENING_AUDIT.md
  references a boundary ID.
Exit criteria: THREAT_MODEL.md complete; boundary IDs in use.
</phase_2>

<phase_3 name="Swift 6.2 strict concurrency">
Goal: Swift 6 language mode, strict concurrency complete, zero concurrency
diagnostics, on every Swift target — deliberately per target, not globally by
accident.
- Enable per target: Swift 6 language mode; Approachable Concurrency
  (SWIFT_APPROACHABLE_CONCURRENCY — brings NonisolatedNonsendingByDefault
  [SE-0461] and InferIsolatedConformances [SE-0470]); Default Actor Isolation
  = MainActor (SWIFT_DEFAULT_ACTOR_ISOLATION) for app/UI targets. For non-UI
  compute modules, decide per module and record in DECISIONS.md. MainActor
  isolation must be intentional, never a band-aid: heavy work is never moved
  onto MainActor just to silence diagnostics, and no DispatchQueue.main.async
  patches over isolation errors.
- UNIFFI GOTCHA (known upstream issue): uniffi-bindgen-generated Swift is FFI
  plumbing and must not inherit MainActor default isolation — it will fail to
  compile or mis-isolate. Either compile generated bindings in a target with
  nonisolated default isolation, or post-process the generated file to prepend
  `nonisolated` to file-level declarations as a deterministic build step.
- Sweep and fix, exhaustively (counts required):
  * Every `Task {}` / `Task.detached`: inherited isolation, cancellation
    handling, whether errors are observed (no silently swallowed throwing
    tasks), lifetime ownership. Detached tasks need written justification,
    priority, and cancellation. Prefer structured concurrency.
  * Every `@unchecked Sendable` and `nonisolated(unsafe)`: replace with real
    isolation, an actor, immutable Sendable value types, or Mutex from the
    Synchronization framework; anything remaining gets a justification.
  * Every DispatchQueue/lock coexisting with actors: migrate or justify.
  * Every continuation: prove single-resume and no leak paths. Every
    AsyncStream: explicit buffering policy and termination.
  * Shared mutable state, globals, singletons, NotificationCenter callbacks,
    timers, Combine/Observation pipelines: audit isolation of each.
  * Main-thread blocking: no file IO, network, parsing, PDF processing, arXiv
    fetching, Rust calls, or Metal prep synchronously on the main actor.
    Compute that must leave the main actor is marked @concurrent
    deliberately; everything else stays caller-isolated.
- AppKit rule: all NSView/NSWindow/NSViewController state is MainActor. Audit
  every delegate/callback for the context it actually arrives on
  (WKNavigation delegates arrive on main; CVDisplayLink, audio, and Rust-side
  callbacks do not) and route hops explicitly.
- Metal render path: drawable acquisition/present ordering verified; uniform
  and vertex buffers use a ring (triple buffering) or are actor-owned — no
  shared mutable frame state. Prefer NSView.displayLink (macOS 14+) over raw
  CVDisplayLink where it simplifies isolation; render loop pauses when the
  window is occluded/hidden.
- Verification: zero concurrency warnings (treat concurrency diagnostics as
  errors); full test suite under Thread Sanitizer, clean; a targeted TSan run
  exercising graph interaction + agent streaming simultaneously.
Exit criteria: gates green. CHECKPOINT: concurrency migration summary.
</phase_3>

<phase_4 name="Platform security — sandbox, entitlements, secrets, network">
- Entitlements: least privilege, deny by default. Justify every remaining
  entitlement in APP_REVIEW_NOTES.md; remove the rest, including temporary
  exceptions unless still absolutely required and documented. No mic/audio
  entitlement in builds where meetings don't ship. App Sandbox on; Hardened
  Runtime with no allow-unsigned-executable-memory and no
  disable-library-validation — if the Rust core currently forces either,
  prefer static linking to eliminate it.
- Permissions UX: never request a permission before the user takes the action
  that needs it; privacy strings accurate and human.
- Secrets: Keychain only. Sweep for tokens/keys in UserDefaults, plists,
  localStorage, logs, print statements, crash metadata, environment handling.
  os.Logger privacy: .private for user-derived data; no print() in release
  paths.
- Network: ATS strict, https only; explicit timeouts and bounded retries on
  every request (Swift and Rust); streaming requests cancel cleanly on view
  teardown and app quit.
- Filesystem: writes confined to the container; security-scoped bookmark
  start/stop paired; temp files cleaned; restrictive permissions on user data.
- MAS compliance re-check against existing docs: no private APIs; encryption
  export answer (ITSAppUsesNonExemptEncryption) correct.
Exit criteria: entitlement diff + justifications; secret sweep with counts;
network audit table (endpoint, TLS, timeout, retry, cancel).
</phase_4>

<phase_5 name="WKWebView and JS bridge hardening">
Treat the web layer as hostile by default, even the local HTML.
- Bridge (boundary B1): enumerate every message handler from the Phase 0
  catalog. One versioned envelope { v, type, id, payload }, validated
  natively with strict Codable decoding: unknown types rejected, payloads
  size-limited, every field validated, origin/content-world checked.
  Request/response uses WKScriptMessageHandlerWithReply; streaming pushes use
  callAsyncJavaScript with arguments passed as structured values — never
  string interpolation into JS source (interpolation is an injection path).
  Bridge APIs are minimal, typed, and permissioned; deny by default.
- Isolation: injected scripts and the bridge live in a dedicated
  WKContentWorld; page-world JS cannot reach the bridge namespace.
- App UI webview: loadFileURL(_:allowingReadAccessTo:) scoped to the UI
  bundle directory only; CSP on UI documents (default-src 'self'; no
  unsafe-inline, no eval/new Function, no remote CDNs — bundle all assets);
  javaScriptCanOpenWindowsAutomatically off; isInspectable false in release
  (any debug enablement behind #if DEBUG); navigation delegate denies by
  default; external links open via NSWorkspace after URL validation; unknown
  schemes blocked. No secrets in localStorage/sessionStorage.
- THE BROWSER IS A DIFFERENT TRUST DOMAIN (boundary B2). Remote pages never
  share a WKWebViewConfiguration, process pool, website data store, user
  content controller, or any message handler with the app UI webview. The
  browsing webview gets: zero bridge handlers, its own (non-persistent or
  clearly scoped) data store, explicit navigation policy, deliberate popup
  and download handling (explicit, user-controlled, path-safe — or denied),
  and no file URL access. Any HTML/markdown the app itself renders from
  fetched content (arXiv abstracts, meeting notes) is sanitized before
  display. Verify isolation by construction and by test.
Exit criteria: bridge catalog 100% schema-validated; tests proving page JS
cannot reach the bridge and the browser webview has no handlers; release
config proves isInspectable off.
</phase_5>

<phase_6 name="Rust / Goose core hardening">
- Lints and supply chain: clippy -D warnings (pedantic where sane); cargo
  audit clean; cargo deny (advisories, licenses, duplicate bans) with a
  committed deny.toml; Cargo.lock committed; flag any dependency whose
  build.rs does network or surprising work.
- Panic policy: no unwrap/expect/panic!/todo!/unimplemented! on runtime-
  reachable paths. Typed errors (thiserror) surfaced across the FFI as
  structured errors — not strings. A panic in the Rust core must not take
  down the app: verify boundary behavior for panics and make it defined.
- unsafe: enumerate every unsafe block; each gets a // SAFETY: invariant
  comment or a rewrite; keep unsafe tiny and wrapped in safe abstractions;
  #![forbid(unsafe_code)] on crates needing none.
- All FFI and web-UI input is untrusted: length limits, UTF-8 validation,
  typed schema validation on every IPC message; file-path inputs canonicalize
  + prefix-check against allowed roots (no traversal).
- LOCAL SERVER RULES (if the Goose side opens ANY listening socket or HTTP/WS
  server — find out in Phase 0 and treat this as boundary B8): bind loopback
  only; require an unguessable per-launch capability token on every request
  (a webview or any local process must not be able to hit privileged
  endpoints unauthenticated); no fixed well-known port assumptions; validate
  Origin on anything a browser context could reach; document why the server
  exists at all versus in-process FFI, and whether it is MAS-sandbox
  compatible. If no server exists, record that as a verified fact.
- SUBPROCESSES: avoid shell invocation entirely; structured Command argument
  vectors only; never pass untrusted strings into commands; sanitize the
  environment before spawning; timeouts and kill-on-drop.
- Async runtime: every spawned task has an owner and a shutdown path;
  graceful drain on app quit; bounded channels with explicit backpressure;
  timeouts on all network I/O; resource limits on tool execution.
- AGENT TOOL SURFACE (boundary B3 — the enterprise-trust core): inventory
  every tool the Goose runtime can execute. For each: enabled?, what it can
  touch, MAS-sandbox compatibility, and what gates it. Deny by default —
  allow only specific tools/actions. File tools rooted to allowed
  directories; shell/exec-style tools disabled in the shipping
  configuration; tool network access allowlisted. Content originating from
  the browser, arXiv, or meeting transcripts is UNTRUSTED INPUT to the
  agent: delimited as data in prompts, and unable to trigger tool execution
  or config changes without an explicit user confirmation step. Add a test:
  a hostile instruction embedded in fetched page text does not cause a tool
  call.
- Secrets in Rust: zeroize key material; no Debug derives printing tokens;
  transcripts and logs redact credentials; structured logging with redaction.
Exit criteria: clippy/audit/deny green; unsafe and panic inventories at zero
unjustified; local-server status verified either way; tool-surface table
written; prompt-injection test passing; tests added around IPC parsing,
denied actions, command validation, and shutdown.
</phase_6>

<phase_7 name="Conditional compilation and feature-flag hygiene">
Both directions, exhaustively.
- Inventory every #if DEBUG / #if os / custom compilation condition (Swift),
  every cfg/feature (Rust), and every runtime toggle. For each flag document:
  source of truth (exactly one — no duplicates), default value, ON behavior,
  OFF behavior, background tasks, network calls, permissions requested,
  storage/cache, entitlements implicated, tests, files affected.
- Prove OFF removes ALL of it: UI entry points, menu items, shortcuts,
  routes, bridge methods, background workers, scheduled tasks, network
  calls, storage, logs, permission prompts. "Hidden visually but still
  running" is a finding. Prove ON is complete: no half-wired features.
- Kill unconditional debug leftovers reachable in release: print/NSLog/dump,
  mock data paths, test hooks, debug endpoints, sample content. Remove stale
  conditionals that can never be true; remove provably unused code; if
  removal is risky, quarantine behind a tracked TODO with evidence.
- Run `strings` on the release binary; grep for localhost, dev hosts, test
  tokens, internal URLs; explain anything found.
- Rust: features are additive; default feature set contains no debug
  tooling; enable check-cfg so cfg typos fail the build.
Exit criteria: flag inventory table with ON/OFF proof per flag; release-binary
strings sweep clean or explained.
</phase_7>

<phase_8 name="Native-first pass">
- Inventory every UI surface: AppKit or web, with a keep/convert decision and
  rationale per surface. Decision rule: application chrome and OS integration
  go native — window/toolbar (NSToolbar), menus and key equivalents, Settings
  window, open/save panels, alerts, contextual menus, drag & drop, sharing,
  search fields, focus and the responder chain. Rendered/document content may
  remain web where that is genuinely the better or safer architecture
  (sandboxed browser/preview surfaces qualify), but must behave natively:
  standard shortcuts, full keyboard access, correct first-responder behavior.
  Do not convert blindly; convert where native improves trust, accessibility,
  performance, or platform feel.
- For everything that remains web, wire native behaviors through the hardened
  bridge rather than reimplementing chrome in HTML. No duplicate sidebars,
  panels, settings, or empty states between web and native.
- System integration: window restoration; Dark Mode driven by NSAppearance
  with an effectiveAppearance observer injecting theme state into the
  webviews; accessibility pass — VoiceOver labels on custom views, keyboard
  navigation unbroken everywhere, and a keyboard/text alternative for the
  Metal graph view (full accessibility of a custom Metal view may be a
  documented follow-up, but navigation must not dead-end for VoiceOver
  users).
Exit criteria: surface inventory with decisions + rationale; conversions
done; accessibility findings fixed or documented as follow-ups.
</phase_8>

<phase_9 name="Feature integration — meetings, arXiv, browser">
Goal: three real features inside one product model, not three demos.
- For each: define the end-to-end user story and make it work — entry point
  in the unified navigation, loading/empty/error states, cancellation, and
  where its output lands in the knowledge graph / agent context.
- Meetings: permission requested only at the moment of use, with a real
  denial UX; the user ALWAYS knows when recording/listening is active
  (visible indicator, correct state on stop/cancel); start/stop lifecycle
  leaves no orphaned audio sessions; failed transcription never silently
  loses the raw audio — warn and preserve; transcripts/recordings stored
  in-container with a visible way to delete them; meeting data never leaks
  into logs; if system-audio capture is involved, verify the current macOS
  API + entitlement/TCC requirements before relying on it.
- arXiv: respect arXiv's published API etiquette (verify current terms; as of
  now that means conservative serial request scheduling with multi-second
  spacing, no parallel hammering); retry/backoff; cache metadata; defensive
  parsing of fetched XML/PDF (untrusted); pagination and duplicate handling;
  prefer linking to abstract pages unless the user explicitly downloads;
  background fetch cancellable; results flow into the graph and can be
  saved/opened/sent to the browser or notes.
- Browser: built on the isolated webview from Phase 5; the user can always
  tell web content from native app content; page content flows to the agent
  only through the untrusted-content pipeline from Phase 6; simple native
  chrome (back/forward/URL field), safe external handoff to the default
  browser; the browser serves the app's real workflows, not a half-integrated
  demo.
- Shell cohesion: one navigation model, one state store pattern, shared
  empty/error components, no orphan windows, no feature-specific one-off
  styling.
Exit criteria: scripted end-to-end walkthrough of each feature performed and
logged with evidence; a hostile-page prompt-injection walkthrough logged.
</phase_9>

<phase_10 name="UI system — minimal pixel-art, theme-aware">
- One source of truth for design tokens (colors, spacing, type scale, radii)
  that generates BOTH the Swift constants and the CSS custom properties — no
  hand-duplicated values between AppKit and web surfaces.
- Pixel art is a restrained design language, not a gimmick: iconography,
  texture, selected display type — while body and dense text stay in a highly
  legible face. Select a bitmap-style font whose license permits bundled app
  distribution (verify the license text before bundling; candidates to
  evaluate: Departure Mono, Silkscreen, Pixelify Sans); register at launch;
  use from both NSFont and @font-face.
- Crispness: integer pixel alignment for pixel-styled elements;
  image-rendering: pixelated for pixel assets on the web side; check at 1x
  and 2x backing scale.
- Theme-aware: semantic tokens only (no raw hex at call sites); light, dark,
  and increased-contrast respected; NSAppearance changes propagate live to
  webviews via the Phase 8 injection; system accent respected where sensible.
- Minimalism: reduce chrome, consistent spacing rhythm, one accent used
  sparingly; empty states and errors clear and considered. Distinctive, not
  generic; reduce visual fragmentation between meetings, arXiv, browser, and
  agent surfaces.
Exit criteria: token pipeline in place; both themes screenshotted across all
major surfaces (attach to PROGRESS.md); font licensing recorded. CHECKPOINT:
UI direction sign-off before mass application.
</phase_10>

<phase_11 name="Performance">
- Instruments passes with recorded numbers: Time Profiler on launch (target:
  first window < 1s on the dev machine) and on graph interaction;
  Allocations/Leaks (zero leaks across a full feature walkthrough); hang
  detection (no main-thread stall > 100ms in normal use); Metal frame time
  inside budget at the display's refresh (8.3ms at 120Hz) during force-layout
  + streaming.
- Pipeline states and buffers reused; no shader compilation or expensive
  Metal allocation on hot paths; no needless WebView reloads; timers and
  render loops stop when windows/features are inactive; no background
  polling; display link pauses when hidden; clean shutdown.
- Fix the top findings; record before/after numbers. Anything requiring
  deeper manual profiling gets documented with the exact Instruments recipe.
Exit criteria: PERFORMANCE.md with measured numbers and deltas.
</phase_11>

<phase_12 name="Final verification and report">
- Gates, all green with output captured: clean release build with zero
  concurrency diagnostics and no unexplained warnings; Swift + Rust test
  suites pass; TSan suite run clean; cargo audit/deny/clippy clean;
  release-binary strings sweep clean; scripted end-to-end smoke of all three
  features passes; feature-off behavior spot-checked.
- Dispatch a final fresh-context verifier subagent with only this
  directive's exit criteria and the cumulative diff; it tries to prove the
  work incomplete; close the gaps it finds.
- Write ENTERPRISE_AUDIT_REPORT.md: outcome in plain prose first; findings
  table (ID, severity, boundary ID, area, file:line, description, failure
  scenario, fix commit, verification evidence); the Plan 1–3 audit (what was
  valid, incomplete, fixed, remaining); residual risks and accepted
  trade-offs; App Review risk notes; a manual QA checklist; follow-ups that
  are genuinely out of scope or blocked; and NEXT BEST MOVE — the single most
  important follow-up after this run.
</phase_12>

<severity_rubric>
CRITICAL: exploitable across a trust boundary (web content → native / agent /
filesystem; unauthenticated privileged local API; arbitrary command
execution), data loss, credential exposure, sandbox escape vector, crash on a
mainline path. Fix immediately, in the phase where found.
HIGH: data race confirmed or strongly indicated, panic reachable in the Rust
core, unvalidated bridge/IPC input, feature flag leaking disabled
functionality, broad entitlement without justification.
MEDIUM: reliability defects, missing cancellation/timeout, main-thread
stalls, accessibility blockers, unsafe download handling.
LOW: hygiene, dead code, style-with-consequences.
Every finding gets an ID, references a boundary ID where applicable, and
appears in the final table even if fixed on sight.
</severity_rubric>

<non_goals>
No framework migration: AppKit stays AppKit — no SwiftUI rewrites or
conversions. No new dependencies without a DECISIONS.md entry. No breaking
MAS sandbox compliance. No silent behavior changes — anything user-visible
gets noted. No speculative features. No exploit or attack tooling of any
kind. Keep the product vision intact: cohesive, theme-aware, minimal
pixel-art-inspired macOS app with useful meeting, arXiv, browser, and agent
features.
</non_goals>

<definition_of_done>
Every phase's exit criteria met with captured evidence; HARDENING_AUDIT.md,
PLAN_AUDIT.md, THREAT_MODEL.md, ARCHITECTURE_BASELINE.md, DECISIONS.md,
PERFORMANCE.md, and ENTERPRISE_AUDIT_REPORT.md exist and are current; the app
builds and passes everything from a clean checkout following documented
steps; no known critical breakage is left unpatched or undocumented; and the
final report contains nothing labeled UNVERIFIED without an explanation and a
plan.
</definition_of_done>

---

# APPENDIX A — INDEPENDENT VERIFIER PROMPT
# (Run this in a FRESH session after the main run completes. Paste as-is.)

You are the independent verifier for a hardening run that was just completed
on this repository by a previous agent. Do not assume the previous
implementation is correct — assume it is incomplete until proven otherwise.
Your job is to find what the previous pass missed, overclaimed, or quietly
weakened. Prefer brutal accuracy over politeness. This is defensive review of
my own app: describe failure scenarios plainly; produce no exploit tooling.

Read first: EPISTEMOS_HARDENING_DIRECTIVE.md (the contract the run was held
to), HARDENING_AUDIT.md, ENTERPRISE_AUDIT_REPORT.md, THREAT_MODEL.md,
PLAN_AUDIT.md, DECISIONS.md, the full git diff of the run, and the changed
Swift, Rust, JS/CSS/HTML, entitlement, Info.plist, build-setting, and flag
files. Then verify — with fresh tool evidence, not by trusting the report:

1. RE-RUN THE GATES YOURSELF. Release build (capture warnings), Swift + Rust
   test suites, a TSan pass, cargo clippy/audit/deny, the release-binary
   strings sweep, and the feature-off spot checks. A claim without a
   reproduced result is unverified.
2. Concurrency hardening is real, not annotation theater: MainActor isolation
   is deliberate; no heavy work was parked on the main actor or wrapped in
   DispatchQueue.main.async to silence diagnostics; remaining
   @unchecked Sendable / nonisolated(unsafe) / detached tasks each have a
   justification that actually holds; UniFFI-generated bindings are correctly
   nonisolated by a deterministic build step.
3. The bridge and webviews: page-world JS cannot reach the bridge; every
   handler schema-validates and size-limits input; the browser webview shares
   no configuration, data store, or handlers with the app UI; isInspectable
   is off in release; no interpolated JS injection paths.
4. Rust/Goose boundaries are safe by default: no reachable panics or
   unjustified unsafe; any local server is loopback-bound and
   capability-token gated (or verified absent); subprocesses use argument
   vectors with sanitized environments; the agent tool surface is
   deny-by-default and the prompt-injection test genuinely exercises hostile
   content reaching the agent.
5. Disabled features truly disable UI, routes, background tasks, network,
   storage, permissions, entitlements, and bridge methods — not just hidden
   visually.
6. No tests were deleted, weakened, or hard-coded around to make gates pass;
   no new secrets, broad entitlements, insecure logging, or unsafe command
   execution were introduced by the run itself.
7. The Plan 1–3 audit findings were each handled or explicitly documented;
   meetings, arXiv, and browser actually complete their end-to-end stories;
   native/AppKit conversion choices are justified and no SwiftUI migrations
   snuck in.

Return, in this order: verified claims (with the evidence you reproduced);
false or weak claims; remaining high-risk issues by severity with boundary
IDs and file:line; specific files/functions to rework; tests still missing;
and the top 5 patches that should happen next. Append your findings to
HARDENING_AUDIT.md under a "Independent Verification" heading. Make edits
only when the issue is small, obvious, and safe; everything else is a
documented finding.
