---
state: candidate
candidate_promoted_on: 2026-05-05
codex_continuation_update: 2026-05-05 Tier-1 doctrine lifts landed; runtime phases remain candidate
audit_item: B1 (CANON_GAPS_AND_ADDENDA bonus block)
source_doc: /Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md (689 lines, dated 2026-04-29)
---

# B1 — Biometric / Tamagotchi / Brain-Export — lift targets

> **State: candidate for runtime implementation.** Read-then-absorb pass per CANON_GAPS_AND_ADDENDA
> bonus block B1. The source addendum is 689 lines covering Waves 9–11
> of the Quick Capture standalone canon. This brief maps each thread
> to current main, classifies what's net-new vs already-covered, and
> recommends specific lift targets. Codex continuation landed the
> Tier-1 doctrine lifts into `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`;
> Phase 21-25 runtime work remains queued behind deliberation briefs.

## Source-doc summary (one paragraph per thread)

The B1 addendum splits Waves 9–11 into three productization layers:

- **Wave 9 — Biometric substrate.** Hardware-rooted Touch ID / Face ID
  / Apple Watch unlock via `LocalAuthentication`, minting Ed25519-signed
  *Session Authority Tokens* with bounded TTL + scope + binding.
  Tokens cover routine reversible actions; 8 named categories require
  fresh biometric every time (system-prompt edits, irreversible tool
  calls, agent reset, brain artifact load, etc.). Plus a *confidence
  meter* (composite of token entropy / schema-validation / self-consistency
  / tool-success-rate / citation-coverage / variant-ladder fall-through);
  sustained <70% triggers a `Suspended-LowConfidence` state; user
  consents via fingerprint to a *targeted* re-learn (diagnose-first
  per failure cause: SchemaDrift / ContextStale / ToolUnavailable /
  ConceptCollision / CitationGap / ModelDrift / Unknown), bounded at 3
  re-learns/agent/day.

- **Wave 10 — Tamagotchi agent surface.** Pixel-art animated agents
  (per-agent identity: name, purpose, vault list, capability manifest,
  avatar) with a UI mode toggle: **Pixel mode** (founder/creator/casual)
  vs **Tactical mode** (enterprise/compliance/medical/defense — same
  agents, info-dense status pills, no animations). Plus accessory
  system (LoRAs as "equipment" — helmet/glasses/book/armor metaphor),
  A2A "phone" channel for sub-agent coordination, computer-use
  supervisor mode (one agent watching another), and a Cloud-as-Teacher
  distillation lab (Professor cloud + Student local + PII sluice +
  catastrophic-forgetting eval).

- **Wave 11 — Brain Export.** Compiled, signed, license-keyed
  artifact bundles (`brain-artifact-<sha>.epistemos/`) — license-permissive
  base model (Llama/Qwen/Mistral), domain LoRA + style LoRA, obfuscated
  Rust scaffold dylib, tool grammar schemas, signed test reports,
  source provenance, Ed25519 signature. Hardware-fingerprint license
  binding. Customer's enterprise C2 stays inside Epistemos. EULA/MSA
  gated on legal review.

## Map: each thread vs current main

| Thread | Already in main? | Where | Gap |
|---|---|---|---|
| Sovereign Gate (biometric category-class doctrine §4.2) | ✅ partial | `Epistemos/Security/CapabilityBridge.swift` (`SovereignGate`, `SovereignGateRequirement`, `SovereignGateOutcome`); `KnowledgeFusionAdapterDeletionSovereignGate` is a real consumer | Session Authority Token + scope/binding model + 8 enumerated "always-fresh" categories NOT yet in main |
| Confidence meter | ❌ NOT in main | — | New feature surface; no `ConfidenceMeter`, no `composite_confidence`, no `Suspended-LowConfidence` state |
| 70%-biometric-triggered re-learn | ❌ NOT in main | — | New feature surface; diagnose-first targeted-refresh logic absent |
| Tamagotchi UI (Pixel mode) | ❌ NOT in main | (lives in `simulation` worktree per memory; not main) | New UX layer; substrate doesn't change |
| Tactical UI mode | ❌ NOT in main | — | UX toggle; pairs with Pixel mode |
| Per-agent identity model | ✅ partial | `agent_core/src/vault_registry.rs` supports multi-vault; agent identity scaffolding exists in `agent_runtime/` | Capability manifest per agent + visual avatar fields not yet present |
| Accessory system (LoRA equipment) | ✅ partial substrate | `Epistemos/KnowledgeFusion/` has LoRA pipelines + adapter management | UX wrapper (helmet/glasses/book/armor metaphor) is new |
| A2A "phone" channel | ❌ NOT in main | — | New sub-agent dispatch surface |
| Computer-use supervisor mode | ✅ partial | `Epistemos/Omega/Inference/DeviceAgentService.swift`, `Vision/VisualVerifyLoop.swift`, `Vision/ScreenCaptureService.swift` (Pro tier) | Supervisor-supervisee pairing UI is new |
| Cloud-as-teacher distillation lab | ✅ partial substrate | `KnowledgeFusion/CloudKnowledgeDistillationService.swift` exists; `MoLoRAInferenceService` | "Lab" UX + PII sluice + catastrophic-forgetting eval gate are new |
| Brain Export | ❌ NOT in main | — | New module; gated on legal review per addendum §5.4 |

## Anti-hype filter (already pre-applied in source-doc §0)

The addendum's own §0 ("audit pass — what's already covered, what's net-new,
what's hype") + §7 ("anti-hype critique — what NOT to do") are
load-bearing. The lift below honors them:

- ❌ Do NOT lift "DFlash speculative decoding" — unverified product name
- ❌ Do NOT lift "Kimi K2.5 Agent Swarm 100 agents" — unverified scaling
- ❌ Do NOT lift "patent the recursive loop" — legally fraught
- ❌ Do NOT lift "0% hallucination" — false; lift "0% syntactic violation under grammar-bound dispatch"
- ❌ Do NOT lift "complete privacy in cloud-as-teacher" — false; lift "PII-redacted egress with user preview"
- ✅ Lift the *Logic Entity vs Cluster Provider* strategic split (sound positioning)
- ✅ Lift the Apple Private Cloud Compute precedent for confidential-compute *partial* claim (honest version)

## Recommended lift targets (priority-ordered, held for sign-off)

### Tier 1 — Lift to doctrine (landed by Codex continuation; no runtime code)

These doctrine-shaping additions were landed by Codex continuation
without runtime code. They codify already-present capabilities or set
guardrails for future work.

| Target | Where | Why |
|---|---|---|
| **Session Authority Token contract** | doctrine §4.2 (Sovereign Gate) addendum | The 8 always-fresh categories + the Authority/Expired/OutOfScope/WrongBinding/FreshBiometricRequired verdict enum is exactly what the existing `CapabilityBridge` plumbing needs to converge against. Lifting the contract gives implementation a target without needing to land code yet. |
| **Confidence meter doctrine** | new doctrine Annex (A.17 candidate) | The 6 composite-confidence signals + the 70% threshold + diagnose-first re-learn + bounded-budget-per-day rules form a coherent doctrine even before code lands. Lifting now means a future implementation slice has the canonical contract to verify against. |
| **UI mode toggle** | doctrine §4.0 (UX posture, the C4 entry) addendum | "Pixel mode vs Tactical mode" doctrine pairs naturally with the C4 "one composer, two modes" doctrine; both about the same composer/UX surface differentiated by user posture. Tier-locked: Tactical mode required for Pro/enterprise distribution; Pixel mode default for Core. |
| **Accessory metaphor doctrine** | doctrine Annex A.5 (continual learning) addendum | LoRAs-as-equipment is a UX wrapper over QOFT/QDoRA/QPiSSA; the doctrine annex on continual learning can name the metaphor as the canonical visual model without changing the technology. |
| **Brain Artifact contract** | doctrine §3 (Tier Matrix) addendum | The compiled-binary + signed-bundle + license-keyed-fingerprint contract is the explicit Pro/Research distribution model the doctrine §3 already implies. Lifting the artifact shape pins the contract before legal review begins. |

### Tier 2 — Build-order graph additions (queue for substantive work)

These are real new features. Each gets a row in doctrine §7
"Build-Order Dependency Graph" but no implementation lands until
explicit sign-off + a deliberation brief per the existing Operating
Rule.

| Build-order entry | Tier | Depends on |
|---|---|---|
| Phase 21 — Biometric substrate (Session Authority Tokens + 8-category enforcement) | Core | existing `CapabilityBridge` + `SovereignGate` |
| Phase 22 — Confidence meter + biometric-triggered re-learn | Core | Phase 21 + `ToolMeta.confidence` field |
| Phase 23 — Tamagotchi + Tactical agent surface | Pro (Tactical) / Core (Pixel) | Phase 21 + per-agent identity model |
| Phase 24 — Cloud-as-teacher distillation lab | Pro | existing `KnowledgeFusion/CloudKnowledgeDistillationService.swift` + PII sluice |
| Phase 25 — Brain Export | Pro/Research | Phase 24 + LEGAL REVIEW |

### Tier 3 — Reject (do not lift)

| Rejected | Reason |
|---|---|
| Patent strategy on recursive loops | Source-doc itself says don't (§5.2) — trade-secret + copyright + compiled binary is the realistic moat |
| YC-pitch positioning verbatim | Marketing surface, not doctrine surface; out of scope for canon |
| 100-agent swarm scaling claims | Unverified |
| Specific hardware ROI claims | Unverified, workload-dependent |

## What this slice does NOT do

- Does NOT add doctrine sections — this is the brief that proposes them, not the merge.
- Does NOT add code — the build-order entries are queued, not implemented.
- Does NOT modify existing `CapabilityBridge` / `SovereignGate` plumbing — those are the Phase 21 anchor, not the Phase 21 deliverable.
- Does NOT touch `KnowledgeFusion/CloudKnowledgeDistillationService.swift` — that's the Phase 24 anchor.

## Sign-off questions for the next deliberation

1. Should Tier-1 lifts land as a single doctrine PR or as 5 separate slices (one per addendum)?
2. The 8 "always-fresh-biometric" categories — accept verbatim from B1 §1.3 or curate?
3. The "Tactical mode required for Pro distribution" stance — is that the canonical default, or per-customer?
4. Brain Export legal review — is there a recommended legal partner, or is that out of scope for this canon work?
5. Should the build-order Phase 21–25 queue go to Codex's deliberation queue immediately or after the next CD-004 V2.1 8.H authority flip?

## Cross-refs

- Source: `/Users/jojo/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`
- CANON_GAPS_AND_ADDENDA bonus B1 entry
- Doctrine §4.2 (Sovereign Gate)
- Doctrine §4.0 (UX posture — C4 entry, merged 2026-05-05)
- Doctrine Annex A.5 (continual learning)
- Doctrine §3 (Tier Matrix)
- Existing biometric scaffolding: `Epistemos/Security/CapabilityBridge.swift`, `KnowledgeFusionAdapterDeletionSovereignGate.swift`
- Existing Pro substrate touched: `Epistemos/Omega/Inference/DeviceAgentService.swift`, `Epistemos/KnowledgeFusion/CloudKnowledgeDistillationService.swift`
- B2 + B3 absorb passes remain as future-session work (LIVE_FILES_AND_SUBSTRATE 67KB, OBSCURA_BROWSER 62KB)

## Bottom line

B1 is a 689-line productization addendum spanning three substantial
waves. ~50% of the substrate it requires is already partially present
in main; ~50% is genuinely new feature surface. The Tier-1 lifts (5
doctrine additions) are now landed — they codify the contracts before
code lands, so any future implementation has a canonical target. The
Tier-2 build-order entries (Phases 21–25) queue
for explicit sign-off + deliberation briefs per the existing Operating
Rule. Tier-3 items (patent strategy, YC pitch, hardware claims) stay
out of canon.

Runtime implementation remains held for sign-off; Tier-1 doctrine is landed.
