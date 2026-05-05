//! Canonical Hermes-in-Rust runtime spine.
//!
//! Stage B.1 starts here: the Swift Hermes mirrors collapse toward this
//! module one surface at a time. Prompt formatting and function-call parsing
//! are implemented first because they are deterministic and isolated. Skills,
//! procedural memory, and self-evolution keep explicit module boundaries so
//! follow-up slices can collapse the existing parallel surfaces without
//! smuggling new behavior into this first patch.

pub mod function_call;
pub mod procedural_memory;
pub mod prompt_format;
pub mod self_evolution;
pub mod skills;
