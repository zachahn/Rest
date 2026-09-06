import SwiftUI

struct MenuBarContent: View {
    @Bindable var monitor: IdleMonitor
    var launchAtLogin: LaunchAtLogin

    var body: some View {
        Toggle("Sleep When Idle", isOn: $monitor.isEnabled)

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
        Button("Reset Timer") { monitor.restartCountdown() }

        Divider()

        Button("Quit Spore") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Presets, plus the stored value in case it came from an older build that
    /// allowed arbitrary intervals, so the picker always has a row matching the
    /// current selection.
    private var intervalOptions: [TimeInterval] {
        Set(IdleMonitor.presetIntervals + [monitor.thresholdSeconds]).sorted()
    }
}
