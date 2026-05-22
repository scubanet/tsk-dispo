// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Hotkeys",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "Hotkeys", targets: ["Hotkeys"]),
  ],
  targets: [
    .target(name: "Hotkeys"),
    .testTarget(name: "HotkeysTests", dependencies: ["Hotkeys"]),
  ]
)
