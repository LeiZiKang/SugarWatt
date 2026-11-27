// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KangChargeCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "KangChargeCore", targets: ["KangChargeCore"]),
        .library(name: "KangChargeUI", targets: ["KangChargeUI"])
    ],
    targets: [
        .target(
            name: "KangChargeCore",
            path: "Sources/KangChargeCore"
        ),
        .target(
            name: "KangChargeUI",
            dependencies: ["KangChargeCore"],
            path: "Sources/KangChargeUI"
        ),
        .testTarget(
            name: "KangChargeCoreTests",
            dependencies: ["KangChargeCore"],
            path: "Tests/KangChargeCoreTests"
        )
    ]
)
