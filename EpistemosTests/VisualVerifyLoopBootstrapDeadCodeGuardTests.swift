import Testing

/// Source guard for the Omega vision cleanup slice. VisualVerifyLoop remains a
/// tested helper, but AppBootstrap should not keep a constructed lazy instance
/// until a future bridge slice deliberately wires post-action verification.
@Suite("VisualVerifyLoop Bootstrap Dead Code Guard")
struct VisualVerifyLoopBootstrapDeadCodeGuardTests {

    @Test("AppBootstrap no longer exposes an unused VisualVerifyLoop singleton")
    func appBootstrapDoesNotOwnUnusedVisualVerifyLoop() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/AppBootstrap.swift")

        #expect(!source.contains("_visualVerifyLoop"))
        #expect(!source.contains("var visualVerifyLoop"))
        #expect(!source.contains("VisualVerifyLoop(screenCapture: screenCapture"))
    }

    @Test("AppEnvironment does not inject an unwired visual verification singleton")
    func appEnvironmentDoesNotInjectVisualVerifyLoop() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/App/AppEnvironment.swift")

        #expect(!source.contains("bootstrap.visualVerifyLoop"))
    }

    @Test("ComputerUseBridge does not claim visual verification without wiring it")
    func computerUseBridgeDoesNotReferenceVisualVerifyLoop() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/ComputerUseBridge.swift")

        #expect(!source.contains("VisualVerifyLoop"))
        #expect(!source.contains(".verify("))
    }
}
