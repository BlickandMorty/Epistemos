// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EpistemosChatDonorContracts",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "EpistemosChatDonorContracts",
            targets: ["EpistemosChatDonorContracts"]
        )
    ],
    targets: [
        .target(
            name: "EpistemosChatDonorContracts",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "EpistemosChatDonorContractsTests",
            dependencies: ["EpistemosChatDonorContracts"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
