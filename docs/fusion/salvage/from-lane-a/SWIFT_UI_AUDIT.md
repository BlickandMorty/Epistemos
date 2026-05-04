# Swift UI Audit

## Verdict

`PARTIAL`

The staged bridge follows the right actor split. It is not yet the production UI data path.

## What is good

- `KnowledgeCoreShadowRuntime` is `@MainActor @Observable`
- bridge polling happens off the main actor in a `Task(priority: .utility)`
- main-thread application is batched through `applyBatch(...)`
- startup guards prevent multiple polling tasks

## What is not enough yet

- the shadow runtime only updates counters, not real UI models
- Swift still materializes strings and arrays per payload
- payload decoding still uses repeated FFI helper calls
- no signpost/instrumentation path exists for main-thread budget tracking

## Live app reality

- production query UI is still `ReactiveQuery` + `NotificationCenter`
- reevaluation happens on `@MainActor`
- graph/search invalidations are still coarse

## Conclusion

The staged Swift bridge is well-contained enough for shadow mode. It is not proof that the production UI path is low-latency.
