# Advanced Apple Silicon Optimization Techniques for LLM Inference

## Research Summary

This document compiles findings from 15+ web searches on advanced Apple Silicon optimization techniques for LLM inference, focusing on MLX (Apple's Machine Learning eXperimentation framework), Metal Performance Shaders, memory management, and ANE/GPU/CPU dispatch strategies. All findings include inline citations.

---

## 1. MLX Lazy Evaluation and Operation Fusion

### Core Concept

MLX uses **lazy evaluation**: operations build a computation graph that is only executed when `mx.eval()` is called or results are needed [^379^]. This is fundamentally different from PyTorch's eager execution model.

```python
import mlx.core as mx

x = mx.array([1.0, 2.0, 3.0])
y = x + 1    # NOT computed yet — just builds the graph
mx.eval(y)   # NOW it runs on Metal
```

### Key Benefits for LLM Inference

1. **Operation Fusion**: The MLX runtime can fuse consecutive operations into single Metal kernels, reducing kernel launch overhead and intermediate memory allocations [^2647^].

2. **Graph-Level Optimizations**: Before execution, MLX optimizes the entire computation graph, eliminating redundant operations and reordering for better memory access patterns [^2653^].

3. **Reduced Memory Allocations**: Lazy evaluation enables the framework to optimize memory allocation across the full graph rather than per-operation [^379^].

4. **Temporal Unrolling**: For autoregressive generation, the temporal unrolling loop can build the full computation graph for T timesteps before executing, allowing the MLX runtime to optimize memory allocation and kernel scheduling [^379^].

### mx.compile for JIT Kernel Fusion

MLX provides `mx.compile()` (also `@mlx.compile`) to JIT-compile pure functions for additional performance [^379^][^2653^]:

```python
import mlx.core as mx

# Automatic differentiation with compilation
gradient_fn = mx.grad(sin_function)
compiled_gradient = mx.compile(gradient_fn)
```

The `mx.compile` transform enables:
- **Kernel fusion**: Multiple small ops merged into single GPU kernels
- **Memory reuse**: Immutable arrays enable aggressive buffer recycling
- **Static scheduling**: Pre-planned command buffer encoding [^723^]

### PMetal's Fused Kernel Ecosystem

The PMetal framework (Rust-based) demonstrates the state-of-the-art in Metal kernel fusion for LLMs [^268^][^269^]:

| Kernel | Speedup | Description |
|--------|---------|-------------|
| `flash_attention` | 1.5-2x | O(n) memory attention with fused softmax |
| `fused_lora` | ~2x | Combined base+adapter forward pass |
| `fused_cross_entropy` | 1.3x | Chunked loss computation, avoids logits materialization |
| `fused_rope` | 1.2x | In-kernel position encoding |
| `fused_sampler` | 1.4x | JIT-compiled token sampling |
| `fused_swiglu` | - | MLP activation fusion |

PMetal also implements an **Async Scheduler** with double/triple-buffered GPU command scheduling to hide CPU encoding latency [^268^].

### Open-TQ-Metal: Fused Compressed-Domain Attention

Open-TQ-Metal implements a **fused int4 SDPA kernel** for Metal that reads packed int4 keys and values directly from device memory, dequantizes per-element in GPU registers via bitwise operations, and computes attention with online softmax — producing zero intermediate matrices [^2649^][^2692^].

**Performance**: At 128K context, this kernel is **48x faster** than the dequantize-then-attend baseline [^2692^].

**Memory Impact**: Reduces KV cache from 40 GB (FP16) to 12.5 GB (int4), enabling Llama 3.1 70B at 128K context on a 64GB Mac [^2692^].

---

## 2. Metal Performance Shaders Optimization

### Unified Memory Architecture

Apple Silicon's unified memory means CPU and GPU share the same physical memory. Unlike PyTorch MPS which requires explicit `tensor.to(device)` copies, MLX tensors are accessible to both CPU and GPU without transfers [^379^][^2653^].

```python
# Traditional approach: data location determines compute location
# MLX approach: specify device per operation
c = mx.add(a, b, stream=mx.gpu)   # GPU computation
d = mx.multiply(a, b, stream=mx.cpu)  # CPU computation
```

### Metal Shader Compilation Caching

The first inference run on a new model triggers Metal shader compilation, adding several seconds of latency. Subsequent runs benefit from macOS's persistent shader cache [^2387^].

**Pre-warming strategy**: Run a short prompt after model load to populate the cache. The penalty is per-model and persists across reboots unless the system's shader cache is cleared [^2387^].

**Binary Archives**: Metal supports binary archives as precompiled static libraries for specific GPU architectures. Metal automatically builds and caches shaders on the device running an app [^2657^].

### Tier-Aware Kernel Tuning

PMetal auto-detects Apple Silicon capabilities and tunes kernel parameters per chip tier [^268^]:

| Chip Family | GPU Family | ANE Cores | Status |
|-------------|-----------|-----------|--------|
| M1 / Pro / Max / Ultra | Apple7 | 16 | Fully supported |
| M2 / Pro / Max / Ultra | Apple8 | 16 | Fully supported |
| M3 / Pro / Max / Ultra | Apple9 | 16 | Fully supported |
| M4 / Pro / Max / Ultra | Apple9 | 16 | Fully supported |
| M5 / Pro / Max / Ultra | Apple10 | 16 | Fully supported |

**Auto-detected features**: GPU family, device tier, core counts, memory bandwidth, dynamic caching, mesh shaders, NAX (M5+), UltraFusion topology [^268^].

**Tier-based tuning**: Matrix tile sizes, FlashAttention block sizes, fused kernel threadgroup sizes, and batch multipliers are selected based on device tier (Base/Pro/Max/Ultra) [^268^].

### Command Buffer Batching and Scheduling

**Multithreaded Command Buffer Encoding**: For complex inference workloads, encode command buffers on multiple CPU threads to reduce CPU bottleneck [^2370^]:

```
# Before: Serial encoding = 25ms CPU time per frame
# After: Parallel encoding (shadow pass on thread 1, G-buffer+UI on thread 2) = 15ms
```

**Triple Buffering with Semaphores**: Use `DispatchSemaphore` instead of `waitUntilCompleted()` to keep GPU utilization high and eliminate "Thread blocked waiting for next drawable" stalls [^2650^].

**Double/Triple-Buffered GPU Command Scheduling**: PMetal's Async Scheduler implements this pattern for inference workloads, hiding CPU encoding latency behind GPU execution [^268^].

---

## 3. Memory Pool Management in MLX

### MLX Memory API (Critical for Production)

**Note**: As of recent MLX versions, use `mx.*` directly — `mx.metal.*` is deprecated [^2683^].

```python
import mlx.core as mx

# Memory monitoring
active_bytes = mx.get_active_memory()    # Currently allocated
cache_bytes  = mx.get_cache_memory()     # Cached but not active
peak_bytes   = mx.get_peak_memory()      # Peak since last reset

# Memory control
mx.reset_peak_memory()                   # Reset peak counter
mx.set_memory_limit(limit_bytes)         # Set max memory (0 = unlimited)
mx.set_cache_limit(limit_bytes)          # Set max cache (bytes)
mx.clear_cache()                         # Free cached memory to OS
```

### The Buffer Cache Problem (Production Critical)

The MLX Metal caching allocator retains an **unbounded buffer pool** when cached buffers cannot be reused [^2644^]. This is the #1 issue for long-running inference servers.

**Symptom**: After handling sequential requests at increasing context lengths, `footprint` shows 108 GB allocated when only 34 GB should be in use [^2644^]:

```
Python [53213]: Footprint: 108 GB
  106 GB    IOAccelerator (graphics)    [43,692 regions]
Expected: ~34 GB (3 GB weights + 30.5 GB KV cache at 1M context)
```

**Root Cause**: `max_pool_size_` defaults to `block_limit_` = `min(1.5 * max_rec_size, 0.95 * memsize)`, which is ~192 GB on an M2 Ultra with 128 GB RAM. Freed buffers are always recycled into the pool [^2644^].

**GC Path**: Only triggers when `active_memory_ + cache_size + new_alloc >= gc_limit_`, but `gc_limit_` is capped at `0.95 * max_rec_size` (~107 GB on M2 Ultra) — by then the machine is already swapping [^2644^].

### Recommended Memory Management for Servers

```python
import mlx.core as mx

# 1. Set cache limit at startup (proportional to working set)
mx.set_cache_limit(4 * 1024**3)  # 4 GB cache limit

# 2. Clear cache between requests
def handle_request(...):
    mx.clear_cache()  # pre-request cleanup
    result = generate(...)
    mx.clear_cache()  # post-request cleanup
    return result

# 3. Monitor memory drift
active = mx.get_active_memory() / (1024**3)
peak = mx.get_peak_memory() / (1024**3)
cache = mx.get_cache_memory() / (1024**3)
print(f"Active: {active:.1f} GB, Peak: {peak:.1f} GB, Cache: {cache:.1f} GB")

# 4. Set memory limit with relaxed=True (allows temporary exceeding)
mx.set_memory_limit(40 * 1024**3, relaxed=True)
```

**Production workaround for fragmentation** [^2684^]:
- Call `mx.clear_cache()` before and after each request
- Periodic process recycling (every 24h) to reset Metal allocator state
- Catch OOM errors and retry with reduced token count
- Use `gc.collect()` periodically

### Environment Variable: MLX_METAL_CACHE_LIMIT

```bash
export MLX_METAL_CACHE_LIMIT=4GB
```

This sets `max_pool_size_` but only limits after successful allocation. It does NOT prevent pool growth via the unconditional `recycle_to_cache` path in `free()` [^2644^].

### Memory Sawtooth Pattern in Serving

During sustained serving benchmarks, system memory exhibits a sawtooth pattern: 40GB -> 62GB (gradual climb) -> 40GB (sudden drop) -> repeat [^2646^]. This occurs because:

1. MLX's intermediate buffer cache accumulates without a cap
2. The intended memory fraction (e.g., 50% = ~32GB) is respected for KV cache
3. But total memory grows beyond it due to uncached intermediate allocations

**Sysctl tuning does NOT help** — kernel-level memory flags cannot prevent MLX's userspace allocator from requesting more memory [^2646^]:

```bash
# These do NOT solve the MLX buffer cache issue:
sudo sysctl iogpu.wired_limit_mb=57344
sudo sysctl iogpu.disable_wired_collector=1
sudo sysctl iogpu.dynamic_lwm=0
```

### MLX Memory Leak Detection Pattern

```python
class LeakDetector:
    def __init__(self, tolerance_mb=10):
        self.tolerance = tolerance_mb * 1024**2
        self.baseline = None

    def start(self):
        mx.clear_cache()
        self.baseline = mx.get_active_memory()

    def check(self, label=""):
        mx.clear_cache()
        current = mx.get_active_memory()
        leaked = current - self.baseline
        if leaked > self.tolerance:
            print(f"Potential leak {label}: {leaked / (1024**2):.2f} MB")
```

---

## 4. ANE vs GPU vs CPU Dispatch Strategies

### Apple Neural Engine (ANE) Characteristics

The ANE is present in every Apple Silicon chip since A11 Bionic (2017). With M4 generation, it delivers up to 38 TOPS (INT8) across 16 cores [^373^].

**Key Findings from Research** [^373^][^374^]:

| Characteristic | Value |
|----------------|-------|
| Actual FP16 throughput | ~19 TFLOPS (INT8 dequantizes to FP16 before compute) |
| SRAM capacity | 32 MB (30% throughput drop when exceeded) |
| Dispatch overhead | ~0.095 ms per dispatch |
| Compilation limit | ~119 compilations per process |
| 1x1 conv vs matmul throughput | 3x better for convolutions |
| Deep graph utilization | 94% ANE utilization (16-64 ops) vs ~30% for single ops |

### ANE vs GPU vs CPU: Performance Comparison

**GPT-2 124M on M4 Max** [^373^]:

| Path | Prefill (tok/s) | Decode (tok/s) | Notes |
|------|-----------------|----------------|-------|
| ANE (1st call) | 165 | - | Includes ~1015 ms compilation |
| ANE (cached) | 165 | 170 | Compilation amortized |
| CPU Decode | - | 283 | cblas_sgemm, faster than ANE for decode |
| ANE Decode | - | 170 | ~2.3 ms IOSurface round-trip overhead per dispatch |

### ANE Pros and Cons for LLM Inference

**Advantages** [^373^]:
1. **Zero idle power** — hard power-gated when unused, ideal for always-on inference
2. **Dedicated silicon** — leaves GPU and CPU entirely free for other workloads
3. **Operation-specific speedups** — softmax over large vocabularies is 33.8x faster on ANE than CPU

**Disadvantages**:
1. **Per-dispatch IOSurface overhead** (~2.3 ms) dominates for single-token decode
2. **Amortized during prefill** but hurts decode performance
3. **No public API** — CoreML is the only public interface, operates as black-box scheduler
4. **Weight compilation overhead** — every training step requires recompilation (Orion v2.0 delta compilation reduces this from 4,200 ms to 494 ms, 8.5x improvement) [^373^]

### Hybrid Inference Strategy: ANE Prefill + GPU Decode

The optimal strategy for many workloads is **disaggregated inference** [^2679^]:

- **ANE prefill** for prompt processing (long sequences, overhead amortized)
- **GPU decode** for token generation (higher sustained throughput)
- **CPU fallback** for operations ANE cannot handle (large vocabulary projection, RMSNorm in fp32)

**Yetter Inference Engine** implements this hybrid approach, combining Core ML (ANE) prefill with MLX (GPU) decode [^2679^].

**Results on iPhone 15 Pro** [^2679^]:
- Core ML (ANE) substantially improves TTFT in prefill-heavy scenarios
- MLX (GPU) consistently outperforms in TPOT across both scenarios
- Yetter achieves lower prefill latency than MLX, nearly identical decode latency

### ane.cpp: Direct ANE Inference

ane.cpp achieves direct ANE inference without CoreML [^2678^]:

| Model | Mode | Prompt tok/s | Generate tok/s |
|-------|------|--------------|----------------|
| Qwen3.5-4B | fp16 | 18.93 | 9.21 |
| Qwen3.5-4B | int8 | 30.08 | 11.66 |
| Qwen3.5-9B | fp16 | 6.49 | 4.27 |
| Qwen3.5-9B | int8 | 7.39 | 7.01 |

### Dispatch Strategy Recommendations

| Scenario | Recommended Dispatch |
|----------|---------------------|
| Single-user, max throughput | MLX on GPU |
| Multi-user serving | MLX on GPU + continuous batching |
| Always-on background inference | ANE (zero idle power) |
| Prefill-heavy workloads | ANE prefill + GPU decode hybrid |
| Battery-powered device | ANE for power efficiency |
| Max model size (70B+) | GPU (ANE has 32MB SRAM cliff) |

---

## 5. Metal Command Buffer Batching

### MLX Streams and Concurrent Execution

MLX dispatches GPU work through Metal command queues. By default, every op shares a single command queue (the default worker thread) [^2694^].

**Stream-per-process pattern** for concurrent inference (Emily/Elixir NIFs) [^2694^]:

```elixir
# Create a stream per process
stream = Emily.Stream.new(:gpu)
Emily.Stream.with_stream(stream, fn ->
  Nx.Serving.batched_run(my_serving, input)
end)
```

Each stream allocates a dedicated OS thread that owns the MLX stream object. Tensors allocated by one stream can be read by another (MLX arrays are refcounted and thread-safe for reads), but lazy tensors must be evaluated on the stream that created them [^2694^].

### Command Buffer Encoding Optimization

**Parallel Render Command Encoder**: When splitting a single pass across multiple threads, use `MPSThreadGroup` or Metal's parallel render command encoder. The order of subordinate encoder creation determines GPU submission order [^2370^].

**Enqueue vs Commit**: Use `commandBuffer.enqueue()` to reserve queue order, then `commit()` when encoding is complete. This allows out-of-order encoding with ordered execution [^2370^].

### Kernel Launch Overhead

**Cold launch** (first kernel invocation) vs **follow-up launch** latency [^2701^]:

| Device | Cold Launch (ms) | Follow-up Launch (ms) |
|--------|------------------|----------------------|
| M2 Ultra | 0.786 | 0.148 |
| M2 Max | 0.980 | 0.127 |
| M2 Pro | 0.583 | 0.284 |
| RTX A6000 | 0.023 | 0.006 |
| RTX 4090 | 0.023 | 0.006 |

Apple Silicon has **significantly higher kernel launch latency** than CUDA devices. This makes kernel fusion even more critical — each unfused op adds ~0.1-0.3 ms of launch overhead [^2701^].

---

## 6. Shader Compilation Caching

### macOS Persistent Shader Cache

Metal automatically builds and caches shaders on the device. The cache persists across reboots unless cleared by the system [^2387^].

**First-run penalty**: Expect 2-10 seconds of shader compilation on first model load. This is one-time per model [^2387^].

**No manual pre-warming required** — simply running a short prompt after model load populates the cache [^2387^].

### Pipeline State Object (PSO) Caching

For custom Metal kernels (e.g., PMetal, Open-TQ-Metal), pipeline state objects should be created once and reused:

```objc
// Create PSO once at initialization
id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:function error:&error];

// Reuse for all subsequent dispatches
[computeEncoder setComputePipelineState:pipeline];
```

### Binary Archives for Distribution

Binary archives are precompiled static libraries for specific GPU architectures that allow avoiding runtime shader compilation cost [^2657^]:

- Use binary archives as part of distributed apps
- Deliver through content updates
- Create from device-built pipeline state objects

---

## 7. mx.set_cache_limit and Memory Management APIs

### Complete Memory API Reference

```python
import mlx.core as mx

# --- Query Functions ---
mx.get_active_memory()      # Currently allocated GPU memory in bytes
mx.get_peak_memory()        # Peak GPU memory since last reset
mx.get_cache_memory()       # Cached (freed but not returned to OS) memory
mx.reset_peak_memory()      # Reset peak counter

# --- Control Functions ---
mx.set_memory_limit(limit, relaxed=True)   # Max GPU memory MLX can use
mx.set_cache_limit(limit)                   # Max cache size in bytes
mx.clear_cache()                            # Return cached memory to OS

# --- Metal-specific (deprecated, use mx.* directly) ---
# mx.metal.get_active_memory() -> use mx.get_active_memory()
# mx.metal.set_cache_limit()   -> use mx.set_cache_limit()
```

### Memory Limit Best Practices

```python
import mlx.core as mx
import mlx.core.metal as metal

if metal.is_available():
    info = metal.device_info()
    total_memory = info['memory']

    # Use at most 80% of available memory
    limit = int(total_memory * 0.8)
    mx.set_memory_limit(limit, relaxed=True)
    print(f"Memory limit set to {limit / (1024**3):.2f} GB")
```

**Relaxed mode**: `relaxed=True` allows temporary exceeding of the limit (default). Use `relaxed=False` for hard caps [^2655^].

### Server Memory Configuration Template

```python
import mlx.core as mx

def configure_mlx_for_server(total_gb, reserved_gb=8, cache_gb=4):
    """Configure MLX memory for long-running inference servers."""
    total_bytes = total_gb * 1024**3
    reserved_bytes = reserved_gb * 1024**3
    cache_bytes = cache_gb * 1024**3

    # Leave headroom for OS and other apps
    mx.set_memory_limit(total_bytes - reserved_bytes, relaxed=True)

    # Cap the buffer cache to prevent unbounded growth
    mx.set_cache_limit(cache_bytes)

    print(f"MLX configured: limit={(total_bytes - reserved_bytes) / 1e9:.1f}GB, "
          f"cache={cache_bytes / 1e9:.1f}GB")

# Example: 128GB Mac, reserve 16GB for system, 4GB cache
configure_mlx_for_server(128, reserved_gb=16, cache_gb=4)
```

### Memory-Efficient Training Pattern

```python
class MemoryEfficientTrainer:
    def __init__(self, model, memory_limit_gb=None):
        self.model = model
        if memory_limit_gb:
            mx.set_memory_limit(memory_limit_gb * 1024**3, relaxed=True)
        mx.set_cache_limit(4 * 1024**3)

    def train_epoch(self, data_loader):
        mx.reset_peak_memory()
        for i, batch in enumerate(data_loader):
            loss, grads = self.loss_fn(self.model, batch)
            self.optimizer.update(self.model, grads)

            # Periodic memory cleanup
            if i % 100 == 0:
                mx.clear_cache()

            if i % 50 == 0:
                active = mx.get_active_memory() / (1024**2)
                peak = mx.get_peak_memory() / (1024**2)
                print(f"Batch {i}: Active={active:.0f}MB, Peak={peak:.0f}MB")
```

---

## 8. Continuous Batching on Apple Silicon (vllm-mlx)

### What is vllm-mlx?

vllm-mlx is a vLLM-style inference server for Apple Silicon built natively on MLX [^267^][^85^]. It provides:

- **Continuous batching**: Multiple sequences processed simultaneously
- **Paged KV cache**: Memory-efficient attention state management
- **Prefix caching**: Eliminates redundant computation for shared prefixes
- **OpenAI-compatible API**: Drop-in replacement for OpenAI endpoints
- **Multimodal support**: Text, images, video, audio, embeddings

### Performance: vllm-mlx vs llama.cpp

**M4 Max (128GB) benchmarks** [^377^][^270^]:

| Model | vllm-mlx (tok/s) | llama.cpp (tok/s) | Speedup |
|-------|------------------|-------------------|---------|
| Qwen3-0.6B | 525 | 281 | **+87%** |
| Llama-3.2-1B | 462 | 331 | **+39%** |
| Qwen3-4B | 159 | 118 | **+35%** |
| Qwen3-8B | 93 | 77 | **+21%** |
| Nemotron-30B | ~14 | ~14 | Tied |

**Why MLX outperforms llama.cpp** [^377^]:
1. MLX's native unified memory design enables zero-copy tensor operations
2. MLX's lazy evaluation allows operation fusion and reduces kernel launch overhead
3. Continuous batching scheduler maximizes GPU utilization

### Continuous Batching Scaling

**Concurrency scaling on vllm-mlx** [^377^][^85^]:

| Concurrent Requests | Qwen3-0.6B (tok/s) | Scaling Factor |
|--------------------|--------------------|----------------|
| 1 | 441 | 1.0x |
| 4 | ~1,200 | ~2.7x |
| 16 | 1,642 | **3.7x** |

For Qwen3-0.6B, throughput scales from 441 tok/s (single) to 1,642 tok/s (16 concurrent), a **3.7x improvement** [^377^].

**Aggregate throughput at 16 concurrent requests: 4.3x** [^85^][^2656^].

Larger models show diminishing returns due to memory bandwidth saturation: Qwen3-8B achieves 2.6x scaling [^377^].

### Server Startup

```bash
pip install vllm-mlx
vllm-mlx serve mlx-community/Llama-3.2-3B-Instruct-4bit \
  --port 8000 \
  --continuous-batching
```

**OpenAI SDK usage**:
```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8000/v1", api_key="not-needed")
r = client.chat.completions.create(
    model="default",
    messages=[{"role": "user", "content": "Hi!"}]
)
```

### higgs Server (Rust-based MLX Server)

higgs is a Rust-based MLX server achieving even higher throughput [^2681^]:

| Model | higgs | mlx_lm | vllm-mlx | llama.cpp | Ollama |
|-------|-------|--------|----------|-----------|--------|
| Llama-3.2-1B-4bit | **448** | 421 | 433 | 314 | 305 |
| Mistral-7B-4bit | **103** | 103 | - | 87 | 85 |
| Qwen3-1.7B-4bit | **305** | 293 | 300 | 216 | 183 |

**Continuous batching (Llama-1B)** [^2681^]:

| Concurrent | higgs tok/s | vllm-mlx tok/s |
|-----------|-------------|----------------|
| 1 | 280 | 250 |
| 2 | 585 | 459 |
| 4 | 698 | 510 |
| 8 | **755** | 646 |

### Prefix Caching for Multimodal

vllm-mlx introduces **content-based prefix caching** for vision embeddings [^377^]:

- Identifies identical images through content hashing
- Eliminates redundant vision encoding
- **28x speedup** on repeated image queries
- **24.7x speedup** on video analysis (up to 64 frames)
- Reduces multimodal latency from 21.7 seconds to under 1 second [^377^]

---

## 9. Benchmark Comparisons: MLX vs llama.cpp vs Core ML

### Comprehensive Framework Comparison

**M2 Ultra (192GB) - Qwen-2.5 family** [^2654^]:

| Framework | Throughput (tok/s) | P50 Latency | P99 Latency | TTFT (moderate) |
|-----------|-------------------|-------------|-------------|-----------------|
| **MLX** | **~230** | ~5-7ms | ~12ms | Linear growth |
| MLC-LLM | ~190 | ~8ms | ~13ms | Faster than MLX |
| llama.cpp | ~150 (short only) | - | - | - |
| Ollama | 20-40 | - | - | >50s at 100K |
| PyTorch MPS | 7-9 | - | - | Fails at 3B+ |

**NVIDIA A100+vLLM**: ~5-10x higher absolute throughput (external ceiling) [^2654^].

### M4 Max (128GB) - Qwen3.5 35B Benchmark

**Antekapetanovic benchmark** [^2651^]:

| Engine | Gen tok/s (native) | Gen tok/s (client) |
|--------|--------------------|--------------------|
| mlx-py | 130.2 | 114.9 |
| mlx-http | N/A | 107.6 |
| llama.cpp | 72.4 | 70.4 |
| Ollama | 48.1 | 46.3 |

**Key findings** [^2651^]:
- MLX is **2-3x faster** than Ollama
- MLX is **~1.5x faster** than llama.cpp
- HTTP overhead is ~20% (TCP, SSE, JSON parsing)
- Thinking mode doesn't affect per-token speed

### Ollama 0.19 MLX Backend vs llama.cpp Backend

**Qwen3.5-35B-A3B on M4 Max 64GB** [^2696^]:

| Metric | llama.cpp (0.18) | MLX (0.19) | Improvement |
|--------|------------------|------------|---------------|
| Prefill | 1,147 tok/s | 1,804 tok/s | **+57%** |
| Decode | 57.8 tok/s | 111.4 tok/s | **+93%** |
| Total duration | 4.2s | 2.3s | **-45%** |

To enable: `export OLLAMA_MLX=1` (requires 32GB+ unified memory) [^2696^].

### Core ML vs MLX

**Prefill-heavy vs Decode-heavy scenarios** [^2679^]:

- **Core ML (ANE)**: Substantially improves TTFT in prefill-heavy scenarios
- **MLX (GPU)**: Consistently outperforms in TPOT across both scenarios
- **Yetter (Hybrid)**: Lower prefill latency than MLX, nearly identical decode latency

### Hardware Tier Performance Expectations

**Community-reported tok/s by chip** [^2387^]:

| Chip | Max Memory | GPU Cores | ~tok/s (7B Q4) | ~tok/s (13B Q4) |
|------|-----------|-----------|----------------|-----------------|
| M1 Max | 64GB | 24-32 | 30-35 | 18-22 |
| M2 Max | 96GB | 30-38 | 35-42 | 22-28 |
| M2 Ultra | 192GB | 60-76 | 50-60 | 30-38 |
| M3 Max | 128GB | 30-40 | 40-50 | 26-34 |
| M3 Ultra | 192GB | 60-80 | 55-68 | 35-45 |
| M4 Max | 128GB | 40+ | 40-50+ | - |

### Key Architectural Insight

**Apple Silicon excels at capacity; NVIDIA excels at raw compute density** [^2387^]:

- A 70B Q4 model at 8-12 tok/s on M2 Ultra has no equivalent on a 24GB RTX 4090
- For models fitting in VRAM (e.g., 8B Q4), RTX 4090 delivers ~2-3x the throughput of M3 Ultra
- Apple Silicon's advantage is **unified memory capacity**, not absolute compute speed

---

## 10. Additional Optimization Techniques

### Speculative Decoding

Use a small "draft" model to generate candidate tokens; the large "target" model verifies them in a single forward pass. Output is mathematically identical [^2696^][^2389^].

```python
from mlx_lm import load, generate

model, tokenizer = load("./models/llama-3.1-8b-4bit")
draft_model, _ = load("mlx-community/Llama-3.2-1B-Instruct-4bit")

response = generate(
    model, tokenizer,
    prompt=prompt,
    draft_model=draft_model,
    num_draft_tokens=4,  # Sweet spot for structured outputs
    verbose=True,
)
# Draft acceptance rate: ~0.73 -> ~1.6x speedup
```

**Tuning `num_draft_tokens`** [^2389^]:
- 2-3 tokens: Conservative, works for creative outputs
- 4-6 tokens: Sweet spot for structured outputs (JSON, code)
- 8+ tokens: Diminishing returns; rejection rate climbs

### KV Cache Management

```python
from mlx_lm import load

model, tokenizer = load(
    "./models/llama-3.1-8b-4bit",
    model_config={"max_kv_size": 4096}  # Cap memory growth
)
```

Setting `max_kv_size` caps memory growth for long generations. Without this, generating 8K+ tokens on a 16GB machine can trigger memory pressure and force swapping, dropping throughput by 10x or more [^2389^].

### Sysctl Tuning for Unified Memory

Apple's Metal memory management caps GPU memory usage to ~75% of unified RAM by default. This can be raised [^2698^][^2700^]:

```bash
# Check current policy
sysctl iogpu.wired_limit_mb

# Raise cautiously (e.g., 12GB on 16GB machine)
sudo sysctl iogpu.wired_limit_mb=12288

# Or set persistently
echo "iogpu.wired_limit_mb=122880" | sudo tee /etc/sysctl.conf
```

**Caution**: Leave at least 8GB for the system. Setting to 100% makes the system unstable and may decrease speed due to SWAP [^2700^].

**Verification**: Run any model and check `ggml_metal_init: recommendedMaxWorkingSetSize` in console output [^2706^].

### Quantization Strategy

| Format | Apple Silicon Support | Speed | Quality |
|--------|----------------------|-------|---------|
| **GGUF** | Full native (Metal) | Fast (llama.cpp) | Excellent (K-quants) |
| **MLX native** | Full native | Fastest (MLX) | Excellent |
| **AWQ** | No (CUDA only) | N/A | Best accuracy |
| **GPTQ** | No (CUDA only) | N/A | Good |

**Use GGUF for Ollama/llama.cpp. Use MLX-native models (from `mlx-community`) for mlx-lm** [^2696^].

### MLX Distributed Inference

MLX distributed allows splitting large language models across multiple Apple Silicon Macs [^2699^][^2703^]:

- **Pipeline parallelism** (Ring backend): Each node holds a slice of model layers
- **Tensor parallelism** (JACCL via RDMA/Thunderbolt): Each rank holds all layers with sharded weights
- **mDNS auto-discovery** for worker registration

**Quick start with LocalAI**:
```bash
docker run -ti --net host \
  --name local-ai \
  localai/localai:latest-metal-darwin-arm64 run --p2p
```

**Practical example**: 3 Mac Minis (M2 Pro, 64GB each) can run Llama-3.1-70B via distributed sharding [^2703^].

---

## 11. Summary: Optimization Checklist

### For Maximum Single-Stream Throughput

1. **Use MLX-native models** from `mlx-community` (not GGUF)
2. **Quantize to 4-bit** with group size 64 (best speed/quality tradeoff)
3. **Enable speculative decoding** with a 1B-3B draft model (1.5-2x speedup)
4. **Cap KV cache** with `max_kv_size` to prevent unbounded growth
5. **Pre-warm shaders** with a short prompt after model load
6. **Use `mx.compile()`** for JIT graph optimization

### For Production Serving

1. **Use vllm-mlx or higgs** for continuous batching (3.7x scaling at 16 concurrent)
2. **Set `mx.set_cache_limit()`** at startup (e.g., 4GB) to prevent unbounded buffer growth
3. **Call `mx.clear_cache()`** between requests
4. **Set `mx.set_memory_limit()`** to leave ~16GB headroom for OS
5. **Monitor `mx.get_active_memory()` / `mx.get_peak_memory()`** for drift detection
6. **Recycle processes** every 24h to reset Metal allocator state
7. **Use prefix caching** for multimodal workloads (28x speedup on repeated images)

### For Memory-Bandwidth-Bound Models (27B+)

1. **Both MLX and llama.cpp hit the same ceiling** — advantage collapses at 27B+ [^2696^]
2. **Use MoE models** to reduce active parameters (Gemma 4 achieves 59 tok/s vs ~10 for dense 70B) [^2692^]
3. **Consider Open-TQ-Metal** for int4 KV cache compression (3.2x memory reduction)
4. **Enable TurboQuant KV cache** (PMetal) for 4-6x cache compression

### For Power-Efficient / Always-On Inference

1. **Use ANE** via Core ML for zero idle power consumption
2. **Consider ane.cpp** for direct ANE inference without CoreML overhead
3. **Hybrid ANE prefill + GPU decode** for best TTFT + TPOT balance

---

## References

[^2644^]: GitHub mlx-explore/mlx#3350 — "Metal caching allocator retains unbounded buffer pool" (2026-03-31)
[^2645^]: swift-mlx Skills Marketplace — MLX Swift framework overview (2026-04-09)
[^2646^]: vllm-project/vllm-metal#234 — "MLX buffer cache grows unbounded" (2026-04-06)
[^2647^]: DEV Community — "Installing Qwen 3.5 on Apple Silicon Using MLX for 2X Performance" (2026-03-03)
[^2648^]: MLX 0.31.2 Documentation — Metal module (2026)
[^2649^]: arXiv:2604.16957 — "Fused Compressed-Domain Attention for Long-Context LLM Inference on Apple Silicon" (2026-04-18)
[^2650^]: Kodeco — Metal by Tutorials, Chapter 24: Performance Optimization
[^2651^]: Antekapetanovic blog — "Ollama vs. llama.cpp vs. MLX with Qwen3.5 35B" (2026-03-18)
[^2652^]: MLX 0.31.2 Official Documentation — ml-explore.github.io/mlx
[^2653^]: DEV Community — "WWDC 2025 - Get started with MLX for Apple silicon" (2025-06-27)
[^2654^]: arXiv:2511.05502 — "Production-Grade Local LLM Inference on Apple Silicon" (2025)
[^2655^]: Mintlify MLX API Docs — Memory Management (2026-02-28)
[^2656^]: arXiv:2601.19139 — "Native LLM and MLLM Inference at Scale on Apple Silicon" (2026-01-27)
[^2657^]: Apple Developer Documentation — Shader Libraries
[^2658^]: GitHub Blaizzy/mlx-vlm#983 — JIT compilation feature request (2026-04-08)
[^2678^]: GitHub skyfallsin/ane.cpp — ANE direct inference (2026-04-27)
[^2679^]: Blog.squeezebits.com — "Disaggregated Inference on Apple Silicon: NPU prefill and GPU decode" (2025-08-25)
[^2681^]: GitHub panbanda/higgs — Rust MLX server benchmarks (2026-04-30)
[^2683^]: LobeHub apple-ml skill — MLX memory monitoring (2026-03-12)
[^2684^]: GitHub ml-explore/mlx-lm#1015 — OOM recovery patterns (2026-03-17)
[^2686^]: MLX 0.31.2 Documentation — Metal module reference
[^2691^]: HuggingFace Daily Papers — Open-TQ-Metal (2026-04-30)
[^2692^]: arXiv:2604.16957v1 — Open-TQ-Metal paper (2026-04-18)
[^2694^]: HexDocs Emily.Stream — Per-process MLX stream management (2026-04-25)
[^2696^]: Blog.starmorph.com — "Apple Silicon LLM Inference Optimization" (2026-04-10)
[^2697^]: ACM DL — "Benchmarking and Characterization of LLM Inference on Apple Silicon" (2025-12-02)
[^2698^]: sudoall.com — "Your Mac Does Not Have Hidden VRAM" (2026-03-10)
[^2699^]: LocalAI.io — MLX Distributed Inference documentation (2026-03-09)
[^2700^]: Zenn.dev — "How to Increase VRAM Allocation on Mac" (2024-10-31)
[^2701^]: arXiv:2501.14925 — "Profiling Apple Silicon Performance for ML Training" (2025)
[^2704^]: ML Systems Review — "Apple M4 Max First NPU Benchmarks" (2026-04-16)
[^373^]: arXiv:2603.06728 — "Characterizing and Programming Apple's Neural Engine for LLM Training and Inference" (2026-03-06)
[^377^]: arXiv:2601.19139v1 — vllm-mlx paper (2026-01-27)
[^379^]: arXiv:2603.03529 — "mlx-snn: Spiking Neural Networks on Apple Silicon via MLX" (2026-03-03)
[^723^]: Aman's AI Journal — ML Runtimes primer
[^85^]: yage.ai — "MLX: The Next Inference Engine for Apple Silicon" (2026-03-31)
[^1159^]: youngju.dev — "Running LLMs on Apple Silicon: Inside M4/M5 Architecture" (2026-03-18)
[^2099^]: arXiv:2510.18921 — "Benchmarking On-Device ML on Apple Silicon with MLX" (2025-10-21)
[^2370^]: WWDC 2015 — "Metal Performance Optimization Techniques" transcript
[^2387^]: SitePoint — "Local LLMs Apple Silicon Mac 2026" (2026-03-13)
[^2389^]: branch8.com — "Apple Silicon MLX LLM Inference Optimization Tutorial" (2026-05-01)
[^268^]: GitHub Epistates/pmetal — Powdered Metal framework (2026-04-21)
[^269^]: lib.rs pmetal-metal crate documentation (2026-03-24)
[^272^]: Reddit r/LocalLLaMA — "vLLM-MLX: Native Apple Silicon LLM inference" (2026-02-26)
[^280^]: pmetal.io — PMetal website
