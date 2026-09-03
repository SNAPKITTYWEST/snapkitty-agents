// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnapKittyAgents",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SnapKittyAgents", targets: ["SnapKittyAgents"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SnapKittyAgents",
            path: "Sources/SnapKittyAgents"
        ),
        .testTarget(
            name: "SnapKittyAgentsTests",
            dependencies: ["SnapKittyAgents"],
            path: "Tests/SnapKittyAgentsTests"
        ),
    ]
)
