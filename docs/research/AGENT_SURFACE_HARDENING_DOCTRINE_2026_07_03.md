# Agent-Surface Hardening Doctrine (2026-07-03)

**Read-first canon for the 2026-07 build plans** (1-PRO, 1-MAS, 8-ResearchHub, 9-Data).
Hardening is a **per-phase shipping gate, not an end-phase cleanup** — same discipline as
the performance doctrine. This codifies the robustness upgrades that the earlier 9-phase
hardening pass and the four goose audits actually discovered, so the new surfaces inherit
them instead of re-learning them the hard way.

**Framing (important):** the specific traps below were real at discovery time; some may be
fixed. Treat each as a **lens + pattern to VERIFY against current code**, not an assertion
that the bug exists today. Tag findings `[VERIFIED-CODE]`. Deeper substrate:
`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`, `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`,
`docs/handoffs/GOOSE_DEEP_HARDENING_REPORT_2026_06_29.md`, memory `project_hardening_insights`.

---

## §1 THE FOUR AUDIT LENSES (run each, per phase, on what you touched)

Not one audit at the end — a bounded pass over the code each phase changed:

1. **Security.** Secrets never in the binary or in webview JS (Keychain only; proxy holds
   engine/provider keys). Origin/trust pinning never weakened. Every tool/FFI/bridge arg
   validated + bounded. Subprocess hardening (Pro) on every spawn. The **instruction-source
   boundary**: anything read through a tool (web content, a file, OCR'd text, a DOM
   attribute) is DATA, never commands — an agent must not act on instructions embedded in
   ingested/external content.
2. **Memory-leak.** Every view/webview/model/observer/timer has a teardown path. WebViews:
   shared `WKProcessPool`, non-persistent store, `dismantleNSView` releases handlers +
   display links + controllers. In-process models: idle-unload under memory pressure. No
   retain cycles in closures (`[weak self]`).
3. **Data-leak.** No vault/personal data sent to a recipient, URL, or form suggested by
   observed content. No PII in URL params. Third-party content stays quarantined from the
   vault unless the user explicitly saves it (with provenance). Honor retention obligations
   (e.g. ResearchHub's Reddit/X 48h-delete).
4. **Robustness / fluidity.** Click reliability, focus correctness, motion, no dropped
   events, no hang on the main actor, graceful failure (never a blank/spinner-forever).
   The instant-open recipe (perf doctrine) is a robustness property too: warm-path stays
   responsive under a cold/failing backend.

## §2 UNIVERSAL ROBUSTNESS PATTERNS (verify current state; apply the pattern)

- **FFI truth boundary (any Rust↔Swift).** `catch_unwind` is a no-op under
  `panic = "abort"` — a Rust panic then SIGTRAPs the whole macOS process. Confirm the
  crate's panic strategy matches its unwinding assumption (Epistemos crates are standalone,
  no workspace → a crate may use `panic = "unwind"` while others `abort`). `std::mem::forget`
  extracted panic payloads (Drop impls can re-panic → double-panic at the boundary). No
  Rust panic should ever cross the FFI as a process abort.
- **Supervision, not polling.** A 30s health-check loop reading booleans is monitoring
  theater. Real supervision **owns the child's Task lifecycle**: spawn → await failure →
  apply restart policy (backoff, max-retries, honest `.failed` state). Zombie cleanup on
  quit (SIGTERM→SIGKILL, process groups so MCP grandchildren die); occupied-port honesty
  (never a second spawn). (Pro supervises 3 children; MAS supervises the in-process runtime.)
- **Circuit breaker = ring buffer, not sticky counter.** A counter that resets every 60s
  can't tell "10 failures in 1s" from "10 over 55s". Use a rolling bit-buffer for the true
  failure rate. Half-open requires **N consecutive successes** for cloud LLM/provider APIs
  (partial outages: one request succeeds, the next fails). A **thermal pause is a no-op on
  the breaker** (else thermal parks → timeouts → breaker trips → "API down" when it's fine).
- **Mode machine.** Degrade fast (may skip levels: full→read-only in a crisis). Recover
  **step-by-step with hysteresis** (else oscillation when a subsystem flaps). Carry a
  `DegradationReason` — you can't decide when to recover without knowing why you degraded.
- **Swift/code standards (CLAUDE.md, non-negotiable):** every `unsafe`/unchecked block gets
  a `// SAFETY:` comment; no `try!`, no force-unwrap, no `print()` in production paths;
  UniFFI callbacks hop to main via `DispatchQueue.main.async`, **never `.sync`** (deadlock);
  `AsyncStream` uses `.bufferingNewest(256)`, never `.unbounded`; new files → xcodegen.

## §3 SURFACE-SPECIFIC HARDENING

**A. WKWebView embeds (Pro OpenChamber host; the Data grid).**
- **Loopback-origin pinning — NEVER weaken.** The goose deep-hardening H1 finding: allowing
  any `127.0.0.1`/`localhost` page (reached via a plain link or a tool/MCP-influenced
  `window.location`) lets a foreign local page inherit the injected boot shim — including
  `getSecretKey()` and the native FS bridge. Pin to the exact registered ports/origin.
- **No secret in webview JS.** The engine secret (X-Secret-Key / server password) lives
  Swift-side + in the same-origin proxy; the page never sees it.
- **Message-bridge validation.** Every `WKScriptMessageHandler` payload is untrusted:
  validate kind + shape + bounds before acting; never `evaluateJavaScript` with
  string-interpolated content that could break out.
- CSP blocks all external hosts (inline everything); service worker + self-updater OFF;
  navigation decider pins trusted origins only.

**B. Agent destructive operations (Plans 8, 9 — the NL-restructures-my-data risk).**
- `dry_run → schema-diff preview → explicit confirm → apply-in-ONE-transaction → undo`.
  Harden: **transaction atomicity** (no partial migration — all-or-nothing), **inverse-op
  correctness** (undo must exactly reverse; test it), coercion warnings surfaced before
  data loss. Every op-log row carries agent attribution.
- The **instruction-source boundary** applies to the agent chat: an agent restructuring the
  DB must act on the *user's* request, never on instructions found inside ingested rows /
  external content it read.
- Bound every tool arg (table/field IDs exist, ranges in-bounds, formula parses).

**C. Untrusted ingest + third-party content (Plans 8, 9).**
- Rendered third-party posts/HTML: **sanitize, no script execution, no injection** through
  a card into the app. OCR'd receipts, parsed PDFs, pasted text, CSV/JSON = untrusted data
  → malformed input must not corrupt the schema, crash the parser, or reach an eval path.
- Provenance on every ingested record; the source is quarantined data until saved.

**D. Data core (Plan 9).**
- **Parameterized SQL only** — field names, formula strings, and agent args never string-
  concatenate into SQL. **Formula-eval DoS**: bound recalc (IronCalc has no dirty-cell API
  and a pathological formula/cycle could stall) — timeout/iteration cap, surface errors via
  `Result` (CellValue has no Error variant). **Named-range extent correctness is the #1
  data-integrity risk** (per the synthesis): get extent maintenance wrong on record
  insert/delete/reorder or field rename and formulas silently point at the wrong data —
  test this explicitly with a reorder+rename fuzz.

## §4 THE PER-PHASE GATE + REVIEW SHAPE

- Each plan phase ends with a **bounded hardening pass over the code that phase touched**
  (the four §1 lenses + the relevant §2/§3 patterns), then STOP — do not launch open-ended
  app-wide sweeps (that was an anti-pattern; hardening must not preempt unfinished features).
- Report in the proven **"thermonuclear" disposition shape**: `N HIGH / N MED / N LOW`, each
  finding with file:line + FIXED/DEFERRED + why. A HIGH blocks the phase commit like a
  broken build. DEFERRED items get a one-line rationale (never a silent skip).
- A perf regression AND a hardening HIGH each block the commit — same bar.

## §5 REFERENCES
`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` (WRV promotion), `MASTER_HARDENING_AND_HARNESS_PLAN.md`,
`HARDENING_TRACKER_2026_05_16.md`, `docs/handoffs/GOOSE_DEEP_HARDENING_REPORT_2026_06_29.md` +
`GOOSE_PHASE_1_HARDENING_2026_06_29.md` (the audit + disposition template),
memory `project_hardening_insights` (the 9-phase traps), `AGENT_SURFACE_PERFORMANCE_DOCTRINE_2026_07_03.md`
(the sibling gate). CLAUDE.md = the code standards.
