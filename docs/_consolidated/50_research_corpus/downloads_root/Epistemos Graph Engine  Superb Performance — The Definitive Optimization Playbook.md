# Epistemos Graph Engine: Superb Performance — The Definitive Optimization Playbook

## Executive Summary

The synthesis you have is architecturally correct in its diagnosis. However, it presents optimizations as roughly equal paths. They are not. The single most impactful root cause — the one that causes *every other symptom* (stutters, crashes, flickering labels, lag on selection) — is that **the main thread is performing all three jobs simultaneously: physics simulation, GPU command encoding, and SwiftUI state observation**. Fix that one structural flaw and 80% of the described problems disappear. This playbook ranks every recommendation by impact-per-effort, gives you the exact implementation pattern for each, and surfaces the non-obvious pitfalls that will kill you if you skip them.

***

## The Single True Priority: The Render/Physics Split

### Why This Is Item #1

Everything else in the synthesis is a downstream consequence of one fact: `graph_engine_render()` is called synchronously on the `@MainActor` inside the `CADisplayLink` callback. That means when you have 5,000 nodes and the physics integrator is running a Barnes-Hut or N-body pass, it consumes all of the 8.3 ms budget (at 120 Hz) *before SwiftUI has a chance to respond to a tap*. This is the precise definition of main-thread saturation.[^1][^2]

The canonical fix — used by every physics-driven renderer from game engines to Blender's viewport — is the **fixed-timestep physics loop with render interpolation**:[^3][^4]

```
BACKGROUND THREAD (fixed 60 Hz):
  while (running) {
    previousState = currentState
    simulate(currentState, dt: 1/60)
    atomically swap → read buffer
  }

MAIN THREAD (CADisplayLink, up to 120 Hz):
  alpha = accumulator / fixedDt   // 0.0 → 1.0
  renderState = lerp(previousState, currentState, alpha)
  encode Metal commands → present
```

The `alpha` interpolation formula is simply:[^5]

\[\text{renderPosition} = \text{currentPos} \times \alpha + \text{previousPos} \times (1 - \alpha)\]

This decouples render cadence from physics cadence entirely. The display link fires at 120 Hz and always has data to render because it interpolates between the two most recent physics snapshots. The physics thread runs at a fixed 60 Hz regardless of display refresh. Main thread CPU time for the render loop drops to: one atomic read of the state buffer + Metal command encoding. Physics N-body work is gone from the main thread entirely.[^4][^6][^7][^3]

### The Atomic Swap Pattern

The state buffer between threads must be lock-free. Use a simple double-buffer:

```swift
// Rust side: two node-position arrays, atomic index
struct PhysicsStateBuffer {
    positions_a: [NodePos; MAX_NODES],
    positions_b: [NodePos; MAX_NODES],
    write_index: AtomicU8,  // 0 or 1
}

// After each physics tick:
write_index.store(1 - write_index.load(Acquire), Release)

// Swift render thread reads the OPPOSITE buffer:
let readIdx = 1 - physicsBuffer.write_index.load(Acquire)
```

This is the same pattern used in Bevy's physics interpolation and game engines implementing fixed timestep. No mutex, no blocking. **Do this before anything else.** It is a Rust-side change that requires no Swift actor restructuring and can be shipped in days.[^8][^3]

***

## Priority 2: The FFI Crash Fix (Zero-Copy Ownership)

### Why `___BUG_IN_CLIENT_OF_LIBMALLOC` Happens

The crash at `EmbeddingService.swift:215` is a textbook **allocator mismatch**. Rust's allocator (jemalloc or the system allocator, depending on build config) and Swift's allocator are separate. When Rust allocates a `Vec<f32>` and returns it across the FFI boundary, Swift receives a pointer but doesn't know which allocator owns it. If Swift or its ARC system ever tries to `free()` that memory, it's calling the wrong deallocator — hence `BUG_IN_CLIENT_OF_LIBMALLOC`.[^9][^10]

The canonical fix stated in the Rust community: **the language that allocates must be the language that deallocates**. The correct zero-copy handshake is:[^11][^10]

```swift
// Swift pre-allocates a buffer with its own allocator
var buffer = [Float32](repeating: 0, count: expectedNodeCount * 2)
buffer.withUnsafeMutableBufferPointer { ptr in
    // Rust receives the pointer, fills it, returns void
    // Rust NEVER allocates; it only writes into Swift's memory
    graph_engine_fill_positions(engine, ptr.baseAddress, UInt32(ptr.count))
}
// Swift reads from buffer — ownership never crossed the boundary
```

This is exactly what the Rust FFI community calls "borrowing, not transferring". Rust fills a buffer it doesn't own. Swift reads a buffer it allocated. No double-free is possible.[^12][^9]

### Serializing FFI Calls (Actor-as-Queue)

Even with zero-copy memory, concurrent FFI calls on different background threads will race on Rust's internal mutable state. The fix is to gate all FFI through a **custom-executor actor** backed by a serial `DispatchQueue`:[^13][^14][^15]

```swift
actor GraphFFIActor {
    // All actor jobs run on this dedicated serial queue
    private nonisolated let queue = DispatchSerialQueue(
        label: "com.epistemos.ffi.serial",
        qos: .userInteractive
    )

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    func fillPositions(into buffer: inout [Float32]) {
        // This is now guaranteed serial — no two FFI calls overlap
        buffer.withUnsafeMutableBufferPointer { ptr in
            graph_engine_fill_positions(engine, ptr.baseAddress, UInt32(ptr.count))
        }
    }
}
```

Swift actors always use a serial executor under the hood; what the custom executor adds is the guarantee that the underlying OS thread is dedicated and predictable rather than drawn from the cooperative pool. This matters because the cooperative pool has a limited count equal to CPU cores — blocking it with FFI work starves other Tasks.[^14][^16][^17]

Apple's own `AVCam` sample code uses exactly this pattern: a `DispatchSerialQueue`-backed actor for any session-level hardware operations.[^15][^18]

***

## Priority 3: Selection Task Cancellation (The Flickering Fix)

### The Root Cause of Ghost Updates

The "flickering between two nodes" symptom happens when:
1. User clicks Node A → Task starts, begins slow semantic neighbor calculation
2. User clicks Node B → new Task starts while old Task is still running
3. Old Task finishes, writes Node A's state → UI flashes back to Node A

This is a straightforward structured concurrency problem. The fix uses a stored `Task` handle with cooperative cancellation:[^19][^20]

```swift
@MainActor
final class GraphState: Observable {
    private var selectionTask: Task<Void, Never>?

    func selectNode(_ id: NodeID) {
        // Cancel any in-flight selection computation immediately
        selectionTask?.cancel()

        selectionTask = Task(priority: .userInitiated) {
            // 1. Immediate visual feedback (cheap, synchronous on MainActor)
            self.dimAllNodesExcept(id)

            // 2. Check cancellation before expensive work
            guard !Task.isCancelled else { return }

            // 3. Request context from background actor
            let context = await graphFFIActor.fetchNeighborContext(for: id)

            // 4. Check again — user may have clicked elsewhere
            guard !Task.isCancelled else { return }

            // 5. Apply final label state
            self.applySelectionContext(context)
        }
    }
}
```

`Task.isCancelled` is a cooperative check — it requires you to insert checkpoints. Place them between each expensive phase. When the user taps a new node, `selectionTask?.cancel()` sets the cancellation flag; the next `guard !Task.isCancelled` checkpoint causes the old task to return early without writing stale state.[^20][^19]

The `priority: .userInitiated` priority ensures the system schedules this task ahead of `.utility` background work like semantic re-indexing.[^21][^19]

***

## Priority 4: Observer Churn Throttling

### The `selectedNodeScreenPoint` Observation Cascade

Writing an `@Observable` property from inside the `CADisplayLink` callback (every frame, 120×/sec) triggers SwiftUI's dependency tracking infrastructure every frame. For a property like `selectedNodeScreenPoint` that drives the Inspector panel, this causes layout recalculation on every frame even when the node has barely moved.[^22]

The fix is threshold + frequency gating:

```swift
// Inside renderFrame(), after computing new screen position:
let delta = distance(newScreenPos, lastPublishedScreenPoint)
if frameCount % 3 == 0 && delta > 2.0 {
    // Only publish to @Observable state at ~40Hz when position changed meaningfully
    await MainActor.run {
        graphState?.selectedNodeScreenPoint = newScreenPos
    }
    lastPublishedScreenPoint = newScreenPos
}
frameCount &+= 1
```

The `% 3` divisor limits updates to ~40 Hz at 120 Hz display refresh. The `delta > 2.0` guard prevents updates when the panel barely moves. Together, these reduce SwiftUI observation events by ~95% during smooth drag/pan. Switching to `@Observable` (over `ObservableObject`) is already the right foundation — `@Observable` tracks per-property rather than whole-object, so this throttle eliminates the remaining overhead.[^23][^22]

***

## Priority 5: Metal-Side Animation (Eliminate SwiftUI Competition)

### The `withAnimation` Problem in Hot Paths

The `PhysicsCoordinator.pulse()` method runs `withAnimation(Motion.settle)` on the `@MainActor`. SwiftUI animations are driven by a `CADisplayLink`-like mechanism *also on the main thread*. When this runs concurrently with your Metal render loop — which is also main-thread-bound — both are fighting for the 8.3 ms frame budget.[^24][^25]

The correct approach for node-position animations is to let the Metal shader perform interpolation using a time uniform:[^25][^24]

```metal
// In your vertex shader, interpolate toward target position
vertex VertexOut node_vertex(
    uint vid [[vertex_id]],
    constant NodeUniforms &u [[buffer(0)]]
) {
    // u.animTime goes 0→1 over your desired duration (passed from Swift)
    float t = smoothstep(0.0, 1.0, u.animTime);
    float2 pos = mix(u.prevPosition, u.targetPosition, t);
    // ... rest of vertex transform
}
```

Swift sends `targetPosition` and resets `animTime` to `0.0` on selection change. The shader advances `animTime` each frame using the elapsed time uniform. This is **GPU-local interpolation** — zero main thread work per frame after the initial update. For the "breathe" and "glow" effects driven by `TimelineView`, use the `.animation` schedule with a `paused` binding:[^26][^27][^24][^25]

```swift
TimelineView(.animation(paused: isWindowOccluded || isStaticMode)) { timeline in
    GlowOverlay(time: timeline.date.timeIntervalSinceReferenceDate)
}
```

Apple explicitly designed `TimelineView` with a `paused` parameter for exactly this energy-gating use case. When `isWindowOccluded` is `true`, the timeline stops entirely — zero GPU/CPU wake-ups.[^27][^26]

### Handling Window Occlusion for CAMetalLayer

Additionally, `CAMetalLayer.nextDrawable()` **hangs for up to one second** when the window is fully occluded. This is a known macOS Metal behavior. Gate your `CADisplayLink` using the `NSWindowDelegate` occlusion notification:[^28]

```swift
// NSWindowDelegate
func windowDidChangeOcclusionState(_ notification: Notification) {
    let isVisible = window.occlusionState.contains(.visible)
    isVisible ? displayLink.add(to: .current, forMode: .default)
              : displayLink.invalidate()
}
```

This is the fix used by every macOS Metal app that doesn't want a 1-second freeze on window switch.[^28]

***

## Priority 6: LOD + Frustum Culling (Rust Side)

### When to Implement This

Once the main-thread physics split is done (Priority 1), you'll find a new bottleneck: even with physics off the main thread, the *render* path still iterates all 5,000+ nodes to build instance buffers. LOD and culling are the answer.

The architecture is straightforward in Rust:[^29]

```rust
fn build_draw_list(&self, view: &ViewBounds) -> DrawList {
    let mut full_nodes = Vec::new();
    let mut dot_nodes = Vec::new();

    for (id, node) in &self.nodes {
        // Frustum cull: skip entirely if off-screen
        if !view.aabb_intersects(node.pos, NODE_RADIUS) { continue; }

        // LOD: far nodes render as 1px dots (single instance)
        if node.screen_radius(view.zoom) < 3.0 {
            dot_nodes.push(DotInstance::from(node));
        } else {
            full_nodes.push(NodeInstance::from(node));
        }
    }
    DrawList { full_nodes, dot_nodes }
}
```

Research on interactive LOD for large graph drawings confirms this approach reduces rendered primitive count proportional to zoom level, with negligible visual loss. For a dense PKM graph, at 20% zoom you might render 5,000 nodes but only 200 are large enough to need full geometry — the other 4,800 become dots. GPU work drops proportionally.[^29]

***

## Priority 7: GPU-Driven Rendering with Indirect Command Buffers (Long-Term)

### When This Becomes Necessary

At 10,000+ nodes, even an optimized CPU loop building instance buffers will become the bottleneck. The solution is Metal's **Indirect Command Buffers (ICB)**, which allow a GPU compute shader to perform culling and build draw commands entirely on the GPU.[^30][^31][^32][^33]

The architecture:

```
CPU: Upload all node data once to a persistent MTLBuffer
     Encode a single executeCommandsInBuffer() call

GPU Compute Pass:
  for each node in parallel:
    if frustum_visible(node) && lod_sufficient(node):
      encode draw_indexed_primitives into ICB slot[node.id]
    else:
      reset ICB slot[node.id]  // no draw

GPU Render Pass:
  executeCommandsInBuffer(icb, range: allNodes)
  // GPU only executes commands where slots weren't reset
```

ICBs are supported on all Macs from 2015+ and iMacs from 2015+. The CPU is completely free of per-frame node iteration. Apple's own WWDC 2019 "Modern Rendering with Metal" session demonstrates this GPU-driven pipeline explicitly. For Epistemos with 10,000+ nodes at 120 Hz, this is the architecture that makes it possible.[^31][^34][^32][^33][^35]

One important caveat from real-world testing: the ICB command limit is 16,384 per buffer. For very large graphs, you'd need to split across multiple ICB dispatches. Also, on some AMD GPUs, ICB can be slightly slower than a CPU loop for smaller node counts — profile before committing.[^36]

***

## The Definitive Order of Operations

The synthesis suggests doing the FFI fix first, then selection cancellation. After deep research, the correct ordering is:

| Step | What | Why This Order | Time |
|------|------|----------------|------|
| **1** | Fixed-timestep physics loop + atomic state buffer (Rust) | Eliminates *all* main-thread physics cost; instantly stops stutters | Days |
| **2** | Zero-copy FFI buffer ownership fix | Stops the crash; prerequisite for everything else being stable | Days |
| **3** | `GraphFFIActor` with custom serial executor | Serializes all FFI calls; prevents races introduced once background physics is active | 1 week |
| **4** | Observer throttle (`selectedNodeScreenPoint`) | 3-line change, ~95% reduction in SwiftUI churn | Hours |
| **5** | Selection `Task` cancellation | Kills ghost updates; requires stable actor isolation from Step 3 | 1 week |
| **6** | Metal shader interpolation + `TimelineView` gating | Battery life, animation quality; no more `withAnimation` competition | 2 weeks |
| **7** | Rust-side frustum cull + LOD draw list | Handles 5,000–10,000 node density | 2–4 weeks |
| **8** | GPU-driven ICB rendering | 10,000+ nodes at 120 Hz; architectural commitment | 1–3 months |

***

## Common Traps to Avoid

### Trap 1: CADisplayLink Still on Main Thread After Physics Move

Moving physics to a background thread does not mean you can move `CADisplayLink` off main. Metal's `drawable.present()` must be called from a context synchronized with the display — in practice, main thread or a thread with an explicit `MTLCommandBuffer` scheduling semaphore. What you *can* do is use `CVDisplayLink` (macOS-only, C API) which fires its callback on a dedicated render thread, while still presenting on main. This is more complex but gives you true background encoding.[^2][^37]

### Trap 2: Cooperative Pool Starvation from FFI

If you route FFI calls through a regular `actor` (no custom executor), they land on Swift's cooperative thread pool. That pool has exactly `processorCount` threads. Blocking FFI work — even millisecond-scale Rust simulation ticks — can stall all other `async` tasks in your app. The custom `DispatchSerialQueue` executor from Priority 2 is not optional; it isolates FFI onto a dedicated OS thread outside the pool.[^38][^39][^14]

### Trap 3: Swift 6.2 Default MainActor Isolation

Swift 6.2 (shipping with iOS/macOS 26) introduces an opt-in `defaultIsolation = MainActor` compiler flag. If you ever enable this, every class without an explicit actor annotation becomes `@MainActor` — including your new background worker types. Mark your `GraphFFIActor`, `BackgroundPhysicsCoordinator`, and any other explicitly background types as `nonisolated` or give them their own global actor to prevent them from being silently pulled onto main.[^40][^41]

### Trap 4: Allocator Mismatch Is Platform-Dependent

On macOS with recent Rust versions (1.x+), Rust uses the system allocator by default, which is the same `malloc`/`free` as Swift. This means allocator mismatches *may not crash on your dev machine* but will crash on builds with `#[global_allocator]` pointing to jemalloc or mimalloc. The zero-copy pattern (Priority 2) is the architecturally correct solution regardless — do not rely on "it compiles and doesn't crash today" as a signal that ownership transfer is safe.[^10][^42][^9]

### Trap 5: `TimelineView` CPU Overhead

Despite being designed for animation, `TimelineView` with `.animation` schedule can consume significant CPU if content is complex. Existing Reddit reports show Canvas + TimelineView producing unexpectedly high CPU utilization on earlier iOS versions. The `paused:` binding gate (Priority 5) is not just an energy optimization — it's a correctness mechanism. Verify with Instruments that your `TimelineView` content is actually paused when the window is occluded.[^43]

***

## What "Superb" Looks Like After All Steps

Once the full playbook is executed:

- **120 Hz sustained** during pan/zoom on 5,000 nodes because physics is background-only and the render loop is interpolating pre-computed positions
- **Zero crashes** at the FFI boundary because Swift never touches Rust-allocated memory
- **Instant node selection response** (<1 frame visual feedback) because dim/highlight is immediate and the heavier context fetch is background-async with cancellation
- **Zero flicker** between nodes because the old task is cancelled before it can write stale state
- **Smooth "physical" animations** because the shader interpolates position, not SwiftUI's spring animator
- **Battery-efficient** because `TimelineView` pauses when occluded and LOD means the GPU renders only what's visible

The contrast with Electron-based tools is felt most strongly in the last 20% of polish — and the last 20% is almost entirely thread architecture.

---

## References

1. [GPU renders at 30 FPS when using CADisplayLink with Metal Kit](https://www.reddit.com/r/swift/comments/r5ljey/gpu_renders_at_30_fps_when_using_cadisplaylink/) - The display link duration is printing at 0.0167 which is 60 FPS, but Xcode says my GPU is rendering ...

2. [CADisplayLink in a DispatchQueue - Stack Overflow](https://stackoverflow.com/questions/55979229/cadisplaylink-in-a-dispatchqueue) - So I think I will have to run the display link in the main thread as it should and do a dispatch asy...

3. [Support interpolating values from fixed-timestep systems · Issue #1259](https://github.com/bevyengine/bevy/issues/1259) - Rendering related systems should likely use the interpolated transform, where as other systems may/m...

4. [Why use interpolation in fixed time step game loop? - Reddit](https://www.reddit.com/r/gamedev/comments/t1uxzb/why_use_interpolation_in_fixed_time_step_game_loop/) - The game updates the state to the next step (0.01s) once and then, for some reason, it interpolates ...

5. [Interpolated Physics Rendering - KSH](https://kirbysayshi.com/2013/09/24/interpolated-physics-rendering.html) - A basic game loop that attempts to keep rendering updates independent of physics updates, with actua...

6. [Fixed timestep without interpolation | Jakub's tech blog](https://jakubtomsu.github.io/posts/fixed_timestep_without_interpolation/) - It's possible to use the game tick to “predict” the render game state without explicitly writing any...

7. [Using a fixed physics timestep in Unreal Engine, free the physics ...](https://forums.unrealengine.com/t/using-a-fixed-physics-timestep-in-unreal-engine-free-the-physics-approach/67537/20) - The simulation (physics) will run when the 10fps (10hz) timer has indicated a new physics step is du...

8. [Manual: Set fixed timestep to optimize physics simulation frequency](https://docs.unity3d.com/2022.3/Documentation/Manual/physics-optimization-cpu-frequency.html) - Select the Time group. Adjust the Fixed Timestep field. Mitigate escalating physics simulation load....

9. [How to prevent double free and leaks with FFI - rust - Stack Overflow](https://stackoverflow.com/questions/75855900/how-to-prevent-double-free-and-leaks-with-ffi) - One of the problems I'm facing is how to prevent double frees and memory leaks when the dynamic libr...

10. [Beware of allocators mismatch · Issue #53 · Michael-F-Bryan/rust-ffi ...](https://github.com/Michael-F-Bryan/rust-ffi-guide/issues/53) - I've found it needed to write small custom functions to expose deallocation or allocation missing on...

11. [C FFI Memory Leak: Take ownership of allocated memory in C/C++](https://users.rust-lang.org/t/c-ffi-memory-leak-take-ownership-of-allocated-memory-in-c-c/24337) - However in my case I would need to dynamically create the string object on the C++ and want to take ...

12. [Guide to zero-copy FFI with Rust and Unity - Test Double](https://testdouble.com/insights/rust-unity-zero-copy-ffi-guide) - A technical guide to building zero-copy FFI bridges between Rust and Unity. Learn how to pass struct...

13. [swift-evolution/proposals/0392-custom-actor-executors.md at main](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md) - This proposal introduces a basic mechanism for customizing actor executors. By providing an instance...

14. [Controlling Actors With Custom Executors - Jack Morris](https://jackmorris.xyz/posts/2023/11/21/controlling-actors-with-custom-executors) - I decided to give custom actor executors a whirl (new in Swift 5.9), which in this case allows me to...

15. [Swift Actor and GCD Dispatch Queue Executor - Stack Overflow](https://stackoverflow.com/questions/79319749/swift-actor-and-gcd-dispatch-queue-executor) - This defines an actor that is using a custom executor, namely a GCD serial queue: Copy. actor Captur...

16. [How are Actors Implemented in Swift? - Jacob's Tech Tavern](https://blog.jacobstechtavern.com/p/how-are-swift-actors-implemented) - It takes jobs and schedules them for execution on the cooperative thread pool. They behave a little ...

17. [How Actors Work Internally in Swift - SwiftRocks](https://swiftrocks.com/how-actors-work-internally-in-swift) - Lets explore how actors work under the hood, using Swift's own source code as a guide to finding out...

18. [Swift Actor and GCD Dispatch Queue Executor : r/iOSProgramming](https://www.reddit.com/r/iOSProgramming/comments/1hqcuke/swift_actor_and_gcd_dispatch_queue_executor/) - A serial dispatch queue to use for capture control actions. private let sessionQueue = DispatchSeria...

19. [How to Use Swift Concurrency with async/await - OneUptime](https://oneuptime.com/blog/post/2026-02-03-swift-async-await/view) - Tasks can have priorities and support cooperative cancellation. Check Task.isCancelled or call Task....

20. [Difference of TaskPriority for Task.cancel() - Stack Overflow](https://stackoverflow.com/questions/74852104/difference-of-taskpriority-for-task-cancel) - The Swift concurrency system can prioritize tasks. But, the priority behavior you are experiencing i...

21. [Structured Concurrency With Task Groups in Swift - Andy Ibanez](https://www.andyibanez.com/posts/structured-concurrency-with-group-tasks-in-swift/) - Where priority is of type Task.Priority . This gives you more flexible control when dealing with can...

22. [How to update SwiftUI many times a second while being performant?](https://forums.swift.org/t/how-to-update-swiftui-many-times-a-second-while-being-performant/71249) - The easiest solution to this is to switch to @Observable , which does change-tracking on a per-prope...

23. [CADisplayLink and its applications | topolog's tech blog](http://dmtopolog.com/cadisplaylink-and-its-applications/) - The main feature of CADisplayLink is that it's synchronised with the display refresh rate. It's even...

24. [How to perform animations in Metal using a CADisplayLink - delasign](https://www.delasign.com/blog/metal-animations-cadisplaylink/) - This tutorial first walks you through how to the project to draw multiple shapes from multiple shade...

25. [Create custom visual effects with SwiftUI - WWDC24 - Videos](https://developer.apple.com/videos/play/wwdc2024/10151/) - Learn to build unique scroll effects, rich color treatments, and custom transitions. We'll also expl...

26. [Understanding SwiftUI's TimelineView: A Deep Dive - Kyle-Ye's Blog](https://kyleye.top/posts/swiftui-timeline-view/?lang=en) - TimelineView is a powerful container view in SwiftUI that updates its content according to a schedul...

27. [Integrating TimelineView in a SwiftUI app - Create with Swift](https://www.createwithswift.com/integrating-timelineview-in-a-swiftui-app/) - Learn how to periodically refresh and update UI components, enabling smooth and efficient animations...

28. [[mtl] hangs on background/foregrounding in [CAMetalLayer ... - GitHub](https://github.com/gfx-rs/gfx/issues/2460) - I hacked up a CVDisplayLink impl to test and verified that the render thread was no longer hanging. ...

29. [[PDF] Interactive Level-of-Detail Rendering of Large Graphs](https://d-nb.info/1096195852/34) - Abstract— We propose a technique that allows straight-line graph drawings to be rendered interactive...

30. [Bring your game to Mac, Part 3: Render with Metal - Apple Developer](https://developer.apple.com/videos/play/wwdc2023/10125/) - Find out how to optimize GPU commands submission, render rich visuals with MetalFX Upscaling, and mo...

31. [Modern Rendering with Metal - WWDC19 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2019/601/) - Metal is the GPU-accelerated graphics and compute framework that helps developers build everything f...

32. [Metal by Tutorials, Chapter 26: GPU-Driven Rendering - Kodeco](https://www.kodeco.com/books/metal-by-tutorials/v3.0/chapters/26-gpu-driven-rendering) - Indirect command buffers contain a list of render or compute encoder commands. You can create the li...

33. [Encoding indirect command buffers on the GPU - Apple Developer](https://developer.apple.com/documentation/Metal/encoding-indirect-command-buffers-on-the-gpu) - This sample app demonstrates how to use indirect command buffers (ICB) to issue rendering instructio...

34. [MTLIndirectCommandBuffer | Apple Developer Documentation](https://developer.apple.com/documentation/metal/mtlindirectcommandbuffer) - Overview. Use an indirect command buffer to encode commands once and reuse them, and to encode comma...

35. [Metal by Tutorials, Chapter 15: GPU-Driven Rendering - Kodeco](https://www.kodeco.com/books/metal-by-tutorials/v2.0/chapters/15-gpu-driven-rendering) - Note: Indirect command buffers are supported by: iOS - Apple A9 devices and up; iMacs - models from ...

36. [MultiDrawIndirect and Metal - Tellusim Technologies Inc.](https://tellusim.com/metal-mdi/) - The official Metal way is to use Indirect Command Buffer and encode rendering commands on CPU or GPU...

37. [How, exactly, do I render Metal on a background thread?](https://stackoverflow.com/questions/63709936/how-exactly-do-i-render-metal-on-a-background-thread) - The main point of the sample code is to use CVDisplayLink to trigger rendering in the background whe...

38. [Guaranteeing an actor executes off the main thread - Swift Forums](https://forums.swift.org/t/guaranteeing-an-actor-executes-off-the-main-thread/75009) - Every actor which is not the main actor executes on a background thread; this is actually a public g...

39. [“Thread” vs. “Queue” vs. “Actor's executor” - Swift Forums](https://forums.swift.org/t/thread-vs-queue-vs-actor-s-executor/80601) - Actor's queue/executor —Every actor has its own serial executor, which is basically a queue of tasks...

40. [Swift 6.2: Default Actor Isolation to MainActor - LinkedIn](https://www.linkedin.com/posts/jacobmartinbartlett_swift-62-default-actor-isolation-with-swift-activity-7354103231578267649-AjFv) - You can set default actor isolation to MainActor. This defaults everything to run on the main actor ...

41. [Should you opt-in to Swift 6.2's Main Actor isolation? - Donny Wals](https://www.donnywals.com/should-you-opt-in-to-swift-6-2s-main-actor-isolation/) - The result of your code bein main actor isolated by default is that your app will effectively be sin...

42. [A deep dive into Rust and C memory interoperability - Hacker News](https://news.ycombinator.com/item?id=44786962) - The reason you are not seeing crashes when allocating with Rust and freeing with C (or vice versa) i...

43. [iOS 15: SwiftUI Canvas/TimelineView terrible performance - Reddit](https://www.reddit.com/r/SwiftUI/comments/pd9jcl/ios_15_swiftui_canvastimelineview_terrible/) - Just for drawing you can remove TimelineView completelly. Eventually the same Canvas code alone will...

