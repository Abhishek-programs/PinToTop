// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PinToTop",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PinToTop", targets: ["PinToTop"])],
    targets: [.executableTarget(name: "PinToTop", path: "Sources/PinToTop")]
)
