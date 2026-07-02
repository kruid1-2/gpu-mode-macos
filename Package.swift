// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GPUMode",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PowerMode", targets: ["PowerMode"])
    ],
    targets: [
        .executableTarget(
            name: "PowerMode",
            path: "Sources/PowerMode"
        ),
        .testTarget(
            name: "PowerModeTests",
            dependencies: ["PowerMode"]
        )
    ]
)
