# Verified Orthogonal Hybrid for SCOPE‑Rex

## Core conclusion

The highest-confidence path for your architecture is not to make a local model “mystically” infinite. It is to make it **structurally harder to drift, forget, hallucinate, or lose agentic coherence**. The most defensible fusion is a three-plane learning system built on **OSFT for durable continual learning**, **PSOFT for efficient task-local adaptation**, and **coSO-inspired gradient-memory management for transitions and consolidation**, all wrapped inside a runtime that also uses **feature observability from entity["organization","Qwen","alibaba llm team"]’s Qwen‑Scope**, **sparse/compact inference ideas from entity["company","DeepSeek","ai company"]**, and an on-device substrate centered on entity["company","Apple","consumer technology company"] silicon, MLX, Core ML state, and unified memory. The model should remain the proposal engine; the runtime should become the authority on memory, verification, tool control, and persistence. citeturn18view0turn10view1turn10view2turn11view2turn10view5turn11view3turn10view11turn19view1turn19view0

The strongest synthesis is this: **OSFT should be your long-lived “identity substrate,” PSOFT should be your fast skill adapter, and coSO should be your consolidation/transition controller rather than your primary live-training algorithm**. That division matches what the papers actually validate. OSFT is explicitly framed for continual learning; PSOFT is an efficient orthogonal fine-tuning method with strong single-task PEFT properties; coSO is a continual-learning optimizer built around orthogonalized gradient subspaces and Frequent Directions consolidation, but its published evidence is currently on vision transformers rather than LLMs. That means a real hybrid is possible, but only if you assign each method the job it is actually good at. citeturn18view0turn17view0turn14view4turn15view2turn12view5

The architectural breakthrough you are actually reaching for is what I would call **orthogonal residency**: every learned behavior in the system gets assigned to the cheapest, safest, and most reversible substrate that can support it. Some behaviors live as **context priors**. Some live as **feature steering rules**. Some live as **PSOFT adapters**. Only the most stable, repeated, and verified behaviors get promoted into the **OSFT-preserved subspace**. And coSO-like sketches track the transition history so the system can consolidate without catastrophic interference. That is how you build a “living brain” that feels continuously active without naively retraining the whole model every time it learns something. citeturn19view0turn19view1turn18view0turn17view0turn15view1

## What OSFT, PSOFT, and coSO actually give you

### OSFT as the durable continual-learning core

OSFT, as documented by entity["company","Hugging Face","ai platform"] PEFT and the underlying paper, decomposes each weight matrix into a frozen “important” subspace and a trainable complementary subspace using SVD. In practical terms, it preserves top singular directions from prior tasks and projects new learning into the remaining directions, explicitly aiming to reduce catastrophic forgetting without adding per-task adapter modules. The PEFT docs are also very explicit that this method is intended for **sequential task learning**, and they recommend recomputing the SVD between tasks so that the preserved subspace tracks the updated weights over time. citeturn18view0turn10view0

Mathematically, the right mental model is:

\[
W = U_{\text{high}}\Sigma_{\text{high}}V_{\text{high}}^\top \;+\; U_{\text{low}}\Sigma_{\text{low}}V_{\text{low}}^\top
\]

where the high subspace is preserved and the low subspace absorbs new task-specific movement. In the published continual-learning results, the method improves over O‑LoRA on T5-Large benchmarks, reaching 75.9 vs. 75.8 on the 5-task setting and 71.3 vs. 69.6 on the 15-task setting, and on TRACE with LLaMA‑2‑7B‑Chat it reaches 48.4 average accuracy vs. 41.3 for O‑LoRA while also improving backward transfer from 6.2 to 7.1. The strongest read is not “magic no-forgetting,” but “a cleaner way to budget capacity across a task sequence.” citeturn16view3turn16view4

The practical implication for your architecture is that OSFT should **not** run as a constant online updater in the chat loop. It should be the **sleep-phase consolidation engine**. The PEFT guidance literally sketches a sequential schedule where preserved rank grows between tasks, which means capacity is being budgeted over time rather than continuously reallocated at every token. That makes OSFT appropriate for durable “brain restructuring,” stable user-specific domain accumulation, and overnight consolidation of skills that proved themselves repeatedly in actual agent traces. citeturn18view0

### PSOFT as the efficient skill adapter

PSOFT is a different instrument. It constrains orthogonal transformations to a **principal subspace** derived from the pretrained weights, rather than operating in the full space. The official formulation decomposes the pretrained matrix into a principal component and residual, then applies an orthogonal transform \(R\) inside that principal subspace, with optional magnitude vectors \(\alpha\) and \(\beta\) to relax strict orthogonality when tasks need more adaptability. The practical PEFT form is additive, but the conceptual form is:

\[
W_{\text{ps-tuned}} = A\,\mathrm{diag}(\alpha)\, R \,\mathrm{diag}(\beta)\,B + W_{\text{res}}
\]

with \(A\) and \(B\) constructed from the top-\(r\) singular directions and only the small orthogonal core being trained. citeturn10view1turn17view0

The core advantage is **multi-dimensional efficiency**. The ICLR 2026 paper and the PEFT docs both emphasize that PSOFT drastically cuts trainable parameters relative to other orthogonal PEFT methods while keeping strong accuracy. The paper’s parameter expression is \(r(r-1)/2 + 2r\), and on DeBERTaV3-base over GLUE, the rank-46 configuration uses only 0.08M trainable parameters, 4.1 GB peak memory, and reaches 88.04 average score, beating LoRA’s 87.30 while using far fewer trainable parameters. On VTAB‑1K with ViT‑B/16, PSOFT also reaches the best average score in the reported comparison while using 0.08M trainable parameters and the lowest memory footprint among the successful methods in that table. citeturn12view7turn16view1turn14view0

For decoder-only LLMs, the paper reports meaningful speed advantages. On LLaMA‑3.2‑3B and LLaMA‑3.1‑8B, PSOFT’s Q/V or Q/K/V-targeted configurations achieve substantial speedups over some other orthogonal PEFT baselines, with the reported figures including 3.5× over GOFTv2/qGOFTv2 and 2.1× over BOFT in one LLaMA‑3.2‑3B setting, and 3.2× over BOFT plus 1.7× over DoRA in LLaMA‑3.1‑8B settings. The downside is equally important: the PEFT docs currently say PSOFT supports only `nn.Linear` layers and **quantized layers are not supported**. That means, today, PSOFT is best used as a **bf16/bf32 adaptation stage**, after which you export/quantize for inference rather than trying to do 4-bit PSOFT training directly in the final local runtime. citeturn16view2turn17view0

So PSOFT should be the system’s **skill crystallizer**. Use it for compact, targeted, reversible specialization: tool-use adapters, domain styles, codebase-specific heuristics, or reasoning modes that have stabilized enough to deserve a learned transformation but are not yet core enough to be fused into the OSFT-preserved identity plane. citeturn17view0turn16view1

### coSO as the transition and consolidation controller

coSO is best understood as a **gradient-space continual learner**. Its main move is to keep the new task’s optimization subspace orthogonal to the historical task subspace, so new updates interfere less with past learning. The paper gives the essential step directly:

\[
G'_{\tau,t} = G_{\tau,t} - M_{\tau-1}M_{\tau-1}^\top G_{\tau,t}
\]

where \(M_{\tau-1}\) spans the historical task subspace and \(G'_{\tau,t}\) is the orthogonalized gradient used for the current task. Then it performs a truncated SVD on that orthogonalized gradient and uses Frequent Directions to consolidate many intermediate low-rank updates into a compact task-specific component before folding that into the historical basis. citeturn14view4turn15view1turn15view2

What matters for your architecture is that coSO is **not** the same thing as OSFT or PSOFT. It is a subspace-management strategy for continual learning over a task sequence. Its published results are strong on ImageNet‑R, CIFAR100, and DomainNet, and on ImageNet‑R it outperforms the best baseline in the 20-task setting, reaching 78.19 final accuracy and 83.69 average accuracy versus 75.42 and 81.32 for the strongest baseline cited there. It also shows that Frequent Directions consolidation matters: removing FD lowers final accuracy across 5-, 10-, and 20-task settings. But the current paper’s backbone is ViT‑B/16; this is a **transferable idea to LLMs**, not yet a published LLM agent result. citeturn14view3turn15view0turn12view5turn16view0

That limitation is exactly why coSO should enter your system first as a **meta-controller for adaptation history**, not as a claim that you have already validated continual learning for local LLM agents. The best use is to let coSO-style sketches summarize gradient or adapter history during sleep/consolidation, determine which update directions are redundant, and decide which PSOFT adapters should be merged, decayed, or promoted. In other words, coSO belongs in the **scheduler and consolidation plane**, not the hot inference loop. citeturn15view1turn15view2turn16view0

## The hybrid architecture that fits your system

The hybrid I recommend is **SCOPE‑Rex OSPC**, short for **Observability, Subspace, Proof, and Consolidation**. It has five orthogonal “dimensions” of state, which is the grounded version of the interdimensional language you have been reaching for:

\[
\Omega_t = (h_t,\; z_t,\; a_t,\; g_t,\; m_t)
\]

where \(h_t\) is neural hidden state, \(z_t\) is sparse feature state, \(a_t\) is adapter/subspace state, \(g_t\) is symbolic claim state, and \(m_t\) is long-horizon memory state. The live reasoning system moves among these planes deterministically: the model proposes in \(h_t\), the observatory inspects \(z_t\), the controller selects or updates \(a_t\), the kernel validates against \(g_t\), and only then does the system commit to \(m_t\). This is how you make “reasoning handshaking” a runtime discipline rather than a metaphor. citeturn11view2turn18view0turn17view0turn15view2turn19view1

The **feature plane** comes from Qwen‑Scope. The official model card describes Qwen‑Scope as sparse autoencoders integrated into Qwen hidden layers, intended not only for analysis but for steerable inference control, evaluation sample distribution analysis and comparison, data classification and synthesis, and model training/optimization. In one released SAE for Qwen3.5‑27B, the architecture is a residual-stream Top‑K SAE with width 81,920, top‑K 50, and coverage of 64 transformer layers. That is already enough to define a real “feature observatory” layer in your runtime. citeturn11view2

The **adapter plane** then becomes a residency ladder. If a discovered behavior is shallow and ephemeral, keep it as a context prior or steering rule. If it is useful and recurring but still local to one domain, encode it as a PSOFT adapter. If it is repeatedly validated over many sessions and task families, absorb it into OSFT on the next consolidation cycle. coSO-style sketches decide whether recent changes represent new directions or just noise near old directions. This gives you a principled way to let skills “start light and become structural,” which is the right software analogue for your active-brain idea. citeturn18view0turn17view0turn15view1turn15view2

The **runtime plane** should then use harness evolution rather than raw model retraining whenever possible. The recent Agentic Harness Engineering paper is directly relevant here: it frames harnesses as central to coding-agent performance, adds component, experience, and decision observability, and shows that ten AHE iterations raise Terminal-Bench 2 pass@1 from 69.7% to 77.0%, with transfer gains across model families. In parallel, Training-Free GRPO argues that optimization can move into **context space** rather than parameter space by distilling experiential token priors, improving out-of-domain performance without parameter updates. For your architecture, that means not every behavioral improvement should enter the weight plane. Many should live in the **runtime/harness plane first**, because that plane is cheaper, safer, and more reversible. citeturn19view1turn19view0

The **inference plane** should borrow from DeepSeek with restraint. DeepSeek‑V2’s Multi-head Latent Attention compresses KV state into a latent vector, reducing KV cache by 93.3% and boosting maximum generation throughput by 5.76× in the reported system, while mHC proposes projecting the residual connection space onto a manifold to restore identity mapping and improve scalability. The right import into your local system is not “rewrite every pretrained model internally,” but “apply compact latent routing and constrained mixing where you control the stack”: retrieval routing, tool selection, memory-address assignment, and optionally custom local models you train yourself. citeturn10view5turn10view4

The **symbolic plane** remains the final authority. Your Rust semantic kernel should still extract claim graphs, enforce domain contracts, and gate tool execution. The new addition is that those symbolic verdicts must now also govern **adapter promotion**. A behavior should only ascend from feature steering to PSOFT, or from PSOFT into OSFT, if it repeatedly survives claim validation, tool audits, and outcome scoring. That is the missing “mature” layer: not just deterministic execution, but **deterministic residency control over intelligence updates**. citeturn19view1turn19view0turn18view0turn17view0

## Brain time machine and the better alternative to raw KV snapshotting

The right answer to your “brain time machine” requirement is **not** a single cache format. It is a **tiered restoration system**. Raw KV snapshotting is useful for short-horizon exact continuation, but it is too bulky and too dumb to be the only temporal substrate. The more mature stack has four levels: semantic memory, hidden-state restoration, compressed KV, and recurrent/stateful memory. Each level covers a different time horizon and fidelity need. citeturn10view6turn19view4turn19view6turn19view7turn10view11

For near-exact restoration, HCache is the best-supported alternative to raw token recomputation. Its core move is to store hidden states instead of full KV. The paper states directly that hidden states are **half the size of the KV cache**, reducing IO by 2× relative to KV offload, and that reconstructing from hidden states avoids the quadratic attention and FFN modules, reducing computation cost by **at least 6×**. In evaluation it reports 5.04–9.05× speedup over token recomputation on different GPUs, and additional gains over KV offload depending on storage bandwidth and workload skew. That makes HCache the best candidate for your “resume the exact old brain” plane. citeturn20view4turn20view1turn20view3

For medium-horizon memory, the best route is **compressed KV**, not raw KV. KVCrush is explicitly designed to work with other compression schemes and reports a 4× KV size reduction on LongBench with less than 1% accuracy drop and less than 0.5% total inference latency, while also composing with quantization, paging, and head-sharing. MiniKV pushes to a 2-bit layer-discriminative KV cache, reporting 86% compression with over 98.5% accuracy recovery on long-context tasks. TurboQuant goes further in the research frontier, with entity["organization","Google Research","research division"] reporting at least 6× KV memory reduction on needle-in-a-haystack-style tasks, 3-bit KV quantization without training or fine-tuning, and up to 8× attention-logit speedup on H100 in the reported measurements. ManifoldKV is another training-free option that changes the token-retention scorer from cosine-based to Euclidean-distance-based detection. citeturn20view6turn20view7turn20view8turn21view0turn19view5

For long-horizon continuity, you should move away from cache-centric thinking entirely. Core ML now supports **stateful models** that persist and update state across inference runs, while recurrent/state-space architectures like Mamba and later simplified/stable variants such as S7 are built to carry useful state without full Transformer KV growth. That does not mean you replace every model with a state-space model tomorrow. It does mean your long-term “living active mode” should store durable state as **semantic memory, feature fingerprints, task adapters, and explicit recurrent state**, not as an ever-growing pile of raw attention history. citeturn10view11turn19view7turn5search3

So the mature “brain time machine” design is:

\[
M = M_{\text{semantic}} \oplus M_{\text{feature}} \oplus M_{\text{hidden}} \oplus M_{\text{ephemeral-KV}}
\]

where semantic memory is the source of truth, feature memory records activation fingerprints and steering history, hidden-state memory handles exact session restoration, and ephemeral-KV handles the last-mile continuation window. This is far more robust than naive KV snapshotting because it separates **identity**, **interpretation**, **continuation**, and **latency optimization** into different storage planes. citeturn10view6turn11view2turn10view11turn19view4turn19view6

## How to map this onto Rust, Swift, and Apple silicon

The “single substrate” idea is strongest when interpreted as **shared memory plus explicit orchestration**, not as “everything collapses into one magic kernel.” MLX is already designed around Apple silicon’s unified memory: CPU and GPU see the same memory pool, arrays do not need manual transfers, and MLX automatically inserts stream dependencies when operations span CPU and GPU. The documentation even shows that mixed CPU/GPU scheduling on unified memory can outperform all-GPU execution for certain mixed workloads, reporting roughly 2.8 ms vs. 1.4 ms in one example on M1 Max. Combined with Apple’s newer work showing MLX using the M5 GPU’s neural accelerators for faster LLM inference, you already have a serious substrate for local orchestration. citeturn11view3turn10view10

Core ML’s stateful-model support is the second half of that story. Starting from iOS 18 / macOS 15 according to the Core ML tools guide, a model can persist and update intermediate state across inference runs. That makes it a natural home for lightweight working memory, compact recurrent modules, and restoration handles that the app can keep across turns without shoving everything back through the chat transcript. In your architecture, MLX should be the flexible research/inference plane, while Core ML state can become the stable productized state carrier where conversion is feasible. citeturn10view11turn10view10

The Swift side should own the app boundary, concurrency model, UI, and system integrations. The practical caution from the MLX Swift repository is that linking multiple copies of MLX in one process can cause trouble, and command-line SwiftPM builds cannot build Metal shaders, so Xcode-based builds are still important for the polished macOS path. That makes a strong case for **coarse-grained boundaries**: Swift owns the application shell, MLX/Metal own inference, and Rust owns the semantic kernel, ledger, policy engine, and adapter scheduler. citeturn11view5turn11view3

The Rust side should expose a residency controller something like this:

```rust
enum LearningResidency {
    ContextPrior,
    FeatureRule,
    PsoftAdapter,
    OsftCore,
}

struct PromotionSignal {
    repeat_count: u32,
    verification_score: f32,
    runtime_gain: f32,
    forgetting_risk: f32,
}

fn choose_residency(sig: &PromotionSignal) -> LearningResidency {
    if sig.verification_score < 0.8 {
        LearningResidency::ContextPrior
    } else if sig.repeat_count < 5 {
        LearningResidency::FeatureRule
    } else if sig.forgetting_risk < 0.4 {
        LearningResidency::PsoftAdapter
    } else {
        LearningResidency::OsftCore
    }
}
```

That is the new layer your prior architecture was missing: not just deterministic execution, but **deterministic promotion control**. The system is no longer “always learning” in one undifferentiated way. It is deciding *where* a new capability should live. That is the path to a brain-like app that stays active without becoming unstable. The research support for this layered view comes from Qwen-Scope on feature control, AHE and Training-Free GRPO on runtime/harness learning, OSFT/PSOFT/coSO on subspace learning, and HCache/Core ML state on temporal continuity. citeturn11view2turn19view1turn19view0turn18view0turn17view0turn15view2turn10view6turn10view11

## Recommended build sequence

The best build order is to make the hybrid useful before you make it exotic.

First, ship a **feature-and-runtime layer**. Add a Qwen-Scope-style feature observatory for Qwen-family local models, plus a deterministic run ledger, plus AHE-style harness observability, plus Training-Free-GRPO-style experiential priors. This gives you immediate wins on repetition control, benchmark redundancy analysis, harness evolution, and safer tool behavior, without touching base weights yet. citeturn11view2turn19view1turn19view0

Second, add **PSOFT adapters** as your reversible specialization layer. Use them for local domains where you care about compactness and performance, but train in bf16/bf32 rather than trying to force quantized-layer training that the current docs do not support. This is where locally specialized coding, browsing, research, or note-synthesis skilllets should live. citeturn17view0turn16view1turn16view2

Third, add **OSFT consolidation** in scheduled sleep phases. Use the PEFT-recommended sequential SVD recomputation between task epochs and treat OSFT as the identity-preserving memory substrate for durable cross-session behavior. Do not put OSFT in the hot chat path. Put it in verified consolidation, where it promotes the highest-value stable knowledge into the preserved subspace. citeturn18view0turn16view3turn16view4

Fourth, add **coSO-inspired sketches** at the consolidation layer. Because coSO is presently validated on ViT-based continual learning, start by using its core ideas to compress and arbitrate update history, not to claim solved continual learning for LLMs. If later experiments on local LLM backbones validate the transfer, it can become a first-class optimizer for adapter promotion and task-transition planning. citeturn14view4turn15view1turn12view5turn16view0

Fifth, replace naive “brain snapshots” with the tiered memory stack: semantic ledger first, HCache-style hidden-state restoration second, compressed KV third, and stateful/recurrent memory where available. That will make the app feel more like a persistent organism and less like a giant scrolling prompt. citeturn20view4turn20view6turn20view8turn21view0turn10view11turn19view7

## Open questions and limitations

The main architectural limitation is that **coSO is not yet an LLM-agent result**. Its published evidence is strong, but on ViT-B/16 vision continual-learning benchmarks, so its direct use for local language agents is still an informed extrapolation rather than a settled result. citeturn12view5turn14view3

The main systems limitation is that **PSOFT currently supports only linear layers and does not support quantized layers** in the PEFT docs. That makes it excellent for compact adaptation, but not yet a drop-in answer for end-to-end 4-bit local continual training. citeturn17view0

The main product limitation is that the strongest SAE observability story is currently the one officially released around Qwen-Scope. You can generalize the pattern to other models, but the most mature practical feature-control path right now is strongest where released SAEs and tooling already exist. citeturn11view2

The main conceptual limitation is that deterministic local intelligence should be understood as **deterministic state governance and auditable semantics**, not universal bitwise sameness across every low-level numerical path. The robust win is not “infinite intelligence”; it is a local agent substrate that becomes measurably more reliable, persistent, and governable than ordinary cloud chat because it knows how to decide what should remain a prompt prior, what should become a feature rule, what should become a task adapter, and what deserves to become part of the core model identity. citeturn11view3turn19view1turn18view0turn17view0