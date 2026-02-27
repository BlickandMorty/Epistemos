# Observatory Graph Effects — Design Document

**Goal:** Transform the Metal+Rust knowledge graph into a cosmic observatory experience — layered depth, gravitational arc edges, magnetic field line interactions, and ambient stellar effects.

**Theme:** "Observatory" — a star chart of knowledge. Dark space, layered depth planes, gravitational physics, magnetic field reveals on interaction.

---

## 1. Three-Tier Depth System

Quantize node z-depth into three discrete layers for clean parallax:

| Tier | Criteria | z-depth | Visual |
|------|----------|---------|--------|
| Background | 1-2 links | -0.25 | Smaller, dimmer, recedes |
| Midground | 3-8 links | 0.0 | Normal size, standard brightness |
| Foreground | 9+ links | 0.35 | Larger, brighter, closest to viewer |

- Parallax on pan shifts layers at different rates (diorama effect).
- Breathing animation varies by tier: background slowest (0.3 Hz), foreground fastest (0.6 Hz).
- Background tier nodes get slight alpha reduction (~0.85) for atmospheric depth.

## 2. Gravitational Arc Edges

Replace straight-line edges with quadratic bezier curves that bend based on node mass.

- Control point offset perpendicular to edge midpoint.
- Offset magnitude: `k * (mass_heavy / mass_light)` — heavier nodes bend the curve toward them.
- Equal-mass nodes → symmetric curve. Hub+leaf → strongly curved toward hub.
- Tessellated into 8 segments in the vertex shader.
- On hover: connected edges brighten and curve becomes slightly more pronounced.
- Same subtle gray at 30% opacity; weight affects thickness.

## 3. Magnetic Field Lines (Hover Interaction)

On hover, invisible forces become visible — field lines fan between the hovered node and neighbors.

- 2-3 bezier field lines per neighbor, slightly offset angles (dipole fan pattern).
- Animate with slow oscillation (`sin(time)` offset) for shimmering alive feel.
- Opacity scales with edge weight (stronger connection = brighter field).
- On grab+drag: field lines warp and stretch in real-time.
- On release: fade out over 0.3s.
- Rendered in the node's type color at ~15% opacity.
- Separate GPU buffer, uploaded only when hover changes. Max ~100 segments.

## 4. Hub Glow

Foreground hub nodes (9+ links) get a faint radial glow rendered behind them.

- Second node instance at same position, 3x radius, ~8% opacity, same color.
- Creates "brighter star" effect for important knowledge hubs.
- Rendered before regular nodes (behind).

## 5. Existing Effects (Already Implemented)

| Effect | Description |
|--------|-------------|
| Entrance animation | Big Bang: nodes emerge from center cluster, camera zooms out |
| Ripple shockwave | Radial wave on node grab — gravitational wave through spacetime |
| 3D perspective + parallax | Depth-based size scaling and pan offset |
| Breathing animation | Per-node gentle pulsing — stars twinkling |

## 6. Future Effects (Not in This Phase)

- **Star dust particles**: Tiny dim dots drifting in far background. Ambient.
- **Constellation outlines**: At extreme zoom-out, convex hull glow around clusters.
- **Edge energy pulse**: Traveling light dot along edges (information flow direction).

## 7. Implementation Priority

1. Quantize depth to 3 tiers (modify `z_for_link_count`)
2. Hub glow (second node instance pass)
3. Gravitational arc edges (bezier tessellation)
4. Magnetic field lines (new buffer + hover interaction)
5. Tier-based breathing speeds
6. Future: star dust, constellations, energy pulse
