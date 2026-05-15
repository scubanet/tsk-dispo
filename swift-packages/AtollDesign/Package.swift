// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AtollDesign",
  defaultLocalization: "de",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
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
      ]
    ),
  ]
)
