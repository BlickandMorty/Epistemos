import Foundation
import Testing

@Suite("MarkEdit package plugin strip guards (Plan 2)")
nonisolated struct MarkEditPackagePluginStripTests {
    @Test("vendored MarkEdit packages do not invoke SwiftLint plugins inside Epistemos builds")
    func vendoredMarkEditPackagesDoNotInvokeSwiftLintPlugins() throws {
        let manifests = [
            "LocalPackages/MarkEdit/MarkEditCore/Package.swift",
            "LocalPackages/MarkEdit/MarkEditKit/Package.swift",
            "LocalPackages/MarkEdit/MarkEditMac/Modules/Package.swift",
        ]

        for manifest in manifests {
            let package = try loadMirroredSourceTextFile(manifest)
            #expect(!package.contains("plugins:"))
            #expect(!package.contains(".plugin(name: \"SwiftLint\""))
            #expect(!package.contains("package: \"MarkEditTools\""))
        }
    }

    @Test("MarkEdit module package resolves the vendored top-level MarkEditKit package")
    func markEditModulesResolveVendoredTopLevelMarkEditKit() throws {
        let modulesPackage = try loadMirroredSourceTextFile("LocalPackages/MarkEdit/MarkEditMac/Modules/Package.swift")

        #expect(modulesPackage.contains(#".package(path: "../../MarkEditKit")"#))
        #expect(!modulesPackage.contains(#".package(path: "../MarkEditKit")"#))
    }
}
