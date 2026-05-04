# EPISTEMOS UNIFIED MEMORY CONTROL ROOM
## Raw Memory Inspection & Deep Model Implantation via Apple Silicon UMA

**Date**: 2026-05-02 | **Technical Depth**: Implementation-Ready
**Target Tier**: Research (Developer ID + Notarization) | **Est. Build Time**: 6-8 weeks

---

# EXECUTIVE SUMMARY

## The Answer: Yes — At the Metal Buffer Level

Apple Silicon's Unified Memory Architecture (UMA) means **CPU, GPU, and ANE all read from the same physical memory pool.** There is no "VRAM." A `MTLBuffer` created with `storageModeShared` gives you a **direct CPU pointer** to bytes that the GPU is actively using. You can read them, modify them, and the GPU sees the changes immediately — no copy, no sync, no driver call.

**What this enables:**
- **Raw memory hex dump** of any GPU tensor while the model is running
- **Live weight patching** — change model weights in-place without reloading
- **KV cache pre-loading** — "implant" knowledge by writing pre-computed K/V vectors directly into cache
- **Attention mask manipulation** — force the model to attend to specific tokens
- **Activation interception** — read and modify hidden states between transformer layers
- **Command buffer inspection** — see every GPU dispatch, its arguments, its memory footprint

**What this does NOT enable:**
- ANE silicon internals (still a black box)
- Kernel-level physical memory paging (SIP blocks this)
- In-place MLX ops (MLX avoids this by design, but raw buffer access bypasses MLX)

---

# PART I: THE UNIFIED MEMORY REALITY

## 1.1 How Apple Silicon UMA Actually Works

On discrete GPUs (NVIDIA), the flow is:
```
CPU RAM → cudaMemcpy → GPU VRAM → compute → cudaMemcpy → CPU RAM
              ↑_________________________________________↑
                        20-50 GB/s PCIe bottleneck
```

On Apple Silicon, the flow is:
```
CPU/GPU/ANE all point to the same physical memory address
        ↓
    [Physical RAM]
        ↓
No copy. Same pointer. Both processors see the same bytes.
        ↓
  ~138-153 GB/s internal fabric bandwidth
```

**The critical API:**

```swift
// On Apple Silicon, this buffer lives in system memory accessible by BOTH CPU and GPU
let buffer = device.makeBuffer(
    length: 1024 * MemoryLayout<Float>.stride,
    options: .storageModeShared  // ← The magic flag
)

// CPU gets a direct pointer. No copy. No driver involvement.
let rawPointer = buffer.contents()  // UnsafeMutableRawPointer

// Cast to typed pointer and iterate
let floatPointer = rawPointer.bindMemory(to: Float.self, capacity: 1024)
for i in 0..<1024 {
    print("Byte \(i): \(floatPointer[i])")  // Reading GPU memory from CPU
}

// Modify from CPU — GPU sees this immediately
floatPointer[0] = 3.14159
```

**This is the foundation of everything that follows.** Any buffer, texture, or tensor that the GPU uses is just bytes in RAM that you can read from Swift/Rust.

---

## 1.2 MLX Tensors Are Just Metal Buffers

MLX Swift uses Metal for all GPU compute. Every MLX `Array` has an underlying `MTLBuffer`. The path to raw memory:

```swift
import MLX
import Metal

// MLX array backed by Metal buffer on GPU
let mlxArray = MLXArray([1.0, 2.0, 3.0, 4.0])

// Access the underlying Metal buffer
// NOTE: This requires MLX internals — the buffer is not publicly exposed
// but we can work around it via the C API or custom kernel injection

// Better approach: custom Metal kernel that exports buffer handle
```

**The workaround for MLX raw access:**

Since MLX does not expose its internal Metal buffers, you have two paths:

**Path A: Intercept at the Metal command level**
Use `MTLCaptureManager` to capture every command buffer, then inspect the buffers passed to each kernel.

**Path B: Custom Metal compute shader that reads/writes MLX buffers**
Register a custom MLX op that has side effects (logging buffer addresses to shared ring buffer).

**Path C: Use MLX C API directly**
MLX C++ backend exposes `array::buffer()` which returns the raw buffer pointer. Build a small C++ bridge.

```cpp
// C++ bridge to MLX internals
// File: mlx_raw_access.cpp

#include "mlx/array.h"
#include "mlx/backend/metal/metal.h"

extern "C" {
    // Get the raw Metal buffer pointer from an MLX array
    void* mlx_array_buffer_ptr(const mlx::core::array& arr) {
        const auto& buffer = arr.buffer();
        return buffer.ptr();
    }
    
    // Get the buffer size in bytes
    size_t mlx_array_buffer_size(const mlx::core::array& arr) {
        return arr.buffer().size();
    }
    
    // Write bytes directly to MLX array buffer (DANGEROUS: no synchronization)
    void mlx_array_buffer_write(void* buffer_ptr, size_t offset, const void* data, size_t len) {
        uint8_t* dst = static_cast<uint8_t*>(buffer_ptr) + offset;
        memcpy(dst, data, len);
    }
    
    // Read bytes directly from MLX array buffer
    void mlx_array_buffer_read(void* buffer_ptr, size_t offset, void* out, size_t len) {
        uint8_t* src = static_cast<uint8_t*>(buffer_ptr) + offset;
        memcpy(out, src, len);
    }
}
```

---

# PART II: THE RAW MEMORY INSPECTOR

## 2.1 Metal Buffer Enumeration — See Every GPU Resource

You can enumerate every Metal buffer, texture, and pipeline currently allocated:

```swift
import Metal

class MetalResourceInspector {
    let device: MTLDevice
    
    // Capture manager for programmatic inspection
    var captureManager: MTLCaptureManager?
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    /// Capture a single frame and extract all resource information
    func captureAndInspect(completion: @escaping ([MetalResourceInfo]) -> Void) {
        let captureManager = MTLCaptureManager.shared()
        let descriptor = MTLCaptureDescriptor()
        descriptor.captureObject = device
        descriptor.destination = .gpuTraceDocument
        descriptor.outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos_inspect.gputrace")
        
        do {
            try captureManager.startCapture(with: descriptor)
            
            // ... trigger one inference step here ...
            
            captureManager.stopCapture()
            
            // Parse the gputrace file (private format, but we can use xctrace)
            parseGPUTrace(descriptor.outputURL!, completion: completion)
        } catch {
            print("Capture failed: \(error)")
        }
    }
    
    /// Alternative: Real-time resource tracking via Metal Performance HUD
    func enableRealTimeHUD() {
        // MTL_HUD_ENABLED=1 environment variable
        // Shows: FPS, GPU time, memory usage, draw/dispatch counts
        setenv("MTL_HUD_ENABLED", "1", 1)
        setenv("MTL_HUD_LOGGING_ENABLED", "1", 1)  // Logs to system log
    }
}

struct MetalResourceInfo {
    let name: String
    let type: ResourceType  // buffer, texture, accelerationStructure
    let size: Int           // bytes
    let storageMode: MTLStorageMode
    let cpuCacheMode: MTLCPUCacheMode
    let usage: ResourceUsage
    let boundToEncoder: String?
}
```

## 2.2 xctrace CLI — Programmatic Metal System Trace

```bash
# Record a Metal System Trace from command line
xctrace record --device $(xcrun xctrace list devices | grep "My Mac" | awk '{print $1}') \
  --template "Metal System Trace" \
  --time-limit 10s \
  --launch -- /Applications/Epistemos.app/Contents/MacOS/Epistemos

# Export to XML for parsing
xctrace export --input trace.trace --output trace.xml

# The XML contains:
# - Every GPU command buffer
# - Every compute dispatch with threadgroup size
# - Every buffer binding with address and size
# - Memory allocation/deallocation events
# - GPU idle/active intervals
```

**Parse the XML in Swift:**

```swift
import Foundation

class MetalTraceParser {
    func parse(url: URL) -> [GPUCommand] {
        let xml = try! XMLDocument(contentsOf: url)
        
        var commands: [GPUCommand] = []
        
        // Extract all compute dispatches
        let dispatches = try! xml.nodes(forXPath: "//dispatchCompute")
        for dispatch in dispatches {
            let command = GPUCommand(
                type: .compute,
                pipeline: dispatch.attribute(forName: "pipeline")!.stringValue!,
                threadgroups: MTLSize(
                    width: Int(dispatch.attribute(forName: "threadgroupsX")!.stringValue!)!,
                    height: Int(dispatch.attribute(forName: "threadgroupsY")!.stringValue!)!,
                    depth: Int(dispatch.attribute(forName: "threadgroupsZ")!.stringValue!)!
                ),
                threadsPerGroup: MTLSize(
                    width: Int(dispatch.attribute(forName: "threadsPerGroupX")!.stringValue!)!,
                    height: Int(dispatch.attribute(forName: "threadsPerGroupY")!.stringValue!)!,
                    depth: Int(dispatch.attribute(forName: "threadsPerGroupZ")!.stringValue!)!
                ),
                buffers: extractBufferBindings(dispatch),
                timestamp: Double(dispatch.attribute(forName: "timestamp")!.stringValue!)!
            )
            commands.append(command)
        }
        
        return commands
    }
    
    func extractBufferBindings(_ node: XMLElement) -> [BufferBinding] {
        // Extract buffer(index), offset, length for each binding
        // This gives you the exact memory addresses the GPU is using
    }
}

struct GPUCommand {
    let type: CommandType
    let pipeline: String        // Shader function name
    let threadgroups: MTLSize
    let threadsPerGroup: MTLSize
    let buffers: [BufferBinding]
    let timestamp: Double
}

struct BufferBinding {
    let index: Int              // [[buffer(N)]] index
    let address: UInt64           // Raw virtual address
    let length: Int               // Size in bytes
    let contents: Data?           // Snapshot of buffer at dispatch time
}
```

## 2.3 The Real-Time Memory Hex Viewer

```swift
import SwiftUI
import Metal

struct UnifiedMemoryHexView: View {
    @ObservedObject var inspector: MemoryInspector
    let targetBuffer: MTLBuffer
    
    var body: some View {
        VStack {
            HStack {
                Text("Unified Memory Inspector")
                    .font(.headline)
                Spacer()
                Text("Size: \(targetBuffer.length) bytes")
                    .font(.caption)
                Text("Storage: \(targetBuffer.storageMode.description)")
                    .font(.caption)
            }
            
            // Hex dump grid
            HexDumpGrid(
                data: inspector.currentSnapshot,
                bytesPerRow: 16,
                highlightRange: inspector.selectedRange
            )
            .font(.system(size: 10, design: .monospaced))
            
            // ASCII sidebar
            ASCIISidebar(data: inspector.currentSnapshot)
            
            // Live update controls
            HStack {
                Button("Snapshot") { inspector.takeSnapshot() }
                Button("Live") { inspector.startLiveUpdates(interval: 0.1) }
                Button("Stop") { inspector.stopLiveUpdates() }
                
                Toggle("Auto-highlight changes", isOn: $inspector.highlightChanges)
            }
        }
    }
}

class MemoryInspector: ObservableObject {
    let buffer: MTLBuffer
    @Published var currentSnapshot: Data = Data()
    @Published var selectedRange: Range<Int>?
    @Published var highlightChanges = false
    
    private var previousSnapshot: Data?
    private var timer: Timer?
    
    init(buffer: MTLBuffer) {
        self.buffer = buffer
    }
    
    /// Read bytes directly from shared memory
    func takeSnapshot() {
        let ptr = buffer.contents()
        let length = buffer.length
        
        // Copy to Data for SwiftUI display
        let data = Data(bytes: ptr, count: length)
        
        if highlightChanges, let prev = previousSnapshot {
            // Compute diff and publish
            let changes = computeDiff(prev, data)
            DispatchQueue.main.async {
                self.currentSnapshot = data
                // Highlight changed bytes
            }
        } else {
            DispatchQueue.main.async {
                self.currentSnapshot = data
            }
        }
        
        previousSnapshot = data
    }
    
    func startLiveUpdates(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.takeSnapshot()
        }
    }
    
    func stopLiveUpdates() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Write bytes directly to shared memory (DANGEROUS)
    func writeBytes(offset: Int, data: Data) {
        let ptr = buffer.contents().advanced(by: offset)
        data.copyBytes(to: ptr.bindMemory(to: UInt8.self, capacity: data.count), count: data.count)
    }
}
```

---

# PART III: THE DEEP IMPLANT ARCHITECTURE

## 3.1 KV Cache Pre-Loading — "Implanting" Knowledge

The KV cache is the model's working memory. Every token's keys and values are stored there. If you **pre-compute K/V vectors for a document and write them into the cache**, the model acts as if it just read that document — without actually processing it.

**This is the ultimate "implant" technique.**

### How KV Cache Pre-Loading Works

```
Normal inference:
  [User prompt: "Summarize the contract"]
  → Tokenize → Embed → Layer 1 → ... → Layer N → Logits → "The contract states..."
  
  KV cache starts empty. Each token adds one row to K_cache and V_cache.

Pre-loaded inference:
  [Pre-load: Contract K/V vectors written to cache positions 0-499]
  [User prompt: "Summarize"]
  → Tokenize → Embed → Layer 1 → ... → Layer N → Logits → "The contract states..."
  
  Model attends to pre-loaded contract vectors as if it read them itself.
```

### Implementation: KV Cache Direct Manipulation

```swift
import MLX
import Metal

class KVCacheImplanter {
    let model: LLMModel  // Your MLX-loaded model
    let device: MTLDevice
    
    /// Pre-compute K/V vectors for a document and write them into the cache
    func implantDocument(
        document: String,
        into layerRange: ClosedRange<Int> = 0...31,
        at position: Int = 0
    ) -> KVCacheSnapshot {
        // Step 1: Run model on document to populate KV cache normally
        let tokens = tokenize(document)
        let prefillResult = model.prefill(tokens: tokens)
        
        // Step 2: Extract the populated KV cache
        let snapshot = extractKVCache(from: prefillResult, layers: layerRange)
        
        // Step 3: (Optional) Compress or quantize the snapshot
        let compressed = quantize(snapshot, to: .q8_0)  // 8-bit quantization
        
        return compressed
    }
    
    /// Write a pre-computed KV snapshot into the active cache
    func loadImplant(
        snapshot: KVCacheSnapshot,
        into activeCache: inout MLX.KVCache,
        at position: Int
    ) {
        for layer in snapshot.layers {
            let kBuffer = layer.keys.metalBuffer  // Underlying MTLBuffer
            let vBuffer = layer.values.metalBuffer
            
            // Direct memory write — no MLX API, just raw bytes
            let kPtr = kBuffer.contents()
            let vPtr = vBuffer.contents()
            
            // Write pre-computed K vectors
            layer.keysData.withUnsafeBytes { src in
                memcpy(kPtr.advanced(by: position * layer.keyStride), src.baseAddress!, src.count)
            }
            
            // Write pre-computed V vectors
            layer.valuesData.withUnsafeBytes { src in
                memcpy(vPtr.advanced(by: position * layer.valueStride), src.baseAddress!, src.count)
            }
        }
    }
    
    /// Extract KV cache from an MLX inference result
    func extractKVCache(from result: InferenceResult, layers: ClosedRange<Int>) -> KVCacheSnapshot {
        var layerSnapshots: [LayerKVSnapshot] = []
        
        for layerIdx in layers {
            let layer = result.hiddenStates[layerIdx]
            
            // MLX stores K and V as separate arrays in the KV cache
            // Access via C++ bridge or Metal buffer interception
            let kBuffer = getKVBuffer(layer: layerIdx, type: .key)
            let vBuffer = getKVBuffer(layer: layerIdx, type: .value)
            
            // Read raw bytes from shared memory
            let kData = Data(bytes: kBuffer.contents(), count: kBuffer.length)
            let vData = Data(bytes: vBuffer.contents(), count: vBuffer.length)
            
            layerSnapshots.append(LayerKVSnapshot(
                layerIndex: layerIdx,
                keysData: kData,
                valuesData: vData,
                keyStride: kBuffer.length / result.sequenceLength,
                valueStride: vBuffer.length / result.sequenceLength,
                sequenceLength: result.sequenceLength
            ))
        }
        
        return KVCacheSnapshot(layers: layerSnapshots)
    }
}

struct KVCacheSnapshot: Codable {
    let layers: [LayerKVSnapshot]
    let modelId: String
    let createdAt: Date
}

struct LayerKVSnapshot {
    let layerIndex: Int
    let keysData: Data       // Raw K vectors (fp16 or quantized)
    let valuesData: Data     // Raw V vectors (fp16 or quantized)
    let keyStride: Int       // Bytes per token's K vector
    let valueStride: Int     // Bytes per token's V vector
    let sequenceLength: Int
}
```

### KV Cache Implant Use Cases

| Use Case | How It Works | Effect |
|----------|-------------|--------|
| **Document pre-load** | Pre-compute contract/legal doc K/V, write to cache before user prompt | Model "knows" the doc without processing it |
| **Persona implant** | Pre-compute system prompt K/V vectors, persist to disk | Instant persona switch without token cost |
| **Memory injection** | Load yesterday's conversation K/V from database | Seamless multi-day context |
| **Skill implant** | Pre-compute coding pattern K/V (e.g., SwiftData best practices) | Model acts like an expert in that domain |
| **Adversarial defense** | Pre-load "do not harm" K/V with high attention weights | Safety guardrails at the memory level |

---

## 3.2 Attention Mask Manipulation — Forcing Attention

The attention mask controls which tokens the model can attend to. By modifying the mask directly in shared memory, you can force the model to focus on specific tokens.

```swift
class AttentionManipulator {
    /// Force the model to attend maximally to specific token positions
    func forceAttention(
        to positions: [Int],
        in attentionScores: MTLBuffer,  // Pre-softmax attention logits
        sequenceLength: Int
    ) {
        let ptr = attentionScores.contents()
            .bindMemory(to: Float.self, capacity: attentionScores.length / 4)
        
        // Attention logits are a [seq_len, seq_len] matrix
        // Row i = query token i attending to all key tokens
        
        for queryPos in 0..<sequenceLength {
            let rowOffset = queryPos * sequenceLength
            
            // Zero out all attention except forced positions
            for keyPos in 0..<sequenceLength {
                if !positions.contains(keyPos) {
                    ptr[rowOffset + keyPos] = -Float.infinity  // Softmax → 0
                }
            }
            
            // Boost forced positions
            for keyPos in positions {
                ptr[rowOffset + keyPos] = 100.0  // Dominates softmax
            }
        }
        
        // No synchronization needed — GPU sees changes immediately in shared memory
    }
    
    /// Create a "spotlight" attention pattern — high on specific tokens, low elsewhere
    func spotlightAttention(
        weights: [Int: Float],  // [token_position: attention_weight]
        in attentionScores: MTLBuffer,
        sequenceLength: Int
    ) {
        let ptr = attentionScores.contents()
            .bindMemory(to: Float.self, capacity: attentionScores.length / 4)
        
        for queryPos in 0..<sequenceLength {
            let rowOffset = queryPos * sequenceLength
            
            for (keyPos, weight) in weights {
                ptr[rowOffset + keyPos] += weight  // Additive boost
            }
        }
    }
}
```

---

## 3.3 Weight Patching — Hot-Swapping Model Behavior

Model weights are just large tensors in Metal buffers. You can modify them in-place:

```swift
class WeightPatcher {
    let model: LLMModel
    
    /// Apply a LoRA-style delta to weights in-place
    func applyLoRADelta(
        layer: Int,
        weightType: WeightType,  // .qProj, .kProj, .vProj, .oProj, .gate, .up, .down
        delta: MLXArray,        // Low-rank delta matrix
        alpha: Float = 1.0
    ) {
        // Get the underlying Metal buffer for this weight tensor
        let weightBuffer = getWeightBuffer(layer: layer, type: weightType)
        let deltaBuffer = delta.deviceBuffer()  // MLX→Metal buffer
        
        // Read current weights
        let weightPtr = weightBuffer.contents()
            .bindMemory(to: Float16.self, capacity: weightBuffer.length / 2)
        let deltaPtr = deltaBuffer.contents()
            .bindMemory(to: Float.self, capacity: deltaBuffer.length / 4)
        
        // Apply delta in-place: W_new = W_old + alpha * delta
        // NOTE: For fp16 weights, need careful arithmetic
        for i in 0..<(weightBuffer.length / 2) {
            let oldValue = Float(weightPtr[i])
            let deltaValue = deltaPtr[i]
            weightPtr[i] = Float16(oldValue + alpha * deltaValue)
        }
    }
    
    /// Revert weight patch (store original before patching)
    func revertPatch(
        layer: Int,
        weightType: WeightType,
        originalSnapshot: Data
    ) {
        let weightBuffer = getWeightBuffer(layer: layer, type: weightType)
        originalSnapshot.withUnsafeBytes { src in
            memcpy(weightBuffer.contents(), src.baseAddress!, src.count)
        }
    }
}

enum WeightType {
    case qProj, kProj, vProj, oProj   // Attention projections
    case gate, up, down              // MLP layers
    case embed, lmHead               // Embedding / output
}
```

---

## 3.4 Activation Interception — The "Glass Pipe"

Intercept activations between transformer layers by injecting a custom Metal compute kernel:

```metal
// Interceptor kernel: copies hidden states to inspection buffer
kernel void intercept_activations(
    device float* hidden_states [[buffer(0)]],    // [batch, seq_len, hidden_dim]
    device float* inspection_buffer [[buffer(1)]], // Ring buffer for capture
    constant int& layer_index [[buffer(2)]],
    constant int& batch_size [[buffer(3)]],
    constant int& seq_len [[buffer(4)]],
    constant int& hidden_dim [[buffer(5)]],
    device atomic_int* write_index [[buffer(6)]],  // Atomic ring index
    uint gid [[thread_position_in_grid]]
) {
    // Each thread copies one element
    if (gid >= batch_size * seq_len * hidden_dim) return;
    
    // Atomically get write position
    int idx = atomic_fetch_add_explicit(write_index, 1, memory_order_relaxed);
    int ring_size = batch_size * seq_len * hidden_dim * MAX_LAYERS;
    int pos = (idx % ring_size);
    
    // Write hidden state to inspection ring buffer
    inspection_buffer[pos] = hidden_states[gid];
}
```

```swift
class ActivationInterceptor {
    let device: MTLDevice
    let pipelineState: MTLComputePipelineState
    
    // Ring buffer stores last N layers of activations
    let inspectionBuffer: MTLBuffer
    let ringIndexBuffer: MTLBuffer  // atomic_int for ring position
    
    init(device: MTLDevice, maxTokens: Int, hiddenDim: Int, numLayers: Int) {
        self.device = device
        
        // Ring buffer: stores activations from all layers
        let ringSize = maxTokens * hiddenDim * numLayers * MemoryLayout<Float>.stride
        self.inspectionBuffer = device.makeBuffer(length: ringSize, options: .storageModeShared)!
        
        // Atomic index buffer
        self.ringIndexBuffer = device.makeBuffer(length: MemoryLayout<Int32>.stride, options: .storageModeShared)!
        
        // Load interceptor shader
        let library = device.makeDefaultLibrary()!
        let function = library.makeFunction(name: "intercept_activations")!
        self.pipelineState = try! device.makeComputePipelineState(function: function)
    }
    
    /// Inject interceptor before a transformer layer
    func intercept(
        hiddenStates: MTLBuffer,
        layerIndex: Int,
        batchSize: Int,
        seqLen: Int,
        hiddenDim: Int,
        commandBuffer: MTLCommandBuffer
    ) {
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(hiddenStates, offset: 0, index: 0)
        encoder.setBuffer(inspectionBuffer, offset: 0, index: 1)
        
        var layerIdx = Int32(layerIndex)
        var batch = Int32(batchSize)
        var seq = Int32(seqLen)
        var dim = Int32(hiddenDim)
        encoder.setBytes(&layerIdx, length: 4, index: 2)
        encoder.setBytes(&batch, length: 4, index: 3)
        encoder.setBytes(&seq, length: 4, index: 4)
        encoder.setBytes(&dim, length: 4, index: 5)
        encoder.setBuffer(ringIndexBuffer, offset: 0, index: 6)
        
        let threads = batchSize * seqLen * hiddenDim
        let groupSize = min(threads, pipelineState.maxTotalThreadsPerThreadgroup)
        encoder.dispatchThreads(
            MTLSize(width: threads, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: groupSize, height: 1, depth: 1)
        )
        encoder.endEncoding()
    }
    
    /// Read captured activations from shared memory
    func readCapturedActivations(layer: Int, token: Int) -> [Float] {
        let ptr = inspectionBuffer.contents()
            .bindMemory(to: Float.self, capacity: inspectionBuffer.length / 4)
        
        // Calculate offset for this layer and token
        // (Depends on your ring buffer layout)
        let offset = (layer * maxTokens + token) * hiddenDim
        
        var result: [Float] = []
        for i in 0..<hiddenDim {
            result.append(ptr[offset + i])
        }
        return result
    }
}
```

---

# PART IV: THE UNIFIED MEMORY CONTROL ROOM UI

## 4.1 Complete Dashboard Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    UNIFIED MEMORY CONTROL ROOM                               │
│                                                                              │
│  ┌──────────────────────────────┐  ┌─────────────────────────────────────┐ │
│  │    LIVE MEMORY MAP           │  │      GPU COMMAND STREAM             │ │
│  │                              │  │                                     │ │
│  │  [Visual representation of   │  │  23.4ms  dispatch_attention       │ │
│  │   all Metal buffers, color-  │  │          threadgroups: 1024×1×1    │ │
│  │   coded by type:            │  │          buffers: [0x7f8a2c000:    │ │
│  │   - Weights (green)          │  │                   64MB] [0x7f8b... │ │
│  │   - KV Cache (blue)          │  │  12.1ms  dispatch_ffn_up            │ │
│  │   - Activations (purple)     │  │          threadgroups: 512×1×1     │ │
│  │   - Attention scores (red)]  │  │  45.2ms  dispatch_layer_norm      │ │
│  │                              │  │          threadgroups: 256×1×1     │ │
│  │  Hover → shows hex dump      │  │                                     │ │
│  │  Click → opens detail view   │  │  [Click command → see all buffer    │ │
│  │                              │  │   contents and pipeline state]     │ │
│  └──────────────────────────────┘  └─────────────────────────────────────┘ │
│                                                                              │
│  ┌──────────────────────────────┐  ┌─────────────────────────────────────┐ │
│  │    HEX DUMP VIEWER           │  │      IMPLANT CONTROL PANEL         │ │
│  │                              │  │                                     │ │
│  │  Offset  00 01 02 03 04 ... │  │  Active Implants:                   │ │
│  │  000000  3f 80 00 00 00 00  │  │  • [Contract_v2] 500 tokens loaded  │ │
│  │  000010  40 00 00 00 00 00  │  │  • [SwiftData_Guide] 200 tokens    │ │
│  │  000020  3e cc cc cd 00 00  │  │  • [Safety_Guardrails] 50 tokens   │ │
│  │  ...                         │  │                                     │ │
│  │                              │  │  [Load Implant] [Save Current KV]  │ │
│  │  Selected: 0x000008-0x00000C│  │  [Force Attention] [Patch Weights]  │ │
│  │  Float32: 2.0                │  │                                     │ │
│  │  Hex: 0x40000000             │  │  Weight Patches:                   │ │
│  │  ASCII: "@"                  │  │  • Layer 12 Q-proj: +LoRA_delta   │ │
│  │                              │  │  • Layer 7 gate: +coding_expert     │ │
│  │  [Modify] [Freeze] [Export]  │  │  [Revert All] [Snapshot Weights]   │ │
│  └──────────────────────────────┘  └─────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐│
│  │  ACTIVATION PIPELINE (Glass Pipe)                                     ││
│  │                                                                        ││
│  │  [Layer 0] → [Layer 1] → [Layer 2] → ... → [Layer N] → [Logits]      ││
│  │     ↓          ↓          ↓                   ↓          ↓            ││
│  │   [SAE]      [SAE]      [SAE]               [SAE]      [SAE]           ││
│  │     ↓          ↓          ↓                   ↓          ↓            ││
│  │  "embed"    "syntax"    "reasoning"        "entity"    "token"        ││
│  │                                                                        ││
│  │  Click any layer → see full activation vector, SAE features, attention  ││
│  │  Click any SAE → see decoder vector, top-activating examples           ││
│  └────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ANE Power: 2.3W | GPU Power: 1.1W | Mem Pressure: 62% | Bandwidth: 89 GB/s│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART V: SYNCHRONIZATION & SAFETY

## 5.1 The Cache Coherency Problem

Apple Silicon UMA has **separate CPU and GPU caches**. Writing from CPU does not automatically invalidate GPU cache lines. You must synchronize.

```swift
/// Synchronize CPU writes to GPU visibility
func synchronizeCPUToGPU(buffer: MTLBuffer) {
    // Option 1: Use Managed storage mode + didModifyRange
    // Only needed if buffer was created with .storageModeManaged
    if buffer.storageMode == .managed {
        let range = 0..<buffer.length
        buffer.didModifyRange(range)
    }
    
    // Option 2: For .storageModeShared (default on Apple Silicon):
    // Shared mode requires manual cache flushing
    // Use memory barriers in Metal command buffers
}

/// Memory barrier in Metal command buffer
func insertMemoryBarrier(commandBuffer: MTLCommandBuffer) {
    // Ensures all prior GPU writes are visible to subsequent GPU commands
    // CPU-side writes to Shared buffers are visible immediately on Apple Silicon
    // (but GPU caches may be stale)
}
```

**Critical rule for Apple Silicon:**
- `.storageModeShared`: CPU writes visible to GPU **after next command buffer commit**
- `.storageModeManaged`: CPU writes visible to GPU **after `didModifyRange()`**
- `.storageModePrivate`: CPU **cannot access** at all

## 5.2 Safe Implant Protocol

```
1. PAUSE inference (finish current command buffer)
2. WRITE implant to shared buffer (KV cache, weights, etc.)
3. SYNCHRONIZE (didModifyRange or memory barrier)
4. RESUME inference (next command buffer sees updated data)
5. VERIFY (check that model output reflects implant)
```

```swift
class SafeImplanter {
    let commandQueue: MTLCommandQueue
    
    func performSafeImplant(
        buffer: MTLBuffer,
        offset: Int,
        data: Data,
        during inference: InferenceSession
    ) {
        // Step 1: Wait for current GPU work to complete
        inference.currentCommandBuffer.waitUntilCompleted()
        
        // Step 2: Write to shared memory
        data.withUnsafeBytes { src in
            let dst = buffer.contents().advanced(by: offset)
            memcpy(dst, src.baseAddress!, src.count)
        }
        
        // Step 3: Synchronize
        if buffer.storageMode == .managed {
            buffer.didModifyRange(offset..<(offset + data.count))
        }
        
        // Step 4: Resume inference — next command buffer sees new data
        // (No explicit step needed — new command buffers pick up shared memory)
    }
}
```

## 5.3 Safety Interlocks

| Danger | Interlock |
|--------|-----------|
| Writing to GPU-active buffer mid-compute | Always `waitUntilCompleted()` before CPU write |
| Overflowing buffer bounds | Verify `offset + data.count <= buffer.length` |
| Corrupting weight tensors | Store original snapshot before patch; verify numerical range |
| Creating NaN/Inf | Check all written values with `isFinite` |
| Implants persisting across sessions | Clear KV cache on session boundary unless explicitly persisted |
| Unauthorized implant loading | Sign implant files; verify hash before loading |

---

# PART VI: THE BUILD PLAN

## Phase 1: Raw Memory Inspector (2 weeks)

- [ ] `MetalResourceTracker` — enumerate all buffers, report size/storageMode
- [ ] `MemoryHexViewer` — SwiftUI view showing live hex dump of any buffer
- [ ] `BufferDiffEngine` — highlight changed bytes between snapshots
- [ ] `xctrace` integration — programmatic Metal System Trace capture

## Phase 2: KV Cache Implantation (2 weeks)

- [ ] C++ bridge to MLX internal buffer access
- [ ] `KVCacheExtractor` — extract K/V vectors after prefill
- [ ] `KVCacheImplanter` — write pre-computed K/V to active cache
- [ ] `ImplantDatabase` — store/retrieve implant snapshots on disk
- [ ] Compression: quantize implants to Q4/Q8 for storage

## Phase 3: Weight Patching (1 week)

- [ ] `WeightBufferLocator` — map layer names to Metal buffer addresses
- [ ] `LoRAApplier` — apply low-rank deltas in-place
- [ ] `WeightSnapshotManager` — save/restore original weights
- [ ] Verification: check patched weights produce valid outputs

## Phase 4: Activation Interception (1 week)

- [ ] `ActivationInterceptor` Metal kernel — ring buffer capture
- [ ] Layer-by-layer activation streaming to CPU
- [ ] SAE encoding on captured activations (Metal shader)
- [ ] Real-time feature visualization

## Phase 5: Control Room UI (2 weeks)

- [ ] Metal Memory Map — visual buffer layout
- [ ] GPU Command Stream — live command buffer listing
- [ ] Hex Dump + ASCII + Float32 interpretation
- [ ] Implant Control Panel — load/save/force
- [ ] Activation Pipeline — layer-by-layer glass pipe

**Total: 8 weeks** to a working Unified Memory Control Room with deep implant capability.

---

# PART VII: INTEGRATION WITH YOUR EXISTING ARCHITECTURE

| Your Layer | How Control Room Connects |
|-----------|---------------------------|
| `agent_core` (agent runtime) | Add `unified_memory` module; implant hooks in inference loop |
| `MLXInferenceService.swift` | Add `captureMode`, `implantMode`, `interceptorMode` flags |
| `epistemos-shadow` (search) | Implant database queries — "find me the contract implant" |
| `graph-engine` (graph) | Store implant relationships (Contract_v2 → Clause_4 implant) |
| `ContextualShadows` (memory) | KV cache visualization IS the memory visualization |
| Provenance spine | Every implant operation logged with before/after buffer hashes |
| Residency Governor | Memory pressure triggers implant eviction to disk |
| Ternary substrate | Buffer modifications go through Claim verification before write |
| SAE Glass Ball | Unified memory inspector provides the raw activation data |

---

# PART VIII: THE HONEST BOUNDARIES

| Dream | Reality |
|-------|---------|
| See ANE internal SRAM | ANE is a black box — no SRAM readback |
| Modify ANE microcode | No interface exists — ANE firmware is immutable |
| See GPU register file | No public API — would need kernel driver |
| True in-place MLX ops | MLX avoids this by design; raw buffer access works around it |
| Read other apps' GPU memory | macOS isolates GPU memory per-process |
| Modify system GPU buffers | Hardened Runtime prevents this |
| Kernel-level memory inspection | SIP blocks kernel extensions |

**What IS possible:** Everything in this document — raw buffer inspection, KV cache manipulation, weight patching, activation interception, command buffer capture. All within your app's own memory space, via shared Metal buffers.

---

# PART IX: THE NO-COMPROMISE POSITION

This feature is **Research tier** for two reasons:

1. **Raw memory manipulation is dangerous.** Writing to GPU-active buffers can crash the model, corrupt outputs, or create security vulnerabilities. The user must understand what they're doing.

2. **It requires `disable-library-validation`** (for the C++ MLX bridge) and full filesystem access (for implant database).

But it is **genuinely buildable** on Apple Silicon today. The UMA architecture makes this possible in a way that is impossible on NVIDIA (where CPU and GPU memory are separate, requiring expensive copies).

**The superpower**: You can pause inference, write 500 tokens of pre-computed K/V vectors into the cache, resume inference, and the model acts as if it just read a 500-token document. The user prompt "Summarize" produces a summary of that document. Total cost: 1 token of user input.

**That is the deep implant.**

---

*This document is based on:
- Metal documentation: MTLBuffer, MTLStorageMode, MTLCaptureManager [^2373^][^2376^][^2380^][^2381^][^2382^]
- MLX issues: no in-place ops, custom kernel read+write [^2372^]
- Metal Frame Capture programmatic API [^2367^][^2371^][^2374^][^2378^]
- Metal Performance Optimization (WWDC 2015) [^2370^]
- Apple Silicon UMA architecture [^2368^][^274^]
- KV cache internals and prefill/decode mechanics [^2369^][^2375^][^2377^][^2379^]*
