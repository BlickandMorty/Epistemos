---
state: canon
canon_promoted_on: 2026-05-05
question: "is mmap utilizable through my app as well?" (user, 2026-05-05)
companion_to: docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §2.2 invariant #1
---

# Where mmap lives in Epistemos — 2026-05-05 audit

> **Question answered:** the user asked whether `mmap` is utilized
> across the app. Short answer: **yes — across both the Swift host
> and the Rust kernel — and the canonical pattern is documented
> below so future drift on this question doesn't have to re-derive
> the answer.**
>
> This doc is the canonical reference for "where mmap lives in
> Epistemos." It is companion to doctrine §2.2 invariant #1
> (zero-copy unified memory) — `mmap` is the kernel-layer mechanism
> that makes the invariant *cheap*; UMA via `MTLBuffer.storageModeShared`
> is the GPU-layer mechanism. They are the same physical RAM pool.

## Inventory — where mmap is actually called

### Rust kernel (`agent_core`)

| Site | What | Mode | Purpose |
|---|---|---|---|
| `agent_core/src/arena/mod.rs:224` | `MmapOptions::new().len(SIZE).map_mut(&file)?` | RW | The Arena ring-buffer for FFI-side request/response slots. Header-prefixed; 16 MB per segment. Backs the `ShmPool` TTL-eviction surface. |
| `agent_core/src/tools/workspace_search.rs:163, 426, 510, 621, 660` | `Mmap::map(&file).ok()?` | RO | Workspace symbol search — read whole source files via mmap so the OS page cache absorbs hot lookups across multiple search invocations. |
| `agent_core/Cargo.toml:110` | `memmap2 = "0.9"` | n/a | Direct dependency. |
| Transitive via `tantivy` | tantivy's `mmap` feature | RO | Posting lists + term dictionaries for the Shadow lexical index (`epistemos-shadow` crate). |
| Transitive via `usearch` | usearch HNSW segment mmap | RO | Vector index for the Shadow semantic index. |

### Swift host (`Epistemos`)

| Site | What | Mode | Purpose |
|---|---|---|---|
| `Epistemos/Sync/SearchIndexService.swift:235` | `PRAGMA mmap_size = 268435456` (256 MiB) | RO | SQLite mmap for the FTS5 derivative full-text index. Trimmed from 1 GiB → 256 MiB during the 2026-04-29 perf wave (kernel page cache absorbs the gap; ~55 MB resident saved at idle). |
| `Epistemos/State/PaperclipStateStore.swift:76` | `sqlite3_exec(... PRAGMA mmap_size = 268435456 ...)` | RO | Paperclip ephemeral state store. |
| GRDB (vault, audit, agent_events, graph_events DBs) | inherits SQLite's `PRAGMA mmap_size` | RO | Per-DB pragma block; the canonical block lives at `Epistemos/Sync/SearchIndexService.swift:204-228` and is documented in CLAUDE.md "Wave 2026-04-29 perf additions". |
| `Epistemos/Engine/MetalRuntimeManager.swift` (37 sites) | `MTLBuffer.makeBuffer(... .storageModeShared)` | RW (CPU↔GPU) | UMA zero-copy buffers for Mamba-2 / KIVI / Metal compute shaders. **NOT mmap of a file** — but it IS `mmap`'s GPU-layer cousin (one physical RAM pool, no `cudaMemcpy`). Doctrine §2.2 invariant #1. |

## Three mmap surfaces, three rules

### 1. File mmap (memmap2 + SQLite PRAGMA mmap_size)

**Purpose:** read-mostly large files (source code in workspace search,
posting lists in tantivy, vector segments in usearch, SQLite database
files for FTS5 + paperclip + audit DBs).

**Rule:** prefer **read-only** mmap unless the surface is a header-
prefixed ring buffer (Arena) where in-place mutation is the design.
Match the SQLite `mmap_size` pragma to the working-set size, not to
the DB file size — kernel page cache fills the gap on cold reads via
readahead, and oversized `mmap_size` just steals address space the
process can't use for other allocations.

**Tier impact:** all tiers. Apple Sandbox (MAS) does NOT block mmap
of files the app has read access to; the security-scoped bookmark
path resolution happens before mmap, not at mmap time.

### 2. UMA zero-copy MTLBuffer (Apple Silicon)

**Purpose:** CPU↔GPU↔ANE shared-memory buffers for inference hot path
(Mamba-2 SSM state, KIVI KV cache, Metal compute shader inputs/outputs,
landing-wave FDTD GPU sim).

**Rule:** every hot-path tensor lives in `storageModeShared`. Doctrine
§2.2 invariant #1 forbids `cudaMemcpy`-style double-buffering. The
139-153 GB/s UMA fabric bandwidth is wasted by any patch that adds a
`memcpy`-equivalent on the inference hot path.

**Tier impact:** all tiers. Apple Foundation Models, MLX-Swift inference,
and the Rex Metal kernels all share this pool.

**NOT mmap of a file:** `storageModeShared` is GPU-resident memory
that the CPU can read/write directly because all three engines share
one physical RAM pool. It is the *cousin* of file mmap, not the same
mechanism. Both are zero-copy.

### 3. KV cache implantation via `MTLBuffer.contents()` (Research tier only)

**Purpose:** direct pointer access to weight/KV regions for activation
steering, KV implantation, raw-memory inspection, weight surgery
("the Glass Ball").

**Rule:** Research tier only (Annex A.10, A.11). Never in Core or
Pro builds. Requires `cs.disable-library-validation` to load
`AppleNeuralEngine.framework` dynamically; Apple does not grant this
to App Store apps.

**Tier impact:** Research only. Annex A.10 + A.11 cover the doctrine.

## Three drift hazards to watch

1. **Re-introducing `cudaMemcpy`-style copies** when porting CUDA
   research code. The doctrine §6 "copy hot-path tensors across
   CPU↔GPU↔ANE" forbidden line catches this.
2. **Oversized SQLite `mmap_size`** on derivative indices. The 2026-
   04-29 perf wave trimmed `SearchIndexService.swift` from 1 GiB →
   256 MiB. New SQLite-using code SHOULD start at 256 MiB and only
   increase if hot-path benchmarks justify it.
3. **Sandbox confusion.** `mmap` works fine under Apple Sandbox for
   files the app can read. The MAS sandbox restriction is on
   *security-scoped bookmarks* (vault file access requires explicit
   user grant), not on mmap itself. Don't conflate the two.

## Cross-refs

- Doctrine §2.2 invariant #1 (zero-copy unified memory): `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`
- Doctrine §6 forbidden list: "Copy hot-path tensors across CPU↔GPU↔ANE."
- Annex A.10 (KV implantation + raw memory inspection — Research only)
- Annex A.11 (ANE direct path — Research only)
- 2026-04-29 perf wave: CLAUDE.md "Wave 2026-04-29 perf additions" §`SearchIndexService.swift:204-228`
- Arena memory pressure handling: `agent_core/src/shared_memory.rs::ShmPool`
- ShmPool TTL eviction: `respond_to_memory_pressure(level: u8)` FFI in `agent_core/src/bridge.rs`
- The user's question that prompted this audit: `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` §"Two architectural questions raised by the user (2026-05-05)" Q1.

## Bottom line

mmap is utilized everywhere it makes sense to be: SQLite pragma on
all derivative DBs, memmap2 for workspace search + Arena ring buffer,
tantivy + usearch transitive use for the Shadow indices. The GPU
parallel — UMA zero-copy via `MTLBuffer.storageModeShared` — is the
canonical Apple Silicon pattern and lives in 37+ sites in
`MetalRuntimeManager.swift`. The Research-tier `MTLBuffer.contents()`
direct-pointer path is documented but explicitly OUT of Core/Pro.

If a future slice introduces a new file format or a new GPU buffer
class, this audit is the canonical decision tree for "where does
mmap apply?"
