// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchTerm",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "NotchTerm", targets: ["NotchTerm"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "NotchTerm",
            dependencies: ["SwiftTerm", "HotKey"],
            path: "NotchTerm",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
