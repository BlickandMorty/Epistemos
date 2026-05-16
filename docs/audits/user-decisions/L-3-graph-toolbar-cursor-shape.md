---
item: L-3
created_on: 2026-05-16
scope: Graph toolbar Cursor Force and Shape Bound user decision
status: COMPLETE_RESEARCH_READY
---

# L-3 Graph Toolbar Cursor Force + Shape Bound User Decision

## Problem Statement

The original L-3 source doc is a research spec with `verdict: AWAITING_USER_SIGNOFF_BEFORE_IMPLEMENTING`. It asked the user to confirm two graph-toolbar interactions before code changed:

- Cursor Force: a continuous cursor-anchored force that pulls nodes toward the cursor or pushes them away.
- Shape Bound: a persistent invisible geometric boundary that pushes nodes inward.

Current main has moved past that gate. The graph toolbar now already includes Cursor and Shape popover buttons, `GraphState` stores and persists the overlay settings, `MetalGraphView` pushes them through FFI, and `graph-engine` has cursor-force and shape-bound kernels. The user decision is therefore no longer "should we implement this?" It is now whether to ratify the current implementation, trim it back to the original minimal spec, keep it experimental, or roll it back.

The current implementation also exceeds the original spec in two ways: Cursor Force includes a third `vortex` mode, and Shape Bound includes `hexagon` and `star` beyond the original circle/triangle/square set. Those additions need explicit product approval before the stale sign-off row can be considered resolved.

## Options

### Option A - Ratify the current expanded implementation and verify it

Approve the current code shape:

- Toolbar order: Physics, Pixel/Fast, Forces, Cursor, Shape, Reset, Rebuild, Close.
- Cursor modes: Off, Suck, Repel, Vortex.
- Cursor strength: continuous slider, with the UI disabling the slider when the mode is Off.
- Shape modes: Off, Circle, Square, Triangle, Hexagon, Star.
- Shape radius: continuous world-unit slider.
- Swift state persists through UserDefaults and pushes changes to Rust through `MetalGraphView`.
- Rust wakes the simulation when overlays become active and applies the kernels every physics tick.

Pros:

- Matches the feature the user asked for and keeps the already-landed implementation.
- Preserves the richer "or more" shape inventory as shipped UI instead of hiding work.
- Avoids churn across Swift UI, FFI, and Rust physics.
- Turns L-3 into a verification/ratification task instead of a rollback task.

Cons:

- The original sign-off was bypassed in history, so the user must now approve the expanded semantics retroactively.
- Vortex and star are beyond the original minimal research scope.
- Dedicated force-kernel tests were not found in the current source search; closure should require a focused test or manual verification pass.

### Option B - Keep only the original minimal spec

Keep the feature, but trim it to the original research shape:

- Cursor modes: Off, Suck, Repel only.
- Shape modes: Off, Circle, Triangle, Square only.
- Remove or hide Vortex, Hexagon, and Star.
- Keep the same toolbar placement, FFI surface, persistence keys, and basic kernel architecture where possible.

Pros:

- Aligns tightly with the sign-off doc.
- Reduces UI and physics review surface.
- Leaves richer modes for a future post-V1 polish slice.

Cons:

- Reworks code that already exists.
- Makes the product less expressive for little MAS-risk reduction.
- Still needs verification of the remaining kernels.

### Option C - Keep current code but mark it experimental until interactive QA

Keep the code path but gate the toolbar controls behind a debug preference, lab toggle, or explicit "experimental graph controls" flag until the user tries it interactively.

Pros:

- Preserves the work.
- Avoids committing visible V1 UI to untested interaction feel.
- Lets the user decide with a live graph instead of a paper spec.

Cons:

- Adds another settings/gating path.
- Increases state complexity.
- Does not resolve whether vortex, hexagon, and star are canonical product modes.

### Option D - Roll back to the sign-off-only state

Remove the current Cursor/Shape toolbar UI, Swift state, FFI calls, and Rust kernels, then return the item to the original AWAITING_USER_SIGNOFF state.

Pros:

- Restores strict process correctness.
- Removes unapproved feature surface from V1.

Cons:

- Destroys already-landed implementation work.
- Leaves a user-requested graph interaction unserved.
- Requires a multi-file rollback across Swift UI, GraphState persistence, FFI, and graph-engine simulation.

## Canonical Sources

- `docs/audits/GRAPH_TOOLBAR_CURSOR_FORCE_SHAPE_BOUND_SPEC_2026_05_12.md:1` through `:5` records the source as `research-spec` and `AWAITING_USER_SIGNOFF_BEFORE_IMPLEMENTING`.
- `docs/audits/GRAPH_TOOLBAR_CURSOR_FORCE_SHAPE_BOUND_SPEC_2026_05_12.md:16` through `:38` defines the requested Cursor Force and Shape Bound behavior.
- `docs/audits/GRAPH_TOOLBAR_CURSOR_FORCE_SHAPE_BOUND_SPEC_2026_05_12.md:40` through `:57` places both buttons between Forces and Reset using `AnchoredPopoverButton`.
- `docs/audits/GRAPH_TOOLBAR_CURSOR_FORCE_SHAPE_BOUND_SPEC_2026_05_12.md:178` through `:203` lists unresolved user questions: continuous versus pulse, persistent versus one-shot, strength feel, compact picker versus richer picker, commit split, and "or more" shapes.
- `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md:928` still records Wave H6 as awaiting user sign-off and says no implementation until the user signs off.
- `Epistemos/Views/Graph/GraphFloatingControls.swift:19` through `:35` already wires `showCursorForce`, `showShapeBound`, and the Cursor/Shape buttons into the toolbar between Forces and Reset.
- `Epistemos/Views/Graph/GraphFloatingControls.swift:125` through `:255` implements the two popover panels, mode pickers, and sliders.
- `Epistemos/Graph/GraphState.swift:82` through `:179` defines `CursorForceMode` and `ShapeBoundKind`, including Vortex, Hexagon, and Star.
- `Epistemos/Graph/GraphState.swift:1468` through `:1513` stores overlay state and writes UserDefaults keys.
- `Epistemos/Graph/GraphState.swift:1634` through `:1656` restores overlay settings on launch.
- `Epistemos/Graph/GraphState.swift:2026` through `:2030` resets both overlays to Off/default values in the canonical physics reset path.
- `Epistemos/Views/Graph/MetalGraphView.swift:1311` through `:1327` pushes overlay settings to Rust through `graph_engine_set_cursor_force` and `graph_engine_set_shape_bound`.
- `Epistemos/Views/Graph/MetalGraphView.swift:1618` through `:1623` watches `userForceOverlayVersion` and re-pushes the settings in the render loop.
- `graph-engine/src/lib.rs:1468` through `:1515` exposes the two FFI entry points and documents the accepted mode/kind values.
- `graph-engine/src/engine.rs:1961` through `:1992` stores the overlay values and wakes the simulation when active.
- `graph-engine/src/simulation.rs:295` through `:517` contains the cursor-force and shape-bound kernels.
- `graph-engine/src/simulation.rs:1317` through `:1329` holds alpha above a visible floor while a user-directed overlay is active.
- `graph-engine/src/simulation.rs:1483` through `:1515` applies both kernels during physics tick processing.

Current verification gap:

- Static source search found the implementation, but no dedicated `cursor_force` / `shape_bound` test names in `graph-engine/tests` or `EpistemosTests`. If Option A is chosen, closure should add or run focused verification before calling L-3 fully done.

## Code Impact Estimate

### Option A impact

Estimated code change: small to moderate, depending on verification appetite.

- Required product code: likely none.
- Required docs: update stale sign-off wording after user approval.
- Required verification: focused Rust tests for `apply_cursor_force`, shape SDF outside/inside cases, FFI value clamping, and a Swift enum/persistence or UI smoke check.
- Optional manual QA: open graph overlay, enable Suck/Repel/Vortex, switch each shape, adjust radius and strength, Reset to defaults, relaunch and confirm persistence.

Risk:

- Low product-code risk if no code changes are made.
- Moderate verification risk because force feel is visual and may need human interaction.

### Option B impact

Estimated code change: moderate.

- Remove or hide `CursorForceMode.vortex`.
- Remove or hide `ShapeBoundKind.hexagon` and `.star`.
- Update FFI docs and possibly Rust mode handling.
- Update localized strings if any removed labels are user-visible.
- Add tests for the remaining modes.

Risk:

- Moderate regression risk across persistence because saved UserDefaults may already contain removed raw values.
- Requires migration behavior for users with saved Vortex/Hexagon/Star settings.

### Option C impact

Estimated code change: moderate.

- Add a debug/lab/experimental gate.
- Hide the toolbar buttons until enabled.
- Decide whether persisted settings apply while hidden.
- Add UI tests or manual QA for both gated and enabled states.

Risk:

- Adds product ambiguity and another state path.

### Option D impact

Estimated code change: large rollback.

- Remove toolbar state and panels.
- Remove GraphState overlay fields and persistence.
- Remove MetalGraphView FFI push.
- Remove Rust FFI entry points and kernels.
- Clean localization entries and stale docs.

Risk:

- High churn for a user-requested interaction that already works structurally.

## Recommendation

Recommend **Option A: ratify the current expanded implementation and verify it**.

Recommended decision record:

> L-3 is no longer a pre-implementation sign-off item. Current main already implements Cursor Force and Shape Bound across Swift UI, GraphState persistence, FFI, and graph-engine simulation. Ratify the current expanded mode inventory: Suck, Repel, Vortex for Cursor Force, and Circle, Square, Triangle, Hexagon, Star for Shape Bound. Before calling L-3 fully closed, add or run focused verification for the Rust kernels, FFI clamping, Swift persistence, Reset-to-defaults behavior, and an interactive graph overlay smoke test.

Reasoning:

- The current implementation satisfies the original button placement and continuous/persistent interpretation.
- The expanded modes are coherent with the source doc's "or more" shape prompt.
- Rolling back or trimming now creates more risk than it removes.
- The real gap is verification and explicit user ratification of the expanded shape/mode inventory.

## Acceptance Criteria

If the user chooses **Option A**:

- Keep the Cursor and Shape toolbar buttons between Forces and Reset.
- Keep continuous Cursor Force semantics anchored to the live cursor.
- Keep persistent Shape Bound semantics centered on the graph origin.
- Keep Vortex, Hexagon, and Star as approved product modes.
- Keep UserDefaults persistence for mode/strength/kind/radius.
- Keep Reset-to-defaults clearing both overlays.
- Verify FFI value mapping and clamping for cursor mode, cursor strength, shape kind, and radius.
- Add or run focused Rust verification for inside/outside shape behavior and Suck/Repel/Vortex vector direction.
- Add or run a Swift persistence/UI smoke check for the toolbar controls.
- Update stale `AWAITING_USER_SIGNOFF_BEFORE_IMPLEMENTING` doctrine language after ratification.

If the user chooses **Option B**:

- Hide or remove Vortex, Hexagon, and Star.
- Define migration behavior for saved removed values.
- Verify the reduced mode inventory across Swift and Rust.

If the user chooses **Option C**:

- Add one explicit gate for experimental graph controls.
- Make the hidden/enabled states predictable across relaunch.
- Keep L-3 open until interactive QA approves the feel.

If the user chooses **Option D**:

- Roll back the existing implementation as an explicit revert-style change.
- Restore the old no-implementation-before-signoff state.
- Leave L-3 open until a new implementation decision is made.

## Decision-Ready Prompt

Choose the L-3 Graph Toolbar Cursor Force + Shape Bound path:

1. **Recommended:** Ratify the current expanded implementation, including Vortex, Hexagon, and Star, then run focused verification before closing L-3.
2. Keep the feature but trim it to the original minimal inventory: Suck/Repel plus Circle/Triangle/Square.
3. Keep current code but hide it behind an experimental/debug gate until interactive QA.
4. Roll back the implementation and return to the original sign-off-only state.
