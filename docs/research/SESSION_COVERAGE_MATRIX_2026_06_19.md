# SESSION COVERAGE MATRIX — every owner concern → plan + research + status (2026-06-19)

**Purpose (owner 2026-06-19):** *"deep check the ledgers + everything — all concerns, all queries, all intent
(verbatim), including before compactions; cross-reference so all queries/concerns are in the plan, researched,
hardened, and WILL be implemented 100%. No more forgetting. Always honest. Tests at the end."* This is the
definitive cross-reference. Authority = `OWNER_REQUESTS_LEDGER_2026_06_18.md` (verbatim items); research =
`SETTINGS_SIMPLIFICATION_HUB_2026_06_19.md` slices (file:line plans); read-first = the loop plan banner. Verified
this pass: ledger = 129 tracked items; every concern below confirmed present (grep-verified).

## A. PRE-COMPACTION intent (from the conversation summary's verbatim user-message list) — all CAPTURED
| # | Owner concern (pre-compaction, verbatim-sourced) | Ledger | Research | Status |
|---|---|---|---|---|
| 1 | MiniChat = mini-main-chat, 3 toggles, new session = native tab | MINICHAT item | (UI) | captured |
| 2 | Can't download/install models; install ALL; remove old; only foundation pkg works | MODEL DOWNLOAD/INSTALL BROKEN | SS-G | ✅ researched; build loop shipped install-CTA `a1dd7c6ed` + GGUF fix in progress |
| 3 | Keep ALL models incl hidden; advertise only canon | model-stack item | SS-G/SS-B | captured |
| 4 | Install ANY + select advertised stack in Settings | INSTALL-ANY | SS-G | captured |
| 5 | Model-selection deferred work / resume nuance | MODEL SELECTION | SS-Z | captured |
| 6 | Hermes → Swift/Rust port; bulk/online tools | HERMES item | SS-A (Hermes) | captured |
| 7 | Hermes must NOT overlap Osaurus | HERMES item | SS-A | captured |
| 8 | Skills/tools not working → repair | TOOLS/SKILLS BROKEN + REPAIR+HARDEN | SS-H | ✅ researched (keystone) |
| 9 | Qwen still broken | Qwen routing items | SS-Z/SS-W | ✅ root found (RuntimeRouter + template) |
| 10 | Logos B&W, model + settings + claude-code mascot in proper chats | LOGO item | (P6.1) | ✅ build loop shipped logos `9cd327e56`/`10d41e105` |
| 11 | Find as many real logos; audit ALL buttons | whole-app real-logo audit | — | ✅ logo audit subagent ran |
| 12 | Clone rebels' settings into my app, pixel-rescan, never delete/hide; apply to opencode/goose | CLONED-APP SETTINGS (override S3) | SS-A | ✅ researched |
| 13 | Balance: automate/simplify but don't break/hide | BALANCE sub-note | SS-A/SS-B | captured |
| 14 | DeerFlow placement / is it a whole program / add commands | DEERFLOW item | SS-A | captured |
| 15 | Skills/superpowers work in BOTH local+cloud chat; clones access native tools+skills + Anthropic/Vercel/Google | SKILLS/TOOLS WORK EVERYWHERE | SS-H + SS-I | ✅ researched |
| 16 | Simplify setup + settings + persistence; reduce complexity | settings-simplify items | SS-A/B/C/D/E/F | partial (C/D/E/F queued) |
| 17 | Browser-use (the github project) everywhere | BROWSER-USE | SS-J | ✅ researched |
| 18 | Voice models picker (Settings + chat TTS) | VOICE-MODEL PICKER | SS-K | ✅ researched |
| 19 | OpenAI skills + Cursor skills + OpenAI/Google/Claude agent on chat | PROVIDER AGENTS + OpenAI/Cursor | SS-L | ✅ researched |
| 20 | Obscura browser + agent-scraper + privacy | OBSCURA item | SS-M | ✅ researched |
| 21 | OpenAI open-source redaction model (PII) | SENSITIVE-INFO REDACTION | SS-N | ✅ researched |
| 22 | Living-Index / Lattice (sequenced LAST) | Living-Index item | (deferred last) | captured, sequenced last |
| 23 | OMNIBUS hard rule: everything researched→hardened→coded | OMNIBUS + ALL-RESEARCH-CODED | all | captured |

## B. THIS-THREAD intent — all CAPTURED
| # | Owner concern (this thread) | Ledger | Research | Status |
|---|---|---|---|---|
| 24 | Osaurus/Act right-side panel (context/plan/tools/skills/completed) | OSAURUS RIGHT-PANEL | — | captured |
| 25 | Provider-agent DEEP+HARDENED ("at what level is an agent created") | PROVIDER-AGENT DEEP | SS-L | ✅ answered (mode×provider, not a format) |
| 26 | Build loop use subagents | BUILD-LOOP SUBAGENTS | — | ✅ loop using subagents |
| 27 | Existing skills/tools REPAIR + HARDEN | REPAIR+HARDEN item | SS-H | ✅ researched |
| 28 | Voice premium-default + cloning + bitcrush + custom system voice | VOICE expand | SS-K + SS-Q | ✅ researched |
| 29 | Vulnerability research before add | VULN item | SS-S (queued) | captured |
| 30 | MAIN-ONLY no worktree, never lose work | MAIN-ONLY (hard) + memory | — | ✅ enforced |
| 31 | More robust loop hung-checks | (monitor discipline) | — | ✅ process-liveness check live |
| 32 | More local models LFM2/ternary/Bonsai | MORE LOCAL MODELS | SS-R (queued) | captured |
| 33 | Epdoc repair + Tolaria v2 (never touch TK2/Prose) | EPDOC + Tolaria | SS-O ✅ + SS-P/P+ (queued) | partial |
| 34 | All research coded + plan references all research + harden each cycle | ALL-RESEARCH-CODED | this matrix | ✅ enforced |
| 35 | PDF live native viewer + max Apple-native | PDF item | SS-T | ✅ researched |
| 36 | "Nuclear" aggressive code-checker, multi-checkpoint | NUCLEAR item | SS-V | ✅ identified (Cursor thermo-nuclear) |
| 37 | Dark/light mode crash | DARK/LIGHT item | SS-U | ✅ root found |
| 38 | Full Tolaria port + dynamic HTML-DOM + best-of-GitHub-MD + agent-MD | Tolaria-v2 expand | SS-P+ (queued) | captured |
| 39 | Recent crash + study ALL logs | CRASH item | SS-W | ✅ root found (GGUF template SIGABRT); build loop fixing |
| 40 | Chat message-bar still messy (think/pro/tools) | CHAT-BAR item | SS-X | ✅ root found |
| 41 | Hyperdynamic determinism / deterministic schema — local>cloud | HYPERDYNAMIC item | SS-Y | ✅ researched (masked processor + loop) |
| 42 | Per-model bespoke engineering framework | PER-MODEL item | SS-Z | ✅ researched |
| 43 | Clone marketplace non-clash; engineering CHAT-FIRST | CHAT-FIRST constraint | SS-Z | captured |
| 44 | Final coverage audit + loop-plan integrity | AUDIT item | this matrix + loop banner | ✅ done |
| 45 | (this msg) Deep cross-ref + GitHub per-model study + tests-at-end + "left unchanged by simplification" robustness | new items below | SS-Z+ (GitHub) | capturing now |

## C. NEW directives this message (owner 2026-06-19) — added to ledger + research
- **GITHUB PER-MODEL ENGINEERING STUDY** — study how many GitHub repos do per-model engineering for local+cloud
  (prompt formats, tool-call dialects, context handling, samplers, adapters); harvest proven techniques/patterns
  → extend SS-Z. (Local + remote research.) → ledger item + SS-Z extension.
- **TESTS AT THE END** — after each feature/cycle and at the end of all of it, real tests (Swift Testing compile-
  verify + `cargo test --lib` real execution + reasoned assertions); honest, no green-without-witness. → ledger.
- **"LEFT UNCHANGED BY SIMPLIFICATION" ROBUSTNESS AUDIT** — surfaces the simplification directives never touched
  remain un-hardened; sweep the app for surfaces that were skipped + make them robust (cross-ref SS-B sprawl,
  SS-X chat-bar, SS-U/SS-W crashes). → ledger item.

## D. Honesty + completeness guarantees
- **Nothing research-only:** every ✅-researched slice is a BUILD COMMITMENT (loop plan banner enforces). The
  build loop is already coding researched items (model-install CTA, logos, the SS-W/SS-Z GGUF crash fix in
  progress) — the research→code pipeline is live.
- **All research saved + referenced:** every slice is a committed doc under `docs/research/`, indexed in the hub +
  `DEEP_PLAN_AUDIT_HUB` + this matrix + the loop-plan read-first banner → no research is lost on compaction.
- **Compaction safety:** the ledger + research docs are on-disk + pushed to main; pre-compaction intent is
  captured in section A above (sourced from the conversation summary's verbatim user-message list). The loop
  re-reads them each pass → intent survives any compaction.
- **Priority by frequency (owner's hint):** (1) model install/run + per-model engineering (most-repeated);
  (2) skills/tools everywhere + repair/harden; (3) simplify UI/settings/chat-bar without breaking;
  (4) visible wins (logos✅, install-CTA✅); (5) editors; (6) native features. ALL coded — frequency only orders.

Cross-link: referenced from `SETTINGS_SIMPLIFICATION_HUB_2026_06_19.md` + the loop-plan read-first banner.

## E. NEW directive 2026-06-19 (re-issued /loop) — captured
- **MODEL CAPABILITY PROFILE = deeply-hardened COMBO + per-model deep profiles/descriptions + picker use-case
  copy (best advertised, every model deliberate).** → ledger item + **SS-AB** (definitive synthesis of SS-Z/AA/R).
  Status: ✅ researched (definitive spec authored); the build loop is ALREADY coding the foundation (llguidance
  dep added + per-model --chat-template/chatml fallback in progress).
- **Reiteration — all concerns/queries saved + everything since last update in plan.** ✅ confirmed: this matrix
  + the 130+ ledger items cover every concern incl. pre-compaction verbatim intent; nothing dropped.
