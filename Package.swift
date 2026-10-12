// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tempo",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Tempo", targets: ["Tempo"])
    ],
    dependencies: [
        // nimbi's shared cloud, tokens and components. To work on both at once, swap in
        // .package(path: "../nimbi-kit") with a checkout next to this repo.
        .package(url: "https://github.com/behkha/nimbi-kit.git", from: "0.6.0")
    ],
    targets: [
        // Everything that isn't a view: the timer, the session log, sounds as settings, moods.
        .target(
            name: "TempoCore",
            dependencies: [.product(name: "NimbiKit", package: "nimbi-kit")],
            path: "Sources/TempoCore"
        ),
        .executableTarget(
            name: "Tempo",
            dependencies: ["TempoCore", .product(name: "NimbiKit", package: "nimbi-kit")],
            path: "Sources/Tempo"
        ),
        .testTarget(
            name: "TempoCoreTests",
            dependencies: ["TempoCore", .product(name: "NimbiKit", package: "nimbi-kit")],
            path: "Tests/TempoCoreTests"
        )
    ]
)
