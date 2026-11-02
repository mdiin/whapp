// swift-tools-version:6.1
import PackageDescription

// ledjer-swift from GitHub, or from a local checkout when `LEDJER_SWIFT_PATH` is set
// (e.g. `LEDJER_SWIFT_PATH=../../ledjer-swift swift build`). Either way its package identity is `ledjer-swift`.
let ledjer: Package.Dependency =
    if let path = Context.environment["LEDJER_SWIFT_PATH"], !path.isEmpty {
        .package(path: path)
    } else {
        .package(url: "https://github.com/planmdk/ledjer-swift", from: "0.1.0")
    }

let package = Package(
    name: "AppCore",
    platforms: [
        .iOS(.v18),
        // Only so the package resolves on a Mac. The app, and its tests, run on iOS (see README).
        .macOS(.v15),
    ],
    products: [
        .library(name: "AppCore", targets: ["AppCore"]),
    ],
    dependencies: [
        ledjer,
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "AppCore",
            dependencies: [
                .product(name: "Ledjer", package: "ledjer-swift"),
                .product(name: "LedjerGRDB", package: "ledjer-swift"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: [
                "AppCore",
                .product(name: "Ledjer", package: "ledjer-swift"),
                .product(name: "LedjerGRDB", package: "ledjer-swift"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
