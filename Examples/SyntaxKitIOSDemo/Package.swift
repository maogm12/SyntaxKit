// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyntaxKitIOSDemo",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "SyntaxKitIOSDemo",
            targets: ["SyntaxKitIOSDemo"]
        )
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "SyntaxKitIOSDemo",
            dependencies: [
                .product(name: "SyntaxKit", package: "SyntaxKit")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SyntaxKitIOSDemoTests",
            dependencies: ["SyntaxKitIOSDemo"]
        )
    ]
)
