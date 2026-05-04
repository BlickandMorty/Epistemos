# Capability 2: Ambient Cross-App Knowledge Capture
## Research Reference Document

**System context:** Native macOS personal knowledge system (Swift + Rust + Metal) with AXUIElement access via Rust FFI and ScreenCaptureKit integration. This document covers the technical, historical, and UX dimensions needed to implement passive ambient knowledge capture from third-party applications.

---

## Table of Contents

1. [macOS Accessibility API Surface](#section-1)
2. [Privacy and Consent Architecture](#section-2)
3. [Polling vs Event-Driven AX Observation](#section-3)
4. [On-Device OCR for AX-Sparse Apps](#section-4)
5. [Lifelogging Research Heritage](#section-5)
6. [Critical UX Pitfalls](#section-6)

---

<a name="section-1"></a>
## Section 1: macOS Accessibility API Surface

### 1.1 The Core AXUIElement Pattern for Cross-App Text Reading

The macOS Accessibility framework (part of ApplicationServices / HIServices) exposes a C-level opaque reference type, `AXUIElementRef`, that represents any UI object in any running application. The canonical pipeline for reading selected text from a third-party app is a two-step attribute copy:

```c
// Step 1: Get the system-wide focused element
AXUIElementRef systemWide = AXUIElementCreateSystemWide();
AXUIElementRef focusedEl  = NULL;
AXError err = AXUIElementCopyAttributeValue(
    systemWide,
    kAXFocusedUIElementAttribute,   // "AXFocusedUIElement"
    (CFTypeRef *)&focusedEl
);

// Step 2: Read selected text from that element
AXValueRef selectedText = NULL;
AXUIElementCopyAttributeValue(
    focusedEl,
    kAXSelectedTextAttribute,       // "AXSelectedText"
    (CFTypeRef *)&selectedText
);
```

**Known pitfall with `AXUIElementCreateSystemWide()`:** In practice, developers have found that using the system-wide element to retrieve the focused element sometimes returns `cannotComplete` (AXError -25212) from command-line tools and certain non-GUI contexts. The more reliable pattern is to bind to the frontmost application's PID directly ([Stack Overflow](https://stackoverflow.com/questions/77628629/is-it-possible-to-use-macos-accessibility-api-features-from-a-cli-or-library)):

```swift
guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
// then traverse from appRef to find focused element
```

---

### 1.2 Key Attributes

#### `kAXFocusedUIElementAttribute`
- **What it returns:** The `AXUIElementRef` of the UI element currently holding keyboard focus within the frontmost application. This is the root of the useful AX subtree for text capture.
- **What apps expose it:** All standard AppKit/UIKit/Catalyst applications expose this. Web browsers expose it for the frontmost tab's focused element. Some apps with custom event routing may return a top-level window element rather than the specific focused text field.
- **Type:** `AXUIElement` (opaque CFTypeRef)
- **Availability:** macOS 10.2+

#### `kAXSelectedTextAttribute`
- **Apple documentation:** "The currently selected text within this accessibility object. This attribute is required for all accessibility objects that represent editable text elements." ([Apple Developer](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute))
- **What it returns:** A `CFStringRef` containing the currently selected (highlighted) text. Returns empty string or error if nothing is selected.
- **Coverage:** Works reliably in: TextEdit, Notes, Mail, Xcode, most AppKit text views, Safari (for text field content), most native macOS text input contexts. Does NOT work for: non-selectable rendered text in browsers (body text you highlight visually uses a different path), some custom rendering frameworks.
- **Companion attribute:** `kAXSelectedTextRangeAttribute` returns a `CFRange` (as `AXValue`) with `location` and `length` of the selection, enabling precise source tracking.
- **Bounds attribute:** `kAXBoundsForRangeParameterizedAttribute` returns a `CGRect` from a range value — useful for displaying UI overlays near the selection.

#### `kAXValueAttribute`
- **What it returns:** The current string content of a text field or text area (not just selected portion — the full value).
- **Use case:** Reading the entire text of a focused field, regardless of selection state. Most useful for short text fields (URL bars, search boxes, form fields). For large documents, prefer selection-based capture.
- **Coverage:** Required for all editable text elements per Apple's accessibility specification.

#### `kAXRoleAttribute` / `kAXSubroleAttribute`
- **Use case:** Inspecting what kind of element you're dealing with before attempting text reads. Key roles for knowledge capture:
  - `AXTextField` — single-line input
  - `AXTextArea` — multi-line editable text
  - `AXStaticText` — non-editable label/body text
  - `AXWebArea` — web content area in browsers
  - `AXDocument` — document container in word processors

---

### 1.3 AXObserver: Event-Driven Observation

`AXObserver` is the preferred mechanism for non-polling notification of accessibility events. The API:

```c
// Create observer for a target PID
AXObserverRef observer = NULL;
AXObserverCreate(targetPID, axCallbackFn, &observer);

// Register for specific notifications on a specific element
AXObserverAddNotification(observer, element, notification, userData);

// Add observer's run loop source to your run loop
CFRunLoopAddSource(
    CFRunLoopGetCurrent(),
    AXObserverGetRunLoopSource(observer),
    kCFRunLoopDefaultMode
);
```

The callback signature:
```c
void axCallbackFn(
    AXObserverRef observer,
    AXUIElementRef element,
    CFStringRef notification,
    void *userData
)
```

**Important implementation note from Apple (confirmed by direct engineer contact):** AXUIElement functions must be called on the application's **main thread**. Background thread calls produce undefined behavior ([Stack Overflow](https://stackoverflow.com/questions/64435187/can-the-functions-in-axuielement-h-be-safely-called-from-threads-other-than-the)). This has architectural implications: your Rust FFI calls to AX APIs must be dispatched to the main thread.

---

### 1.4 Key Notification Constants

These are the notification names for `AXObserverAddNotification`:

| Notification | When Fired | Capture Strategy |
|---|---|---|
| `kAXFocusedUIElementChangedNotification` | User tabs between fields or clicks into new element | Re-read `kAXSelectedTextAttribute` on the new focused element |
| `kAXSelectedTextChangedNotification` | User changes text selection (highlight) | Read `kAXSelectedTextAttribute` immediately |
| `kAXValueChangedNotification` | Content of a text element changes (typing) | Debounce and read `kAXValueAttribute`; high-frequency during typing |
| `kAXFocusedWindowChangedNotification` | Active window changes | Update which app/window is being monitored |
| `kAXWindowCreatedNotification` | New window opens | Potentially add observer to new window |
| `kAXApplicationActivatedNotification` | App comes to foreground | Re-establish observer set for the new app |
| `kAXUIElementDestroyedNotification` | Element destroyed | Remove observers to avoid dangling refs |

**Note on `kAXValueChangedNotification` for typing:** This fires on every keystroke for text fields. For knowledge capture (not transcription), debounce this with a ~2 second idle timer: only capture when typing stops. Otherwise you generate enormous noise from partial words and deletions.

**AXObserverCreateWithInfoCallback (macOS 10.9+):** The alternative constructor provides richer per-notification dictionaries including the notification's `userInfo`, useful for accessibility announcements. Not required for basic text capture.

---

### 1.5 Full Header Location

The canonical authoritative source for all AX constants (more complete than Apple's web documentation) is the C header at ([Reddit discussion on AX headers](https://www.reddit.com/r/swift/comments/18k909w/i_hit_a_dead_end_with_accessibility_apis/)):

```
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/
Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/ApplicationServices.framework/
Versions/A/Frameworks/HIServices.framework/Versions/A/Headers/
```

Key files: `AXUIElement.h`, `AXAttributeConstants.h`, `AXNotificationConstants.h`, `AXValueConstants.h`, `AXActionConstants.h`.

---

### 1.6 App-by-App AX Tree Coverage

Based on empirical data from the [Screen2AX paper (MacPaw/arxiv, July 2025)](https://arxiv.org/html/2507.16704v1), which analyzed 99 popular and 452 randomly selected macOS apps:

| Population | Full AX Metadata | Partial | Absent |
|---|---|---|---|
| Top-99 popular free apps | **36.4%** | 45.9% | **17.7%** |
| Random 452 Mac App Store/Brew apps | 29.4% | 37.8% | **32.7%** |

"Full" means all on-screen elements present in the tree with correct bounding boxes. "Absent" means only the three window chrome buttons (close/minimize/maximize) or nothing at all.

**Practical breakdown by app type:**

| App Category | AX Coverage Quality | Notes |
|---|---|---|
| **Safari** | Good for web page content | WebKit exposes `AXWebArea` subtree; `kAXSelectedTextAttribute` works in most fields |
| **Chrome / Chromium** | Requires `AXManualAccessibility` enable | See Electron workaround below |
| **Firefox** | Good | Accessible by default; full AX tree available in DevTools |
| **Preview (PDF)** | Partial | Selected text via `kAXSelectedTextAttribute` works for text-based PDFs; scanned PDFs return nothing (OCR required) |
| **Xcode** | Excellent | Full AppKit compliance; source editor exposes full tree |
| **TextEdit / Notes / Mail** | Excellent | All text attributes available |
| **VS Code (Electron)** | Requires `AXManualAccessibility` | See below |
| **Slack (Electron)** | Requires `AXManualAccessibility` | Top-level element tree sparse by default |
| **Discord (Electron)** | Requires `AXManualAccessibility` | Same pattern |
| **Figma** | Sparse/Absent | Canvas uses custom WebGL/Metal rendering; AX tree has minimal real content |
| **Games (Unity/Unreal)** | Absent | Metal/OpenGL rendering; no AX integration |
| **Java Swing apps** | Problematic | `CAccessibility` bridge; can freeze on large trees ([GitHub/corretto](https://github.com/corretto/corretto-17/issues/132)) |
| **Photoshop** | Absent/Custom | Highly custom UI; Screen2AX reports detection failures |

**The Electron workaround:** Electron-based apps (VS Code, Slack, Discord, Notion desktop) disable AX by default for performance. They can be unlocked by an external process setting `AXManualAccessibility` to `true` on the app's root element ([Electron docs](https://electronjs.org/docs/latest/tutorial/accessibility)):

```swift
let axApp = AXUIElementCreateApplication(electronAppPID)
AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, true as CFTypeRef)
```

This enables Chrome's underlying accessibility tree. Note: this is an undocumented/semi-public protocol; it has been broken in some Electron versions ([GitHub issue](https://github.com/electron/electron/issues/37465)).

---

### 1.7 Rust FFI Patterns for AXUIElement

#### Available Crates

| Crate | Version | Description | Completeness |
|---|---|---|---|
| [`accessibility-sys`](https://crates.io/crates/accessibility-sys) | 0.2.0 (Mar 2025) | Raw C FFI bindings for macOS Accessibility | Complete — all attribute/notification/role constants and `AXUIElementRef` functions |
| [`accessibility`](https://crates.io/crates/accessibility) | 0.2.0 | Higher-level safe Rust wrappers built on `accessibility-sys` | "Pretty spotty" — incomplete safe wrappers |
| [`accesskit_macos`](https://crates.io/crates/accesskit_macos) | Active 2026 | macOS adapter for AccessKit — for implementing AX support, NOT consuming it | Not applicable for reading third-party app AX |
| [`macos-accessibility-client`](https://crates.io/crates/macos-accessibility-client) | Active 2026 | Currently only checks `AXIsProcessTrusted()` | Minimal utility for this use case |

The [eiz/accessibility GitHub repo](https://github.com/eiz/accessibility) provides the most usable starting point. `accessibility-sys` is described as complete for the raw C API surface; the high-level `accessibility` crate has sparse safe wrappers.

#### FFI Architecture Recommendation

For a Swift + Rust + Metal system, the cleanest approach is a hybrid:

```
Swift (main thread, AXObserver run loop) 
  → Receives AX notifications
  → Calls into Rust via FFI with extracted text/metadata
  → Rust processes/embeds/stores the knowledge
```

Because AX APIs must run on the main thread, calling into them from Rust creates ordering constraints. The safer pattern is to do all AX interactions from Swift (which naturally runs on the main thread via its RunLoop) and use Rust for the heavy downstream processing (embedding, storage, search indexing).

If direct Rust AX calls are required (e.g., for the observer callback logic), use `dispatch_async` to the main queue from within the Rust FFI code via `objc2` bindings.

**objc2 status:** The `objc2` crate and its ecosystem do not yet support `ApplicationServices` (which contains the AX types) directly. As of 2024, developers have confirmed this gap ([Reddit/r/rust](https://www.reddit.com/r/rust/comments/1do68tl/what_knowledge_and_rust_libraries_do_i_need_to/)). The `accessibility-sys` crate is the workaround — it provides direct C-style bindings without going through `objc2`.

#### Typical Rust Binding Usage

```rust
use accessibility_sys::*;

unsafe {
    let system_wide = AXUIElementCreateSystemWide();
    let mut focused: AXUIElementRef = std::ptr::null_mut();
    let err = AXUIElementCopyAttributeValue(
        system_wide,
        kAXFocusedUIElementAttribute as *const _,
        &mut (focused as _),
    );
    if err == kAXErrorSuccess {
        let mut selected_text: CFTypeRef = std::ptr::null_mut();
        AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as *const _,
            &mut selected_text,
        );
        // cast selected_text to CFStringRef and read
    }
}
```

---

### 1.8 Sandboxing Limitations

The macOS App Sandbox imposes critical constraints:

1. **Your app cannot be sandboxed if it needs full Accessibility access** for cross-app text reading. Sandboxed apps can request the `com.apple.security.temporary-exception.accessibility` entitlement, but this is poorly supported and frequently fails in practice ([Stack Overflow](https://stackoverflow.com/questions/36375434/appsandboxing-accessibility-axuielement)). The consensus: ambient capture apps must be non-sandboxed or distributed outside the Mac App Store.

2. **Mac App Store distribution:** Requires sandboxing, which blocks Accessibility permissions for cross-process UI reading. Ambient capture apps (Rewind.ai, Granola, etc.) distribute outside the App Store for this reason.

3. **Third-party app sandbox:** The app being monitored does not need to be non-sandboxed. AX works cross-process: your (trusted, non-sandboxed) app reads AX data from any running app including sandboxed ones.

4. **Fullscreen apps:** AX observation continues to work for fullscreen apps, but some AX attributes return different values or respond slower when the app is in a fullscreen space. The `AXObserver` callbacks still fire.

5. **TCC requirement:** Accessibility permission (under Privacy & Security → Accessibility) must be granted to your app. Without it, `AXIsProcessTrusted()` returns false and all attribute reads return `kAXErrorAPIDisabled`. This permission cannot be granted programmatically — it requires user action in System Settings or via MDM PPPC profiles.

---

<a name="section-2"></a>
## Section 2: Privacy and Consent Architecture

### 2.1 Rewind.ai: The Reference Privacy Architecture

Rewind.ai (now partially rebranded as Limitless) established the foundational privacy model for macOS ambient capture. From a [technical teardown by Kevin Chen (Dec 2022)](https://kevinchen.co/blog/rewind-ai-app-teardown/), the full architecture:

**Data pipeline:**
1. Use Accessibility APIs to identify frontmost window and capture metadata (app name, window title, timestamps) → stored in SQLite
2. Screenshot every 2 seconds via ScreenCaptureKit, targeting only the focused screen
3. On-device OCR using Apple's Vision framework (same pipeline as Live Text)
4. Compress screenshot sequences to H.264 video at 0.5 fps with FFmpeg
5. All stored in `~/Library/Application Support/com.memoryvault.MemoryVault/`
6. FTS4 full-text search index in SQLite with Porter stemming

**Privacy architecture decisions:**

| Decision | Implementation | Why It Worked |
|---|---|---|
| **Local-only storage** | All data in `~/Library/Application Support/` — no cloud | Addresses primary trust barrier: "who has my data" |
| **Private window exclusion** | ScreenCaptureKit filters exclude Safari/Chrome/Firefox private windows by default | Demonstrates respect for explicit user privacy signals |
| **Per-app exclusion list** | User-defined list; ScreenCaptureKit filters exclude these windows at the compositor level | Granular control; password managers should be excluded by default |
| **Soft-deletion** | Delete SQLite metadata; underlying video re-encoded on full deletion | Handles "I want to forget that" requests |
| **Meeting-specific audio** | Zoom transcription requires explicit enable per-meeting; microphone optional | Consent scoped to the highest-stakes data type |

**Noted vulnerability ([Chen teardown](https://kevinchen.co/blog/rewind-ai-app-teardown/)):** Data not encrypted at rest. Any process with Full Disk Access, or an attacker with physical access to an unlocked Mac, can read the entire capture history including soft-deleted clips. The recommendation: encrypt the SQLite database and video chunks using a key stored in the macOS Keychain, requiring biometric authentication to unlock (similar to what Microsoft belatedly added to Recall).

**The `segment` table** (which stores focused app changes) uses Accessibility API data — timestamps, window titles, and browser URLs — confirming that Rewind combines AX metadata with OCR'd screenshots rather than relying on either alone.

---

### 2.2 Microsoft Recall: What Went Wrong and What It Teaches

Microsoft Recall was announced in May 2024 as a Copilot+ PC feature that silently took a screenshot every 3–5 seconds, stored them locally with an OCR'd text database, and exposed a semantic timeline search interface.

**What went wrong ([WIRED, June 2024](https://www.wired.com/story/microsoft-recall-off-default-security-concerns/)):**

1. **Opt-out rather than opt-in:** Recall was enabled by default on all new Copilot+ PCs. Users had to actively disable it. The psychological framing of "already watching you" created immediate backlash.

2. **Unencrypted local database:** The SQLite database containing all OCR'd text (including passwords, bank details, private messages) was stored unencrypted. Security researcher Kevin Beaumont and others demonstrated that any malware with user-level access — no privilege escalation required — could exfiltrate the entire database in seconds, effectively becoming "spyware installed by Microsoft."

3. **No authentication to view captured data:** In preview builds, the timeline and search were accessible to any user logged into the PC without re-authentication.

4. **"Unrequested preinstalled spyware" framing:** Because it was opt-out and captured everything visible (including incognito browsing that users had explicitly taken steps to make private), security researchers described it as a "gift to hackers" and a "panopticon."

5. **Sensitive content not filtered by default:** Bank logins, health information, private messages — all captured indiscriminately.

**How Microsoft redesigned it ([VentureBeat](https://venturebeat.com/ai/microsofts-recall-feature-will-now-be-opt-in-and-double-encrypted-after-privacy-outcry), [The Hacker News](https://thehackernews.com/2024/06/microsoft-revamps-controversial-ai.html)):**

| Change | Original | Redesigned |
|---|---|---|
| Default state | **Opt-out (enabled)** | **Opt-in (disabled)** |
| Database encryption | Unencrypted SQLite | Encrypted; decrypted only on user auth |
| Authentication to view timeline | None | Windows Hello biometric required |
| Authentication to enable | None | Windows Hello biometric enrollment required |
| Presence detection | Not required | "Proof of presence" to view data |
| Sensitive content | Captured | Filtering improved (still imperfect) |

**Lessons for your system:**

1. **Default to off.** Ambient capture must be explicitly enabled, with a ceremony (not just a checkbox) that communicates what will be captured.
2. **Encrypt the knowledge store.** Use the macOS Keychain to store the encryption key; tie decryption to Touch ID / device password authentication.
3. **Private browsing is a hard signal.** If users explicitly entered a private browsing context, they have communicated their intent. Respect it at the system level using ScreenCaptureKit's filtering.
4. **Make the capture state visible at all times.** A persistent, unobscured status indicator when capture is active — not buried in a menu bar icon.
5. **Sensitive content heuristics.** At minimum, exclude: password manager app windows, banking URLs (Mint, Chase, etc.), medical records apps, incognito/private windows.

---

### 2.3 Granola: Context-Scoped Capture as a Privacy Strategy

[Granola](https://docs.granola.ai/help-center/consent-security-privacy/getting-consent) takes a fundamentally different approach from total-capture systems: it scopes capture exclusively to meeting contexts. This scope reduction has a significant privacy-anxiety-reduction effect:

- Users understand what's being captured (meeting audio + transcript) vs. a vague "everything"
- Third-party consent (meeting participants) is a concrete, manageable obligation
- The consent boundary is temporal: the meeting start/end acts as a natural permission bracket

**Granola's consent implementation:**
- Automated consent messaging: sends a chat message at the meeting start in Zoom/Google Meet
- Uses AX APIs to open the chat panel, paste consent text, and send — this is itself an AX-powered action
- Limitations: only Zoom and Google Meet; requires the window to be focused; English-only for Google Meet

**What this teaches:** For a cross-app knowledge system, consider offering a "contextual capture" mode alongside ambient mode. "Capture when I'm reading this document" or "capture while in this meeting" sets a time-bounded scope that reduces the psychological burden of continuous surveillance.

---

### 2.4 macOS TCC Framework: Technical Requirements

The Transparency, Consent, and Control (TCC) framework governs access to privacy-sensitive resources. Ambient capture requires two TCC permissions ([The Eclectic Light Company](https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/)):

#### Required Permissions

| Permission | TCC Service Key | What It Enables | Request Mechanism |
|---|---|---|---|
| **Accessibility** | `kTCCServiceAccessibility` | AXUIElement cross-process reads; AXObserver; controlling other apps | `AXIsProcessTrusted()` + system alert directing to Settings |
| **Screen Recording** | `kTCCServiceScreenCapture` | ScreenCaptureKit; CGDisplayStream; screenshots | SCContentSharingPicker or first call to `SCShareableContent` triggers prompt |

**How TCC grants work:**
- TCC is a rule-based SQLite database at `~/Library/Application Support/com.apple.TCC/TCC.db`
- `auth_value = 2` = denied; `auth_value = 1` = allowed (though values vary by macOS version)
- The database is SIP-protected — cannot be written programmatically without disabling SIP
- `tccutil reset ScreenCapture` resets Screen Recording permission from Terminal (useful for testing)
- There is no API to pre-grant permissions; the user must act in System Settings

**Best practice for requesting permissions gracefully:**

1. **Explain value before asking.** On first launch, show a setup flow explaining what each permission enables in user-benefit language ("So you can capture text you highlight in any app") before triggering the system prompt.
2. **Request progressively.** Ask for Accessibility first (lower perceived risk), Screen Recording second. Only request Screen Recording when the user explicitly enables visual capture.
3. **Deep-link to the right Settings pane.** Open `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` to take the user directly to the right toggle. ([Accessibility permission guide, jano.dev](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html))
4. **Handle permission change gracefully.** The user can revoke permission at any time. Detect with `AXIsProcessTrusted()` and degrade gracefully (offer clipboard-only capture, or show a banner to re-enable).
5. **The restart problem for Screen Recording:** macOS requires an app restart after Screen Recording permission is granted (the permission doesn't take effect in the running process). Design for this: detect the just-granted state and prompt for restart.

---

### 2.5 Consent UX Design Principles

Drawing from Microsoft Recall's failure and the research on smart home creepiness ([Taylor & Francis, 2025](https://www.tandfonline.com/doi/full/10.1080/0144929X.2025.2598603)):

**Key finding from the creepiness research:** Perceived creepiness is significantly increased by **temporal proximity** — when the system acts on captured data immediately after capture, it triggers "how does it know that already?" discomfort. Introducing a slight intentional delay (or making the connection between capture and surfacing explicit) reduces this effect.

**Consent UX checklist:**

- [ ] Visual indicator always visible during active capture (not just a menu bar icon — a persistent status bar or subtle but consistent indicator)
- [ ] One-click global pause, accessible without opening Settings
- [ ] Per-app granular control in a single Settings view (not scattered through multiple panels)
- [ ] Ability to review and delete captured data by time range, app, or content type
- [ ] Automatic exclusion defaults for high-risk apps (1Password, KeePass, banking apps, private browsing)
- [ ] "What was captured?" transparency log
- [ ] Encryption at rest, with Touch ID / password requirement to unlock the knowledge store

---

<a name="section-3"></a>
## Section 3: Polling vs Event-Driven AX Observation

### 3.1 The Core Trade-Off

| Approach | Pros | Cons |
|---|---|---|
| **Polling (e.g., every 500ms)** | Simple implementation; no observer lifecycle management; works even when notifications are unreliable | CPU cost proportional to interval and app complexity; wasted work when nothing changes; higher latency possible between change and capture |
| **AXObserver (event-driven)** | Zero CPU cost between events; immediate notification; scales to many apps | Observer lifecycle must be managed per-PID; observers must be on the main thread run loop; some apps have unreliable notification firing |

### 3.2 CPU Overhead Analysis

**Polling cost factors:**
- `AXUIElementCopyAttributeValue` is a synchronous IPC call to the target process. Cost is proportional to: (a) the element's complexity, (b) whether the app is responsive, (c) how deep in the tree you're querying.
- For a simple text field query (getting `kAXSelectedTextAttribute` from a focused element): typically <1ms per call on modern hardware.
- For a full tree traversal of a complex browser window with hundreds of AX elements: can take 50–200ms per pass.
- **The Muzzle app analysis** found that a window-state polling loop (checking for fullscreen state every ~30 seconds via AX) consumed ~5% CPU with a 2+ second detection latency. Compare to their AXObserver approach: "under 0.3% CPU idle, 0.0W power" ([lifetips.alibaba.com/muzzle teardown](https://lifetips.alibaba.com/tech-efficiency/muzzle-automatically-disables-macos-notifications-when-y)).
- **Polling at 500ms** on a complex app (e.g., a browser with many tabs' worth of AX tree loaded) could realistically consume 3–8% CPU continuously — enough to impact battery life noticeably.

**AXObserver event cost:**
- When a notification fires, you receive the specific `AXUIElementRef` that changed. You only query that element, not the whole tree.
- The callback overhead is negligible — essentially a run loop dispatch.
- Total CPU impact: near-zero between events; brief spike on each event proportional to what you query in the callback.

### 3.3 Recommended Hybrid Architecture

The optimal architecture combines observers for coarse-grained context detection with targeted immediate reads:

```
Level 1: NSWorkspace observers (zero AX cost)
├── NSWorkspaceDidActivateApplicationNotification
│   → Update which app is active; set up/tear down AX observers for that PID
└── NSWorkspaceScreensDidSleepNotification
    → Suspend all monitoring; no-op until wake

Level 2: AXObserver for focus/window changes (low cost)
├── kAXFocusedUIElementChangedNotification
│   → User moved focus: read kAXSelectedTextAttribute on new element
├── kAXApplicationActivatedNotification
│   → New app came foreground: rebuild observer set
└── kAXWindowCreatedNotification
    → New window: add to observer set if needed

Level 3: AXObserver for content changes (medium cost, rate-limited)
├── kAXSelectedTextChangedNotification
│   → User made a new text selection: read selected text
│   → Debounce: only emit if selection held stable for ≥ 300ms
└── kAXValueChangedNotification
    → Content changed (typing): debounce ≥ 2000ms idle before capture
    → Only capture if text length indicates meaningful content (> 50 chars, e.g.)

Fallback: Targeted polling only when needed
└── When AXObserver fails to register (app doesn't support notifications)
    → Narrow polling: only query kAXSelectedTextAttribute on current focused element
    → At 1000ms interval (not 500ms) to reduce load
    → Suspended when screen locked, user idle > 60s
```

### 3.4 User Idle Detection

macOS provides multiple mechanisms to detect when monitoring is unnecessary:

**Screen sleep/wake** — use NSWorkspace notifications:
```swift
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.screensDidSleepNotification, ...)
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.screensDidWakeNotification, ...)
```

**User idle time** — use IOKit's HIDIdleTime ([Stack Overflow](https://stackoverflow.com/questions/6418210/notification-when-the-system-is-idle-or-not-on-os-x)):
```c
NSTimeInterval GetIdleTimeInterval() {
    io_iterator_t iter = 0;
    int64_t nanoseconds = 0;
    IOServiceGetMatchingServices(kIOMainPortDefault,
        IOServiceMatching("IOHIDSystem"), &iter);
    io_registry_entry_t entry = IOIteratorNext(iter);
    CFMutableDictionaryRef dict;
    IORegistryEntryCreateCFProperties(entry, &dict, kCFAllocatorDefault, 0);
    CFNumberRef obj = CFDictionaryGetValue(dict, CFSTR("HIDIdleTime"));
    CFNumberGetValue(obj, kCFNumberSInt64Type, &nanoseconds);
    return (double)nanoseconds / 1e9;
}
```

**App in background:** If your knowledge app itself is in the background with its window not visible, that's not a signal to stop monitoring — that's the expected operating mode. Distinguish your app's visibility from the target apps' visibility.

### 3.5 Battery Impact Considerations

From the AX-polling-vs-observer analysis, the key battery impact factors:

1. **Wake events per second** — frequent polling creates wake events that prevent the CPU from entering deep idle states. Even 1 AX call/second can keep efficiency cores from sleeping between calls.
2. **IPC overhead** — each `AXUIElementCopyAttributeValue` call is an inter-process message. On Apple Silicon, this is extremely efficient but not free.
3. **Practical guideline:** Observer-based design targeting <1 wake event per second from your process keeps battery impact below the threshold of user-noticeable drain on Apple Silicon MacBooks.

---

<a name="section-4"></a>
## Section 4: On-Device OCR for AX-Sparse Apps

### 4.1 The AX Coverage Problem: Quantitative Baseline

Based on the [Screen2AX paper (July 2025)](https://arxiv.org/html/2507.16704v1), studying macOS accessibility coverage across a large app sample:

- **17.7% of popular apps** and **32.7% of randomly sampled apps** have essentially absent AX trees (only window chrome elements or nothing).
- **45.9% of popular apps** and **37.8% of random apps** have only partial AX trees.
- Only **~36%** of popular apps provide full accessibility metadata.

This means for roughly 64% of apps, AX-based text extraction will be incomplete or impossible. OCR fallback is not an edge case — it is a first-class requirement.

**App categories most likely to have absent/sparse AX trees:**
- **Games** (Unity, Unreal, custom Metal/OpenGL rendering)
- **Creative tools** (Photoshop, Figma, Sketch — custom canvas rendering)
- **Java Swing applications** (NetBeans, IntelliJ IDEA's custom renderer, older enterprise tools; also prone to freezing the AX bridge on large trees ([GitHub/corretto-17](https://github.com/corretto/corretto-17/issues/132)))
- **Flutter and other non-native cross-platform apps**
- **Less-known/indie apps** using custom UI frameworks
- **Scanned PDF content in Preview** (the PDF structure exposes no text if it's a scan)

**AXStaticText note:** The Screen2AX paper specifically found that `AXStaticText` elements (non-editable body text, labels) are the hardest to detect via the AX tree and are "best detected using OCR." This means even apps with good AX coverage for interactive elements may leave static reading content (article text, documentation) as OCR-only territory.

---

### 4.2 Deciding When to Fall Back to OCR: Heuristics

Rather than OCR-ing everything, use a tiered decision tree to minimize unnecessary computation:

```
1. Is AXIsProcessTrusted() false?
   → All apps: must use OCR or clipboard only

2. Query kAXChildrenAttribute on the app's root element
   → If child count ≤ 3 AND roles are only AXWindow/AXMenuBar:
     → AX tree is absent; use OCR

3. Query the focused element for kAXSelectedTextAttribute
   → If returns kAXErrorCannotComplete or kAXErrorNoValue repeatedly
     (>3 attempts across 5 seconds): app has sparse coverage; escalate to OCR

4. Query kAXRoleAttribute on focused element
   → If AXScrollArea → AXWebArea → [many AXStaticText children]:
     → Good AX coverage for web content
   → If AXScrollArea → AXLayoutItem (generic group):
     → Likely Electron with AXManualAccessibility not yet enabled; try that first
   → If returns kAXErrorInvalidUIElement repeatedly:
     → Custom rendering; use OCR

5. Specific bundle IDs known to be OCR-only:
   → com.adobe.Photoshop, com.figma.Desktop, com.unity.*
   → Any app whose bundle ID starts with the known-OCR-required list
```

**The Electron unlock path (try before OCR):**
For any app whose bundle ID includes known Electron markers, or whose AX tree shows only top-level chrome elements, attempt:
```swift
AXUIElementSetAttributeValue(axApp, "AXManualAccessibility" as CFString, true as CFTypeRef)
```
If the child count grows substantially after this, the app has been unlocked and AX is now usable.

---

### 4.3 Apple Vision Framework: VNRecognizeTextRequest

`VNRecognizeTextRequest` is the on-device OCR engine that powers Live Text in Photos, Quick Look, and macOS's native text selection in images. It runs fully locally with no network requests.

**Recognition levels** ([Apple Developer](https://developer.apple.com/documentation/vision/vnrequesttextrecognitionlevel/fast)):
- `.accurate` — uses a neural network pipeline optimized for accuracy; slower (~100–300ms per frame on M1/M2 for a typical 1440p screenshot region), higher accuracy
- `.fast` — rule-based + simpler model; faster (~20–50ms), lower accuracy, fewer supported languages

**Language support** (from empirical testing via [Swift language query](https://stackoverflow.com/questions/69546997/swifts-vision-framework-not-recognizing-japanese-characters)):

| Revision | Level | Supported Languages |
|---|---|---|
| `VNRecognizeTextRequestRevision2` | `.accurate` | `en-US`, `fr-FR`, `it-IT`, `de-DE`, `es-ES`, `pt-BR`, `zh-Hans`, `zh-Hant` |
| `VNRecognizeTextRequestRevision2` | `.fast` | `en-US`, `fr-FR`, `it-IT`, `de-DE`, `es-ES`, `pt-BR` |
| macOS Ventura + Revision3 | `.accurate` | Adds `yue-Hans`, `yue-Hant`, `ko-KR`, `ja-JP`, `ru-RU`, `uk-UA` |

**Key properties:**
- `recognitionLevel`: `.accurate` or `.fast`
- `usesLanguageCorrection`: `true` (apply language model correction to results) — increases accuracy for prose, reduces accuracy for code/URLs/structured data
- `recognitionLanguages`: explicit language hints as BCP-47 strings; affects model selection
- `minimumTextHeight`: float in [0, 1] as fraction of image height — filter out small text below this size

**Performance on Apple Silicon:** On M1/M2, `.accurate` mode runs on the Neural Engine (ANE), dramatically reducing CPU and battery impact vs. older Intel-based implementations. For ambient capture where OCR runs in background, the ANE allows OCR without measurable CPU load.

**Typical implementation:**

```swift
func performOCR(on image: CGImage) async -> [String] {
    return await withCheckedContinuation { continuation in
        let request = VNRecognizeTextRequest { request, error in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let texts = observations.compactMap { $0.topCandidates(1).first?.string }
            continuation.resume(returning: texts)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }
}
```

**Note:** `VNRecognizeTextRequest` is **not thread-safe** — do not share a single instance across threads ([Reddit](https://www.reddit.com/r/swift/comments/1bkkt9n/need_help_parallelizing_ocr_using_visions/)). Create a new request per image. For throughput, use concurrent `VNImageRequestHandler` instances on a serial or concurrent background queue.

---

### 4.4 ScreenCaptureKit: Targeted Window Capture for OCR

For OCR fallback, capturing the entire screen is unnecessary, wasteful, and captures private data from adjacent windows. ScreenCaptureKit allows surgical capture of exactly the target window ([WWDC22 session](https://developer.apple.com/videos/play/wwdc2022/10155/)):

**Performance vs legacy APIs (OBS benchmark):**
| Metric | CGWindowListCreateImage (legacy) | ScreenCaptureKit |
|---|---|---|
| Frame rate | As low as 7fps with stuttering | 60fps smooth |
| RAM usage | Higher | Up to 15% less |
| CPU utilization | Higher | Up to 50% less |

**Single-window capture for OCR:**

```swift
// Get the target window
let content = try await SCShareableContent.excludingDesktopWindows(
    false, onScreenWindowsOnly: false)
let targetWindow = content.windows.first { $0.owningApplication?.bundleIdentifier == targetBundleID }

// Create a display-independent window filter
let filter = SCContentFilter(desktopIndependentWindow: targetWindow!)

// Configure for OCR use (not video — just frames)
let config = SCStreamConfiguration()
config.width = Int(targetWindow!.frame.width * 2)  // 2x for Retina
config.height = Int(targetWindow!.frame.height * 2)
config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1fps sufficient for OCR

// Capture a single frame
let stream = SCStream(filter: filter, configuration: config, delegate: nil)
```

**Key ScreenCaptureKit properties for privacy-conscious OCR:**
- `SCContentFilter(desktopIndependentWindow:)` captures ONLY the target window, even when occluded — other windows' content cannot bleed in
- `SCStreamConfiguration.sourceRect` can further crop to the visible portion of the window, reducing OCR workload
- Private browser windows are excluded by default from SCShareableContent; the filter composition naturally excludes them

**Privacy comparison: OCR vs AX**

| Dimension | AX-Based Capture | OCR-Based Capture |
|---|---|---|
| **Scope** | Reads only structured UI data (role, value, selection) | Reads all visually rendered text in the target window |
| **Sensitivity** | Lower: only what the AX model exposes | Higher: captures everything visible including passwords in visible fields, sensitive documents |
| **Selectivity** | Can target `kAXSelectedTextAttribute` only | Must capture full window; post-filter in software |
| **Private windows** | Apps typically return `kAXErrorCannotComplete` for truly private contexts | ScreenCaptureKit natively excludes private windows |
| **Recommendation** | Prefer AX for interactive text capture | Use OCR only as fallback; apply sensitive-content filtering (detect password fields, financial patterns) before storing |

---

### 4.5 Screenpipe: Open-Source Reference Implementation

[screenpipe](https://rewind.sh) is the leading open-source Rewind alternative, built in Rust with an event-driven capture model. From their documentation: "captures your screen using an intelligent event-driven system that triggers on actual user activity instead of continuous polling" — exactly the hybrid architecture recommended in Section 3. Key technical choices:
- ScreenCaptureKit for windowed capture
- Apple Vision framework for OCR
- Local-only storage with encryption
- Per-app exclusion list including incognito detection
- All OCR and storage runs in Rust, demonstrating the viability of the Rust-heavy architecture

---

<a name="section-5"></a>
## Section 5: Lifelogging Research Heritage

### 5.1 Vannevar Bush's Memex (1945): The Founding Vision

In his July 1945 essay "As We May Think" ([The Atlantic](https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/)), Vannevar Bush articulated the problem that ambient knowledge capture attempts to solve:

> "The summation of human experience is being expanded at a prodigious rate, and the means we use for threading through the consequent maze to the momentarily important item is the same as was used in the days of square-rigged ships."

The **Memex** was Bush's proposed solution: a desk-like device where a person stores all their books, records, and communications, "mechanized so that it may be consulted with exceeding speed and flexibility." It served as "an enlarged intimate supplement to his memory."

**Core Memex innovations that directly inform ambient capture design:**

1. **Associative indexing over hierarchical filing:** Bush observed that "the human mind... operates by association. With one item in its grasp, it snaps instantly to the next that is suggested by the association of thoughts." The Memex was designed to link items, not file them. Modern knowledge graphs and semantic embedding capture this insight.

2. **Trail building:** Users create named trails through their Memex — sequences of linked documents representing a research path. "When numerous items have been thus joined together to form a trail, they can be reviewed in turn, rapidly or slowly." This anticipates hyperlinks, but also the session-based capture model: capturing not just content but the *path through* content.

3. **Microfilm capture:** Bush envisioned users photographing documents with head-mounted cameras and annotating them in real-time. The technological substrate was wrong but the insight was right: capture must be frictionless and ambient, not active and deliberate.

**The Memex's influence:** Doug Engelbart directly cited Bush's essay when inventing the mouse, word processor, and hyperlink. [Wikipedia notes](https://en.wikipedia.org/wiki/As_We_May_Think) that "As We May Think" anticipated many aspects of the information society and has been described as visionary and influential since its 1945 Atlantic publication.

**What Bush got prescient:** The distinction between *stored records* and *associative trails*. For a knowledge capture system, the insight is that captured snippets are only valuable if the retrieval mechanism respects the associative structure of how the information was encountered — not just date-sorted flat search.

---

### 5.2 Gordon Bell's MyLifeBits (1998–2007): Total Capture at Scale

Gordon Bell, then a principal researcher at Microsoft Research, began in 1998 what became the MyLifeBits project: a systematic attempt to capture every artifact of his life digitally and store it in a searchable database ([Microsoft Research](https://www.microsoft.com/en-us/research/project/mylifebits/)).

**What they captured:**
- Lifetime archive of articles, books, cards, CDs, letters, memos, papers, photos, pictures, presentations, home movies
- Progressively added: phone calls, IM transcripts, TV, radio
- SenseCam (wearable camera) data: images triggered by movement/light/heat changes
- Heart rate, temperature, location

**What they built (software):** Jim Gemmell and Roger Lueder developed the MyLifeBits application, built on SQL Server, providing:
- Hyperlinks between all stored items
- Annotations and voice annotations
- Gang annotation on right-click (annotate multiple items at once)
- Reports, saved queries, pivoting, clustering
- Fast FTS search
- Faceted classification and document similarity ranking

**The "Total Recall" philosophy:** Bell and Gemmell's 2009 book advocated for "total recall" through "total capture" — augmenting or replacing biological memory with complete digital records. Bell's thesis: "I can retrieve all the information I would otherwise forget."

**What the research actually found:** From the [Sellen & Whittaker critique "Beyond Total Capture" (Microsoft Research, published in Communications of the ACM)](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/04/Beyond-total-capture.pdf):

The MyLifeBits approach produced surprisingly little evidence of practical utility:
- Digital archives are "rarely accessed, even when deliberately saved"
- Petrelli & Whittaker (2010): fewer than 2% of mnemonic objects in homes are digital; family photos/videos/emails seldom used
- Meeting/lecture recording tools: "little uptake despite tools; no grade improvement from lectures" (Abowd 1999)
- Desktop search: "infrequent use; better search doesn't increase use" (Bergman et al. 2008)
- Total capture was used by "only a small number of people with direct investment in the technology"

**The data graveyard problem defined:** The fundamental failure mode: capturing everything but accessing nothing. Storage became the goal; retrieval was an afterthought. The captured data became a "just-in-case" archive with no specific retrieval purpose — "a digital attic" rather than an active second brain.

**Sellen & Whittaker's Four Lessons for System Designers:**

| Lesson | Implication for Ambient Capture |
|---|---|
| **Selectivity, not total capture** | Design for high-value situations; allow forgetting; don't capture everything just because you can |
| **Cues, not capture** | Design effective retrieval cues (place, people, events) rather than high-fidelity facsimiles; a well-chosen thumbnail cues memory better than 10 minutes of video |
| **Clarify which memory to support** | The "Five Rs": Recollecting, Reminiscing, Retrieving, Reflecting, Remembering intentions — each requires different data types and interfaces |
| **Synergy, not substitution** | Offload to the system only what organic memory handles poorly; don't displace memory, augment it |

---

### 5.3 Steve Mann and Sousveillance: The Ethics of Personal Capture

Steve Mann at the University of Toronto has worn various forms of continuous wearable cameras since the 1970s, creating one of the longest empirical records of personal visual lifelogging. His term "**sousveillance**" (from French *sous*, "under," as opposed to *sur*veillance from "above") describes inverse surveillance: the individual watching the world, rather than institutions watching the individual ([ACM](https://dl.acm.org/doi/10.1145/1027527.1027673), [MIT Press](https://direct.mit.edu/pvar/article/14/6/625/18597/Sousveillance-and-Cyborglogs-A-30-Year-Empirical)).

**Mann's key insight:** Continuous capture is qualitatively different from selective capture. The EyeTap device "captures exactly what the bearer does see... a serendipitously generated logfile that happens without conscious thought or effort." This produces a new type of record — not a curated memory but a complete episodic stream.

**The social tensions Mann documented (from 30 years of field experience):**
1. Recording in public spaces provokes confrontation with "surveillance authorities" (store security, police) who see personal recording as threatening surveillance infrastructure
2. Others' consent: being in someone else's video capture without knowledge or consent is experienced as fundamentally different from being seen by the person's own eyes
3. The legal landscape (as of Mann's work) was ambiguous about personal continuous recording in most jurisdictions

**Relevance for cross-app capture:** Mann's framing of sousveillance as a *personal* act — the data belongs entirely to the person doing the recording, is stored by them, and serves their individual memory — is the ethical core that Rewind.ai, screenpipe, and similar tools invoke. The key distinction from surveillance: the data flows toward the individual, not toward institutions or third parties.

**The consent boundary:** Mann's work suggests the critical ethical line is not whether you capture (you may always record your own experience) but whether the capture **reveals information about others without their consent**. Meeting transcripts, emails from other people, shared documents — these cross from personal sousveillance into third-party data capture, requiring explicit consent frameworks.

---

### 5.4 The Lifelogging Research Consensus on Information Overload

A 2024 survey paper ["Lifelogging As An Extreme Form of Personal Information Management" (arxiv)](https://arxiv.org/html/2401.05767v1) reviewing the state of the field confirms the data graveyard and overload problems:

- "The vast volume and immense complexity of lifelog archives presents a challenge for users to navigate and analyse these archives in order to identify relevant information."
- MyLifeBits' limitations "soon became apparent" as data volumes grew beyond what traditional database search could make useful
- The annual Lifelog Search Challenge (LSC) benchmarking workshop exists specifically because retrieval from large lifelogs is an unsolved research problem

**The volume problem in numbers:** A typical ambient capture system (screenshots every 2 seconds at 1440p) generates approximately 14GB/month of H.264 video (Rewind's estimate), or roughly 1.5TB per year. The OCR text index is much smaller (tens of megabytes), but the retrieval problem compounds: 1.5TB of captured screenshots representing millions of screenful-equivalents is not meaningfully searchable by traditional full-text search.

**The research verdict:** The [Sellen & Whittaker critique](https://hci.stanford.edu/courses/cs247/2011/readings/sellen.pdf) from Stanford's HCI reading list summarizes: "capturing vast arrays of data might overwhelm end users maintaining and retrieving valuable information from large archives; it also ignores the burden huge amounts of data impose on system designers and developers."

---

<a name="section-6"></a>
## Section 6: Critical UX Pitfalls

### 6.1 The Creepy Factor

**Definition:** Ambient capture makes users feel surveilled even by their own software when: (a) the data flow is invisible, (b) the system acts on captured data in unexpected ways, or (c) the capture scope is broader than users consciously registered consenting to.

**Research grounding:** A 2025 study on smart home surveillance ([Taylor & Francis](https://www.tandfonline.com/doi/full/10.1080/0144929X.2025.2598603)) identified five creepiness factors:
1. **Persistent privacy fears** about unauthorized access
2. **Creepy personalization** — system knows too much too quickly
3. **Hidden data practices** — user doesn't know what's being stored
4. **Surveillance awareness** — the feeling of being watched by your own device
5. **Bias and manipulation concerns** — fear the system will misuse knowledge against you

**The temporal proximity effect:** Creepiness is significantly amplified when captured data is surfaced immediately after capture. If a user mentions something in a meeting and the knowledge system surfaces a related note 10 seconds later, this triggers "it knows what I said" discomfort. Introduce a deliberate 5–15 minute lag between capture and first surfacing of captured data — long enough that the connection doesn't feel surveillance-like.

**Mitigation strategies:**
- Make capture state unambiguously visible at all times (not just when the mouse is over a menu bar icon)
- Name the system's capability explicitly: "This is capturing the text you selected in Preview" — not just a generic "recording"
- Give users a "not that" button immediately when a captured item appears in the UI: "Remove this capture"
- Distinguish between capture (always happening during active use) and surfacing (intentional, triggered by user action or explicit recommendations)

---

### 6.2 The Data Graveyard Problem

Ambient capture systems consistently create impressive-looking archives that no one uses. The specific failure modes:

**1. No retrieval surface.** Capturing everything but only providing full-text search means the user must know what they're looking for — which defeats the purpose of ambient capture. The knowledge was already in their head; the system just stores a copy. The value of ambient capture is surfacing information the user has *forgotten* they encountered.

**2. Staleness without curation.** Text captured 8 months ago from a browser tab is rarely relevant to current work. Without temporal decay, recency weighting, or explicit curation, the archive grows but the retrieval quality degrades.

**3. Context loss.** A snippet of text captured from a browser article is hard to interpret without knowing: What article? What was the user doing? What was the question they were exploring? Capture without context is lower quality than a note taken intentionally.

**4. No differentiation between signal and noise.** A user navigating to their bank to pay a bill, then checking email, then reading an article, generates equally weighted AX/OCR output for all three. The banking text is private noise; the email is ephemeral; the article might be knowledge. Without a signal/noise filter, storage grows without utility.

**Design countermeasures:**

| Anti-Pattern | Countermeasure |
|---|---|
| Flat chronological archive | Temporal decay weighting in retrieval; surface recent captures higher |
| Equal treatment of all captured text | Context weighting: selected/highlighted text > briefly-viewed text > typed-into-forms text |
| No curation mechanism | "Save this" / "Discard this" UI when capture is surfaced; explicit user confirmation for high-value items |
| Capture everything by default | Start with selective capture (user-initiated highlights only); enable ambient capture as an opt-in tier |
| Store raw snippets | Immediately process captured text: entity extraction, deduplication, clustering — store structured knowledge, not raw text |

---

### 6.3 Permission Fatigue

macOS ambient capture requires two high-visibility permissions (Accessibility and Screen Recording) plus potentially three more (Microphone, Contacts, Full Disk Access). Requesting them all at install creates:

1. **Decision paralysis:** Users faced with 5 permission dialogs in sequence are more likely to deny them all than accept them all
2. **Trust erosion:** A long list of permissions signals "this app wants everything" — the same pattern as malware and adware
3. **The chicken-and-egg problem:** Users can't see the value of the app until permissions are granted, but granting permissions requires trusting an app they haven't yet seen work

**Recommended permission sequencing:**

| Phase | Permission | Rationale |
|---|---|---|
| First launch | **Accessibility only** | Minimal footprint; enables clipboard and selected-text capture without screen recording |
| After user sees first capture surfaced | **Screen Recording** | User has evidence of value; present with specific explanation of what it enables |
| Explicitly optional | **Microphone** | Only for meeting transcription; skip entirely if not building that feature |
| Never request | Full Disk Access | Not needed for ambient capture; requesting it is a major trust red flag |

**"Just-in-time" permission requests:** Request each permission at the moment the user tries to use the feature that requires it, not upfront. This creates context: "To capture what's visible on screen (not just what you select), we need Screen Recording access" — said when the user explicitly clicks "Enable visual capture" in Settings.

---

### 6.4 Performance Degradation: Not Making Other Apps Slower

AX monitoring can visibly impact the performance of target apps under two conditions:

1. **Chrome's accessibility tree with `AXManualAccessibility = true`:** Enabling Chrome's AX tree incurs real overhead in the Chrome process. Chromium has reported that enabling AX mode increases memory and CPU usage measurably. For a knowledge capture system, consider enabling it only temporarily (while Chrome is the frontmost app) and disabling it when the user switches away.

2. **AXEnhancedUserInterface on Chrome/Electron ([Chromium bug tracker](https://issues.chromium.org/40865608)):** Setting `AXEnhancedUserInterface` on Chromium-based apps has historically triggered freezes/lags. `AXManualAccessibility` is the correct modern attribute; avoid `AXEnhancedUserInterface`.

3. **AX query blocking:** `AXUIElementCopyAttributeValue` is a synchronous blocking IPC call. If the target app is slow, unresponsive, or in the middle of a heavy operation, your call blocks your own thread until it times out. Use `AXUIElementSetMessagingTimeout` to set a maximum wait:
```c
AXUIElementSetMessagingTimeout(element, 0.5); // 500ms max wait
```

4. **Java Swing AX bridge:** `sun.lwawt.macosx.CAccessibility` (the Java/macOS AX bridge) can freeze or become unresponsive when handling large tree queries ([GitHub/corretto](https://github.com/corretto/corretto-17/issues/132)). If the target app is a Java Swing app (identified by the JVM process), use aggressive timeout settings and fall back to OCR quickly.

---

### 6.5 False Confidence: AX Gaps the User Doesn't Know About

The most dangerous UX failure: the user believes their knowledge system captured important information, but it silently failed.

**Where silent failures occur:**

| Scenario | Why It Fails | User Perception |
|---|---|---|
| Reading a scanned PDF in Preview | No text in AX tree; OCR not triggered | User thinks "it captured my PDF reading" |
| Highlighting text in a custom-rendered app (Figma, game, video player) | AX tree absent; selection not accessible | "I highlighted that quote, it should be saved" |
| Text in a system modal/dialog | Some system dialogs have restricted AX access | "I read that warning, system probably logged it" |
| Text in a screenshot (an image of text) | OCR can read it but requires proactive screen region analysis | No automatic capture of image-embedded text |
| Private browsing tab | Intentionally excluded | Correct behavior — but user may not realize it was excluded |

**Countermeasure — capture confidence signals:**
- When the system successfully captures text from an app, show a subtle brief indicator (1.5s fade): "Captured from Preview"
- When the system detects you're reading an AX-sparse app and falls back to OCR, indicate the mode: a slightly different icon or color
- When the system cannot capture (absent AX, failed OCR), do NOT silently fail — show a faint "No capture available" state that the user can acknowledge
- Provide a per-app capture status view: "In Figma, I can only capture text you copy to clipboard (the app doesn't expose text to accessibility tools)"

---

## Summary Technical Reference

### AXUIElement Attribute Quick Reference

| Attribute | Type | Use for Knowledge Capture |
|---|---|---|
| `kAXFocusedUIElementAttribute` | AXUIElement | Entry point: get current focused element |
| `kAXSelectedTextAttribute` | CFString | Read highlighted/selected text |
| `kAXSelectedTextRangeAttribute` | CFRange (AXValue) | Get selection position/length |
| `kAXBoundsForRangeParameterizedAttribute` | CGRect (AXValue) | Get screen coordinates of selection |
| `kAXValueAttribute` | CFString | Full content of focused text element |
| `kAXRoleAttribute` | CFString | Element type (AXTextField, AXWebArea, etc.) |
| `kAXChildrenAttribute` | CFArray | Enumerate subtree |
| `kAXTitleAttribute` | CFString | Window/element title |
| `kAXURLAttribute` | CFURL | URL of browser content |

### Key Rust Crates

| Crate | Version | Use |
|---|---|---|
| `accessibility-sys` | 0.2.0 | Complete C-level AX bindings |
| `accessibility` | 0.2.0 | Higher-level safe wrappers (incomplete) |
| `screencapturekit` | search crates.io | ScreenCaptureKit bindings for Rust |

### Permission Requirements Summary

| TCC Permission | Needed For | User Impact if Missing |
|---|---|---|
| Accessibility | AXUIElement reads, AXObserver | No cross-app text capture at all |
| Screen Recording | ScreenCaptureKit OCR fallback | No visual capture; text-selection-only mode |

### The Minimal Viable Consent Architecture

1. **Default state:** Capture DISABLED. Opt-in only.
2. **Minimum capture:** AX-only selected text (no screen recording required). Zero-risk first step.
3. **Full capture:** AX + ScreenCaptureKit OCR. Requires Screen Recording permission. Opt-in after user sees value from minimum capture.
4. **Encryption:** All stored knowledge encrypted at rest. Decrypt on Touch ID / password only.
5. **Exclusion defaults:** Password managers, private browsing, banking apps, health apps — excluded by bundle ID allowlist.
6. **Visual indicator:** Always-visible capture status in the UI.
7. **One-click pause:** Global capture pause in ~2 clicks maximum.

---

## Sources

- [Apple Developer: kAXSelectedTextAttribute](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute)
- [Apple Developer: AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification)
- [Apple Developer: AXUIElementCreateApplication](https://developer.apple.com/documentation/applicationservices/1459374-axuielementcreateapplication)
- [Apple Developer: VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
- [Apple Developer: ScreenCaptureKit WWDC22](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [Stack Overflow: AXUIElement main thread requirement](https://stackoverflow.com/questions/64435187/can-the-functions-in-axuielement-h-be-safely-called-from-threads-other-than-the)
- [Stack Overflow: Using AXUIElement from CLI](https://stackoverflow.com/questions/77628629/is-it-possible-to-use-macos-accessibility-api-features-from-a-cli-or-library)
- [Mac Developers Blog: Get selected text and coordinates](https://macdevelopers.wordpress.com/2014/02/05/how-to-get-selected-text-and-its-coordinates-from-any-system-wide-application-using-accessibility-api/)
- [Reddit: AX dead end analysis with headers](https://www.reddit.com/r/swift/comments/18k909w/i_hit_a_dead_end_with_accessibility_apis/)
- [GitHub: eiz/accessibility Rust bindings](https://github.com/eiz/accessibility)
- [crates.io: accessibility-sys 0.2.0](https://crates.io/crates/accessibility-sys)
- [Reddit: Rust libraries for macOS accessibility](https://www.reddit.com/r/rust/comments/1do68tl/what_knowledge_and_rust_libraries_do_i_need_to/)
- [Electron docs: AXManualAccessibility](https://electronjs.org/docs/latest/tutorial/accessibility)
- [WIRED: Microsoft Recall off-by-default](https://www.wired.com/story/microsoft-recall-off-default-security-concerns/)
- [Ars Technica: Microsoft Recall reworked](https://arstechnica.com/gadgets/2024/06/microsoft-makes-recall-feature-off-by-default-after-security-and-privacy-backlash/)
- [VentureBeat: Recall opt-in and encryption](https://venturebeat.com/ai/microsofts-recall-feature-will-now-be-opt-in-and-double-encrypted-after-privacy-outcry)
- [The Hacker News: Recall biometric authentication](https://thehackernews.com/2024/06/microsoft-revamps-controversial-ai.html)
- [Kevin Chen: Rewind.ai technical teardown](https://kevinchen.co/blog/rewind-ai-app-teardown/)
- [The Sweet Setup: Rewind.ai first look](https://thesweetsetup.com/a-first-look-at-rewind-ai/)
- [Granola: Getting consent documentation](https://docs.granola.ai/help-center/consent-security-privacy/getting-consent)
- [The Eclectic Light Company: TCC explainer](https://eclecticlight.co/2025/11/08/explainer-permissions-privacy-and-tcc/)
- [jano.dev: Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [Spektion: TCC tampering risks](https://www.spektion.com/articles/tampering-with-macos-tcc/)
- [GitHub/corretto: Java Swing AX bridge freeze](https://github.com/corretto/corretto-17/issues/132)
- [MacPaw/arxiv: Screen2AX accessibility coverage paper](https://arxiv.org/html/2507.16704v1)
- [GitHub: MacPaw/Screen2AX](https://github.com/MacPaw/Screen2AX)
- [The Atlantic: Vannevar Bush "As We May Think" (1945)](https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/)
- [Wikipedia: As We May Think](https://en.wikipedia.org/wiki/As_We_May_Think)
- [Microsoft Research: MyLifeBits project](https://www.microsoft.com/en-us/research/project/mylifebits/)
- [Microsoft Research: "Beyond Total Capture" PDF](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/04/Beyond-total-capture.pdf)
- [Stanford HCI: "Beyond Total Capture" (Sellen & Whittaker)](https://hci.stanford.edu/courses/cs247/2011/readings/sellen.pdf)
- [ACM: Mann "Sousveillance" inverse surveillance](https://dl.acm.org/doi/10.1145/1027527.1027673)
- [MIT Press: Mann sousveillance 30-year empirical voyage](https://direct.mit.edu/pvar/article/14/6/625/18597/Sousveillance-and-Cyborglogs-A-30-Year-Empirical)
- [arxiv: Lifelogging as Extreme Personal Information Management](https://arxiv.org/html/2401.05767v1)
- [JMIR: Lifelog Retrieval From Daily Digital Data narrative review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9112086/)
- [Taylor & Francis: Unpacking creepiness in smart home surveillance](https://www.tandfonline.com/doi/full/10.1080/0144929X.2025.2598603)
- [Stack Overflow: VNRecognizeTextRequest language support](https://stackoverflow.com/questions/69546997/swifts-vision-framework-not-recognizing-japanese-characters)
- [Stack Overflow: User idle detection macOS](https://stackoverflow.com/questions/6418210/notification-when-the-system-is-idle-or-not-on-os-x)
- [Apple Developer: NSWorkspace screensDidSleepNotification](https://developer.apple.com/documentation/AppKit/NSWorkspace/screensDidSleepNotification)
- [lifetips.alibaba.com: Muzzle AX-based fullscreen detection analysis](https://lifetips.alibaba.com/tech-efficiency/muzzle-automatically-disables-macos-notifications-when-y)
- [Screenpipe: Event-driven capture documentation](https://mintlify.com/screenpipe/screenpipe/features/screen-capture)
- [Chromium issue: AXEnhancedUserInterface freezes](https://issues.chromium.org/40865608)
- [Yahoo Finance: Gordon Bell MyLifeBits retrospective](https://finance.yahoo.com/news/microsoft-legend-mind-blowing-theory-011028997.html)
