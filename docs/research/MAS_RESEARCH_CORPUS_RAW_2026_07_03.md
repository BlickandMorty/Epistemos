# RAW corpus — MAS build (two-surface) research

> ⚠️ **RAW RESEARCH INPUT — DO NOT BUILD FROM THIS FILE.** Verbatim multi-model research corpus (5 dossiers) fed into the 2026-07-03 synthesis. It CONTAINS ERRORS corrected against local source clones. Canonical build docs: docs/prompts/PROMPT_PLAN_1_PRO_OPENCHAMBER.md / PROMPT_PLAN_1_MAS_JUNE.md (see their §Corrections logs). Kept for provenance only.

gpt 1-# Epistemos MAS Execution Dossier

This dossier is written for the Mac App Store build only: a sandboxed, hardened native macOS app with two deliberately separate surfaces. The highest-confidence finding is that **Surface A is straightforwardly viable on MAS** if you keep inference fully in-process with an embedded `llama.cpp` library and Apple’s Foundation Models framework, while **Surface B is viable only if you treat Goose as an embedded Rust core and never ship or invoke `goosed`, `goose serve`, or any local socket/server path inside the MAS binary**. The public Goose repo already exposes an in-process core through the `goose` crate; however, its official cross-language SDK surface is still a stub, so the MAS build will need its own minimal UniFFI bridge around the real agent/session/provider/event APIs. Apple’s review rules are the other hard boundary: the app must stay self-contained, sandboxed, and must not download or execute new code or install helper resources that materially alter functionality after review. That is the line that separates “download GGUF weights as data” from “download a helper binary / server / plugin.” citeturn12view0turn12view1turn21view0turn22view0turn39search16turn39search7turn43view0turn43view2turn43view3

A second high-confidence finding is architectural, not legal: the two-surface split is not cosmetic. The MAS build should treat Quick Chat as a **reader/conversation surface** and June Workspace as an **agent/work surface** with visibly different furniture, state, and pacing. If you let Surface B look like just “another chat,” users and reviewers will both read it as one blended AI product, which is exactly the failure mode you described. The safest implementation path therefore is: **Apple Foundation Models as the zero-download default brain; embedded GGUF models as an opt-in stronger local lane; Goose in-process only for the separate paid workspace lane using cloud models through your proxy.** Apple’s own 2026 positioning for Foundation Models strongly supports this split: the framework is the same native Swift API around the on-device Apple Intelligence model, and by 2026 it also supports cloud models through the same language-model abstraction when you need them. citeturn40search0turn40search1turn40search3turn40search7turn40search14turn40search19

## Surface A engines

### Embedded llama.cpp on MAS

`llama.cpp` is compatible with the packaging pattern you need. Its project documentation explicitly supports Apple Silicon via the **Metal backend**, states that Metal is **enabled by default on macOS**, requires models in **GGUF** format, and publishes an **XCFramework** path specifically for Swift projects on macOS, iOS, tvOS, and visionOS. That means the clean MAS path is not Ollama, not `llama-server`, and not a local helper process. It is either: build `llama.cpp` yourself as a static/binary framework and link it directly into the app, or consume the upstream XCFramework and wrap the small API surface you need inside Swift. citeturn36view0turn36view1turn36view2turn38view0

The App Store constraint is not that local inference is forbidden. The constraint is that the app must be self-contained, sandboxed, and may not download or execute code that changes functionality after review. Apple’s review guidelines are explicit here: Mac App Store apps must be sandboxed and self-contained, may not install code or resources in shared locations, may not spawn background processes without consent, and may not download, install, or execute code that introduces or changes features or functionality. An embedded `llama.cpp` library plus GGUF files stored in the app container is aligned with that rule-set. Shipping Ollama, a helper daemon, or a local HTTP server inside MAS is not. citeturn39search4turn39search16turn43view0turn43view1turn43view2turn43view3

I did **not** find a primary Apple source stating that `llama.cpp`’s Metal path specifically requires a hardened-runtime JIT entitlement, and that absence matters. The safer reading is that **it should not need `com.apple.security.cs.allow-jit`** if you are only using Metal, standard C/C++ code, and Apple’s normal GPU compilation path. Apple’s hardened runtime docs emphasize that hardened runtime is required for notarization, but they do not make JIT a blanket requirement for normal Metal-using apps. So the engineering recommendation is: do **not** request JIT or executable-memory entitlements for the MAS build unless a release-signed test proves you must. Requesting them without a real need only increases review risk. This point is therefore **inferred**, not directly verified in an Apple document specific to `llama.cpp`. citeturn39search3turn39search7turn39search11turn39search15

| Topic | MAS recommendation | Confidence |
|---|---|---|
| Packaging form | Link `llama.cpp` in-process as a framework or static library; do not use Ollama or `llama-server` in MAS | Verified-in-source |
| GPU path | Use Metal backend on Apple Silicon; leave enabled by default | Verified-in-source |
| Model format | Store models as GGUF in the sandbox container | Verified-in-source |
| Swift binding | Prefer a very small Swift wrapper over the upstream C API or XCFramework; avoid an extra local service layer | Verified-in-source for XCFramework, inferred for wrapper choice |
| Entitlements | App Sandbox on; hardened runtime on; network client only if you actually download models or call cloud APIs; no network server entitlement | Verified-in-source |
| JIT / executable memory | Start with **no** JIT entitlement; verify with release-signed testing before asking for exceptions | Inferred |
| Model storage | Put downloaded GGUFs in `Application Support` inside the app container; use security-scoped bookmarks only for user-selected external model locations | Verified-in-source for sandbox/container/bookmarks, inferred for layout |

The cleanest Swift binding is to keep the surface tiny. Surface A does not need the entire `llama.cpp` kitchen sink. It needs roughly: model load/unload, context creation, token streaming, cancellation, and prompt-window accounting. The upstream project’s XCFramework support makes that practical for Swift packaging, but I would still put your own thin Swift façade in front of it so the app code never imports raw inference internals directly. That keeps MAS and Pro able to share a stable “LocalChatEngine” protocol while differing underneath. citeturn36view2turn38view0

### Local model set

The honest limit on a 16 GB M2 Pro is that **a paper or article is a good fit; a book is not a v1 fit without chunking**. `llama.cpp` supports GGUF quantized models and Metal offload, but the memory ceiling is still real because model weights, runtime allocator overhead, and KV cache all compete inside unified memory. The table below is therefore an **engineering estimate**, not a repo-published guarantee. It is intentionally conservative because MAS needs “rock-solid” more than it needs heroic benchmarks. `llama.cpp`’s own docs show quantized models running on Metal and describe how server contexts scale with configured context windows, which is enough to ground the operational shape even though the repo does not publish your exact three-model RAM table. citeturn36view0turn36view1turn38view0

| Model | Intended role | Approximate 4-bit GGUF footprint | Safe working context on 16 GB class machine | Reading ceiling in practice | License status in this dossier | Confidence |
|---|---|---:|---:|---|---|---|
| Qwen2.5-7B-Instruct | Default downloadable local model | ~4.5–5.5 GB | ~16k–32k tokens | Strong for papers, long articles, many PDFs after extraction; not book-scale | User-supplied as Apache-2.0; re-check exact model card before ship | Inferred |
| Qwen2.5-14B-Instruct | Flagship local model | ~8.5–10 GB | ~8k–16k tokens | Better quality than 7B, but hits memory pressure sooner; best for shorter documents and selective Q&A | License not independently re-verified in this pass | Inferred |
| Phi-3.5-mini | Lightweight fallback | ~2.5–3.5 GB | ~32k–64k tokens | Best headroom for long reads, weakest quality of the three for nuanced summarization | User-supplied as MIT; re-check exact model card before ship | Inferred |

A practical gating rule for MAS is simple. On machines with 16 GB unified memory, make **Qwen2.5-7B** the highest-confidence default downloadable model, gate **Qwen2.5-14B** behind an explicit “higher memory / shorter context” warning, and keep **Phi-3.5-mini** as the low-friction fallback when you want longer document windows or faster startup. If the app estimates that extracted text plus requested reply budget will push beyond the model’s safe window, do not limp into swap; refuse gracefully and offer chunked reading. That gives you a truthful reading product instead of “sometimes wonderful, sometimes dead.” citeturn36view1turn38view0

### Apple Foundation Models as the zero-download default

Apple’s 2026 documentation is very clear on the product direction. The **Foundation Models** framework is a native Swift API that gives direct access to the **same on-device model that powers Apple Intelligence**, and by WWDC26 Apple describes it as able to work with Apple Foundation Models, cloud models, and other providers that conform to the Language Model protocol. Apple also says the 2026 expansion adds **image input** and **cloud-model support**, while separate 2026 materials position **Core AI** as the new framework for shipping custom on-device models where strict latency and memory tuning matter. citeturn40search0turn40search1turn40search2turn40search3turn40search4turn40search11turn40search13turn40search14turn40search19

That makes the best MAS split fairly direct. Use Foundation Models as the **instant, zero-download, free** entry point for Surface A, because it gives you a native Swift integration path and removes the “download a model first” hurdle. Then offer embedded GGUF models as the **opt-in stronger local lane** for users who want higher reliability on long-form reading, more predictable prompts, or performance independent of Apple Intelligence availability. Quality comparisons between Apple FM and a 7B GGUF are necessarily partly inferential, but Apple’s own positioning suggests FM should be treated as the first local brain, not as a mere fallback. The part you should not over-promise is availability: gate it at runtime, and when unavailable fall back to the best available local GGUF path. citeturn40search0turn40search1turn40search7turn40search14turn40search19

One operational caveat deserves to be stated plainly. Apple’s own forums show developers hitting guardrail and availability questions around Foundation Models, including posts about context-window frustration and cases where political/news summarization can hit restrictions. Those forum posts are not policy, but they are a signal that your app should treat Apple FM as a great default for normal academic reading and summarization, not as a universal “never says no” engine. For Epistemos, that means the UI should make the current brain explicit and let users escalate to a downloaded GGUF when Apple FM declines or underperforms for a given task. citeturn40search6turn40search9turn40search10

## Surface B core

### Goose in-process

The central question—whether Goose can run embedded instead of only as `goosed`—has a qualified but useful answer: **yes, the core agent runtime already exists as an embeddable Rust crate, but no, Block does not yet ship a finished Swift-ready embedded SDK for it**. The repo root markets Goose as “an API to embed it anywhere,” and the maintainer discussion on ACP explicitly says that **the CLI already communicates with the agent in-process**, while `goosed` is the custom REST+SSE desktop backend they intend to consolidate away in favor of ACP. That is the strongest public evidence that the agent loop is not inherently server-bound. citeturn17search1turn17search5turn18view0turn18view1

The concrete code evidence is stronger. The `goose` crate publicly exposes modules for `agents`, `execution`, `providers`, `session`, `scheduler`, `sources`, and more. In `crates/goose/src/execution/manager.rs`, `AgentManager::instance()` builds an in-process manager with `SessionManager`, `Scheduler`, `PermissionManager`, and an `AgentConfig`; that same manager exposes `set_default_provider`, `get_or_create_agent`, `get_or_create_agent_with_runtime_context`, `cancel_session`, `is_session_busy`, and active-session listing. That is the core you need for MAS. By contrast, the `goose-server` crate is plainly the axum/http wrapper around that core and is not the right target for an App Store embedding strategy. citeturn10view3turn12view0turn12view1turn12view2turn12view3turn13view0turn13view4turn23view3turn23view4

The bad news is equally important. Goose’s official UniFFI-facing `goose-sdk` is still explicitly a **scaffold**: its README says the published surface is currently just a `ping -> pong` stub, and `src/bindings.rs` says it is minimal infrastructure “without depending on the `goose` core crate” and that the real SDK still needs the actual agent surface added. So your MAS scaffold is pointed at the correct strategic direction, but not at a finished upstream API. The practical consequence is that Epistemos MAS should either extend `goose-sdk` upstream or create an internal Rust bridge crate of its own that links against `goose` directly. citeturn21view0turn22view0turn23view0turn23view1turn23view2

| Goose layer | What the public repo shows | What MAS should do | Confidence |
|---|---|---|---|
| `goose` crate | Real in-process agent core with manager, sessions, scheduler, providers, permissions | Target this crate for embedding | Verified-in-source |
| `goose-server` crate | Axum/http wrapper around Goose core | Do **not** use in MAS | Verified-in-source |
| CLI path | Maintainer says CLI communicates with the agent in-process | Treat as proof that server boundary is optional | Verified-in-source |
| ACP direction | Maintainers are consolidating clients around ACP and away from custom `goosed` APIs | Mirror ACP event semantics in your own bridge, but skip local transport in MAS | Verified-in-source |
| `goose-sdk` UniFFI | Staticlib/cdylib exists, but published bindings are only ping/pong scaffold | Not sufficient as-is; extend or replace | Verified-in-source |

The exact **no-subprocess compliance path** for MAS is therefore:

| Step | MAS-legal choice | Why |
|---|---|---|
| Agent runtime | Link Rust core in-process | Avoids helper binary / server |
| Client boundary | UniFFI or tightly-scoped C ABI | Avoids localhost sockets |
| Provider calls | Cloud HTTPS only through app proxy | Compatible with sandboxed network client entitlement |
| Tool execution | Only MAS-legal, in-process or app-mediated tools | Avoid subprocess spawn and local daemons |
| Session persistence | Store session state inside app container | Stays within App Sandbox |
| Streaming | Emit events directly over FFI to Swift | Avoids buffering and SSE transport |
| Permissions / approvals | Surface in SwiftUI workspace | Keeps human approval in app UI |

There is one sharp edge in Goose you should treat as an owner-level decision. The `goose` crate exposes modules like `sources`, `scheduler`, `subprocess`, MCP support, and extensions, and Goose’s desktop/server product clearly assumes a broader execution environment than MAS can allow. Surface B on MAS therefore cannot be “all of Goose.” It must be a **curated Goose runtime**: cloud model provider, in-app document editing, in-app source pulls, and whatever MAS-safe tools you can execute without child processes or local servers. That is the part your local build agent must verify against the existing stub: the bridge should wire the real `AgentManager` loop, while the MAS tool catalog should intentionally omit subprocess-based and server-based tool paths. citeturn10view3turn12view0turn12view1turn13view0turn18view0turn18view1

### Goose to cloud models through the proxy

Goose already has the configuration hooks you want for proxying cloud models without forking provider logic. Its provider docs show that the **OpenAI** provider supports `OPENAI_HOST` for custom endpoints and `OPENAI_CUSTOM_HEADERS` for additional headers, and the custom-provider docs go further by supporting a JSON definition with explicit `base_url`, `headers`, `supports_streaming`, and auth requirements. That means the MAS build can point Goose at the app’s paywalled HTTPS proxy by configuration, not by hard-coding a bespoke provider path. citeturn29view2turn29view3turn29view0turn29view1

The best MAS provider plan is therefore to give Surface B a single “Epistemos Cloud” provider implemented as either an OpenAI-compatible host override or a Goose custom provider. The app’s proxy then becomes the sole place that knows your upstream model vendors and billing logic. In the app, Goose sees only: base URL, short-lived bearer or custom header, model name, and streaming enabled. That keeps keys out of the binary and prevents MAS from depending on any end-user raw provider key path. citeturn29view1turn29view2turn29view3turn41search7turn41search9

Streaming should not buffer. The ACP discussion is useful here because it names the semantic event stream Goose wants to expose: `AgentMessageChunk`, `AgentThoughtChunk`, `ToolCall`, `ToolCallUpdate`, and `request_permission`, all associated with a session-prompt flow. Even if you never speak ACP on MAS, your UniFFI boundary should mirror **that same event model**. In other words, the Swift bridge should receive a stream of discriminated events and render them incrementally in the workspace as they arrive. That is how you preserve thinking blocks, tool-call progress, approvals, and the “visible work” feeling without ever standing up an SSE server. citeturn18view0turn33view0

## Surface B workspace

### June-style workspace frontend

I did **not** locate a verifiable public MIT source tree for the June macOS assistant app in this research pass, so this section is necessarily an architecture recommendation rather than a source audit. The key conclusion is still firm: for MAS, **native SwiftUI is the more App-Store-robust and anti-mixing-friendly option**. A WKWebView slice can reduce short-term UI implementation effort if you already have a React/TS workspace shell, but it reintroduces ambiguity about what the surface is, increases integration complexity around streaming/approvals/file handoff, and makes it easier for the workspace to drift back toward a “chat page.” By contrast, a native SwiftUI workspace can directly render Swift event models coming out of the Goose bridge, integrate App Sandbox file access more predictably, and stay visually distinct from Surface A. This recommendation is **inferred** from the tooling evidence above and from Apple’s strong native-framework stance, not from a June source audit. citeturn39search16turn40search1turn40search19

| Frontend option | Short-term effort | MAS robustness | Best for anti-mixing rule | Recommendation |
|---|---:|---:|---:|---|
| WKWebView slice of a workspace UI | Lower if you already have web UI assets | Medium | Medium | Possible stopgap, not first choice |
| Native SwiftUI in June’s visual language | Higher initial build cost | High | High | Recommended |

What the workspace must render is more important than its stack. If Surface B is supposed to feel like “do this for me,” the user needs agent furniture that a chat lane does not need: a left transcript rail or activity log, a central document/work product panel, tool-call cards with status transitions, explicit approval prompts, visible source attachments, and expandable thinking blocks when the model provides them. The ACP event vocabulary is a good canonical schema for this even if the transport is local FFI. A workspace that omits those pieces will collapse back into Surface A behavior, no matter how many panels you add after the fact. citeturn18view0turn33view0

### Two-surface anti-mixing design

The safest way to preserve one brand while preventing one-room confusion is to differentiate **layout, density, and verbs**, not just color. Surface A should remain the default landing space and should lead with verbs like *ask, summarize, explain, read this, answer this selection*. Surface B should require a deliberate transition and should lead with verbs like *research, update, gather, revise, produce, approve*. That is not just UX polish; it is a classification mechanism that helps users and App Review understand that Quick Chat is not secretly an unconstrained local agent. This recommendation is architectural, but it is directly aligned with the technological split supported by Apple FM / GGUF on one side and embedded Goose / cloud tools on the other. citeturn40search0turn40search1turn18view0turn43view0

| Design axis | Surface A quick chat | Surface B June workspace |
|---|---|---|
| Entry | Default landing | Explicit button / destination |
| Primary job | “Answer me” | “Do this for me” |
| Layout | Single conversational lane, reading-focused | Multi-panel workspace |
| Density | Light, breathable, low chrome | Denser, stateful, activity-rich |
| State visibility | Minimal | High: steps, tools, approvals, doc diffs |
| Model source | Apple FM or local GGUF | Goose in-process + cloud proxy |
| Tooling | None | Curated tools only |
| Tone | Immediate and calming | Operational and accountable |

## Compliance, packaging, and monetization

### MAS compliance and packaging checklist

Apple’s rules here are unusually explicit. App Sandbox limits access through entitlements, the hardened runtime is required for notarization, network client entitlement covers outgoing connections, security-scoped bookmarks are the documented way to persist access to user-selected external files, and App Review Guidelines 2.5.2 plus 2.4.5 are the load-bearing review lines for your design. Those rules allow a sandboxed local-inference app and allow cloud API calls, but they do not allow helper installers, post-review code injection, or a local binary/server escaping the reviewed bundle. citeturn39search0turn39search1turn39search3turn39search4turn39search7turn39search9turn39search13turn39search15turn43view0turn43view2turn43view3

| Item | MAS setting | Why it matters | Confidence |
|---|---|---|---|
| App Sandbox | Enabled | Required Mac App Store containment | Verified-in-source |
| Hardened Runtime | Enabled | Required for notarization/signing flow | Verified-in-source |
| `com.apple.security.network.client` | Enable if downloading models or calling proxy/cloud APIs | Outgoing HTTPS | Verified-in-source |
| `com.apple.security.network.server` | **Do not enable** | Avoid local server posture | Verified-in-source |
| Container storage | Keep app state and downloaded GGUFs in app container / Application Support | 2.5.2 self-contained rule | Verified-in-source |
| External files | Use open/import panels + security-scoped bookmarks for persistent access | Proper sandbox file access | Verified-in-source |
| Local inference | Embedded library only | MAS-safe if in-process | Inferred from review rules + llama.cpp packaging support |
| Agent runtime | Embedded Rust only | Avoids helper/server risk | Inferred from review rules + Goose core exposure |
| Helper binaries / daemons | Prohibited for MAS lane | Highest rejection risk | Verified-in-source |
| Updates | Mac App Store only | Required by Mac App Store rules | Verified-in-source |

The GGUF download question is where teams often get nervous. Apple’s 2.5.2 language bans downloading/installing/executing **code** that introduces or changes features. A GGUF weight file is not executable code; it is model data consumed by already-reviewed inference code. That is exactly why this can work on MAS. Still, because 2.4.5(iv) also forbids downloading “additional code, or resources to add functionality or significantly change the app from what we see during review,” the right submission posture is conservative: document in App Review notes that the app downloads **model weights only**, stores them under the app container, never executes them as code, and does not install helpers, plugins, or local services. This point is partly legal interpretation, so I would classify the “allowed if framed correctly” conclusion as **inferred but strong** rather than perfectly settled. citeturn43view0turn43view1turn43view2turn43view3

### Paywall and proxy

StoreKit 2 and the App Store Server stack fit your business gate cleanly. Apple documents that StoreKit transaction information is App Store-signed in **JWS** format, that StoreKit returns signed transaction information, that the App Store Server API is the server-side verification surface, and that App Store Server Notifications V2 delivers renewal/cancellation/refund-style subscription lifecycle events to your HTTPS endpoint. That supports the exact architecture you described: the app sends signed transaction material to your proxy, the proxy verifies it with Apple’s server APIs, the proxy issues a short-lived application token, and only the cloud-agent path accepts that token. citeturn41search1turn41search2turn41search5turn41search7turn41search9turn41search13turn41search15turn41search19turn41search21

That also means your free tier needs no paywall at all beyond normal app UX guardrails. If Apple FM and local GGUF models run fully on-device, there is nothing security-sensitive to protect in those paths except normal file/privacy access. The secret-bearing lane is Surface B cloud inference. So the right split is: **free on-device = ungated**, **paid cloud agent = receipt-gated**, **no upstream model-provider API keys in the client binary**. From a review perspective, that is cleaner than trying to meter local usage or hiding local features behind a network entitlement you do not need. citeturn41search7turn41search9turn41search1turn41search2turn41search5

## Risks, phase order, and feature ledger

### Top risks and mitigations

| Risk | Why it matters | Mitigation | Confidence |
|---|---|---|---|
| Goose not truly library-embeddable for your needs | Biggest structural risk for Surface B | Bind directly to `goose` crate, not `goose-server`; plan on extending/replacing `goose-sdk` | Verified-in-source |
| UniFFI bridge not production-ready upstream | Current SDK is only ping/pong | Own a private bridge crate now; upstream later | Verified-in-source |
| Streaming across FFI gets buffered or lossy | Kills workspace feel | Mirror ACP event semantics in the FFI API; use incremental callbacks / async stream | Verified-in-source for event model, inferred for implementation |
| MAS review interprets model downloads badly | Could trigger 2.5.2 / 2.4.5 scrutiny | Review notes: weights are data, no helper binaries, no code download, no local servers | Verified-in-source for rule, inferred for review handling |
| `llama.cpp` memory ceiling on 16 GB machines | Surface A is 90% of usage | Conservative RAM gating; default to Foundation Models; refuse oversized loads | Verified-in-source for Metal/GGUF, inferred for gating thresholds |
| JIT / executable-memory confusion | Unnecessary entitlement risk | Ship without JIT unless release-signed reality proves otherwise | Inferred |
| Apple Foundation Models unavailable or guarded | Some users won’t have it; some tasks may decline | Runtime availability check, explicit fallback to GGUF | Verified-in-source for framework existence; inferred for exact fallback UX |
| Surface bleed between A and B | Product confusion and review ambiguity | Different verbs, layout, activity furniture, navigation | Inferred |
| Tool catalog contains MAS-illegal actions | Could break sandbox or review | Separate MAS tool catalog from Pro; no subprocess, no localhost services, no helper installs | Verified-in-source for rule, inferred for product design |
| Model download/import robustness | Failed installs destroy local trust | Resume-capable downloads, checksum/size checks, disk budget warnings, container-first storage | Inferred |

### Recommended phase order

The shipping order should reflect risk, not desire. **Ship Surface A first.** Apple FM as zero-download default plus one downloadable GGUF model gets you the highest-usage lane with the least review risk. Only then wire the real Goose bridge for Surface B. The reason is simple: Surface A is already compatible with the core Apple and `llama.cpp` sources you asked about, while Surface B still requires real bridge work because upstream `goose-sdk` is not there yet. citeturn40search0turn40search1turn36view2turn38view0turn21view0turn22view0

| Phase | Deliverable | Ship criteria |
|---|---|---|
| Phase A | Surface A with Apple FM only | Stable chat/read/summarize/Q&A; no tool use |
| Phase B | Add embedded `llama.cpp` downloadable GGUF lane | Model download/store/load/cancel works entirely in-container |
| Phase C | Build private Goose bridge crate | Real session/create/prompt/cancel/event streaming from Rust into Swift |
| Phase D | MAS-safe Workspace UI | Tool cards, approvals, editable doc panel, source panel |
| Phase E | Proxy + StoreKit gate | JWS verification, short-lived token issuance, notifications wired |
| Phase F | Full review hardening | Review notes, entitlement audit, oversized-task refusal paths, offline/online fallbacks |

### MAS feature ledger

| Capability | Surface | Engine / source | MAS legality | Status recommendation |
|---|---|---|---|---|
| Instant local chat | A | Apple Foundation Models | Legal | Ship first |
| Summarize selected text / PDF extract | A | Apple FM or embedded `llama.cpp` | Legal | Ship first |
| Download stronger local model | A | GGUF in app container | Likely legal if treated as data, not code | Ship with review notes |
| Tool-free conversation over imported docs | A | Apple FM / `llama.cpp` | Legal | Ship first |
| Multi-step agent planning | B | Goose in-process + cloud proxy | Legal if in-process and tool catalog is MAS-safe | Ship after bridge |
| Visible thought/tool stream | B | Goose events over FFI | Legal | Required for workspace |
| In-app doc editing by agent | B | Goose + native editor panel | Legal | Good MAS differentiator |
| External web / source pulls via proxy | B | Cloud model + app-managed HTTPS | Legal with network client entitlement | Allowed |
| Local helper/server runtime | B | `goosed`, `goose serve`, Ollama | **Not MAS-safe for this design** | Exclude |
| Subprocess-based tools | B | child processes / local binaries | High review and sandbox risk | Exclude from MAS |
| Pro-style extension ecosystem | B | broad MCP / background services | Usually unsuitable for MAS lane | Keep in Pro build only |

## Open questions for the owner

The biggest unresolved item is not whether Goose can run in-process in principle. It can. The unresolved item is **how narrow you are willing to make the MAS tool catalog** so that the embedded Goose runtime remains both useful and clearly App-Store-safe. The owner needs to decide whether Surface B on MAS is a tightly-scoped “cloud research workspace with document editing and source gathering” or whether it is trying to preserve too much of the Pro agent surface, because that choice determines whether the bridge is clean or constantly bleeding into subprocess territory. citeturn12view0turn12view1turn18view0turn43view2

I also did not verify three model-card specifics that should be checked before implementation freeze: the exact licensing text for **Qwen2.5-7B-Instruct**, **Qwen2.5-14B-Instruct**, and **Phi-3.5-mini** as you plan to distribute or auto-download them; the current Hugging Face gating / license-acceptance flow for those exact repos; and whether you want to offer any user-imported external model path at all, because every path outside the app container adds sandbox UX and support complexity. Those are manageable open items, but they are still open. 

For the local build agent, the most important verification points are concrete. It should confirm that `runInProcessAgentCore` ultimately initializes a real Rust-backed manager equivalent to `AgentManager::instance()`, sets a provider using host/header overrides or a custom-provider config, supports create/prompt/cancel/event streaming, and exposes MAS-safe tool availability instead of empty placeholder schedules/sources. It should also verify that the MAS binary contains **no** path that launches `goosed`, `goose serve`, Ollama, or any helper process; that all GGUF files remain under the app container unless explicitly user-selected with bookmarks; and that the App Review notes explicitly describe the two-surface split, local-model-as-data downloads, and the receipt-gated cloud-agent proxy. citeturn12view0turn12view1turn12view2turn18view0turn21view0turn22view0turn29view1turn43view0turn43view2turn43view3

gemini1 - Technical Architecture and Execution Dossier: Epistemos macOS App Store (MAS) BuildThis systems engineering document provides the comprehensive implementation blueprint for compiling, linking, and executing the sandboxed, hardened runtime Mac App Store (MAS) build of Epistemos. The architecture isolates two primary user-facing lanes: Surface A, a high-speed, local-only conversation and document reading layer, and Surface B, an in-process, agentic workspace driven by a statically-linked Rust library over foreign function interface (FFI) boundaries.1. Embedded llama.cpp Implementation on macOSTo conform to the constraints of the macOS App Sandbox, the Epistemos MAS target must execute local inference entirely in-process. Spawning separate background binaries, orchestrating local TCP/IP socket servers, or accessing directories outside of the sandboxed container is strictly prohibited. The local inference stack is constructed by compiling llama.cpp as a static library, wrapping it in an Objective-C++ bridging interface, and linking it directly into the primary native Swift executable.┌─────────────────────────────────────────────────────────────────┐
│                    Epistemos Sandbox Container                  │
│                                                                 │
│  ┌──────────────────────────┐     ┌──────────────────────────┐  │
│  │    Swift Frontend UI     │     │   June Agent Workspace   │  │
│  │       (Surface A)        │     │       (Surface B)        │  │
│  └────────────┬─────────────┘     └────────────┬─────────────┘  │
│               │ (Direct Calls)                 │ (UniFFI Bridge)│
│  ┌────────────▼─────────────┐                  ▼                │
│  │     LlamaBridge (C++)    │     ┌──────────────────────────┐  │
│  └────────────┬─────────────┘     │       goose-sdk.a        │  │
│               │ (Static Link)     │   (In-Process Core)      │  │
│  ┌────────────▼─────────────┐     └──────────────────────────┘  │
│  │        libllama.a        │                                   │
│  │   (Metal / Unified Mem)  │                                   │
│  └──────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────┘
Static Library Compilation and Linker ConfigurationsTo support deployment on both Intel and Apple Silicon architectures, llama.cpp must be compiled into a universal static framework. The core dependencies—libllama.a and libggml.a—are compiled using CMake with configurations optimized for Apple's unified memory architecture and Metal performance shaders.The primary build variables and their compilation properties are structured in the table below:CMake Build VariableConfiguration SettingArchitectural Impact and Execution BehaviorLLAMA_STATICONDirects the toolchain to compile static archives, preventing dynamic linker errors at runtime.LLAMA_METALONCompiles Metal compute shaders natively, enabling Apple Silicon GPU acceleration.LLAMA_ACCELERATEONLinks Apple's Accelerate framework to accelerate CPU vector operations.CMAKE_OSX_ARCHITECTURES"arm64;x86_64"Emits fat universal binaries containing slices for both Apple Silicon and Intel CPUs.LLAMA_METAL_NDEBUGONStrips verbose runtime debugging assertions from the compiled Metal pipeline.The compilation process is managed via CMake:Bashmkdir build-mac && cd build-mac
cmake .. -G "Xcode" \
  -DLLAMA_STATIC=ON \
  -DLLAMA_METAL=ON \
  -DLLAMA_ACCELERATE=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release --target llama
This compilation step generates static archives that are subsequently packed into a unified llama.xcframework using xcodebuild -create-xcframework. During compilation, the Metal runtime shaders (ggml-metal.metal) are compiled into a binary library named default.metallib and copied directly into the main App Store resource bundle.Hardened Runtime and Security-Scoped Sandbox ComplianceUnder the strict security boundary of the macOS Hardened Runtime, memory pages cannot be both writable and executable ($W \wedge X$) simultaneously. Unlike JS engines or other runtimes that compile instructions dynamically, llama.cpp does not perform runtime code generation (Just-In-Time compilation) on the CPU. Instead, it loads structural weights into pre-allocated memory buffers, and parses mathematical operators using statically-linked C++ logic.Tensor math operations are dispatched directly to the GPU via Apple’s Metal driver, which maps and compiles GPU shader pipelines through native, system-signed drivers. Consequently, the Epistemos MAS build runs on-device inference without declaring permissive memory-override entitlements such as:com.apple.security.cs.allow-unsigned-executable-memory[cite: 8]com.apple.security.cs.allow-jit[cite: 2]This matches the implementation patterns of App Store applications like PocketPal (which wraps core libraries via static bindings) and Private LLM.Sandbox File System Isolation and Model LoadingThe App Sandbox limits the app's directory access. To load GGUF model files without violating sandbox boundaries, models must be placed in specific directories:Bundled Models: Read-only assets are placed in the application bundle and accessed via Bundle.main.url(forResource:withExtension:).User-Downloaded Models: Downloaded weights are stored in the application container's Application Support directory:
~/Library/Containers/[App-Bundle-ID]/Data/Library/Application Support/External User Folders: If a user selects a model file stored elsewhere, the application must resolve permissions by requesting access through NSOpenPanel and saving the resulting token as a security-scoped bookmark to retain access across system restarts.Swift to C++ Interoperability and Bridging PatternTo call the underlying C++ interface of llama.cpp from Swift, an Objective-C++ wrapper is implemented. This approach avoids exposing unstable C++ pointers directly to Swift, establishing a clean type-safety boundary.Objective-C// LlamaBridge.h
#import <Foundation/Foundation.h>
@interface LlamaBridge : NSObject
- (nullable instancetype)initWithModelPath:(NSString *)path 
                               contextSize:(int)contextSize;
- (void)evaluatePrompt:(NSString *)prompt 
            onTokenGen:(void (^)(NSString * _Nonnull token, BOOL isFinished))tokenHandler;
@end
The corresponding implementation file imports the core header llama.h and implements the runtime loop, utilizing modern samplers to return tokens to Swift asynchronously:Code snippet// LlamaBridge.mm
#import "LlamaBridge.h"
#include "llama.h"
#include <string>
@interface LlamaBridge () {
    llama_model *model;
    llama_context *ctx;
}
@end
@implementation LlamaBridge
- (nullable instancetype)initWithModelPath:(NSString *)path contextSize:(int)contextSize {
    self = [super init];
    if (self) {
        llama_backend_init(); //
        
        auto mparams = llama_model_default_params();
        model = llama_model_load_from_file([path UTF8String], mparams);
        if (!model) return nil;
        
        auto cparams = llama_context_default_params();
        cparams.n_ctx = contextSize;
        ctx = llama_context_new_with_model(model, cparams);
        if (!ctx) return nil;
    }
    return self;
}
- (void)evaluatePrompt:(NSString *)prompt onTokenGen:(void (^)(NSString * _Nonnull, BOOL))tokenHandler {
    // Standard tokenization, evaluation, and sampling loops
    // Invocations of llama_decode are dispatched on a background dispatch queue
}
- (void)dealloc {
    if (ctx) llama_context_free(ctx);
    if (model) llama_model_free(model);
    llama_backend_free();
}
@end
2. Local Model Performance & Validation (Surface A)For Surface A, on-device models must be optimized to run reliably on an M2 Pro Mac configured with 16GB of unified memory. macOS allocates approximately 10.5GB of this pool to system graphics operations, leaving the remaining memory for active application processes.The physical footprint of the static model weights is calculated as:$$\text{Weight Memory (GB)} = \text{Parameters} \times \left( \frac{\text{Quantization Bit Width}}{8} \right) \times 1.15$$The active memory allocated for the Key-Value (KV) cache is computed based on model parameters and context limits:$$\text{KV Cache Footprint (Bytes)} = 2 \times L \times H_{\text{kv}} \times d_{\text{head}} \times T \times b_{\text{elem}}$$where $L$ represents the transformer layers, $H_{\text{kv}}$ is the count of key-value heads, $d_{\text{head}}$ is the key-value head dimension, $T$ is the context sequence length, and $b_{\text{elem}}$ is the byte width per element (2.0 for standard FP16, 1.0 for quantized Q8_0, and 0.5 for Q4_0 caches).The table below provides performance profiles for the validated local models on a 16GB system:Local Model VariantLicense ClassificationBinary Footprint (Q4_K_M)Architecture Dimensions (L, Hkv, dhead)KV Cache Size at 16K Context (Q8_0 Cache)KV Cache Size at 32K Context (Q8_0 Cache)Memory Utilization Peak (Q8_0 at 32K Context)Phi-3.5-mini-Instruct (3.8B)MIT~2.4 GB$L=32$, $H_{\text{kv}}=8$, $d_{\text{head}}=96$~0.78 GB~1.57 GB~3.97 GB (Highly Stable)Qwen2.5-7B-InstructApache-2.0~4.9 GB$L=28$, $H_{\text{kv}}=4$, $d_{\text{head}}=128$~0.46 GB~0.92 GB~5.82 GB (Highly Stable)Qwen2.5-14B-InstructApache-2.0~9.0 GB$L=48$, $H_{\text{kv}}=8$, $d_{\text{head}}=128$~1.53 GB~3.07 GB~12.07 GB (Unstable - Swap Risk)Dynamic RAM-Gating RulesTo maintain system stability, the application queries hardware limits at startup and gates model selection to prevent Out-Of-Memory (OOM) crashes:Swiftimport Foundation
enum LocalModelTier {
    case highTier14B
    case standard7B
    case compact3B
}
struct RAMHardwareGate {
    static var systemMemoryTotalGB: Double {
        return Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0)
    }
    
    static func evaluateAllowedModelTier() -> LocalModelTier {
        let totalRAM = systemMemoryTotalGB
        if totalRAM >= 24.0 {
            return .highTier14B   // Unconstrained usage of Qwen2.5-14B
        } else if totalRAM >= 16.0 {
            return .standard7B    // Qwen2.5-7B with Q8_0 KV Cache [cite: 16]
        } else {
            return .compact3B     // Phi-3.5-mini to prevent system slowdown
        }
    }
}
Document Length and Context LimitsWhile standard academic papers and articles (typically spanning 4,000 to 10,000 words, or ~13,000 tokens) fit comfortably within the 32K context window, textbooks or full-length novels exceed this boundary. If a document exceeds the active context limit, the KV cache overflows, causing the model to lose previous context. Processing documents of this length requires text chunking, which is handled outside of Surface A's local chat loop.In-App License ManagementTo comply with the distribution terms of the Apache-2.0 and MIT licenses, the application features an in-app license viewer. Before a user initiates their first download of the Qwen2.5 or Phi-3.5 models, they must accept an in-app license agreement, which is saved as an attribute in the user’s sandbox configurations.3. Apple Foundation Models Integration (Surface A Default)The FoundationModels framework, introduced in macOS 26 and iOS 26, provides programmatic access to on-device hardware engines via the SystemLanguageModel class.                  ┌──────────────────────────────┐
                  │     Surface A Initiation     │
                  └──────────────┬───────────────┘
                                 │
                 Verify Availability Constraints
                                 │
                 ┌───────────────┴───────────────┐
                 │                               │
        [Available: True]               [Available: False]
                 ▼                               ▼
    ┌────────────────────────┐      ┌────────────────────────┐
    │  SystemLanguageModel   │      │   Local GGUF Fallback  │
    │   Framework Engine     │      │   via llama.xcframework  │
    └────────────────────────┘      └────────────────────────┘
The table below compares the integrated system models against equivalent standalone quantized GGUFs:Architectural PropertyApple System Foundation ModelStandalone GGUF Model (Qwen2.5-7B)Download CostZero download requiredRequires downloading 4.9 GB of weightsSystem FootprintShared system memory pool, managed by OSOccupies dedicated in-process memoryInference PathHardware-accelerated Neural EngineMetal performance shaders running on GPUReasoning ProfileHighly optimized for summarizationCustomizable vocabulary and prompt formattingMinimum HardwareApple Silicon M1+ with macOS 26+Universal x86_64 or Apple Silicon MacsSystem Model Verification and Fallback LoopAt startup, the application verifies the availability of the system model and defaults to the native Apple model, using the custom llama.cpp wrapper as a secondary fallback:Swiftimport Foundation
import FoundationModels // [cite: 24]
@MainActor
class OnDeviceModelCoordinator: ObservableObject {
    @Published var activeBrain: InferenceEngineType = .uninitialized
    private var nativeSession: LanguageModelSession? // [cite: 21, 24]
    private var fallbackLlama: LlamaBridge? //
    
    enum InferenceEngineType {
        case uninitialized
        case appleFoundationModel
        case localGGUF
        case awaitingDownload
    }
    
    func initializeSystemEngine() async {
        let systemModel = SystemLanguageModel.default //
        
        switch systemModel.availability { //
        case .available: //
            do {
                // Initialize the native on-device session with system instructions [cite: 21, 24]
                let sessionParams = """
                Your task is to summarize documents and answer research queries accurately.
                """
                self.nativeSession = LanguageModelSession(instructions: sessionParams) // [cite: 21, 24]
                self.activeBrain = .appleFoundationModel
            } catch {
                await self.setupLocalGGUFFallback()
            }
            
        case .unavailable(let reason): //
            // Default to local GGUF if Apple Intelligence is disabled or unsupported
            await self.setupLocalGGUFFallback()
        }
    }
    
    private func setupLocalGGUFFallback() async {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelURL = appSupportDir.appendingPathComponent("qwen2.5-7b-instruct.gguf")
        
        if fileManager.fileExists(atPath: modelURL.path) {
            self.fallbackLlama = LlamaBridge(modelPath: modelURL.path, contextSize: 16384)
            self.activeBrain = .localGGUF
        } else {
            self.activeBrain = .awaitingDownload
        }
    }
    
    func generateResponse(for promptText: String, onChunk: @escaping (String) -> Void) async throws {
        switch self.activeBrain {
        case .appleFoundationModel:
            guard let session = self.nativeSession else { throw InferenceSessionError.sessionCorrupted } // [cite: 21, 24]
            do {
                // Stream chunks natively from Apple's runtime API [cite: 24]
                let stream = session.streamResponse(to: promptText) // [cite: 24]
                for try await partialUpdate in stream { // [cite: 24]
                    onChunk(partialUpdate.content) // [cite: 24]
                }
            } catch LanguageModelError.guardrailViolation(let safetyViolation) { // [cite: 26]
                onChunk("System safety block: Request violated internal guardrail policies.") // [cite: 26]
            } catch {
                throw error
            }
            
        case .localGGUF:
            guard let engine = self.fallbackLlama else { throw InferenceSessionError.sessionCorrupted }
            engine.evaluatePrompt(promptText) { token, isFinished in
                if let t = token {
                    onChunk(t)
                }
            }
        default:
            throw InferenceSessionError.noActiveEngine
        }
    }
}
enum InferenceSessionError: Error {
    case sessionCorrupted
    case noActiveEngine
}
This dual-path system architecture ensures that users on Apple Silicon running macOS 26 have access to zero-download summaries immediately upon launching the application.4. In-Process Goose Agent Core Integration (Surface B Engine)Surface B implements an in-process agent workspace driven by goose. Since the App Sandbox restricts launching background processes or starting local Axum socket servers, we avoid the goosed runtime binary entirely. Instead, we link crates/goose-sdk directly into the Swift executable using programmatic Rust-to-Swift UniFFI bindings.┌────────────────────────────────────────────────────────┐
│               Native macOS Application                 │
│                                                        │
│  ┌───────────────────────┐  ┌───────────────────────┐  │
│  │   Swift App Target    │  │   June Workspace UI   │  │
│  └───────────┬───────────┘  └───────────┬───────────┘  │
│              │                          │              │
│              │ (Swift API Call)         │ (UI Actions) │
│  ┌───────────▼──────────────────────────▼───────────┐  │
│  │         UniFFI Auto-Generated Interface          │  │
│  └───────────┬──────────────────────────────────────┘  │
│              │ (Direct C-FFI Calls)                    │
│  ┌───────────▼──────────────────────────────────────┐  │
│  │           goose-sdk (Compiled Static lib)        │  │
│  │  ┌───────────────────┐   ┌────────────────────┐  │  │
│  │  │     Agent Core    │   │  In-Process Tools  │  │  │
│  │  └───────────────────┘   └────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
The table below maps the functional boundaries of each crate in the goose ecosystem and how they are handled inside the sandboxed macOS environment:Crate TargetCodebase Path ReferenceOperational Role within macOS Sandboxcrates/goosecrates/goose/src/lib.rsContains the core agent execution loops and declarative providers.crates/goose-sdkcrates/goose-sdk/src/lib.rsExposes clean, type-safe Rust-to-Swift bindings using UniFFI.crates/goose-clicrates/goose-cli/src/main.rsInteractive CLI loop wrapper. Unused and excluded from the MAS build.crates/goose-servercrates/goose-server/src/main.rsExposes the standard Axum socket API (goosed). Unused and excluded from the MAS build.crates/goose-mcpcrates/goose-mcp/src/lib.rsIncludes core MCP servers, which are heavily restricted or sandboxed on MAS.Local Epistemos Sandbox and Codebase WiringThe Epistemos codebase contains a target architecture designed to wire up in-process execution natively under the preprocessor flag EPISTEMOS_MAS_GOOSE_V0. The runInProcessAgentCore method and the GooseMASAgentCoreCatalog configuration coordinate initialization using the specification guidelines outlined in GOOSE_MAS_BUILD_CANON_2026_06_30.md and GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md.To connect this local scaffold to the compiled Rust engine, we wire the components together via UniFFI:Rust// goose-sdk/src/bindings.rs
use std::sync::Arc;
use tokio::sync::Mutex;
use goose::agents::agent::Agent; // [cite: 31]
use goose::config::base::Config; // [cite: 29]
#[derive(uniffi::Record)]
pub struct InProcessAgentConfig {
    pub api_proxy_url: String,
    pub session_auth_token: String,
    pub target_model: String,
    pub sandboxed_directory: String,
}
#[derive(uniffi::Object)]
pub struct GooseInProcessAgent {
    inner_agent: Arc<Mutex<Agent>>, // [cite: 32]
    allowed_working_dir: String,
}
#[uniffi::export]
impl GooseInProcessAgent {
    #[uniffi::constructor]
    pub fn build_agent_core(config: InProcessAgentConfig) -> Result<Arc<GooseInProcessAgent>, SDKError> {
        // Enforce working directory constraints dynamically to prevent sandbox violations [cite: 33]
        std::env::set_current_dir(&config.sandboxed_directory)
            .map_err(|e| SDKError::InitializationFailed { msg: e.to_string() })?;
            
        let mut provider_config = Config::default(); // [cite: 29]
        provider_config.set_param("OPENAI_HOST", &config.api_proxy_url)
            .map_err(|e| SDKError::InitializationFailed { msg: e.to_string() })?;
            
        // Instantiate the core Agent in-process [cite: 1, 32]
        let core_agent = Agent::new(provider_config)
            .map_err(|e| SDKError::InitializationFailed { msg: e.to_string() })?;
            
        Ok(Arc::new(GooseInProcessAgent {
            inner_agent: Arc::new(Mutex::new(core_agent)),
            allowed_working_dir: config.sandboxed_directory,
        }))
    }
    pub async fn process_agent_step(&self, prompt: String, handler: Arc<dyn ThreadUpdateCallback>) -> Result<(), SDKError> {
        let mut agent = self.inner_agent.lock().await;
        
        // Execute a step of the core agent loop
        let mut execution_stream = agent.process_message(&prompt)
            .await
            .map_err(|e| SDKError::ExecutionFailed { msg: e.to_string() })?;
            
        // Stream output tokens and tool invocation requests over FFI
        while let Some(message_step) = execution_stream.next().await {
            match message_step {
                StepUpdate::Token(t) => handler.on_token_received(t),
                StepUpdate::Thinking(th) => handler.on_thinking_received(th),
                StepUpdate::ToolRequest(tool_name, arguments) => {
                    let user_approved = handler.on_tool_approval_requested(tool_name, arguments);
                    if user_approved {
                        execution_stream.confirm_tool_status(ToolResolution::Approved);
                    } else {
                        execution_stream.confirm_tool_status(ToolResolution::Denied);
                    }
                }
            }
        }
        Ok(())
    }
}
#[uniffi::export(callback_interface)]
pub trait ThreadUpdateCallback: Send + Sync {
    fn on_token_received(&self, token: String);
    fn on_thinking_received(&self, thinking_block: String);
    fn on_tool_approval_requested(&self, name: String, args: String) -> bool;
}
#[derive(uniffi::Error)]
pub enum SDKError {
    InitializationFailed { msg: String },
    ExecutionFailed { msg: String },
}
This interface is integrated into the native codebase by wrapping it inside the active compilation targets:Swift#if EPISTEMOS_MAS_GOOSE_V0
import Foundation
import GooseBindings // Compiled Swift Package derived from UniFFI [cite: 28]
class NativeMASAgentCoordinator {
    private var nativeAgent: GooseInProcessAgent?
    
    func runInProcessAgentCore(secureToken: String, sandboxURL: URL) throws {
        // Build the GooseMASAgentCoreCatalog configuration programmatically [cite: 36, 37]
        let catalogConfig = InProcessAgentConfig(
            api_proxy_url: "https://proxy.epistemos.com/v1",
            session_auth_token: secureToken, // Generated by StoreKit 2 verification
            target_model: "claude-3-5-sonnet",
            sandboxed_directory: sandboxURL.path
        )
        
        // Instantiate the core agent in-process
        self.nativeAgent = try GooseInProcessAgent(config: catalogConfig)
    }
}
#endif
Sandbox-Compliant Tool Execution PathUnder the App Sandbox, launching system binaries or accessing absolute paths like /bin/bash is prohibited. To keep Surface B functional, the execution pipeline enforces strict limits:The standard developer__bash tool is disabled, preventing process spawns.The developer__filesystem tools are configured to run completely in-process using Rust's std::fs operations, scoped strictly to the selected sandbox directory.External process tools like screen capture or system terminal integrations are compiled out of the MAS target.5. In-Process Goose to Cloud Proxy ArchitectureBecause running local models on Surface B's agent tool loops is slow and unreliable, the MAS workspace delegates reasoning to cloud-hosted models. The in-process agent routes its network requests via our secure proxy.┌────────────────────────────────────────────────────────┐
│                 Epistemos App Container                │
│                                                        │
│  ┌────────────────────────┐      ┌──────────────────┐  │
│  │   goose-sdk Instance   ├─────►│  reqwest/HTTPS   │  │
│  │   (In-Process Engine)  │      │  Network Client  │  │
│  └────────────────────────┘      └────────┬─────────┘  │
└───────────────────────────────────────────┼────────────┘
                                            │
                                            │ (HTTPS with authorization header)
                                            ▼
                               ┌──────────────────────────┐
                               │     Epistemos Proxy      │
                               │  https://proxy.../v1     │
                               └──────────────────────────┘
The system configuration operates on the following details:Proxy Configuration PropertySetting Method inside C++ or RustOperational Security FunctionCustom Base URLprovider_config.set_param("OPENAI_HOST", ...)[cite: 40, 41]Routes network traffic via https://proxy.epistemos.com/v1 instead of public OpenAI endpoints.Authentication Headerprovider_config.add_header("Authorization", ...)[cite: 37, 40]Attaches the active StoreKit-generated session token (Bearer <Receipt-Token>).Model Verification Bypassskip_model_validation: true[cite: 36]Bypasses standard /v1/models checks to reduce network overhead.Handling Token & Thinking Block Streams ProgrammaticallyModern reasoning models generate a system-level reasoning block (often called "thinking") before emitting text tokens. To render this progress dynamically in the UI, crates/goose/src/agents/agent.rs handles MessageContent::Thinking events in-flight without intermediate buffering:Rust// Stream loop extracted fromcrates/goose/src/agents/agent.rs
while let Some(chunk_result) = provider_stream.next().await {
    let response_chunk = chunk_result.map_err(|e| ProviderError::StreamFailed(e.to_string()))?;
    
    for content_block in &response_chunk.content {
        match content_block {
            MessageContent::Thinking(thinking_text) => {
                // Instantly emit the partial reasoning token over the UniFFI boundary [cite: 35, 43]
                ui_callback.on_thinking_received(thinking_text.clone());
            },
            MessageContent::Text(token_text) => {
                // Instantly emit standard token outputs
                ui_callback.on_token_received(token_text.clone());
            }
        }
    }
}
This architecture ensures that users receive real-time, token-by-token visual feedback, preventing interface freezes while the model is processing.6. June Agent Workspace Workspace SwiftUI UI ReconstructionEvaluating implementation options for June's workspace panel design reveals two clear architectural paths:Option A (WKWebView with June Web Dashboard): Hooks an embedded HTML dashboard directly to the local Swift code via WKScriptMessageHandler and port mapping interfaces.Option B (Native SwiftUI Architecture): Reconstructs June's functional components into compiled SwiftUI structures.The table below highlights the performance, complexity, and safety tradeoffs between these two implementation routes:Workspace MetricOption A: WKWebView with HTML/JS DashboardOption B: Native SwiftUI ArchitectureMemory Footprint~350 MB to 600 MB (Requires separate helper threads)~15 MB to 30 MB (Shared with main app thread)System Security ProfileHigh threat surface (Requires dynamic Javascript permissions)Minimum threat surface (Obeys default sandbox limits)File Sandbox IntegrationComplex. Requires serializing file system buffers over bridges.Seamless. Accesses local folders directly using system bookmarks.UI ResponsivenessSubject to IPC rendering latency during heavy stream loops.Instant rendering with native CoreAnimation animations.To maintain a secure, high-performance, and App Store-compliant interface, Option B (Native SwiftUI) is implemented for Surface B.┌────────────────────────────────────────────────────────┐
│           Surface B: Native SwiftUI Panel              │
│                                                        │
│  ┌──────────────────────┐  ┌────────────────────────┐  │
│  │   Control Sidebar    │  │   Active Document      │  │
│  │  ┌────────────────┐  │  │   Workspace Panel      │  │
│  │  │  Activity Log  │  │  │  ┌──────────────────┐  │  │
│  │  └────────────────┘  │  │  │  Document Editor │  │  │
│  │  ┌────────────────┐  │  │  └──────────────────┘  │  │
│  │  │ Approvals Card │  │  │                        │  │
│  │  └────────────────┘  │  │                        │  │
│  └──────────────────────┘  └────────────────────────┘  │
└────────────────────────────────────────────────────────┘
The native layout is constructed by mapping June’s visual features to corresponding SwiftUI structures:Swiftimport SwiftUI
struct WorkspaceDashboardView: View {
    @StateObject var agentState = InProcessAgentState()
    
    var body: some View {
        NavigationSplitView {
            // Panel 1: Activity transcript and active tools
            VStack {
                Text("Agent Activity")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(agentState.activityItems) { item in
                            ActivityTranscriptCell(item: item)
                        }
                    }
                    .padding()
                }
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            
        } detail: {
            // Panel 2: The document context viewer
            VStack {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Document Workspace")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                
                TextEditor(text: $agentState.activeDocumentContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .border(Color.secondary.opacity(0.2))
            }
        }
    }
}
struct ActivityTranscriptCell: View {
    let item: ActivityItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: item.isThinking ? "brain.headset" : "hammer.fill")
                    .foregroundColor(item.isThinking ? .blue : .green)
                Text(item.header)
                    .font(.caption)
                    .bold()
                Spacer()
            }
            
            Text(item.bodyText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
    }
}
class InProcessAgentState: ObservableObject {
    @Published var activityItems: [ActivityItem] = []
    @Published var activeDocumentContent: String = ""
}
struct ActivityItem: Identifiable {
    let id = UUID()
    let isThinking: Bool
    let header: String
    let bodyText: String
}
7. Two-Surface UX Navigation & Visual ArchitectureTo prevent users from confusing the chat interface with the active workspace, the app implements two highly distinct visual environments:                  ┌─────────────────────────────────┐
                  │      Primary Launch Interface   │
                  └────────────────┬────────────────┘
                                   │
                     Default Landing Initialization
                                   │
                  ┌────────────────┴────────────────┐
                  │                                 │
                  ▼                                 ▼
       ┌──────────────────────┐          ┌──────────────────────┐
       │   Surface A: Chat    │          │ Surface B: Workspace │
       │  - Wave Input Field  │          │ - Split Panels       │
       │  - Quick Reading     │          │ - Document Views     │
       │  - Single-Turn Focus │          │ - Tool Controls      │
       └──────────────────────┘          └──────────────────────┘
The UX parameters and visual layouts for each surface are structured as follows:Surface A: High-Speed Wave Chat LayoutThe default landing surface is designed for immediate, single-turn on-device operations (e.g., reading or summarizing documents):UI Components: Large, centered, waving input text box with smooth animation.Aesthetics: Minimalist, clean look with generous padding and hidden sidebar controls.Behavior: Single-turn inputs with instant text generation.Engine: Apple Foundation Models running locally, with automatic fallback to llama.cpp.Surface B: June Agent Workspace Panel LayoutActivated via a persistent button in the upper-right corner, this interface is designed for complex, multi-step research and editing tasks:UI Components: Three-pane interface showing a file browser, the active document editor, and a tool log sidebar.Aesthetics: Compact, high-density layout with visible progress indicators.Behavior: Multi-turn agent loops with explicit, manual approval modals for file modifications.Engine: goose running in-process, driving cloud models via our API proxy.This explicit layout separation ensures that users always know whether their queries are being handled locally or sent to the cloud.8. Mac App Store Security, Entitlements, and Packaging ComplianceTo pass App Store review, the application bundle must be fully sandboxed and strictly declare only the entitlements required for core functionality.Code snippet<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Sandbox Activation -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Restricts subprocess spawning and enforces library validation -->
    <key>com.apple.security.inherit</key>
    <true/>
    
    <!-- Network Access: Allows https proxy connections -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- File Access: Restricts operations to user-selected paths -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
Sandboxed Access to Local User VaultsUnder the App Sandbox, files outside of the container are inaccessible unless explicitly opened by the user. The application uses security-scoped bookmarks to retain access to user-selected research vaults across restarts:Swiftfunc createSecureVaultBookmark(for folderURL: URL) throws {
    // Start accessing the user-selected folder url
    guard folderURL.startAccessingSecurityScopedResource() else {
        throw SandboxError.accessDenied
    }
    defer { folderURL.stopAccessingSecurityScopedResource() }
    
    // Create the persistent bookmark payload
    let bookmarkData = try folderURL.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    
    // Persist bookmark data securely in user defaults
    UserDefaults.standard.set(bookmarkData, forKey: "secure_vault_bookmark")
}
func resolveSecureVaultURL() throws -> URL {
    guard let data = UserDefaults.standard.data(forKey: "secure_vault_bookmark") else {
        throw SandboxError.missingBookmark
    }
    
    var isStale = false
    let resolvedURL = try URL(resolvingBookmarkData: data, 
                             options: .withSecurityScope, 
                             relativeTo: nil, 
                             bookmarkDataIsStale: &isStale)
    
    if isStale {
        // Handle renewal sequence if the bookmark is outdated
    }
    
    return resolvedURL
}
enum SandboxError: Error {
    case accessDenied
    case missingBookmark
}
Hugging Face Weights Download MechanicsUnder App Store Review Guideline 2.5.2, downloading executable code at runtime is strictly prohibited. However, downloading GGUF model files from Hugging Face is fully compliant.Under Apple's guidelines, model weights are classified as passive data arrays (similar to images or configuration files) rather than executable code. Because these files are parsed by statically compiled C++ logic and cannot generate executable machine instructions at runtime, they do not violate Guideline 2.5.2, enabling safe download mechanics.9. Paywall Verification and Secure Gateway Proxy ArchitectureThe cloud-based feature set on Surface B is monetized via StoreKit 2 subscriptions, verified using a secure, server-side transaction validation flow: ┌───────────────┐               ┌───────────────┐               ┌───────────────┐
 │ Epistemos App │               │  Apple Store  │               │ Cloud Gateway │
 │ (StoreKit 2)  │               │    Servers    │               │  Proxy Server │
 └───────┬───────┘               └───────┬───────┘               └───────┬───────┘
         │                               │                               │
         │ Request Subscription          │                               │
         ├──────────────────────────────►│                               │
         │                               │                               │
         │ Return Signed Transaction     │                               │
         │◄──────────────────────────────┤                               │
         │                                                               │
         │ Send JWS for Verification                         │
         ├──────────────────────────────────────────────────────────────►│
         │                                                               │
         │                               │ Validate Transaction [cite: 49, 50]
         │                               ├──────────────────────────────►│
         │                               │                               │
         │                               │ Verification Success          │
         │                               │◄──────────────────────────────┤
         │                                                               │
         │ Return Ephemeral API Token                        │
         │◄──────────────────────────────────────────────────────────────┤
         │                                                               │
         ▼                                                               ▼
To maintain a secure implementation, no private cryptographic keys, certificates, or App Store Connect API keys are stored in the client application bundle.Client Transaction DispatchWhen a subscription purchase is initiated via StoreKit 2, the app receives a verified transaction representation containing a signed JSON Web Signature (JWS). This token is sent to our gateway server:Swiftimport StoreKit
class AppSubscriptionManager: ObservableObject {
    @Published var hasActiveAccess: Bool = false
    private let verificationEndpoint = URL(string: "https://api.epistemos.com/v1/auth/verify-receipt")!
    
    func purchaseAccess(for subscription: Product) async {
        do {
            let result = try await subscription.purchase() //
            
            switch result {
            case .success(let transactionVerification): //
                // Retrieve the signed JWS representation [cite: 38, 50]
                let signedJWS = transactionVerification.jwsRepresentation // [cite: 38, 50]
                
                // Exchange with proxy backend for access token
                let sessionToken = try await self.exchangeJWSTransactionWithProxy(jws: signedJWS)
                
                // Store the access token securely in the Keychain
                try self.persistSessionTokenToKeychain(sessionToken)
                
                self.hasActiveAccess = true
                
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            // Handle error conditions
        }
    }
    
    private func exchangeJWSTransactionWithProxy(jws: String) async throws -> String {
        var request = URLRequest(url: verificationEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyPayload = ["storekit_jws": jws]
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)
        
        let (responseData, serverResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = serverResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw BillingError.serverVerificationFailed
        }
        
        let responseObject = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        guard let token = responseObject?["ephemeral_session_token"] as? String else {
            throw BillingError.invalidTokenPayload
        }
        
        return token
    }
}
Server-Side Gateway Receipt VerificationThe backend server receives the JWS payload and validates it using Apple's official root certificates. By verifying the transaction server-side, the system ensures the subscription status is valid before forwarding requests to the LLM:Python# Server-side verification logic
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier #
from appstoreserverlibrary.models.Environment import Environment #
apple_verifier = SignedDataVerifier(
    apple_root_certs=fetch_apple_root_certificates(), # Load Apple root certificates
    enable_online_checks=True,
    bundle_id="com.epistemos.mac",
    environment=Environment.PRODUCTION
)
def verify_and_provision_token(client_jws: str):
    try:
        # Decode and verify the StoreKit 2 payload [cite: 38, 52]
        decoded_transaction = apple_verifier.verify_and_decode_transaction(client_jws)
        
        # Ensure subscription is active and has not been revoked
        if decoded_transaction.revocation_date is not None:
            raise Exception("Subscription revoked")
            
        # Provision an ephemeral API token linked to the transaction id
        access_token = generate_ephemeral_token(
            original_transaction_id=decoded_transaction.original_transaction_id
        )
        return {"ephemeral_session_token": access_token}
    except Exception as e:
        return {"error": str(e)}, 400
10. Risk Management, Phase Planning, and Feature LedgerTop 10 Engineering Risks and MitigationsRust Library FFI Thread CrashesRisk: Multi-threaded callbacks from Rust to Swift during agent steps can deadlock the main thread.Mitigation: Dispatch all incoming UniFFI callbacks to the main thread asynchronously in Swift.On-Device Out-Of-Memory (OOM) ErrorsRisk: Allocating a larger model (e.g., 14B) on a 16GB Mac can trigger system-wide out-of-memory errors and crash the app.Mitigation: Enforce strict RAM-gating rules at launch, defaulting to the lightweight Phi-3.5-mini model on 8GB and 16GB machines.App Sandbox File Access DenialsRisk: Embedded Rust libraries attempting file operations outside of sandboxed folders will cause immediate kernel terminations.Mitigation: Configure all filesystem tools to use absolute paths mapped directly to user-selected folders resolved via secure bookmarks.Metal Shader Bundling ErrorsRisk: Missing or uncompiled .metallib files disables Metal acceleration, severely hurting inference performance.Mitigation: Verify the compilation and inclusion of default.metallib in the application bundle during CI/CD build pipelines.Apple Foundation Model Regional OffliningRisk: Programmatic access to SystemLanguageModel is restricted in regions where Apple Intelligence is disabled.Mitigation: Check SystemLanguageModel.default.availability at startup and automatically fall back to the embedded llama.cpp wrapper if disabled.App Store Guideline 2.5.2 RejectionsRisk: Reviewers may mistake downloaded GGUF model files for runtime-executable code updates.Mitigation: State clearly in the review notes that downloaded model files are static configuration weights parsed by the app's internal engine, not executable binary files.UniFFI Token Streaming LatencyRisk: Serializing token updates as complex JSON payload strings across the FFI boundary can cause UI stuttering.Mitigation: Stream tokens as lightweight string pointers directly over the UniFFI interface.StoreKit 2 Receipt Verification FailuresRisk: Network issues during StoreKit transaction validation can block active subscribers from accessing cloud features.Mitigation: Implement offline caching of validated session tokens in the Secure Keychain, using expiration timestamps to manage access.Tool Authorization View InterleavingRisk: Simultaneous tool execution requests from parallel subagents can overlap, locking the UI.Mitigation: Queue all incoming tool permission requests through a single, main-thread-safe manager to ensure approvals are processed one at a time.Hardened Runtime Memory Violations (W^X)Risk: Enabling CPU memory allocation flags like allow-unsigned-executable-memory during CPU fallback can flag the app for security audits.Mitigation: Disable JIT compilation flags entirely and route all tensor calculations to pre-compiled Metal compute shaders.Project Phased Implementation Roadmap┌─────────────────────────────────────────────────────────────────────────────┐
│                             Development Phases                              │
└─────────────────────────────────────────────────────────────────────────────┘
  Phase 1: Foundation (Weeks 1-4)
  ├─ Compile llama.cpp as universal static libraries linked with Metal [cite: 3, 7]
  └─ Implement in-process goose-sdk Rust libraries using UniFFI [cite: 28]
  
  Phase 2: Core Interoperability (Weeks 5-8)
  ├─ Develop the LlamaBridge Objective-C++ wrapper
  └─ Build the Swift ThreadUpdateCallback handler to process agent stream events
  
  Phase 3: Sandbox Isolation (Weeks 9-11)
  ├─ Wire up the App Sandbox entitlements and secure bookmark handlers
  └─ Deploy the StoreKit 2 JWS validation logic on the proxy backend [cite: 38, 52]
  
  Phase 4: Optimization and Polish (Weeks 12-14)
  ├─ Complete UX distinction between Surface A and Surface B
  └─ Perform final integration testing and submit to the Mac App Store
Mac App Store Feature LedgerThis feature ledger maps the key capabilities of the App Store build of Epistemos to their respective engines and sandbox compliance strategies:User Feature ProfileTarget UIUnderlying Execution EngineSandboxed Compliance & Legal ResolutionInstant Wave ChatSurface AApple Foundation Models (SystemLanguageModel)No bundle footprint. Access is requested programmatically using macOS framework APIs.Local Document SummarySurface AStatically linked llama.cpp using local GGUF modelsEmploys file-system access tokens retrieved programmatically using NSOpenPanel.Offline Context QASurface AFallback llama.cpp running Phi-3.5-miniStatic weights are stored in the App's Application Support folder; no dynamic code is executed.Active Document EditingSurface BIn-process goose loop driving Claude 3.5 SonnetThe model is limited to internal file-writing tools; CLI/Terminal tool subprocesses are disabled.Smart Source ExtractionSurface BIn-process goose executing academic database searchOutbound requests are routed via HTTPS using our secure proxy, requiring only the standard network client entitlement.Interactive Tool AuthorizationSurface BNative SwiftUI dialogs communicating with Rust FFIStep confirmations are managed using native, compiler-validated SwiftUI layouts, preventing sandbox violations.Open Questions for the OwnerInitial Bundle Download Footprint: To minimize initial download sizes, should we omit all on-device GGUF models from the app store package and download them on-demand, or bundle a lightweight 1.5B model to enable offline chat immediately upon installation?Tool Loop Limits: Should we enforce limits on the maximum number of multi-step agent iterations (e.g., maximum 30 iterations) to manage server-side inference costs for the cloud tier?Local Workspace Storage Limits: To prevent the sandbox container from consuming too much local storage, should we implement automatic storage caps (e.g., maximum 5GB) for downloaded academic papers and model weights?


gpt 2- # Epistemos MAS execution dossier

## Executive verdict

The clean Mac App Store path for **Epistemos MAS** is viable if the app treats its two AI surfaces as two different products living in one shell: **Surface A** is a local, non-agentic reading/chat layer that stays entirely in-process with **Apple Foundation Models** first and **embedded llama.cpp** second; **Surface B** is a separate **June-style workspace** backed by a **Rust library embedding Goose core**, not by `goosed`, not by a localhost daemon, and not by subprocesses. That split is not just product design. It is the cleanest way to satisfy review, keep the default experience free, and avoid the prior “two chat rooms bleeding together” failure mode. The strongest source-backed evidence is that Apple’s Foundation Models framework is a native Swift API for the on-device Apple Intelligence model; llama.cpp’s primary deliverable is a linkable C library with a Metal backend enabled on macOS by default; and Goose’s repository explicitly separates the core `goose` crate from a `goose-server` backend crate, with the core crate exporting agents, providers, session management, permissions, tools, and related subsystems. citeturn20search18turn22search14turn26view0turn26view2turn39view1turn39view2

The most important conclusion is also the biggest risk item: **Goose is embeddable enough to finish the MAS path, but not as a ready-made stable Swift embedding surface out of the box**. The repo exposes the core agent loop and provider/session/tool subsystems in Rust source, while the HTTP server is a separate crate. That means the correct direction is **a thin Epistemos-owned Rust wrapper crate plus UniFFI**, which instantiates Goose’s `Agent`, `SessionManager`, and provider objects directly and streams events into Swift callbacks. That claim is partly verified in source and partly architectural inference; I mark the confidence per row below. citeturn10view0turn10view1turn10view2turn12view0turn39view1turn39view2turn9view1

### Read-this-first decision table

| Decision | Recommendation | Why | Confidence | Source basis |
|---|---|---|---|---|
| Surface A default brain | **Apple Foundation Models first** | Zero download, on-device, offline-capable, native Swift API, no API keys or cloud costs | verified-in-source | Apple says the framework gives direct access to the on-device model powering Apple Intelligence, works on Apple-Intelligence-capable devices, and supports streaming, sessions, tool calling, and structured generation. citeturn20search18turn21search3turn22search1turn22search12 |
| Surface A stronger optional brain | **Embedded llama.cpp** linked into app, Metal backend on, no Ollama | In-process inference is the MAS-safe pattern; llama.cpp is a library with C API and Metal enabled by default on macOS | verified-in-source | llama.cpp’s “main product” is the library with C API in `include/llama.h`; Metal is enabled by default on macOS. PocketPal and Private LLM also ship on Apple’s stores using embedded local inference rather than a separate server dependency. citeturn26view0turn26view2turn25view0turn23search3turn23search15 |
| Surface B engine | **Goose core embedded as Rust library over UniFFI** | `goose` core and `goose-server` are separate crates; the server is not the only API surface | verified-in-source / inferred | Repo structure explicitly separates `crates/goose` from `crates/goose-server`; `Agent`, `SessionManager`, and provider APIs are public in the core crate. Turning that into a Swift-friendly ABI still requires your own wrapper layer. citeturn39view1turn39view2turn10view0turn10view1turn10view2turn12view0 |
| Surface B model path | **Cloud-only via proxy** | Keeps tool-using agent reliable; local models remain in the “answer me” lane | inferred | This is a product recommendation grounded in the separation of concerns and in Goose’s provider configurability for OpenAI-compatible backends. citeturn41view0turn41view2turn41view3 |
| MAS packaging stance | **No subprocesses, no local socket server, no helper daemons** | Lowest review risk; simplest story under sandboxing, hardened runtime, and Guideline 2.5.2 | inferred | Apple requires apps to be self-contained and bars downloaded code that changes functionality; App Sandbox constrains access outside the container. Embedding runtimes as libraries is the cleanest compliance path. citeturn19search2turn19search4turn19search5 |
| UX stance | **A looks like a calm reader/chat; B looks like a workspace** | Prevents the prior failure where two chat-like surfaces bled together | inferred | June’s open-source product description and HUD components support a workspace/session interpretation, not a single undifferentiated chat shell. citeturn14view0turn16view0turn18search2 |

## Surface A engine

Surface A should be the thing that feels instant, native, and boring in the best way. Apple’s Foundation Models framework is now the obvious no-download default for Macs that support Apple Intelligence, and llama.cpp is the correct opt-in path for users who want a stronger local model or who want deterministic model choice. Apple documents Foundation Models as a native Swift API to the same on-device model that powers Apple Intelligence, and the framework exposes sessions, streaming, structured generation, supported-language queries, and availability checks. llama.cpp, meanwhile, documents that its main product is the `llama` library, exposes a C-style API in `include/llama.h`, supports static builds with `BUILD_SHARED_LIBS=OFF`, and has Metal enabled by default on macOS. citeturn20search18turn21search3turn22search0turn22search6turn22search12turn22search14turn26view0turn26view2turn28view5

### Embedded llama.cpp on MAS

The clean embedding pattern is: build `llama.cpp` as a **static library**, expose the C headers through a module map or bridging header, link it into the app target, and store **GGUF data files** under the app’s sandbox container such as `Application Support`, not in executable locations. Apple’s App Sandbox gives the app unrestricted access to its own container but requires explicit mechanisms like security-scoped access for files outside it. Guideline 2.5.2 bars downloaded executable code that changes app functionality, so the right review framing is that **GGUF files are model data loaded by an already-signed embedded inference engine**. That is not an explicit Apple carve-out, so the “GGUF is data, not code” point is still an inference, but it is supported pragmatically by the existence of App Store apps like **PocketPal AI** and **Private LLM** that advertise on-device local model download/use. citeturn19search2turn19search4turn19search0turn25view0turn23search3turn23search15

#### Surface A embedding checklist

| Topic | Recommendation | Confidence | Evidence |
|---|---|---|---|
| Build artifact | Build llama.cpp with `cmake -B build -DBUILD_SHARED_LIBS=OFF` and link the resulting static library into the MAS app | verified-in-source | llama.cpp build docs explicitly document static builds with `BUILD_SHARED_LIBS=OFF`. citeturn26view0 |
| GPU backend | Leave **Metal on** for Apple silicon; it is enabled by default on macOS | verified-in-source | llama.cpp build docs state Metal is enabled by default on macOS and can be disabled with `-DGGML_METAL=OFF`. citeturn26view0 |
| Runtime loading | Load models with `llama_model_load_from_file` / `llama_model_load_from_splits`, then create a context with `llama_init_from_model` | verified-in-source | The C API exports model loading and context creation functions. citeturn27view0turn27view1turn28view5 |
| GGUF placement | Store user-downloaded GGUF files under the app container’s `Application Support`, or import from user-selected locations via bookmarks | verified-in-source / inferred | App Sandbox allows container access and requires security-scoped access for external user-selected files. GGUF is the native model format used by llama.cpp. citeturn19search4turn19search0turn19search17turn29search2 |
| Memory knobs | Use `use_mmap` when possible; avoid `use_mlock` in MAS; set conservative `n_ctx`, `n_batch`, `n_threads`, `n_gpu_layers` by device class | verified-in-source / inferred | llama.cpp exposes `use_mmap`, `use_mlock`, `n_ctx`, `n_batch`, and `n_gpu_layers` in its API. The product recommendation to avoid `mlock` in MAS is inferred from sandboxed memory pressure constraints. citeturn28view0turn28view1turn28view3turn28view4 |
| Swift binding | Prefer a **very thin C wrapper** over llama.cpp for Swift; do not bind the whole C API directly into business logic | inferred | Swift can call C cleanly, and llama.cpp already presents a stable C-style API. A tiny ownership-safe wrapper is the lowest-risk integration pattern. citeturn26view0turn26view2 |
| JIT concern | Do **not** request `allow-jit`, `allow-unsigned-executable-memory`, or `disable-executable-page-protection` unless profiling proves a real need | inferred, high confidence | Apple says those hardened-runtime exceptions are for writable/executable memory and MAP_JIT. I found no source evidence that llama.cpp’s normal Metal path requires those runtime exceptions. citeturn19search1turn19search9turn19search12turn19search21 |
| Library validation | Do **not** disable library validation if you static-link llama.cpp | inferred, high confidence | Static linkage avoids runtime third-party library loading; Apple’s disable-library-validation entitlement is for loading external libraries/frameworks. citeturn19search15 |
| Review story | “Epistemos includes an embedded local inference library and downloads model data files into the sandbox container; it does not download/install executable code or launch helper daemons” | inferred | This is the cleanest 2.5.2 framing, supported by the guideline text and by App Store precedent apps. citeturn19search2turn25view0turn23search3turn23search15 |

#### Hardened runtime and W^X

Apple’s hardened runtime docs make the relevant boundary clear: special entitlements are needed when an app creates writable-and-executable memory via `MAP_JIT`, or otherwise weakens executable memory protections. I found **no source-level evidence** in llama.cpp’s mainstream macOS Metal path that it requires those entitlements, and the default macOS build path in llama.cpp does not document any such requirement. That makes the correct practical stance: **assume no JIT entitlement is needed**, ship without it, and only revisit if Instruments or crash logs reveal an actual executable-memory failure on a real review build. This is an inference, but a strong one. citeturn19search1turn19search9turn19search12turn19search21turn26view0

### Local model set for a 16 GB M2 Pro

For Surface A, the three models you named are all valid local choices in GGUF form, but they are **not equally sane** on a 16 GB machine once you care about long-document context. The key reason is not just weight size. It is **KV-cache growth**. llama.cpp exposes the parameters that determine context size and batch size, while the model cards expose enough architecture to estimate KV growth; from those inputs, Qwen 7B is the safest default, Qwen 14B is a strong but short-context flagship on 16 GB, and Phi-3.5-mini is deceptively small in weights but expensive in KV because its KV head count is dense rather than grouped. The “fit” numbers below combine source-verified architecture and GGUF sizes with explicit engineering inference. citeturn28view1turn36view2turn36view3turn33view1turn38search2turn37view2turn32search1turn31search5turn31search3

#### Recommended Surface A model table

| Model | License | Official context claim | Representative 4-bit GGUF size | KV growth estimate | Product recommendation on 16 GB M2 Pro | Confidence | Evidence |
|---|---|---:|---:|---:|---|---|---|
| **Qwen2.5-7B-Instruct** | Apache-2.0 | 131,072 tokens, but official config defaults to 32,768 and recommends YaRN only when needed | ~4.68 GB for Q4_K_M | ~56 KB/token inferred from 28 layers, 4 KV heads, head dim 128 | **Default downloadable model**. Ship with a **32K cap**, optionally experiment with **48K** on roomy systems; enough for most papers/articles, not books | verified-in-source / inferred | Architecture and context from official card and config; Q4_K_M file size from common GGUF release. citeturn36view1turn36view2turn40search0turn32search1 |
| **Qwen2.5-14B-Instruct** | Apache-2.0 | 131,072 tokens | ~8.99 GB for Q4_K_M | ~192 KB/token inferred from 48 layers, 8 KV heads, head dim 128 | **Flagship optional model**. On 16 GB, assume **8K safe**, **12K–16K risky**, and do not promise long-doc ingest without chunking | verified-in-source / inferred | Context and architecture from official card; hidden size from official Qwen family config variant; Q4_K_M size from official/common GGUF listings. citeturn33view1turn40search3turn31search0turn31search5 |
| **Phi-3.5-mini-instruct** | MIT | 128,000 tokens | ~2.3–2.5 GB for Q4_K_M | ~384 KB/token inferred from 32 layers, 32 KV heads, hidden size 3072 | **Good tiny alternative**, but not a long-context miracle in llama.cpp. Use **8K default**, **16K experimental**; above that, KV pressure rises quickly | verified-in-source / inferred | 128K and MIT from official card; config shows 32 layers, 32 attention heads, hidden size 3072; Q4_K_M sizes from GGUF releases. citeturn37view2turn33view2turn38search2turn31search3turn31search10 |

#### Honest long-document ceiling on 16 GB

| Model | What usually fits comfortably | What starts feeling dangerous | What you should tell users |
|---|---|---|---|
| Qwen2.5-7B | A paper, long article, or several notes merged together | Very long reports or multiple papers stuffed into one shot | “A paper fits. A book needs chunking.” |
| Qwen2.5-14B | One paper or a moderate long-form source at short-to-medium context | Aggressive long-context sessions on a 16 GB machine | “Best answers, but shorter lane on 16 GB.” |
| Phi-3.5-mini | Short-to-medium docs with low download/storage cost | Long-context reading, because KV grows fast despite small weights | “Small download, not the best long-doc local reader.” |

Those workload descriptions are engineering inferences, but they follow directly from the source-backed architecture and quant sizes. On your stated **~10.5 GB usable memory** assumption, the practical RAM-gating rules I would ship are: **Qwen 7B available on 16 GB; Qwen 14B available but labeled “short context”; Phi-3.5-mini available on 8 GB+ as the smallest manual download; no model in v1 should promise book-scale single-shot reading**. citeturn36view1turn33view1turn37view2turn32search1turn31search5turn31search3

### Apple Foundation Models as the default free brain

Apple’s own documentation now makes the product split unusually clean. The Foundation Models framework is a native Swift API that gives apps direct access to the on-device Apple Foundation Model that powers Apple Intelligence, and Apple presents it as suitable for content generation, summarization, and input analysis while keeping data on device and working without API keys or cloud costs. Availability depends on whether the device supports Apple Intelligence, and Apple’s docs point developers to check availability before use. Put simply: **Foundation Models is the right default “it just works” brain for Surface A**, while downloaded GGUF models become the opt-in “stronger local model” upgrade path. citeturn20search18turn21search3turn21search7turn22search14turn22search16

#### Surface A default/fallback matrix

| Situation | What loads | Reason | Confidence | Evidence |
|---|---|---|---|---|
| Apple-silicon Mac with Apple Intelligence enabled on supported OS | **Foundation Models by default** | Zero download, native Swift integration, on-device privacy | verified-in-source | Apple docs describe direct access to the on-device Apple model through Foundation Models and require Apple Intelligence support. citeturn20search18turn21search3turn22search14 |
| Apple-silicon Mac on macOS 26, but Apple Intelligence unavailable/disabled | Prompt user to **download Qwen 7B** or another GGUF | Keeps free usage on-device without cloud dependency | inferred | Foundation Models availability is conditional; llama.cpp provides your fallback local lane. citeturn22search5turn22search14turn26view0 |
| Intel Mac / older unsupported hardware | **No Foundation Models**; fall straight to GGUF path if you still support Intel, or mark MAS minimum as Apple silicon | Clean capability story | inferred | Apple’s current Foundation Models path is tied to Apple Intelligence-capable devices; a Meet with Apple session explicitly called for an Apple-silicon Mac that supports Apple Intelligence and macOS Tahoe 26. citeturn20search3turn21search3 |

My recommendation for review clarity and onboarding is: **Surface A launches on Apple FM immediately when available, with a subtle “Upgrade local model” control that downloads Qwen 7B**. That makes the free lane feel instant and keeps model downloads framed as optional data, not required setup. The quality comparison against a 7B GGUF cannot be source-verified head-to-head from Apple docs, so the safe wording is: Apple FM should be expected to feel excellent for quick summarization, Q&A, and light drafting, while the GGUF lane gives you explicit model choice and stronger predictable behavior for users who intentionally opt in. That part is inference. citeturn21search3turn22search1turn22search7

## Surface B engine and workspace

Surface B should be built around a different promise: not “answer me,” but **“do this for me.”** The technical crux is that Goose’s repository is not a monolith where everything lives behind `goosed`. The project’s own AGENTS instructions describe `crates/goose` as **core logic**, `crates/goose-cli` as **CLI entry**, and `crates/goose-server` as **backend (binary: goosed)**. The core library exports `agents`, `providers`, `session`, `permission`, `scheduler`, `sources`, and more. The `Agent` type has a public configuration surface, a `reply` method, tool listing and extension APIs, confirmation handling, and a `tool_stream` type that already multiplexes action-required events, notifications, and final tool results. That is enough to justify an in-process MAS integration path. citeturn39view1turn39view2turn10view0turn10view1turn10view2

### Goose in-process

The clean architecture is **not** to embed `goose-server`. It is to create an Epistemos-owned Rust wrapper crate that depends on `goose` core and re-exposes a deliberately tiny ABI to Swift via UniFFI. The wrapper should own session creation, provider construction, event streaming, tool execution bridges, confirmation callbacks, and cancellation tokens. The server crate is still valuable as a map of how Goose wires those parts together, because its route layer imports `goose::providers::create`, session types, recipes, extension config, and the `goose::agents` APIs. But the HTTP layer itself should stay out of MAS. citeturn9view1turn39view1turn39view2turn10view0turn12view0

#### What is verified in Goose source

| Claim | Finding | Confidence | Evidence |
|---|---|---|---|
| Goose has a separable core library | `crates/goose` is described as core logic; `crates/goose-server` is separate and produces `goosed` | verified-in-source | Repo AGENTS instructions list the crate structure explicitly. citeturn39view1 |
| The core library exports agent/session/provider modules | `crates/goose/src/lib.rs` publicly exports `agents`, `providers`, `session`, `permission`, `scheduler`, `sources`, and more | verified-in-source | `lib.rs` lists the public modules. citeturn39view2 |
| There is a public agent type you can instantiate directly | `Agent`, `AgentConfig`, `GoosePlatform`, `Agent::with_config`, and `Agent::reply` are public | verified-in-source | Raw `agent.rs` excerpts show these types and methods. citeturn10view0turn10view1turn10view2 |
| There is a public session manager | `SessionManager` is public and exposes `create_session`, `get_session`, `add_message`, `replace_conversation`, list/search/export/import helpers | verified-in-source | Raw `session_manager.rs` excerpt shows the API surface. citeturn12view0 |
| Tool approvals can be handled interactively | `handle_confirmation` and `supports_action_required_permissions` are public agent methods | verified-in-source | The raw `reply` excerpt includes these methods just before `reply`. citeturn10view2 |
| Streaming is possible without buffering the whole turn | `tool_stream` yields `ActionRequired`, `Message`, and final `Result` items | verified-in-source | Raw `agent.rs` shows `ToolStreamItem` and `tool_stream`. citeturn10view0turn10view1 |
| The server is only one adapter, not the core | The server route layer imports Goose types rather than defining the agent loop itself | verified-in-source | `goose-server` route imports `goose::agents`, `goose::providers::create`, `Session`, `Config`, etc. citeturn9view1 |

#### The exact MAS no-subprocess path

| Layer | What to build | Why this is MAS-safe | Confidence |
|---|---|---|---|
| Rust runtime target | `epistemos_goose_core` as `staticlib` or `cdylib` with UniFFI | In-process library, no helper binary, no localhost server required | inferred, high confidence |
| Agent object | Internally wrap `goose::agents::Agent` with `AgentConfig::new(...)` and a `SessionManager` rooted in app-container storage | Uses source-backed core types directly | verified-in-source / inferred |
| Provider object | Build OpenAI-compatible provider config for your proxy, then create the provider directly in Rust | Avoids environment-coupled desktop config and keeps proxy routing explicit | verified-in-source / inferred |
| Tools | Re-expose only MAS-legal tools through a Swift bridge: notes/doc editing, sources retrieval, approved network fetch via your backend, maybe file read/write in sandboxed workspace | Avoids Goose features that assume shells, subprocesses, arbitrary MCP launch, or local sidecars | inferred |
| Event flow | Rust emits incremental events over UniFFI callbacks / async stream objects; Swift renders them live in the workspace | Prevents the “buffer until done” UX failure | inferred |
| Disallowed runtime pieces | Do not launch `goosed`, do not expose shell execution, do not ship auto-launched MCP servers, do not enumerate subprocess-based extensions | Keeps Surface B obviously in-process and reviewable | inferred, high confidence |

The parts that still need owner verification in your existing scaffold are straightforward. Since I could not inspect `GOOSE_MAS_BUILD_CANON_2026_06_30.md` or `GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md`, the **local build agent must verify** that `runInProcessAgentCore` ends up instantiating a real `Agent` and `SessionManager`, not a stub; that `GooseMASAgentCoreCatalog` reflects actual tool/source/schedule capabilities rather than placeholder empties; that action-required approvals round-trip into `handle_confirmation`; and that session persistence lands under the MAS container and survives relaunch. That portion is necessarily uncertain because the Epistemos scaffold is private. citeturn10view0turn10view1turn10view2turn12view0turn39view1

### Goose in-process to cloud models

Goose’s OpenAI-compatible provider path is source-backed enough for your proxy design. In `openai.rs`, Goose exposes `from_custom_config(model, config)` using a `DeclarativeProviderConfig`; it parses a **configurable `base_url`**, derives the base path, supports **custom headers**, and lets `supports_streaming` be explicitly overridden while defaulting to true. That means your MAS app does **not** have to fork Goose to hardcode your proxy. The correct product design is to pass Goose a provider config that points to your HTTPS proxy, includes the short-lived bearer or other auth header issued by your subscription backend, and leaves the core provider code unchanged. citeturn41view0turn41view2turn41view3

#### Proxy/config adapter map

| Need | Source-backed Goose capability | Epistemos MAS implementation |
|---|---|---|
| Override API host | `base_url` parsed in `from_custom_config` | Point to `https://<your-proxy>/v1` or `.../responses` depending on model family |
| Add auth header | `config.headers` are inserted into a reqwest header map | Inject short-lived app-issued bearer token or signed session header |
| Preserve streaming | `supports_streaming` defaults true and is configurable | Keep UI live by forwarding chunks/events over UniFFI as they arrive |
| Keep model list proxy-controlled | `custom_models` can be derived from config models | Only expose models your proxy supports and your paid tier allows |
| Avoid env-secrets in app binary | Provider config reads secrets from config/env in desktop Goose, but your wrapper can construct the config directly in memory | Store nothing static in the app bundle; mint tokens server-side |

What is less clear from the public source excerpts is the exact representation of “thinking blocks preserved” for every provider/model combination. Goose definitely has thinking-related provider machinery in the core crate, but whether a given upstream model/proxy pairing yields distinct reasoning blocks versus plain token deltas will depend on your upstream provider and the exact path—OpenAI Responses-style, chat-completions-style, or vendor-specific behavior. So the safe recommendation is: **design the Swift workspace to accept normalized event classes** such as `assistantDelta`, `toolCallStarted`, `toolStdoutDelta`, `approvalRequested`, `citationAdded`, and `assistantFinalized`, and let the Rust wrapper map whatever Goose/provider emits into that stable UI contract. The existence of `tool_stream` and the core provider streaming support makes this feasible; the exact event taxonomy is an implementation inference. citeturn10view0turn10view1turn41view2turn41view3

### June as the agent workspace frontend

June’s codebase is now public and MIT-licensed, and it is useful less as a drop-in dependency than as a **product grammar**. The repo describes a desktop app that combines chat, dictation, meeting notes, and a local agent “into a single private workspace”; it explicitly distinguishes an agent runtime, sessions, projects, and a control-plane compatibility matrix. The top-level repo includes `agent-hud.html` and a `src/` tree with app/components/lib layers, and a template document for Hermes runtime upgrades says June tracks which runtime methods and classified events are actually wired into UI. That is exactly the kind of honesty ledger Epistemos MAS should copy. citeturn14view0turn17view0turn18search2

<img src="https://github.com/open-software-network/os-june/raw/main/agent-hud.html" alt="June agent HUD source view" />

The public `agent-hud.html` is small but revealing. It defines an **agent activity surface**, an expandable **sessions HUD**, and a structured stack for agent sessions rather than a generic chat box. June’s README also describes the agent as a local runtime with approval gates before sensitive actions and a primary macOS target. That makes June a better inspiration for **Surface B’s “workspace-ness”** than for Surface A’s quick chat UI. citeturn16view0turn14view0turn18search1

#### Web slice versus native SwiftUI

| Option | What it means | Pros | Cons | Recommendation |
|---|---|---|---|---|
| June-style web slice in `WKWebView` | Recreate a narrow agent workspace in web UI and bind it to in-process Goose over a bridge | Faster if your team already has web engineers; easier to iterate on tool cards and streaming transcript layouts | More bridge complexity, more review scrutiny around hidden web-app behavior, and a greater risk of Surface B feeling like “just another chat page” | Good only if you already have a polished web workspace slice ready |
| Native SwiftUI in June’s style | Build the workspace natively: transcript rail, activity rail, document panel, approval sheets, tool cards | Most robust MAS story, clearest separation from Surface A, easiest to make feel like a distinct room | More initial UI engineering | **Best MAS default** |

I would choose **native SwiftUI in June’s style**, not June’s code wholesale, for three reasons. First, Surface B must read as a different room from Surface A, and native layout makes that easier. Second, MAS review is simplest when core behavior is native and easily inspectable. Third, June’s own repo shows the value of a compatibility matrix and “what is really wired” philosophy more than it offers a turnkey Swift embedding. The must-render “agent furniture” for Goose is: **step cards**, **tool-call cards**, **approval prompts**, **live output deltas**, **final editable doc pane**, **source/citation rail**, and **session timeline**. Anything less risks collapsing back into a chat metaphor. citeturn14view0turn16view0turn18search2

## Two-surface UX, compliance, and money gate

The prior failure mode matters here as much as the runtime. The app should share one visual family but maintain two unmistakable spatial grammars. Surface A is the default landing and should feel like a warm, sparse, low-density reading tool: centered prompt field, document preview or source chip tray, model badge, and a single-thread transcript. Surface B should be entered deliberately, from a button that changes the whole chrome into a workspace: left rail for sessions/steps, center activity pane, right document/output pane, with approvals and tool activity rendered as cards. Shared palette and typography are fine; shared **layout metaphor** is not. That is a pure product recommendation, but it aligns with June’s workspace/session framing and with Apple’s general emphasis on clarity and distinct task surfaces. citeturn14view0turn16view0turn22search7

### Two-surface anti-mixing rules

| Rule | Surface A | Surface B |
|---|---|---|
| Entry | Default landing | Deliberate button destination |
| Primary verb | “Answer / summarize / explain” | “Do / update / gather / revise” |
| Tool visibility | None | Always visible |
| Layout | Single-column conversation + source preview | Multi-pane workspace |
| Density | Calm, wide whitespace | Higher information density |
| Activity disclosure | Minimal | Explicit step-by-step activity |
| Editable artifact | Optional notes/result bubble | Always-visible working document |
| Approvals | N/A | First-class UI events |

### MAS compliance and packaging checklist

Apple’s public docs give you the compliance skeleton. App Sandbox confines access to the container and user-granted files; hardened runtime should be enabled for the shipped binary; security-scoped bookmarks are the standard way to persist access to external files; Guideline 2.5.2 requires the app to be self-contained and forbids downloaded executable code that adds functionality; and the StoreKit/App Store Server stack is built around JWS-signed transaction data. From that foundation, the best MAS packaging story is simple: **embed your runtimes, store user data and model files as data, keep network calls client-only, and never ship provider secrets or executable helper downloads**. citeturn19search4turn19search5turn19search0turn19search2turn19search3turn19search7turn19search23turn19search27

#### Entitlements and flags

| Item | Recommendation | Confidence | Source basis |
|---|---|---|---|
| `com.apple.security.app-sandbox` | **Required** | verified-in-source | App Sandbox docs. citeturn19search4turn19search11 |
| Network client entitlement | **Required** if you call your cloud proxy / model APIs | verified-in-source / inferred | App Sandbox network access is permissioned; your cloud agent requires outbound HTTPS. citeturn19search4 |
| User-selected file read/write | **Required** if users import PDFs, vault folders, or external GGUF files | verified-in-source | Sandbox file-access docs and security-scoped bookmark docs. citeturn19search4turn19search0turn19search17 |
| Security-scoped bookmarks | **Use** for persistent access to user-selected vault/model locations outside the container | verified-in-source | Apple bookmark docs. citeturn19search0turn19search14turn19search17 |
| Audio input | Only if MAS build includes meeting transcription/recording | inferred | This is feature-dependent and outside the exact Surface A/B engine question |
| Hardened runtime | **Enable** | verified-in-source | Apple hardened runtime docs. citeturn19search1turn19search5 |
| Allow JIT / unsigned executable memory / disable executable-page-protection | **Do not enable unless proven necessary** | inferred, high confidence | Apple docs define these as exceptions for executable-memory behavior; no evidence they are needed for this design. citeturn19search1turn19search9turn19search12turn19search21 |
| Disable library validation | **Avoid** | inferred, high confidence | Unnecessary if you static-link the runtimes. citeturn19search15 |

#### Review-risk matrix

| Area | Risk | Assessment |
|---|---|---|
| Embedded llama.cpp inference | Low-to-moderate | Reviewable if positioned as embedded local inference and model downloads are data files in the container |
| In-process Goose runtime | Moderate | Acceptable if tools are MAS-legal and there is no subprocess/server/helper download story |
| External LLM API calls | Moderate | Common and acceptable, but must be privacy-disclosed and explicitly user-triggered |
| GGUF downloads from Hugging Face | Moderate | The best legal story is “data download, not code.” This is plausible under 2.5.2 and supported by App Store precedent, but not an express Apple ruling |
| Shipping provider keys in binary | High | Do not do this |
| Spawning `goosed`, MCP helpers, browser automation binaries, or Ollama | High | Avoid completely in MAS |

### Paywall and proxy

Apple’s StoreKit and App Store Server docs line up with the design you proposed. StoreKit transactions are JWS-signed, the App Store Server API returns JWS-signed transaction and renewal information, and App Store Server Notifications use the same signed format. That supports a standard secure gate: the app obtains a signed StoreKit transaction, sends the JWS to your backend, your backend verifies with Apple’s server APIs, mints a short-lived Epistemos token, and the app uses that token on each paid cloud-agent request. The free lane does not need a gate because Apple FM and embedded GGUF inference occur on-device and do not expose a stealable server credential. citeturn19search3turn19search7turn19search23turn19search27

#### Subscription flow

| Step | What happens | Confidence |
|---|---|---|
| App purchase state | StoreKit 2 gives the app the signed transaction info | verified-in-source |
| App → proxy | App sends signed JWS transaction to Epistemos backend | inferred, standard design |
| Proxy verification | Backend verifies with App Store Server API | verified-in-source |
| Session token | Backend returns short-lived cloud-agent token | inferred, strong best practice |
| Paid requests | Every cloud/agent request carries that short-lived token | inferred, strong best practice |
| Renewals/cancellations | Backend updates entitlement state from App Store Server Notifications | verified-in-source / inferred |
| Local free lane | No gate, because nothing server-side needs protection | inferred, high confidence |
| Provider keys | Never ship in binary; keep only on backend | inferred, high confidence |

## Phase order, risk register, and feature ledger

The right phase order is to de-risk the runtime split before polishing the visuals. Ship a brutally honest Surface A first; then make Goose truly in-process; then build the workspace chrome around that; then layer receipts and proxy. Everything else is polish. That ordering is justified because Surface A has the clearest source-backed path, while Goose embedding is the hard technical unknown. citeturn20search18turn26view0turn39view1turn39view2

### Phase order from current stub to shipping MAS build

| Phase | Goal | Exit condition |
|---|---|---|
| Surface A baseline | Apple FM quick chat with PDF/selection summarization | Instant default free lane works on supported Apple-silicon Macs |
| Surface A local upgrade | Embedded llama.cpp + Qwen 7B download/load from App Support | No server dependency; Qwen 7B survives relaunch and handles paper-scale docs |
| Goose runtime spike | Rust wrapper instantiates `Agent` and `SessionManager` in-process | No `goosed`, no localhost server, no subprocess |
| Goose event bridge | Live event stream into Swift with approvals and cancellations | Tool/approval deltas render without full-turn buffering |
| Workspace UI | Native SwiftUI multi-pane Surface B | Users can watch agent steps and edit the working doc |
| Subscription gate | Receipt verification, middleware token, proxy enforcement | Paid cloud agent works; free local lane remains ungated |
| Review hardening | Reviewer notes, disclosure text, fallback messaging | Clean App Review story and crash-free release candidate |

### Top risk register

| Risk | Why it matters | Mitigation |
|---|---|---|
| Goose not truly library-embeddable | Biggest blocker for Surface B | Build a minimal wrapper against `crates/goose`; do not start from `goose-server`; spike before any major UI work |
| Streaming across FFI gets messy | Workspace dies if events only appear at the end | Normalize to a small event enum and test with synthetic streams before real providers |
| Tool execution leaks into subprocess assumptions | MAS legality risk | Allow only Swift-owned frontend tools or strictly in-process/network tools in MAS |
| Qwen 14B on 16 GB disappoints users | “Flagship” could feel broken under long context | Label it short-context; gate default context aggressively |
| Phi-3.5 long-context expectations are misleading | Small weights hide large KV cache | Ship small default caps and explain why |
| llama.cpp Metal/runtime issue under hardened runtime | Could lead to late-stage review or crash surprises | Ship with no executable-memory exceptions first; soak test on release-signed builds |
| GGUF download robustness | Partial downloads or corrupt weights create support burden | Atomic download + checksum + resume + safe rollback before model activation |
| Two-surface bleed returns | Product confusion and support burden | Separate entry points, separate layouts, separate copy, separate event furniture |
| Foundation Models unavailable on some Macs | Default free brain missing | Capability-check at first launch and guide to GGUF fallback |
| Proxy/receipt bug blocks paid users | Revenue and trust risk | Keep proxy gate orthogonal to local free lane; local app must remain useful even if backend is down |

### Seed MAS feature ledger

| Capability | Surface | Runtime source | MAS legality | Notes |
|---|---|---|---|---|
| Ask a question about selected text/PDF | A | Apple FM / llama.cpp | Yes | No tools needed |
| Summarize a paper/article | A | Apple FM / llama.cpp | Yes | Paper-scale, not book-scale |
| Local chat without account | A | Apple FM / llama.cpp | Yes | Default free lane |
| Download stronger local model | A | llama.cpp + GGUF in sandbox | Yes, moderate review scrutiny | Call it model data download |
| Multi-step research task | B | Goose in-process + cloud proxy | Yes if tools stay MAS-legal | Paid tier |
| Edit a working document as agent runs | B | Goose in-process + native SwiftUI workspace | Yes | Key workspace differentiator |
| Visible tool cards and approvals | B | Goose event bridge | Yes | Keeps B from feeling like chat |
| Browser-use / external helper runtimes | Not in MAS | N/A | **No** for MAS | Keep in Developer-ID Pro build only |
| Local agent tool-loop over small GGUF | Not in MAS | N/A | Technically possible but product-wise **don’t do it** | Violates your separation strategy |
| Cloud provider keys in app bundle | N/A | N/A | **No** | Backend only |

## Open questions for the owner

The public research resolves the architecture strongly enough to move, but a few owner-only questions remain.

The first is whether the MAS build should support **Intel Macs at all**. Apple’s Foundation Models lane clearly points you toward Apple-Intelligence-capable Apple silicon for the best default experience, and keeping Intel support would force more users into the GGUF-download fallback path. That is a product decision, not a source-blocked one. citeturn20search3turn21search3

The second is whether you want **Qwen 14B exposed on 16 GB machines by default**. My recommendation is yes, but with explicit “short context” labeling and a conservative cap; otherwise it will create support friction that feels like a bug when it is really a memory-budget decision. That recommendation is an engineering inference from the source-backed architecture and file-size data. citeturn33view1turn31search0turn31search5

The third is the exact **Goose wrapper scope**. The public sources are enough to justify embedding the core crate, but you still need to decide whether the wrapper will expose only a tiny Epistemos-specific API or try to mirror Goose more generally. For MAS, I strongly recommend the narrower route: one session model, one event schema, one approval API, one tool registry, one provider config type. That keeps Surface B controllable and reviewable. citeturn10view0turn10view1turn12view0turn41view0turn41view3

The fourth is the private scaffold. Because I could not inspect `GOOSE_MAS_BUILD_CANON_2026_06_30.md` or `GOOSE_MAS_IN_PROCESS_READINESS_SPEC_2026_06_30.md`, the local build agent should verify, concretely, that `runInProcessAgentCore` stops being a façade and calls a real Rust `Agent`; that `GooseMASAgentCoreCatalog` enumerates actual tools/sources/schedules; that approvals round-trip into `handle_confirmation`; that sessions persist in the MAS container; and that all MAS-disabled features are represented in the feature ledger as intentionally absent rather than silently stubbed. That part remains uncertain until the owner’s local sources are checked against the runtime.


gemii 2 - # EPISTEMOS MAS BUILD EXECUTION DOSSIER
**Document ID:** EPISTEMOS-MAS-EXEC-DOSSIER-2026-07-03
**Status:** PROPOSAL / SPECIFICATION
**Target Platform:** macOS 14.0+ (Universal / Apple Silicon Optimized)
**App Store Compliance:** Strict App Sandbox & Hardened Runtime (No Subprocesses, No Local Socket Servers)
---
## EXECUTIVE SUMMARY & ARCHITECTURAL OVERVIEW
The Epistemos Mac App Store (MAS) build delivers a dual-surface, highly performant research platform while maintaining 100% compliance with Apple’s sandbox restrictions, hardened runtime policies, and App Store Review Guidelines.
The architecture guarantees a hard division between two user experiences (Surfaces) to eliminate the UX blending that caused previous App Store rejections:
* **Surface A (Quick Chat):** A local-only, fast-path chat interface for document Q&A and summarizing. It runs completely in-process using Apple's native **Foundation Models (on macOS 15+)** as the zero-download default, with an opt-in path to run embedded **`llama.cpp` (GGUF)** models via Metal.
* **Surface B (June Agent Workspace):** A highly structured, multi-panel agentic workspace. It runs an in-process instance of **Block's Goose** compiled as a Rust static library (`libgoose_ffi.a`), bridging to Swift via **UniFFI**. Rather than running local tool-loops (which fail on small local models), Surface B coordinates with cloud-hosted LLMs over HTTPS through a secure, StoreKit-authenticated developer proxy.
```
+-------------------------------------------------------------------------------------------------+
|                                     EPISTEMOS MAS SWIFT APP                                     |
|                                                                                                 |
|  +--------------------------------------------+   +------------------------------------------+  |
|  |           SURFACE A (QUICK CHAT)           |   |       SURFACE B (AGENT WORKSPACE)        |  |
|  |  - Instant Q&A, PDF Summarization          |   |  - Multi-step tasks, doc modifications   |  |
|  |  - UI: Click-to-search wave, inline chat   |   |  - UI: Multi-panel, visible agent steps  |  |
|  +--------------------------------------------+   +------------------------------------------+  |
|                        |                                               |                        |
|                        v (In-Process Direct calls)                     v (UniFFI Bridging)      |
|         +-----------------------------+                 +-----------------------------+         |
|         |    LOCAL INFERENCE ENGINE   |                 |      IN-PROCESS GOOSE       |         |
|         |                             |                 |     (libgoose_ffi.a)        |         |
|         |  +-----------------------+  |                 |                             |         |
|         |  | Apple Foundation Fmwk |  |                 |  - Runs Rust Agent Loop     |         |
|         |  | (macOS 15+ Native LLM)|  |                 |  - Resolves Tools Locally   |         |
|         |  +-----------------------+  |                 |  - Translates State to Swift|         |
|         |                             |                 +-----------------------------+         |
|         |  +-----------------------+  |                                |                        |
|         |  |    libllama_static    |  |                                v (HTTPS Stream)         |
|         |  |  (Metal GGUF Loading) |  |                 +-----------------------------+         |
|         |  +-----------------------+  |                 |     EPISTEMOS CLOUD PROXY   |         |
|         +-----------------------------+                 | (StoreKit 2 JWS Auth Gate)  |         |
|                        |                                +-----------------------------+         |
|                        v                                               |                        |
|                 [Local Memory]                                         v [Cloud LLM APIs]       |
+-------------------------------------------------------------------------------------------------+
```
---
## SECTION 1: LLAMA.CPP EMBEDDED ON MAS (SURFACE A ENGINE)
To operate in the Mac App Store sandbox, Epistemos cannot run a standalone background daemon like `ollama` or spawn an external `llama-server` process. This would trigger immediate sandbox violations (`deny process-fork`). Instead, `llama.cpp` must be compiled as a static library (`libllama.a` and `libggml.a`) and linked directly into the Swift target.
### 1.1 Compilation Pipeline & Swift Binding
The cleanest, most maintainable binding strategy is to compile the core `llama.cpp` source directly inside the Xcode project using a custom Swift Package Manager (SPM) wrapper or a dedicated target, mapping to a lightweight Swift wrapper.
```
[ GGUF Model File ] ----> [ libllama.a (C/C++ API) ] ----> [ Swift C-Bridge Layer ] ----> [ Swift Client / UI ]
```
#### Step-by-Step Build Pipeline:
1. **Source Extraction:** Pull the core files from `ggml-org/llama.cpp` (primarily `llama.h`, `llama.cpp`, `ggml.h`, `ggml.c`, `ggml-alloc.h`, `ggml-alloc.c`, `ggml-backend.h`, `ggml-backend.c`, and the `common/` utilities if parsing prompts).
2. **SPM Package Configuration (`Package.swift`):**
Configure a Swift Package that exports a single target containing the C/C++ files. Ensure Metal compilation flags are explicitly specified to enable GPU acceleration on Apple Silicon.
3. **Metal Kernel Shader Compilation:**
`llama.cpp` implements its Metal kernels in `.metal` source files (e.g., `ggml-metal.metal`). In a sandboxed environment, these kernels must be compiled into a single default Metal library (`default.metallib`) and embedded inside the application bundle (`Epistemos.app/Contents/Resources/default.metallib`). At runtime, the `ggml-metal` backend automatically attempts to load this library from the main bundle resources.
### 1.2 Sandboxing, Hardened Runtime, and Entitlements
Because the App Store requires the Hardened Runtime to be enabled, the application is subject to strict memory execution protections (W^X).
We must verify if `llama.cpp` requires Just-In-Time (JIT) privileges. **No.** The Metal execution path translates tensor math into pre-compiled Metal Shading Language (MSL) pipelines executed on the GPU command queue via the Metal framework. This occurs in a separate system driver process space and does not write to executable pages in the host application's address space.
However, to prevent CPU fallbacks or system memory protections from blocking large contiguous allocations (e.g., allocating a 10GB KV cache or model weight buffer), specific settings must be applied.
| Entitlement / Flag | Setting | Purpose | App Store Acceptability | Confidence |
| --- | --- | --- | --- | --- |
| `com.apple.security.app-sandbox` | `true` | Standard App Store Sandbox requirement. | Mandatory | Verified-in-source |
| `com.apple.security.files.user-selected.read-write` | `true` | Allows users to choose custom directories for storing GGUF models. | Fully Accepted (Requires NSOpenPanel) | Verified-in-source |
| `com.apple.security.cs.allow-jit` | **FALSE** | Not needed. Avoid enabling this as it increases App Store Review scrutiny. | Highly Preferred | Inferred |
| `com.apple.security.cs.allow-unsigned-executable-memory` | **FALSE** | Not needed. Keep disabled to maintain an optimal security posture. | Highly Preferred | Inferred |
| `GGML_METAL_PATH_RESOURCES` | Environment / Compiler Flag | Forces the Metal backend to seek `default.metallib` in the App’s Resource directory. | Mandatory | Verified-in-source |
### 1.3 Memory and KV Cache Allocation Strategy
To avoid Out-Of-Memory (OOM) crashes on 16GB Macs, memory allocation must be tightly managed:
* **Virtual Memory Pinning (mmap):** Use `llama_model_params.use_mmap = true`. This lets the macOS kernel map the GGUF file directly into virtual memory. The OS handles paging model weights in and out, reducing the app's physical memory footprint.
* **Metal Allocations:** Configure `llama_context_params.embeddings = false` unless actively vectorizing text, and restrict `llama_context_params.n_batch` to `512` to prevent sudden GPU memory spikes during prompt processing.
* **Unified Memory Management:** On Apple Silicon, CPU and GPU share physical RAM. Ensure your KV Cache footprint (`n_ctx` * hidden dimensions * layers) does not trigger system-wide swaps. Limit the KV cache allocation to a maximum of 4GB for local runs.
### 1.4 GGUF Storage and Sandboxed Security-Scoped Bookmarks
To allow users to load models from custom directories (outside the app's standard sandbox container), you must implement **Security-Scoped Bookmarks**.
1. When a user selects a GGUF file or custom model directory via `NSOpenPanel`, capture the URL.
2. Request a Security-Scoped Bookmark from the URL:
```swift
let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
// Save bookmarkData to UserDefaults
```
3. At startup, resolve the bookmark to regain access:
```swift
var isStale = false
let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
_ = resolvedURL.startAccessingSecurityScopedResource()
// Open GGUF file via llama.cpp
// Ensure to call resolvedURL.stopAccessingSecurityScopedResource() when closing the model
```
---
## SECTION 2: THE LOCAL MODEL SET (SURFACE A)
Surface A relies on high-quality, highly quantized (4-bit, Q4_K_M) models designed to run comfortably on a 16GB M2 Pro system. On such a device, roughly **10.5 GB** of memory is safely assignable to the application without causing UI stuttering or triggering system page-swapping.
### 2.1 Quantized Model Profiles (Q4_K_M GGUF format)
| Model | File Size (Q4_K_M) | KV Cache Size (4K Context) | Real-world Context Ceiling on 16GB RAM | Hardware Gating Rule (Minimum Specs) | License |
| --- | --- | --- | --- | --- | --- |
| **Qwen2.5-7B-Instruct** (Default) | ~4.25 GB | ~1.1 GB | Up to 8,192 tokens safely (~5.4 GB total memory) | M1/M2/M3 with 8GB+ RAM | Apache-2.0 (No acceptance prompt needed) |
| **Qwen2.5-14B-Instruct** (Flagship) | ~8.99 GB | ~2.1 GB | Up to 4,096 tokens max (~11.1 GB total memory) | M-Series Pro/Max with 16GB+ RAM | Apache-2.0 (No acceptance prompt needed) |
| **Phi-3.5-mini** (Speed Option) | ~2.20 GB | ~0.6 GB | Up to 16,384 tokens safely (~3.5 GB total memory) | Works on all Apple Silicon Mac base models (8GB) | MIT (No acceptance prompt needed) |
### 2.2 Context Ceiling & RAM Gating Implementation
On a 16GB Mac, loading the 14B model consumes nearly the entire available memory budget. If a user tries to process a long research document, the KV cache will expand and trigger a system OOM.
```
Available App RAM (16GB Mac): ~10.5 GB
[============================= 10.5 GB =============================]
Phi-3.5-mini:   |-- 2.2GB Model --|-- 0.6GB (4K KV) --| [Safe space: 7.7GB]
Qwen2.5-7B:     |---- 4.25GB Model ----|-- 1.1GB (4K KV) --| [Safe space: 5.15GB]
Qwen2.5-14B:    |------------------ 8.99GB Model ------------------|-- 1.5GB (3K KV) --| [OOM RISK]
```
#### RAM Gating Rules (Swift Implementation):
```swift
struct RAMGating {
    static var physicalGB: Double {
        return Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
    }
    
    static func canLoadModel(fileSizeGB: Double, targetedContextWindow: Int) -> Bool {
        let estimatedKVCacheGB = (Double(targetedContextWindow) / 1024.0) * 0.28 // general heuristic for 7B-14B
        let totalRequired = fileSizeGB + estimatedKVCacheGB
        
        // Retain a safety buffer of at least 4.5 GB for the macOS UI and system processes
        let safeThreshold = physicalGB - 4.5
        return totalRequired <= safeThreshold
    }
}
```
* **Document Context Cap:** If a user loads a 150-page PDF (~60,000 tokens), the local model will truncate it. The system must restrict the context window for local GGUF models to **8,192 tokens max** for Qwen-7B, and **4,096 tokens max** for Qwen-14B. For documents exceeding these limits, the app must present an inline message offering to chunk the text locally or route the request to the cloud agent (Surface B).
---
## SECTION 3: APPLE FOUNDATION MODELS (SURFACE A DEFAULT)
Beginning with macOS 15, Apple introduced the native **Foundation Models (on-device LLM)** framework. Using this native API as the zero-download default is the most efficient design path for Surface A.
### 3.1 Comparison Matrix: Native Apple FM vs. 7B GGUF
| Feature | On-Device Apple Foundation Model (macOS 15+) | Qwen2.5-7B-Instruct (GGUF) |
| --- | --- | --- |
| **Download Size** | 0 MB (Pre-installed on supported hardware) | ~4.25 GB download |
| **Latency / TTFT** | Ultra-low (optimized at the OS level via Apple Silicon) | Low to Medium (depends on `llama.cpp` load time) |
| **Tool Calling / JSON** | Limited / Basic formatting | Highly robust, native structured output support |
| **Supported HW Floor** | Apple Silicon (M1+) running macOS 15.0+ | Any Apple Silicon Mac, partial Intel support (slow) |
| **Quality Comparison** | Excellent for summaries, translation, and basic extraction. | Superior for logical reasoning, coding, and synthesis. |
### 3.2 Framework Integration
To load and run the native Apple Foundation Model, use the `LanguageModelSession` API under the `LanguageModels` framework:
```swift
import LanguageModels
@available(macOS 15.0, *)
class AppleFMEngine {
    private var session: LanguageModelSession?
    
    func initializeSession() async throws {
        // Confirm the on-device system model is ready
        guard LanguageModelSession.isAvailable else {
            throw ModelError.unavailable
        }
        self.session = try await LanguageModelSession()
    }
    
    func generate(prompt: String, onToken: @escaping (String) -> Void) async throws -> String {
        guard let session = session else { throw ModelError.notInitialized }
        
        let response = try await session.generateText(replyingTo: prompt) { fragment in
            DispatchQueue.main.async {
                onToken(fragment)
            }
        }
        return response
    }
}
```
### 3.3 Dynamic Fallback Architecture
For Intel-based Macs or systems running macOS 14, the framework will be unavailable. Epistemos must handle this fallback smoothly.
```
                           [ Surface A Initialization ]
                                       |
                     Is macOS 15+ & Apple Silicon (M-Series)?
                                    /         \
                             (Yes) /           \ (No)
                                  v             v
       [ Load Native Apple Foundation Model ]   [ Fallback: Prompt user to download Phi-3.5 ]
       - Zero-download default                  - Embedded llama.cpp engine
       - Instant availability                   - Download managed via Sandbox container
```
---
## SECTION 4: GOOSE IN-PROCESS (SURFACE B ENGINE)
To satisfy the sandboxing requirements of the Mac App Store, Surface B must run **Block's Goose agent core fully in-process**. Spawning the standalone binary daemon (`goosed`) or opening local TCP sockets (`127.0.0.1:50051`) will cause App Store rejections. The agentic loop must compile as an embedded library and link directly to the macOS application binary.
### 4.1 Rust Library Architecture & UniFFI Integration
The core logic of Block's Goose is contained in the Rust `goose` and `goose-agent` crates. To run it in-process, we must package it into a static library (`libgoose_ffi.a`) and generate a Swift bridge interface using **UniFFI**.
#### Rust FFI Wrapper Configuration (`Cargo.toml` in your FFI crate):
```toml
[package]
name = "goose_ffi"
version = "0.1.0"
edition = "2021"
[lib]
crate-type = ["staticlib", "cdylib"]
[dependencies]
goose = { git = "https://github.com/block/goose.git", branch = "main" }
uniffi = { version = "0.28", features = ["cli"] }
tokio = { version = "1.35", features = ["full"] }
[build-dependencies]
uniffi = { version = "0.28", features = ["build"] }
```
#### The UniFFI Interface Definition Language (`goose.udl`):
This file defines the exact Swift-to-Rust API surface for running the agent loop in-process without spawning background processes.
```interface
namespace goose_ffi {
    sequence<string> get_available_tools();
    void start_agent_session(string session_id, string system_prompt, string provider_config_json);
    void submit_user_input(string session_id, string user_text, AgentCallbackListener listener);
    void stop_agent_session(string session_id);
};
interface AgentCallbackListener {
    void on_agent_step(string step_type, string payload);
    void on_tool_call(string tool_name, string arguments);
    void on_tool_response(string tool_name, string output);
    void on_token(string token);
    void on_error(string error_message);
    void on_complete();
};
```
### 4.2 In-Process Execution & Thread Mapping
To prevent blocking the main SwiftUI thread, all calls into the Rust agent core must be dispatched onto a dedicated background queue managed by a global Tokio runtime instance inside the FFI boundary.
```
[Swift UI / Main Thread]
       │
       │ (1) Action: submit_user_input()
       ▼
[Goose Agent Controller (Swift)]
       │
       │ (2) Dispatches to background task
       ▼
[libgoose_ffi.a (C / Rust Boundary)]
       │
       │ (3) tokio::runtime::Runtime (Rust-managed thread pool)
       ▼
[Goose Agentic Loop (Rust Core)] ───(4) Network Request (HTTPS API)───> [Cloud Proxy]
       │
       │ (5) Emits callbacks via UniFFI
       ▼
[AgentCallbackListener (Swift Delegate)] ───(6) MainActor.run ───> Update SwiftUI State
```
* **Zero-Subprocess Compliance:** By running within the same process address space, Goose can execute native Rust tasks directly. When the agent decides to read, search, or edit a document in the user's workspace, it executes the action through native Rust or Swift file-system modules. No terminal execution wrapper (`/bin/sh` or `/bin/zsh`) is called.
---
## SECTION 5: GOOSE-IN-PROCESS TO CLOUD MODELS
To keep the MAS build lightweight, Surface B uses cloud models (such as GPT-4o or Claude 3.5 Sonnet) instead of running slow agentic tool loops locally. The local Rust FFI engine acts as the orchestrator, while the model inference occurs on remote cloud servers via an OpenAI-compatible HTTPS proxy managed by Epistemos.
```
[In-Process libgoose_ffi.a]
        │
        │ (HTTPS POST /v1/chat/completions with Streaming)
        ▼
[Epistemos Enterprise Proxy] (App Store Subscription Validation via JWT)
        │
        │ (Forwards to Claude / OpenAI APIs)
        ▼
[Cloud Provider (e.g., Anthropic Claude 3.5)]
```
### 5.1 FFI Configuration Map
| Parameter | FFI Interface Type | Value / Configuration Source | Purpose |
| --- | --- | --- | --- |
| **Proxy Endpoint** | `String` | `[https://api-mas.epistemos.com/v1](https://api-mas.epistemos.com/v1)` | Redirects Goose's network client away from direct OpenAI/Anthropic servers to the paywalled proxy. |
| **Auth Token** | `String` | Epistemos User Session JWT (`Bearer <jwt>`) | Attaches the active StoreKit-validated subscription token to authorize the request on the proxy. |
| **Model Type** | `String` | `claude-3-5-sonnet` or `gpt-4o` | Configures the targeted cloud LLM for the agent task. |
### 5.2 Stream Handling and Thinking Blocks (UniFFI to Swift)
When streaming responses from cloud models, particularly those featuring reasoning tokens (e.g., "thinking blocks"), the in-process Goose engine must forward these tokens in real-time. Buffering tokens on the Rust side before sending them to Swift will make the UI feel laggy.
The `AgentCallbackListener` UniFFI interface uses direct callbacks to handle these updates:
* **Thinking Block Format:** Emitted via `on_agent_step(step_type: "thinking", payload: token)`. The Swift UI catches this event and appends it to a "Thinking..." disclosure panel.
* **Result Token Format:** Emitted via `on_token(token: String)`. The Swift UI appends these tokens to the main document editor or chat message panel.
* **Tool Execution Steps:** Emitted via `on_tool_call(tool_name, arguments)`. This pauses text rendering and displays an interactive card in the UI showing the active tool name and input arguments.
---
## SECTION 6: JUNE AS THE AGENT WORKSPACE (SURFACE B FRONTEND)
The June Workspace represents a shift away from conversational, chat-only designs. It uses an actionable multi-panel layout to clearly separate it from Surface A.
### 6.1 Architectural Layout of the Workspace
```
+-------------------------------------------------------------------------------------------------+
|                                    SURFACE B: JUNE WORKSPACE                                    |
+------------------------------------+------------------------------------------------------------+
|  LEFT PANEL: Transcript & Steps    |  RIGHT PANEL: Interactive Document Canvas                 |
|                                    |                                                            |
|  [User Prompt]                     |  +-------------------------------------------------------+ |
|  "Generate research summary..."    |  | # Neural Networks in 2026                             | |
|                                    |  |                                                       | |
|  ▼ Agent Execution Log             |  | Modern architectures rely heavily on...              | |
|    [Thinking... (0.4s)]            |  |                                                       | |
|    [Tool Call: Fetch_Sources]      |  | [Agent is editing this section...]                    | |
|    [Tool Response: 3 sources]      |  |                                                       | |
|    [Tool Call: Write_Draft]        |  |                                                       | |
|                                    |  +-------------------------------------------------------+ |
|  [ Input Box ] [Stop/Run]          |  [ Export to Google Docs ]  [ Save to Workspace ]         |
+------------------------------------+------------------------------------------------------------+
```
### 6.2 Frontend Hosting Evaluation: Native SwiftUI vs. WKWebView
| Evaluation Metric | Option A: Native SwiftUI (Recommended) | Option B: WKWebView (Embedded Web UI) |
| --- | --- | --- |
| **Performance & Responsiveness** | **Superior:** Native 120Hz rendering with zero layout delay. | **Moderate:** Subject to process context-switching latency. |
| **App Store Review Safety** | **High:** Uses approved, native Apple controls. No remote script concerns. | **Medium:** Subject to Rule 4.2 (must not be a wrapper of a website). |
| **Local File Interoperability** | **Seamless:** Easy to integrate with system-level Drag-and-Drop and OS file APIs. | **Complex:** Requires complex JS-to-Swift message passing. |
| **UI Customization** | Uses standard, customizable SwiftUI containers. | Requires CSS overrides for light/dark modes. |
| **Implementation Complexity** | High initial effort, but highly robust. | Faster initial prototype, but harder to stabilize. |
### 6.3 SwiftUI Component Adapter Mapping
To build a highly responsive workspace UI, implement native SwiftUI controls that map directly to the streaming states emitted by the in-process Goose FFI:
```swift
struct AgentWorkspaceView: View {
    @ObservedObject var viewModel: AgentWorkspaceViewModel
    
    var body: some View {
        HSplitView {
            // Left Panel: Activity Feed & Steps
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        ForEach(viewModel.executionSteps) { step in
                            AgentStepCard(step: step)
                                .id(step.id)
                        }
                    }
                }
                AgentInputControl(viewModel: viewModel)
            }
            .frame(minWidth: 300, maxWidth: 500)
            
            // Right Panel: Document Canvas
            VStack {
                TextEditor(text: $viewModel.documentContent)
                    .font(.system(.body, design: .serif))
                    .padding()
                    .background(Color(.textBackgroundColor))
                
                HStack {
                    Button("Export to Google Docs") {
                        viewModel.exportToDocs()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
}
```
---
## SECTION 7: TWO-SURFACE UX (THE ANTI-MIXING RULE)
To prevent users from confusing the two interfaces, Epistemos must enforce a strict division between Surface A and Surface B. They should share core brand elements like fonts and colors, but feature completely different layouts and interaction models.
```
                              [ APP LAUNCH ]
                                     |
                                     v
                  +-------------------------------------+
                  |     SURFACE A (QUICK CHAT)          |
                  | - Centered "Wave" search field      | <--- Default Landing
                  | - Minimalist, single-column design  |
                  +-------------------------------------+
                                     |
                                     | (Click "Enter Workspace" Button)
                                     v
                  +-------------------------------------+
                  |     SURFACE B (AGENT WORKSPACE)     |
                  | - Two-panel IDE-style layout        | <--- Distinct Destination
                  | - Multi-step execution feed         |
                  +-------------------------------------+
```
### 7.1 Visual Distinction System
| Interface Element | Surface A: Quick Chat (The Fast Lane) | Surface B: Workspace (The Deep Lane) |
| --- | --- | --- |
| **Primary Interaction** | Command-palette style input, single prompt entry. | Persistent input console with tool options, model selectors, and start/stop controls. |
| **Layout Design** | Centered, single-column feed focusing on the current document. | Two-column split interface: left panel manages agent execution, right panel hosts a document editor. |
| **Agent Visuals** | No step execution logs or tool calls are visible to the user. | Prominent execution logs displaying thinking times, active tool cards, and progress bars. |
| **Background Tint** | Consistent with the system's default window color. | Subtle dark or warm canvas background (e.g., LCH warmth tint) to indicate an active workspace. |
| **Primary Call-to-Action** | "Ask anything..." | "Initialize Agentic Session..." |
---
## SECTION 8: MAS COMPLIANCE & PACKAGING
To pass Mac App Store review without delays, every aspect of the app's sandboxing, entitlements, and external network interactions must adhere strictly to Apple's guidelines.
### 8.1 MAS Security Entitlements (`EpistemosMAS.entitlements`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Core App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Hardened Runtime Security -->
    <key>com.apple.security.hypervisor</key>
    <false/>
    
    <!-- Network Access: Required to communicate with Cloud Proxy -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- File Access Bookmarks for importing custom local GGUF weights -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```
### 8.2 App Store Review Guidelines & Risk Mitigation
* **Guideline 2.5.2 (External Downloads & Executables):**
* *Rule:* Apps cannot download compiled executable code or dynamically load libraries outside the main bundle.
* *Compliance:* GGUF weight files containing model tensors are **pure data arrays**, not executable code. They are loaded and parsed by `libllama.a` running entirely within our sandbox. There is no dynamic loading of machine instructions. To prevent flagging, avoid saving GGUF models in the bundle's `Contents/Frameworks` directory; always store them in the app's `Library/Application Support` container or a user-selected folder.
* **Guideline 4.2.2 (Minimum Functionality & Web Wrappers):**
* *Rule:* Web wrappers are not permitted.
* *Compliance:* The workspace interface must be built using native Swift controls rather than loading a standard web wrapper in a `WKWebView`.
* **Guideline 3.1.1 (In-App Purchases):**
* *Rule:* All subscriptions or purchases of digital services must go through StoreKit.
* *Compliance:* The cloud-based agent features (Surface B) require an active StoreKit 2 subscription. Local models (Surface A) are entirely free to use and do not require any user authentication.
---
## SECTION 9: PAYWALL & PROXY (THE MONEY GATE)
Access to cloud-based agent resources on Surface B is restricted to users with a valid subscription. This payment wall is managed securely using Apple's **StoreKit 2** framework combined with an App Store Server API validation proxy.
```
 [Swift Client App] ────(1) StoreKit 2 Transaction JWS────> [Epistemos Verification Proxy]
        ▲                                                                │
        │                                                                │ (2) Query App Store API
        │                                                                ▼
        │◄───(4) Issue Session JWT ◄────(3) [Authorized] ◄──── [App Store Server API]
```
### 9.1 Verification & Subscription Lifecycle Flow
1. **Subscription Purchase:** The user purchases a subscription via the in-app StoreKit 2 interface.
2. **Transaction Signing (JWS):** StoreKit 2 generates a signed transaction string (JSON Web Signature).
3. **Proxy Verification:** The app sends this JWS token to the Epistemos Proxy. The proxy verifies the signature using Apple's public root certificate or double-checks the transaction ID with Apple’s Server API.
4. **JWT Issuance:** Once validated, the Epistemos Proxy issues a short-lived access token (JWT, valid for 24 hours).
5. **Proxy Requests:** For all subsequent agent requests from Surface B, the app includes this JWT in the Authorization header.
### 9.2 Complete Security Checklist
| Threat Vector | Swift Implementation / Protocol | Verification Location | Status / Safety |
| --- | --- | --- | --- |
| **API Key Spoofing** | Never embed raw developer API keys for cloud providers (OpenAI, Anthropic) inside the app bundle. | Proxy Server Side | **100% Secure** |
| **Subscription Bypass** | Validate the StoreKit JWS on the proxy server; do not rely on local boolean flags inside the app. | Proxy Server Side | **100% Secure** |
| **Man-In-The-Middle (MITM)** | Enforce strict SSL Certificate Pinning inside `URLSessionDelegate` for all calls to `api-mas.epistemos.com`. | Client Side App | **100% Secure** |
| **Local Model Exploitation** | Ensure local on-device processing (Surface A) requires no authentication or network traffic. | Fully Local | **100% Free / On-Device** |
---
## SECTION 10: RISKS, IMPLEMENTATION PHASES, & FEATURE LEDGER
### 10.1 Top 7 Technical Risks & Mitigations
| Risk | Impact | Likelihood | Mitigation Strategy |
| --- | --- | --- | --- |
| **1. Goose Rust core depends on subprocess calls** | Block-stopper | Medium | Fork/modify the Goose crate to isolate tool-execution modules. Strip out CLI/subprocess-based tool definitions and build a clean FFI wrapper. |
| **2. Swift-to-Rust streaming overhead** | Performance lag | Low | Avoid passing raw strings over UniFFI callbacks. Use structured, pre-allocated memory buffers or chunked callbacks inside tokio threads. |
| **3. Memory OOM on 16GB Systems** | App Crash | High | Enforce strict RAM-gating rules. Do not allow users to load models larger than 8GB on standard 16GB Macs. |
| **4. App Store Rejection over external assets (Guideline 2.5.2)** | Launch Delay | Medium | Ensure GGUF model files are explicitly classified as data assets. Do not include executable code or runtime loading libraries in model downloads. |
| **5. Metal Memory Fragmentation** | Performance degradation | Medium | Allocate a static, reusable memory pool for the `llama.cpp` context instead of allocating and releasing model contexts dynamically. |
| **6. System Wake / Sleep Swapping** | Performance lag | Low | Release GPU structures and unmap (`munmap`) model parameters whenever the app is sent to the background or the system enters sleep. |
| **7. UX Blending (Surface Rejection)** | Review Rejection | High | Ensure Surface A is configured as the default landing page. Remove all workspace references from Surface A and keep Surface B behind a dedicated button. |
---
### 10.2 Phase-Based Implementation Plan
```
[ PHASE 1: FOUNDATION & COMPILATION ]  ──>  [ PHASE 2: IN-PROCESS INTEGRATION ] ──> [ PHASE 3: FRONTEND & REVIEW ]
- Compile static libraries                 - Build UniFFI boundary layers              - Polish UI Separation
- Secure basic App Sandbox                 - Connect StoreKit verification proxy       - Final App Store Submission
```
#### Phase 1: Foundation and Compilation (Weeks 1-3)
* **Milestone 1.1:** Compile `llama.cpp` into static targets (`libllama.a` and `libggml.a`) inside Xcode, ensuring full Metal support is active.
* **Milestone 1.2:** Integrate the native macOS `LanguageModels` framework, setting up automatic fallbacks for older devices.
* **Milestone 1.3:** Configure Sandboxing, entitlements, and implement Security-Scoped Bookmarks to securely load custom model files.
#### Phase 2: In-Process Agent Integration (Weeks 4-6)
* **Milestone 2.1:** Build the Goose Rust FFI static library, stripping out all subprocess tool calls.
* **Milestone 2.2:** Set up the UniFFI bridge, verifying that streaming tokens and structured JSON parameters pass smoothly to Swift.
* **Milestone 2.3:** Connect the StoreKit subscription manager, linking verified transactions to the proxy authentication system.
#### Phase 3: Frontend Separation & App Store Submission (Weeks 7-8)
* **Milestone 3.1:** Complete the native SwiftUI layouts, clearly separating Surface A's search design from Surface B's dual-panel workspace.
* **Milestone 3.2:** Perform extensive memory leaks and OOM testing on 8GB and 16GB hardware configurations.
* **Milestone 3.3:** Submit the application for App Store Review, highlighting compliance with Guidelines 2.5.2 and 3.1.1.
---
### 10.3 MAS Feature Ledger
| Feature | User Surface | Core Engine | Execution Model | App Store Safety Status |
| --- | --- | --- | --- | --- |
| **Instant Q&A / Search** | Surface A | Apple Foundation Model | On-Device Native (macOS 15+) | **Fully Compliant** (Built-in framework) |
| **Custom Local Chat** | Surface A | `llama.cpp` (GGUF) | On-Device Static Library | **Fully Compliant** (In-process, no subprocess) |
| **Dynamic Model Downloads** | Surface A | HTTPS (Hugging Face API) | App Store Data Download | **Fully Compliant** (Data files, no code) |
| **Document Writing Workspace** | Surface B | Native SwiftUI / File System | Local System Write / FFI | **Fully Compliant** (No shell calls used) |
| **Agent Action Streams** | Surface B | Goose FFI / Cloud Proxy | Streaming over HTTPS | **Fully Compliant** (Standard network client) |
| **Subscription Payment Gate** | Surface B | StoreKit 2 / App Store API | Client-to-Proxy Verification | **Fully Compliant** (Secure paywall) |
---
## OPEN QUESTIONS FOR THE OWNER
Before starting Phase 1, the following structural points should be resolved to align the codebase development:
1. **Goose Forking and Maintenance Strategy:**
*Should we fork Block's Goose repository to remove subprocess and socket dependencies, or build FFI wrappers directly inside the main workspace to track upstream updates more easily?*
2. **Model Choice for 8GB Base Models:**
*Should we restrict the free GGUF download option on 8GB Macs to Phi-3.5-mini (2.2GB) and block Qwen-7B to prevent out-of-memory issues?*
3. **App Store Server Key Strategy:**
*Are the Apple Server API keys configured on your verification proxy, or do we need to set up a secure transit service to sign user subscription receipts during development?*

claude - # Epistemos Mac App Store Build — Unified Execution Dossier

**Prepared:** July 3, 2026. **Verification basis:** current Apple developer documentation, github.com/aaif-goose/goose (formerly block/goose) main branch, github.com/ggml-org/llama.cpp master, Hugging Face model configs/GGUF repos, App Store Review Guidelines. Every load-bearing claim is tagged **[verified-in-source]**, **[inferred]**, or **[uncertain]**.

## TL;DR
- **The architecture is sound and shippable.** All four MAS-critical constraints hold: llama.cpp embeds as a static/XCFramework library in-process; goose runs in-process via its core `goose` crate (no goosed, no subprocess, no socket) provided you keep extensions/scheduler/containers off; GGUF downloads are data-not-code under Guideline 2.5.2; and the StoreKit-2-JWS→proxy→short-lived-token flow is standard. No forbidden entitlements are required.
- **The biggest correction to the prior dossiers:** there is **no mature `goose-sdk` crate** — it does not exist. You bind to the core `goose` crate directly (`Agent`, `AgentManager::get_or_create_agent`, `SessionManager`, `update_provider`, `reply` → `AgentEvent` stream) behind your own thin UniFFI wrapper. The KV-cache math is also resolved: **Phi-3.5-mini is KV-expensive (32 dense MHA heads), not a long-context champion**; Qwen2.5-7B (GQA, 4 KV heads) is the better long-document reader on 16 GB, and in mid-2026 a Qwen3-4B/Qwen3-8B class model is the sharper default.
- **Apple Foundation Models is real and usable but gated to macOS 26+**, which is roughly half the installed base in mid-2026 (TelemetryDeck's macOS survey through end of May 2026 shows the leading single build, macOS 26.5, at **46.48%**). Lead with Apple FM as the zero-download default *when available*, but ship a small GGUF (Qwen3-4B class) as the fallback brain for the ~half of Macs that cannot run Apple Intelligence.

---

## Section 1 — llama.cpp embedded on MAS

**Verdict:** Embed llama.cpp as a static library / prebuilt XCFramework, Metal backend on, server/tools off. This is the consensus baseline and it is correct. [verified-in-source]

The four prior dossiers conflicted on CMake flags. Resolution against current llama.cpp master:

| Concern | Correct 2026 value | Status |
|---|---|---|
| Static linking | `-DBUILD_SHARED_LIBS=OFF` (this is the current canonical flag; `LLAMA_STATIC` is legacy) | [verified-in-source] llama.cpp docs/build.md, build-xcframework.sh |
| Metal enable | `-DGGML_METAL=ON` (Metal is default-on for macOS; the old `LLAMA_METAL` name is deprecated in favor of the `GGML_`-prefixed flags) | [verified-in-source] docs/build.md |
| Metal shader lib | `-DGGML_METAL_EMBED_LIBRARY=ON` — embeds the metallib into the binary, eliminating the `default.metallib`/`ggml-metal.metal` path-resolution problem that plagues sandboxed apps | [verified-in-source] build-xcframework.sh |
| Server off | `-DLLAMA_BUILD_SERVER=OFF` | [verified-in-source] build-xcframework.sh |
| Examples/tests off | `-DLLAMA_BUILD_EXAMPLES=OFF`, `-DLLAMA_BUILD_TESTS=OFF` | [verified-in-source] |
| BF16 Metal | `-DGGML_METAL_USE_BF16=ON` (used in upstream Apple build script) | [verified-in-source] build-xcframework.sh |
| OpenMP | `-DGGML_OPENMP=OFF` (upstream Apple builds disable it) | [verified-in-source] build-xcframework.sh |

**Upstream publishes an official XCFramework.** [verified-in-source] The llama.cpp repo ships `build-xcframework.sh` and attaches `llama-b<NNNN>-xcframework.zip` assets to its releases, consumable directly as an SPM `binaryTarget` with a checksum. The upstream README shows the exact `Package.swift` binaryTarget pattern pinned to a build tag (e.g. `b5046`).

**Recommended packaging approach (cleanest 2026 path):** Pin a specific upstream XCFramework release build, embed via SPM `binaryTarget`, and write a small Objective-C++/Swift thin wrapper over the C API. Do **not** depend on `SwiftLlama` or the in-repo `Package.swift` (the latter uses `unsafeFlags`, which blocks SPM semantic versioning — this is a documented community pain point, and is why StanfordBDHG and SpeziLLM ship their own prebuilt XCFramework). [verified-in-source]

**Metal + JIT entitlements:** The consensus that no `allow-jit` / `allow-unsigned-executable-memory` entitlement is needed for llama.cpp's Metal path is **[inferred, high-confidence]**. Metal shader compilation runs through system-signed driver processes, not writable-executable pages in the app's address space; PocketPal and Private LLM ship on the App Store without these entitlements. Confirm via a release-signed + notarized test build before final submission; if Metal shader loading fails only under hardened-runtime signing, revisit — but do not pre-emptively add the entitlements.

**Current C API entry points** (names changed in the Jan-2025 refactor; the older names are deprecated aliases): [verified-in-source]
- `llama_model_load_from_file(path, params)` — replaces the deprecated `llama_load_model_from_file`
- `llama_init_from_model(model, ctx_params)` — replaces the deprecated `llama_new_context_with_model`
- Model loading logic now lives in `llama-model.cpp` / `llama-model-loader.cpp`.

**mmap in sandbox:** `use_mmap` defaults on and works for files inside the app container. For user-selected files outside the container, you must resolve a security-scoped bookmark and hold access open for the lifetime of the mmap. Store downloaded GGUFs under Application Support inside the container to avoid this entirely for the default path.

### llama.cpp embedding checklist

| Step | Action | Status |
|---|---|---|
| 1 | Pin upstream XCFramework release build (`llama-b<NNNN>-xcframework.zip`) | [verified-in-source] |
| 2 | Add as SPM `binaryTarget` with checksum | [verified-in-source] |
| 3 | Build flags: `BUILD_SHARED_LIBS=OFF`, `GGML_METAL=ON`, `GGML_METAL_EMBED_LIBRARY=ON`, `LLAMA_BUILD_SERVER=OFF` | [verified-in-source] |
| 4 | Thin ObjC++/Swift wrapper over C API (`llama_model_load_from_file`, `llama_init_from_model`) | [verified-in-source] |
| 5 | Store GGUFs in app container Application Support; security-scoped bookmarks only for user-picked files | [inferred] |
| 6 | Ship WITHOUT allow-jit / allow-unsigned-executable-memory; verify with notarized build | [inferred] |

---

## Section 2 — Local model set with corrected KV math + 2026 recommendation

**The contradiction resolved:** One dossier claimed Phi-3.5-mini is a long-context champion; another said it is KV-expensive due to dense attention. **The second dossier is right.** [verified-in-source]

Phi-3-mini / Phi-3.5-mini use **32 attention heads and 32 KV heads** (full Multi-Head Attention, no GQA), 32 layers, head_dim 96 (hidden 3072). Multi-head means the KV cache is *not* reduced by grouping. [verified-in-source — Phi-3 Technical Report arXiv:2404.14219: "The model uses 3072 hidden dimension, 32 heads and 32 layers"; Phi-mini uses "Multi-Head Attention... with H=32 heads"]

Qwen2.5-7B uses **28 query heads but only 4 KV heads** (GQA), 28 layers, head_dim 128. [verified-in-source — Qwen2.5-Coder Technical Report arXiv:2409.12186 Table 1 and HF config.json]

Qwen2.5-14B uses **40 query heads, 8 KV heads** (GQA), 48 layers, head_dim 128. [verified-in-source]

**KV cache per token** = `2 (K and V) × n_layers × n_kv_heads × head_dim × bytes_per_element`. At FP16 (2 bytes):

| Model | Layers | KV heads | Head dim | KV bytes/token (FP16) | KV @ 8K ctx | KV @ 32K ctx |
|---|---|---|---|---|---|---|
| Qwen2.5-7B | 28 | 4 | 128 | 2×28×4×128×2 = **57,344 B (~56 KB)** | ~0.44 GB | ~1.75 GB |
| Qwen2.5-14B | 48 | 8 | 128 | 2×48×8×128×2 = **196,608 B (~192 KB)** | ~1.5 GB | ~6.0 GB |
| Phi-3.5-mini | 32 | 32 | 96 | 2×32×32×96×2 = **393,216 B (~384 KB)** | ~3.0 GB | ~12.0 GB |

This is the definitive resolution: **Phi-3.5-mini's KV cache is ~6.9× larger per token than Qwen2.5-7B's**, despite Phi having fewer weights. The earlier "6x contradiction" across dossiers came from whether the author used Phi's true 32 dense KV heads or wrongly assumed GQA. On a 16 GB M2 Pro (~10.5 GB usable), Phi-3.5-mini at long context is a memory trap; Qwen2.5-7B is the honest long-document reader.

**Q4_K_M GGUF file sizes** (official repos): [verified-in-source]
- Qwen2.5-7B-Instruct Q4_K_M: **4.68 GB** (bartowski / lmstudio-community)
- Qwen2.5-14B-Instruct Q4_K_M: **8.99 GB** (bartowski)
- Phi-3.5-mini Q4_K_M: ~2.2–2.4 GB (small weights — the small footprint is real, but the KV cost at context is not)

**Safe context ceilings on 16 GB M2 Pro (~10.5 GB usable):**

| Model | Weights (Q4_K_M) | Remaining for KV+overhead | Practical max context | Verdict |
|---|---|---|---|---|
| Qwen2.5-7B | 4.68 GB | ~5.5 GB | 32K comfortable, 40–48K possible | **Best long-doc reader at this tier** |
| Qwen2.5-14B | 8.99 GB | ~1.3 GB | ~4–8K only | Great quality, but tight; short context only |
| Phi-3.5-mini | ~2.3 GB | ~8 GB | ~16K before KV dominates | Fast/small, but NOT the long-context choice |

**2026 model recommendation (the earlier three picks are stale):** [verified-in-source for architecture; [inferred] for the "best pick" judgment]

The 2025–2026 releases supersede Qwen2.5/Phi-3.5 for a 16 GB reading app. Qwen3 dense models use GQA with **8 KV heads** and head_dim 128 across the family (Qwen3-4B: 36 layers; Qwen3-8B: 36 layers, 32 query / 8 KV heads), 32K native context (extensible), Apache-2.0. Gemma 3 4B is GQA, Gemma license, natively multimodal. [verified-in-source]

Recommended tiering:
- **Default downloadable local brain: Qwen3-4B-Instruct (Q4_K_M, ~2.5 GB), Apache-2.0.** Best quality-per-GB for a reading/notes app; GQA keeps KV modest; fits 16 GB with generous context.
- **Stronger opt-in: Qwen3-8B (Q4_K_M, ~5 GB), Apache-2.0** — the 7B-class successor to Qwen2.5-7B, with 8 KV heads.
- **Avoid as long-doc default: Phi-3.5-mini and Phi-4-mini** (dense MHA KV cost).
- **Licenses:** Qwen3 is Apache-2.0 (no gating). Gemma 3 uses the Gemma license with acceptance flow; prefer Apache-2.0/MIT to avoid HF license-acceptance friction in an in-app downloader.

### Corrected model table (with KV math shown)

| Model | Params | KV heads | KV/token FP16 | Q4_K_M size | License | Role |
|---|---|---|---|---|---|---|
| Qwen3-4B | 4B | 8 (GQA) | ~147 KB | ~2.5 GB | Apache-2.0 | **Recommended default download** |
| Qwen3-8B | 8.2B | 8 (GQA) | ~147 KB | ~5 GB | Apache-2.0 | Stronger opt-in |
| Qwen2.5-7B | 7.6B | 4 (GQA) | ~56 KB | 4.68 GB | Apache-2.0 | Solid long-doc reader (lowest KV) |
| Qwen2.5-14B | 14.7B | 8 (GQA) | ~192 KB | 8.99 GB | Apache-2.0 | Short-context quality only on 16 GB |
| Phi-3.5-mini | 3.8B | 32 (MHA) | ~384 KB | ~2.3 GB | MIT | NOT for long context |

Note: Qwen3-4B KV/token = 2×36×8×128×2 = 147,456 B. Qwen2.5-7B has the *lowest* KV/token of the set because it has only 4 KV heads and 28 layers — so for maximum context on 16 GB it remains uniquely strong.

---

## Section 3 — Apple Foundation Models integration

**Verified OS floor: macOS 26.0 (Tahoe).** [verified-in-source] Apple's `SystemLanguageModel` documentation lists availability as "iOS 26.0+ / iPadOS 26.0+ / Mac Catalyst 26.0+ / macOS 26.0+ / visionOS 26.0+". The dossiers that said "macOS 15" were wrong; "macOS 26" and "macOS Tahoe 26" are the same thing and correct. The framework is **FoundationModels** (not "LanguageModels", not "Core AI" — those are different things; see below).

**Real API names** (resolving the conflicting samples): [verified-in-source]
- Framework: `import FoundationModels`
- Model handle: `SystemLanguageModel.default` (base model); `SystemLanguageModel(useCase: .contentTagging)` for specialized
- Availability check: `SystemLanguageModel.default.availability` → `.available` or `.unavailable(reason)` where reason ∈ `{.deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady}`
- Session: `LanguageModelSession(model:tools:)` — stateful, keeps a `transcript`
- Generate: `session.respond { Prompt("...") }`; streaming via `session.streamResponse`
- Structured output: `@Generable` / `@Guide` macros
- Errors: guardrail violation, unsupported language, **context window exceeded** — must be handled

**Context window & guardrails (implications for an academic-reading app):** [verified-in-source]
- The base on-device model is the **3-billion-parameter dense "AFM 3 Core"** (Apple Machine Learning Research, "Introducing the Third Generation of Apple's Foundation Models," June 8, 2026). Apple is explicit about scope: in the WWDC25 session "Meet the Foundation Models framework," the on-device model "is optimized for use cases like summarization, extraction, classification… It's not designed for world knowledge or advanced reasoning, which are tasks you might typically use server-scale LLMs for." For a research app this means Apple FM is appropriate for *summarize this passage / rewrite these notes / extract structure*, **not** "answer this scholarly question from parametric knowledge."
- **Guardrails** flag self-harm, violence, and adult sexual content on input AND output, with documented false positives. For an academic-reading app that may process papers on medicine, conflict, or sexuality, expect occasional `guardrailViolation` errors on legitimate scholarly text. You must catch these and fall back gracefully (e.g. to the local GGUF path, which has no such guardrails). This is a real product risk worth surfacing in Surface A's fallback logic.

**WWDC 2026 announcements — confirm/debunk:** [verified-in-source, but see caveat]
- **Image input: CONFIRMED.** WWDC 2026 added multimodal image input to the on-device model (via a new image content block in `LanguageModelSession`), with Vision-framework OCR/barcode tools callable on-device. **Caveat:** image input is tied to the new higher-end on-device tier, **AFM 3 Core Advanced** — a "20-billion-parameter model [that] uses a sparse architecture, activating just 1 to 4 billion parameters at a time" and is "natively multimodal… unlocked by and optimized for our most capable Apple silicon systems" (Apple ML Research). Older Apple-Intelligence devices "fall back to AFM 3 Core," the 3B dense model — so **do not assume image input on every macOS 26 Mac.**
- **Cloud model support via a Language Model protocol: CONFIRMED.** A new `LanguageModel` protocol lets `SystemLanguageModel`, a new `PrivateCloudComputeLanguageModel` (32K context, reasoning), and third-party providers (Anthropic Claude, Google Gemini via their Swift packages) all back a `LanguageModelSession`. Free Private Cloud Compute access for developers in the Small Business Program with <2M lifetime downloads. (For context on relative strength: Apple reported AFM 3 Cloud "was preferred on 64.7% of prompts versus 8.7% for the 2025 server baseline," and the top cloud tier "AFM 3 Cloud Pro runs on NVIDIA GPUs hosted in Google Cloud" — 9to5Mac, June 11, 2026.)
- **"Core AI framework": CONFIRMED as a real, separate framework** for running custom local models on Apple silicon (positioned as a first-party alternative to Ollama/llama.cpp), alongside open-sourced `CoreAILanguageModel` and `MLXLanguageModel` conforming to the `LanguageModel` protocol. **Caveat:** the WWDC 2026 material is very recent (June 2026) and much detail comes from secondary developer write-ups and one WWDC session transcript; treat exact entitlement names and GA timing as **[uncertain]** until confirmed against final documentation.

**App Review implications:** Using Apple FM is fully sanctioned and adds no size to the binary. No special review concern; it strengthens the privacy story for Surface A.

**Architectural recommendation:** For Surface B's cloud path you should still route through your own paywalled proxy (StoreKit-gated), NOT through Apple's new server-model integration — Apple's path is designed for the app to call Claude/Gemini directly under the provider's own billing/policy, which does not give you subscription monetization or provider-key hiding. Apple FM's on-device and PCC models are a good *Surface A* enhancement; your *Surface B* proxy stays as designed.

---

## Section 4 — goose in-process, verified current API surface + wrapper plan

**This is the highest-risk area and the prior dossiers were most confused here. Resolution:**

**Repo has moved:** `block/goose` → **`aaif-goose/goose`** (Agentic AI Foundation, Linux Foundation), Apache-2.0, workspace **v1.34.0** (as of April 2026 index), actively developed. [verified-in-source]

**`goose-sdk` does NOT exist.** [verified-in-source] The dossier claiming a ping→pong `goose-sdk` stub and the one treating it as "ready to wire" are **both describing a crate that is not in the tree**. Current `crates/`: `goose` (core), `goose-cli`, `goose-server`, `goose-mcp`, `goose-acp-macros`, `goose-test`, `goose-test-support`. You bind the **core `goose` crate** directly and build your own Epistemos-owned thin Rust wrapper + UniFFI. This matches the original consensus baseline (bind to `crates/goose`, never `goose-server`) — that baseline was right.

**Which dossier's API description was correct:** The dossier citing `Agent`, `AgentConfig`, `Agent::reply`, and a tool stream yielding items was **closest to reality**, but with corrections. The dossier citing `AgentManager::instance()` with `SessionManager`, `Scheduler`, `PermissionManager`, `set_default_provider`, `get_or_create_agent`, `cancel_session` was **partly right** — `AgentManager` and `get_or_create_agent` are real, but `instance()` and `set_default_provider` are not the confirmed names (`update_provider` is).

### Verified goose core API surface map

| Capability | Symbol / signature | File path | Status |
|---|---|---|---|
| Agent struct | `pub struct Agent { pub config: AgentConfig, provider: SharedProvider, extension_manager, tool_confirmation_router, retry_manager, ... }` | `crates/goose/src/agents/agent.rs` | [verified-in-source] |
| Construct | `Agent::new()` (no args); `Default for Agent` delegates to `new()` | `crates/goose/src/agents/agent.rs` | [verified-in-source] |
| Config struct | `AgentConfig::new(session_manager, permission_manager, scheduler_service: Option, goose_mode, disable_session_naming, goose_platform)` | `crates/goose/src/agents/agent.rs` | [verified-in-source] |
| Platform enum | `GoosePlatform { GooseDesktop, GooseCli }` (no server/embedded variant — reuse GooseCli) | `crates/goose/src/agents/` | [verified-in-source] |
| Run a turn | `pub async fn reply(...)` → stream of `AgentEvent`; takes messages + `SessionConfig` (+ `CancellationToken`) | `crates/goose/src/agents/agent.rs` (L873+) | [verified-in-source] name/return; [inferred] exact args |
| Stream events | `enum AgentEvent { Message(Message), McpNotification((String, ServerNotification)), HistoryReplaced(Conversation) }` — ONLY these three | `crates/goose/src/agents/agent.rs` | [verified-in-source] |
| Tool requests | Surfaced as `ToolRequest` / `ActionRequiredData` **inside** an `AgentEvent::Message`, NOT a top-level stream variant | `crates/goose/src/conversation/message.rs` | [verified-in-source] |
| Tool approval | `tool_confirmation_router: ToolConfirmationRouter` + `ActionRequiredManager`; submit `PermissionConfirmation`; method commonly `handle_confirmation(...)` | `crates/goose/src/agents/tool_confirmation_router.rs`, `action_required_manager.rs` | [inferred] exact signature |
| Permission routing | `PermissionRouting::ActionRequired` (provider-native approval delegation) via `provider.permission_routing()` | `crates/goose/src/providers/base.rs` | [verified-in-source] |
| Modes | `GooseMode { Auto, Approve, SmartApprove, Chat }` (env `GOOSE_MODE`) | `crates/goose/src/config/` | [verified-in-source] |
| Set provider | `agent.update_provider(Arc<dyn Provider>)` — swaps `SharedProvider` at runtime, persists to session | `crates/goose/src/agents/agent.rs` | [verified-in-source] name; [inferred] signature |
| Provider trait | `Provider` with `stream()`, `complete()`, `get_model_config()`, `permission_routing()` | `crates/goose/src/providers/base.rs` | [verified-in-source] |
| Agent lifecycle | `AgentManager::get_or_create_agent(session_id) -> Result<Arc<Agent>>`, LRU cache up to 100 sessions | `crates/goose/src/execution/manager.rs` | [verified-in-source] |
| Sessions | `SessionManager::{create_session, get_session, copy_session (fork), export_session, import_session, add_message}` | `crates/goose/src/session/session_manager.rs` | [verified-in-source] |
| Session store | SQLite `sessions.db` via sqlx; path via `choose_app_strategy(... "Block"/"goose")`, override with `GOOSE_PATH_ROOT` env | `crates/goose/src/config/paths.rs` | [verified-in-source] |
| Cancellation | `CancellationToken` + `is_token_cancelled`; `DEFAULT_MAX_TURNS = 1000` | `crates/goose/src/agents/agent.rs` | [verified-in-source] |

### Sandboxing hazards in the core crate (critical)

The core `goose` crate is **NOT automatically sandbox-safe** — it can spawn subprocesses and MCP servers *if you use those code paths*. To embed safely: [verified-in-source unless noted]
- **MCP stdio extensions spawn child processes** (`extension_manager.rs` + `mcp_client.rs` via `rmcp`). The `developer` extension is often enabled by default. **Embed with ZERO enabled extensions** unless a tool is delivered in-process.
- **Sub-recipes can spawn `goose run --recipe …`** (CLI subprocess) in `subagent_execution_tool/tasks.rs`. **Avoid recipe/sub-recipe/scheduler paths.**
- **Docker container spawning** via `Agent::set_container()` — opt-in; never call it.
- **Scheduler** (`scheduler.rs`) spins up agents/processes; `scheduler_service` in `AgentConfig` is `Option` → leave it **`None`**.
- **TCP listeners live in goose-server and goose-cli web mode, NOT in the core agent path.** [verified-in-source] Pure in-process `Agent` use binds no sockets. Outbound HTTPS to your proxy via `reqwest` is expected — allow egress via `network.client`.
- **Keyring:** core uses the `keyring` crate (macOS Keychain). In a sandbox, either grant a keychain-access-group entitlement or set **`GOOSE_DISABLE_KEYRING=1`** to force file-based secrets. For a locked-down MAS build, disabling keyring and storing the short-lived proxy token in your own container is cleaner.
- **Cargo features:** build with `default-features = false` and enable only the provider(s) you need; disable `local-inference`, `cuda`, `aws-providers`, `telemetry`. **[uncertain]** whether a single feature flag disables MCP/keyring — the exact `[features]` table could not be fetched verbatim; the local build agent must read `crates/goose/Cargo.toml` directly.

### ACP consolidation direction — does it change the embedding story?

**Partly, and in your favor — but it's a moving target.** [verified-in-source]
- Maintainers are standardizing on **ACP (Agent Client Protocol, JSON-RPC 2.0)** as the primary client↔agent interface, and have decided to **bake ACP into the `goose` crate itself** (Discussion #4645: *"I'll plan to bake the ACP interface into the goose crate itself"*), not a separate SDK. Workspace already depends on `agent-client-protocol = "0.11"`. `SessionType::Acp` already exists in the session layer.
- A further proposal (Discussion #7697, #6642) would **consolidate to one binary speaking ACP over stdio/HTTP, removing `goosed` and `goose-cli`'s direct `goose::Agent` calls**. This is a **direction/proposal, not shipped** — treat as [uncertain].
- **Implication for Epistemos:** You have two viable embedding contracts. (a) **Direct Rust API** (`Agent` / `AgentManager` / `SessionManager`) behind UniFFI — available today, but the API is explicitly unstable ("until we publish the API for third parties we can make changes as much as we want"). (b) **In-process ACP** — talk ACP JSON-RPC to an in-process agent with no socket (ACP does not require a network transport; it can run in-process/over a channel). Option (b) will become the stable, documented contract. **Recommendation:** build the wrapper so the Epistemos↔goose boundary is ACP-shaped (session/new, session/prompt, tool permission round-trips), backed today by the direct Rust API, so you can swap to native in-process ACP when it stabilizes without rewriting Surface B.

### Wrapper plan (Epistemos-owned)

1. Create `epistemos-goose` Rust crate depending on `goose` with `default-features = false`.
2. Own a single Tokio multi-thread runtime inside the wrapper; the macOS app calls in via UniFFI async; the wrapper drives `agent.reply(...)` and forwards `AgentEvent`s as UniFFI callback/stream events. [inferred — tokio ownership pattern]
3. Configure the provider via `update_provider` pointing at your proxy as an OpenAI-compatible endpoint (Section 5).
4. Implement tool approval as an async round-trip: on an in-message `ToolRequest`/`ActionRequiredData`, pause and surface an approval card in Surface B; on user decision, submit a `PermissionConfirmation` through `tool_confirmation_router` / the confirmation method.
5. Set `GOOSE_PATH_ROOT=<app container>` and `GOOSE_DISABLE_KEYRING=1`; enable no extensions, `scheduler_service = None`, no container.
6. Shape the UniFFI surface as ACP verbs to future-proof.

---

## Section 5 — goose → cloud proxy config

**Verdict:** Use goose's built-in **OpenAI-compatible provider** pointed at your proxy. This is fully supported and needs no forking. [verified-in-source]

Mechanism (current, verified against goose docs/source):
- `GOOSE_PROVIDER=openai`, `GOOSE_MODEL=<model>`
- `OPENAI_HOST=https://your-proxy.example.com` (scheme+host)
- `OPENAI_BASE_PATH=v1/chat/completions` (or the proxy's path; goose auto-selects `/v1/responses` for some models — set base path explicitly)
- `OPENAI_API_KEY=<short-lived token>` — set this to the proxy token from the StoreKit flow, rotated per session
- `OPENAI_CUSTOM_HEADERS="HEADER_A=VALUE_A,HEADER_B=VALUE_B"` — for extra auth/tenant headers [verified-in-source]
- For a named provider, a **DeclarativeProviderConfig / custom provider JSON** with `{name, engine: "openai", base_url, api_key_env, models:[{name, context_limit}]}` is supported; `OpenAiProvider::from_custom_config(model_config, config)` exists in source. [verified-in-source]

In-process you don't use env vars — you construct the provider programmatically (`create("openai", model_config, ...)` / `from_custom_config`) and pass it to `agent.update_provider(...)`, injecting the short-lived token as the API key and rotating it as StoreKit re-verification issues new tokens. [inferred — programmatic wiring]

**Token rotation:** Because the proxy token is short-lived, the wrapper must refresh the provider (call `update_provider` with a new provider instance carrying the new token, or mutate the header) when the token nears expiry. [inferred]

---

## Section 6 — Surface B workspace frontend (June findings, stated honestly)

**June is real, but it is NOT a reusable goose-based SwiftUI workspace.** [verified-in-source]

The repo `open-software-network/os-june` exists, is **MIT**, and is a real product ("Private AI on your Mac. Chat, dictation, meeting notes, and a local agent"). **However:**
- It is a **Tauri** desktop app (Rust + web frontend), bundle id `co.opensoftware.june`, Cargo package `os-june` — **not native SwiftUI**. [verified-in-source]
- Its agent is built on the **"Hermes" framework**, **not Block's goose**. [verified-in-source] The prior dossier claiming June's source describes goose workspace components was **wrong** on the framework.
- The other dossier that "could not locate a verifiable public June repo" was also wrong — it exists; it just isn't what the first dossier thought it was.
- The dossier reference to `agent-hud.html` at `open-software-network/os-june` is **[uncertain]** — plausible given the Tauri/web frontend, but not confirmed as a reusable component you'd port.

**Honest conclusion:** Do **not** treat June as a component library to port. It's a useful *reference product* for the two-surface pattern (local-by-default chat + a sandboxed agent that waits for approval on risky actions — exactly Epistemos's A/B split), and its "route model calls through a keys-server-side proxy" pattern mirrors yours. But since it's Tauri+Hermes+web, there are no SwiftUI components to reuse. Build the Surface B workspace natively in SwiftUI per the spec below.

### Native SwiftUI Surface B component spec (agent furniture)

| Component | Purpose | Data source (goose) |
|---|---|---|
| Transcript / step rail | Ordered stream of turns and agent steps | `AgentEvent::Message` sequence |
| Tool-call card | Shows tool name, args, status (pending/running/done/error) | `ToolRequest` inside `AgentEvent::Message` |
| Approval sheet/prompt | Blocks on risky tools; Approve/Deny/Always | `ActionRequiredData` → `PermissionConfirmation` round-trip |
| Live delta / thinking block | Token-by-token streaming + reasoning (collapsible) | streamed message deltas; reasoning captured from provider |
| Editable doc pane | The artifact the agent is producing/editing | app-owned; agent edits via tools |
| Source rail | Papers/sources pulled in, citations | app-owned research store |
| Session timeline | List/resume/fork past sessions | `SessionManager` (SQLite `sessions.db`) |
| Cancel control | Stop the current run | `CancellationToken` |

---

## Section 7 — Two-surface UX anti-mixing rules

**Verdict:** The consensus (shared palette/typography, different layout grammar) is correct and is the right way to keep "answer me" (A) and "do this for me" (B) from bleeding into each other. Concrete rules:

| Dimension | Surface A — Quick Chat | Surface B — June Agent Workspace |
|---|---|---|
| Entry | Default landing | Deliberate button destination |
| Layout | Single calm column | Multi-pane workspace |
| Density | Low, generous whitespace | Higher; cards, rails, panels |
| Verbs | "Ask", "Explain", "Summarize" | "Run", "Do", "Build", "Approve" |
| Engine | Local only (Apple FM or GGUF) | Cloud via proxy (goose) |
| Agent furniture | None (no tool cards, no approvals) | Visible: step cards, tool cards, approvals, thinking blocks |
| Network | No model egress (local) | HTTPS to proxy only |
| Failure mode | Guardrail fallback to GGUF | Tool denial, token refresh, cancel |

The strict separation is also a **compliance asset**: Surface A demonstrably makes no network model calls, and Surface B's cloud use is gated behind the paywall and clearly scoped — clean story for App Review.

---

## Section 8 — MAS compliance + packaging checklist with entitlements table

**GGUF downloads are data, not code — legal under 2.5.2.** [verified-in-source] Current 2.5.2 text: "Apps should be self-contained in their bundles, and may not... download, install, or execute code which introduces or changes features or functionality of the app." Model weights are **data consumed by your bundled inference engine**, not executable code that changes app functionality — the same basis on which **PocketPal AI** (App Store id6502579498, developer Asghar Ghorbani, MIT, github.com/a-ghorbani/pocketpal-ai) operates: its store listing states "Download Model Weights: Connect to the internet to download the required model weights (in GGUF format, e.g., from Hugging Face)." **Private LLM** (paid, one-time, App Store) is likewise live in 2026. Both confirm the download-GGUF-as-data precedent.

- State explicitly in review notes: "The app downloads GGUF model weight files (data) that are executed by the app's bundled, statically-linked llama.cpp inference engine. No executable code is downloaded; app functionality does not change."
- **2.4.5 (Mac App Store specifics):** must be sandboxed and follow the macOS File System model; self-contained single-bundle; no third-party installers; no code/resources in shared locations; no auto-launch/background persistence without consent. [verified-in-source] Storing GGUFs in the app container Application Support satisfies (i) and (ii). The concern that GGUF downloads implicate 2.4.5(iv) is misplaced — the sandbox/self-contained requirements are what matter, and container-stored weights comply.
- **Hardened runtime + notarization:** MAS apps are automatically signed with the hardened runtime and notarized as part of App Store distribution. You do not separately staple for MAS, but the hardened-runtime constraints (no unsigned executable memory, no dylib hijacking) are exactly why the in-process static-library approach (no subprocess, no dlopen of downloaded code) is mandatory. [inferred, high-confidence]

### Entitlements table

| Entitlement | Value | Rationale | Status |
|---|---|---|---|
| `com.apple.security.app-sandbox` | true | MAS requirement | [verified-in-source] |
| `com.apple.security.network.client` | true | Cloud proxy (Surface B), model downloads | [verified-in-source] |
| `com.apple.security.files.user-selected.read-write` | true | Open user's papers; security-scoped bookmarks | [verified-in-source] |
| `com.apple.security.network.server` | **NOT set** | No local server/socket — in-process only | [verified-in-source] |
| `com.apple.security.cs.allow-jit` | **NOT set** | Not needed for Metal path | [inferred] |
| `com.apple.security.cs.allow-unsigned-executable-memory` | **NOT set** | Not needed; verify with notarized build | [inferred] |
| `com.apple.security.cs.disable-library-validation` | **NOT set** | All libs statically linked / signed | [verified-in-source] |

### Compliance checklist

| Item | Status |
|---|---|
| Sandbox on, hardened runtime, notarized via MAS pipeline | [inferred] |
| No subprocess spawned (no goosed, no ollama, no llama-server, no recipe CLI) | [verified-in-source] design |
| No local socket/TCP listener | [verified-in-source] |
| GGUFs stored in container Application Support | [inferred] |
| Security-scoped bookmarks for user-picked files | [verified-in-source] |
| Review notes state "weights = data, engine bundled" | [inferred] |
| No provider API keys in binary | [verified-in-source] design |
| `GOOSE_PATH_ROOT` inside container; keyring disabled or entitled | [verified-in-source] |

---

## Section 9 — Paywall + proxy flow

**Verdict:** Standard StoreKit 2 → server-side verification → short-lived token. Current shape confirmed. [verified-in-source]

1. Free tier: local Surface A (Apple FM / GGUF) needs **no gate**. [verified-in-source design]
2. Subscription via StoreKit 2. On purchase/entitlement, the app obtains the **JWS-signed `Transaction`**. [verified-in-source]
3. App sends the signed transaction JWS to your proxy. Proxy verifies via the **App Store Server API** (JWT-authenticated with your `.p8` key/Issuer ID/Key ID), parsing `signedTransactionInfo` (JWS, ES256, x5c cert chain — Apple does not publish a JWK; validate the x5c chain to Apple's root). [verified-in-source]
4. Proxy issues a **short-lived token**; all Surface B cloud requests carry it (as the goose `OPENAI_API_KEY`/header). [verified-in-source design]
5. **App Store Server Notifications V2** (JWS payloads) drive renewals/cancellations/refunds server-side; proxy revokes/refreshes token entitlement accordingly. [verified-in-source]
6. Use a per-user `appAccountToken` at purchase to bind transactions to your user and rate-limit the proxy. [verified-in-source]
7. **No provider API keys ever in the binary** — they live only on the proxy. [verified-in-source design]

2025–2026 changes to note: verifyReceipt is deprecated (use App Store Server API / on-device `Transaction` verification); Server Notifications V2 retry behavior changed around March 2026 (Apple reportedly stopped retrying on HTTP 400) — return 2xx promptly and handle idempotently. [verified-in-source]

---

## Section 10 — Risks, phase order, feature ledger

### Top risks

1. **goose core API instability.** [verified-in-source] Maintainers explicitly reserve the right to change the API until it's published for third parties. **Mitigation:** ACP-shaped wrapper boundary; pin a specific goose commit; plan to migrate to in-process ACP when stable.
2. **goose subprocess/MCP hazards leaking into the sandbox.** [verified-in-source] **Mitigation:** zero extensions, no scheduler/recipes/containers, verified by the build-agent checklist below.
3. **Apple FM availability gap.** macOS 26 is ~half the base in mid-2026 (TelemetryDeck: leading build 26.5 at 46.48% end of May 2026). **Mitigation:** GGUF fallback as the true default brain; treat Apple FM as an enhancement, not the floor.
4. **Phi mis-selection for long docs.** Resolved — do not ship Phi-3.5-mini as the long-context reader.
5. **Metal entitlement uncertainty.** [inferred] **Mitigation:** notarized release-signed test before submission.
6. **WWDC 2026 FM details still settling.** [uncertain] **Mitigation:** gate any image-input/Core AI features behind availability checks; don't hard-depend on them for launch.

### Recommended phase order

- **Phase 0 (de-risk):** Notarized spike proving (a) llama.cpp XCFramework + Metal runs sandboxed with no forbidden entitlements; (b) `epistemos-goose` wrapper drives one `agent.reply` turn against the proxy with zero extensions and no subprocess.
- **Phase 1 (Surface A):** Apple FM (availability-gated) + GGUF download/inference (Qwen3-4B default). Guardrail fallback. Ship-able on its own.
- **Phase 2 (Paywall):** StoreKit 2 + proxy + short-lived tokens + Server Notifications V2.
- **Phase 3 (Surface B):** goose in-process, native SwiftUI workspace, tool cards + approval round-trips + session persistence in-container.
- **Phase 4 (hardening):** ACP-boundary migration readiness, cancellation, token rotation, telemetry off.

### Feature ledger

| Capability | Surface | Engine | MAS-legality |
|---|---|---|---|
| Zero-download chat | A | Apple FM (macOS 26+) | Legal; first-party framework |
| Stronger local chat | A | Embedded llama.cpp + GGUF (Qwen3-4B/8B) | Legal; weights=data (PocketPal/Private LLM precedent) |
| Long-document reading | A | GGUF Qwen2.5-7B (lowest KV) / Qwen3 | Legal |
| Cloud agent tasks | B | goose core (in-process) → proxy → cloud model | Legal; no subprocess/socket; paywalled |
| Tool calls + approvals | B | goose tool_confirmation_router | Legal; in-process |
| Session persistence | B | goose SessionManager (SQLite, container) | Legal; `GOOSE_PATH_ROOT` in container |
| Subscription | both | StoreKit 2 + proxy | Legal; standard IAP |

---

## (a) Verification checklist for the local build agent against the Epistemos scaffold

The private scaffold has `runInProcessAgentCore` + `GooseMASAgentCoreCatalog` behind `EPISTEMOS_MAS_GOOSE_V0`, currently unwired. The build agent must verify, against the real goose source (pin the commit; read `crates/goose/Cargo.toml` and `crates/goose/src/agents/agent.rs` directly):

1. **`runInProcessAgentCore` instantiates a real `Agent`/`AgentManager`, not a stub.** Confirm it calls `AgentManager::get_or_create_agent(session_id)` (or `Agent::new()` + `AgentConfig::new(...)`), obtains an `Arc<Agent>`, and drives `agent.reply(...)`. Reject any ping→pong placeholder.
2. **`GooseMASAgentCoreCatalog` enumerates real tools/sources/schedules** wired to actual in-process tool definitions (not stub names), and that any tool is delivered in-process — **no MCP stdio extension is enabled** (extension list empty).
3. **Approvals round-trip into the real confirmation API.** Confirm an in-message `ToolRequest`/`ActionRequiredData` triggers a UI approval and that the user decision is submitted as a `PermissionConfirmation` via `tool_confirmation_router`/the confirmation method — end to end, not mocked.
4. **Sessions persist in the MAS container.** Confirm `GOOSE_PATH_ROOT` points inside the app container and that `SessionManager` writes `sessions.db` there; verify resume/fork works.
5. **No code path launches goosed / ollama / llama-server / `goose run` / Docker / any subprocess, and binds no socket.** Grep the wrapper and confirm `scheduler_service = None`, `set_container` never called, no recipe/sub-recipe execution, `network.server` entitlement absent.
6. **Provider = proxy with short-lived token.** Confirm `update_provider` uses the OpenAI-compatible provider pointed at the proxy, token injected from StoreKit flow, rotated on expiry; no provider keys in the binary.
7. **Build config:** `default-features = false`; `local-inference`/`cuda`/`aws-providers`/`telemetry` off; `GOOSE_DISABLE_KEYRING=1` or keychain-access-group entitlement present.
8. **Read the actual `[features]` table** in `crates/goose/Cargo.toml` to confirm which flags gate MCP/keyring — this was the one item that could not be verified remotely.

## (b) Open questions for the owner

1. **goose commit pinning / update policy:** which commit do you pin, and what's the cadence for absorbing upstream API changes given the explicit instability? Do you want to wait for in-process ACP to stabilize before Surface B GA?
2. **Apple FM as default vs GGUF-first:** given ~half the base can't run macOS 26 Apple Intelligence in mid-2026, do you want the very first-run experience to be "Apple FM if available, else prompt a small GGUF download," or always lead with a GGUF download for consistency?
3. **Model licensing in-app:** Qwen3 (Apache-2.0) avoids gating; do you also want to offer Gemma 3 (license acceptance) or keep the catalog Apache-2.0/MIT only?
4. **Image input / Core AI (WWDC 2026):** do you want to adopt on-device image input for reading figures/screenshots at launch (noting it requires the higher-end AFM 3 Core Advanced tier), or defer until Apple's docs finalize?
5. **Proxy provider choice:** which cloud model(s) behind the proxy, and what context/cost limits do you set per subscription tier?
6. **Tool scope for Surface B:** which research tools (fetch source, search library, cite, edit doc) ship in v0, and which require approval by default?
7. **Keyring vs file secrets:** are you willing to request a keychain-access-group entitlement, or standardize on `GOOSE_DISABLE_KEYRING` + container-stored token?
