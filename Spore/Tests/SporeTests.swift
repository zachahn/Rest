import CoreGraphics
import Foundation
import Testing

@testable import Spore

@MainActor
struct IdleMonitorTests {
    /// A throwaway defaults domain so tests never touch the real preferences.
    private func makeMonitor() -> (IdleMonitor, UserDefaults) {
        let suite = "SporeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (IdleMonitor(defaults: defaults), defaults)
    }

    @Test func clampsThresholdToMinimum() {
        let (monitor, _) = makeMonitor()
        monitor.thresholdSeconds = 1
        #expect(monitor.thresholdSeconds == IdleMonitor.minimumInterval)
    }

    /// Regression: clamping used to live in a `didSet` that assigned to its own
    /// `@Observable` property, which re-entered the setter until the stack blew.
    /// Any write — including one that changes nothing — used to recurse.
    @Test func writingTheSameValueTerminates() {
        let (monitor, _) = makeMonitor()
        monitor.thresholdSeconds = 600
        monitor.thresholdSeconds = 600
        #expect(monitor.thresholdSeconds == 600)
    }

    @Test func persistsThreshold() {
        let (monitor, defaults) = makeMonitor()
        monitor.thresholdSeconds = 900
        #expect(defaults.double(forKey: "idleThresholdSeconds") == 900)
        #expect(IdleMonitor(defaults: defaults).thresholdSeconds == 900)
    }

    @Test func persistsEnabledFlag() {
        let (monitor, defaults) = makeMonitor()
        monitor.isEnabled = false
        #expect(IdleMonitor(defaults: defaults).isEnabled == false)
    }

    @Test func countsOnlyMovementAndKeyPresses() {
        let counted = Set(IdleMonitor.activityEvents)
        #expect(counted.contains(.mouseMoved))
        #expect(counted.contains(.keyDown))
        #expect(!counted.contains(.scrollWheel))
        #expect(!counted.contains(.leftMouseDown))
    }

    @Test(arguments: [
        (0.0, "0s"), (45.0, "45s"), (750.0, "12m 30s"), (3900.0, "1h 5m"),
    ])
    func formatsDurations(seconds: TimeInterval, expected: String) {
        #expect(formatDuration(seconds) == expected)
    }
}
