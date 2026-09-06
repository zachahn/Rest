import ProjectDescription

let project = Project(
    name: "Rest",
    targets: [
        .target(
            name: "Rest",
            destinations: .macOS,
            product: .app,
            bundleId: "com.zachahn.Rest",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                // Menu bar only: no Dock icon, no windows at launch.
                "LSUIElement": true,
                "NSMainStoryboardFile": "",
            ]),
            buildableFolders: [
                "Rest/Sources",
                "Rest/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "RestTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.zachahn.RestTests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            buildableFolders: [
                "Rest/Tests"
            ],
            dependencies: [.target(name: "Rest")]
        ),
    ]
)
