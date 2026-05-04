# Windows Port Decision Matrix

> **Index status**: DEFERRED-RESEARCH — Windows porting research; deferred (V1 = macOS-only per ambient_V1_DECISION.md).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/60_deferred_research/windows_research/`.



## What Google Research Should Decide

By the end of the research, these questions should have a crisp answer.

## Frontend Stack

Choose one:

- Swift 6 + direct WinUI 3 path
- Swift 6 + generated WinRT projections
- Swift 6 + minimal native Windows host layer

Reject anything that:

- depends on web UI
- hides the app in a browser shell
- cannot support a serious native text editor and multi-window desktop app

## Editor Stack

Choose the best native Windows text architecture for:

- large markdown notes
- syntax-aware editing
- persistent editor instances
- AI streaming insertion
- native undo

Reject anything that:

- rerenders the whole document on each change
- routes editing through HTML
- weakens native editing quality

## AI Runtime

Choose:

- primary local chat runtime
- lightweight assist runtime
- coding-model runtime
- whether NPU is worth adding for background tasks

Reject anything that:

- hides model choice
- causes token stutter on hybrid-core CPUs
- wastes the limited laptop GPU power budget

## Graph Runtime

Choose:

- rendering API
- delta transport strategy
- ownership boundary

Reject anything that:

- duplicates graph state unnecessarily
- forces full redraw or full state remarshal for small graph changes

## Packaging

Choose:

- build system
- dependency shipping strategy
- Rust + Swift runtime packaging
- signing and update path

Reject anything that:

- is hard to ship repeatedly
- creates a brittle local-dev setup
- depends on abandoned tooling

## Minimum Acceptable Research Output

The final research result should include:

- recommended stack
- rejected alternatives and why
- risk list
- phased migration plan
- benchmark plan
- hardware utilization plan for CPU, GPU, NPU, and RAM

If the research cannot prove that pure Swift 6 + WinUI 3 is mature enough, it should say so directly and propose the smallest native Windows host layer needed to keep the overall architecture clean.
