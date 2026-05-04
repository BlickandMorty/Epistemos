# Night Brain — Autonomous Background Processing
## Research Compendium — Capability 5

*Expert audience. All citations inline. Covers macOS background APIs, spaced repetition theory, incremental HNSW indexing, orphan knowledge detection, comparable systems, and critical UX pitfalls for a nightly autonomous pipeline on Apple Silicon.*

---

## Section 1: macOS Background Processing APIs

### 1.1 NSBackgroundActivityScheduler

`NSBackgroundActivityScheduler` is the primary high-level API for scheduling maintenance and background work in macOS apps. It functions similarly to `NSTimer` but critically delegates scheduling decisions to the system, which can defer or cluster execution based on energy usage, thermal conditions, and CPU utilization. ([Apple Energy Efficiency Guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/SchedulingBackgroundActivity.html))

**Key configuration properties:**

| Property | Purpose | Recommended Value for Night Brain |
|---|---|---|
| `identifier` | Reverse-DNS constant, stable across launches | `com.yourapp.nightbrain.nightly` |
| `repeats` | Reschedule after completion | `true` |
| `interval` | Average time between invocations | `86400` (24h) |
| `tolerance` | Window around nominal fire date | `3600` (±1h) |
| `qualityOfService` | Scheduling aggressiveness | `.background` (default) |

**Scheduling mechanics:** The system calculates a nominal fire date from `interval` + last fire date. The tolerance creates a window `[nominalDate - tolerance/2, nominalDate + tolerance/2]`. Within that window, the system picks an opportunistic moment — typically when the machine is otherwise idle and has excess thermal and power headroom. DAS (Daemon Activity Scheduler), the kernel subsystem underneath, assigns each registered activity a priority score and a time window, and prevents incompatible activities from running concurrently. ([Eclectic Light Company — Watch Your Background](https://eclecticlight.co/2025/01/29/watch-your-background-background-activities-with-das-cts/))

**Completion handler contract:** The block receives an `NSBackgroundActivityCompletionHandler`. Call it with `.finished` on success or `.deferred` to reschedule. **Failure to call the completion handler prevents rescheduling** — a common crash-silent bug. For very long tasks (re-indexing can take tens of minutes), design work as resumable segments; check `activity.shouldDefer` frequently. If `shouldDefer` returns `true` (e.g., user unplugged the machine), checkpoint state and call `.deferred`.

```swift
let scheduler = NSBackgroundActivityScheduler(identifier: "com.app.nightbrain.nightly")
scheduler.repeats = true
scheduler.interval = 86_400    // 24 hours
scheduler.tolerance = 3_600    // ±1 hour
scheduler.qualityOfService = .background

scheduler.schedule { completion in
    guard !scheduler.shouldDefer else {
        // Save checkpoint, reschedule
        completion(.deferred)
        return
    }
    // ... perform work in segments ...
    completion(.finished)
}
```

**Underlying mechanism:** `NSBackgroundActivityScheduler` wraps XPC Activity (`com.apple.xpc.activity`), which in turn goes through `launchd` and DAS. The system also automatically wraps the block with `ProcessInfo.processInfo.beginActivity(options:reason:)` at the QoS-appropriate level — meaning App Nap suppression is automatic during scheduled execution. ([Apple Energy Efficiency Guide](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/SchedulingBackgroundActivity.html))

**Limitation:** `NSBackgroundActivityScheduler` is in-process — if the app is not running, it cannot fire. For a headless nightly pipeline that must run even when the user hasn't launched the app, use a **LaunchAgent** `.plist` registered via `launchctl` or `SMAppService` (macOS 13+). LaunchAgents with `StartCalendarInterval` or `StartInterval` are fired by `launchd` independently of the app's lifecycle.

---

### 1.2 ProcessInfo.thermalState Monitoring

Apple Silicon Macs expose thermal state through multiple channels with different granularities. ([Stanislas Blog — Building a macOS App to Know When My Mac Is Thermal Throttling](https://stanislas.blog/2025/12/macos-thermal-throttling-app/))

**ProcessInfo.thermalState (public, sandbox-safe):**

```swift
let state = ProcessInfo.processInfo.thermalState
// .nominal, .fair, .serious, .critical
```

**Mapping table — ProcessInfo vs. actual throttling level:**

| `ProcessInfo.thermalState` | `powermetrics` thermal pressure | Interpretation |
|---|---|---|
| `.nominal` | Nominal | Full performance |
| `.fair` | Moderate | Slight frequency reduction |
| `.fair` | Heavy | Real throttling begins — **ProcessInfo conflates these two** |
| `.serious` | Trapping | Aggressive throttling, fan at high RPM |
| `.critical` | Sleeping | System may enter protective low-power state |

The coarse mapping is the key limitation: `.fair` covers both "moderate" (acceptable for background work) and "heavy" (where throttling meaningfully impacts throughput). For Night Brain's use, `.fair` should trigger backoff. ([UBOS — MacThrottle](https://ubos.tech/news/macthrottle-real%E2%80%91time-thermal-throttling-monitoring-app-for-macos/))

**Higher-resolution channel — thermald notifyd (no root required):**

The `thermald` daemon publishes to Darwin's notification system under `com.apple.system.thermalpressurelevel`. This gives the 5-level scale (0=nominal, 1=moderate, 2=heavy, 3=trapping, 4=sleeping):

```swift
import Foundation

@_silgen_name("notify_register_check")
private func notify_register_check(_ name: UnsafePointer<CChar>,
                                   _ token: UnsafeMutablePointer<Int32>) -> UInt32
@_silgen_name("notify_get_state")
private func notify_get_state(_ token: Int32,
                               _ state: UnsafeMutablePointer<UInt64>) -> UInt32
@_silgen_name("notify_cancel")
private func notify_cancel(_ token: Int32) -> UInt32

func thermalPressureLevel() -> UInt64 {
    let name = "com.apple.system.thermalpressurelevel"
    var token: Int32 = 0
    guard name.withCString({ notify_register_check($0, &token) }) == 0 else { return 0 }
    defer { _ = notify_cancel(token) }
    var state: UInt64 = 0
    _ = notify_get_state(token, &state)
    return state
}
```

**Recommended Night Brain thermal policy:**

```
Level 0 (nominal)  → Full throughput, all workers active
Level 1 (moderate) → Reduce worker threads by 25%
Level 2 (heavy)    → Pause embedding generation, complete GRDB writes only
Level 3 (trapping) → Checkpoint state immediately, suspend pipeline
Level 4 (sleeping) → OS handles; should never reach here during normal operation
```

Register for the notification to receive state-change callbacks rather than polling. Combine with a 30-second polling fallback for robustness.

---

### 1.3 Detecting Plugged-In + Idle State

**Power source detection via IOPowerSources:**

```swift
import IOKit.ps

func isOnACPower() -> Bool {
    guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
        return true // assume AC if detection fails
    }
    for source in list {
        if let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
           let state = desc[kIOPSPowerSourceStateKey] as? String {
            return state == kIOPSACPowerValue
        }
    }
    return false
}
```

`IOPSNotificationCreateRunLoopSource()` provides real-time callbacks when power state changes — register this to immediately pause processing if the user unplugs. ([Stack Overflow — Mac Get Battery Charging Status](https://stackoverflow.com/questions/5751132/mac-get-battery-charging-status-plugged-in-or-not), [Apple Developer — IOPowerSources.h](https://developer.apple.com/documentation/iokit/iopowersources_h))

**User idle time via CoreGraphics:**

```swift
import CoreGraphics

func userIdleSeconds() -> Double {
    return CGEventSource.secondsSinceLastEventType(
        .combinedSessionState,
        eventType: CGEventType(rawValue: ~0)!  // kCGAnyInputEventType
    )
}
```

`kCGAnyInputEventType` covers keyboard, mouse, and tablet input. For Night Brain, treat ≥ 5 minutes idle as "safe to run heavy work." ([Apple Developer — CGEventSource.secondsSinceLastEventType](https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)))

**Recommended precondition gate for pipeline start:**

```swift
func canStartNightBrain() -> Bool {
    return isOnACPower() &&
           userIdleSeconds() > 300 &&   // 5 min idle
           thermalPressureLevel() <= 1   // nominal or moderate
}
```

---

### 1.4 App Nap Prevention and ProcessInfo.beginActivity

**App Nap** is macOS's energy optimization that throttles CPU, I/O, and timers for apps not visible to the user. For background processing, it must be explicitly prevented during active pipeline execution.

**Using ProcessInfo.beginActivity:**

```swift
var activityToken: NSObjectProtocol?

func startPipelineActivity() {
    activityToken = ProcessInfo.processInfo.beginActivity(
        options: [.background, .idleSystemSleepDisabled, .automaticTerminationDisabled],
        reason: "Night Brain nightly re-indexing pipeline"
    )
}

func endPipelineActivity() {
    if let token = activityToken {
        ProcessInfo.processInfo.endActivity(token)
        activityToken = nil
    }
}
```

**NSActivityOptions for background work:**

| Option | Effect |
|---|---|
| `.background` | Informs system of important background work (baseline) |
| `.idleSystemSleepDisabled` | Prevents idle sleep (pair with IOPMAssertion for belt-and-suspenders) |
| `.automaticTerminationDisabled` | Prevents macOS from terminating the process silently |
| `.suddenTerminationDisabled` | Prevents immediate kill on quit (for safe checkpointing) |

**Important:** The token must be kept strongly referenced. If it is deallocated, the activity ends immediately. Store it as an instance property on a long-lived object. ([Stack Overflow — Disable App Nap in Swift](https://stackoverflow.com/questions/27653939/disable-app-nap-in-swift), [Lazarus Wiki — macOS App Nap](https://wiki.lazarus.freepascal.org/macOS_App_Nap))

---

### 1.5 IOPMAssertions — Preventing Sleep

For preventing system sleep during critical write operations (HNSW snapshot serialization, GRDB transaction commits), use the IOKit Power Management assertion API:

```swift
import IOKit.pwr_mgt

class SleepGuard {
    private var assertionID: IOPMAssertionID = 0
    private var isActive = false

    func prevent(reason: String) {
        guard !isActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        isActive = (result == kIOReturnSuccess)
    }

    func allow() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        isActive = false
    }
}
```

`kIOPMAssertionTypeNoIdleSleep` prevents sleep only when the system would otherwise go idle — it does not prevent user-initiated sleep. `kIOPMAssertionTypeNoDisplaySleep` additionally keeps the display on (avoid this for background work). The assertion string (≤128 characters) is shown to the user in Energy Saver's "Why is my Mac not sleeping?" UI. ([Apple Technical QA1340](https://developer.apple.com/library/archive/qa/qa1340/_index.html), [Stack Overflow — Disable sleep mode in OS X with Swift](https://stackoverflow.com/questions/36757229/disable-sleep-mode-in-os-x-with-swift))

---

### 1.6 XPC Services for Process Isolation

An XPC service runs as a separate process inside the app bundle (`Contents/XPCServices/`), with its own sandbox, memory space, and lifecycle. This is the correct architecture for Night Brain's heavy ML and indexing work: a crash in the indexer XPC service does not bring down the main app. ([Apple Developer — Creating XPC Services](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html))

**Architecture for Night Brain:**

```
Main App (Swift + SwiftUI)
    │
    ├── XPC Connection → NightBrainWorker.xpc
    │       ├── HNSW re-indexing (Rust via FFI)
    │       ├── Embedding generation (Metal shaders)
    │       ├── Orphan detection computation
    │       └── Cognitive digest assembly
    │
    └── GRDB/SQLite (shared read, XPC writes via protocol)
```

Key design principles:
- XPC services must be **minimally stateful** — they can be killed by the OS at any time. Design for crash-safe resumption via GRDB-backed checkpoints.
- Communication is via `NSXPCConnection` with a declared protocol. Use `NSProgress` for reporting pipeline progress back to the main app.
- Use `NSXPCInterface.allowedClasses` to sandbox the object types that can cross the XPC boundary.
- Apple uses XPC pervasively internally: Spotlight's `mdworker` processes are XPC services; Photos' ML analysis workers are XPC-isolated. ([Eclectic Light Company — Spotlight Problems](https://eclecticlight.co/2022/12/08/spotlight-problems-mds_stores-and-mdworker-in-trouble/))

---

### 1.7 Thermal and Energy Citizenship on Apple Silicon

Apple Silicon's unified memory architecture means CPU, GPU, and ANE share the same thermal envelope. Running a Metal embedding compute shader at full throughput while HNSW insertion is hot on the CPU cores can quickly push the package to `heavy` thermal pressure, triggering throttling that reduces overall throughput below what a 50% CPU + 50% GPU schedule would achieve. ([Apple ML Research — On-Device Face Detection](https://machinelearning.apple.com/research/face-detection))

**Practical guidelines:**
1. **Phase work sequentially, not in parallel by subsystem.** Run GRDB reads first, then Metal embedding generation, then HNSW insertion — don't pipeline all three simultaneously.
2. **Use `.background` QoS** throughout. The scheduler will preempt night brain for any user-facing work.
3. **Check `activity.shouldDefer` every N operations** (e.g., every 500 HNSW insertions) to detect conditions that warrant pausing.
4. **Cap Metal dispatch groups** to avoid GPU saturation — limit concurrentDispatchGroups to 2-4 even on M-series chips during background work.
5. **Report thermal state in pipeline telemetry** stored in GRDB so you can retroactively understand performance variability.

Apple Photos' on-device ML takes a similar approach: "we split GPU work items for each layer of the network until each individual time is less than a millisecond. This allows the driver to switch contexts to higher priority tasks in a timely manner, such as UI animations." ([Apple ML Research — On-Device Face Detection](https://machinelearning.apple.com/research/face-detection))

---

## Section 2: Spaced Repetition and Daily Review Research

### 2.1 Ebbinghaus Forgetting Curve

Hermann Ebbinghaus conducted his memory experiments from 1880–1885, studying retention of nonsense syllable lists using the *savings method* (time-to-relearn as a percentage of time-to-learn). His 1885 equation, which became the canonical Ebbinghaus Forgetting Equation:

**R(t) = 1.84 / ((log₁₀ t)^1.25 + 1.84)**

where t is time in appropriate units. His power function from 1880 fit equally well. The forgetting curve shows rapid initial loss followed by a decelerating decay.

A 2015 replication by Murre & Dros confirmed the curve's validity across languages and settings. One subject spent 70 hours learning and relearning syllable lists at intervals of 20 minutes, 1 hour, 9 hours, 1 day, 2 days, and 31 days. The resulting curve was "very similar to both that of Ebbinghaus and that of the two subjects in an earlier German replication." ([Murre & Dros, PLoS ONE 2015 — Replication and Analysis of Ebbinghaus' Forgetting Curve](https://pmc.ncbi.nlm.nih.gov/articles/PMC4492928/))

**Practical numbers for Night Brain:**
- After 1 day without review: ~30% retention
- After 1 week: ~10–15% retention without reinforcement
- A single well-timed review at the 70% retention point reshapes the curve, extending the next forgetting half-life exponentially

The key insight for the Night Brain's cognitive digest: notes written more than ~7 days ago without any access are likely below the 15% retention threshold — they are candidates for surfacing.

---

### 2.2 SM-2 Algorithm (SuperMemo)

SM-2 (Wozniak, 1987) is the foundational spaced repetition algorithm used in early Anki versions. It tracks an **Easiness Factor (EF)** per item:

**Interval calculation:**
- I(1) = 1 day
- I(2) = 6 days
- I(n) = I(n-1) × EF, for n > 2

**EF update rule after each review (grade q ∈ [0,5]):**

EF' = EF + (0.1 − (5 − q) × (0.08 + (5 − q) × 0.02))

Constraints: EF ≥ 1.3 (minimum). If q < 3, reset to I(1) without changing EF. ([Stack Overflow — Spaced repetition algorithm from SuperMemo](https://stackoverflow.com/questions/49047159/spaced-repetition-algorithm-from-supermemo-sm-2))

**Limitations of SM-2 for note surfacing (not just flashcards):** EF is a static per-item scalar — it doesn't model the multi-dimensional nature of a note's relevance, recency, or semantic relationship to active work. SM-2 was designed for isolated vocabulary items where "ease" is a stable property of the item, not the context.

---

### 2.3 FSRS Algorithm (Free Spaced Repetition Scheduler)

FSRS (Ye et al., 2022) is a probabilistic memory model built on the **DSR framework** (Difficulty, Stability, Retrievability), now the default scheduler in Anki 23+. It is substantially more accurate than SM-2 because it models memory as continuous rather than discrete. ([FSRS4Anki GitHub](https://github.com/open-spaced-repetition/fsrs4anki))

**Three state variables per item:**

1. **Retrievability R(t)**: Probability of recall at time t since last review.
   R(t, S) = (1 + F × t/S)^C, where F = 19/81, C = −0.5
   At t = S (stability days), R = 90%.

2. **Stability S**: Time in days for R to decay from 100% to 90%. Higher is better. Initial S after first review depends solely on grade (4 parameters: one per grade: Again, Hard, Good, Easy).

3. **Difficulty D**: Scalar ∈ [1, 10] representing inherent difficulty. Initialized from first-review grade; updated via:
   - Grade-only delta
   - Linear damping (asymptotic approach to D=10)
   - Mean reversion toward w₄ (Easy-default difficulty)

**Stability update on successful review:**

S_new = S × SInc
SInc = 1 + e^(w₈) × (11 − D) × S^(−w₉) × (e^(w₁₀(1−R)) − 1) × w₁₅[grade] × w₁₆[grade]

Where w₁₅ < 1 for Hard, = 1 for Good/Easy; w₁₆ = 1 for Hard/Good, > 1 for Easy.

**Stability on lapse (Again):**

S_lapse = min(w₁₁ × D^(−w₁₂) × ((S+1)^(w₁₃) − 1) × e^(w₁₄(1−R)), S)

The `min(…, S)` ensures post-lapse stability never exceeds pre-lapse stability. ([Expertium — A Technical Explanation of FSRS](https://expertium.github.io/Algorithm.html))

**Interval computation:**

I = (S / F) × (DR^(1/C) − 1)

When desired retention (DR) = 90%, I = S exactly.

**17–20 weight parameters** optimized via gradient descent on binary cross-entropy (recall/lapse classification). Parameters can be personalized to individual user review logs.

**Why FSRS matters for Night Brain:**
FSRS' S (stability) value is directly actionable: a note with S=2 needs review in ~2 days; S=60 needs review in ~60 days. The Night Brain can maintain an FSRS state table per note in GRDB and compute "due for review tonight" notes as those where R(t) has decayed below a configurable threshold (e.g., 0.75). ([Fernando Borretti — Implementing FSRS in 100 Lines](https://borretti.me/article/implementing-fsrs-in-100-lines))

---

### 2.4 Leitner System and Box-Based Surfacing

The Leitner system (Sebastian Leitner, 1970s) is a physical implementation of spaced repetition using five boxes with fixed review frequencies: ([University of York — The Leitner System](https://subjectguides.york.ac.uk/study-revision/leitner-system))

| Box | Review Frequency | Interpretation |
|---|---|---|
| 1 | Daily | New or frequently-missed items |
| 2 | Every 3 days | Learning |
| 3 | Weekly | Familiar |
| 4 | Bi-weekly | Well-known |
| 5 | Monthly | Mastered |

For note surfacing (not memorization), the Leitner structure maps naturally to a note's "access tier." A note that was accessed last week lives in Box 3; one not accessed in a month lives in Box 5. The Night Brain can use Leitner-style tiering as a fast O(1) lookup for "which notes are due tonight" without running the full FSRS computation across all notes — compute FSRS only for notes already in Box 1-2, use FSRS-approximate bucket membership for Box 3-5.

---

### 2.5 Andy Matuschak and Michael Nielsen — Transformative Tools for Thought

In their 2019 essay "How can we develop transformative tools for thought?" (the companion to their *Quantum Country* prototype), Matuschak and Nielsen established the conceptual framework for **mnemonic media** — combining spaced repetition with long-form essays so that reading and remembering are inseparable. ([Matuschak & Nielsen — How can we develop transformative tools for thought?](https://numinous.productions/ttft/))

**Key findings from Quantum Country data:**
- Devoting <50% additional time to spaced repetition after reading produced months-to-years of retention across 112 cards
- 195 users achieved ≥1 month retention on ≥80% of cards within 6 months
- After 6 repetitions (95 minutes total), average demonstrated retention was ~54 days per card

**Critical insight for Night Brain's cognitive digest design:** Matuschak and Nielsen emphasize that memory systems should surface material in *context* — cards are valuable because they are linked to a source essay that provides narrative embedding. An isolated note surfaced in a digest without contextual framing has lower retention value than one surfaced with its semantic neighborhood visible.

**Elaborative encoding** (connecting new ideas to existing knowledge) and **avoiding orphans** (cards/notes with no connections to other items in the knowledge graph) are the two most important quality criteria. The Night Brain's digest should not just surface individual notes but also show *why* they are relevant to current work — the bridge, not just the node.

Matuschak's separate essay on writing prompts explicitly states: "Memory ceases to be a haphazard phenomenon... spaced repetition systems make memory a choice." ([Andy Matuschak — How to write good prompts](https://andymatuschak.org/prompts/))

---

### 2.6 Daily Review Practices

**Julia Cameron — Morning Pages:**
Three pages of stream-of-consciousness longhand writing upon waking, every day. "Morning Pages provoke, clarify, comfort, cajole, prioritize and synchronize the day at hand." ([Jenna Avery — How to Write Morning Pages](https://www.jennaavery.com/morning-pages)) The mechanism is *cognitive clearing* — externalizing anxieties and pending tasks before they load into working memory. A Night Brain digest should front-load the "clearing" function: show what happened in the vault overnight before surfacing recommendations.

**Zettelkasten Daily Review (Tietze/Fast):**
The Zettelkasten daily review starts with reviewing short-to-mid-term goals (via a mind map), then limits the day's active work to 3–5 WIP items from a personal kanban. Key principle: the system should "present you with ideas you have already forgotten, allowing your brain to focus on thinking instead of remembering." ([Zettelkasten.de — Tasks and Goals of my Daily Review](https://zettelkasten.de/posts/daily-review-tasks/)) This is exactly what the Night Brain digest is attempting — the slip-box (Zettelkasten) was explicitly designed to be a "conversation partner" that surfaces forgotten connections.

**Roam/Obsidian daily notes pattern:**
Creating a new dated note each day, linked to the previous and future days, provides a temporal spine for the knowledge graph. The Night Brain can use the daily note as the *injection point* for digest content — the cognitive digest is a structured section within today's daily note.

---

### 2.7 Note Selection for Daily Review

The challenge is not random surfacing but *intelligent* surfacing. Three principles should govern which notes appear in the digest:

1. **Forgetting risk** (FSRS-derived): Notes where R(t) < threshold
2. **Semantic relevance to current active projects**: Notes with high cosine similarity to recent-N-day note embeddings
3. **Bridge value**: Notes that have high betweenness centrality in the link graph but haven't been accessed recently — they connect clusters

**Against random surfacing:** Boris Smus's Obsidian semantic similarity plugin demonstrated that "the current paragraph is continuously fed into a semantic similarity model, so that movement of the cursor or textual edits trigger updates in real-time." ([Boris Smus — Semantic Similarity for Note Taking](https://smus.com/semantic-similarity-note-taking/)) Night Brain extends this concept to temporal context: instead of the current cursor position, use the centroid of embeddings from the last 7 days of active notes.

---

## Section 3: Incremental HNSW Re-indexing

### 3.1 usearch API — Add/Remove Operations

usearch (Unum Cloud) is a HNSW implementation with first-class support for incremental operations across all target platforms and languages including Swift, Rust, C99, Python, Java, and Go. ([usearch GitHub](https://github.com/unum-cloud/usearch))

**Core operations (supported in Swift and Rust):**

| Operation | Swift/Rust Support | Notes |
|---|---|---|
| `add(key, vector)` | ✅ | Can batch-add in parallel |
| `remove(key)` | ✅ | Soft delete with tombstone |
| `search(vector, k)` | ✅ | ANN with ef control |
| `save(path)` | ✅ | Atomic file serialization |
| `load(path)` | ✅ | Full in-memory load |
| `view(path)` | ✅ | Memory-mapped read (no RAM copy) |
| Filter predicates | ✅ | Closure-based key filtering |

**Incremental add** works without full rebuild. HNSW supports dynamic insertion: new nodes are connected to existing graph nodes at all levels, then the entry point and level structure are updated. The insertion QPS is proportional to efConstruction and connectivity (M). ([usearch PyPI](https://pypi.org/project/usearch/2.8.14/))

**Consistency guarantees:** usearch does not publish explicit ACID-style consistency guarantees in its documentation. For Night Brain, treat the usearch index as an eventually-consistent cache of the GRDB-authoritative vector store — GRDB is the source of truth, usearch is the search acceleration structure. This means a rebuild from GRDB is always safe on startup.

---

### 3.2 Performance Benchmarks

usearch benchmarks on **AWS Graviton 3 (ARM, 64 cores)** — the closest publicly available proxy for Apple Silicon:

| Configuration | Add QPS | Search QPS | Recall @1 |
|---|---|---|---|
| f32×256, M=16, efA=128, efS=64 | 75,640 | 131,654 | 99.3% |
| f32×256, M=16, efA=64, efS=32 | 128,644 | 228,422 | 97.2% |
| i8×256, M=16, efA=128, efS=64 | 115,923 | 274,653 | 98.9% |

From a separate benchmark: "On 100M vectors, USearch achieves 105,000 insertions/second vs FAISS's 5,500 (19x faster) and 115,000 searches/second vs FAISS's 600 (189x faster)." ([Twitter — @ohmypy](https://x.com/ohmypy/status/1993747658381643943))

**Apple Silicon extrapolations for Night Brain (conservative estimates):**

Apple M-series chips have significantly better single-thread performance and SIMD throughput than Graviton 3 for non-batched workloads. Using the ARM benchmark as a lower bound:

| Vault Size | Vectors (1536-dim f32) | Estimated full rebuild time | Estimated incremental additions/night |
|---|---|---|---|
| 10K notes | ~10K vectors | ~8 seconds | ~100 adds in <1s |
| 100K notes | ~100K vectors | ~80 seconds | ~1,000 adds in <2s |
| 500K notes | ~500K vectors | ~7 minutes | ~5,000 adds in <10s |

*Note: 1536-dim f32 is used for text-embedding-3-small class embeddings. Throughput decreases with dimension count; FAISS published 5x slower indexing at 1536d vs. 96d.*

For Night Brain on a personal vault (realistic: 5K–50K notes), full nightly rebuild takes 10–80 seconds — fast enough that **full nightly rebuild is viable** and simpler than incremental management for most users. Delta indexing becomes important only at 200K+ notes.

---

### 3.3 Delta Indexing Strategy

For large vaults, full nightly rebuild is wasteful. The recommended delta architecture:

**Main index + delta buffer pattern:**

```
[Primary usearch Index] ← Large, stable, read-optimized
        +
[Delta usearch Index]   ← Small, recent changes since last full rebuild
        +
[Tombstone set in GRDB] ← Keys removed since last full rebuild
```

**Search query:** Search both primary and delta, union results, filter tombstones, rerank. The overhead is minimal: delta index is typically <5% of primary.

**Merge policy:** When delta index grows beyond threshold (e.g., 5% of primary, or at scheduled nightly rebuild), merge via usearch's `Indexes` multi-index API or by rebuilding primary from GRDB source:

```python
# Python pseudocode; Swift equivalent via usearch C FFI
from usearch.index import Indexes
multi = Indexes(indexes=[primary_idx, delta_idx])
results = multi.search(query_vector, k=10)
```

Alternatively, the arxiv paper "Three Algorithms for Merging Hierarchical Navigable Small World Graphs" (2025) proposes Naive Graph Merge (NGM), Intra Graph Traversal Merge (IGTM), and Cross Graph Traversal Merge (CGTM) for direct HNSW merge without re-insertion. IGTM outperforms CGTM in the paper's evaluation. ([arXiv — Three Algorithms for Merging HNSW Graphs](https://arxiv.org/html/2505.16064v1)) Elasticsearch's HNSW merge work showed 30% merge time improvement using `SEARCH-LAYER` with low `ef_construction`. ([Elasticsearch Labs — HNSW Graphs Speed Up Merging](https://www.elastic.co/search-labs/blog/hnsw-graphs-speed-up-merging))

---

### 3.4 Copy-on-Write Patterns for Snapshots

During background rebuild, the main app must still serve search queries from the in-use index. The canonical pattern is:

1. **Build new index** into a temp file (`index_building.usearch`)
2. **Atomic rename** temp file to live path (`index.usearch`) via `rename(2)` syscall — POSIX atomic on HFS+/APFS
3. **Hot-swap** in-memory pointer: old `Index` object continues serving until its `deinit` (reference counted)

```swift
class IndexManager {
    private var currentIndex: Index     // read by search threads
    private let indexPath: URL
    
    func replaceIndex(with newIndex: Index) {
        // Atomic swap — ARC handles deallocation of old index
        // after all in-flight queries complete
        currentIndex = newIndex
    }
    
    func rebuildInBackground() async throws {
        let tempPath = indexPath.deletingLastPathComponent()
            .appendingPathComponent("index_building.usearch")
        let newIndex = try buildIndex(at: tempPath)
        try FileManager.default.replaceItemAt(indexPath, withItemAt: tempPath)
        replaceIndex(with: try Index.restore(indexPath))
    }
}
```

Weaviate's production HNSW implementation uses a commit log + periodic snapshot pattern: "Every time a node starts, the HNSW commit log is read and used to rebuild the index in memory... HNSW snapshots can significantly reduce startup times." The snapshot pattern enables fast startup without sacrificing durability of the commit log. ([Weaviate HNSW Snapshots](https://docs.weaviate.io/weaviate/configuration/hnsw-snapshots), [GitHub HNSW Snapshots Issue](https://github.com/weaviate/weaviate/issues/7189))

---

### 3.5 Handling Deleted/Modified Notes

**HNSW deletion is fundamentally a tombstone operation.** Unlike trees or hash tables, removing a node from an HNSW graph requires repairing the broken edges — potentially O(M × ef) work per deletion where M is connectivity and ef is the search expansion factor. Most production implementations use soft deletion (tombstones) and defer cleanup to compaction. ([Milvus — How do you handle incremental updates in a vector database?](https://milvus.io/ai-quick-reference/how-do-you-handle-incremental-updates-in-a-vector-database))

**Three approaches:**

| Approach | Pros | Cons |
|---|---|---|
| Tombstone (soft delete) | O(1) delete, no graph disruption | Degrades search quality as tombstone count grows; tombstoned nodes still traverse edges |
| In-place update (delete + re-insert) | Always consistent | O(ef) work per update; can create unbalanced graph structure over time |
| Periodic compaction (full rebuild) | Optimal graph structure | Requires rebuild downtime (mitigated by CoW above) |

**Recommended strategy:** Soft-delete immediately (maintain tombstone set in GRDB). Re-insert modified notes with new vectors immediately (old vector remains as soft-deleted, new vector is fresh add). Schedule full compaction nightly as the standard Night Brain rebuild step. This gives O(1) modification latency during the day and optimal index quality after each nightly run.

**Recall degradation over time:** Studies on production vector databases show that after 20% soft-deleted nodes, recall at @10 begins degrading measurably (1-3% drop). Nightly full compaction keeps the vault's deletion fraction near zero.

---

## Section 4: Orphan Knowledge Detection

### 4.1 Defining "Orphan Knowledge"

An orphan note is **not** one that has no links — it is one that is **semantically relevant to the user's current work** but has been **effectively forgotten**: low recent access, old modification date, and residing in a semantic cluster disconnected from the user's recent activity pattern.

This distinction is critical: a note about a topic the user genuinely finished with is *legitimately* dormant, not an orphan. An orphan has **latent value that the user would want to know about** if prompted. The detection problem is therefore a false-positive problem: surfacing too many legitimately-dormant notes creates noise; surfacing genuinely-orphaned notes creates value.

---

### 4.2 Component Signals

**Signal 1: Semantic Similarity to Active Context**

Compute the centroid embedding of the user's "active context" — all notes modified or accessed in the last N days (N=7 is a reasonable default). Then compute cosine similarity between each candidate orphan and this centroid:

```
sim_active(note) = cosine(embed(note), centroid(active_N_days))
```

Notes with `sim_active > threshold` (e.g., 0.65) but not in the active set are prime orphan candidates.

**Signal 2: Temporal Recency Decay**

Model access frequency as exponential decay. For a note last accessed at time τ_last with access count c:

```
recency_score(note) = exp(−λ × (now − τ_last) / days)
```

A reasonable decay constant λ = 0.1 gives half-life of ~7 days. Notes with `recency_score < 0.3` (not accessed in ~12 days) are candidates. Weight by `log(1 + c)` to deprioritize notes the user has genuinely stopped working with (high access but very old is different from low access always).

**Signal 3: Graph Betweenness Centrality**

In the note link graph (directed or undirected), betweenness centrality of a node k is:

BC(k) = (1 / ((N−1)(N−2))) × Σ_{i≠j,i≠k,j≠k} (sp_ij(k) / sp_ij)

where sp_ij is the number of shortest paths from i to j, and sp_ij(k) is the subset passing through k. ([Memgraph — Betweenness Centrality and Other Centrality Measures](https://memgraph.com/blog/betweenness-centrality-and-other-centrality-measures-network-analysis))

High-betweenness notes are "bridge concepts" — they connect otherwise separate clusters in the knowledge graph. A note with high betweenness that is *also* semantically relevant to current work but *not* recently accessed is the highest-value orphan candidate: it potentially bridges the user's current project to a forgotten body of prior work.

For large vaults (50K+ notes), exact betweenness is O(N²M) — expensive. Use approximate BC via Brandes' algorithm with sampling, or use the link graph's community structure to identify cross-cluster bridges cheaply.

**Signal 4: Semantic Neighborhood Clustering**

Apply HNSW-based clustering (Night Brain already has the index) to detect which notes are semantic neighbors of active-cluster centroids but not yet linked. These are "almost connected" orphans — the user's knowledge graph has not yet recognized the relationship.

Use HNSW approximate nearest neighbor search: for each note in the active cluster, find its k=20 nearest neighbors in embedding space, then subtract the already-linked notes. Remaining candidates are unlinked semantic neighbors.

**Signal 5: Information Foraging Theory — Patch Depletion**

Peter Pirolli and Stuart Card's Information Foraging Theory models humans as rational foragers maximizing "information scent" (value per time cost). The Marginal Value Theorem applies: a user leaves a topic "patch" when the local gain rate falls below the global average. ([Peter Pirolli — Information Foraging Theory](https://www.peterpirolli.com/ewExternalFiles/31354_C01_UNCORRECTED_PROOF.pdf))

For Night Brain: a note cluster the user heavily accessed 6 months ago and then abandoned represents a depleted patch. But if current work triggers semantic similarity to that cluster, the patch may have been abandoned prematurely. The orphan detection algorithm should flag notes in "depleted patches" that have re-emerged as informationally relevant.

---

### 4.3 The "Hidden Gem" Problem

The hidden gem problem is: a note written in context X (e.g., reading a paper about ML optimization in 2022) is now deeply relevant to context Y (e.g., implementing a gradient descent optimizer in 2024), but the user has never connected them because they were in different mental contexts at creation time.

This is not solvable by link-following (links require conscious recognition of relationships) — only by **semantic similarity search across time**. The HNSW index is precisely the tool for this. The Night Brain's nightly sweep can compute:

```
for each note in vault:
    neighbors = hnsw.search(embed(note), k=10, exclude_recent=true)
    for n in neighbors:
        if n.last_accessed > 14 days AND sim(note, n) > 0.75:
            candidate_orphan = n  // semantically close to note but dormant
```

---

### 4.4 Practical Scoring Formula

Combining signals into a ranked list of orphan candidates:

```
orphan_score(note) = w₁ × sim_active(note)          // relevance to current work
                   + w₂ × (1 − recency_score(note))   // forgotten-ness
                   + w₃ × betweenness_centrality(note) // bridge value
                   + w₄ × unlinked_neighbor_score(note)// semantic proximity to active cluster
```

Reasonable starting weights: w₁=0.40, w₂=0.25, w₃=0.20, w₄=0.15. These can be learned from explicit user feedback (when the user acts on a surfaced note, reinforce those weights; when dismissed repeatedly, decay the contributing signal).

**Hard filters before scoring:**
- Modified today: exclude (user knows about it)
- Last accessed within 3 days: exclude (too fresh)
- Zero content (stub note): exclude

Surface top-K (K=5–10) orphan candidates in the morning digest. More than 10 creates cognitive overload.

---

## Section 5: Comparable Systems

### 5.1 Apple Photos — Background ML Processing

Apple Photos runs person clustering "periodically, typically overnight during device charging" using an agglomerative HAC algorithm. The system:

1. Generates face + upper-body embeddings via ANE (< 4ms per image on recent hardware — 8x faster than GPU equivalent)
2. Runs incremental cluster updates: "novel agglomerative clustering algorithm that enables an efficient incremental update of existing clusters and can scale to large libraries"
3. Builds a "private, on-device knowledge graph that identifies interesting patterns in a user's library"
4. Powers the Memories feature — essentially a nightly-computed cognitive digest of the photo library

([Apple ML Research — Recognizing People in Photos Through Private On-Device Machine Learning](https://machinelearning.apple.com/research/recognizing-people-photos))

**Key design decisions applicable to Night Brain:**
- **ANE first, GPU second, CPU third** for embedding generation — ANE is dramatically more energy-efficient for inference
- **Overnight + charging** as the canonical scheduling trigger — matches Night Brain's target conditions
- **Incremental HAC** (not full rebuild each night) — the clustering algorithm updates existing cluster assignments rather than recomputing from scratch
- **Privacy as architecture constraint** — all work on-device, no data to cloud

Apple's on-device ML work explicitly addresses the core Night Brain challenge: "users don't want the battery to drain or the performance of the system to slow to a crawl... background computer vision processing shouldn't significantly impact the rest of the system's features." ([Apple ML Research — On-Device Face Detection](https://machinelearning.apple.com/research/face-detection))

---

### 5.2 Spotlight's Incremental Indexing Architecture

Spotlight's architecture is the canonical macOS incremental background indexing reference:

- **FSEvents subsystem** records every file modification to a persistent, kernel-level journal (`/.fseventsd`)
- When a file change is recorded, `mds` (metadata server) receives an XPC call and dispatches `mdworker` processes to index the changed file
- `mdworker` extracts content using the file's UTI (Uniform Type Identifier), adds metadata to per-volume indexes in `.Spotlight-V100`
- `mds_stores` handles the index compaction and compression passes
- CPU and I/O are throttled via DAS (the same system under `NSBackgroundActivityScheduler`) — mdworker runs at QoS `.background`

([Eclectic Light Company — Spotlight Problems: mds_stores and mdworker in Trouble](https://eclecticlight.co/2022/12/08/spotlight-problems-mds_stores-and-mdworker-in-trouble/))

**Night Brain equivalents:**

| Spotlight | Night Brain |
|---|---|
| FSEvents | GRDB `notes` table modified_at trigger / file watcher |
| mdworker | NightBrainWorker XPC service |
| .Spotlight-V100 | usearch index file + GRDB vector table |
| mds_stores | Nightly compaction job |
| UTI-based content extraction | Note parser (Markdown → plain text → embeddings) |

**Critical lesson from Spotlight:** The XPC isolation between `mds` and `mdworker` means a malformed file that crashes the indexer plugin does not crash the Spotlight metadata server. Night Brain must apply the same isolation: the embedding generator and HNSW inserter should run in the XPC service, with the main app only receiving structured results.

---

### 5.3 Time Machine's Snapshot and Delta Architecture

Time Machine on APFS creates APFS snapshots (point-in-time, copy-on-write) before each backup:

1. **APFS snapshot created** on source volume (near-instantaneous, COW)
2. **FSEvents log consulted** to identify files changed since last backup
3. **Delta transferred** to backup volume (only changed data blocks)
4. **Source snapshot** retained for up to 24 hours for fast local restore
5. **Hourly snapshots** created even when backup volume is unavailable

([Eclectic Light Company — Time Machine to APFS: Understanding Backups](https://eclecticlight.co/2021/03/11/time-machine-to-apfs-understanding-backups/))

**Night Brain analog:** Before each nightly run, GRDB can record a "vault snapshot" — a record of all note IDs, hashes, and modification timestamps at the start of the run. On morning completion, the delta (added/modified/deleted notes) is logged. This provides both a correctness audit trail and the data for "what changed last night" in the user-facing digest.

---

### 5.4 macOS Core Data CloudKit Sync

`NSPersistentCloudKitContainer` uses a background processing pattern worth examining:
- Sync events fire when the app is in the background, driven by `NSPersistentCloudKitContainer.eventChangedNotification`
- The system throttles sync aggressively on iOS (7-day learning period for app usage patterns)
- On macOS, background refresh is more permissive but still subject to DAS scheduling

([TN3163 — Understanding the Synchronization of NSPersistentCloudKitContainer](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer))

The most useful pattern is **event-driven rather than timer-driven**: the sync fires in response to data events (CloudKit notifications), not on a fixed schedule. Night Brain should similarly be event-responsive — if the user adds 50 notes just before bed, the Night Brain should incorporate them even if the pipeline has already started.

---

### 5.5 DEVONthink's "See Also" Analysis

DEVONthink's See Also feature uses an **internal AI** (not vector embeddings or RAG):
- Driven by a form of Latent Semantic Analysis (LSA/LSI): Singular Value Decomposition over a term-document matrix
- **Does not use embeddings or a vector database** — the developer explicitly notes this and observes that "without a vector database [DT4's approach] is considerably more accurate for querying a specific PDF or set of PDFs"
- Adding vector store indexing has "disadvantages: increased disk space usage and slower indexing (a lot slower)"
- Analysis runs incrementally as documents are added; no explicit nightly batch mode documented
- For language-specific corpora, LSI produces language-separated clusters (German with German, English with English) — a known limitation vs. multilingual embeddings

([DEVONtechnologies Community — DT4 Inner Workings of Indexing](https://discourse.devontechnologies.com/t/dt4-inner-workings-of-indexing-see-also-similar-documents-thought-about-using-vectorization/82596))

**Night Brain advantage over DEVONthink:** Modern transformer-based embeddings (text-embedding-3-small, nomic-embed-text) are multilingual, contextual, and substantially more semantically expressive than LSI. The Night Brain's choice of transformer embeddings + HNSW is qualitatively superior to DEVONthink's classical IR approach for semantic clustering and orphan detection.

**DEVONthink's reliability lesson:** Background AI jobs in DEVONthink 4 hang indefinitely on edge-case documents ("these jobs are hanging... the last two hours... Stopping and Starting DEVONthink is the only solution"). ([DEVONtechnologies Community — Background Jobs Hanging](https://discourse.devontechnologies.com/t/background-jobs-hanging-for-ever/85497)) Night Brain must implement timeout-per-document (e.g., 10 seconds to embed one note) and watchdog logic in the XPC worker.

---

### 5.6 Obsidian/Logseq Background Indexing

Obsidian's graph computation runs on the main thread in JavaScript (Electron), using a `--watch` flag for file system monitoring. The Obsidian Index MCP Server (community tool) implements:
- **Nightly full re-index** of the vault via `--reindex` flag
- **`--watch` for continuous updates** during the day
- Vector embeddings stored as JSON (not a binary index format)
- Semantic search via matrix multiplication over the embeddings JSON

([Skywork.ai — A Deep Dive into the Obsidian Index MCP Server](https://skywork.ai/skypage/en/unlocking-second-brain-obsidian-index/1977912100451192832))

**Night Brain advantages:** Native macOS + Metal GPU acceleration vs. JavaScript Matrix multiplication; usearch binary format vs. JSON; proper background scheduling via NSBackgroundActivityScheduler vs. always-on file watcher; XPC isolation vs. main-thread blocking.

---

## Section 6: Critical UX Pitfalls

### 6.1 The "Morning Surprise" Problem

The user wakes up to a cognitive digest that is confusing, irrelevant, or anxiety-inducing. Common failure modes:

1. **Out-of-context surfacing**: A note from 3 years ago surfaces with no explanation of *why* it's relevant today → user is confused and the digest feels random
2. **Misleading relevance scores**: A note about "Python async" surfaces because it has high cosine similarity to today's "neural network training" notes, but the connection is superficial (shared tokens) rather than conceptual
3. **Wrong "active project" detection**: Night Brain infers the active project from recent notes, but the user was actually doing shallow research, not deep work → digest is calibrated to the wrong context

**Mitigation:**
- Always show *why* each note was surfaced: "High semantic similarity to [Project X notes from this week]" not just the note title
- Show the bridge: what is the detected connection between the surfaced note and current work?
- Allow the user to explicitly set active projects via a simple UI — don't rely entirely on inference

---

### 6.2 Battery Drain and Thermal Discomfort

Even while plugged in, a sustained nightly pipeline running on Apple Silicon at full CPU utilization will push the laptop to uncomfortable temperatures. The fan (on MacBook Pros with fans) spinning at 4,500 RPM at 2 AM is a user-experience problem even if the owner is asleep.

**Thermal budget:** Tests show `ProcessInfo.thermalState` conflates "moderate" and "heavy" throttling under `.fair`. The `thermald` notification channel provides 5-level granularity. ([Stanislas Blog — Building a macOS App to Know When My Mac Is Thermal Throttling](https://stanislas.blog/2025/12/macos-thermal-throttling-app/))

**Mitigation:**
- Hard cap: never run Night Brain above thermal pressure level 1 (moderate)
- Introduce deliberate `Task.sleep` pauses between work batches (e.g., 2 seconds after every 1,000 HNSW insertions)
- Prioritize phases: GRDB reads → Metal embedding generation → HNSW insertions → orphan scoring. Sequencing prevents thermal accumulation from overlapping workloads
- Set `qualityOfService = .background` throughout — this activates energy efficiency mode on Apple Silicon's efficiency cores

---

### 6.3 Processing Overruns

The pipeline doesn't finish before the user needs the laptop. Scenarios:
- User wakes at 6 AM; pipeline started at 3 AM but vault has 200K notes → still running
- Thermal throttling extended a normally 10-minute run to 45 minutes
- HNSW rebuild encountered a corrupt vector → hung

**Mitigation:**
1. **Hard timeout**: The pipeline must complete in ≤ 4 hours. Design in a budget: allocate time per phase (30% re-index, 20% orphan detection, 20% digest assembly, 30% buffer)
2. **Checkpoint and resume**: GRDB tracks pipeline state (`last_processed_note_id`, `phase_completed`). If the system wakes the user before completion, Night Brain stops gracefully and serves a partial digest
3. **Watchdog timer**: A GCD timer that fires after 4 hours and calls `completion(.deferred)` regardless of state
4. **Partial digest**: "Tonight's processing is 67% complete. Here are results so far. Full digest available tomorrow."

---

### 6.4 Stale Digests

If the user doesn't read today's digest, it accumulates. After a week of unread digests, the user opens the app to a wall of backlogs. Two failure modes: anxiety (too much undone) and habituation (user learns to ignore the digest).

**Mitigation:**
- **Expiry model**: A digest expires 36 hours after generation. Expired digests are archived, not presented as pending action items
- **Carry-forward**: If a surfaced note was truly important, its orphan score will remain high and it will appear in future digests — the system does not need to nag
- **Single daily digest**: Never accumulate; each morning's digest replaces the previous. The past is accessible in digest history but not in the active UI
- **Staleness indicator**: "This digest is from 2 days ago. Generate a fresh one?" — give the user explicit control

---

### 6.5 The "Assistant Cleaned My Desk" Problem

Autonomous reorganization that confuses the user's mental model. Examples:
- Night Brain renames a note cluster silently
- Orphan detection "archives" notes that the user considers active
- Cognitive digest reorganizes the note hierarchy based on semantic clustering

This is the most trust-destroying failure mode. Users have strong spatial memory for where things are; even beneficial reorganization, if not anticipated and reversible, creates anxiety and loss of trust. ([Frontiers in Psychology — Intentional Forgetting in Organizations](https://pmc.ncbi.nlm.nih.gov/articles/PMC5799275/))

**Hard rule:** Night Brain is **read-only** on the vault. It never moves, renames, deletes, or modifies notes without explicit user confirmation. The digest is a *recommendation* surface, not an action surface. Any action the digest suggests (e.g., "Link these two notes?") is a user-initiated one-click confirmation.

---

### 6.6 Trust: Transparency of Overnight Actions

The user must understand what Night Brain did overnight. Without transparency, the system feels like a black box — and when something looks wrong (a surprising recommendation, a missing note), the user has no way to audit or correct it.

**Transparency requirements:**

1. **Action log**: Night Brain writes a structured log of every action (notes scanned, embeddings updated, orphans scored, digest generated) to a human-readable GRDB table. The user can inspect this in a "Last night's activity" view.

2. **Score explanations**: Every digest item includes its scoring breakdown: "Similarity to active projects: 0.71 / Recency decay: 0.18 / Bridge centrality: 0.43"

3. **Confidence indicators**: "I found 3 strong connections and 7 speculative ones. Showing the top 5."

4. **Immutability**: Explicitly state in the UI that "Night Brain never modifies your notes. It only reads your vault."

5. **Opt-out per note**: Users can mark notes as "do not surface in digest" — this trains the orphan score model and respects the user's sense of what is private or intentionally dormant.

Research on user trust in AI systems consistently shows that transparency and reversibility are the two strongest predictors of continued trust — more than accuracy. A system that explains itself and never makes irreversible changes will be tolerated even when it makes mistakes. ([Standard Beagle — 13 Proven Error Fixes for Improving User Trust Through UX Design](https://standardbeagle.com/improving-user-trust-through-ux-design/))

---

## Architectural Summary

The following table maps each Night Brain capability to its primary technology and key risk:

| Pipeline Phase | Technology | Key Risk | Mitigation |
|---|---|---|---|
| Trigger detection | `NSBackgroundActivityScheduler` + LaunchAgent | Missed fire if app not running | LaunchAgent as safety net |
| Power/idle gate | `IOPowerSources` + `CGEventSource` | False positive (user returned) | Recheck every 60s during run |
| Sleep prevention | `IOPMAssertionCreateWithName` | Forgotten release on crash | XPC isolates crashes; assertion auto-releases on process exit |
| Thermal management | `thermald` notifyd + levelcheck | Thermal overrun | Hard backoff at level 2; pause at level 3 |
| App Nap prevention | `ProcessInfo.beginActivity` | Token deallocation | Store strongly on long-lived object |
| Process isolation | XPC service | Crash propagation | XPC crash does not affect main app |
| Note parsing | Markdown → plain text | Encoding edge cases | Per-document timeout (10s) |
| Embedding generation | Metal compute shaders | GPU thermal pressure | Sequential phases, not concurrent |
| HNSW re-indexing | usearch (Swift/Rust) | Rebuild overrun | Checkpoint every N insertions; full rebuild if delta < 5K |
| Deletion handling | Soft tombstone in GRDB | Recall degradation | Nightly compaction (full rebuild from GRDB) |
| Index swap | Atomic rename + CoW | Read-during-write races | ARC reference counting ensures old index lives until last reader drops ref |
| Orphan detection | HNSW ANN + graph centrality | False positives | Multi-signal scoring + confidence threshold |
| Digest assembly | GRDB + struct serialization | Stale content | 36h expiry; replace not accumulate |
| Digest delivery | Native SwiftUI notification | Ignored digest | Single daily digest; non-intrusive entry point |
| User trust | Transparent log + read-only | "Cleaned my desk" failure | Hard rule: Night Brain never writes to vault |

---

*Sources: All citations are inline throughout the document. Primary sources: Apple Developer Documentation, Apple Machine Learning Research, arXiv academic papers, Eclectic Light Company macOS technical writing, Weaviate/usearch/Milvus vector database documentation, PLoS ONE / Frontiers in Psychology / ACM academic papers, Andy Matuschak & Michael Nielsen "How can we develop transformative tools for thought?" (2019), Peter Pirolli "Information Foraging Theory" (Oxford University Press, 2007).*
