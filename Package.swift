// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Halo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Halo", targets: ["Halo"])
    ],
    targets: [
        .target(name: "HaloCore", path: "src/HaloCore"),
        .executableTarget(
            name: "Halo",
            dependencies: ["HaloCore"],
            path: "src/Halo",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(name: "HaloCoreTests", dependencies: ["HaloCore"], path: "tests/HaloCoreTests")
    ]
)
