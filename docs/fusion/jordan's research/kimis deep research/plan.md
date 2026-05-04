# Epistenos Master Plan — 3 Coding Cycles (May 2026)

## Context Synthesis (from 9 canonical docs)

**Existing substrate (already on disk, do NOT rebuild):**
- AgentEvent provenance: PR0–PR52 closed, 52 instrumented surfaces
- Sovereign Gate: PR1–PR17 closed, 17 destructive-action gates
- OpLog: PR1–PR7 closed, BLAKE3 Merkle chain, Swift bridge, replay, export
- GraphEvent: PR1–PR9 closed, durable mutation mapping, audit projection
- Durable GraphEvent: PR1–PR9 closed, Halo consumer, Trace Inspector
- TextCapturePipeline: Card 4 vertical slice closed
- 1403 Swift tests, 549 Rust tests, 131 MCP tests

**4 truly new pieces (net-new code):**
1. App Group container migration — move shared state to `group.com.epistemos.shared`
2. AgentXPC + ProviderXPC service skeleton — XPC helpers for bounded execution
3. Simulation Mode v1.6 — Landing Farm + Notes Sidebar Skin (from worktree)
4. KV-Direct gate experiment — test harness, binary outcome

**Plus:** Resonance chip mount into production view (already built in prior session, needs integration)

## Cycle 1 — SLICE 1: App Group Container Migration

**Position:** Hackathon Block A prerequisite + Hackathon Block B prerequisite
**Tier:** Core (MAS-shippable foundation)
**Dependencies:** None — this is the foundation

**What it does:**
Moves all shared substrate state from app-private containers into the App Group container `group.com.epistemos.shared`. Creates the mmap arena, blob store, provenance SQLite, vault index SQLite, and resonance SQLite. All XPC helpers will read/write here.

**Agent fleet:**
1. RESEARCH → Reads `mac store edition.md` §"Shared arena", `hermes.md` §"Keeping the substrate unified"
2. MATH → Verifies arena layout is page-aligned, atomic ordering is Release-Acquire
3. HARDWARE → MAS-safe: file-backed mmap, not shm_open
4. SOFTWARE → Rust `Arena` struct + Swift `ArenaPathResolver` + UniFFI bridge
5. INTEGRATION → Composes into existing `AppBootstrap` + `AppEnvironment`
6. SAFETY → Red-team: arena corruption, double-init, path traversal
7. SHIPPABILITY → App Review: uses documented App Group APIs only

**Code output:**
- `agent_core/src/arena/mod.rs` — Rust arena implementation
- `Epistemos/Shared/ArenaPathResolver.swift` — Swift path resolution
- `Epistemos/Shared/AppGroupContainer.swift` — App Group container singleton
- Tests: arena init, ring buffer, corruption detection

## Cycle 2 — SLICE 2: AgentXPC + ProviderXPC Service Skeleton

**Position:** Hackathon Block A — THE priority
**Tier:** Core (MAS-shippable)
**Dependencies:** Slice 1 (App Group container)

**What it does:**
Creates the XPC service bundle with AgentXPC (bounded local execution) and ProviderXPC (cloud boundary). Control plane via XPC (tiny typed messages). Data plane via App Group mmap arena (handles, not payloads). Existing `HermesCommandDispatcher` + 26 parity commands run inside AgentXPC.

**Agent fleet:**
1. RESEARCH → Reads `hermes.md` (full), `mac store edition.md` §"XPC service interface"
2. MATH → Verifies capability grant HMAC is constant-time
3. HARDWARE → MAS-safe: XPC services get their own sandbox, no private entitlements
4. SOFTWARE → `AgentServiceProtocol.swift`, `AgentXPC/main.swift`, `ProviderXPC/main.swift`, capability grants Rust
5. INTEGRATION → Wires into existing `HermesGatewayPolicy` + `ToolTierBridge`
6. SAFETY → Red-team: XPC spoofing, capability forgery, helper escalation
7. SHIPPABILITY → App Review: XPC services are documented Apple pattern

**Code output:**
- `XPCServices/AgentXPC/main.swift` — AgentXPC service entry
- `XPCServices/AgentXPC/AgentService.swift` — service implementation
- `XPCServices/ProviderXPC/main.swift` — ProviderXPC service entry
- `Epistemos/XPC/AgentServiceProtocol.swift` — @objc protocol
- `Epistemos/XPC/AgentServiceClient.swift` — client wrapper
- `agent_core/src/capability.rs` — HMAC capability grants
- Tests: XPC ping, submit/cancel, capability verify

## Cycle 3 — SLICE 3: Simulation Mode v1.6 (Landing Farm + Notes Sidebar Skin)

**Position:** Hackathon Block B
**Tier:** Core (MAS-shippable)
**Dependencies:** Slice 1 (App Group for companion state), AgentEvent v1.6 forward kinds (PR34 already closed)

**What it does:**
Lands Simulation Mode v1.6 from the worktree. Landing Farm as default app open view. Notes Sidebar Skin with companion presence. Companion creation/delete/restore flows with Touch ID gates. Companion reacts to live AgentEvent stream.

**Agent fleet:**
1. RESEARCH → Reads `simulation` worktree DOCTRINE.md v1.6 invariants I-1 to I-15
2. MATH → Animation duration ≥ adapter apply duration (Invariant I-11)
3. HARDWARE → Metal rendering, reduce-motion fallback (Invariant I-14)
4. SOFTWARE → `LandingFarmView.swift`, `CompanionView.swift`, `NotesSidebarSkin.swift`, companion creation/delete/restore
5. INTEGRATION → Consumes live AgentEvent + GraphEvent stream
6. SAFETY → Red-team: companion spoofing, animation seizure risk, tier leakage
7. SHIPPABILITY → App Review: animation accessibility, reduce-motion support

**Code output:**
- `Epistemos/Views/Landing/LandingFarmView.swift` — main landing view
- `Epistemos/Views/Landing/CompanionView.swift` — companion rendering
- `Epistemos/Views/Notes/NotesSidebarSkin.swift` — sidebar skin
- `Epistemos/Views/Landing/CompanionCreationFlow.swift` — creation wizard
- `Epistemos/Views/Landing/CompanionDeleteSheet.swift` — delete with Touch ID
- Tests: companion CRUD, AgentEvent reaction, reduce-motion fallback

## Execution Order

Since the user wants "3 more cycles of coding", we execute all 3 slices in sequence. Each slice gets the full 7-agent + 7-cycle treatment, but we parallelize within each cycle where possible.

**Meta-audit after Slice 3:**
- Re-read all 9 docs for drift
- Sum WBO-6 contributions (these are infrastructure slices, minimal math drift)
- Verify bandwidth budget (arena is file-backed, negligible)
- Check dependency graph: Slice 1 → Slice 2 → Slice 3 ✓
- Verify hackathon priorities still front-of-queue ✓

## Anti-patterns enforced

- No `ProseEditor*.swift` edits without protected-path gate
- No `MetalGraphView.swift` edits without coordination
- No `HologramController.swift` edits
- No subprocess for inference
- No LAContext outside `SovereignGate.swift`
- No private `com.apple.private.*` entitlements
- No per-frame allocation in render loops
- No string-keyed dispatch

## Rollback plan

Each slice is a git commit. Rollback = `git revert <commit>`. Arena migration has backward-compat fallback (reads old path if App Group not initialized).
