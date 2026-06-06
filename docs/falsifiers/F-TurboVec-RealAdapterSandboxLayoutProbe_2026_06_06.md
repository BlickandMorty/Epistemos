---
falsifier: F-TurboVec-RealAdapterSandboxLayoutProbe
date: 2026-06-06
artifact: artifacts/falsifiers/turbovec_real_adapter_sandbox_layout_probe/result.json
scope: metadata-only / T1-L1
---

# F-TurboVec-RealAdapterSandboxLayoutProbe

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 primary witness.

- Command:
  `Tools/falsifiers/f_turbovec_real_adapter_sandbox_layout_probe.sh`
- Artifact:
  `artifacts/falsifiers/turbovec_real_adapter_sandbox_layout_probe/result.json`
- Pinned upstream: `https://github.com/RyanCodrai/turbovec`
- Pinned revision: `efe29a184986cbf562a9847c2ac52a2990bfaca2`
- Sandbox-layout address:
  `turbovec_real_adapter_sandbox_layout_probe:ade4603f6f4bd86da82abff1e5332957033d0e1b1d00142924736a12b68fd69f@1779040900000`
- Layout slots: 10.
- Red fixtures rejected: 84.
- Planned quarantine byte lease: `8388608` bytes.
- Former next research-to-build unit:
  `turbovec_quarantine_real_adapter_fetch_lease_probe` (now landed by
  `F-TurboVec-RealAdapterFetchLeaseProbe`; current next side-ladder unit is
  `turbovec_quarantine_real_adapter_source_byte_manifest_probe`).

## What This Proves

The real TurboVec adapter branch now has a quarantine sandbox layout after the
source-pin and dependency-envelope gates. Future research bytes, if explicitly
leased later, must remain under
`.epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2`
and in typed read-only slots for source snapshots, fork sweeps, manifest
snapshots, extracted API notes, extracted test specs, benchmark transcripts,
failure reports, clean-room rewrite notes, native-link notes, and cleanup
tombstones.

The witness rejects product roots, build graph membership, runtime route
membership, absolute paths, traversal paths, duplicate slot IDs, duplicate slot
paths, writable slots, symlinks, executable slots, nonmetadata actions, missing
cleanup phases, missing rollback/log/AnswerPacket refs, native-link shortcuts,
benchmark laundering, byte loads, hidden authority, hidden cloud fallback,
MAS/product promotion, live dense 70B claims, and SSD-as-RAM claims.

## What It Does Not Prove

This does not fetch or clone TurboVec, copy product source, add a product
dependency, import/build/run an adapter, probe native links, open index bytes,
load Gemma/QAT/GGUF/MLX/LiteRT/model bytes, choose RuntimeRouter/System G
routes, advance L2 capability, or make L3 user-facing model capability green.
It is not live 70B, live sparse 70B, or product runtime proof.

## Architecture Consequence

TurboVec remains Eidos/AppColdStore rebuildable cache material and
quarantine-reference research. The large-local-model path becomes more
buildable because Epistemos can now study risky or no-license adapter repos for
APIs, tests, benchmark shapes, failure cases, dependency behavior, and
clean-room motifs without contaminating product code or granting hidden route
authority. The next step must be a fetch/lease witness, not a product import.
That fetch/lease witness is now landed; the next safe step is a source-byte
manifest witness, still not a product import.
