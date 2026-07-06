# Workspace Agent MAS Test Handoff - 2026-07-05

Scope: App Store/MAS agent surface only. Do not use this checklist for Pro/OpenChamber.

## Build Setup

Use the App Store debug scheme:

```sh
xcodebuild -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' build
```

For local June web iteration, run a Debug build with:

```sh
EPISTEMOS_JUNE_WEBROOT=/Users/jojo/dev/june-epistemos/dist
```

Release/MAS builds must load only the bundled signed `JuneWeb` resources.

## Local Model Test

1. Open Home > Workspace.
2. Open the model picker and confirm these on-device rows are visible:
   - Qwen3 4B Instruct
   - Qwen3 8B Instruct
   - Qwen2.5 7B Instruct
   - Phi-3.5 Mini Instruct
   - TinyLlama 1.1B Chat
3. Pick a not-installed GGUF row from an open chat. Expected: the row persists as that session's model, download starts, and the next prompt reports download/preparing state instead of silently using cloud.
4. After download completes, turn Wi-Fi off and submit: `Answer in one sentence: what is local inference?`
5. Expected: streamed answer arrives on-device. No subscription, proxy, or network error should appear.
6. Switch to another on-device row in the same chat, submit again, quit/reopen, and confirm the selected row persists for the visible chat.

## Cloud Test

The cloud lane must use the real proxy SSE endpoint. It must not fake completions.

Set a proxy base when testing a non-production backend:

```sh
EPISTEMOS_PROXY_BASE_URL=https://your-proxy.example
```

Use one of these DEBUG-only auth paths:

```sh
EPISTEMOS_PROXY_DEV_TOKEN=...
```

or:

```sh
EPISTEMOS_PROXY_DEV_SESSION_TOKEN=...
EPISTEMOS_PROXY_DEV_SESSION_EXPIRES_AT=2026-07-05T23:59:00Z
```

Then:

1. Pick `Epistemos Cloud`.
2. Submit: `Say cloud route ok in five words.`
3. Expected: a real `/v1/chat/completions` SSE stream arrives.
4. Unset the DEBUG token/session and clear the stored proxy session. Pick cloud again.
5. Expected: the honest subscription/session error appears. No local fallback and no fabricated answer.

## UI Checklist

Capture screenshots for dark and light mode:

1. Workspace first open: no visible `June` copy; ChonkyPixels-style typography is applied inside the web surface.
2. Toolbar pill: exactly `Epistemos`, `New Chat`, and `All Chats`; no Settings, Greeting, or read-aloud button in the native pill.
3. Light mode user bubble: text is white and readable.
4. Message layout: user and assistant bubbles align cleanly and do not collide with action buttons.
5. Composer: caret stays inside the input, long words wrap, and text does not shift outside the composer.
6. Sidebar expanded/collapsed: main chat and composer shift with the sidebar and do not slide underneath it.
7. All Chats sheet: title says `Workspace chats`, empty state says `No chats yet`, and the primary action says `New Chat`.
8. Tab switch: leave Workspace and return. Expected: warm WebView returns without reload and the selected model/session remains.

## Model Provenance Checked

Checked against Hugging Face on 2026-07-05:

- `bartowski/Phi-3.5-mini-instruct-GGUF`, file `Phi-3.5-mini-instruct-Q4_K_M.gguf`, MIT, 2,393,232,672 bytes: https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF
- `TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF`, file `tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf`, Apache-2.0, 668,788,096 bytes: https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF
- Existing Qwen rows use Apache-2.0 GGUF files from `Qwen/Qwen3-4B-GGUF`, `Qwen/Qwen3-8B-GGUF`, and `bartowski/Qwen2.5-7B-Instruct-GGUF`.

Llama 3.x GGUFs were not added because their license is the custom Llama community license. TinyLlama Chat is the permissive Llama-family chat row.
