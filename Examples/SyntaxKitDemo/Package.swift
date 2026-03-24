// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyntaxKitDemo",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "SyntaxKitDemo",
            dependencies: [
                .product(name: "SyntaxKit", package: "SyntaxKit")
            ],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
