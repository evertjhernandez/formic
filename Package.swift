// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Formic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Formic", targets: ["Formic"])
    ],
    targets: [
        .executableTarget(
            name: "Formic",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("PDFKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "FormicTests",
            dependencies: ["Formic"]
        )
    ]
)
