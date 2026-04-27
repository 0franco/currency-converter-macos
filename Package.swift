// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CurrencyConverterMacOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CurrencyConverterMacOS",
            targets: ["CurrencyConverterMacOS"]
        ),
        .executable(
            name: "CurrencyConverter",
            targets: ["CurrencyConverterApp"]
        )
    ],
    targets: [
        .target(
            name: "CurrencyConverterMacOS"
        ),
        .executableTarget(
            name: "CurrencyConverterApp",
            dependencies: ["CurrencyConverterMacOS"],
            path: "CurrencyConverter",
            exclude: ["Info.plist", "Assets.xcassets"]
        ),
        .testTarget(
            name: "CurrencyConverterMacOSTests",
            dependencies: ["CurrencyConverterMacOS"]
        )
    ]
)
