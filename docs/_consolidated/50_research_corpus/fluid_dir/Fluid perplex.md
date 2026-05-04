# Fluid, Organic Physics for Knowledge Graphs in Epistemos

## Executive overview

Google has not publicly documented a specific "cognitive graph" product with the exact water‑like graph behavior described, but related work around Gemini, NotebookLM, AI Mode, and the Material 3 "motion physics system" makes it clear that Google is standardizing on physically‑based spring motion with expressive, organic easing rather than the rigid, globally uniform damping typical of d3‑force. Modern graph engines like cosmos.gl (used by Cosmograph) and graphology/ForceAtlas2 also emphasize continuous, friction‑based simulations on the GPU or in workers, tuned for "organic" motion and drag interactions, rather than discrete layout phases. Building on these ideas, the specification below proposes a hybrid model for Epistemos: keep your existing force‑directed base (springs, repulsion, Barnes–Hut) but layer on (1) a low‑resolution fluid velocity field, (2) distance‑attenuated wave impulses, (3) spatially coherent Perlin noise, and (4) per‑node mass/damping, all integrated into your existing Rust + Metal stack.[^1][^2][^3][^4][^5][^6][^7]


## 1. What Google appears to be doing

### 1.1 Products and motion principles

Material 3 Expressive introduced a new motion physics system that replaces simple ease‑in/ease‑out timing with physically‑based spring motion that "makes interactions feel alive, fluid, and natural" and is explicitly described as a physics‑based system rather than pure easing curves. Public descriptions emphasize organic motion, elastic easing, curved paths, and soft rebounds where elements accelerate and decelerate smoothly, never starting or stopping instantaneously. This matches the behavior you describe: overshoot, gentle oscillation, and gradual settling rather than the abrupt convergence typical of d3‑force with high velocity decay.[^8][^2][^3][^9][^1]

Google’s Material motion guidelines describe motion that is responsive, natural, aware, and intentional, where elements push/pull others and the entrance of one element affects the movement of others. That philosophy maps well onto a graph where dragging one node creates a disturbance that propagates outward, and heavier nodes act as anchors with different motion profiles.[^10][^11][^8]

Gemini AI Mode and NotebookLM emphasize rich, multimodal visualizations (charts, maps, knowledge structures) but public materials focus on data synthesis rather than the low‑level physics of any graph visualizations. Third‑party coverage of NotebookLM in 2025 mentions a long‑term vision of a "personalized knowledge graph" and mind‑map‑style views, but again does not document underlying renderers or physics. No official Google blog post, repository, or talk could be found that documents a custom fluid‑like physics engine for knowledge graphs, so the most reliable clues come from the Material 3 motion physics system and from industry‑standard force‑directed engines.[^12][^13][^14][^15][^16][^17][^18]


### 1.2 Likely rendering stack

Material 3’s motion physics system is implemented directly in Android’s Jetpack Compose and MDC‑Android libraries and is designed to be portable to other platforms via tokens and parameters. For web‑based visualizations in Google products, the common stack is still WebGL or WebGPU (for example in Maps, Data Studio/Looker, and experimental graph demos), with custom shaders or Three.js‑style engines layered over them; however, no public reference explicitly ties a Gemini or NotebookLM cognitive graph visualization to a specific WebGL/WebGPU stack.[^19][^2][^20]

Given that cosmos.gl runs a GPU‑based force‑directed layout entirely in WebGL shaders and is now an OpenJS project, it is a strong analogue for the kind of tech Google would use for a high‑end web graph visualization. Cosmograph itself is documented as a WebGL‑based GPU force graph engine where all force computations happen in fragment and vertex shaders, with parameters for friction, gravity, and repulsion tuned for real‑time interaction with large graphs. For Epistemos, your Metal compute pipeline is directly comparable to the shaders cosmos.gl uses for layout and suggests that running a low‑resolution fluid field and/or partial force computations on the GPU is feasible within your frame budget.[^4][^5]


## 2. Fluid and stochastic physics models relevant to graphs

### 2.1 Smoothed Particle Hydrodynamics (SPH)

Smoothed Particle Hydrodynamics (SPH) models fluids as particles that move with the flow and interact via kernel‑weighted local neighborhoods rather than a fixed grid. Each particle’s density and pressure are estimated by summing contributions from nearby particles within a smoothing radius, and accelerations are computed from pressure gradients and viscosity terms, making SPH well suited to free‑surface flows and large deformations. SPH is widely used in astrophysics and fluid simulations but has computational cost roughly proportional to the number of particle neighbors per step (often mitigated via spatial hashing or trees).[^21][^22][^23]

For a 2D graph layout, a full SPH simulation over all nodes would be overkill and would likely violate your 2–5 ms budget when combined with spring forces, especially above several hundred nodes unless heavily GPU‑accelerated. Instead, SPH is most useful here as inspiration: the idea of a local kernel around each disturbance, with velocity updates based on smoothed neighborhood influences, directly informs the wavefield and velocity‑field approach in section 4.


### 2.2 Lattice Boltzmann methods (LBM)

The Lattice Boltzmann Method (LBM) simulates fluids on a fixed lattice by evolving discrete particle distribution functions via collision and streaming steps, approximating macroscopic flows governed by Navier–Stokes. It is highly parallel and well‑suited to GPU implementations and complex boundaries, and GPU Gems shows how LBM can yield visually plausible fluid flow at interactive rates using fragment shaders. However, LBM requires evolving multiple distribution values per cell and is more complex than necessary for subtle graph motion.[^24][^25][^26]

Given that Epistemos already has a 64×64 velocity field with diffusion (a simplified fluid grid) and that you only need gentle ripples and drift—not full vortical fluid detail—LBM is not recommended here. A lightweight velocity‑diffusion grid driven by impulses and noise achieves most of the perceptual benefits with far less complexity.


### 2.3 Langevin dynamics and stochastic motion

Langevin dynamics models particles subject to deterministic forces plus random thermal noise and viscous damping, resulting in stochastic trajectories that still relax toward equilibrium. The continuous‑time Langevin equation combines deterministic force, friction, and Gaussian noise; discrete variants are widely used in molecular dynamics and statistical sampling.[^27][^28]

For graphs, an overdamped or underdamped Langevin integrator can be viewed as your existing spring forces plus drag, with an added random (or structured) noise term in velocity space. By choosing low‑frequency, spatially correlated noise (via Perlin noise fields; see below) instead of uncorrelated white noise, you can create coherent "breathing" motion without visible jitter.


### 2.4 Perlin/simplex noise and flow fields

Perlin noise is a gradient‑based coherent noise function where nearby positions have similar values, widely used to create natural‑looking textures and pseudo‑random motion. Typical implementations define a grid of random gradient vectors, compute dot products with offsets from each lattice corner, and interpolate smoothly between them to produce spatially smooth noise values. Perlin noise can be extended to vector fields, where each point in space has a direction and magnitude derived from one or more noise channels.[^29][^30][^31]

Artists and generative programmers commonly use Perlin noise to define 2D "flow fields", assigning a direction vector at each position on a canvas and moving particles through the field to obtain organic, swirling motion. Flow‑field tutorials show how to treat noise as a force field: a grid of vectors updated over time based on noise in a three‑dimensional domain (x, y, t), which naturally produces coherent motion and soft, wave‑like changes. This is directly applicable to your existing FluidGrid: replacing or augmenting the diffusion‑based velocity field with a Perlin‑driven vector field gives a cheap, spatially coherent background drift for graph nodes.[^32][^33]


## 3. Existing graph engines and physics implementations

### 3.1 d3‑force and its limitations

D3’s force simulation implements a velocity Verlet integrator with unit mass and a global velocity decay parameter that multiplies each node’s velocity by a constant factor on each tick. The documentation explicitly describes the decay factor as "akin to atmospheric friction" applied uniformly to every node; in practice, high decay values produce fast convergence but can feel rigid and over‑damped, while low decay values produce oscillations that may never settle. D3 also uses Barnes–Hut for many‑body repulsion to scale to larger graphs, similar to your current engine.[^34][^9][^35]

The lack of per‑node masses and damping coefficients in the canonical d3‑force implementation explains why all nodes in such layouts tend to move and settle in the same way; this aligns with your observation of rigid, uniform stop behavior.[^36][^9]


### 3.2 Obsidian graph view

Obsidian does not publicly document the exact engine behind its 2D graph view, but community analysis on the Obsidian forum notes that the behavior is consistent with a standard force‑directed layout using modified Hooke’s‑law springs and Coulomb‑like repulsion, likely implemented via Verlet integration as in d3.js. The discussion points out that Obsidian probably uses link forces akin to d3’s link force and many‑body electrostatic repulsion with an inverse‑square law, plus a centering force to keep nodes within view. Obsidian exposes parameters very similar to d3‑force (link distance, repulsion strength, center force), supporting the hypothesis that its graph is essentially a tuned d3‑style engine rather than a fundamentally different fluid model.[^37][^34]

A community plugin, Obsidian 3D Graph, uses the 3d‑force‑graph library, which relies on Three.js for 3D rendering and either d3‑force‑3d or ngraph for physics. This again reinforces that mainstream note‑graph tools are using conventional force‑directed layouts with spring/repulsion physics.[^38][^39][^40]


### 3.3 Sigma.js, vis.js, Cytoscape.js

Sigma.js focuses on WebGL rendering and delegates layout to graphology, including ForceAtlas2 and a simpler "Force" layout. The graphology force layout is explicitly described as less scalable but "more organic" for small graphs and drag‑and‑drop interactions, trading global optimality for locally smooth motion. ForceAtlas2 itself is a continuous force‑directed layout with parameters for gravity, scaling, Barnes–Hut theta, and edge weight influence; several open implementations are available in graphology and Python.[^41][^6][^42][^7]

vis.js’s network module exposes physics solvers including a ForceAtlas2‑based mode with Barnes–Hut repulsion and tunable gravity, spring length, spring strength, and damping. The documentation notes that ForceAtlas2 mode uses a distance‑independent central gravity and linear repulsion; node masses are scaled by degree, which is directly relevant to your non‑uniform inertia requirement.[^43][^44][^45]

Cytoscape.js offers the CoSE (Compound Spring Embedder) and fCoSE layouts, spring‑embedder algorithms with support for compound graphs and non‑uniform node dimensions. These layouts emphasize compound node placement and overlap avoidance rather than fluid motion, but show how per‑node properties (size, containment) can be integrated into a force‑directed solver.[^46][^47]


### 3.4 Cosmograph / cosmos.gl and GPU layouts

Cosmograph is a large‑scale graph exploration tool that runs its force‑directed layout entirely on the GPU via WebGL shaders, powered by the cosmos.gl engine. The cosmos.gl documentation highlights parameters such as simulation friction, gravity, and repulsion, and notes that all computations and drawing occur on the GPU, enabling real‑time simulation of hundreds of thousands of points. Cosmograph’s concept docs describe using many‑body repulsion, spring forces, and gravity, but do not mention fluid fields or waves; the emphasis is on scaling classical force‑directed layouts rather than changing the qualitative behavior.[^5][^4]

Other projects like ParaGraphL similarly use WebGL GLSL shaders to compute Fruchterman–Reingold forces for large graphs, keeping CPU cost low by parallelizing forces on the GPU. For Epistemos, your existing Metal compute shader for N‑body repulsion is architecturally similar to these engines and can be extended to include additional per‑node forces (e.g., wave impulses) if needed.[^48][^36]


## 4. Target behaviors and mathematical models

This section specifies concrete models for the four behaviors: drag ripple, release wave settle, ambient breathing, and non‑uniform inertia. All are designed to compose with your existing velocity Verlet integrator and forces.

### 4.1 Notation and base integrator

Let each node i have position \(x_i \in \mathbb{R}^2\), velocity \(v_i\), mass \(m_i\), and damping coefficient \(\gamma_i\). Your existing integrator uses velocity Verlet with global decay; per d3‑force, a simplified form is:

\[
\begin{aligned}
 v_i^{t+1/2} &= (1 - \lambda) v_i^t + \Delta t \; a_i^t, \\
 x_i^{t+1} &= x_i^t + \Delta t \; v_i^{t+1/2},
\end{aligned}
\]

where \(a_i^t = F_i^t / m_i\) is total acceleration and \(\lambda\) is a global velocity decay factor. The proposed changes are:[^9]

- Replace global \(\lambda\) with per‑node damping \(\gamma_i\).
- Add new force terms for fluid ripple, wave settle, noise, and mass‑scaled response.
- Preserve existing spring, repulsion, collision, and center forces.

A convenient discrete Langevin‑style update is:

\[
\begin{aligned}
 a_i^t &= \frac{1}{m_i} (F_{\text{spr}} + F_{\text{rep}} + F_{\text{coll}} + F_{\text{cent}} + F_{\text{fluid}} + F_{\text{wave}} + F_{\text{noise}}), \\
 v_i^{t+1/2} &= (1 - \gamma_i \Delta t) v_i^t + \Delta t \; a_i^t, \\
 x_i^{t+1} &= x_i^t + \Delta t \; v_i^{t+1/2}.
\end{aligned}
\]

### 4.2 4a. Drag → Ripple via fluid grid coupling

Use your existing 64×64 FluidGrid as a low‑resolution velocity field \(u(x) \in \mathbb{R}^2\) over the viewport. Nodes sample this field and receive an additional fluid force proportional to the difference between the fluid velocity and their own velocity:[^49][^26][^32]

\[
F_{\text{fluid}, i} = k_f (u(x_i) - v_i),
\]

where \(k_f\) is a coupling constant.

#### 4.2.1 Fluid grid update

Maintain, per cell c, a velocity vector \(u_c\). On each physics tick:

1. **Injection from drag**: If the user is dragging node j with instantaneous drag velocity \(v_{\text{drag}}\), inject an impulse into the grid near \(x_j\):
   \[
   u_c \leftarrow u_c + w_c \, v_{\text{drag}},
   \]
   where \(w_c = \exp(-\|x_c - x_j\|^2 / (2 r_d^2))\) is a Gaussian kernel with drag radius \(r_d\).

2. **Diffusion and decay**: Apply a 9‑point diffusion stencil to approximate viscosity and spread the disturbance, similar to your existing implementation:[^26][^49]
   \[
   u_c^{\text{new}} = (1 - \nu - \mu) u_c + \nu \sum_{c' \in N(c)} w_{cc'} u_{c'},
   \]
   where \(\nu\) controls diffusion strength, \(w_{cc'}\) are normalized neighbor weights, and \(\mu\) is a global decay factor.

3. **Time integration**: Optionally integrate \(u\) forward with semi‑implicit Euler; for small \(\Delta t\) and moderate \(\nu\), the simple stencil above suffices.

This grid naturally creates a wave‑like velocity front that expands outward from the dragged node and decays over time. Near nodes experience velocity changes quickly; distant nodes are affected later as diffusion spreads the field, yielding the desired ripple.

#### 4.2.2 Node coupling and cutoff

For each node, sample \(u(x_i)\) via bilinear interpolation between the four surrounding cells, as you already do. Then compute \(F_{\text{fluid}, i}\) as above. To enforce a cutoff radius for the disturbance, modulate the coupling by the distance from the drag origin position \(x_0\) and the time since drag start \(t_0\):[^50][^49]

\[
F_{\text{fluid}, i} = k_f \, s(r_i, t) (u(x_i) - v_i),
\]

where \(r_i = \|x_i - x_0\|\) and a simple spatiotemporal envelope is:

\[
 s(r, t) = \exp(-r^2 / (2 R^2)) \cdot \exp(-(t - t_0)/\tau_\text{fluid}),
\]

with cutoff radius R and decay time \(\tau_\text{fluid}\). Nodes with \(r \gg R\) effectively ignore the fluid perturbation.


### 4.3 4b. Release → Wave settle via radial ring impulses

On release of a dragged node j, you want its overshoot and oscillation to propagate outward to neighbors as a damped wave. Model this as a set of expanding radial wavefronts that add transient spring‑like forces.

Maintain a list of active wave events, each with:

- origin position \(x_0\),
- start time \(t_0\),
- amplitude A,
- angular frequency \(\omega\),
- wave speed c,
- spatial decay \(\alpha\),
- temporal decay \(\beta\).

When the user releases node j at position \(x_j\) with release velocity \(v_j\), create a wave event with:

\[
A = k_A \|v_j\|, \quad \omega = 2\pi / T, \quad c = c_w,
\]

where T is the target initial oscillation period and \(c_w\) is a configurable wave propagation speed.

For a node i at time t, define

\[
 r_i = \|x_i - x_0\|, \quad \phi_i = \omega (t - t_0) - k r_i,
\]

where \(k = \omega / c_w\) is the radial wavenumber. The scalar wave envelope is:

\[
 W_i(t) = A \exp(-\alpha r_i) \exp(-\beta (t - t_0)) \sin(\phi_i).
\]

The corresponding force on node i is directed radially outward or inward from the origin:

\[
 F_{\text{wave}, i} = k_w W_i(t) \frac{x_i - x_0}{r_i + \varepsilon},
\]

where \(k_w\) scales the overall effect and \(\varepsilon\) avoids division by zero for the origin node.

- Near j, nodes feel the wave immediately; for larger \(r_i\), the phase \(\phi_i\) lags, producing the visible outward propagation.
- The exponential in r ensures distant nodes are only weakly affected.
- The exponential in t ensures the wave damps out after \(1–3\) seconds.

This ring‑wave model is conceptually similar to adding a transient radial force kernel around the release position, but the explicit sinusoid with temporal decay gives you a controllable oscillation count before rest.


### 4.4 4c. Ambient breathing via Perlin noise flow field

To make the graph "breathe" at rest, use Perlin noise to define a slowly varying vector field that applies small forces to nodes, with amplitude inversely proportional to node mass.[^30][^33][^29][^32]

Define a continuous noise function \(N: \mathbb{R}^3 \to [-1,1]^2\) that maps (x, y, t) to a 2D vector, implemented via a standard 2D or 3D Perlin/simplex noise library (you can reuse or port algorithms described in references). For node i at position x_i and time t, define a noise force:[^31][^51][^29][^30]

\[
 F_{\text{noise}, i} = a_0 \left( \frac{m_\text{ref}}{m_i} \right)^{p} N(\kappa x_i, \omega_t t),
\]

where:

- \(a_0\) is a base amplitude.
- \(m_\text{ref}\) is a reference mass (e.g., median mass).
- p controls how strongly mass affects amplitude.
- \(\kappa\) is spatial frequency (larger -> more rapid variation in space).
- \(\omega_t\) is temporal frequency (larger -> faster breathing).

Because Perlin noise is spatially coherent, nearby nodes see similar vectors, creating coherent drift instead of jitter. Using a low temporal frequency ensures the motion is slow and barely perceptible when the graph is otherwise at rest.[^33][^29][^32]


### 4.5 4d. Non‑uniform inertia via mass and damping scheduling

Use your existing per‑node mass array, derived from degree or other importance metrics, to scale both acceleration response and damping. Many graph layout engines (e.g., vis.js ForceAtlas2‑based solver) already scale node mass by degree plus one for better layouts; you can adopt a similar scheme.[^6][^43]

Define raw importance scores s_i (e.g., degree, semantic weight), then compute masses as:

\[
 m_i = m_\text{min} + (m_\text{max} - m_\text{min}) \frac{(s_i - s_\text{min})}{(s_\text{max} - s_\text{min} + \varepsilon)},
\]

clamped to [m_min, m_max]. Heavy nodes (high s_i) get large m_i.

Set damping coefficients as:

\[
 \gamma_i = \gamma_0 + \gamma_1 \left( \frac{m_i - m_\text{min}}{m_\text{max} - m_\text{min} + \varepsilon} \right)^q.
\]

Heavier nodes get higher damping, causing them to resist motion and settle more quickly; lighter nodes get lower damping and are more easily perturbed by fluid and noise forces.

Additionally, scale force responses selectively:

- For spring forces, keep magnitude independent of mass to preserve layout geometry.
- For fluid and noise forces, scale by \(1 / m_i\) or by a mass‑based factor to ensure leaves move much more than hubs.


## 5. Integration into your Rust/Metal stack

This section uses generic file/function names because the actual structure of your codebase is not publicly documented. The intent is to indicate the logical insertion points.

### 5.1 Physics tick pipeline

At each 60 Hz physics tick, perform the following in your Rust engine thread:

1. Update FluidGrid from user interactions (drag impulses) and diffusion/decay.
2. For each node:
   - Gather existing forces: springs, many‑body repulsion (CPU or GPU), collision, centering.
   - Sample FluidGrid for \(F_{\text{fluid}}\).
   - Evaluate active wave events for \(F_{\text{wave}}\).
   - Evaluate Perlin noise field for \(F_{\text{noise}}\).
   - Compute acceleration with mass scaling.
   - Integrate velocity and position using per‑node damping.
3. Apply viewport culling and send updated positions to Metal.


### 5.2 Suggested module‑level insertion points

Assuming a typical layout:

- `src/physics/integrator.rs` or similar: where your main `step(dt)` or `update(dt)` loop runs.
- `src/physics/forces.rs`: where link springs, repulsion, collision, and centering forces are computed.
- `src/physics/fluid_grid.rs`: your existing `FluidGrid` with velocity field and diffusion.
- `src/input/drag.rs` or equivalent: drag event handling and node selection.

Changes:

1. **Per‑node mass and damping** (section 4.5):
   - Add arrays `mass[i]` and `damping[i]` to your node state struct.
   - Compute `mass[i]` once when building the graph (e.g., from degree) and rescale using the formula above.
   - Compute `damping[i]` from `mass[i]` when building or when importance changes.
   - In the integrator, use `damping[i]` instead of a global decay factor.

2. **Fluid grid coupling** (section 4.2):
   - In `fluid_grid.rs`, expose `inject_impulse(position, velocity)` and `step(dt)`.
   - In the drag handler, call `FluidGrid::inject_impulse` each frame while dragging, using the node’s current position and pointer velocity.
   - In the physics tick, call `FluidGrid::step(dt)` before integrating nodes.
   - In `forces.rs` or the integrator, add `F_fluid[i] = k_f * s(r_i, t) * (u(x_i) - v[i])`.

3. **Wave events** (section 4.3):
   - Define a `WaveEvent` struct and an `ActiveWaves` collection in `physics/waves.rs`.
   - When a drag ends, create a `WaveEvent` with origin `x_j`, amplitude from release speed, and store current sim time.
   - Each physics tick, iterate over active events, evaluate `F_wave[i]` for nodes within a reasonable radius, and accumulate forces.
   - Remove events whose amplitude has decayed below a threshold.

4. **Ambient noise field** (section 4.4):
   - Add a small Perlin or simplex noise module, either pure Rust or via an existing crate that implements standard gradient noise.[^29][^30][^31]
   - In the physics tick, compute `F_noise[i]` from `N(kappa * x_i, omega_t * t)` and accumulate it.
   - Optionally share the same noise function with the FluidGrid (e.g., to modulate viscosity or add subtle vortices).

5. **GPU integration**:
   - For now, compute the new forces on CPU for node counts up to ~1500; only repulsion and perhaps FluidGrid diffusion need GPU acceleration.
   - Your existing Metal N‑body shader can remain unchanged; just adjust how you combine its output with CPU‑side forces.


## 6. Parameter ranges and perceptual tuning

The following ranges are intended as starting points for interactive tuning; exact values will depend on your world units (pixels vs. abstract units) and viewport scaling.

### 6.1 Mass and damping

- Mass range: \(m_\text{min} \in [0.5, 1.0]\), \(m_\text{max} \in [3.0, 6.0]\).
- Damping base: \(\gamma_0 \in [0.5, 1.0]\) (per second, scaled by dt in your integrator).
- Damping slope: \(\gamma_1 \in [0.5, 1.5]\), exponent \(q \in [0.5, 1.5]\).

Perceptually:

- Higher \(m_\text{max}\) makes hubs more stationary and resistant, emphasizing leaf motion.
- Higher \(\gamma_1\) causes heavy nodes to snap back quickly while light nodes continue to oscillate.

### 6.2 Fluid grid (drag ripple)

- Grid resolution: 64×64 (already chosen; sufficient for 50–1500 nodes).
- Drag radius \(r_d\): roughly 5–15% of the viewport diagonal.
- Diffusion \(\nu\): small, e.g. 0.05–0.2.
- Decay \(\mu\): 0.02–0.1 per tick.
- Fluid coupling \(k_f\): start small, e.g. 0.1–0.5 relative to spring strength.
- Envelope radius R: 25–50% of viewport diagonal.
- Envelope time constant \(\tau_\text{fluid}\): 0.5–1.5 seconds.

Perceptually:

- Larger \(r_d\) and R create broader, slower waves; smaller values confine ripples near the drag.
- Higher \(k_f\) makes the graph feel more like a liquid sheet; too high and the layout becomes mushy.

### 6.3 Wave settle

- Initial oscillation period T: 0.6–1.2 seconds.
- Wave speed \(c_w\): choose so that a wavefront traverses the visible graph in about 0.5–1.0 seconds.
- Spatial decay \(\alpha\): 0.5–2.0 (in inverse world units).
- Temporal decay \(\beta\): choose so that the envelope decays to ~1% after 1–3 seconds.
- Wave amplitude scale \(k_A\): start such that a moderately fast release produces ~5–15% overshoot in position.

Perceptually:

- Lower T yields snappier, springy rebounds; higher T feels sluggish.
- Larger \(\alpha\) tightly localizes waves; smaller \(\alpha\) produces global pulses.

### 6.4 Ambient breathing (noise)

- Base amplitude \(a_0\): 0.01–0.05 times typical spring force magnitude.
- Mass exponent p: 0.5–1.5 (larger = stronger mass contrast).
- Spatial frequency \(\kappa\): make the noise vary over distances comparable to 20–50% of viewport; too high causes fine‑grained twitching.[^32][^33][^29]
- Temporal frequency \(\omega_t\): cycle every 10–30 seconds for subtle breathing.

Perceptually:

- If \(a_0\) is too low, the effect is imperceptible; too high and the graph never feels at rest.
- Lower \(\omega_t\) feels like slow drift; higher \(\omega_t\) feels like nervous jitter.


## 7. Performance considerations

### 7.1 Complexity

- Existing forces: springs and collisions are O(E + V), Barnes–Hut repulsion is O(V log V) per tick.[^52][^35][^36]
- FluidGrid: 64×64 grid implies 4096 cells; the 9‑point diffusion stencil is O(cells) ≈ 4000 operations per tick, negligible compared to per‑node forces.[^49][^26]
- Wave events: each event adds O(V) work in the worst case; in practice, limit active events to a small number (e.g. last 3 releases) and attenuate by distance so that distant nodes can be skipped when \(W_i(t)\) is effectively zero.
- Perlin noise: evaluating a noise function per node is O(V); high‑quality implementations are fast enough for hundreds to low thousands of evaluations per frame.[^51][^30][^31][^29]

For 500–1500 nodes, the added O(V) terms (noise and wave) should be small relative to existing O(V log V) repulsion and should fit within your 2–5 ms budget when implemented with SIMD and carefully tuned.


### 7.2 SIMD and GPU opportunities

- **SIMD**:
  - Node‑wise operations (noise, fluid coupling, damping, integration) are ideal for NEON SIMD; structure your node arrays as SoA (separate x[], y[], vx[], vy[], mass[], damping[]) to maximize vectorization.
  - Wave computations involve simple arithmetic per node and can also be SIMD‑friendly.

- **GPU (Metal compute)**:
  - Continue to compute many‑body repulsion on GPU as you already do; this is the dominant cost at higher node counts.[^35][^4][^5]
  - Optionally move FluidGrid diffusion to a small Metal compute shader operating on a 64×64 texture or buffer; this is similar to GPU LBM implementations, but simpler.[^26]
  - If CPU becomes a bottleneck for noise or wave forces at 1500+ nodes, consider computing these forces in the same Metal kernel that performs repulsion and writing them into a per‑node force buffer.

### 7.3 Degradation above 1500 nodes

For 1500+ nodes, adopt a static layout + ambient motion strategy, similar to how other engines fall back to static ForceAtlas2 layouts with gentle transitions. Concretely:[^7][^6]

- Precompute a stable layout offline or during idle using your current force engine.
- Disable FluidGrid and wave events; keep only low‑amplitude ambient Perlin noise.
- Optionally freeze heavy hub nodes entirely and allow only light leaf nodes to drift.

This maintains the "alive" feeling without incurring heavy per‑frame computation.


## 8. Test scenarios and interaction patterns

To validate the feel and performance, test in the following scenarios.

### 8.1 Node count tiers

- **50 nodes**: small, dense conceptual cluster. Expect strong visible ripples and waves; tune so that the whole cluster visibly "sloshes" when a central node is dragged and released.
- **200–500 nodes**: typical working knowledge graph. Ensure:
  - Drag ripple propagates out over ~0.5 seconds and decays gracefully.
  - Release waves produce 1–3 visible oscillations before rest.
  - Ambient breathing is visible when zoomed in but not distracting when zoomed out.
- **1000–1500 nodes**: stress test. Focus on maintaining sub‑5 ms physics ticks and avoiding numerical instabilities; reduce amplitudes of fluid and noise forces if needed.


### 8.2 Interaction patterns

- **Single‑node drag in sparse region**: drag a light, low‑degree node at the periphery quickly and release. Expected:
  - Local neighbors follow with a noticeable delay.
  - Distant nodes barely move.

- **Single‑node drag in hub region**: drag a high‑degree hub in a dense cluster. Expected:
  - The hub barely leaves its approximate position due to high mass and damping.
  - Surrounding lighter nodes swirl and flow around it, showing strong non‑uniform inertia.

- **Repeated oscillation**: repeatedly drag and release a node along the same axis at varying speeds. Expected:
  - Wave amplitude correlates with release velocity.
  - Waves do not stack explosively because temporal decay \(\beta\) prevents long‑term energy buildup.

- **Idle behavior**: leave the graph untouched for 30–60 seconds. Expected:
  - Nodes exhibit subtle, coherent drift in small patches due to Perlin noise.
  - Hubs remain almost stationary.

- **Zoom and pan**: while the graph breathes and waves settle, zoom and pan the camera. Ensure that the perceived motion scales appropriately with zoom and does not cause discomfort.


## 9. Reference implementations and code to study

While there is no single open‑source implementation that exactly matches the desired feel, the following projects provide concrete patterns for each component.

### 9.1 Force‑directed layouts and non‑uniform inertia

- **Graphology ForceAtlas2 / Force layout**: graphology’s ForceAtlas2 implementation and its simpler "Force" layout show how to implement continuous layouts with Barnes–Hut and node‑dependent masses, and note that the simpler Force layout yields more organic movement for small graphs.[^42][^6][^7]
- **vis.js network physics**: vis.js’s physics documentation and options demonstrate how to expose gravity, dampening, spring length/strength, and ForceAtlas2‑based solvers to users, including degree‑based node mass scaling.[^44][^45][^43]
- **Cosmograph / cosmos.gl**: cosmos.gl’s GPU‑accelerated force graph engine shows how to compute layout entirely in WebGL shaders with configurable friction, repulsion, and gravity; the Cosmograph docs explain the conceptual forces and how they are mapped to GPU.[^4][^5]
- **Rust ForceAtlas2 crate**: the `forceatlas2` crate implements ForceAtlas2 in Rust and can serve as a reference or even a fallback layout engine for Epistemos.[^53]


### 9.2 Fluid grids, waves, and flow fields

- **LBM GPU examples**: GPU Gems chapter on Lattice Boltzmann shows how to evolve fluid quantities on a 2D grid with diffusion and streaming in shaders; while more complex than needed, the grid update patterns are similar to what your FluidGrid already does.[^25][^24][^26]
- **Perlin noise flow fields**: tutorials on Perlin noise flow fields and vector fields demonstrate using coherent noise to define a force direction at each point on a canvas and advect particles through it for organic motion.[^33][^32]
- **Ambient noise generators**: the `ambient` package in R and Perlin noise articles document multi‑octave Perlin/simplex noise and fractional Brownian motion; these can guide your choice of noise frequencies and amplitudes.[^30][^51][^29]


### 9.3 Graph visualization stacks similar to Obsidian and Google

- **d3‑force**: the d3‑force and force simulation docs describe the velocity Verlet integrator, global velocity decay, and force modules used in many web graph visualizations.[^34][^9]
- **3d‑force‑graph**: this Three.js/WebGL component uses d3‑force‑3d or ngraph for physics and underlies plugins like Obsidian 3D Graph; its source shows how drag forces are integrated with the simulation.[^39][^40]
- **Obsidian community discussion**: the Obsidian forum thread on graph view physics explains how Hooke’s‑law springs and Coulomb repulsion can be implemented to match Obsidian’s behavior, confirming that their engine is essentially a tuned force‑directed layout.[^37]


## 10. Summary of design choices

The specification above deliberately avoids full SPH or LBM fluid simulation, instead using a lightweight 2D velocity grid, radial wavefronts, Perlin noise fields, and mass‑dependent damping to achieve a water‑like, breathing graph. These techniques draw directly from well‑understood fluid and stochastic models but are tuned for the performance envelope of interactive graph layouts. By integrating them into your existing Rust + Metal force engine, Epistemos can offer a distinctive, fluid interaction model that goes beyond conventional d3‑style snapping while remaining controllable, performant, and physically interpretable.[^22][^21][^24][^26][^29][^32][^33]

---

## References

1. [Motion – Material Design 3](https://m3.material.io/styles/motion/overview/how-it-works) - A motion system designed for expression. May 2025. Material introduced the motion physics system wit...

2. [Material 3 Expressive: New Components, Motion, Shapes, and More](https://supercharge.design/blog/material-3-expressive) - It's a smarter, more expressive, and more adaptive way to build modern user interfaces, from mobile ...

3. [What is Material Design? — updated 2026 | IxDF](https://ixdf.org/literature/topics/material-design) - It introduces spring-like motion—animations that bounce, stretch, and respond to touch more organica...

4. [cosmosgl/graph: GPU-accelerated force graph layout and rendering](https://github.com/cosmosgl/graph) - Cosmos.gl is a high-performance WebGL Force Graph algorithm and rendering engine. All the computatio...

5. [The Concept of Cosmograph](https://cosmograph.app/docs-general/concept/) - Cosmograph combines several technologies to achieve high-performance graph visualization: cosmos.gl ...

6. [graphology-layout-forceatlas2 - NPM](https://www.npmjs.com/package/graphology-layout-forceatlas2) - ForceAtlas2, a Continuous Graph Layout Algorithm for Handy Network Visualization Designed for the Ge...

7. [Graphology Force layout](https://graphology.github.io/standard-library/layout-force.html) - JavaScript implementation of a basic force directed layout algorithm for graphology. In some few cas...

8. [Material Design Motion - YouTube](https://www.youtube.com/watch?v=cQzien5H2Do) - Check out the new Motion section in the Material Design Guidelines at g.co/design/motion. ... Implem...

9. [Force simulations | D3 by Observable](https://d3js.org/d3-force/simulation) - A force simulation implements a velocity Verlet numerical integrator for simulating physical forces ...

10. [Understanding motion - Material Design](https://m2.material.io/design/motion/understanding-motion.html) - Motion design informs users by highlighting relationships between elements, action availability, and...

11. [The Material Design Motion Guidelines - Sharon Harris - Dribbble](https://dribbble.com/shots/2713947-The-Material-Design-Motion-Guidelines) - The Material Design Motion guidelines is out in the world! Material motion is responsive, natural, a...

12. [Google NotebookLM Guide 2025: Master Research & Workflow](https://tech-now.io/en/blogs/google-notebooklm-guide-2025-the-ai-knowledge-companion-for-2025) - Personalized knowledge graph: A long-term vision is for NotebookLM to evolve into a continuous, pers...

13. [NotebookLM: The Complete Guide - Wonder Tools](https://wondertools.substack.com/p/notebooklm-the-complete-guide) - NotebookLM is the most useful free AI tool of 2025. It has twin superpowers. You can use it to find,...

14. [Google I/O 2025: How Gemini AI Is Reshaping Marketing & Creativity](https://adgpt.com/blog/google-io-2025-how-gemini-ai-is-reshaping-marketing-creativity) - Google I/O 2025 signals a major AI shift. Learn how Gemini, AI search, and shopping innovations will...

15. [Google Research at Google I/O 2025](https://research.google/blog/google-research-at-google-io-2025/) - We celebrate Google Research highlights from I/O 2025, including our latest research breakthroughs a...

16. [At I/O 2025, Google Reimagines Search with AI Mode](https://virtualizationreview.com/articles/2025/05/20/at-io-2025-google-reimagines-search-with-ai-mode.aspx) - Custom Charts and Graphs: AI Mode can generate interactive, query-specific data visualizations--such...

17. [NotebookLM Review: Best Features 2025 For Researchers](https://effortlessacademic.com/googles-notebooklm-updates-in-2025-for-literature-review-and-study/) - NotebookLM the perfect companion for literature reviews, allowing you to create mind maps, synthesiz...

18. [Expanding AI Overviews and introducing AI Mode - Google Blog](https://blog.google/products-and-platforms/products/search/ai-mode-search/) - You can not only access high-quality web content, but also tap into fresh, real-time sources like th...

19. [Motion physics system - Material Design](https://m3.material.io/styles/motion/overview/specs) - The motion physics system is available on Jetpack Compose and MDC-Android, and can be easily adapted...

20. [Building Beautiful Transitions with Material Motion for Android](https://developer.android.com/codelabs/material-motion-android) - This codelab will guide you through building some transitions into an example Android email app call...

21. [Accelerating smoothed particle hydrodynamics with graph neural ...](https://www.epcc.ed.ac.uk/whats-happening/articles/accelerating-smoothed-particle-hydrodynamics-graph-neural-networks) - Smoothed particle hydrodynamics (SPH) is a meshless alternative to traditional CFD that foregoes the...

22. [15.2.1 Smoothed particle hydrodynamics](https://ceae-server.colorado.edu/v2016/books/usb/pt04ch15s02aus96.html) - The smoothed particle hydrodynamic method is implemented via the formulation associated with PC3D el...

23. [[PDF] Smooth Particle Hydrodynamics (SPH) - Penn State](https://personal.ems.psu.edu/~fkd/courses/EGEE520/2017Deliverables/SPH_2017.pdf) - ➢ The basic idea of the meshfree methods is to discretize the continuum through a set of nodes witho...

24. [The Lattice Boltzmann Method (LBM) in CFD | SimWiki - SimScale](https://www.simscale.com/docs/simwiki/cfd-computational-fluid-dynamics/lattice-boltzmann-method-lbm/) - Lattice Boltzmann Method (LBM) simulates fluid dynamics on a macroscopic scale based on kinetic equa...

25. [[PDF] The lattice-boltzmann method for simulating gaseous phenomena](https://www3.cs.stonybrook.edu/~mueller/papers/smokeTVCG04.pdf) - We introduce the Lattice Boltzmann Model (LBM), which simulates the microscopic movement of fluid pa...

26. [Chapter 47. Flow Simulation with Complex Boundaries](https://developer.nvidia.com/gpugems/gpugems2/part-vi-simulation-and-numerical-algorithms/chapter-47-flow-simulation-complex) - In this chapter, we present a physically plausible yet fast fluid flow simulation approach based on ...

27. [Decentralized Langevin Dynamics over a Directed Graph - arXiv](https://arxiv.org/abs/2103.05444) - Langevin dynamics as a tool for high dimensional sampling and posterior Bayesian inference has been ...

28. [Casimir-force-driven ratchets.](https://link.aps.org/doi/10.1103/PhysRevLett.98.160801) - We explore the nonlinear dynamics of two parallel periodically patterned metal surfaces that are cou...

29. [Perlin noise - Wikipedia](https://en.wikipedia.org/wiki/Perlin_noise) - Perlin noise is a type of gradient noise developed by Ken Perlin in 1982. It has many uses, includin...

30. [Perlin Noise Explained: Meaning, Features, & Workflow](https://www.foxrenderfarm.com/share/what-is-perlin-noise/) - Perlin Noise: Can show grid-aligned or directional patterns, especially at low resolution or high fr...

31. [Perlin Noise: A Procedural Generation Algorithm - Raouf's blog](https://rtouti.github.io/graphics/perlin-noise-algorithm) - Perlin noise is a popular procedural generation algorithm invented by Ken Perlin. It can be used to ...

32. [Getting Creative with Perlin Noise Fields - Sighack](https://sighack.com/post/getting-creative-with-perlin-noise-fields) - Think of the canvas as a two-dimensional force field. Each point on the canvas is assigned a directi...

33. [Perlin Noise - Flow Field - David's Raging Nexus](https://ragingnexus.com/creative-code-lab/experiments/perlin-noise-flow-field/) - We're building a grid of force vectors, spread out across the canvas into which we drop individual p...

34. [d3-force | D3 by Observable - D3.js](https://d3js.org/d3-force) - Force simulations can be used to visualize networks and hierarchies, and to resolve collisions as in...

35. [The Barnes-Hut Approximation](https://jheer.github.io/barnes-hut/) - The key idea is to approximate long-range forces by replacing a group of distant points with their c...

36. [Force-directed graph drawing - Wikipedia](https://en.wikipedia.org/wiki/Force-directed_graph_drawing) - Their purpose is to position the nodes of a graph in two-dimensional or three-dimensional space so t...

37. [Graph view, physics, and force directed graphs - Obsidian Forum](https://forum.obsidian.md/t/graph-view-physics-and-force-directed-graphs/72586) - The great thing about force directed graphs is that they're easy to write. You just need a basic phy...

38. [Apoo711/obsidian-3d-graph: Visualize your vault in 3D with ... - GitHub](https://github.com/Apoo711/obsidian-3d-graph) - A plugin for Obsidian that provides a highly customizable 3D, force-directed graph view of your vaul...

39. [3D Force-Directed Graph - GitHub Pages](https://vasturiano.github.io/3d-force-graph/) - Can be used to extend the current scene with additional objects not related to 3d-force-graph. camer...

40. [3D force-directed graph component using ThreeJS/WebGL - GitHub](https://github.com/vasturiano/3d-force-graph) - Can be used to extend the current scene with additional objects not related to 3d-force-graph. camer...

41. [Sigma.js](https://www.sigmajs.org) - Sigma.js is a modern JavaScript library for rendering and interacting with network graphs in the bro...

42. [Fastest Gephi's ForceAtlas2 graph layout algorithm implemented for ...](https://github.com/bhargavchippada/forceatlas2) - ForceAtlas2 is a force-directed layout algorithm designed for network visualization. It spatializes ...

43. [Physics documentation. - vis.js](https://visjs.github.io/vis-network/docs/network/physics.html) - Network - physics. Handles the physics simulation, moving the nodes and edges to show them clearly. ...

44. [Physics Parameters and the Barnes Hut Algorithm Options (PyVis ...](https://www.youtube.com/watch?v=r8RC1kmdCiQ) - In this video, I go through each of the parameters in the physics options buttons and speak specific...

45. [Vis Network | Physics | Playing with Physics](https://visjs.github.io/vis-network/examples/network/physics/physicsConfiguration.html) - The network configurator can be used to explore which settings may be good for him or her. This is m...

46. [The CoSE layout for Cytoscape.js by Bilkent with enhanced ... - GitHub](https://github.com/cytoscape/cytoscape.js-cose-bilkent) - A spring embedder layout with support for compound graphs (nested structures) and varying (non-unifo...

47. [Cytoscape.js & cose-bilkent: optimal parameters for preventing node ...](https://stackoverflow.com/questions/60991222/cytoscape-js-cose-bilkent-optimal-parameters-for-preventing-node-edge-overl) - Neither cose-bilkent nor fcose has a mechanism to prevent edge overlaps. It is actually hard to achi...

48. [ParaGraphL | WebGL-powered Parallel Large-scale Graph Layout ...](https://nblintao.github.io/ParaGraphL/) - We use the GLSL on WebGL to do general purpose computation for a force-directed graph layout algorit...

49. [[PDF] Computational System for Visualization and Lattice Boltzmann Fluid ...](http://www.decom.ufop.br/sibgrapi2012/eproceedings/wuw/102790_1.pdf) - Abstract—This work focus on scientific visualization techniques and fluid simulation via Lattice Bol...

50. [[PDF] WebGL-Enabled Remote Visualization of Smoothed Particle ...](https://diglib.eg.org/bitstream/handle/10.2312/eurovisshort.20151116.001-005/001-005.pdf?sequence=1) - We combine WebGL volume rendering rendering with data compression and intel- ligent streaming to pro...

51. [[PDF] ambient: A Generator of Multidimensional Noise - CRAN](https://cloud.r-project.org/web/packages/ambient/ambient.pdf) - The 'ambient' package provides an interface to the 'FastNoise' C++ library and allows for efficient ...

52. [Barnes–Hut simulation - Wikipedia](https://en.wikipedia.org/wiki/Barnes%E2%80%93Hut_simulation) - The Barnes–Hut simulation (named after Joshua Barnes and Piet Hut) is an approximation algorithm for...

53. [forceatlas2 - crates.io: Rust Package Registry](https://crates.io/crates/forceatlas2) - Implementation of ForceAtlas2 – force-directed Continuous Graph Layout Algorithm for Handy Network V...

