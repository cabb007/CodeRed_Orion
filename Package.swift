// swift-tools-version: 6.0
import PackageDescription

// xtool builds the same app sources as Recycli.xcodeproj.
let package = Package(
    name: "Recycli",
    platforms: [.iOS(.v17)],
    products: [.library(name: "Recycli", targets: ["Recycli"])],
    targets: [
        .target(
            name: "Recycli",
            path: "Recycli",
            exclude: ["Assets.xcassets", "Info.plist", "Resources", "Sounds"],
            sources: ["RecycliApp.swift", "Models", "Views"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
