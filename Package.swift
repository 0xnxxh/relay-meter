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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.3")
    ],
    targets: [
        .executableTarget(
            name: "RelayMeter",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/RelayMeter"
        )
    ],
    swiftLanguageModes: [.v5]
)
