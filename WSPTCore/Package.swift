// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WSPTCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WSPTCore",
            targets: ["WSPTCore"]
        )
    ],
    targets: [
        .target(
            name: "WSPTCore"
        ),
        .testTarget(
            name: "WSPTCoreTests",
            dependencies: ["WSPTCore"]
        )
    ]
)
