// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "trackpad-volume",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "trackpad-volume",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
