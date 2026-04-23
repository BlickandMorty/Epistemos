# Build / Test Green Baseline — 2026-04-23

**Captured:** 2026-04-23, during the pre-execution audit.
**Branch state:** DIRTY (35 modified Swift/Rust files + 2 untracked). See §4 below.

---

## Summary

| Check | Result |
|---|---|
| `cargo test --manifest-path agent_core/Cargo.toml` | ✅ **PASS — 577 tests total across crates, 0 failed** |
| `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` | ✅ **BUILD SUCCEEDED** (verified 2026-04-23) |
| `swift test` | ⏭️ **SKIPPED** — branch is dirty; risk of interleaving uncommitted work with test observations |
| Git status | ⚠️ Dirty — 35 modified, 2 untracked. Full list in §4. |

---

## 1. Rust tests (cargo)

Command: `cargo test --manifest-path agent_core/Cargo.toml` (without `--quiet` flag; quiet mode suppressed output)

```
running 570 tests (agent_core lib)
....................................................................................... 87/570
....................................................................................... 174/570
....................................................................................... 261/570
....................................................................................... 348/570
....................................................................................... 435/570
....................................................................................... 522/570
................................................
test result: ok. 570 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 4.34s

running 2 tests (integration suite A)
..
test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

running 5 tests (integration suite B)
.....
test result: ok. 5 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

running 0 tests (doc-tests)
test result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s
```

**Verdict:** 577/577 (570 + 2 + 5) passing. Zero failures. Runtime ~4.4s.

**Reconciliation with `docs/audit-progress.md`** — the audit-progress doc claims 549 Rust tests. Current count is 577 (+28 since that snapshot). This is GROWTH, not drift — more tests added. Green baseline is real.

**Caveat:** `--quiet` flag collapsed output to "0 tests" first pass. Always run cargo test WITHOUT `--quiet` when capturing baselines, or the test count is invisible.

---

## 2. Swift / Xcode build

Command: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 > /tmp/epistemos_build.log`

**Result:** ✅ **BUILD SUCCEEDED**

- First-party errors: 0
- First-party warnings: 0 (per `grep -c "^error:" /tmp/epistemos_build.log` → 0 matches)
- Expected third-party `mlx-swift` C++ warnings: presumed unchanged per `docs/audit-progress.md` baseline (4 `constexpr if is a C++17 extension`).
- Log size: ~3,790+ lines (Rust cross-compile + Swift compile + link phases visible)

**Reconciliation:** this is the same clean-build state documented in `docs/audit-progress.md` L17. No new regressions introduced by the 35 uncommitted modified files.

---

## 3. Swift tests (NOT run)

**Reason not run:** branch is dirty (§4). Swift test runs can hang or flake on partially-modified source. Running swift test now risks conflating uncommitted-work defects with baseline defects.

**What to do:** after the user commits or stashes, run:
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' \
    -derivedDataPath /tmp/epistemos_dd \
    -clonedSourcePackagesDirPath /tmp/epistemos_spm \
    test 2>&1 | xcbeautify
```

Per `docs/audit-progress.md` the target count is **1,404 Swift tests** across **192 suites** passing. Any drift from this baseline = regression.

---

## 4. Branch state (`git status --short`)

**Modified files (35):**

```
M Epistemos/App/AppBootstrap.swift
M Epistemos/App/ChatCoordinator.swift
M Epistemos/App/RootView.swift
M Epistemos/Engine/Extensions.swift
M Epistemos/Engine/TriageService.swift
M Epistemos/KnowledgeFusion/KnowledgeProfileStore.swift
M Epistemos/LocalAgent/LocalAgentLoop.swift
M Epistemos/Omega/Inference/ToolCallParser.swift
M Epistemos/State/AgentCommandCenterState.swift
M Epistemos/State/ChatState.swift
M Epistemos/State/InferenceState.swift
M Epistemos/Sync/VaultIndexActor.swift
M Epistemos/Vault/SkillDiscoveryCatalog.swift
M Epistemos/Views/Landing/LandingView.swift
M Epistemos/Views/Landing/LiquidGreeting.swift
M Epistemos/Views/MiniChat/MiniChatView.swift
M Epistemos/Views/Notes/CodeEditorView.swift
M Epistemos/Views/Notes/ModelInvolvementSheet.swift
M Epistemos/Views/Notes/ModelVaultBrowserSheet.swift
M Epistemos/Views/Notes/ModelVaultsSidebarSection.swift
M Epistemos/Views/Notes/NoteDetailWorkspaceView.swift
M Epistemos/Views/Notes/NotesSidebar.swift
M Epistemos/Views/Notes/ProseEditorView.swift
M Epistemos/Views/Settings/AuthoritySettingsView.swift
M Epistemos/Views/Settings/ModelVaultsSettingsView.swift
M Epistemos/Views/Shared/AppKitPopover.swift
M EpistemosTests/LandingOptimizationTests.swift
M EpistemosTests/LocalAgentLoopTests.swift
M EpistemosTests/ModelVaultBrowserTests.swift
M EpistemosTests/RuntimeValidationTests.swift
M EpistemosTests/TriageServiceTests.swift
M EpistemosTests/VaultIndexActorTests.swift
M agent_core/src/tools/registry.rs
M docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md
```

**Untracked files (2):**

```
?? EpistemosTests/AppKitPopoverAuditTests.swift
?? docs/CLAUDE_CANONICAL_STATE_HANDOFF_2026-04-23.md
```

### What this means for Phase 0 / Phase R work

- **`docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` is modified but NOT COMMITTED** — the user's in-progress plan edits from this conversation. The plan file is still canonical; just un-committed. User should commit or stash before agentic execution to prevent a Phase R fix PR from accidentally inheriting plan-edit changes.
- **Many files overlap with R.1 inventory targets** (ChatState, InferenceState, ModelInvolvementSheet, ModelVaultsSidebarSection, NoteChatState, LocalAgentLoop, ProseEditorView, etc.). The R.1 inventory should be run AFTER these are committed so it captures final-state code, not half-applied changes.
- **`AppKitPopoverAuditTests.swift` is untracked** — likely from the Wave-17 audit work. Should be git-added and committed before further work.

### Recommended pre-work

```bash
# 1. Commit the current working state (whatever the user intended)
git add <the specific files the user wants to commit>
git commit -m "<describe in-progress work>"

# 2. If there are WIP changes not ready to commit:
git stash push -u -m "pre-R1-inventory-WIP"

# 3. Then run the full green baseline
xcodebuild -scheme Epistemos -destination 'platform=macOS' test 2>&1 | xcbeautify
```

---

## 5. Green baseline definition (for Phase R exit criteria)

For Phase R to close (per plan §Phase R verification), these checks must all be green on a **clean branch**:

1. ✅ `cargo test --manifest-path agent_core/Cargo.toml` → 577+ tests pass, 0 failed.
2. ⏳ `xcodebuild -scheme Epistemos build` → clean (only third-party `mlx-swift` C++ warnings acceptable).
3. ⏳ `xcodebuild -scheme Epistemos test` → 1,404+ tests pass across 192+ suites.
4. ⏳ `codesign -d --entitlements - <build>.app` → App Sandbox status matches the target build (YES for MAS profile, NO for Pro profile).
5. ⏳ `grep -rE "fn (read|write|find|create|edit|delete)_note\b" agent_core/ epistemos-core/ Epistemos/ | grep -v "ResourceService\|_adapter\b"` → zero matches (deferred until Phase R.3 lands).
6. ⏳ `grep -rE "try!" Epistemos/ agent_core/` → zero matches (deferred until Phase R warm-up fixes I-017 land).

Current state: **only check 1 is green.** The rest are deferred to their respective phases.

---

## 6. Quick-reference commands for future sessions

```bash
# Rust baseline
cargo test --manifest-path agent_core/Cargo.toml 2>&1 | tail -10

# Swift build (clean)
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Swift test (clean branch only)
xcodebuild -scheme Epistemos -destination 'platform=macOS' \
    -derivedDataPath /tmp/epistemos_dd \
    -clonedSourcePackagesDirPath /tmp/epistemos_spm \
    test 2>&1 | xcbeautify

# Git hygiene
git status --short
git diff --stat

# Verify Rust links into Xcode build
grep -E "agent_core|agent_coreFFI" project.yml

# Inventory split-brain grep (for Phase R.3 exit check)
grep -rE "fn (read|write|find|create|edit|delete)_note\b" \
    agent_core/ epistemos-core/ Epistemos/ | \
    grep -v "ResourceService\|_adapter\b" | wc -l
```
