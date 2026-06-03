// swift-tools-version: 6.0
import PackageDescription

// Module name avoids Apple's `Speech.framework` collision (same reason
// Tide named its module `TideSpeech`).
let package = Package(
  name: "AtollSpeech",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [
    .library(name: "AtollSpeech", targets: ["AtollSpeech"]),
  ],
  targets: [
    .target(name: "AtollSpeech"),
    .testTarget(name: "AtollSpeechTests", dependencies: ["AtollSpeech"]),
  ]
)
