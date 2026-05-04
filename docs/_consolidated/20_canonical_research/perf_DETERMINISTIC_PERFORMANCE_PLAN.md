# EPISTEMOS DETERMINISTIC PERFORMANCE PLAN

**Audience:** Claude Code / Codex / any agentic coding tool
**Author of plan:** conservative max-performance + max-optimization advisor
**Project:** Epistemos (native macOS PKM/cognitive augmentation app)
**Stack:** Swift 6 + Rust (UniFFI + carve-outs) + Metal 4 + MLX-Swift + GRDB
**Hardware target:** Apple Silicon, M2 Pro 18 GB UMA baseline
**Codebase scale at start:** ~137K Swift, ~94K Rust
**Plan type:** layered, reversible, sprint-scoped, signpost-instrumented
**Plan length:** 6 sprints over ~12 weeks (parallel-compatible with active Phase I Rust agent migration and 24-week MoE roadmap)

> **HOW TO USE THIS DOCUMENT.** This is a *reference spec*, not a single-session prompt. Each sprint is a fresh Claude Code session. Read the sprint header, read the relevant inline reference, then execute the tasks in order. After every sprint, update `docs/PROGRESS.md` with the verification output and stop. Do not chain sprints in one session.

---

## 0. PREAMBLE — READ EVERY WORD BEFORE TOUCHING CODE

### 0.1 What this plan does

This plan converts five categories of *runtime inference* in Epistemos into *compile-time or load-time deterministic dispatch*:

1. **String-keyed registries** → compiled into `phf::Map` perfect-hash tables.
2. **JSON serialization on the FFI hot path** → replaced by `repr(C)` ring buffers and rkyv archives.
3. **Runtime Metal pipeline compilation** → moved offline into shipped `.metallib` + `MTLBinaryArchive`.
4. **Heap-allocated entity stores** → migrated to slotmap + structure-of-arrays component columns.
5. **Per-frame allocations** → arena-scoped via `bumpalo::Bump` reset each frame.

Plus three force-multipliers: GRDB pragma tuning, profile-guided optimization, and `os_signpost` coverage from day one.

Every change in this plan is reversible at the sprint boundary. Every change has a measurable acceptance criterion. No change requires touching the active Phase I Rust agent migration code paths.

### 0.2 What this plan does NOT do

It does NOT:

- Replace UniFFI everywhere. UniFFI keeps the cold/control plane (settings, MCP tool dispatch, panel open/close, anything fired at human cadence). Only events firing >100 Hz or >0.5 % of frame time migrate.
- Adopt rkyv for persisted data. Persisted data stays in GRDB. rkyv is for transient FFI messages only.
- Replace GRDB. GRDB is correct.
- Add a new database. SQLite + GRDB is the canonical store.
- Touch `agent_core` (the Phase I Rust agent runtime). That migration is independent.
- Adopt Bevy-style ECS. We use slotmap + SecondaryMap, which is 90 % of the benefit at 10 % of the complexity.
- Hand-write SIMD. The Rust compiler vectorizes well; explicit `std::simd` is a measured intervention, not a default.
- Switch allocators. macOS native is competitive on M-series.
- Pursue BOLT on macOS. Tooling too rough as of 2026.
- Build bindless GPU rendering. Binary archives capture 80 % of the Metal win at 10 % of the engineering cost. Bindless is a Phase II treat.

If Claude Code finds itself doing any of the above, it is drifting. Stop and re-read this section.

### 0.3 The five constraints (violations = build failure)

1. **NO HOT-PATH SERIALIZATION.** Any event firing >100 Hz or >0.5 % of frame budget MUST cross the FFI as a `repr(C)` POD struct in the ring buffer, never as a UniFFI-serialized type.
2. **NO MAIN-THREAD METAL COMPILATION.** Every `MTLRenderPipelineState` and `MTLComputePipelineState` MUST be sourced from a shipped `MTLBinaryArchive`. Runtime fallback is allowed but logged as a regression.
3. **NO STRING-KEYED DISPATCH IN INNER LOOPS.** Tool registries, edge-kind enums, slash commands, view dispatch — all phf or compile-time `enum`. `[String: Any]` and `as? AnyView` are forbidden in render hot paths.
4. **NO ALLOCATION IN RENDER FRAMES.** All per-frame data lives in `bumpalo::Bump` arenas reset at frame start. The first frame allocates; no subsequent frame allocates.
5. **EVERY OPTIMIZATION SHIPS WITH A SIGNPOST.** No optimization merges to main without an `os_signpost` interval bracketing the changed code path and a CI assertion on the signpost duration p99.

### 0.4 Anti-drift integration

This plan integrates with the existing Epistemos anti-drift system:

- **Layer 1 (CLAUDE.md):** add a 5-line block referencing this plan in the project root `CLAUDE.md`. Do not paste the whole plan there.
- **Layer 2 (post-compaction hook):** the existing `.claude/settings.json` hook fires `cat .claude/context-essentials.txt` after every compaction. *Append* the five constraints from §0.3 to `context-essentials.txt`. Do not replace the file.
- **Layer 3 (sprint-scoped sessions):** each sprint below is a separate Claude Code session. The agent's first action in any sprint session is `cat docs/PROGRESS.md && cat docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md | head -200`.
- **Layer 4 (PROGRESS.md):** the progress file gets a new top-level section `## Deterministic Performance Plan`. Each sprint's verification block writes here at completion.
- **Layer 5 (verification scripts):** every sprint has a final shell block that the agent runs and pastes to PROGRESS.md.

If any of those four layers is missing, run sprint 0 first.

### 0.5 Research grounding

This plan synthesizes:

- The Epistemos deterministic-performance research report (the long-form artifact that produced this plan; reference-level inline below).
- TigerBeetle ARCHITECTURE.md and TIGER_STYLE.md (deterministic-determinism principles).
- Mike Acton's CppCon 2014 *Data-Oriented Design and C++* talk.
- Andrew Kelley's *Practical Data Oriented Design* talk (Zig compiler, directly comparable workload).
- Apple WWDC22 #10102 *Target and optimize GPU binaries with Metal 3* and WWDC20 #10615 *Build GPU binaries with Metal*.
- David Koloski's published rkyv vs. {bincode, capnp, flatbuffers, ...} benchmarks.
- Cloudflare `mmap-sync` (production zero-copy IPC pattern with rkyv).
- Mitchell Hashimoto's Ghostty architecture (`libghostty` C-ABI core, Swift/AppKit shell).
- Phiresky's SQLite tuning guide and Stephen Margheim's Rails-on-SQLite series.
- Jakub Beránek's `cargo-pgo`.
- Apple WWDC23 #10166 *Write Swift macros*.

Specific links live in the deterministic-performance research artifact; do not re-fetch.

### 0.6 Realism budget

This plan is optimistic-but-realistic. Concretely:

- Sprint 0 (instrumentation + GRDB) is *certain* to ship within a week.
- Sprints 1–3 are *likely* to ship in 2 weeks each.
- Sprint 4 (zero-copy FFI carve-out) is the highest-variance sprint. Budget is 3 weeks; if blocked at end of week 2, fall back to Stabilization Path A (§7.1).
- Sprint 5 (Metal binary archive + tree-sitter SoA) is parallelizable across Sprint 4 if you have separate evening blocks.
- Sprint 6 (PGO + polish) is non-blocking and can slip without consequence.

Total realistic completion: **10–14 weeks of solo evenings/weekends**, alongside Phase I Rust agent migration.

If at any point you are >2 weeks behind on a sprint, invoke the Stabilization Path (§7) and ship what's done. Every sprint produces a shippable improvement on its own.

---

## 1. SPRINT 0 — INSTRUMENTATION + GRDB FAST PATH (week 1)

**Goal.** Make every subsequent sprint measurable. Apply the canonical SQLite pragma block. Tighten the release profile.

**Why first.** No optimization is real without measurement. The pragma changes are 1 file. The release profile changes are ~10 lines of TOML. The signpost wiring is 1 day. This sprint is high-value, low-risk, and unblocks everything below.

### 1.1 Tasks

#### Task 0.1 — Wire OSSignposter into hot paths

Apple's `OSSignposter` (macOS 12+) is the substrate for Instruments tracing. Add this module:

```swift
// Sources/Telemetry/Sig.swift
import os.signpost
import Foundation

public enum Sig {
    public static let render    = OSSignposter(subsystem: "io.epistemos.core", category: "render")
    public static let mcp       = OSSignposter(subsystem: "io.epistemos.core", category: "mcp")
    public static let graph     = OSSignposter(subsystem: "io.epistemos.core", category: "graph")
    public static let ffi       = OSSignposter(subsystem: "io.epistemos.core", category: "ffi")
    public static let storage   = OSSignposter(subsystem: "io.epistemos.core", category: "storage")
    public static let inference = OSSignposter(subsystem: "io.epistemos.core", category: "inference")

    @inlinable
    public static func interval<T>(
        _ poster: OSSignposter,
        _ name: StaticString,
        _ message: @autoclosure () -> String = "",
        _ body: () throws -> T
    ) rethrows -> T {
        let id = poster.makeSignpostID()
        let state = poster.beginInterval(name, id: id, "\(message())")
        defer { poster.endInterval(name, state) }
        return try body()
    }
}
```

Wire it at every UniFFI call site, every render frame, every GRDB query, every MCP invocation. Bracket pattern:

```swift
try Sig.interval(Sig.render, "frame", "nodes=\(scene.nodes.count)") {
    renderFrame(scene)
}
```

In Rust, expose a tiny shim crate `epistemos-trace` that wraps `os_signpost_emit_with_name_and_type` from `libsystem_trace.dylib` via `dlopen`. The shim publishes one `signpost_begin(category: u32, name: u32, id: u64)` and one `signpost_end(category: u32, name: u32, id: u64)`. Rust events arrive in the same Instruments trace as Swift events. Reference: Apple WWDC18 #405 *Measuring Performance Using Logging*.

#### Task 0.2 — Build a custom `Performance.instrpkg`

In Xcode → Instruments → File → New → Custom Instrument:

- Subsystems: `io.epistemos.core` with categories `render`, `mcp`, `graph`, `ffi`, `storage`, `inference`.
- Modeler: per-category interval list with p50/p99 columns.
- Reference: MEGA team writeup on customized Instruments packages (linked from the research report).

Save as `Tools/Performance.instrpkg` and check into the repo.

#### Task 0.3 — Apply the GRDB pragma block

Replace the existing GRDB configuration with this canonical block:

```swift
// Sources/Storage/DatabaseManager.swift
import GRDB

public func makeDatabasePool(at path: String) throws -> DatabasePool {
    var config = Configuration()

    config.prepareDatabase { db in
        try db.execute(sql: """
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;
            PRAGMA temp_store = MEMORY;
            PRAGMA mmap_size = 1073741824;
            PRAGMA cache_size = -65536;
            PRAGMA page_size = 4096;
            PRAGMA foreign_keys = ON;
            PRAGMA wal_autocheckpoint = 1000;
            PRAGMA optimize;
            PRAGMA fullfsync = 0;
            PRAGMA checkpoint_fullfsync = 0;
        """)

        let result = try String.fetchOne(db, sql: "PRAGMA integrity_check")
        guard result == "ok" else {
            throw DatabaseError.integrityCheckFailed(result ?? "unknown")
        }
    }

    return try DatabasePool(path: path, configuration: config)
}
```

**Pragma rationale:**
- `journal_mode = WAL`: concurrent reads, serialized writes, crash-safe.
- `synchronous = NORMAL`: under WAL, NORMAL is corruption-safe and dramatically faster than FULL on APFS. (Phiresky's published guide; Apple's own SQLite forum guidance.)
- `mmap_size = 1 GB`: enables `xFetch()` near-zero-copy reads. 1 GB on an 18 GB UMA machine is well-proportioned.
- `cache_size = -65536`: 64 MB page cache (negative value = KB, per SQLite convention).
- `page_size = 4096`: matches APFS block size. MUST be set before first write to take effect.
- `temp_store = MEMORY`: keeps temp B-trees off disk.
- `fullfsync = 0` + `checkpoint_fullfsync = 0`: APFS plus barrier-fsync gives sufficient durability for a single-user PKM. The ZERO_CORRUPTION_SPEC's atomic-write protocol covers the file-system layer separately.

**WARNING:** The `ZERO_CORRUPTION_SPEC` previously specified `synchronous = FULL` and `fullfsync = 1`. That was correct for the old assumptions. Under WAL with `synchronous = NORMAL`, durability is preserved at commit boundaries (the WAL is fsync'd before commit returns NORMAL behavior). This is documented SQLite behavior. If your security model requires FULL, revert these two pragmas — accept the ~3–5× write-latency cost.

Convert all hot queries to `cachedStatement(sql:)`:

```swift
// Before:
try db.execute(sql: "INSERT INTO notes (id, title, body) VALUES (?, ?, ?)",
               arguments: [id, title, body])

// After:
let stmt = try db.cachedStatement(sql:
    "INSERT INTO notes (id, title, body) VALUES (?, ?, ?)")
stmt.setUncheckedArguments([id, title, body])
try stmt.execute()
```

Audit: `git grep "db.execute(sql:" | wc -l` should drop to near zero in code paths under `Sources/Storage/Hot/`.

#### Task 0.4 — Tighten the release profile

In `Cargo.toml` (workspace root):

```toml
[profile.release]
lto = "fat"
codegen-units = 1
panic = "abort"
strip = "symbols"
opt-level = 3
debug = false
overflow-checks = false

[profile.release.package."*"]
opt-level = 3

[profile.release.build-override]
opt-level = 0
```

Run `cargo build --release` and record the binary size. Expect a 30–60 % reduction in dylib size.

#### Task 0.5 — Define performance budgets

Create `docs/perf-budgets.toml`:

```toml
[budgets]
cold_start_ms_p99 = 800
frame_ms_p99 = 8.3
mcp_invoke_ms_p99 = 2.0
graph_query_ms_p99 = 1.0
ffi_hot_path_us_p99 = 5.0
binary_size_mb_max = 12
sqlite_cold_open_ms_p99 = 20

[regressions]
allow_pct_over_budget = 10
allow_consecutive_violations = 3
```

Wire a CI step that runs the synthetic workload (defined in Task 0.6) and asserts these budgets via `xcrun xctrace export --xrun ...` parsing.

#### Task 0.6 — Define the synthetic workload

A single-shot workload that exercises the app realistically. Save as `bench/morning-session.swift`:

```swift
// Pseudo-spec — implement against your actual app entry points
// 1. Cold start
// 2. Open last vault
// 3. Scroll graph view 60 seconds at varying speeds
// 4. Open 100 random notes in sequence (10/sec)
// 5. Run 10 MCP tool invocations
// 6. Trigger 5 raw-thought captures
// 7. Search 20 queries against the FTS index
// 8. Close cleanly
```

This is your PGO training input later. It's also your CI regression workload.

### 1.2 Acceptance criteria

- `xcrun xctrace record --template Tools/Performance.instrpkg` produces a trace with intervals visible in all six categories.
- `sqlite3 vault.db "PRAGMA journal_mode"` returns `wal`.
- `sqlite3 vault.db "PRAGMA mmap_size"` returns `1073741824`.
- `du -sh target/release/libepistemos_core.dylib` shows ≥30 % reduction.
- `docs/perf-budgets.toml` exists and CI consumes it.
- `bench/morning-session` runs to completion.

### 1.3 Verification block (paste output to PROGRESS.md)

```bash
echo "=== Sprint 0 Verification ==="
sqlite3 ~/Library/Application\ Support/Epistemos/vault.db \
    "PRAGMA journal_mode; PRAGMA mmap_size; PRAGMA synchronous; PRAGMA cache_size;"
ls -lh target/release/libepistemos_core.dylib
grep -rc "OSSignposter\|Sig.interval" Sources/ | grep -v ":0$" | wc -l
grep -rc "signpost_begin\|signpost_end" crates/ | grep -v ":0$" | wc -l
test -f Tools/Performance.instrpkg && echo "instrpkg exists" || echo "MISSING"
test -f docs/perf-budgets.toml && echo "budgets exist" || echo "MISSING"
```

### 1.4 Stabilization checkpoint

Sprint 0 alone is a 20–40 % perceived-perf win. If nothing else in this plan ships, the GRDB tuning + LTO + measurement substrate is still a real, deployable improvement. Ship it as a release tag: `v-perf-0`.

---

## 2. SPRINT 1 — SLOTMAP + STRUCTURE-OF-ARRAYS MIGRATION (weeks 2–3)

**Goal.** Replace the existing entity store with `slotmap::SlotMap` + `SecondaryMap` columns. Expose entity handles across the FFI as `u64`. Parallel-run with the old store for one week, then cut over.

**Why second.** Slotmap is the foundation for sprints 2, 4, and 5. Without `u64` handles, the phf registry can't dispatch on entities, the ring buffer events can't reference entities, and the Tree-sitter SoA spans can't index by node. Slotmap also delivers immediate wins (O(1) ops, stale-handle safety).

**Reference:** Andrew Kelley's *Practical DoD* talk; Mike Acton's CppCon 2014; the slotmap discussion at github.com/fitzgen/generational-arena#13.

### 2.1 Tasks

#### Task 1.1 — Add the dependencies

```toml
# crates/substrate-core/Cargo.toml
[dependencies]
slotmap = "1.0"
smallvec = "1.13"
smol_str = "0.2"
parking_lot = "0.12"
```

#### Task 1.2 — Define the entity store

```rust
// crates/substrate-core/src/store.rs
use slotmap::{SlotMap, SecondaryMap, Key, KeyData};
use smallvec::SmallVec;
use smol_str::SmolStr;
use parking_lot::RwLock;

slotmap::new_key_type! {
    pub struct ArtifactKey;
    pub struct EdgeKey;
}

#[repr(u8)]
#[derive(Copy, Clone, Eq, PartialEq, Debug)]
pub enum ArtifactKind {
    RawThought = 0,
    Note       = 1,
    Tweet      = 2,
    Paper      = 3,
    Code       = 4,
    Image      = 5,
    Audio      = 6,
    Derived    = 7,
}

#[repr(u8)]
#[derive(Copy, Clone, Eq, PartialEq, Debug)]
pub enum EdgeKind {
    DerivedFrom  = 0,
    GeneratedBy  = 1,
    Cites        = 2,
    Annotates    = 3,
    Contradicts  = 4,
    LinksTo      = 5,
    EmbeddedIn   = 6,
}

pub struct ArtifactCore {
    pub kind: ArtifactKind,
    pub created_at: u64,
    pub modified_at: u64,
}

pub struct Edge {
    pub kind: EdgeKind,
    pub from: ArtifactKey,
    pub to:   ArtifactKey,
    pub weight: f32,
}

pub struct Substrate {
    artifacts: SlotMap<ArtifactKey, ArtifactCore>,

    // SoA component columns
    titles:     SecondaryMap<ArtifactKey, SmolStr>,
    bodies:     SecondaryMap<ArtifactKey, String>,
    embeddings: SecondaryMap<ArtifactKey, Box<[f32; 768]>>,

    edges:      SlotMap<EdgeKey, Edge>,
    out_edges:  SecondaryMap<ArtifactKey, SmallVec<[EdgeKey; 8]>>,
    in_edges:   SecondaryMap<ArtifactKey, SmallVec<[EdgeKey; 8]>>,
}
```

The SoA layout pays off whenever you iterate "all titles" or "all embeddings" — iterating embeddings as a contiguous `&[Box<[f32; 768]>]` saturates the memory bus the way an Array-of-Structures cannot.

#### Task 1.3 — Expose `u64` handles via C ABI

```rust
// crates/substrate-core/src/abi.rs
use crate::store::{ArtifactKey, ArtifactKind};
use slotmap::{Key, KeyData};

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct EpiArtifactRef(pub u64);

impl From<ArtifactKey> for EpiArtifactRef {
    #[inline(always)]
    fn from(k: ArtifactKey) -> Self { Self(k.data().as_ffi()) }
}

impl TryFrom<EpiArtifactRef> for ArtifactKey {
    type Error = ();
    #[inline(always)]
    fn try_from(r: EpiArtifactRef) -> Result<Self, ()> {
        Ok(Self::from(KeyData::from_ffi(r.0)))
    }
}

#[no_mangle]
pub unsafe extern "C" fn epi_artifact_kind(r: EpiArtifactRef) -> u32 {
    let Ok(key) = ArtifactKey::try_from(r) else { return u32::MAX; };
    let g = SUBSTRATE.read();
    g.artifacts.get(key).map(|a| a.kind as u32).unwrap_or(u32::MAX)
}
```

The generation tag in the upper bits gives you stale-handle safety: a Swift `EpiArtifactRef` from a deleted entity returns `u32::MAX` instead of a use-after-free.

#### Task 1.4 — Differential testing during migration

Keep the old store. Wrap every operation in a feature-flagged dual-write:

```rust
pub fn insert_artifact(&mut self, kind: ArtifactKind, title: &str) -> ArtifactKey {
    let new_key = self.new_store_insert(kind, title);
    #[cfg(feature = "differential")]
    {
        let old_key = self.legacy_store.insert(kind, title);
        self.differential_log.write_insert(new_key, old_key, kind, title);
    }
    new_key
}
```

Run `cargo test --features differential` continuously during the migration. Any divergence is a build failure.

#### Task 1.5 — Migration order

Migrate in this order — each step ships independently:

1. Read paths first (reads are safe; failures are visible).
2. Write paths next, behind the differential flag.
3. Component columns (titles, kinds) — start with two columns, validate, add more.
4. Edges last (most complex; most coupling).
5. Remove the legacy store. Remove the differential flag.

#### Task 1.6 — Swift bridge

The Swift side imports `EpiArtifactRef` as a transparent `UInt64` newtype:

```swift
public struct ArtifactRef: Hashable, Sendable, Codable {
    public let raw: UInt64
    @inlinable public init(raw: UInt64) { self.raw = raw }
    @inlinable public static var invalid: Self { Self(raw: UInt64.max) }
    @inlinable public var isValid: Bool { raw != UInt64.max }
}
```

All existing Swift call sites that took `ArtifactID: String` get migrated to `ArtifactRef`. This is the largest mechanical change in the sprint and is best done with a `sed` codemod plus manual review.

### 2.2 Acceptance criteria

- `cargo test --features differential -p substrate-core` passes after every commit.
- `git grep "ArtifactID: String" Sources/` returns 0 lines.
- Slotmap `.get(key)` measured at <10 ns under Instruments.
- Memory footprint of the new store is within ±10 % of the old store on a 100K-artifact synthetic vault.
- Stale-handle test: deleting an artifact then accessing its old `EpiArtifactRef` returns the sentinel, not a panic.

### 2.3 Verification block

```bash
echo "=== Sprint 1 Verification ==="
cargo test --features differential -p substrate-core 2>&1 | tail -20
echo "Legacy refs remaining (should be 0): $(grep -rn 'ArtifactID: String' Sources/ | wc -l)"
echo "Slotmap usages: $(grep -rn 'SlotMap\|SecondaryMap' crates/ | wc -l)"
cargo bench -p substrate-core slotmap 2>&1 | grep "time:"
```

### 2.4 Stabilization checkpoint

If you cut sprint 1 short at the read-path-only milestone, you still have stale-handle safety on reads and the foundation for sprint 2. Ship as `v-perf-1`.

---

## 3. SPRINT 2 — phf REGISTRIES + SWIFT MACRO ROUTING (weeks 4–5)

**Goal.** Replace every read-mostly string-keyed dispatch table with a compile-time phf map. Replace the artifact view router with a Swift macro that synthesizes an exhaustive `switch`.

**Why third.** This is the most directly *deterministic* of the wins. You're encoding knowledge you already have (the artifact ontology, the MCP tool catalog, the edge kinds, the slash commands) as build-time data. Lookup goes from "hash a string, walk a chain, compare bytes" to "two memory loads and a comparison."

**Reference:** Mainmatter's `rust-phf` case study (conduit-mime-types, JSON parse on startup → essentially zero cost). Apple WWDC23 #10166 *Write Swift macros*.

### 3.1 Tasks

#### Task 2.1 — Add phf to substrate-core

```toml
[dependencies]
phf = { version = "0.11", features = ["macros"] }

[build-dependencies]
phf_codegen = "0.11"
```

#### Task 2.2 — Compile the MCP tool registry

```rust
// crates/substrate-core/build.rs
use std::{env, fs::File, io::{BufWriter, Write}, path::Path};

fn main() {
    println!("cargo:rerun-if-changed=tools/");
    let out_dir = env::var("OUT_DIR").unwrap();
    let dest = Path::new(&out_dir).join("dispatch.rs");
    let mut f = BufWriter::new(File::create(&dest).unwrap());

    let tools = load_tools_from("tools/");
    let mut tool_map = phf_codegen::Map::<&'static str>::new();
    for tool in &tools {
        let entry = format!(
            "&Tool {{ name: \"{name}\", schema: &SCHEMA_{idx}, handler: handlers::{handler} }}",
            name = tool.name, idx = tool.idx, handler = tool.handler_fn);
        tool_map.entry(tool.name, &entry);
    }
    writeln!(f,
        "pub static TOOLS: phf::Map<&'static str, &'static Tool> = {};",
        tool_map.build()).unwrap();

    let mut ek = phf_codegen::Map::<&'static str>::new();
    for kind in &["derived_from", "generated_by", "cites", "annotates", "contradicts", "links_to", "embedded_in"] {
        ek.entry(kind, &format!("EdgeKind::{}", camel_case(kind)));
    }
    writeln!(f,
        "pub static EDGE_KINDS: phf::Map<&'static str, EdgeKind> = {};",
        ek.build()).unwrap();
}
```

In the lib:

```rust
// crates/substrate-core/src/dispatch.rs
include!(concat!(env!("OUT_DIR"), "/dispatch.rs"));
```

Now `TOOLS.get("graph_query")` is two memory loads and a comparison. No JSON parse on startup. No HashMap allocation. Lookup is faster than `HashMap` and collision-free.

#### Task 2.3 — Write the `@ArtifactView` Swift macro

Create a macro package:

```swift
// Sources/EpistemosMacros/ArtifactViewMacro.swift
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

public struct ArtifactViewMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Synthesize an exhaustive `static func make(for ref: ArtifactRef) -> some View` switch.
        // Full pattern in WWDC23 #10166 sample code.
    }
}

@main
struct EpistemosMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [ArtifactViewMacro.self]
}
```

Usage:

```swift
@ArtifactView(.rawThought)
struct RawThoughtView: View { /* ... */ }

@ArtifactView(.note)
struct NoteView: View { /* ... */ }

// At the call site:
@ViewBuilder
func view(for ref: ArtifactRef) -> some View {
    ArtifactRouter.make(for: ref)  // synthesized: exhaustive switch
}
```

The `some View` opaque return is critical. SwiftUI's diffing only works efficiently when the return type is statically resolvable. `AnyView` erases this and forces SwiftUI into worst-case re-layout.

#### Task 2.4 — Write the `@MCPSchema` proc macro

```rust
// crates/epistemos-macros/src/lib.rs
use proc_macro::TokenStream;

#[proc_macro_attribute]
pub fn mcp_schema(args: TokenStream, item: TokenStream) -> TokenStream {
    // Parse the function signature, extract types, emit a static SchemaNode tree
    // and a registration entry that build.rs picks up.
    item
}
```

Usage:

```rust
#[mcp_schema(name = "graph_query", description = "Query the knowledge graph")]
pub fn graph_query(args: GraphQueryArgs) -> Result<GraphQueryResult, ToolError> {
    // ...
}
```

This eliminates the runtime JSON-schema parse. Schemas live as `&'static SchemaNode` trees, baked at build time.

#### Task 2.5 — Audit `[String: Any]` and `as? AnyView`

Run:

```bash
git grep -n "\[String: Any\]" Sources/ > audit/string-any.txt
git grep -n "as? AnyView\|AnyView(" Sources/ > audit/anyview.txt
```

Each line in those files is a deterministic-dispatch opportunity. Migrate at least the render hot paths to typed enums + macro routing. Cold paths (settings, debug menus) can keep dynamic dispatch.

### 3.2 Acceptance criteria

- `cargo build --release` produces a binary where `TOOLS`, `EDGE_KINDS`, `SLASH_COMMANDS` are static `phf::Map`s.
- No JSON-schema parse on startup (verify by stripping the JSON-parse imports from the runtime path; build must succeed).
- `audit/string-any.txt` and `audit/anyview.txt` are committed to the repo as a record.
- The `@ArtifactView` macro generates exhaustive switch coverage; removing one `case` from `ArtifactKind` causes a Swift compile error citing the macro-synthesized `make` function.

### 3.3 Verification block

```bash
echo "=== Sprint 2 Verification ==="
nm -g target/release/libepistemos_core.dylib 2>/dev/null | grep -E "TOOLS|EDGE_KINDS|SLASH_COMMANDS" | head
test -f audit/string-any.txt && echo "string-any audit: $(wc -l < audit/string-any.txt) lines"
test -f audit/anyview.txt && echo "anyview audit:    $(wc -l < audit/anyview.txt) lines"
swift build 2>&1 | grep -E "macro|expansion" | head
```

### 3.4 Stabilization checkpoint

If sprint 2 only completes the Rust side (TOOLS/EDGE_KINDS/SLASH_COMMANDS) and not the Swift macro, that's still a real win. The Swift macro is a 1-week task that can land later as `v-perf-2.5`. Don't delay sprint 3 waiting for it.

---

## 4. SPRINT 3 — METAL BINARY ARCHIVE + TREE-SITTER SoA (weeks 5–6, parallelizable)

**Goal.** Eliminate runtime Metal pipeline compilation. Pre-compute Tree-sitter highlight spans into a flat SoA cache.

**Why parallel-compatible.** Sprint 3 touches rendering and editor code paths that are independent of the substrate-core changes in sprints 1–2. If you have an evening free during sprint 1 or 2, work on this. Otherwise, run it after sprint 2.

**Reference:** Apple WWDC22 #10102 *Target and optimize GPU binaries with Metal 3*; WWDC20 #10615 *Build GPU binaries with Metal*; Helix 25.07 release notes on incremental highlighting.

### 4.1 Tasks

#### Task 3.1 — Move Metal shader compilation offline

```bash
# scripts/build-metal.sh
xcrun -sdk macosx metal -O3 -ffast-math \
    Resources/Shaders/GraphShaders.metal \
    -o $(OUT)/GraphShaders.air

xcrun -sdk macosx metallib $(OUT)/GraphShaders.air \
    -o Resources/GraphShaders.metallib
```

Add `Resources/GraphShaders.metallib` to your bundle. Replace `device.makeDefaultLibrary(source:)` with:

```swift
let url = Bundle.main.url(forResource: "GraphShaders", withExtension: "metallib")!
let library = try device.makeLibrary(URL: url)
```

This alone saves 30–100 ms at cold start.

#### Task 3.2 — Generate the binary archive

Create `pipelines.mtlp` (a JSON spec describing every PSO your app actually uses):

```json
{
  "pipelines": [
    {
      "name": "graph_node_render",
      "vertexFunction": "graph_node_vertex",
      "fragmentFunction": "graph_node_fragment",
      "pixelFormat": "BGRA8Unorm"
    },
    {
      "name": "graph_edge_render",
      "vertexFunction": "graph_edge_vertex",
      "fragmentFunction": "graph_edge_fragment",
      "pixelFormat": "BGRA8Unorm"
    },
    {
      "name": "force_directed_layout",
      "computeFunction": "force_directed_kernel"
    }
  ]
}
```

Build the archive:

```bash
xcrun -sdk macosx metal-tt \
    --pipelines pipelines.mtlp \
    --library Resources/GraphShaders.metallib \
    --output Resources/GraphShaders.metalbinary
```

Use it at runtime:

```swift
let archiveURL = Bundle.main.url(forResource: "GraphShaders", withExtension: "metalbinary")!
let archiveDesc = MTLBinaryArchiveDescriptor()
archiveDesc.url = archiveURL
let archive = try device.makeBinaryArchive(descriptor: archiveDesc)

let pipeDesc = MTLRenderPipelineDescriptor()
pipeDesc.vertexFunction = library.makeFunction(name: "graph_node_vertex")!
pipeDesc.fragmentFunction = library.makeFunction(name: "graph_node_fragment")!
pipeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
pipeDesc.binaryArchives = [archive]

let pso = try device.makeRenderPipelineState(descriptor: pipeDesc, options: [])
```

PSO creation now hits the archive, not the compiler.

#### Task 3.3 — Convert to argument buffers + UMA shared storage

For the graph render path:

```swift
// One buffer holds all node records, written by Rust through bytesNoCopy
let nodeBuffer = device.makeBuffer(
    bytesNoCopy: substrate.nodeArrayPtr(),
    length: substrate.nodeArraySize(),
    options: .storageModeShared,
    deallocator: nil)!

let argEncoder = renderPSO.makeArgumentEncoder(bufferIndex: 0)
let argBuffer = device.makeBuffer(length: argEncoder.encodedLength, options: .storageModeShared)!
argEncoder.setArgumentBuffer(argBuffer, offset: 0)
argEncoder.setBuffer(nodeBuffer, offset: 0, index: 0)
```

UMA + shared storage = the GPU reads what the CPU wrote. Zero copies.

#### Task 3.4 — Tree-sitter SoA highlight cache

In Rust:

```rust
// crates/substrate-core/src/editor/highlight.rs
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct HighlightSpan {
    pub start_byte: u32,
    pub end_byte:   u32,
    pub style:      u16,
    pub _pad:       u16,
}
const _: () = assert!(std::mem::size_of::<HighlightSpan>() == 12);

pub struct HighlightCache {
    spans: Vec<HighlightSpan>,
    parser: tree_sitter::Parser,
    tree:   Option<tree_sitter::Tree>,
}

impl HighlightCache {
    pub fn reparse(&mut self, source: &str) {
        let new_tree = self.parser.parse(source, self.tree.as_ref());
        self.tree = new_tree;
        self.spans.clear();
        if let Some(t) = &self.tree {
            self.populate_spans(t.root_node(), source);
        }
        self.spans.sort_unstable_by_key(|s| s.start_byte);
    }

    pub fn spans_in_range(&self, start: u32, end: u32) -> &[HighlightSpan] {
        let lo = self.spans.partition_point(|s| s.end_byte <= start);
        let hi = self.spans.partition_point(|s| s.start_byte < end);
        &self.spans[lo..hi]
    }
}
```

Expose across the FFI:

```rust
#[no_mangle]
pub unsafe extern "C" fn epi_highlight_spans(
    cache: *const HighlightCache,
    start: u32,
    end: u32,
    out_ptr: *mut *const HighlightSpan,
    out_len: *mut usize,
) {
    let spans = (*cache).spans_in_range(start, end);
    *out_ptr = spans.as_ptr();
    *out_len = spans.len();
}
```

Swift calls this once per frame, walks the slice, paints. No serialization. No allocation per frame.

### 4.2 Acceptance criteria

- `Resources/GraphShaders.metallib` and `GraphShaders.metalbinary` exist in the shipped bundle.
- `xcrun xctrace export ... | grep "Pipeline State Compilation"` shows zero events during a cold start.
- Cold-start time drops by 30–100 ms (measured via signpost interval `cold_start`).
- Graph rendering at 10K nodes hits sustained 120 fps on M2 Pro (signpost `frame` p99 < 8.3 ms).
- `epi_highlight_spans` returns in <50 µs for typical viewport ranges.

### 4.3 Verification block

```bash
echo "=== Sprint 3 Verification ==="
test -f Resources/GraphShaders.metallib && echo "metallib exists ($(du -h Resources/GraphShaders.metallib | cut -f1))" || echo "MISSING"
test -f Resources/GraphShaders.metalbinary && echo "metalbinary exists ($(du -h Resources/GraphShaders.metalbinary | cut -f1))" || echo "MISSING"
nm -gU target/release/libepistemos_core.dylib | grep epi_highlight_spans
```

### 4.4 Stabilization checkpoint

The `.metallib` change alone is shippable as `v-perf-3a`. The binary archive is `v-perf-3b`. The argument-buffer conversion is `v-perf-3c`. The Tree-sitter SoA is `v-perf-3d`. Each is independently valuable.

---

## 5. SPRINT 4 — ZERO-COPY FFI CARVE-OUT (weeks 7–9, highest variance)

**Goal.** Carve out a `substrate-rt` crate with a `repr(C)` SPSC ring buffer for hot-path events. Migrate the highest-volume UniFFI calls onto the ring. Keep UniFFI for the cold/control plane.

**Why this is the variance sprint.** It's the largest engineering investment. It's where determinism produces the largest single perf win. It's also where the unsafe surface grows. Budget 3 weeks. If at end of week 2 you don't have the ring working, fall back to Stabilization Path A.

**Reference:** Ghostty `libghostty` C-ABI architecture; Cloudflare `mmap-sync`; UniFFI overhead documented at github.com/mozilla/uniffi-rs#244; Apple `MTLStorageMode.shared` UMA semantics.

### 5.1 Tasks

#### Task 4.1 — Create the substrate-rt crate

```toml
# crates/substrate-rt/Cargo.toml
[package]
name = "substrate-rt"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib", "cdylib"]

[dependencies]
slotmap = "1.0"
substrate-core = { path = "../substrate-core" }
```

#### Task 4.2 — Implement the ring buffer

```rust
// crates/substrate-rt/src/ring.rs
use std::sync::atomic::{AtomicU64, Ordering};
use std::cell::UnsafeCell;
use std::mem::MaybeUninit;

const CACHE_LINE: usize = 128;
const RING_SIZE: usize = 1 << 14; // 16384 slots

#[repr(C)]
#[derive(Copy, Clone)]
pub struct GraphEvent {
    pub kind:      u32,
    pub _pad0:     u32,
    pub entity:    u64,
    pub edge:      u64,
    pub timestamp: u64,
    pub payload:   [u8; 32],
}
const _: () = assert!(std::mem::size_of::<GraphEvent>() == 64);

#[repr(C, align(128))]
pub struct EventRing {
    _pad0: [u8; CACHE_LINE],
    head:  AtomicU64,
    _pad1: [u8; CACHE_LINE - 8],
    tail:  AtomicU64,
    _pad2: [u8; CACHE_LINE - 8],
    slots: [UnsafeCell<MaybeUninit<GraphEvent>>; RING_SIZE],
}

unsafe impl Sync for EventRing {}

impl EventRing {
    pub fn new() -> Box<Self> {
        unsafe { Box::<Self>::new_zeroed().assume_init() }
    }

    #[inline(always)]
    pub fn push(&self, ev: &GraphEvent) -> bool {
        let head = self.head.load(Ordering::Relaxed);
        let tail = self.tail.load(Ordering::Acquire);
        if head.wrapping_sub(tail) >= RING_SIZE as u64 {
            return false;
        }
        let idx = (head as usize) & (RING_SIZE - 1);
        // SAFETY: slot ownership is bounded by head/tail; the producer is the unique writer
        unsafe {
            let slot = self.slots[idx].get();
            (*slot).write(*ev);
        }
        self.head.store(head.wrapping_add(1), Ordering::Release);
        true
    }

    #[inline(always)]
    pub fn pop(&self) -> Option<GraphEvent> {
        let tail = self.tail.load(Ordering::Relaxed);
        let head = self.head.load(Ordering::Acquire);
        if tail == head { return None; }
        let idx = (tail as usize) & (RING_SIZE - 1);
        // SAFETY: slot was written by the producer before head advanced past tail
        let ev = unsafe {
            let slot = self.slots[idx].get();
            (*slot).assume_init_read()
        };
        self.tail.store(tail.wrapping_add(1), Ordering::Release);
        Some(ev)
    }
}

#[no_mangle]
pub extern "C" fn epi_ring_new() -> *mut EventRing {
    Box::into_raw(EventRing::new())
}

#[no_mangle]
pub unsafe extern "C" fn epi_ring_free(r: *mut EventRing) {
    drop(Box::from_raw(r));
}

#[no_mangle]
pub unsafe extern "C" fn epi_ring_push(r: *const EventRing, ev: *const GraphEvent) -> bool {
    (*r).push(&*ev)
}

#[no_mangle]
pub unsafe extern "C" fn epi_ring_pop(r: *const EventRing, out: *mut GraphEvent) -> bool {
    if let Some(ev) = (*r).pop() {
        *out = ev;
        true
    } else {
        false
    }
}
```

#### Task 4.3 — Write the Swift module map

```
// Sources/EpistemosRT/include/module.modulemap
module EpistemosRT {
    header "epistemos_rt.h"
    export *
}
```

```c
// Sources/EpistemosRT/include/epistemos_rt.h
#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef struct EventRing EventRing;

typedef struct {
    uint32_t kind;
    uint32_t _pad0;
    uint64_t entity;
    uint64_t edge;
    uint64_t timestamp;
    uint8_t  payload[32];
} GraphEvent;

EventRing* epi_ring_new(void);
void       epi_ring_free(EventRing*);
bool       epi_ring_push(const EventRing*, const GraphEvent*);
bool       epi_ring_pop(const EventRing*, GraphEvent*);
```

Swift consumption:

```swift
import EpistemosRT

@MainActor
final class EventDrain {
    private let ring: OpaquePointer
    init(ring: OpaquePointer) { self.ring = ring }

    @inline(__always)
    func drain(_ sink: (GraphEvent) -> Void) {
        var ev = GraphEvent()
        while withUnsafeMutablePointer(to: &ev, { epi_ring_pop(ring, $0) }) {
            sink(ev)
        }
    }
}
```

#### Task 4.4 — Identify hot-path events to migrate

From your sprint-0 signpost data, identify the 5–10 highest-frequency UniFFI calls. Likely candidates:

- Cursor moves
- Edit deltas (per-keystroke)
- Layout updates from force-directed layout
- MCP streaming token chunks
- Frame-tick updates from the agent runtime

Each gets a `kind` constant and a payload schema. The payload layout MUST be `repr(C)` POD with no `String`, `Vec`, or `Box` — only inline-sized fields.

#### Task 4.5 — Migrate one event at a time

For each hot-path event:

1. Add the `kind` constant.
2. Implement the Rust producer site.
3. Implement the Swift consumer site.
4. Run differential test: both old (UniFFI) and new (ring) paths fire; compare results.
5. Once parity is established, remove the UniFFI path.

**Do not migrate more than one event per day.** This is the sprint where over-eagerness causes real bugs. The ring is `unsafe`; every migration is a chance to introduce a use-after-free.

#### Task 4.6 — mmap'd raw-thoughts log (optional, can defer to sprint 5)

The same architectural principle applies to the raw-thoughts capture path. See research artifact §3.6 for the full mmap'd append-only design. If you have time at the end of sprint 4, ship the basic version. If not, it lives in sprint 5.

### 5.2 Acceptance criteria

- `cargo test -p substrate-rt` passes; ring is correct under SPSC stress test (1M events, no loss, no duplicate).
- Median latency of migrated FFI events drops to <1 µs (from ~20–100 µs through UniFFI; verify via signpost).
- No regressions in differential testing for 7 consecutive days before removing the UniFFI fallback.
- Unsafe surface is contained: `git grep -c "unsafe " crates/substrate-rt/src/` should be ≤20 lines, all with `// SAFETY:` comments.

### 5.3 Verification block

```bash
echo "=== Sprint 4 Verification ==="
cargo test -p substrate-rt --release 2>&1 | tail -10
cargo bench -p substrate-rt ring 2>&1 | grep "time:"
grep -c "// SAFETY:" crates/substrate-rt/src/*.rs
nm -gU target/release/libsubstrate_rt.dylib | grep "epi_ring_"
```

### 5.4 Stabilization checkpoint

If sprint 4 stalls, ship what you have. Even one migrated hot-path event (cursor moves alone) is a real perceived-latency win. Tag as `v-perf-4-partial`. The remaining events can migrate one at a time over the following weeks without urgency.

---

## 6. SPRINT 5 — PGO + ARENA ALLOCATORS + RAW-THOUGHTS mmap (weeks 10–11)

**Goal.** Apply profile-guided optimization to the Rust crates. Introduce per-frame `bumpalo::Bump` arenas. If not already done, ship the mmap'd raw-thoughts log.

**Why fifth.** PGO is the highest-payoff optimization that *requires* the previous sprints to be in place. Without sprint 0's instrumentation, you don't have a workload to train on. Without sprint 4's ring, the FFI hot path isn't representative. Run PGO on a stable foundation.

**Reference:** Jakub Beránek's `cargo-pgo` and the Rust Performance Book on PGO. Bumpalo benchmarks at vorner.github.io/2020/09/03/performance-cheating.html.

### 6.1 Tasks

#### Task 5.1 — Install cargo-pgo

```bash
cargo install cargo-pgo
```

#### Task 5.2 — Run instrumented build + workload

```bash
cargo pgo build
./target/release-pgo-instrumented/epistemos-bench --workload bench/morning-session.toml
cargo pgo optimize build
```

The PGO-optimized binary lives at `target/release-pgo/`. Run sprint-0's signpost workload against it; expect a 5–15 % wall-clock improvement on the Rust-bound workloads.

#### Task 5.3 — Bumpalo arenas in render and MCP paths

```rust
// crates/substrate-core/src/render/frame.rs
use bumpalo::Bump;

pub struct FrameCtx {
    arena: Bump,
}

impl FrameCtx {
    pub fn new() -> Self {
        Self { arena: Bump::with_capacity(16 * 1024 * 1024) }
    }

    #[inline(always)]
    pub fn begin_frame(&mut self) {
        self.arena.reset(); // O(1), no per-frame allocation cost
    }

    #[inline(always)]
    pub fn alloc_spans(&self, count: usize) -> &mut [HighlightSpan] {
        self.arena.alloc_slice_fill_default(count)
    }
}
```

Wire the `FrameCtx` to be reset by the Metal frame callback before any frame work begins.

For MCP, use a per-invocation arena:

```rust
pub fn invoke_tool(name: &str, args: &[u8]) -> Result<Vec<u8>, ToolError> {
    let arena = Bump::with_capacity(1 * 1024 * 1024);
    let parsed_args = parse_args_in(&arena, args)?;
    let tool = TOOLS.get(name).ok_or(ToolError::Unknown)?;
    (tool.handler)(&arena, parsed_args)
}
```

#### Task 5.4 — Raw-thoughts mmap (if not done in sprint 4)

```rust
// crates/substrate-rt/src/raw_log.rs
use memmap2::{MmapMut, MmapOptions};
use std::fs::OpenOptions;
use std::sync::atomic::{AtomicU64, Ordering};

#[repr(C)]
#[derive(Copy, Clone)]
pub struct RawThought {
    pub timestamp_ns: u64,
    pub kind:         u32,
    pub len:          u32,
    pub xxh3:         u64,
    pub bytes:        [u8; 232],
}
const _: () = assert!(std::mem::size_of::<RawThought>() == 256);

pub struct RawLog {
    map:  MmapMut,
    head: *const AtomicU64,
}

unsafe impl Send for RawLog {}
unsafe impl Sync for RawLog {}

impl RawLog {
    pub fn open(path: &std::path::Path, size_mb: usize) -> std::io::Result<Self> {
        let f = OpenOptions::new().read(true).write(true).create(true).open(path)?;
        f.set_len((size_mb * 1024 * 1024) as u64)?;
        let map = unsafe { MmapOptions::new().map_mut(&f)? };
        let head = map.as_ptr() as *const AtomicU64;
        Ok(Self { map, head })
    }

    pub fn append(&self, t: &RawThought) {
        // SAFETY: head is the first 8 bytes of an mmap'd region; appends are bounded
        unsafe {
            let head = &*self.head;
            let off = head.fetch_add(256, Ordering::AcqRel) as usize + 8;
            let dst = self.map.as_ptr().add(off) as *mut RawThought;
            std::ptr::write(dst, *t);
        }
    }
}
```

Swift tails the same file via `mmap()` directly — no FFI per record.

### 6.2 Acceptance criteria

- `cargo pgo optimize build` succeeds.
- PGO binary shows ≥5 % wall-clock improvement on `bench/morning-session` (record before/after in PROGRESS.md).
- Render frame allocation count, measured via Instruments → Allocations, drops to single digits per frame (was likely hundreds).
- Raw-thought capture latency (signpost `raw_thought_capture`) drops below 1 ms p99.

### 6.3 Verification block

```bash
echo "=== Sprint 5 Verification ==="
ls -lh target/release-pgo/libepistemos_core.dylib 2>/dev/null
ls -lh target/release/libepistemos_core.dylib 2>/dev/null
cargo bench -p substrate-core 2>&1 | grep "time:" | tail -20
test -f ~/Library/Application\ Support/Epistemos/raw-thoughts.log && echo "raw log exists"
```

### 6.4 Stabilization checkpoint

PGO is non-blocking; it can ship as a separate release `v-perf-5` whenever it's ready. The bumpalo arenas are independently shippable as `v-perf-5b`.

---

## 7. STABILIZATION PATHS

If at any point scope gets messy, fall back to one of these.

### 7.1 Path A — Cheap wins only

Keep:
- Sprint 0 in entirety (instrumentation + GRDB pragmas + LTO).
- Sprint 1 read paths only (slotmap behind feature flag, no SecondaryMap migration).
- Sprint 3a only (pre-compiled metallib; skip binary archive and argument buffers).

Skip everything else.

This is roughly 2–3 weeks of work for a 25–35 % perceived-perf win and a measurable cold-start reduction. Ship as `v-perf-stable-A`.

### 7.2 Path B — Skip the FFI carve-out

If sprint 4 turns into a swamp, skip it. UniFFI overhead is real but not catastrophic at moderate event rates. The other sprints (0, 1, 2, 3, 5) all stand without sprint 4.

The mmap'd raw-thoughts log in sprint 5 still gives you the lowest-latency capture path you'll likely care most about.

Ship as `v-perf-stable-B`.

### 7.3 Path C — Defer the macro work

If Swift macros prove finicky, ship the Rust-side phf registries (sprint 2 partial) and keep the Swift view router as a hand-maintained switch with a `precondition(false, "missing case")` guard. Add the macro later as a polish item.

---

## 8. ACCEPTANCE CRITERIA — END STATE

When all sprints are done, the following hold:

1. `du -sh target/release/libepistemos_core.dylib` is at least 30 % smaller than at sprint-0 start.
2. Cold-start time, measured at signpost `cold_start`, p99 < 800 ms on M2 Pro.
3. Render frame, measured at signpost `frame`, p99 < 8.3 ms on M2 Pro at 10K-node graph.
4. MCP tool invocation, measured at signpost `mcp`, p99 < 2 ms for in-process tools.
5. Median FFI hot-path event, measured at signpost `ffi`, p50 < 1 µs.
6. SQLite hot query, measured at signpost `storage`, p99 < 1 ms for indexed reads.
7. Binary size of the shipped `.app` bundle ≤ 80 MB.
8. `cargo test --workspace` passes; differential-test feature flag is removed.
9. `git grep -n "[String: Any]" Sources/Render/ Sources/Graph/` returns 0 lines.
10. `git grep -n "as? AnyView\|AnyView(" Sources/Render/` returns 0 lines.
11. Every signpost interval has a CI assertion on its p99 budget.
12. `xcrun xctrace export --xrun` of `bench/morning-session` shows zero "Pipeline State Compilation" events.
13. Tag the release as `v-perf-1.0`.

---

## 9. WHAT THIS PLAN INTENTIONALLY DEFERS

These are real wins, but Phase II:

- **GPU-driven force-directed layout** (Barnes-Hut on Metal compute). Phase II — only meaningful past 100K nodes.
- **Bindless rendering with argument buffer hierarchies**. Phase II — meaningful past 100K draw calls.
- **rkyv archive in shared memory for variable-size graph snapshots**. Phase II — implement once you measure that the ring buffer doesn't cover the variable-size cases.
- **BOLT post-link optimization on macOS**. Tooling too rough; revisit in 6 months.
- **Custom SIMD for embedding similarity**. Profile first; the compiler may already vectorize.
- **TigerBeetle-style storage engine for the entity graph**. Wildly out of scope; SQLite + GRDB is correct.
- **NaN-boxing / tagged pointers**. Statically-typed Rust niche optimizations make this a no-op.

---

## 10. AGENT CONTRACT

Claude Code, executing this plan:

1. **READ** the entire sprint header, including its acceptance criteria and verification block, before any code change.
2. **ANNOUNCE** the sprint and current task at the top of every assistant turn ("Sprint 2 / Task 2.3 — Writing the @ArtifactView Swift macro").
3. **BUILD INCREMENTALLY**. After each file change, run the smallest possible verification (`cargo check -p substrate-core`, `swift build`, etc.).
4. **NEVER SKIP THE VERIFICATION BLOCK**. Run it at the end of every sprint and paste its output to `docs/PROGRESS.md`.
5. **NEVER DRIFT**. If a task seems to require something not in this plan or its referenced research artifact, STOP and surface the question. Do not invent.
6. **NEVER TOUCH `agent_core/`**. The Phase I Rust agent migration is independent. If a task seems to require touching it, STOP and surface the question.
7. **PRESERVE THE FIVE CONSTRAINTS** (§0.3) in every change.
8. **WRITE `// SAFETY:` COMMENTS** on every `unsafe` block, citing the invariants enforced.
9. **AT THE END OF EVERY SPRINT**, propose the next sprint's first task in a single sentence, then stop. Do not auto-continue.

Stop here. Do not take initiative beyond the current sprint.

---

*This is the plan. The research is done. Ship it.*
