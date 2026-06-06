---
falsifier: F-TurboVec-RealAdapterOwnerApprovalProbe
date: 2026-06-06
artifact: artifacts/falsifiers/turbovec_real_adapter_owner_approval_probe/result.json
scope: metadata-only T1/L1 real-adapter source/provenance owner gate
status: PASS
---

# F-TurboVec-RealAdapterOwnerApprovalProbe

Epistemos is a local cognitive substrate where every meaningful object has an
address, plane, budget, status, and witness; MAS ships the safe floor, Pro
contains the gated/research/vault/omega ladder, and no claim promotes without
visible proof.

## Result

PASS as a metadata-only T1/L1 source/provenance owner gate.

- Command: `Tools/falsifiers/f_turbovec_real_adapter_owner_approval_probe.sh`
- Artifact:
  `artifacts/falsifiers/turbovec_real_adapter_owner_approval_probe/result.json`
- Upstream:
  `F-TurboVec-QuarantineAdapterMicrobenchProbe`
- Next research-to-build unit:
  `turbovec_quarantine_real_adapter_source_pin_probe`

## What Passed

- 1 upstream real-adapter source card:
  `https://github.com/RyanCodrai/turbovec`
- Owner approval remains pending.
- Source pin remains pending.
- Fork sweep is required before source pinning.
- Allowed action is quarantine reference only.
- Clean-room provenance, dependency manifest, upstream-benchmark caveat,
  rollback, RunEventLog, AnswerPacket, and compatibility fence refs are
  required.
- 45 red fixtures reject bad source URL, bad owner/repo, bad license, missing
  Rust/Python/API refs, premature approval, premature source pinning, direct
  import, adapter wrap, product integration, missing quarantine path, missing
  provenance, benchmark laundering, fetched/cloned bytes, external crate
  import, product file copy, built binary, product index, model/provider bytes,
  route/context mutation, hidden authority, MAS/Live/T2+ promotion, live dense
  70B, and SSD-as-RAM.

## What This Does Not Prove

This does not clone TurboVec, inspect fork code, pin a source revision, import
an external crate, add a dependency, build or run an adapter, open product
index bytes, load Gemma/QAT/GGUF/MLX/LiteRT/model bytes, choose routes, advance
L2, or make L3 user-facing model capability green.

Correct phrasing:

> Real-adapter owner gate advanced; product capability and user surface did
> not.

## Large-Model Relevance

This is the first gate that points at a real external TurboVec source while
still preserving Epistemos' privacy/stability boundary. It makes future
large-model context selection more practical by forcing compressed retrieval
adapters through owner approval, source pinning, fork sweep, quarantine,
clean-room provenance, rollback, RunEventLog, and AnswerPacket before any
actual bytes are allowed near Eidos/AppColdStore or System G.

## Next

The next unit is `turbovec_quarantine_real_adapter_source_pin_probe`.
That unit must pin a source revision and fork-sweep policy without importing,
building, or running external adapter bytes unless the owner explicitly
approves the quarantine step.
