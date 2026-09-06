import ProjectDescription

let project = Project(
    name: "Spore",
    targets: [
        .target(
            name: "Spore",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.tuist.Spore",
            infoPlist: .default,
            buildableFolders: [
                "Spore/Sources",
                "Spore/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "SporeTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.tuist.SporeTests",
            infoPlist: .default,
            buildableFolders: [
                "Spore/Tests"
            ],
            dependencies: [.target(name: "Spore")]
        ),
    ]
)
