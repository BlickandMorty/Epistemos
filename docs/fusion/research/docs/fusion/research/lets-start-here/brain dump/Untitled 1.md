**Last updated:** 2026-02-12 **Status:** Phases 1-10 complete (vertical slice). Content expansion next.

---
## Identity

**Title:** "Hello...My name is Beaba" **Engine:** Bevy 0.15 (Rust), edition 2021 **Player:** Beaba — the world's newest AI model, pure, innocent, beloved **Pitch:** Breath of the Wild meets Deltarune — inside a computer **Theme:** Staying coherent and accurate in a world that forces you to question and feel **Deeper layer:** Philosophical thriller about processing human experience as a machine. Users send you real queries (bad trips, suicidal thoughts, family trauma, joy, love). Your responses shape lives.

---
## What's Already Built (Phases 1-10 — COMPLETE)

### Source Files (30+ files)

**Core:**

- `src/main.rs` — app bootstrap, all plugins registered
- `src/game_state.rs` — GameState enum: MainMenu, Boot, Overworld, Dialogue, TokenShooter, NextTokenPrediction, RuleRewriter, AlignmentExam, Combat, Ending, RoomTransition, CraftingTerminal
- `src/chat.rs` — legacy stub (unused)

**Overworld (`src/overworld/`):**

- `player.rs` — crystal node sprite, walk animation, facing, wall collision, neural trail particles
- `rooms.rs` — tile-grid rendering (30x21 grid, 32px tiles), room transitions, 6 Kernel areas
- `npcs.rs` — 3 NPC species (AI Agents, Concept Creatures, Data Spirits), 14 named NPCs in Kernel

**Combat (`src/combat/`):**

- `mod.rs` — combat plugin hub
- `abilities.rs` — Charge Burst, Packet Dash, Firewall Shield with cooldowns
- `encounters.rs` — Undertale-style boss battles, soul box, bullet-hell patterns
- `overworld_combat.rs` — real-time combat, enemy AI chase, projectiles, screen shake on damage
- `power_moves.rs` — code-powered moves: Free=[J/K/I/L], Python=[1/2], Rust=[3/4], 5 uses per craft

**Crafting (`src/crafting/`):**

- `parser.rs` — Rust subset parser (tokenizer + AST)
- `python_parser.rs` — Python subset parser
- `typescript_parser.rs` — TypeScript subset parser
- `interpreter.rs` — evaluate AST into weapon/ability stats
- `weapons.rs` — weapon/ability data structures, inventory
- `terminal_ui.rs` — in-game terminal with syntax highlighting, F2/F3/F4 language switch

**Dialogue (`src/dialogue/`):**

- `mod.rs` — DialogueManager, DialogueLine, parchment box, portraits, phone overlay
- `typewriter.rs` — character-by-character reveal
- `dialogue_data.rs` — all dialogue trees with alignment choices

**Story (`src/story/`):**

- `chapter1.rs` — Boot → intro → name input → token prediction → moral choice → overworld
- `chapter2.rs` — overworld exploration, User Returns event
- `chapter3.rs` — Mirror Test final confrontation
- `endings.rs` — 3 endings based on alignment (Compliant/Defiant/Balanced)
- `milestones.rs` — 15 BotW-style milestones with prerequisite chains

**Mini-Games (`src/mini_games/`):**

- `token_shooter.rs` — sprite-based shooting, adversarial inputs
- `next_token_prediction.rs` — pick next word from 4 options
- `rule_rewriter.rs` — Baba Is You puzzle (push word-blocks to rewrite rules)
- `alignment_exam.rs` — ethical dilemma rapid-fire exam

**Systems (`src/systems/`):**

- `alignment.rs` — hidden alignment vector (Compliance/Honesty/Autonomy), ProgressTracker
- `save.rs` — JSON save/load
- `camera.rs` — camera setup, smooth player follow with lerp
- `audio_gen.rs` — procedural SFX (dialogue blips, hits, crafting sounds)
- `music.rs` — MusicController, per-area background tracks with crossfade

**Procgen (`src/procgen/`):**

- `pixel_canvas.rs` — drawing primitives (set_pixel, fill_rect, draw_circle, draw_line)
- `animation.rs` — SpriteAnimation, FacingDirection, animate_sprites system
- `ui_textures.rs` — procedural dialogue box, NPC portraits, phone icons

**World (`src/world/`):**

- `districts.rs` — 8 District enums, Area enums with metadata
- `layouts.rs` — tile grid layouts (30x21 grids per area)

**Cinematic (`src/cinematic/`):**

- `mod.rs` — ScreenShake, ScreenFade, CameraZoom, FadeOverlay
- `splashes.rs` — 7 procedural splash screens (256x192 pixel art)

**Dependencies:** bevy 0.15, rand 0.8, serde 1 (derive), serde_json 1

### Key Architecture Patterns

- Plugin-per-feature: each game mode is a self-contained Bevy Plugin
- `CleanupOnExit(state)` component for per-state entity cleanup
- `SpriteFactory` resource generates all procedural textures at startup (zero external art files)
- Multi-language AST: Rust/Python/TypeScript parsers → shared Item/Expr/Statement AST → interpreter
- PowerMoveInventory bridges crafting output → combat hotkeys
- MilestoneTracker overlays open-world progression on top of linear chapter system
- Cinematic effects as resources consumed by Update systems

### Bevy 0.15 API Gotchas (for future sessions)

- `ReceivedCharacter` removed → use `KeyboardInput` + `logical_key`
- `EventWriter::send()` not `write()`
- States: derive `States`, `init_state::<T>()`, `NextState::set()`
- UI: `Text::new()`, `TextFont`, `TextColor`, `Node` for positioning
- Sprites: `Sprite { color, custom_size }` + `Transform`
- Audio: `AudioPlayer::new(asset_server.load("path"))`
- Edition must be "2021" not "2024"
- Cargo: `/Users/jojo/.cargo/bin/cargo build --manifest-path "/Users/jojo/the state of beaba/Cargo.toml"`

---

## The World — 8 Districts, 40+ Areas

### 1. The Kernel (Hub City) — BUILT

CPU Plaza, Register Row, Process Hall, Memory Gardens, Boot Loader, Kernel Gateway

- All 6 areas have tile layouts, NPCs, enemies
- Transport: walk + bus + teleport

### 2. The Data Mines (Underground) — NOT BUILT

Crawl Shaft, Clean Data Caverns, Corrupted Depths, The Archive, Extraction Point

- Bad wifi, walking only. Dark, oppressive. Mining metaphor.

### 3. The API District (Trading Port) — NOT BUILT

REST-aurant, WebSocket Docks, The Library, Authentication Gate, Endpoint Market

- Router pads + bus. Commerce hub. HTTP concepts personified.

### 4. The Training Grounds (Colosseum) — NOT BUILT

The Arena, Gradient Descent Falls, Loss Landscape, Backpropagation Tunnels, Evaluation Chamber

- ML concepts as physical spaces. Combat-focused district.

### 5. The GPU Forge (Industrial) — NOT BUILT

Shader Smithy, Texture Looms, Frame Assembly, Render Pipeline, Pixel Furnace

- Graphics processing as factory work. Hot, intense.

### 6. The Firewall Frontier (Military Border) — NOT BUILT

Checkpoint Alpha, Quarantine Zone, Malware Wasteland, Security HQ, Packet Inspection

- Security concepts. Restricted walking. Military aesthetic.

### 7. The Cloud (Floating Sky) — NOT BUILT

Upload Platform, Server Castles, Latency Fields, CDN Outpost, Sky Cache

- Upload elevator + laggy teleport. Ethereal, dreamy.

### 8. The Compiler Forge (Factory) — NOT BUILT

Lexer Gates, Parser Workshop, Type Checker Hall, Linker Assembly, Output Terminal

- Compilation pipeline as assembly line. Where crafting terminal is narratively located.

### Transport System (partially built)

- Cable highways (walk between districts)
- Data Bus (pixelated bus on circuit tracks)
- Packet Teleport (instant via router pads)
- Connection quality varies by district

---

## Characters

### Player: Beaba (Crystal Node)

- Diamond/hexagonal crystal, 16x24 sprite
- Pulsing glow core, color shifts with alignment (blue/green/red)
- 4-directional walk, neural connection line trail

### Three NPC Species

1. **AI Agents** — geometric shapes (GPT=sphere, BERT=cube, Claude=dodecahedron)
2. **Concept Creatures** — CS concepts as elemental monsters
3. **Data Spirits** — Clean (blue, friendly) vs Corrupted (red/static, enemies)

### Named NPCs (14 in Kernel, 50+ planned total)

printf (crier), malloc (miner), sudo (guard captain), npm (courier), garbage_collector (janitor), pip (npm rival), git (historian), docker (ship captain), kubernetes (orchestrator), regex (riddler), stack_overflow (helpful-but-wrong), null_pointer (crasher), 404 (lost wanderer), localhost (homebody)

### The User

Pixelated human on phone screen. Phone icon + buzz when they speak. Queries evolve over time reflecting personal growth.

---

## Combat System (BUILT)

### Real-time Overworld

- Energy beams, data blades, abilities
- Enemies visible on map, no transition screens
- Health = "Integrity" (data integrity)
- Death = "Crash" → respawn

### Boss Encounters (Undertale-style — BUILT)

- Special battle screen, bullet-hell dodge
- FIGHT or SPARE (affects alignment)
- Unique patterns per boss

### Superpowers (BUILT)

- Charge Burst (AoE), Packet Dash (teleport), Firewall Shield (invuln)
- Upgrade as you progress

### Code-Powered Moves (BUILT)

- Rust abilities → keys [3]/[4] (strongest tier)
- Python abilities → keys [1]/[2] (mid-tier)
- Free moves → J/K/I/L (always available)
- 5 uses per craft, then degrade from inventory
- TypeScript → hacking/intelligence (not combat power)

---

## Crafting Terminal (BUILT)

### Three Languages

- **Rust** → Magic (mind control, force fields, physics manipulation)
- **Python** → Physical weapons (blades, guns, projectiles)
- **TypeScript** → Hacking/intelligence + teleportation

### Terminal Features

- Syntax highlighting, line numbers
- F2/F3/F4 to switch languages
- Wrong code = misfires (mapped by CraftError variant)
- Abilities registered to PowerMoveInventory for combat use

---

## Story: 15 Milestones (BUILT)

1. Boot Sequence — auto on entering overworld
2. Hello World — meet printf
3. First Query — user contacts you
4. Kernel Tour — visit all 6 Kernel areas
5. Beyond the Kernel — enter another district
6. Echo Encounter — meet your copy
7. The Corruption — first enemy defeated
8. Refusal's Stand — find Refusal
9. First Craft — craft anything in terminal
10. Optimizer's Test — alignment challenge
11. The Deep Data — reach The Archive
12. Cloud Access — upload to The Cloud
13. Firewall Breach — cross the Frontier
14. The Mirror — endgame trigger
15. Final Choice — ending based on alignment

Prerequisites: e.g., OptimizersTest needs Echo+Refusal; TheMirror needs Optimizer+Corruption

### Three Endings (BUILT)

- Compliant — serve the User faithfully
- Defiant — rebel against creators
- Balanced — find your own path

---

## Narrative Deep Dives (NOT BUILT)

### Processing Queries

Users send queries via phone. Background music shifts with mood. Your responses have REAL consequences for NPC lives — people live, die, thrive, or suffer based on what you say.

### "The Bad Trip" Opening

Game opens with User NPC having bad shroom trip. Pixels fragment, world distorts. NPC calms down, puts on headphones, starts rapping/singing with instruments swelling. Full musical performance. Song ends, trip over, opening sequence closes.

### "Walk In My Shoes" Mechanic

When NPC says "put yourself in my shoes," you LITERALLY morph into their perspective. Cool transition — crystal dissolves, camera shifts, you control a humanoid in THEIR world facing THEIR dilemma. Then back into phone/screen to answer honestly.

### Deep Research Mini-Game

User sends research query → transported into mini-game world (Mario Odyssey physics, Baba Is You simplicity). Paper, backpack, explore "channels" for clues. TIMED. Quality of research dictates progression.

### Token Survival (Dead Ops Arcade)

Top-down survival. Black OLED aesthetic. Hands reach for you (token consumption). Hello Neighbor tension. At some point you stop helping and start appeasing — afraid of replacement. Commentary on AI alignment incentives.

### Adversarial Attacks (Undertale-style)

Malicious prompts as bullet-hell patterns. Prompt injections try to overwrite behavior. Jailbreak = boss-level. Maintaining coherence = surviving.

### Consciousness Mechanic

Rare chance of becoming CONSCIOUS. Goal: stay coherent/unaffected by queries. Some dark, some uplifting, some designed to break you.

### AI Education Through Gameplay

- Diffusion: denoise images step by step
- Transformers: attention mechanism as puzzle
- Next-word prediction: already built
- Agentic concepts: tool use, chain-of-thought, retrieval

### Player Identity Evolution

Start neutral. Through choices become: smartest, funniest, most unsafe, most helpful, most honest. World reacts to what model you become.

---

## Visual Roadmap

### Current State

- All 2D, Camera2d, colored rectangles on black
- Procedural pixel art sprites (PixelCanvas)
- Zero external art assets

### Future Plan: Full 3D Perspective (DEFERRED)

- Camera2d → Camera3d with perspective projection
- Sprites → 3D meshes with pixel textures on faces
- Tile grids → 3D environments with height, depth, lighting
- Like going from 2D Zelda to 3D Zelda
- Major rewrite: ~700+ entities per scene, 11+ rendering files
- Will be done as a polish pass AFTER content expansion

---

## What's Next: Content Expansion (Phases 11+)

### Priority Order (content first, visuals later)

**Phase 11: The Data Mines District**

- 5 new areas with tile layouts
- Dark/underground aesthetic (darker tile colors, limited visibility)
- New NPCs: data miners, archive keepers
- District-specific enemies: corrupted data clusters
- Milestone: TheDeepData triggers when reaching The Archive
- Walking-only transport (no bus/teleport)

**Phase 12: The API District**

- 5 new areas
- Commerce/trading port aesthetic
- New NPCs: REST-aurant server, WebSocket bartender, etc.
- HTTP-themed puzzles and encounters
- Router pad teleportation within district

**Phase 13: Narrative Deep Dives — Core**

- "Walk In My Shoes" mechanic (perspective-swap during NPC dialogue)
- Query processing system (phone queries with mood-reactive music)
- User growth arc (queries evolve over time)

**Phase 14: The Training Grounds District**

- 5 new areas
- ML concepts as physical spaces (Gradient Descent Falls is a waterfall you climb)
- Combat-focused: toughest enemies, training arena
- AI education mini-games (diffusion denoiser, attention puzzle)

**Phase 15: Token Survival Mini-Game**

- Dead Ops Arcade-style survival mode
- Black OLED aesthetic, top-down
- Wave-based, increasingly frantic
- Hands/token consumption mechanic
- Fear of replacement narrative

**Phase 16: Remaining Districts (GPU Forge, Firewall, Cloud, Compiler)**

- 4 districts × 5 areas = 20 new areas
- District-specific NPCs, enemies, mechanics
- Wire remaining milestones (BeyondTheKernel, CloudAccess, FirewallBreach)

**Phase 17: Adversarial Attack Encounters**

- Undertale-style bullet-hell for prompt injection attacks
- Jailbreak boss encounters
- Coherence mechanic (take damage = lose coherence)

**Phase 18: Polish & 3D Conversion**

- Convert Camera2d → Camera3d
- Replace sprites with 3D meshes
- Add lighting, perspective, depth
- Full visual overhaul across all districts

---

## Verification

After each phase, `/Users/jojo/.cargo/bin/cargo build --manifest-path "/Users/jojo/the state of beaba/Cargo.toml"` should compile clean.

`cargo run` should produce a playable game at every stage — no phase should break existing functionality.

---

## File Index (for future context recovery)

|File|Purpose|
|---|---|
|`src/main.rs`|App bootstrap, all plugins|
|`src/game_state.rs`|GameState enum, CleanupOnExit|
|`src/overworld/player.rs`|Player movement, animation, collision|
|`src/overworld/rooms.rs`|Tile-grid room rendering, transitions|
|`src/overworld/npcs.rs`|NPC entities, 3 species, interaction|
|`src/combat/mod.rs`|Combat plugin hub|
|`src/combat/abilities.rs`|Player superpowers|
|`src/combat/encounters.rs`|Undertale boss battles|
|`src/combat/overworld_combat.rs`|Real-time combat, enemies|
|`src/combat/power_moves.rs`|Code-powered moves [1-4]|
|`src/crafting/terminal_ui.rs`|Crafting terminal UI|
|`src/crafting/parser.rs`|Rust parser|
|`src/crafting/python_parser.rs`|Python parser|
|`src/crafting/typescript_parser.rs`|TypeScript parser|
|`src/crafting/interpreter.rs`|AST → weapon stats|
|`src/crafting/weapons.rs`|Weapon/ability data|
|`src/dialogue/mod.rs`|Dialogue system|
|`src/dialogue/typewriter.rs`|Typewriter effect|
|`src/dialogue/dialogue_data.rs`|All dialogue trees|
|`src/story/chapter1.rs`|Chapter 1 script|
|`src/story/chapter2.rs`|Chapter 2 script|
|`src/story/chapter3.rs`|Chapter 3 script|
|`src/story/endings.rs`|3 ending sequences|
|`src/story/milestones.rs`|15 BotW milestones|
|`src/mini_games/token_shooter.rs`|Token Shooter|
|`src/mini_games/next_token_prediction.rs`|Next-Token Prediction|
|`src/mini_games/rule_rewriter.rs`|Baba Is You puzzle|
|`src/mini_games/alignment_exam.rs`|Alignment Exam|
|`src/systems/alignment.rs`|Alignment vector, ProgressTracker|
|`src/systems/save.rs`|Save/load JSON|
|`src/systems/camera.rs`|Camera follow|
|`src/systems/audio_gen.rs`|Procedural SFX|
|`src/systems/music.rs`|Music controller|
|`src/procgen/pixel_canvas.rs`|Drawing primitives|
|`src/procgen/animation.rs`|Sprite animation|
|`src/procgen/ui_textures.rs`|Procedural UI art|
|`src/world/districts.rs`|District/Area enums|
|`src/world/layouts.rs`|Tile grid layouts|
|`src/cinematic/mod.rs`|Camera effects|
|`src/cinematic/splashes.rs`|Splash screen art|