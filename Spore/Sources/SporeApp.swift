import SwiftUI

@main
struct SporeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var monitor = IdleMonitor.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(monitor: monitor)
        } label: {
            Image(systemName: monitor.isEnabled ? "moon.zzz.fill" : "moon.zzz")
        }

        Settings {
            SettingsView(monitor: monitor)
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
