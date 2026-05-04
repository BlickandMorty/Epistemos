# Epistemos Processes & Runtimes Audit — 2026-05-03

> Ground-truth inventory of every runtime in the Epistemos tree as of
> 2026-05-03 (commits ending `459b8671`). Classifies each by language /
> runtime / process boundary and recommends migration where in-process is
> achievable. Generated from live greps; cross-reference §11 of the kernel
> doctrine for the target architecture.

---

## 0. Executive summary

| Runtime                | Status today                                          | Target (after kernel doctrine ships)                       |
|---|---|---|
| **Swift (Apple frameworks + UI)** | Owns: SwiftUI, MLX-Swift inference, macOS APIs, WKWebView | Same — these are Apple-only domains, do not move |
| **Rust agent_core (in-process)** | Owns: 11 in-tree crates, agent loop, tools, providers, security, prompt caching | Expand: absorb hermes-agent Python responsibilities, expose Skills + procedural memory |
| **Metal compute shaders (in-process via Swift/MTL)** | 13 .metal files in tree (4 UI, 4 Mamba2, 6 Helios, 1 ungrouped) | Verify all 6 Helios kernels are wired; add Resonance batch ops |
| **Python (build-time only)** | 30+ test/data-prep scripts; KnowledgeFusion training scripts | Same — build-time is fine; no runtime Python |
| **Python (runtime — hermes-agent subprocess)** | Submodule consumed via subprocess for cloud orchestration + skills | **REMOVE** — port to `agent_core::hermes` (kernel doctrine Phase 2) |
| **JavaScript (in WebKit)** | Tiptap editor + KaTeX in WKWebView (js-editor/dist) | Same — web content needs WebKit; not a process Epistemos manages |
| **Subprocess (Pro tier)** | 14 spawn sites: cli_passthrough, code_exec, terminal, osascript, browser, media, mcp/client, tirith | Compress: WASM for code_exec moves to Core; LSP moves to Core via in-proc Rust; rest stays Pro |
| **XPC services (planned)** | AgentXPC, ProviderXPC (not yet shipped) | Implement as pass-through to kernel UniFFI |

**Headline:** the binary is already very Rust-heavy (11 crates, ~94K LOC) and
very in-process. The few remaining external boundaries are well-known
(hermes-agent Python, ~14 subprocess spawn sites in agent_core, 1 LSP Process
in Swift, the Tiptap WebKit content). Migration is bounded and feasible.

---

## 1. Swift surface (renderer + Apple frameworks)

### 1.1 Swift runtimes that are correct as Swift

| Subsystem                                       | Why Swift                                                                     |
|---|---|
| All SwiftUI views                               | SwiftUI is Apple-native; Rust can't render NSView/UIView trees                |
| MLX-Swift inference (`MLXInferenceService`)     | Apple's MLX is Swift-first; Apple's mlx-swift-lm is the canonical inference SDK |
| LocalAuthentication (`SovereignGate.swift`)     | LAContext is Apple framework; not exposed to Rust                              |
| AXorcist (Accessibility queries)                 | macOS AX API is Swift/ObjC                                                    |
| ScreenCaptureKit                                | Swift framework; required entitlement                                          |
| CGEvent (input synthesis)                       | Quartz-CG; Swift bridge canonical                                             |
| WKWebView (Tiptap editor + KaTeX)               | WebKit; required for rich text rendering                                      |
| SwiftData (`SDChat`, `SDMessage`, etc.)         | Apple persistence framework                                                   |
| Spotlight indexing (`SpotlightIndexer`)         | CoreSpotlight is Apple framework                                              |
| `NSWorkspace` / `NSPasteboard`                   | macOS APIs                                                                    |

**Verdict:** Keep all of the above as Swift. Forever. The kernel doctrine §1 Renderer layer is correct.

### 1.2 Swift surfaces that should COLLAPSE into the Rust kernel

| Subsystem                                            | File                                              | Why migrate                                                                     |
|---|---|---|
| LocalAgentLoop                                       | `Epistemos/LocalAgent/LocalAgentLoop.swift`       | Parallel agent loop — kernel doctrine §1 Rule 1 (one loop). Becomes thin caller of `agent_core::agent_loop` via UniFFI. |
| HermesPromptBuilder (Swift mirror)                   | `Epistemos/LocalAgent/HermesPromptBuilder.swift`  | Mirror of canonical `agent_core::hermes::prompt_format`. Keep as thin mirror; canonical lives in Rust. |
| IncrementalToolCallDetector (Swift mirror)           | `Epistemos/LocalAgent/IncrementalToolCallDetector.swift` | Same — thin mirror of `agent_core::hermes::function_call`. |
| LSPServerProcess.swift (the only remaining Swift `Process()`) | `Epistemos/Engine/LSPServerProcess.swift:120` | Subprocess LSP forbidden in MAS. Replace with in-process Rust LSP via `tower-lsp` or `lsp-server` crates calling `tree-sitter` parsers. **Moves Pro → Core.** |

### 1.3 Swift `Process()` audit (current)

```
Epistemos/Harness/HarnessLab.swift:876   — runAgentSubprocess (test harness; OK)
Epistemos/Harness/HarnessLab.swift:936   — runAgentSubprocess implementation
Epistemos/Engine/LSPServerProcess.swift:120 — Process() for LSP  ★ MIGRATE TO RUST
```

**Total Swift subprocess sites: 2** (and one is test-only). After LSP migration: **1** test-only site. Excellent state.

---

## 2. Rust kernel surface (the cognitive kernel)

### 2.1 Workspace inventory

11 in-tree Rust crates:

| Crate                  | Purpose                                                                  | LOC class |
|---|---|---|
| `agent_core`           | The kernel — agent loop, tools, providers, security, compaction, vault  | ~50K      |
| `omega-mcp`            | MCP dispatcher; today subprocess-spawning, target in-process bundled    | ~5K       |
| `epistemos-shadow`     | BM25 + HNSW search index (FFI via @_silgen_name)                        | ~8K       |
| `graph-engine`         | Graph data structure + spatial / cluster / search ops                    | ~12K      |
| `epistemos-core`       | Core types, shared abstractions                                          | ~3K       |
| `epistemos-code-index` | Code search index                                                        | ~4K       |
| `substrate-core`       | Substrate primitives                                                     | ~2K       |
| `substrate-rt`         | Substrate runtime                                                        | ~2K       |
| `omega-ax`             | AX-related (likely AXorcist Rust complement)                             | ~3K       |
| `syntax-core`          | Syntax parsing                                                           | ~2K       |
| `bench`                | Benchmarks                                                               | ~3K       |

**Total Rust LOC: ~94K** (matches CLAUDE.md figure).

### 2.2 agent_core module inventory (the kernel itself)

44 modules / files at top level (excluding `bin/`):

```
agent_loop.rs       approval.rs           arena/                arenas/
artifacts/          bridge.rs (2319 LOC)  channel_relay.rs      circuit_breaker.rs
command_center.rs   compaction.rs         context_compiler.rs   context_loader.rs
credential_pool.rs  dispatcher.rs         error.rs              error_classifier.rs
etl/                evolution/            example_bank.rs       lattice/
mcp/                mutations/            neocortex.rs          oplog.rs
process_registry.rs prompt_caching.rs     prompts.rs            provenance/
provider.rs         providers/            pty.rs                rate_limit_tracker.rs
reasoning_metrics.rs resonance/           resources/             rope.rs
rope_handle.rs      routing.rs            runtime/               security.rs
session.rs          session_insights.rs   session_persistence.rs shared_memory.rs
sketch/             skill_router.rs       sovereign/             storage/
tirith.rs           title_generator.rs    tools/                 types.rs
vault_registry.rs   wbo6/
```

Notable observations:
- **`wbo6/` already exists** — Helios v3 WBO-6 module is partially in-tree (verify against doctrine target)
- **`lattice/`, `sketch/` exist** — Helios v3 lattice + count-sketch modules in-tree
- **`resonance/` exists** — committed `06230e8d` + `07e33fed` this session
- **`sovereign/` exists** — Rust-side Sovereign Gate counterpart
- **`provenance/` exists** — provenance module (verify alignment with AgentEvent)
- **`evolution/` exists** — possibly precursor to hermes self-evolution
- **NO `hermes/` yet** — Phase 2 of kernel doctrine creates this

**Bridge size: 2319 LOC at `agent_core/src/bridge.rs`.** The UniFFI surface is substantial. After Phase 8 DAG additions, expect ~3000-3500 LOC.

### 2.3 Rust subprocess audit (the 14 spawn sites)

```
agent_core/src/security.rs:911      harden_cli_subprocess (helper; not a spawn)
agent_core/src/security.rs:1131,1153 env subprocess (test-only)
agent_core/src/tirith.rs:268        arbitrary binary (test harness)
agent_core/src/tools/imessage.rs:93 osascript                          [PRO]
agent_core/src/tools/registry.rs:2193 bash                             [PRO]
agent_core/src/tools/code_execution.rs:51 Python/Node/Ruby/Perl/shell  [PRO → wasm Core]
agent_core/src/tools/terminal.rs:163 sh                                [PRO]
agent_core/src/tools/media.rs:589   say                                [PRO]
agent_core/src/tools/cli_passthrough.rs:118 claude/codex/gemini/kimi   [PRO — stays]
agent_core/src/tools/apple.rs:50    osascript                          [PRO]
agent_core/src/tools/browser.rs:521 browser binary                     [PRO]
agent_core/src/mcp/client.rs:148    user-installed MCP servers         [PRO — stays for external]

omega-mcp/src/osascript.rs:38       osascript                          [PRO — stays or move via Apple Events Rust crate]
omega-mcp/src/osascript.rs:128      /usr/bin/open                      [PRO]
omega-mcp/src/osascript.rs:166      /usr/bin/pgrep                     [PRO]
omega-mcp/src/osascript.rs:262      /bin/zsh                           [PRO]
```

**Summary:**
- 2 are helpers / tests (not real spawn sites at runtime)
- 4 in `omega-mcp/osascript.rs` are osascript / shell (Pro)
- 8 in agent_core tools/ are tool implementations:
  - `code_execution` → MIGRATE to WASM via wasmtime (Phase 3 of kernel doctrine) — moves to Core
  - `mcp/client` → bundled MCPs MIGRATE to in-process Rust (Phase 4) — moves to Core for bundled, stays Pro for external
  - `cli_passthrough` → cannot migrate (external binaries) — stays Pro
  - `terminal`, `imessage`, `apple`, `browser`, `media` → stay Pro

**Migration count after kernel doctrine ships:**
- 2 spawn sites move to in-process (code_execution → WASM, mcp/client bundled → in-proc)
- 1 Swift Process() removed (LSP → in-proc Rust)
- 12 spawn sites stay Pro (they are by-design subprocess; e.g. CLI passthrough cannot avoid spawning the CLI)

---

## 3. Metal compute surface

### 3.1 Inventory (13 .metal files in tree)

```
UI / rendering:
  Epistemos/Shaders/LandingWave.metal           (liquid wave landing animation)
  Epistemos/Shaders/ThinkingGlow.metal          (thinking-state shimmer)
  Epistemos/Shaders/CodeEditorEmbedding.metal   (code editor embed visual)

Mamba2 SSM compute (4 kernels):
  Epistemos/Shaders/Mamba2/inter_chunk_scan.metal
  Epistemos/Shaders/Mamba2/segsum_stable.metal
  Epistemos/Shaders/Mamba2/elementwise_ssm_helpers.metal
  Epistemos/Shaders/Mamba2/direct_conv.metal

Helios v3 (6 kernels) — already in tree:
  agent_core/metal/dora_apply.metal             (LoRA / DoRA application)
  agent_core/metal/eml_softmax_lse.metal        (numerically stable softmax — Pillar III)
  agent_core/metal/count_sketch_update.metal    (CountSketch fused update)
  agent_core/metal/ternary_proj_residual.metal  (ternary projection — Lane 6)
  agent_core/metal/ternary_gemv.metal           (ternary GEMV — Lane 6)
  agent_core/metal/kv_fingerprint.metal         (KV cache fingerprint for KV-Direct gate)
```

**The 6 Helios kernels are ALREADY in `agent_core/metal/`.** Surprise discovery — they were pulled in earlier (likely from a prior fusion attempt or from the Kimi/GPT mockup). Codex must verify whether each kernel is actually wired (i.e., compiled and called from Rust + Swift) or sitting orphaned. Audit task: grep for kernel filenames in Swift + Rust source to find call sites.

### 3.2 Metal-using Swift files

```
Epistemos/Engine/MLXInferenceService.swift       (MLX-Swift backed inference; uses Metal under the hood)
Epistemos/Engine/MetalRuntimeManager.swift       (MTLDevice / pipeline cache; deepUnload optimization)
Epistemos/Graph/GraphEngine.swift                (graph rendering or compute)
Epistemos/Views/Notes/CodeEditorView.swift       (CodeEditorEmbedding shader)
Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift   (LandingWave shader)
Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift  (MTKView host)
Epistemos/Views/Landing/Wave/LandingWaveGlyphAtlas.swift (glyph atlas for wave)
```

### 3.3 New Metal opportunities (not yet shipped)

| Op                                  | Why Metal                                          | Effort       |
|---|---|---|
| Resonance Gate signature batch      | Hash + truth-eval over many claims at once         | Low — fits a single threadgroup-per-claim |
| Embedding similarity (procedural memory retrieval) | Cosine similarity over N candidate procedures | Medium — needs MPS or custom Metal |
| BLAKE3 hashing for DAG nodes        | Already SIMD on CPU; GPU rarely beats CPU here     | Skip          |
| LoRA hot-swap weight blend          | Apply alpha-blended LoRA at swap time              | Medium — depends on MLX-Swift adapter API |
| CountSketch updates                 | Already a Helios kernel; ensure wired              | Low — verify call site |

**Verdict:** Metal surface is healthy. Main work is verifying the 6 Helios kernels are wired, and adding Resonance batch + embedding similarity if perf demands it.

---

## 4. Python surface

### 4.1 Build-time scripts (correct as Python)

These run only at build/test/data-prep time. They never ship in the binary. **Keep as Python:**

```
generate_swift_tests.py
patch-uniffi-bindings.py
generate_hardened_native_tests.py
generate_advanced_swift_tests.py
graph-engine/generate_*_tests.py (5 files)
scripts/generate_*_tests.py (~10 files)
scripts/verify_hotpath.py
```

### 4.2 KnowledgeFusion training scripts (correct as Python)

```
Epistemos/KnowledgeFusion/MoLoRA/sgmm_kernel.py
Epistemos/KnowledgeFusion/MoLoRA/train_router.py
Epistemos/KnowledgeFusion/MoLoRA/molora_inference.py     ★ NEEDS AUDIT
Epistemos/KnowledgeFusion/MOHAWK/rebuild_symbol_qa.py
Epistemos/KnowledgeFusion/MOHAWK/fill_training_gaps.py
Epistemos/KnowledgeFusion/MOHAWK/strict_validate_and_rebuild.py
Epistemos/KnowledgeFusion/MOHAWK/compose_training_mix.py
Epistemos/KnowledgeFusion/MOHAWK/generate_embodied_trajectories.py
Epistemos/KnowledgeFusion/MOHAWK/validate_training_data.py
Epistemos/KnowledgeFusion/MOHAWK/sft_macos_agent.py
Epistemos/KnowledgeFusion/MOHAWK/generate_general_macos_data.py
```

These are training-time / data-prep tooling. They **must not** be invoked
at runtime by the shipping app. **One audit item:** `molora_inference.py`
has a name suggesting runtime inference. Verify whether it's a build-time
training-data generator or a runtime inference path. If runtime — port to
Rust + MLX-Swift before MAS submission.

### 4.3 Runtime Python (the only one — DOCTRINE TARGET FOR REMOVAL)

`hermes-agent/` submodule (per CLAUDE.md and project memory). **Currently
spawned as a subprocess for cloud orchestration + skills + procedural memory.**

**Migration:** Phase 2 of the kernel doctrine (Hermes-in-Rust). Result: zero
runtime Python; submodule deleted; subprocess removed.

---

## 5. JavaScript surface (WebKit content, not a process)

### 5.1 Tiptap editor + KaTeX

```
js-editor/                        (esbuild source)
js-editor/dist/                   (bundled output)
Epistemos/Views/Epdoc/            (10 Swift files hosting WKWebView)
Epistemos/Views/Notes/CodeEditorView.swift  (WKWebView-backed editor)
```

**Verdict:** Keep as JavaScript. WebKit content is the right abstraction for
rich-text + math rendering. Tiptap and KaTeX are mature, well-maintained,
and used by mainstream apps. Apple Sandbox permits WKWebView content.

The build-script gating (content-hash on `package-lock.json`) is correct;
no runtime npm spawn. Good engineering.

---

## 6. WASM surface (target — does not yet exist)

### 6.1 Target inventory (Phase 3 of kernel doctrine)

```
agent_core/src/exec/
  wasm_runtime.rs    (wasmtime engine + WASI ctx + fuel + memory limits)
  pyodide_loader.rs  (Pyodide WASM for Python user code)
  quickjs_loader.rs  (QuickJS WASM for JS user code)
  policy.rs          (per-execution policy: memory, fuel, fs preopens, net allow)

Resources/Wasm/      (bundled in app)
  pyodide-core.wasm  (~12 MB compressed)
  quickjs.wasm       (~1 MB)
  epistemos-tools.wasm  (~3 MB pre-compiled tool modules)
```

**Total bundle size impact: ~16 MB.** Negligible vs model files (gigabytes).

### 6.2 Tools that move to WASM

| Tool                | Today                  | After WASM Phase     | Tier change |
|---|---|---|---|
| exec_python         | subprocess `python3`   | wasmtime + Pyodide   | Pro → **Core** |
| exec_javascript     | subprocess `node`      | wasmtime + QuickJS   | Pro → **Core** |
| exec_ruby           | subprocess `ruby`      | (TBD; mruby-WASM)    | Pro → optional Core |
| exec_perl           | subprocess `perl`      | (no good WASM Perl)  | Stays Pro |
| exec_shell          | subprocess `sh`        | no — shell is Pro by-design | Stays Pro |

---

## 7. XPC surface (target — does not yet exist)

### 7.1 Target inventory (Hermes hackathon block from kernel doctrine §11 Layer)

```
XPCServices/
  AgentXPC/
    main.swift
    AgentService.swift          (XPC service — pass-through to agent_core via UniFFI)
  ProviderXPC/
    main.swift
    ProviderService.swift       (XPC service — cloud provider sandbox boundary)

Epistemos/XPC/
  AgentServiceProtocol.swift
  AgentServiceClient.swift
  ProviderServiceClient.swift

Epistemos/Security/
  CapabilityBridge.swift        (HMAC capability grant verifier)
```

**Doctrinal rule:** XPC services are pass-through. They do not contain
agent loops, skill registries, or memory state. They are sandbox-crossing
syscall stubs. The kernel doctrine Audit (Phase 1) verifies this; any
XPC service with shadow state is a violation of §1 Rule 1.

---

## 8. Migration matrix — what moves where

### 8.1 Currently-fragmented → unified

| From                                              | To                                      | Phase |
|---|---|---|
| Python `hermes-agent/` subprocess                 | `agent_core::hermes` Rust kernel        | Doctrine Phase 2 |
| Swift `LocalAgentLoop`                            | UniFFI caller of `agent_core::agent_loop` | Doctrine Phase 6 |
| Swift `LSPServerProcess` (Process subprocess)     | `agent_core::lsp` (in-proc Rust LSP)    | New — recommend Phase 4.5 |
| `omega-mcp/osascript.rs` subprocess               | Apple Events via `core-foundation` crate (research) | Optional — Phase 9 |
| Subprocess `python3` / `node`                     | wasmtime + Pyodide / QuickJS             | Doctrine Phase 3 |
| Subprocess bundled MCP servers                    | `omega-mcp::inproc::*` Rust modules      | Doctrine Phase 4 |
| 7 separate kernel subsystems                      | One typed cognitive DAG                  | DAG Phase 8 (Cognitive DAG doctrine) |

### 8.2 Should NOT migrate (correct as-is)

| Subsystem                         | Why not                                                     |
|---|---|
| MLX-Swift inference                | Apple's framework; in-process; correct                       |
| SwiftUI / SwiftData / WKWebView    | Apple-native frameworks; correct                             |
| All 13 Metal shaders               | GPU compute; correct                                          |
| Build-time Python scripts          | Don't ship; correct as Python                                |
| Tiptap JS in WKWebView             | WebKit content; correct                                       |
| `cli_passthrough` (Pro)            | Spawning external CLIs is the literal point; correct as subprocess |
| `terminal` shell (Pro)             | Pro-only; can never move to Core                             |
| `iMessage` / `apple` osascript     | Apple Events; subprocess by design                           |

---

## 9. The Pro → Core unlock summary

After kernel doctrine Phases 1-7 land:

**Migrated Pro → Core:**
- Hermes runtime (prompt format, function-call parse, skills, procedural memory, self-evolution)
- Code execution for Python (via wasmtime + Pyodide)
- Code execution for JavaScript (via wasmtime + QuickJS)
- Generic WASM execution
- Bundled MCP servers (vault ops, search, fetch, think, todo, calc)
- LSP (in-process Rust)
- Long-horizon agent loops

**Stays Pro (App Sandbox forbids):**
- External CLI passthrough (claude / codex / gemini / kimi binaries)
- Native shell, Docker, native subprocess
- External user-installed MCP servers
- iMessage osascript bridge
- Computer use (AX + ScreenCaptureKit) — TCC permissions

**Net Core capability expansion:** ~60% more shipping surface area for the
MAS build than today.

---

## 10. Audit deliverables (Codex follow-up tasks)

When Codex picks up the kernel doctrine work, the following ground-truth
checks should be performed and recorded in
`docs/fusion/COGNITIVE_KERNEL_AUDIT_2026_05_03.md` (Phase 1 deliverable):

1. **Verify the 6 Helios Metal kernels in `agent_core/metal/` are wired.**
   Grep for each `.metal` filename in Swift and Rust source. Any orphaned
   kernel is a finding — either wire it or remove it.

2. **Verify `molora_inference.py` is build-time, not runtime.** Read the
   file. If it's invoked at runtime, port to Rust + MLX-Swift before MAS.

3. **Verify `agent_core::wbo6`, `agent_core::lattice`, `agent_core::sketch`
   modules are canonical Epistemos implementations** (not Kimi/GPT mockups
   pulled wholesale). Cross-check with fusion handoff §3 conflict rules.

4. **Verify `agent_core::sovereign`, `agent_core::provenance`,
   `agent_core::evolution` modules align with the Swift-side canonical
   implementations** (no parallel state, no parallel logic).

5. **Inventory every `agent_core::tools::registry` registered tool** with
   its current tier classification. Cross-check against the Pro→Core
   migration matrix. Any tool registered without tier classification is a
   gap — assign tier explicitly.

6. **Inventory every `omega-mcp` MCP server** — bundled vs external.
   Bundled servers must be re-derivable as in-process Rust modules
   (Phase 4). External servers stay Pro.

---

## Appendix A — Cross-references

```
docs/fusion/PROCESSES_AND_RUNTIMES_AUDIT_2026_05_03.md  ← this doc
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md     (the unified-binary doctrine)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md        (the deeper schema unification)
docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md      (Kimi/GPT as reference framing)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md
CLAUDE.md                                                (NON-NEGOTIABLE constraints)
```
