// swift-tools-version:4.0
import PackageDescription

let package = Package(
  name: "rswift",
  dependencies: [
    .package(url: "https://github.com/kylef/Commander.git", .upToNextMinor(from: "0.6.0")),
    .package(url: "https://github.com/tomlokhorst/XcodeEdit", from: "1.0.0")
  ],
  targets: [
    .target(
      name: "rswift",
      dependencies: ["RswiftCore"]
    ),
    .target(
      name: "RswiftCore",
      dependencies: ["Commander", "XcodeEdit"]
    ),
  ],
  swiftLanguageVersions: [4]
)
