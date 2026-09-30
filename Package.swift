// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Nightglow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Nightglow", targets: ["Nightglow"]),
    ],
    targets: [
        .target(name: "NightglowCore"),
        .executableTarget(name: "Nightglow", dependencies: ["NightglowCore"]),
        .testTarget(name: "NightglowCoreTests", dependencies: ["NightglowCore"]),
    ]
)
