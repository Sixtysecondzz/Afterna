// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ConversationCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ConversationCore", targets: ["ConversationCore"])
    ],
    targets: [
        .target(
            name: "ConversationCore",
            path: "Sources/ConversationCore"
        ),
        .testTarget(
            name: "ConversationCoreTests",
            dependencies: ["ConversationCore"],
            path: "Tests/ConversationCoreTests"
        )
    ]
)
