// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TimebaseActivity",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "timebase-activity-probe", targets: ["TimebaseActivityProbe"])
    ],
    targets: [
        .executableTarget(
            name: "TimebaseActivityProbe",
            path: "Sources/TimebaseActivityProbe"
        )
    ]
)
