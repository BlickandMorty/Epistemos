---
falsifier: F-CompressedRoute-AnswerPacket-DryRun
created_on: 2026-06-06
hardware_floor: M2 Pro 16 GB UMA
status: PASS - PRIMARY WITNESS
artifact: artifacts/falsifiers/compressed_route_answer_packet_dry_run/result.json
---

# F-CompressedRoute-AnswerPacket-DryRun

## Purpose

This is the executable metadata-only witness that turns
`F-QAT-ModelRouteCard-MemoryPreflight` route preflights into visible compressed
route AnswerPacket dry-run packets before any small compressed model runtime
harness can cite them.

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Command

```bash
Tools/falsifiers/f_compressed_route_answer_packet_dry_run.sh
```

## Artifact

- `artifact_kind`: `primary_witness`
- `fallback_tier`: `Primary`
- path: `artifacts/falsifiers/compressed_route_answer_packet_dry_run/result.json`
- scope: metadata-only; `model_bytes_loaded=0`, `runtime_bytes_loaded=0`,
  and `provider_calls_made=0`

The artifact passes with 4 accepted compressed-route packets and 48
red-fixture rejections. E2B and E4B Gemma 4 QAT GGUF candidates become visible
dry-run AnswerPackets only. The 12B candidate is carried as a visible
abstention packet for insufficient 16 GB UMA headroom. The 31B candidate is
carried as a VaultPreserved packet. The witness records planned model bytes,
planned KV bytes, planned scratch bytes, planned route bytes, fallback
reserved bytes, opened bytes, resident bytes, loaded bytes, provider calls,
route caveats, fallback, rollback, cancellation, compatibility fence,
RunEventLog, and AnswerPacket refs.

## Hard Rejections

The witness rejects duplicate packet IDs, duplicate model/runtime lanes, bad
upstream preflight refs, bad AnswerPacket refs, bad visible-summary refs,
missing rejected candidates, short visible summaries, zero declared bytes,
file-size-as-memory route planning, zero KV bytes, invalid planned route bytes,
opened model/runtime bytes, resident model/runtime bytes, observed RSS claims,
model/runtime byte loads, provider calls, missing fallback, missing rollback,
missing cancellation, missing route caveat, missing selected-model visibility,
hidden byte ledger, suppressed AnswerPacket, route-policy mutation,
first-token claims, quality claims, runtime-parity claims, MAS readiness,
MAS product build, Pro Live status, T2+ promotion, hidden cloud fallback,
hidden route authority, hidden chain exposure, live dense 70B claims,
SSD-as-RAM claims, 12B dry-run packetization, 31B non-vault packetization,
missing abstention reason, missing vault ref, packet metadata overflow, set
metadata overflow, missing L1/L2/L3 separation, undeferred runtime, and
unblocked product promotion.

## Non-Promotion Rule

This falsifier does not run MLX, GGUF, LiteRT, Transformers, llama.cpp, or
custom Metal; does not load Gemma QAT weights; does not prove first token,
quality, tool use, runtime parity, Swift MLX support, MAS readiness, L2
capability, L3 user-facing behavior, live dense 70B, or live sparse 70B. It
advances T1/L1 metadata architecture only. L2 capability and L3 product
runtime remain unchanged.

## Queue Effect

`F-CompressedRoute-AnswerPacket-DryRun` gives the model ladder visible,
cancellable, reversible, byte-accounted AnswerPacket dry-run packets for later
`F-SmallCompressedModel-LiveHarness` work. The guard-owned product cursor
remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
