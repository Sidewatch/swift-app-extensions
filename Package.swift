// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AppExtensions",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppExtensions", targets: ["AppExtensions"]),
    ],
    targets: [
        .target(name: "AppExtensions", path: "Sources", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "AppExtensionsTests", dependencies: ["AppExtensions"], path: "Tests"),
    ]
)
