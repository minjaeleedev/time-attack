// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeAttack",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TimeAttackApp", targets: ["TimeAttackApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2")
    ],
    targets: [
        .executableTarget(
            name: "TimeAttackApp",
            dependencies: ["KeychainAccess"],
            path: "Sources/TimeAttackApp"
        )
    ]
)
