# SS-N — Sensitive-info redaction model (on-device PII detect/redact) (2026-06-19)

Read-only research (subagent), code-grounded + web-validated. Feeds the SENSITIVE-INFO-REDACTION ledger item +
pairs with SS-M (privacy). Owner: *"OpenAI open-source model that's able to redact out sensitive information"*
(on-device PII detect/redact before store/display/cloud-send). Doctrine: local-first, on-device, embed-not-
sidecar, honest gating, no-fake, engine-isolation.

## Headline
**MOSTLY-NEW — one real seam exists, narrowly scoped.** The repo has a regex `PIIRedactor` (email/phone/SSN/CC)
+ three credential redactors + the native NER primitives (NLTagger `.nameType`, NSDataDetector) — but **none
sit at the cloud-egress seam, and the NER primitives are wired only to note-insight, never to redaction.** No
name/address/health/financial-aware redaction MODEL, no pre-cloud-egress filter. **The owner's "OpenAI
open-source model" is REAL:** OpenAI shipped **Privacy Filter** (~Apr 2026, Apache-2.0, gpt-oss-derived,
on-device, 1.5B/50M-active sparse-MoE, BIOES token-classification over 8 PII categories) — BUT it's
ONNX/safetensors only, **no MLX/GGUF runtime**, so NOT drop-in embeddable on the app's MLX-Swift lane today.

## What exists (secret/narrow-PII) vs the gap (no egress PII model)
- **Rust credential redactor** `agent_core/src/security.rs:131 redact_credentials()` (16 prefixes `:105-122` +
  PEM `:166`) — applied to **tool OUTPUT only** (`agent_loop.rs:989,1009`), inbound to history, NOT outbound.
- **Browser/web error-string redaction** `browser.rs:811 redact_browser_error_token`/`:794`; `web.rs:404
  describe_web_request_error` — error messages, not user content.
- **Skills quarantine scanner** `skills.rs:1254 scan_quarantined_tree` (40-rule) — detection-only, supply-chain.
- **Swift `PIIRedactor`** `KnowledgeFusion/Alignment/FeedbackLogger.swift:31` (email `:37`/phone `:44`/SSN `:51`/
  CC `:58` → `[REDACTED_*]`). **ONLY caller = FeedbackLogger** (`:152-153`, redacts KTO training data before
  SQLite). No other call site (grep empty). Tested `EpistemosTests/PrivacyTest.swift:17-75`.
- **`CredentialRedactor`** `Omega/Safety/CredentialRedactor.swift:11-27`; **`AmbientCaptureService.redactSecrets`**
  `State/AmbientCaptureService.swift:217` — secrets, not personal PII.
- **GAP:** secret/credential redaction = EXISTS; a real PII-detection MODEL (NER over names/addresses/orgs/
  health/financial) at egress/vault = ABSENT. The NER engine EXISTS — `Engine/NLAnalysisService.swift:31
  extractEntities` (NLTagger `.nameType`→person/place/org `:50-52`) + `Engine/DataDetectionService.swift:30`
  (NSDataDetector address/phone/date/link `:33`) — but both feed note-insight (`TextCapturePipeline.swift:272`,
  `ProseEditorRepresentable2.swift:1571`), **NOT redaction.** Bridging NER→redaction is the missing wire.

## The "OpenAI model" reality + honest mapping
- **OpenAI Privacy Filter is real** (not gpt-oss): Apache-2.0, 1.5B/50M-active sparse-MoE (128 experts top-4),
  gpt-oss backbone, token-classification (BIOES, 33 logits/token, 8 categories: account_number/private_address/
  private_email/private_person/private_phone/private_url/private_date/secret). Runtimes: Transformers/
  Transformers.js/ONNX; safetensors F32/BF16. **No MLX/GGUF.**
- **gpt-oss-20b/120b** (Aug 2025) = separate general LLMs, not PII-specific.
- **Honest mapping (notarized Swift/Rust, no Python sidecar, MLX lane):**
  - **DEFAULT / MAS-safe:** Apple **NLTagger `.nameType`** (person/place/org NER) + **NSDataDetector** (address/
    phone/date/link) + **Rust regex** for structured tokens (SSN/CC/email/API-key — reuse `security.rs` +
    `PIIRedactor`). 100% on-device, free, zero download, App-Store-safe. **Covers 6 of Privacy-Filter's 8
    categories natively.** Recommended default-on layer.
  - **Pro/Research (deferred):** OpenAI Privacy Filter = broader NER but no MLX/GGUF → needs ONNX→CoreML or MLX
    port (unverified MAS/notarization) → gate under `F-ProprietaryCompression-ProvenanceGate`. OR a local-LLM
    redaction pass (app's own Gemma/Qwen via MLX) — heavier, Pro.
  - **Honesty:** do NOT claim "the OpenAI model is embedded" until a real MLX/CoreML build loads — that's a
    no-fake violation. Ship NLTagger+regex now; track Privacy-Filter as a Pro upgrade.

## Egress hook points
- **Cloud egress (critical):** bodies assembled in `providers/claude.rs` — `message_to_api_json` +
  `apply_message_cache_breakpoints` `:284-285`, body `json!` `:298`, POST `:537-539`; mirrors in `openai.rs`,
  `gemini.rs`. **NO existing pre-send redaction hook on outbound messages** — `agent_loop.rs` redaction
  (`:989,1009`) is tool-output (inbound). The `messages.map(message_to_api_json)` step is the single choke
  point for a pre-egress filter.
- **Pre-storage:** `storage/vault.rs:646 write(...)` (Tantivy index) — redact-before-index candidate.
- **Display (optional):** `ProseTextView2.swift:1570` already attribute-tags detected data — reversible masking.

## Native embedding design
`SensitiveInfoRedactor` native in-process service: **detection** = NLTagger NER (reuse `NLAnalysisService
.extractEntities`) + NSDataDetector (reuse `DataDetectionService.detect`) + Rust structured-token regex (lift
`security.rs` + `PIIRedactor`); categories mirror Privacy-Filter's 8 for forward-compat. **Wiring:** register
ONCE in the shared registry (`tools/registry.rs`) → all engines share it, AND insert as a pre-egress filter at
`message_to_api_json` (`claude.rs:284` + mirrors) behind a flag. **Reversible** tokenize→restore (`[PERSON_1]`,
map kept local-only, restored on inbound render) for agent flows that need the value back, AND **destructive**
for storage/feedback. Reversible map NEVER leaves device. **Settings:** `redact-before-cloud` master + per-
category toggles (names/addresses/contact/financial/health/secrets). **MAS** = NLTagger+regex default-on;
**Pro** = Privacy-Filter ONNX / local-LLM pass.

## Honest gating
Fully-local NLTagger+regex = MAS-safe, default-on, no entitlement/network. **NEVER send PII to a cloud model to
detect PII** (self-defeating — hard no). **No-fake:** redactor must actually fire + be witnessed (extend
`PrivacyTest.swift` with egress-path tests asserting the cloud body has no raw PII; no green until a test
proves the outbound body is scrubbed, ARCHITECTURE_TIER T4). **Engine-isolation:** one shared redactor,
identical for cloud+local, no per-engine bypass. Privacy-Filter gated Research until a real CoreML/MLX load.

## Ordered plan
1. **[S]** Promote `PIIRedactor` (`FeedbackLogger.swift:31`) → shared `SensitiveInfoRedactor`; add a flagged
   **pre-egress hook** at `claude.rs:284` (+ openai/gemini) on the outbound message array; add egress no-PII
   test to `PrivacyTest.swift`. Destructive mode first.
2. **[S]** Wire the existing NER — route `NLAnalysisService.extractEntities` + `DataDetectionService.detect` into
   the redactor so names/addresses/orgs are covered, not just regex.
3. **[M]** Reversible tokenize→restore map (local-only) for agent flows; Settings master + per-category toggles;
   pre-storage redaction option at `vault.rs:646`.
4. **[M]** Map categories to Privacy-Filter's 8-label taxonomy; display-layer masking reusing `ProseTextView2
   .swift:1570`.
5. **[L/Pro-Research]** Evaluate Privacy-Filter embed (ONNX→CoreML/MLX port + MAS proof under provenance gate)
   OR local-LLM (Gemma/Qwen) redaction pass. Gated, no hidden fallback, witnessed.

## Unverified
Privacy-Filter on-disk size, ONNX/onnxruntime MAS-sandbox viability, CoreML-conversion feasibility (no MLX/GGUF
build — ONNX/Transformers/safetensors only). Whether `openai.rs`/`gemini.rs` body-build differs from `claude.rs`
inferred from provider-matrix, not line-read.

Key files: `KnowledgeFusion/Alignment/FeedbackLogger.swift:31` (PIIRedactor) · `EpistemosTests/PrivacyTest.swift
:17-75` · `Engine/NLAnalysisService.swift:31` (NLTagger NER — unwired to redaction) · `Engine/DataDetection
Service.swift:30` · `Omega/Safety/CredentialRedactor.swift:11` · `State/AmbientCaptureService.swift:217` ·
`agent_core/src/security.rs:131,105` · `agent_core/src/tools/skills.rs:1254` · `tools/browser.rs:811` +
`web.rs:404` · `providers/claude.rs:284-298,537` (**egress seam**) + openai.rs/gemini.rs mirrors · `agent_loop
.rs:327,989,1009` · `storage/vault.rs:646`. Sources: HF openai/privacy-filter; openai.com/index/introducing-
openai-privacy-filter; model-card PDF; VentureBeat; MarkTechPost (2026-04).
