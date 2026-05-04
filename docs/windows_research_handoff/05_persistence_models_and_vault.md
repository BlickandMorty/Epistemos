# Persistence, Models, And Vault Strategy

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## Real Source Files

- [SDPage.swift](/Users/jojo/Epistemos/Epistemos/Models/SDPage.swift)
- [SDChat.swift](/Users/jojo/Epistemos/Epistemos/Models/SDChat.swift)

## Real Pattern

The app uses hybrid persistence.

Structured metadata lives in the app data store.
Large note bodies live on disk.

That split is deliberate.

## Why It Exists

`SDPage.swift` makes the design explicit:

- relational note metadata is queryable
- note body storage is file-based
- `loadBody()` and `saveBody()` keep giant markdown out of the primary row store
- dirty state is tracked separately for vault export

This avoids:

- bloated database rows
- repeated giant string churn
- slow query scans over note bodies when metadata would do

## Chat Persistence

`SDChat.swift` keeps chat threads and ordered messages as structured app data:

- stable chat identity
- recent chat ordering
- linked note association
- persisted message history

## Windows Port Requirement

Research the best Windows-native equivalent to this exact persistence shape:

- structured note/chat metadata in a local embedded database
- large note bodies on disk
- strong indexing for metadata queries
- stable recent chat history
- robust file watching / vault sync

## Specific Questions

- SQLite, LiteFS, RocksDB, or another embedded option for metadata?
- Best way to store large markdown bodies on Windows without file-lock misery?
- Best file watching strategy for a user vault on Windows?
- How to avoid antivirus / Defender penalties on hot note I/O paths?
- How should recent chats and note metadata be indexed for low-latency UI queries?

## Pattern To Preserve

- metadata store and body store are different on purpose
- queryable structures stay small
- heavy text stays in files
- dirty flags are explicit and persisted
