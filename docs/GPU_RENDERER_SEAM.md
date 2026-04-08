# GPU Renderer Seam — Future Architecture Notes

## Date: 2026-04-07
## Status: Documentation Only (Not Implemented)

---

## Current Architecture

```
SwiftUI CodeEditorView
  └─ CodeEditSourceEditor (SourceEditor)
       └─ TextViewController
            ├─ CodeEditTextView (CoreText-based, custom NSView)
            │   └─ CoreText CTLine rendering (CPU-bound)
            ├─ GutterView (line numbers, folding ribbon)
            ├─ MinimapView (scaled-down token rects)
            └─ TreeSitterClient (syntax highlighting)
```

All text rendering is CPU-bound via CoreText. The minimap uses CoreGraphics `drawRect`.

---

## Target Architecture (Zed-Style GPU Pipeline)

```
SwiftUI CodeEditorView
  └─ EpistemosTextEngine
       ├─ TextBuffer (Rope/SumTree — O(log n) edits)
       ├─ CoreText Shaper (shaping only, no drawing)
       │   └─ Glyph cache: text-font pair → glyph positions
       ├─ Glyph Atlas (MTLTexture)
       │   └─ Alpha-only bitmaps, 16 sub-pixel variants per glyph
       │   └─ Bin-packed via etagere algorithm
       ├─ Metal Renderer
       │   ├─ Vertex buffer: per-glyph quads {position, atlas UV, color}
       │   ├─ Vertex shader: document space → clip space
       │   ├─ Fragment shader: sample atlas alpha × syntax color
       │   └─ Single instanced draw call per frame
       ├─ Minimap (CAMetalLayer)
       │   └─ Same atlas, different scale matrix
       │   └─ MSDF for infinite zoom clarity
       └─ ProMotion Pacing
            ├─ CADisplayLink keep-alive (1s after last input)
            ├─ Triple-buffered instance buffers
            └─ wait_until_scheduled (not wait_until_completed)
```

---

## Abstraction Seam Points

### 1. Text Buffer Seam

**Current:** `NSTextStorage` (via CodeEditSourceEditor)
**Future:** Rust `ropey` or `sum-tree` Rope via UniFFI

```swift
protocol TextBufferProvider {
    var length: Int { get }
    func string(in range: NSRange) -> String
    func replaceCharacters(in range: NSRange, with string: String)
    func lineRange(for line: Int) -> NSRange
    func lineCount() -> Int
}
```

### 2. Renderer Seam

**Current:** CoreText draws to CoreGraphics context
**Future:** CoreText shapes → Metal draws from glyph atlas

```swift
protocol TextRenderer {
    func renderVisibleLines(_ lines: Range<Int>, in viewport: CGRect)
    func invalidateCache(for range: NSRange)
    func setTheme(_ theme: EditorTheme)
}

// Current implementation:
class CoreTextRenderer: TextRenderer { ... }

// Future implementation:
class MetalTextRenderer: TextRenderer {
    let device: MTLDevice
    let glyphAtlas: GlyphAtlas
    let instanceBuffer: TripleBuffer<GlyphInstance>
    ...
}
```

### 3. Minimap Seam

**Current:** CoreGraphics `drawRect` with cached line fragments
**Future:** CAMetalLayer with MSDF texture atlas

```swift
protocol MinimapRenderer {
    func render(document: TextBufferProvider, theme: EditorTheme)
    func scrollTo(viewportRect: CGRect) // GPU position update only
}
```

---

## Metal Pipeline Components (When Ready)

### Glyph Atlas Generator

```swift
class GlyphAtlas {
    let texture: MTLTexture  // alpha-only, long-lived
    var glyphLocations: [GlyphKey: CGRect]  // UV coords per glyph

    func rasterize(glyph: CGGlyph, font: CTFont, subpixelOffset: CGPoint) -> CGRect
    // Uses CoreText to rasterize alpha-only bitmap
    // Packs into atlas using bin-packing
    // Stores 16 sub-pixel variants for antialiasing precision
}
```

### Instance Buffer (Per-Glyph Data)

```metal
struct GlyphInstance {
    float2 position;       // screen position
    float2 atlasOrigin;    // UV in atlas texture
    float2 size;           // glyph bounding box
    float4 color;          // syntax highlight color (from theme)
};
```

### Fragment Shader

```metal
fragment float4 glyphFragment(
    GlyphVertexOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]]
) {
    float alpha = atlas.sample(linearSampler, in.atlasUV).a;
    return float4(in.color.rgb, in.color.a * alpha);
}
```

### Triple Buffering + GPU Synchronization

When driving 120Hz Metal rendering, CPU-GPU race conditions are the primary crash/tearing risk.
The CPU must not write to a buffer the GPU is currently reading. Triple buffering solves this:

| Buffer | Frame N | Frame N+1 | Frame N+2 |
|--------|---------|-----------|-----------|
| A | GPU reading | idle | CPU writing |
| B | idle | GPU reading | idle |
| C | CPU writing | idle | GPU reading |

**Critical: `wait_until_scheduled` vs `wait_until_completed`**

| API | Composited Mode (windowed) | Direct Mode (M2+) |
|-----|---------------------------|-------------------|
| `waitUntilCompleted()` | Fast (returns when pixels hit buffer) | **SLOW** (blocks for full scanout) |
| `waitUntilScheduled()` | Fast (returns when GPU work queued) | Fast (returns when GPU work queued) |

Zed discovered that M2+ Macs run in "direct mode" where `waitUntilCompleted` blocks the main
thread for the full GPU scanout time — causing severe jank on 120fps machines. Always use
`waitUntilScheduled` with triple-buffered instance buffers.

```swift
class TripleBuffer<T> {
    private var buffers: [MTLBuffer]  // 3 buffers
    private var index = 0
    private let semaphore = DispatchSemaphore(value: 3)

    func nextWriteBuffer() -> MTLBuffer {
        semaphore.wait()
        let buffer = buffers[index % 3]
        index += 1
        return buffer
    }

    func signalComplete() {
        semaphore.signal()
    }
}

// In the render loop:
let commandBuffer = commandQueue.makeCommandBuffer()
commandBuffer.addCompletedHandler { _ in tripleBuffer.signalComplete() }
// Use waitUntilScheduled, NOT waitUntilCompleted:
commandBuffer.commit()
commandBuffer.waitUntilScheduled()  // ← Fast on both composited and direct mode
```

### ProMotion Pacing (CADisplayLink Keep-Alive)

macOS ProMotion displays **downclock to 24-30Hz** when no new frames are submitted.
This causes a sluggish feel when typing resumes after a pause. The fix: submit keep-alive
frames for 1 second after the last input event.

**Required Configuration:**

| Parameter | Value | Effect |
|-----------|-------|--------|
| `CADisableMinimumFrameDuration` | `true` in Info.plist | Unlocks full ProMotion range |
| `preferredFrameRateRange` | `80-120-120` | Requests 120Hz during interactions |
| `presentsWithTransaction` | `true` on CAMetalLayer | Syncs Metal with AppKit redraws |
| Keep-alive window | 1.0 second | Prevents downclocking during typing |

**CVDisplayLink vs CADisplayLink:**
- `CVDisplayLink` (macOS): provides high-precision callbacks at true hardware refresh rate
- `CADisplayLink` (macOS 14+): simpler API, may be capped at 60Hz by OS power management
- For maximum control, prefer `CVDisplayLink` with fallback to `CADisplayLink`

```swift
class DisplayPacer {
    private var displayLink: CADisplayLink?
    private var lastInputTime: TimeInterval = 0
    private let keepAliveWindow: TimeInterval = 1.0

    func userDidInteract() {
        lastInputTime = CACurrentMediaTime()
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        // Request maximum refresh rate during active editing
        link.preferredFrameRateRange = .init(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc func tick(_ link: CADisplayLink) {
        if CACurrentMediaTime() - lastInputTime > keepAliveWindow {
            link.isPaused = true  // Allow ProMotion to downclock (saves battery)
            displayLink = nil
        } else {
            renderer.presentFrame()  // Keep display locked at 120Hz
        }
    }
}
```

**Energy optimization:** The keep-alive automatically stops after 1 second of inactivity,
allowing the display to downclock and save battery. Only active editing holds 120Hz.

---

## MSDF (Multi-Channel Signed Distance Fields)

For the minimap and future resolution-independent text. Unlike bitmap atlases which
become blurry when scaled, MSDF encodes the mathematical distance to glyph edges in
the RGB color channels, allowing the GPU to reconstruct razor-sharp text at ANY scale.

### How It Works

| Feature | Bitmap Atlas | MSDF Atlas |
|---------|-------------|------------|
| Clarity | Good at native resolution only | Razor-sharp at any scale |
| Memory | High (large textures per size) | Low (single texture, all sizes) |
| GPU cost | Minimal | Moderate (median + smoothstep) |
| Anti-aliasing | Standard linear filtering | Procedural via `fwidth()` |
| Minimap reuse | Separate atlas needed | Same atlas as main editor |

### MSDF Fragment Shader

```metal
fragment float4 msdfFragment(
    MSDFVertexOut in [[stage_in]],
    texture2d<float> msdfAtlas [[texture(0)]]
) {
    // Sample the three distance channels
    float3 msd = msdfAtlas.sample(linearSampler, in.atlasUV).rgb;

    // Median of RGB gives the signed distance
    float sd = median(msd.r, msd.g, msd.b);

    // Screen-space derivatives for adaptive anti-aliasing
    float screenPxDistance = in.fontSize * (sd - 0.5);
    float opacity = clamp(screenPxDistance / fwidth(screenPxDistance) + 0.5, 0.0, 1.0);

    // Apply syntax color with computed opacity
    return float4(in.color.rgb, in.color.a * opacity);
}

// Median helper
float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}
```

The `fwidth()` function provides screen-space derivatives that automatically adapt the
smoothing ramp to match the display's pixel density — crisp on Retina, smooth on standard.

### Integration Path

1. Generate MSDF atlas from SF Mono using [msdfgen](https://github.com/Chlumsky/msdfgen)
2. Load as MTLTexture in the Metal pipeline
3. Use for BOTH main editor text AND minimap (same atlas, different scale matrix)
4. Minimap becomes "free" — just a different viewport transform on the same data

Reference: [DJBen/MSDFTextRender-Metal](https://github.com/DJBen/MSDFTextRender-Metal)

---

## Rope/SumTree Data Structure

For O(log n) seeks and edits on million-line files. This is the data structure used by
Zed, Xi-editor, and other high-performance editors to handle massive files.

### Complexity Comparison

| Data Structure | Insertion | Search (Line/Offset) | Ideal Use Case |
|---------------|-----------|---------------------|----------------|
| Swift String | O(n) | O(n) | Small prose or labels |
| Gap Buffer | O(1) local / O(n) move | O(n) | Traditional single-cursor editors |
| Piece Table | O(1) | O(n) | Large undo/redo history |
| **SumTree / Rope** | **O(log n)** | **O(log n)** | **Massive files + multi-threading** |

### Architecture

- **B+ tree** where internal nodes store summaries:
  - Total line count in subtree
  - Total byte count (UTF-8)
  - Total UTF-16 code unit count
- Each **leaf** stores a short string chunk (~64-128 bytes)
- **Seek** by line number, byte offset, or UTF-16 offset in O(log n)
- **Insert/delete** in O(log n) — constant regardless of file size
- **Immutable snapshots** for safe background tree-sitter parsing (no locks needed)
- **CRDT-ready** for future collaborative editing

### Integration Path

1. Extend `agent_core` Rust crate with a `ropey` buffer module
2. Expose via UniFFI as `TextBufferProvider` protocol
3. Swift side holds a handle; all mutations go through Rust FFI
4. NSTextStorage becomes a thin mirror that syncs from the Rope on edit
5. Tree-sitter parser reads directly from the Rope (zero-copy via `read_callback`)

### Why Not Now

The current CodeEditSourceEditor uses a standard Swift String internally. Replacing it
with a Rope requires either forking the package or building a custom text engine. This
is a multi-week project that should only start after Phase C-F optimizations prove
insufficient for the target file sizes.

**Reference:** [Zed's SumTree](https://zed.dev/blog/hiring), [ropey crate](https://crates.io/crates/ropey)

---

## Three-Phase Highlighting Integration

```
Phase 1 (sync, 0ms): Rust FFI markdown_parse_code_tokens()
    └─ Applied immediately on keystroke, no flicker
Phase 2 (async, 5-50ms): Tree-sitter via CodeEditSourceEditor
    └─ Replaces Phase 1 tokens as results arrive
Phase 3 (async, 100-500ms): LSP semantic tokens
    └─ Augments with type-aware coloring (future)
```

Seam: Implement `HighlightProviding` protocol from CodeEditSourceEditor that layers all three phases.

---

## Implementation Priority

| Component | Effort | Impact | When |
|-----------|--------|--------|------|
| Phase 1 (Rust FFI fallback highlighting) | 1 session | Medium — instant feedback | After Phase C-F |
| Minimap CAMetalLayer | 2 sessions | High — zero-cost scroll | After profiling shows minimap bottleneck |
| Gutter Metal rendering | 1 session | Medium — zero-cost scroll | After minimap |
| Full Metal text pipeline | 3-6 months | Maximum — 120fps guaranteed | Long-term |
| Rope/SumTree buffer | 2-4 weeks | High — million-line files | After Metal pipeline |
| ProMotion pacing | 1 session | Medium — prevents downclocking | After Metal pipeline |

---

## References

- [Zed: Leveraging Rust and GPU for 120fps](https://zed.dev/blog/videogame)
- [Zed: Optimizing Metal for 120fps](https://zed.dev/blog/120fps)
- [MSDF Text Rendering in Metal](https://github.com/DJBen/MSDFTextRender-Metal)
- [Metal by Example: Text with SDFs](https://metalbyexample.com/rendering-text-in-metal-with-signed-distance-fields/)
- [CodeEditTextView](https://github.com/CodeEditApp/CodeEditTextView)
- [Neon: Three-Phase Highlighting](https://github.com/ChimeHQ/Neon)
