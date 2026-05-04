# Dead Code Report

> **Index status**: CANONICAL-OPERATIONAL — Append-only audit log; needed for state reconstruction. No copy to _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



- Generated: Sat Mar 21 15:26:43 CDT 2026
- Root: `/Users/jojo/Epistemos`

## Non-Direct SwiftPM Pins
- These are pins in `Package.resolved` that are not direct Xcode package references.
- They may be legitimate transitive dependencies; review before deleting.
- `eventsource`
- `swift-asn1`
- `swift-atomics`
- `swift-collections`
- `swift-crypto`
- `swift-jinja`
- `swift-nio`
- `swift-numerics`
- `swift-system`
- `swift-transformers`
- `yyjson`

## Potentially Orphaned Model Scripts
- `/Users/jojo/Epistemos/scripts/models/build_retrieval_index.py`
- `/Users/jojo/Epistemos/scripts/models/build_retrieval_index.sh`
- `/Users/jojo/Epistemos/scripts/models/build_retrieval_index_test.py`
- `/Users/jojo/Epistemos/scripts/models/common.sh`
- `/Users/jojo/Epistemos/scripts/models/common_test.sh`
- `/Users/jojo/Epistemos/scripts/models/prepare_retrieval_assets.sh`
- `/Users/jojo/Epistemos/scripts/models/prepare_router.sh`

## TODO / FIXME / HACK / XXX Hits
- /Users/jojo/Epistemos/docs/codex-v2-release-audit.md:302:- TODOs that represent real work vs aspirational notes
- /Users/jojo/Epistemos/docs/codex-v2-release-audit.md:306:- All `// TODO:` comments across the codebase
- /Users/jojo/Epistemos/docs/plans/2026-03-03-query-compiler.md:568:        case (.updated, .gte): filter.createdAfter = value // TODO: add updatedAfter to NodeFilter
- /Users/jojo/Epistemos/docs/plans/2026-03-03-query-compiler.md:808:        // TODO: Requires BTK integration. Query block properties via FFI.
- /Users/jojo/Epistemos/docs/plans/2026-03-03-query-compiler.md:814:        // TODO: Requires BTK integration. Query block depth via FFI.
- /Users/jojo/Epistemos/graph-engine/src/knowledge_core/parser.rs:233:        return (Some("TODO"), false, Cow::Borrowed(rest));
- /Users/jojo/Epistemos/graph-engine/src/knowledge_core/parser.rs:238:    if let Some(rest) = trimmed.strip_prefix("TODO ") {
- /Users/jojo/Epistemos/graph-engine/src/knowledge_core/parser.rs:239:        return (Some("TODO"), false, Cow::Borrowed(rest));
- /Users/jojo/Epistemos/graph-engine/src/knowledge_core/parser.rs:331:            "* TODO Root :owner:jojo:\n** Child [[note]]",
- /Users/jojo/Epistemos/graph-engine/src/lib.rs:146:    /// Task marker such as TODO or DONE.
- /Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs:1084:    if let Some(rest) = trimmed.strip_prefix("TODO ") {
- /Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs:1085:        return ("TODO".to_string(), !rest.is_empty());
- /Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs:1091:        return ("TODO".to_string(), false);
- /Users/jojo/Epistemos/graph-engine/src/block_kernel/query_kernel.rs:1147:                content: "TODO Root [[child-ref]]".into(),
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-103022.md:347:1085 |         return ("TODO".to_string(), rest.is_empty() && false);
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-103022.md:353:1085 |         return ("TODO".to_string(), rest.is_empty() && false);
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-105328.md:98:1085 |         return ("TODO".to_string(), rest.is_empty() && false);
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-105328.md:104:1085 |         return ("TODO".to_string(), rest.is_empty() && false);
- /Users/jojo/Epistemos/docs/future-work-audit.md:13:- In-code TODOs
- /Users/jojo/Epistemos/docs/future-work-audit.md:258:- **Fix:** Fulfill the existing TODO in `ResearchState.swift` to migrate `savedPapers` to a proper `SDSavedPaper` @Model inside SwiftData.
- /Users/jojo/Epistemos/docs/future-work-audit.md:1510:## IN-CODE TODOs
- /Users/jojo/Epistemos/docs/future-work-audit.md:1514:| `Epistemos/State/ResearchState.swift` | 35 | `// TODO: Migrate to SDSavedPaper @Model when library view is built.` |

## Live Legacy AI Runtime References
- none

## Historical Legacy AI Doc References
- /Users/jojo/Epistemos/docs/future-work-audit.md:881:  - **Primary local server:** Microsoft Foundry Local — OpenAI-compatible REST API, auto-routes to Intel NPU/CUDA GPU/CPU. Models: Phi-3.5-mini (NPU), DeepSeek-R1.
- /Users/jojo/Epistemos/docs/future-work-audit.md:1340:  - **Layer 1: Microsoft Foundry Local** — Primary on-device model server. OpenAI-compatible REST API (`localhost:{PORT}/v1`). Auto-detects and routes to best hardware (NPU/CUDA GPU/CPU). Uses `foundry-local` Rust crate for model management + `reqwest` for inference. Models: Phi-3.5-mini (NPU-optimized), DeepSeek-R1 distilled. Equivalent to Apple Intelligence Foundation Models framework.
- /Users/jojo/Epistemos/docs/superpowers/specs/2026-03-10-craft-inspired-vision-design.md:393:| **DeepSeek** (new) | deepseek-r1 | Strong reasoning, very cheap |
- /Users/jojo/Epistemos/docs/superpowers/specs/2026-03-10-craft-inspired-vision-design.md:1447:| `LLMService` | New `MLXClient` + request builders for DeepSeek (OpenAI-compatible API) and Grok |
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:20:| 0 — Decision Reset | complete | audited | DeepSeek lane removed from the live target architecture |
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:21:| 1 — Artifact Inventory | complete | audited | local Qwen and retrieval assets remain relevant; reasoner artifacts are no longer part of the plan |
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:26:| 5 — Structured Local Contract | not started | not audited | blocked on 4.5 completion; no sidecar or separate reasoner lane is part of this phase |
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:36:- DeepSeek/reasoner runtime routing has been removed
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:37:- optional sidecar/worker routing has been removed from the live app
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:90:- another heavy local reasoner
- /Users/jojo/Epistemos/docs/ai_stack_implementation_plan.md:100:4. docs, manifests, and tests no longer advertise removed reasoner behavior
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:5:Epistemos no longer carries a separate DeepSeek reasoner lane.
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:15:## Why DeepSeek Was Removed
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:17:The previous heavy-reasoner split created the wrong tradeoff for the 18 GB target:
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:24:The app is easier to stabilize with one real local text model than with a router-plus-reasoner split that was not operationally solid.
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:44:1. No DeepSeek runtime path.
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:45:2. No prepared reasoner role in the live manifest.
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:46:3. No UI that implies a separate heavy reasoner exists.
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:74:- bringing back a dedicated heavy reasoner before Phase 5
- /Users/jojo/Epistemos/docs/ai_stack_decision_report.md:75:- replacing DeepSeek with another large local model immediately
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-130204.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-105328.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/ai_stack_phase_audit_log.md:12:- DeepSeek/reasoner runtime routing was removed from live code
- /Users/jojo/Epistemos/docs/ai_stack_phase_audit_log.md:13:- the prepared model manifest no longer carries reasoner entries
- /Users/jojo/Epistemos/docs/ai_stack_phase_audit_log.md:36:- DeepSeek/reasoner removal from live runtime state, tests, scripts, and manifest
- /Users/jojo/Epistemos/docs/ai_stack_phase_audit_log.md:37:- optional sidecar/worker routing has been removed from the live app
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-103022.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-150205.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-150205.md:6015:◇ Test "live local ai surfaces stay free of sidecar and deepseek residue" started.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-150205.md:6082:✔ Test "live local ai surfaces stay free of sidecar and deepseek residue" passed after 3.355 seconds.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-151726.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-151726.md:5328:◇ Test "live local ai surfaces stay free of sidecar and deepseek residue" started.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-151726.md:9429:✔ Test "live local ai surfaces stay free of sidecar and deepseek residue" passed after 3.047 seconds.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-145858.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-150644.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-150644.md:5222:◇ Test "live local ai surfaces stay free of sidecar and deepseek residue" started.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-150644.md:5301:✔ Test "live local ai surfaces stay free of sidecar and deepseek residue" passed after 3.015 seconds.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-152308.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-152308.md:4897:◇ Test "live local ai surfaces stay free of sidecar and deepseek residue" started.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-152308.md:4950:✔ Test "live local ai surfaces stay free of sidecar and deepseek residue" passed after 3.174 seconds.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-111847.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-111847.md:4423:◇ Test "live local ai surfaces stay free of sidecar and deepseek residue" started.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-111847.md:4468:✔ Test "live local ai surfaces stay free of sidecar and deepseek residue" passed after 3.810 seconds.
- /Users/jojo/Epistemos/docs/audits/verify-2026-03-21-110651.md:11:- Failing on sidecar / DeepSeek / localhost transport residue in live code.
