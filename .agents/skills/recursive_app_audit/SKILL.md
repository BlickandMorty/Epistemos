---
name: Recursive App Audit
description: A deeply nuanced, recursive testing and auditing methodology for the entire application. It autonomously runs tests, performs manual checks, analyzes nuances, and repeatedly refines logic until achieving 3 successive perfect passes with zero fails and zero errors.
---

# Recursive App Audit Skill

**Purpose:** Building a complex native application requires absolute stability across multiple layers (e.g., Rust core, Swift native UI, Metal renderer). A single test pass is insufficient because fixing a bug in one layer often creates a regression in another. 

This skill provides the AI with "leg room to think," instructing you on how to recursively run the test suites, perform deep logical audits, and iterate on fixes until reaching a truly stabilized, zero-fail, zero-error state across three successive passes.

## The Tri-Phase Recursive Loop

When the USER invokes this skill or asks you to "run the recursive app audit", you MUST strictly follow this procedural loop:

### Phase 1: Comprehensive Test Execution
You must run the tests for the application stack:
1. Run Rust tests (e.g., `cargo test` in the relevant directories).
2. Run any other available test suites (e.g., Swift/XCTest if accessible via CLI, or frontend tests).
3. Check for compiler warnings and address them. 
4. If tests pass, do not stop. Moving past assertions is required for true stability.

### Phase 2: The Nuanced Audit (The "Thinking Process")
Passing basic tests is the bare minimum. You must analyze the code logically and perform manual verifications:
- **Architectural Integrity:** Read active code files to ensure design patterns (e.g., concurrent actors, memory safety, state management) are strictly adhered to.
- **Edge Cases and Race Conditions:** Actively search for potential deadlocks, unbounded memory growth, and unhandled `Result/Option` unwrap panics.
- **Side Effects:** Verify that recent fixes haven't introduced unintended side-effects in connected components.
- **Silent Errors:** Check logs, terminal outputs, and error boundaries for hidden warnings or anomalies that tests might miss.

You have full autonomy to think deeply. Use your intelligence to spot what automated tests miss. Ask "What if?" and verify the code's resilience.

### Phase 3: The Refinement Loop
If *any* test fails, or if your nuanced audit reveals a sub-optimal pattern, brittleness, or logical flaw:
1. Stop the current pass.
2. Formulate a fix: Use your tools to correct the code.
3. Document the "Why": Keep track of the root cause and why the fix resolves it.
4. **Reset the Pass Counter to `0`.**
5. Restart from Phase 1.

### Phase 4: The 3-Pass Zero-Fail Rule
You must achieve **three successful, uninterrupted passes** of Phase 1 AND Phase 2 without modifying ANY code between the passes. 

- **Pass 1 (Verification):** Code compiles strictly, tests pass, and your manual audit finds zero structural issues.
- **Pass 2 (Confirmation):** Re-running all checks confirms determinism. Flaky tests, race conditions, or non-deterministic behaviors are caught here.
- **Pass 3 (Solidification):** The absolute proof of stability. No errors, no warnings, no logical flaws. The system is hardened.

## Success Condition
Once you have achieved 3 consecutive zero-fail, zero-error passes:
1. Break the loop.
2. Use the `notify_user` tool to inform the USER. 
3. Provide a detailed, highly readable markdown summary explaining:
   - The test commands executed.
   - The deep logical audits performed (your exact "thinking process").
   - Any bugs caught and fixed during the refinement loops.
   - The confirmation of the 3-time zero fail state.
