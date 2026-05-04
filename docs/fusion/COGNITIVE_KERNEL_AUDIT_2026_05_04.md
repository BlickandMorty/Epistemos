# Cognitive Kernel Audit — Fragmentation Map — 2026-05-04

> **Stage A.1 deliverable** of `CANONICAL_RECOVERY_PLAN_2026_05_03.md`.
> Per `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §11 + Appendix B.
>
> Live grep over the tree on 2026-05-04 (commit `d6048bf5` + dirty WIP). Names
> every parallel agent loop, skill registry, procedural memory store,
> prompt manager, tool dispatch in the tree, and assigns a
> `keep | collapse | reject` verdict per the kernel doctrine §1
> (one agent loop, one memory store, one provenance ledger, one
> skill registry, one privilege boundary).

---

## 0. Headline findings

1. **Two agent loops in the active tree** — Swift `LocalAgentLoop` (actor) + Rust `agent_core::agent_loop` (canonical kernel target). The Swift loop must collapse to a thin caller of the Rust loop via UniFFI per kernel doctrine §1 Rule 1.
2. **The Python `hermes-agent` submodule is NOT in the tree** as of 2026-05-04 (`ls hermes-agent` empty). Either pruned or never landed in main. **Good news:** the kernel doctrine Phase 2 (Hermes-in-Rust) doesn't have to migrate FROM a Python subprocess; it builds the Rust runtime fresh and the UI starts using it.
3. **Three Rust skill surfaces with distinct roles** — `agent_core/src/skill_router.rs` routes queries to `SKILL.md` files, `agent_core/src/storage/skills_registry.rs` persists usage/success metadata, and `agent_core/src/tools/skills.rs` is the active tool CRUD/progressive-disclosure/quarantine installer surface. These should consolidate under `agent_core::hermes::skills` as router + persistence + tool facade, not survive as parallel registries.
4. **Runtime prompt assembly is split across purpose-specific surfaces** — `Epistemos/LocalAgent/HermesPromptBuilder.swift` is the Swift Hermes mirror to collapse; `Epistemos/Engine/PromptRenderer.swift` is provider-target serialization to keep; `Epistemos/Harness/HarnessPromptBuilder.swift` is harness-only to keep isolated; `Epistemos/App/ChatCoordinator.swift` assembles runtime system prompts and already uses `PromptComposer`/`PromptRenderer` behind `EPISTEMOS_PROMPT_TREE`, so it should become an input gatherer for the kernel prompt builder rather than a second canonical builder.
5. **AgentEvent provenance** flows through ONE canonical recorder (`AgentToolProvenanceRecorder`) consumed by 10+ Engine call sites. **Doctrinally correct as-is.**
6. **Tool registries are well-centralized** — `agent_core/src/tools/registry.rs` is the canonical Rust registry; Swift consumers call FFI. **Doctrinally correct as-is.**

---

## 1. Agent loops (kernel doctrine §1 Rule 1: one loop)

| Loop                                    | Path                                                      | Verdict      | Action |
|---|---|---|---|
| Rust kernel agent loop                  | `agent_core/src/agent_loop.rs`                            | **canonical (canon)** | Keep, extend per Phase 2 (host the Hermes runtime via `agent_core::hermes`) |
| Swift `LocalAgentLoop` actor            | `Epistemos/LocalAgent/LocalAgentLoop.swift` (line 61, `actor LocalAgentLoop`) | **collapse** | Convert to a thin Swift caller of the Rust loop via UniFFI; preserve the actor wrapper for `@MainActor` UI integration but route every step through `agent_core::agent_loop` |
| `ConfidenceRouter.usesLocalAgentLoop` flag | `Epistemos/LocalAgent/ConfidenceRouter.swift` (multiple sites) | **keep — different concern** | This is a routing decision (use local vs cloud), NOT a parallel loop. After collapse, the routing decision becomes "use Rust local path" vs "use Rust cloud path"; both still go through the canonical Rust loop. |
| `LocalAgentLoopError` + `LocalAgentLoop.supportsLocalAgentLoop` | `Epistemos/LocalAgent/LocalToolGrammar.swift:50`, `LocalAgentLoop.swift:35` | **keep as Swift mirror types** | Error + capability surfaces stay Swift-side for SwiftUI binding; their actual behavior comes from the Rust loop |
| `agent_core/src/runtime/` modules        | `agent_core/src/runtime/{typestate,write_pipeline}.rs`     | **keep — different concern** | `typestate.rs` is lifecycle phantom-state scaffolding; `write_pipeline.rs` is Resource Runtime verified-write + audit-log plumbing. Neither is an agent loop. Keep as runtime substrate; do not collapse into `agent_loop.rs`. |

**Kernel doctrine §1 Rule 1 will be met when:**
- Only `agent_core/src/agent_loop.rs` contains the actual loop body
- Swift `LocalAgentLoop.swift` is ≤ 200 lines (currently larger), all of it FFI delegation + `@MainActor` glue
- Grep `class.*Loop\|actor.*Loop\|fn agent_loop\|impl.*Loop` against `Epistemos/` returns only mirror types, never loop bodies

---

## 2. Skill registries (kernel doctrine §1 Rule 4: one registry)

Three Rust surfaces with distinct responsibilities — this is the most important consolidation in the audit because the responsibilities are correct but the ownership boundary is not yet `agent_core::hermes::skills`.

| Registry                                    | Path                                              | Verdict      | Action |
|---|---|---|---|
| `agent_core::skill_router`                  | `agent_core/src/skill_router.rs`                  | **collapse into Hermes skills router** | Query-to-skill router over vault `skills/` docs using trigger match + TF-IDF cosine over name/description/triggers. Keep the algorithm as `agent_core::hermes::skills::router`; remove the standalone registry ownership. |
| `agent_core::storage::skills_registry`      | `agent_core/src/storage/skills_registry.rs`       | **keep as persistence layer, move under Hermes** | YAML-backed usage/success metadata store (`skills/skills_registry.yaml`). Keep semantics as `agent_core::hermes::skills::registry_store`; it is persistence, not a runtime dispatcher. |
| `agent_core::tools::skills`                 | `agent_core/src/tools/skills.rs`                  | **canonical seed, split under Hermes** | Active procedural-memory tool surface: legacy `skills` CRUD plus `skills_list`, `skill_view`, `skill_manage`, install/quarantine/promotion scanners. Split into `hermes::skills::{store,tools,installer}` and register through the canonical `tools::registry`. |
| Swift `RecipeGraphSkills`                   | `Epistemos/Omega/Knowledge/RecipeGraphSkills.swift` | **keep — different concern** | Recipe graph (Omega knowledge subsystem); not a runtime skill registry |
| Swift `SkillEvolutionService`               | `Epistemos/Vault/SkillEvolutionService.swift`     | **keep — different concern** | Vault-tier skill evolution (offline); after Phase 2 lands, this consumes `hermes::self_evolution` Rust output via FFI |
| Swift `SkillGenerator` (KnowledgeFusion)    | `Epistemos/KnowledgeFusion/SkillGeneration/SkillGenerator.swift` | **keep — different concern** | Knowledge Fusion training-time skill generation; pre-runtime |

**Kernel doctrine §1 Rule 4 will be met when:**
- One canonical Rust file: `agent_core/src/hermes/skills.rs` per Phase 2
- The three current Rust files either collapse INTO that file or become its callers / persistence layer / router
- Swift consumers reach skills via the new canonical FFI

**Verified 2026-05-04:** all three Rust files were read. Phase 2 should preserve their useful roles while moving ownership under `agent_core::hermes::skills`: router, persistence, tool facade, quarantine installer.

---

## 3. Prompt managers (kernel doctrine §1: one prompt manager)

| Surface                                     | Path                                              | Verdict      | Action |
|---|---|---|---|
| `HermesPromptBuilder` (Swift)               | `Epistemos/LocalAgent/HermesPromptBuilder.swift`  | **collapse**  | Becomes a thin Swift mirror that calls Rust `hermes::prompt_format::build(...)` via FFI; keeps the same public Swift API for callers, no behavior change visible |
| `PromptRenderer` (Swift)                    | `Epistemos/Engine/PromptRenderer.swift` (renders to provider-specific shapes: anthropic, openAI, AFM) | **keep — different concern** | This is the *provider-target serializer* (turns canonical prompts into Claude / OpenAI / Apple Foundation Models wire formats). Sits between the kernel's canonical prompt and the network. Stays Swift; the kernel's canonical prompt becomes its input. |
| `HarnessPromptBuilder` (Swift)              | `Epistemos/Harness/HarnessPromptBuilder.swift`    | **keep — different concern** | Test harness fixture builder; not a runtime path |
| `ToolTierBridge` tool-surface bridge        | `Epistemos/Bridge/ToolTierBridge.swift`           | **keep — bridge consumer** | Loads tier-filtered Rust tool schemas via `listToolsForTier*`, filters visible tools for MAS/Pro distribution, and forwards execution to `executeToolCall*`. It does not build prompts; its comment still mentions `HermesPromptBuilder` as a consumer and should be revised when that mirror collapses. |
| `ChatCoordinator` prompt assembly           | `Epistemos/App/ChatCoordinator.swift`             | **collapse input assembly into kernel prompt API** | Builds runtime system prompts in two Rust-agent paths and, when `EPISTEMOS_PROMPT_TREE=1`, composes typed prompts with `PromptComposer` then renders via `PromptRenderer.anthropicSystemPrefix`. Keep its context-gathering role, but Phase 2 should pass structured inputs to Rust `hermes::prompt_format` instead of treating joined Swift strings as canonical. |
| `PromptCache` / `PromptTree`                | `Epistemos/Engine/{PromptCache,PromptTree}.swift` | **keep — different concern** | Prompt caching (per-provider) + Prompt-tree N1 substrate (Lane A); orthogonal to the prompt-builder concern |

**Kernel doctrine §1 will be met when:**
- One canonical Rust file: `agent_core/src/hermes/prompt_format.rs` per Phase 2
- Swift `HermesPromptBuilder.swift` becomes a ≤ 50-line FFI mirror
- Provider-target serialization stays in `PromptRenderer.swift` (separate concern, keep)

---

## 4. Tool dispatch (kernel doctrine §1: one registry)

| Surface                                     | Path                                              | Verdict      | Action |
|---|---|---|---|
| `agent_core::tools::registry`               | `agent_core/src/tools/registry.rs`                | **canonical (canon)** | Keep. Becomes substrate for `agent_core::hermes::skills` per kernel doctrine §4.3 (a Skill is a higher-order Tool composed of multiple Tool calls). |
| `Epistemos/Bridge/StreamingDelegate`        | `Epistemos/Bridge/StreamingDelegate.swift`        | **keep — different concern** | Streaming bridge; consumes tool-call events, doesn't register tools |
| `Epistemos/App/ChatCoordinator`             | `Epistemos/App/ChatCoordinator.swift`             | **keep — different concern** | Coordinator surface; consumer |
| `Epistemos/State/AgentCommandCenterState`   | `Epistemos/State/AgentCommandCenterState.swift`   | **keep — different concern** | UI state for the agent command center; consumer |
| `Epistemos/Omega/MCPBridge`                 | `Epistemos/Omega/MCPBridge.swift`                 | **keep — different concern** | MCP-side tool surfacing; canonical for that bridge |
| `Epistemos/Omega/iMessageDriver`            | (Pro-deferred per MAS-First Focus Doctrine)       | **keep gated** | Pro-only; `#[cfg(feature = "pro-build")]` migration when each PR touches |
| `ToolSchemaGrammar`                         | `Epistemos/Omega/Inference/ToolSchemaGrammar.swift` | **keep — different concern** | Grammar-constrained generation; orthogonal to registry |
| `OverseerProtocol`                          | `Epistemos/Engine/OverseerProtocol.swift`         | **keep — different concern** | Overseer pattern protocol; consumer |

**Kernel doctrine §1 Rule 4 already met for tools** — `agent_core::tools::registry` is the single canonical surface; everything else is a consumer.

---

## 5. Procedural memory (kernel doctrine §4.4)

| Surface                                     | Path                                              | Verdict      | Action |
|---|---|---|---|
| `agent_core::tools::skills`                 | `agent_core/src/tools/skills.rs`                  | **likely seed** | Only file referencing procedural memory in tree. Codex audit: confirm this contains the skill-outcome storage; if so, lift into `agent_core::hermes::procedural_memory` per Phase 2 §4.4 |

No parallel implementations. Single-file seed; clean migration path.

---

## 6. Provenance ledger (kernel doctrine §1 Rule 3)

| Surface                                     | Path                                              | Verdict      | Action |
|---|---|---|---|
| `AgentToolProvenanceRecorder` (Swift, `@MainActor`) | `Epistemos/Engine/AgentToolProvenanceRecorder.swift` | **canonical (canon)** | Keep. Single canonical Swift-side recorder. |
| `AgentToolProvenanceSyncRecorder` (Swift, `nonisolated`) | same file                                        | **canonical (canon)** | Sync variant for non-MainActor call sites. Keep. |
| `AgentProvenanceEventKind` enum             | `Epistemos/Models/AgentProvenanceEvent.swift`     | **canonical (canon)** | Keep. 18 variants per H6. Add 6 v1.6 forward variants when needed. |
| `agent_core::events::AgentEvent` (Rust)     | `agent_core/src/events/`                          | **canonical (canon)** | Keep. Mirror of the Swift kind enum. |
| Consumers (10+ Engine files)                | various                                            | **all canonical** | All call into `AgentToolProvenanceRecorder` via the canonical pattern. **Provenance Console (T2) UI is the missing surface** — when it ships, it consumes from the same recorder; no new provenance store needed. |

**Kernel doctrine §1 Rule 3 already met for provenance.** Strongest existing canon-compliance surface in the tree.

---

## 7. Privilege boundary (kernel doctrine §1 Rule 5)

| Surface                                     | Path                                              | Verdict      | Action |
|---|---|---|---|
| `SovereignGate`                             | `Epistemos/Sovereign/SovereignGate.swift`         | **canonical (canon)** | Keep. Single biometric context owner per doctrine §A.7. |
| Consumers (recovery work in `HermesExpertModeRunner`, `CompanionDeleteSheet`, `CompanionRestoreSheet`) | per file                                          | **canonical (canon)** | All route through the canonical gate |
| `Epistemos/Sovereign/SovereignGateLifecycleObserver` | (referenced from `AppBootstrap`)                  | **canonical (canon)** | Observer pattern, not a parallel gate |

**Kernel doctrine §1 Rule 5 already met for Sovereign Gate.**

---

## 8. Cloud providers (orthogonal — not part of the kernel rules but inventoried)

Five providers in `agent_core/src/providers/`:
- `claude.rs` (Anthropic)
- `openai.rs` (OpenAI)
- `openai_compatible.rs` (Groq, Together, etc.)
- `gemini.rs` (Google)
- `perplexity.rs` (Perplexity)
- `schema.rs` (shared types)

**All canonical.** When `appleIntelligence` integration ships
(Stage B.2 of recovery plan), it adds `apple_foundation_models.rs`
to this directory.

---

## 9. The Hermes-runtime gap (the cause of every Hermes UI shortcut)

What does NOT exist in the tree as of 2026-05-04:

| Module (target per Phase 2)                        | Current state |
|---|---|
| `agent_core/src/hermes/mod.rs`                     | does not exist |
| `agent_core/src/hermes/prompt_format.rs`           | does not exist (Swift `HermesPromptBuilder.swift` is the closest existing surface) |
| `agent_core/src/hermes/function_call.rs`           | does not exist (Swift `IncrementalToolCallDetector.swift` is the closest existing surface) |
| `agent_core/src/hermes/skills.rs`                  | partial (`agent_core/src/tools/skills.rs` is the seed; needs lift + consolidation with `skill_router` + `storage/skills_registry`) |
| `agent_core/src/hermes/procedural_memory.rs`       | partial (`agent_core/src/tools/skills.rs` references procedural memory; needs lift) |
| `agent_core/src/hermes/self_evolution.rs`          | does not exist |
| Swift FFI bridge for the new `hermes::*` surface   | does not exist |

**This is exactly the gap the Hermes Expert Mode UI shortcuts are
papering over.** Phase 2 closes the gap by building these six
modules + the FFI; the Hermes Expert Mode UI then calls into them
instead of fanning out to per-command stubs.

---

## 10. Audit summary table

| Doctrine rule (`COGNITIVE_KERNEL_DOCTRINE` §1)     | Status as of 2026-05-04 |
|---|---|
| Rule 1 — One agent loop                            | **PARTIAL** — Swift `LocalAgentLoop` must collapse to FFI caller |
| Rule 2 — One memory store                          | **MET** — vault + agent_core memory surfaces are canonical |
| Rule 3 — One provenance ledger                     | **MET** — `AgentToolProvenanceRecorder` is the single canon |
| Rule 4 — One skill registry                        | **NOT MET** — three parallel Rust surfaces need consolidation in Phase 2 |
| Rule 5 — One privilege boundary                    | **MET** — `SovereignGate` is the single canon |

**Net:** 3 of 5 rules met today. Rules 1 + 4 close in Phase 2
(Hermes-in-Rust) which is Stage B.1 of the recovery plan.

---

## 11. Recommended implementation order (Phase 2 sub-stages)

When Stage B.1 (Hermes-in-Rust) executes, sequence the modules so
each new module compiles + tests before the next begins:

1. **`agent_core/src/hermes/mod.rs`** — empty module with the public
   API surface declared (function signatures, type stubs, no bodies)
2. **`hermes/prompt_format.rs`** — most decoupled; can be tested
   against fixture inputs without the rest of the runtime
3. **`hermes/function_call.rs`** — depends only on streaming token
   types; isolated parser
4. **`hermes/skills.rs`** — consolidates the three current parallel
   surfaces (skill_router + storage/skills_registry + tools/skills);
   wires into the existing `tools::registry`
5. **`hermes/procedural_memory.rs`** — depends on `skills.rs`; SQLite
   storage layer
6. **`hermes/self_evolution.rs`** — depends on `procedural_memory.rs`
   + the canonical `AgentEvent` ring buffer
7. **FFI bridge** in `agent_core/src/bridge.rs` — exposes the seven
   new entry points from `COGNITIVE_KERNEL_DOCTRINE` §3
8. **Swift mirror** — collapse `HermesPromptBuilder.swift` +
   `IncrementalToolCallDetector.swift` to thin FFI consumers

After step 8, the Hermes Expert Mode UI's per-command renderers can
be replaced with calls into the canonical kernel — closing the
biggest hackathon shortcut structurally.

---

## 12. Completed follow-up audit items

These were the original open items in the first draft of this audit; they
were read and classified on 2026-05-04 before Phase 2 code was
authorized.

1. **`agent_core/src/runtime/`** — not a fourth loop. `typestate.rs`
   is lifecycle-state scaffolding; `write_pipeline.rs` is Resource
   Runtime verified-write / readback / audit-log plumbing.
2. **`agent_core/src/skill_router.rs`** — routing logic. It parses
   vault `skills/*.md`, computes IDF, and routes queries by explicit
   triggers or TF-IDF cosine. Collapse into `hermes::skills::router`.
3. **`agent_core/src/storage/skills_registry.rs`** — persistence
   layer. It stores skill usage, success/failure counts, and timestamps
   in `skills/skills_registry.yaml`. Move under Hermes skills storage.
4. **`agent_core/src/tools/skills.rs`** — active procedural-memory
   tool facade. It owns SKILL.md CRUD, progressive disclosure
   (`skills_list`, `skill_view`, `skill_manage`), install-from-github /
   URL / local path, quarantine scanning, and promotion. Split under
   Hermes skills while preserving registration through `tools::registry`.
5. **`Epistemos/Bridge/ToolTierBridge.swift`** — bridge consumer, not
   a prompt builder. It loads Rust tool schemas, applies visible-surface
   distribution filtering, and executes tool calls through Rust FFI.
6. **`Epistemos/App/ChatCoordinator.swift`** — runtime prompt
   assembler and context gatherer. It currently joins Swift strings for
   Rust agent sessions, with typed PromptTree composition behind
   `EPISTEMOS_PROMPT_TREE`; Phase 2 should make Rust
   `hermes::prompt_format` the canonical builder and keep
   `ChatCoordinator` as structured-input plumbing.

**Stage A.1 status:** complete. A.2 / A.3 GenUI or
Stage B.1 Hermes module scaffolding. The next code slice must cite the
collapse path above instead of re-opening these verdicts.

---

## 13. Cross-references

```
docs/fusion/COGNITIVE_KERNEL_AUDIT_2026_05_04.md       ← this doc (Stage A.1 deliverable)
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md    (canonical kernel doctrine; this audit informs Phase 2)
docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md      (Stage A.1 of the recovery sequence)
docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md (broader runtime audit; complements this kernel-specific one)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md     (T0 sub-track 1 status)
CLAUDE.md                                              (NON-NEGOTIABLE constraints)
```
