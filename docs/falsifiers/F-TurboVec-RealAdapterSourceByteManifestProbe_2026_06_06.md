---
falsifier: F-TurboVec-RealAdapterSourceByteManifestProbe
date: 2026-06-06
artifact: artifacts/falsifiers/turbovec_real_adapter_source_byte_manifest_probe/result.json
scope: metadata-only / T1-L1
---

# F-TurboVec-RealAdapterSourceByteManifestProbe

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 primary witness.

- Command:
  `Tools/falsifiers/f_turbovec_real_adapter_source_byte_manifest_probe.sh`
- Artifact:
  `artifacts/falsifiers/turbovec_real_adapter_source_byte_manifest_probe/result.json`
- Pinned upstream: `https://github.com/RyanCodrai/turbovec`
- Pinned revision: `efe29a184986cbf562a9847c2ac52a2990bfaca2`
- Source-byte-manifest address:
  `turbovec_real_adapter_source_byte_manifest_probe:44bd136396f6a19cc12f01ec82ef57968c5826e7cae6ac30116eef5e724328ba@1779040902000`
- Required manifest rows: 22.
- Root buckets: 15.
- Upstream Git tree entries: 207.
- Upstream Git blobs: 180.
- Declared upstream blob bytes: `1615603`.
- Red fixtures rejected: 100.
- Former next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterSourceInspectionPolicyProbe`:
  `turbovec_quarantine_real_adapter_source_inspection_policy_probe`.
- Former next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterMotifExtractionCardProbe`:
  `turbovec_quarantine_real_adapter_motif_extraction_card_probe`.
- Current next research-to-build unit:
  `turbovec_quarantine_real_adapter_clean_room_adapter_plan_probe`.

## What This Proves

The pinned TurboVec branch now has a metadata-only source-byte manifest after
the fetch-lease gate. The manifest binds current GitHub tree metadata for the
pinned revision: file paths, modes, Git blob SHAs, aggregate tree/blob counts,
root bucket counts, and selected critical source, test, build, benchmark, docs,
symlink, and binary-asset rows.

The witness rejects source tree count drift, blob count drift, byte total drift,
missing critical rows, missing root buckets, bad blob SHAs, unsafe paths,
product roots, symlink laundering, binary-asset import, benchmark-authority
laundering, source inspection shortcuts, native-link shortcuts, product graph
or dependency insertion, raw source reads, codeload/archive fetches, quarantine
file writes, runtime/model/index/provider bytes, hidden route/context/cloud
authority, MAS/Live/T2+ promotion, live dense 70B claims, and SSD-as-RAM
claims.

## What It Does Not Prove

This does not clone TurboVec, open the codeload archive, write quarantine source
files, inspect source content, import product source, add dependencies, build an
adapter, probe native links, open index bytes, load Gemma/QAT/GGUF/MLX/LiteRT/
model bytes, choose RuntimeRouter/System G routes, advance L2 capability, or
make L3 user-facing model capability green. It is not live 70B, live sparse
70B, or product runtime proof.

## Architecture Consequence

TurboVec remains Eidos/AppColdStore rebuildable cache material and quarantine
research. The large-local-model path becomes more buildable because source
inspection and adapter rewrite work now has to pass a manifest-bound policy:
critical paths and risky rows are known, binary/symlink/benchmark/native-link
surfaces are blocked, and no product graph or route can cite source bytes until
the next source-inspection policy witness proves exactly what may be read and
how clean-room notes, rollback, RunEventLog, and AnswerPacket proof will hold.
