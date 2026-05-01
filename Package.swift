// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EInkToggle",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "EInkToggle",
            targets: ["EInkToggle"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "EInkToggle"
        ),
    ]
)
