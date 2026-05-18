// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollCore",
  defaultLocalization: "de",
  platforms: [
    .iOS("26.0"),
    .macOS("26.0"),
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
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AtollCoreTests",
      dependencies: ["AtollCore"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
