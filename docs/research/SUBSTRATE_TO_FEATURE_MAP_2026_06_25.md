# Substrate → Feature Map: what to keep / re-add / reconceptualize for Chat · Act · Work

**Date:** 2026-06-25 · **Companion to:** `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md`
**Question:** from the deep substrate (System G, Night Brain/LoRA, UAS/SSM/Neural-Cache, autogenous kernel, the 457-file corpus), what becomes a real FEATURE attached to one or a combination of the three surfaces — Chat (Swift/AgentClone), Act (Goose), Work (OpenGUI/OpenCode)?

## §0 The reframe (the finding that drives everything)
Almost all of this is **already built at Tier-1** (compiled, cargo-verified, tested) and just **gated off / not wired to UI.** The job is **promote T1 → T4 (live + visible + verified)**, attached to a surface — NOT build more. Resist surfacing the deep plumbing as features; it makes the features below *better/provable*, it is not itself user-legible.

## §1 THE ANSWER — attach exactly FOUR features (everything else stays plumbing)

### Attach to ALL THREE surfaces (shared shell — the cross-cutting wins)
1. **Honesty / provenance spine** — *reconceptualize System G's `AnswerPacket` + `RunEventLog` + `SovereignGate`.* Every answer from Chat, Act (Goose), and Work (OpenGUI) emits one inspectable **AnswerPacket** (final text + citations + budget + route + witness hash) and passes a **SovereignGate** admission classification (Trivial→Sovereign) before any tool runs. → User-facing payoff: *"every surface can prove what it did, and nothing risky runs without honest admission."* Build state: Rust T1 (built), needs the Swift event-mirror + a shared "trace/approve" rail (the federation plan already wants this).
2. **Shared vault memory / context** — *keep + surface the Neural Cache (4-layer) behind the existing `epistemos.context.snapshot` seam.* All three surfaces read your vault/graph/note context through one shared snapshot (hot facts <1ms). → *"all three see your whole vault, the same way."* Build state: Neural Cache shipped T1; Work already has the snapshot seam — extend it to Chat + Act.
3. **Autogenous skills** — *keep + surface the self-evolving kernel (`self_evolution.rs` + `procedural_memory.rs`).* It watches repeated tool sequences across **all three** surfaces and offers to turn them into reusable skills usable by **all three**. → *"Epistemos noticed you do X often — make it a one-click skill?"* Build state: **shipped V1** — this is the cheapest visible win; it just needs a surface (a proposal card).

### Attach to CHAT only (the Swift native lane you own + can train)
4. **Overnight local learning** — *reconceptualize Night Brain + the native LoRA trainer.* Night Brain harvests signal from **all three** surfaces' transcripts overnight and fine-tunes a LoRA adapter for **Chat's** local MLX model (the only lane you control end-to-end). → *"your private model quietly learned from everything you did this week — and it can show you the adapter."* Build state: trainer + adapter-apply + Night-Brain job **all built**, flag-OFF, needs one owner-validated token-gen run + a small inventory UI. **Why Chat-only:** Act=Goose and Work=OpenCode run their *own* models/runtimes you can't fine-tune; they *contribute training data*, they don't *receive the adapter*.

> These four compose into ONE story: **"a private, trustworthy workspace that sees your whole vault, automates what you repeat, improves itself overnight, and can prove everything it did — across chat, autonomous action, and coding."** All four are built (T1), on-16GB-feasible, and genuinely differentiated.

## §1b The NON-MODEL substrate — your most-shipped, most-defensible layer (retrieval · knowledge · provenance)

The deeper finding (Eidos + lattice + Living-Index sweep): your **non-model substrate is MORE shipped than the model side**, and it's what actually makes three surfaces feel like *one intelligent app*. Most of it is T4/T1-wired and needs only last-mile UI. **This is the crown jewel — lead with it, not the model fine-tuning.**

| Subsystem | What it is | Build state | Feature → surface |
|---|---|---|---|
| **Eidos V0** | 9-mode deterministic retrieval with a CLOSED-CITATION contract — the AI can only cite what it actually retrieved | **Shipped T1 substrate** (472 Rust tests, Swift mirror, vault FFI, EidosHealthRow live); wiring W-47/W-48 pending-but-ready | **"every citation is real"** → all three (validate any surface's sources) |
| **Halo/Shadow + RRF fusion** | live incremental BM25+HNSW+RRF(k=60), re-indexes on every vault edit | **Shipped T4** | **ambient recall — relevant notes surface as you work** → all three |
| **Cognitive DAG + resonance** | typed content-addressed knowledge graph (10 node/10 edge kinds, Merkle, Kleene-K3 truth that cascades through DerivesFrom/Contradicts) | **Shipped T4 core**; live-driven resonance = Phase 8.H pending | **living knowledge graph — claims/evidence/contradictions with truth that propagates** → Work/Graph + shared |
| **Provenance Ledger (ClaimLedger + ReplayBundle)** | every claim → evidence → status; retraction propagates to dependents; replay-auditable | **Shipped T1** | part of the honesty spine (§1.1) → all three |
| **Meaning Anchors** | chat-as-intelligence: unified SDChat/SDMessage, recency weighting, proactive surfacing | **Shipped T4** | **"based on what you've been doing, here's what matters"** → Chat |
| **Vault Memory System** | per-model 6-phase session memory (history, KV, reasoning, tool context, rollback) | **Shipped T4** | persistent sessions/recents → all three |
| **Lattice WBO (Wyner-Ziv)** | 7-tier × 7-term error-budget LEDGER proving every compression/approximation's cost | **Shipped T1 (metadata)** | PLUMBING — the "compression never silently loses truth" accountant; surface only as a diagnostic |

**Correction to §1:** the non-model retrieval/provenance/graph features are *closer to shippable AND more central to the PKM value prop* than model fine-tuning. "Overnight learning" is the flashiest, but **closed-citation retrieval (Eidos) + ambient recall (Halo/RRF) + living knowledge graph (DAG) + proven provenance (ClaimLedger)** are the foundation that makes Epistemos a *trustworthy knowledge OS* — and they're mostly built. Revised lead order in §5.

**Accuracy note (agents disagreed, reconciled):** Eidos V0 — the 9-mode closed-citation *retrieval engine* — is SHIPPED substrate. The TurboVec/AppColdStore *compression layer* over it is research-only (21 falsifier gates pass on metadata, no code). Do not conflate them.

**On "the lattice" (three distinct things):** (1) **LatticeWBO** = the shipped Wyner-Ziv write-budget error ledger (plumbing/diagnostics). (2) a **707KB HTML lattice-coordinate explainer** artifact (not wired into the app). (3) the aspirational **FCA concept-lattice UI** (navigable concept partial-orders) — no code, correctly your "absolutely last, indefinite" item. Robust *research* = `EPISTEMOS_LIVING_INDEX_2026_05_24.md` + `LATTICE_WYNER_ZIV_WBO_REGISTER_2026_05_18.md`; the buildable near-term piece is the Cognitive DAG (already T4), not a new FCA engine.

## §2 Keep as PLUMBING (do NOT surface as a feature yet — promote later, one slice at a time)
- **System G runtime / RuntimeRouter** — the engine under the provenance spine + Chat's lane selection. Surface the *output* (AnswerPacket), not the router.
- **SSM / Mamba-2** (`ssm_state.rs`, Phase 1A) + **UAS / AppColdStore / cold-assembly** + the **5 HELIOS Metal kernels** (PageGather etc., W-41, dense-restore still failing) — these are the *reasoning backbone + memory transport* under Chat's local model. Invisible. Promote individually behind falsifiers.
- **Lean proof plane** (skeleton, 35 sorries) — the verification layer that *backs* the honesty spine. Not a surface feature; deepen in place (no new repo).

## §3 Keep GATED (research moat — revisit much later, not now)
Exotic kernels (BitNet b1.58, sparse-ternary GEMM, ternary GEMV), the 40 research-tier modules (Koopman, Belnap 4-valued logic, Tropical algebra, RWKV-7, Mamba-3, Sherry E8 quantizer, SAE), ACS recursive governance (never-ships-MAS), XPC 5-service mastery (paid-team gated), 70B cocktail (hardware-impossible on 16GB — already correctly forbidden). All properly gated; leave them.

## §4 Reconceptualizations (old framing → shippable feature framing)
| Was framed as | Reconceptualize as | Surface |
|---|---|---|
| "System G 70B dual-brain runtime" | **the honesty spine** — every answer is an inspectable, admission-gated AnswerPacket | all three |
| "Night Brain background jobs" | **"your private model learns overnight from everything you did"** | Chat (trained by all three) |
| "Autogenous / self-evolution kernel" | **"automate what you repeat"** — skill proposals from your own patterns | all three |
| "Adapter gift-box / Mailroom" | **the adapter/skill inventory** — where overnight-learned + downloaded adapters/skills live | shell/Settings → applies to Chat model |
| "UAS / Neural Cache / cold assembly" | **shared vault memory** (surface the cache) + invisible transport (keep the rest) | all three (cache); plumbing (transport) |

## §5 Promotion priority (REVISED — lead with the mostly-shipped non-model substrate)
1. **Autogenous skills proposal card** — shipped V1, just needs a surface. Fastest visible win.
2. **Eidos closed-citation gate (W-47) + "Retrieved by Eidos" brain-panel (W-48)** — shipped substrate, last-mile wiring. The trust differentiator: the AI can only cite what it actually retrieved. All three.
3. **Ambient recall surfacing (Halo/Shadow + RRF)** — already T4; surface "relevant notes as you work" consistently across all three.
4. **Shared context snapshot → Chat + Act** — reuse Work's seam. Makes all three feel like one app.
5. **Living knowledge graph (Cognitive DAG)** — already T4 core; surface claims/evidence/contradictions; wire live resonance (Phase 8.H) for truth-propagation.
6. **Overnight local learning (Chat)** — prove one token-gen run, flip `EPISTEMOS_NIGHTBRAIN_LORA_V0`, inventory UI. The signature *model-side* differentiator — after the non-model foundation is visible.
7. **Provenance spine (AnswerPacket + ClaimLedger) across all three** — the trust capstone.
Everything in §2 promotes *under* these, one falsifier at a time. §3 stays gated.

## §6 Build-state truth table (the "wired vs gated" sheet)
| Subsystem | Build state | Surface fit | Action |
|---|---|---|---|
| AnswerPacket + RunEventLog + SovereignGate | Rust T1 (built), not Swift-wired | all three | Re-add → promote (provenance spine) |
| Neural Cache (4-layer) + context snapshot | T1 shipped; Work-wired | all three | Keep → extend to Chat+Act |
| Autogenous kernel (self-evolution + procedural memory) | **Shipped V1** | all three | Keep → surface (proposal card) |
| Night Brain + native LoRA trainer + adapter-apply | Built, flag-OFF, unproven | Chat | Re-add → prove + surface |
| System G runtime / RuntimeRouter | Rust T1, not wired | Chat (lane) | Keep as plumbing |
| SSM / Mamba-2 (save/resume) | Phase 1A shipped | Chat engine | Keep as plumbing |
| UAS / AppColdStore / KV-Direct | T1 shipped | Chat engine | Keep as plumbing |
| HELIOS Metal kernels (PageGather etc.) | CPU shipped; Metal W-41 failing dense | Chat engine | Keep gated; promote per falsifier |
| Lean proof skeleton | 35 sorries | (verification) | Keep in-repo; deepen slowly |
| Exotic kernels + 40 research modules + ACS + XPC + 70B | Gated / research / never-MAS | — | Leave gated |

## §7 Final thought
The shape: a small set of **cross-cutting non-model features** — closed-citation retrieval (Eidos), ambient recall (Halo/RRF), a living knowledge graph (Cognitive DAG), and a provenance spine (AnswerPacket + ClaimLedger) — that make all three surfaces one *trustworthy knowledge OS*; **plus** the model-side flourishes (overnight learning, honest routing) on Chat; **plus** autogenous skills across all three. The non-model layer is your crown jewel and it is **mostly already shipped** — the win is last-mile wiring, not new engines. Everything deeper (System G runtime, SSM, UAS, Metal kernels, Lean, the exotic research) stays the **moat underneath**.

The defensibility nobody with TS/Python wrappers can touch: *private, on-device, self-improving, and **provable*** — and "provable" (closed-citation + claim ledger + answer packet) is the part you've built most fully. So the real order is: **ship the non-model foundation first** (it's closest to done and most central), then the model flourishes, then promote the deep moat one falsifier at a time. You don't need to build more — you need to *surface what's already there.*
