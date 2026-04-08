# Epistemos Session Report — 2026-04-06

## For: Next Agent (Kimi or Claude)

Two unresolved issues remain from this session. The code compiles with zero errors and zero warnings in the affected files, but runtime behavior is broken.

---

## ISSUE 1: Code Editor Syntax Colors Not Visible

### Symptoms
- Code editor opens but text appears as a single flat color (no syntax highlighting)
- May also be laggy during scroll
- Theme changes may not reflect in the editor

### What Was Changed (This Session)

Two files were modified:

**`Epistemos/Theme/EpistemosTheme.swift`**
- Added `XcodeCodeColors` struct (~line 194) with exact Xcode Default Dark/Light colors
- Added `@MainActor var xcodeColors: XcodeCodeColors` (~line 272) that returns `isDark ? .defaultDark : .defaultLight`
- Rewrote `nsColorForTokenType(_:)` (~line 905) to use `xcodeColors` instead of the old semantic palette (emerald/amber/violet)

**`Epistemos/Views/Notes/CodeEditorView.swift`**
- Switched syntax highlighting from `textStorage.addAttribute(.foregroundColor)` to `layoutManager.addTemporaryAttribute(.foregroundColor)` for zero-layout-cost coloring
- Added `applyBaseFormatting(theme:)` — sets font, foreground color, paragraph style on textStorage once
- Added `retokenize()` — calls Rust FFI, caches tokens as UTF-16 ranges in `cachedTokens`
- Added `applyHighlighting(theme:, fullPass:)` — applies temporary attributes; `fullPass: true` for initial load / text changes, `fullPass: false` (additive) for scroll
- `highlightSyntax(theme:)` now calls `retokenize()` then `applyHighlighting(theme:, fullPass: true)`
- Moved current-line highlight from `drawBackground(in:)` to a `CALayer` sublayer (`currentLineLayer`)
- Added `override var isOpaque: Bool { true }`
- Added layer backing: `scrollView.wantsLayer = true`, `contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay`
- Replaced drawBackground indent guide caching with dirty-rect-scoped drawing
- Added NSTextView config: `lineHeightMultiple = 1.1`, `textContainerInset = (0, 8)`, `lineFragmentPadding = 4.0`, disabled 9 auto-features, set `typingAttributes`
- Inspector views (CodeInspectorPreview, CodeInspectorEditor) updated to use `xcodeColors`

### Likely Root Causes (Not Yet Verified)

**Most Likely — Temporary attributes not surviving layout passes:**
The switch from `textStorage.addAttribute` to `layoutManager.addTemporaryAttribute` is correct for performance, but temporary attributes are cleared by the layout manager when text storage changes trigger `processEditing`. If `applyBaseFormatting` (which modifies textStorage) runs AFTER `highlightSyntax`, or if the NSTextView internally triggers a processEditing pass during initial layout, the temporary colors get wiped and never re-applied.

**Possible — `retokenize()` returns zero tokens:**
The FFI call `markdown_parse_code_tokens(code, code_len, language, buffer, max_tokens)` requires the `language` parameter to match a supported tree-sitter language exactly. Supported: `swift`, `rust`, `python`, `javascript`, `typescript`, `tsx`, `json`, `html`, `css`, `bash`, `go`, `c`, `cpp`. If the language string doesn't match, zero tokens are returned and `cachedTokens` stays empty.

**Possible — `@MainActor` isolation on `xcodeColors`:**
`nsColorForTokenType` is a regular (non-isolated) method that internally accesses `xcodeColors` which is `@MainActor`. The compiler allowed it (no error), but runtime actor hopping could cause unexpected behavior.

### How to Debug

Add temporary logging to verify the pipeline:

```swift
// In retokenize(), after the FFI call:
#if DEBUG
print("[CodeEditor] retokenize: lang=\(language), utf8Len=\(text.utf8.count), tokens=\(cachedTokens.count)")
#endif

// In applyHighlighting(), at the start:
#if DEBUG
print("[CodeEditor] applyHighlighting: fullPass=\(fullPass), cachedTokens=\(cachedTokens.count), nsLen=\(nsLen)")
#endif

// In makeNSView, after highlightSyntax:
#if DEBUG
if let lm = textView.layoutManager {
    let attrs = lm.temporaryAttributes(atCharacterIndex: 0, effectiveRange: nil)
    print("[CodeEditor] tempAttrs at index 0 after initial highlight: \(attrs)")
}
#endif
```

### How to Fix

**Option A: Hybrid approach (safest)**
Keep temporary attributes for scroll-triggered reapplication, but also apply foreground colors to textStorage during `highlightSyntax` (not just in `applyBaseFormatting`). This ensures colors survive layout passes. The temporary attributes provide the zero-cost scroll updates on top.

```swift
func highlightSyntax(theme: EpistemosTheme) {
    retokenize()

    // Apply to textStorage (persistent, survives layout) for base colors
    guard let storage = textStorage, !cachedTokens.isEmpty else { return }
    let nsLen = (string as NSString).length
    storage.beginEditing()
    let baseFont = font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    for token in cachedTokens {
        let range = NSRange(location: token.start16, length: token.end16 - token.start16)
        guard range.location + range.length <= nsLen else { continue }
        let color = theme.nsColorForTokenType(token.tokenType)
        storage.addAttribute(.foregroundColor, value: color, range: range)
        if token.tokenType == 3 {
            let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italic, range: range)
        }
    }
    storage.endEditing()
}
```

**Option B: Re-apply temporary attributes after layout**
Override `layoutManager(_:didCompleteLayoutFor:atEnd:)` on a delegate to re-apply temporary attributes after each layout pass completes.

**Option C: Revert to the old approach**
If performance is acceptable, revert `highlightSyntax` back to the original `textStorage.beginEditing/endEditing` approach with `storage.addAttribute(.foregroundColor)`. This was working before the session. The performance cost is O(document) per keystroke, which is noticeable on files >5000 lines but fine for most files.

### Key Files

| File | Lines | What to Check |
|------|-------|--------------|
| `Epistemos/Views/Notes/CodeEditorView.swift` | 155-300 | `makeNSView` — setup flow |
| Same file | 623-643 | `applyBaseFormatting` — textStorage attributes |
| Same file | 645-710 | `retokenize` — FFI call and token caching |
| Same file | 712-790 | `applyHighlighting` — temporary attribute application |
| Same file | 380-410 | Coordinator — textDidChange/selectionDidChange/scrollDidChange |
| `Epistemos/Theme/EpistemosTheme.swift` | 194-273 | `XcodeCodeColors` struct and `xcodeColors` property |
| Same file | 905-922 | `nsColorForTokenType` — token type to NSColor mapping |
| `graph-engine/src/code_highlight.rs` | Full file | Rust FFI — tree-sitter tokenization |

---

## ISSUE 2: Cloud Models Not Working

### Symptoms
- Cloud model requests fail or don't return responses
- User cannot use GPT-5.4, Claude, or other cloud models

### Recent Fixes (This Week — Already Committed)

Three commits on `main` addressed cloud issues:

**Commit `5377822a` — Manual mode default:**
- Cloud routing now defaults to **manual mode** (no silent fallback)
- If the selected cloud model fails, user sees an error message instead of silently falling back to local Qwen
- User must enable "Auto-route on failure" in **Settings > Inference > Cloud Routing** for fallback behavior

**Commit `c2ab0149` — GPT-5.4 model resolution:**
- Fixed bug where GPT-5.4 was silently downgraded to GPT-5.4-mini via "fast mode" resolution
- Fixed OpenAI Responses API requiring `instructions` as a top-level field (not in messages array)
- Without this fix, every OpenAI request returned 400: `"Instructions are required"`

**Commit `56ee11a1` — OpenAI store=false:**
- Added `store: false` to OpenAI requests for privacy compliance

### What to Check

1. **API Keys:** Verify API keys are set in **Settings > AI** for each provider (OpenAI, Anthropic, Google)
   - Keys are stored in macOS Keychain via `SecItemAdd`/`SecItemCopyMatching`
   - Files: `Epistemos/State/InferenceState.swift`, Keychain access in `Epistemos/Engine/LLMService.swift`

2. **Manual Mode:** The app now defaults to manual mode. If the selected model's API key is missing or invalid, it fails with an error instead of falling back. Check:
   - `InferenceState.cloudAutoFallback` — should be `false` by default
   - The error message shown to the user should include troubleshooting steps
   - Toggle **Settings > Inference > Cloud Routing > Auto-route on failure** to enable fallback

3. **OpenAI Request Format:** Verify the request body includes:
   ```json
   {
     "model": "gpt-5.4",
     "instructions": "system prompt here",
     "store": false,
     "stream": true,
     "input": [{"role": "user", "content": "..."}]
   }
   ```
   File: `Epistemos/Engine/LLMService.swift` ~line 1098-1110

4. **Anthropic Request Format:** Verify standard messages API format:
   - Endpoint: `api.anthropic.com/v1/messages`
   - Headers: `x-api-key`, `anthropic-version`
   - Body: `model`, `messages`, `max_tokens`, `stream`
   - File: `Epistemos/Engine/LLMService.swift`

5. **Network Connectivity:** The app may be failing silently on network errors. Add logging in `LLMService.swift` at the URLSession streaming call to capture HTTP status codes.

### Key Files for Cloud Debugging

| File | What It Does |
|------|-------------|
| `Epistemos/Engine/LLMService.swift` | All HTTP calls to cloud APIs (OpenAI, Anthropic, Google) |
| `Epistemos/Engine/TriageService.swift` | Cloud routing logic, manual vs auto mode (~line 1524) |
| `Epistemos/State/InferenceState.swift` | Model selection, API key management, cloudAutoFallback flag |
| `Epistemos/Views/Settings/SettingsView.swift` | Cloud routing toggle UI |
| `Epistemos/Bridge/StreamingDelegate.swift` | SSE/streaming response handling |

### Supported Cloud Providers

| Provider | Models | Endpoint |
|----------|--------|----------|
| OpenAI | gpt-5.4, gpt-5.4-mini, gpt-5.4-nano, gpt-5.2, gpt-4.1, o3, o3-mini | `api.openai.com/v1/responses` |
| Anthropic | claude-opus-4-1, claude-opus-4, claude-sonnet-4, claude-3-7-sonnet, claude-3-5-haiku | `api.anthropic.com/v1/messages` |
| Google | gemini-2.5-pro, gemini-2.5-flash, gemini-3-flash-preview | Google Generative AI API |
| DeepSeek | deepseek-chat, deepseek-reasoner | DeepSeek API |

---

## Summary for Next Agent

1. **Code editor colors:** The highlighting pipeline was rewritten to use `layoutManager.addTemporaryAttribute` instead of `textStorage.addAttribute`. This is architecturally correct but temporary attributes may be getting cleared by layout passes before they're visible. Either add debug logging to verify, or fall back to the textStorage approach (Option C above) which was working before this session.

2. **Cloud models:** Three fixes were already committed for manual mode default, GPT-5.4 model resolution, and OpenAI request format. If cloud still doesn't work, the next step is to add HTTP response logging in `LLMService.swift` to see what error codes and bodies are coming back from the APIs. Also verify API keys are present in the Keychain.
