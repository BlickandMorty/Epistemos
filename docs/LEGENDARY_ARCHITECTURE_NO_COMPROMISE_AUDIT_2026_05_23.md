# Legendary Architecture — No-Compromise Audit (2026-05-23)

> **2026-05-31 naming supersession:** preserve the original no-compromise
> ambition, but read old `research-tier`, `Vault`, and `Omega` language through
> the current two-build grammar: `MAS` and `Pro`, with Pro statuses `Pro Live`,
> `Pro Gated`, `Pro Research`, `Pro Vault-Preserved`, and `Pro Omega`.
> Read old `ACS` governance language as `SCOPE-Rex` / `SovereignGate`;
> reserve `AcsAnchor` / Anchored Cognitive Substrate for coordinate,
> provenance, and residency anchoring.
>
> **2026-06-01 residency supersession:** the no-compromise ambition now includes
> Residency PatternBoost as an offline/idle Pro Research discovery layer for
> UAS assembly genomes, repair kernels, sparse fingerprints, elite archives,
> lattice abstention, compute resume leases, and cold route/layout patches.
> Read `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md` and
> `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md` before using
> this audit for active model-state, sparse residency, mmap/SSD, dynamic
> compute, or 70B-cocktail work.

User mandate, verbatim:

> "no compromises so all the things i can put it in the app literally need to be there - future/pro/research-tier work. just need u to do a final check to make sure literally the app becomes legendary because of the brilliant architecture."

> "i want this included in the work as well — making sure that all the remaining work is truly what im supposed to do to the point that if i was to go back to all 20 or so chat threads and did a deep audit of all the research i did, that my app would have 100% of all the research doctrine theorems and etc. work done."

> "want to make sure that everything is truly there or will be built — only superseded never get worse."

This audit confirms what's preserved, what's hardened, what's live, and the **explicit no-orphaned-data-class invariant** every Phase 2+ PR must honor.

---

## 1. The canon — restated

**"Everything is one substrate object, expressed through different coordinates, planes, residencies, and primitive representations."**

Pixels, vectors, notes, graph nodes, KV pages, model components, AnswerPackets, tool results, and proofs are NOT separate "worlds." They are typed projections of the same addressable fabric.

The 7 Laws (from [docs/CANONICAL_CHRONICLE_2026_05_23.md:43](docs/CANONICAL_CHRONICLE_2026_05_23.md)) every PR must satisfy or call out explicitly:

1. **Density law** — Morph/EML approximates compact controller policies where the formal domain permits.
2. **Address law** — every cognitive object has a stable UAS/UASA address independent of residency.
3. **Active-support law** — only the relevant slice of notes/graph/memory/model/tools/agent state wakes.
4. **Lattice-error law** — every compressed or approximate representation pays into WBO.
5. **Glue law** — local context must cohere before it becomes global context.
6. **Duplex law** — hard compact and soft page-backed branches both allowed, but routing error is accounted.
7. **Witness law** — every meaningful action is typed, permissioned, logged, replayable, and visible.

Canon anchor: [docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md](docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md) (182 lines; read forward as UAS = address fabric, AcsAnchor = coordinate/provenance anchor, SCOPE-Rex/SovereignGate = governance and admission).

---

## 2. No-Orphaned-Data-Class Invariant (NEW — must be in every PR going forward)

> **No data class may remain orphaned. Every pixel buffer, vector, note, graph node, model component, KV page, tool result, AnswerPacket, mutation, claim, proof, and event must have:**
> - **UAS address** (`UasAddress { kind: UasKind, payload_id: String }`)
> - **Plane placement** (`RuntimePlane::{State, Episodic, Assembly, Controller, Verification}`)
> - **Residency tier** (`ResidencyTier::{CurrentApp, VerifiedFloor, CapabilityCeiling}`)
> - **WBO/error policy** if approximate (`LatticeBudget` + `WboLedgerEntry`)
> - **WRV status** if product-facing (`{Wired, Reachable, Visible, Verified}`)

**Why this matters:** This is the bridge from your original lattice ontology ("pixels = numbers = vectors = graph data on one lattice") into the working app. Without it, the doctrine becomes "everything is only an EML tree" — the canonical drift Codex flagged. EML is ONE primitive; the substrate fabric is wider.

**Enforcement:** Every Phase 2+ PR description MUST include a §No-Orphan check listing which data classes the PR touches + which 5 invariants are satisfied (or explicitly waived with reason).

---

## 3. Preservation matrix — what's preserved vs hardened vs live

| Concept | Preserved? | Hardened? | Live? | Where |
|---------|-----------|-----------|-------|-------|
| **Same-substrate doctrine** | YES (canon doc + 7 Laws) | Mostly docs | NO (T14 not wired) | `UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` |
| **UAS address identity** | YES (`agent_core/src/uas/`) | Basic tests | Partial (vault not yet returning `Vec<UasAddress>`) | T3 salvage |
| **Pixels/shaders as substrate** | Partial (Metal shaders + PixelSurface) | Partial | Visual/render layer only | `Epistemos/Shaders/` |
| **Vectors/embeddings/pages** | YES (HNSW + PageGather + ActiveAssembly) | Partial | Not in chat/runtime yet | T3 + epistemos-shadow |
| **Lattice/WBO error law** | YES (`agent_core/src/lattice_wbo/`) | Strong (305 tests) | OpLog accounting wired | T17B salvage |
| **AcsAnchor / five-plane coordinates** | YES (`epistemos-research/src/five_planes.rs` 308 LOC) | Partial / Pro Research | NOT product-wired (T14 needed) | UAS canon §2; legacy UAS-ACS rows map to UAS + AcsAnchor |
| **Primitive IR stack (EML/Tropical/Scan/Operator/Info/Geometry)** | YES (T5 salvaged) | Phase 1 hardened | NOT user-visible | T5 salvage |
| **Falsifier floor** | YES as docs (15+) | NOT enough (0/15 PASS on M2 Pro) | Mostly not implemented | `docs/falsifiers/` + T23B |
| **Cognitive DAG (10 NodeKind + 10 EdgeKind)** | YES | Phase 8.A-G shipped | Substrate live; visualizer NOT live (W-26) | `agent_core/src/cognitive_dag/` |
| **SCOPE-Rex (MutationEnvelope + WitnessedState + ClaimGraph + RunEventLog)** | YES | Hardened | Partial (RunEventLog wired via T11) | `agent_core/src/scope_rex/` |
| **KV-Direct gate** | YES (290 LOC Rust + 65 LOC Metal) | MAS-safe shipped when bit-identical | F-KV-Direct-Gate harness NOT yet runnable | `agent_core/src/scope_rex/kv/direct_gate.rs` |
| **Provenance ledger (Phase 1)** | YES | Hardened | Wired via T17B/T18B OpLog | `agent_core/src/provenance/` |
| **5 V6.1 Metal kernels (PageGather / SemiseparableBlockScan / LocalRecallIsland / ControllerKernelPack / PacketRouter1bit)** | YES (doctrine targets) | NOT YET (target-only) | NOT live | V6.1 lock + V6.2 falsifier order |
| **70B Local Cocktail (F-70B)** | YES (Pro Vault-Preserved / Pro Research) | NOT yet | NOT yet | T23 |
| **Foundational Seven (E1-E7)** | YES (`theorem_status::FOUNDATIONAL_SEVEN`) | Doctrine | NOT yet visible | acs.rs cross-link |
| **Goodfire VPD/SPD parameter decomposition** | YES (revalidated live 2026-05-07 per V6.2 intake) | Doctrine | NOT yet wired | V6.2 intake |
| **Mamba-2 / SSM substrate** | YES (Phase 1A complete) | save/load/resume/staleness all wired | Local mlx-swift-lm fork ready | `project_mamba2_runtime` |
| **Goose migration to Rust agent_core** | YES | 95% ready | Phase 1: runAgentSession→ChatCoordinator pending | `project_goose_migration` |
| **Vault Memory System (6-phase + Neural Cache + FFI)** | YES | All phases + NightBrain jobs done 2026-04-08 | LIVE | `project_vault_memory_system` |
| **NightBrain idle scheduler** | YES (`agent_core/src/nightbrain/` 949 LOC) | 3-of-7 eligibility conditions wired | Diagnostic-only V1 | `project_nightbrain_doctrine` |
| **XPC Mastery (5-service decomposition)** | YES (doctrine) | NOT YET | NOT YET (gated on paid team per V2 plan) | `XPC_MASTERY_DOCTRINE_2026_05_03` |
| **Simulation Mode v1.6 (Block/Sage/Orb body grammars + Hermes Snake)** | YES | Partial (UI shell ~50%, assets ~0%, LoRA swap ~0%) | NOT YET | `simulation` worktree (Hermes Swift files contradict purge — assets-only extraction possible) |
| **Honest-Handle FFI Doctrine** | YES | Shipped 2026-05-04 | LIVE (RustShadowFFIClient + epistemos-shadow honest_handle.rs) | `project_honest_handle_ffi_doctrine` |
| **Provenance Console** | YES (third leg of MAS feature trio) | Shipped 2026-05-04 at ad6280cf | LIVE | `project_provenance_console_doctrine` |
| **Quick Capture (25 Rust files Tier A/B/C/D)** | YES (preserved in vigorous-goldberg) | Mixed | Pro-tier deferred per MAS-First doctrine | `project_quick_capture_salvage_triage` |
| **Halo Shadow index (W8.4 / W8.7 — tantivy 0.22 + usearch 2.24 HNSW + RRF k=60)** | YES | LIVE | LIVE | `epistemos-shadow` crate |
| **Epdoc (Tiptap editor)** | YES (W7.17) | LIVE | LIVE | `Epistemos/Views/Epdoc/` |
| **Hermes namespace (Swift / Rust subprocess)** | DELETED 2026-05-05 (intentional purge) | N/A | N/A | Use `LocalAgent*` (Swift) / `Runtime*` (Rust). HF model paths preserved as ground truth. |

---

## 4. All 53 W-rows mapped to terminals (no row left orphaned)

Status notation: ✅ DONE · 🟡 PARTIAL · 🔴 NOT-STARTED · ⏳ GATED. Per BACKLOG:312-317, DONE = (1) code path on main + (2) measurable acceptance bar + (3) screenshot-verified surface + (4) no baseline regression.

### W-01..W-10: Substrate-to-Product (P0/P1)
- W-01 UasAddress on vault notes 🔴 → **Terminal A** (Eidos binding needs this)
- W-02 UasKind on agent traces 🔴 → **Terminal C** (System G RunEventLog)
- W-03 AcsAnchor in ClaimLedger 🔴 → **Terminal E** (SCOPE-Rex admission + AcsAnchor provenance)
- W-04 page_gather → vault retrieval 🔴 → **Terminal A** + **Terminal B**
- W-05 Active Assembly in agent_runtime 🔴 → **Terminal C** (System G consumer)
- W-06 Tri-Fusion mutations in agent_runtime + Epdoc 🔴 → **Terminal C** + new T1 pull from `codex/t1-trifusion-2026-05-16`
- W-07 EML observatory health row 🔴 → **Terminal D** (Substrate Health panel)
- W-08 EML potential in ConfidenceRouter 🔴 → **Terminal D** consumer
- W-09 Scan-IR ↔ SemiseparableBlockScan 🔴 → **Terminal F** (falsifier substrate)
- W-10 UAS/AcsAnchor substrate health row 🔴 → **Terminal D**

### W-11..W-18: Agent + Model (P0)
- W-11 ActiveConstellationRow live binding 🟡 → **Terminal D** consumer
- W-12 Per-model agent badges 🔴 → **Terminal D** + side-task
- W-13 Power-user mode UI toggle 🔴 → **side task** (ISSUE-2026-05-16-015)
- W-14 AnswerPacket runtime emission ✅ PASS (per-row badge = W-27 → **Terminal B**)
- W-15 AgentBlueprint creation flow 🟡 → **Terminal C** closure
- W-16 Run timeline + replay 🔴 → **Terminal C**
- W-17 Local agent diagnostics 🟡 → **Terminal D**
- W-18 EML confidence in timeline 🔴 → **Terminal C** + **Terminal D**

### W-19..W-23: Vault retrieval honesty (P0)
- W-19 ChatCoordinator Vault Context Contract 🟡 → **Terminal B** closure (pull T4's tests from `codex/t4-vault-2026-05-16`)
- W-20 Provenance cards in 3+ surfaces 🟡 → **Terminal B** (Halo + ChatInputBar pending)
- W-21 Vault recall health row 🔴 → **Terminal B**
- W-22 hybrid_search returns Vec<UasAddress> 🔴 → **Terminal G** (T14 needs this)
- W-23 Vault Context Contract everywhere + CI gate 🔴 → **Terminal B** + CI

### W-24..W-28: Cognitive DAG + Provenance (P1)
- W-24 DAG node carries UasAddress + AcsAnchor 🔴 → **Terminal G** (T14 wiring)
- W-25 Provenance Console AcsAnchor column 🔴 → **Terminal E**
- W-26 Cognitive DAG visualizer 🔴 → **Terminal D** + new front-end work
- W-27 AnswerPacket badge per chat row 🔴 → **Terminal B**
- W-28 ResidencyTier indicator 🔴 → **Terminal G** (T14)

### W-29..W-33: UI surface unification (P1)
- W-29 Unified Substrate Health panel 🔴 → **Terminal D**
- W-30 Cognitive Weight Class badges 🔴 → **Terminal D**
- W-31 Audio diagnostics panel 🔴 → **side task** (post-audio-PR-56)
- W-32 Experimental Features panel 🔴 → **side task**
- W-33 Substrate Drift Monitor row 🔴 → **Terminal D**

### W-34..W-39: Biometric lock (GATED — fires after T1+T2+T6 land)
- W-34 BiometricLockService ⏳ GATED
- W-35 LockedContentGate macaroon ⏳ GATED
- W-36 Retrieval filters locked items ⏳ GATED
- W-37 Lock badge + unlock sheet UI ⏳ GATED
- W-38 Spotlight respects lock state ⏳ GATED
- W-39 Recovery-code printable view ⏳ GATED

### W-40..W-46 (research): Research-tier (P3)
- W-40 F-ULP-Oracle harness 🔴 → **Terminal F**
- W-41 5 Metal kernels 🔴 → **Terminal F** + Apple-platform external work
- W-42 F-KV-Direct-Gate (Qwen 3 8B 128k) 🔴 → **Terminal F**
- W-43 F-70B-Cocktail composition 🔴 → **Terminal F** (research)
- W-44 6 IR primitives in hyperdynamic_schemas 🔴 → **Terminal G** (T14 typed projections)
- W-45 Per-IR Lean proofs 🔴 (T5 ships 28 sorries; budget-gated; lake build green) → **Research-tier**
- W-46 (T23B block) Artifact validator harness 🔴 → **Terminal F** (T23B sibling)

### W-46..W-53 (T09 block): Drift + cleanup (P1/P2 security)
- W-46 (T09 block) CLAUDE.md macaroons-orphan claim 🔴 → **side task** (doc-only fix)
- W-47 (T09 block) MutationEnvelope naming collision + alias table 🔴 → **side task** (doc-only)
- W-48 omega-mcp/pty.rs env-leak ✅ **DONE in PR #45 today**
- W-49 IMessageDriverService missing `#if !EPISTEMOS_APP_STORE` 🔴 → **side task** (P2 ship-hardening)
- W-50 MemoryTier enum vs prompt-deck canon divergence 🔴 → **side task** (T17B canonicalizes first)
- W-51 Pro-tier capability gating in omega-mcp dispatch 🔴 → **Pro-tier deferred** (F-OmegaMCP-ProToolGating)
- W-52 CSISafeguard wired into CloudKnowledgeDistillationService 🔴 → **Terminal E** (P4 in ladder)
- W-53 ModelDownloadManager SHA256 LFS hash verification 🔴 → **side task** (P2 security; supply-chain integrity)

### Eidos block W-46..W-51 (under §3.4 closed-citation, not §3.9 T09 drift)
- W-46 (Eidos) EidosBridge.swift FFI 🔴 → **Terminal A**
- W-47 (Eidos) ChatCoordinator validate_citations 🔴 → **Terminal A**
- W-48 (Eidos) Brain Panel "Retrieved by Eidos" surface 🔴 → **Terminal A** + **Terminal D**
- W-49 (Eidos) LedgerBackedClaimEvidence ✅ **RUST-LANDED** (ce69d4f28; 9 tests); pending W-46 wire
- W-50 (Eidos) DagBackedGraphNeighborhood 🔴 → **Terminal A** sibling
- W-51 (Eidos) ShadowBackedSemanticIndex 🔴 → **Terminal A** sibling

---

## 5. Falsifier suite — full register (15+ already named; add 2 new)

| # | Falsifier | Already in `docs/falsifiers/` | Target Terminal |
|---|-----------|-------------------------------|------------------|
| 1 | F-VaultRecall-50 + baseline | ✅ | **Terminal F** |
| 2 | F-PageGather-M2Pro | ✅ | **Terminal F** |
| 3 | F-UAS-ZeroCopy-Spine (5 paths) | ✅ | **Terminal F** |
| 4 | F-ULP-Oracle | ✅ | **Terminal F** |
| 5 | F-ControllerKernelPack | ✅ | **Terminal F** |
| 6 | F-ACS-Anchor-Addressing | ✅ | **Terminal E** |
| 7 | F-ActiveAssembly-Minimal | ✅ | **Terminal C** + **F** |
| 8 | F-KV-Direct-Gate | ✅ | **Terminal F** + research |
| 9 | F-LocalRecallIsland-32K | ✅ | **Terminal F** |
| 10 | F-PacketRouter1bit-Dispatch | ✅ | **Terminal F** |
| 11 | F-SemiseparableBlockScan-Correctness | ✅ | **Terminal F** |
| 12 | F-ShadowFirst-PageEscalation | ✅ | **Terminal A** + **F** |
| 13 | F-70B-Local-Cocktail-Composition | ✅ | Research-tier (Vault) |
| 14 | F-OmegaMCP-ProToolGating | (referenced) | Pro-deferred |
| 15 | F-Eidos-Bridge-RoundTrip | NEW (Terminal A spec) | **Terminal A** |
| **16** | **F-UAS-CopyCount** — NEW per Codex: counts tensor copies on the UAS hot path; PASS = 0 copies between Swift / Rust / Metal / MLX / KV / HNSW | NEW | **Terminal G** |
| **17** | **F-ACS-AnchorLookup** — NEW per Codex: every claim resolves to AcsAnchor in O(1) via anchor_registry.rs; PASS = lookup < 1 μs over 10k claims | NEW | **Terminal G** |

After **Terminal F + G** close: 15+ falsifiers measurable, ≥ 7 PASS on M2 Pro 16 GB.

---

## 6. Pro-tier + Research-tier — what to preserve (don't actively develop, but don't lose)

Per `project_mas_first_focus_2026_05_03` + `project_app_store_first_sequencing`:

**MAS-shippable surface (actively built — Phase 2):**
- Local-agent path · sandboxed extensions · biometric lock · FoundationModels · MLX · cognitive substrate · Simulation v1.6 (Block/Sage/Orb body grammars but without Hermes namespace)
- XPC primary path (Hermes XPC framing — re-named to LocalAgent XPC)

**Pro-only (feature-gated stubs `#[cfg(feature = "pro-build")]` / `#if PRO_BUILD` — preserve geometry, don't develop):**
- Phase K (full power mode) · Phase H · D+ Power Mode · G+ CLI compiler
- Bash / MultiEdit / WebFetch (vigorous-goldberg branch: action_bash, browser_*, apple_*, system_*)
- omega-mcp Pro-tier capability gating
- Long-horizon orchestration

**Research-tier (Lane 3 — `epistemos-research/` crate; NEVER ships in MAS; preserved as canon):**
- 5 V6.1 Metal kernels (PageGather / SemiseparableBlockScan / LocalRecallIsland / ControllerKernelPack / PacketRouter1bit)
- F-70B-Cocktail composition study
- L_SE Self-Evolving Adapter Lane (T26)
- Per-IR Lean proofs (W-45)
- ACS substrate (`epistemos-research/src/acs.rs` 190 LOC — already preserved)
- Foundational Seven theorems
- HELIOS V6.1/V6.2 substrate doctrine

**Vault (preserved-speculation only):**
- All hypothesis docs that don't (yet) pass falsifier gates
- Hermes namespace work in `simulation` worktree (deleted from active code; doc trail preserved)

---

## 7. T-track register — every track audited

| T-# | Status | Track |
|-----|--------|-------|
| T0 (Foundation) | ✅ | Cognitive substrate floor |
| T1 | ✅ MERGED + docs salvaged | Tri-Fusion (RustTriFusionDocumentClient + tests preserved in branch) |
| T2 | 🟡 ~75% | Local Agent (per-model grammars partial; AgentBlueprint UI done) |
| T3 | ✅ MERGED + docs salvaged | UAS-ACS (12 falsifier tests preserved in branch) |
| T4 | 🟡 ~85% | Vault Recall (ChatCoordinator integration partial; tests preserved in branch) |
| T5 | ✅ MERGED (6 IR primitives) | EML / Tropical / Scan / Operator / Info / Geometry IR |
| T6 | 🟡 ~50% | UI/UX (Simulation Mode v1.6 partial; UIUX test preserved) |
| T7 | ✅ MERGED | EML observatory |
| T8 | ✅ DOCTRINE MERGED | Biometric lock (gated on T1+T2+T6) |
| T9 | ✅ MERGED + audits | Coordinator drift catches |
| T09 (May-18) | ✅ MERGED | Product Architecture Ledger |
| T10 | ✅ MERGED | Eidos V0 (Rust shipped; Swift bridge = Terminal A) |
| T10B | 🔴 | Eidos Form Layer (EidosKind 13 kinds + BLAKE3) — small follow-up |
| T11 | ✅ MERGED | System G Rust + Swift seam (StubSystemGRunSeam → Real = **Terminal C**) |
| T12 | ✅ MERGED (collapsed) | F-ULP-Oracle |
| T13 | ⏳ GATED | F-KV-Direct-Gate harness on rig |
| T14 | 🔴 → **Terminal G** | **Five-plane UAS wiring — THE BRIDGE PIECE** |
| T15 | 🔴 | Executor Trait + MissionPacket + ExecutorEvent + mock |
| T16 | 🔴 | Live File Compiler (10-state machine + LivePlan.v1) |
| T17 | 🔴 | Cognitive Weight Class Enforcement (4 weight bands + 5 promotion gates) |
| T17B | ✅ MERGED | Lattice WBO Register |
| T18 | 🔴 | Residency Governor (full Settings diagnostics + L4-L6 emission rules) |
| T18B | ✅ MERGED | ACS Admission Field |
| T19 | 🔴 | Halo V1 + Eidos Control Vectors |
| T20 | 🔴 | Variant Ladder (deterministic→cloud escalation with logging) |
| T21 | ✅ MERGED | Vault Recall Contract |
| T22 | 🔴 → **Terminal D** | Substrate Health Panel (full) |
| T22B | 🔴 → **Terminal A** | Brain Panel Closed Citations (gates on W-46 Eidos FFI) |
| T23 | 🔴 → **Terminal F** | F-70B Local Cocktail research harness |
| T23B | ✅ MERGED | M2 Pro Falsifier Handbook |
| T24 | 🔴 (research) | Lean ClaimLedger Schema Authority |
| T25 | 🟡 ~80% → **side task** | ACS Naming Reconciliation (lint) |
| T26 | 🔴 RESEARCH-DEFERRED | L_SE Self-Evolving Adapter Lane |
| T27 | 🔴 = **the umbrella of all 6 terminals** | WRV Product Surfacing |

---

## 8. The 7-terminal Phase 2 deck — UPDATED

Terminals A-F from [docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md](docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md) (PR #63) PLUS new **Terminal G** for T14 five-plane wiring + no-orphan-data invariant.

### NEW Terminal G — T14 Five-Plane UAS Wiring + No-Orphan-Data Invariant + F-UAS-CopyCount + F-ACS-AnchorLookup

**Goal:** Land the bridge piece. Make the "one substrate, many projections" doctrine REAL by adding plane placement + UAS address + residency tier + WBO + WRV to every data class. Plus two new substrate-floor falsifiers.

**Substrate already in main:**
- `epistemos-research/src/five_planes.rs` (308 LOC — RuntimePlane enum)
- `epistemos-research/src/acs.rs` (190 LOC — AcsAnchor + CmsXField + ACS_CANONICAL_PLANE)
- `agent_core/src/uas/` (UasAddress + UasKind)
- `agent_core/src/lattice_wbo/` (305 tests)
- `agent_core/src/cognitive_dag/node.rs` (10 NodeKind + 10 EdgeKind)
- `agent_core/src/scope_rex/` (MutationEnvelope + WitnessedState + ClaimGraph)

**To wire:**
1. Add `uas: Option<UasAddress>` + `plane: RuntimePlane` + `residency: ResidencyTier` to every NodeKind variant in `cognitive_dag/node.rs`
2. Promote `epistemos-research::five_planes` types into `agent_core` (or re-export); MAS build doesn't need the research module, but the enum + tier markers must be addressable from prod code
3. Add `lattice_budget: Option<LatticeBudget>` field where applicable (compressed/approximate representations only — Lattice-Error Law §1.4)
4. New harness in `agent_core/src/bin/uas_copy_count.rs` — counts tensor copies between Swift / Rust / Metal / MLX / KV / HNSW on the hot path; PASS = 0 copies → **F-UAS-CopyCount**
5. New harness in `agent_core/src/bin/acs_anchor_lookup.rs` — measures `anchor_registry.rs` lookup latency over 10k claims; PASS = < 1 μs avg → **F-ACS-AnchorLookup**
6. New `Epistemos/Views/Settings/PlanePlacementHealthRow.swift` — surfaces per-class plane placement count + per-plane node count (Visible per Witness Law §1.7)
7. CI lint: every new `struct` / `enum` / `class` declaration in code MUST have `// UAS: <address-pattern>` + `// Plane: <RuntimePlane>` + `// Residency: <ResidencyTier>` comments OR explicit `// UAS-EXEMPT: <reason>` waiver
8. Audit doc `docs/audits/T14_FIVE_PLANE_NO_ORPHAN_<date>.md`

**Acceptance:**
- Every NodeKind variant has UAS address + plane + residency
- F-UAS-CopyCount PASS on M2 Pro (≥ 1 measured run with 0 copies)
- F-ACS-AnchorLookup PASS on M2 Pro (< 1 μs avg over 10k)
- `PlanePlacementHealthRow` renders in Substrate Health panel
- CI lint catches any new orphaned data class

---

## 9. Outcome bar — when the app becomes legendary

**Floor (after 7 terminals + side tasks close):**
- W-rows: 6/53 → ~30/53 wired (~57%)
- Falsifiers PASS on M2 Pro: 0 → 7+
- Substrate-total: ~70% → ~90%
- T-tracks: 13 done / 18 partial-or-pending → 18+ done / ≤ 5 partial
- HealthRow chip strips: orange/red → green where production-wired (0 cosmetic green-Xes)
- No-Orphan-Data invariant enforced via CI lint
- All 7 Laws cited in every PR description

**Ceiling (after additional cycles — Pro + Research tiers):**
- Pro-only features unlocked behind feature flag (Phase K, H, D+, G+ all live)
- 5 V6.1 Metal kernels measured on M2 Max scale-validation rig
- F-70B-Cocktail composition study published
- Per-IR Lean proofs landed (28 → 0 sorries)
- XPC Mastery 5-service decomposition (gated on paid team per V2.4)
- Simulation Mode v1.7+ with custom-drawn body grammars + LoRA adapter swap

**Legendary = both floor + ceiling closed. Floor alone = "brilliant architecture, app works." Floor + ceiling = "the brilliant architecture has fully manifested in the working app."**

---

## 10. Cross-references

- [docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md](docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md) — canon anchor
- [docs/CANONICAL_CHRONICLE_2026_05_23.md](docs/CANONICAL_CHRONICLE_2026_05_23.md) — chronicle (7 Laws §1.2; T-track register §2; 53 W-rows §3)
- [docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md](docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md) — W-row source
- [docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md](docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md) — Terminals A-F (PR #63)
- [docs/WHATS_LEFT_2026_05_23.md](docs/WHATS_LEFT_2026_05_23.md) — P-ladder source
- [docs/SANITIZATION_LOOP_TRACKER_2026_05_23.md](docs/SANITIZATION_LOOP_TRACKER_2026_05_23.md) — Stash + branch triage record
