# Chat Surfaces And Session Patterns

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## Real Source Files

- [MiniChatView.swift](/Users/jojo/Epistemos/Epistemos/Views/MiniChat/MiniChatView.swift)
- [ChatCoordinator.swift](/Users/jojo/Epistemos/Epistemos/App/ChatCoordinator.swift)
- [SDChat.swift](/Users/jojo/Epistemos/Epistemos/Models/SDChat.swift)

## Current Product Pattern

The app has multiple chat surfaces:

- main chat
- mini chat windows
- note-linked chat flows

Mini chat is not a fake floating overlay anymore. It is its own real windowed surface with isolated session identity.

## Session Pattern

Each chat has:

- its own `chatID`
- persisted history
- optional note linkage
- optional context attachments
- streaming state

Recent chats are app-wide, but opening one in mini chat should stay in mini chat.

## UI Pattern

`MiniChatView.swift` shows several important behaviors:

- centered transcript column
- distinct user bubble vs assistant output alignment
- recent chats view within mini chat
- add-chat action
- context attachment support
- streaming transcript auto-follow behavior with throttling

## Coding Patterns To Preserve

- chat session identity is explicit
- streaming text is throttled for UI stability
- scroll-follow policy is stateful
- chat windows are real native windows, not one fake tab strip
- recent chats are shared without collapsing separate surfaces into one

## Windows Research Requirement

Research the best native Windows way to preserve:

- multiple real chat windows
- native tabbed/attached-window behavior where appropriate
- shared recent-chat history across surfaces
- per-chat isolation
- stable streaming behavior
- note-context auto-attachment

## Specific Questions

- Best way to model real multi-window chat surfaces on Windows?
- Best way to restore chats into the correct surface?
- Best way to stream tokens into long chat transcripts without UI jank?
- Best way to keep transcript centering and bubble layout stable during resize?
