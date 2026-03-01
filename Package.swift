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
            name: "PrinterSimulator",
            targets: ["PrinterSimulator"]
        ),
    ],
    targets: [
        .target(
            name: "ThermalPrinterCommand"
        ),
        .target(
            name: "PrinterSimulator",
            dependencies: ["ThermalPrinterCommand"]
        ),
        .testTarget(
            name: "ThermalPrinterCommandTests",
            dependencies: ["ThermalPrinterCommand"]
        ),
        .testTarget(
            name: "PrinterSimulatorTests",
            dependencies: ["PrinterSimulator"]
        ),
    ]
)
