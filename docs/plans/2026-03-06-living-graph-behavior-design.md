# Living Graph Behavior — Design Document

> Approved design. Nodes behave like fish in an aquarium — drifting, breathing, trailing parents, reacting to the cursor.

## Summary

Add autonomous behavior to graph nodes so the settled graph feels alive. A single new force function (`force_behavior`) plugs into the existing physics loop as force #9. It reads the existing `AIComponent` on each ECS entity and injects small velocity impulses per tick. No new threads, no new render code, no new FFI. Nodes just move differently because the forces tell them to.

**Feel:** Aquarium / fish tank. Slow, meditative. Child nodes trail parents like jellyfish tentacles. Archetype personality drives movement style. Nodes notice the cursor — lean in with curiosity, drift away if it moves fast.

---

## Architecture

```
simulation.tick():
  1. alpha decay
  2. settled check  ← behavior bypasses this (stays warm)
  3. force_link
  4. force_many_body
  5. force_collide
  6. force_center
  7. force_cluster
  8. force_semantic
  9. force_behavior()  ← NEW: wander + breathe + tether + cursor
  10. force_wind / force_orbital
  11. velocity integration
```

**Key difference from other forces:** `force_behavior()` stays active at alpha floor. All other forces go dormant when the graph settles. Behavior keeps running via a separate `behavior_alpha` that never drops below a warm floor (0.15), so the aquarium stays alive even when layout is done converging.

**Where behavior plugs in:**
- `simulation.rs` — new `behavior_alpha` field + call to `force_behavior()`
- `ecs/components.rs` — extend `AIComponent` with new fields
- `ecs/systems.rs` — new `system_behavior_tick()` for FSM transitions
- `forces.rs` — new `force_behavior()` function

**What does NOT change:**
- All 8 existing force functions — untouched
- Renderer — untouched (breathe scale modulates existing per-instance data)
- Swift code — untouched (cursor position already flows via `graph_engine_mouse_moved`)
- FFI boundary — no new functions for v1
- Dialogue system — untouched
- `ForceParams` — no new user-facing physics sliders for v1

---

## Behavior State Machine

Each node runs a lightweight FSM via `AIComponent::state`. Six states with soft transitions (speed/amplitude interpolate over 0.3-0.5s).

```
                    ┌──────────────┐
                    │   Sleeping   │◄── care health < 0.2
                    └──────┬───────┘
                           │ health recovers
                           ▼
┌─────────┐  settled  ┌─────────┐  cursor near  ┌──────────────────┐
│  Idle   │─────────►│Swimming │─────────────►│ AvoidingCursor   │
│(startup)│          │(default)│◄─────────────│ (or Curious first)│
└─────────┘          └────┬────┘  cursor gone  └──────────────────┘
                          │
                    has parent?
                          │ yes
                          ▼
                   ┌──────────────┐
                   │TrailingParent│  (damped tether to parent)
                   └──────────────┘
                          │
                    node clicked / dialogue opened
                          │
                          ▼
                    ┌──────────┐
                    │ Excited  │  (energy burst, wider wander, then calm)
                    └──────────┘
```

**State logic:**
- **Idle:** Startup only. Transitions to Swimming after first physics settle.
- **Swimming:** Default. Gentle Perlin wander + sinusoidal breathe. The aquarium feel.
- **TrailingParent:** Active when node has a parent in hierarchy. Damped tether pulls toward parent. Still breathes and wanders slightly around the tether point.
- **AvoidingCursor:** Cursor within ~120px. First 0.3s: tiny attractive force toward cursor (curiosity). Then: soft repulsion if cursor moves fast. Returns to Swimming when cursor leaves.
- **Excited:** Triggered by click/dialogue. 2-3 second burst — wander radius doubles, speed increases. Decays back to Swimming.
- **Sleeping:** Care health below 0.2. Minimal breathing (0.5% amplitude at 0.15 Hz), near-zero wander. Wakes when health recovers.

---

## The Four Behavior Forces

All four computed inside `force_behavior()`, applied as velocity impulses per tick.

### 1. Wander Force (Perlin Noise)

Smooth Perlin-noise-driven drift. NOT random jitter — that looks twitchy. Each node samples a 1D gradient noise function using `(time * wander_speed + personality_seed)` to get a heading angle:

```rust
angle = perlin_1d(time * wander_speed + seed) * TAU
force_x = cos(angle) * wander_amplitude
force_y = sin(angle) * wander_amplitude
```

Wander stays within `wander_radius` of the node's equilibrium position (where physics settled it). A soft spring pulls back if it drifts too far — prevents nodes from slowly migrating across the screen.

**Perlin speed** (~0.1-0.3) controls turn frequency. **Perlin amplitude** (~0.3-0.8 px/tick) controls drift strength. Both modulated by archetype profile.

**Implementation:** 20-line inline 1D gradient noise. No external crate needed.

### 2. Breathe Force (Sinusoidal Scale)

Not a position force — directly modulates the node's render scale:

```rust
scale = 1.0 + amplitude * sin(time * freq + breath_phase)
```

- Amplitude: 1-3% (subtle). Frequency: 0.3-0.7 Hz (slow, meditative).
- `breath_phase` seeded from `personality_seed` — nodes don't pulse in sync.
- Archetype modulates amplitude and frequency.

### 3. Damped Tether (Parent-Child)

For nodes in `TrailingParent` state. Viscous pull, not elastic spring — no overshoot, no bounce.

```rust
let delta = parent_pos - child_pos
let relative_vel = parent_vel - child_vel
let force = delta * stiffness - relative_vel * damping
```

- `stiffness`: 0.02 (gentle pull)
- `damping`: 0.85 (heavy — kills oscillation, creates glide)
- Chain depth multiplier: `stiffness *= 0.7^depth` — deeper children trail more lazily
- Adds on top of existing `force_link` spring — children *prefer* parent proximity but still participate in layout

**Feel:** Parent moves → child starts gliding after brief inertia delay → accelerates smoothly toward parent's trail → decelerates as it arrives. No jitter, no bounce. Like fish following a leader through water.

### 4. Cursor Reaction (Curiosity Then Avoidance)

Two-phase response based on cursor velocity:

- **Phase 1 — Curiosity** (cursor speed < 50 px/s, within 120px): Tiny attractive force toward cursor. Nodes lean in. Duration: ~0.3s or until cursor speeds up.
- **Phase 2 — Avoidance** (cursor speed > 50 px/s, or after curiosity window): Soft repulsion. `force = direction_away * strength / distance²`. Inverse-square falloff — gentle, not explosive.
- Cursor position from existing `graph_engine_mouse_moved` FFI. No new FFI needed.
- `cursor_awareness` field interpolates 0→1 over the transition for smooth blending.

---

## Archetype Behavior Profiles

Each of the 6 dialogue archetypes maps to parameter multipliers. No unique logic per archetype — just tuning knobs.

```rust
struct BehaviorProfile {
    wander_speed_mult: f32,     // Perlin sample rate
    wander_amplitude_mult: f32, // Drift strength
    breathe_amplitude_mult: f32,
    breathe_freq_mult: f32,
    tether_stiffness_mult: f32, // How close to parent
    cursor_curiosity_mult: f32, // How much lean-in
    cursor_avoidance_mult: f32, // How strong repulsion
}
```

| Archetype | Wander | Breathe | Tether | Cursor | Personality |
|-----------|--------|---------|--------|--------|-------------|
| **Archivist** | 0.3× slow, tight | 0.8× steady | 1.2× stays close | Low curiosity, slow avoid | Anchored scholar |
| **Examiner** | 0.6× medium, patrol | 1.3× sharp, alert | 1.0× standard | High curiosity, quick avoid | Watchful guard |
| **Dreamer** | 1.5× wide, floaty | 0.7× slow, dreamy | 0.6× loose trail | High curiosity, slow avoid | Drifting jellyfish |
| **Gardener** | 1.0× medium | 1.0× standard | 0.8× moderate | Medium both | Reliable worker (default) |
| **Guide** | 1.2× purposeful | 0.9× calm | 1.0× standard | Very high curiosity | Cartographer — investigates |
| **Sentinel** | 0.1× nearly still | 0.5× minimal | 1.5× tight formation | Zero curiosity, strong avoid | Stone guardian |

Nodes without archetypes get the Gardener profile as default.

Profiles stored as a `const [BehaviorProfile; 7]` array (6 archetypes + 1 default). Indexed by `AIComponent::profile_index`. Zero per-tick lookup cost.

---

## AIComponent Extension

Existing fields (already in `ecs/components.rs`):
```rust
state: u8              // AIState enum
personality_seed: u32  // Per-node RNG seed
breath_phase: f32      // Oscillation phase offset
breath_freq: f32       // Base frequency
wander_radius: f32     // Max drift from equilibrium
speed: f32             // Base movement speed
```

New fields to add:
```rust
wander_target_angle: f32  // Current Perlin-sampled heading
equilibrium_x: f32        // Where physics settled this node (snapshot)
equilibrium_y: f32
cursor_awareness: f32     // 0.0-1.0 interpolating curiosity→avoidance
excitement_timer: f32     // Seconds remaining in Excited state
profile_index: u8         // Index into BehaviorProfile array
_pad2: [u8; 3]           // Alignment
```

**Equilibrium snapshot:** After the graph first settles (`is_settled` flips true), snapshot each node's `(x, y)` into `equilibrium_x/y`. Wander uses this as home anchor. Re-snapshot after user drag ends.

---

## Performance Budget

At 5,000 nodes, `force_behavior()` is a single O(n) pass:
- 5,000 iterations
- Per iteration: 1 Perlin noise sample (~4 multiplies + 2 lerps), 1 sin call, 4 force accumulations
- Total: <100μs per tick

For comparison: `force_many_body` (Barnes-Hut) costs ~2-5ms at 5,000 nodes. Behavior is <5% of per-tick budget.

Breathe scale: one float write per node per tick to the render buffer. Metal already reads per-instance scale — zero additional GPU cost.

**Static layout gate:** When `static_layout` is true (>9,000 nodes), behavior is disabled. At that scale the graph is a performance-critical visualization, not an aquarium.

---

## Testing Strategy

Rust unit tests in `forces.rs`:

1. **`test_wander_stays_within_radius`** — 10,000 ticks, verify node never exceeds `equilibrium + wander_radius * 1.5`
2. **`test_damped_tether_no_overshoot`** — parent jumps 100px, verify child position approaches monotonically (no oscillation)
3. **`test_cursor_curiosity_then_avoidance`** — slow cursor at 80px → attractive force. Fast cursor → repulsive force.
4. **`test_archetype_profiles_differ`** — Sentinel wander amplitude < Dreamer wander amplitude after 1,000 ticks
5. **`test_behavior_active_at_alpha_floor`** — set `alpha = ALPHA_FLOOR`, tick 100 times, verify positions changed
6. **`test_sleeping_node_minimal_motion`** — Sleeping state, verify displacement < 0.5px over 1,000 ticks

No Swift tests needed — entirely Rust-side. No new FFI, no new Swift code.

---

## What's NOT in v1

- User-facing behavior toggle in UI (can be added later via ForceParams)
- Per-node behavior customization from Swift
- Behavior reacting to dialogue mood changes in real-time (care state only checked on graph load)
- Flocking/schooling between sibling nodes (v2 — use existing `force_semantic` infrastructure)
- Sound effects tied to behavior state transitions
