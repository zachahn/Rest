import SwiftUI

@main
struct RestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = IdleMonitor.shared
    @State private var launchAtLogin = LaunchAtLogin.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(monitor: monitor, launchAtLogin: launchAtLogin)
        } label: {
            Image(systemName: monitor.isEnabled ? "moon.zzz.fill" : "moon.zzz")
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
