# Implemented Agent History — What Was Real Vs What Was Scaffold

> **Index status**: SUPERSEDED-HISTORICAL — March 2026 Google research pack; superseded by IMPLEMENTATION_PLAN_FROM_ADVICE (April 2026 4-model council synthesis).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/google_research_packs/` for historical record.



The historical agent system was not imaginary, but much of it was still scaffold-level.

## Real Infrastructure That Existed

The repo did previously contain actual agent code.

### Agent engine

From commit `fe367fe`:

```swift
@MainActor @Observable
final class AgentEngine {
    private(set) var agents: [AgentID: any AgentProtocol] = [:]
    private(set) var statuses: [AgentID: AgentStatus] = [:]
    let messageBus = MessageBus()

    func register(_ agent: any AgentProtocol) { ... }
    func start() { ... }
    func stop() { ... }
    func submitTask(_ task: AgentTask) async { ... }
}
```

This was real orchestration scaffolding.

### Agent memory

From commit `10c4871`:

```swift
@MainActor @Observable
final class WorkingMemory {
    let agentId: AgentID
    let maxTokens: Int
    private(set) var entries: [MemoryEntry] = []
    private(set) var currentTokens: Int = 0
}
```

There was also:

- episodic memory
- semantic memory
- compaction logic

### Agent-specific classes

There were real classes for:

- Librarian
- Writer
- Builder

There was also:

- Learning Pool scaffold
- graph NPC state
- voice system scaffold
- trust / voice / notification settings UI

## Where The Old System Was Still Thin

The older system often had structure without deep capability.

Example from commit `69008ee`:

```swift
func handleTask(_ task: AgentTask) async {
    status = .working(task: task.instruction.prefix(40) + "…")

    // For now, acknowledge the task and publish completion.
    // Full implementation requires later memory-engine crate.
    let output = "Librarian received task: \\(task.instruction)"

    await messageBus.publish(.taskComplete(...))
    status = .idle
}
```

This is important:

- the old system proved architecture
- it did not yet prove "wow, this agent can really do useful work"

## Why This Matters

When researching the next version, do not assume the old agent system should simply be restored.

The better reading is:

- reuse the good structural ideas
- do not restore scaffold behavior just because it existed
- focus on actual usefulness:
  - research quality
  - note enrichment quality
  - writing quality
  - safe writeback
  - good tool use
  - clear approvals

## Practical Conclusion

The old implementation history is valuable as:

- evidence of intended architecture
- evidence of naming / types / state boundaries
- evidence of what already felt too broad

It should not be treated as a final product shape.

