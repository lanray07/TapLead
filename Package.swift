// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "TapLeadCore", platforms: [.iOS(.v17)], products: [.library(name: "TapLeadCore", targets: ["TapLeadCore"])], targets: [.target(name: "TapLeadCore", path: "Sources/TapLeadCore"), .testTarget(name: "TapLeadCoreTests", dependencies: ["TapLeadCore"], path: "Tests/TapLeadCoreTests")])
