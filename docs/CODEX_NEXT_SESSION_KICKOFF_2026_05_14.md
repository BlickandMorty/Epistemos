# Codex Next-Session Kickoff — 2026-05-14
**Branch:** `codex/research-snapshot-2026-05-08`
**Latest commit:** `9b7629752` (Claude this session) — `feat(schemas): epistemos.{soul,skill,episode,semantic}.v1 first cut (B.5)`
**Mission:** continue Master Fusion plan execution per `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`. Everything except POSTV1 exclusions.

## Read first (in this order)

1. `CLAUDE.md` + `AGENTS.md`
2. `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` (953L — your master backlog, 54 items across 5 phases)
3. `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` (674L — concept atlas + source index)
4. `docs/MAS_FUSION_NO_COMPROMISE_2026_05_13.md` (Atlas of every concept, 32 domains)
5. `docs/CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` (your prior 13-pass audit)
6. `docs/CODEX_V1_CLOSURE_VERIFICATION_2026_05_14.md` (Claude's verification on top)

## What Claude shipped this session

Two items from the Master Fusion plan, both verified live:

| Item | Plan ref | Commit | Status |
|---|---|---|---|
| C.11 `/image` command hide for V1 | §C.11 (RCA12-P1-003 + RCA2-P1-014 + RCA3-P2-003) | `e48205e3b` | Pro Debug BUILD SUCCEEDED |
| B.5 4 epistemos.*.v1 JSON schemas (standalone files, README) | §B.5 | `9b7629752` | All 4 schemas parse as valid JSON; cargo test agent_core lib 1098 passed |

Plus the paid Apple Developer activation chain (`cb4a38f8d` + `6ccb26068`):
- App Group `group.com.epistemos.shared` restored in all 3 entitlements files (MAS Debug, MAS Release, Pro Debug, Pro Release — verified via `codesign -d --entitlements`)
- `DEVELOPMENT_TEAM` flipped from Personal `AL562BVF23` → paid `3BNL2669SL` everywhere in pbxproj
- Pro Debug signed bundle confirms `application-groups` lands

## What's left from Phase A (User actions — outside Codex scope)

Per `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §A:

- **A.1** MAS Release build verification (5 min — user runs the `xcodebuild Epistemos-AppStore -configuration Release` + verifies `codesign` output shows sandbox=true + App Group)
- **A.2** Provider credential live smoke (3-10 min — user adds OpenAI or Anthropic OAuth/key; unblocks PRO-001 + first-run web approval)
- **A.3** MAS simple-rewrite smoke (5 min — scratch note + ready runtime + rewrite turn)
- **A.4** Graph first-open framing decision (user issues scoped graph-camera approval OR accepts as-is)
- **A.5** App Store Connect metadata (~1-2 hours — privacy manifest, screenshots, App Privacy answers, URLs)
- **A.6** TestFlight upload + internal soak (~1 day)

You can't do any of A.1-A.6. Tell the user when they should run them per the plan's dependency graph (§3 of the plan).

## What Codex should do — priority order

### Track 1: Wave A No-Compromise quality wins (Phase B)

**B.1 Variant Ladder dispatcher retrofit on `vault.search` (highest ROI)** ⭐
- The typed `VariantLadder<I,O>` seam exists at `agent_core/src/variant_ladder/mod.rs` (303 LOC) with ZERO live callers
- The route-capture domain has reference impl at `agent_core/src/route/variant_b_classifiers.rs` (using its own `LlmClassifier` trait — different from the typed `VariantLadder`)
- Goal: wire the typed `VariantLadder` to `vault.search` end-to-end
- The blocker for the full version is that `VaultBackend` trait only exposes `hybrid_search` (RRF-combined), not separate lexical-only / embedding-only entry points
- **Approach A (small)** — Add `lexical_search` + `embedding_search` methods to `VaultBackend` trait (default impls fall through to `hybrid_search`), then wire 3 LadderVariant instances (Tier 1 Lexical / Tier 2 Embedding / Tier 3 RRF) with FLOOR_T1 ≥ 0.85, FLOOR_T2 ≥ 0.75, FLOOR_T3 ≥ 0.70 thresholds
- **Approach B (smaller)** — Wire ONE deterministic Tier-1 backstop (vault.list path-name overlap) → fall through to existing hybrid_search as Tier-3 sentinel. Cleaner first cut, proves seam wired
- Acceptance per doctrine §4.2: deterministic Tier-1 produces usable answer for happy path AND defers cleanly when below floor
- LadderLog row writes to Provenance Console per call
- Source-guard tests: happy-path Tier 1 exit + escalation gate proof

**B.4 reasoning field ≤256 token cap at GBNF compile**
- `Epistemos/LocalAgent/LocalToolGrammar.swift:73-96` builds the grammar with `AnyTextFormat()` inside `<think>` tags — no length cap today
- MLXStructured may not expose a `maxLength` parameter — verify
- If not, implement the cap at the streaming pipeline level (stop-token detection after 256 reasoning tokens; force-emit `</think>`)
- Per-model cap in `LocalTextModelID` capabilities table (32 for Qwen 7B per "Brief Is Better"; 256 default)

**B.9 NightBrain task body — vault_consolidate prototype**
- `agent_core/src/nightbrain/live.rs` registers 10 task names with NoOp placeholders
- Pick `vault_consolidate` as the prototype — finds duplicate notes by content hash, surfaces a dedup proposal (does NOT auto-merge; user-confirmed action)
- Wires into `epistemos.episode.v1` for the action proposal
- Bounded run window (≤5s) + safe rollback

**B.2 + B.3 + B.6 + B.7 + B.8** — see plan §B for full specs

### Track 2: Phase C audit PARTIAL closure (parallel)

**C.1 Hidden-capture metadata existing-note migration** (RCA-P0-003 + RCA5-P1-006 + RCA10-P0-001)
- New captures already clean. Add `Settings → Privacy → "Migrate hidden capture metadata"` action
- Scans vault for notes with HTML-comment capture metadata; surfaces in a user-confirmed migration sheet
- ~2-3 days

**C.7 FFI-only credential delivery** (RCA4-P1-001 final hardening)
- Process-wide env mirroring REMOVED 2026-05-09. Current state: scoped `withScopedAgentCoreEnvironment(operation:)` wrapper
- Remaining: all cloud provider credentials enter `agent_core` via typed FFI argument, not env var
- Source-guard test proves no env-var leak across FFI

**C.8 Verified-write coverage** (RCA7-P1-006)
- 5 high-risk paths still need `resourceVerifiedWrite` migration: AppCoordinator / CodeEditorView / ModelVaultBrowserStore / JournalIntents / sync-import flows
- Per-path regression tests

**C.13 DB fault-injection runtime matrix** (RCA-P0-002 + RCA10-P0-003)
- Inject corrupt store / missing schema / version mismatch / locked file
- Assert: fail-fast + user-visible error + no silent in-memory replacement
- Source-guard tests per fault class

**C.16 + C.17 + C.12** — operator smoke (computer-use):
- Voice temp-file MIC smoke
- Current Access runtime proof
- Connected-vault to Halo manual smoke

**C.2 + C.3 + C.4 + C.5 + C.6 + C.9 + C.10 + C.11 + C.14 + C.15 + C.18 + C.19-C.22** — see plan §C for full specs (most done; some operator-runtime-only)

### Track 3: Wave F XPC Mastery (Phase D — sequential AFTER user runs A.1 successfully)

Gate: User must run A.1 first (`xcodebuild -scheme Epistemos-AppStore -configuration Release`) and confirm App Group lands in MAS Release signed bundle BEFORE Wave F work. Same paid Team `3BNL2669SL`.

**D.1 VaultXPC service (narrowest entitlements first)** — start here
- `XPC_MASTERY_DOCTRINE_2026_05_03.md` §2.2 + §1.4
- New target: `VaultXPC` with `VaultXPC.entitlements` (`app-sandbox = true` + `application-groups` + `files.bookmarks.app-scope` ONLY)
- XPC interface exposes vault.* operations
- Main app routes vault operations through XPC service
- Trust attestation per §3
- Source-guard test pins entitlement set + interface shape

**D.2 CapabilityGrant HMAC-SHA256 tokens (in-process first)**
- `agent_core/src/capabilities/` new module
- `bitflags` for capabilities (TOOL_USE / FILE_READ / FILE_WRITE / VAULT_READ / VAULT_WRITE / NETWORK / COMPUTER_USE)
- HMAC-SHA256 signing with rotating key
- Time-limited (5 min default)
- Caveat narrowing (path scoping)
- In-process verify first; XPC wire integration in D.4+

**D.3-D.13** — see plan §D for full specs

## Acceptance bar per Codex session

Before pushing each commit:

1. **8-question PR discipline** (`MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` §6):
   - Stage / Wave?
   - GenUI route?
   - Sovereign?
   - Pro impact?
   - App Group?
   - Variant Ladder?
   - Atlas update?
   - Disambiguation?
2. **Build green** — `xcodebuild -scheme Epistemos` + `xcodebuild -scheme Epistemos-AppStore -configuration Debug CODE_SIGNING_ALLOWED=NO`
3. **Tests green** — `cargo test --manifest-path agent_core/Cargo.toml --lib` + Pro feature variant
4. **MAS leak audits green** — `strings` + `nm` scans ZERO matches
5. **Append row to Implementation Log** in `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §8 with date + phase + item + commit + WRV status
6. **No graph touches** unless user gave explicit scoped approval (`V1-GATE-GRAPH-001`)
7. **No vault data mutation** without evidence + rollback plan

## Phase E gate: when to start the 5 recursive passes

Per plan §Phase E gate:
- ✅ Phase A complete (all 6 sub-gates green — user actions)
- ✅ Phase B core items: B.1, B.4, B.5 merged
- ✅ Phase C core items: C.1, C.7, C.8, C.11, C.12, C.16, C.17 merged
- ✅ Phase D Stage 1: D.1 + D.2 merged
- ✅ All Rust + Swift tests green
- ✅ MAS leak audits ZERO matches
- ✅ Apple's official scanner PASS

Then run 5 consecutive zero-new-blocker recursive passes. Each pass appends to `CODEX_V1_FINAL_RECURSIVE_RELEASE_AUDIT_2026_05_14.md` §Recursive Pass Log.

Then MAS submission.

## Reference test commands

```bash
cd /Users/jojo/Downloads/Epistemos

# Build matrix
xcodebuild -scheme Epistemos -destination 'platform=macOS' build
xcodebuild -scheme Epistemos-AppStore -destination 'platform=macOS' -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Test matrix
cargo test --manifest-path agent_core/Cargo.toml --lib
cargo test --manifest-path agent_core/Cargo.toml --features pro-build --lib
cargo test --manifest-path omega-mcp/Cargo.toml --lib
cargo test --manifest-path omega-ax/Cargo.toml --lib
cargo test --manifest-path epistemos-research/Cargo.toml --features research --lib

# Validate any new JSON schemas
for f in agent_core/schemas/*.schema.json; do
  python3 -c "import json; json.load(open('$f'))" && echo "OK $f"
done

# MAS leak audits (re-run after EVERY Wave A/F change)
APP=$(find ~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Debug -name "Epistemos.app" -not -path "*Index.noindex*" 2>/dev/null | head -1)
find "$APP" -type f -print0 | xargs -0 strings 2>/dev/null | grep -E '^(/usr/local/bin/(claude|codex|gemini|kimi)|/usr/bin/osascript|/bin/bash|/bin/sh|/usr/local/bin/docker)$'
nm -gU "$APP/Contents/Frameworks/libagent_core.dylib" 2>/dev/null | grep -iE 'osascript|bash_execute|cli_passthrough|stdio_mcp|browser_subprocess|imessage_send|cronjob|cli_(claude|codex|gemini|kimi)|computer_use|screencap'
```

## What Codex must NOT do

- **No graph rendering / camera / physics / layout / edges / hologram changes** without user-issued scoped approval (`V1-GATE-GRAPH-001`)
- **No vault reset / delete / casual migration** — evidence + rollback plan required
- **No Pro features bleed into MAS** — MAS leak audits must stay at ZERO matches
- **No silent compromises** — every deferral appends a row to `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §10 Compromises Recorded
- **No POSTV1 exclusions** — Wave B / C / D (Halo V1 full) / E / G / H / I / J are explicitly out-of-scope until V1 ships. Per `POSTV1-EXCL-001`

## Five-minute orientation

```bash
git log --oneline 6ccb26068..HEAD | head -10  # see Claude's session work
git status --short  # working tree state
cat docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md | head -100  # plan structure
cat agent_core/schemas/README.md  # B.5 first cut + next-slice tasks
```

---

*— Master continuation kickoff. Read the 6 docs above, pick from Phase B / C / D priority order, honor the 8-question PR discipline, append to Implementation Log per commit. No drift, no compromise except POSTV1 exclusions.*
