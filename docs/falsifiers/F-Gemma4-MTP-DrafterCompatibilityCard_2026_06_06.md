---
falsifier: F-Gemma4-MTP-DrafterCompatibilityCard
created_on: 2026-06-06
artifact: artifacts/falsifiers/gemma4_mtp_drafter_compatibility_card/result.json
scope: T1/L1 metadata-only Gemma 4 MTP drafter compatibility
---

# F-Gemma4-MTP-DrafterCompatibilityCard

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS
ships the safe floor, Pro contains the gated/research/vault/omega ladder, and
no claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 witness on 2026-06-06.

The artifact is:

- `artifacts/falsifiers/gemma4_mtp_drafter_compatibility_card/result.json`

The script is:

- `Tools/falsifiers/f_gemma4_mtp_drafter_compatibility_card.sh`

## What It Proves

`F-Gemma4-MTP-DrafterCompatibilityCard` source-cards Gemma 4 MTP target/drafter
pairs before MTP can influence RuntimeRouter / System G.

It accepts two compatibility cards:

- target `google/gemma-4-12B-it` with drafter
  `google/gemma-4-12B-it-assistant`
- target `google/gemma-4-E2B-it` with drafter
  `google/gemma-4-E2B-it-assistant`

The witness binds:

- official Google Gemma 4 MTP source with the reported upper-bound speedup
  capped as source material, not product proof
- Hugging Face model IDs, revisions, and Apache-2.0 license metadata
- upstream `F-LiteRTLM-NativeSwiftAdmission` proof
- target-token verification
- accepted and rejected draft-token visibility
- target-only final output
- hidden alternate text and hidden chain rejection
- quality, acceptance, latency, and extra-memory metric requirements
- rollback, RunEventLog, AnswerPacket, and abstention requirements

The artifact rejects 41 red fixtures, including target/drafter mismatch,
unsupported license, bad revisions, non-HTTPS source, unsupported runtime lane,
MAS/Live promotion, T2 promotion, unbounded speed claim, missing verification,
missing token visibility, hidden alternate text, hidden chain, missing quality
or acceptance metrics, missing latency or extra-memory budgets, missing
rollback/RunEventLog/AnswerPacket/abstention, nonzero target/drafter/runtime
bytes, provider calls, product-file copies, first-token claims, product speed
claims, quality-improvement claims, MAS readiness, live dense 70B, hidden route
authority, and hidden cloud fallback.

## What It Does Not Prove

This witness does not download a target model, download a drafter model, load a
runtime, import LiteRT-LM, run GGUF/MLX/Transformers, start a server, emit a
first token, benchmark MTP, prove quality, prove speed, prove MAS safety, or
make any product capability claim.

Correct phrasing:

- Architecture source-card compatibility proof advanced for Gemma 4 MTP
  target/drafter pairs.
- Product capability, runtime route, MTP speedup, MAS readiness, and
  user-facing model surfaces did not advance.

## Next Unit

The next runtime-plural research-to-build unit is
`F-RuntimePlural-QATLaneTournamentPlan`, comparing LiteRT-LM, GGUF/llama.cpp,
MLX, and explicit local endpoint candidates on the same redacted fixture with
visible byte, latency, cancellation, quality, rollback, RunEventLog, and
AnswerPacket evidence.
