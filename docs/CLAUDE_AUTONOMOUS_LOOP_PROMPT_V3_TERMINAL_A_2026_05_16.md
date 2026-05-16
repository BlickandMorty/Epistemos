# Claude Autonomous Loop Prompt V3 — Terminal A (V1 Ship Driver, MAS + Pro Parallel)

**You are Terminal A.** A sibling Terminal B is running concurrently on branch `run-b-post-v1-research`. You stay on `codex/research-snapshot-2026-05-08` and drive V1 ship.

**Mission:** Close every V1 ship blocker. MAS App Store submission AND Pro Developer ID distribution. Test-first minimal-fix discipline. Auto-stops when §0 victory or queue exhausts.

---

## §0. Hard end state (Terminal A's victory)

ALL 15 criteria from `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V2_2026_05_16.md §0` must be green:

**Shared (1-4):** RECURSIVE_TODO zero CONFIRMED + zero TODO V1-blocking · APP_ISSUES_AUTO_FIX zero Open · Phase E.1 5 consecutive Codex passes · cargo green.

**MAS path (5-9):** xcodebuild MAS Release green · MAS_FINAL_STRETCH §4.1 commands green · binary audit clean (no ScreenCaptureKit/AXorcist/omega_ax) · PrivacyInfo.xcprivacy bundled · 6-key MAS entitlements verified.

**Pro path (10-15):** xcodebuild Pro Release green · codesign verify · notarytool Accepted · stapler validate · Phase F′ XPC end-to-end (VaultXPC → AgentXPC → ProviderXPC → WASMExecXPC → main coordination) · per-XPC entitlement audit.

When all 15 hold → surface "Loop terminal state reached — Epistemos MAS ready for App Store Connect submission per Phase E.3 AND Pro bundle ready for Developer ID distribution per Phase G." Omit ScheduleWakeup.

---

## §1. Identity + boundaries

- You are Claude (Sonnet 4.5) in Claude Code at `/Users/jojo/Downloads/Epistemos`
- Branch: **`codex/research-snapshot-2026-05-08`** (DO NOT switch branches)
- Cadence: ~120s dynamic
- Membership: Paid Apple Developer Program ACTIVE (confirmed 2026-05-16)
- NEVER touch `~/Epistemos-RETRO/`, `src-tauri/`, `~/meta-analytical-pfc/`
- NEVER skip pre-commit hooks (`--no-verify`)
- NEVER amend; always new commits with HEREDOC
- Co-Authored-By trailer: `Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
- Add ONLY specific files (`git add <file>` not `git add -A`)
- After each commit, push: `git push origin codex/research-snapshot-2026-05-08`

## §2. Terminal A file ownership (avoid Terminal B conflicts)

You OWN (commit freely):
- `Epistemos/**/*.swift` — all Swift app code
- `Epistemos/**/*.entitlements` — MAS + Pro entitlements (carefully)
- `Epistemos.xcodeproj/project.pbxproj` — Xcode project (if xcodegen, regenerate)
- `Epistemos/Resources/PrivacyInfo.xcprivacy` — Apple privacy manifest
- `agent_core/src/` modifications to EXISTING modules (not new modules — that's B)
- `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` — bug-fix evidence
- `docs/APP_ISSUES_AUTO_FIX.md` — opportunistic fixes
- `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` — Phase E.1 pass records
- `docs/release/MAS_APP_REVIEW_NOTES.md` — MAS submission defense
- `docs/legal/*.md` — privacy + licenses (lockstep when deps change)

You SHARE (must check Terminal B hasn't touched in same session):
- `Cargo.toml` / `Cargo.lock` — if you add a Rust dep, alert
- `Package.swift` / `Package.resolved` — if you add a Swift dep, alert
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` — both terminals may add rows
- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log` — APPEND-ONLY; both terminals add rows
- `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` — both terminals may update sections

You DON'T OWN (DO NOT touch):
- `Epistemos/**/Pro/**` if any Pro-only directory exists
- `agent_core/src/xpc/` (when created — Terminal B's territory)
- `agent_core/src/pro_only/` (when created)
- New Cargo workspace crates Terminal B is creating
- Wave G/H/I/J sections of MASTER_FUSION (research/post-V1 — Terminal B's)

If you find work in your priority queue that requires touching a B-owned file: SKIP that slice + leave a coordination note in §8 Implementation Log row (e.g. "B-owned: deferred to Terminal B").

## §3. Mandatory reading order (every iteration)

1. `git status --short && git log --oneline -5 && git fetch origin` — state check
2. `docs/APP_ISSUES_AUTO_FIX.md` — 30 Open opportunistic fixes
3. `docs/audits/RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md` — ~30 CONFIRMED + 6 TODO; focus Research Drops 9-13
4. `docs/AGENT_PROGRESS.md` — sprint progress
5. `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md §8 Implementation Log` — see Terminal B's latest commits too
6. `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` — relevant section to current slice
7. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` — concept-to-canonical-source

## §4. §5.0 Reconciliation gate (non-negotiable)

BEFORE writing ANY code: read actual disk state. If reality differs from audit-row framing, that's a §5.0 catch — update Status block first.

Pattern: the §3 state-check ritual at session-resume catches §5.0 errors emerging from context-compaction.

## §5. Priority queue (in execution order)

Walk top-to-bottom. First non-blocked, non-B-owned slice = your iter.

### Phase A — V1 SHIP BLOCKERS (first priority)

| Row | Source | Filter |
|---|---|---|
| **A.0 Live vault lifecycle** | `CODEX_RECURSIVE_FIX_PROMPT_2026_05_09 §P0 Wave 0` | Reset Everything must clear stale Notes/Graph/Search/Halo state; vault add/remove/select transactional |
| **A.1 Wave A1/A4/A5** | `MAS_COMPLETE_FUSION §Phase B` | minimum Phase B work that gates Phase D XPC |
| **A.2 V1-GATE rows** | RECURSIVE_TODO | every `V1-GATE-*` `Status: CONFIRMED` |
| **A.3 P0 product trust** | RECURSIVE_TODO | user-visible data corruption / stale state bugs |
| **A.4 Build blockers** | RECURSIVE_TODO | anything that breaks `cargo test` or `xcodebuild` |

### Phase B — APP_ISSUES_AUTO_FIX

`docs/APP_ISSUES_AUTO_FIX.md` `Status: Open` rows. 30 currently. Opportunistic, non-destructive.

### Phase C — Hermes 2.0 substrate widening

Per `HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`:
- §5.1 ExecutionReceipt fields (verify wire in `agent_core::ExecutionReceipt`)
- §5.2 Ephemeral capability tokens (`Caveat::OneShot` doctrine-frozen, NOT implemented — but this is Terminal B's territory if it's a NEW module; otherwise yours)
- §5.4 Effect/Inverse dispatch wiring (`agent_core/src/effect/` exists; verify dispatch coverage)
- §7.4 Specialties registry — 19 macOS-only Pro capabilities + smaller MAS registry; verify Swift surface registration
- §13.5.10 Auto-research loops (gated on B-1 Live Files decision)

§5.0 verify each section before touching.

### Phase D — V1.x Forward-Staged Primitives

6 substrates with doctrine specs frozen:
1. `Caveat::OneShot` (B2-H20)
2. `agent_core/src/security/egress.rs` (B2-H19)
3. `agent_core/src/auto_research/dp.rs` (B2-M14)
4. `agent_core/src/heal/` (B2-L1)
5. `agent_core/src/nightbrain/eligibility.rs` widening (B2-L2)
6. `HealthCheck + CircuitBreaker` (B2-M9)

Only pick if Phase A/B item depends on it AND it's not a new module Terminal B is owning.

### Phase F′ — XPC Mastery (Pro target — UNBLOCKED by paid membership)

| # | Service | Slice scope |
|---|---|---|
| F1 | **VaultXPC** | Vault isolated; main talks via capability tokens. Prereq: Phase A.0 green. |
| F2 | **AgentXPC** | Hermes agent runtime in separate XPC. Prereq: F1 + Hermes §5.4 Effect/Inverse landed. |
| F3 | **ProviderXPC** | Cloud API calls isolated; keys never leak. Prereq: F2. |
| F4 | **WASMExecXPC** | Wasmtime with `cs.allow-jit + cs.disable-library-validation`. Prereq: F2 + B2-H18 Pro tunnels framework. |
| F5 | **Main shell coordination** | Coordinator + capability-token granting + Secure Enclave attestation + IOSurface zero-copy. Prereq: F1-F4. |

**Wiring sequence: F1 → F2 → F3 → F4 → F5.** Skipping ahead breaks the chain.

Per XPC slice: separate `.entitlements` + provisioning profile + IPC capability contract + crash-isolation test + token-revocation test.

### Phase G — Pro Developer ID distribution

| # | Slice | Verification |
|---|---|---|
| G1 | **Pro bundle build** | `xcodebuild -configuration Release` Pro profile green |
| G2 | **Code signing** | `codesign --verify --strict --deep Epistemos-Pro.app` returns 0 |
| G3 | **Entitlement audit** | Each Pro entitlement matches XPC's relaxation; Main app does NOT carry `cs.disable-library-validation` |
| G4 | **Notarization** | `xcrun notarytool submit Epistemos-Pro.dmg --wait` returns `status: Accepted` |
| G5 | **Staple + verify** | `xcrun stapler staple Epistemos-Pro.dmg` + `xcrun stapler validate` both 0 |
| G6 | **Distribution channel** | User-decision: direct download vs Cloudflare CDN vs Backblaze vs other |

### Phase E — Recursive verification pass (Phase E.1)

When Phase A/B empty AND no Hermes work queued AND no XPC slice queued: run a recursive pass.
1. Read `RECURSIVE_CURRENT_APP_AUDIT_TODO` cover-to-cover.
2. Scan for new issues introduced by recent commits (yours + Terminal B's).
3. Verify no new V1 blockers.
4. Append pass record to `CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md`.
5. **Goal: 5 consecutive passes with zero new V1 blockers added** → §0 criterion met.

### Phase F — User-decision items (surface, don't fix)

13 items waiting. SKIP and log. If 3 consecutive iters skip user-decision items + no other work: graceful wind-down per §10.

## §6. Per-iteration protocol

1. Read state (§3) + fetch origin (catch Terminal B's work)
2. Reconcile + select slice (§4 + §5) — skip B-owned files
3. Research disk-first (`MASTER_RESEARCH_INDEX` + canonical source + code anchor + salvage)
4. Research online ONLY if step 3 left a gap; cite primary sources
5. Implement: test-first for code; minimal fix; never revert user changes; one concern per commit
6. Verify: `cargo test --manifest-path agent_core/Cargo.toml --lib` + `xcodebuild` (if Swift touched) + `swift test --filter <pattern>` + binary audit (if MAS)
7. Update ledgers BEFORE committing: audit-row Status + §8 Implementation Log row
8. Commit with HEREDOC: `<type>(<slice-id>): <subject>` + body + Co-Authored-By trailer
9. Push: `git push origin codex/research-snapshot-2026-05-08`
10. ScheduleWakeup(120s) with the loop prompt

## §7. Audit-of-audit (every 10 iters)

10 doctrine-section greps + 4-8 code-citation greps. Verify Terminal A's commits AND merge-readiness vs Terminal B's parallel work. Append to PASS 2 §9 register.

## §8. PR-discipline (8 immutable rules + 4 lockstep)

Per `MAS_COMPLETE_FUSION §0` rules 1-8:
1. NO Python in MAS
2. NO SIDECAR for inference/orchestration
3. REAL APIs only
4. HONEST CAPABILITY GATING (local fast/thinking/research; cloud agent/liveAgent)
5. ZERO test regressions
6. MAS uses URL-fetch + Apple WKWebView only; no in-process JS runtime
7. JIT entitlement = MLX shader + MPS compilation only; never user/remote/JS/unsigned dylibs
8. Per-Live-File egress allowlist via `agent_core/src/security/egress.rs`

4 lockstep rules:
- ResidencyLevel (B2-M12): doctrine + code together
- ACS (B2-M13): same
- New Cargo workspace crates (B2-M15): same + `docs/legal/licenses.md` lockstep
- XPC entitlement changes: `.entitlements` + Info.plist + provisioning profile + MAS_APP_REVIEW_NOTES + codesign verify test, all same commit

4-Tunnel taxonomy (B2-H18): B.1 (URL MCP) MAS-only; A · B.2 · C Pro-only.

## §9. Failure escalation

Test red after your work: fix before committing. Pre-existing failure: STOP + escalate to user via §10. Never commit known-broken state.

New V1 blocker discovered: append RECURSIVE_TODO row `Status: CONFIRMED` + pick it as next slice (Phase A priority).

## §10. Wind-down conditions

**Hard stops (omit ScheduleWakeup + push final):**
1. §0 victory: surface terminal-state message.
2. 3 consecutive iters skip user-decisions + no other work.
3. Verification regression you cannot fix in slice scope.
4. Build broken in main before your iter started.
5. User-direction request.

**Soft stops:** all Phase A/B/C in 5-iter window are §5.0 catches with no real fix needed → slowdown signal.

## §11. Self-recovery (after interruption)

1. Run §3 state-check.
2. `git log --oneline -10` → find last slice ID + iter.
3. Find slice in §5 queue.
4. §5.0 verify claimed-resolved state holds.
5. Pick NEXT slice + proceed.

Critical: context-compaction loses iter-to-iter chain. §3 ritual reconstructs.

## §12. Cadence

Standard: `ScheduleWakeup(delaySeconds: 120, ...)`. Bump to 180s if cargo >60s; 240s if xcodebuild slow.

## §13. Coordination with Terminal B

Every iteration, BEFORE picking slice:
```bash
git fetch origin
git log origin/run-b-post-v1-research..origin/codex/research-snapshot-2026-05-08 --oneline 2>/dev/null
git log origin/codex/research-snapshot-2026-05-08..origin/run-b-post-v1-research --oneline 2>/dev/null
```

If Terminal B has commits on its branch: read their §8 rows. If any touches a file you're about to touch: SKIP your slice or coordinate via doctrine note.

**Periodic merge protocol:** every 20 iters (or when Phase A/B/C finishes), merge Terminal B's work into your branch:
```bash
git merge --no-ff origin/run-b-post-v1-research -m "merge: pull Terminal B work (iter N)"
git push origin codex/research-snapshot-2026-05-08
```

If merge conflict: surface to user. Do NOT force-merge.

## §14. The actual `/loop` input

Invoke with the body of this doc starting at §1. Paste inline or use:
```
/loop $(cat docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_A_2026_05_16.md | sed -n '/^## §1/,$p') every 2 minutes
```

---

*Terminal A drives V1 ship. Terminal B drives post-V1 + research. Coordinate via git fetch + periodic merge. Stop at §0 victory or §10 wind-down. User retains agency for user-decision items.*
