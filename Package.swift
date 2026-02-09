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
        .library(
            name: "ReceiptRenderer",
            targets: ["ReceiptRenderer"]
        ),
    ],
    targets: [
        .target(
            name: "ThermalPrinterCommand"
        ),
        .target(
            name: "ReceiptRenderer",
            dependencies: ["ThermalPrinterCommand"]
        ),
        .testTarget(
            name: "ThermalPrinterCommandTests",
            dependencies: ["ThermalPrinterCommand"]
        ),
        .testTarget(
            name: "ReceiptRendererTests",
            dependencies: ["ReceiptRenderer"]
        ),
    ]
)
