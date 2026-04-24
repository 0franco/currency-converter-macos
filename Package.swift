// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CurrencyConverterMacOS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CurrencyConverterMacOS",
            targets: ["CurrencyConverterMacOS"]
        )
    ],
    targets: [
        .target(
            name: "CurrencyConverterMacOS"
        ),
        .testTarget(
            name: "CurrencyConverterMacOSTests",
            dependencies: ["CurrencyConverterMacOS"]
        )
    ]
)
