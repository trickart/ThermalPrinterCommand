// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ThermalPrinterCommand",
    products: [
        .library(
            name: "ThermalPrinterCommand",
            targets: ["ThermalPrinterCommand"]
        ),
    ],
    targets: [
        .target(
            name: "ThermalPrinterCommand"
        ),
        .testTarget(
            name: "ThermalPrinterCommandTests",
            dependencies: ["ThermalPrinterCommand"]
        ),
    ]
)
