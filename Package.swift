// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Spearo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Spearo",
            path: "Sources/Spearo",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .copy("Resources/spear-tip.svg"),
                .copy("Resources/AppIcon.icns")
            ]
        )
    ]
)
