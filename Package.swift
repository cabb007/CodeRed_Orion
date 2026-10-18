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
            sources: ["RecycliApp.swift", "Models", "Views"],
            swiftSettings: [
                // Xcode enables overlays by default; Linux SwiftBuild toolsets may not.
                // MapKit + SwiftUI needs this to expose MapCameraPosition, MapReader, etc.
                .unsafeFlags(["-Xfrontend", "-enable-cross-import-overlays"]),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
