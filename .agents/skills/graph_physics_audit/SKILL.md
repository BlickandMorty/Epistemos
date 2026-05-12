---
name: Recursive Physics Audit
description: A nuanced, recursive testing methodology for graph-engine physics parameters that runs tests, analyzes nuances, and repeatedly refines logic until achieving 3 successive perfect passes.
---

# Recursive Physics Audit Skill

**Purpose:** The Epistemos graph-engine is an N-body simulation where small parameter tweaks (like `alpha`, `velocity_decay`, or `charge_range`) have cascading, non-linear effects. A single test pass is often insufficient because fixing one bug (e.g. explosive entrances) might inadvertently cause another (e.g. frozen center).

This skill instructs Claude on exactly how to recursively run the Rust unit tests and audit the physics logic until achieving a mathematically proven, stable state across three successive, unmodified passes.

## The Testing Process

When the USER invokes this skill or asks you to "run the recursive audit," you MUST strictly follow this procedural loop:

### Phase 1: The Baseline Pass
1. Run `cargo test --manifest-path /Users/jojo/Epistemos/graph-engine/Cargo.toml` using the `action.bash` tool.
2. If tests pass, do not stop. You must verify that the simulation logic holds up to nuanced edge cases.

### Phase 2: The Nuanced Audit (The "Thinking Process")
Physics behavior cannot be fully validated by passing assertions alone. You must read the test source code (e.g. `physics_audit_test.rs`) and the active defaults in `simulation.rs`. Evaluate the following nuanced behaviors:
- **Blast vs Coast:** Are `center_strength` and `charge_range` balanced? If `center_strength` > 0.0, will unconnected/orphan nodes be pulled back, or will they overshoot the center and perpetually oscillate?
- **The Pinned Velocity Bug:** Does clamping `fx/fy` zero out velocity without accumulating hidden momentum?
- **Explosive Entanglements:** Is the initial spiral spacing wide enough that the repulsive `charge_strength` doesn't blow the graph apart on tick 1?
- **Cooling Limits:** Does `alpha_decay` allow the simulation to settle quickly enough (e.g. within 300 ticks) so it doesn't waste CPU?

### Phase 3: The Refinement Loop
If *any* tests fail, or if your nuanced audit reveals a numerical instability (even if tests pass but are brittle):
1. Use `replace_file_content` or `multi_replace_file_content` to fix the math in `simulation.rs`, `forces.rs`, or the tests themselves.
2. Increment your "Pass Counter" back to `0`.
3. Restart Phase 1.

### Phase 4: The 3-Pass Rule
You must achieve **three successful, uninterrupted passes** of the test suite and your nuanced audit without modifying ANY code between the passes. 

Why 3 passes?
- **Pass 1:** Verifies the code compiles and assertions are met.
- **Pass 2:** Verifies the tests are deterministic (N-body simulations can sometimes suffer from floating-point non-determinism or hash-map-iteration randomness).
- **Pass 3:** Solidifies the stability and signals that the parameters are truly locked in.

## Success Condition
Once you have completed 3 successful passes (Pass 1 ✓, Pass 2 ✓, Pass 3 ✓), use the `notify_user` tool to inform the USER. Provide a beautifully formatted GitHub-style markdown summary of standard test results, the specific math parameters that were stabilized, and the nuanced "thinking" process that led to the final balance.
