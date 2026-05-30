#!/usr/bin/env swift

import CryptoKit
import Foundation
import Metal

enum ControllerArtifactError: Error, CustomStringConvertible {
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

enum ControllerKernel: String, CaseIterable {
    case scalarAddInPlace
    case scalarMulInPlace
    case maxReduce
    case argmaxReduce
    case copyRange
    case zeroFill
}

struct Harness {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipelines: [ControllerKernel: MTLComputePipelineState]
}

struct SampleStats {
    let samples: [Double]

    var p50: Double { percentile(0.50) }
    var p99: Double { percentile(0.99) }
    var min: Double { samples.min() ?? 0 }
    var max: Double { samples.max() ?? 0 }
    var mean: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }

    func percentile(_ p: Double) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let clamped = Swift.min(Swift.max(p, 0), 1)
        let index = Int((Double(sorted.count - 1) * clamped).rounded(.up))
        return sorted[Swift.min(Swift.max(index, 0), sorted.count - 1)]
    }
}

struct RunConfig {
    var sizes = [1, 16, 64, 256, 1_024, 4_096, 16_384]
    var correctnessSeeds = 100
    var perfSize = 4_096
    var warmupIterations = 100
    var timedIterations = 1_000
    var sequenceIterations = 100
    var writeArtifact = false
    var forceWriteResult = false

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
            case "--sizes":
                index += 1
                guard index < CommandLine.arguments.count else {
                    throw ControllerArtifactError.invalidArgument("--sizes requires comma-separated integers")
                }
                config.sizes = try CommandLine.arguments[index].split(separator: ",").map { value in
                    guard let parsed = Int(value), parsed > 0 else {
                        throw ControllerArtifactError.invalidArgument("bad size: \(value)")
                    }
                    return parsed
                }
            case "--correctness-seeds":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw ControllerArtifactError.invalidArgument("--correctness-seeds requires a positive integer")
                }
                config.correctnessSeeds = parsed
            case "--perf-size":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw ControllerArtifactError.invalidArgument("--perf-size requires a positive integer")
                }
                config.perfSize = parsed
            case "--warmup-iterations":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed >= 0 else {
                    throw ControllerArtifactError.invalidArgument("--warmup-iterations requires a non-negative integer")
                }
                config.warmupIterations = parsed
            case "--timed-iterations":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw ControllerArtifactError.invalidArgument("--timed-iterations requires a positive integer")
                }
                config.timedIterations = parsed
            case "--sequence-iterations":
                index += 1
                guard index < CommandLine.arguments.count,
                      let parsed = Int(CommandLine.arguments[index]),
                      parsed > 0 else {
                    throw ControllerArtifactError.invalidArgument("--sequence-iterations requires a positive integer")
                }
                config.sequenceIterations = parsed
            default:
                throw ControllerArtifactError.invalidArgument("unknown argument \(arg)")
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

struct DispatchTiming {
    let wallUs: Double
    let gpuUs: Double?

    var measuredUs: Double {
        gpuUs ?? wallUs
    }
}

struct SequenceTiming {
    let wallMs: Double
    let gpuMs: Double?
}

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = repoRoot.appendingPathComponent("artifacts/falsifiers/controller_kernel_pack")
let outputResultPath = outputDirectory.appendingPathComponent("result.json").path
let outputFailurePath = outputDirectory.appendingPathComponent("metal_failure_result.json").path
let commandString = "swift " + CommandLine.arguments.joined(separator: " ")
let perKernelDispatchesPerSample = 32
let perKernelReplicatesPerSample = 3

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
        throw ControllerArtifactError.noMetalDevice
    }
    guard let queue = device.makeCommandQueue() else {
        throw ControllerArtifactError.noCommandQueue
    }

    let shaderPath = "Epistemos/Shaders/ControllerKernelPack.metal"
    let shaderURL = repoRoot.appendingPathComponent(shaderPath)
    guard FileManager.default.fileExists(atPath: shaderURL.path) else {
        throw ControllerArtifactError.missingRepoFile(shaderPath)
    }
    let source = try String(contentsOf: shaderURL, encoding: .utf8)
    let library = try device.makeLibrary(source: source, options: nil)

    var pipelines: [ControllerKernel: MTLComputePipelineState] = [:]
    for kernel in ControllerKernel.allCases {
        guard let function = library.makeFunction(name: kernel.rawValue) else {
            throw ControllerArtifactError.noFunction(kernel.rawValue)
        }
        do {
            pipelines[kernel] = try device.makeComputePipelineState(function: function)
        } catch {
            throw ControllerArtifactError.noPipeline("\(kernel.rawValue): \(error.localizedDescription)")
        }
    }
    return Harness(device: device, queue: queue, pipelines: pipelines)
}

func makeBuffer<T>(_ values: [T], device: MTLDevice, label: String) throws -> MTLBuffer {
    try values.withUnsafeBufferPointer { pointer in
        guard let baseAddress = pointer.baseAddress else {
            throw ControllerArtifactError.noBuffer(label)
        }
        guard let buffer = device.makeBuffer(
            bytes: baseAddress,
            length: values.count * MemoryLayout<T>.stride,
            options: .storageModeShared
        ) else {
            throw ControllerArtifactError.noBuffer(label)
        }
        buffer.label = label
        return buffer
    }
}

func makeZeroedBuffer<T>(type: T.Type, count: Int, device: MTLDevice, label: String) throws -> MTLBuffer {
    guard let buffer = device.makeBuffer(
        length: max(1, count) * MemoryLayout<T>.stride,
        options: .storageModeShared
    ) else {
        throw ControllerArtifactError.noBuffer(label)
    }
    memset(buffer.contents(), 0, max(1, count) * MemoryLayout<T>.stride)
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
        throw ControllerArtifactError.noBuffer(label)
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
        throw ControllerArtifactError.noBuffer(label)
    }
    buffer.label = label
    return buffer
}

func readArray<T>(_ buffer: MTLBuffer, count: Int, as type: T.Type) -> [T] {
    let pointer = buffer.contents().bindMemory(to: T.self, capacity: count)
    return Array(UnsafeBufferPointer(start: pointer, count: count))
}

func xorshift64(_ state: inout UInt64) -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
}

func fixtureArray(size: Int, seed: Int) -> [Float] {
    var state = UInt64(seed + 1) &* 0x9E37_79B9_7F4A_7C15
    var values: [Float] = []
    values.reserveCapacity(size)
    for index in 0..<size {
        let next = xorshift64(&state)
        let centered = Int64(bitPattern: next) % 2_000
        values.append(Float(centered) / 37.0 + Float(index % 17) * 0.125)
    }
    if size >= 4 {
        let duplicateMax = Float(2_000 + seed)
        values[1] = duplicateMax
        values[size - 1] = duplicateMax
    }
    return values
}

func scalarFor(seed: Int, kernel: ControllerKernel) -> Float {
    switch kernel {
    case .scalarAddInPlace:
        return Float((seed % 11) - 5) / 8.0
    case .scalarMulInPlace:
        return 0.75 + Float(seed % 13) / 16.0
    default:
        return 1.0
    }
}

func dispatch(
    harness: Harness,
    kernel: ControllerKernel,
    buffers: [MTLBuffer],
    threads: Int
) throws -> DispatchTiming {
    guard let pipeline = harness.pipelines[kernel] else {
        throw ControllerArtifactError.noFunction(kernel.rawValue)
    }
    guard let commandBuffer = harness.queue.makeCommandBuffer() else {
        throw ControllerArtifactError.noCommandBuffer
    }
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw ControllerArtifactError.noCommandEncoder
    }
    encodeDispatch(encoder: encoder, pipeline: pipeline, buffers: buffers, threads: threads)
    encoder.endEncoding()
    let start = DispatchTime.now().uptimeNanoseconds
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    let end = DispatchTime.now().uptimeNanoseconds
    if let error = commandBuffer.error {
        throw ControllerArtifactError.commandFailed(error.localizedDescription)
    }
    let gpuSeconds = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    let gpuUs = gpuSeconds > 0 ? gpuSeconds * 1_000_000.0 : nil
    return DispatchTiming(wallUs: Double(end - start) / 1_000.0, gpuUs: gpuUs)
}

func dispatchBatch(
    harness: Harness,
    kernel: ControllerKernel,
    buffers: [MTLBuffer],
    threads: Int,
    repeats: Int
) throws -> DispatchTiming {
    guard repeats > 0 else {
        throw ControllerArtifactError.invalidArgument("dispatchBatch repeats must be positive")
    }
    guard let pipeline = harness.pipelines[kernel] else {
        throw ControllerArtifactError.noFunction(kernel.rawValue)
    }
    guard let commandBuffer = harness.queue.makeCommandBuffer() else {
        throw ControllerArtifactError.noCommandBuffer
    }
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw ControllerArtifactError.noCommandEncoder
    }
    for _ in 0..<repeats {
        encodeDispatch(encoder: encoder, pipeline: pipeline, buffers: buffers, threads: threads)
    }
    encoder.endEncoding()
    let start = DispatchTime.now().uptimeNanoseconds
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    let end = DispatchTime.now().uptimeNanoseconds
    if let error = commandBuffer.error {
        throw ControllerArtifactError.commandFailed(error.localizedDescription)
    }
    let gpuSeconds = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    let divisor = Double(repeats)
    let gpuUs = gpuSeconds > 0 ? gpuSeconds * 1_000_000.0 / divisor : nil
    return DispatchTiming(wallUs: Double(end - start) / 1_000.0 / divisor, gpuUs: gpuUs)
}

func encodeDispatch(
    encoder: MTLComputeCommandEncoder,
    pipeline: MTLComputePipelineState,
    buffers: [MTLBuffer],
    threads: Int
) {
    encoder.setComputePipelineState(pipeline)
    for (index, buffer) in buffers.enumerated() {
        encoder.setBuffer(buffer, offset: 0, index: index)
    }
    let width = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, 256))
    encoder.dispatchThreads(
        MTLSize(width: max(1, threads), height: 1, depth: 1),
        threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
}

func almostEqual(_ lhs: Float, _ rhs: Float) -> Bool {
    if lhs.isNaN && rhs.isNaN { return true }
    return lhs == rhs
}

func countMismatches(_ lhs: [Float], _ rhs: [Float]) -> Int {
    zip(lhs, rhs).reduce(0) { total, pair in
        total + (almostEqual(pair.0, pair.1) ? 0 : 1)
    } + abs(lhs.count - rhs.count)
}

func runAddFixture(harness: Harness, input: [Float], scalar: Float) throws -> Int {
    let count = input.count
    let buffer = try makeBuffer(input, device: harness.device, label: "controller.add.fixture")
    let scalarBuffer = try makeFloatBuffer(scalar, device: harness.device, label: "controller.add.scalar")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.add.count")
    _ = try dispatch(harness: harness, kernel: .scalarAddInPlace, buffers: [buffer, scalarBuffer, countBuffer], threads: count)
    return countMismatches(readArray(buffer, count: count, as: Float.self), input.map { $0 + scalar })
}

func runMulFixture(harness: Harness, input: [Float], scalar: Float) throws -> Int {
    let count = input.count
    let buffer = try makeBuffer(input, device: harness.device, label: "controller.mul.fixture")
    let scalarBuffer = try makeFloatBuffer(scalar, device: harness.device, label: "controller.mul.scalar")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.mul.count")
    _ = try dispatch(harness: harness, kernel: .scalarMulInPlace, buffers: [buffer, scalarBuffer, countBuffer], threads: count)
    return countMismatches(readArray(buffer, count: count, as: Float.self), input.map { $0 * scalar })
}

func runMaxFixture(harness: Harness, input: [Float]) throws -> Int {
    let count = input.count
    let inputBuffer = try makeBuffer(input, device: harness.device, label: "controller.max.fixture")
    let out = try makeZeroedBuffer(type: Float.self, count: 1, device: harness.device, label: "controller.max.out")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.max.count")
    _ = try dispatch(harness: harness, kernel: .maxReduce, buffers: [inputBuffer, out, countBuffer], threads: 256)
    let observed = readArray(out, count: 1, as: Float.self)[0]
    let expected = input.max() ?? Float.nan
    return almostEqual(observed, expected) ? 0 : 1
}

func runArgmaxFixture(harness: Harness, input: [Float]) throws -> Int {
    let count = input.count
    let inputBuffer = try makeBuffer(input, device: harness.device, label: "controller.argmax.fixture")
    let out = try makeZeroedBuffer(type: UInt32.self, count: 1, device: harness.device, label: "controller.argmax.out")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.argmax.count")
    _ = try dispatch(harness: harness, kernel: .argmaxReduce, buffers: [inputBuffer, out, countBuffer], threads: 256)
    let observed = readArray(out, count: 1, as: UInt32.self)[0]
    let expected = input.enumerated().max(by: { $0.element < $1.element })?.offset ?? Int(UInt32.max)
    return observed == UInt32(expected) ? 0 : 1
}

func runCopyFixture(harness: Harness, input: [Float]) throws -> Int {
    let count = input.count
    let src = try makeBuffer(input, device: harness.device, label: "controller.copy.src")
    let dst = try makeZeroedBuffer(type: Float.self, count: count, device: harness.device, label: "controller.copy.dst")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.copy.count")
    _ = try dispatch(harness: harness, kernel: .copyRange, buffers: [src, dst, countBuffer], threads: count)
    return countMismatches(readArray(dst, count: count, as: Float.self), input)
}

func runZeroFixture(harness: Harness, input: [Float]) throws -> Int {
    let count = input.count
    let buffer = try makeBuffer(input, device: harness.device, label: "controller.zero.fixture")
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.zero.count")
    _ = try dispatch(harness: harness, kernel: .zeroFill, buffers: [buffer, countBuffer], threads: count)
    return countMismatches(readArray(buffer, count: count, as: Float.self), Array(repeating: 0, count: count))
}

func runCorrectness(config: RunConfig, harness: Harness) throws -> [String: Int] {
    var violations: [String: Int] = Dictionary(uniqueKeysWithValues: ControllerKernel.allCases.map { ($0.rawValue, 0) })
    for size in config.sizes {
        for seed in 0..<config.correctnessSeeds {
            let input = fixtureArray(size: size, seed: seed)
            violations[ControllerKernel.scalarAddInPlace.rawValue, default: 0] +=
                try runAddFixture(harness: harness, input: input, scalar: scalarFor(seed: seed, kernel: .scalarAddInPlace))
            violations[ControllerKernel.scalarMulInPlace.rawValue, default: 0] +=
                try runMulFixture(harness: harness, input: input, scalar: scalarFor(seed: seed, kernel: .scalarMulInPlace))
            violations[ControllerKernel.maxReduce.rawValue, default: 0] +=
                try runMaxFixture(harness: harness, input: input)
            violations[ControllerKernel.argmaxReduce.rawValue, default: 0] +=
                try runArgmaxFixture(harness: harness, input: input)
            violations[ControllerKernel.copyRange.rawValue, default: 0] +=
                try runCopyFixture(harness: harness, input: input)
            violations[ControllerKernel.zeroFill.rawValue, default: 0] +=
                try runZeroFixture(harness: harness, input: input)
        }
    }
    return violations
}

func runEmptyContracts(harness: Harness) throws -> (maxIsNaN: Bool, argmaxIsSentinel: Bool) {
    let input = try makeZeroedBuffer(type: Float.self, count: 1, device: harness.device, label: "controller.empty.input")
    let countBuffer = try makeUInt32Buffer(0, device: harness.device, label: "controller.empty.count")
    let maxOut = try makeZeroedBuffer(type: Float.self, count: 1, device: harness.device, label: "controller.empty.maxOut")
    _ = try dispatch(harness: harness, kernel: .maxReduce, buffers: [input, maxOut, countBuffer], threads: 256)
    let maxValue = readArray(maxOut, count: 1, as: Float.self)[0]

    let argmaxOut = try makeZeroedBuffer(type: UInt32.self, count: 1, device: harness.device, label: "controller.empty.argmaxOut")
    _ = try dispatch(harness: harness, kernel: .argmaxReduce, buffers: [input, argmaxOut, countBuffer], threads: 256)
    let argmaxValue = readArray(argmaxOut, count: 1, as: UInt32.self)[0]
    return (maxValue.isNaN, argmaxValue == UInt32.max)
}

func perfBuffers(kernel: ControllerKernel, harness: Harness, count: Int) throws -> ([MTLBuffer], Int) {
    let input = fixtureArray(size: count, seed: 0xC0DE)
    let countBuffer = try makeUInt32Buffer(UInt32(count), device: harness.device, label: "controller.perf.count")
    switch kernel {
    case .scalarAddInPlace:
        return ([
            try makeBuffer(input, device: harness.device, label: "controller.perf.add"),
            try makeFloatBuffer(0.125, device: harness.device, label: "controller.perf.addScalar"),
            countBuffer,
        ], count)
    case .scalarMulInPlace:
        return ([
            try makeBuffer(input, device: harness.device, label: "controller.perf.mul"),
            try makeFloatBuffer(1.0001, device: harness.device, label: "controller.perf.mulScalar"),
            countBuffer,
        ], count)
    case .maxReduce:
        return ([
            try makeBuffer(input, device: harness.device, label: "controller.perf.maxInput"),
            try makeZeroedBuffer(type: Float.self, count: 1, device: harness.device, label: "controller.perf.maxOut"),
            countBuffer,
        ], 256)
    case .argmaxReduce:
        return ([
            try makeBuffer(input, device: harness.device, label: "controller.perf.argmaxInput"),
            try makeZeroedBuffer(type: UInt32.self, count: 1, device: harness.device, label: "controller.perf.argmaxOut"),
            countBuffer,
        ], 256)
    case .copyRange:
        return ([
            try makeBuffer(input, device: harness.device, label: "controller.perf.copySrc"),
            try makeZeroedBuffer(type: Float.self, count: count, device: harness.device, label: "controller.perf.copyDst"),
            countBuffer,
        ], count)
    case .zeroFill:
        return ([
            try makeBuffer(input, device: harness.device, label: "controller.perf.zero"),
            countBuffer,
        ], count)
    }
}

func measureKernel(harness: Harness, kernel: ControllerKernel, config: RunConfig) throws -> SampleStats {
    let (buffers, threads) = try perfBuffers(kernel: kernel, harness: harness, count: config.perfSize)
    if config.warmupIterations > 0 {
        for _ in 0..<config.warmupIterations {
            _ = try dispatchBatch(
                harness: harness,
                kernel: kernel,
                buffers: buffers,
                threads: threads,
                repeats: perKernelDispatchesPerSample
            )
        }
    }
    var samples: [Double] = []
    samples.reserveCapacity(config.timedIterations)
    for _ in 0..<config.timedIterations {
        var replicates: [Double] = []
        replicates.reserveCapacity(perKernelReplicatesPerSample)
        for _ in 0..<perKernelReplicatesPerSample {
            replicates.append(try dispatchBatch(
                harness: harness,
                kernel: kernel,
                buffers: buffers,
                threads: threads,
                repeats: perKernelDispatchesPerSample
            ).measuredUs)
        }
        samples.append(replicates.sorted()[perKernelReplicatesPerSample / 2])
    }
    return SampleStats(samples: samples)
}

func measureSequence(harness: Harness, config: RunConfig) throws -> SequenceTiming {
    let input = fixtureArray(size: config.perfSize, seed: 0x51E6)
    let countBuffer = try makeUInt32Buffer(UInt32(config.perfSize), device: harness.device, label: "controller.seq.count")
    let scalarAdd = try makeFloatBuffer(0.1, device: harness.device, label: "controller.seq.addScalar")
    let scalarMul = try makeFloatBuffer(1.001, device: harness.device, label: "controller.seq.mulScalar")
    let a = try makeBuffer(input, device: harness.device, label: "controller.seq.a")
    let copySrc = try makeBuffer(input.reversed(), device: harness.device, label: "controller.seq.copySrc")
    let copyDst = try makeZeroedBuffer(type: Float.self, count: config.perfSize, device: harness.device, label: "controller.seq.copyDst")
    let maxOut = try makeZeroedBuffer(type: Float.self, count: 1, device: harness.device, label: "controller.seq.maxOut")
    let argmaxOut = try makeZeroedBuffer(type: UInt32.self, count: 1, device: harness.device, label: "controller.seq.argmaxOut")

    guard let commandBuffer = harness.queue.makeCommandBuffer() else {
        throw ControllerArtifactError.noCommandBuffer
    }
    guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
        throw ControllerArtifactError.noCommandEncoder
    }
    guard let addPipeline = harness.pipelines[.scalarAddInPlace],
          let mulPipeline = harness.pipelines[.scalarMulInPlace],
          let maxPipeline = harness.pipelines[.maxReduce],
          let argmaxPipeline = harness.pipelines[.argmaxReduce],
          let copyPipeline = harness.pipelines[.copyRange],
          let zeroPipeline = harness.pipelines[.zeroFill] else {
        throw ControllerArtifactError.noFunction("sequence pipeline")
    }

    let started = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<config.sequenceIterations {
        encodeDispatch(encoder: encoder, pipeline: addPipeline, buffers: [a, scalarAdd, countBuffer], threads: config.perfSize)
        encodeDispatch(encoder: encoder, pipeline: mulPipeline, buffers: [a, scalarMul, countBuffer], threads: config.perfSize)
        encodeDispatch(encoder: encoder, pipeline: maxPipeline, buffers: [a, maxOut, countBuffer], threads: 256)
        encodeDispatch(encoder: encoder, pipeline: argmaxPipeline, buffers: [a, argmaxOut, countBuffer], threads: 256)
        encodeDispatch(encoder: encoder, pipeline: copyPipeline, buffers: [copySrc, copyDst, countBuffer], threads: config.perfSize)
        encodeDispatch(encoder: encoder, pipeline: zeroPipeline, buffers: [a, countBuffer], threads: config.perfSize)
    }
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    let ended = DispatchTime.now().uptimeNanoseconds
    if let error = commandBuffer.error {
        throw ControllerArtifactError.commandFailed(error.localizedDescription)
    }
    let gpuSeconds = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
    let gpuMs = gpuSeconds > 0 ? gpuSeconds * 1_000.0 : nil
    return SequenceTiming(wallMs: Double(ended - started) / 1_000_000.0, gpuMs: gpuMs)
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
    let violations = try runCorrectness(config: config, harness: harness)
    let emptyContracts = try runEmptyContracts(harness: harness)

    var stats: [ControllerKernel: SampleStats] = [:]
    for kernel in ControllerKernel.allCases {
        fputs("measuring \(kernel.rawValue)\n", stderr)
        stats[kernel] = try measureKernel(harness: harness, kernel: kernel, config: config)
    }
    let sequenceTiming = try measureSequence(harness: harness, config: config)

    var measurements: [String: Any] = [:]
    var thresholds: [String: Any] = [:]
    var passPerAxis: [String: Bool] = [:]

    var totalViolations = 0
    for kernel in ControllerKernel.allCases {
        let value = violations[kernel.rawValue, default: 0]
        totalViolations += value
        addAxis(
            name: "\(kernel.rawValue)_correctness_violations",
            value: value,
            unit: "count",
            op: "==",
            thresholdValue: 0,
            pass: value == 0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
    }

    addAxis(
        name: "correctness_violations_total",
        value: totalViolations,
        unit: "count",
        op: "==",
        thresholdValue: 0,
        pass: totalViolations == 0,
        measurements: &measurements,
        thresholds: &thresholds,
        passPerAxis: &passPerAxis
    )
    addAxis(
        name: "max_reduce_empty_returns_nan",
        value: emptyContracts.maxIsNaN,
        unit: "bool",
        op: "==",
        thresholdValue: true,
        pass: emptyContracts.maxIsNaN,
        measurements: &measurements,
        thresholds: &thresholds,
        passPerAxis: &passPerAxis
    )
    addAxis(
        name: "argmax_reduce_empty_returns_uint_max",
        value: emptyContracts.argmaxIsSentinel,
        unit: "bool",
        op: "==",
        thresholdValue: true,
        pass: emptyContracts.argmaxIsSentinel,
        measurements: &measurements,
        thresholds: &thresholds,
        passPerAxis: &passPerAxis
    )

    for kernel in ControllerKernel.allCases {
        guard let stat = stats[kernel] else { continue }
        let prefix = kernel.rawValue
        addAxis(
            name: "\(prefix)_p50_us",
            value: stat.p50,
            unit: "microseconds",
            op: "<",
            thresholdValue: 20.0,
            pass: stat.p50 < 20.0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        addAxis(
            name: "\(prefix)_p99_us",
            value: stat.p99,
            unit: "microseconds",
            op: "<",
            thresholdValue: 50.0,
            pass: stat.p99 < 50.0,
            measurements: &measurements,
            thresholds: &thresholds,
            passPerAxis: &passPerAxis
        )
        measurements["\(prefix)_samples_us"] = metric(stat.samples, unit: "microseconds")
        measurements["\(prefix)_mean_us"] = metric(stat.mean, unit: "microseconds")
        measurements["\(prefix)_min_us"] = metric(stat.min, unit: "microseconds")
        measurements["\(prefix)_max_us"] = metric(stat.max, unit: "microseconds")
    }

    addAxis(
        name: "sequence_100_cycle_wall_ms",
        value: sequenceTiming.wallMs,
        unit: "milliseconds",
        op: "<",
        thresholdValue: 30.0,
        pass: sequenceTiming.wallMs < 30.0,
        measurements: &measurements,
        thresholds: &thresholds,
        passPerAxis: &passPerAxis
    )
    if let sequenceGpuMs = sequenceTiming.gpuMs {
        measurements["sequence_100_cycle_gpu_ms"] = metric(sequenceGpuMs, unit: "milliseconds")
    } else {
        measurements["sequence_100_cycle_gpu_ms"] = metric("unavailable", unit: "milliseconds")
    }

    measurements["correctness_fixture_sizes"] = metric(config.sizes, unit: "elements")
    measurements["correctness_seed_count"] = metric(config.correctnessSeeds, unit: "count")
    measurements["correctness_fixture_count"] = metric(config.sizes.count * config.correctnessSeeds, unit: "count")
    measurements["perf_size"] = metric(config.perfSize, unit: "elements")
    measurements["per_kernel_dispatches_per_sample"] = metric(perKernelDispatchesPerSample, unit: "dispatches")
    measurements["per_kernel_replicates_per_sample"] = metric(perKernelReplicatesPerSample, unit: "replicates")
    measurements["warmup_iterations"] = metric(config.warmupIterations, unit: "count")
    measurements["timed_iterations"] = metric(config.timedIterations, unit: "count")
    measurements["sequence_iterations"] = metric(config.sequenceIterations, unit: "count")
    measurements["timing_source"] = metric("per-kernel p50/p99 use median-of-3 batched commandBuffer GPU elapsed divided by dispatch count when available; otherwise batched wall wait divided by dispatch count", unit: "text")
    measurements["harness_wall_clock_seconds"] = metric(Date().timeIntervalSince(started), unit: "seconds")

    let axesPass = passPerAxis.values.allSatisfy { $0 }
    let artifactKind = axesPass ? "primary_witness" : "failure_report"
    let fallbackTier = axesPass ? "Primary" : "Fail"
    let outputPath = axesPass || config.forceWriteResult ? outputResultPath : outputFailurePath

    var anomalies: [[String: String]] = []
    if !axesPass {
        anomalies.append([
            "kind": "controller_kernel_pack_metal_gate_failed",
            "detail": "The Metal ControllerKernelPack witness failed at least one correctness, empty-contract, p50/p99, or sequence timing axis. Do not promote F-ControllerKernelPack; inspect metal_failure_result.json.",
        ])
    }

    let commit = shell("/usr/bin/git", ["rev-parse", "HEAD"])
    let swiftVersion = shell("/usr/bin/swift", ["--version"])
    let xcodeVersion = shell("/usr/bin/xcodebuild", ["-version"])
    let osBuild = shell("/usr/bin/sw_vers", ["-buildVersion"])
    let resultDigest = try canonicalDigest(measurements: measurements, passPerAxis: passPerAxis)

    let artifact: [String: Any] = [
        "falsifier_id": "F-ControllerKernelPack",
        "schema_version": "2026-05-18.2",
        "artifact_kind": artifactKind,
        "hardware_pin": [
            "machine": "M2 Pro 14-inch 2023",
            "cpu": "12-core CPU",
            "gpu": "19-core GPU",
            "unified_memory_gb": 16,
            "memory_bandwidth_gb_s": 200,
        ],
        "command": commandString,
        "command_digest": prefixedSHA256(Data(commandString.utf8)),
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
        "fixture_id": "controller_kernel_pack_metal_\(config.sizes.count)sizes_\(config.correctnessSeeds)seeds_\(config.perfSize)perf_v1",
        "timestamp_utc": timestampUTC(),
        "result_digest": resultDigest,
        "measurements": measurements,
        "acceptance_thresholds": thresholds,
        "pass_per_axis": passPerAxis,
        "overall_pass": axesPass,
        "fallback_tier": fallbackTier,
        "anomalies": anomalies,
        "notes": "Metal ControllerKernelPack witness generated from Epistemos/Shaders/ControllerKernelPack.metal. Correctness covers 6 kernels across the configured size ladder and seed count; performance records per-kernel p50/p99 at 4096 elements using median-of-3 batched commandBuffer GPU elapsed time divided by dispatch count when available, plus the batched 100-cycle six-kernel sequence wall time.",
    ]

    return RunResult(artifact: artifact, overallPass: axesPass, outputPath: outputPath)
}

func writeArtifact(_ artifact: [String: Any], to path: String) throws {
    let data = try JSONSerialization.data(withJSONObject: artifact, options: [.prettyPrinted, .sortedKeys])
    guard var text = String(data: data, encoding: .utf8) else {
        throw ControllerArtifactError.jsonEncoding
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
    fputs("controller-kernel-pack-artifact failed: \(error)\n", stderr)
    exit(1)
}
