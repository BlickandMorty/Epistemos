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

    @Test("runtime is OpenCode-only and does not spawn or proxy a secondary engine")
    func runtimeIsOpenCodeOnly() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/ProAgent/ProAgentRuntimeSupervisor.swift")
        #expect(source.contains(#"opencodeProc.arguments = ["serve", "--hostname", Self.loopbackHost, "--port", String(opencodePort)]"#))
        #expect(source.contains(#"webEnv["OPENCODE_PORT"] = String(opencodePort)"#))
        #expect(source.contains(#"webEnv["OPENCODE_SKIP_START"] = "true""#))
        #expect(!source.lowercased().contains("goose"))
        #expect(!source.contains("EPISTEMOS_GOOSE"))
        #expect(!source.contains("goosedProcess"))
        #expect(!source.contains("goosePort"))
    }
}
#endif
