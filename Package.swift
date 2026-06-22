// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Diskovery",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "DiskoveryCore"
        ),
        .executableTarget(
            name: "Diskovery",
            dependencies: ["DiskoveryCore"]
        ),
        .executableTarget(
            name: "DiskoveryBench",
            dependencies: ["DiskoveryCore"]
        ),
        .testTarget(
            name: "DiskoveryCoreTests",
            dependencies: ["DiskoveryCore"]
        ),
    ]
)
