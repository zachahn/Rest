import AppKit
import Observation

/// Watches how long it has been since the user physically moved the mouse or
/// pressed a key, and forces the machine to sleep once that crosses the
/// configured threshold.
@MainActor
@Observable
final class IdleMonitor {
    static let shared = IdleMonitor()

    /// The only events that count as activity.
    ///
    /// Everything else is deliberately ignored: clicks, scroll wheel, tablet
    /// and other HID events, video playback, downloads, background jobs. Drags
    /// are included because a drag *is* mouse movement — while a button is held
    /// down macOS reports motion as `…MouseDragged` rather than `.mouseMoved`.
    /// `.flagsChanged` covers a modifier key being pressed on its own.
    static let activityEvents: [CGEventType] = [
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .keyDown,
        .flagsChanged,
    ]

    static let presetIntervals: [TimeInterval] = [60, 300, 600, 900, 1800, 2700, 3600]

    /// Smallest interval that can be configured, so a stray keystroke in the
    /// settings field can't put the machine to sleep instantly.
    static let minimumInterval: TimeInterval = 10

    private(set) var idleSeconds: TimeInterval = 0

    /// Set once sleep has been requested (or the system started sleeping for
    /// any other reason) and cleared on wake, so we ask exactly once.
    private(set) var sleepIsPending = false

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Key.isEnabled)
            restartCountdown()
        }
    }

    /// Clamping happens in this setter rather than in a `didSet` on the storage.
    /// `@Observable` turns a stored property into a computed one over `_name`,
    /// so a `didSet` that assigns to its own property re-enters its own setter
    /// forever instead of quietly writing through the way it would on a plain
    /// stored property.
    var thresholdSeconds: TimeInterval {
        get { storedThresholdSeconds }
        set {
            let clamped = max(Self.minimumInterval, newValue)
            guard clamped != storedThresholdSeconds else { return }
            storedThresholdSeconds = clamped
            defaults.set(clamped, forKey: Key.threshold)
        }
    }

    private var storedThresholdSeconds: TimeInterval

    /// Idle time is measured from this instant as well as from the last input
    /// event. The hardware idle timer keeps running across a sleep, so without
    /// this a wake that isn't itself a keypress — lid, power button, Touch ID —
    /// would come back to an already-expired timer and sleep again immediately.
    private var countdownStart = Date()
    private var timer: Timer?

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key {
        static let threshold = "idleThresholdSeconds"
        static let isEnabled = "isEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.threshold: 600.0,
            Key.isEnabled: true,
        ])
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        storedThresholdSeconds = max(
            Self.minimumInterval, defaults.double(forKey: Key.threshold))
    }

    var secondsRemaining: TimeInterval {
        max(0, thresholdSeconds - idleSeconds)
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.sleepIsPending = true }
        }
        workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.restartCountdown() }
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common so the countdown keeps ticking while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    /// Give the user a fresh, full interval starting now.
    func restartCountdown() {
        countdownStart = Date()
        sleepIsPending = false
        idleSeconds = 0
    }

    func sleepNow() {
        sleepIsPending = true
        SystemSleep.request()
    }

    private func tick() {
        idleSeconds = measureIdleSeconds()

        guard isEnabled, !sleepIsPending, idleSeconds >= thresholdSeconds else { return }
        sleepNow()
    }

    private func measureIdleSeconds() -> TimeInterval {
        // .hidSystemState counts only events that came from real hardware, so
        // synthetic events posted by other processes never read as activity.
        let sinceLastInput = Self.activityEvents
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min() ?? 0
        return min(sinceLastInput, Date().timeIntervalSince(countdownStart))
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
