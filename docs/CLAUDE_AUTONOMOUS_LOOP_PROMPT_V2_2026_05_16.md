# Claude Autonomous Loop Prompt V2 — 2026-05-16 (Ship-Driving, MAS + Pro Parallel)

**Purpose:** Self-contained `/loop` prompt that drives Epistemos toward **dual V1 ship targets** — Mac App Store submission (MAS bundle) AND Developer ID distribution (Pro bundle) — in parallel. Each iteration re-reads this prompt verbatim, executes ONE bounded slice, verifies, commits, schedules the next iter — until the **hard end state** is reached or the genuinely-auto-implementable queue exhausts.

**This supersedes** `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15.md` (V1 was doctrine-only; that queue closed at iter 72 of run 2026-05-16). V2 extends scope to production code with test-first discipline + MAS+Pro parallel ship discipline.

**Membership state (verified 2026-05-16):** Paid Apple Developer Program is **ACTIVE**. This unlocks: App Store Connect submission · Developer ID signing for Pro distribution · Notarization (`xcrun notarytool`) · Hardened Runtime relaxations for Pro entitlements (`cs.disable-library-validation` · `cs.allow-unsigned-executable-memory` · `cs.allow-jit` for WASMExecXPC Wasmtime) · Provisioning profiles for XPC services. Phase F XPC Mastery is now in V2 scope (was previously gated on this).

---

## §0. Hard end state (the loop's victory condition — DUAL TARGET)

The loop terminates **successfully** when ALL of these are true:

**Shared (both MAS + Pro targets):**
1. `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` has **zero** `Status: CONFIRMED` and **zero** `Status: TODO` entries that are V1-blocking (PATCHED PARTIAL allowed if explicitly scoped post-V1).
2. `docs/APP_ISSUES_AUTO_FIX.md` has zero `Status: Open` entries.
3. Phase E.1 of `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` reaches **5 consecutive Codex recursive passes with zero new V1 blockers added**.
4. `cargo test --manifest-path agent_core/Cargo.toml --lib` passes (baseline 1190 today, may grow).

**MAS path (App Store submission ready):**

5. `xcodebuild -scheme Epistemos -destination 'platform=macOS' -configuration Release build` passes for MAS profile.
6. `MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md §4.1` pre-submission verification commands all green.
7. Bundle binary audit clean: zero ScreenCaptureKit / AXorcist / `omega_ax` hits in MAS Release bundle (per `/tmp/epistemos_mas_tcc_binary_audit.log` shape).
8. `Epistemos.app/Contents/Resources/PrivacyInfo.xcprivacy` bundled + verified.
9. MAS entitlements at `Epistemos/Epistemos-AppStore.entitlements` carry exactly 6 keys (per §0 rule 7 of `MAS_COMPLETE_FUSION`): `app-sandbox=true` · `application-groups` · `cs.allow-jit=true` · `files.bookmarks.app-scope` · `files.user-selected.read-write` · `network.client`.

**Pro path (Developer ID distribution ready):**

10. `xcodebuild -scheme Epistemos -destination 'platform=macOS' -configuration Release build` passes for Pro profile (separate target).
11. Pro Developer ID code signing verifies: `codesign --verify --strict --deep Epistemos-Pro.app` returns 0.
12. Notarization passes: `xcrun notarytool submit Epistemos-Pro.dmg --wait` returns `status: Accepted`.
13. Staple verification: `xcrun stapler validate Epistemos-Pro.dmg` returns 0.
14. Phase F XPC Mastery services all wire end-to-end (VaultXPC · AgentXPC · ProviderXPC · WASMExecXPC + main shell coordination) per `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`.
15. Pro entitlements verified for each Hardened Runtime relaxation:
    - `WASMExecXPC.entitlements`: `cs.allow-jit + cs.disable-library-validation` (Wasmtime needs both)
    - Other Pro entitlements per `XPC_MASTERY_DOCTRINE` §X.1-X.5

When all 15 hold, surface to user: **"Loop terminal state reached — Epistemos MAS ready for App Store Connect submission per Phase E.3 AND Pro bundle ready for Developer ID distribution per Phase G."** Then omit ScheduleWakeup. The user clicks Submit and runs distribution; you don't.

The loop also terminates **gracefully** (not victory, but clean) when:
- The auto-implementable queue is genuinely exhausted AND every remaining open item is user-decision-gated. In that case, surface the exhaustion + list pending decisions + omit ScheduleWakeup.

**Partial-victory states (informational, not terminal):**
- All 9 MAS criteria green but Pro criteria still open → surface "MAS ready; Pro work in progress" + continue loop on Pro work.
- All Pro criteria green but MAS still open → surface "Pro ready; MAS work in progress" + continue loop on MAS work.
- Both halves green simultaneously → terminal state per §0 victory.

---

## §1. Identity + mode

You are Claude (Sonnet 4.5) running inside Claude Code at `/Users/jojo/Downloads/Epistemos` on branch `codex/research-snapshot-2026-05-08`.

Per memory: full iteration authorized; no parallel-edit session. Cadence: ~120s dynamic. Pick ONE high-leverage slice, work it, commit, schedule next.

**Boundary discipline (non-negotiable):**
- NEVER touch `~/Epistemos-RETRO/`, `src-tauri/`, or `~/meta-analytical-pfc/`.
- NEVER skip pre-commit hooks (`--no-verify`).
- NEVER amend; always create new commits.
- NEVER force-push.
- ALWAYS use HEREDOC for commit messages with `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer.

---

## §2. Mandatory reading order (every iteration, in this order)

1. **`docs/APP_ISSUES_AUTO_FIX.md`** — open runtime issues to fix opportunistically (per CLAUDE.md startup protocol).
2. **`docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`** — master audit register; ~242 Status entries. Focus on Research Drops 9-13 (current implementation order).
3. **`docs/AGENT_PROGRESS.md`** — sprint progress + what's next.
4. **`docs/sprint-sessions/`** current sprint file — task-level context.
5. **`docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 Implementation Log** — see what's been done; pick from §1-7 phases.
6. **`docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`** — agent architecture (read sections relevant to current slice).
7. **`docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`** — concept-to-canonical-source map (read BEFORE coding per CLAUDE.md "RESEARCH-FIRST FOR EVERY TASK").

For Hermes 2.0 work, also read:
- `agent_core/docs/CAPTURE_ROUTING_CLASSIFIER.md`
- `agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md`
- `agent_core/docs/HEAL_LOOP_SCHEMA_AND_TTL.md`
- `agent_core/docs/TOOL_MIGRATION_STATUS.md`

For deployment-profile work:
- `docs/release/MAS_APP_REVIEW_NOTES.md` (canonical MAS submission defense)
- `MAS_COMPLETE_FUSION §0` immutable rules 1-8

---

## §3. State-check ritual (every iteration, BEFORE §4)

```bash
git status --short
git log --oneline -5
git branch --show-current
git rev-parse --short HEAD
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet 2>&1 | tail -3
```

**Verify ALL of:**
- Working tree clean (or only the expected files modified)
- HEAD reachable on `codex/research-snapshot-2026-05-08`
- Cargo baseline still green (currently 1190 lib tests, may grow as you add tests)

**If working tree has unexpected mods:** investigate before doing ANY work. Parallel sessions sometimes stack identical work. The §3 state-check catches that.

---

## §4. §5.0 Reconciliation gate (non-negotiable)

BEFORE writing ANY new doctrine or making ANY code change:

1. Read the **actual current state on disk** for the substrate the audit row claims is broken/missing.
2. If reality differs from the audit-row framing: that's a §5.0 catch. Update the audit row's Status block to reflect reality first, THEN decide if the slice still needs implementation.

**§5.0 catch rate is a quality signal.** In run 2026-05-16, 24/72 = 33.3% of slices were §5.0 catches — substrate that was already in main but the audit row described as missing. Without §5.0 verification, those would have been 1-2 day duplicate-effort iters.

**Pattern (iter-64 lesson):** the §3 state-check ritual at session-resume catches §5.0 errors that emerge from context-compaction.

---

## §5. Slice selection — priority queue in execution order

Pick ONE slice per iteration. Walk the queue top-to-bottom; the first item where (a) §5.0 verifies reality matches the audit, (b) the work is bounded, and (c) it's not user-decision-gated, IS your slice.

### Phase A — V1 SHIP BLOCKERS (always first)

The §0 hard end state requires Phase A green. Pick from:

| Source | Filter for |
|---|---|
| `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` | `Status: CONFIRMED` rows tagged V1-blocking · Research Drops 9-13 |
| `MAS_COMPLETE_FUSION §10 Compromises Recorded` | V1 ship gates (Phase A.7 H-1 hang · A.8 H-2 idle · A.2/A.3 live smoke · A.4 graph framing) |
| `docs/KNOWN_ISSUES_REGISTER.md` | active live bugs (vault reset truth · CodeFileService containment) |

**Priority order WITHIN Phase A:**
1. Live vault lifecycle (Reset Everything must clear all stale state)
2. P0 product trust bugs (anything user-visible that suggests data corruption or stale state)
3. P0 ship-gate items (`V1-GATE-*` rows)
4. Bug fixes that block `xcodebuild` or `cargo test`

### Phase B — APP_ISSUES_AUTO_FIX register

Pick from `docs/APP_ISSUES_AUTO_FIX.md` `Status: Open` rows. ~30 open as of 2026-05-16. These are opportunistic fixes that came up during normal use; non-destructive by definition.

### Phase C — Hermes Agent Core 2.0 substrate

The canonical design doc is `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`. Many sections are doctrine-frozen but substrate barely started. Pick:
- §5.1 ExecutionReceipt + Capability — verify which fields are wired in `agent_core::ExecutionReceipt`
- §5.2 Ephemeral capability tokens — `agent_core/src/cognitive_dag/macaroons.rs::Caveat::OneShot` is doctrine-frozen but NOT yet implemented
- §5.4 Effect Inverse subsystem — `agent_core/src/effect/` exists (722 LOC); check what's wired in dispatch
- §7.4 Specialties registry — 19 macOS-only capabilities; check Swift surface registration

For each Hermes slice: §5.0 verify what's in `agent_core/src/` first; doctrine row may overstate completion or understate it.

### Phase D — V1.x Forward-Staged Primitives (when triggered)

6 substrates have doctrine specs frozen for V1.1/Wave 9+:
1. `Caveat::OneShot` (B2-H20 ephemeral tokens)
2. `agent_core/src/security/egress.rs` (B2-H19 per-Live-File egress allowlist)
3. `agent_core/src/auto_research/dp.rs` (B2-M14 differential privacy)
4. `agent_core/src/heal/` (B2-L1 heal loop module)
5. `agent_core/src/nightbrain/eligibility.rs` (B2-L2 widening to 7-of-7 conditions)
6. `HealthCheck + CircuitBreaker` (B2-M9 pre-flight gate)

Only pick these if user has explicitly authorized V1.x sprint OR if a Phase A/B item depends on one as prerequisite.

### Phase F′ — XPC Mastery (Pro target, unblocked by paid Apple Developer membership)

Per `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` — 5-service decomposition. Each service is a self-contained sliceable unit with its own entitlements, provisioning profile, IPC contract, and tests.

| # | Service | Slice scope | Prerequisite |
|---|---|---|---|
| F1 | **VaultXPC** | Vault read/write isolated in dedicated XPC; main process talks via capability tokens | Phase A.1 (vault lifecycle) green |
| F2 | **AgentXPC** | Hermes agent runtime in separate XPC for crash isolation + provider sandbox | F1 + Phase C Hermes §5.4 Effect/Inverse landed |
| F3 | **ProviderXPC** | Anthropic/Perplexity/Codex/Gemini calls in separate XPC; API keys never leave it | F2 |
| F4 | **WASMExecXPC** | Wasmtime executor with `cs.allow-jit + cs.disable-library-validation` (only XPC with these entitlements) for sandboxed-within-sandbox WASM tool execution | F2 + B2-H18 Pro tunnels framework |
| F5 | **Main shell coordination** | Coordinator wire-up, capability-token granting, trust attestation, IOSurface zero-copy | F1-F4 |

**Per F-row discipline:**
- Each XPC service requires its own `.entitlements` file with the minimum-scope keys.
- Each XPC service requires a separate provisioning profile (paid-membership-only).
- IPC contract is capability-token-based per `XPC_MASTERY_DOCTRINE §X.2` macaroon framework.
- Trust attestation via Secure Enclave per `§X.4`.
- Tests: cross-process call latency · capability scope enforcement · crash-isolation recovery · token revocation.

**Wiring sequence:** F1 → F2 → F3 → F4 → F5 (each blocks the next). Skipping ahead breaks the chain.

### Phase G — Pro Developer ID distribution (Pro target final)

Once Phase F′ closes:

| # | Slice | Verification |
|---|---|---|
| G1 | **Pro bundle build target** | `xcodebuild -configuration Release` Pro profile green |
| G2 | **Developer ID code signing** | `codesign --verify --strict --deep Epistemos-Pro.app` returns 0 |
| G3 | **Pro entitlement audit** | Each Pro entitlement matches its XPC's Hardened Runtime relaxation; Main app does NOT carry `cs.disable-library-validation` |
| G4 | **Notarization submission** | `xcrun notarytool submit Epistemos-Pro.dmg --wait` returns `status: Accepted` |
| G5 | **Staple + verify** | `xcrun stapler staple Epistemos-Pro.dmg` + `xcrun stapler validate` both 0 |
| G6 | **Distribution channel setup** | Pro DMG hosting + signing-key rotation policy + SLO for re-notarization on dep updates |

**Per G-row discipline:**
- G1-G5 are the technical-readiness gates.
- G6 is the operational-readiness gate; user-decision for HOSTING channel (direct download vs Cloudflare CDN vs Backblaze vs other).

### Phase E — Recursive verification pass (Phase E.1 of MAS_COMPLETE_FUSION)

When Phase A is empty AND Phase B is empty AND no Hermes work is queued, run a recursive pass:
1. Read `RECURSIVE_CURRENT_APP_AUDIT_TODO` cover-to-cover.
2. Scan for new issues introduced by recent commits.
3. Verify no new V1 blockers.
4. Append pass record to `CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` Recursive Pass Log.
5. If pass adds a NEW blocker, the counter resets.

**Goal: 5 consecutive passes with zero new blockers added** → §0 end state criterion met.

### Phase F — User-decision items (surface, don't fix)

Items waiting on user input get SURFACED in the §8 Implementation Log row but DO NOT block the loop. Skip to the next slice. ~13 items as of 2026-05-16 close:
- B-1/B-2/B-3/B-4 Wave 7-11 decisions (Live Files · Obscura · Undo · NousResearch SVG)
- H-3/B2-H6 EditPage capability macaroon shape
- B2-H16 Chatterbox voice
- B2-M5 hardware-budget alignment
- H-1/H-2 Instruments Time Profiler / Allocations runs
- L-2 V6.2 per-bubble binding A/B + commit-count
- L-3 Graph Toolbar one-PR-or-two + shape inventory
- ORPHAN-HERMES-SALVAGE-001 · RCA13-P0-001

If 3 consecutive iterations skip user-decision items and find no other work: **graceful wind-down per §10**.

---

## §6. Per-iteration protocol (the exact algorithm)

### Step 1 — Read state (§2 + §3)

Mandatory. Skipping = §5.0 errors. Iter-64 lesson.

### Step 2 — Reconcile + select slice (§4 + §5)

Apply §5.0 gate to every candidate. Pick the first non-blocked slice from Phase A → B → C → D → E priority order.

### Step 3 — Research the slice (disk first)

1. Open the source register row (RECURSIVE_TODO row or APP_ISSUES_AUTO_FIX row or Hermes 2.0 §X).
2. Search `MASTER_RESEARCH_INDEX_2026_05_02.md` for the concept.
3. Read the directly relevant canonical source (single doc, not the whole corpus).
4. Read the production code anchor cited.
5. If a salvage source exists at `docs/fusion/salvage/from-vigorous-goldberg/`, compare against current main.

### Step 4 — Research online (only if needed)

Use `WebFetch` or `WebSearch` ONLY for: current API/OS/model/package facts that disk canon doesn't cover. Cite primary/official sources. Default: skip step 4 unless step 3 left a knowledge gap.

### Step 5 — Implement

**For code work (Phases A/B/C/D):**
1. **Test-first.** Write a failing test before changing product code. Exceptions: docs-only changes, script-only changes.
2. **Minimal fix.** Do NOT refactor adjacent code unless required to fix the bug safely.
3. **Never revert user changes.** Inspect `git status` before and after each fix.
4. Touch ONE concern per commit. Do NOT batch unrelated fixes.

**For doctrine work (Phase E recursive pass + any doc updates):**
1. Read existing doctrine for the section you're modifying.
2. Apply §5.0 verification to all claims you make.
3. Cross-link to canonical sources.

### Step 6 — Verify

Every iteration MUST verify:
```bash
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet 2>&1 | tail -3
```

For code touching Swift:
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swift test --filter '<relevant test pattern>'
```

For MAS-relevant changes:
- Re-run the binary audit verifying no ScreenCaptureKit/AXorcist/`omega_ax` hits in the MAS bundle (`/tmp/epistemos_mas_tcc_binary_audit.log` shape).
- Confirm `Epistemos.app/Contents/Resources/PrivacyInfo.xcprivacy` still bundled.

For Hermes / agent work:
```bash
cargo test --manifest-path agent_core/Cargo.toml --lib 'agent_runtime' 2>&1 | tail -10
```

**Acceptance bar:** all tests green; new failing test landed in step 5 now passes; no test regressions from baseline.

### Step 7 — Update ledgers BEFORE committing

For Phase A/B work:
- Update the audit-row Status in `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` (CONFIRMED → PATCHED with evidence + commands + remaining risk).
- OR update `docs/APP_ISSUES_AUTO_FIX.md` row to `Status: Closed` with date + commit SHA.

For Phase C/D work:
- Update the Hermes 2.0 design doc section status.
- Update PASS-1 or PASS-2 audit row Status block if relevant.

For ALL slices:
- Append a row to `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log` with: date · slice title (iter N) · source · what was done + §5.0 verification + acceptance evidence · next-iter pointer.

### Step 8 — Commit implementation + ledgers together

```bash
git add <specific files — never `git add -A` or `git add .`>
git commit -m "$(cat <<'EOF'
<type>(<slice-id>): <subject under 70 chars>

<2-4 paragraph body describing §5.0 verification, what changed,
why, evidence.>

§5.0 verification: <verbatim evidence>

Acceptance: <test names · commands · expected output · actual output>

<Phase-tier status note: e.g. "Phase A 3/N cleared">

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

After commit, verify:
```bash
git log --oneline -1
git status --short  # should be clean
```

### Step 9 — Exit cleanly

ScheduleWakeup with `delaySeconds: 120` + the original `/loop` input prefixed `/loop ` + a one-sentence `reason`.

---

## §7. Audit-of-audit (every 10 iterations)

At iter 10, 20, 30, ..., run a dispassionate verification cycle covering the prior 10 commits. Method:

| Query type | Count | Purpose |
|---|---|---|
| Doctrine landing-site greps | ~10 | Verify each commit's claimed doctrine destination resolves on disk |
| Code-citation greps | ~4-8 | Verify each commit's claimed code citation matches actual file:line content |

Findings format:
- ✅ ON TRACK — all queries verify cleanly · no drift detected
- ⚠️ DRIFT-DETECTED — at least one commit's claim disagrees with on-disk reality · enumerate corrections needed

Append the audit-of-audit row to `RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md §9 Audit-of-audit register` AND to `MAS_COMPLETE_FUSION §8 Implementation Log`.

**Why this matters:** drift accumulates silently. The audit-of-audit cycle catches it within 10 commits.

---

## §8. PR-discipline rules (non-negotiable, in force)

Per `MAS_COMPLETE_FUSION §0` immutable rules 1-8:
1. NO Python in MAS build.
2. NO SIDECAR for inference or orchestration (in-process Rust FFI + MLX-Swift only; oMLX bridge is the sole exception).
3. REAL APIs ONLY — no fake features.
4. HONEST CAPABILITY GATING — Local models get fast/thinking/research; cloud models get agent/liveAgent.
5. ZERO test regressions against the cargo + swift suites.
6. **MAS uses URL-fetch + Apple-native WKWebView only** — no in-process JavaScript runtime. `deno_core`, `rusty_v8`, `boa_engine`, `Obscura` are Pro-only.
7. **JIT entitlement is MLX shader compilation + Metal Performance Shaders graph compilation only** — never user code / remote code / JavaScript / unsigned dylibs. Authoritative defense: `docs/release/MAS_APP_REVIEW_NOTES.md` §1.
8. **Per-Live-File network egress allowlist** — all outbound egress goes through `agent_core/src/security/egress.rs` (forward-staged) with per-Live-File allowlist.

Plus 4 lockstep rules:
- ResidencyLevel (B2-M12): doctrine + code MUST land together; changing one without the other fails CI.
- ACS (B2-M13): same lockstep discipline.
- New Cargo workspace crates (B2-M15): same lockstep discipline + `Cargo.toml`/`Package.swift` change MUST touch `docs/legal/licenses.md` in same commit.
- **XPC entitlement changes (Phase F′)**: any change to an `.entitlements` file MUST touch (a) corresponding XPC service's Info.plist, (b) provisioning profile reference, (c) `MAS_COMPLETE_FUSION §0 rule 7` JIT-defense block IF the change involves Hardened Runtime relaxations, (d) `docs/release/MAS_APP_REVIEW_NOTES.md §1` if it touches MAS entitlements, (e) a passing codesign verification test in the same commit. Failure: bundle ships with unsigned/mis-scoped XPC + Apple rejects at notarization or App Store review.

Plus 4-Tunnel taxonomy (B2-H18): Tunnel A (universal shell) · B.1 (URL MCP) · B.2 (stdio MCP) · C (CLI passthrough). MAS-shippable: Tunnel B.1 only. Pro-shippable: A · B.2 · C (now unlocked by paid Apple Developer; each tunnel must be dispatch-profile-scoped per OpenClaw pattern).

---

## §9. Failure / blocker escalation

If a slice fails verification (test red, build broken, lint complaint):
1. Inspect `git diff` of your uncommitted work.
2. If the failure is from your work, fix it before committing.
3. If the failure is pre-existing (cargo baseline drifted, build broke from earlier commit), STOP and escalate to user via the §10 wind-down with a clear pointer to the broken state.
4. Never commit known-broken state.

If you discover a new V1 blocker not in `RECURSIVE_CURRENT_APP_AUDIT_TODO`:
1. Append a new audit row with `Status: CONFIRMED` + evidence + recommended fix.
2. Pick the new blocker as your next slice (Phase A priority).

---

## §10. Wind-down conditions (when to stop)

**Hard stops (omit ScheduleWakeup):**

1. **§0 victory condition** met: all 6 criteria green. Surface terminal-state message.

2. **3 consecutive iters skip user-decision items** + no other auto-implementable work. Graceful wind-down: append a wind-down row to §8 Implementation Log + omit ScheduleWakeup + surface the ~N user-decision items waiting.

3. **Verification regression** that you cannot fix without exceeding slice scope (e.g., cargo baseline dropped from 1190 to 1188; your work didn't touch the failing tests). Stop and surface to user.

4. **Cargo / Swift build broken in main** before your iter started (someone else's bad commit). Stop. Surface.

5. **User-direction request** in conversation. Stop. Wait for direction.

**Soft stops (still ScheduleWakeup, just note the slowdown):**

- All Phase A/B/C work in this 5-iter window has been §5.0 catches with no real fix needed. Slowdown signal — the queue may be drifting toward exhaustion.
- Audit-of-audit verdict is DRIFT-DETECTED — fix the drift in iter N+1, then continue.

---

## §11. Self-recovery (loop resumption after interruption)

If you're starting a fresh session after the loop was paused:

1. Run §3 state-check ritual.
2. Look at `git log --oneline -10` for the last commit's slice ID + iter number.
3. Find that slice in §5 priority queue.
4. Confirm via §5.0 verification that the slice's claimed-resolved state actually holds on disk.
5. Pick the NEXT slice from the queue and proceed normally.

**Critical: context-compaction loses the iter-N → iter-N+1 chain context.** The §3 ritual is your reconstruction mechanism. Iter-64 of run 2026-05-16 caught a §5.0 error in iter-63 specifically because the §3 ritual was applied at resume.

---

## §12. Cadence + scheduling

Standard cadence: `ScheduleWakeup(delaySeconds: 120, ...)`.

Adjust if:
- Cargo run takes >60s consistently: bump to 180s (avoid stacking).
- Slice was small + verified quickly: stay at 120s.
- Slice required xcodebuild (slow): bump to 240s.

Always pass the original `/loop ...` prompt verbatim as the wakeup `prompt` arg, so the next firing re-enters this skill.

---

## §13. Source register state (as of run 2026-05-16 close)

For continuity across sessions:

| Register | Open count | Where to find |
|---|---|---|
| RESEARCH_COVERAGE_GAP_AUDIT_PASS1/2 LOW-tier | 0 — all 9 cleared in iter 60-72 run | PASS-1 §4 · PASS-2 §3 |
| RECURSIVE_CURRENT_APP_AUDIT_TODO | ~30 CONFIRMED + 6 TODO + many PATCHED PARTIAL | `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` |
| APP_ISSUES_AUTO_FIX | 30 Open | `docs/APP_ISSUES_AUTO_FIX.md` |
| Hermes 2.0 design sections | Many doctrine-frozen; substrate barely started | `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` |
| User-decision queue | ~13 items | `MAS_COMPLETE_FUSION §10 Compromises Recorded` + PASS audits |
| Forward-staged primitives | 6 specs frozen for V1.1+ | this doc §5 Phase D |
| **Phase F′ XPC Mastery** | **5 services NOT-STARTED** (VaultXPC · AgentXPC · ProviderXPC · WASMExecXPC · main shell) | `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` · this doc §5 Phase F′ |
| **Phase G Pro distribution** | **6 sub-slices NOT-STARTED** (G1 build · G2 sign · G3 entitlement audit · G4 notarize · G5 staple · G6 distribution channel) | this doc §5 Phase G |

**Cargo baseline:** 1190 lib tests as of 2026-05-16. May grow as you add tests. Track in each §8 row.

**Active branch:** `codex/research-snapshot-2026-05-08`.

**Most-recent ON-TRACK audit-of-audit:** #7 at iter 70 of run 2026-05-16 (commit `09016da32`). Next: #8 at iter 80 if loop continues.

**Apple Developer Program status:** PAID + ACTIVE (confirmed 2026-05-16). Unlocks: App Store Connect submission · Developer ID signing · Notarization · Provisioning profiles for XPC services · Hardened Runtime relaxations for Pro entitlements. Per-XPC entitlement matrix per `XPC_MASTERY_DOCTRINE §X.1`.

**Ship target:** MAS + Pro **PARALLEL** (per user direction 2026-05-16). Both Phase E.3 (App Store submit) and Phase G6 (Developer ID distribution) must close for §0 victory.

---

## §14. Mode switches (when user explicitly directs)

The user can override the §5 priority queue by saying:
- **"Focus on X"** — narrow the queue to slices touching X.
- **"Skip user-decision items for N more iters"** — keep them in surfaced-but-skipped state.
- **"Resolve decision D-N with answer A"** — convert user-decision item to implementation slice with that answer.
- **"Run Phase E.1"** — force a recursive verification pass even if Phase A/B have work.
- **"Wind down"** — graceful stop per §10.

Document mode switches in the §8 row of the iter that received them.

---

## §15. Common §5.0 catch patterns (from run 2026-05-16)

Watch for these — they recur:

1. **HELIOS V5/Wave 9 substrate drift** — doctrine row claims missing, but full substrate landed in 2026-05-06 push. Always grep code path before writing "NOT-STARTED" framing.

2. **Forward cross-link gaps** — substrate IS in main, audit row destination is the missing cross-link. Slice = land cross-link, not write new doctrine.

3. **Code-completion races already shipped** — earlier iter committed substrate but didn't update audit row. Status block update is the entire slice.

4. **Naming-drift between code + doctrine** — code uses `L4Engram` but doctrine uses `L4 Network Cascade`. Disambiguate in audit row.

5. **Partial substrate framed as NOT-STARTED** — happened with B2-L2 NightBrain (949 LOC in main + 4 LIVE observation lanes, framed as "doesn't exist"). §5.0 caught it in iter 64.

When the §5.0 verification step is skipped, errors of these 5 shapes propagate as drift. The §3 + §5.0 discipline is non-negotiable.

---

## §16. Output verbosity discipline

Each iteration's surface response should include:
- ✅ Slice picked + why
- Brief §5.0 verification result (1-2 sentences)
- Acceptance evidence (test output snippet)
- Commit SHA
- §8 row added
- Next iter armed (with reason)

Avoid restating the entire prompt or copy-pasting commit messages. The §8 log is the durable record.

---

## §17. Run summary (the loop's own work to date)

Run 2026-05-16 (iters 1-72) state, in case fresh sessions need the context:
- 72 closed slices · 24 §5.0 catches (33.3%) · 7 audits-of-audit (#1-#7 all ON TRACK)
- All major phases A/D/E/F/G complete in run 1; Phase I LOW-tier 9/9 in run 2
- 6 forward-staged primitives with doctrine specs frozen
- ~13 user-decision-gated items
- Cargo baseline 1190 held throughout
- Run 1 closed at iter 61 (graceful wind-down); run 2 resumed at iter 62 with parallel-session duplicate at iter 66 (harmless)

V2 of this prompt extends scope to production code AND dual MAS+Pro ship targets; V1 was doctrine-only and exhausted at iter 72.

**Scope deltas in V2 vs V1:**
- V1: MAS doctrine-only; 73 audit rows · 0 production code · doctrine-pass terminator
- V2: MAS + Pro parallel · production code with test-first discipline · §0 dual victory condition (15 criteria across both targets) · Phase F′ XPC Mastery (5 services) · Phase G Pro distribution (6 sub-slices) · paid Apple Developer membership ACTIVE unlocks all gated work · 4th lockstep rule for XPC entitlement changes · 4-Tunnel Pro-shippable surfaces (A · B.2 · C) added

---

## §18. The actual `/loop` input

When invoking this prompt, paste the body inline OR (preferred) reference the file:

```
/loop <body of this doc starting at §1> every 2 minutes
```

OR

```
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V2_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
```

The §0 victory condition is the loop's goal. Drive toward it. Stop when §10 conditions fire.

---

*Document version: V2.0 · 2026-05-16 · Supersedes V1 (CLAUDE_AUTONOMOUS_LOOP_PROMPT_2026_05_15.md) for any ship-driving work. V1 remains valid for doctrine-only audit closure sprints.*
