# **Architectural Design and Implementation of Per-Token Mixture-of-LoRA Routing on Apple Silicon**

## **Introduction to Dynamic On-Device Adapter Routing**

The paradigm of large language model (LLM) fine-tuning has shifted definitively from full-parameter updates to parameter-efficient fine-tuning (PEFT) methodologies. Among these, Low-Rank Adaptation (LoRA) has established itself as the standard technique due to its minimal storage requirements and competitive performance characteristics.1 By freezing the pre-trained model weights and injecting trainable rank decomposition matrices into each layer of the Transformer architecture, LoRA drastically reduces the number of trainable parameters. In complex inference environments, particularly on-device deployments utilizing Apple Silicon (M1-M4 series), models are increasingly required to serve diverse, highly specialized capabilities seamlessly within a single forward pass. This operational requirement necessitates the deployment of multiple LoRA adapters—such as stylistic modifiers, factual knowledge bases, and complex tool-use directors—simultaneously. The fundamental challenge lies in dynamically routing individual tokens to the appropriate adapter matrix without incurring catastrophic inference latency.

The mathematical formulation of a standard LoRA update is an additive operation to the backbone weight matrix: ![][image1], where ![][image2] represents the input token sequence, ![][image3] is the frozen base model weight, and ![][image4] and ![][image5] are the low-rank projection matrices.4 When multiple adapters are routed dynamically on a per-token basis, different tokens within a batched sequence will route to completely different ![][image4] and ![][image5] matrices.5 While dynamic adapters typically add only 1% to 5% in absolute computational complexity (FLOPs), they often increase decoding latency by an unacceptable margin of 250% to 950%.6 This discrepancy is driven by the sequential nature of routing decisions and the frequent, fragmented memory access overhead associated with launching multiple distinct compute kernels for each adapter.6

For an on-device system running a base model at approximately 21 tokens per second on an Apple M1 chip with 16GB of unified memory, standard iterative adapter looping is completely unviable.8 The solution requires a comprehensive system-algorithm co-design that leverages a per-token Mixture-of-LoRA (MoLoRA) architecture, specifically optimized for the Metal Shading Language (MSL) and deeply integrated into the MLX framework's lazy evaluation graph.9 This report provides an exhaustive, low-level technical blueprint for building a heterogeneous-rank MoLoRA routing system on Apple Silicon. It evaluates the architectural trade-offs of modern routing mechanisms, designs a custom Segmented Grouped Matrix Multiplication (SGMM) compute kernel in Metal, details the integration pathway into the MLX C++ primitive infrastructure, and formalizes a data-efficient training pipeline for the routing classifier.

## **Router Architecture: Trade-offs for On-Device Inference**

The architecture of the routing mechanism dictates both the computational overhead of the forward pass and the specialization capacity of the model. When operating with highly constrained unified memory (16GB to 64GB) and a strict latency budget, the router must balance high-precision token targeting with zero-overhead execution. Three primary paradigms dominate the current literature and production deployments: MoLoRA's per-token multi-layer perceptron (MLP) routing, X-LoRA's dense layer-wise gating, and AdaFuse's "decide-once" token-level pre-gating.6

## **Dense Layer-Wise Gating**

The X-LoRA architecture implements a dense gating mechanism where all loaded adapters contribute to the final token representation, scaled by continuously learned gating values at every layer.12 In this architecture, the router computes a probability distribution over the available adapters, and the output is a weighted sum of all adapter outputs. While this provides a highly nuanced, continuous blending of adapter expertise, it is pathologically inefficient for on-device deployment.11

Dense gating forces the system to execute the matrix multiplication for every single adapter present in memory for every token, completely negating the computational sparsity benefits of a Mixture-of-Experts (MoE) architecture. If a system is configured with four adapters (e.g., style, knowledge, tool, and a generalized fallback), the X-LoRA approach requires four dense matrix multiplications per layer, proportional to the sum of the adapter ranks. For a memory-bound architecture like Apple Silicon, where the primary operational bottleneck is fetching weight matrices from the unified memory to the arithmetic logic units (ALUs), multiplying all weights guarantees severe memory bandwidth saturation and cache thrashing.14 The theoretical limit of the M1 memory bandwidth is approximately 68 GB/s, and forcing the chip to read every adapter matrix for every token ensures that the ALUs will idle while waiting for memory fetches.16

## **Per-Token Layer-Wise Routing**

Standard MoLoRA architectures utilize a top\-![][image6] routing mechanism, typically governed by a two-layer MLP operating on the hidden states of the current token at each transformer block.9 This introduces necessary sparsity, as only the top 1 or 2 adapters are activated for the computation, effectively pruning the execution graph. Extensions of this concept, such as HMoRA (Hierarchical Mixture of LoRA Experts), introduce layer-specific granularity where different layers capture features at varying levels of complexity, allowing the routing mechanism to integrate both token-level and task-level routing.18

However, maintaining a distinct router at every layer introduces significant execution fragmentation. Traditional dynamic adapters employing layer-wise routing must make a sequential decision at every block.6 This sequential dependency prevents efficient weight merging ahead of time and results in excessive compute kernel calls.6 The GPU must synchronize with the host to evaluate the router output, determine the active adapter, and subsequently dispatch the appropriate adapter matrix multiplication kernel.7 This dispatch overhead—specifically the latency incurred by the CPU instructing the GPU to launch a small kernel—is the primary driver of the 2.5x to 9.5x latency penalty observed in naive implementations.7 In profiling studies of dynamic adapter layers, the execution time for the context operations during CUDA or Metal kernel runs significantly exceeds the actual computation time of the low-rank matrices.7

## **Decide-Once Token-Level Pre-Gating**

To reconcile the need for token-level granularity with the severe latency constraints of Apple Silicon, the "decide-once, apply-everywhere" pre-gating strategy proposed by AdaFuse provides the optimal architectural tradeoff.6

This strategy places a single routing classifier at the first expanded linear layer of the model. When a token enters the first layer, the router makes a global routing decision that applies identically to all subsequent layers in the network.6 By making the decision once, the architecture "staticizes" the execution path for each token before it traverses the depth of the LLM.6 This design is grounded in the empirical observation that tokens exhibiting specific semantic properties tend to consistently activate the same expert patterns across varying network depths.6

For Apple Silicon, this pre-gating architecture is transformative. By determining the adapter path at layer zero, the host CPU can construct a single, cohesive command buffer for the GPU that contains the predefined grouped GEMM dispatches for the entire forward pass. It eliminates the need for host-device synchronization at every layer, entirely mitigating the dispatch bottlenecks that throttle Metal performance in dynamic graphs.6 AdaFuse demonstrated that this architecture reduces decoding latency overhead from the 250-950% range to just 29% over the original base model, achieving average speedups of 2.4x compared to state-of-the-art dynamic adapters.6

| Architecture Paradigm | Routing Granularity | Compute Overhead | Dispatch Overhead | Suitability for Apple Silicon |
| :---- | :---- | :---- | :---- | :---- |
| **Dense Gating (X-LoRA)** | Layer-wise (All adapters) | Very High (Computes all paths) | Low (Static execution graph) | Poor (Memory bandwidth bound) |
| **Layer-Wise MoE (MoLoRA)** | Layer-wise (Top\-![][image6] adapters) | Low (Sparse top\-![][image6] computation) | Very High (Dynamic pathing) | Poor (Kernel dispatch bound) |
| **Hierarchical (HMoRA)** | Layer-wise (Token \+ Task) | Moderate (Auxiliary loss routing) | Very High (Dynamic pathing) | Poor (Kernel dispatch bound) |
| **Pre-Gating (AdaFuse)** | Token-level (Decide-once) | Low (Sparse top\-![][image6] computation) | Minimal (Static forward path) | **Optimal** |

## **Kernel Design: Segmented Grouped Matrix Multiplication on Metal**

The performance of the routing system is ultimately dictated by the efficiency of the underlying matrix multiplication kernel. When multiple adapters are active simultaneously across different tokens in a sequence, the system must perform a batch matrix multiplication where the weight matrix differs per batch index.5

Naively, a framework might employ a "gather-then-batch-matmul" approach. This involves iterating through each available adapter, gathering the specific input tokens routed to that adapter from the global sequence, performing a standard Batch Matrix Multiplication (BMM), scattering the results back to their original token positions, and repeating the process for the next adapter.7 This approach is catastrophic for performance. It requires writing intermediate gathered tensors to global memory, launching a distinct compute kernel for each adapter (exacerbating the fragmented kernel launch problem), and then launching another kernel to aggregate the results.7 On Apple Silicon, writing to and reading from global device memory (VRAM) is the most power-intensive and latency-inducing operation, severely underutilizing the computational throughput of the matrix cores.14

## **The SGMV and SGMM Paradigms**

To circumvent these inefficiencies, systems must adopt advanced kernel paradigms. Punica introduced the Segmented Gather Matrix-Vector Multiplication (SGMV) kernel, specifically designed to allow batching GPU operations for different LoRA models simultaneously.4 SGMV maintains a single large input tensor and uses a "segment" offset vector to define which contiguous groups of rows belong to which request or adapter.21 The mathematical representation is defined as ![][image7], where ![][image8] represents the boundaries of the segment.4 In a single kernel launch, it gathers the specific weights and performs the multiplication, maintaining a strong batching effect.4 Punica's SGMV achieved a 12x throughput gain compared to systems that fall back to a batch size of 1 for multi-adapter requests.4

AdaFuse and LoRA-Switch extend this concept further with the Segmented Grouped Matrix Multiplication (SGMM) kernel, which is tailored for dynamic MoE-style adapters within a single sequence.6 While SGMV focuses on serving multiple independent requests with different LoRAs, SGMM facilitates the rapid merging of activated adapters into the backbone and the unmerging of inactivated ones during a single token's forward pass.6 By fusing these merging and multiplication operations, SGMM reduces the total number of kernel launches, ensuring that execution times scale strictly with the arithmetic intensity rather than kernel launch overhead.7 Ablation studies in AdaFuse confirmed that replacing a simple merge approach with the SGMM kernel reduced latency from 4.2 ms/token to 3.1 ms/token.6

## **Adapting SGMM for Apple Silicon Unified Memory Architecture**

Apple Silicon utilizes a unified memory architecture where the CPU and GPU share the exact same physical RAM, accessed via the MTLStorageMode.shared resource mode.22 While this eliminates the traditional PCIe bus transfer bottleneck found in discrete GPU systems, it strictly mandates highly coalesced memory access patterns to saturate the available memory bandwidth (which ranges from approximately 68 GB/s on base M1 chips to over 400 GB/s on M1 Max and higher on M3/M4 iterations).14

The M-Series GPUs implement Tile-Based Deferred Rendering (TBDR) and possess on-chip caches including per-core and shared memory pools.16 In the context of compute shaders written in Metal Shading Language (MSL), the architecture utilizes threadgroups (analogous to CUDA thread blocks) and SIMD groups (analogous to CUDA warps, containing exactly 32 threads in Metal).25 For optimal performance, threadgroup memory (also referred to as tile memory or SRAM) must be aggressively utilized to cache the loaded LoRA matrices, minimizing redundant global memory fetches.25

A highly optimized grouped GEMM kernel on Metal must rely on data-dependent tiling to efficiently support jagged group sizes.28 The kernel receives a packed tensor of all input tokens, sorted by their assigned adapter, alongside an integer array of group\_offsets.28 Instead of dispatching separate compute grids for each adapter, a single grid is dispatched. Each threadgroup utilizes the group\_offsets array to determine which segment of the input matrix it is responsible for, and consequently, which LoRA adapter matrix it must fetch from unified memory.28

| Feature | Gather-Then-BMM | SGMV (Punica) | SGMM (AdaFuse) |
| :---- | :---- | :---- | :---- |
| **Operation Type** | Multi-kernel dispatch | Single-kernel segmented gather | Fused single-kernel merge/matmul |
| **Global Memory Reads** | Very High (Intermediate buffers) | Low (Direct to registers/SRAM) | Low (Direct to registers/SRAM) |
| **Kernel Launch Overhead** | High (![][image9] launches per layer) | Low (1 launch per layer) | Very Low (Fused operations) |
| **Suitability for Metal** | Poor | Good | **Excellent** |

## **Variable Rank Handling in Metal Compute Kernels**

A significant complication in the specified system is that the adapters possess heterogeneous ranks (e.g., style rank=8, knowledge rank=32, tool rank=32). Handling variable rank dimensions in a single kernel launch presents a complex engineering challenge, as standard block-tiled matrix multiplication kernels assume uniform inner dimensions.29 Frameworks that lack specialized grouped GEMM kernels often fall back to naive iterative loops if the ranks differ within a batch, completely forfeiting the performance benefits of grouped execution.31

To process a rank-8 matrix and a rank-32 matrix concurrently in a unified Metal kernel, there are two distinct engineering pathways: zero-padding or data-dependent tile bounding.

## **The Zero-Padding Approach**

Zero-padding involves artificially expanding all smaller adapter matrices to match the maximum rank in the system (rank=32). In this scenario, the rank-8 style adapter is padded with zeros up to rank-32. This simplifies the kernel architecture significantly. By guaranteeing uniform memory access patterns, the MSL compiler can heavily unroll loops and optimize the instruction pipeline without unpredictable branch divergence within SIMD groups.

However, this approach incurs a severe computational penalty. For the style adapter, 75% of the floating-point operations executed by the ALUs will be multiplications by zero, wasting critical ALU cycles and unnecessarily increasing the memory footprint required to store the padded weights.2 In battery-constrained on-device environments, this power inefficiency is unacceptable.

## **Data-Dependent Tile Bounding**

The superior alternative is data-dependent tile bounding, which utilizes the group\_offsets array to dictate the bounds of the inner product loop dynamically per threadgroup.28 The kernel reads the rank for its specific group from a secondary metadata buffer and terminates its inner accumulation loop early if the rank is 8\.28

While this introduces a branch dependency, it is critical to understand that branch divergence only penalizes performance if threads within the *same* SIMD group evaluate the condition differently. In the SGMM architecture, the input tokens are sorted and contiguous; therefore, an entire threadgroup (and by extension, all its constituent SIMD groups) will process tokens assigned to the exact same adapter. Consequently, all threads in the SIMD group will read the same rank value and branch uniformly, entirely avoiding divergence penalties. This technique maximizes arithmetic intensity without bloating the VRAM footprint.28

## **Metal SGMM Kernel Pseudocode**

The optimal Metal compute kernel design employs 2D Tiling with SIMD-level primitives (TiledSimd), which has been consistently proven to maximize GFLOPS on Apple hardware.17 The following MSL pseudocode outlines the architecture of a rank-heterogeneous SGMM kernel utilizing threadgroup memory caching and dynamic offset arrays:

C++

\#**include** \<metal\_stdlib\>  
using namespace metal;

// Structure to hold metadata for heterogeneous grouped GEMM  
struct GroupMetaData {  
    uint offset\_m; // Start row in the packed input sequence  
    uint count\_m;  // Number of tokens routed to this specific adapter  
    uint rank;     // The specific rank for this adapter (e.g., 8, 32\)  
    uint weight\_offset; // Starting index in the packed LoRA weight array  
};

kernel void sgmm\_heterogeneous\_lora(  
    const device float\* packed\_inputs \[\[buffer(0)\]\],  
    const device float\* packed\_lora\_weights \[\[buffer(1)\]\],  
    device float\* outputs \[\[buffer(2)\]\],  
    const device GroupMetaData\* group\_meta \[\[buffer(3)\]\],  
    uint3 threadgroup\_position\_in\_grid \[\[threadgroup\_position\_in\_grid\]\],  
    uint3 thread\_position\_in\_threadgroup \[\[thread\_position\_in\_threadgroup\]\],  
    uint simd\_group\_id \[\[simdgroup\_index\_in\_threadgroup\]\],  
    uint simd\_lane\_id \[\[thread\_index\_in\_simdgroup\]\])   
{  
    // 1\. Identify which adapter group this threadgroup is processing  
    // We map the Z dimension of the grid to the group ID  
    uint group\_id \= threadgroup\_position\_in\_grid.z;  
    GroupMetaData meta \= group\_meta\[group\_id\];  
      
    // 2\. Calculate global coordinates based on group offsets  
    // Threadgroups process 32x32 tiles  
    uint global\_row \= meta.offset\_m \+ threadgroup\_position\_in\_grid.x \* 32 \+ thread\_position\_in\_threadgroup.x;  
    uint global\_col \= threadgroup\_position\_in\_grid.y \* 32 \+ thread\_position\_in\_threadgroup.y;  
      
    // 3\. Bounds checking based on jagged group counts to prevent out-of-bounds reads  
    if (threadgroup\_position\_in\_grid.x \* 32 \+ thread\_position\_in\_threadgroup.x \>= meta.count\_m) {  
        return;  
    }

    // 4\. Allocate high-speed threadgroup (tile) memory for caching  
    // This allows threads to share fetched data, vastly reducing global memory pressure  
    threadgroup float tile\_X;  
    threadgroup float tile\_W;  
      
    float accumulator \= 0.0;  
      
    // 5\. Inner loop dynamically bounded by the specific adapter's rank (meta.rank)  
    // This entirely avoids the need for zero-padding rank-8 adapters  
    for (uint k \= 0; k \< meta.rank; k \+= 32) {  
          
        // Coalesced load from unified memory to threadgroup memory  
        // Apple Silicon ALUs optimize memory fetches when contiguous 128-byte sectors are accessed  
        if (k \+ thread\_position\_in\_threadgroup.y \< meta.rank) {  
            tile\_X\[thread\_position\_in\_threadgroup.x\]\[thread\_position\_in\_threadgroup.y\] \=   
                packed\_inputs\[global\_row \* meta.rank \+ k \+ thread\_position\_in\_threadgroup.y\];  
                  
            tile\_W\[thread\_position\_in\_threadgroup.x\]\[thread\_position\_in\_threadgroup.y\] \=   
                packed\_lora\_weights\[meta.weight\_offset \+ (k \+ thread\_position\_in\_threadgroup.x) \* /\* hidden\_dim \*/ \+ global\_col\];  
        } else {  
            // Fill remainder of the 32x32 tile with zeros to prevent poisoning the accumulator  
            tile\_X\[thread\_position\_in\_threadgroup.x\]\[thread\_position\_in\_threadgroup.y\] \= 0.0;  
            tile\_W\[thread\_position\_in\_threadgroup.x\]\[thread\_position\_in\_threadgroup.y\] \= 0.0;  
        }  
          
        // Synchronize all threads in the threadgroup to ensure tile memory is fully populated  
        threadgroup\_barrier(mem\_flags::mem\_threadgroup);  
          
        // 6\. Compute matrix multiplication using threadgroup memory  
        // In highly optimized versions, this loop is replaced with simdgroup\_matrix instructions  
        for (uint i \= 0; i \< 32; \++i) {  
            accumulator \+= tile\_X\[thread\_position\_in\_threadgroup.x\]\[i\] \* tile\_W\[i\]\[thread\_position\_in\_threadgroup.y\];  
        }  
          
        // Synchronize before fetching the next tile  
        threadgroup\_barrier(mem\_flags::mem\_threadgroup);  
    }  
      
    // 7\. Write result to global unified memory  
    outputs\[global\_row \* /\* hidden\_dim \*/ \+ global\_col\] \= accumulator;  
}

## **Memory Layout Strategies for Coalesced Access**

The physical layout of the LoRA matrices in the unified memory heavily influences the efficiency of the SGMM kernel. Memory coalescing refers to the phenomenon where memory accesses by consecutive threads in a SIMD group are combined into a single, larger memory transaction.14 On Apple Silicon, memory is fetched in 128-byte cache lines.14 If threads access memory with large strides or in a fragmented manner, each memory transaction fetches much more data than is needed, saturating the bus and causing cache evictions.14

## **Contiguous vs. Interleaved Matrices**

When loading multiple LoRA A/B matrices, the framework must decide whether to interleave the weights or pack them contiguously. Interleaving weights (e.g., storing Row 1 of Adapter A, Row 1 of Adapter B, Row 2 of Adapter A, etc.) is highly detrimental to performance.14 Because the input tokens are grouped by adapter, an entire threadgroup will be tasked with fetching data exclusively for Adapter A. If the weights are interleaved, the threadgroup will be forced to perform strided memory reads, pulling in cache lines that contain useless data for Adapter B, thereby halving the effective memory bandwidth.

The optimal strategy is contiguous packing.28 All weights for the style adapter must be laid out continuously in linear memory, followed by the complete set of weights for the knowledge adapter. By utilizing the group\_offsets array, the SGMM kernel can offset its base pointer to the exact start of the required adapter and perform perfectly coalesced, linear reads across the contiguous block.28

## **Optimal Threadgroup Dimensions**

For the routing matmul, defining the grid and threadgroup sizes is critical. In Metal, the number of threads per SIMD group is 32\. To maximize the utilization of threadgroup memory and align with the 128-byte cache line structure (which equates to 32 floating-point 32-bit numbers, or 64 floating-point 16-bit numbers), the optimal threadgroup size is typically (32, 32, 1).17 This allocates 1024 threads per block, organized into 32 SIMD groups. The 2D structure maps cleanly to the matrix multiplication tiles, ensuring that when threads iterate across the inner dimension ![][image6], their memory fetches satisfy the coalescing constraints of the Apple GPU hardware.14

## **MLX Integration Pathway**

Integrating the heavily optimized Metal SGMM kernel into the MLX framework presents a critical architectural choice between two distinct methodologies: utilizing the Python Just-In-Time (JIT) compiler via mx.fast.metal\_kernel() or engineering a C++ custom extension via an mlx::core::Primitive subclass.10

## **Python JIT Compilation (mx.fast.metal\_kernel())**

The mx.fast.metal\_kernel() function provides an immediate, highly accessible mechanism for injecting custom MSL code into MLX directly from Python.10 The user provides the MSL body as a string, and MLX automatically generates the function signature, handles input bindings, and JIT-compiles the Metal library at runtime.10

While rapid to develop, this approach presents significant integration friction with MLX's lazy evaluation engine. MLX heavily relies on deferred graph construction; arrays are purely symbolic and are only materialized in memory when explicitly required by a synchronization event, such as a print statement or an explicit .eval() call.34 Custom kernels injected via mx.fast.metal\_kernel() frequently disrupt this laziness. Because the native MLX scheduler does not possess a semantic understanding of the custom Python-injected kernel, developers are often forced to invoke explicit .eval() calls on the input arrays before dispatching the kernel to ensure the data is resident in memory.35 This manual synchronization breaks the continuous execution flow, introducing stalls in the host-side scheduler and preventing the MLX runtime from optimizing the execution graph globally.35 Furthermore, if the system requires backpropagation through the router, metal\_kernel requires cumbersome manual definitions for atomic Jacobian-vector products (jvp) and vector-Jacobian products (vjp).10

## **C++ Custom Extension (mlx::core::Primitive)**

Conversely, developing a C++ custom extension by subclassing mlx::core::Primitive is the structurally robust approach required for a production-grade, low-latency inference system.33 Primitives form the foundational mathematical building blocks of the MLX computation graph. They possess native understanding of evaluation semantics, stream scheduling, buffer allocation, and graph transformations.33

By defining the SGMM kernel as a C++ primitive, the operation integrates seamlessly into the MLX operator graph without requiring explicit evaluation triggers. The eval\_gpu virtual method serves as the core entry point, allowing the developer to allocate output buffers optimally to prevent redundant memory copies, and enqueueing the MSL payload directly onto the primary Metal command queue managed by the MLX scheduler.33

The ZMLX toolkit has unequivocally demonstrated the efficacy of this approach on Apple Silicon.36 ZMLX extends MLX with a Python-first Metal kernel toolkit specifically targeting MoE decoding inefficiencies. By utilizing a custom primitive for fused sequence operators (gather\_qmm\_swiglu), ZMLX effectively patches mixture-of-experts logic to collapse top\-![][image6] gating, weight-and-reduce combining, and expert activation into a single dispatch.36 This elimination of dispatch overhead during decode yields a proven \+12% performance gain on Apple hardware.36 For a MoLoRA routing system operating under a strict overhead budget, encapsulating the entire grouping, offset calculation, and grouped matrix multiplication logic inside a single mlx::core::Primitive is mandatory.4

## **MLX Primitive Code Structure**

The C++ extension requires a specific architectural layout, binding the Metal library to the Python runtime via nanobind.33 The following code structure outlines the essential components required to bridge the SGMM kernel into MLX:

C++

\#**include** \<mlx/mlx.h\>  
\#**include** \<mlx/primitives.h\>  
\#**include** \<mlx/backend/metal/device.h\>  
\#**include** \<nanobind/nanobind.h\>

namespace nb \= nanobind;

// 1\. Define the Primitive Subclass  
class SGMMPrimitive : public mlx::core::Primitive {  
public:  
    explicit SGMMPrimitive(mlx::core::StreamOrDevice s)   
        : mlx::core::Primitive(s) {}

    // 2\. Define the Metal execution logic  
    void eval\_gpu(const std::vector\<mlx::core::array\>& inputs,   
                  std::vector\<mlx::core::array\>& outputs) override {  
          
        // Unpack inputs: token states, packed A matrices, packed B matrices, group\_offsets  
        auto& x \= inputs;  
        auto& packed\_A \= inputs;  
        auto& offsets \= inputs;

        // Allocate the output array. By passing the inputs as dependencies,   
        // MLX's memory manager optimizes the allocation lifecycle.  
        outputs \= mlx::core::array(  
            x.shape(), x.dtype(), nullptr, std::vector\<mlx::core::array\>{x, packed\_A}  
        );

        // Acquire the Metal command buffer directly from the MLX scheduler stream  
        auto& d \= mlx::backend::metal::device(stream().device);  
        auto command\_buffer \= d.get\_command\_buffer(stream().index);  
        auto encoder \= command\_buffer-\>computeCommandEncoder();  
          
        // Locate and bind the compiled MSL compute pipeline state  
        auto compute\_pipeline \= d.get\_kernel("sgmm\_heterogeneous\_lora");  
        encoder-\>setComputePipelineState(compute\_pipeline);  
          
        // Bind the input, output, and metadata buffers  
        encoder-\>setBuffer(static\_cast\<const MTL::Buffer\*\>(x.buffer()), x.data\_offset(), 0);  
        encoder-\>setBuffer(static\_cast\<const MTL::Buffer\*\>(packed\_A.buffer()), packed\_A.data\_offset(), 1);  
        encoder-\>setBuffer(static\_cast\<const MTL::Buffer\*\>(outputs.buffer()), outputs.data\_offset(), 2);  
          
        // Define grid and threadgroup dimensions (e.g., 32x32x1)  
        MTL::Size grid\_size \= MTL::Size::Make(/\* tokens \*/, /\* hidden\_dim \*/, /\* num\_adapters \*/);  
        MTL::Size threadgroup\_size \= MTL::Size::Make(32, 32, 1);  
          
        // Dispatch the grouped GEMM  
        encoder-\>dispatchThreads(grid\_size, threadgroup\_size);  
        encoder-\>endEncoding();  
    }

    void eval\_cpu(const std::vector\<mlx::core::array\>& inputs,   
                  std::vector\<mlx::core::array\>& outputs) override {  
        throw std::runtime\_error("SGMM CPU fallback is not supported. Metal GPU required.");  
    }  
};

// 3\. Define the functional wrapper  
mlx::core::array sgmm\_forward(const mlx::core::array& x,   
                              const mlx::core::array& packed\_A,   
                              const mlx::core::array& packed\_B,   
                              const mlx::core::array& offsets) {  
    return mlx::core::array(  
        x.shape(), x.dtype(),   
        std::make\_shared\<SGMMPrimitive\>(mlx::core::default\_stream(x.device())),   
        {x, packed\_A, packed\_B, offsets}  
    );  
}

// 4\. Expose the C++ function to Python via nanobind  
NB\_MODULE(custom\_sgmm, m) {  
    m.def("sgmm\_forward", \&sgmm\_forward, "Segmented Grouped Matrix Multiplication for MoLoRA");  
}

## **Training the Router in Low-Data Regimes**

The success of the decide-once pre-gating architecture hinges entirely on the accuracy and stability of the routing classifier. The specified system constraint of possessing fewer than 500 training examples per domain (style, knowledge, tool) presents a severe statistical challenge.

In environments with highly constrained datasets, training a parameterized standard Multi-Layer Perceptron (MLP) router via gradient descent is highly susceptible to extreme overfitting and routing weight collapse.37 Routing collapse occurs when the router disproportionately favors a single adapter—often the one corresponding to the domain with slightly more prominent semantic features—rendering the other specialized adapters inactive and wasting model capacity.37 Methods like ReMix utilize complex reinforcement learning paradigms with non-learnable constant routing weights to maximize effective support size and prevent this collapse.37 However, applying reinforcement learning pipelines is an overly complex and brittle approach for a minimal 3-adapter static configuration.

Similarly, the X-LoRA training methodology, which learns gating scaling values while keeping the base adapter weights completely frozen, requires sufficient data diversity to converge on meaningful continuous scalar values.12 With fewer than 500 examples, X-LoRA's dense scalar parameters lack the statistical support necessary to generalize beyond the immediate training distribution, often resulting in erratic routing behavior during inference.11

## **The Deterministic KMeans Proximity Router**

The most mathematically robust and empirically proven approach for extreme low-data environments is a deterministic clustering technique, identical to the foundational routing methodology employed by the original MoLoRA implementation.9

Instead of training a neural network layer, the KMeans approach computes a static "centroid" embedding for each of the target domains. Using a lightweight, dense embedding model (such as sentence-transformers/all-MiniLM-L6-v2) or, more efficiently, extracting the hidden state projection of the LLM's early layers, all 500 examples for a specific domain are processed to extract their latent representations.9 The system calculates the mean vector of these 500 embeddings, establishing a canonical, singular centroid for that domain in the high-dimensional latent space.9

During on-device inference, as a batch of tokens enters the first layer (aligning with the AdaFuse pre-gating strategy), the system extracts their corresponding hidden state embeddings. The router acts purely as an ![][image10] distance calculator, computing the Euclidean distance or cosine similarity between the current token's embedding and the three pre-computed centroids (style, knowledge, tool).9 The token is deterministically routed to the adapter corresponding to the nearest centroid.

This approach completely sidesteps the need for iterative backpropagation training, making it fundamentally immune to routing collapse.37 It guarantees that the latent representation of the domain is accurately captured even with minute sample sizes. Furthermore, calculating the cosine similarity between a hidden state and three distinct centroids is computationally trivial, executing in microseconds and strictly preserving the latency budget.

## **Python Training Pipeline Implementation**

The training pipeline for the MoLoRA routing mechanism is formulated as a straightforward pre-computation script utilizing MLX operations:

Python

import mlx.core as mx  
import numpy as np

def compute\_domain\_centroids(model, datasets, hidden\_dim):  
    """  
    Computes deterministic centroids for low-data router initialization.  
    datasets: Dict containing domain names and their list of \<500 text examples.  
    """  
    centroids \= {}  
      
    for domain, examples in datasets.items():  
        domain\_embeddings \=  
          
        for text in examples:  
            \# Tokenize and extract the hidden states at the designated routing layer  
            \# In AdaFuse architecture, this is the first expanded linear layer  
            tokens \= tokenize(text)  
            hidden\_states \= model.extract\_first\_layer\_hidden\_states(tokens)  
              
            \# Mean pooling across the sequence length to capture the holistic semantic intent  
            pooled\_state \= mx.mean(hidden\_states, axis=0)   
            domain\_embeddings.append(pooled\_state)  
              
        \# Stack all 500 examples and compute the absolute mean centroid for the domain  
        stacked\_embeddings \= mx.stack(domain\_embeddings)  
        centroid \= mx.mean(stacked\_embeddings, axis=0)  
          
        \# Normalize the centroid to enable rapid cosine similarity routing at inference  
        centroids\[domain\] \= centroid / mx.linalg.norm(centroid)  
          
    \# Return a stacked tensor of shape (num\_adapters, hidden\_dim)  
    return mx.stack(list(centroids.values()))

def decide\_once\_router\_forward(token\_hidden\_state, normalized\_centroids):  
    """  
    Executes during the forward pass at layer zero to determine the static execution path.  
    """  
    \# Normalize input state  
    state\_norm \= token\_hidden\_state / mx.linalg.norm(token\_hidden\_state, axis=-1, keepdims=True)  
      
    \# Compute dot product (cosine similarity) against all adapter centroids  
    similarities \= mx.matmul(state\_norm, normalized\_centroids.T)  
      
    \# Select the adapter index with the highest similarity score  
    best\_adapter\_idx \= mx.argmax(similarities, axis=-1)  
      
    return best\_adapter\_idx

## **Overhead Budget and Performance Expectations**

A critical engineering constraint for on-device deployment is maintaining a minimal latency footprint that does not perceivably degrade the user experience. The specified base model operates at approximately 21 tokens per second on an Apple M1 with 16GB of unified memory, which translates to a processing budget of roughly 47.6 milliseconds per token.6 In conventional execution environments without fused SGMM kernels, injecting dynamic adapters increases latency by 250% to 950%, which would plummet the overall throughput to an unusable 2 to 6 tokens per second.6

Punica's highly optimized SGMV kernel sets the industry benchmark on discrete CUDA architectures (specifically the Nvidia A100 GPU), demonstrating an overhead of merely 2 milliseconds per token when performing multi-tenant LoRA routing.4 However, comparing an A100's HBM2e memory bandwidth (which exceeds 1.5 TB/s) to the Apple M1's unified memory bandwidth (approximately 68 GB/s on the base M1, scaling up to 400 GB/s on the M1 Max) dictates modified, hardware-aware expectations.16

By utilizing the AdaFuse decide-once architecture, the system entirely avoids the kernel launch latency penalties that accumulate sequentially block-by-block.6 Consequently, the latency overhead scales strictly with the execution time of the custom SGMM primitive itself. On Apple Silicon, matrix multiplications that heavily rely on ALUs utilizing TiledSimd MSL operations achieve substantial utilization of theoretical hardware limits, capable of pushing over 2400 GFLOPS on M3 architecture.17

Assuming the injection of three adapters (rank 8, 32, 32\) into a standard 7B parameter model featuring a hidden dimension of 4096, the raw floating-point operations per token added by the adapters are mathematically negligible compared to the billions of operations executed by the dense base model matrices. The true hardware cost is strictly the time required for memory transit from unified RAM to the ALU registers.14

With the SGMM kernel written as a C++ mlx::core::Primitive ensuring zero lazy-evaluation stalls 33, and the grouped LoRA weights residing contiguously in MTLStorageMode.shared memory, the system achieves maximum memory bandwidth utilization. Under these highly optimized conditions, the realistic overhead target on Apple Silicon is approximately 3.5 to 5.0 milliseconds per token on a base M1 chip, and shrinks to 1.5 to 2.5 milliseconds on an M3/M4 Max (due to significantly enhanced memory bandwidth and the inclusion of hardware matrix coprocessors).17 This translates to a total throughput retention of over 90%, maintaining robust decoding speeds of approximately 19 tokens per second, fully satisfying the requirements of real-time, uninterrupted on-device inference.41

## **Synthesized Conclusions**

Engineering a per-token Mixture-of-LoRA routing system for Apple Silicon dictates a stark departure from traditional discrete CUDA programming methodologies. The unique constraints of unified memory architecture and the high overhead of fragmented compute dispatch demand a synergistic approach between algorithm design and low-level kernel execution.

To survive the memory bandwidth bottlenecks inherent in dynamic adapter architectures, the system must abandon layer-wise dense execution (as seen in X-LoRA) and layer-wise dynamic dispatch (as seen in standard MoLoRA) in favor of token-level, decide-once pre-gating (AdaFuse). By isolating the routing decision to the initial layer utilizing a mathematically robust, deterministic KMeans centroid classifier, the system guarantees accurate token routing while remaining immune to the overfitting and collapse issues that plague neural routers trained on fewer than 500 examples.

The computational core must strictly employ a customized Segmented Grouped Matrix Multiplication (SGMM) compute kernel written in the Metal Shading Language. This kernel must leverage data-dependent tiling to handle heterogeneous ranks seamlessly, avoiding the severe ALU waste associated with zero-padding matrices to uniform dimensions. Furthermore, the LoRA matrices must be packed contiguously in memory to ensure that threadgroups perform coalesced, 128-byte cache line reads, satisfying Apple Silicon's stringent memory access requirements.

Most critically, to operate synchronously with MLX's lazy evaluation engine and prevent catastrophic execution stalls, this Metal kernel cannot be injected loosely via Python JIT compilation. It must be encapsulated deeply within a C++ mlx::core::Primitive extension. This synthesis of algorithm design, hardware-aware memory layout, and low-level framework integration ensures that multiple specialized domains can be served simultaneously on-device, successfully preserving the 21 token-per-second baseline performance required for modern LLM applications.

#### **Works cited**

1. \[2511.22880\] Serving Heterogeneous LoRA Adapters in Distributed LLM Inference Systems, accessed March 24, 2026, [https://arxiv.org/abs/2511.22880](https://arxiv.org/abs/2511.22880)  
2. LoRAFusion: Efficient LoRA Fine-Tuning for LLMs \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2510.00206v1](https://arxiv.org/html/2510.00206v1)  
3. Multi-Tenant LoRA Serving \- Punica \- arXiv, accessed March 24, 2026, [https://arxiv.org/abs/2310.18547](https://arxiv.org/abs/2310.18547)  
4. Accelerating MoE's with a Triton Persistent Cache-Aware Grouped GEMM Kernel \- PyTorch, accessed March 24, 2026, [https://pytorch.org/blog/accelerating-moes-with-a-triton-persistent-cache-aware-grouped-gemm-kernel/](https://pytorch.org/blog/accelerating-moes-with-a-triton-persistent-cache-aware-grouped-gemm-kernel/)  
5. AdaFuse: Accelerating Dynamic Adapter Inference via Token ... \- arXiv, accessed March 24, 2026, [https://arxiv.org/abs/2603.11873](https://arxiv.org/abs/2603.11873)  
6. LoRA-Switch: Boosting the Efficiency of Dynamic LLM Adapters via ..., accessed March 24, 2026, [https://arxiv.org/abs/2405.17741](https://arxiv.org/abs/2405.17741)  
7. mlx-examples/lora/README.md at main \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx-examples/blob/main/lora/README.md](https://github.com/ml-explore/mlx-examples/blob/main/lora/README.md)  
8. aicrumb/MoLora \- GitHub, accessed March 24, 2026, [https://github.com/aicrumb/MoLora](https://github.com/aicrumb/MoLora)  
9. Custom Metal Kernels — MLX 0.31.1 documentation, accessed March 24, 2026, [https://ml-explore.github.io/mlx/build/html/dev/custom\_metal\_kernels.html](https://ml-explore.github.io/mlx/build/html/dev/custom_metal_kernels.html)  
10. Pushing Mixture of Experts to the Limit: Extremely Parameter Efficient MoE for Instruction Tuning | OpenReview, accessed March 24, 2026, [https://openreview.net/forum?id=EvDeiLv7qc](https://openreview.net/forum?id=EvDeiLv7qc)  
11. Learning to Route Among Specialized Experts for Zero-Shot Generalization \- arXiv.org, accessed March 24, 2026, [https://arxiv.org/html/2402.05859v2](https://arxiv.org/html/2402.05859v2)  
12. arxiv.org, accessed March 24, 2026, [https://arxiv.org/abs/2402.07148](https://arxiv.org/abs/2402.07148)  
13. Unlock GPU Performance: Global Memory Access in CUDA | NVIDIA Technical Blog, accessed March 24, 2026, [https://developer.nvidia.com/blog/unlock-gpu-performance-global-memory-access-in-cuda/](https://developer.nvidia.com/blog/unlock-gpu-performance-global-memory-access-in-cuda/)  
14. Matrix Multiplication on Blackwell: Part 2 \- Using Hardware Features to Optimize Matmul, accessed March 24, 2026, [https://www.modular.com/blog/matrix-multiplication-on-nvidias-blackwell-part-2-using-hardware-features-to-optimize-matmul](https://www.modular.com/blog/matrix-multiplication-on-nvidias-blackwell-part-2-using-hardware-features-to-optimize-matmul)  
15. Evaluating the Apple Silicon M-Series SoCs for HPC Performance and Efficiency \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2502.05317v1](https://arxiv.org/html/2502.05317v1)  
16. LaurentMazare/gemm-metal · GitHub \- GitHub, accessed March 24, 2026, [https://github.com/LaurentMazare/gemm-metal](https://github.com/LaurentMazare/gemm-metal)  
17. HMoRA: Making LLMs More Effective with Hierarchical Mixture of ..., accessed March 24, 2026, [https://openreview.net/forum?id=lTkHiXeuDl](https://openreview.net/forum?id=lTkHiXeuDl)  
18. LoRA-Switch: Boosting the Efficiency of Dynamic LLM Adapters via System-Algorithm Co-design \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2405.17741v1](https://arxiv.org/html/2405.17741v1)  
19. Inside NVIDIA GPUs: Anatomy of high performance matmul kernels \- Aleksa Gordić, accessed March 24, 2026, [https://www.aleksagordic.com/blog/matmul](https://www.aleksagordic.com/blog/matmul)  
20. \[Tracking\] Multi-LoRA Serving · Issue \#3446 · mlc-ai/mlc-llm \- GitHub, accessed March 24, 2026, [https://github.com/mlc-ai/mlc-llm/issues/3446](https://github.com/mlc-ai/mlc-llm/issues/3446)  
21. Choosing a resource storage mode for Apple GPUs | Apple Developer Documentation, accessed March 24, 2026, [https://developer.apple.com/documentation/metal/choosing-a-resource-storage-mode-for-apple-gpus](https://developer.apple.com/documentation/metal/choosing-a-resource-storage-mode-for-apple-gpus)  
22. LoRA Fine-Tuning On Your Apple Silicon MacBook | Towards Data Science, accessed March 24, 2026, [https://towardsdatascience.com/lora-fine-tuning-on-your-apple-silicon-macbook-432c7dab614a/](https://towardsdatascience.com/lora-fine-tuning-on-your-apple-silicon-macbook-432c7dab614a/)  
23. Tailor your apps for Apple GPUs and tile-based deferred rendering, accessed March 24, 2026, [https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering](https://developer.apple.com/documentation/metal/tailor-your-apps-for-apple-gpus-and-tile-based-deferred-rendering)  
24. Writing Fast ML Kernels on Apple Silicon | by Srivarshan | Feb, 2026 | Medium, accessed March 24, 2026, [https://medium.com/@srivarshan02/writing-fast-ml-kernels-on-apple-silicon-123152624078](https://medium.com/@srivarshan02/writing-fast-ml-kernels-on-apple-silicon-123152624078)  
25. Metal Performance Primitives (MPP) Programming Guide | Apple Developer, accessed March 24, 2026, [https://developer.apple.com/download/files/Metal-Performance-Primitives-Programming-Guide.pdf](https://developer.apple.com/download/files/Metal-Performance-Primitives-Programming-Guide.pdf)  
26. Reducing shader bottlenecks | Apple Developer Documentation, accessed March 24, 2026, [https://developer.apple.com/documentation/xcode/reducing-shader-bottlenecks](https://developer.apple.com/documentation/xcode/reducing-shader-bottlenecks)  
27. Grouped GEMM Example \- Helion documentation, accessed March 24, 2026, [https://helionlang.com/examples/grouped\_gemm.html](https://helionlang.com/examples/grouped_gemm.html)  
28. Low-Rank Adaptation: LoRA Methods \- Emergent Mind, accessed March 24, 2026, [https://www.emergentmind.com/topics/low-rank-adaptation-lora-methods](https://www.emergentmind.com/topics/low-rank-adaptation-lora-methods)  
29. Serving Heterogeneous LoRA Adapters in Distributed LLM Inference Systems \- arXiv, accessed March 24, 2026, [https://arxiv.org/html/2511.22880v1](https://arxiv.org/html/2511.22880v1)  
30. LoRAX: Open Source LoRA Serving Framework for LLMs \- Rubrik, accessed March 24, 2026, [https://www.rubrik.com/blog/ai/23/lorax-the-open-source-framework-for-serving-100s-of-fine-tuned-llms-in](https://www.rubrik.com/blog/ai/23/lorax-the-open-source-framework-for-serving-100s-of-fine-tuned-llms-in)  
31. Custom Extensions in MLX — MLX 0.31.1 documentation, accessed March 24, 2026, [https://ml-explore.github.io/mlx/build/html/dev/extensions.html](https://ml-explore.github.io/mlx/build/html/dev/extensions.html)  
32. ml-explore/mlx: MLX: An array framework for Apple silicon \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx](https://github.com/ml-explore/mlx)  
33. Integrating Custom Kernels with MLX's Lazy Compute Mechanism \#1977 \- GitHub, accessed March 24, 2026, [https://github.com/ml-explore/mlx/discussions/1977](https://github.com/ml-explore/mlx/discussions/1977)  
34. Hmbown/ZMLX: Triton‑style kernel toolkit for MLX plus a ... \- GitHub, accessed March 24, 2026, [https://github.com/Hmbown/ZMLX](https://github.com/Hmbown/ZMLX)  
35. ReMix: Reinforcement Routing for MoLoRA LLMs \- YouTube, accessed March 24, 2026, [https://www.youtube.com/watch?v=HMNQBBjqAlU](https://www.youtube.com/watch?v=HMNQBBjqAlU)  
36. MoLA: MoE LoRA with Layer-wise Expert Allocation \- ACL Anthology, accessed March 24, 2026, [https://aclanthology.org/2025.findings-naacl.284.pdf](https://aclanthology.org/2025.findings-naacl.284.pdf)  
37. Pushing Mixture of Experts to the Limit: Extremely Parameter Efficient MoE for Instruction Tuning \- arXiv, accessed March 24, 2026, [https://arxiv.org/pdf/2309.05444](https://arxiv.org/pdf/2309.05444)  
38. Is MLX working with new M5 matmul yet? : r/LocalLLaMA \- Reddit, accessed March 24, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1oe70jh/is\_mlx\_working\_with\_new\_m5\_matmul\_yet/](https://www.reddit.com/r/LocalLLaMA/comments/1oe70jh/is_mlx_working_with_new_m5_matmul_yet/)  
39. ICML Poster Compress then Serve: Serving Thousands of LoRA Adapters with Little Overhead \- ICML 2026, accessed March 24, 2026, [https://icml.cc/virtual/2025/poster/46530](https://icml.cc/virtual/2025/poster/46530)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIUAAAAYCAYAAADUIj6hAAAEDElEQVR4Xu2ZR6gVSRSGj6PCGNARRTGC6GBATIhhY0BEEYzI4CBujCtBBRMGXKmYQBcO5oRZ1NXAoOBiEGZhwIQIhoURzHHMen6rjn3eud397u3n9HB99cHPqzp/vX5V3dVdp+oRBQKBQCAQqIZ8tIHqzmzWW9ZnpcPe+4P1wXhoL+Bmaq8cWUCu73WsobjHekfROF+wHvmfEpv/rfUPRNqDTfPusFrZYBkhY+ttDUNLcu3mWIM5T84bY41yJ+3BJ3n1WXtssARO2UDOnGPNIze2ScazrCfX7idrMMPJeX9bo9xJevBXKdl7bQMl8o8N5Egj1kVWR3JjW1vRLkCWyjjOkPMGmvhXNrGm2iDTxwZyZB1V7NMK1iJVF+IefGPWlgQPY5pgYqVy2gZKBJ/0Q6zuvt6WtZ/V4VuLZJArgRrkxnZceXGgzWMbZPqS8y5ZAyARqUmuwSAVn+JjedOMdcGXZ1CUKAHM7NW+LNyiwn6+9z/jJsUnU88C+pGVI6yxvoy+7Ca3lNWjwr5afmMtVHW0RzKZRENybZaz2rF+ZfVgXffxwVHTiG3kJgRAI6wxwkMfS2MpuUHFaRdrB2s7ayu5N3cWfqkS9N/E2o96N4pm9njlg5M+XtvXh7JG+zJuur7eYlYbVc9K1kmBB7JP1fHFkf5hSavsflsfdRvTrCHn455gAkBDWJt9vH/UNAI3CayiwoujftTE8qCnKs+liv36WZUFGSDWWKD37je9J9xV5WLAdq9XjK7ExERp4E3XoG+3TSwJPIv2JlbZpEjLJw6Q82QJKwDmfVWX5QQz+//kOSUPSsA+G21GkJvcTZV3wntIzpBhx2XgafzCGhmjazExUSmgb5NtMAZ8BbEk4n5oVTYp4D2zQQ/6Cv8vawgwZZ0D9g1NYhprZQma6X6taNAHLEVpjCPXDodTN4y30XsDKDrY+h5kXT40/ai4ewwwAZBYWtImRRNyHp5lHAfJ+ROtAZDY2QtjdtlYHuDNxN9FUiT5RGflX1ZlAV+zpJuDA5skrypknRR7KeoLzjpsv3DaaEHyj3wsjrSx4VQXnuRamlrkvNSkGw26+nIXXz8W2bkhbzbW8rO+jO0aQLKJbZulAbl2O63BjCLnTbdGFck6KdCXB6qsHyhOF7HMaYaRa9PaxAVcC35da1Dh9QUcdiH+1BoW2X5CcgKm39C8kL03hCwZXwypL1HtLHGDB9iCJXlVIeukwPkI+oP/PYA/fR1vLM4uNG/InS/gq418ornysFV/6f0nrH/Jbd3BK3JnGbLzEqGO62AZ7eTbJtLC1JF4/Bc38kci66QoC/C5wgTY4OvypuKzFUim1F1MWYFPFj49QE6/fo/sQHUFWyOsM8usEQgEAoFAIFAEXwDeQC/Dj6BOhAAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAYCAYAAAAs7gcTAAAAiklEQVR4XmNgGAUDASYCcSoSvwOIa5D4YCAOxJeg7Fwg/gXE/6H8s0DcA2WDAUwCBHigfH0gtoCyI5DkGYyQ2GUMqJo5kNgY4BMDqmK8AKRwMbogDAgwQBQoMyDcq4UkfxWJzTCTAaKAE4jPQdmKUDmQJ1dA2WDAyABRAMKuDBAbYPw6JHWjgHwAAGFEHDJYgssXAAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAYCAYAAAAVibZIAAAA+klEQVR4Xu2SMetBYRTGT7EaWJAPwIcgi8liN6AsJotPoP7FqnwEBhl9BqMyyGCRMlooEuF/jvfcOh3v9Vpkub964n1+PbfrXgAB3yCE2WMeIjt2GcxRuRU7YqtcWbgnJxY2vJGNBqalS485+A/fXfSqC8kYzDCp+grmzk7Tx8R0KemAGeZUf8ZM2YWVW6rzC3Uww5rohpgIZsAuLdxCfPclD2b4J7oZf7bZFfkcBfPTnaTADEd83ghXZdfk80U4JzSku0tguqLPsuthCpiScE5oeMDcVE//CHITi3NCQwrdjcZzcS1c0MjveZFb6/ITaEhv1ga5gIBf8A/vQUX4wN6bNQAAAABJRU5ErkJggg==>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAXCAYAAADUUxW8AAAAlklEQVR4XmNgGNbAHYivoQsSC/5DMclgKQOZmpmA+BMDmZrfADELAxmadYF4FZT9h4FEzciKQSFNtOZmIPZB4m9ggGgWQRLDCX6g8bsZIJod0cQxADbnOTNAxFvRJZDBMiA2RRcEAikGiObN6BIwIAfEv9EFkQBI8xN0wQAg/smAiMt9qNJg/neoHAifAWJjFBWjYLADACCOJ7pducxLAAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAXCAYAAAAC9s/ZAAAAxElEQVR4XmNgGAXooAWIPwLxfyj+DsTvgfgDEP+Fij2Dq8YDYAagAykGiPgXdAl0AFK0CV0QCnAZDgd+DBAFBugSQCDIgPAaTnCWAbcNMNuZ0CWQAUyRMhRrAHE/VGwlkjqcAKRwHxC7ALEzlI6Dim9FUocVwPxviC4BBOwMELm76BLI4B8Dbv+DAMEYAEl+RheEghQGiPxRdAkYgCWScnQJIDBigMj9RpcAAVBAnWRAOO8GEB8E4r1QGiY+AaZhFAw7AABnZTlUC60sAgAAAABJRU5ErkJggg==>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAsAAAAXCAYAAADduLXGAAAAoElEQVR4XmNgGJSAEYhV0QWxgadA/B+KiQJXGEhQDFJ4DV0QFwApjkAXxAaiGDCd0ATE/mhiYHCTAaGYC4jvAzEfEH+Dq0ACIIW3gVgQiDdCxX5CxTEASHAnEM9El0AHMxgQJsyGslUQ0qgAPTJA7INQdj6SOBiAJKeh8VuQ2HDACRUQRRL7CMQbgLgHiA2RxMHAE10ACDyAmANdcBTAAACQdCSKrBERiwAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,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>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAYCAYAAAAlBadpAAAAqUlEQVR4XmNgGAUjFSQC8TIgtkGXIAT+A7EClF0JxFUIKfxgHxCfQOKDDOpE4uMFnxggGuYDsSyaHAycBGI+dEEQ0GSAaIbh96jSYNCKLoAOVID4OQPEAKIASOEXLGIwIM8ACZO5SGJwAFIoiMTfA8Srkfi3gVgIiP8iicGBCxD/Y0D4txhVGgxAgRWBLkgsIDoM0IEDA8TpvEAsgCpFHPgBxMvRBUcaAAC2vyID7WlYgQAAAABJRU5ErkJggg==>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAAYCAYAAAD3Va0xAAAA3UlEQVR4XmNgGAWkgnlA/BmI/0PxAhRZCPjLgJAHYWdUaVSArBAb2AfEKuiC6IARiLcD8XoGiEFBqNJggMsCFJAPxCZQNi5X/UEXwAbeIrE/MEAM4kMSUwPiTiQ+ToDsAlA4gPg3kcSWATEPEh8rAIXPZjQxdO9h8yoGQA4fZDGQ5m4o/xeSHE7wDl0ACmCu0gbiFjQ5rACXs3czQOTuATEnmhwGYAHiveiCUMDEgBlWWAEzEL8B4pPoEkjgGxB/RxdEBquA+CMDJP2A0g0oL2ED+kCcjS44CkYBEAAABi803bhnVOIAAAAASUVORK5CYII=>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABUAAAAYCAYAAAAVibZIAAAA60lEQVR4XmNgGAW0BvOA+BMQ/0fCH4G4D1kRuQBmINUAIwPEwLPoEpSAbAaIoV7oEpSAlwxU9joIUD08QQBk4Al0QUoAofB0QmJ3MEDUvgViPiRxDPCaAb/XQWkWBGqBmAXKVmfArwdveNYAsSOUfQ+I/yDJgfT4IPHhgJkBInkRXQIIZBlwWwYCIDlhdEEQ6GeASAaiic+Ail9AE4eBpUB8Dl1wMRD/AuK/QPyPAREEIAzig7z5HYhlYBqQgA4QH0IXpATwA/FCJL4dEpssACofrgJxAhAnA/EkIGZCVkAOQC8e8UXiKKACAABiGTxmJEORMAAAAABJRU5ErkJggg==>