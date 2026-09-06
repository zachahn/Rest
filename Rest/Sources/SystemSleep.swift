import Foundation

enum SystemSleep {
    /// Puts the machine to sleep immediately.
    ///
    /// `pmset sleepnow` is the explicit sleep path, not the idle one, so it
    /// goes through even when something is holding a power assertion (a media
    /// player, `caffeinate`, an active download). It needs no root and no
    /// Automation permission — unlike the `System Events` AppleScript route —
    /// but the app must not be sandboxed, since it spawns a process.
    static func request() {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["sleepnow"]
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    NSLog("Rest: pmset sleepnow exited with \(process.terminationStatus)")
                }
            } catch {
                NSLog("Rest: could not run pmset sleepnow: \(error.localizedDescription)")
            }
        }
    }
}
