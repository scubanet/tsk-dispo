// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "AtollCore",
  defaultLocalization: "de",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "AtollCore",
      targets: ["AtollCore"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "AtollCore",
      dependencies: [
        .product(name: "Supabase", package: "supabase-swift"),
      ]
    ),
    .testTarget(
      name: "AtollCoreTests",
      dependencies: ["AtollCore"]
    ),
  ]
)
