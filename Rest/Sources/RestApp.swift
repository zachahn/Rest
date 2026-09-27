import SwiftUI
import Sparkle

@main
struct RestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = IdleMonitor.shared
    @State private var launchAtLogin = LaunchAtLogin.shared
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                monitor: monitor, launchAtLogin: launchAtLogin,
                updater: updaterController.updater
            )
        } label: {
            Image(systemName: monitor.isEnabled ? "moon.stars.fill" : "moon.stars")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            IdleMonitor.shared.start()
        }
    }
}
