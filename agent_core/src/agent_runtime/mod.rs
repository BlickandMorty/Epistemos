//! In-process agent runtime — owns prompt formatting, function-call parsing,
//! skills, procedural memory, and self-evolution.
//!
//! Module renamed from `hermes` → `agent_runtime` on 2026-05-05 when the
//! Python `hermes-agent` subprocess was removed. The submodule names
//! (`prompt_format`, `function_call`, `skills`, `procedural_memory`,
//! `self_evolution`) intentionally describe what they do rather than which
//! subprocess they used to coordinate with. The Hermes-3 model's prompt
//! grammar (`<tools>`, `<tool_call>`, `<think>`) is still produced by
//! `prompt_format` because the local model speaks that format — this is a
//! Nous Research model spec, not the removed subprocess.
//!
//! See `docs/_archive/hermes-removal-2026-05-05/README.md` for the full
//! removal record.

pub mod function_call;
pub mod procedural_memory;
pub mod prompt_format;
pub mod self_evolution;
pub mod skills;
