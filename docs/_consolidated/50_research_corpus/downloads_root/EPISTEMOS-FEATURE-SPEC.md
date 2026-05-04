# Epistemos Feature Specification

> **Version:** 1.0  
> **Author:** Jordan Tyrell Conley  
> **Date:** March 27, 2026  
> **Repository:** BlickandMorty/Epistemos  
> **Purpose:** Implementation reference for AI coding agents (Claude, Codex)

---

## Table of Contents

1. [Part 1: CI/CD Pipeline](#part-1-cicd-pipeline)
2. [Part 2: VLM Agent Desktop](#part-2-vlm-agent-desktop-autonomous-desktop-control)
3. [Part 3: Agent Profiles](#part-3-agent-profiles-multi-instance-architecture)
4. [Appendix](#appendix)

---

# Part 1: CI/CD Pipeline

## 1.1 What Is CI/CD (Plain English)

**Continuous Integration (CI)** means that every time anyone pushes code to the repository, a machine automatically checks out that code, builds every component, and runs every test. Think of it as a spell-checker for code — except instead of catching typos, it catches compilation errors, broken tests, and style violations before they land in the main branch. Without CI, bugs merge silently and compound — a Rust crate change that breaks the Swift FFI bridge won't surface until someone manually tries to build the whole project hours or days later.

**Continuous Delivery (CD)** extends that automation through packaging and release. When you tag a commit (e.g., `v0.4.0`), the pipeline automatically builds the release `.app` bundle, wraps it in a DMG, and publishes it as a GitHub Release. No manual Xcode archive, no forgetting to build all four Rust crates first, no "works on my machine" surprises.

**Why this matters for Epistemos specifically:**

- **242K lines of code** across Swift (137K), Rust (94K), and Python (11K). Manual verification is not viable.
- **4 Rust crates** with FFI boundaries (UniFFI, C FFI) that must build in a specific dependency order. A CI pipeline enforces that order on every push.
- **Cross-language builds**: Rust static/dynamic libraries must be compiled before XcodeGen generates the Xcode project and before `xcodebuild` can link against them.
- **Safety net for refactoring**: When modifying the graph-engine C FFI or the omega-ax MainActor patches, CI catches regressions immediately.

Without CI/CD, the cost of a mistake scales with time — a bug introduced Monday that isn't found until Friday requires debugging five days of accumulated changes. CI shortens that feedback loop to minutes.

## 1.2 CI/CD Architecture for Epistemos

### Workflow 1: `ci.yml` — Build & Test (Push/PR to `main`)

**Trigger:** Every push to `main` and every pull request targeting `main`.

**Runner:** `macos-15` (Apple Silicon / ARM64). This is mandatory — all four Rust crates target `aarch64-apple-darwin` exclusively, and MLX requires Apple Silicon. GitHub's `macos-15` runner provides an M1-family chip with Xcode 16+ preinstalled.

**Timeout:** 45 minutes (Rust compilation from cold cache can take 15-20 minutes; Swift compilation adds another 10-15).

**File:** `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  CARGO_TERM_COLOR: always
  RUST_BACKTRACE: 1
  DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer

jobs:
  build-and-test:
    runs-on: macos-15
    timeout-minutes: 45

    steps:
      # ── 1. Checkout ──────────────────────────────────────────────
      - name: Checkout repository
        uses: actions/checkout@v4

      # ── 2. Install Rust toolchain ────────────────────────────────
      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-darwin
          components: clippy, rustfmt

      # ── 3. Cache Cargo registry + build artifacts ────────────────
      - name: Cache Rust dependencies
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: |
            graph-engine -> target
            epistemos-core -> target
            omega-ax -> target
            omega-mcp -> target
          cache-on-failure: true

      # ── 4. Build Rust crates (dependency order) ──────────────────
      - name: Build graph-engine (static lib, C FFI)
        run: |
          cd graph-engine
          cargo build --target aarch64-apple-darwin --release
        
      - name: Build epistemos-core (UniFFI dylib)
        run: |
          cd epistemos-core
          cargo build --target aarch64-apple-darwin --release

      - name: Build omega-ax (UniFFI static lib)
        run: |
          cd omega-ax
          cargo build --target aarch64-apple-darwin --release

      - name: Build omega-mcp (UniFFI dylib)
        run: |
          cd omega-mcp
          cargo build --target aarch64-apple-darwin --release

      # ── 5. Rust tests ───────────────────────────────────────────
      - name: Test graph-engine
        run: cd graph-engine && cargo test --target aarch64-apple-darwin

      - name: Test epistemos-core
        run: cd epistemos-core && cargo test --target aarch64-apple-darwin

      - name: Test omega-ax
        run: cd omega-ax && cargo test --target aarch64-apple-darwin

      - name: Test omega-mcp
        run: cd omega-mcp && cargo test --target aarch64-apple-darwin

      # ── 6. Rust lints ───────────────────────────────────────────
      - name: Clippy (all crates)
        run: |
          for crate in graph-engine epistemos-core omega-ax omega-mcp; do
            echo "::group::Clippy $crate"
            cd "$crate"
            cargo clippy --target aarch64-apple-darwin -- -D warnings
            cd ..
            echo "::endgroup::"
          done

      - name: Check Rust formatting
        run: |
          for crate in graph-engine epistemos-core omega-ax omega-mcp; do
            cd "$crate" && cargo fmt --check && cd ..
          done

      # ── 7. Generate Xcode project ───────────────────────────────
      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode project
        run: xcodegen generate

      # ── 8. Resolve SPM dependencies ─────────────────────────────
      - name: Resolve Swift Package Manager dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -project Epistemos.xcodeproj \
            -scheme Epistemos \
            -clonedSourcePackagesDirPath .spm-cache
        timeout-minutes: 10

      # ── 9. Build Swift project ──────────────────────────────────
      - name: Build Epistemos (Debug)
        run: |
          xcodebuild build \
            -project Epistemos.xcodeproj \
            -scheme Epistemos \
            -destination "platform=macOS,arch=arm64" \
            -clonedSourcePackagesDirPath .spm-cache \
            CODE_SIGNING_ALLOWED=NO \
            | xcpretty --color

      # ── 10. Run Swift tests ─────────────────────────────────────
      - name: Run Swift tests
        run: |
          xcodebuild test \
            -project Epistemos.xcodeproj \
            -scheme Epistemos \
            -destination "platform=macOS,arch=arm64" \
            -clonedSourcePackagesDirPath .spm-cache \
            CODE_SIGNING_ALLOWED=NO \
            -resultBundlePath TestResults.xcresult \
            | xcpretty --color

      # ── 11. Upload test results ─────────────────────────────────
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
          retention-days: 14

      # ── 12. SPM cache for future runs ───────────────────────────
      - name: Cache SPM packages
        uses: actions/cache@v4
        with:
          path: .spm-cache
          key: spm-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-
```

**Key design decisions:**

- **`concurrency` group with `cancel-in-progress`**: If you push twice quickly, the first run cancels instead of wasting runner minutes.
- **`CODE_SIGNING_ALLOWED=NO`**: CI runners lack signing identities; this skips codesign without failing.
- **`xcpretty`**: Compresses xcodebuild output from thousands of lines to human-readable summaries.
- **Separate Cargo steps per crate**: Provides granular failure identification. If omega-mcp fails, you see exactly which step failed rather than digging through a combined log.
- **`cache-on-failure: true`** for Rust cache: Saves the Cargo download cache even if the build fails, so the next attempt doesn't re-download crates.

### Workflow 2: `release.yml` — Build & Publish Release

**Trigger:** Push of a tag matching `v*` (e.g., `v0.4.0`).

**File:** `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

env:
  CARGO_TERM_COLOR: always
  DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer

jobs:
  release:
    runs-on: macos-15
    timeout-minutes: 60

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for changelog generation

      - name: Install Rust toolchain
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-darwin

      - name: Cache Rust
        uses: Swatinem/rust-cache@v2
        with:
          workspaces: |
            graph-engine -> target
            epistemos-core -> target
            omega-ax -> target
            omega-mcp -> target

      # ── Build release Rust libs ──────────────────────────────────
      - name: Build all Rust crates (release)
        run: |
          for crate in graph-engine epistemos-core omega-ax omega-mcp; do
            cd "$crate"
            cargo build --target aarch64-apple-darwin --release
            cd ..
          done

      # ── Generate UniFFI bindings ─────────────────────────────────
      - name: Generate UniFFI Swift bindings
        run: |
          bash scripts/build-epistemos-core.sh
          bash scripts/build-omega-ax.sh
          bash scripts/build-omega-mcp.sh

      # ── Build release .app ───────────────────────────────────────
      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Generate Xcode project
        run: xcodegen generate

      - name: Resolve SPM dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -project Epistemos.xcodeproj \
            -scheme Epistemos \
            -clonedSourcePackagesDirPath .spm-cache

      - name: Build release app bundle
        run: |
          xcodebuild archive \
            -project Epistemos.xcodeproj \
            -scheme Epistemos \
            -destination "platform=macOS,arch=arm64" \
            -archivePath build/Epistemos.xcarchive \
            -clonedSourcePackagesDirPath .spm-cache \
            CODE_SIGNING_ALLOWED=NO \
            SKIP_INSTALL=NO \
            | xcpretty --color

      # ── Create DMG ──────────────────────────────────────────────
      - name: Extract .app from archive
        run: |
          cp -R build/Epistemos.xcarchive/Products/Applications/Epistemos.app build/

      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg \
            --volname "Epistemos" \
            --volicon "Epistemos/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "Epistemos.app" 175 190 \
            --app-drop-link 425 190 \
            "build/Epistemos-${{ github.ref_name }}.dmg" \
            "build/Epistemos.app" || true

      # ── Generate changelog ──────────────────────────────────────
      - name: Generate changelog
        id: changelog
        run: |
          PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
          if [ -z "$PREV_TAG" ]; then
            CHANGELOG=$(git log --oneline --pretty=format:"- %s (%h)" HEAD)
          else
            CHANGELOG=$(git log --oneline --pretty=format:"- %s (%h)" "$PREV_TAG"..HEAD)
          fi
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      # ── Create GitHub Release ───────────────────────────────────
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          body: |
            ## What's Changed
            ${{ steps.changelog.outputs.changelog }}
          files: build/Epistemos-${{ github.ref_name }}.dmg
          draft: false
          prerelease: ${{ contains(github.ref_name, 'beta') || contains(github.ref_name, 'alpha') }}
```

### Workflow 3: `lint.yml` — Lint on PR

**Trigger:** Pull requests to `main`. Runs only linting (faster than full CI).

**File:** `.github/workflows/lint.yml`

```yaml
name: Lint

on:
  pull_request:
    branches: [main]

concurrency:
  group: lint-${{ github.ref }}
  cancel-in-progress: true

jobs:
  rust-lint:
    runs-on: macos-15
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-darwin
          components: clippy, rustfmt
      - uses: Swatinem/rust-cache@v2
        with:
          workspaces: |
            graph-engine -> target
            epistemos-core -> target
            omega-ax -> target
            omega-mcp -> target

      - name: Clippy (all crates)
        run: |
          for crate in graph-engine epistemos-core omega-ax omega-mcp; do
            cd "$crate" && cargo clippy --target aarch64-apple-darwin -- -D warnings && cd ..
          done

      - name: rustfmt check
        run: |
          for crate in graph-engine epistemos-core omega-ax omega-mcp; do
            cd "$crate" && cargo fmt --check && cd ..
          done

  swift-lint:
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - name: Install SwiftLint
        run: brew install swiftlint

      - name: Run SwiftLint
        run: swiftlint lint --strict --reporter github-actions-logging
```

## 1.3 Linting Setup

### Clippy Configuration

**File: `.cargo/config.toml`** (project root — applies to all crates)

```toml
[target.aarch64-apple-darwin]
rustflags = ["-C", "link-arg=-undefined", "-C", "link-arg=dynamic_lookup"]

[build]
target = "aarch64-apple-darwin"
```

**File: `clippy.toml`** (project root)

```toml
# Clippy configuration for Epistemos
# See: https://doc.rust-lang.org/clippy/configuration.html

msrv = "1.78.0"

# Allow C FFI types that don't follow Rust naming conventions
# (needed for graph-engine's C FFI exports)
too-many-arguments-threshold = 8

# UniFFI-generated code uses large enums
enum-variant-size-threshold = 512

# Allow slightly longer functions in FFI boundary code
too-many-lines-threshold = 150
```

Each crate's `Cargo.toml` should include these lint directives in `[lints.clippy]`:

```toml
[lints.clippy]
all = "warn"
pedantic = "warn"
nursery = "warn"
# Allow these common patterns in Epistemos
module_name_repetitions = "allow"   # e.g., graph_engine::GraphEngine is fine
missing_errors_doc = "allow"        # not all errors need doc comments yet
missing_panics_doc = "allow"
must_use_candidate = "allow"        # too noisy for FFI functions
cast_possible_truncation = "allow"  # needed for CGFloat interop
```

### SwiftLint Configuration

**File: `.swiftlint.yml`** (project root)

```yaml
# SwiftLint configuration for Epistemos
# Swift 6.0 | SwiftUI | @Observable | macOS 26.0+

# ── Included / Excluded Paths ─────────────────────────────────────
included:
  - Epistemos
  - EpistemosTests

excluded:
  - graph-engine
  - epistemos-core
  - omega-ax
  - omega-mcp
  - target
  - build
  - .build
  - .spm-cache
  - "**/*Generated*"
  - "**/*UniFFI*"
  - DerivedData
  - Pods

# ── Enabled Opt-In Rules ──────────────────────────────────────────
opt_in_rules:
  - array_init
  - attributes
  - closure_body_length
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_first_not_nil
  - contains_over_range_nil_comparison
  - convenience_type
  - empty_collection_literal
  - empty_count
  - empty_string
  - enum_case_associated_values_count
  - explicit_init
  - fallthrough
  - fatal_error_message
  - file_name_no_space
  - first_where
  - flatmap_over_map_reduce
  - force_unwrapping
  - identical_operands
  - implicit_return
  - joined_default_parameter
  - last_where
  - legacy_multiple
  - literal_expression_end_indentation
  - lower_acl_than_parent
  - modifier_order
  - multiline_arguments
  - multiline_literal_brackets
  - multiline_parameters
  - nimble_operator
  - nslocalizedstring_key
  - number_separator
  - operator_usage_whitespace
  - overridden_super_call
  - pattern_matching_keywords
  - prefer_self_in_static_references
  - prefer_self_type_over_type_of_self
  - private_action
  - private_outlet
  - prohibited_super_call
  - reduce_into
  - redundant_nil_coalescing
  - redundant_type_annotation
  - return_value_from_void_function
  - sorted_first_last
  - static_operator
  - toggle_bool
  - trailing_closure
  - unavailable_function
  - unneeded_parentheses_in_closure_argument
  - unowned_variable_capture
  - vertical_parameter_alignment_on_call
  - yoda_condition

# ── Disabled Rules ────────────────────────────────────────────────
disabled_rules:
  - todo                          # We use TODO/FIXME during development
  - opening_brace                 # Conflicts with multiline SwiftUI view builders
  - trailing_comma                # Team preference: allow trailing commas
  - type_name                     # UniFFI-generated types may have underscores
  - identifier_name               # Single-letter vars (x, y, i) common in geometry/Metal code
  - large_tuple                   # Some FFI return types are tuples
  - nesting                       # SwiftUI views nest deeply by design
  - function_body_length          # Complex SwiftUI body properties can be long

# ── Rule Configuration ────────────────────────────────────────────
line_length:
  warning: 140
  error: 200
  ignores_urls: true
  ignores_comments: true
  ignores_function_declarations: false

file_length:
  warning: 500
  error: 1000
  ignore_comment_only_lines: true

type_body_length:
  warning: 400
  error: 800

function_parameter_count:
  warning: 6
  error: 9

cyclomatic_complexity:
  warning: 15
  error: 25

# Modifier order consistent with Swift 6.0 conventions
modifier_order:
  preferred_modifier_order:
    - acl
    - setterACL
    - override
    - dynamic
    - mutating
    - nonmutating
    - lazy
    - final
    - required
    - convenience
    - typeMethods
    - owned

# Multiline arguments: next-line style for SwiftUI
multiline_arguments:
  only_enforce_after_first_closure_on_first_line: true

# ── Reporter ──────────────────────────────────────────────────────
reporter: "xcode"
```

## 1.4 Implementation Checklist

Follow these steps in order. Each step is a single commit.

| Step | Action | Files Created/Modified |
|------|--------|-----------------------|
| 1 | Create `.github/workflows/` directory | `.github/workflows/` |
| 2 | Add `ci.yml` (copy from §1.2) | `.github/workflows/ci.yml` |
| 3 | Add `release.yml` (copy from §1.2) | `.github/workflows/release.yml` |
| 4 | Add `lint.yml` (copy from §1.2) | `.github/workflows/lint.yml` |
| 5 | Add Clippy config | `clippy.toml`, `.cargo/config.toml` |
| 6 | Add `[lints.clippy]` to each crate's `Cargo.toml` | `graph-engine/Cargo.toml`, `epistemos-core/Cargo.toml`, `omega-ax/Cargo.toml`, `omega-mcp/Cargo.toml` |
| 7 | Install SwiftLint locally: `brew install swiftlint` | — |
| 8 | Add `.swiftlint.yml` (copy from §1.3) | `.swiftlint.yml` |
| 9 | Run `swiftlint lint` locally, fix auto-fixable issues: `swiftlint lint --fix` | Various `.swift` files |
| 10 | Run `cargo clippy` in each crate, fix warnings | Various `.rs` files |
| 11 | Run `cargo fmt` in each crate | Various `.rs` files |
| 12 | Push to a branch, open PR, verify CI passes | — |
| 13 | Merge PR, verify `ci.yml` runs on main push | — |
| 14 | Test release: `git tag v0.1.0-alpha && git push --tags` | — |

**Secrets to configure in GitHub repo settings (Settings → Secrets and variables → Actions):**

- None required for unsigned builds.
- For future signed builds: `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_TEAM_ID`, `APPLE_SIGNING_IDENTITY`, `NOTARIZATION_APPLE_ID`, `NOTARIZATION_PASSWORD`, `NOTARIZATION_TEAM_ID`.

---

# Part 2: VLM Agent Desktop (Autonomous Desktop Control)

## 2.1 Vision

The VLM Agent Desktop enables Epistemos agents to autonomously control a **separate macOS desktop environment** — isolated from the user's active workspace. An agent perceives this desktop via Vision-Language Model (VLM) analysis of screenshots combined with Accessibility (AX) tree extraction, reasons about the current state using the local LLM, executes actions via CGEvent injection and AXUIElement APIs, and verifies outcomes by re-capturing the screen.

The user watches the agent work via a Picture-in-Picture (PiP) Metal view embedded in the Epistemos app. The agent never moves the user's mouse, never types into the user's focused window, and never disrupts the user's workflow.

## 2.2 macOS Desktop Isolation Architecture

### Approach A: macOS Spaces (Mission Control)

macOS Spaces are virtual desktops managed by Mission Control. Each Space has its own set of visible windows.

**Mechanism:**
- Create a new Space programmatically via AppleScript driving System Events:

```swift
func createAgentSpace() async throws {
    let script = """
    do shell script "open -b 'com.apple.exposelauncher'"
    delay 0.3
    tell application id "com.apple.systemevents"
        tell (every application process whose bundle identifier = "com.apple.dock") to ¬
            click (button 1 of group 2 of group 1 of group 1)
        delay 0.3
        key code 53  -- Esc to dismiss Mission Control
    end tell
    """
    let appleScript = NSAppleScript(source: script)!
    var error: NSDictionary?
    appleScript.executeAndReturnError(&error)
    if let error { throw AgentDesktopError.spaceCreationFailed(error) }
}
```

- Assign agent windows to a dedicated Space using `NSWindow.collectionBehavior`:

```swift
agentWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
```

- Switch to a specific Space using keyboard simulation:

```swift
func switchToSpace(index: Int) {
    // Ctrl + <number> to switch to Space N (requires System Preferences setup)
    let keyCode: CGKeyCode = CGKeyCode(18 + index)  // 1=18, 2=19, etc.
    let ctrlDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
    ctrlDown.flags = .maskControl
    ctrlDown.post(tap: .cghidEventTap)
    let ctrlUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
    ctrlUp.flags = .maskControl
    ctrlUp.post(tap: .cghidEventTap)
}
```

**Pros:** Lightweight, same user session, shared filesystem, shared process space.  
**Cons:** Relies on AppleScript UI scripting (fragile); user can accidentally switch into agent's Space; CGEvent injection affects the active Space globally — mouse/keyboard events go to whichever Space is currently frontmost.

### Approach B: Virtual Display (Headless Rendering)

Create a virtual/offscreen display that exists in the window server but has no physical monitor.

**Mechanism:**
- Use `CGVirtualDisplay` (private API available since macOS 14) or a `CGVirtualDisplayDescriptor` to register a headless display with the system.
- Apps launched on this display render normally but are invisible to the user.
- ScreenCaptureKit's `SCDisplay` can capture the virtual display's framebuffer.
- CGEvent injection can target specific display coordinates.

**Pros:** Complete visual isolation; agent display never appears on user's physical screen; true parallel operation.  
**Cons:** `CGVirtualDisplay` is private API (no App Store, may break across OS versions); limited app compatibility for some Cocoa apps that detect display properties; complex coordinate mapping.

### Approach C: Separate User Session (Fast User Switching)

Create a dedicated macOS user account. Agent runs in a background login session.

**Pros:** OS-level process and filesystem isolation; full desktop environment.  
**Cons:** Heavy resource overhead (~1-2 GB RAM per session); requires admin privileges to create users; IPC across user boundaries is restricted; cannot easily share SwiftData containers.

### Recommended Approach: Hybrid — Dedicated Space + ScreenCaptureKit PiP

This provides the best balance of isolation, reliability, and user experience:

1. **Agent gets a dedicated macOS Space.** Created at session start. All agent-controlled windows are assigned to this Space.
2. **Agent actions execute only when the agent's Space is active.** The system briefly switches to the agent's Space (programmatically), performs the action, and switches back — or, preferably, uses `AXUIElement`-based actions that work regardless of frontmost Space.
3. **ScreenCaptureKit captures the agent's windows** (using window-level filtering, not display-level) regardless of which Space is active. This means the user can stay on their own Space while the agent's screen is continuously captured for VLM perception.
4. **A Metal PiP view** in the Epistemos app renders the captured frames, giving the user a live feed of the agent's desktop.

**Why this works:** ScreenCaptureKit can capture specific windows by `SCWindow` reference even when those windows are on a different Space. AXUIElement actions (click, setValue, press) operate on the element directly without requiring the element's window to be frontmost. The agent only needs CGEvent-level injection (raw mouse/keyboard) as a fallback for apps with poor AX support.

## 2.3 VLM Perception Pipeline

### Screenshot Capture

**File: `Epistemos/Services/AgentDesktop/AgentScreenCapture.swift`**

```swift
import ScreenCaptureKit
import CoreImage

@Observable
final class AgentScreenCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var latestFrame: CGImage?
    private let captureQueue = DispatchQueue(label: "com.epistemos.agent.capture", qos: .userInitiated)
    
    /// Target windows belonging to the agent's Space
    private var agentWindows: [SCWindow] = []
    
    /// Frame rate: 2-5 FPS for VLM perception (not video streaming)
    let framesPerSecond: Int = 3
    
    /// Resolution: Downscale for VLM input efficiency
    let captureWidth: Int = 1280
    let captureHeight: Int = 720
    
    func startCapture(forWindows windows: [SCWindow]) async throws {
        agentWindows = windows
        
        let filter = SCContentFilter(
            desktopIndependentWindow: windows.first!  // primary agent window
        )
        
        let config = SCStreamConfiguration()
        config.width = captureWidth
        config.height = captureHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(framesPerSecond))
        config.showsCursor = true       // Agent needs to see cursor position
        config.capturesAudio = false    // No audio needed for VLM
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 3          // Small buffer, we want latest frame
        
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
        try await stream?.startCapture()
    }
    
    func stopCapture() async {
        try? await stream?.stopCapture()
        stream = nil
    }
    
    /// SCStreamOutput callback — receives frames
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            latestFrame = cgImage
        }
    }
    
    /// Get current frame as JPEG Data for VLM input
    func captureSnapshot() -> Data? {
        guard let cgImage = latestFrame else { return nil }
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: captureWidth, height: captureHeight))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.80])
    }
}
```

### Screen Understanding — Dual-Channel Perception

Extend the existing `Screen2AXFusion.swift` to support agent-specific capture:

**File: `Epistemos/Services/Omega/Screen2AXFusion+Agent.swift`**

```swift
extension Screen2AXFusion {
    
    /// Perception result combining VLM output + AX tree
    struct AgentPerception {
        let screenshot: Data              // JPEG bytes
        let vlmDescription: String        // Natural language description from VLM
        let axElements: [AXElementInfo]   // Structured AX tree
        let fusedElements: [UIElement]    // Merged: VLM semantics + AX coordinates
        let timestamp: Date
    }
    
    struct UIElement: Codable {
        let role: String           // "button", "textField", "staticText", etc.
        let label: String          // Human-readable label
        let value: String?         // Current value (for text fields, etc.)
        let frame: CGRect          // Screen coordinates
        let isEnabled: Bool
        let isClickable: Bool
        let axRef: String?         // AXUIElement reference path for direct action
        let vlmConfidence: Float   // How confident VLM is about this element
    }
    
    /// Perform dual-channel perception on the agent's desktop
    func perceiveAgentDesktop(capture: AgentScreenCapture, app: NSRunningApplication?) async throws -> AgentPerception {
        // Channel 1: Screenshot → VLM analysis
        guard let screenshotData = capture.captureSnapshot() else {
            throw PerceptionError.captureUnavailable
        }
        
        let vlmPrompt = """
        Analyze this macOS desktop screenshot. List every visible UI element with:
        - type (button, text field, menu item, label, checkbox, etc.)
        - approximate position (top-left, center, bottom-right, or pixel coordinates)
        - current state (enabled/disabled, checked/unchecked, selected, focused)
        - visible text content
        - what clicking it would likely do
        Format as JSON array.
        """
        
        let vlmResult = try await inferenceState.analyzeImage(screenshotData, prompt: vlmPrompt)
        
        // Channel 2: AX tree extraction
        var axElements: [AXElementInfo] = []
        if let app {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            axElements = extractAXTree(from: axApp, maxDepth: 8)
        }
        
        // Fusion: merge VLM semantic understanding with AX ground truth
        let fusedElements = fusePerception(vlmOutput: vlmResult, axTree: axElements)
        
        return AgentPerception(
            screenshot: screenshotData,
            vlmDescription: vlmResult,
            axElements: axElements,
            fusedElements: fusedElements,
            timestamp: Date()
        )
    }
    
    /// Extract AX tree from an application
    private func extractAXTree(from element: AXUIElement, maxDepth: Int, depth: Int = 0) -> [AXElementInfo] {
        guard depth < maxDepth else { return [] }
        
        var results: [AXElementInfo] = []
        
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        var position: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        
        var size: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        var enabled: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled)
        
        var point = CGPoint.zero
        var sz = CGSize.zero
        if let position { AXValueGetValue(position as! AXValue, .cgPoint, &point) }
        if let size { AXValueGetValue(size as! AXValue, .cgSize, &sz) }
        
        let info = AXElementInfo(
            role: (role as? String) ?? "unknown",
            title: title as? String,
            value: value as? String,
            frame: CGRect(origin: point, size: sz),
            isEnabled: (enabled as? Bool) ?? true
        )
        results.append(info)
        
        // Recurse into children
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childArray = children as? [AXUIElement] {
            for child in childArray {
                results.append(contentsOf: extractAXTree(from: child, maxDepth: maxDepth, depth: depth + 1))
            }
        }
        
        return results
    }
}
```

### Action Space

**File: `Epistemos/Services/AgentDesktop/AgentAction.swift`**

```swift
/// Complete action vocabulary for the desktop agent
enum AgentAction: Codable {
    case click(x: Double, y: Double)
    case doubleClick(x: Double, y: Double)
    case rightClick(x: Double, y: Double)
    case drag(fromX: Double, fromY: Double, toX: Double, toY: Double)
    case typeText(String)
    case keyPress(key: String, modifiers: [KeyModifier])
    case scroll(x: Double, y: Double, deltaX: Double, deltaY: Double)
    case openApp(bundleId: String)
    case switchSpace(index: Int)
    case screenshot
    case wait(seconds: Double)
    case axAction(elementPath: String, action: String)  // AX-based action (more reliable)
    
    enum KeyModifier: String, Codable {
        case cmd, shift, option, control, fn
    }
    
    /// Estimated execution time (for scheduling and timeout calculation)
    var estimatedDuration: TimeInterval {
        switch self {
        case .click, .doubleClick, .rightClick: return 0.3
        case .drag: return 0.8
        case .typeText(let text): return Double(text.count) * 0.03
        case .keyPress: return 0.2
        case .scroll: return 0.4
        case .openApp: return 3.0
        case .switchSpace: return 1.0
        case .screenshot: return 0.5
        case .wait(let s): return s
        case .axAction: return 0.5
        }
    }
}
```

### Action Execution

**File: `Epistemos/Services/AgentDesktop/AgentActionExecutor.swift`**

```swift
import CoreGraphics
import AppKit

actor AgentActionExecutor {
    
    private let retinaScale: CGFloat = 2.0  // Retina display scaling factor
    
    /// Execute a single action. Returns true if execution succeeded mechanically.
    func execute(_ action: AgentAction) async throws -> Bool {
        switch action {
        case .click(let x, let y):
            return postMouseEvent(type: .leftMouseDown, at: scalePoint(x, y))
                && postMouseEvent(type: .leftMouseUp, at: scalePoint(x, y))
            
        case .doubleClick(let x, let y):
            let pt = scalePoint(x, y)
            postMouseEvent(type: .leftMouseDown, at: pt, clickCount: 1)
            postMouseEvent(type: .leftMouseUp, at: pt, clickCount: 1)
            postMouseEvent(type: .leftMouseDown, at: pt, clickCount: 2)
            return postMouseEvent(type: .leftMouseUp, at: pt, clickCount: 2)
            
        case .rightClick(let x, let y):
            return postMouseEvent(type: .rightMouseDown, at: scalePoint(x, y))
                && postMouseEvent(type: .rightMouseUp, at: scalePoint(x, y))
            
        case .drag(let fx, let fy, let tx, let ty):
            let from = scalePoint(fx, fy)
            let to = scalePoint(tx, ty)
            postMouseEvent(type: .leftMouseDown, at: from)
            // Interpolate drag path for smooth movement
            let steps = 20
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let mid = CGPoint(
                    x: from.x + (to.x - from.x) * t,
                    y: from.y + (to.y - from.y) * t
                )
                postMouseEvent(type: .leftMouseDragged, at: mid)
                try await Task.sleep(for: .milliseconds(10))
            }
            return postMouseEvent(type: .leftMouseUp, at: to)
            
        case .typeText(let text):
            return typeString(text)
            
        case .keyPress(let key, let modifiers):
            return pressKey(key, modifiers: modifiers)
            
        case .scroll(let x, let y, let dx, let dy):
            let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: Int32(dy),
                wheel2: Int32(dx)
            )
            event?.location = scalePoint(x, y)
            event?.post(tap: .cghidEventTap)
            return true
            
        case .openApp(let bundleId):
            let config = NSWorkspace.OpenConfiguration()
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                try await NSWorkspace.shared.openApplication(at: url, configuration: config)
                return true
            }
            return false
            
        case .switchSpace(let index):
            switchToSpace(index: index)
            return true
            
        case .screenshot:
            return true  // Handled by capture pipeline, not executor
            
        case .wait(let seconds):
            try await Task.sleep(for: .seconds(seconds))
            return true
            
        case .axAction(let elementPath, let actionName):
            return performAXAction(elementPath: elementPath, action: actionName)
        }
    }
    
    // ── Private Helpers ──────────────────────────────────────────
    
    /// Convert VLM coordinates (1280x720 space) → screen coordinates (Retina-scaled)
    private func scalePoint(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x, y: y)  // ScreenCaptureKit already maps to point coordinates
    }
    
    @discardableResult
    private func postMouseEvent(type: CGEventType, at point: CGPoint, clickCount: Int64 = 1) -> Bool {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: type.rawValue >= CGEventType.rightMouseDown.rawValue ? .right : .left
        ) else { return false }
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event.post(tap: .cghidEventTap)
        return true
    }
    
    private func typeString(_ text: String) -> Bool {
        for character in text {
            let str = String(character)
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { return false }
            event.keyboardSetUnicodeString(stringLength: str.count, unicodeString: Array(str.utf16))
            event.post(tap: .cghidEventTap)
            
            let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            upEvent?.post(tap: .cghidEventTap)
        }
        return true
    }
    
    private func pressKey(_ key: String, modifiers: [AgentAction.KeyModifier]) -> Bool {
        guard let keyCode = keyCodeMap[key.lowercased()] else { return false }
        
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod {
            case .cmd: flags.insert(.maskCommand)
            case .shift: flags.insert(.maskShift)
            case .option: flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .fn: flags.insert(.maskSecondaryFn)
            }
        }
        
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        down.flags = flags
        down.post(tap: .cghidEventTap)
        
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
        up.flags = flags
        up.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func switchToSpace(index: Int) {
        // Ctrl+<number> — requires "Keyboard > Shortcuts > Mission Control" enabled
        let keyCode = CGKeyCode(18 + index)  // 1=18, 2=19, 3=20, etc.
        let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        down.flags = .maskControl
        down.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
        up.flags = .maskControl
        up.post(tap: .cghidEventTap)
    }
    
    private func performAXAction(elementPath: String, action: String) -> Bool {
        // Element path format: "app:com.apple.Safari/window:0/button:Done"
        // Implementation resolves path to AXUIElement and performs action
        // This is a stub — full implementation requires AX tree traversal
        return false
    }
    
    /// Map of common key names → CGKeyCode values
    private let keyCodeMap: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96,
    ]
}
```

## 2.4 Agent Loop Architecture

**File: `Epistemos/Services/AgentDesktop/AgentDesktopLoop.swift`**

```
┌─────────────────────────────────────────────┐
│              AGENT DESKTOP LOOP              │
│                                              │
│  1. PERCEIVE                                 │
│     └─ ScreenCapture → VLM + AX Tree        │
│                                              │
│  2. THINK                                    │
│     └─ LLM reasons about current state       │
│     └─ Plans next action(s)                  │
│     └─ Checks against goal/task              │
│                                              │
│  3. ACT                                      │
│     └─ Execute action via CGEvent/AX API     │
│     └─ Wait for UI to settle (300-500ms)     │
│                                              │
│  4. VERIFY                                   │
│     └─ Re-capture screen                     │
│     └─ Check if action succeeded             │
│     └─ If failed, retry or replan            │
│                                              │
│  5. LOG                                      │
│     └─ Record action + screenshot to trace   │
│     └─ Update task graph progress            │
│     └─ Emit event to user's EventBus         │
│                                              │
│  Loop until: task complete OR max steps OR   │
│              user cancellation OR error       │
└─────────────────────────────────────────────┘
```

**State machine for the loop:**

```
                ┌──────────┐
                │  IDLE    │
                └────┬─────┘
                     │ startTask(goal)
                     ▼
                ┌──────────┐
           ┌───►│ PERCEIVE │
           │    └────┬─────┘
           │         │ perception ready
           │         ▼
           │    ┌──────────┐
           │    │  THINK   │
           │    └────┬─────┘
           │         │ action planned
           │         ▼
           │    ┌───────────────┐
           │    │ CONFIRM_GATE? │──── destructive? ──► WAITING_CONFIRMATION
           │    └───────┬───────┘                              │
           │            │ safe / confirmed                     │ user approves
           │            ▼                                      ▼
           │    ┌──────────┐◄──────────────────────────────────┘
           │    │   ACT    │
           │    └────┬─────┘
           │         │ action executed
           │         ▼
           │    ┌──────────┐
           │    │  VERIFY  │
           │    └────┬─────┘
           │         │
           │    ┌────┴────┐
           │    │ success? │
           │    └─┬─────┬─┘
           │      │ yes │ no (retry < 3)
           │      │     └───► PERCEIVE (retry)
           │      ▼
           │    ┌──────────┐
           │    │   LOG    │
           │    └────┬─────┘
           │         │
           │    ┌────┴──────┐
           │    │ goal met? │
           │    └─┬───────┬─┘
           │      │ no    │ yes
           └──────┘       ▼
                    ┌──────────┐
                    │ COMPLETE │
                    └──────────┘
```

```swift
actor AgentDesktopLoop {
    
    // ── Configuration ────────────────────────────────────────────
    let maxIterations = 100            // Hard cap on loop iterations
    let maxRetries = 3                 // Retries per action before replanning
    let uiSettleDelay: Duration = .milliseconds(400)  // Wait for UI after action
    let perceptionTimeout: Duration = .seconds(10)
    let thinkTimeout: Duration = .seconds(30)
    let totalTimeout: Duration = .minutes(15)  // Max session duration
    
    // ── Dependencies ─────────────────────────────────────────────
    let capture: AgentScreenCapture
    let executor: AgentActionExecutor
    let perception: Screen2AXFusion
    let inference: InferenceState       // Shared LLM service
    let orchestrator: OrchestratorState
    let eventBus: EventBus
    let confirmationGate: ConfirmationGate
    
    // ── State ────────────────────────────────────────────────────
    private(set) var state: LoopState = .idle
    private(set) var iteration: Int = 0
    private var trace: [DesktopTraceEntry] = []
    private var currentGoal: String = ""
    private var cancellationToken: Bool = false
    
    enum LoopState: String, Codable {
        case idle, perceiving, thinking, confirmationWait, acting, verifying, logging
        case completed, failed, cancelled, timedOut
    }
    
    struct DesktopTraceEntry: Codable {
        let iteration: Int
        let timestamp: Date
        let perception: String       // Summarized perception
        let reasoning: String        // LLM's chain-of-thought
        let action: AgentAction
        let success: Bool
        let screenshotPath: String?  // File path to saved screenshot
    }
    
    /// Main entry point: run the agent loop for a given goal
    func run(goal: String, profileId: UUID) async throws -> DesktopSessionResult {
        currentGoal = goal
        state = .perceiving
        iteration = 0
        trace = []
        cancellationToken = false
        
        let sessionStart = Date()
        
        defer {
            state = [.completed, .failed, .cancelled, .timedOut].contains(state) ? state : .failed
        }
        
        while iteration < maxIterations && !cancellationToken {
            // Check total timeout
            if Date().timeIntervalSince(sessionStart) > totalTimeout.seconds {
                state = .timedOut
                break
            }
            
            iteration += 1
            
            // ── 1. PERCEIVE ──────────────────────────────────────
            state = .perceiving
            let percept = try await withTimeout(perceptionTimeout) {
                try await self.perception.perceiveAgentDesktop(
                    capture: self.capture,
                    app: nil  // TODO: track target app
                )
            }
            
            // ── 2. THINK ─────────────────────────────────────────
            state = .thinking
            let plan = try await withTimeout(thinkTimeout) {
                try await self.planNextAction(goal: goal, perception: percept, history: self.trace)
            }
            
            // Check if LLM says the goal is complete
            if plan.goalComplete {
                state = .completed
                break
            }
            
            // ── 3. CONFIRM (if destructive) ──────────────────────
            if plan.action.isDestructive {
                state = .confirmationWait
                let approved = await confirmationGate.request(
                    action: plan.action.humanDescription,
                    context: "Agent wants to: \(plan.action.humanDescription)"
                )
                guard approved else {
                    state = .cancelled
                    break
                }
            }
            
            // ── 4. ACT ──────────────────────────────────────────
            state = .acting
            let success = try await executor.execute(plan.action)
            
            // Wait for UI to settle after action
            try await Task.sleep(for: uiSettleDelay)
            
            // ── 5. VERIFY ────────────────────────────────────────
            state = .verifying
            var actionSuccess = success
            if success {
                let verifyPercept = try await perception.perceiveAgentDesktop(
                    capture: capture, app: nil
                )
                actionSuccess = try await verifyAction(
                    expected: plan.expectedOutcome,
                    actual: verifyPercept
                )
            }
            
            // ── 6. LOG ──────────────────────────────────────────
            state = .logging
            let entry = DesktopTraceEntry(
                iteration: iteration,
                timestamp: Date(),
                perception: percept.vlmDescription.prefix(500).description,
                reasoning: plan.reasoning,
                action: plan.action,
                success: actionSuccess,
                screenshotPath: saveScreenshot(percept.screenshot, iteration: iteration)
            )
            trace.append(entry)
            
            // Emit event to user's EventBus
            await eventBus.emit(.agentDesktopAction(
                profileId: profileId,
                action: plan.action.humanDescription,
                iteration: iteration,
                success: actionSuccess
            ))
        }
        
        if iteration >= maxIterations {
            state = .timedOut
        }
        
        return DesktopSessionResult(
            goal: goal,
            outcome: state,
            iterations: iteration,
            trace: trace,
            duration: Date().timeIntervalSince(sessionStart)
        )
    }
    
    /// User-initiated cancellation
    func cancel() {
        cancellationToken = true
        state = .cancelled
    }
    
    /// Pause the loop (user can resume later)
    func pause() { cancellationToken = true; state = .idle }
    
    // ── Private Planning ─────────────────────────────────────────
    
    private func planNextAction(
        goal: String,
        perception: Screen2AXFusion.AgentPerception,
        history: [DesktopTraceEntry]
    ) async throws -> ActionPlan {
        let prompt = """
        You are an autonomous macOS desktop agent. Your goal: \(goal)
        
        Current screen state:
        \(perception.vlmDescription)
        
        Available UI elements:
        \(perception.fusedElements.map { "- \($0.role): \"\($0.label)\" at (\($0.frame.origin.x), \($0.frame.origin.y)) enabled=\($0.isEnabled)" }.joined(separator: "\n"))
        
        Recent action history (last 5):
        \(history.suffix(5).map { "  Step \($0.iteration): \($0.action) → \($0.success ? "success" : "failed")" }.joined(separator: "\n"))
        
        Respond in JSON:
        {
          "reasoning": "step-by-step thinking about what to do next",
          "action": { ... },  // one of: click, typeText, keyPress, openApp, etc.
          "expectedOutcome": "what the screen should look like after this action",
          "goalComplete": false  // true if the goal has been achieved
        }
        """
        
        let response = try await inference.complete(prompt: prompt)
        return try JSONDecoder().decode(ActionPlan.self, from: Data(response.utf8))
    }
    
    private func verifyAction(expected: String, actual: Screen2AXFusion.AgentPerception) async throws -> Bool {
        let prompt = """
        Expected screen state after action: \(expected)
        Actual screen state: \(actual.vlmDescription)
        Did the action succeed? Respond with JSON: {"success": true/false, "reason": "..."}
        """
        let response = try await inference.complete(prompt: prompt)
        let result = try JSONDecoder().decode(VerifyResult.self, from: Data(response.utf8))
        return result.success
    }
}
```

## 2.5 Integration with Existing Omega System

| Existing File | Modification |
|---|---|
| `MCPBridge.swift` | Add new tool category `"desktop"` with tools: `desktop_click`, `desktop_type`, `desktop_screenshot`, `desktop_open_app`, `desktop_scroll`. Register these in the MCP tool registry so agents can invoke desktop actions through the standard MCP protocol. |
| `OmegaPermissions.swift` | Add `.desktopControl` to the `OmegaPermission` enum. The agent must hold this permission before the `AgentDesktopLoop` can start. Check via `OmegaPermissions.shared.check(.desktopControl)`. |
| `DualBrainRouter.swift` | Add routing logic: if the task involves visual understanding of screen content (keywords: "see", "look at", "what's on screen", "click", "navigate"), route to the VLM pipeline. If the task is purely textual, route to the standard LLM path. |
| `OrchestratorState.swift` | Add new state `.desktopAgentRunning(profileId: UUID)` to the orchestrator state enum. When an agent desktop session is active, the orchestrator tracks it alongside other running tasks. |
| `TaskGraph.swift` | Desktop actions become task nodes. Each `AgentAction` executed in the loop creates a `TaskNode` with edges connecting sequential actions. This enables the orchestrator to visualize the agent's execution plan. |
| `Screen2AXFusion.swift` | Extend with `perceiveAgentDesktop()` method (see §2.3). Add support for multi-window capture — the agent may have multiple app windows open across its Space. |
| `EventBus.swift` | Add new event types to `AppEvent`: `.agentDesktopAction(profileId: UUID, action: String, iteration: Int, success: Bool)`, `.agentDesktopSessionStarted(profileId: UUID)`, `.agentDesktopSessionEnded(profileId: UUID, outcome: String)`. |

## 2.6 Entitlements & Permissions

**File: `Epistemos/Epistemos.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- ScreenCaptureKit: required for agent screen capture -->
    <key>com.apple.security.device.screen-capture</key>
    <true/>
    
    <!-- App Sandbox: must be disabled for CGEvent injection and AXUIElement -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
    
    <!-- Hardened Runtime exceptions -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

**TCC (Transparency, Consent, and Control) permissions the user must grant:**

| Permission | macOS Setting | Why Required |
|---|---|---|
| **Screen Recording** | System Settings → Privacy & Security → Screen Recording | ScreenCaptureKit capture of other apps' windows |
| **Accessibility** | System Settings → Privacy & Security → Accessibility | AXUIElement queries, CGEvent injection for mouse/keyboard |
| **Automation** | System Settings → Privacy & Security → Automation | AppleScript control of System Events, creating Spaces |
| **Full Disk Access** | System Settings → Privacy & Security → Full Disk Access | Agent file operations across the filesystem (optional, scope-dependent) |

**Runtime permission request flow:**

```swift
/// Call on first launch of agent desktop feature
func requestDesktopPermissions() async {
    // 1. Screen Recording — ScreenCaptureKit prompts automatically on first SCStream creation
    // 2. Accessibility — check and prompt:
    let trusted = AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt: true] as CFDictionary
    )
    if !trusted {
        // Show in-app guidance: "Open System Settings → Accessibility → enable Epistemos"
    }
    // 3. Automation — prompted automatically on first NSAppleScript execution
}
```

## 2.7 SwiftData Models

**File: `Epistemos/Models/SDAgentDesktopSession.swift`**

```swift
import SwiftData

@Model
final class SDAgentDesktopSession {
    @Attribute(.unique) var id: UUID
    var agentProfileId: UUID
    var spaceIndex: Int
    var goal: String
    var startedAt: Date
    var endedAt: Date?
    var status: String            // "running", "completed", "failed", "cancelled", "timedOut"
    var totalIterations: Int
    var totalActions: Int
    var durationSeconds: Double?
    
    @Relationship(deleteRule: .cascade, inverse: \SDDesktopAction.session)
    var actions: [SDDesktopAction]
    
    init(agentProfileId: UUID, spaceIndex: Int, goal: String) {
        self.id = UUID()
        self.agentProfileId = agentProfileId
        self.spaceIndex = spaceIndex
        self.goal = goal
        self.startedAt = Date()
        self.status = "running"
        self.totalIterations = 0
        self.totalActions = 0
        self.actions = []
    }
}
```

**File: `Epistemos/Models/SDDesktopAction.swift`**

```swift
@Model
final class SDDesktopAction {
    @Attribute(.unique) var id: UUID
    var session: SDAgentDesktopSession?
    var actionType: String         // "click", "typeText", "keyPress", etc.
    var actionPayload: Data        // JSON-encoded AgentAction
    var coordinateX: Double?
    var coordinateY: Double?
    var timestamp: Date
    var screenshotPath: String?    // Relative path to saved screenshot JPEG
    var success: Bool
    var reasoning: String?         // LLM's chain-of-thought for this action
    var iterationNumber: Int
    
    init(actionType: String, actionPayload: Data, timestamp: Date, success: Bool, iterationNumber: Int) {
        self.id = UUID()
        self.actionType = actionType
        self.actionPayload = actionPayload
        self.timestamp = timestamp
        self.success = success
        self.iterationNumber = iterationNumber
    }
}
```

**File: `Epistemos/Models/SDDesktopTrace.swift`**

```swift
@Model
final class SDDesktopTrace {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var goal: String
    var outcome: String            // "success", "failure", "timeout", "cancelled"
    var totalSteps: Int
    var startedAt: Date
    var endedAt: Date
    var summaryNotes: String?      // Auto-generated summary of what the agent did
    
    /// JSON-encoded array of DesktopTraceEntry for full replay
    var traceData: Data
    
    init(sessionId: UUID, goal: String, outcome: String, totalSteps: Int, startedAt: Date, endedAt: Date, traceData: Data) {
        self.id = UUID()
        self.sessionId = sessionId
        self.goal = goal
        self.outcome = outcome
        self.totalSteps = totalSteps
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.traceData = traceData
    }
}
```

## 2.8 Implementation Plan

| Phase | Step | Files | Depends On |
|-------|------|-------|-----------|
| **P0: Foundation** | 1. Set entitlements | `Epistemos.entitlements` | — |
| | 2. Permission request flow | `PermissionsManager.swift` (new) | Step 1 |
| | 3. Screen capture service | `AgentScreenCapture.swift` (new) | Step 2 |
| | 4. Action executor | `AgentActionExecutor.swift` (new) | Step 2 |
| | 5. Action model | `AgentAction.swift` (new) | — |
| **P1: Perception** | 6. AX tree extraction | `Screen2AXFusion+Agent.swift` (new) | Step 3 |
| | 7. VLM perception integration | `Screen2AXFusion+Agent.swift` | Step 6, existing InferenceState |
| | 8. Perception fusion logic | `Screen2AXFusion+Agent.swift` | Step 7 |
| **P2: Agent Loop** | 9. Desktop loop state machine | `AgentDesktopLoop.swift` (new) | Steps 3-8 |
| | 10. Confirmation gate integration | `AgentDesktopLoop.swift` | Step 9, existing ConfirmationGate |
| | 11. Trace recording + persistence | `SDAgentDesktopSession.swift`, `SDDesktopAction.swift`, `SDDesktopTrace.swift` (new) | Step 9 |
| **P3: Integration** | 12. MCP tools registration | `MCPBridge.swift` (modify) | Step 9 |
| | 13. EventBus events | `EventBus.swift` (modify) | Step 9 |
| | 14. Orchestrator state | `OrchestratorState.swift` (modify) | Step 9 |
| **P4: UI** | 15. PiP Metal view | `AgentDesktopPiPView.swift` (new) | Step 3 |
| | 16. Agent activity panel | `AgentActivityView.swift` (new) | Step 11 |

---

# Part 3: Agent Profiles (Multi-Instance Architecture)

## 3.1 Vision

Epistemos's Agent Profiles system turns the app from a single-user knowledge tool into a **multi-agent cognitive platform**. One human user profile coexists with up to 4 agent profiles. Each agent is a separate "brain" that:

- **Owns its own vault** — a separate set of notes and knowledge distinct from the user's vault.
- **Runs its own app instance** — separate SwiftData container with the same schema but isolated data.
- **Performs independent AI inference** — its own context window, its own LoRA adapters, its own conversation history.
- **Can autonomously research, create notes, train models, and build sub-agents.**
- **Communicates** with the user and with other agents through a typed message protocol.
- **Operates on its own desktop** (via Part 2) when granted autonomous desktop control.

Example profiles: "Athena" (Research Agent, specializes in academic literature), "Hermes" (Writing Agent, produces polished prose from rough notes), "Prometheus" (Code Agent, reviews and generates code), "Minerva" (Strategy Agent, synthesizes cross-domain insights).

## 3.2 Data Architecture

### Profile Model

**File: `Epistemos/Models/SDAgentProfile.swift`**

```swift
import SwiftData

@Model
final class SDAgentProfile {
    @Attribute(.unique) var id: UUID
    var name: String                    // e.g., "Athena"
    var role: String                    // e.g., "autonomous researcher"
    var systemPrompt: String            // Full personality + instructions
    var avatarEmoji: String             // 🔬, 📝, 💻, 🎯
    var createdAt: Date
    var isActive: Bool                  // Whether the agent is currently running
    var autonomyLevel: Int              // 1=Passive, 2=Reactive, 3=Proactive, 4=Autonomous
    
    // ── Storage Paths ────────────────────────────────────────────
    /// ~/Library/Application Support/Epistemos/agents/{id}/vault/
    var vaultPath: String
    /// ~/Library/Application Support/Epistemos/agents/{id}/data/
    var containerPath: String
    /// ~/Library/Application Support/Epistemos/agents/{id}/indices/
    var indexPath: String
    
    // ── Adapter Configuration ────────────────────────────────────
    var adapterIds: [UUID]              // LoRA adapters trained for this profile
    var baseModelId: String             // e.g., "Qwen/Qwen2.5-3B-Instruct-4bit"
    
    // ── Resource Limits ──────────────────────────────────────────
    var maxTokenBudget: Int             // Daily inference token budget
    var tokensUsedToday: Int            // Reset at midnight
    var maxDailyActions: Int            // Rate limit on desktop actions
    var actionsUsedToday: Int
    var maxVaultSizeMB: Int             // Disk budget for vault
    
    // ── Permissions ──────────────────────────────────────────────
    var permissionsData: Data           // JSON-encoded AgentPermissions
    
    // ── Desktop ──────────────────────────────────────────────────
    var assignedSpaceIndex: Int?        // macOS Space index for desktop control
    
    // ── Relationships ────────────────────────────────────────────
    @Relationship(deleteRule: .cascade) var conversations: [SDAgentConversation]
    @Relationship(deleteRule: .cascade) var desktopSessions: [SDAgentDesktopSession]
    
    // ── Computed ─────────────────────────────────────────────────
    var permissions: AgentPermissions {
        get { (try? JSONDecoder().decode(AgentPermissions.self, from: permissionsData)) ?? .default }
        set { permissionsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    
    init(name: String, role: String, systemPrompt: String, avatarEmoji: String) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.systemPrompt = systemPrompt
        self.avatarEmoji = avatarEmoji
        self.createdAt = Date()
        self.isActive = false
        self.autonomyLevel = 1
        
        let basePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Epistemos/agents/\(id.uuidString)")
        self.vaultPath = basePath.appendingPathComponent("vault").path
        self.containerPath = basePath.appendingPathComponent("data").path
        self.indexPath = basePath.appendingPathComponent("indices").path
        
        self.adapterIds = []
        self.baseModelId = "Qwen/Qwen2.5-3B-Instruct-4bit"
        self.maxTokenBudget = 100_000
        self.tokensUsedToday = 0
        self.maxDailyActions = 500
        self.actionsUsedToday = 0
        self.maxVaultSizeMB = 500
        self.permissionsData = (try? JSONEncoder().encode(AgentPermissions.default)) ?? Data()
        self.conversations = []
        self.desktopSessions = []
    }
}
```

### Agent Permissions Model

**File: `Epistemos/Models/AgentPermissions.swift`**

```swift
struct AgentPermissions: Codable, Equatable {
    var canAccessInternet: Bool
    var canControlDesktop: Bool
    var canInstallSoftware: Bool
    var canAccessUserVault: Bool          // Read user's notes
    var canModifyUserVault: Bool          // Write to user's notes
    var canCommunicateWithAgents: [UUID]  // Allowed peer agent IDs (empty = none)
    var canTrainAdapters: Bool
    var canCreateSubAgents: Bool          // Future: agents creating agents
    var allowedApps: [String]             // Bundle IDs the agent may control
    var maxDailyActions: Int              // Rate limit on desktop actions
    
    static let `default` = AgentPermissions(
        canAccessInternet: false,
        canControlDesktop: false,
        canInstallSoftware: false,
        canAccessUserVault: true,
        canModifyUserVault: false,
        canCommunicateWithAgents: [],
        canTrainAdapters: true,
        canCreateSubAgents: false,
        allowedApps: [],
        maxDailyActions: 200
    )
    
    /// Maximum permissions (for "Autonomous" level agents, user must explicitly enable)
    static let autonomous = AgentPermissions(
        canAccessInternet: true,
        canControlDesktop: true,
        canInstallSoftware: false,
        canAccessUserVault: true,
        canModifyUserVault: true,
        canCommunicateWithAgents: [],  // Populated dynamically
        canTrainAdapters: true,
        canCreateSubAgents: false,
        allowedApps: ["*"],           // All apps
        maxDailyActions: 1000
    )
}
```

### Inter-Agent Communication

**File: `Epistemos/Models/SDAgentMessage.swift`**

```swift
@Model
final class SDAgentMessage {
    @Attribute(.unique) var id: UUID
    var fromProfileId: UUID        // Sender (UUID.zero = user)
    var toProfileId: UUID          // Recipient (UUID.zero = user)
    var content: String
    var messageType: String        // AgentMessageType raw value
    var timestamp: Date
    var attachedNoteIds: [UUID]    // Notes shared with the message
    var attachedData: Data?        // Serialized query results, handoff context
    var status: String             // "sent", "delivered", "read", "actedUpon"
    var threadId: UUID?            // For threading conversations
    var priority: Int              // 0=normal, 1=high, 2=urgent
    
    init(from: UUID, to: UUID, content: String, type: AgentMessageType) {
        self.id = UUID()
        self.fromProfileId = from
        self.toProfileId = to
        self.content = content
        self.messageType = type.rawValue
        self.timestamp = Date()
        self.attachedNoteIds = []
        self.status = "sent"
        self.priority = 0
    }
}

enum AgentMessageType: String, Codable {
    case query           // Asking another agent a question
    case response        // Answering a query
    case notification    // Broadcasting an update ("I found something interesting")
    case handoff         // Passing a task to another agent
    case sharedNote      // Sharing a note for collaboration
    case statusUpdate    // "I finished researching X"
    case error           // Reporting a failure
}

enum MessageStatus: String, Codable {
    case sent, delivered, read, actedUpon, failed
}
```

### Agent Conversation Model

**File: `Epistemos/Models/SDAgentConversation.swift`**

```swift
@Model
final class SDAgentConversation {
    @Attribute(.unique) var id: UUID
    var profileId: UUID             // Which agent owns this conversation
    var title: String
    var createdAt: Date
    var lastMessageAt: Date
    var isArchived: Bool
    
    @Relationship(deleteRule: .cascade) var messages: [SDAgentConversationMessage]
    
    init(profileId: UUID, title: String) {
        self.id = UUID()
        self.profileId = profileId
        self.title = title
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.isArchived = false
        self.messages = []
    }
}

@Model
final class SDAgentConversationMessage {
    @Attribute(.unique) var id: UUID
    var role: String              // "user", "agent", "system"
    var content: String
    var timestamp: Date
    var tokenCount: Int
    var conversation: SDAgentConversation?
    
    init(role: String, content: String, tokenCount: Int = 0) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.tokenCount = tokenCount
    }
}
```

## 3.3 Isolated Container Architecture

### Separate SwiftData ModelContainer

Each agent profile gets its own `.sqlite` file. The user's main app maintains a registry of all agent containers.

**File: `Epistemos/Services/AgentContainerManager.swift`**

```swift
import SwiftData

@Observable
final class AgentContainerManager {
    
    /// Registry: profileId → ModelContainer
    private var containers: [UUID: ModelContainer] = [:]
    
    /// Schema shared across all containers (same as main app)
    private let agentSchema = Schema([
        SDPage.self, SDBlock.self, SDFolder.self,
        SDChat.self, SDMessage.self,
        SDGraphNode.self, SDGraphEdge.self,
        SDNoteInsight.self, SDPageVersion.self,
        SDWorkspace.self
    ])
    
    /// Get or create a ModelContainer for a specific agent profile
    func container(for profile: SDAgentProfile) throws -> ModelContainer {
        if let existing = containers[profile.id] {
            return existing
        }
        
        // Ensure directory exists
        let containerURL = URL(filePath: profile.containerPath)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        
        let storeURL = containerURL.appendingPathComponent("agent.store")
        let config = ModelConfiguration(
            "AgentStore-\(profile.id.uuidString)",
            schema: agentSchema,
            url: storeURL,
            allowsSave: true
        )
        
        let container = try ModelContainer(for: agentSchema, configurations: [config])
        containers[profile.id] = container
        return container
    }
    
    /// Remove a container when an agent profile is deleted
    func removeContainer(for profileId: UUID) {
        containers.removeValue(forKey: profileId)
    }
    
    /// Migrate all agent containers when schema changes
    func migrateAll(profiles: [SDAgentProfile]) async throws {
        for profile in profiles {
            _ = try container(for: profile)
            // SwiftData handles lightweight migrations automatically
        }
    }
}
```

### Separate Vault Directory

Each agent has its own markdown vault, with an independent `VaultSyncService` instance.

**File: `Epistemos/Services/AgentVaultManager.swift`**

```swift
@Observable
final class AgentVaultManager {
    
    private var vaultServices: [UUID: VaultSyncService] = [:]
    
    /// Initialize vault for an agent profile
    func initializeVault(for profile: SDAgentProfile) throws {
        let vaultURL = URL(filePath: profile.vaultPath)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        
        // Create default structure
        let subdirs = ["notes", "research", "drafts", "inbox"]
        for dir in subdirs {
            try FileManager.default.createDirectory(
                at: vaultURL.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }
        
        // Create welcome note
        let welcomePath = vaultURL.appendingPathComponent("notes/Welcome.md")
        let welcomeContent = """
        # \(profile.name)'s Vault
        
        Role: \(profile.role)
        Created: \(Date().formatted())
        
        This vault is private to \(profile.name). Notes created here are isolated from the user's vault
        unless explicitly shared.
        """
        try welcomeContent.write(to: welcomePath, atomically: true, encoding: .utf8)
        
        // Start sync service for this vault
        let syncService = VaultSyncService(vaultPath: profile.vaultPath)
        vaultServices[profile.id] = syncService
    }
    
    /// Optionally symlink or copy selected user notes into an agent's vault
    func shareUserNotes(_ noteIds: [UUID], to profile: SDAgentProfile, from userVault: String) throws {
        guard profile.permissions.canAccessUserVault else {
            throw AgentError.permissionDenied("Agent does not have vault access permission")
        }
        // Implementation: create symlinks or copies in agent's vault/shared/ directory
    }
    
    func vaultService(for profileId: UUID) -> VaultSyncService? {
        vaultServices[profileId]
    }
}
```

### Separate Search Indices

Each agent gets its own FTS5 and HNSW vector index.

**File: `Epistemos/Services/AgentSearchIndexManager.swift`**

```swift
@Observable
final class AgentSearchIndexManager {
    
    private var ftsIndices: [UUID: FTS5Index] = [:]
    private var vectorIndices: [UUID: HNSWIndex] = [:]
    
    func initializeIndices(for profile: SDAgentProfile) throws {
        let indexURL = URL(filePath: profile.indexPath)
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        
        // GRDB FTS5 index
        let ftsPath = indexURL.appendingPathComponent("fts5.sqlite")
        let fts = try FTS5Index(path: ftsPath.path)
        ftsIndices[profile.id] = fts
        
        // HNSW vector index
        let hnswPath = indexURL.appendingPathComponent("vectors.hnsw")
        let hnsw = try HNSWIndex(path: hnswPath.path, dimensions: 384)  // Match embedding dim
        vectorIndices[profile.id] = hnsw
    }
    
    func ftsIndex(for profileId: UUID) -> FTS5Index? { ftsIndices[profileId] }
    func vectorIndex(for profileId: UUID) -> HNSWIndex? { vectorIndices[profileId] }
}
```

### Separate LoRA Adapters

**File: `Epistemos/Services/AgentAdapterManager.swift`**

```swift
@Observable
final class AgentAdapterManager {
    
    /// Get the adapter directory for a specific agent
    func adapterDirectory(for profile: SDAgentProfile) -> URL {
        URL(filePath: profile.containerPath)
            .deletingLastPathComponent()
            .appendingPathComponent("adapters")
    }
    
    /// Train a new LoRA adapter for an agent based on its vault content
    func trainAdapter(for profile: SDAgentProfile, trainingData: [TrainingSample]) async throws -> UUID {
        let adapterId = UUID()
        let adapterDir = adapterDirectory(for: profile)
            .appendingPathComponent(adapterId.uuidString)
        try FileManager.default.createDirectory(at: adapterDir, withIntermediateDirectories: true)
        
        // Use MLX LoRA fine-tuning
        // This delegates to the existing ODIA (Overnight Data Intelligence Adaptation) pipeline
        // but scoped to this agent's training data
        let config = LoRAConfig(
            modelId: profile.baseModelId,
            outputDir: adapterDir.path,
            rank: 8,
            alpha: 16,
            epochs: 3,
            batchSize: 4,
            learningRate: 1e-4
        )
        
        try await ODIAService.shared.trainAdapter(config: config, data: trainingData)
        
        return adapterId
    }
    
    /// Load a trained adapter for inference
    func loadAdapter(adapterId: UUID, for profile: SDAgentProfile) throws -> LoRAAdapter {
        let adapterPath = adapterDirectory(for: profile)
            .appendingPathComponent(adapterId.uuidString)
            .appendingPathComponent("adapters.safetensors")
        return try LoRAAdapter(path: adapterPath.path)
    }
}
```

## 3.4 Agent Lifecycle Management

### Creation Flow

**File: `Epistemos/Services/AgentLifecycleManager.swift`**

```swift
@Observable
final class AgentLifecycleManager {
    
    let containerManager: AgentContainerManager
    let vaultManager: AgentVaultManager
    let indexManager: AgentSearchIndexManager
    let adapterManager: AgentAdapterManager
    let runtimeManager: AgentRuntimeManager
    
    /// Create a new agent profile with all supporting infrastructure
    @MainActor
    func createProfile(
        name: String,
        role: String,
        systemPrompt: String,
        emoji: String,
        permissions: AgentPermissions,
        autonomyLevel: Int,
        seedNoteIds: [UUID]? = nil
    ) async throws -> SDAgentProfile {
        // 1. Create the SwiftData model
        let profile = SDAgentProfile(name: name, role: role, systemPrompt: systemPrompt, avatarEmoji: emoji)
        profile.permissions = permissions
        profile.autonomyLevel = autonomyLevel
        
        // 2. Create directory structure
        let dirs = [profile.vaultPath, profile.containerPath, profile.indexPath]
        for dir in dirs {
            try FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true
            )
        }
        
        // 3. Create isolated ModelContainer
        _ = try containerManager.container(for: profile)
        
        // 4. Initialize empty search indices
        try indexManager.initializeIndices(for: profile)
        
        // 5. Initialize vault with default structure
        try vaultManager.initializeVault(for: profile)
        
        // 6. If canAccessUserVault: copy selected user notes
        if let seedNoteIds, permissions.canAccessUserVault {
            try vaultManager.shareUserNotes(seedNoteIds, to: profile, from: userVaultPath)
        }
        
        // 7. Schedule initial LoRA adapter training (async, background)
        if permissions.canTrainAdapters {
            Task.detached(priority: .background) {
                try? await self.adapterManager.trainAdapter(
                    for: profile,
                    trainingData: self.generateSeedTrainingData(from: profile)
                )
            }
        }
        
        // 8. Save to main app's context
        // (caller inserts into main ModelContext)
        
        return profile
    }
    
    /// Delete an agent profile and all its data
    @MainActor
    func deleteProfile(_ profile: SDAgentProfile) async throws {
        // 1. Stop runtime if active
        await runtimeManager.stopAgent(profileId: profile.id)
        
        // 2. Remove container
        containerManager.removeContainer(for: profile.id)
        
        // 3. Delete all files on disk
        let basePath = URL(filePath: profile.vaultPath).deletingLastPathComponent()
        try FileManager.default.removeItem(at: basePath)
        
        // 4. Delete from main ModelContext (caller handles this)
    }
    
    private func generateSeedTrainingData(from profile: SDAgentProfile) -> [TrainingSample] {
        // Generate training samples from the system prompt and role description
        // This creates synthetic Q&A pairs that establish the agent's personality
        return [
            TrainingSample(
                instruction: "What is your role?",
                response: "I am \(profile.name), \(profile.role). \(profile.systemPrompt.prefix(200))"
            ),
            // ... more seed samples generated from systemPrompt
        ]
    }
}
```

### Runtime Management

**File: `Epistemos/Services/AgentRuntimeManager.swift`**

```swift
/// Manages active agent instances. Max 4 concurrent agents.
actor AgentRuntimeManager {
    
    static let maxConcurrentAgents = 4
    
    struct AgentRuntime {
        let profileId: UUID
        let inferenceQueue: AgentInferenceQueue
        let eventStream: AsyncStream<AgentEvent>
        let taskGraph: TaskGraph
        let desktopLoop: AgentDesktopLoop?
        var state: AgentRuntimeState
        
        enum AgentRuntimeState {
            case initializing, idle, thinking, acting, paused, stopping
        }
    }
    
    private var activeAgents: [UUID: AgentRuntime] = [:]
    
    /// Start an agent. Throws if at max capacity.
    func startAgent(profile: SDAgentProfile, dependencies: AgentDependencies) async throws {
        guard activeAgents.count < Self.maxConcurrentAgents else {
            throw AgentError.maxAgentsReached(Self.maxConcurrentAgents)
        }
        guard activeAgents[profile.id] == nil else {
            throw AgentError.alreadyRunning(profile.name)
        }
        
        // Create per-agent inference queue
        let inferenceQueue = AgentInferenceQueue(
            profileId: profile.id,
            adapterIds: profile.adapterIds,
            maxTokenBudget: profile.maxTokenBudget
        )
        
        // Create event stream
        let (stream, continuation) = AsyncStream.makeStream(of: AgentEvent.self)
        
        // Create task graph
        let taskGraph = TaskGraph(ownerId: profile.id)
        
        // Create desktop loop if agent has desktop control permission
        var desktopLoop: AgentDesktopLoop? = nil
        if profile.permissions.canControlDesktop {
            desktopLoop = AgentDesktopLoop(
                capture: dependencies.screenCapture,
                executor: dependencies.actionExecutor,
                perception: dependencies.perception,
                inference: dependencies.inference,
                orchestrator: dependencies.orchestrator,
                eventBus: dependencies.eventBus,
                confirmationGate: dependencies.confirmationGate
            )
        }
        
        let runtime = AgentRuntime(
            profileId: profile.id,
            inferenceQueue: inferenceQueue,
            eventStream: stream,
            taskGraph: taskGraph,
            desktopLoop: desktopLoop,
            state: .idle
        )
        
        activeAgents[profile.id] = runtime
    }
    
    /// Stop an agent and clean up resources
    func stopAgent(profileId: UUID) async {
        guard var runtime = activeAgents[profileId] else { return }
        runtime.state = .stopping
        await runtime.desktopLoop?.cancel()
        runtime.inferenceQueue.shutdown()
        activeAgents.removeValue(forKey: profileId)
    }
    
    /// Get runtime state for UI display
    func runtimeState(for profileId: UUID) -> AgentRuntime.AgentRuntimeState? {
        activeAgents[profileId]?.state
    }
    
    /// GPU time-sharing: round-robin inference slots across active agents
    func nextInferenceSlot() -> AgentInferenceQueue? {
        // Simple round-robin. In production, weight by priority/token budget.
        let agents = Array(activeAgents.values)
        guard !agents.isEmpty else { return nil }
        // Return the agent with the oldest last-inference timestamp
        return agents
            .sorted { $0.inferenceQueue.lastInferenceTime < $1.inferenceQueue.lastInferenceTime }
            .first?.inferenceQueue
    }
}
```

### Agent Autonomy Levels

| Level | Name | Behavior | Permissions Required |
|-------|------|----------|---------------------|
| **1** | **Passive** | Only responds when explicitly asked by the user or another agent. Never initiates actions. Conversation-only. | Minimal |
| **2** | **Reactive** | Monitors its own vault for changes. When new notes appear, it generates insights, tags, and connections automatically. Does not leave its vault. | `canTrainAdapters` |
| **3** | **Proactive** | Can initiate research (internet access required), create notes without being asked, send messages to user or other agents. Scheduled tasks (e.g., "every morning, check for new papers on X"). | `canAccessInternet`, `canCommunicateWithAgents` |
| **4** | **Autonomous** | Full desktop control. Can open apps, browse the web, download files, create content in any app. Operates on its own macOS Space. All actions logged and auditable. | `canControlDesktop`, `canAccessInternet`, `allowedApps` |

These levels are enforced in `AgentRuntimeManager` — the runtime refuses to execute actions beyond the profile's autonomy level.

## 3.5 Communication Protocol

### User ↔ Agent Communication

**Dedicated chat per agent.** Each agent has its own `SDAgentConversation` instances. The UI shows a chat view identical to the existing `ChatState`-driven interface, but backed by the agent's isolated `ModelContainer`.

**@mention anywhere.** In any text field in Epistemos, the user can type `@Athena how does this relate to quantum computing?` and the message is routed to the named agent. The response appears inline or in a notification.

```swift
/// Parse @mentions in user input
func extractMentions(from text: String, profiles: [SDAgentProfile]) -> [(SDAgentProfile, String)] {
    var results: [(SDAgentProfile, String)] = []
    for profile in profiles {
        let pattern = "@\(profile.name)"
        if text.contains(pattern) {
            let query = text.replacingOccurrences(of: pattern, with: "").trimmingCharacters(in: .whitespaces)
            results.append((profile, query))
        }
    }
    return results
}
```

### Agent ↔ Agent Communication

**File: `Epistemos/Services/AgentMessageBus.swift`**

```swift
/// Inter-agent message bus built on top of the existing EventBus
@Observable
final class AgentMessageBus {
    
    private let eventBus: EventBus
    private let modelContext: ModelContext
    
    /// Send a message from one agent to another
    func send(
        from: UUID,
        to: UUID,
        content: String,
        type: AgentMessageType,
        attachedNoteIds: [UUID] = [],
        attachedData: Data? = nil
    ) async throws {
        // Verify sender has permission to communicate with recipient
        // (enforced via AgentPermissions.canCommunicateWithAgents)
        
        let message = SDAgentMessage(from: from, to: to, content: content, type: type)
        message.attachedNoteIds = attachedNoteIds
        message.attachedData = attachedData
        
        modelContext.insert(message)
        try modelContext.save()
        
        // Emit on EventBus so the recipient's runtime can pick it up
        await eventBus.emit(.agentMessage(
            fromId: from,
            toId: to,
            messageId: message.id,
            type: type
        ))
    }
    
    /// Handoff: transfer a task from one agent to another
    func handoff(
        from senderProfile: SDAgentProfile,
        to recipientProfile: SDAgentProfile,
        task: String,
        context: Data
    ) async throws {
        try await send(
            from: senderProfile.id,
            to: recipientProfile.id,
            content: task,
            type: .handoff,
            attachedData: context
        )
    }
    
    /// Share a note between agent vaults
    func shareNote(
        noteId: UUID,
        from senderProfile: SDAgentProfile,
        to recipientProfile: SDAgentProfile
    ) async throws {
        // Copy note from sender's vault to recipient's vault/shared/ directory
        // Then send a .sharedNote message
        try await send(
            from: senderProfile.id,
            to: recipientProfile.id,
            content: "Shared note: \(noteId)",
            type: .sharedNote,
            attachedNoteIds: [noteId]
        )
    }
}
```

### Multi-Agent Task Orchestration

**File: `Epistemos/Services/MultiAgentOrchestrator.swift`**

```swift
/// Decomposes complex tasks into multi-agent workflows
@Observable
final class MultiAgentOrchestrator {
    
    let runtimeManager: AgentRuntimeManager
    let messageBus: AgentMessageBus
    let inference: InferenceState
    
    struct WorkflowStep {
        let agentProfileId: UUID
        let task: String
        let dependsOn: [UUID]      // Step IDs this depends on
        let outputType: OutputType
        
        enum OutputType {
            case notes([UUID])
            case handoffData(Data)
            case notification(String)
        }
    }
    
    /// Decompose a user's high-level task into a multi-agent workflow
    func planWorkflow(task: String, agents: [SDAgentProfile]) async throws -> [WorkflowStep] {
        let prompt = """
        You are a task orchestrator for a multi-agent system.
        Available agents:
        \(agents.map { "- \($0.name) (\($0.role)): \($0.systemPrompt.prefix(100))" }.joined(separator: "\n"))
        
        User's task: \(task)
        
        Decompose this into sequential steps, assigning each to the best agent.
        Output JSON array of steps with: agentName, task, dependsOnStepIndex.
        """
        
        let response = try await inference.complete(prompt: prompt)
        // Parse response into WorkflowStep array
        return try parseWorkflowSteps(response, agents: agents)
    }
    
    /// Execute a planned workflow
    func executeWorkflow(steps: [WorkflowStep]) async throws {
        var completedSteps: Set<UUID> = []
        
        for step in steps {
            // Wait for dependencies
            while !step.dependsOn.allSatisfy({ completedSteps.contains($0) }) {
                try await Task.sleep(for: .seconds(1))
            }
            
            // Send task to agent
            try await messageBus.send(
                from: UUID.zero,  // orchestrator
                to: step.agentProfileId,
                content: step.task,
                type: .handoff
            )
            
            // Wait for agent to signal completion
            // (agent sends .statusUpdate when done)
            // ... event listener logic ...
        }
    }
}
```

**Example workflow decomposition:**

```
User: "Research quantum computing applications in neuroscience,
       write a summary, and create a presentation outline"

Orchestrator decomposes:
  Step 1: Athena (Research Agent) → autonomous web research + note creation
  Step 2: Athena → handoff(findings) → Hermes (Writing Agent)  [depends: Step 1]
  Step 3: Hermes → summarize findings into polished notes       [depends: Step 2]
  Step 4: Hermes → handoff(summary) → Minerva (Strategy Agent)  [depends: Step 3]
  Step 5: Minerva → create presentation outline from summary     [depends: Step 4]
  Step 6: Minerva → notify(user, "Task complete")               [depends: Step 5]
```

## 3.6 UI Design

### Agent Sidebar Panel

**File: `Epistemos/Views/AgentSidebar/AgentSidebarView.swift`**

A new section in the existing sidebar displaying all agent profiles:

```swift
struct AgentSidebarView: View {
    @Environment(AgentLifecycleManager.self) var lifecycleManager
    @Query var profiles: [SDAgentProfile]
    
    var body: some View {
        Section("Agents") {
            ForEach(profiles) { profile in
                AgentSidebarRow(profile: profile)
            }
            
            if profiles.count < AgentRuntimeManager.maxConcurrentAgents {
                Button("Create Agent...") {
                    // Present creation wizard
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct AgentSidebarRow: View {
    let profile: SDAgentProfile
    @Environment(AgentRuntimeManager.self) var runtime
    
    var body: some View {
        HStack {
            Text(profile.avatarEmoji)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(profile.name)
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            
            Spacer()
            
            // Status indicator dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
    
    var statusText: String {
        switch runtime.runtimeState(for: profile.id) {
        case .idle: "Idle"
        case .thinking: "Thinking..."
        case .acting: "Working..."
        case .paused: "Paused"
        case .none: "Offline"
        default: "Active"
        }
    }
    
    var statusColor: Color {
        switch runtime.runtimeState(for: profile.id) {
        case .thinking, .acting: .green
        case .idle: .yellow
        case .paused: .orange
        case .none: .gray
        default: .blue
        }
    }
}
```

### Additional UI Components

| View | File | Purpose |
|------|------|---------|
| **Per-agent chat** | `AgentChatView.swift` | Full conversation interface for each agent, reusing existing ChatView patterns but backed by agent's ModelContainer. |
| **Per-agent vault** | `AgentVaultBrowserView.swift` | File browser for the agent's vault directory. Same layout as user vault browser. |
| **Agent desktop PiP** | `AgentDesktopPiPView.swift` | Metal-rendered live view of the agent's screen capture. Shows what the agent "sees." |
| **Creation wizard** | `AgentCreationWizard.swift` | Multi-step form: name, emoji, role, system prompt, autonomy level, permissions. |
| **Permissions editor** | `AgentPermissionsEditor.swift` | Toggle grid for all AgentPermissions fields. Dangerous permissions (desktop control, internet) have confirmation dialogs. |
| **Multi-agent conversation** | `MultiAgentConversationView.swift` | Timeline view showing inter-agent messages. Color-coded by agent. User can inject messages. |
| **Activity timeline** | `AgentActivityTimelineView.swift` | Chronological log of all agent actions across all profiles. Filterable by agent, action type, time range. |

## 3.7 Integration with Existing Systems

| Existing System | Integration |
|---|---|
| **EventBus.swift** | Add to `AppEvent` enum: `.agentMessage(fromId: UUID, toId: UUID, messageId: UUID, type: AgentMessageType)`, `.agentStatusChange(profileId: UUID, oldState: String, newState: String)`, `.agentDesktopAction(profileId: UUID, action: String, iteration: Int, success: Bool)`, `.agentCreated(profileId: UUID)`, `.agentDeleted(profileId: UUID)` |
| **ChatState.swift** | Extract protocol `ChatStateProtocol` with methods `send(message:)`, `streamResponse()`, `history`. Create `AgentChatState` conforming to same protocol but using agent's container and adapter. |
| **InferenceState.swift** | Add per-agent inference queue support. Each agent gets an `AgentInferenceQueue` that wraps calls to the shared `LLMService` with the agent's LoRA adapter and context window. |
| **LLMService** | Add `complete(prompt:adapterId:)` variant that loads the specified LoRA adapter before inference. Adapters are cached in memory (LRU, max 2 adapters hot). |
| **AdapterRegistry** | Add `profileId` field to adapter metadata. Query adapters by profile: `adapters(for: profileId)`. |
| **NightBrainService** | Schedule ODIA (Overnight Data Intelligence Adaptation) per-agent. Each agent's vault is processed independently. Training runs sequentially to avoid GPU contention: user's adapters first, then each agent in creation order. |
| **MCPBridge.swift** | Per-agent tool access. When an agent invokes an MCP tool, check `AgentPermissions` before execution. Add `agentProfileId` parameter to `MCPBridge.invoke()`. |

## 3.8 Resource Management

### Memory Budget

| Component | Per-Agent Estimate | Notes |
|---|---|---|
| ModelContainer (SwiftData) | 10-50 MB | Depends on vault size |
| FTS5 Index (GRDB) | 5-20 MB | Scales with note count |
| HNSW Vector Index | 20-100 MB | ~384 dims × num vectors |
| Inference Context Window | 50-200 MB | Depends on context length |
| LoRA Adapter (in GPU) | 20-50 MB | 8-rank adapter for 3B model |
| **Total per agent** | **~105-420 MB** | |
| **Total (4 agents + user)** | **~525 MB - 2.1 GB** | Well within 16 GB Apple Silicon |

### GPU Sharing

MLX inference is single-threaded on the GPU. Multiple agents share the GPU via a cooperative scheduling model:

```swift
actor GPUScheduler {
    private var queue: [InferenceRequest] = []
    private var isProcessing = false
    
    func enqueue(request: InferenceRequest) async -> InferenceResponse {
        return await withCheckedContinuation { continuation in
            queue.append(InferenceRequest(
                profileId: request.profileId,
                prompt: request.prompt,
                adapterId: request.adapterId,
                continuation: continuation
            ))
            processNextIfIdle()
        }
    }
    
    private func processNextIfIdle() {
        guard !isProcessing, let next = queue.first else { return }
        queue.removeFirst()
        isProcessing = true
        
        Task {
            // Load adapter if needed (hot-swap)
            if let adapterId = next.adapterId {
                await LLMService.shared.loadAdapter(adapterId)
            }
            
            let response = await LLMService.shared.generate(prompt: next.prompt)
            next.continuation.resume(returning: response)
            isProcessing = false
            processNextIfIdle()
        }
    }
}
```

### Disk Budget

- Each agent vault has a configurable `maxVaultSizeMB` (default: 500 MB).
- Vault size is checked before write operations. If over budget, the agent is notified and must prune or archive old notes.
- Total agent storage is capped at a user-configurable value (default: 5 GB for all agents).

### Token Budget

- Each agent has a `maxTokenBudget` (daily). Default: 100,000 tokens/day.
- Token usage is tracked in `SDAgentProfile.tokensUsedToday`.
- Resets at midnight (local time) via a scheduled task.
- When budget is exhausted, the agent enters a "budget exceeded" state and stops autonomous operations until the next reset.

### Battery Awareness

```swift
extension AgentRuntimeManager {
    func checkBatteryAndThrottle() {
        let info = ProcessInfo.processInfo
        if info.isLowPowerModeEnabled || !info.isExternalPowerConnected {
            // Reduce to max 1 active agent
            // Pause proactive/autonomous agents
            // Keep only passive agents running
            throttleMode = .batterySaver
        } else {
            throttleMode = .full
        }
    }
}
```

## 3.9 Security & Safety

| Rule | Enforcement |
|---|---|
| **Agents cannot escalate permissions** | `AgentPermissions` is immutable from the agent's perspective. Only the user can modify permissions through the UI. Permissions struct is stored in the main app's `ModelContainer`, not the agent's. |
| **Destructive actions require confirmation** | All actions matching a destructive pattern (delete, send email, purchase, execute command) are routed through `ConfirmationGate`. The user sees a modal: "Agent X wants to: [action]. Allow?" |
| **Desktop sessions are recorded** | Every `AgentDesktopSession` saves screenshots and action logs to disk. The user can replay any session like a video. Traces are immutable once written. |
| **Kill switch** | User can click "Stop" on any agent in the sidebar. Calls `AgentRuntimeManager.stopAgent()` which cancels all tasks, closes the desktop loop, and releases resources within 1 second. |
| **Data isolation** | Agents cannot access each other's SwiftData containers or vault directories. The filesystem enforces this (separate directories). Cross-agent communication is exclusively through `AgentMessageBus`. |
| **Rate limiting** | `maxDailyActions` enforced in `AgentActionExecutor`. Action counter checked before every execution. Exceeding the limit pauses the agent. |
| **No self-modification** | Agents cannot modify their own `SDAgentProfile` (system prompt, permissions, autonomy level). These are read-only from the agent's runtime. |

## 3.10 Implementation Plan

| Phase | Step | Files Created/Modified | Depends On |
|-------|------|----------------------|-----------|
| **P0: Models** | 1. SDAgentProfile model | `Models/SDAgentProfile.swift` | — |
| | 2. AgentPermissions model | `Models/AgentPermissions.swift` | — |
| | 3. SDAgentMessage model | `Models/SDAgentMessage.swift` | — |
| | 4. SDAgentConversation model | `Models/SDAgentConversation.swift` | — |
| | 5. Add models to SwiftData schema | `EpistemosApp.swift` (modify) | Steps 1-4 |
| **P1: Container** | 6. AgentContainerManager | `Services/AgentContainerManager.swift` | Step 1 |
| | 7. AgentVaultManager | `Services/AgentVaultManager.swift` | Step 1 |
| | 8. AgentSearchIndexManager | `Services/AgentSearchIndexManager.swift` | Step 1 |
| | 9. AgentAdapterManager | `Services/AgentAdapterManager.swift` | Step 1 |
| **P2: Runtime** | 10. AgentRuntimeManager | `Services/AgentRuntimeManager.swift` | Steps 6-9 |
| | 11. AgentInferenceQueue | `Services/AgentInferenceQueue.swift` | Step 10 |
| | 12. GPUScheduler | `Services/GPUScheduler.swift` | Step 11 |
| | 13. AgentLifecycleManager | `Services/AgentLifecycleManager.swift` | Steps 6-10 |
| **P3: Communication** | 14. AgentMessageBus | `Services/AgentMessageBus.swift` | Step 10 |
| | 15. MultiAgentOrchestrator | `Services/MultiAgentOrchestrator.swift` | Step 14 |
| | 16. EventBus extensions | `EventBus.swift` (modify) | Step 14 |
| **P4: Integration** | 17. ChatState protocol extraction | `ChatState.swift` (modify), `AgentChatState.swift` (new) | Step 10 |
| | 18. InferenceState per-agent | `InferenceState.swift` (modify) | Step 11 |
| | 19. LLMService adapter routing | `LLMService.swift` (modify) | Step 12 |
| | 20. NightBrainService per-agent ODIA | `NightBrainService.swift` (modify) | Step 9 |
| | 21. MCPBridge per-agent permissions | `MCPBridge.swift` (modify) | Step 10 |
| **P5: UI** | 22. AgentSidebarView | `Views/AgentSidebar/AgentSidebarView.swift` | Steps 1, 10 |
| | 23. AgentCreationWizard | `Views/AgentSidebar/AgentCreationWizard.swift` | Step 13 |
| | 24. AgentChatView | `Views/AgentChat/AgentChatView.swift` | Step 17 |
| | 25. AgentPermissionsEditor | `Views/AgentSidebar/AgentPermissionsEditor.swift` | Step 2 |
| | 26. MultiAgentConversationView | `Views/AgentChat/MultiAgentConversationView.swift` | Step 14 |
| | 27. AgentActivityTimelineView | `Views/AgentActivity/AgentActivityTimelineView.swift` | Step 16 |

---

# Appendix

## A. Complete New File List

```
.github/
  workflows/
    ci.yml
    release.yml
    lint.yml

.swiftlint.yml
clippy.toml
.cargo/config.toml

Epistemos/
  Models/
    SDAgentProfile.swift
    AgentPermissions.swift
    SDAgentMessage.swift
    SDAgentConversation.swift
    SDAgentDesktopSession.swift
    SDDesktopAction.swift
    SDDesktopTrace.swift

  Services/
    AgentDesktop/
      AgentScreenCapture.swift
      AgentAction.swift
      AgentActionExecutor.swift
      AgentDesktopLoop.swift
    AgentContainerManager.swift
    AgentVaultManager.swift
    AgentSearchIndexManager.swift
    AgentAdapterManager.swift
    AgentRuntimeManager.swift
    AgentInferenceQueue.swift
    GPUScheduler.swift
    AgentLifecycleManager.swift
    AgentMessageBus.swift
    MultiAgentOrchestrator.swift
    PermissionsManager.swift

  Views/
    AgentSidebar/
      AgentSidebarView.swift
      AgentSidebarRow.swift
      AgentCreationWizard.swift
      AgentPermissionsEditor.swift
    AgentChat/
      AgentChatView.swift
      MultiAgentConversationView.swift
    AgentActivity/
      AgentActivityTimelineView.swift
    AgentDesktop/
      AgentDesktopPiPView.swift
```

**Total new files: 31**

## B. Modified File List

| File | Changes |
|---|---|
| `Epistemos.entitlements` | Add screen capture, disable sandbox |
| `EpistemosApp.swift` | Register new SwiftData models (SDAgentProfile, SDAgentMessage, SDAgentConversation, SDAgentDesktopSession, SDDesktopAction, SDDesktopTrace), instantiate agent managers |
| `EventBus.swift` | Add 5 new AppEvent cases for agent system |
| `ChatState.swift` | Extract `ChatStateProtocol`; existing class conforms to it |
| `InferenceState.swift` | Add per-agent inference queue support, adapter routing |
| `LLMService.swift` | Add `complete(prompt:adapterId:)` method, adapter hot-swap |
| `MCPBridge.swift` | Add `agentProfileId` parameter, permission checking, "desktop" tool category |
| `OmegaPermissions.swift` | Add `.desktopControl` permission |
| `DualBrainRouter.swift` | Add VLM routing for visual tasks |
| `OrchestratorState.swift` | Add `.desktopAgentRunning` state |
| `TaskGraph.swift` | Support desktop action nodes |
| `Screen2AXFusion.swift` | Add `perceiveAgentDesktop()` extension |
| `NightBrainService.swift` | Schedule per-agent ODIA training |
| `project.yml` | Add new source files, new targets if needed |
| `graph-engine/Cargo.toml` | Add `[lints.clippy]` section |
| `epistemos-core/Cargo.toml` | Add `[lints.clippy]` section |
| `omega-ax/Cargo.toml` | Add `[lints.clippy]` section |
| `omega-mcp/Cargo.toml` | Add `[lints.clippy]` section |

**Total modified files: 18**

## C. Dependency Order

Implementation should proceed in this order, respecting dependencies:

```
Phase 1: CI/CD (no code dependencies — can be done first)
  1.1  .github/workflows/ci.yml
  1.2  .github/workflows/lint.yml
  1.3  .github/workflows/release.yml
  1.4  .swiftlint.yml + clippy.toml
  1.5  Cargo.toml lint sections

Phase 2: Foundation Models (all new models, no runtime deps)
  2.1  SDAgentProfile.swift
  2.2  AgentPermissions.swift
  2.3  SDAgentMessage.swift
  2.4  SDAgentConversation.swift
  2.5  SDAgentDesktopSession.swift + SDDesktopAction.swift + SDDesktopTrace.swift
  2.6  Register models in EpistemosApp.swift

Phase 3: Desktop Foundation (depends on Phase 2)
  3.1  Epistemos.entitlements
  3.2  PermissionsManager.swift
  3.3  AgentAction.swift
  3.4  AgentScreenCapture.swift
  3.5  AgentActionExecutor.swift
  3.6  Screen2AXFusion+Agent.swift

Phase 4: Agent Container Infrastructure (depends on Phase 2)
  4.1  AgentContainerManager.swift
  4.2  AgentVaultManager.swift
  4.3  AgentSearchIndexManager.swift
  4.4  AgentAdapterManager.swift

Phase 5: Runtime (depends on Phases 3 + 4)
  5.1  AgentInferenceQueue.swift
  5.2  GPUScheduler.swift
  5.3  AgentRuntimeManager.swift
  5.4  AgentDesktopLoop.swift
  5.5  AgentLifecycleManager.swift

Phase 6: Communication (depends on Phase 5)
  6.1  EventBus.swift modifications
  6.2  AgentMessageBus.swift
  6.3  MultiAgentOrchestrator.swift

Phase 7: Integration (depends on Phase 6)
  7.1  ChatState.swift → protocol extraction + AgentChatState.swift
  7.2  InferenceState.swift modifications
  7.3  LLMService.swift adapter routing
  7.4  MCPBridge.swift modifications
  7.5  OmegaPermissions.swift modifications
  7.6  OrchestratorState.swift modifications
  7.7  NightBrainService.swift modifications

Phase 8: UI (depends on Phase 7)
  8.1  AgentSidebarView.swift + AgentSidebarRow.swift
  8.2  AgentCreationWizard.swift
  8.3  AgentPermissionsEditor.swift
  8.4  AgentChatView.swift
  8.5  AgentDesktopPiPView.swift
  8.6  MultiAgentConversationView.swift
  8.7  AgentActivityTimelineView.swift
```

## D. Testing Strategy

### New Test Suites

| Suite | File | Coverage |
|---|---|---|
| **AgentContainerTests** | `EpistemosTests/Agent/AgentContainerTests.swift` | Container creation, isolation (agent A can't see agent B's data), migration, cleanup |
| **AgentPermissionsTests** | `EpistemosTests/Agent/AgentPermissionsTests.swift` | Permission enforcement — verify agents can't exceed their permissions. Test every permission flag. |
| **AgentMessageBusTests** | `EpistemosTests/Agent/AgentMessageBusTests.swift` | Message sending, delivery, threading, handoff. Verify cross-agent communication respects permissions. |
| **AgentActionTests** | `EpistemosTests/AgentDesktop/AgentActionTests.swift` | Action serialization/deserialization, coordinate transformation, destructive action detection. |
| **AgentDesktopLoopTests** | `EpistemosTests/AgentDesktop/AgentDesktopLoopTests.swift` | Loop state machine transitions, timeout handling, cancellation, max iteration limits. Use mock perception and executor. |
| **AgentLifecycleTests** | `EpistemosTests/Agent/AgentLifecycleTests.swift` | Profile creation (directory structure created), deletion (all data cleaned up), max agent limit enforcement. |
| **GPUSchedulerTests** | `EpistemosTests/Agent/GPUSchedulerTests.swift` | Fair scheduling across agents, adapter hot-swap, queue ordering. |
| **MultiAgentOrchestratorTests** | `EpistemosTests/Agent/MultiAgentOrchestratorTests.swift` | Workflow decomposition, dependency resolution, execution ordering. |
| **CI Workflow Tests** | Run via `scripts/ci_test.sh` | Existing pattern — extend to include new test suites. |

### Testing Approach

- **Unit tests** for all models, permissions, and pure logic (serialization, coordination, scheduling).
- **Integration tests** for container isolation (create 2 agents, verify data doesn't leak).
- **Mock-based tests** for the desktop loop (mock `AgentScreenCapture`, mock `AgentActionExecutor`, mock `InferenceState` to return canned VLM responses).
- **No UI tests initially** — SwiftUI views are thin wrappers around state; test the state objects.

---

*End of specification. This document is the single source of truth for implementing CI/CD, VLM Agent Desktop, and Agent Profiles in Epistemos. All code sketches are illustrative — adapt to the existing codebase's conventions and patterns.*
