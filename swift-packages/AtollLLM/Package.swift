// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollLLM",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [
    .library(name: "AtollLLM", targets: ["AtollLLM"]),
  ],
  targets: [
    .target(name: "AtollLLM"),
    .testTarget(name: "AtollLLMTests", dependencies: ["AtollLLM"]),
  ]
)
