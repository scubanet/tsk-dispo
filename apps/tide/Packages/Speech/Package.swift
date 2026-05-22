// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Speech",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "Speech", targets: ["Speech"]),
  ],
  targets: [
    .target(name: "Speech"),
    .testTarget(name: "SpeechTests", dependencies: ["Speech"]),
  ]
)
