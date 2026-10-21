import CoreAudio
import Dispatch

enum Microphone {
    static func isOn() -> Bool {
        audioClientProcessIDs().contains(where: isRecording)
    }

    @MainActor
    static func statusChanges() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)
        let listener = Listener(continuation: continuation)
        continuation.onTermination = { _ in
            Task { @MainActor in listener.stop() }
        }
        listener.start()
        return stream
    }

    private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    private static let processListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    private static let isRunningInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyIsRunningInput,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    private static let inputDevicesAddress = AudioObjectPropertyAddress(
        mSelector: kAudioProcessPropertyDevices,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)

    private static func audioClientProcessIDs() -> [AudioObjectID] {
        var address = processListAddress
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr else {
            return []
        }
        var processIDs = [AudioObjectID](
            repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard
            AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &processIDs)
                == noErr
        else { return [] }
        return processIDs
    }

    private static func isRecording(_ processID: AudioObjectID) -> Bool {
        var address = isRunningInputAddress
        var isRunningInput: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            processID, &address, 0, nil, &size, &isRunningInput)
        return status == noErr && isRunningInput != 0
    }

    @MainActor
    private final class Listener {
        private let continuation: AsyncStream<Bool>.Continuation
        private var processListListener: AudioObjectPropertyListenerBlock?
        private var processListeners: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
        private var lastStatus: Bool?

        init(continuation: AsyncStream<Bool>.Continuation) {
            self.continuation = continuation
        }

        func start() {
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.processListChanged() }
            }
            var address = Microphone.processListAddress
            if AudioObjectAddPropertyListenerBlock(systemObject, &address, .main, listener)
                == noErr
            {
                processListListener = listener
            }
            processListChanged()
        }

        func stop() {
            if let processListListener {
                var address = Microphone.processListAddress
                AudioObjectRemovePropertyListenerBlock(
                    systemObject, &address, .main, processListListener)
                self.processListListener = nil
            }
            for processID in Array(processListeners.keys) {
                stopListening(to: processID)
            }
        }

        private func processListChanged() {
            let currentProcessIDs = Set(audioClientProcessIDs())
            for processID in processListeners.keys where !currentProcessIDs.contains(processID) {
                stopListening(to: processID)
            }
            for processID in currentProcessIDs where processListeners[processID] == nil {
                startListening(to: processID)
            }
            emitStatus()
        }

        private func startListening(to processID: AudioObjectID) {
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.emitStatus() }
            }
            var address = Microphone.inputDevicesAddress
            if AudioObjectAddPropertyListenerBlock(processID, &address, .main, listener) == noErr {
                processListeners[processID] = listener
            }
        }

        private func stopListening(to processID: AudioObjectID) {
            guard let listener = processListeners.removeValue(forKey: processID) else { return }
            var address = Microphone.inputDevicesAddress
            AudioObjectRemovePropertyListenerBlock(processID, &address, .main, listener)
        }

        private func emitStatus() {
            let isOn = Microphone.isOn()
            guard isOn != lastStatus else { return }
            lastStatus = isOn
            continuation.yield(isOn)
        }
    }
}
