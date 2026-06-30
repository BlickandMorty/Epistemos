# AGENT FARM — MASTER BUILD DOC (finalized 2026-06-30)

> The capstone. Distills **8 research efforts** (3 adversarial deep-research passes + Gemini-1/2 + Claude + GPT-1/2) into
> a build-ready spec **with code**. Design is SETTLED; remaining risk is engineering only. Companions:
> `AGENT_FARM_SYNTHESIS_2026_06_30.md` (the convergence) · `AGENT_FARM_RESEARCH_REPORT_2026_06_30.md` (verified findings) ·
> `PROMPT_AGENT_FARM_BUILD.md` (the paste-ready loop prompt). **Separate app from Epistemos — does not touch its code.**

---

## 0. THE SHELL — what you actually start with (the question you asked)

**It is NOT Tauri / Electron / a webview.** Those host a *web* UI in a native window — the exact "web-in-a-shell" you're
escaping, and they cannot render a 2D ECS agent world with custom shaders. **The shell IS the Bevy app: one native Rust
binary.** On macOS it builds to a `.app` via `cargo` (use `cargo-bundle` for the icon/Info.plist). Cross-platform later
for free via wgpu (Mac=Metal, Win=DX12, Linux=Vulkan; web=wasm with caveats).

**Native vs usefulness is a false tradeoff here:** the usefulness comes from the AGENTS (budget economy + real artifacts),
NOT from a web UI. Native Bevy gives you both — the frosted 2D world *and* the useful society. Go native.

```toml
# Cargo.toml — pin EXACT versions (Bevy 0.x churns every ~3 months; the research flagged this).
[dependencies]
bevy             = { version = "0.15", features = ["bevy_winit","bevy_ui","bevy_sprite","bevy_render","webgpu"] }
window-vibrancy  = "0.5"          # NSVisualEffectView (mac) / Mica/Acrylic (win) — the frost
bevy_egui        = "0.31"         # DEBUG/dev tooling ONLY, never the product surface
crossbeam-channel = "0.5"         # the brain<->ECS bridge
rusqlite         = { version = "0.32", features = ["bundled"] }  # per-agent vault + memory.db
# brain sidecar deps live in the sidecar crate, not here (keep the engine lean)
```

```rust
// src/shell.rs — the entire shell. A transparent, borderless, vibrancy-backed native window.
use bevy::prelude::*;
use bevy::window::CompositeAlphaMode;
use bevy::winit::WinitWindows;

pub fn shell_plugin(app: &mut App) {
    app.insert_resource(ClearColor(Color::NONE))               // transparent → OS frost shows through
       .add_plugins(DefaultPlugins.set(WindowPlugin {
           primary_window: Some(Window {
               transparent: true,
               decorations: false,                              // borderless "widget"
               #[cfg(target_os = "macos")]
               composite_alpha_mode: CompositeAlphaMode::PostMultiplied,
               titlebar_shown: false,
               resolution: (960.0, 680.0).into(),
               present_mode: bevy::window::PresentMode::AutoNoVsync, // 120fps TARGET (profile! ship 60 if it won't hold)
               ..default()
           }),
           ..default()
       }))
       .add_systems(Startup, apply_native_vibrancy);
}

// window-vibrancy must run AFTER the window exists; WinitWindows is the bridge to the real OS window.
fn apply_native_vibrancy(winit: NonSend<WinitWindows>, q: Query<Entity, With<Window>>) {
    for e in &q {
        let Some(win) = winit.get_window(e) else { continue };
        #[cfg(target_os = "macos")]
        { use window_vibrancy::{apply_vibrancy, NSVisualEffectMaterial};
          let _ = apply_vibrancy(win, NSVisualEffectMaterial::HudWindow, None, None); }
        #[cfg(target_os = "windows")]
        { let _ = window_vibrancy::apply_mica(win, None); }
        // Linux blur is compositor-dependent — fall back to the shader-frost (§5) there.
    }
}
```
> ⚠️ **Honest flags (all source-backed):** native vibrancy is solid on mac/win, compositor-dependent on Linux, absent on
> web (use the shader-frost fallback there). 120fps on macOS ProMotion has open Bevy bugs — *profile on real hardware,
> ship 60 if 120 won't hold.* Exact Bevy API names (`delta_seconds` vs `delta_secs`, etc.) drift per version — **pin and adjust.**

---

## 1. THE SETTLED DESIGN (one screen, all flags)
A **budgeted production society** — minimal world, STRONG economics is the spine. Mascots feel alive via cheap drives;
they're USEFUL because scarce budget forces real, inspectable artifacts.
- **Two-speed mind:** cheap Rust ECS every tick (drives/needs/movement/memory-retrieval-math/budget-ledger) · slow LLM
  async on triggers (reflection/planning/artifact-writing/conversation). *Aliveness = cheap motion that LOOKS spontaneous.*
- **Brain = Generative-Agents** (memory stream + reflection + planning, all three) **+ Sims utility-AI drives.** Verified
  constants: recency decay **0.995**, reflection threshold **150**.
- **Economy = closed compute-budget; EVE faucet/sink discipline** (every mint has a sink) + **AP2 mandates**
  (Intent→Cart→settle, deterministic in Rust) + per-agent caps + a **VERIFIER role** (reward releases only on a pass —
  this is the *believable→useful* fix). Anti-exploit: demurrage/upkeep, novelty/dup detector, no recursive self-purchase.
- **Brains = Hermes as an out-of-process WORKER** (NOT world-host; Hermes-4-*chat* isn't for agent work — use the
  function-calling variant). **MoA offline-only** (slow + Self-MoA contests it) for the "produce serious research" path.
- **Frameworks = MINE, don't fork** (all Python/TS, stack-mismatched) — lift IDEAS (memory formula, Voyager skill-library,
  PIANO concurrency, elizaOS character-JSON, CAMEL inception-prompting), build the Rust runtime FRESH.
- **World = 6 affordances** (board · vault · shop · server/tool · meeting spot · messaging) + **"state permanence beneath
  visual impermanence"** (dissolve in the render; persist in the data layer; spotlight to summon any object).
- **Don't over-promise emergence** (contested/validation-weak) — seed reputation + gossip; don't bet on de-novo institutions.

---

## 2. CORE CODE — the verified pieces (idiomatic Bevy; pin + adjust to your version)

### 2a. The two-speed schedule
```rust
app.add_systems(FixedUpdate, (              // CHEAP, deterministic, every fixed step (~10 Hz is plenty for sim logic)
        decay_needs, score_and_pick_action, move_agents,
        retrieve_memory, settle_ledger, accrue_upkeep, maybe_trigger_reflection,
    ).chain())
   .add_systems(Update, (                    // render-rate
        poll_cognition_results,              // pull finished LLM work back into ECS
        dispatch_cognition_on_trigger,       // push expensive work OUT to the sidecar
        animate_transitions,                 // blur/dissolve interpolation
    ));
```

### 2b. Sims-style drives (cheap, every tick — the "spontaneity" layer)
```rust
#[derive(Component)]
struct Needs { energy: f32, curiosity: f32, social: f32, thrift: f32 } // 0..1

fn decay_needs(time: Res<Time>, mut q: Query<&mut Needs>) {
    let dt = time.delta_seconds();
    for mut n in &mut q {
        n.energy    = (n.energy    - 0.020 * dt).clamp(0.0, 1.0);
        n.curiosity = (n.curiosity + 0.030 * dt).clamp(0.0, 1.0); // grows → pushes toward research
        n.social    = (n.social    + 0.015 * dt).clamp(0.0, 1.0);
    }
}

// Infinite-Axis Utility AI (Dave Mark): each candidate action scores its appeal from current needs; pick the argmax.
fn score_and_pick_action(mut q: Query<(&Needs, &Wallet, &mut Intent)>) {
    for (n, w, mut intent) in &mut q {
        let research = n.curiosity * 0.9 + (w.balance > 100.0) as i32 as f32 * 0.1;
        let socialize = n.social * 0.8;
        let earn = (1.0 - (w.balance / w.daily_cap).min(1.0)) * 0.7; // broke → want to earn
        let rest = (1.0 - n.energy) * 1.0;
        *intent = [(Action::Research, research), (Action::Socialize, socialize),
                   (Action::Earn, earn), (Action::Rest, rest)]
            .into_iter().max_by(|a,b| a.1.total_cmp(&b.1)).map(|(a,_)| Intent(a)).unwrap();
    }
}
```

### 2c. Generative-Agents memory retrieval (deterministic, ZERO LLM at retrieval — the verified core)
```rust
const RECENCY_DECAY: f64 = 0.995;            // VERIFIED from the paper

struct Memory { text: String, emb: Vec<f32>, importance: f32 /*1..10*/, last_access: f64, created: f64 }
#[derive(Component)] struct MemoryStream(Vec<Memory>);

fn retrieval_score(m: &Memory, now_game_hours: f64, query_emb: &[f32]) -> f32 {
    let recency   = RECENCY_DECAY.powf(now_game_hours - m.last_access) as f32; // since last ACCESS, not creation
    let importance = m.importance / 10.0;
    let relevance  = cosine(&m.emb, query_emb);
    recency + importance + relevance        // weights all = 1 (paper); min-max normalize before summing if you prefer
}
fn cosine(a: &[f32], b: &[f32]) -> f32 {
    let (mut d, mut na, mut nb) = (0.0, 0.0, 0.0);
    for i in 0..a.len() { d += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i]; }
    if na == 0.0 || nb == 0.0 { 0.0 } else { d / (na.sqrt()*nb.sqrt()) }
}
```

### 2d. Reflection trigger (the slow-LLM cadence — importance budget 150)
```rust
const REFLECTION_THRESHOLD: f32 = 150.0;     // VERIFIED
#[derive(Component, Default)] struct ReflectBudget(f32);

fn maybe_trigger_reflection(mut q: Query<(Entity, &mut ReflectBudget)>, mut tx: EventWriter<TriggerCognition>) {
    for (e, mut b) in &mut q {
        if b.0 >= REFLECTION_THRESHOLD {     // ~2–3×/agent/day in practice
            b.0 = 0.0;
            tx.send(TriggerCognition { agent: e, kind: Cognition::Reflect }); // → sidecar (§2f)
        }
    }
}
```

### 2e. Budget economy: AP2 Intent→Cart→settle, all deterministic in Rust
```rust
#[derive(Component)] struct Wallet { balance: f64, daily_cap: f64, spent_today: f64, max_hold: f64 }
#[derive(Component)] struct IntentMandate { goal: String, max_cost: f64, category: Category, ttl: f64 }
struct CartMandate { item: ItemId, price: f64 }                  // a shop writes this after matching an Intent
#[derive(Event)] struct LedgerEntry { agent: Entity, amount: f64, reason: &'static str } // immutable audit

fn settle_ledger(mut q: Query<(Entity, &mut Wallet, &IntentMandate, &CartMandate)>,
                 mut ledger: EventWriter<LedgerEntry>) {
    for (e, mut w, intent, cart) in &mut q {
        let ok = cart.price <= intent.max_cost                  // within the mandate cap
              && w.spent_today + cart.price <= w.daily_cap       // within the daily cap (Stripe-Issuing model)
              && w.balance >= cart.price;                        // can afford
        if ok {
            w.balance -= cart.price; w.spent_today += cart.price; // SINK: this budget is BURNED (compute spent)
            ledger.send(LedgerEntry { agent: e, amount: -cart.price, reason: "purchase" });
            // grant the item/tool/skill to the agent here
        }
    }
}
// Anti-exploit (run periodically): demurrage on idle balance; recycle anything over max_hold to treasury;
// novelty-check artifacts before minting reward; NO endpoint that lets an agent mint its own budget.
```

### 2f. The brain SIDECAR bridge (out-of-process — the CONSENSUS, never PyO3 on the hot path)
```rust
use crossbeam_channel::{unbounded, Sender, Receiver};
#[derive(Resource)] struct Brain { tx: Sender<CogReq>, rx: Receiver<CogResp> }

// Startup: spawn the worker (a thread that owns a tokio runtime + reqwest to the Hermes sidecar/local server,
// OR a gRPC client to a separate Python process). It does the BLOCKING LLM call off the frame thread.
fn spawn_brain(mut commands: Commands) {
    let (req_tx, req_rx) = unbounded::<CogReq>();
    let (res_tx, res_rx) = unbounded::<CogResp>();
    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        while let Ok(req) = req_rx.recv() {
            let res = rt.block_on(call_hermes_worker(req));  // Hermes function-calling variant; structured JSON out
            let _ = res_tx.send(res);
        }
    });
    commands.insert_resource(Brain { tx: req_tx, rx: res_rx });
}
fn dispatch_cognition_on_trigger(brain: Res<Brain>, mut ev: EventReader<TriggerCognition>, q: Query<&AgentState>) {
    for t in ev.read() { if let Ok(s) = q.get(t.agent) {
        let _ = brain.tx.send(CogReq { agent: t.agent, kind: t.kind, state: s.serialize() }); } }
}
fn poll_cognition_results(brain: Res<Brain>, mut commands: Commands) {
    while let Ok(resp) = brain.rx.try_recv() {
        // apply resp INSTANTLY: write a Plan, append a Memory+importance, emit a CartMandate, write a markdown artifact, etc.
    }
}
```
> The frame thread NEVER blocks on an LLM. The worker can be an in-binary thread (simplest) or a separate process over
> gRPC/Tonic (best isolation — a crashing brain doesn't kill the render). Start in-binary; move to gRPC if you need isolation.

### 2g. The VERIFY loop (believable→useful — a worker drafts, a verifier passes/fails, reward releases on pass)
```rust
// In the sidecar: worker drafts the artifact → a DIFFERENT (cheap "judge") model critiques (cap 3–5 turns) →
// pass/fail. Only on PASS does the ECS mint reward into the author's Wallet (with a novelty check vs the board).
// This makes quality control an in-world JOB that earns budget. Do NOT skip it — it's what makes artifacts useful.
```

---

## 3. SHADERS — frosted blur + noise dissolve (the "calm app" feel)
Two WGSL passes (the reports verified both via Bevy's `custom_post_processing` + `Material2d` examples):
- **Screen-space Gaussian blur** post-process behind UI panels (the frosted look) — 7-tap separable blur reading the main
  pass texture. (Use `bevy_blur_regions` to mark blurred UI nodes, or hand-roll the post-process node.)
- **Per-entity noise dissolve** `Material2d`: a `VisualTransition(f32)` component interpolates 0→1; the fragment shader
  `discard`s pixels where `noise(uv) < threshold`, with a glowing edge band. ECS inserts/removes the structural component
  INSTANTLY; only the *visual* lerps. (Full WGSL is in the owner's GPT-1 report — lift it verbatim.)

```rust
#[derive(Component)] struct VisualTransition { t: f32, dir: f32 } // dir +1 reveal, -1 dissolve
fn animate_transitions(time: Res<Time>, mut q: Query<&mut VisualTransition>) {
    for mut v in &mut q { v.t = (v.t + v.dir * 2.5 * time.delta_seconds()).clamp(0.0, 1.0); }
    // feed v.t into the Material2d uniform; entity stays in the data layer the whole time (permanence > impermanence)
}
```

---

## 4. THE BUILD PLAN (staged — prove each gate before the next)
| Stage | Build | GATE before next |
|---|---|---|
| **1 · Prove the split (ZERO LLM)** | shell (§0) + Rust drives (§2b) + budget ledger (§2e) + 25 wandering agents trading vs a *stubbed* appraiser + dissolve/blur | **stable 120fps (or 60) w/ 50 agents + 200 objects; ledger NEVER violates caps under fuzzing** |
| **2 · Bridge ONE brain** | sidecar (§2f) + Hermes function-calling + memory stream (§2c) + reflection (§2d); one mascot writes one real markdown to its vault | **an artifact a human would actually keep; ZERO main-thread stalls** |
| **3 · Economy + society** | AP2 mandate flow (§2e) + shop affordance + gossip/reputation + the VERIFY loop (§2g) + appraiser mints on pass; tune EVE faucets/sinks | **budget supply stays bounded over a long run; agents specialize UNscripted** |
| **4 · Offline super-agent (optional)** | MoA / Self-MoA for "serious research" artifacts only, off the live loop | quality gain pays for the latency/cost, or cut it |

---

## 5. HARD GATES / NON-NEGOTIABLES (the flags, one last time)
× **No LLM in the hot path / no PyO3 on the frame thread** — sidecar only; the frame thread never blocks.
× **No faucet without a sink** — every minted budget unit must be burnable (EVE discipline) or you get Diablo-3 hyperinflation.
× **No reward without a verifier pass + novelty check** — else spam-to-earn; the verifier IS the usefulness.
× **No recursive self-purchase of authority / no self-minting** — the paperclip-maximizer guard.
× **No web/model-rendered UI** — hand-authored `bevy_ui` + WGSL; `egui` for DEBUG only. (This is why it's NOT Tauri.)
× **Don't fork a framework** — mine the ideas, build the Rust runtime fresh.
× **Don't over-promise emergence** — seed reputation/gossip; emergent institutions are a *maybe*, not a feature.
× **Pin the Bevy version** — it churns; budget for migration; ProMotion 120fps is a target to PROVE, not assume.
× **Separate repo from Epistemos** — reuse PATTERNS (agent_core ideas, cli-passthrough, per-model vault) not a shared binary.
