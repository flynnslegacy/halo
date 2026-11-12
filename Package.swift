// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Menulens",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Menulens", targets: ["Menulens"])
    ],
    targets: [
        .target(name: "MenulensCore", path: "src/MenulensCore"),
        .executableTarget(
            name: "Menulens",
            dependencies: ["MenulensCore"],
            path: "src/Menulens",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(name: "MenulensCoreTests", dependencies: ["MenulensCore"], path: "tests/MenulensCoreTests")
    ]
)
