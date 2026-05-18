// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollDesign",
  defaultLocalization: "de",
  platforms: [
    .iOS("26.0"),
    .macOS("26.0"),
  ],
  products: [
    .library(
      name: "AtollDesign",
      targets: ["AtollDesign"]
    ),
  ],
  dependencies: [
    .package(path: "../AtollCore"),
  ],
  targets: [
    .target(
      name: "AtollDesign",
      dependencies: [
        .product(name: "AtollCore", package: "AtollCore"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
