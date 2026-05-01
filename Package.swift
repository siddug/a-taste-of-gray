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
        .executable(
            name: "EInkToggleHelper",
            targets: ["EInkToggleHelper"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "EInkToggle"
        ),
        .executableTarget(
            name: "EInkToggleHelper"
        ),
    ]
)
