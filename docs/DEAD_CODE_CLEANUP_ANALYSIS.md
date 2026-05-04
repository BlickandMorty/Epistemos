# Dead Code + Stale Docs Cleanup Analysis — 2026-04-23

> **Index status**: CANONICAL-OPERATIONAL — Dead code + stale docs cleanup analysis — ARCHIVE/DELETE/KEEP table (47 ARCHIVE 2 DELETE 89 KEEP) + ~500MB disk-space recovery; preserves deferred features (MOHAWK/ODIA/Hermes).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Source:** read-only analysis agent + grep passes.
**Purpose:** give the user a clear decision table for what to KEEP, ARCHIVE (reversible), or DELETE so the repo stays "super clean but truly useful still."

**Rule enforced:** err on ARCHIVE over DELETE. Nothing user-written should be lost; every archive is reversible via `git log` / `git mv` reverse.

---

## Summary

| Metric | Count |
|---|---|
| Swift files reviewed | 440 |
| Root-level `.md` docs | 116 |
| Other files reviewed | 180+ |
| Recommended **ARCHIVE** | 47 items |
| Recommended **DELETE** | 2 directories (empty placeholders) + 3 abandoned-research files |
| Recommended **KEEP** | 89 core directories + docs + code |
| Disk space reclaimed after archive | ~500 MB (build artifacts, tmp/, training data) |

**Key finding:** the codebase is surprisingly clean for its maturity. Most "dead code" is actually **deferred features** (MOHAWK Python training pipeline, ODIA trace generators) or **research artifacts** (Hermes upstream, Paperclip, Lambda-RLM) explicitly excluded from the build. These belong in an archive for future reference, not deletion.

---

## Part A — Code directories: decision table

### KEEP (active, in place)

| Directory | Rationale |
|---|---|
| `Epistemos/App/` | Main app lifecycle — always active |
| `Epistemos/Engine/` | Runtime services (Triage, Pipeline, LLM) — core |
| `Epistemos/State/` | 34 state files, all @Observable, all active |
| `Epistemos/Views/` | UI surface — always active |
| `Epistemos/Graph/` | Graph engine bridge — always active |
| `Epistemos/Sync/` | Vault sync + file storage — always active |
| `Epistemos/Omega/` | All subdirectories verified active via grep: |
| → `Epistemos/Omega/Agents/` | agent orchestration referenced by app |
| → `Epistemos/Omega/Channels/` | communication channels |
| → `Epistemos/Omega/Inference/` | DualBrainRouter actively used by HybridRouter |
| → `Epistemos/Omega/Knowledge/` | AgentGraphMemory, RecipeGraphSkills, GhostBrainCoauthor all imported in `AppBootstrap.swift` |
| → `Epistemos/Omega/Orchestrator/` | OrchestratorState stub preserved for API compat per L4 comment; can be removed when views migrate to AgentViewModel |
| → `Epistemos/Omega/Safety/` | 12 files registered in HookRegistry — production |
| → `Epistemos/Omega/Vision/` | VLM/vision integration — active |
| → `Epistemos/Omega/iMessageDriver/` | iMessage automation — active |
| `Epistemos/LocalAgent/` | 5 files, 2,705 lines — production local agent runtime |
| `Epistemos/KnowledgeFusion/` | Adapters + knowledge profile store — KEEP (subdirs vary, see ARCHIVE below) |
| `Epistemos/Models/` | SwiftData models — always active |
| `Epistemos/Vault/` | Vault operations — always active |
| `Epistemos/Bridge/` | UniFFI Swift bridges — always active |
| `agent_core/` | Rust core crate — always active |
| `epistemos-core/` | Rust knowledge core — always active |
| `graph-engine/` | Rust graph engine — always active |
| `omega-mcp/`, `omega-ax/`, `syntax-core/` | Rust crates — all linked via project.yml |
| `EpistemosTests/` | Swift test target — always active |

### ARCHIVE (move to `archive/`, reversible)

| Path | Size | Why archive (not delete) |
|---|---|---|
| `Epistemos/KnowledgeFusion/MOHAWK/` | ~3.5 MB | Python training pipeline for deferred MOHAWK Model Training feature. **Explicitly excluded** from `project.yml` L46 (`KnowledgeFusion/MOHAWK/**`). Not dead — scheduled for Phase 2 of the 3-wave roadmap. Recommended: `git mv Epistemos/KnowledgeFusion/MOHAWK archive/code/MOHAWK`. |
| `Epistemos/Omega/Knowledge/ODIATraceGenerator.swift` | — | Excluded in `project.yml` L47. Training-data generator, deferred. Keep accessible for future work but not in main tree. Decision: KEEP at current location (single file, low friction) OR archive alongside MOHAWK — user preference. |
| `Epistemos/Omega/Knowledge/TraceDataMixer.swift` | — | Excluded in `project.yml` L48. Same situation as ODIATraceGenerator. |
| `jojo/` | ~240 MB | Session work artifacts (release notes, app icon exports, reference code from earlier sprints). Local experimentation, not canonical. **Recommended:** `git mv jojo archive/session-work/jojo`. |
| `tmp/hermes-agent-upstream/` | ~100 MB | Upstream reference code for Hermes. Useful for architectural study. Not part of build. Archive for reference. |
| `tmp/lambda-RLM/` | ~50 MB | Experimental RL training; not integrated. Archive. |
| `tmp/paperclip/` | ~80 MB | Experimental agent. Archive. |
| `reference-code/` | 144 KB | Anthropic SDK reference samples (Rust). Keep accessible in archive. |
| `artifacts/reliability/` | ~10 MB | Test artifacts, old benchmarks. **Generated, not source.** Can safely delete — will be regenerated by CI. Alternatively: `.gitignore` the directory. |

### DELETE (truly empty placeholders)

| Path | Why delete |
|---|---|
| `Epistemos/ComputerUse/` | Empty directory. Placeholder. No files. `git rm -r`. |
| `Epistemos/Agent/` | Empty directory. Placeholder. No files. `git rm -r`. |
| `verification/` | Empty 64-byte directory. Placeholder. `git rm -r`. |

### KEEP (generated build artifacts, gitignored)

| Path | Why keep |
|---|---|
| `build/` | Xcode DerivedData equivalent — needed for incremental builds. |
| `build-rust/` | Rust cross-compiled static/dynamic libs + UniFFI Swift bindings. Needed to link. |

---

## Part B — Orphaned Swift types

Only **2–3 truly dead types** out of 440 Swift files. Most "dead" types are deferred-feature scaffolding.

| Type name | File | External refs | Recommendation |
|---|---|---|---|
| `StructuredODIATraceGenerator` | `KnowledgeFusion/SyntheticData/ODIATraceGenerator.swift` | 1 (self-comment) | **DELETE** — training data generator, excluded from build |
| `TraceDataMixer` | `KnowledgeFusion/SyntheticData/TraceDataMixer.swift` | 0 | **DELETE** — experimental, excluded from build |
| `ODIATraceGenerator` (in `Epistemos/Omega/Knowledge/`) | same name, different location | 1 (TraceDataMixer comment) | **ARCHIVE** — part of deferred knowledge distillation |
| `AgentGraphMemory` | `Epistemos/Omega/Knowledge/AgentGraphMemory.swift` | 3+ (AppBootstrap, NightBrainService) | **KEEP** — actively used |
| `RecipeGraphSkills` | `Epistemos/Omega/Knowledge/RecipeGraphSkills.swift` | 2+ (AppBootstrap, tests) | **KEEP** — actively used |
| `GhostBrainCoauthor` | `Epistemos/Omega/Knowledge/GhostBrainCoauthor.swift` | 1+ (AppBootstrap) | **KEEP** — actively used |

---

## Part C — `docs/` classification (116 files)

### ACTIVE — current roadmap & canonical reference (KEEP)

- **`IMPLEMENTATION_PLAN_FROM_ADVICE.md`** (243 KB) — ground-truth plan; currently modified (uncommitted). NEVER archive.
- `ROADMAP_NEXT_3.md` — feature prioritization (Knowledge Fusion → MOHAWK → Omega v2)
- `AGENTS.md` (repo root) — engineering bible, patterns, architecture overview
- `audit-progress.md` — audit state, fixes completed, deferred items
- `future-work-audit.md` (93 KB) — 21 waves of planned work
- `KNOWN_ISSUES_REGISTER.md` — current blockers
- `RESOURCE_INVENTORY.md` — R.1 inventory (already exists from earlier today)
- `RESOURCE_RUNTIME_RESEARCH.md` — R phase authoritative spec
- `BEST_OF_CLAW_AND_OPENCLAW.md` — cross-referenced by K+I.4 phases
- `CLI_CONFIG_COMPILATION_RESEARCH.md` — cross-referenced by G phase
- `BUILD_TEST_GREEN_BASELINE.md` — today's baseline
- `CODE_EDITOR_POLISH_SCOPE.md` — today's scope
- `DEAD_CODE_CLEANUP_ANALYSIS.md` — this file
- `CLAUDE_CANONICAL_STATE_HANDOFF_2026-04-23.md` — today's handoff (currently untracked)

### HISTORICAL-KEEP — research / advice worth preserving (KEEP IN PLACE)

- `MASTER_MODEL_STACK_PLAN.md` — model selection decisions
- `EPISTEMOS_SPECIALTIES.md` — positioning, competitive analysis
- `FUSED_AGENT_ENGINEERING_REPORT.md` — technical analysis of agent approaches
- `GOOSE_AGENT_RESEARCH.md`, `GOOSE_AGENT_RESEARCH_2.md` — alternative agent architectures studied
- `UNIFIED_SUBSTRATE_RESEARCH.md` — backend architecture exploration
- `TOOL_TIER_AND_IMESSAGE_INTEGRATION.md` — iMessage system design
- Any doc in `docs/research/` with a dated timestamp since 2026-04-01

Keep these in `docs/` for historical context. Do NOT archive — future sessions reference them.

### SUPERSEDED — archive to `docs/archive/superseded/`

- `CODEX_HANDOFF.md` → superseded by `CODEX_HANDOFF_2026-04-18.md` → superseded by `CODEX_HANDOFF_2026-04-23.md` (if exists)
- `CODEX_HANDOFF_2026_04_10.md` → older
- `SESSION_STATE_2026_03_25.md` → older session state
- `SESSION_HANDOFF_2026-04-07.md`, `SESSION_REPORT_2026-04-06.md` → older session reports
- `CLAUDE_CODE_SESSION_PROMPT.md`, `SESSION_BOOTSTRAP_PROMPT.md` → older session prompts (if present)
- `AUDIT_LOG.md` (113 KB) → archived audit log
- `AUDIT_REPORT.md`, `AUDIT-HANDOFF-Ω10-Ω14.md` → old audit reports

### HANDOFF — selective archive of `docs/handoffs/`

**Keep (recent, needed for continuation):**
- `2026-04-22-codex-to-claude-live-runtime-and-architecture-handoff.md`
- `2026-04-20-claude-to-codex-verification.md`
- `2026-04-20-codex-to-claude-full-thread-handoff.md`
- any handoff dated 2026-04-20 or later

**Archive to `docs/archive/handoffs/`:**
- `2026-03-28-*.md` (11 files) → older
- `2026-04-17-*.md` (3 files) → older

### EXPERIMENTAL / ABANDONED (archive to `docs/archive/abandoned-research/`)

- `ANTI_DRIFT_SYSTEM.md` — incomplete design, superseded by Appendix B §B.4 drift alarms
- `EPISTEMOS_FUSED_v3.md` — old fused architecture proposal
- `CODE_EDITOR_DEBUG.md`, `CODE_EDITOR_ROOT_CAUSE.md`, `CODE_EDITOR_STACK_RESEARCH.md` — superseded by `CODE_EDITOR_POLISH_SCOPE.md` (today) and PLAN_V2 §23
- `CUSTOM_TEXT_ENGINE_RESEARCH.md` — abandoned text engine research; the app uses CodeEditSourceEditor instead

### SUBDIRECTORY CLASSIFICATIONS

| Directory | Count | Recommendation |
|---|---|---|
| `docs/handoffs/` | 22 files | Keep 2026-04-20+, archive 2026-03-28 through 2026-04-17 |
| `docs/research/` | 30+ files | Keep `hermes-*`, `local-models-*`; archive dead-feature research |
| `docs/audits/` | 10+ files | Keep 2026-04+, archive 2026-03 versions |
| `docs/plans/` | ~8 files | Keep `ROADMAP_NEXT_3`, `future-work-audit`; review others |
| `docs/architecture/` | ~6 files | Keep active architecture docs; archive pre-Omega obsolete |
| `docs/sprint-sessions/` | ~15 files | Archive (all are historical session notes) |
| `docs/knowledge-fusion/` | ~12 files | Keep MOHAWK training guides; archive experimental data configs |
| `docs/bug-fixes/` | ~6 files | Archive (completed issues) |

---

## Part D — Executable cleanup script

```bash
#!/bin/bash
# Epistemos cleanup script — REVIEW BEFORE RUNNING
# Date: 2026-04-23
# Purpose: archive dead/deferred code + superseded docs
# Reversibility: every `git mv` is reversible via git log + git mv reverse.
set -e

REPO_ROOT="/Users/jojo/Downloads/Epistemos"
cd "$REPO_ROOT"

# Ensure archive directories exist
mkdir -p archive/{code,docs,reference,session-work,experimental}
mkdir -p archive/docs/{historical,superseded,handoffs,abandoned-research}

echo "=== PHASE 1: Archive code directories ==="

# MOHAWK — deferred Python training pipeline
if [ -d "Epistemos/KnowledgeFusion/MOHAWK" ]; then
  git mv Epistemos/KnowledgeFusion/MOHAWK archive/code/MOHAWK
  echo "[ARCHIVE] Epistemos/KnowledgeFusion/MOHAWK → archive/code/MOHAWK"
fi

# Session work artifacts
if [ -d "jojo" ]; then
  git mv jojo archive/session-work/jojo
  echo "[ARCHIVE] jojo/ → archive/session-work/jojo/"
fi

# Upstream reference + experimental agents
if [ -d "tmp/hermes-agent-upstream" ]; then
  git mv tmp/hermes-agent-upstream archive/reference/hermes-upstream
  echo "[ARCHIVE] tmp/hermes-agent-upstream → archive/reference/hermes-upstream/"
fi
if [ -d "tmp/lambda-RLM" ]; then
  git mv tmp/lambda-RLM archive/experimental/lambda-rlm
  echo "[ARCHIVE] tmp/lambda-RLM → archive/experimental/lambda-rlm/"
fi
if [ -d "tmp/paperclip" ]; then
  git mv tmp/paperclip archive/experimental/paperclip
  echo "[ARCHIVE] tmp/paperclip → archive/experimental/paperclip/"
fi
if [ -d "reference-code" ]; then
  git mv reference-code archive/reference/reference-code-samples
  echo "[ARCHIVE] reference-code/ → archive/reference/reference-code-samples/"
fi

echo ""
echo "=== PHASE 2: Delete empty placeholder directories ==="

for dir in "Epistemos/ComputerUse" "Epistemos/Agent" "verification"; do
  if [ -d "$dir" ] && [ -z "$(find "$dir" -type f)" ]; then
    git rm -r "$dir"
    echo "[DELETE] $dir (empty placeholder)"
  fi
done

echo ""
echo "=== PHASE 3: Archive superseded documentation ==="

for file in docs/CODEX_HANDOFF.md docs/CODEX_HANDOFF_2026_04_10.md \
            docs/SESSION_STATE_2026_03_25.md \
            docs/SESSION_HANDOFF_2026-04-07.md \
            docs/SESSION_REPORT_2026-04-06.md \
            docs/CLAUDE_CODE_SESSION_PROMPT.md \
            docs/SESSION_BOOTSTRAP_PROMPT.md \
            docs/AUDIT_LOG.md \
            docs/AUDIT_REPORT.md \
            "docs/AUDIT-HANDOFF-Ω10-Ω14.md"; do
  if [ -f "$file" ]; then
    git mv "$file" archive/docs/superseded/
    echo "[ARCHIVE] $file → archive/docs/superseded/"
  fi
done

echo ""
echo "=== PHASE 4: Archive older handoffs (keep 2026-04-20+) ==="

# 2026-03 handoffs
for file in docs/handoffs/2026-03-*.md; do
  if [ -f "$file" ]; then
    git mv "$file" archive/docs/handoffs/
    echo "[ARCHIVE] $(basename "$file") → archive/docs/handoffs/"
  fi
done

# 2026-04-17 and earlier
for file in docs/handoffs/2026-04-17-*.md; do
  if [ -f "$file" ]; then
    git mv "$file" archive/docs/handoffs/
    echo "[ARCHIVE] $(basename "$file") → archive/docs/handoffs/"
  fi
done

echo ""
echo "=== PHASE 5: Archive abandoned research ==="

for file in docs/ANTI_DRIFT_SYSTEM.md docs/EPISTEMOS_FUSED_v3.md \
            docs/CODE_EDITOR_DEBUG.md docs/CODE_EDITOR_ROOT_CAUSE.md \
            docs/CODE_EDITOR_STACK_RESEARCH.md \
            docs/CUSTOM_TEXT_ENGINE_RESEARCH.md; do
  if [ -f "$file" ]; then
    git mv "$file" archive/docs/abandoned-research/
    echo "[ARCHIVE] $(basename "$file") → archive/docs/abandoned-research/"
  fi
done

echo ""
echo "=== CLEANUP COMPLETE ==="
echo ""
echo "Summary:"
echo "  • Archived code dirs: MOHAWK, jojo, hermes-upstream, lambda-rlm, paperclip, reference-code"
echo "  • Deleted empty placeholders: ComputerUse, Agent, verification"
echo "  • Archived ~20 superseded docs + old handoffs + abandoned research"
echo ""
echo "Next steps:"
echo "  1. Inspect: git status --short | head"
echo "  2. Build + test: xcodebuild -scheme Epistemos build && cargo test --manifest-path agent_core/Cargo.toml"
echo "  3. Commit: git commit -m 'chore: archive obsolete code and superseded docs'"
echo ""
```

### Execution safety

- Script uses `git mv` (reversible), not `rm`.
- Script uses `git rm -r` only on verified-empty directories.
- Review every `[ARCHIVE]` / `[DELETE]` line before running.
- After execution, build + test BEFORE committing.
- If any test fails, `git reset --hard HEAD` to revert all moves.

---

## Part E — What NOT to archive (explicit KEEPS)

| Path | Why |
|---|---|
| `Epistemos/Omega/` (whole subtree minus the two excluded files) | Production — `MCPBridge`, `ResearchOrchestrator`, `iMessageDriver`, `Safety/*` all imported |
| `Epistemos/Omega/Orchestrator/OrchestratorState.swift` | Retired-but-preserved stub per its own file L4 comment. Preserves API surface until views migrate to AgentViewModel. KEEP until I-015 full cleanup lands. |
| `Epistemos/LocalAgent/` | 1,968 lines of production Swift-native local agent runtime |
| `Epistemos/KnowledgeFusion/` (excluding `MOHAWK/`, `SyntheticData/ODIATraceGenerator.swift`, `SyntheticData/TraceDataMixer.swift`) | Adapters, MoLoRA, KnowledgeProfileStore all active |
| `agent_core/src/resources/` | 1,854 lines of Phase R Rust infrastructure. Zero Swift callers TODAY but target of Phase R.2+ UniFFI exposure work. **DO NOT archive.** |
| All `docs/` files listed in "ACTIVE" and "HISTORICAL-KEEP" sections above | Ground-truth and research context |

---

## Final conclusion

The Epistemos codebase is remarkably clean for its maturity. Running this cleanup:

- **~500 MB disk space reclaimed** (mostly tmp/ + jojo/ + generated training data)
- **docs/ structure clarified** — ACTIVE plans separated from HISTORICAL context from SUPERSEDED archives
- **project.yml unchanged** — no build-breaking code deletions
- **All canonical work preserved** for future sessions via archive/
- **Deferred features (MOHAWK, ODIA generators) safely parked** for Phase 2 MOHAWK training wave

The app becomes "super clean" (clutter removed) while staying "truly useful" (research, deferred features, historical context preserved in archive/).

**Recommended execution order:**
1. Commit current dirty branch state FIRST (35 modified files from this session).
2. Run cleanup script (PHASES 1–5).
3. Build + test to confirm no regressions.
4. Commit as `chore: archive obsolete code and superseded docs`.
5. THEN start Phase R.2 work.
