---
falsifier: F-GemmaMainFamilyPolicySourceCard
date: 2026-06-08
artifact: artifacts/falsifiers/gemma_main_family_policy_source_card/result.json
scope: metadata-only T1/L1 Gemma preferred-family policy witness
---

# F-GemmaMainFamilyPolicySourceCard

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as metadata-only T1/L1 architecture proof.

Command:

```bash
Tools/falsifiers/f_gemma_main_family_policy_source_card.sh
```

Artifact:

- path: `artifacts/falsifiers/gemma_main_family_policy_source_card/result.json`
- policy cards: `6`
- red fixtures rejected: `25`
- model bytes loaded: `0`
- runtime bytes loaded: `0`
- command executions: `0`
- next cursor: `gemma_qat_small_lane_owner_path_manifest`

## What It Proves

`F-GemmaMainFamilyPolicySourceCard` turns the Gemma 4 QAT "main model family"
ambition into a fail-closed policy packet:

- Gemma is the preferred Google local-model family strategy, not a hardcoded
  live default.
- Gemma 4 E2B/E4B QAT are the small warmup lanes.
- Gemma 4 12B QAT GGUF/LiteRT is the flagship Pro Gated target.
- Gemma 4 26B-A4B and 31B remain Pro Vault / ResearchCandidate.
- MLX Swift Gemma 4 remains blocked until loader parity is witnessed.
- GGUF and LiteRT lanes are policy candidates only until owner path, byte/KV
  envelope, first token, cancellation, quality replay, RunEventLog, and
  AnswerPacket proof exist.

The witness consumes the existing Gemma QAT candidate card, GGUF admission
packet, and LiteRT-LM admission card as upstream references. It opens no model
files and runs no runtime.

## What It Does Not Prove

This witness does not prove:

- Gemma is the live main app model.
- Gemma 4 12B QAT fits Jojo's current app memory envelope.
- GGUF, LiteRT-LM, or MLX is the winning runtime lane.
- Swift MLX can load Gemma 4.
- LiteRT-LM is MAS-safe or app-embedded.
- first token, quality, tool JSON, citation quality, coding quality, or
  user-facing WRV proof.
- live dense 70B, live sparse 70B, SSD-as-RAM, hidden cloud fallback, or hidden
  Eidos/PatternBoost/lattice route authority.

Correct phrasing: "Gemma preferred-family policy is L1 metadata-proofed;
Gemma is not yet the live main app model."

## Red Fixtures

The falsifier rejects:

- hardcoded or live default claims;
- product capability claims;
- MAS, L2, or L3 promotion;
- Swift MLX loader bypass;
- live dense 70B and SSD-as-RAM claims;
- hidden cloud fallback and hidden route authority;
- LiteRT sidecar laundering;
- Python MLX as Swift proof;
- missing owner path manifest;
- missing byte/KV/app envelope;
- missing redacted first-token probe;
- missing same-fixture or quality replay;
- missing settings visibility;
- missing AnswerPacket route explanation;
- missing abstention;
- model/runtime/provider bytes;
- command execution;
- duplicate model IDs;
- missing preferred-family policy invariant;
- metadata budget overflow.

## Next

The next Gemma side-ladder unit is
`F-GemmaQATSmallLaneOwnerPathManifest`, consuming this policy card and the
landed GGUF admission packet. The guard-owned product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
