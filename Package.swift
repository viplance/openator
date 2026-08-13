// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Openator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Openator", targets: ["Openator"])
    ],
    targets: [
        .executableTarget(
            name: "Openator",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreServices")
            ]
        ),
        .testTarget(
            name: "OpenatorTests",
            dependencies: ["Openator"]
        )
    ]
)
