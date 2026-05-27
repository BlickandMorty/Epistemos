#!/usr/bin/env swift

import CryptoKit
import Foundation
import Metal

enum PageGatherArtifactError: Error, CustomStringConvertible {
    case noMetalDevice
    case noCommandQueue
    case noBuffer(String)
    case noCommandBuffer
    case noCommandEncoder
    case noFunction(String)
    case noPipeline(String)
    case missingRepoFile(String)
    case commandFailed(String)
    case invalidArgument(String)
    case jsonEncoding

    var description: String {
        switch self {
        case .noMetalDevice:
            return "No default Metal device is available"
        case .noCommandQueue:
            return "Unable to create Metal command queue"
        case let .noBuffer(label):
            return "Unable to create Metal buffer: \(label)"
        case .noCommandBuffer:
            return "Unable to create Metal command buffer"
        case .noCommandEncoder:
            return "Unable to create Metal command encoder"
        case let .noFunction(name):
            return "Metal function not found: \(name)"
        case let .noPipeline(detail):
            return "Unable to create Metal pipeline: \(detail)"
        case let .missingRepoFile(path):
            return "Missing required repo file: \(path)"
        case let .commandFailed(detail):
            return "Metal command failed: \(detail)"
        case let .invalidArgument(detail):
            return "Invalid argument: \(detail)"
        case .jsonEncoding:
            return "Unable to encode artifact JSON"
        }
    }
}

struct Harness {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let streamTriad: MTLComputePipelineState
    let pageGather: MTLComputePipelineState
    let pageGatherScheduled: MTLComputePipelineState
}

struct SampleStats {
    let samples: [Double]

    var median: Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let midpoint = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2.0
        }
        return sorted[midpoint]
    }

    var min: Double { samples.min() ?? 0 }
    var max: Double { samples.max() ?? 0 }
    var mean: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }

    var rangeOverMean: Double {
        let meanValue = mean
        guard meanValue > 0 else { return Double.infinity }
        return (max - min) / meanValue
    }

    var secondRunRatio: Double {
        guard samples.count >= 2, samples[0] > 0 else { return 0 }
        return samples[1] / samples[0]
    }
}

struct WorkingSetResult {
    let mb: Int
    let stream: SampleStats
    let gather: SampleStats
    let scatter: SampleStats
    let localWindow: SampleStats?
    let blockSorted: SampleStats?
    let gatherViolations: Int
    let scatterViolations: Int
    let localWindowViolations: Int?
    let blockSortedViolations: Int?
}

struct RunConfig {
    var workingSetsMB: [Int] = [256, 512, 1024]
    var windowSeconds: Double = 5.0
    var trials: Int = 3
    var warmupIterations: Int = 3
    var writeArtifact = false
    var forceWriteResult = false
    var probeLocality = false
    var localityWindowElements = 65_536
    var localityBlockElements = 8_192

    var isCanonicalPrimaryRun: Bool {
        !probeLocality && workingSetsMB == [256, 512, 1024] && windowSeconds >= 5.0 && trials >= 3
    }

    var fixtureSuffix: String {
        let sets = workingSetsMB.map(String.init).joined(separator: "_")
        let window = String(format: "%.2fs", windowSeconds).replacingOccurrences(of: ".", with: "p")
        return "\(sets)mb_\(trials)x_\(window)"
    }

    static func parse() throws -> RunConfig {
        var config = RunConfig()
        var index = 1
        while index < CommandLine.arguments.count {
            let arg = CommandLine.arguments[index]
            switch arg {
            case "--write-artifact":
                config.writeArtifact = true
            case "--force-write-result":
                config.forceWriteResult = true
            case "--probe-locality":
                config.probeLocality = true
            case "--locality-window-elements":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw PageGatherArtifactError.invalidArgument("--locality-window-elements requires a positive integer")
                }
                config.localityWindowElements = parsed
            case "--locality-block-elements":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw PageGatherArtifactError.invalidArgument("--locality-block-elements requires a positive integer")
                }
                config.localityBlockElements = parsed
            case "--working-sets-mb":
                index += 1
                guard index < CommandLine.arguments.count else {
                    throw PageGatherArtifactError.invalidArgument("--working-sets-mb requires comma-separated values")
                }
                config.workingSetsMB = try CommandLine.arguments[index]
                    .split(separator: ",")
                    .map { value in
                        guard let parsed = Int(value), parsed > 0 else {
                            throw PageGatherArtifactError.invalidArgument("bad working set: \(value)")
                        }
                        return parsed
                    }
            case "--window-seconds":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Double(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw PageGatherArtifactError.invalidArgument("--window-seconds requires a positive number")
                }
                config.windowSeconds = parsed
            case "--trials":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw PageGatherArtifactError.invalidArgument("--trials requires a positive integer")
                }
                config.trials = parsed
            case "--warmup-iterations":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed >= 0 else {
                    throw PageGatherArtifactError.invalidArgument("--warmup-iterations requires a non-negative integer")
                }
                config.warmupIterations = parsed
            default:
                throw PageGatherArtifactError.invalidArgument("unknown argument \(arg)")
            }
            index += 1
        }
        return config
    }
}

struct RunResult {
    let artifact: [String: Any]
    let overallPass: Bool
    let outputPath: String
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = repoRoot.appendingPathComponent("artifacts/falsifiers/page_gather")
let outputResultPath = outputDirectory.appendingPathComponent("result.json").path
let outputFailurePath = outputDirectory.appendingPathComponent("metal_failure_result.json").path
let outputLocalityProbePath = outputDirectory.appendingPathComponent("locality_probe_result.json").path
let actualCommandString = "swift " + CommandLine.arguments.joined(separator: " ")
let fp32Bytes = 4
let pageGatherTrafficBytesPerElement = 12
let pageGatherScheduledTrafficBytesPerElement = 16
let streamTrafficBytesPerElement = 16

let streamShader = """
#include <metal_stdlib>
using namespace metal;

kernel void streamTriad(
    device float* a [[buffer(0)]],
    device const float* b [[buffer(1)]],
    device const float* c [[buffer(2)]],
    constant float& scalar [[buffer(3)]],
    constant uint& count [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= count) {
        return;
    }
    a[gid] = b[gid] + scalar * c[gid];
}
"""

func shell(_ launchPath: String, _ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return "unknown"
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\n", with: " ")
        ?? "unknown"
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
}

func prefixedSHA256(_ data: Data) -> String {
    "sha256:\(sha256Hex(data))"
}

func canonicalDigest(measurements: [String: Any], passPerAxis: [String: Bool]) throws -> String {
    let payload: [String: Any] = [
        "measurements": measurements,
        "pass_per_axis": passPerAxis,
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    return prefixedSHA256(data)
}

func timestampUTC() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: Date())
}

func makeHarness() throws -> Harness {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw PageGatherArtifactError.noMetalDevice
    }
    guard let queue = device.makeCommandQueue() else {
        throw PageGatherArtifactError.noCommandQueue
    }

    let shaderPath = "Epistemos/Shaders/PageGather.metal"
    let shaderURL = repoRoot.appendingPathComponent(shaderPath)
    guard FileManager.default.fileExists(atPath: shaderURL.path) else {
        throw PageGatherArtifactError.missingRepoFile(shaderPath)
    }
    let pageGatherSource = try String(contentsOf: shaderURL, encoding: .utf8)
    let library = try device.makeLibrary(source: pageGatherSource + "\n" + streamShader, options: nil)

    guard let streamFn = library.makeFunction(name: "streamTriad") else {
        throw PageGatherArtifactError.noFunction("streamTriad")
    }
    guard let gatherFn = library.makeFunction(name: "pageGatherScatter") else {
        throw PageGatherArtifactError.noFunction("pageGatherScatter")
    }
    guard let scheduledGatherFn = library.makeFunction(name: "pageGatherScatterScheduled") else {
        throw PageGatherArtifactError.noFunction("pageGatherScatterScheduled")
    }
    do {
        return Harness(
            device: device,
            queue: queue,
            streamTriad: try device.makeComputePipelineState(function: streamFn),
            pageGather: try device.makeComputePipelineState(function: gatherFn),
            pageGatherScheduled: try device.makeComputePipelineState(function: scheduledGatherFn)
        )
    } catch {
        throw PageGatherArtifactError.noPipeline(error.localizedDescription)
    }
}

func makeBuffer(device: MTLDevice, length: Int, label: String) throws -> MTLBuffer {
    guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
        throw PageGatherArtifactError.noBuffer(label)
    }
    buffer.label = label
    return buffer
}

func makeUInt32Buffer(_ value: UInt32, device: MTLDevice, label: String) throws -> MTLBuffer {
    var mutable = value
    guard let buffer = device.makeBuffer(
        bytes: &mutable,
        length: MemoryLayout<UInt32>.stride,
        options: .storageModeShared
    ) else {
        throw PageGatherArtifactError.noBuffer(label)
    }
    buffer.label = label
    return buffer
}

func makeFloatBuffer(_ value: Float, device: MTLDevice, label: String) throws -> MTLBuffer {
    var mutable = value
    guard let buffer = device.makeBuffer(
        bytes: &mutable,
        length: MemoryLayout<Float>.stride,
        options: .storageModeShared
    ) else {
        throw PageGatherArtifactError.noBuffer(label)
    }
    buffer.label = label
    return buffer
}

func sourceValue(_ index: Int) -> Float {
    Float(index % 1_000_003) * 0.0001
}

func initializeFloatBuffer(_ buffer: MTLBuffer, count: Int, offset: Int = 0) {
    let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)
    for index in 0..<count {
        pointer[index] = sourceValue(index + offset)
    }
}

func initializeIdentityIndices(_ buffer: MTLBuffer, count: Int) {
    let pointer = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
    for index in 0..<count {
        pointer[index] = UInt32(index)
    }
}

func xorshift64(_ state: inout UInt64) -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
}

func initializeFisherYatesIndices(_ buffer: MTLBuffer, count: Int, seed: UInt64) {
    let pointer = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
    for index in 0..<count {
        pointer[index] = UInt32(index)
    }
    var state = seed &* 0x9E37_79B9_7F4A_7C15 | 1
    if count > 1 {
        for index in stride(from: count - 1, through: 1, by: -1) {
            let next = xorshift64(&state)
            let swapIndex = Int(next % UInt64(index + 1))
            let tmp = pointer[index]
            pointer[index] = pointer[swapIndex]
            pointer[swapIndex] = tmp
        }
    }
}

func initializeLocalWindowIndices(_ buffer: MTLBuffer, count: Int, windowElements: Int) {
    let pointer = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
    let window = max(1, min(windowElements, count))
    for index in 0..<count {
        pointer[index] = UInt32(index % window)
    }
}

func initializeBlockSortedIndices(
    _ buffer: MTLBuffer,
    count: Int,
    blockElements: Int,
    seed: UInt64
) {
    let pointer = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
    let blockSize = max(1, min(blockElements, count))
    var blockStarts = Array(stride(from: 0, to: count, by: blockSize))
    var state = seed &* 0xD1B5_4A32_D192_ED03 | 1
    if blockStarts.count > 1 {
        for index in stride(from: blockStarts.count - 1, through: 1, by: -1) {
            let next = xorshift64(&state)
            let swapIndex = Int(next % UInt64(index + 1))
            blockStarts.swapAt(index, swapIndex)
        }
    }

    var writeIndex = 0
    for start in blockStarts {
        let end = min(start + blockSize, count)
        for sourceIndex in start..<end {
            pointer[writeIndex] = UInt32(sourceIndex)
            writeIndex += 1
        }
    }
}

func dispatch(
    harness: Harness,
    pipeline: MTLComputePipelineState,
    buffers: [MTLBuffer],
    count: Int
) throws -> Double {
    guard let commandBuffer = harness.queue.makeCommandBuffer() else {
        throw PageGatherArtifactError.noCommandBuffer
    }
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw PageGatherArtifactError.noCommandEncoder
    }
    encoder.setComputePipelineState(pipeline)
    for (index, buffer) in buffers.enumerated() {
        encoder.setBuffer(buffer, offset: 0, index: index)
    }
    let width = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, 256))
    encoder.dispatchThreads(
        MTLSize(width: count, height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
    encoder.endEncoding()

    let start = DispatchTime.now().uptimeNanoseconds
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    let end = DispatchTime.now().uptimeNanoseconds
    if let error = commandBuffer.error {
        throw PageGatherArtifactError.commandFailed(error.localizedDescription)
    }
    return Double(end - start) / 1_000_000_000.0
}

func measure(
    harness: Harness,
    pipeline: MTLComputePipelineState,
    buffers: [MTLBuffer],
    count: Int,
    bytesPerElement: Int,
    windowSeconds: Double,
    warmupIterations: Int,
    trials: Int
) throws -> SampleStats {
    if warmupIterations > 0 {
        for _ in 0..<warmupIterations {
            _ = try dispatch(harness: harness, pipeline: pipeline, buffers: buffers, count: count)
        }
    }

    var samples: [Double] = []
    samples.reserveCapacity(trials)
    for _ in 0..<trials {
        var iterations = 0
        let start = Date()
        repeat {
            _ = try dispatch(harness: harness, pipeline: pipeline, buffers: buffers, count: count)
            iterations += 1
        } while Date().timeIntervalSince(start) < windowSeconds
        let elapsed = Swift.max(Date().timeIntervalSince(start), 1e-9)
        let bytes = Double(iterations * count * bytesPerElement)
        samples.append(bytes / elapsed / 1e9)
    }
    return SampleStats(samples: samples)
}

func sampleViolations(
    source: MTLBuffer,
    indices: MTLBuffer,
    out: MTLBuffer,
    count: Int
) -> Int {
    let sourcePointer = source.contents().bindMemory(to: Float.self, capacity: count)
    let indexPointer = indices.contents().bindMemory(to: UInt32.self, capacity: count)
    let outPointer = out.contents().bindMemory(to: Float.self, capacity: count)
    let sampleCount = min(4096, max(1, count))
    let step = max(1, count / sampleCount)
    var bad = 0
    var index = 0
    while index < count {
        let sourceIndex = Int(indexPointer[index])
        if outPointer[index] != sourcePointer[sourceIndex] {
            bad += 1
        }
        index += step
    }
    return bad
}

func sampleScheduledViolations(
    source: MTLBuffer,
    indices: MTLBuffer,
    logicalPositions: MTLBuffer,
    out: MTLBuffer,
    count: Int
) -> Int {
    let sourcePointer = source.contents().bindMemory(to: Float.self, capacity: count)
    let indexPointer = indices.contents().bindMemory(to: UInt32.self, capacity: count)
    let logicalPositionPointer = logicalPositions.contents().bindMemory(to: UInt32.self, capacity: count)
    let outPointer = out.contents().bindMemory(to: Float.self, capacity: count)
    let sampleCount = min(4096, max(1, count))
    let step = max(1, count / sampleCount)
    var bad = 0
    var index = 0
    while index < count {
        let sourceIndex = Int(indexPointer[index])
        let logicalPosition = Int(logicalPositionPointer[index])
        if outPointer[logicalPosition] != sourcePointer[sourceIndex] {
            bad += 1
        }
        index += step
    }
    return bad
}

func runWorkingSet(config: RunConfig, harness: Harness, mb: Int) throws -> WorkingSetResult {
    let bytes = mb * 1024 * 1024
    let count = bytes / fp32Bytes
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "pageGather.\(mb)mb.count")

    let streamA = try makeBuffer(device: harness.device, length: bytes, label: "pageGather.\(mb)mb.streamA")
    let streamB = try makeBuffer(device: harness.device, length: bytes, label: "pageGather.\(mb)mb.streamB")
    let streamC = try makeBuffer(device: harness.device, length: bytes, label: "pageGather.\(mb)mb.streamC")
    initializeFloatBuffer(streamA, count: count)
    initializeFloatBuffer(streamB, count: count, offset: 17)
    initializeFloatBuffer(streamC, count: count, offset: 31)
    let scalar = try makeFloatBuffer(0.5, device: harness.device, label: "pageGather.\(mb)mb.scalar")

    let stream = try measure(
        harness: harness,
        pipeline: harness.streamTriad,
        buffers: [streamA, streamB, streamC, scalar, countBuffer],
        count: count,
        bytesPerElement: streamTrafficBytesPerElement,
        windowSeconds: config.windowSeconds,
        warmupIterations: config.warmupIterations,
        trials: config.trials
    )

    let source = try makeBuffer(device: harness.device, length: bytes, label: "pageGather.\(mb)mb.source")
    let out = try makeBuffer(device: harness.device, length: bytes, label: "pageGather.\(mb)mb.out")
    let indices = try makeBuffer(device: harness.device, length: count * MemoryLayout<UInt32>.stride, label: "pageGather.\(mb)mb.indices")
    let logicalPositions = try makeBuffer(device: harness.device, length: count * MemoryLayout<UInt32>.stride, label: "pageGather.\(mb)mb.logicalPositions")
    initializeFloatBuffer(source, count: count)

    initializeIdentityIndices(indices, count: count)
    let gather = try measure(
        harness: harness,
        pipeline: harness.pageGather,
        buffers: [source, indices, out, countBuffer],
        count: count,
        bytesPerElement: pageGatherTrafficBytesPerElement,
        windowSeconds: config.windowSeconds,
        warmupIterations: config.warmupIterations,
        trials: config.trials
    )
    let gatherViolations = sampleViolations(source: source, indices: indices, out: out, count: count)

    initializeFisherYatesIndices(indices, count: count, seed: UInt64(mb) ^ 0xBA_7A_C1_5A)
    let scatter = try measure(
        harness: harness,
        pipeline: harness.pageGather,
        buffers: [source, indices, out, countBuffer],
        count: count,
        bytesPerElement: pageGatherTrafficBytesPerElement,
        windowSeconds: config.windowSeconds,
        warmupIterations: config.warmupIterations,
        trials: config.trials
    )
    let scatterViolations = sampleViolations(source: source, indices: indices, out: out, count: count)

    var localWindow: SampleStats?
    var localWindowViolations: Int?
    var blockSorted: SampleStats?
    var blockSortedViolations: Int?

    if config.probeLocality {
        initializeLocalWindowIndices(
            indices,
            count: count,
            windowElements: config.localityWindowElements
        )
        localWindow = try measure(
            harness: harness,
            pipeline: harness.pageGather,
            buffers: [source, indices, out, countBuffer],
            count: count,
            bytesPerElement: pageGatherTrafficBytesPerElement,
            windowSeconds: config.windowSeconds,
            warmupIterations: config.warmupIterations,
            trials: config.trials
        )
        localWindowViolations = sampleViolations(source: source, indices: indices, out: out, count: count)

        initializeBlockSortedIndices(
            indices,
            count: count,
            blockElements: config.localityBlockElements,
            seed: UInt64(mb) ^ 0xB10C_50A7
        )
        initializeFisherYatesIndices(
            logicalPositions,
            count: count,
            seed: UInt64(mb) ^ 0xD35A_D05E
        )
        blockSorted = try measure(
            harness: harness,
            pipeline: harness.pageGatherScheduled,
            buffers: [source, indices, logicalPositions, out, countBuffer],
            count: count,
            bytesPerElement: pageGatherScheduledTrafficBytesPerElement,
            windowSeconds: config.windowSeconds,
            warmupIterations: config.warmupIterations,
            trials: config.trials
        )
        blockSortedViolations = sampleScheduledViolations(
            source: source,
            indices: indices,
            logicalPositions: logicalPositions,
            out: out,
            count: count
        )
    }

    return WorkingSetResult(
        mb: mb,
        stream: stream,
        gather: gather,
        scatter: scatter,
        localWindow: localWindow,
        blockSorted: blockSorted,
        gatherViolations: gatherViolations,
        scatterViolations: scatterViolations,
        localWindowViolations: localWindowViolations,
        blockSortedViolations: blockSortedViolations
    )
}

func metric(_ value: Any, unit: String) -> [String: Any] {
    ["value": value, "unit": unit]
}

func threshold(_ op: String, _ value: Any, unit: String) -> [String: Any] {
    ["operator": op, "value": value, "unit": unit]
}

func addAxis(
    name: String,
    value: Any,
    unit: String,
    op: String,
    thresholdValue: Any,
    pass: Bool,
    measurements: inout [String: Any],
    thresholds: inout [String: Any],
    passPerAxis: inout [String: Bool]
) {
    measurements[name] = metric(value, unit: unit)
    thresholds[name] = threshold(op, thresholdValue, unit: unit)
    passPerAxis[name] = pass
}

func runArtifact(config: RunConfig) throws -> RunResult {
    let started = Date()
    let harness = try makeHarness()
    var results: [WorkingSetResult] = []
    results.reserveCapacity(config.workingSetsMB.count)

    for mb in config.workingSetsMB {
        fputs("running PageGather Metal working set \(mb) MB\n", stderr)
        results.append(try runWorkingSet(config: config, harness: harness, mb: mb))
    }

    var measurements: [String: Any] = [:]
    var thresholds: [String: Any] = [:]
    var passPerAxis: [String: Bool] = [:]

    for result in results {
        let mb = result.mb
        let stream = result.stream.median
        let gather = result.gather.median
        let scatter = result.scatter.median
        let gatherRatio = stream > 0 ? gather / stream : 0
        let scatterRatio = stream > 0 ? scatter / stream : 0

        addAxis(
            name: "stream_triad_gbs_\(mb)mb",
            value: stream,
            unit: "GB_per_second",
            op: ">",
            thresholdValue: 0,
            pass: stream > 0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "gather_gbs_\(mb)mb",
            value: gather,
            unit: "GB_per_second",
            op: ">",
            thresholdValue: 0,
            pass: gather > 0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "scatter_gbs_\(mb)mb",
            value: scatter,
            unit: "GB_per_second",
            op: ">",
            thresholdValue: 0,
            pass: scatter > 0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "gather_stream_ratio_\(mb)mb",
            value: gatherRatio,
            unit: "ratio",
            op: ">=",
            thresholdValue: 0.95,
            pass: gatherRatio >= 0.95,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "scatter_stream_ratio_\(mb)mb",
            value: scatterRatio,
            unit: "ratio",
            op: ">=",
            thresholdValue: 0.70,
            pass: scatterRatio >= 0.70,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "gather_correctness_violations_\(mb)mb",
            value: result.gatherViolations,
            unit: "violations",
            op: "==",
            thresholdValue: 0,
            pass: result.gatherViolations == 0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "scatter_correctness_violations_\(mb)mb",
            value: result.scatterViolations,
            unit: "violations",
            op: "==",
            thresholdValue: 0,
            pass: result.scatterViolations == 0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "scatter_stability_range_over_mean_\(mb)mb",
            value: result.scatter.rangeOverMean,
            unit: "ratio",
            op: "<",
            thresholdValue: 0.15,
            pass: result.scatter.rangeOverMean < 0.15,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "scatter_second_run_ratio_\(mb)mb",
            value: result.scatter.secondRunRatio,
            unit: "ratio",
            op: ">=",
            thresholdValue: 0.90,
            pass: result.scatter.secondRunRatio >= 0.90,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )

        measurements["stream_samples_gbs_\(mb)mb"] = metric(result.stream.samples, unit: "GB_per_second")
        measurements["gather_samples_gbs_\(mb)mb"] = metric(result.gather.samples, unit: "GB_per_second")
        measurements["scatter_samples_gbs_\(mb)mb"] = metric(result.scatter.samples, unit: "GB_per_second")

        if let localWindow = result.localWindow,
           let localWindowViolations = result.localWindowViolations {
            let localWindowValue = localWindow.median
            let localWindowRatio = stream > 0 ? localWindowValue / stream : 0
            addAxis(
                name: "local_window_gbs_\(mb)mb",
                value: localWindowValue,
                unit: "GB_per_second",
                op: ">",
                thresholdValue: 0,
                pass: localWindowValue > 0,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            addAxis(
                name: "local_window_stream_ratio_\(mb)mb",
                value: localWindowRatio,
                unit: "ratio",
                op: ">=",
                thresholdValue: 0.70,
                pass: localWindowRatio >= 0.70,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            addAxis(
                name: "local_window_correctness_violations_\(mb)mb",
                value: localWindowViolations,
                unit: "violations",
                op: "==",
                thresholdValue: 0,
                pass: localWindowViolations == 0,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            addAxis(
                name: "local_window_stability_range_over_mean_\(mb)mb",
                value: localWindow.rangeOverMean,
                unit: "ratio",
                op: "<",
                thresholdValue: 0.15,
                pass: localWindow.rangeOverMean < 0.15,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            measurements["local_window_samples_gbs_\(mb)mb"] = metric(localWindow.samples, unit: "GB_per_second")
        }

        if let blockSorted = result.blockSorted,
           let blockSortedViolations = result.blockSortedViolations {
            let blockSortedValue = blockSorted.median
            let blockSortedRatio = stream > 0 ? blockSortedValue / stream : 0
            addAxis(
                name: "block_sorted_scheduled_scatter_gbs_\(mb)mb",
                value: blockSortedValue,
                unit: "GB_per_second",
                op: ">",
                thresholdValue: 0,
                pass: blockSortedValue > 0,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            addAxis(
                name: "block_sorted_scheduled_scatter_stream_ratio_\(mb)mb",
                value: blockSortedRatio,
                unit: "ratio",
                op: ">=",
                thresholdValue: 0.70,
                pass: blockSortedRatio >= 0.70,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            addAxis(
                name: "block_sorted_scheduled_scatter_correctness_violations_\(mb)mb",
                value: blockSortedViolations,
                unit: "violations",
                op: "==",
                thresholdValue: 0,
                pass: blockSortedViolations == 0,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            addAxis(
                name: "block_sorted_scheduled_scatter_stability_range_over_mean_\(mb)mb",
                value: blockSorted.rangeOverMean,
                unit: "ratio",
                op: "<",
                thresholdValue: 0.15,
                pass: blockSorted.rangeOverMean < 0.15,
                measurements: &measurements,
                thresholds: &thresholds,
                passPerAxis: &passPerAxis
            )
            measurements["block_sorted_scheduled_scatter_samples_gbs_\(mb)mb"] = metric(blockSorted.samples, unit: "GB_per_second")
        }
    }

    let elapsed = Date().timeIntervalSince(started)
    measurements["harness_wall_clock_seconds"] = metric(elapsed, unit: "seconds")
    measurements["window_seconds"] = metric(config.windowSeconds, unit: "seconds")
    measurements["trial_count"] = metric(config.trials, unit: "count")
    measurements["warmup_iterations"] = metric(config.warmupIterations, unit: "count")
    measurements["probe_locality_enabled"] = metric(config.probeLocality, unit: "bool")
    measurements["locality_window_elements"] = metric(config.localityWindowElements, unit: "elements")
    measurements["locality_block_elements"] = metric(config.localityBlockElements, unit: "elements")

    let axesPass = passPerAxis.values.allSatisfy { $0 }
    let overallPass = axesPass && config.isCanonicalPrimaryRun
    let artifactKind: String
    let fallbackTier: String
    if overallPass {
        artifactKind = "primary_witness"
        fallbackTier = "Primary"
    } else if axesPass {
        artifactKind = "fallback_witness"
        fallbackTier = "Fallback"
    } else {
        artifactKind = "failure_report"
        fallbackTier = "Fail"
    }
    let outputPath: String
    if config.probeLocality {
        outputPath = outputLocalityProbePath
    } else {
        outputPath = overallPass || config.forceWriteResult ? outputResultPath : outputFailurePath
    }

    var anomalies: [[String: String]] = []
    if !axesPass {
        anomalies.append([
            "kind": "page_gather_metal_gate_failed",
            "detail": "The Metal PageGather witness failed at least one ratio, correctness, or stability axis. Do not promote F-PageGather-M2Pro; inspect metal_failure_result.json.",
        ])
    }
    if axesPass && !config.isCanonicalPrimaryRun {
        anomalies.append([
            "kind": "noncanonical_probe",
            "detail": "This run passed its measured axes but did not use the canonical 256/512/1024 MB, >=5s, >=3-trial gate. It is not a primary witness.",
        ])
    }
    if config.probeLocality {
        anomalies.append([
            "kind": "locality_probe",
            "detail": "Diagnostic run includes local-window and block-sorted scheduled scatter candidates. It cannot promote F-PageGather-M2Pro by itself.",
        ])
    }

    let commit = shell("/usr/bin/git", ["rev-parse", "HEAD"])
    let swiftVersion = shell("/usr/bin/swift", ["--version"])
    let xcodeVersion = shell("/usr/bin/xcodebuild", ["-version"])
    let osBuild = shell("/usr/bin/sw_vers", ["-buildVersion"])
    let resultDigest = try canonicalDigest(measurements: measurements, passPerAxis: passPerAxis)

    let artifact: [String: Any] = [
        "falsifier_id": "F-PageGather-M2Pro",
        "schema_version": "2026-05-18.2",
        "artifact_kind": artifactKind,
        "hardware_pin": [
            "machine": "M2 Pro 14-inch 2023",
            "cpu": "12-core CPU",
            "gpu": "19-core GPU",
            "unified_memory_gb": 16,
            "memory_bandwidth_gb_s": 200,
        ],
        "command": actualCommandString,
        "command_digest": prefixedSHA256(Data(actualCommandString.utf8)),
        "runner_environment": [
            "cwd": "repo_root",
            "shell": "zsh",
            "env_policy": "script_owned",
            "locale": "C",
            "timezone": "UTC",
            "os_build": "Darwin \(osBuild)",
            "toolchain_identity": [
                "xcodebuild": xcodeVersion,
                "swift": swiftVersion,
                "rustc": "not_used",
                "python": "not_used",
            ],
            "thermal_state_start": "unknown",
            "thermal_state_end": "unknown",
            "power_source": "unknown",
        ],
        "commit_sha": commit,
        "fixture_id": "page_gather_metal_stream_scatter_\(config.fixtureSuffix)\(config.probeLocality ? "_locality_probe" : "")_v1",
        "timestamp_utc": timestampUTC(),
        "result_digest": resultDigest,
        "measurements": measurements,
        "acceptance_thresholds": thresholds,
        "pass_per_axis": passPerAxis,
        "overall_pass": axesPass,
        "fallback_tier": fallbackTier,
        "anomalies": anomalies,
        "notes": "Metal PageGather witness generated from Epistemos/Shaders/PageGather.metal with an in-harness STREAM triad baseline. Ratios use measured traffic bytes (STREAM=16 bytes/element; PageGather=12 bytes/element; scheduled PageGather=16 bytes/element). result.json is written only on full pass; failed primary runs write metal_failure_result.json unless --force-write-result is explicitly supplied. --probe-locality writes locality_probe_result.json and is diagnostic only.",
    ]

    return RunResult(artifact: artifact, overallPass: overallPass, outputPath: outputPath)
}

func writeArtifact(_ artifact: [String: Any], to path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: artifact, options: [.prettyPrinted, .sortedKeys])
    guard var text = String(data: data, encoding: .utf8) else {
        throw PageGatherArtifactError.jsonEncoding
    }
    text.append("\n")
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}

do {
    let config = try RunConfig.parse()
    let result = try runArtifact(config: config)
    let data = try JSONSerialization.data(withJSONObject: result.artifact, options: [.prettyPrinted, .sortedKeys])
    let summary = String(data: data, encoding: .utf8) ?? "{}"
    if config.writeArtifact {
        try writeArtifact(result.artifact, to: result.outputPath)
        fputs("wrote \(result.outputPath)\n", stderr)
    } else {
        Swift.print(summary)
    }
    if !result.overallPass {
        exit(2)
    }
} catch {
    fputs("page-gather-metal-artifact failed: \(error)\n", stderr)
    exit(1)
}
