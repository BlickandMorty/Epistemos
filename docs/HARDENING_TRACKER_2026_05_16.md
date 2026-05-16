# Hardening Tracker — 2026-05-16

**Purpose:** Per-feature Phase 2 hardening checklist. Every feature shipped in Phase 1 (feature build) gets a row here. Phase 2 (post-V1) iterates through each feature's checklist until all green.

**Status:** LIVING — append every Phase 1 feature ship. Cross-reference: `docs/PARALLEL_FLOW_DOCTRINE_2026_05_16.md §1` (phase boundary doctrine), `docs/HARDENING_VERIFICATION.md` (verification commands), `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` (master harness plan).

---

## §1. Hardening dimensions (per feature)

Each shipped feature gets evaluated across these axes:

| Axis | What it covers | Acceptance bar |
|---|---|---|
| **Security** | Capability scope · macaroon enforcement · egress allowlist · `harden_cli_subprocess` usage · SQL injection · path traversal | Each dimension has a passing test |
| **Performance** | P50/P95/P99 latency · memory footprint · thermal impact · battery drain · cold-start vs warm-start | Bench harness in `agent_core/benches/` + Swift perf test |
| **Edge cases** | Empty inputs · max-size inputs · malformed inputs · concurrent access · interrupt/cancel | Property-based test (proptest) + fuzzing run |
| **Accessibility** | VoiceOver · Dynamic Type · reduce-motion · color contrast · keyboard-only nav | XCUITest accessibility audit pass |
| **Internationalization** | All user-facing strings in Localizable.strings · plurals via stringsdict · RTL layout safe | Localization audit pass; ships English-only V1 |
| **Documentation** | API docs (Swift jazzy / Rust rustdoc) · user-facing help · onboarding tooltips · error message quality | Each public symbol has doc comment |
| **Test coverage** | Line ≥80% · branch ≥70% · happy + sad path · property-based · integration | `cargo tarpaulin` + `xccov` reports |
| **Bench coverage** | `cargo bench` for hot paths · Swift XCTest measurement blocks for UI | Bench results in CI artifact |
| **CI hardening** | Matrix builds (Pro × MAS × Debug × Release) · cross macOS-version · drift detection | All matrix axes green |
| **Privacy** | Privacy manifest entry · App Store Connect answer · no unexpected logging | `PrivacyInfo.xcprivacy` updated |

---

## §2. Per-feature tracker (append rows as features ship in Phase 1)

Each row format:

```
| Feature | Shipped (commit) | Terminal | Sec | Perf | Edge | A11y | i18n | Docs | Tests | Bench | CI | Privacy | Phase 2 commit | Notes |
```

| Feature | Shipped | Terminal | Sec | Perf | Edge | A11y | i18n | Docs | Tests | Bench | CI | Privacy | Phase 2 | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| _(append as features ship)_ | | | | | | | | | | | | | | |

Legend:
- ⬜ Not yet — Phase 1 feature ship; hardening deferred
- 🔵 In progress — Phase 2 hardening underway
- ✅ Green — hardening axis passed
- ⚠️ Partial — known partial; documented remaining risk
- ❌ Failed — hardening regression caught; needs fix
- N/A — axis genuinely doesn't apply

---

## §3. Per-terminal hardening responsibilities

| Terminal | Primary hardening dimension |
|---|---|
| **A** | Privacy · MAS bundle audit · Pro entitlement scope · App Store metadata accuracy |
| **B** | Performance (Helios kernel bench) · Edge cases (research-grade falsifier harnesses) · Test coverage |
| **C** | CI hardening · Drift detection · Cross-link integrity · This tracker maintenance |
| **D** | Security (provider API key handling · `harden_cli_subprocess` · capability scope) · Edge cases (provider API drift) |
| **E** | Documentation · Decision-trail completeness |
| **F** | Security (XPC entitlement scope · macaroon enforcement on channels) · Privacy (channel data flow) |

---

## §4. Trigger conditions for Phase 2

Phase 2 hardening sweep starts when ALL of:
1. Terminal A reaches §0 victory (V1 MAS + Pro Developer ID ready)
2. Cargo baseline holds at 1190+ tests
3. CI bundle-size gate green on `main`
4. User explicitly says "BEGIN PHASE 2 HARDENING"

Until trigger fires: terminals continue Phase 1 feature build. New feature ships append rows to §2 with all axes ⬜.

---

## §5. Phase 2 execution order (per-terminal)

After trigger:
1. Each terminal reads its §3 row in this tracker → identifies own features with ⬜ axes
2. For each ⬜ axis: write test/audit/bench/etc. per §1 dimension's acceptance bar
3. Update §2 row to 🔵 (in progress) → ✅ (green) per axis as work completes
4. Commit with HEREDOC: `harden(<feature-id>): <axis>: <subject>` + body + trailer
5. Push to own branch; surface in §8 Implementation Log

When all features green across all axes → Phase 2 complete → Phase 3 (sustaining) begins.

---

## §6. Drift detection during Phase 2

`drift-detection.yml` workflow scans this tracker every 6h:
- Features marked ✅ that have regressed (test failures, bench drift) get flagged in GitHub issue
- Features marked ⬜ after Phase 2 trigger get flagged as "Phase 2 not started"

---

## §7. Sample row (template for first Phase 1 ship)

When Terminal A closes the live vault lifecycle bug (P0 Wave 0), append:

```
| Live vault lifecycle | <SHA> | A | ⬜ | ⬜ | ⬜ | N/A | N/A | ⬜ | ⬜ | N/A | ⬜ | ⬜ | _(pending)_ | Reset Everything clears all state |
```

Where:
- Sec ⬜ = vault capability scope not yet audited
- Perf ⬜ = reset perf not yet measured
- Edge ⬜ = concurrent reset + add + select not yet stress-tested
- A11y N/A = no UI element on reset itself (modal triggers separately)
- i18n N/A = no user-facing string from reset path itself
- Docs ⬜ = onboarding doesn't yet mention reset-and-fresh-vault flow
- Tests ⬜ = current test count not yet 80% coverage on reset path
- Bench N/A = reset is one-shot, no hot path
- CI ⬜ = reset path not yet in CI smoke matrix
- Privacy ⬜ = privacy manifest doesn't yet enumerate reset-cleared data categories

---

*Living tracker. Owner: Terminal C maintains the structure; every terminal appends own feature rows. Phase 2 trigger: user direction after A §0 victory.*
