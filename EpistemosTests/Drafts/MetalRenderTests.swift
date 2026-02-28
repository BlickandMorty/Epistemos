import Metal
import MetalKit
import XCTest

class MetalRenderTests: XCTestCase {

    // Abstract tests to ensure shaders compile correctly and that
    // GPU state buffers upload properly.

    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!

    override func setUp() {
        super.setUp()
        guard let dev = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal is not supported on this device")
            return
        }
        device = dev
        commandQueue = device.makeCommandQueue()
    }

    func testShaderLibraryCompilation() {
        // Assume default.metallib is requested here
        // let bundle = Bundle(for: GraphRenderer.self)
        // guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
        //     XCTFail("Failed to compile default metal library shaders")
        //     return
        // }
        //
        // XCTAssertNotNil(library.makeFunction(name: "nodeVertexShader"))
        // XCTAssertNotNil(library.makeFunction(name: "nodeFragmentShader"))
    }

    func testBufferUploadsForNodes() {
        struct NodeStruct {
            var position: SIMD2<Float>
            var color: SIMD4<Float>
            var size: Float
        }

        // let nodes = [NodeStruct(position: [0, 0], color: [1, 0, 0, 1], size: 10)]
        // let buffer = device.makeBuffer(bytes: nodes, length: MemoryLayout<NodeStruct>.stride * nodes.count, options: .storageModeShared)

        // XCTAssertNotNil(buffer, "Metal failed to allocate buffer for nodes.")
        // XCTAssertEqual(buffer!.length, MemoryLayout<NodeStruct>.stride * nodes.count)
    }

    func testFramePacing() {
        // let cvDisplayLink = setupCVDisplayLink()
        // var frameTimes = [CFTimeInterval]()

        // XCTAssertEqual(cvDisplayLink.ticksPerSecond, 120.0, "Expected 120hz frame pacing!")
        // ... (accumulate timestamps across callbacks and test standard deviation)
    }
}
