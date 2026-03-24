// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyntaxKit",
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
        ),
        .testTarget(
            name: "SyntaxKitCLITests",
            dependencies: ["SyntaxKitCLI", "SyntaxKit"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
