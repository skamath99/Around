// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AroundCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AroundCore", targets: ["AroundCore"])
    ],
    targets: [
        .target(name: "AroundCore"),
        .testTarget(name: "AroundCoreTests", dependencies: ["AroundCore"]),
    ]
)
