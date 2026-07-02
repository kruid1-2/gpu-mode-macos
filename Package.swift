// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GPUMode",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PowerMode", targets: ["PowerMode"]),
        .executable(name: "GPUModeHelper", targets: ["GPUModeHelper"]),
        .library(name: "GPUModeShared", targets: ["GPUModeShared"])
    ],
    targets: [
        .target(
            name: "GPUModeShared",
            path: "Sources/GPUModeShared"
        ),
        .executableTarget(
            name: "PowerMode",
            dependencies: ["GPUModeShared"],
            path: "Sources/PowerMode"
        ),
        .executableTarget(
            name: "GPUModeHelper",
            dependencies: ["GPUModeShared"],
            path: "Sources/GPUModeHelper"
        ),
        .testTarget(
            name: "PowerModeTests",
            dependencies: ["PowerMode", "GPUModeShared"]
        )
    ]
)
