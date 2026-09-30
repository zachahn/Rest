import CoreGraphics
import Foundation
import Testing

@testable import Rest

@MainActor
struct IdleMonitorTests {
    /// A throwaway defaults domain so tests never touch the real preferences.
    private func makeMonitor() -> (IdleMonitor, UserDefaults) {
        let suite = "RestTests.\(UUID().uuidString)"
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

    @Test func persistsCameraPreference() {
        let (monitor, defaults) = makeMonitor()
        #expect(!monitor.preventSleepWhileCameraIsOn)
        monitor.preventSleepWhileCameraIsOn = true
        #expect(IdleMonitor(defaults: defaults).preventSleepWhileCameraIsOn)
    }

    @Test func cameraBlocksIdleSleepUntilItTurnsOff() {
        let (_, defaults) = makeMonitor()
        var cameraActive = true
        var sleepRequests = 0
        let monitor = IdleMonitor(
            defaults: defaults, cameraIsOn: { cameraActive },
            requestSleep: { sleepRequests += 1 })
        monitor.preventSleepWhileCameraIsOn = true
        monitor.checkForIdleSleep(idleSeconds: monitor.thresholdSeconds)
        #expect(sleepRequests == 0)
        #expect(!monitor.sleepIsPending)
        cameraActive = false
        monitor.checkForIdleSleep(idleSeconds: monitor.thresholdSeconds)
        monitor.checkForIdleSleep(idleSeconds: monitor.thresholdSeconds)
        #expect(sleepRequests == 1)
    }

    @Test func cameraDoesNotBlockWhenPreferenceIsOff() {
        let (_, defaults) = makeMonitor()
        var sleepRequests = 0
        let monitor = IdleMonitor(
            defaults: defaults, cameraIsOn: { true },
            requestSleep: { sleepRequests += 1 })
        monitor.checkForIdleSleep(idleSeconds: monitor.thresholdSeconds)
        #expect(sleepRequests == 1)
    }

    @Test func manualSleepOverridesCameraPreference() {
        let (_, defaults) = makeMonitor()
        var sleepRequests = 0
        let monitor = IdleMonitor(
            defaults: defaults, cameraIsOn: { true },
            requestSleep: { sleepRequests += 1 })
        monitor.preventSleepWhileCameraIsOn = true
        monitor.sleepNow()
        #expect(sleepRequests == 1)
    }

    @Test func countsMovementClicksAndKeyPresses() {
        let counted = Set(IdleMonitor.activityEvents)
        #expect(counted.contains(.mouseMoved))
        #expect(counted.contains(.leftMouseDown))
        #expect(counted.contains(.rightMouseDown))
        #expect(counted.contains(.otherMouseDown))
        #expect(counted.contains(.keyDown))
        #expect(!counted.contains(.scrollWheel))
    }

    @Test(arguments: [
        (0.0, "0s"), (45.0, "45s"), (750.0, "12m 30s"), (3900.0, "1h 5m"),
    ])
    func formatsDurations(seconds: TimeInterval, expected: String) {
        #expect(formatDuration(seconds) == expected)
    }
}
