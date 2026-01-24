// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeAttack",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TimeAttackApp", targets: ["TimeAttackApp"]),
        .library(name: "TimeAttackCore", targets: ["TimeAttackCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2")
    ],
    targets: [
        .target(
            name: "TimeAttackCore",
            dependencies: [],
            path: "Sources/TimeAttackCore"
        ),
        .executableTarget(
            name: "TimeAttackApp",
            dependencies: ["TimeAttackCore", "KeychainAccess"],
            path: "Sources/TimeAttackApp"
        ),
        .testTarget(
            name: "TimeAttackTests",
            dependencies: ["TimeAttackCore"],
            path: "Tests/TimeAttackTests"
        )
    ]
)
