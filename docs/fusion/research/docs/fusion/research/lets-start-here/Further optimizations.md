---
id: 5F58F3A8-0DC2-4084-BACD-9FE9267818E3
title: Further optimizations
---

# Further optimizations



cross-ABI pass.

This closes the safe part of the findings list. The remaining unfinished item is the Rust-side BTK batching step, and it should stay deferred until you want an intentional cross-ABI pass.

Honest status:

ReactiveQuery invalidation: implemented and verified.
repeated loadBody() cleanup: materially improved across the requested live paths.
Swift-side BTK materialization: improved, but not “perfect.” The next real win would require a Rust ABI batching change, and I did not do that because it would stop being a low-risk patch. The current decoder is still zero-copy for the raw buffer via GraphEngine.swift (line 590), but row strings still materialize on the Swift side. That part is only partially optimized, not finished.

the remaining non-trivial BTK materialization win is still not safely solvable in Swift alone without an intentional cross-ABI pass