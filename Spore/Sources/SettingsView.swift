import SwiftUI

struct SettingsView: View {
    @Bindable var monitor: IdleMonitor

    var body: some View {
        Form {
            Section {
                Toggle("Sleep when idle", isOn: $monitor.isEnabled)

                LabeledContent("Sleep after") {
                    HStack(spacing: 12) {
                        durationField(value: minutes, range: 0...1440, unit: "min")
                        durationField(value: seconds, range: 0...59, unit: "sec")
                    }
                }
            } footer: {
                Text(
                    """
                    Only physical mouse movement and key presses count as activity. \
                    Clicks, scrolling, video playback and background work do not.

                    Sleep is forced with `pmset sleepnow`, so it goes through even when \
                    an app is holding the Mac awake.
                    """
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }

    private func durationField(
        value: Binding<Int>, range: ClosedRange<Int>, unit: String
    ) -> some View {
        HStack(spacing: 4) {
            TextField("", value: value, format: .number)
                .labelsHidden()
                .frame(width: 52)
                .multilineTextAlignment(.trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { total / 60 },
            set: { setTotal(minutes: $0, seconds: total % 60) }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { total % 60 },
            set: { setTotal(minutes: total / 60, seconds: $0) }
        )
    }

    private var total: Int { Int(monitor.thresholdSeconds.rounded()) }

    private func setTotal(minutes: Int, seconds: Int) {
        let clamped = max(0, minutes) * 60 + min(59, max(0, seconds))
        monitor.thresholdSeconds = TimeInterval(clamped)
    }
}
