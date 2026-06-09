# Epistemos — Engineering Bible

## Golden Rules (non-negotiable)

1. **Zero copy-paste.** If code exists, call it. If two things look similar, extract a shared function. Three similar lines is better than a premature abstraction, but four is not.
2. **Direct communication.** No wrappers around wrappers. No indirection for indirection's sake. The shortest path from intent to execution wins.
3. **Performance is architecture.** Pre-allocate buffers. Debounce hot paths. Cache expensive results. Zero per-frame allocations in render loops. No `repeatForever` animations — gate with `windowOccluded` + `reduceMotion`.
4. **Minimal fixes.** Don't refactor adjacent code. Don't add features beyond what's asked. Don't add comments to code you didn't change. A bug fix is just a bug fix.
5. **Test-first.** Write a failing test before the fix. Edge cases: empty, nil, max, unicode, concurrent, rapid toggle.
6. **Read before writing.** Never modify a file you haven't read. Understand existing code before touching it.
7. **macOS Opulent only.** Never touch `~/Epistemos-RETRO/`, `src-tauri/`, or `~/meta-analytical-pfc/` from this repo. Those are separate projects.
8. **Research-first.** For every concept, deliberation, task, refactor, reroute,
   reduction, bug fix, or simple edit, search the local canon before coding:
   start at `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`, follow the
   canonical source it names, then verify current code/logs. Use a quick local
   pass for simple edits and a deeper pass for architecture/high-risk work; do
   not waste tokens reading unrelated docs. If the local canon lacks a
   structured answer or the task depends on current external facts (API, OS,
   package, model, App Store, security, framework), do a targeted web
   validation pass with primary/official sources where possible. Web validates
   the local plan; it does not replace the user's research corpus. Apply this to
   Codex, Claude, Kimi, and every delegated agent handoff. Use semantic
   expansion: "zero-copy" also means UMA, in-process, single-binary,
   deterministic, no hot-path subprocess, no tensor copies, direct/bare-metal
   path, and "as complex as a brain, as simple as an app, as fast as a jet."

## Current Architecture Addendum — 2026-06-01

Full-thread umbrella codeword: `JUNE1-CANON-FUSION-LOCK`. If the user invokes
that codeword, reintegrate the entire June 1 research/canon thread before
acting on older architecture language. Narrow residency subset:
`JUNE1-PATTERNBOOST-LOCK`.

Future agents must preserve the new local-reasoning doctrine before touching
UAS/AppColdStore, active model-state selection, sparse residency, mmap/SSD
transport, dynamic compute, route/layout policy, or 70B-cocktail work.

Required current reads for that domain:
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md`
- `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- `docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`
- `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`
- `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`
- `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
- `docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md`
- `docs/fusion/MLX_QAT_TURBOVEC_LOCAL_SUBSTRATE_RESEARCH_2026_06_06.md`
- `docs/fusion/LARGE_MODEL_BREAKTHROUGH_RESEARCH_LOOP_2026_06_07.md`
- `docs/fusion/LARGE_MODEL_KEYWORD_RESEARCH_ATLAS_2026_06_07.md`

The current lock is ambitious but falsifier-gated:
- Model size is cold material, not a live-RAM promise. UAS makes model, KV,
  note, graph, adapter, verifier, and tool units addressable and comparable;
  active capability comes from selecting, prefetching, leasing, verifying, and
  witnessing the smallest sufficient support set.
- Residency PatternBoost is the offline/idle discovery layer. It may search
  UAS assembly genomes, repair invalid candidates, sparsely fingerprint them,
  archive held-out winners, and distill reusable route/layout motifs before
  live execution. It must not become hidden live route authority.
- PatternBoost-derived policies remain Pro Research / Pro Vault-Preserved until
  repair, sparse fingerprint, held-out replay, LatticeAbstentionGate,
  ComputeResumeLease, rollback, and AnswerPacket witness evidence pass.
- Zero-copy is a backend/compute/transport/proof discipline, not a blanket ban
  on product copies. Preserve intentional copies for multiple graph/editor
  surfaces, undo-safe text storage, previews, snapshots, visual variants, and
  artifacts unless a falsifier proves they are on a compute or transport hot
  path.
- Older Helios, ACS, 70B, mmap, lane/tier, and research-corpus language is
  historical unless the Living Index or Master Research Index promotes it
  through the June 2026 canon. Translate old "ACS admission" wording to
  AcsAnchor for address/residency continuity and SCOPE-Rex/SovereignGate for
  admission/governance.

## Compression / Runtime-Plural Addendum — 2026-06-06

Future agents must preserve the TurboVec/QAT intake before touching local model
routing, MLX/GGUF/LiteRT lanes, compressed retrieval, low-bit KV experiments,
Gemma 4, TurboQuant, TurboVec, llama.cpp, Rapid-MLX/OpenCode/Hermes motif
mining, or large-model compression work.

Required reads for that domain:
- `docs/audits/SOVEREIGN_ARCHITECTURE_HARDENING_PROMPT_2026_06_06.md`
- `docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md`
- `docs/fusion/MLX_QAT_TURBOVEC_LOCAL_SUBSTRATE_RESEARCH_2026_06_06.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §0E
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md` §6 June 6 entries

Runtime policy:
- MLX is Apple Silicon first-lane where it proves quality, stability, and
  Swift-loader support, but Epistemos is not MLX-only. GGUF/llama.cpp,
  LiteRT-LM, Transformers, custom Metal, and optional user-selected local
  endpoints remain candidate execution organs under System G / RuntimeRouter /
  SovereignGate / AnswerPacket.
- Current app inference paths still obey MAS/Pro boundaries and no hidden
  sidecar/cloud fallback. Pro runtime-plural experiments must be explicit,
  owner-gated, witnessed, rollbackable, and never silently selected.
- Gemma 4 12B QAT GGUF/LiteRT is the current Pro Gated research target.
  Gemma 4 E2B/E4B QAT are MAS/Pro candidates only after memory,
  cancellation, structured-output, loader, package-size, RunEventLog, and
  AnswerPacket witnesses. MLX Gemma 4 repos are not Swift runtime proof.
- 2026-06-08 simplification: near-term large-model work is Gemma-first.
  Work E2B QAT GGUF/llama.cpp as the harness lane, E4B QAT as the next scale
  lane, and 12B QAT GGUF/LiteRT as the Pro flagship target before returning to
  broad model-family exploration. Preserve 70B-class/custom cold assembly for
  the point where Gemma-class models become too large for ordinary runtime
  proof or no longer suffice. This is a build-order policy only: it does not
  make Gemma live, default, quality-proven, user-facing, or System G admitted.
- 2026-06-08 best-runtime lock: for Gemma work, optimize for the smallest
  evidence-producing runtime first, not the prettiest model-picker row. The
  current preferred implementation sequence is E2B QAT GGUF via direct
  llama.cpp with exact owner manifest, file digest, runtime digest, redacted
  one-token proof, memory samples, cancellation/teardown, RunEventLog, and
  AnswerPacket; then E4B repeats the same harness; then 12B QAT GGUF/LiteRT
  can become the Pro flagship only after its own byte, quality, release-audit,
  and product-capability recheck evidence. MLX Swift and LiteRT-LM remain
  candidate lanes until loader/package/cancellation/product integration proof
  lands. A downloadable model or HF command example is source evidence, not an
  Epistemos product route.
- 2026-06-08 release-audit bottleneck lock: do not try to make Gemma the main
  app model by bypassing the current product gate. The guard-owned bottleneck
  is still
  `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
  Its retained artifact is red because `xcodebuild_test` failed. Treat the top
  retained family `graph_filter_visibility` as the first focused repair target,
  then rerun the full automated-check gate, then log/manual/distribution/
  repeated-zero-fail evidence. Only after that can a Gemma E2B product
  capability recheck be meaningful.
- 2026-06-08 focused proof-root boundary: graph-filter command-card and
  execution-artifact parser gates validate as metadata-only evidence on current
  HEAD, but the actual focused Xcode proof-root run requires explicit owner
  approval per
  `docs/audits/FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_2026_06_08.md`.
  Do not treat command-card/parser PASS as executed Swift tests, full
  automated-check PASS, release readiness, or Gemma product capability.
- 2026-06-08 Gemma fast-add distinction: a model-picker/settings row can be
  added quickly only as honest gated visibility. Gemma as the main app model is
  a separate runtime admission claim requiring owner path, selected byte
  envelope, runtime digest, cancellation, rollback, RunEventLog, AnswerPacket,
  release-audit evidence, and user-visible caveats. Do not let a visible row
  mutate RuntimeRouter/System G/default-model state, skip the release-audit
  bottleneck, or imply live E2B/E4B/12B capability.
- 2026-06-08 Gemma E2B release-audit surface status:
  `F-GemmaQATE2BReleaseAuditSurfaceGate` is landed as metadata-only L1/T1. It
  consumes the settings/diagnostics WRV gate and binds the release-audit skill,
  red automated-check blocker, graph-filter proof-root command card,
  execution-artifact parser gate, owner-approval runbook, log/manual/
  distribution/repeated-zero-fail requirements, settings/diagnostics copy,
  AnswerPacket, RunEventLog, rollback, abstention, SCOPE-Rex, SovereignGate,
  cancellation, non-promotion, fast-row gated visibility, owner action, and
  product-capability recheck deferral. It wires zero settings rows, runs zero
  Xcode commands, loads zero model/runtime/provider bytes, and does not make
  Gemma live/default/user-facing. Next Gemma side-ladder unit:
  `gemma_qat_e2b_product_capability_recheck_gate`, still blocked by the
  guard-owned release-audit automated-check cursor for product truth.
- 2026-06-08 Gemma E2B product-capability recheck status:
  `F-GemmaQATE2BProductCapabilityRecheckGate` is landed as metadata-only
  L1/T1. It consumes the release-audit surface gate plus regenerated
  architecture guard/capability-kernel truth, and passes only by proving Gemma
  E2B product capability is still blocked by
  `small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
  It binds 36 recheck fields, 52 fail-closed policies, 9 blocked truth anchors,
  6 gated surfaces, 62 red fixtures, rollback, RunEventLog, AnswerPacket,
  abstention, SCOPE-Rex, SovereignGate, non-promotion, and next-unit deferral.
  It wires zero settings rows, emits zero user-visible AnswerPackets, runs zero
  Xcode commands, loads zero model/runtime/provider bytes, mutates zero routes
  or defaults, and does not make Gemma live/default/L2/L3/T4. Next Gemma
  side-ladder unit:
  `gemma_qat_e2b_release_audit_blocker_repair_bridge_gate`, still downstream of
  the guard-owned release-audit automated-check cursor for product truth.
- 2026-06-08 runtime-lane split research: Deep Research Pass 206 upgrades the
  Gemma runtime plan into two evidence lanes. Keep E2B QAT GGUF/direct
  `llama.cpp` as the smallest owner-approved one-token harness. Add a separate
  Pro Gated LiteRT-LM native admission track for Gemma 4 12B because current
  Google AI Edge and LiteRT-LM sources now claim Gemma 4 12B support,
  OpenAI-compatible serving, and Swift package support for macOS/iOS. This is
  source-card canon only: no LiteRT-LM package, endpoint, sidecar, route,
  settings row, model bytes, or product capability is proven. Proposed backlog:
  `F-GemmaRuntimeLaneSplit-SourceCard`,
  `F-LiteRTLMGemma12BNativeAdmissionSourceCard`,
  `F-GemmaMTPAccelerationPacket`, and
  `F-GGUFQATForkDeltaQuarantineCard`.
- 2026-06-08 MTP acceleration packet research: Deep Research Pass 207 makes
  Gemma MTP/speculative decoding a target-verified acceleration packet, not a
  runtime default. MTP may improve larger Gemma responsiveness only after the
  base route exists, target verification preserves the final answer digest,
  acceptance/latency/memory counters are visible, Apple Silicon overhead beats
  baseline, rollback disables MTP without disabling the base route, and
  RunEventLog/AnswerPacket witnesses exist. Treat Atomic/TurboQuant, Unsloth,
  and other assistant-GGUF/fork signals as quarantine references until
  `F-GemmaMTPAccelerationPacket` source-cards exact assistant/runtime digests,
  same-fixture replay, abstention, provenance, and no hidden route authority.
- 2026-06-08 GGUF/QAT fork-delta quarantine research: Deep Research Pass 208
  sharpens `F-GGUFQATForkDeltaQuarantineCard`. Official Google QAT Q4_0 is the
  baseline; Unsloth Dynamic 2.0 / UD-Q* GGUFs, Atomic/TurboQuant assistant/KV
  forks, bartowski/mradermacher-style conversions, and older local Downloads
  model memos are useful motif sources only. Every fork delta must bind source
  URL, upstream base, conversion tool/version, quant recipe, selected bytes,
  digest, license/provenance/import mode, extracted motif, failure risk,
  same-fixture replay, rollback, RunEventLog, AnswerPacket, abstention, and no
  route/default mutation before RuntimeRouter/System G can cite it.
- 2026-06-08 GGUF/QAT same-fixture replay research: Deep Research Pass 209
  defines `F-GGUFQATForkDeltaSameFixtureReplaySchema` as the next fork-delta
  replay contract. Official Google QAT Q4_0, Unsloth Dynamic 2.0 / UD-Q*,
  Atomic/TurboQuant assistant/KV forks, community conversions, and clean-room
  rewrites must compete on the same fixture pack with baseline source card,
  fork source card, selected-byte budget, runtime digest, tokenizer digest,
  chat-template digest, prompt/scorer digest, final output digest,
  structured-output/tool-call/citation validity, memory and latency counters,
  timeout/cancel/teardown, rollback, RunEventLog, AnswerPacket, abstention, and
  no route/default/settings mutation. Current evidence from Google Gemma 4 QAT,
  llama.cpp, LiteRT-LM, LightEval, and lm-evaluation-harness is source-card
  material only; it does not prove Epistemos Gemma runtime, L2/L3, or product
  capability.
- 2026-06-08 Gemma replay fixture/scorer lock research: Deep Research Pass 210
  defines `F-GemmaReplayFixtureScorerPackLock` as the Gemma-first fixture pack
  that E2B, E4B, 12B, official QAT, forked GGUF, LiteRT-LM, MLX, and future
  clean-room runtime lanes must reuse. The seven required task families are
  note synthesis, research citation grounding, coding patch planning, writing
  style transform, structured tool JSON, refusal/privacy boundary, and
  latency/abstention. Each family must bind descriptor digest, redacted prompt
  digest, allowed-source digest, deterministic scorer digest, failure taxonomy,
  AnswerPacket fields, RunEventLog join, rollback, MAS/Pro caveat, and no
  route/default/settings mutation. Inspect AI, LightEval, lm-evaluation-harness,
  and llama.cpp grammar/JSON support are motifs only; Epistemos owns the
  fixture/scorer proof.
- 2026-06-08 Gemma direct harness rail research: Deep Research Pass 211 defines
  `F-GemmaDirectHarnessAdmissionRail` as the first owner-approved live-probe
  shape. The first Gemma proof should use local-only E2B/E4B QAT GGUF through
  bounded `llama-cli` single-turn execution, not `-hf` remote download,
  `llama-server`, an OpenAI-compatible sidecar, MLX, LiteRT-LM, or a fork
  winner. The rail must bind selected model/source-card digest, owner path
  digest, `llama-cli` binary/version digest, command-template digest, prompt
  digest, seed, context/predict caps, grammar/JSON option digest when needed,
  timeout/cancel, termination reason, stderr redaction, timing/memory plan,
  rollback, RunEventLog, AnswerPacket, abstention, MAS/Pro caveat, and no
  route/default/settings mutation. Server/tool-call rails can come later after
  the direct CLI artifact is reviewable.
- 2026-06-08 Gemma direct harness receipt-map research: Deep Research Pass 212
  defines `F-GemmaDirectHarnessArtifactReceiptMap` as the digest-only bridge
  from a future bounded `llama-cli` Gemma run into the already-landed runtime
  replay, first-token artifact review, reconciliation, and same-fixture gates.
  It requires subject/material/invocation/process/observation/join/promotion
  sections, rejects raw prompt/output/stdout/stderr/token/path bytes, hidden
  command args, missing exit/termination/timeout/cancel/teardown/redaction/
  memory/timing evidence, and any RuntimeRouter/System G/default mutation.
  This is T0 research-to-build canon only: it does not prove Gemma works, does
  not run a model, and does not promote Gemma to live/default/L2/L3/T4.
- 2026-06-08 Gemma direct harness receipt-map status:
  `F-GemmaDirectHarnessArtifactReceiptMap` is now landed as metadata-only
  L1/T1. It consumes the existing Gemma execution artifact, owner-approved
  execution probe, and first-token review gate artifacts, binds 7 receipt
  sections, 26 receipt fields, 37 rejection policies, process exit/
  termination/timeout/cancel/teardown proof, redaction/timing/memory proof,
  RunEventLog, AnswerPacket, rollback, abstention, non-promotion, and 45
  red-fixture rejections. It reads zero receipt/model/runtime/provider bytes,
  arms or executes zero commands, captures zero raw prompt/output/stdout/
  stderr/token/path bytes, mutates zero RuntimeRouter/System G/settings/
  default state, and makes no Gemma live/default/L2/L3/T4/user-facing claim.
- 2026-06-08 Gemma direct harness receipt-emitter status:
  `F-GemmaDirectHarnessOwnerApprovedReceiptEmitterGate` is now landed as
  metadata-only L1/T1. It consumes the landed direct-harness receipt-map
  artifact, binds 33 emitter fields, 42 abort conditions, owner approval,
  owner path-manifest digest, upstream receipt-map digest, model/llama.cpp/
  version/command-template digests, argv/environment/workdir/prompt/grammar
  digests, process/timeout/cancel/teardown/stdout/stderr policies, token
  redaction, timing/memory samplers, atomic write, cleanup, RunEventLog,
  AnswerPacket, rollback, abstention, non-promotion, and 54 red-fixture
  rejections. It writes zero receipts, reads zero receipt/model/runtime/
  provider bytes, opens zero files, arms or executes zero commands, captures
  zero raw owner path/prompt/output/stdout/stderr/token bytes, mutates zero
  RuntimeRouter/System G/settings/default state, and makes no Gemma
  live/default/L2/L3/T4/user-facing claim. Next side-ladder unit is
  `gemma_direct_harness_receipt_emitter_dry_run_artifact_gate`.
- 2026-06-08 Gemma direct harness dry-run artifact status:
  `F-GemmaDirectHarnessReceiptEmitterDryRunArtifactGate` is now landed as
  metadata-only L1/T1. It consumes the landed direct-harness receipt-emitter
  gate, binds 36 dry-run artifact fields, 46 abort conditions, upstream
  emitter digest, dry-run schema and artifact digest, owner/model/llama.cpp/
  command placeholders, argv/environment/workdir/prompt/grammar policies,
  process/timeout/cancel/teardown/stdout/stderr policies, token redaction,
  timing/memory sampler plans, temp-path/atomic-write/cleanup policy,
  RunEventLog, AnswerPacket, rollback, abstention, non-promotion, and 60
  red-fixture rejections. It writes zero dry-run artifact bytes, writes or
  reads zero receipt bytes, opens zero files, arms or executes zero commands,
  captures zero raw owner path/prompt/output/stdout/stderr/token bytes, mutates
  zero RuntimeRouter/System G/settings/default state, and makes no Gemma
  live/default/L2/L3/T4/user-facing claim. Next side-ladder unit is
  `gemma_direct_harness_owner_approved_receipt_runbook_gate`.
- 2026-06-08 Gemma direct harness runbook status:
  `F-GemmaDirectHarnessOwnerApprovedReceiptRunbookGate` is now landed as
  metadata-only L1/T1. It consumes the landed dry-run artifact gate, binds 34
  runbook fields, 46 abort conditions, owner approval and identity digests,
  owner path/model/llama.cpp/version/command digest requirements, argv/
  environment/workdir/prompt/grammar policies, context/predict caps,
  seed/timeout/cancel/teardown, stdout/stderr redaction, memory/timing
  samplers, temp/atomic/cleanup policy, RunEventLog, AnswerPacket, rollback,
  abstention, human-visible confirmation, non-promotion, and 52 red-fixture
  rejections. It writes zero runbook bytes, opens zero owner/model/llama.cpp
  paths, arms or executes zero commands, captures zero raw owner path/prompt/
  output/stdout/stderr/token bytes, mutates zero RuntimeRouter/System G/
  settings/default state, and makes no Gemma live/default/L2/L3/T4/user-facing
  claim. Next side-ladder unit is
  `gemma_direct_harness_owner_approved_receipt_preflight_packet_gate`.
- 2026-06-08 Gemma direct harness preflight packet status:
  `F-GemmaDirectHarnessOwnerApprovedReceiptPreflightPacketGate` is now landed
  as metadata-only L1/T1. It consumes the landed owner-approved runbook gate,
  binds 30 preflight fields, 45 abort conditions, owner/path/model/llama.cpp
  digests, hardware profile, memory byte envelope, command/prompt policies,
  timeout/cancel/stdio/sampler policy, rollback, RunEventLog, AnswerPacket,
  abstention, human-visible confirmation, no-command-arm proof,
  non-promotion, and 46 red-fixture rejections. It writes zero preflight packet
  bytes, opens zero owner/model/llama.cpp paths, arms or executes zero
  commands, captures zero raw owner path/prompt/output/stdout/stderr/token
  bytes, mutates zero RuntimeRouter/System G/settings/default state, and makes
  no Gemma live/default/L2/L3/T4/user-facing claim. Next side-ladder unit is
  `gemma_direct_harness_owner_approved_command_envelope_gate`.
- 2026-06-08 Gemma direct harness command envelope status:
  `F-GemmaDirectHarnessOwnerApprovedCommandEnvelopeGate` is now landed as
  metadata-only L1/T1. It consumes the landed owner-approved preflight packet
  gate, binds 35 command-envelope fields, 58 abort conditions,
  owner/path/model/llama.cpp identity, hardware and memory verdicts,
  argv/environment allowlists, shell/network/hub-download denial,
  prompt/grammar policy, timeout/cancel/teardown, stdio redaction, output byte
  cap, token digest policy, memory sampler, rollback, RunEventLog,
  AnswerPacket, abstention, human-visible confirmation, no-execution proof,
  non-promotion, and 51 red-fixture rejections. It writes zero command
  envelope bytes, opens zero owner/model/llama.cpp paths, arms or executes zero
  commands, spawns zero processes, captures zero raw owner path/prompt/output/
  stdout/stderr/token bytes, mutates zero RuntimeRouter/System G/settings/
  default state, and makes no Gemma live/default/L2/L3/T4/user-facing claim.
  Next side-ladder unit is
  `gemma_direct_harness_owner_approved_redacted_dry_run_receipt_gate`.
- 2026-06-08 Gemma direct harness redacted receipt status:
  `F-GemmaDirectHarnessOwnerApprovedRedactedDryRunReceiptGate` is now landed
  as metadata-only L1/T1. It consumes the landed owner-approved command
  envelope gate, binds 28 receipt fields, 51 abort conditions,
  owner/model/llama.cpp identity, exit/timeout/teardown policy,
  stdout/stderr/first-token/prompt digest policy, redaction maps, output/token
  byte caps, memory/timing samples, temp/atomic/cleanup policy, rollback,
  RunEventLog, AnswerPacket, abstention, human-visible confirmation,
  no-route-mutation proof, quality denial, non-promotion, and 48 red-fixture
  rejections. It writes zero receipt bytes, opens zero temp/owner/model/
  llama.cpp paths, arms or executes zero commands, spawns zero processes,
  captures zero raw prompt/output/stdout/stderr/token bytes, mutates zero
  RuntimeRouter/System G/settings/default state, and makes no Gemma
  live/default/L2/L3/T4/user-facing claim. Next side-ladder unit is
  `gemma_direct_harness_owner_approved_first_token_digest_review_gate`.
- 2026-06-09 Gemma direct harness first-token digest review status:
  `F-GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate` is now landed
  as metadata-only L1/T1. It consumes the landed owner-approved redacted
  dry-run receipt gate, binds 24 review fields, 46 abort conditions,
  owner/model/llama.cpp identity, prompt and first-token digests, tokenizer
  and chat-template identity, stdout/stderr/exit/memory/timing digests,
  rollback, RunEventLog, AnswerPacket, abstention, reviewer-visible summary,
  no-raw-token proof, no quality or route claim, and 49 red-fixture
  rejections. It reads zero receipt bytes, writes zero review bytes, observes
  zero live tokens, arms or executes zero commands, spawns zero processes,
  captures zero raw prompt/output/stdout/stderr/token bytes, mutates zero
  RuntimeRouter/System G/settings/default state, and makes no Gemma
  live/default/L2/L3/T4/user-facing claim. Next side-ladder unit is
  `gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate`.
- 2026-06-09 Gemma direct harness same-fixture quality packet status:
  `F-GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate` is now
  landed as metadata-only L1/T1. It consumes the landed owner-approved
  first-token digest review gate, binds 34 quality packet fields, 52 rejection
  policies, owner approval, redacted receipt and first-token review digests,
  model/llama.cpp/prompt/token/tokenizer identity, fixture/scorer/task-family
  digests, redacted candidate output policy, deterministic scorer
  requirements, contamination and cache-deletion proof, rollback, RunEventLog,
  AnswerPacket, abstention, reviewer-visible summary, non-promotion, and 81
  red-fixture rejections. It reads zero quality packet bytes, opens zero
  fixture/review/receipt bytes, runs zero scorers or benchmarks, arms or
  executes zero commands, spawns zero processes, captures zero raw
  prompt/context/output/judge bytes, mutates zero RuntimeRouter/System
  G/settings/default state, and makes no Gemma
  live/default/quality-proven/route-admitted/L2/L3/T4/user-facing claim. Next
  side-ladder unit is
  `gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate`.
- 2026-06-08 Gemma E2B path privacy status: `F-GemmaQATE2BOwnerPathManifestDigestGate`
  is landed as metadata-only L1/T1. It binds the future owner path manifest by
  digest, selected E2B source revision, filename, expected bytes, rollback,
  RunEventLog, AnswerPacket, and abstention while storing zero raw/canonical
  path bytes, reading zero owner-manifest/model/runtime/provider bytes, and
  performing zero canonicalization/stat/hash/symlink actions. Next Gemma unit:
  `gemma_qat_e2b_model_file_and_llama_cpp_digest_gate`.
- 2026-06-08 Gemma E2B model/runtime digest status:
  `F-GemmaQATE2BModelFileAndLlamaCppDigestGate` is landed as metadata-only
  L1/T1. It consumes the owner-path manifest digest gate and requires future
  owner-approved model-file sha256, llama.cpp binary sha256, llama.cpp version
  digest, visible offline command-template digest, memory probe plan,
  timeout/cancel, rollback, RunEventLog, AnswerPacket, and abstention before
  any first-token run can proceed. It opens zero model files, opens zero
  llama.cpp binaries, executes zero version checks, arms zero commands,
  executes zero commands, loads zero model/runtime/provider bytes, rejects HF
  download/server/mmap/provider shortcuts, and makes no MAS/L2/L3/T4/user-
  facing Gemma claim. Next Gemma unit:
  `gemma_qat_e2b_owner_approved_first_token_runtime_probe`.
- 2026-06-08 Gemma E2B owner-approved first-token probe status:
  `F-GemmaQATE2BOwnerApprovedFirstTokenRuntimeProbe` is landed as
  metadata-only L1/T1. It consumes the E2B model-file and llama.cpp digest
  gate, keeps the direct GGUF/llama.cpp E2B lane, and requires explicit owner
  approval, owner manifest digest, canonical path digest, model-file sha256,
  llama.cpp binary sha256, llama.cpp version digest, visible offline command
  template, synthetic prompt digest, memory before/load/first-token/teardown
  samples, timeout/cancel, rollback, RunEventLog, AnswerPacket, and abstention
  before any one-token run can proceed. It rejects 74 red fixtures, opens zero
  files, arms zero commands, executes zero commands, observes zero tokens,
  captures zero raw path/prompt/output/stdout/stderr bytes, loads zero
  model/runtime/provider bytes, denies network/server/download/mmap/provider
  shortcuts, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, E4B/12B
  bypass, quality, benchmark-fit, live dense 70B, or SSD-as-RAM claim. Next
  Gemma unit:
  `gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate`.
- 2026-06-08 Gemma E2B first-token artifact reconciliation status:
  `F-GemmaQATE2BFirstTokenRuntimeArtifactReviewReconciliationGate` is landed
  as metadata-only L1/T1. It consumes the owner-approved first-token probe and
  requires exact owner approval, owner manifest, canonical path, model-file,
  llama.cpp binary/version, command, argv, environment, synthetic prompt,
  redacted first-token, memory, timeout/cancel, teardown, rollback,
  RunEventLog, AnswerPacket, and abstention digests before any future
  first-token artifact can feed quality replay or RuntimeRouter/System G. It
  rejects 66 red fixtures, reads zero runtime artifact bytes, opens zero
  files, hashes zero local files, opens zero llama.cpp binaries, executes zero
  version checks, arms zero commands, executes zero commands, observes zero
  tokens, captures zero raw path/prompt/output/stdout/stderr/token bytes,
  loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/T4/user-
  facing, Gemma-default, E4B/12B bypass, quality, benchmark-fit, live dense
  70B, or SSD-as-RAM claim. Next Gemma unit:
  `gemma_qat_e2b_same_fixture_quality_replay_packet_gate`.
- 2026-06-08 Gemma E2B same-fixture quality packet status:
  `F-GemmaQATE2BSameFixtureQualityReplayPacketGate` is landed as
  metadata-only L1/T1. It consumes the E2B first-token artifact reconciliation
  gate and requires same-fixture pack, deterministic scorer bundle, seven task
  families, owner approval/manifest/path/model-file/llama.cpp digests,
  prompt/context/tool/final-output digests, failure taxonomy, contamination
  check, cache salt/deletion, timeout/cancel, rollback, RunEventLog,
  AnswerPacket, and abstention before a future E2B artifact can feed
  RuntimeRouter/System G admission. It rejects 65 red fixtures, reads zero
  quality packet bytes, opens zero fixture payloads, reads zero runtime
  artifact bytes, runs zero scorers or benchmarks, arms zero commands,
  executes zero commands, captures zero raw prompt/context/output/judge bytes,
  loads zero model/runtime/provider bytes, reuses zero cache bytes, and makes
  no MAS/L2/L3/T4/user-facing, Gemma-default, E4B/12B/70B bypass, quality,
  benchmark-fit, live dense 70B, or SSD-as-RAM claim. Next Gemma unit:
  `gemma_qat_e2b_runtime_router_admission_packet_gate`.
- 2026-06-08 Gemma E2B RuntimeRouter admission packet status:
  `F-GemmaQATE2BRuntimeRouterAdmissionPacketGate` is landed as metadata-only
  L1/T1. It consumes the same-fixture quality packet gate and binds future
  RuntimeRouter/System G admission to 31 admission fields, 48 rejection
  policies, quality summary, failure taxonomy, budget vector, memory headroom,
  KV budget, latency budget, privacy class, MAS/Pro boundary, SCOPE-Rex,
  SovereignGate, fallback, abstention, cancellation, rollback, RunEventLog,
  AnswerPacket, visible caveats, settings/diagnostic visibility, default-model
  non-mutation, hidden-authority denial, and non-promotion. It rejects 61 red
  fixtures, reads zero admission packet bytes, performs zero admission, mutates
  zero RuntimeRouter/System G/default-model state, arms/executes zero commands,
  loads zero model/runtime/provider bytes, captures zero raw prompt/output
  bytes, suppresses zero AnswerPackets, and makes no MAS/L2/L3/T4/user-facing,
  Gemma-default, E4B/12B/70B bypass, quality, benchmark-fit, live dense 70B, or
  SSD-as-RAM claim. Next Gemma unit:
  `gemma_qat_e2b_system_g_dry_run_route_packet_gate`.
- 2026-06-08 Gemma E2B System G dry-run route packet status:
  `F-GemmaQATE2BSystemGDryRunRoutePacketGate` is landed as metadata-only
  L1/T1. It consumes the RuntimeRouter admission packet gate and binds future
  System G dry-run route evidence to 29 route fields, 56 rejection policies,
  System G dry-run envelope, RuntimeRouter policy digest, route-priority
  snapshot, no-priority-mutation proof, budgets, privacy, MAS/Pro boundary,
  SCOPE-Rex, SovereignGate, fallback, abstention, cancellation, rollback,
  RunEventLog, AnswerPacket, visible caveats, settings/diagnostic visibility,
  route explanation, hidden-authority denial, and non-promotion. It rejects 70
  red fixtures, reads zero route packet bytes, performs zero dry-run or
  admission actions, mutates zero RuntimeRouter/System G/default-model state,
  arms/executes zero commands, loads zero model/runtime/provider bytes,
  captures zero raw prompt/output bytes, suppresses zero AnswerPackets, and
  makes no MAS/L2/L3/T4/user-facing, Gemma-default, E4B/12B/70B bypass,
  quality, benchmark-fit, live dense 70B, or SSD-as-RAM claim. Next Gemma unit:
  `gemma_qat_e2b_route_answer_packet_visibility_gate`.
- 2026-06-08 Gemma E2B route AnswerPacket visibility status:
  `F-GemmaQATE2BRouteAnswerPacketVisibilityGate` is landed as metadata-only
  L1/T1. It consumes the System G dry-run route packet gate and binds future
  settings, diagnostics, or WRV visibility to 30 visibility fields, 63
  rejection policies, AnswerPacket template, visible model identity/runtime
  lane/route status/caveat/budgets/privacy/MAS-Pro boundary, visible
  SCOPE-Rex, SovereignGate, fallback, abstention, cancellation, rollback,
  RunEventLog, no-default-model-mutation, no-hidden-authority, non-promotion,
  settings/diagnostics copy, route explanation, rejected-candidate summary,
  user-action requirement, and explicit no-quality/no-live-default/
  no-large-model-bypass claims. It rejects 77 red fixtures, reads zero
  visibility packet bytes, emits zero user-visible AnswerPackets, performs zero
  dry-run or admission actions, mutates zero RuntimeRouter/System G/default-
  model state, arms/executes zero commands, loads zero model/runtime/provider
  bytes, captures zero raw prompt/output bytes, suppresses zero AnswerPackets,
  and makes no MAS/L2/L3/T4/user-facing, Gemma-default, E4B/12B/70B bypass,
  quality, benchmark-fit, live dense 70B, or SSD-as-RAM claim. Next Gemma unit:
  `gemma_qat_e2b_settings_diagnostics_wrv_gate`.
- 2026-06-08 Gemma E2B settings/diagnostics WRV status:
  `F-GemmaQATE2BSettingsDiagnosticsWRVGate` is landed as metadata-only L1/T1.
  It consumes the route AnswerPacket visibility gate and binds future
  settings, diagnostics, release-audit, or WRV surface claims to 34 WRV fields,
  69 rejection policies, settings source marker, diagnostics source marker,
  WRV test marker, manual check plan, release-audit link, AnswerPacket
  template, settings/diagnostics copy, visible model identity/runtime lane/
  route status/caveat/budgets/privacy/MAS-Pro boundary, SCOPE-Rex,
  SovereignGate, fallback, abstention, cancellation, rollback, RunEventLog,
  route explanation, rejected-candidate summary, user-action requirement,
  no-toggle-unlock proof, and explicit no-quality/no-live-default/
  no-large-model-bypass/no-L2-L3-T4 claims. It rejects 87 red fixtures, reads
  zero visibility packet bytes, emits zero user-visible AnswerPackets,
  performs zero route visibility or admission actions, mutates zero
  RuntimeRouter/System G/default-model state, arms/executes zero commands,
  loads zero model/runtime/provider bytes, captures zero raw prompt/output
  bytes, suppresses zero AnswerPackets, and makes no MAS/L2/L3/T4/user-facing,
  Gemma-default, E4B/12B/70B bypass, quality, benchmark-fit, live dense 70B, or
  SSD-as-RAM claim. Next Gemma unit:
  `gemma_qat_e2b_release_audit_surface_gate`.
- 2026-06-07 status: `F-HardwareTieredModelCatalog-SourceCard`,
  `F-MoEActiveParamsMemoryTruth`, `F-ExoticQuantQuarantineRouteCard`, and
  `F-ExoticQuantSourcePinAndByteBudgetPreflight`, and
  `F-ExoticQuantRuntimeLaneOwnerApprovalGate`, and
  `F-ExoticQuantLoaderCompatibilityModelPathGate`, and
  `F-ExoticQuantLocalArtifactAvailabilityOwnerGate`, and
  `F-ExoticQuantOwnerPathManifestIntakeGate`, and
  `F-ExoticQuantOwnerPathCanonicalizationPreflightGate` are landed as T1/L1
  metadata-only witnesses. They make Gemma/Qwopus/MoE/GPU/exotic-quant rows
  addressable, prove active parameters are compute evidence rather than
  memory-fit proof, quarantine TQ3_4S, HLWQ, APEX, NVFP4, and AutoRound before
  any route use, and bind exact source pins, manifest digests, selected-
  artifact bytes, Mac/server tier decisions, pending owner approval, unarmed
  command envelopes, unopened model paths, metadata-only loader classes, owner
  path-manifest requirements, server-only Mac denials, zero owner manifests
  present, zero local paths verified, zero path canonicalization, a typed
  owner path-manifest intake contract, fail-closed path policy, unsafe path
  shape rejection, zero owner path bytes stored, zero file access, rollback,
  RunEventLog, AnswerPacket, and abstention. They do not prove model load,
  local artifact availability, owner path safety, Apple Silicon fit, product
  default, or user-facing capability.
- The downstream `F-ExoticQuantOwnerPathByteEnvelopePreflightGate` is now
  landed as metadata-only L1/T1: it recomputes selected byte envelopes, denies
  Jojo's current 16 GB M2 Pro hardware for all five exotic rows, keeps selected
  bytes non-resident, opens zero files, arms zero commands, and makes no MAS,
  L2, L3, live dense 70B, or SSD-as-RAM claim. The next side-ladder unit is
  `exotic_quant_crash_safe_command_envelope_preflight_gate`.
- 2026-06-08 Gemma-main ladder status: `F-GemmaMainFamilyPolicySourceCard`,
  `F-GemmaQATSmallLaneOwnerPathManifest`,
  `F-GemmaQATByteKVAppEnvelopePreflight`, and
  `F-GemmaQATRedactedFirstTokenProbe`, and
  `F-GemmaQATSameFixtureRuntimeReplay`, and
  `F-GemmaQATHeldOutQualityReplayPacket`, and
  `F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate`, and
  `F-GemmaQATOwnerApprovedRuntimeReplayProbe`, and
  `F-GemmaQATRuntimeReplayExecutionArtifactGate`, and
  `F-GemmaQATOwnerApprovedRuntimeReplayExecutionProbe` are landed as
  metadata-only T1/L1
  witnesses. They make Gemma the preferred Google model-family strategy, bind
  E2B/E4B QAT owner path-manifest contracts, and bind selected artifact bytes
  `12091583309`, KV floor bytes `1342177280`, runtime workspace bytes
  `1879048192`, app headroom bytes `8589934592`, and total planned envelope
  bytes `24104069965` across E2B/E4B warmup cards. They also bind four
  redacted first-token preflight cards across GGUF/llama.cpp and LiteRT-LM,
  owner-approval-pending status, synthetic prompt descriptors, prompt digest
  policy, future token digest policy, one-token/context/batch bounds, 16
  memory sample slots, cancellation, teardown, rollback, RunEventLog,
  AnswerPacket, lane caveats, non-promotion, and 48 red-fixture rejections.
  They now also bind four same-fixture replay cards across E2B/E4B GGUF/LiteRT,
  one replay fixture, source/search/body freshness, prompt/tokenizer/chat-
  template/tool-schema boundaries, memory sampling, one-token replay bounds,
  no cache reuse, cancellation, rollback, RunEventLog, AnswerPacket,
  abstention, non-promotion, and 45 red-fixture rejections.
  They now also bind four held-out quality replay cards across E2B/E4B
  GGUF/LiteRT, one fixture pack, one scorer bundle, seven task families,
  held-out split, synthetic-safe fixture policy, verifier/scorer/final-output/
  failure-taxonomy digests, model-graded-primary denial, hidden-judge denial,
  raw prompt/output denial, rollback, RunEventLog, AnswerPacket, abstention,
  non-promotion, and 46 red-fixture rejections.
  They now also bind four owner-approval-pending runtime replay transcript
  cards across E2B/E4B GGUF/LiteRT, exactly one selected first future probe
  candidate (`E2B` GGUF/llama.cpp), visible unarmed/unexecuted command
  envelopes, transcript templates, fresh memory sample requirements, redacted
  prompt/output digest policies, cancellation, rollback, RunEventLog,
  AnswerPacket, abstention, non-promotion, and 50 red-fixture rejections.
  They now also bind one smallest E2B GGUF/llama.cpp replay-probe envelope,
  offline one-token command template, forbidden download/server/mmap args,
  owner-approval-pending status, model-path-pending status, synthetic prompt
  digest, redacted output digest, fresh memory samples, cancellation, rollback,
  RunEventLog, AnswerPacket, abstention, non-promotion, and 45 red-fixture
  rejections.
  They now also bind the future owner-approved E2B GGUF one-token execution
  artifact schema: 23 manifest fields, 20 rejection policies, owner approval,
  owner model-path manifest digests, canonical path digesting without raw path
  retention, model/command/version digests, redacted prompt/output/first-token
  digests, memory before/start/after samples, cancellation, rollback,
  RunEventLog, AnswerPacket, abstention, non-promotion, and 49 red-fixture
  rejections.
  They now also bind the future owner-approved E2B GGUF/llama.cpp one-token
  execution-probe envelope: 27 proof fields, 24 abort conditions, owner
  approval pending, owner model-path manifest and canonical path digest
  requirements, visible but unarmed command template, offline/no-server/no-
  download/no-mmap-stress/no-provider route, digest/version/memory sample
  requirements, timeout, cancellation, rollback, RunEventLog, AnswerPacket,
  abstention, non-promotion, and 51 red-fixture rejections.
  E2B is only a post-owner-approval probe candidate; E4B is only a tight
  candidate requiring a fresh memory sample. These gates open zero files,
  allocate zero KV/runtime/app bytes, attempt zero first tokens, capture zero
  raw prompt/token/stdout/stderr/tool/cache/output/judge bytes, run zero
  scorers or benchmarks, arm or execute zero commands, observe zero tokens,
  load zero
  model/runtime/provider bytes, and do not prove local availability, path
  safety, runtime fit, Swift MLX loader support, LiteRT embedding, quality,
  product default, L2, L3, live dense 70B, or user-facing Gemma capability.
  The current Gemma side-ladder unit after the landed first-token artifact
  reconciliation gate is
  `gemma_qat_e2b_same_fixture_quality_replay_packet_gate`.
- 2026-06-07 research-to-build lock: future work must separately bind exact
  source pins, file manifests, declared artifact bytes, runtime-lane byte
  envelopes, Mac-tier denial/allowance, full-weight bytes, KV cache bytes,
  expert-residency leases, router/runtime workspace, app headroom, rollback,
  RunEventLog, AnswerPacket, abstention, provenance, clean-room/import mode,
  and no-hidden-authority proof before any MoE/A3B/A4B/exotic-quant row can
  influence RuntimeRouter/System G.
- TurboVec belongs first in Eidos/AppColdStore as a rebuildable compressed
  retrieval cache with UAS-stable external IDs, allowlist-before-rank privacy,
  crash-safe persistence wrapping, exact source validation, and no hidden route
  authority.
- `F-ProprietaryCompression-ProvenanceGate` is mandatory before public-repo
  logic enters the proprietary implementation path. Messy provenance is not a
  reason to lose useful research: clone/run/inspect in quarantine, extract API
  shapes, parser behavior, cache logic, memory assumptions, tests, benchmarks,
  and failure cases, then use compatible direct import, adapter wrapping,
  permission/legal review, or clean-room Epistemos-owned rewrite.
- L1/L2/L3 remain Epistemos truth layers, not runtime tiers. Use hot resident
  lane, balanced local lane, cold assembly, vault research lane, or Pro Gated
  lane for runtime placement.
- A 1536-dimensional vector has about 768 bytes of 4-bit coordinate payload or
  about 384 bytes of 2-bit coordinate payload before norms, IDs, calibration,
  side tables, and index overhead. Do not repeat the older 384/192 byte claim
  for 1536 dimensions.

Future-session prompt lock:
- `docs/audits/SOVEREIGN_ARCHITECTURE_HARDENING_PROMPT_2026_06_06.md` is the
  current paste-ready successor for broad architecture-hardening sessions. It
  preserves the owner's original recursive hardening prompt and the shorter
  external proposal, but adds explicit local research gates, L1/L2/L3 truth
  separation, safe build order, commit/push checkpoints, and the June 6
  TurboVec/QAT runtime-plural intake.

## Architecture Tier Promotion Canon — 2026-06-06

Read `docs/fusion/ARCHITECTURE_TIER_PROMOTION_CANON_2026_06_06.md` before
claiming any architecture segment is green, usable, user-facing, compiled, or
complete. It defines the current end goal and promotion ladder:

- T0 canon/research/vault: ambition or source intake only.
- T1 L1 architecture proof: primitive/source guard/metadata witness only.
- T2 L2 capability route: admitted route through RuntimeRouter/System G,
  rollback, RunEventLog, AnswerPacket, capability kernel, and focused tests.
- T3 L3 WRV surface: wired, reachable, visible, and verified in product
  surfaces with log-correlated proof.
- T4 build-green capability: correct MAS/Pro build scope compiles and passes
  tests/release-audit evidence for the claim.
- T5 full substrate segment: identity, state, assembly, controller,
  verification, user surface, rollback, and witness operate together.

"Green" is reserved for T4 or higher. Metadata-only PASS is blue L1 evidence,
not product green. The full architecture is complete only when every named
segment is T4/T5 or is explicitly red/amber with the missing falsifier, runtime
proof, release audit, or user-facing WRV evidence named.

## Release Audit Rule

For release-readiness, final regression, or "is this truly ready?" work, use the repo skill `.agents/skills/epistemos_release_audit/SKILL.md`.

That workflow is mandatory for ship calls:
- logs are first-class evidence
- manual/runtime verification is required on ship-risk surfaces
- unsupported model modes must disappear, not merely fail
- App Store versus direct-distribution readiness must be evaluated explicitly
- no release-ready claim without repeated zero-fail verification

## Architecture Overview

**Opulent Edition** = Swift + Metal + Rust FFI. macOS native. Apple Design Award quality.

```
User → SwiftUI Views → @Observable State → Services (Engine/) → Rust FFI (graph-engine/)
                                         → SwiftData (Models/)
                                         → Apple Intelligence (TriageService)
```

### Key Files (read these first for any subsystem)

| Subsystem | Start Here | Then Read |
|-----------|-----------|-----------|
| AI Pipeline | `Engine/TriageService.swift` | `Engine/PipelineService.swift`, `Engine/LLMService.swift` |
| Graph | `Graph/GraphState.swift` | `Graph/GraphStore.swift`, `Graph/GraphBuilder.swift` |
| Graph Engine (Rust) | `graph-engine/src/lib.rs` | `src/renderer.rs`, `src/physics.rs`, `src/types.rs` |
| Note Editor | `Views/Notes/ProseEditorView.swift` | `Views/Notes/ProseEditorRepresentable2.swift`, `Views/Notes/ProseTextView2.swift` |
| Note Chat | `State/NoteChatState.swift` | `Views/Notes/NoteChatSidebar.swift`, `Views/Notes/NoteWindowManager.swift` |
| Note Windows | `Views/Notes/NoteWindowManager.swift` | `Views/Notes/NotesSidebar.swift` |
| Graph Overlay | `Views/Graph/HologramController.swift` | `Views/Graph/HologramOverlay.swift`, `Views/Graph/MetalGraphView.swift` |
| Environment | `App/AppEnvironment.swift` | `App/AppBootstrap.swift`, `App/EpistemosApp.swift` |
| Vault Sync | `Sync/VaultSyncService.swift` | `Sync/NoteFileStorage.swift` |
| Models | `Models/SDPage.swift` | `Models/SDGraphNode.swift`, `Models/GraphTypes.swift` |

### Bible & State Files

- `docs/future-work-audit.md` — THE BIBLE. 21 waves, 134 items. All planned work.
- `docs/audit-progress.md` — Audit state. Read this to know what's been fixed/deferred.

## Patterns to Follow

### Swift

- `@MainActor @Observable` for all state classes. Never `ObservableObject`.
- `withAppEnvironment(bootstrap)` for environment injection — never manual `.environment()` chains. Single source: `AppEnvironment.swift`. NoteWindowManager uses this too.
- `nonisolated(unsafe)` for NSView properties written from AppKit event handlers.
- `Task { @MainActor in }` for delayed work — never `DispatchQueue.main.asyncAfter`.
- Swift Testing framework (`@Suite` + `@Test` + `#expect`). Never XCTest.
- `guard let` / `if let` — never force unwrap (`!`).
- `do/catch` — never `try!`.
- `Int(floatValue)` traps on NaN/Infinity — always guard with `value.isFinite` first.

### Rust

- `#[repr(C)]` on all FFI structs. Match Swift layout.
- `// SAFETY:` comment required on every `unsafe` block.
- `with_capacity()` for all Vec allocations in hot paths.
- `#[test]` inline in modules or `tests/` directory.
- Zero `clone()` in render loop — borrow or use indices.

### SwiftUI + AppKit Bridge

- NSTextStorage changes go through `shouldChangeText`/`didChangeText` for undo support.
- Use `isFlushingTokens` flag to suppress binding sync during programmatic storage changes.
- Binding sync (Coordinator → SwiftUI) must be debounced (300ms) to prevent per-keystroke SwiftUI re-evaluation.
- Never call `page.loadBody()` in a SwiftUI view body — it reads from disk on every re-evaluation.

## Patterns to Avoid

- Manual `.environment()` chains — use `withAppEnvironment()`.
- `.repeatForever` animations — use `TimelineView` gated by `windowOccluded`.
- `DispatchQueue.main.asyncAfter` — use `Task.sleep`.
- `parent.text = tv.string` on every keystroke — debounce to 300ms.
- `page.needsVaultSync = true` during streaming — causes @Query refetch cascade.
- `loadBody()` in SwiftUI view body — disk read on every re-evaluation.
- `Int(Float.nan)` — traps. Always check `.isFinite` first.
- Committing without running `xcodebuild test` + `cargo test`.

## Critical Anti-Patterns (learned from real bugs)

### The Binding Cascade
Coordinator writes `parent.text` → SwiftUI `onChange` fires → sets `page.needsVaultSync = true` → `@Query` refetches → NoteTabView body re-evaluates → `loadBody()` (disk read) → `updateNSView` → text sync races with next callback. **Fix:** Debounce binding sync to 300ms. Never sync during AI streaming.

### The Zone Protection Gap
`shouldChangeTextIn` guards AI zone only during `isStreaming`. After streaming ends but before accept/discard, user edits above divider don't adjust offset → stale offset → data loss on accept. **Fix:** Guard whenever `hasDivider` is true, not just `isStreaming`.

### The Multi-Turn Double Insertion
Second query when `hasDivider` is already true — tokens appended raw without prompt header separator. **Fix:** Track `lastFlushedTurnCount`, insert header when turn count increases.

### The Environment Sync Drift
NoteWindowManager had a manual list of `.environment()` calls that drifted from `AppEnvironment.swift`. Any new state object added to AppEnvironment but not to NoteWindowManager caused runtime crashes. **Fix:** Use `withAppEnvironment(bootstrap)` everywhere. Single source of truth.

### The Unpersisted Dirty Flag
Setting `page.needsVaultSync = true` without `modelContext.save()` appears to work in memory but the `@Query(filter: #Predicate { $0.needsVaultSync == true })` in the sidebar never sees it, and `isDirtyVault` returns false after a context refresh. **Fix:** Always call `try? modelContext.save()` immediately after setting dirty flags. See `docs/bug-fixes/2026-03-03-note-saving-fix.md`.

## Service Architecture

### TriageService — AI Routing
Routes operations between the two live local tiers:
- Apple Intelligence for the lightest rewrite / summarize / simple ask work
- local Qwen 3.5 for deeper local reasoning, coding, graph analysis, and long-context work
- no cloud fallback in the live app

Operations and their tiers:
| Operation | Complexity | Route |
|-----------|-----------|-------|
| `.rewrite` | 0.25 | Apple Intelligence when light enough, otherwise local Qwen |
| `.summarize` | 0.20 | Apple Intelligence when light enough, otherwise local Qwen |
| `.continueWriting` | 0.30 | Local Qwen |
| `.outline` | 0.40 | Local Qwen |
| `.expand` | 0.50 | Local Qwen |
| `.analyze` | 0.60 | Local Qwen |
| `.ask(query:)` | 0.20 + query complexity | Apple Intelligence when light enough, otherwise local Qwen |

### NoteChatState — Per-Note AI Chat
One instance per open note tab. Manages query → response cycle with 60ms token buffering.
- Callbacks wired by ProseEditorRepresentable Coordinator: `onStreamStart`, `onTokenFlush`, `onAccept`, `onDiscard`.
- AI text lives in NSTextStorage below a `---` divider, not in a separate view.
- Accept strips divider, keeps response inline. Discard removes everything from divider onward.
- `noteBodyProvider` closure reads current body from storage (set by Coordinator).

### GraphStore — Compact Storage
Internal storage uses Int-indexed arrays for O(1) adjacency lookup:
- `_nodeIdx: [String: Int]` — node ID → stable compact index
- `_neighbors: [[Int]]` — compact adjacency lists (deduplicated)
- `_edgesOf: [[Int]]` — edge reverse index
- `_trigramIdx: [String: [Int]]` — trigram → posting list for fuzzy search
- Proxy types (`AdjacencyProxy`, `EdgesByNodeProxy`) preserve `store.adjacency[nodeId]` syntax.
- Public API unchanged: `nodes`, `edges`, `adjacency`, `edgesByNode` all work as before.

### GraphState — FFI Bridge
- `engineHandle: OpaquePointer?` — the Rust engine pointer.
- `pendingNodes` / `pendingEdges` — queue for incremental FFI updates, drained in render loop.
- `mode: .global | .page(nodeId:)` — determines graph scope.
- `buildPageSubgraph()` — extracts quotes, sources, wikilinks as ephemeral nodes.
- All mutations `@MainActor` serialized. No races.

### PhysicsCoordinator — Cross-View State
`@Observable` singleton for graph ↔ sidebar hover signaling:
- `graphHoveredNodeId: String?` — written by MetalGraphNSView on mouseMoved.
- Read by `GraphReactiveModifier` on sidebar rows for highlight effect.
- Zero cost when idle (no timers, no per-frame work).

## FFI Boundary (Swift <-> Rust)

Header: `graph-engine-bridge/graph_engine.h` (42 functions)
- All FFI calls must have nil engine guards.
- String encoding: UTF-8 both sides, validate on return.
- Memory ownership: Rust allocates, Rust frees. Swift never frees Rust memory directly.
- Node types: Note(0), Chat(1), Idea(2), Source(3), Folder(4), Quote(5), Tag(6), Block(7)
- Edge types: reference(0)..questions(11) — 12 total including semantic edges.

## Note Editor Internals

### ProseEditorRepresentable2 + ProseTextView2 (the heart of editing)
TextKit 2 editor bridge wrapping `ProseTextView2` (`NSTextView` backed by `NSTextLayoutManager`).
- **Coordinator2** owns: binding sync debounce (300ms), table alignment, AI callbacks, fold/indent helpers, and transclusion overlay coordination.
- **MarkdownContentStorage** — delegate-backed structural + inline markdown styling for the TK2 stack.
- **ProseTextView2** — NSTextView subclass with wikilink handling, AI context menu notifications, structural edit helpers, and divider protection.

### Text Flow
```
User types → ProseTextView2.didChangeText() → reparseAndInvalidate()
           → Coordinator2.textDidChange() → debounced binding sync (300ms)
           → ProseEditorView debounced disk/model save
AI streams → NoteChatState.appendStreamingText() → 60ms buffer
           → flushTokens() → onTokenFlush callback
           → Coordinator2.flushNoteChatTokens() → insert into storage
           → isFlushingTokens flag prevents binding sync cascade
```

### AI Context Menu Operations
Right-click in editor → ProseTextView2 builds menu → posts notification with operation string.
NoteTabView receives notification → `handleAIContextMenuOperation()` maps to `(NotesOperation, systemPrompt, userPrompt)` → `noteChatState.submitQuery()`.

Operations: rewrite, summarize, expand, simplify, toList, toTable, continue, outline, structure, restructure.

## View Modifiers (Theme/PhysicsModifiers.swift)

| Modifier | Purpose | Cost |
|----------|---------|------|
| `.physicsHover(.subtle/.medium/.lift)` | Scale + shadow on hover | Zero when idle |
| `.physicsPress()` | Scale down on press, spring back | Zero when idle |
| `.breathe()` | 30Hz subtle oscillation | TimelineView, gated by `windowOccluded` |
| `.springEntrance(index:)` | Staggered appear animation | One-shot |
| `.graphReactive(nodeId:)` | Highlight when graph hovers matching node | Requires `PhysicsCoordinator` in environment |
| `.glassEffect()` | macOS 26 liquid glass | System-provided |
| `.siriGlow()` | Animated border glow (streaming indicator) | Active only during streaming |

## Testing

```bash
# Swift (1403 tests, 194 suites)
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test

# Rust (549 tests)
cd graph-engine && cargo test

# Quick build check
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build
```

Test file naming:
- `EpistemosTests/<System>Tests.swift` — core tests
- `EpistemosTests/<System>EdgeCaseTests.swift` — boundary + edge cases
- `EpistemosTests/<System>ComprehensiveTests.swift` — thorough coverage
- `EpistemosTests/<System>AuditTests.swift` — audit-specific tests

## Audit Status

**AUDIT COMPLETE.** Waves 1-13 fully reviewed. 16 fixes committed, 9 already implemented, 15 not-a-bug.
Remaining deferred (architecture changes, not minimal fixes):
- W7.4: Graph Store Memory — DONE (compact Int-indexed arrays)
- W13.2: Fuzzy Search Scalability — DONE (trigram index)
- W17.13: App Crashes Creating Note — needs actual crash log to reproduce

## File Layout

| Purpose | Location |
|---------|----------|
| App bootstrap + environment | `Epistemos/App/` |
| State classes (@Observable) | `Epistemos/State/` |
| Services (AI, pipeline, triage) | `Epistemos/Engine/` |
| Graph state + builder | `Epistemos/Graph/` |
| Graph engine (Rust) | `graph-engine/src/` |
| FFI bridge header | `graph-engine-bridge/graph_engine.h` |
| SwiftData models | `Epistemos/Models/` |
| Vault sync + file I/O | `Epistemos/Sync/` |
| Views — Graph | `Epistemos/Views/Graph/` |
| Views — Notes | `Epistemos/Views/Notes/` |
| Views — Chat | `Epistemos/Views/Chat/` |
| Views — Landing | `Epistemos/Views/Landing/` |
| Views — Shell | `Epistemos/Views/Shell/` |
| Theme + modifiers | `Epistemos/Theme/` |
| Tests (Swift) | `EpistemosTests/` |
| Audit bible | `docs/future-work-audit.md` |
| Audit progress | `docs/audit-progress.md` |
