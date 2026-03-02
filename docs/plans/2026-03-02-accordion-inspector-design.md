# Accordion Inspector Panel — Design

## Problem

The node inspector panel (HologramNodeInspector) has four sections fighting for fixed vertical space:
- Header: ~90px
- Summary: capped at 180px (`maxHeight: 180`)
- Relationships: capped at 220px (`maxHeight: 220`)
- Chat: 120–560px range (`minHeight: 120, maxHeight: 560`)

Total potential: ~1050px vs. 960px max panel height. In mini mode (620px NSWindow), the chat input gets clipped entirely and the summary truncates after a few lines.

## Solution: True Accordion

Replace the fixed-height stacked layout with a single-section-expanded accordion. Only one section body is visible at a time — it fills all available space. The other two sections collapse to a single header row (~36px each).

### Layout

```
┌────────────────────────────────┐
│  ● Note  Node Title       [×] │  always visible
│  12 connections · Mar 2        │
├────────────────────────────────┤
│ ▼ ✨ Summary                   │  expanded
│  Full summary text flows       │
│  with no height cap.           │
│  ScrollView handles overflow.  │
├────────────────────────────────┤
│ ▶ ↗ Relationships (12)        │  collapsed
├────────────────────────────────┤
│ ▶ 💬 Chat (3 messages)         │  collapsed
└────────────────────────────────┘
```

Mini mode (620px): header ~90px + 2 collapsed ~72px + dividers ~6px = **~452px for expanded section**.

### State

```swift
enum InspectorSection: CaseIterable {
    case summary, relationships, chat
}
@State private var expandedSection: InspectorSection = .summary
```

- View-level state (not on NodeInspectorState)
- Resets to `.summary` on new node selection
- Tapping collapsed header expands it, collapses current
- Tapping expanded header is a no-op

### Collapsed Header Previews

| Section | Preview |
|---------|---------|
| Summary | First line of summary text, truncated |
| Relationships | Count from store |
| Chat | Message count, or empty |

### Chat Input Pinning

When chat is expanded, the input field is pinned at the bottom of the section (outside the ScrollView), always accessible regardless of message count.

### Visual Treatment

- Single `.glassEffect(.regular.interactive(), ...)` on outer container — unchanged
- Section headers: `.caption` font, `.secondary` foreground, chevron rotates on expand
- Content transitions: smooth height animation, no `.move` transitions
- All existing styling (fonts, colors, chat bubbles, relationship rows) preserved

## Files Modified

1. `HologramNodeInspector.swift` — restructure to accordion, add expandedSection state
2. `RelationshipBrowser.swift` — remove `frame(maxHeight: 220)`, fill available space

## Files NOT Modified

- `NodeInspectorState.swift`
- `HologramOverlay.swift`
- Any Rust code

## What's Fixed

- Summary gets full panel height when expanded (was 180px)
- Chat input always visible when chat is expanded
- Mini mode works — 620px is plenty for one expanded section
- No resize glitches — sections don't compete for space

## What's Preserved

- Liquid glass on outer container
- Panel width (380), mini panel NSWindow size (380×620)
- All functionality (summary, chat, relationship navigation)
- All existing visual styling
