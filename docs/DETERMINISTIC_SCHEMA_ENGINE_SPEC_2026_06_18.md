# Deterministic Schema Engine + Local-Model Excellence — BUILD SPEC (owner 2026-06-18)

This is the FOUNDING THESIS made concrete (local AI useful via dynamic determinism
+ verifiability, NOT model size). It is the CHAT-MODE core and must NOT be buried.
RESEARCH-FIRST: before building, find + read the owner's EXISTING local research +
prior plans on deterministic schemas, and the existing grammar/json-schema work
(Epistemos/LocalAgent/LocalToolGrammar.swift, the `with_json_schema` FFI /
run_local_gguf_generation, P4.3, agent_core tool-call parsing). Build ON those —
do not greenfield. Honest: real schemas + real validation only, no fake gate.

## A. Dynamic Deterministic Schema Engine (Rust core, "universal knowledge core")
- Rust backend parses file types + codebase ASTs + tool payloads into type-safe,
  deterministic JSON schemas. Type-safe serialization bridge between polymorphic
  sources (Swift / Rust / Python / C) and standard JSON.
- VALIDATION SEQUENCE: a local tool's output is validated against the deterministic
  schema via an AST quality gate BEFORE any disk write or compile loop runs. The
  model targets an immutable typed schema — never guesses a regex / vague output.
- UniFFI boundary: schemas stream Rust→Swift as async event payloads, never
  blocking the main SwiftUI render thread.

## B. Local model tool-calling optimization (Gemma 4 + Coder Adapter)
- RAG PREFLIGHT TOOL SELECTION (Rust): instead of dumping the whole tool suite into
  Gemma 4's context, evaluate the prompt against local vector embeddings and load
  ONLY the necessary tools for that turn. Keep the active tool footprint tight
  (~3–5 definitions) to preserve local-model focus and avoid logic loops.
- Structured-generation constraints + prompt template that force the Coder Adapter
  to emit valid JSON matching the deterministic schemas (near-100% tool-call
  fidelity on Apple Silicon).
- Reasoning-token handling: isolate Gemma 4's native thinking tokens for UI tracing
  while cleanly extracting the tool arguments for execution (preserve thinking
  blocks per the honesty constraint; don't strip).

## C. Expected deliverables (the loop should produce these, build-verified)
1. SYSTEMS BLUEPRINT: trace a request SwiftUI View → RAG Preflight Filter → local
   Gemma 4 → structured tool output → deterministic schema validation gate → Rust
   executor.
2. RUST CORE CONTRACTS: concrete idiomatic Rust structs/enums for the Schema
   Validator + Tool Router interface.
3. SWIFTUI INTEGRATION: Swift actor/coordinator that ingests the local execution
   stream with no race conditions / no dropped UI frames (inference off @MainActor).
4. IMPLEMENTATION CHECKLIST: phased roadmap, stability + deterministic execution
   FIRST. Concrete systems work, no hand-waving.

## D. Where it lives
- This is CHAT MODE's brain (and powers Act/Work's local tool loops too). Surface
  the determinism/verifiability ("why this route", schema-gated tool calls,
  validation results) visibly — it's the app's edge, not hidden plumbing.
- Ties to PRIORITY 5 / R-ARCH (substrate + Knowledge Core) and the NORTH STAR.
