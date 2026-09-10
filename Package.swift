// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "glm-usage-hud",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "GLMUsageCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "glm-usage-hud",
            dependencies: ["GLMUsageCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GLMUsageCoreTests",
            dependencies: ["GLMUsageCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
