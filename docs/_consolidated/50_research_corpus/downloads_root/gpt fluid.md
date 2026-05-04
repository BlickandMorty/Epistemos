# Epistemos Fluid Graph Technical Specification

## The stance

Yes.  
The **slow ramp-up, delayed ripple, overshoot, and alive-at-rest motion should be true**.

But the right way to get there is **not** to replace your whole graph with literal fluid particles. The right move is a **hybrid solver**: keep the graph’s structural forces for topology, then add a **real damped-wave field** plus **mass-varying damping** plus **coherent ambient curl-noise** on top. That gives you the *water feel* without sacrificing graph readability or blowing your frame budget. Your current base is d3-like by design: d3-force explicitly uses a velocity-Verlet simulation with a constant unit time step and constant unit mass, which is exactly why equal-mass/equal-decay behavior feels rigid unless you add heterogeneity and secondary motion. Position-Based Fluids and Position-Based Dynamics are real-time-stable and great for actual liquids, but they are overkill as a first rewrite for a semantic graph that still needs springs, repulsion, and readable equilibrium. citeturn44search0turn44search3turn37search0turn37search12turn37search2

The high-level design principle is this:

**instant contact, delayed field response**.

The node under your cursor must react immediately.  
Its neighborhood should react on the same beat.  
The wider graph should react **a fraction of a beat later**.

That two-timescale split is what reads as “water” instead of “lag.” Your repo is already unusually well-positioned for this because it has a Rust simulation core, a `FluidGrid`, explicit per-node mass storage, and a renderer that already composes SDF-based nodes and curve/line edges in Metal-facing Rust. citeturn8view0turn8view1turn18view0turn19view0turn33view0

## What Google appears to have built

I could not verify a public, consumer-facing Google product called a “cognitive graph” with a published physics solver. The **closest official 2025–2026 candidates** are:

- Google’s official **Mind Maps** feature in NotebookLM, which Google describes as interactive visual diagrams and the help docs describe as a **branching diagram** that summarizes uploaded sources. citeturn39search0turn45search1
- Google’s enterprise-side **Knowledge Graph** work for Gemini Enterprise, which is officially described as linking **people, content, and interactions**. citeturn45search2
- The April 2026 **Workspace Intelligence** announcement, which explicitly says it turns scattered emails, chats, and files into a **cohesive knowledge graph**. citeturn45search8
- Google Search **AI Mode**, which Google positioned at I/O 2025 as a Gemini-powered future of search, while also noting that some results shown are **illustrative** and include future-looking features. citeturn39search2turn39search5turn39search8

That matters because your remembered ad may have been a **conceptual or illustrative motion piece**, not a faithful rendering of an already-shipped physics engine. I did not find a Google engineering write-up in the reviewed sources that discloses the renderer choice or graph physics model for those visuals. What Google *did* publicly articulate in 2025 is a motion language: Material 3 Expressive emphasizes **more natural, springy animations**, and the Android blog explicitly gives an example where neighboring UI elements **subtly respond to your drag**. That is not a graph paper, but it is a direct design clue. citeturn41search0turn39search0turn45search1

So the strongest research-based inference is this:

Google’s public products point to **branching knowledge visuals**, **knowledge-graph semantics**, and a **motion philosophy of nearby delayed response**, but I did not find public evidence that they shipped a disclosed “water-physics knowledge graph” engine. If you want the “Google/Obsidian but grand” feel, you should copy the **motion principles and visual restraint**, not wait for a hidden Google implementation to surface. citeturn41search0turn39search5turn45search2turn45search8

## What Epistemos has today

Your repo is clearly split into the right layers already. The app side has `Epistemos/Graph`, `Epistemos/Theme`, `Epistemos/Shaders`, and a bridging header; the Rust core lives in `graph-engine/src` and the FFI surface is exposed through `graph_engine.h`. On the Swift side, `GraphEngine.swift` forwards mouse and physics settings into Rust; `GraphState.swift` owns the preset system, visual theme persistence, performance mode, and water-node toggles. citeturn18view0turn19view0turn20view0turn20view1turn33view0turn34view0

The current physics model is still fundamentally the d3 family. The d3 docs describe the solver as velocity-Verlet with constant unit mass, and your Swift state exposes the same conceptual knobs: link distance, charge strength, charge range, link strength, velocity decay, center strength, and collision radius. On top of that, `GraphState.swift` currently adds a very large preset matrix and an additional “laboratory” layer of toggles for fluid, torsion, elastic edges, viscosity, boids cohesion, wind, and orbital motion. There are twelve named presets from `Observatory` through `Chaos`, plus saved scheduler state and water-node persistence. citeturn44search0turn44search3turn24view1turn26view0turn23view2turn23view5

That is the first core problem:

**too many knobs are compensating for the absence of a coherent motion model**.

You already have evidence of configuration sprawl. `GraphState.swift` says the static-layout threshold is `9000`, while the C header comment for `graph_engine_is_static_layout()` says physics is disabled for graphs over `1500` nodes. Even if one is stale commentary, the existence of that mismatch tells you the model is already drifting faster than the UI can explain. citeturn31view0turn34view0

The second core problem is that the engine still has a “dead stop” path. In `simulation.rs`, `is_settled()` checks a tiny velocity threshold, and when the simulation marks settled it zeroes all velocities and flips `is_settled = true`. In `engine.rs`, `resume()` only restarts physics if the simulation is *not* settled. That yields exactly the dead freeze you described: once the system decides it is done, the graph is effectively treated as asleep rather than alive. citeturn9view1turn9view6turn46view0

The third problem is that the current “water” mode is mostly cosmetic. In the node vertex shader, `water_wobble` modulates **effective radius** with a sinusoid; it does not create a fluid positional field. The node shader also still carries cinematic features like glow, pulse-wave glow, chromatic aberration, sprite-like shine tiers, and outline logic. That can look flashy, but it is not the clean minimal motion you are after. citeturn13view4turn17view0

The edge complaint is real too. `LineEdgeInstance` stores only `p0`, `p1`, and color. `CurveEdgeInstance` stores only `p0`, `c0`, `c1`, `p1`, and color. There is no endpoint radius or gap built into the edge instance itself, so the default geometry naturally wants to originate from node centers. `string_edge_control_points()` improves curve shape with velocity-aware sag, but unless you trim endpoints you still get that “line runs into the middle of the node” look. citeturn14view0turn16view0turn16view1

## Recommended motion architecture

The recommendation is a **field-coupled, underdamped graph solver**.

Not full SPH.  
Not full PBD.  
Not fake easing.

A **real damped wave field** should sit on top of the graph forces you already trust.

The total node acceleration should become:

\[
\mathbf{a}_i
=
\frac{
\mathbf{F}^{graph}_i
+
\mathbf{F}^{wave}_i
+
\mathbf{F}^{ambient}_i
+
\mathbf{F}^{interaction}_i
}{m_i}
\]

and the velocity update should stop being globally uniform:

\[
\mathbf{v}_i^{t+\Delta t}
=
\rho_i \, \mathbf{v}_i^t
+
\Delta t \, \mathbf{a}_i
\]

\[
\mathbf{x}_i^{t+\Delta t}
=
\mathbf{x}_i^t
+
\Delta t \, \mathbf{v}_i^{t+\Delta t}
\]

where \(m_i\) and \(\rho_i\) vary by node importance. This preserves the graph’s spring/charge equilibrium while adding the missing liquid secondary motion. The design is informed by d3’s explicit force integration, by the stability goals of Position-Based Dynamics/Fluids, by SPH’s local-neighbor intuition, and by curl-noise techniques used for procedural fluid-style motion. citeturn44search3turn37search0turn37search12turn37search2turn38search20turn38search5

**Drag to ripple**

Use your existing `FluidGrid`, but stop treating it as only a diffused velocity buffer. Extend it into a **hybrid wave field**:

- scalar pressure/displacement field \(p\)
- scalar pressure velocity \(q\)
- vector wake field \(\mathbf{u}\)

Per grid cell \(g\), step the damped wave system as:

\[
q_g \leftarrow q_g + \Delta t \left(c_w^2 \nabla^2 p_g - \lambda_w q_g + S_g \right)
\]

\[
p_g \leftarrow p_g + \Delta t \, q_g
\]

\[
\mathbf{u}_g \leftarrow
\lambda_u \mathbf{u}_g
-
\kappa_p \nabla p_g
+
\nu \nabla^2 \mathbf{u}_g
+
\mathbf{A}_g
\]

When a node is dragged at position \(\mathbf{x}_0\) with drag velocity \(\Delta \mathbf{v}\), inject **two** things:

\[
\mathbf{u} \mathrel{+}= \kappa_d \, \Delta \mathbf{v} \, G_\sigma(r)
\]

\[
p \mathrel{+}= \kappa_r \, (\Delta \mathbf{v}\cdot(\mathbf{x}-\mathbf{x}_0)) \, G_\sigma(r)
\]

where \(G_\sigma(r)=\exp(-r^2 / 2\sigma^2)\).

That first term gives you **same-direction immediate follow**.  
That second term gives you a **true propagating wavefront** with distance-based delay.

Nodes then sample the field by bilinear interpolation:

\[
\mathbf{F}^{wave}_i
=
\kappa_{sample}\,m_i^{-1/2}\,\mathbf{u}(\mathbf{x}_i)
\]

The \(m_i^{-1/2}\) factor is important. It is what makes heavy nodes feel like anchors instead of leaves. The qualitative target is much closer to a damped surface wave than to ordinary spring relaxation. citeturn8view0turn8view1turn37search2turn38search20

```rust
fn inject_drag(pos: Vec2, dv: Vec2) {
    fluid.inject_vector_gaussian(pos, k_direct * dv, sigma_direct);
    fluid.inject_pressure_dipole(pos, k_pressure * dv, sigma_pressure);
}
```

That is the one behavior where I would be uncompromising:  
**the ripple must be real**.

If you need a lower-code fallback, use an analytic wavefront per active interaction:

\[
\mathbf{F}^{analytic}_i
=
A_0 e^{-\lambda \tau_i}\sin(\omega \tau_i)\,e^{-(r_i/R)^2}\,\hat{\mathbf{d}}
\quad
\text{with}
\quad
\tau_i = \max(0, t-t_0-r_i/c)
\]

But the grid-wave version is better because you already have the grid abstraction and it composes naturally with ambient breathing. citeturn8view1turn38search20

**Release to wave settle**

On release, do **not** zero the dragged node’s velocity. Let that residual velocity become the initial condition of a damped oscillator plus a field emission.

Schedule a release source:

\[
S^{release}(\mathbf{x}, t)
=
A_0 e^{-\lambda_{rel}\tau}\sin(\omega_{rel}\tau)
\,
(\hat{\mathbf{d}}\cdot(\mathbf{x}-\mathbf{x}_0))
\,
G_{\sigma_{rel}}(r)
\]

for \(\tau = t - t_0 \ge 0\).

Then temporarily reduce local damping around the release point:

\[
\rho_i(t)
=
\rho_i^{base}
+
\eta_{rel} e^{-r_i^2 / 2R_{rel}^2} e^{-\lambda_{loc}\tau}
\]

clamped into a sane range.

You can optionally add a short-lived release anchor on the released node itself:

\[
\mathbf{F}^{anchor}_j
=
-k_{rel}(\mathbf{x}_j-\mathbf{x}_j^\*)
-c_{rel}\mathbf{v}_j
\]

where \(\mathbf{x}_j^\*\) is the graph-only predicted target captured immediately after release. This is a practical way to guarantee one readable overshoot before the field dampens out. The combination of underdamped local motion plus field propagation is what produces the visible “neighbor overshoot a beat later” effect you want. This blends underdamped/Langevin-style thinking with your existing graph forces. citeturn38search3turn37search0turn37search12

```rust
fn inject_release(pos: Vec2, v_release: Vec2, mass: f32) {
    active_impulses.push(Impulse {
        origin: pos,
        dir: normalize_or_zero(v_release),
        amp: k_release * length(v_release) * mass.sqrt(),
        omega: release_omega,
        decay: release_decay,
        sigma: release_sigma,
        born_at: now(),
    });
}
```

Your perceptual target for release is:

- first overshoot visible within about **120–220 ms**
- neighbors visibly pick it up **40–180 ms later** depending on radius
- meaningful decay to calm within **1–3 s**

That is readable and watery without turning the graph into soup. citeturn41search0turn38search3turn37search0

**Ambient breathing**

Do **not** use raw white noise.

Raw Langevin noise alone reads as jitter.  
What you want is **colored, coherent, divergence-free drift**.

Use a scalar simplex-noise potential \(\psi(x,y,t)\), then derive a 2D curl field:

\[
\mathbf{v}^{ambient}(x,y,t)
=
\alpha
\begin{bmatrix}
\partial \psi / \partial y \\
-\partial \psi / \partial x
\end{bmatrix}
\]

This gives you local coherence and avoids sink/source artifacts. Per node:

\[
\mathbf{F}^{ambient}_i
=
\kappa_{amb}\,m_i^{-0.7}\,\mathbf{v}^{ambient}(\mathbf{x}_i,t)
\]

That inverse mass exponent is what makes light nodes drift more while hubs barely breathe. Robert Bridson’s curl-noise paper is still the right mental model here, and even modern engine tooling documents the same principle: curl-noise gives turbulent motion while remaining divergence-free. citeturn38search20turn38search5

```rust
fn sample_ambient(x: Vec2, t: f32, mass: f32) -> Vec2 {
    let psi = noise3(x.x * amb_scale, x.y * amb_scale, t * amb_speed);
    let dpsi_dx = finite_diff_x(...);
    let dpsi_dy = finite_diff_y(...);
    let curl = vec2(dpsi_dy, -dpsi_dx);
    return amb_strength * curl / mass.powf(0.7);
}
```

A good idle graph should feel alive **only when you stare at it**.  
If you notice it immediately, it is too strong.

**Non-uniform inertia**

You already compute mass from degree. Keep going and make it first-class:

\[
m_i = \text{clamp}(1.0 + 0.65\log_2(1+\deg_i) + 0.35 s_i,\ 1.0,\ 6.0)
\]

where \(s_i\) is optional semantic importance normalized to \([0,1]\).

Then make damping and field coupling mass-aware:

\[
\rho_i = \text{lerp}(\rho_{light}, \rho_{heavy}, \tilde{m}_i)
\]

\[
\kappa_{field,i} = \kappa_{field} / \sqrt{m_i}
\]

Use inverse-mass weighting in collision resolution:

\[
\Delta \mathbf{x}_i
=
-\delta \mathbf{n}\,
\frac{1/m_i}{1/m_i + 1/m_j}
\quad,\quad
\Delta \mathbf{x}_j
=
+\delta \mathbf{n}\,
\frac{1/m_j}{1/m_i + 1/m_j}
\]

That one change alone will make heavy nodes feel like they belong to a deeper layer of the graph. This is where “semantic importance” becomes visible motion, not just size. citeturn30view0turn24view1turn44search3

On the research question of SPH, LBM, and PBD:

- **Full SPH** is conceptually adaptable, but for a graph it is the wrong base abstraction; use it only as an optional **local SPH-lite** term inside an active drag radius if you later want extra slosh. citeturn37search2
- **LBM** is fantastic on GPUs because of local lattice updates, but it is a poor fit for sparse semantic graph layout at 50–1500 nodes. You already have the right “cheap LBM feeling” abstraction: the field grid. citeturn37search11turn37search23turn8view1
- **PBD/PBF** is the closest true fluid framework, especially in the work of **entity["people","Miles Macklin","graphics researcher"]** and **entity["people","Matthias Müller","graphics researcher"]**, and in engines such as those built around **entity["company","NVIDIA","gpu company"]** FleX. But for Epistemos, the right move is to **borrow its stability ideas**, not replace the graph solver with a particle-liquid solver in v1. citeturn37search0turn37search12turn36search11turn36search13

## Rendering and visual direction

Your current node shader stack is doing too much. The code path includes water wobble, glow instances, pulse-wave glow, chromatic aberration, stepped shine, outlines, and a light-vs-dark dimming system. That is impressive engineering, but it is fighting the aesthetic you described. You do not want “cinematic.” You want **quiet authority**. citeturn13view4turn17view0

The visual direction I recommend is **minimal grand**:

- **light mode:** near-black edges and labels on an off-white field
- **dark mode:** near-white edges and labels on charcoal/near-black
- node fills: mostly restrained, with only a few semantic accents
- selection: soft halo only
- no always-on glow
- no chromatic aberration
- no animated node breathing via size change
- no shiny sprite highlight tiers

That still leaves room for elegance, but it moves elegance into **proportion, contrast, anti-aliasing, and depth ordering** instead of effect stacking. Google’s 2025 expressive direction pushed toward fluidity and responsive motion, but the visual surfaces themselves remained disciplined and readable. citeturn41search0

For the nodes, keep SDF circles, but simplify the fragment shader to a **2.25D disc**:

\[
\alpha = 1 - \text{smoothstep}(1-aa,\ 1+aa,\ d)
\]

\[
shade = 1 + s_{lift}\max(0,\langle \mathbf{n}, \mathbf{l}\rangle) - s_{rim}\,rim(d)
\]

with extremely small values like \(s_{lift}=0.03\) to \(0.05\) and \(s_{rim}=0.04\) to \(0.08\). The result should read as “crafted flatness,” not faux glossy 3D. You already have the SDF infrastructure to do this cleanly. citeturn13view4turn17view0

For color, your current default node palette is vivid: note teal, chat lilac, source green, folder brown, and so on. That is a useful taxonomy, but it wants to be compressed. Keep the semantic distinctions, but reduce the display palette to three primary accents:

- **Folder**: warm neutral stone
- **Note**: deep teal
- **Chat**: indigo-violet

Let the rest derive from these by luminance/saturation adjustment or collapse into neutrals unless highlighted. Your current repo already has Note/Chat/Folder distinct in `NodeType::color()` and darker equivalents in `color_light()`, so you can evolve the palette instead of reinventing it. citeturn29view1turn29view4turn29view5

Suggested starting colors:

- light background: `#F7F6F3`
- dark background: `#111214`
- light edge/text: `#15171A`
- dark edge/text: `#F2F4F7`
- folder accent: `#7B6A58` dark-mode lifted / `#3A3128` light-mode ink
- note accent: `#0F8E86` dark-mode lifted / `#143D39` light-mode ink
- chat accent: `#6E77E8` dark-mode lifted / `#262A57` light-mode ink

That gives you a graph that is mostly monochrome at first glance, but reveals semantic color when you focus.

The edge fix is not optional.

Right now the visual data model for edges is center-to-center. That is why they feel like they pierce nodes and meet at a sharp middle. The fix is:

\[
\mathbf{p}_0' = \mathbf{p}_0 + \hat{\mathbf{d}}(r_0 + g)
\]

\[
\mathbf{p}_1' = \mathbf{p}_1 - \hat{\mathbf{d}}(r_1 + g)
\]

with \(g\) as a small gap beyond the node radius.

For cubic edges, preserve tangent directions and recompute handles from the trimmed endpoints:

\[
\mathbf{c}_0' = \mathbf{p}_0' + h_0 \hat{\mathbf{t}}_0
\quad,\quad
\mathbf{c}_1' = \mathbf{p}_1' - h_1 \hat{\mathbf{t}}_1
\]

This alone removes the “sharp middle” feeling. Your current renderer already computes dynamic string-like control points, so you do not need a new curve system. You just need endpoint-aware trimming. citeturn16view0turn16view1turn14view0

Then make the stroke itself cleaner:

\[
\alpha_{edge}
=
1 - \text{smoothstep}(w-aa,\ w+aa,\ d_{px})
\]

where \(d_{px}\) is the pixel-space distance to the curve centerline.

That is the correct move for “low quality lines.”  
This is an anti-aliasing problem and a topology problem.

Finally, ensure edges are **visually under nodes even if draw order changes**. CPU endpoint trimming solves most of it. If you want belt-and-suspenders safety, give edge instances `r0`, `r1`, and discard any stroke fragments that fall inside the endpoint occlusion discs. That way node interiors stay visually clean no matter what happens with blending or depth conventions. citeturn14view0turn15view0

## File-by-file implementation map

These are the files I would change first.

- `graph-engine/src/simulation.rs`  
  This is the center of gravity. `ForceParams` is where the new motion model should become first-class; `FluidGrid` is where you should add `pressure` and `pressure_vel`; `is_settled()` is where you should replace hard freeze with **soft sleep**; and `tick()` is where graph forces, field coupling, mass-aware damping, and ambient breathing should be integrated. Use the existing grid stencil and sampling path rather than introducing a second field system. citeturn7view2turn8view0turn8view1turn9view1turn9view6turn9view5

- `graph-engine/src/engine.rs`  
  This is where drag lifecycle behavior should be wired. The input block already comments on the d3-style warmup behavior during `mouse_down()`. Extend the same interaction block so drag motion injects directional wake + pressure dipole into the simulation, and release schedules a damped impulse event instead of ending abruptly. Also use this layer to switch from a hard “settled means done” policy to a **low-energy alive** policy. The render sync comments also show that the engine already extrapolates sub-tick motion for smoother rendering, which helps you hide lower simulation rates when needed. citeturn46view0turn24view2

- `graph-engine/src/renderer.rs`  
  Change three clusters here. First, extend `LineEdgeInstance` and `CurveEdgeInstance` to carry endpoint radii and gap. Second, modify `string_edge_control_points()` to work from trimmed endpoints and tangent-preserving recomputed handles. Third, simplify the node fragment path by stripping back wobble/glow/chromatic code from the default theme and replacing it with the restrained 2.25D disc shader. This file already holds both node and edge shader logic, so it is the right place for the under-node edge look and line-quality upgrades. citeturn14view0turn16view0turn16view1turn13view4turn15view0

- `graph-engine/src/types.rs`  
  Use this file to compress the node and edge palette. Right now edges are semantically colorful in both dark and light mode, and node types have a broad color taxonomy. Shift edges toward neutral strokes by default, and keep semantic color for selection, hover, search, or high-confidence emphasis. Collapse node display colors to the three-key family palette while preserving type metadata. citeturn30view0turn29view1

- `Epistemos/Graph/GraphState.swift`  
  This is where you should simplify the settings model. Right now it contains twelve physics presets, a large persistent lab layer, water-node settings, a visual theme enum with only `dialogue` and `classic`, and multiple persistence/versioning branches. Replace the public physics surface with three user-facing controls: **Motion Style**, **Layout Spacing**, and **Appearance Style**. Keep everything else behind a developer panel. This is also the right place to add a new visual theme state such as `minimalGrand`, and to delete the user-facing “water wobble” concept once real field motion lands. citeturn26view0turn24view1turn24view0turn31view0turn31view1

- `Epistemos/Graph/GraphEngine.swift`  
  The Swift side already forwards core force params, extended params, and lab params into Rust. Add a narrow, opinionated API for the new model instead of expanding the old lab API forever. For example: `setMotionStyle`, `setAppearanceStyle`, `setLayoutSpacing`, and an optional debug-only `setAdvancedMotionParams`. citeturn24view2turn25view0

- `graph-engine-bridge/graph_engine.h` and `Epistemos-Bridging-Header.h`  
  Add the new FFI functions here. At minimum you will want setters for wave parameters, ambient parameters, visual theme, and perhaps an endpoint-gap or edge-style mode. The header already exposes force params, lab params, light/dark mode, and visual theme across the boundary, so this is a straightforward extension point. citeturn34view0turn33view0

- `Epistemos/Shaders/ThinkingGlow.metal`  
  Treat this as secondary. The graph’s main node/edge look is currently controlled from `renderer.rs`, and the shader folder listing suggests `ThinkingGlow.metal` is not the right first target for your core graph restyle. Touch it only if your new selection halo language needs it. citeturn20view0turn13view4

## Performance, tuning, validation, and study references

The comforting part is that the **water feel you want does not require full fluid cost**.

A 64×64 field is only 4096 cells. Even with `pressure`, `pressure_vel`, and `velocity`, the wave-field step is tiny compared with Barnes-Hut and edge building. On CPU, a 9-point stencil over 4096 cells is cheap. At 500 nodes, the added field work should be comfortably sub-millisecond in Rust. At 1500 nodes, the dominant cost will still be many-body repulsion, visibility bookkeeping, and edge preparation, not the wave layer. That is why I would keep the wave model on CPU for v1 and reserve GPU compute for bigger graphs or future SPH-lite experiments. Cosmograph and cosmos.gl are useful references here because they show how GPU-native force layouts scale, but your target range does not force you there yet. citeturn42search0turn42search20turn42search16

Use these as **starting parameter ranges**:

- `wave_speed`: **600–1400 world units/s**  
  Perceptually: higher feels more instant, lower feels more syrupy.

- `wave_damping`: **4–10 s⁻¹**  
  Perceptually: lower gives long rings; higher gives thick, restrained settling.

- `direct_drag_coupling`: **0.18–0.45**  
  Perceptually: how much the neighborhood immediately follows the drag direction.

- `pressure_coupling`: **0.4–1.2**  
  Perceptually: how visible the delayed ripple is.

- `drag_sigma`: **24–72 world units**  
  Perceptually: local hand-feel radius.

- `release_omega`: **7–11 s⁻¹**  
  Roughly 1.1–1.75 Hz; this is the “one or two readable sways, then calm” zone.

- `release_decay`: **1.2–2.4 s⁻¹**  
  Perceptually: how fast the graph forgets the release.

- `ambient_strength`: **0.25–1.2 px/s equivalent**  
  Perceptually: the “alive” amount.

- `ambient_scale`: **220–480 world units**  
  Perceptually: larger means coherent regional drift.

- `ambient_speed`: **0.03–0.10 Hz**  
  Perceptually: too high becomes fidgety; too low becomes invisible.

- `mass range`: **1.0–6.0**  
  Enough to visibly separate anchors from leaves without breaking the layout.

- `velocity retain`:  
  light nodes **0.90–0.94**, heavy nodes **0.84–0.90** per tick in your current-style retain model.  
  Perceptually: leaves flutter, hubs resist and settle earlier.

- `edge endpoint gap`: **1.5–3.5 px beyond radius**
- `edge width`: **1.0–1.6 px**
- `edge alpha`: **0.08–0.16** dark mode, **0.12–0.22** light mode  
  Perceptually: enough to knit the graph together without turning the field into spaghetti. citeturn38search20turn38search5turn38search3turn44search3turn16view0turn16view1

These are the **test scenarios** I would run, in order:

- **Hub drag test at 80 nodes**  
  One heavy hub, many light leaves. Drag the hub 250–400 px fast, then release.  
  Pass condition: hub responds instantly; leaves near it respond almost instantly; outer leaves start 1–4 frames later; the graph visibly rings instead of snapping. citeturn41search0turn38search20

- **Peripheral whip test at 200 nodes**  
  Grab a light leaf, whip it through a cluster, release.  
  Pass condition: local wavefront forms, but hubs do not get yanked unrealistically. This validates mass-aware coupling.

- **Cluster bridge test at 500 nodes**  
  Two dense clusters linked by a few bridge nodes. Drag one bridge node hard, release.  
  Pass condition: the bridge transmits motion as a visible delayed pulse; the far cluster reacts later, not simultaneously.

- **Idle read test at 500 nodes**  
  Leave the graph untouched for 20 seconds.  
  Pass condition: you notice motion only after staring; nearby nodes drift coherently; no visible jitter; search and selection remain readable.

- **Budget test at 1500 nodes**  
  Repeat the same drag/release flows while measuring physics tick time.  
  Pass condition: motion field still reads; tick stays under your 5 ms budget; if not, reduce edge work first, not wave math.

- **Static-plus-breathing test above the fully interactive tier**  
  If you choose to degrade above ~1500 nodes, freeze topology but keep ambient field and selection halos alive.  
  Pass condition: the view still feels inhabited, even when the layout is no longer fully dynamic.

One more important recommendation: **do not hard-freeze at settle**. Sleep the expensive parts instead. For example, stop Barnes-Hut rebuilds when the graph is calm, but keep the ambient field updating every second or third tick. Your engine already extrapolates sub-tick motion for smoother rendering, which makes this hybrid sleep strategy a very good fit. citeturn46view0turn9view1turn9view6

For **reference implementations and papers worth studying**, these are the best anchors:

- d3-force for the exact base mechanics you are replacing emotionally but not structurally. citeturn44search0turn44search3
- ForceAtlas2 and the Sigma.js ForceAtlas2 worker plugin for continuous graph layout behavior and “always relaxed, never truly dead” graph mentality. citeturn44search1turn42search2turn42search10
- Cytoscape.js CoSE/fCoSE and cola-style layout work for constraint-aware graph layout thinking. citeturn42search1turn42search5turn42search9turn42search21
- Cosmograph / cosmos.gl and the role of the **entity["organization","OpenJS Foundation","javascript foundation"]** project around GPU-native force layouts. citeturn42search0turn42search8turn42search20
- Position-Based Fluids and Position-Based Dynamics for what “stable real-time fluid” actually looks like mathematically. citeturn37search0turn37search12
- SPH review literature for local-neighbor density intuition, if you later build SPH-lite inside an interaction radius. citeturn37search2turn37search10
- Bridson curl-noise and engine-level Perlin curl-noise tooling for the ambient breathing layer. citeturn38search20turn38search5

**TL;DR:** the best path is a **hybrid graph-plus-wave-field rewrite**, not a full liquid solver rewrite. Make the ripple real, keep the topology graph-native, trim edges to node boundaries, simplify the shader down to a minimal 2.25D disc, and collapse the public settings into a small opinionated surface.

**Check for understanding:** the core recommendation is **true wave propagation layered over your existing graph solver**, with **mass-aware damping**, **curl-noise breathing**, and **endpoint-trimmed under-node edges** as the three changes that will most transform the feel.