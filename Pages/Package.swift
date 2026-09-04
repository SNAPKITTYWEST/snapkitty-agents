// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiMoCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MiMoCore", targets: ["MiMoCore"]),
    ],
    targets: [
        .target(
            name: "MiMoCore",
            path: "swift",
            swiftSettings: [
                .unsafeFlags(["-Xwasm"], .when(platforms: [.wasi]))
            ]
        ),
    ]
)
