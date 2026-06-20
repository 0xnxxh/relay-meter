// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CPAMenubar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cpa-menubar", targets: ["CPAMenubar"])
    ],
    targets: [
        .executableTarget(
            name: "CPAMenubar",
            path: "Sources/CPAMenubar"
        )
    ]
)
