import Foundation
import Testing

/// Wave 6 base source-guard
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 6,
///  cross-ref dpp §6.1-6.3 Sprint 5/6).
///
/// Three artefacts MUST stay in lock-step:
///   1. `agent_core/src/arenas/` — bumpalo per-frame arena module
///   2. `agent_core/Cargo.toml` — bumpalo dep + serde_json raw_value
///      feature + [profile.release-pgo] inheriting canonical release settings
///   3. `scripts/pgo-cycle.sh` — canonical cargo-pgo workflow with the
///      Apple ld64 trap warning embedded
///
/// Drift in any of those silently regresses the PGO + arena
/// optimisations. This test reads each file via the mirrored source bundle and
/// asserts the canonical wiring is present.
@Suite("PGO + Arenas (Wave 6 base)")
struct PGOAndArenasTests {

    private static func loadText(_ relative: String) throws -> String {
        try loadMirroredSourceTextFile(relative)
    }

    // MARK: - bumpalo arena module

    @Test("agent_core ships the bumpalo per-frame arena module")
    func arenasModuleExists() throws {
        let modURL = try sourceMirrorURL(for: "agent_core/src/arenas/mod.rs")
        let frameURL = modURL.deletingLastPathComponent()
            .appendingPathComponent("frame.rs", isDirectory: false)
        let rawURL = modURL.deletingLastPathComponent()
            .appendingPathComponent("raw_value.rs", isDirectory: false)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: modURL.path),
                "agent_core/src/arenas/mod.rs must exist (Wave 6.2 deliverable)")
        #expect(fm.fileExists(atPath: frameURL.path),
                "agent_core/src/arenas/frame.rs must exist (per-frame Bump arena)")
        #expect(fm.fileExists(atPath: rawURL.path),
                "agent_core/src/arenas/raw_value.rs must exist (serde_json::RawValue copy helper)")
    }

    @Test("with_frame uses thread_local Bump per the Wave 6 research finding")
    func frameArenaUsesThreadLocal() throws {
        let source = try Self.loadText("agent_core/src/arenas/frame.rs")
        #expect(source.contains("thread_local!"),
                "frame.rs must use thread_local! per the canonical Wave 6 research finding (Bump is !Sync; sharing requires a Mutex that destroys the win)")
        #expect(source.contains("pub fn with_frame"),
                "frame.rs must expose `with_frame` so callers don't poke the thread-local directly")
        #expect(source.contains("arena.reset()"),
                "with_frame must call arena.reset() at the start of each closure (O(1) bump-pointer rewind)")
    }

    @Test("raw_value module ships the serde_json::RawValue → BumpString copy helper")
    func rawValueHelperExists() throws {
        let source = try Self.loadText("agent_core/src/arenas/raw_value.rs")
        #expect(source.contains("pub fn raw_value_in"),
                "raw_value.rs must expose raw_value_in() — the canonical workaround for serde_json's heap-string allocation")
        #expect(source.contains("BumpString"),
                "raw_value.rs must use bumpalo::collections::String to keep the copy in the arena")
    }

    // MARK: - Cargo.toml wiring

    @Test("agent_core declares bumpalo + serde_json raw_value feature")
    func agentCoreCargoTomlHasArenaDeps() throws {
        let cargo = try Self.loadText("agent_core/Cargo.toml")
        #expect(cargo.contains("bumpalo = "),
                "agent_core/Cargo.toml must declare a bumpalo dependency (Wave 6.2)")
        #expect(cargo.contains("\"raw_value\""),
                "agent_core/Cargo.toml must enable serde_json's raw_value feature (canonical Wave 6 research workaround)")
    }

    @Test("[profile.release-pgo] inherits the canonical release profile")
    func pgoProfileInheritsCanonicalReleaseProfile() throws {
        let cargo = try Self.loadText("agent_core/Cargo.toml")
        #expect(cargo.contains("[profile.release-pgo]"),
                "agent_core/Cargo.toml must declare [profile.release-pgo] (Wave 6.1)")
        let pgoSection = cargo.components(separatedBy: "[profile.release-pgo]").last ?? ""
        #expect(pgoSection.contains("inherits = \"release\""),
                "[profile.release-pgo] must inherit the canonical [profile.release] contract")
        #expect(!pgoSection.contains("lto = \"thin\""),
                "[profile.release-pgo] must not override canonical release LTO")
    }

    // MARK: - pgo-cycle.sh

    @Test("scripts/pgo-cycle.sh exists, is executable, and embeds the Apple ld64 warning")
    func pgoScriptIsCanonical() throws {
        let url = try sourceMirrorURL(for: "scripts/pgo-cycle.sh")
        let fm = FileManager.default
        #expect(fm.fileExists(atPath: url.path),
                "scripts/pgo-cycle.sh must exist (Wave 6.1)")
        let attrs = try fm.attributesOfItem(atPath: url.path)
        let perms = (attrs[FileAttributeKey.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        #expect((perms & 0o111) != 0,
                "scripts/pgo-cycle.sh must be executable")

        let script = try Self.loadText("scripts/pgo-cycle.sh")
        #expect(script.contains("cargo pgo instrument build"),
                "pgo-cycle.sh must call `cargo pgo instrument build` (canonical cargo-pgo 0.2.x workflow)")
        #expect(script.contains("cargo pgo optimize build"),
                "pgo-cycle.sh must call `cargo pgo optimize build` to consume the collected profile data")
        #expect(script.contains("119016") || script.contains("ld64"),
                "pgo-cycle.sh must document the Apple ld64 LTO trap (cargo-pgo + lto=\"fat\" silently drops profile sections)")
    }
}
