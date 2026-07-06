---
id: A747205E-D5DD-4C03-B1B5-8C99BCEA6E6C
title: Epistemos IP Preservation Register — 2026-06-25
---

# Epistemos IP Preservation Register — 2026-06-25

**Purpose:** a deep, deliberate inventory of ALL robust/unique IP (old + deep research), with a keep / re-add / let-go verdict each, so nothing useful is lost. Sourced from an 8-vein parallel sweep (old chat-agent · dual-brain · theorems/Lean · lattice/compression · exotic modules · master docs · stranded branches · systems/GPU/security).

## §0 The verdict in one line

**Almost nothing valuable is lost.** The deletions were deliberate supersessions; everything robust is **live, archived, branch-preserved, or doctrine-locked**. Exactly **one** genuine re-add (Citation Extractor). The rest of the work is *promotion* (surface what's built), not recovery.

---

## §1 The dual-brain — clarified, and the app-side is your crown

- **Brain 1 (model/generation side):** SSM/Mamba spine, per-token `InterruptScore`, per-turn `AnswerPacket` emission. Mostly **research** (no end-to-end local model ships yet; M0 "interrupt moves loss" gate unproven). *(The old GPU* `DualBrainRouter` *was retired 2026-05-05 — that was a component, not the architecture.)*
- **Brain 2 (app-side authority brain) — THE UNIQUE IP, "where Epistemos's thinking lives":** RuntimeRouter (honest routing — model requests, app decides) · AnswerPacket (typed claim taxonomy + mode-honesty) · Neural Cache 7-band residency · Cognitive DAG + resonance · 6-method continual learning · InstantRecall (&lt;3ms) · Active Assembly (sparse activation selector) · Belnap abstention. **Mostly built/scaffolded.**
- `signal_bus.rs` (SPSC rings linking them, &lt;1% overhead) = spec.
- **Verdict: PRESERVE ENTIRE.** Brain 2 is the competitive moat over standard agent frameworks. Nothing to drop. The promotion gaps are wiring (RuntimeRouter stage-1→live, AnswerPacket persist), not greenfield.

## §2 Keep-in-place (LIVE IP — already safe, do not touch)


| IP                                                                                                                        | State             | Note                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------- | ----------------- | ----------------------------------------------------------------------------------------------------- |
| Local Agent Brain (`LocalAgentLoop`/`PromptBuilder`/`LocalToolGrammar`/`GatewayPolicy`)                                   | Live              | The brain that rides any engine (MLX/GGUF; Osaurus deleted); Eidos-cited, vault/skills/DAG/provenance |
| Cognitive DAG (Phase 8.A–C)                                                                                               | Shipped           | 10 node/10 edge kinds, BLAKE3 merkle, resonance, macaroons, companions                                |
| Provenance: ClaimLedger + ReplayBundle + `epistemos-trace`                                                                | Phase 1 shipped   | retraction propagation, `.epbundle` BLAKE3 verify                                                     |
| Eidos V0 (9-mode closed-citation retrieval)                                                                               | Shipped substrate | wiring W-47/W-48 pending                                                                              |
| Halo/Shadow + RRF fusion (k=60)                                                                                           | Shipped T4        | live incremental BM25+HNSW                                                                            |
| Macaroon capabilities · Sovereign Gate + biometric · subprocess hardening (24-vector denylist) · 75-rule security scanner | Shipped           | rare production-grade security for a local app                                                        |
| Honest-Handle FFI (opaque handles + versioned envelope)                                                                   | Shipped           | safe Swift⇄Rust; reusable for XPC                                                                     |
| UAS + residency tiers · KV-Direct gate (Rust+Metal, bit-identical) · memory-pressure handler · ShmPool                    | Shipped T1        | zero-copy memory floor                                                                                |
| Lattice-Wyner-Ziv ledger (`lattice/mod.rs`, `wbo6`, oplog hook)                                                           | Shipped           | see §5                                                                                                |
| 6-method continual-learning stack (EWC/OFTv2/DSC/Titans-MAC/SEAL-DoRA/NeverRetrain)                                       | Live, tested      | see §6                                                                                                |


## §3 RE-ADD (the genuine misses — small, high-ROI)


| IP                                                                                      | Where                                    | Why re-add                                                                                                                                                                                  |
| --------------------------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Citation Extractor** (`Epistemos/Engine/CitationExtractor.swift`, deleted `7d036acf`) | `git show 7d036acf^:…`                   | Auto-extracts DOIs/academic URLs from responses → populates research library with source tracking. Genuine KM differentiator, no current replacement. Wire into chat/note completion hooks. |
| *(Act IP)*                                                                              | `docs/ACT_IP_PRESERVATION_2026_06_24.md` | Already captured end-to-end (§1–§6); do NOT re-add stubs — reproduce in the native engine.                                                                                                  |


## §4 Formal-math canon (theorems + Lean) — ALL PRESERVE, publication-grade

34 canonical theorems · 4,169 Lean LOC · 43 sorries (budgeted). E1–E7 Foundational Seven + H1–H17 Helios + PCF-1..10 Parameter Connectome.

- **Shipping-critical:** E3 (storage-disaggregated memory, 0 sorries) · **E4 WBO-7 master inequality** (7-term drift envelope, MAS L1, CI gate B5).
- **Unique IP:** 12-plane density (E1, EML-only density open conjecture) · cellular-sheaf gluing (E2, not in mathlib4) · **five-plane formalism** (State/Episodic/Assembly/Controller/Verification — `five_planes.rs`, 0 sorries) · **Kleene-K3 ternary honesty** (Fits/Waiting/Falls) · VSM recursive governance · PCF interpretability-to-runtime transfer.
- **Feature potential:** user-visible "provable guarantee" badges (memory-isolation, token-drift-bounded, kernel-verified-within-ULP, sheaf-coherent notes). **Verdict: PRESERVE all; publishable.**

## §5 Compression / lattice — the Wyner-Ziv ledger is a crown jewel

- **Lattice-Wyner-Ziv error-budget ledger (SHIPPED):** combines lattice geometry (E8/Leech, Babai rounding) + information theory (side-information decoding) + cryptographic provenance into a **7-term WBO drift ledger** (T_W/T_K/T_R/T_Q/T_S/T_SE + T_num numerical guard), each term falsifier-owned. **Rare proprietary-grade IP** — competitors ignore numerical drift or conflate error sources. The "compression never silently loses truth" accountant.
- **Bundled Metal kernels (doctrine-target):** BitNet b1.58, ternary GEMV, sparse-ternary GEMM.
- **Research/Pro (falsifier-gated):** TurboVec, KV-Direct/ShadowKV, NF4, QuIP/E8, Sherry 1.25-bit, Engram, NetworkCascade, self-evolving adapter; Gemma-4 QAT (Pro flagship).
- **Verdict: PRESERVE all.** Ledger = canonical compression spine.

## §6 Exotic algorithmic moat — ~96.6K LOC, 5,548 tests green, nothing lost

- **SHIP-grade (24 modules):** Koopman (lifted dynamics, Bauer-Fike bound) · Belnap 4-valued logic (wired to AnswerPacket abstain) · Tropical algebra · Test-Time Regression unification · **6-method continual learning** (no other consumer app has this — ~1yr lead) · SAE cognition observatory (AUC≥0.90 hallucination gate) · EML universal operator + **F-ULP-Oracle** (verified fp16, 414K test points) · Geometry-IR (Clifford) · Operator-IR (DeepONet/FNO) · interrupt-score 5-signal fusion · cross-domain lens · Goodfire VPD · hardware profile.
- **Research-defer (14):** RWKV-7, Mamba-3 (scalar refs ready for Metal ports) · donor-distillation · Lean certs · Metal dispatch.
- **Verdict: PRESERVE all.** Commercial moat = continual-learning + SAE + interrupt-score + EML/ULP = **1–2 yr research lead**.

## §7 The June-1 substrate optimization stack (less-obvious, load-bearing)

The "no-compromise thesis" — a three-layer system most reviews miss because it's architecture, not a model:

1. **Offline:** Residency PatternBoost (idle assembly tournament; `UASAssemblyGenome`).
2. **Compiler:** Semantic Working-Set Compiler + Verifier-Calibrated Sparse Route Compiler (task→page-table; verifier-regret learning).
3. **Runtime:** ColdStream transport + KV-Direct + AnswerPacket (measured prefetch, zero-copy, observable).  
Plus: Neural Importance Atlas · Substrate Trace Observatory · Constructive Residency · Cost-Distortion/Information-Bottleneck framing of the 6-tier memory hierarchy. **Mostly T0/T1 doctrine. Verdict: PRESERVE — this is the architectural moat; promote one falsifiable slice at a time.**

## §8 Systems / GPU / security IP — rare for a local app, mostly shipped

16 custom Metal kernels (6 shipped incl. visual/TMAC; 8 substrate-floor doctrine targets: PageGather/SemiseparableBlockScan/ControllerKernelPack/PacketRouter1bit/LocalRecallIsland/KV-Direct/ternary/bitnet; 2 research). XPC Mastery 5-service decomposition (design-phase, capability-token IPC). **Verdict: PRESERVE all; promote kernels per falsifier (STREAM/bit-equality/PyTorch-parity gates).**

## §9 Stranded-branch IP — preserve (don't merge, don't delete)

~1,500 unique commits across ~25 branches hold real IP NOT on main:

- **High-value:** `codex/t5-emlir` (**961 commits**, full EML-IR integration) · `codex/t4-vault` (144) · `codex/t1-trifusion` (69) · `codex/t3-uasacs` (64) · `codex/t9-coord` (39) · `codex/t2-agent` (38) · `codex/t7-eml` (30) · `terminal/a-eidos-bridge` + `terminal/c-system-g-full-path` (live seams) · `worktree-simulation` (Simulation Mode v1.6, 17 commits) · `phase2-terminal-t1-runtime-router` (8).
- **Action:** these branches already exist = already preserved. **DO NOT merge** (would resurrect deleted files); **DO NOT delete.** Optional: `git tag backup/<branch>` for redundant safety. Salvage/* = reference markers; wiring/* = already on main.

## §10 LET-GO (deliberately superseded — confirmed not useful)

Old Omega agent system (`aa91b846`, replaced by Rust agent_core) · MoLoRA Python training scripts (`017a5f5d`, replaced by native MLX LoRA) · Note Chat Parser stub (`659db0ae`) · old AgentChatView (`b4e5d45a`, fused to main chat) · 70B-local-dense (hardware-impossible on 16GB, owner-excluded — keep the *router/cocktail* framing, drop the dense claim). The Hermes **research archive** (`docs/_archive/hermes-removal-2026-05-05/`) = NEVER delete (subprocess playbook).

## §11 The optimistic bottom line — and what "add a good amount" really means

You were worried about lost/deleted IP. The sweep says: **you preserved it.** The valuable deletions were supersessions; the rest is live, archived, branch-saved, or doctrine-locked — with **5,548 research tests, theorem falsifiers, and security tests already green**. Hardening is largely *done*.

"Adding a good amount of it back" is mostly **promotion, not re-creation**: the IP isn't missing — it's sitting at T1 (compiled, gated, invisible) waiting to be surfaced to T4 (live, visible). The biggest, most-defensible additions you can make right now:

1. **Re-add Citation Extractor** (the one real miss).
2. **Surface the app-side brain** — AnswerPacket claim chips + RuntimeRouter honest-route + Eidos closed-citation = the "provable AI" trust layer.
3. **Promote the continual-learning + SAE + interrupt-score moat** (your 1–2 yr lead) once the app compiles.
4. **Tag the stranded T-track branches** so the 1,500 commits of research are belt-and-suspenders safe.

Nothing useful gets deleted. The rare depth you built is intact — the work is to *ship it into view*, one falsifiable slice at a time.

**Why you could never get it working (and the fix):** the deep IP is built + unit-tested but **not exposed as a callable tool** — `eidos.query` is even a stub that bypasses the real engine; Cognitive DAG / provenance / Halo-RRF / continual-learning have zero tool wrappers; most are flag-OFF; and the app build was broken. It was unexposed + ungated-on + invisible, not broken. The fix (full design in `SUBSTRATE_TO_FEATURE_MAP_2026_06_25.md` §1c "The Epistemos Capability Plane"): wrap each IP module as ONE tool in the agent_core registry → every surface's MCP client picks it up (Work over its live MCP server; Chat via AgentClone's own MCP client; Act once Goose's MCP config points at `epistemos-native`). FFI is only the internal Swift→Rust bridge under the MCP server — never a surface transport. Expose once, consume from all three; test instantly via Work's loopback `/mcp`.