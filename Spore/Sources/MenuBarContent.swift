import SwiftUI

struct MenuBarContent: View {
    @Bindable var monitor: IdleMonitor

    var body: some View {
        Text(statusLine)

        Divider()

        Toggle("Sleep When Idle", isOn: $monitor.isEnabled)

        Picker("Sleep After", selection: $monitor.thresholdSeconds) {
            ForEach(intervalOptions, id: \.self) { interval in
                Text(formatDuration(interval)).tag(interval)
            }
        }

        Divider()

        Button("Sleep Now") { monitor.sleepNow() }
        Button("Reset Timer") { monitor.restartCountdown() }

        Divider()

        Button("Quit Spore") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLine: String {
        guard monitor.isEnabled else {
            return "Idle \(formatDuration(monitor.idleSeconds)) · off"
        }
        return "Idle \(formatDuration(monitor.idleSeconds)) · sleeps in \(formatDuration(monitor.secondsRemaining))"
    }

    /// Presets, plus the stored value in case it came from an older build that
    /// allowed arbitrary intervals, so the picker always has a row matching the
    /// current selection.
    private var intervalOptions: [TimeInterval] {
        Set(IdleMonitor.presetIntervals + [monitor.thresholdSeconds]).sorted()
    }
}
