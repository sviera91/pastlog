// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pastlog",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PastlogCore"),
        .executableTarget(name: "Pastlog", dependencies: ["PastlogCore"]),
        .executableTarget(name: "PastlogSelfTest", dependencies: ["PastlogCore"]),
    ],
    swiftLanguageModes: [.v5]
)
