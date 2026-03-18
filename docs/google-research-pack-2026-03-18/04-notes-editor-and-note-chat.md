# Notes Editor and Note Chat

## Why this matters

The note system is one of the most important integration targets for local MLX inference and TTS.

This is not a web text area. It is a high-performance AppKit editor with careful performance rules and inline AI flows. Any local-model or voice work must respect that.

## Current editor architecture

The app uses a persistent `NSTextView` inside `NSScrollView`:

```swift
struct ProseEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    let pageId: String
    let pageBody: String
    let isFocused: Bool
    let theme: EpistemosTheme
    let isEditable: Bool
    ...
}
```

The file explicitly documents the performance philosophy:

```swift
// - ONE persistent NSTextView for the entire notes lifetime.
// - MarkdownTextStorage instances are swapped per page via PageStoragePool.
// - NSScrollView handles all scrolling natively — NOT a SwiftUI ScrollView.
// - Text stack built manually so MarkdownTextStorage is the original storage.
```

This means:

- local AI streaming must avoid per-token SwiftUI churn
- any TTS feature in notes should avoid expensive view reactivity
- anything that touches selection, note content, or inline AI should follow the current AppKit coordinator pattern

## Writing Tools already exist

The editor enables Apple Writing Tools:

```swift
tv.writingToolsBehavior = NSWritingToolsBehavior.default
```

That matters because research should preserve coexistence between:

- Apple native writing tools
- current note AI actions
- future MLX local generation
- future TTS / read-aloud behaviors

## Current note chat architecture

Each note has its own `NoteChatState`:

```swift
@MainActor @Observable
final class NoteChatState {
    let pageId: String

    var inputText = ""
    var isStreaming = false
    var responseText = ""
    var error: String?
    var hasResponse = false
    var useResponsePanel = false
    var messages: [AssistantMessage] = []
}
```

It already supports multiple routing modes:

```swift
enum NoteChatMode: String, Codable, CaseIterable, Sendable {
    case auto
    case cloudOnly
    case provider
}
```

And its submit path already streams through triage:

```swift
let stream = triageService.stream(
    prompt: fullPrompt,
    systemPrompt: fullSystemPrompt,
    operation: operation,
    contentLength: noteBody.count,
    query: trimmed
)
```

This is a strong signal that MLX integration should happen down in the shared inference layer, not by inventing a totally separate note-local AI path.

## Existing token buffering

Note chat already buffers tokens:

```swift
private var pendingTokens = ""
private var flushTask: Task<Void, Never>?

func appendStreamingText(_ text: String) {
    pendingTokens += text
    guard flushTask == nil else { return }
    flushTask = Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(60))
        self?.flushTokens()
    }
}
```

That means research should consider:

- how MLX token streaming cadence should plug into this existing buffering
- whether local streaming should use the same `AsyncThrowingStream<String, Error>` model
- whether TTS read-aloud of responses should tap buffered text, completed responses, or chunked utterances

## Good MLX/TTS surfaces inside notes

Likely V1 surfaces:

- note chat responses
- note-context AI commands that already stream responses
- selection read-aloud or note read-aloud

Likely non-V1 / riskier:

- fully live spoken token-by-token TTS while a note response is still streaming
- speech generation directly inside the text system on every edit

## What research should answer

- best way to stream MLX tokens into existing note chat architecture
- whether local model routing should be transparent in note chat `auto` mode
- best way to add TTS/read-aloud without hurting editor responsiveness
- best way to cancel local generation and local TTS inside note flows
- best way to avoid editor hitching while local models are loaded or speaking
