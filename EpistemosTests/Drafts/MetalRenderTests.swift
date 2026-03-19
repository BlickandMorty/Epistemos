import Metal
import Testing

@Suite("Metal Render Sanity")
struct MetalRenderTests {
    @Test("Metal device is available for renderer sanity checks")
    func metalDeviceIsAvailable() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        #expect(device.makeCommandQueue() != nil)
    }
}
