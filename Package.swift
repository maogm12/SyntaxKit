// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyntaxKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SyntaxKit",
            targets: ["SyntaxKit"]
        ),
        .executable(
            name: "syntaxkit",
            targets: ["SyntaxKitCLI"]
        )
    ],
    targets: [
        .target(
            name: "SyntaxKit"
        ),
        .executableTarget(
            name: "SyntaxKitCLI",
            dependencies: ["SyntaxKit"]
        ),
        .testTarget(
            name: "SyntaxKitTests",
            dependencies: ["SyntaxKit"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
