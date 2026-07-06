import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE
@Suite("Pro agent runtime supervisor")
struct ProAgentRuntimeSupervisorTests {
    @Test("child env drops unsafe inherited values and bounds PATH")
    func childEnvironmentDropsUnsafeInheritedValuesAndBoundsPath() {
        let oversized = String(
            repeating: "x",
            count: ProAgentRuntimeSupervisor.maxSubprocessEnvironmentValueCharacters + 1
        )
        let env = ProAgentRuntimeSupervisor.childEnvironment(
            binaryDirectories: [URL(fileURLWithPath: "/Runtime/openchamber/bin")],
            base: [
                "PATH": "/custom/bin:relative/bin:.:/usr/bin:/custom/bin",
                "HOME": oversized,
                "USER": "bad\0actor",
                "LANG": oversized,
                "LC_ALL": "en_US.UTF-8",
                "TMPDIR": "relative/tmp",
                "TERM": "xterm-256color",
                "OPENAI_API_KEY": "secret-token",
                "NODE_OPTIONS": "--require /tmp/inject.js",
                "DYLD_INSERT_LIBRARIES": "/tmp/inject.dylib",
            ]
        )

        let path = env["PATH"] ?? ""
        #expect(path.hasPrefix("/Runtime/openchamber/bin:/custom/bin:/usr/bin"))
        #expect(path.count <= ProAgentRuntimeSupervisor.maxSubprocessPathCharacters)
        #expect(path.components(separatedBy: ":").filter { $0 == "/custom/bin" }.count == 1)
        #expect(!path.components(separatedBy: ":").contains("relative/bin"))
        #expect(!path.components(separatedBy: ":").contains("."))
        #expect(!path.contains("bad"))
        #expect(!path.contains(oversized))
        #expect(env["LC_ALL"] == "en_US.UTF-8")
        #expect(env["TERM"] == "xterm-256color")
        #expect(env["HOME"] == nil)
        #expect(env["USER"] == nil)
        #expect(env["LANG"] == nil)
        #expect(env["TMPDIR"] == nil)
        #expect(env["OPENAI_API_KEY"] == nil)
        #expect(env["NODE_OPTIONS"] == nil)
        #expect(env["DYLD_INSERT_LIBRARIES"] == nil)

        let manyBinaryDirectories = (0..<(ProAgentRuntimeSupervisor.maxSubprocessPathEntries + 20))
            .map { URL(fileURLWithPath: "/Runtime/bin-\($0)") }
        let capped = ProAgentRuntimeSupervisor.childEnvironment(
            binaryDirectories: manyBinaryDirectories,
            base: ["PATH": "/usr/bin", "HOME": "/Users/me"]
        )
        #expect(capped["PATH"]?.components(separatedBy: ":").count == ProAgentRuntimeSupervisor.maxSubprocessPathEntries)
    }

    @Test("goosed env user tool path is bounded and deduped")
    func withUserToolPathIsBoundedAndDeduped() {
        let env = ProAgentRuntimeSupervisor.withUserToolPath([
            "HOME": "/Users/me",
            "PATH": "relative/bin:/usr/bin:/Users/me/.local/bin:/usr/bin",
        ])
        #expect(env["PATH"] == "/Users/me/.local/bin:/Users/me/bin:/usr/bin")

        let invalidHome = ProAgentRuntimeSupervisor.withUserToolPath([
            "HOME": "bad\0home",
            "PATH": "/usr/bin",
        ])
        #expect(invalidHome["PATH"] == "/usr/bin")
    }
}
#endif
