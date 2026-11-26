// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KodouUI",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KodouUI", targets: ["KodouUI"])],
    targets: [.target(name: "KodouUI")]
)
