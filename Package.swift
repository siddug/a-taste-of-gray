// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ATasteOfGray",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "ATasteOfGray",
            targets: ["ATasteOfGray"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ATasteOfGray"
        ),
    ]
)
