# ABI Audit

## Current state

- Rust FFI structs are `#[repr(C)]`
- header declarations exist in [graph_engine.h](/Users/jojo/Epistemos/graph-engine-bridge/graph_engine.h)
- Swift uses the header directly

## Strengths

- ring layout is exported explicitly
- row projection uses stable C structs instead of raw Rust enums
- archived payload itself is not treated as a stable C ABI surface

## Risks

- header is manually maintained
- no `cbindgen` pipeline exists
- no dedicated layout-compatibility test compares header expectations to Rust at build time

## Verdict

ABI is serviceable for staging. Drift risk remains non-trivial.
