// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RelayMeter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "relay-meter", targets: ["RelayMeter"])
    ],
    targets: [
        .executableTarget(
            name: "RelayMeter",
            path: "Sources/RelayMeter"
        )
    ]
)
