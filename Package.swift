// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CMemo",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CMemoKit"),
        .executableTarget(name: "cmemo", dependencies: ["CMemoKit"]),
        .executableTarget(name: "CMemoApp", dependencies: ["CMemoKit"]),
        .testTarget(name: "CMemoKitTests", dependencies: ["CMemoKit"]),
    ]
)
