# 00 - Read First: Epistemos MAS Master Canon

ID: `EPISTEMOS-MAS-MASTER-CANON-2026-07-08`
Lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`
Status: canonical MAS-only fusion packet

This ZIP is the fused, pruned, contradiction-cleaned operating canon for the
Epistemos Mac App Store pivot. It is not a raw dump and not a lazy repack. The
root files are the active operating corpus. The original ZIPs are preserved
unchanged under `source_archives/originals/` for provenance and audit.

## Latest Owner Steer

The owner clarified that `research1.zip`, `research2.zip`, `research3.zip`,
and `research4.zip` are the most updated executive research outputs. This
master canon therefore treats those four as the primary synthesis layer.

Older `mac c`, `stack`, MAS pivot, MAS C, instruction-profile, and release
source ZIPs were still inventoried, hashed, extracted, and preserved. They are
used as donor/provenance evidence, not allowed to pull the active plan back
toward Pro, Experimental, 1Code, Goose, Kindred, OpenChamber, browser-use,
terminal, stdio MCP, local-server, or sidecar lanes.

## What Was Fused

Input archives fused: 18.

Primary/latest executive inputs:

- `research1.zip`
- `research2.zip`
- `research3.zip`
- `research4.zip`

Current control and raw provenance inputs:

- `epistemos-mas-c-control-pack-2026-07-08.zip`
- `epistemos-mas-pivot-cloud-research-packet-2026-07-07.zip`
- `epistemos-mas-pivot-research-2026-07-08.zip`

Older donor/provenance inputs:

- `mac c.zip`
- `mac c v2.zip`
- `mac v3.zip`
- `mac c v4.zip`
- `stack1.zip`
- `stack2.zip`
- `stack3.zip`
- `stack4.zip`
- `stack5.zip`
- `epistemos-agent-instruction-profile-2026-07-07.zip`
- `files (5).zip`

Every original ZIP is unchanged in `source_archives/originals/`. Archive hashes,
sizes, file counts, priorities, and extraction metadata are in
`source_inventory.json`. Every extracted file is classified in `source_map.md`
and `source_map.json`.

## What Is Active

Epistemos is one Mac App Store product.

Active lane:

- `Epistemos-AppStore`
- `EPISTEMOS_APP_STORE`
- `MAS_SANDBOX`
- MAS/June as the only active agent surface
- in-process `agent_core`
- native Swift/AppKit/SwiftUI where the surface should feel native
- bundled WKWebView assets where web is the honest best component host
- Keychain for secrets
- security-scoped bookmarks and sandbox-safe file access
- approval-gated tools
- vault files and approved artifacts as durable truth

Active build spine:

1. KEELSTONE storage, release, pruning, and archive truth.
2. MAS June agent seam and Epdoc MiniChat/Assist as June-owned.
3. LUMENLENS editor/provenance and RECKONER datasets inside one workspace
   fabric.
4. Capability ring: ResearchHub, Quick Capture, Sync, PDF/Vision/Speech,
   WebKit browser-lite, and source/provider legality.
5. Release evidence: entitlements, privacy manifests, required-reason APIs,
   archive scans, source legality, storage soak tests, and App Review notes.

## What Is Parked

The following are not active product lanes:

- Pro
- Developer-ID
- Experimental
- 1Code
- OpenChamber
- Goose runtime/surface
- Kindred runtime/companion lane
- browser-use / Chromium automation
- terminal / code-exec
- stdio MCP
- local server
- subprocess sidecars
- hidden sidecars
- second chat runtime
- second transcript database
- second tool authority
- second data room

Useful ideas from parked lanes may be salvaged only by rebuilding them through
MAS-safe June, native Swift/AppKit/SwiftUI, bundled WKWebView assets,
in-process `agent_core`, Keychain, sandbox-safe storage, and approval-gated
tools.

## Agent Read Order

1. `00_READ_FIRST.md`
2. `01_OWNER_LOCK_AND_CANONICAL_THESIS.md`
3. `02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md`
4. `03_MINIMAL_PROMPT_PACK.md`
5. The relevant domain doc: `04`, `05`, `06`, `07`, or `08`
6. `10_LOCAL_AGENT_REDIRECT_AND_STATUS_TEMPLATES.md` before handoff/status work
7. `09_PARKED_PROVENANCE_AND_SUPERSESSION_LEDGER.md` only when checking
   provenance or resolving contradictions

Recommended first build prompt:

`03_MINIMAL_PROMPT_PACK.md` / Prompt 1 - MAS Pivot Program Director, then
Prompt 2 - KEELSTONE Storage and MAS Release Gate.

## Never Do These Things

Never revive a parked lane because an older file mentions it. Never make
GRDB/SQLite/search/graph/cache durable truth over vault files/artifacts. Never
implement MiniChat as Goose, 1Code, Kindred, Node, Tauri, local server,
subprocess, or a second transcript/tool runtime. Never ship ResearchHub
scraping, Sci-Hub, LibGen, Google Scholar scraping, unauthorized full-text
downloads, hidden paid-content access, or credential harvesting. Never claim
MAS release readiness without archive-level evidence.

## Source Archives Only

Everything under `source_archives/originals/` is preservation/provenance. These
files are not the daily prompt surface. Use `source_inventory.json`,
`source_map.md`, `source_map.json`, and
`09_PARKED_PROVENANCE_AND_SUPERSESSION_LEDGER.md` to decide when an older
archive should be inspected.

## Still Requires Local Repo Verification

This master canon includes exact commands, but it cannot prove current live
repository state from ZIPs alone. These remain `REQUIRES LOCAL VERIFICATION`
until run in the repo:

- `project.yml` target flags and XcodeGen truth
- every `*.entitlements`
- every `PrivacyInfo.xcprivacy`
- `AppSurface.swift`, `LandingView.swift`, and MAS archive surface routing
- `JuneAgent/*` actual bridge/runtime wiring
- `VaultSyncService`, `VaultIndexActor`, `AtomicVaultWriter`, index actors
- Epdoc editor bridge files and editor bundle target membership
- RECKONER dataset/grid source ownership
- `agent_core/src/bridge.rs` and `agent_core/src/tools/*` allowlists
- App Store hardening tests and archive leak checks

Use the command blocks in `08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md` and
`10_LOCAL_AGENT_REDIRECT_AND_STATUS_TEMPLATES.md` before claiming release
readiness.
