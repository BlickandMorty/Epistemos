# Subscription Lifecycle Report

## Live ReactiveQuery

Good:

- subscriptions are attached when `stream()` is created
- `onTermination` removes Combine cancellables
- reevaluation is debounced

Risks:

- every reevaluation executes on `@MainActor`
- lifecycle is tied to stream consumption, not visibility heuristics

## Staged knowledge-core shadow runtime

Good:

- one polling task per runtime via `startIfNeeded`
- task is cancelled in `stop()`
- `PollTaskBox` cancels on `deinit`

Risks:

- polling continues until `stop()` even if all Rust subscriptions are removed
- there is no automatic “zero subscriptions -> stop polling” rule
- batch application currently only updates counters, so real UI lifecycle cost is still unknown

## Recommendation

Keep the staged bridge in shadow mode until subscription ownership is tied to visible consumers and automatic stop conditions.
