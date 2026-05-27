import Foundation
import Metal
import Testing

@Suite("Metal witness gates")
nonisolated struct MetalWitnessGatesTests {
    private enum WitnessError: Error {
        case noDevice
        case noCommandQueue
        case noDefaultLibrary
        case noFunction(String)
        case noPipeline(String)
        case noBuffer(String)
        case noCommandBuffer
        case noCommandEncoder
        case commandFailed(String)
    }

    private struct Harness {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let library: MTLLibrary
    }

    private static func makeHarness() throws -> Harness {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw WitnessError.noDevice
        }
        guard let queue = device.makeCommandQueue() else {
            throw WitnessError.noCommandQueue
        }
        guard let library = device.makeDefaultLibrary() else {
            throw WitnessError.noDefaultLibrary
        }
        return Harness(device: device, queue: queue, library: library)
    }

    private static func makePipeline(_ name: String, harness: Harness) throws -> MTLComputePipelineState {
        guard let function = harness.library.makeFunction(name: name) else {
            throw WitnessError.noFunction(name)
        }
        do {
            return try harness.device.makeComputePipelineState(function: function)
        } catch {
            throw WitnessError.noPipeline("\(name): \(error.localizedDescription)")
        }
    }

    private static func makeBuffer<T>(
        _ values: [T],
        device: MTLDevice,
        label: String
    ) throws -> MTLBuffer {
        try values.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else {
                throw WitnessError.noBuffer(label)
            }
            guard let buffer = device.makeBuffer(
                bytes: baseAddress,
                length: values.count * MemoryLayout<T>.stride,
                options: .storageModeShared
            ) else {
                throw WitnessError.noBuffer(label)
            }
            buffer.label = label
            return buffer
        }
    }

    private static func makeZeroedBuffer<T>(
        type: T.Type,
        count: Int,
        device: MTLDevice,
        label: String
    ) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(
            length: count * MemoryLayout<T>.stride,
            options: .storageModeShared
        ) else {
            throw WitnessError.noBuffer(label)
        }
        memset(buffer.contents(), 0, count * MemoryLayout<T>.stride)
        buffer.label = label
        return buffer
    }

    private static func makeUInt32Buffer(
        _ value: UInt32,
        device: MTLDevice,
        label: String
    ) throws -> MTLBuffer {
        var mutable = value
        guard let buffer = device.makeBuffer(
            bytes: &mutable,
            length: MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        ) else {
            throw WitnessError.noBuffer(label)
        }
        buffer.label = label
        return buffer
    }

    private static func makeFloatBuffer(
        _ value: Float,
        device: MTLDevice,
        label: String
    ) throws -> MTLBuffer {
        var mutable = value
        guard let buffer = device.makeBuffer(
            bytes: &mutable,
            length: MemoryLayout<Float>.stride,
            options: .storageModeShared
        ) else {
            throw WitnessError.noBuffer(label)
        }
        buffer.label = label
        return buffer
    }

    private static func readArray<T>(_ buffer: MTLBuffer, count: Int, as type: T.Type) -> [T] {
        let pointer = buffer.contents().bindMemory(to: T.self, capacity: count)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    private static func dispatch(
        pipeline: MTLComputePipelineState,
        harness: Harness,
        buffers: [MTLBuffer],
        threads: Int
    ) throws {
        guard let commandBuffer = harness.queue.makeCommandBuffer() else {
            throw WitnessError.noCommandBuffer
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw WitnessError.noCommandEncoder
        }
        encoder.setComputePipelineState(pipeline)
        for (index, buffer) in buffers.enumerated() {
            encoder.setBuffer(buffer, offset: 0, index: index)
        }
        let threadCount = max(1, threads)
        let width = max(1, min(pipeline.maxTotalThreadsPerThreadgroup, 256))
        encoder.dispatchThreads(
            MTLSize(width: threadCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw WitnessError.commandFailed(error.localizedDescription)
        }
    }

    private static func fp16Bits(_ value: Float16) -> UInt16 {
        var mutable = value
        return withUnsafeBytes(of: &mutable) { raw in
            raw.load(as: UInt16.self)
        }
    }

    private static func fp16UlpDistance(_ lhs: Float16, _ rhs: Float16) -> Int {
        abs(Int(fp16Bits(lhs)) - Int(fp16Bits(rhs)))
    }

    @Test("PageGather Metal kernels match CPU references on deterministic fixtures")
    func pageGatherMetalKernelsMatchCpuReferences() throws {
        let harness = try Self.makeHarness()
        let scatter = try Self.makePipeline("pageGatherScatter", harness: harness)
        let scheduled = try Self.makePipeline("pageGatherScatterScheduled", harness: harness)
        let scaled = try Self.makePipeline("pageGatherScatterScaled", harness: harness)

        let source: [Float] = [10, 20, 30, 40, 50, 60, 70, 80]
        let indices: [UInt32] = [7, 0, 3, 3, 5, 2]
        let scales: [Float] = [0.5, 1, -1, 2, 0, 4]
        let count = UInt32(indices.count)

        let sourceBuffer = try Self.makeBuffer(source, device: harness.device, label: "pageGather.source")
        let indexBuffer = try Self.makeBuffer(indices, device: harness.device, label: "pageGather.indices")
        let countBuffer = try Self.makeUInt32Buffer(count, device: harness.device, label: "pageGather.count")
        let outBuffer = try Self.makeZeroedBuffer(type: Float.self, count: indices.count, device: harness.device, label: "pageGather.out")
        try Self.dispatch(
            pipeline: scatter,
            harness: harness,
            buffers: [sourceBuffer, indexBuffer, outBuffer, countBuffer],
            threads: indices.count
        )

        let gathered = Self.readArray(outBuffer, count: indices.count, as: Float.self)
        let expectedGathered = indices.map { source[Int($0)] }
        #expect(gathered == expectedGathered)

        let scheduledIndices: [UInt32] = [0, 1, 2, 3, 4, 5]
        let logicalPositions: [UInt32] = [1, 4, 5, 2, 3, 0]
        let scheduledIndexBuffer = try Self.makeBuffer(scheduledIndices, device: harness.device, label: "pageGather.scheduledIndices")
        let logicalPositionBuffer = try Self.makeBuffer(logicalPositions, device: harness.device, label: "pageGather.logicalPositions")
        let scheduledOut = try Self.makeZeroedBuffer(type: Float.self, count: scheduledIndices.count, device: harness.device, label: "pageGather.scheduledOut")
        try Self.dispatch(
            pipeline: scheduled,
            harness: harness,
            buffers: [sourceBuffer, scheduledIndexBuffer, logicalPositionBuffer, scheduledOut, countBuffer],
            threads: scheduledIndices.count
        )

        let scheduledValues = Self.readArray(scheduledOut, count: scheduledIndices.count, as: Float.self)
        let expectedScheduled: [Float] = [60, 10, 40, 50, 20, 30]
        #expect(scheduledValues == expectedScheduled)

        let scalesBuffer = try Self.makeBuffer(scales, device: harness.device, label: "pageGather.scales")
        let scaledOut = try Self.makeZeroedBuffer(type: Float.self, count: indices.count, device: harness.device, label: "pageGather.scaledOut")
        try Self.dispatch(
            pipeline: scaled,
            harness: harness,
            buffers: [sourceBuffer, indexBuffer, scalesBuffer, scaledOut, countBuffer],
            threads: indices.count
        )

        let scaledValues = Self.readArray(scaledOut, count: indices.count, as: Float.self)
        let expectedScaled = indices.enumerated().map { offset, index in
            source[Int(index)] * scales[offset]
        }
        #expect(scaledValues == expectedScaled)
    }

    @Test("ControllerKernelPack Metal kernels match scalar controller references")
    func controllerKernelPackMetalKernelsMatchReferences() throws {
        let harness = try Self.makeHarness()
        let add = try Self.makePipeline("scalarAddInPlace", harness: harness)
        let multiply = try Self.makePipeline("scalarMulInPlace", harness: harness)
        let maxReduce = try Self.makePipeline("maxReduce", harness: harness)
        let argmaxReduce = try Self.makePipeline("argmaxReduce", harness: harness)
        let copy = try Self.makePipeline("copyRange", harness: harness)
        let zero = try Self.makePipeline("zeroFill", harness: harness)

        let count = UInt32(6)
        let countBuffer = try Self.makeUInt32Buffer(count, device: harness.device, label: "controller.count")

        let addInput: [Float] = [1, -2, 4, 8, 16, -32]
        let addBuffer = try Self.makeBuffer(addInput, device: harness.device, label: "controller.add")
        let addScalar = try Self.makeFloatBuffer(0.5, device: harness.device, label: "controller.addScalar")
        try Self.dispatch(pipeline: add, harness: harness, buffers: [addBuffer, addScalar, countBuffer], threads: addInput.count)
        #expect(Self.readArray(addBuffer, count: addInput.count, as: Float.self) == addInput.map { $0 + 0.5 })

        let multiplyInput: [Float] = [1, -2, 4, 8, 16, -32]
        let multiplyBuffer = try Self.makeBuffer(multiplyInput, device: harness.device, label: "controller.multiply")
        let multiplyScalar = try Self.makeFloatBuffer(2, device: harness.device, label: "controller.multiplyScalar")
        try Self.dispatch(pipeline: multiply, harness: harness, buffers: [multiplyBuffer, multiplyScalar, countBuffer], threads: multiplyInput.count)
        #expect(Self.readArray(multiplyBuffer, count: multiplyInput.count, as: Float.self) == multiplyInput.map { $0 * 2 })

        let reductionInput: [Float] = [1, 5, 3, 5, -2, 0]
        let reductionBuffer = try Self.makeBuffer(reductionInput, device: harness.device, label: "controller.reduction")
        let maxOut = try Self.makeZeroedBuffer(type: Float.self, count: 1, device: harness.device, label: "controller.maxOut")
        try Self.dispatch(pipeline: maxReduce, harness: harness, buffers: [reductionBuffer, maxOut, countBuffer], threads: 1)
        #expect(Self.readArray(maxOut, count: 1, as: Float.self)[0] == 5)

        let argmaxOut = try Self.makeZeroedBuffer(type: UInt32.self, count: 1, device: harness.device, label: "controller.argmaxOut")
        try Self.dispatch(pipeline: argmaxReduce, harness: harness, buffers: [reductionBuffer, argmaxOut, countBuffer], threads: 1)
        #expect(Self.readArray(argmaxOut, count: 1, as: UInt32.self)[0] == 1)

        let copySource: [Float] = [3, 1, 4, 1, 5, 9]
        let copySrcBuffer = try Self.makeBuffer(copySource, device: harness.device, label: "controller.copySource")
        let copyDstBuffer = try Self.makeZeroedBuffer(type: Float.self, count: copySource.count, device: harness.device, label: "controller.copyDestination")
        try Self.dispatch(pipeline: copy, harness: harness, buffers: [copySrcBuffer, copyDstBuffer, countBuffer], threads: copySource.count)
        #expect(Self.readArray(copyDstBuffer, count: copySource.count, as: Float.self) == copySource)

        let zeroBuffer = try Self.makeBuffer(copySource, device: harness.device, label: "controller.zero")
        try Self.dispatch(pipeline: zero, harness: harness, buffers: [zeroBuffer, countBuffer], threads: copySource.count)
        #expect(Self.readArray(zeroBuffer, count: copySource.count, as: Float.self) == Array(repeating: 0, count: copySource.count))
    }

    @Test("F-ULP Metal oracle kernel stays within the fp16 two-ULP smoke budget")
    func fulpMetalOracleKernelStaysWithinSmokeBudget() throws {
        let harness = try Self.makeHarness()
        let oracle = try Self.makePipeline("morphOracleFp16", harness: harness)

        let x: [Float] = [0.5, 0.75, 1.0, 1.25, 2.0]
        let y: [Float] = [2.0, 1.25, 1.0, 0.75, 0.5]
        let count = UInt32(x.count)

        let xBuffer = try Self.makeBuffer(x, device: harness.device, label: "fulp.x")
        let yBuffer = try Self.makeBuffer(y, device: harness.device, label: "fulp.y")
        let expOut = try Self.makeZeroedBuffer(type: Float16.self, count: x.count, device: harness.device, label: "fulp.expOut")
        let lnOut = try Self.makeZeroedBuffer(type: Float16.self, count: y.count, device: harness.device, label: "fulp.lnOut")
        let emlOut = try Self.makeZeroedBuffer(type: Float16.self, count: x.count, device: harness.device, label: "fulp.emlOut")
        let countBuffer = try Self.makeUInt32Buffer(count, device: harness.device, label: "fulp.count")

        try Self.dispatch(
            pipeline: oracle,
            harness: harness,
            buffers: [xBuffer, yBuffer, expOut, lnOut, emlOut, countBuffer],
            threads: x.count
        )

        let expValues = Self.readArray(expOut, count: x.count, as: Float16.self)
        let lnValues = Self.readArray(lnOut, count: y.count, as: Float16.self)
        let emlValues = Self.readArray(emlOut, count: x.count, as: Float16.self)

        for index in x.indices {
            let expectedExp = Float16(Foundation.exp(Double(x[index])))
            let expectedLn = Float16(Foundation.log(Double(y[index])))
            let expectedEml = Float16(Foundation.exp(Double(x[index])) - Foundation.log(Double(y[index])))
            #expect(Self.fp16UlpDistance(expValues[index], expectedExp) <= 2)
            #expect(Self.fp16UlpDistance(lnValues[index], expectedLn) <= 2)
            #expect(Self.fp16UlpDistance(emlValues[index], expectedEml) <= 2)
        }
    }
}
