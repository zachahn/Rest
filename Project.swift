import ProjectDescription

let signingSettings: Settings = .settings(base: [
    "DEVELOPMENT_TEAM": "TZWTJP2JSN",
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_IDENTITY": "Apple Development",
    "ENABLE_HARDENED_RUNTIME": "YES",
    "MARKETING_VERSION": "1.0",
    "CURRENT_PROJECT_VERSION": "2",
])

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
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "SUFeedURL": "https://github.com/zachahn/Rest/releases/latest/download/appcast.xml",
                "SUPublicEDKey": "DY6oJN7LMzE0XhPJXA1DRt7l1L6N/QQETbaBEUUHuZk=",
            ]),
            buildableFolders: [
                "Rest/Sources",
                "Rest/Resources",
            ],
            dependencies: [.external(name: "Sparkle")],
            settings: signingSettings
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
            dependencies: [.target(name: "Rest")],
            settings: signingSettings
        ),
    ]
)
