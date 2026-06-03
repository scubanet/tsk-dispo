// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollHub",
  defaultLocalization: "de",
  platforms: [
    .iOS("26.0"),
    .macOS("26.0"),
  ],
  products: [
    .library(
      name: "AtollHub",
      targets: ["AtollHub"]
    ),
  ],
  dependencies: [
    .package(path: "../AtollCore"),
  ],
  targets: [
    .target(
      name: "AtollHub",
      dependencies: [
        .product(name: "AtollCore", package: "AtollCore"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AtollHubTests",
      dependencies: [
        "AtollHub",
        .product(name: "AtollCore", package: "AtollCore"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
