# AI Routing And Local Inference

## Real Source Files

- [TriageService.swift](/Users/jojo/Epistemos/Epistemos/Engine/TriageService.swift)
- [PipelineService.swift](/Users/jojo/Epistemos/Epistemos/Engine/PipelineService.swift)
- [ChatCoordinator.swift](/Users/jojo/Epistemos/Epistemos/App/ChatCoordinator.swift)

## Real Architecture

The app already has a routing layer instead of a single blunt model call.

`TriageService.swift`:

- classifies work
- evaluates complexity and context size
- decides between Apple Intelligence and local Qwen
- carries explicit policy reasons
- preserves model selection state

`PipelineService.swift`:

- runs the streaming query path
- yields token deltas
- manages cancellation
- converts the routing result into UI-visible events

`ChatCoordinator.swift`:

- assembles user query context
- builds conversation history
- starts the pipeline
- persists the result

## Coding Patterns To Preserve

- routing is explicit, not magical
- model choice is surfaced in state
- streaming is first-class
- cancellation is real
- context assembly happens once, not on every token
- persistence happens after completion, not inside the hot token loop

## Windows Research Requirements

Research the best Windows-local equivalent for:

- a fast lightweight assist tier
- a deeper local reasoning tier
- coding-oriented local models
- model selection and routing transparency

Research must answer:

- best runtime for local Qwen on this hardware
- best CUDA-first path on Windows
- best fallback path if a selected model is unavailable
- best way to pin or bias inference threads to P-cores
- best token streaming bridge from Rust to native Windows UI

## Routing Quality Bar

The Windows version should not regress into:

- fake model labels
- hidden fallback behavior
- UI showing one model while another is actually used
- main-thread token handling

## Specific Research Tasks

- Define a Windows-native replacement for Apple Intelligence lightweight tasks.
- Determine whether one small model should stay hot in VRAM.
- Determine whether larger models should be GPU-only, CPU-offloaded, or split.
- Specify quantizations by task class, not one-size-fits-all.
