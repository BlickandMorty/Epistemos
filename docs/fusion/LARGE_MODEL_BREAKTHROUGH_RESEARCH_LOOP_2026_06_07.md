# Large Model Breakthrough Research Loop - 2026-06-07

Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Purpose

This document upgrades the research method for making large local models practical in Epistemos. Research is not allowed to remain a summary. Every promising source must become one of:

- a source card
- a falsifier backlog item
- a UAS primitive
- a runtime-harness fixture
- a red-team fixture
- a blue-team repair rule
- a visible L2/L3 promotion requirement

## Current Bottlenecks

The large-model path is still bottlenecked by:

- exact artifact mapping from model card to file bytes, OIDs, revisions, licenses, conversion method, and local owner manifest
- local path safety without symlink, shortcut, rowid, or Downloads-folklore laundering
- selected-byte envelope math versus actual UMA, KV cache, app headroom, runtime workspace, and model-loader overhead
- crash-safe command envelopes before any loader, subprocess, mmap, GGUF, MLX, LiteRT, or provider-like endpoint is touched
- first-token proof on small models before larger rows
- quality and accuracy proof after quantization, including exact baseline, held-out tasks, refusal drift, tool-JSON drift, citation drift, and coding/research/writing task quality
- visible AnswerPacket and RunEventLog promotion rather than hidden route authority

## Source Intake Ladder

For each candidate large-model mechanism, use this ladder:

1. Local canon: Living Index, Master Research Index, June 1 canon, June 6 QAT/TurboVec canon, Downloads-folder research.
2. Official source: Google/Apple/Hugging Face/model owner/repo owner docs.
3. Code source: original GitHub repo, forks, releases, issues, PRs, benchmarks, tests, examples.
4. Paper source: arXiv, OpenReview, conference pages, official project pages.
5. Community signal: Reddit/forums/blogs only as leads, never as promotion authority.
6. Quarantine clone: inspect risky/no-license code for APIs, tests, failure cases, benchmark methodology, memory assumptions, and motifs without contaminating product code.
7. Epistemos source card: convert source into exact refs, byte claims, caveats, risk class, ProductBuild, ProStatus, and next falsifier.

## Artifact-Pull Accuracy

Every model or compressed artifact must be mapped with this record before runtime:

- model id and source owner
- exact revision, branch, tag, commit, or release
- file list and selected file names
- declared file bytes and measured local bytes
- git-lfs OID or digest where available
- conversion method and converter version
- quantization family: QAT, PTQ, GGUF, k-quant, TQ3_4S, HLWQ, APEX, NVFP4, AutoRound, TurboQuant-like, or other
- runtime lane: llama.cpp/GGUF, MLX, MLX Swift, LiteRT-LM, Transformers, KTransformers, vLLM, or research-only
- hardware tier and UMA/KV/app-headroom envelope
- owner manifest, allowed root, path-canonicalization proof, byte-envelope proof, crash-safe command proof
- no-hidden-cloud, no-hidden-router, no PatternBoost/lattice/Eidos live authority

No artifact can promote from a URL, filename, row id, source-card claim, local-looking path, or benchmark screenshot.

## Red-Team / Blue-Team Loop

Each research pass must synthesize adversarial failures first:

- mislabeled QAT versus PTQ
- fork drift or malicious fork replacing files under a known model id
- Git LFS pointer mismatch
- GGUF conversion mismatch
- tokenizer mismatch
- local symlink/path traversal/tilde/env expansion
- file bytes fitting but KV/app/runtime workspace not fitting
- MoE active-parameter count treated as resident-memory proof
- TurboVec compressed coordinates treated as durable truth
- benchmark cherry-picking or prompt leakage
- hidden provider fallback
- hidden route mutation by Eidos, PatternBoost, lattice, or a model self-router
- command that is dry-run in docs but executable in code
- AnswerPacket absent or uncorrelated with logs

Then blue-team each failure into one of:

- a validation rule in UAS primitive code
- a red fixture in the falsifier binary
- an axis in `agent_core/src/falsifier_artifacts/axes.rs`
- a command/script guard
- a Living Index/lattice disclaimer
- a runtime harness assertion

Use `docs/fusion/LARGE_MODEL_KEYWORD_RESEARCH_ATLAS_2026_06_07.md` as the
query-expansion companion for every pass. It contains Epistemos-native keyword
families, GitHub/arXiv/Hugging Face search recipes, red-team mutations, blue-
team repair mutations, and build-track translations.

2026-06-07 Pass 86 addendum: before searching externally, mine current app
symbols and active gates into equivalent phrasing clusters. Cross UAS/OAS,
ColdStore/AppColdStore, ActiveAssembly, Eidos, SCOPE-Rex/SovereignGate,
RuntimeRouter/System G, RunEventLog/AnswerPacket, PatternBoost, lattice,
owner-path manifests, path canonicalization, byte envelopes, command
envelopes, KV/cache, QAT, TurboVec, EML/Lean, and Metal safety with red-team
failures and blue-team repairs. The keyword atlas now has source-specific
GitHub/HF/arXiv/Downloads/code-search packs and creative combinations that map
directly to future falsifiers. This is T0 research/backlog pressure only; it
does not arm commands, load model/runtime bytes, or promote L2/L3 capability.

## Breakthrough Targets

Prioritize mechanisms that plausibly become code:

- QAT model lane: Gemma 4 QAT, especially small harness candidates and the 12B Pro Gated target.
- GGUF/llama.cpp lane: exact file manifests, command dry-run, first-token, KV envelope, quality replay.
- MLX lane: only after loader support and Swift/Metal constraints are source-carded; MLX is a lane, not the architecture.
- LiteRT-LM lane: Swift package/binary review, unsafe linker review, command and cancellation proof.
- TurboVec/TurboQuant lane: Eidos/AppColdStore compressed retrieval cache only, with UAS-stable external IDs and allowlist-before-rank.
- KV compression lane: KIVI/LeanKV/InnerQ/TurboQuant-style ideas as source-carded motifs before runtime authority.
- MoE/sparse lane: active params are compute evidence only; full-weight bytes and KV bytes still bind.
- Proof-guided route lane: Lean/AxProver/OProver-style compiler feedback, verifier traces, and repair loops for route correctness and code-generation confidence.
- EML/Primitive IR lane: elementary-function charts are internal primitive maps, not substrate-wide proof; source-card EML/math repos as motifs before implementation.

## Current External Validation Leads

- Google Gemma 4 QAT official blog: `https://blog.google/innovation-and-ai/technology/developers-tools/quantization-aware-training-gemma-4/`
- Google TurboQuant official research blog: `https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/`
- TurboVec repository: `https://github.com/RyanCodrai/turbovec`
- KIVI KV cache quantization paper: `https://arxiv.org/abs/2402.02750`
- LeanKV KV compression paper: `https://arxiv.org/abs/2412.03131`
- OProver agentic Lean proving paper: `https://arxiv.org/abs/2605.17283`
- AxProver project and baseline repo: `https://prover.axiomatic-ai.com/`, `https://github.com/Axiomatic-AI/ax-prover-base`
- Lean State Search: `https://premise-search.com/`

These are leads for falsifiers, not product claims.

## Immediate Codeable Backlog

1. `exotic_quant_crash_safe_command_envelope_preflight_gate`
   - Consume byte-envelope preflight.
   - Require unarmed command envelope, dry-run serialization, no subprocess execution, cancellation token, rollback, RunEventLog, AnswerPacket, and owner approval absent.
   - Red-team executable command leakage, hidden provider fallback, bad cwd, unsafe env, path traversal, stale model revision, and missing logs.

2. `large_model_artifact_pull_accuracy_source_card`
   - Bind model id, revision, selected files, LFS OIDs/digests, declared bytes, local bytes, converter, tokenizer, and runtime lane.
   - Red-team rowid identity, fork drift, file mismatch, and benchmark screenshot promotion.

3. `qat_accuracy_shadow_replay_preflight`
   - Build held-out prompts for coding, research notes, writing, tool JSON, citations, refusal behavior, and long-context recall.
   - Require exact baseline, quantized candidate, answer packet, and no hidden chain.

4. `kv_cache_envelope_model_fit_gate`
   - Bind prompt length, batch, heads, layers, dtype, KV compression mode, app headroom, and runtime workspace.
   - Red-team "weights fit, KV does not" and "TurboQuant solves all RAM" claims.

5. `proof_guided_route_repair_card`
   - Source-card Lean/AxProver/OProver-style compiler/verifier feedback as route repair motifs.
   - Keep as Pro Research until local verifier traces and rollback exist.

## Promotion Rule

Research can be brilliant and still be T0. It reaches T1 only when a falsifier exists. It reaches T2 only when the capability kernel admits a product route. It reaches T3 only when WRV proves a user-visible surface. It reaches T4 only when MAS/Pro build and logs agree. It reaches T5 only when the whole substrate segment has no unmapped gaps.
