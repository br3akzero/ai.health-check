// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HealthCheck",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")
    ],
    targets: [
        .target(name: "PDF"),
        .executableTarget(
            name: "HealthCheck",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "GRDB", package: "GRDB.swift"),
                "PDF"
            ]
        ),
        .testTarget(
            name: "HealthCheckTests",
            dependencies: [
                "HealthCheck",
                "PDF",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
    ]
)
