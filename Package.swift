// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Snapshot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Snapshot", targets: ["Snapshot"])
    ],
    targets: [
        .executableTarget(
            name: "Snapshot",
            path: "Sources/Snapshot",
            exclude: ["Resources/Info.plist"]
        )
    ]
)
