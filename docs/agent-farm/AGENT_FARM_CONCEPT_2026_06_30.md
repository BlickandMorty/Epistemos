# AGENT FARM — concept doc (2026-06-30)

> **A SEPARATE app from Epistemos — does NOT interfere with it.** Different repo, different stack (Bevy/Rust), its own
> identity. It MAY reuse Epistemos *patterns* (the Rust agent brain, the CLI-passthrough auth, the per-model-vault idea,
> the companion/mascot shape-ontology) — but it ships independently, with no MAS constraints. This is the **freedom
> sandbox**: where the cut/wild agent stuff (overnight fine-tuning, multi-agent, a real Rust agent layer) gets to live.
> Good experiments here GRADUATE back into Epistemos later. **Status: concept / not started.**

## 0. One-liner
A minimal, windowed, cross-platform-native **2D game** (Bevy / Rust ECS) where AI agents are **mascots** living in a
world — you create them, chat with them, watch them engage each other, and they do **real things** (build, trade, keep
their own files). It's a Tamagotchi, an agent lab, and a multi-agent orchestration *visualizer* in one.

## 1. The shell / aesthetic (same minimalism as Epistemos)
- **Black OR white background, toggleable** (start minimal — "welcome, <name>").
- **Blurred background** like the Epistemos graph's frosted look — same blur feel.
- **Windowed, NOT fullscreen** — like a "demo graph." Take the Epistemos graph idea and *implant the whole game inside
  that canvas* (agents as living nodes in a 2D world).
- ⚠️ **HONEST blur note:** Bevy can easily blur *its own* rendered scene (a post-process fragment shader). But the
  "frosted glass showing the blurred *desktop* behind a translucent window" (the exact Epistemos-graph look) is a
  *native window vibrancy* effect (NSVisualEffectView on macOS, Acrylic/Mica on Windows) — Bevy doesn't do that out of
  the box. To get it: transparent Bevy window (winit supports transparency) + a small per-platform native vibrancy
  shim. Doable, but it's the one platform-specific bit. (Fallback: a self-rendered blurred gradient scene — looks 95%
  as good, fully cross-platform, zero native shim.)

## 2. The agent ontology — THREE TIERS (resolving the "are these all agents?" question)
A mascot's **brain** can be any of three tiers — this is the clean taxonomy you were working out:
| Tier | What it is | Examples |
|---|---|---|
| **1 · Model** | raw LLM, chat/completion only | Claude Opus, GPT-5.5, Kimi, Pi |
| **2 · CLI / pseudo-agent** | model + tools + a thin loop (a coding-agent harness) | Claude Code, Codex, Gemini CLI |
| **3 · Full agent** | a real agentic framework (own loop, memory, skills, A2A) | Hermes agent, Goose |
A mascot = a **body** (the creature) + a **brain** (one of these tiers). Tier is a property you pick at creation.

## 3. Presets + ZERO-SETUP auth (reuse your machine's equipment)
- **Presets** = the roster above (Opus · GPT-5.5 · Kimi · Pi · Codex · Claude Code · Hermes · Goose).
- **Killer move — reuse the CLIs already authed on your machine.** Like signing into Goose and just *using* it without
  setting up Anthropic/OpenAI keys: the game **shells out to your existing CLIs** (`claude`, `codex`, `gemini`, `goose`,
  `kimi`) which already hold their own auth. **No key setup — it "comes like that."** (Epistemos's `agent_core` already
  has this exact `cli_passthrough` pattern — reuse it.) One setting screen; everything routes through your installed,
  signed-in tools.

## 4. Creating an agent
- **From a preset** (pick a roster brain) → instant mascot.
- **Custom (two-step):** (1) pick/compose the **brain** (a tier-3 like Hermes/Goose, or just a tier-1 model + what it
  can natively do, or a tier-2 CLI); (2) **design the body** — a mascot using the shared shape-ontology (the Companion
  `CompanionBodyKind` grammar), but dynamic + creative (custom coat/color/personality).
- **Super-agent (later):** compose/merge multiple brains into one (model/agent merging-as-a-mechanic) + prune/breed.

## 5. The game itself (minimal)
- **Top-down 2D:** mascots walk around a world, engage each other.
- **First-person:** animate INTO a mascot — you *embody* that brain. Walk up to other agents → "what's up?" → exchange
  ideas. (The text-box "blooms" into a full agent chat — the signature animation.)
- **Auto-engage:** set agents to interact with each other on their own.

## 6. Orchestration — the design answer (loops/cron vs ECS)
You asked: cron/loops like normal agents, OR engineered orchestration, OR a Rust-ECS game thing? **→ Make the ECS WORLD
the orchestrator — not a cron scheduler.** This is what makes it a *game* instead of a dashboard:
- **Proximity-driven A2A:** two mascots near each other → an "interaction" System fires → they talk. The *world*
  (position, who's nearby, who needs what) drives who-talks-to-whom — emergent, not scheduled.
- **Think-tick throttle:** agents "think" on a slow tick (not every frame); only engaged/active agents think hard;
  ambient mascots idle on cheap local models. (ECS makes "who thinks now" a trivial query — this is also the fix for
  the cost/throughput problem of many brains.)
- **Goal Systems:** give the world (or a mascot) a goal (your paperclip instinct) → Systems drive build/trade behavior.
- So: **A2A orchestration emerges from world rules.** Cron is the fallback for a specific "do X every hour" agent, not
  the core loop.

## 7. "Real game" — agents that DO real things (the ambitious layer)
- **Per-agent VAULT:** each agent owns a folder (`Vault(path)` component). Press a button → open *that* agent's folder
  = all the files it has made/owns. Give another agent another vault. (Mirrors Epistemos's per-model-vault concept.)
- **Build:** agents create real artifacts in their vault (write code/docs/data).
- **Economy (experimental, flagged):** agents have a `Wallet`; an ECS **Store** entity sells items (compute, tools,
  data, files); agents **earn/spend/trade**. "Sell things" = produce an artifact, sell it to another agent or the store.
  (Real agent-payment/bank-account experiments exist in industry — capture as a stretch, not v1.)
- These are the layers that make it "a real game where the models actually do things," not just chat bubbles.

## 8. Tech foundation
- **Engine:** **Bevy** (Rust, ECS, `wgpu`) — **cross-platform-native** (macOS=Metal, Windows=DX12/Vulkan, web=WebGPU)
  from ONE codebase. This is what solves "I want a Windows version" *for free* (Epistemos is Swift = Mac-locked).
- **Brains:** Hermes (Python) + the CLI passthrough (tier-2) + raw model APIs (tier-1), bridged into the ECS via an
  async task per active agent. **No MAS = the Python/subprocess bridge is simply allowed** (the freedom you're after).
- **Reuse from Epistemos (patterns, not a shared binary):** `agent_core` Rust brain · `cli_passthrough` auth · the
  per-model vault · the Companion body-grammar + animation work · the "agents on a 2D graph" precedent.
- **ECS schema sketch:** `Entity` = agent · Components = `Brain(tier, model/cli/framework)`, `Body(coat, color,
  personality)`, `Position`, `Energy`, `Wallet`, `Vault(path)`, `Goal` · Systems = movement · proximity-A2A ·
  think-tick · build · trade · overnight-growth.

## 9. START HERE — the vertical slice that proves the magic
Don't build the city first. Build **one creature, alive:**
1. Bevy window (B/W, self-blurred scene — skip the native vibrancy shim for v1).
2. Forge ONE mascot (pick a brain from a preset that reuses your CLI auth + a simple body).
3. Chat with it; its bubble **blooms** into a full chat.
4. **Overnight growth:** it fine-tunes (LoRA) on the day's chats → wakes up sharper. (Resurrects the cut Epistemos
   "overnight fine-tuning" feature — this is the *hook*.)
If that feels magic in your hands, the society (multiple mascots · proximity-A2A · vaults · economy) writes itself.

## 10. Open questions + honest challenges
- **Blur shell** = the one platform-specific bit (native vibrancy) — or fall back to a self-rendered blur (v1 choice).
- **Brain throughput/cost** — many agents thinking = many LLM calls; the think-tick throttle + cheap-local-ambient is
  the mitigation; start with 3 mascots.
- **The economy/bank-account layer is experimental** — capture it, but it's a later stretch, not the proof slice.
- **Scope discipline** — this is big; the vertical slice (§9) is the whole point. Resist building the economy before
  one mascot feels alive.

## 11. Separation from Epistemos (explicit)
- Separate repo + app + stack (Bevy/Rust). It does NOT touch Epistemos's code, build, or MAS constraints.
- It REUSES Epistemos *ideas/patterns* freely (above), and the *good* discoveries (what makes agents orchestrate,
  visualize-the-society, the brain tiers) graduate BACK into Goose/Epistemos.
- This is the playground; Epistemos is the product. Keep them clean of each other.
