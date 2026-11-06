// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Coffee",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "Coffee")],
    swiftLanguageModes: [.v5]
)
