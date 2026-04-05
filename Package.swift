// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OverlayNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OverlayNotes", targets: ["OverlayNotes"])
    ],
    targets: [
        .executableTarget(
            name: "OverlayNotes",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OverlayNotesTests",
            dependencies: ["OverlayNotes"],
            path: "Tests/OverlayNotesTests"
        )
    ]
)
