// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodexThreadMonitor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CodexThreadRadarCore",
            targets: ["CodexThreadRadarCore"]
        ),
        .executable(
            name: "CodexThreadRadar",
            targets: ["CodexThreadRadar"]
        ),
    ],
    targets: [
        .target(
            name: "CodexThreadRadarCore"
        ),
        .executableTarget(
            name: "CodexThreadRadar",
            dependencies: ["CodexThreadRadarCore"]
        ),
        .testTarget(
            name: "CodexThreadRadarCoreTests",
            dependencies: ["CodexThreadRadarCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
