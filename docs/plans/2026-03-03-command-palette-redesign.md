# Command Palette Redesign — Typewriter-as-Placeholder

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the command palette into a mini landing page where the typewriter greeting animates inside the search field as a placeholder, retracts on first keypress, and action chips dissolve.

**Architecture:** Two visual states (idle / active) sharing one search bar container. Idle shows a compact LiquidGreeting as animated placeholder + action chips below. On first keypress the typewriter fast-retracts, the real TextField becomes visible with the captured keystroke, and chips dissolve. Clearing to empty restores idle.

**Tech Stack:** SwiftUI, AppKit (NSPanel), RetroGaming custom font

---

### Task 1: Add `compact` mode to LiquidGreeting

**Files:**
- Modify: `Epistemos/Views/Landing/LiquidGreeting.swift`

**Step 1: Add compact parameter and retract binding**

Add three new parameters to `LiquidGreeting` and adjust the font/sizing logic.

```swift
struct LiquidGreeting: View {
    @Environment(UIState.self) private var ui

    // New parameters
    var compact: Bool = false
    @Binding var retractNow: Bool
    var onRetractComplete: (() -> Void)?

    // Typewriter state
    @State private var displayText = ""
    @State private var cursorVisible = true

    private var theme: EpistemosTheme { ui.theme }
    private var greetingFont: Font {
        .custom("RetroGaming", size: compact ? 22 : 44)
    }
```

Update the existing call site in `LandingView.swift` to pass `.constant(false)` for `retractNow` so it compiles unchanged.

**Step 2: Add retract logic to typewriter engine**

In the `.task(id:)` modifier, watch for `retractNow` becoming true. When it does, fast-delete the current text at ~15ms/char and call `onRetractComplete`. Add a new method:

```swift
@MainActor
private func retractText() async {
    var charIdx = displayText.count
    while charIdx > 0 && !Task.isCancelled {
        charIdx -= 1
        displayText = String(displayText.prefix(charIdx))
        try? await Task.sleep(for: .milliseconds(15))
    }
    onRetractComplete?()
}
```

Modify the `.task(id:)` to use a composite animation key:

```swift
private var animationKey: String {
    "\(shouldAnimate)-\(retractNow)"
}
```

Use `.task(id: animationKey)`:
- If `retractNow` is true → run `retractText()` then pause (don't enter typewriterLoop).
- If `retractNow` is false AND `shouldAnimate` is true → run typewriterLoop as before.
- Otherwise → clear text.

**Step 3: Adjust compact sizing**

In compact mode, reduce the cursor and minHeight:

```swift
// Block cursor
Rectangle()
    .fill(theme.fontAccent.opacity(0.85))
    .frame(width: compact ? 8 : 12, height: compact ? 20 : 36)
    .clipShape(RoundedRectangle(cornerRadius: 2))
    .opacity(cursorVisible ? 1 : 0)
    .animation(.easeInOut(duration: 0.3), value: cursorVisible)
    .padding(.leading, 2)
```

```swift
.frame(minHeight: compact ? 0 : 80)
```

In compact mode, remove the shadow (it'll inherit from the search bar container).

**Step 4: Update LandingView call site**

In `LandingView.swift`, update the existing `LiquidGreeting()` usage to:

```swift
LiquidGreeting(retractNow: .constant(false))
```

**Step 5: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED. Landing page greeting unchanged.

**Step 6: Commit**

```bash
git add Epistemos/Views/Landing/LiquidGreeting.swift Epistemos/Views/Landing/LandingView.swift
git commit -m "feat(palette): add compact mode + retractNow binding to LiquidGreeting"
```

---

### Task 2: Bump CommandPaletteWindowController dimensions

**Files:**
- Modify: `Epistemos/Views/Landing/CommandPaletteWindowController.swift:142-158`

**Step 1: Update panel dimensions**

In `ensurePanel()`, change three values:

```swift
// Line 143: contentRect width 600 → 720 (includes 40px shadow padding each side)
contentRect: NSRect(x: 0, y: 0, width: 720, height: 120),

// Line 157: minSize width 520 → 600
p.minSize = NSSize(width: 600, height: 80)

// Line 158: maxSize width 680 → 740
p.maxSize = NSSize(width: 740, height: 780)
```

**Step 2: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add Epistemos/Views/Landing/CommandPaletteWindowController.swift
git commit -m "feat(palette): bump panel dimensions to 720px for redesign"
```

---

### Task 3: Typewriter-as-placeholder in CommandPaletteOverlay

**Files:**
- Modify: `Epistemos/Views/Landing/CommandPaletteOverlay.swift`

This is the core task. The search bar (lines 172-287) gets a major rework in the `mode == .search` branch.

**Step 1: Add new state properties**

At the top of `CommandPaletteOverlay`, add:

```swift
@State private var retractNow = false
@State private var isTypewriterVisible = true  // true when idle, false when typing
```

**Step 2: Replace the search bar idle state**

In `searchBar`, the `else` branch (line 208, `mode == .search`) currently has one `VStack`. Replace the inner `HStack(spacing: 10)` (lines 210-248) with a `ZStack` that layers the typewriter and the real TextField:

```swift
VStack(spacing: 0) {
    ZStack(alignment: .leading) {
        // Layer 1: Typewriter placeholder (visible when idle)
        if isTypewriterVisible {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.75, saturation: 0.5, brightness: 0.9),
                                Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                                Color(hue: 0.05, saturation: 0.5, brightness: 0.95),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                LiquidGreeting(
                    compact: true,
                    retractNow: $retractNow,
                    onRetractComplete: {
                        withAnimation(Motion.quick) {
                            isTypewriterVisible = false
                        }
                    }
                )
            }
            .transition(.opacity)
        }

        // Layer 2: Real TextField (always present, visible when active)
        HStack(spacing: 10) {
            if !isTypewriterVisible {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hue: 0.75, saturation: 0.5, brightness: 0.9),
                                Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                                Color(hue: 0.05, saturation: 0.5, brightness: 0.95),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            TextField("Search or ask anything\u{2026}", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(theme.foreground)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit { executeSelected() }
                .opacity(isTypewriterVisible ? 0 : 1)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    cachedSearchResults = []
                    selectedIndex = 0
                    graphState.searchHighlight("")
                    graphState.setSearchActive(false)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .animation(Motion.quick, value: searchText.isEmpty)
            }
        }
    }
    .frame(height: 30)
```

**Step 3: Trigger retract on first keypress**

Add an `onChange` handler for `searchText` that triggers retract when transitioning from empty to non-empty:

```swift
.onChange(of: searchText) { oldValue, newValue in
    if oldValue.isEmpty && !newValue.isEmpty && isTypewriterVisible {
        retractNow = true
    }
    if newValue.isEmpty && !isTypewriterVisible {
        // Return to idle — typewriter resumes
        retractNow = false
        withAnimation(Motion.smooth) {
            isTypewriterVisible = true
        }
    }
}
```

Place this on the `ZStack` or the outer `VStack`.

**Step 4: Add action chips row**

Below the search bar `ZStack` but inside the search-mode `VStack`, add a chip row that dissolves when active:

```swift
// Action chips — visible in idle state, dissolve when typing
if isTypewriterVisible && searchText.isEmpty {
    HStack(spacing: 8) {
        paletteChip(label: "New Note", icon: "doc.badge.plus") {
            CommandPaletteWindowController.shared.hide()
            Task { @MainActor in
                if let pageId = await vaultSync.createPage(title: "Untitled") {
                    NoteWindowManager.shared.open(pageId: pageId)
                }
            }
        }
        paletteChip(label: "Quick Idea", icon: "lightbulb") {
            CommandPaletteWindowController.shared.hide()
            captureQuickIdea()
        }
        paletteChip(label: "Vault Briefing", icon: "book.pages") {
            CommandPaletteWindowController.shared.hide()
            chat.startNewChat()
            ui.setActivePanel(.home)
            AppBootstrap.shared?.requestVaultBriefing(chatState: chat)
        }
        paletteChip(label: "Daily Brief", icon: "newspaper.fill") {
            CommandPaletteWindowController.shared.hide()
            let prompt = DailyBriefState.buildBriefPrompt(pages: Array(allPages), chats: Array(allChats))
            dailyBrief.requestDailyBrief(prompt: prompt)
        }
    }
    .padding(.top, 8)
    .transition(.opacity.combined(with: .blurReplace))
}
```

**Step 5: Add `paletteChip` helper**

Add a private function matching the `landingChip` style from `LandingView`:

```swift
private func paletteChip(label: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule().fill(theme.foreground.opacity(0.06))
        }
    }
    .buttonStyle(.plain)
}
```

**Step 6: Check if `captureQuickIdea()` exists or needs bridging**

Look for `captureQuickIdea` in `LandingView.swift` — copy the implementation or call through the appropriate service. If it creates a note with type "idea", replicate that exact call. Otherwise simplify to creating a note titled "Quick Idea".

**Step 7: Update frame width**

Change the outer `.frame(width: 520)` (line 103 of overlay body) to:

```swift
.frame(width: 640)
```

**Step 8: Reset typewriter state on palette hide**

In the `.onReceive(NotificationCenter.default.publisher(for: .commandPaletteDidHide))` handler, reset:

```swift
.onReceive(NotificationCenter.default.publisher(for: .commandPaletteDidHide)) { _ in
    isSearchFocused = false
    isChatFocused = false
    // Reset typewriter state for next show
    retractNow = false
    isTypewriterVisible = true
}
```

**Step 9: Keep focus working**

The TextField needs to receive focus even when the typewriter is visible (opacity 0 but present). Ensure `isSearchFocused = true` still fires in `.onAppear`. The hidden TextField (opacity 0) should still accept keystrokes — SwiftUI's `@FocusState` works regardless of opacity.

**Step 10: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 11: Commit**

```bash
git add Epistemos/Views/Landing/CommandPaletteOverlay.swift
git commit -m "feat(palette): typewriter-as-placeholder with action chips and dissolve transitions"
```

---

### Task 4: Integration test — manual verification

**Step 1: Launch app and test idle state**

- Press Option+Space → palette appears at 640px width
- Typewriter animates inside search bar area in compact RetroGaming font (~22pt)
- Four action chips visible below: New Note, Quick Idea, Vault Briefing, Daily Brief
- Cursor blinks

**Step 2: Test active state transition**

- Type a character → typewriter fast-retracts (~15ms/char)
- Once retracted, real TextField visible with typed character
- Chips dissolve out (blurReplace)
- Search results appear below

**Step 3: Test return to idle**

- Clear text (click X or backspace to empty) → TextField hides
- Typewriter resumes cycling from a fresh greeting
- Chips fade back in

**Step 4: Test chip actions**

- Click each chip → palette hides, action executes (new note opens, etc.)

**Step 5: Test chat mode**

- Cmd+Shift+M or submit a query → chat mode unaffected by redesign
- Back chevron returns to search mode → typewriter visible if text empty

**Step 6: Test palette dismiss + reopen**

- Press Option+Space to dismiss, then reopen → typewriter starts fresh
- Escape key dismisses → reopen shows typewriter

---

### Task 5: Extract duplicate sparkles gradient

**Files:**
- Modify: `Epistemos/Views/Landing/CommandPaletteOverlay.swift`

**Step 1: DRY the sparkles gradient**

The sparkles icon + gradient appears twice in the ZStack (once for typewriter layer, once for active layer). Extract to a computed property:

```swift
private var sparklesIcon: some View {
    Image(systemName: "sparkles")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(
            LinearGradient(
                colors: [
                    Color(hue: 0.75, saturation: 0.5, brightness: 0.9),
                    Color(hue: 0.55, saturation: 0.5, brightness: 0.95),
                    Color(hue: 0.05, saturation: 0.5, brightness: 0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
}
```

Use `sparklesIcon` in both layers.

**Step 2: Build and verify**

Run: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add Epistemos/Views/Landing/CommandPaletteOverlay.swift
git commit -m "refactor(palette): extract sparkles gradient to computed property"
```
