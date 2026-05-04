// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EpistenosApp",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "EpistenosApp", targets: ["EpistenosApp"])],
    targets: [
        .executableTarget(
            name: "EpistenosApp",
            path: "Sources/EpistenosApp"
        )
    ]
)
