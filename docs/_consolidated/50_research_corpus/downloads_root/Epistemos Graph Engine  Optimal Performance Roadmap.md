# Epistemos Graph Engine: Optimal Performance Roadmap
## Executive Summary
The path to a superb, "Metal-smooth" graph in Epistemos follows a strict dependency order: **first stop the crashes, then stop the flickering, then eliminate main-thread saturation**. Every other optimization — background physics, LOD, GPU-driven rendering — builds on that stable foundation. Attempting Tier 2 or Tier 3 changes before the FFI boundary is hardened will produce harder-to-diagnose instability. The single most high-leverage change is a **dedicated FFI Actor with a custom serial executor** that serializes all Rust calls and owns the zero-copy memory contract.

***
## The True Root Cause of Every Symptom
Before prioritizing, it helps to understand why the three visible symptoms — crashes, flickering labels, and uneven frame rates — each trace back to a different architectural layer:

| Symptom | Root Layer | Root Cause |
|---------|-----------|-----------|
| `___BUG_IN_CLIENT_OF_LIBMALLOC` crash | FFI Memory | Two background threads call into Rust concurrently; Swift's allocator and Rust's allocator disagree on ownership of the same heap block [^1][^2] |
| "Ghost" label flicker on rapid node clicks | Task Lifecycle | The first selection `Task` was never cancelled before the second one started writing to `@Observable` [^3][^4] |
| Choppy FPS in dense clusters | Main Thread Saturation | Rust N-body physics, GPU command encoding, and SwiftUI observation writes all run serially on the same main thread [^5] |

Fixing them out of order (e.g. optimizing the render loop before fixing the crash) is counterproductive. The memory corruption at the FFI boundary can silently corrupt physics state, making perf data unreliable anyway.

***
## Tier 1 — Ship This Week (Hours to Days)
### Fix 1 — The FFI Boundary Actor (Crash Elimination, Highest Priority)
This is the single most important change in the entire document. The `___BUG_IN_CLIENT_OF_LIBMALLOC` error confirms that at least two concurrent callers are entering Rust FFI simultaneously. The fix is to funnel **every** Rust call through one actor backed by a dedicated serial `DispatchQueue`.

Swift 5.9 introduced **Custom Actor Executors** (SE-0392), which allow an actor to declare a custom `SerialExecutor` so its body always runs on a specific `DispatchQueue` rather than the global cooperative thread pool. This is the correct primitive — not a `DispatchSemaphore`, not `DispatchQueue.sync`, which would block threads rather than suspend them.[^6][^7]

```swift
// 1. A dedicated serial queue — single-threaded by construction
private let ffiQueue = DispatchSerialQueue(label: "com.epistemos.rust-ffi")

actor GraphFFIActor {
    // Custom executor pins this actor to ffiQueue
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        ffiQueue.asUnownedSerialExecutor()
    }

    // Rust engine pointer: nonisolated(unsafe) is the correct annotation
    // when you manually guarantee single-threaded access via the actor
    nonisolated(unsafe) private var engine: OpaquePointer?

    func render(width: UInt32, height: UInt32) -> Bool {
        // This body ONLY runs on ffiQueue — no concurrency possible
        graph_engine_render(engine, width, height)
    }

    func pushNodeMetadataBatch(_ payload: NodeMetadataPayload) {
        send_node_metadata_batch(engine, payload)
    }
}
```

**Why `nonisolated(unsafe)` is correct here**: The Swift 6 migration guide and Apple's WWDC24 session confirm that `nonisolated(unsafe)` is the intended escape hatch when you manually guarantee safety via an external mechanism (in this case, the actor's serial executor). Using it anywhere other than this guarded pattern is the bug; using it here is the solution.[^8]
### Fix 2 — Zero-Copy FFI Handshake (Allocator Mismatch Elimination)
The secondary crash vector is Rust returning a `Vec<T>` or allocated string that Swift attempts to free with its own allocator. When Rust and Swift use different allocators (which they do on Apple platforms), this is a guaranteed double-free.[^1][^2]

The correct pattern is **caller-owns-the-buffer**:

```swift
// Swift pre-allocates the buffer — owns it from start to finish
func fetchNeighborPositions(for nodeId: String, capacity: Int) -> [SIMD2<Float>] {
    var result = [SIMD2<Float>](repeating: .zero, count: capacity)
    result.withUnsafeMutableBufferPointer { ptr in
        // Rust WRITES into Swift's buffer — it never allocates anything
        graph_engine_get_neighbor_positions(engine, nodeId, ptr.baseAddress, capacity)
    }
    return result
}
```

Swift's `withUnsafeTemporaryAllocation` and `UnsafeMutableBufferPointer` are the standard APIs for this pattern. On the Rust side, the function signature takes a raw pointer and a length and writes into it without allocating. Ownership never crosses the boundary in either direction.[^9][^10]
### Fix 3 — Selection Task Cancellation (Flicker Elimination)
The label flicker happens because Task A is still writing `selectedNodeScreenPoint` after the user has already clicked Node B and spawned Task B. Swift's cooperative cancellation model provides the exact primitive needed:[^3][^4]

```swift
// In GraphState or the selection handler
private var selectionTask: Task<Void, Never>?

func selectNode(_ id: String) {
    // Cancel the previous task IMMEDIATELY, before spawning a new one
    selectionTask?.cancel()

    selectionTask = Task(priority: .userInitiated) {
        // Step 1: cheap — dim other nodes (synchronous write, negligible cost)
        await MainActor.run { graphState.dimAllExcept(id) }

        // Step 2: medium — fetch graph context
        guard !Task.isCancelled else { return }
        let context = await backgroundActor.fetchContext(for: id)

        // Step 3: expensive — calculate semantic neighbors + labels
        guard !Task.isCancelled else { return }
        let labels = await graphFFIActor.calculateLabels(for: id, context: context)

        await MainActor.run { graphState.applySelection(id, labels: labels) }
    }
}
```

The `guard !Task.isCancelled else { return }` checks at each suspension point ensure the task stops at the earliest safe moment. Checking `isCancelled` is cooperative — it is the task's responsibility to check, not the runtime's.[^11][^4]
### Fix 4 — Throttle Inspector Position Updates (3-Line Win)
Every frame writes `selectedNodeScreenPoint` to an `@Observable` property. Since `@Observable` uses dependency tracking under the hood, this forces SwiftUI to re-evaluate every view that reads that property at 120Hz. A 2-point dead-zone threshold and a 3-frame skip reduces this to ~20Hz, which is more than sufficient for a sidebar inspector:[^12][^13]

```swift
// In renderFrame(), before publishing
let delta = distance(newScreenPoint, lastPublishedSelectedNodeScreenPoint ?? newScreenPoint)
if frameCount % 3 == 0 && delta > 2.0 {
    graphState?.selectedNodeScreenPoint = newScreenPoint
    lastPublishedSelectedNodeScreenPoint = newScreenPoint
}
```

An important nuance: Swift 6.2's `Observations` struct introduces `AsyncSequence`-based `.throttle()` directly on `@Observable` properties, which will eventually make this manual gating unnecessary — but the manual approach works today on any Swift version.[^14]
### Fix 5 — Truly Fire-and-Forget Metadata Push
The metadata push (`pushDeferredNodeMetadata`) blocks commit when awaited inline. Detaching it completely removes it from the critical path:

```swift
// Before (blocks the caller until metadata FFI is done)
await pushDeferredNodeMetadata()

// After (fire-and-forget — commit returns immediately)
Task.detached(priority: .utility) { [weak self] in
    await self?.graphFFIActor.pushDeferredNodeMetadata()
}
```

The `Task.detached` does not inherit the caller's actor context, which means it genuinely runs off the main thread.[^15][^16]

***
## Tier 2 — Ship This Month (Architecture Changes)
### Background Physics Thread with Interpolation
The most impactful Tier 2 change is decoupling physics simulation from the render loop. Today, `graph_engine_render()` blocks main thread for the entire N-body tick + GPU encode. The canonical solution — used in every professional game engine — is the **fixed timestep + render interpolation** pattern:[^17][^18]

```
Physics Thread (60Hz, fixed dt):
    while running:
        simulate(dt=1/60)
        prevState = currentState
        atomicSwap(sharedState, currentState)

Render Thread (120Hz+, variable dt):
    accumulator += frameDelta
    alpha = accumulator / physicsDt          // where in the current tick are we?
    renderedPos = lerp(prevState.pos, currentState.pos, alpha)
    render(renderedPos)
```

The interpolation `alpha = accumulator / dt` ensures that even at 120Hz display refresh with 60Hz physics, every rendered frame shows a smooth position between the last two physics frames. The Rust physics thread and the Swift render thread share state via an **atomic swap** (Rust `AtomicU8` index into a triple buffer) — no locks, no blocking.[^19][^20][^21][^17]

This architecture requires:
1. A new Rust function `graph_engine_tick(dt: f32)` separate from `graph_engine_render()`
2. A background `Thread` (not a Swift `Task`) for the physics loop, since fixed-timestep loops need a dedicated OS thread
3. A lock-free triple-buffer for the physics state → render thread handoff
### LOD System in Rust
Dense clusters crash frame time because every node — visible or not, near or far — goes through the full physics + render path. Two culling stages reduce the per-frame work proportionally to the number of off-screen or distant nodes:

- **Frustum culling**: Any node whose position falls outside the camera's view bounds is skipped entirely from the draw list[^22]
- **Level of Detail (LOD)**: Nodes beyond a distance threshold are emitted as dot-only instances (8 bytes per node instead of ~120 bytes for full node data)

Both should live in Rust's `build_draw_list()` function so the culled data never crosses the FFI boundary at all.

***
## Tier 3 — Ship Eventually (Deep Architecture)
### GPU-Driven Rendering via Metal Indirect Command Buffers
Today's render loop: CPU iterates all visible nodes, builds instance buffers, encodes commands, submits. With 10,000+ nodes, this CPU work scales linearly. **Metal Indirect Command Buffers (ICBs)** invert this: the GPU runs a compute pass that culls nodes and writes its own draw commands into an ICB, then executes that ICB.[^23][^24][^25]

Apple demonstrated this pattern at both WWDC 2019 and WWDC 2023:[^25][^26]

```metal
// Compute kernel (GPU-side culling)
kernel void buildDrawList(
    device NodeInstance* allNodes [[buffer(0)]],
    device MTLDrawPrimitivesIndirectArguments* args [[buffer(1)]],
    constant uint& nodeCount [[buffer(2)]],
    constant Frustum& frustum [[buffer(3)]],
    uint id [[thread_position_in_grid]])
{
    if (id >= nodeCount) return;
    NodeInstance node = allNodes[id];
    if (!frustum.contains(node.position)) return;
    // Append to ICB — GPU writes its own draw call
    uint slot = atomic_fetch_add_explicit(&args->instanceCount, 1, memory_order_relaxed);
    // ... encode draw command at slot
}
```

The CPU's only per-frame work becomes uploading the frustum uniform and calling `executeCommandsInBuffer`. Note that Metal ICBs cap at 16,384 commands on some hardware, so for graphs above that threshold, multiple ICBs or a draw-indirect approach is needed.[^27]
### Async Swift→Rust Message Queue
The final architectural milestone eliminates the last class of main-thread Rust blocking. Instead of calling Rust synchronously (even through the FFI Actor), Swift pushes commands into a lock-free queue; Rust drains and applies them each physics tick:

```swift
// Swift — non-blocking push
func updateCameraPosition(_ cam: CameraState) {
    commandQueue.push(.cameraUpdate(cam))   // returns immediately
}

// Rust — applied per physics tick
while let cmd = command_queue_pop() {
    match cmd {
        CameraUpdate(cam) => apply_camera(cam),
        NodeMetadata(batch) => apply_metadata(batch),
        // ...
    }
}
```

This makes the Swift side entirely non-blocking and gives Rust the ability to batch-apply commands at the physics rate rather than the UI rate.

***
## Animation Optimization Details
The "programmatic vs physical" feel difference is almost entirely about **where interpolation happens**. SwiftUI `withAnimation` runs layout passes on the main thread, competes with render work, and produces the "software" feeling. Moving animation state into Metal shader uniforms eliminates that competition:[^5][^28]

```metal
// In the vertex shader — spring physics in Metal, not SwiftUI
float t = clamp((time - nodeData.animStartTime) / 0.5, 0.0, 1.0);
float spring = 1.0 - exp(-6.0 * t) * cos(12.0 * t);   // damped spring
float2 interpolatedPos = mix(nodeData.prevPos, nodeData.targetPos, spring);
```

For `TimelineView`-driven effects (the "breathe" and "glow" animations), gating is critical. An unconstrained `TimelineView(.animation)` can cause severe frame budget overruns when combined with heavy render work. The correct pattern is:[^28]

```swift
TimelineView(isPaused ? .pause : .animation(minimumInterval: 1.0/30.0)) { context in
    GlowEffect(time: context.date.timeIntervalSinceReferenceDate)
}
```

The `.pause` schedule stops the timeline entirely when the window is occluded or the user is in Static Mode, eliminating unnecessary GPU wake-ups. Using `Transaction(animation: .none)` for programmatic state writes that do not need animation (e.g. version counter updates, config syncs) prevents SwiftUI from generating spurious animation transactions.[^29][^30][^5]

***
## Definitive Implementation Order
```
Week 1
├── GraphFFIActor with custom serial executor  ← fixes crash
├── Zero-copy buffer handshake (Swift owns)    ← eliminates double-free
├── selectionTask?.cancel() pattern            ← fixes label flicker
├── Inspector position throttle (3 lines)      ← eliminates observation churn
└── Fire-and-forget metadata push              ← unblocks commit path

Month 1
├── Rust: graph_engine_tick() split from render()
├── Physics background thread + triple-buffer
├── Render interpolation (alpha = accumulator/dt)
└── Rust: frustum culling + LOD in build_draw_list()

Eventually
├── Metal ICBs for GPU-driven culling
└── Async Swift→Rust command queue
```
## Why This Order Is Non-Negotiable
Attempting background physics before the FFI Actor is hardened means the physics thread will race with the render thread at the Rust boundary — reproducing the exact crash being fixed. Attempting GPU-driven rendering before the physics thread is decoupled means the GPU workload increases while the CPU is still blocked, worsening frame spikes. The tiers form a strict dependency graph, not an arbitrary backlog.

The payoff at each stage is concrete:
- **After Week 1**: App stops crashing; labels stop flickering; inspector stops causing observation storms
- **After Month 1**: FPS becomes consistent regardless of cluster density; battery impact drops significantly
- **After "Eventually"**: Genuine 10,000+ node capacity at 120Hz on a MacBook Air

---

## References

1. [Guide to zero-copy FFI with Rust and Unity - Test Double](https://testdouble.com/insights/rust-unity-zero-copy-ffi-guide) - A technical guide to building zero-copy FFI bridges between Rust and Unity. Learn how to pass struct...

2. [Python calling Rust FFI with ctypes crashes at exit with "pointer ...](https://stackoverflow.com/questions/38412184/python-calling-rust-ffi-with-ctypes-crashes-at-exit-with-pointer-being-freed-wa) - Thanks to the effort made in J.J. Hakala's answer, I was able to produce a MCVE in pure Rust: Copy. ...

3. [Dive into structured tasks and task cancellation in Swift Concurrency](https://juniperphoton.substack.com/p/dive-into-structured-tasks-and-task) - To cancel a task, we call the cancel method of a task instance. Then the task itself and all of its ...

4. [Task Cancellation in Swift Concurrency](https://swiftwithmajid.com/2025/02/11/task-cancellation-in-swift-concurrency/) - Swift Concurrency provides a cooperative cancellation model to handle task cancellation. This week, ...

5. [SwiftUI updates reduce FPS of metal window - Stack Overflow](https://stackoverflow.com/questions/59212294/swiftui-updates-reduce-fps-of-metal-window) - I had the slider data updating the Metal window but when I moved the slider the FPS dropped from 60 ...

6. [swift-evolution/proposals/0392-custom-actor-executors.md at main](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md) - We propose to give developers the ability to implement simple serial executors, which then can be us...

7. [Controlling Actors With Custom Executors - Jack Morris](https://jackmorris.xyz/posts/2023/11/21/controlling-actors-with-custom-executors) - I decided to give custom actor executors a whirl (new in Swift 5.9), which in this case allows me to...

8. [Migrate your app to Swift 6 - WWDC24 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2024/10169/) - This should be a last resort, it's best to use Swift's compile time guarantees instead. But the comp...

9. [How to use UnsafeMutableBufferPointer - Stack Overflow](https://stackoverflow.com/questions/34750166/how-to-use-unsafemutablebufferpointer) - UnsafeMutableBufferPointer doesn't own its memory, so you still have to use UnsafeMutablePointer to ...

10. [swift-evolution/proposals/0322-temporary-buffers.md at main - GitHub](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0322-temporary-buffers.md) - The caller can call UnsafeMutableBufferPointer<taco_t>.allocate(capacity:) to get uninitialized memo...

11. [How to manage unstructured tasks with Swift's structured concurrency](https://itnext.io/how-to-manage-unstructured-tasks-with-swifts-structured-concurrency-6cc4329b4d13) - In this post, we will explore managing unstructured tasks in Swift Structured Concurrency and handli...

12. [Improving View Performance with Asynchronous Switching Between ...](https://www.reddit.com/r/swift/comments/1dlt1b7/improving_view_performance_with_asynchronous/) - This approach leverages Swift's concurrency features with async/await and MainActor to streamline th...

13. [Evidence for Performance Benefits of the Observation - Swift Forums](https://forums.swift.org/t/evidence-for-performance-benefits-of-the-observation/74398) - Observation provides a more efficient way to make app model data observable, I'm looking for more co...

14. [The State of Observability after WWDC25 : r/swift - Reddit](https://www.reddit.com/r/swift/comments/1lihdq9/the_state_of_observability_after_wwdc25/) - Observation on the other hand, is more performant out of the box, and the funcionality it has couple...

15. [ios - Running Time-Consuming Tasks on @MainActor: Should I Be ...](https://stackoverflow.com/questions/79097247/running-time-consuming-tasks-on-mainactor-should-i-be-concerned-about-ui-respo) - I always thought that using Task would automatically run time-consuming tasks on a background thread...

16. [Major Concurrency Changes in Swift 6.1 — What's New and Why It ...](https://blog.stackademic.com/major-concurrency-changes-in-swift-6-1-whats-new-and-why-it-matters-3a505cb94563) - Forgetting to do so could lead to runtime issues if you touch UIKit from a background thread. With M...

17. [Why use interpolation in fixed time step game loop? - Reddit](https://www.reddit.com/r/gamedev/comments/t1uxzb/why_use_interpolation_in_fixed_time_step_game_loop/) - The reason it's done is to keep the rendering smooth despite running at a different framerate than t...

18. [Reliable fixed timestep & inputs | Jakub's tech blog](https://jakubtomsu.github.io/posts/input_in_fixed_timestep/) - It explains how to properly accumulate a timer and run ticks with a fixed delta time within your mai...

19. [Understanding how a fixed time step game loop works, but having ...](https://www.gamedev.net/forums/topic/701411-understanding-how-a-fixed-time-step-game-loop-works-but-having-trouble-grasping-interpolation-in-the-render-function/) - I'm just having trouble understanding how interpolation in the rendering loop works. Everything seem...

20. [Atomics: Triple Buffer - The Rust Programming Language Forum](https://users.rust-lang.org/t/atomics-triple-buffer/51048) - I am trying to implement a triple buffer. At any given time, the "reader" is reading one buffer, and...

21. [What is the difference between Rust's thread safety guarentees and ...](https://users.rust-lang.org/t/what-is-the-difference-between-rusts-thread-safety-guarentees-and-atomic-variables/44409) - Rust's restriction that only only thread can write to a variable at a time, but any thread can read ...

22. [Metal by Tutorials, Chapter 15: GPU-Driven Rendering - Kodeco](https://www.kodeco.com/books/metal-by-tutorials/v2.0/chapters/15-gpu-driven-rendering) - Note: Indirect command buffers are supported by: iOS - Apple A9 devices and up; iMacs - models from ...

23. [MTLIndirectCommandBuffer | Apple Developer Documentation](https://developer.apple.com/documentation/metal/mtlindirectcommandbuffer) - Overview. Use an indirect command buffer to encode commands once and reuse them, and to encode comma...

24. [Harness Apple GPUs with Metal - WWDC20 - Videos](https://developer.apple.com/videos/play/wwdc2020/10602/) - In this session, we'll discuss the efficiency of Apple GPUs and show how TBDR applies to an array of...

25. [Modern Rendering with Metal - WWDC19 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2019/601/) - Metal is the GPU-accelerated graphics and compute framework that helps developers build everything f...

26. [Bring your game to Mac, Part 3: Render with Metal - Apple Developer](https://developer.apple.com/videos/play/wwdc2023/10125/) - We'll show you how to manage GPU resource bindings, residency, and synchronization. Find out how to ...

27. [MultiDrawIndirect and Metal - Tellusim Technologies Inc.](https://tellusim.com/metal-mdi/) - The official Metal way is to use Indirect Command Buffer and encode rendering commands on CPU or GPU...

28. [iOS 15: SwiftUI Canvas/TimelineView terrible performance - Reddit](https://www.reddit.com/r/SwiftUI/comments/pd9jcl/ios_15_swiftui_canvastimelineview_terrible/) - Playing around with new Canvas/TimelineView for iOS 15. I tried to create a particle system using th...

29. [Mastering TimelineView in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/) - We will learn how to use TimelineView to create time-based views this week. Enhancing the Xcode Simu...

30. [TimelineView in SwiftUI - Swift Programming](https://swiftprogramming.com/timelineview-swiftui/) - This is the most battery-efficient scheduler. It updates the view exactly at the beginning of each m...

