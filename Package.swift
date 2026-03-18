// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CloudSyncKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "CloudSyncKit", targets: ["CloudSyncKit"]),
    ],
    targets: [
        .target(
            name: "CloudSyncKit",
            path: "Sources/CloudSyncKit"
        ),
        .testTarget(
            name: "CloudSyncKitTests",
            dependencies: ["CloudSyncKit"],
            path: "Tests/CloudSyncKitTests"
        ),
    ]
)
