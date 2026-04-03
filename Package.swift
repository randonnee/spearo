// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Spearo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Spearo",
            path: "Sources/Spearo",
            exclude: ["Info.plist", "Assets.xcassets"]
        )
    ]
)
