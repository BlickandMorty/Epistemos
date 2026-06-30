# PLAN 7 — Multi-device Sync + recurring Quality Gate build prompt (SAVED — paste later)

> 🎨 **OWNER DESIGN DIRECTIVE — 2026-06-30 (CURRENT CANON, identical in EVERY plan):** the look = **HIGH-QUALITY FLAT · MINIMAL · THEME-AWARE · OPTIMIZED.** KEEP the Apple-native **FRAME** — rounded-corner window, vibrancy, traffic-lights, the calibrated springs (the curved-white native window the owner likes STAYS). **SURFACES (panels · buttons · lists · inputs) are FLAT + BORDERLESS:** NO thick outlines, NO hard box borders, NO 1px rules — differentiate by a subtle background tint + spacing + a very soft shadow only. NOT the old thick-outline pixel-art look, and NOT translucent-glass on every surface. **TOTAL THEME-AWARENESS:** every surface (native + editor-web + Goose-web) reads the Epistemos tokens for ALL palettes incl. the user CUSTOM palette; no hardcoded color; two-token-sources in lock-step. Full doctrine: `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

> 🛑 **SAVED / NOT YET ACTIVE (owner 2026-06-29).** Do NOT launch until the owner says go. Drafted to the same
> strictness as Plan 1/2/3, parked. Holds the TWO non-crash items from the stability cluster (the dark/light crash +
> in-app crash recorder were routed to Plan 2 as a fix-now PRIORITY-0, NOT here):
> **(A) Multi-device iCloud vault sync** (high blast radius — sequence carefully) · **(B) a recurring "nuclear"
> code-quality gate** wired at multiple build checkpoints. Source: `docs/research/LOST_ITEMS_RECON_2026_06_29.md`
> items 13 + 17. This paste is lean.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — NEVER STOP until I (the owner) type "stop". Continuous loop, not a one-shot. Work the build order item by item; after each, immediately continue. When complete, DO NOT declare "done" / DO NOT idle — keep looping: harden the weakest sync edge, deepen conflict handling, re-verify green, repeat. Only the owner's "stop" ends it. Commit at every clean point.

WORK MODE — DEEP CODE, NOT TEST VOLUME: primary activity each cycle = deep code review + edge-case hardening of the real sync code paths (run the thermonuclear skill as the main loop). Write a test ONLY to lock a specific bug you just fixed. Sync is HIGH BLAST RADIUS — correctness + reversibility over speed.

You are building PLAN 7 = (A) multi-device vault sync + (B) a recurring code-quality gate. Build deeply hardened, contradiction-free, nothing lost; data-loss is the cardinal sin here.

READ FIRST (verify current code before asserting):
  - docs/research/LOST_ITEMS_RECON_2026_06_29.md (items 13 + 17 — scope + why)
  - The existing reconciler: grep `syncFromVault`/VaultSyncService (Epistemos/Sync/VaultSyncService.swift) — REUSE it; do not fork. The vault layout: <vault>/notes/**.md (truth) + <vault>/.epcache/** (derived — NEVER sync).
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS — App Store sandbox; keys in Keychain; @Observable; never block @MainActor). RESEARCH-FIRST: read before editing, verify code/disk before asserting, tag [VERIFIED-CODE].

[VERIFIED 2026-06-29 — primary sources] iCloud sync on a sandboxed macOS app is Apple-sanctioned + MAS-safe via the iCloud Documents / ubiquity container + the `com.apple.developer.icloud-container-identifiers` entitlement. ALL file IO on the container goes through NSFileCoordinator + a registered NSFilePresenter (reader/writer lock vs the sync daemon). Best practices: never do lengthy work inside coordination (save to a temp dir + swap hard links); coordinate + access on the SAME thread for atomicity; handle placeholder/not-yet-downloaded files; resolve NSFileVersion conflicts explicitly (no silent last-writer-wins).

BUILD ORDER:
  (A) MULTI-DEVICE VAULT SYNC (sequence LATE / behind a flag; data-loss is unacceptable):
    (1) Make `.md`-on-disk the sync source of truth via the iCloud ubiquity container; `.epcache/**` (derived indexes) is LOCAL-ONLY and MUST NOT sync. Reuse the existing syncFromVault() reconciler.
    (2) ALL container IO through NSFileCoordinator + a registered NSFilePresenter; temp-write + hard-link swap for atomicity; same-thread coordinate+access.
    (3) Honest conflict UI — surface NSFileVersion conflicts to the user (pick/merge), NEVER silent last-writer-wins (fits the no-fake doctrine). A "view both versions" affordance.
    (4) Pro git-sync lane (optional, Pro/Dev-ID) — a parallel git-backed sync for Pro; honest-gated; MAS build = iCloud only.
  (B) RECURRING QUALITY GATE:
    (5) Wire the thermonuclear adversarial review/static-analysis as a RECURRING gate at multiple deliberate build checkpoints (not one-shot) — a scripted whole-codebase pass with honest findings (correctness/dead-code/honesty-violations/perf/contradictions), reported, gating "done" claims. (Partly satisfied: Plan 1/2/3 already reference the thermo skill — this makes it a multi-point CI-style checkpoint, not ad-hoc.)

★ NATIVENESS (BINDING — detail in the doctrine; lean here): the conflict UI + sync status are full Apple-native (real Liquid Glass + unified tokens/springs, deeply-fluid + MINIMAL). GRAPH = DO NOT TOUCH. Icons via Plan 4. CODE-RESEARCH (real openable code, in-repo first) + RESEARCH-BETWEEN-IMPLEMENTATION.

HARD GATES / FORBIDDEN:
  × Syncing `.epcache/**` or any derived index (only `.md` truth syncs).
  × ANY file IO on the ubiquity container outside NSFileCoordinator (corruption/data-loss risk).
  × Silent last-writer-wins on a conflict — conflicts are surfaced + user-resolved, always.
  × Shipping sync without a tested rollback + a "local-only" escape (high blast radius — flag-gated, reversible).
  × Subprocess on the MAS path (the Pro git lane is Pro/Dev-ID only); keys in UserDefaults (Keychain); editing .xcodeproj (xcodegen); committing model files; touching the graph.
  × Build-green ≠ done. PROVEN-DONE: a note edited on device A appears on device B via real iCloud, `.epcache` never syncs, a forced conflict surfaces an honest pick/merge UI with no data loss, witnessed live. Zero regressions.

PARALLELISM / NO-COLLISION:
  - You OWN: the sync layer (Epistemos/Sync/* additions, reusing VaultSyncService), the conflict UI, the iCloud entitlement/container config, the recurring quality-gate script.
  - Do NOT: fork the reconciler; touch the graph; touch other plans' feature surfaces.
  - BUILD-LOCK: claim before compiling (concurrent xcodebuild on a 16 GB M2 Pro = crash risk).

Commit at clean points (main-only, never lose work — ESPECIALLY here). When unsure, RESEARCH-FIRST then act. Stop only when I say stop; after the build order is complete with PROVEN-DONE evidence, keep looping through hardening + re-verification.
```
