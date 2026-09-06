import Foundation
import Observation
import ServiceManagement

/// The app's own Login Items registration.
///
/// `SMAppService.mainApp` is the modern, sandbox-safe replacement for the
/// deprecated `LSSharedFileList` API: it registers the running bundle itself,
/// so it needs no helper target and no separate login-item app.
@MainActor
@Observable
final class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    /// Mirrors `SMAppService`, which is not observable. The user can flip the
    /// real setting from System Settings › General › Login Items at any time,
    /// so `refresh()` re-reads it whenever the menu is about to be shown.
    private(set) var isEnabled: Bool

    private let service = SMAppService.mainApp

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        isEnabled = service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog("Spore: could not \(enabled ? "register" : "unregister") the login item: \(error.localizedDescription)")
        }
        // Whatever the outcome, show what the system actually holds — the
        // registration can be refused, or left pending the user's approval.
        refresh()
    }
}
