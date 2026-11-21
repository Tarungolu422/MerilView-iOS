// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MerilView-iOS",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MerilViewCore",
            targets: ["MerilViewCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MerilViewCore",
            dependencies: [],
            path: "MerilView",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "MerilViewTests",
            dependencies: ["MerilViewCore"],
            path: "MerilViewTests"
        )
    ]
)
