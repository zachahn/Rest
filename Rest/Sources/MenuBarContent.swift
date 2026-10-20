import SwiftUI
import Sparkle

struct MenuBarContent: View {
    @Bindable var monitor: IdleMonitor
    var launchAtLogin: LaunchAtLogin
    let updater: SPUUpdater

    var body: some View {
        Toggle("Sleep When Idle", isOn: $monitor.isEnabled)

        Toggle("Keep Awake While Camera Is On", isOn: $monitor.preventSleepWhileCameraIsOn)

        Toggle("Keep Awake While Mic Is On", isOn: $monitor.preventSleepWhileMicrophoneIsOn)

        Picker("Sleep After", selection: $monitor.thresholdSeconds) {
            ForEach(intervalOptions, id: \.self) { interval in
                Text(formatDuration(interval)).tag(interval)
            }
        }

        Toggle(
            "Launch at Login",
            isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) })
        )
        .onAppear { launchAtLogin.refresh() }

        Divider()

        Button("Sleep Now") { monitor.sleepNow() }

        Divider()

        CheckForUpdatesButton(updater: updater)

        Button("Quit Rest") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Presets, plus the stored value in case it came from an older build that
    /// allowed arbitrary intervals, so the picker always has a row matching the
    /// current selection.
    private var intervalOptions: [TimeInterval] {
        Set(IdleMonitor.presetIntervals + [monitor.thresholdSeconds]).sorted()
    }
}

private struct CheckForUpdatesButton: View {
    let updater: SPUUpdater
    @State private var canCheck = false

    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!canCheck)
            .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheck = $0 }
    }
}

/// Formats a duration as `1h 5m`, `12m 30s`, `45s`.
func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60

    var parts: [String] = []
    if hours > 0 { parts.append("\(hours)h") }
    if minutes > 0 { parts.append("\(minutes)m") }
    if secs > 0 || parts.isEmpty { parts.append("\(secs)s") }
    return parts.joined(separator: " ")
}
