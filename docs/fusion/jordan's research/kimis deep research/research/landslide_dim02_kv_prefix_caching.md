# KV Cache Prefix Caching and Prompt Reuse Techniques for LLM Inference

## Executive Summary

KV cache prefix caching has emerged as one of the highest-ROI optimizations in LLM inference, delivering **50-90% cost reductions** and **up to 85% latency improvements** across production workloads [^2547^][^2549^]. This research surveys the major techniques and implementations—from vLLM's hash-based Automatic Prefix Caching to SGLang's tree-based RadixAttention, cross-model sharing via PrefillShare, workflow-aware eviction via KVFlow, and emerging multi-modal caching for vision embeddings. Concrete benchmarks show **2.5-7x throughput gains** and **TTFT reductions from seconds to milliseconds** when cache hit rates exceed 70% [^2509^][^2421^].

---

## 1. RadixAttention in SGLang: Tree-Structured KV Reuse

### Architecture

RadixAttention is SGLang's core innovation for automatic KV cache reuse across requests. Instead of discarding KV cache after each request, SGLang stores cached prefixes in a **radix tree** (compressed trie), where each node holds a variable-length sequence of tokens and its associated KV cache pages [^1130^][^1134^].

```
                    Root
                      |
              [System Prompt + Tools]
                    /    \
          [User Query A]  [User Query B]
             /     \
      [Response 1] [Response 2]
```

When a new request arrives, SGLang walks the tree from the root to find the **longest matching prefix**. Matched nodes reuse cached KV tensors with zero prefill compute; only the unmatched suffix triggers new computation [^2393^]. An **LRU eviction policy** reclaims GPU memory by removing least-recently-used leaf nodes [^1132^].

### Cache-Aware Scheduling

Execution order directly impacts cache efficiency. SGLang implements **cache-aware scheduling** that prioritizes requests with longer shared prefixes, approximating a depth-first traversal of the radix tree. The SGLang paper formally proves this achieves **optimal cache hit rates in the offline case** [^1134^][^1132^].

### Performance Numbers

| Workload | Cache Hit Rate | Throughput Gain | TTFT |
|---|---|---|---|
| Few-shot learning (shared examples) | **85-95%** | Up to 5x | Near-zero for prefix |
| Multi-turn chat (conversation history) | **75-90%** | ~10-20% over vLLM | 54-79ms p50 |
| Agentic (tool defs + memory) | **~88%** | Up to 6.4x | 41ms p50 |
| Unique prompts (no sharing) | 0% | Baseline | 112ms p50 |

*Sources:* [^2501^][^2502^][^2505^][^1134^]

On H100 GPUs with Llama 3.1 8B, SGLang delivers **16,215 tok/s** vs vLLM's **12,553 tok/s**—a **29% throughput advantage** that compounds to ~$15,000/month GPU savings at 1M requests/day [^2505^][^2503^]. Independent benchmarks confirm SGLang's **6.4x higher throughput** on prefix-heavy workloads [^2501^].

### Implementation Notes

- `--mem-fraction-static` controls KV cache pool size (default 0.9 / 90% of GPU memory) [^1132^]
- `sglang_cache_hit_rate` metric should stay >30%; below this, check prefix consistency [^2502^]
- Session affinity across load-balanced instances is critical for multi-turn workloads; use `ip_hash` or conversation-ID routing [^2502^]

---

## 2. vLLM Automatic Prefix Caching (APC)

### Architecture: Hash-Based Block Caching

vLLM takes a fundamentally different approach: instead of a tree, it uses a **hash-based block cache**. Each KV cache block (default 16 tokens) is uniquely identified by:

1. **Parent block hash** — chaining ensures the entire prefix history is encoded
2. **Current block token IDs** — exact tokens in this block
3. **Extra hashes** — LoRA IDs, multimodal input hashes (`mm_hash`), cache salts [^278^][^1186^]

```
hash(block 0) = sha256(NONE_HASH, tokens[0:16], extras)
hash(block 1) = sha256(hash(block 0), tokens[16:32], extras)
hash(block 2) = sha256(hash(block 1), tokens[32:48], extras)
```

The chained parent hash is critical: if block 2's hash matches, blocks 0 and 1 are **guaranteed identical** due to causal attention dependencies [^1186^]. As of vLLM v0.11, SHA256 is the default hashing algorithm to eliminate collision risks (with ~100-200ns per token overhead) [^278^].

### Performance Numbers

| Metric | Without APC | With APC | Improvement |
|---|---|---|---|
| Output throughput | 427 tok/s | 1,513 tok/s | **+254%** (3.5x) |
| Mean TTFT | 4,343ms | 970ms | **-78%** |
| Cache hit rate | 0% | ~50% | — |
| P90 TTFT (10k tokens) | 4.3s | 0.6s | **7x faster** |

*Sources:* [^2509^][^2421^][^2506^]

In a realistic B2B SaaS benchmark with 150 enterprise customers, each with unique 6K-token contexts and 5 concurrent users per customer, **precise prefix cache-aware routing** achieved:
- **P90 TTFT: 0.542s** vs 92.55s for random scheduling (**170x improvement**)
- **Throughput: 8,730 tok/s** vs 4,429 tok/s (**97% improvement**)
- Near-zero waiting queue vs 27.3 average queue depth [^2506^]

### vLLM V1 Multimodal Caching

vLLM V1 treats multimodal inputs as first-class citizens. It moves image preprocessing to a **non-blocking process** and adds a **preprocessing cache** for reused processed inputs [^2491^]. For prefix caching with images, vLLM encodes the **image hash** as an "extra hash" in each block's hash computation, enabling correct differentiation between placeholder tokens for different images [^278^][^2490^].

---

## 3. PrefillShare: Cross-Model Prefill Sharing

### Problem

Multi-agent systems increasingly orchestrate multiple specialized LLMs over shared context. Each model redundantly executes prefill on identical prompts and maintains separate KV caches, intensifying **prefill-decode interference** and duplicating memory [^2419^].

### Architecture

PrefillShare factorizes a model into two modules:
- **Shared prefill module** — frozen base model that processes the shared context once
- **Task-specific decode modules** — fine-tuned only for decoding, consuming the shared KV cache [^2394^]

```
Traditional:          PrefillShare:
Model A: [Prefill]→[Decode]    Shared Prefill: [Prefill] → KV Cache
Model B: [Prefill]→[Decode]        ├──→ Decode A (specialized)
Model C: [Prefill]→[Decode]        ├──→ Decode B (specialized)
Model D: [Prefill]→[Decode]        └──→ Decode C (specialized)
```

### Cache-Conditioned Fine-Tuning

PrefillShare introduces a disaggregation-aware training procedure: freeze the prefill module and fine-tune only the decode module conditioned on the shared KV cache. This matches full fine-tuning accuracy within **±1%** across math (GSM8K), coding (HumanEval), and tool-calling benchmarks [^2419^].

### Memory Complexity

| Setup | Memory Required |
|---|---|
| Baseline (N models) | O(N × (L_shared + L_unique)) |
| PrefillShare | O(L_shared + N × L_unique) |

When L_shared >> L_unique, memory cost becomes **effectively independent of the number of decode modules** [^2394^].

### Performance Numbers

| Metric | Baseline (Disaggregated) | PrefillShare | Improvement |
|---|---|---|---|
| p95 latency (ReAct) | Baseline | — | **Up to 3.9x lower** |
| p95 latency (Reflexion) | Baseline | — | **Up to 4.5x lower** |
| Throughput (ReAct) | Baseline | — | **Up to 3.6x higher** |
| Throughput (Reflexion) | Baseline | — | **Up to 3.9x higher** |
| Prefix cache hit ratio | Degrades beyond ~40 sessions | Sustained high | **~4x throughput at high load** |

*Sources:* [^2419^][^2420^]

### Implementation

PrefillShare extends vLLM's disaggregated serving pipeline with:
- **Prefix-aware routing** — pins requests with the same shared prefix to consistent prefill workers
- **Cache handoff mechanism** — transfers shared KV cache between decode stages
- **Partial prefill** — only computes new tokens appended by previous agent outputs [^2394^]

---

## 4. KVFlow: Workflow-Aware Cache Management

### Problem

Existing serving systems use **LRU eviction**, which is suboptimal for agentic workflows. In multi-agent systems, agents with different "steps-to-execution" values compete for GPU memory, and premature eviction of prefixes needed by soon-to-run agents causes cache misses [^2422^].

### Architecture

KVFlow introduces:

1. **Agent Step Graph** — a flexible abstraction capturing execution dependencies among agents, including conditional branching and synchronization barriers [^2422^]
2. **Steps-to-execution values** — computed via aggregation functions (max for AND dependencies, min for OR dependencies) propagated across the graph
3. **Workflow-aware eviction** — assigns eviction priorities at the **cache node level**; agents with larger steps-to-execution are more likely to be evicted
4. **Fully overlapped KV prefetching** — proactively loads required KV tensors from CPU to GPU ahead of time based on graph predictions [^2422^]

### Performance Numbers

| Scenario | Baseline (SGLang LRU) | KVFlow | Speedup |
|---|---|---|---|
| Single workflow, large prompt | Baseline | — | **1.83x** |
| Many concurrent workflows | Baseline | — | **2.19x** |
| Cache miss overhead | High | Eliminated | Zero stall |

*Source:* [^2422^]

---

## 5. Prompt Caching Pricing: OpenAI and Anthropic

### OpenAI Prompt Caching

| Model | Standard Input | Cached Input | Discount | Latency Impact |
|---|---|---|---|---|
| gpt-4o | $2.50/M | $1.25/M | **50%** | Up to 80% faster |
| gpt-4.1 | $2.00/M | $0.50/M | **75%** | Up to 80% faster |
| gpt-5-nano | $0.05/M | $0.005/M | **90%** | Up to 80% faster |
| gpt-5.2 | $1.75/M | $0.175/M | **90%** | Up to 80% faster |
| gpt-realtime (audio) | $32.00/M | $0.40/M | **98.75%** | Near-instant |

*Sources:* [^2549^][^2558^]

OpenAI's caching activates **automatically** for prompts ≥ 1024 tokens, with cache hits in 128-token increments. No code changes required. Key implementation details:
- Uses hash of first ~256 tokens for **cache routing** to appropriate machines
- Optional `prompt_cache_key` parameter improves routing for shared prefixes [^2558^]
- Default retention: **5-10 minutes** in memory; extended retention up to **24 hours** for specific models [^2504^]
- Real-world result: **Warp achieved 87% cache hit rate**, dropping cost per request from $0.25 to $0.02 [^2548^]

### Anthropic Prompt Caching

| Model | Standard Input | 5-min Cache Write | 1-hr Cache Write | Cache Hit | Discount |
|---|---|---|---|---|---|
| Claude Opus 4.6 | $5.00/M | $6.25 (1.25x) | $10.00 (2.0x) | $0.50/M | **90%** |
| Claude Sonnet 4.6 | $3.00/M | $3.75 | $6.00 | $0.30/M | **90%** |
| Claude Haiku 4.5 | $1.00/M | $1.25 | $2.00 | $0.10/M | **90%** |

*Sources:* [^2459^][^2460^]

Anthropic requires **explicit configuration** via `cache_control: { type: "ephemeral" }` in content blocks. Break-even analysis:
- **5-minute cache**: Break even after **2 cache reads**
- **1-hour cache**: Break even after **8 cache reads** [^2460^]

---

## 6. Multi-Agent Prefix Hit Rates in Production

### The Surprising Reality

Production traces from a major agent-serving platform reveal a starkly different picture from optimistic assumptions:

> "More than **40% of requests have zero or very limited cache hit rates**. This occurs because specialized agents rely on distinct system prompts, preventing prefix sharing across agent boundaries." [^2484^]

Key findings from production workload analysis:
- Specialized agents use **distinct prompts** — no cross-agent prefix sharing
- Sequential execution with **long-running tool calls** (tens of seconds) causes cache eviction before re-invocation
- **Intervening traffic** flushes previously cached prefixes [^2484^]

### Multi-Agent Caching Techniques

| Technique | Approach | Reuse Rate | Speedup |
|---|---|---|---|
| **KVCOMM** (NeurIPS'25) | Anchor-based offset alignment across agents | **70%+** | **7.8x** TTFT reduction |
| **PrefillShare** | Shared prefill module + specialized decoders | Near-100% for shared prefix | **4.5x** lower p95 latency |
| **KVFlow** | Workflow-aware eviction + prefetching | Context-dependent | **1.83-2.19x** |
| **UniCache** | Unified eviction for heterogeneous workloads | **+3.86-17.32%** hit rate improvement | **1.10-3.63x** QTTFT reduction |

*Sources:* [^2552^][^2557^][^2419^][^2422^][^2488^]

### KVCOMM Details

KVCOMM addresses the **offset variance problem**: identical text segments produce diverging KV cache values when prefixed by different agent-specific contexts. It maintains an **online anchor pool** of cached examples that stores observed cache deviations under varying prefixes, enabling dynamic adaptation [^2557^].

For a five-agent fully-connected setting with 1K input tokens per agent (512 prefix + 512 output):
- Standard prefill TTFT: ~430ms
- With KVCOMM: ~55ms
- **Speedup: 7.8x** [^2552^]

---

## 7. Apple Silicon Unified Memory Advantages

### Architecture Benefits

Apple Silicon's **Unified Memory Architecture (UMA)** shares a single physical memory pool between CPU, GPU, and Neural Engine. Unlike discrete GPU systems requiring explicit PCIe transfers, UMA enables **zero-copy tensor access** from any processor [^270^].

Key specifications:
- M4 Pro: up to **64GB** unified memory, **273 GB/s** bandwidth
- M4 Max: up to **128GB** unified memory, **546 GB/s** bandwidth — comparable to high-end datacenter GPUs [^270^]

### KV Cache Implications

On Apple Silicon, KV cache does not need transfer between devices. Model weights and KV cache compete for the same memory pool, making **KV cache the dominant memory consumer at long context** [^2510^][^2507^].

Empirical findings from M4 Pro 64GB [^2463^]:

| KV Mode | Cache Growth (4K tokens) | MB per 1K tokens | TPS (Phi-3.5-mini) |
|---|---|---|---|
| None (FP16) | 1.60 GB | 404 | 71.4 |
| kv8 | 0.91 GB | 226 | 67.9 (-4.9%) |
| kv4 | 0.51 GB | 127 | 72.2 (+1.1%) |

**Key insight: kv4 quantization should arguably be the default** for Apple Silicon inference — it provides **3.2x more context capacity** at zero or negative performance cost [^2463^].

### Persistent Q4 KV Cache for Edge

A recent system for multi-agent edge inference proposes **per-agent persistent Q4 KV cache** with disk-backed safetensors [^2462^]:
- Enables **warm-start TTFT** after server restarts
- Memory scales as O(L_shared + N × L_unique) vs O(N × (L_shared + L_unique)) for baseline
- Interleaved scheduler for chunked prefill + batched decode within MLX's single-thread constraint
- Q4 cache stores ~2.9GB for full agent context vs ~128KB/token for FP16 — enabling practical multi-agent serving on 64GB devices [^2462^]

---

## 8. Prefix Caching in MLX

### Current State

MLX (Apple's native ML framework) provides KV cache management through `mlx-lm`, but prefix caching has significant gaps:

**What works:**
- Pure full-attention models (e.g., MiniMax M2.5) show clear prefix reuse: **29.33s → 2.79s (10.5x speedup)** on warm requests [^2461^]
- mlx_vlm.server has `prompt_cache_state` infrastructure partially present [^2457^]

**What's broken:**
- **Hybrid models** (sliding window + full attention, Mamba/SSM layers) silently fall back to full prompt recomputation on every request [^2461^]
- `mlx_vlm.server` calls `mx.clear_cache()` after every generation request, **wiping all KV state** and forcing full re-prefill on every turn [^2457^]
- No per-layer cache type introspection — uniform `KVCache()` allocation fails for non-standard architectures [^2461^]

### Benchmark Comparison

| System | Prefix Cache | KV Quantization | Disk Persistence | Multi-modal | Platform |
|---|---|---|---|---|---|
| llama.cpp | Manual slot save/restore | Q4_0 | Manual | No | Cross-platform |
| vllm-mlx | In-memory (SHA-256) | FP16 only | No | Limited | Apple Silicon |
| agent-memory (MLX) | Character-level text matching | Q4 | Safetensors | Yes | Apple Silicon |
| mlx-lm | Partial (pure attention only) | kv4/kv8 | No | Partial | Apple Silicon |

*Source:* [^2462^]

### Content-Based Prefix Matching

The agent-memory system for edge devices matches prefixes by comparing **raw prompt text at the character level** rather than token IDs, addressing BPE tokenization's context-dependency problem [^2462^]. Categories:
- **EXACT**: identical prompts
- **EXTEND**: new prompt starts with cached text
- **DIVERGE**: insufficient overlap (<50% threshold)

---

## 9. Multi-Modal Prefix Caching (Vision Embeddings)

### The Problem

Vision-language models (VLMs) such as Qwen3-VL and Gemma 3 must process images through a vision encoder on every request, even when the same image appears across multiple conversation turns. This adds **1.5-2 seconds of redundant latency per request** [^270^].

### LMCache for Multimodal (vLLM)

LMCache extends vLLM's multimodal stack by hashing image-side tokens using `mm_hashes` [^2485^]:

| Query | Total Tokens | KV Hits | Hit Rate |
|---|---|---|---|
| First image | 16,178 | 0 | 0% |
| Same image (2nd) | 16,178 | 16,177 | ~100% |
| New image (3rd) | 4,669 | 0 | 0% |

The second request streams in **~1s** vs **~18s** cold-start [^2485^]. Key technical changes:
- `apply_mm_hashes_to_token_ids()` replaces dummy vision-token IDs with a 16-bit hash
- `RequestTracker` stores `mm_hashes` + positions for complete true hash lookup
- Identical images map to identical token sequences, enabling KV reuse in both storage and P2P transport modes [^2485^]

### Native MLX Multimodal Caching

A native MLX framework for Apple Silicon achieves **up to 28x speedup** on repeated image queries, cutting latency from **21.7 seconds to under 1 second** [^270^]. For video analysis: **24.7x speedup**. Implementation:
- **Content hashing** (SHA-256) detects identical images
- Caches both **vision embeddings** and **KV cache states**
- Exploits unified memory for **zero-copy cache management**
- OpenAI-compatible API with continuous batching (4.3x scaling at 16 concurrent requests) [^270^]

---

## 10. Practical Integration Patterns

### Pattern 1: Static-First Prompt Structure

```
# MAXIMIZE CACHE HITS
messages = [
    {"role": "system", "content": STATIC_SYSTEM_PROMPT},  # Cached
    {"role": "user", "content": STATIC_FEW_SHOT_EXAMPLES},  # Cached
    {"role": "user", "content": dynamic_user_input},  # NOT cached
]
```

Place all static content (system prompts, tool definitions, few-shot examples, retrieved documents) **before** dynamic user input. Even a single character difference in the prefix invalidates the entire cache tree downstream [^2501^][^2551^].

### Pattern 2: vLLM + LMCache Tiered Caching

```bash
# Single-node with offloading
vllm serve meta-llama/Llama-3.1-8B \
  --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}'
```

LMCache extends vLLM with:
- **GPU → CPU RAM → disk → network** tiered offloading
- **Cross-engine sharing** across vLLM and SGLang instances
- **Up to 15x throughput improvement** in multi-round QA and document analysis [^2480^]
- **3-10x TTFT speed-ups** on text workloads; comparable gains now available for multimodal [^2489^]

### Pattern 3: Disaggregated Serving with Shared Prefill

```
Prefill Cluster (4 GPUs)          Decode Cluster (4 GPUs)
├─ Shared Prefill Worker          ├─ Decode A (math agent)
│  └─ Computes KV cache once      ├─ Decode B (code agent)
│                                 ├─ Decode C (tool agent)
│     Cache Handoff ──────────────┼─ Decode D (summary agent)
```

PrefillShare's architecture separates prefill and decode across GPUs while sharing the prefill KV cache across all task-specific decoders. This eliminates **both** redundant prefill compute and duplicated KV storage [^2419^].

### Pattern 4: Session Affinity for Multi-Turn

```nginx
upstream sglang_backend {
    ip_hash;  # or better: hash $conversation_id consistent;
    server sglang-1:30000;
    server sglang-2:30000;
}
```

Without session affinity, the same conversation lands on different instances each turn, and each instance starts with a **cold cache** [^2502^]. Use conversation-ID-based routing for production agent deployments.

---

## 11. Comparison Matrix

| System | Cache Structure | Granularity | Multi-Model | Multi-Modal | Workflow-Aware | Cross-Instance | Quantized KV |
|---|---|---|---|---|---|---|---|
| vLLM APC | Hash-based blocks | Block (16 tokens) | No | Yes (V1) | No | Via LMCache | No (FP16) |
| SGLang RadixAttention | Radix tree | Variable prefix | No | Limited | Via cache-aware scheduling | No | No |
| PrefillShare | Shared prefill + per-model decode | Full model | **Yes** | No | No | No | No |
| KVFlow | Workflow-aware tree | Node-level | No | No | **Yes** | No | No |
| KVCOMM | Anchor pool alignment | Token-level | **Yes** | No | No | No | No |
| LMCache | Tiered (GPU/CPU/disk/network) | Block/chunk | No | **Yes** | No | **Yes** | Via compression |
| MLX native | In-memory prefix | Token sequence | No | **Yes** | No | No | kv4/kv8 |
| UniCache | Unified eviction | Block-level | No | No | Task-aware | No | No |

---

## 12. Key Takeaways

1. **Prefix caching is "almost a free lunch"** — it changes no model outputs while delivering 50-90% cost and latency reductions [^278^].

2. **Cache hit rate is the critical variable** — production multi-agent workloads often see <40% hit rates due to distinct agent prompts and long tool-call gaps, while well-structured chat/RAG workloads achieve 75-95% [^2484^][^2502^].

3. **Prompt structure matters more than engine choice** — placing static content first and keeping it byte-identical across requests is the single highest-leverage optimization [^2501^][^2551^].

4. **Cross-model sharing is the next frontier** — PrefillShare and KVCOMM demonstrate that shared prefixes across heterogeneous models can deliver 4-8x speedups, but require training or system-level coordination [^2419^][^2557^].

5. **Apple Silicon is viable for long-context serving** — unified memory + kv4 quantization enables 3.2x more context capacity at zero performance cost, with persistent Q4 caches enabling practical multi-agent edge deployment [^2463^][^2462^].

6. **Vision caching is now practical** — LMCache and MLX-native implementations achieve ~100% hit rates for repeated images, cutting multimodal latency from ~20s to ~1s [^2485^][^270^].

---

## References

[^1130^]: SGLang Documentation. "RadixAttention." https://sgl-project-sglang-93.mintlify.app/concepts/radix-attention

[^1132^]: Inference.net. "SGLang: The Complete Guide to High-Performance LLM Inference." 2026-01-26.

[^1134^]: LearnOpenCV. "Serving SGLang: Launch a Production-Style Server." 2026-01-13.

[^1177^]: Introl Blog. "Prompt Caching Infrastructure | LLM Cost & Latency Reduction Guide." 2026-03-17.

[^1186^]: Sankalp. "How prompt caching works - Paged Attention and Automatic Prefix Caching." 2025-11-30.

[^2393^]: Medium. "Part 1: Shared Prefix, KV Cache, and RadixAttention." 2025-12-13.

[^2394^]: arXiv. "PrefillShare: A Shared Prefill Module for KV Reuse in Multi-LLM Disaggregated Serving." 2602.12029, 2026-02-12.

[^2419^]: arXiv. "PrefillShare: A Shared Prefill Module for KV Reuse in Multi-LLM Disaggregated Serving." Abstract and experiments.

[^2421^]: Alibaba Cloud Blog. "Caching is Efficiency: Achieving Precise LLM Cache Hits with Alibaba Cloud ACK GIE." 2026-02-26.

[^2422^]: OpenReview. "KVFlow: Efficient Prefix Caching for Accelerating LLM-based Agentic Workflows."

[^2457^]: GitHub Issue. "Server clears Metal cache after every request, destroying KV prefix cache." mlx-vlm, 2026-04-08.

[^2458^]: MindStudio Blog. "What Is Anthropic's Prompt Caching." 2026-04-05.

[^2459^]: Finout Blog. "Anthropic API Pricing in 2026: Complete Guide." 2026-03-24.

[^2460^]: MetaCTO Blog. "Claude API Pricing 2026: Full Anthropic Cost Breakdown." 2026-03-23.

[^2461^]: GitHub Issue. "Prefix cache reuse is broken for all hybrid-architecture models." mlx-lm, 2026-03-10.

[^2462^]: arXiv. "Persistent Q4 KV Cache for Multi-Agent LLM Inference on Edge Devices." 2603.04428, 2026-02-17.

[^2463^]: GitHub Discussion. "UMA-Native KV-Cache Benchmarks on M4 Pro 64GB." mlx-explore/mlx, 2026-02-16.

[^2476^]: NetApp Community Blog. "Engineering Inference: KV Cache, Shared Storage, and the Economics of AI." 2026-03-13.

[^2477^]: vLLM Forums. "How do I precompute multimodal embeddings?" 2026-02-01.

[^2478^]: GMI Cloud Blog. "Achieving 4x LLM Performance Boost with KVCache." 2025-12-30.

[^2480^]: arXiv. "LMCache: An Efficient KV Cache Layer for Enterprise-Scale LLM Inference." 2510.09665, 2025-12-05.

[^2482^]: LMCache Docs. "KV Caching for Multimodal Models with vLLM." 2025-08-04.

[^2483^]: Redis Blog. "Get faster LLM inference and cheaper responses with LMCache and Redis." 2025-07-28.

[^2484^]: arXiv. "Pythia: Exploiting Workflow Predictability for Efficient Agent-Native LLM Serving." 2604.25899, 2026-04-28.

[^2485^]: LMCache Blog. "LMCache Extends Its Turbo-Boost to Multimodal Models in vLLM V1." 2025-07-03.

[^2488^]: arXiv. "UniCache: Unifying Prefix Cache Eviction for Heterogeneous LLM Serving Workloads." SIGMETRICS 2026.

[^2490^]: Red Hat Developer. "vLLM V1: Accelerating multimodal inference for large language models." 2025-02-27.

[^2491^]: OpenLM AI. "vLLM V1." 2025-01-27.

[^2501^]: RunPod Blog. "SGLang in Production: A Developer's Guide." 2026-04-17.

[^2502^]: Spheron Blog. "SGLang Production Deployment Guide." 2026-03-31.

[^2503^]: Particula Tech Blog. "SGLang vs vLLM in 2026." 2026-03-25.

[^2504^]: Towards Data Science. "Prompt Caching with the OpenAI API." 2026-03-22.

[^2505^]: Premai Blog. "vLLM vs SGLang vs LMDeploy: Fastest LLM Inference Engine in 2026?" 2026-02-28.

[^2506^]: Alibaba Cloud Blog. "Caching is Efficiency." 2026-02-26.

[^2507^]: Medium. "TurboQuant on Apple MacOS: Five Integration Paths." 2026-04-03.

[^2508^]: Local AI Master. "SGLang vs vLLM: Complete Comparison 2026." 2026-02-04.

[^2509^]: JarvisLabs Blog. "vLLM Optimization Techniques." 2026-02-06.

[^2510^]: Vijay.eu. "KV Cache, Flash Attention, and Optimizing for Apple Silicon." 2026-02-14.

[^2546^]: The AI Engineer. "vLLM vs Ollama vs SGLang vs TensorRT-LLM." 2026-04-10.

[^2547^]: Introl Blog. "Prompt Caching Infrastructure." 2026-03-17.

[^2548^]: GrowwStacks. "Master Next-Gen AI Development: Prompt Caching." 2026-02-22.

[^2549^]: OpenAI Cookbook. "Prompt Caching 201." 2026-02-18.

[^2551^]: DigitalOcean. "Prompt Caching Explained." 2025-12-25.

[^2552^]: NeurIPS 2025. "KVCOMM: Online Cross-context KV-cache Communication." Poster 115164.

[^2557^]: arXiv. "KVCOMM: Online Cross-context KV-cache Communication." 2510.12872, 2025-10-14.

[^2558^]: OpenAI API Docs. "Prompt caching."

[^2569^]: Introl Blog. "KV Cache Optimization: Memory Efficiency for Production LLMs." 2026-03-13.

[^2570^]: vLLM Docs. "Automatic Prefix Caching - vLLM V1."

[^2571^]: UC Berkeley. "PagedAttention & vLLM for Efficient LLM Inference." LLMSystem Course.

[^270^]: arXiv. "Native LLM and MLLM Inference at Scale on Apple Silicon." 2601.19139, 2026-01-29.

[^278^]: vLLM Docs. "Automatic Prefix Caching." https://docs.vllm.ai/en/stable/design/prefix_caching/
