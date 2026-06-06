---
falsifier: F-TurboVec-RealAdapterDependencyEnvelopeProbe
date: 2026-06-06
artifact: artifacts/falsifiers/turbovec_real_adapter_dependency_envelope_probe/result.json
scope: metadata-only / T1-L1
---

# F-TurboVec-RealAdapterDependencyEnvelopeProbe

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 primary witness.

- Command:
  `Tools/falsifiers/f_turbovec_real_adapter_dependency_envelope_probe.sh`
- Artifact:
  `artifacts/falsifiers/turbovec_real_adapter_dependency_envelope_probe/result.json`
- Pinned upstream: `https://github.com/RyanCodrai/turbovec`
- Pinned revision: `efe29a184986cbf562a9847c2ac52a2990bfaca2`
- Dependency-envelope address:
  `turbovec_real_adapter_dependency_envelope_probe:f59dcce8a5c6691d3cf9c132f99e80c44a42b85c784d9b49745d1d435d26d2f5@1779040900000`
- Manifest coverage: 8 SHA-bound manifests.
- Dependency coverage: 22 dependency/native-link/codegen records.
- Red fixtures rejected: 76.
- Next research-to-build unit:
  `turbovec_quarantine_real_adapter_sandbox_layout_probe`.

## What This Proves

The real TurboVec adapter branch now has an exact metadata dependency envelope
after the source-pin gate. It binds the root workspace Cargo manifest, Rust
core Cargo manifest, build script, Python Cargo manifest, Python pyproject,
Cargo config, Cargo.lock, downstream-smoke Cargo manifest, Rust core crates,
target-specific BLAS entries, native macOS Accelerate and Linux OpenBLAS link
boundaries, Python/maturin/numpy binding shape, optional Python integrations,
and x86_64-v3 codegen caveat.

## What It Does Not Prove

This does not fetch or clone TurboVec, import source, add a product dependency,
build/run an adapter, probe native links, open index bytes, load
Gemma/QAT/GGUF/MLX/LiteRT/model bytes, choose RuntimeRouter/System G routes,
advance L2 capability, or make L3 user-facing model capability green. It is
not a live 70B or large-local-model runtime proof.

## Architecture Consequence

TurboVec remains Eidos/AppColdStore rebuildable cache material, not durable
truth and not hidden route authority. The large-local-model path becomes more
buildable because any future sandbox must start from this exact dependency
envelope, preserve clean-room provenance, keep optional integrations denied by
default, and carry rollback, RunEventLog, AnswerPacket, compatibility fence,
and benchmark-caveat proof before real adapter bytes can be fetched or built.
