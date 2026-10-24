// swift-tools-version:5.9
// Optional SwiftPM manifest (for Xcode / `swift build`). The supported build is scripts/build.sh,
// which needs only the Command Line Tools.
import PackageDescription

let package = Package(
    name: "DockFolders",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DockFolders",
            path: "Sources/DockFolders"
        )
    ],
    swiftLanguageVersions: [.v5]
)
