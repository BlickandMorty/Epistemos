---
state: research-spec
created_on: 2026-05-12
scope: Two new graph-toolbar interactions (cursor force + shape bound)
verdict: AWAITING_USER_SIGNOFF_BEFORE_IMPLEMENTING
---

# Graph Toolbar — Cursor Force + Shape Bound Spec

User asked for two new graph toolbar buttons. This doc captures my
understanding of the spec + the architecture I'd ship, presented
for explicit sign-off before implementing.

## What I understood

### Button 1: Cursor force

While active, every node feels a force pulling it **toward** (suck)
or pushing it **away from** (repel) the live cursor position. Like
a magnetic field anchored to wherever your mouse is.

**Knobs the user wanted:**
- Direction: suck / repel toggle.
- Intensity: granular slider (probably ~0–1.0 strength multiplier).
- On/Off: implicit — toolbar button toggles whether the force
  applies at all.

### Button 2: Shape bound

While active, all nodes get pushed inward toward a geometric
formation: **circle**, **triangle**, **square** (and the user
mentioned "or more"). The bounding shape is invisible — only its
inward push is visible.

**Knobs the user wanted:**
- Shape: picker (circle / triangle / square / off; possibly
  hexagon / star later).
- Scale: slider for the shape's invisible-bounding radius.

## Where I'd put both buttons in the UI

`Epistemos/Views/Graph/GraphFloatingControls.swift` is the existing
toolbar pill at the bottom of the hologram overlay. Today's chips
in order: Physics toggle → Pixel/Fast → Forces popover → Reset
view → Rebuild graph → Close. The toolbar pill is glass-effect
+ capsule + fixed-size-horizontal.

I'd add two new chips between "Forces" and "Reset view" using the
existing `AnchoredPopoverButton` pattern (matches the Forces popover
shape — small button with a popover for the actual controls):

```
Physics · Pixel · Forces · 🧲 Cursor Force · 🔷 Shape Bound · Reset · Rebuild · Close
```

Both popovers open downward; each carries the relevant slider +
mode picker inside.

## Architecture sketch

### Swift side

Two new `@Observable` state fields on `GraphState`:

```swift
// Cursor force
enum CursorForceMode: String, CaseIterable, Sendable {
    case off
    case suck      // attract toward cursor
    case repel     // push away from cursor
}
var cursorForceMode: CursorForceMode = .off
var cursorForceStrength: Float = 0.5  // 0…1 multiplier

// Shape bound
enum ShapeBoundKind: String, CaseIterable, Sendable {
    case off
    case circle
    case triangle
    case square
}
var shapeBoundKind: ShapeBoundKind = .off
var shapeBoundRadius: Float = 800.0  // world units
```

Each pushes its values through to Rust via FFI when changed.
`MetalGraphView` already tracks the live cursor via the existing
`graph_engine_mouse_moved` call — that's the hook for the cursor
force.

### Rust side

Add two new FFI surfaces in `graph-engine/src/lib.rs`:

```rust
#[no_mangle]
pub extern "C" fn graph_engine_set_cursor_force(
    engine: *mut Engine,
    mode: u8,          // 0=off, 1=suck, 2=repel
    strength: f32,     // 0..1, multiplied into per-tick force
) { ... }

#[no_mangle]
pub extern "C" fn graph_engine_set_shape_bound(
    engine: *mut Engine,
    kind: u8,          // 0=off, 1=circle, 2=triangle, 3=square
    radius: f32,       // world units; inward push when outside
) { ... }
```

Then two new force kernels in `graph-engine/src/forces.rs` (or
`simulation.rs`):

**Cursor force kernel** — runs every physics tick when mode ≠ off.
The cursor's world-space position is already known (from
`graph_engine_mouse_moved`, which stores `sim.cursor_world`).
For each node: compute `dx = cursor_x - node_x`, apply force
`±strength * dx / max(dist², ε)` (inverse-square falloff to keep
nearby nodes from accelerating too violently). Sign flips for
repel.

**Shape bound kernel** — runs every physics tick when kind ≠ off.
For each node: compute its signed-distance to the shape boundary.
If outside (sdf > 0), apply an inward force proportional to the
overshoot. SDF for circle is trivial (`r − dist_from_center`),
square is `max(|x|, |y|) − r`, triangle uses the standard
equilateral SDF.

Both forces add to the existing per-tick force accumulator in
`simulation.rs::tick()` BEFORE damping, so they integrate
smoothly with charge / link / center / collision.

### Granular control surfaces

Inside each popover:

**Cursor Force popover:**
- Segmented control: Off · Suck · Repel
- Slider: Strength (0–1, default 0.5)
- Help text: "Hold the mouse anywhere over the graph; nodes will
  follow/flee."

**Shape Bound popover:**
- Segmented control: Off · ○ · △ · ▢
- Slider: Radius (100–3000 world units, default 800)
- Help text: "All nodes are gently pushed inside the shape."

## Risk assessment

- **UI work**: low — both follow the established `AnchoredPopoverButton`
  + `@Observable` GraphState pattern. The Forces popover is the
  pre-existing template.
- **FFI surface**: low — two new entry points, no existing FFI
  signatures change.
- **Physics work**: moderate — adding two new forces requires care
  that they integrate cleanly with the existing force budget (alpha
  decay, viewport scoping, GPU N-body dispatch). Both kernels are
  O(N) per tick; should be cheap.
- **State persistence**: each new GraphState field needs a
  UserDefaults key for cross-launch persistence. ~3 LOC each.
- **Tests**: I'd add Rust tests for the two new force kernels
  (boundary cases: cursor at origin / very-far cursor / shape
  radius 0 / shape radius huge) + a couple of Swift Codable tests
  for the new enum mirrors.

## Estimated effort

- 3-4 commits if split cleanly:
  1. Swift state + UI shells (toolbar buttons + popovers, no physics
     yet — just observable state).
  2. Rust force kernels + FFI entry points + tests.
  3. Swift FFI wiring + UserDefaults persistence.
  4. Optional: small refinement pass after live testing.

OR one large commit if you'd rather get it all at once and accept
the size.

## Open questions for you

1. **Do I have the spec right?** Particularly:
   - Cursor force is a HOLD-down (active while button is on,
     follows live cursor) vs CLICK-to-pulse (one-shot impulse at
     click point)? I assumed continuous-while-active.
   - Shape bound is a PERSISTENT inward force vs ONE-SHOT
     organize-then-release? I assumed persistent.

2. **Strength feel** — should the cursor force be strong enough to
   overwhelm equilibrium (so nodes really crowd the cursor) or
   subtle (gentle drift toward cursor)? I'd start with overwhelm
   and you can dial back.

3. **Shape picker UI** — I proposed a segmented Off/○/△/▢ control.
   Want a richer picker with names + icons? Or are you OK with the
   compact segmented form?

4. **Split into 3-4 commits or land all in one?** Splitting is
   safer; one-shot is faster.

5. **Shape options beyond circle/triangle/square** — you said "or
   more." Hexagon and 5-pointed star are easy SDFs. Other ideas?

When you reply with answers to these, I'll ship in the order you
prefer. No code changes until then.
