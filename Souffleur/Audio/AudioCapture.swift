import AVFoundation
import AudioToolbox
import Foundation

final class AudioCapture {
    var onLevel: ((Double) -> Void)?
    var onDeviceLost: (() -> Void)?

    private let queue = DispatchQueue(label: "co.theyo.souffleur.audio-capture")
    private var engine: AVAudioEngine?
    private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var deviceToken: AnyObject?
    private var selectedUID: String?
    private var lastLevelTime = Date.distantPast

    init() {}

    func start(deviceUID: String?) throws -> AsyncStream<AVAudioPCMBuffer> {
        try queue.sync {
            stopLocked()
            let stream = AsyncStream<AVAudioPCMBuffer>(bufferingPolicy: .bufferingNewest(20)) { continuation in
                self.continuation = continuation
            }
            selectedUID = deviceUID.flatMap { $0.isEmpty ? nil : $0 }
            do {
                try startEngineLocked()
            } catch {
                stopLocked()
                throw error
            }
            deviceToken = AudioDevices.observeChanges { [weak self] in
                self?.queue.async { self?.handleDeviceChangeLocked() }
            }
            return stream
        }
    }

    func stop() {
        queue.sync { stopLocked() }
    }

    private func startEngineLocked() throws {
        let newEngine = AVAudioEngine()
        let input = newEngine.inputNode
        if let selectedUID {
            guard let unit = input.audioUnit else {
                throw SpeechEngineError.engineFailure("Unité audio du microphone indisponible.")
            }
            guard var deviceID = AudioDevices.deviceID(for: selectedUID) else {
                throw SpeechEngineError.engineFailure("Entrée audio introuvable : \(selectedUID)")
            }
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                                              kAudioUnitScope_Global, 0, &deviceID,
                                              UInt32(MemoryLayout<AudioDeviceID>.size))
            guard status == noErr else {
                throw SpeechEngineError.engineFailure("Impossible de sélectionner l'entrée audio (\(status)).")
            }
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw SpeechEngineError.engineFailure("Format du microphone indisponible.")
        }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
            guard let self, let copy = Self.copy(buffer) else { return }
            let level = Self.levelDBFS(buffer)
            self.queue.async { [self] in
                self.continuation?.yield(copy)
                let now = Date()
                if now.timeIntervalSince(self.lastLevelTime) >= 0.05 {
                    self.lastLevelTime = now
                    DispatchQueue.main.async { [weak self] in self?.onLevel?(level) }
                }
            }
        }
        do {
            try newEngine.start()
            engine = newEngine
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }

    private func handleDeviceChangeLocked() {
        guard let selectedUID, engine != nil,
              !AudioDevices.inputDevices().contains(where: { $0.id == selectedUID }) else { return }
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        self.selectedUID = nil
        do {
            try startEngineLocked()
            DispatchQueue.main.async { [weak self] in self?.onDeviceLost?() }
        } catch {
            stopLocked()
        }
    }

    private func stopLocked() {
        deviceToken = nil
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.engine = nil
        }
        continuation?.finish()
        continuation = nil
        selectedUID = nil
    }

    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let target = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        target.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
        let targetBuffers = UnsafeMutableAudioBufferListPointer(target.mutableAudioBufferList)
        for index in 0..<min(sourceBuffers.count, targetBuffers.count) {
            guard let from = sourceBuffers[index].mData, let to = targetBuffers[index].mData else { continue }
            let size = min(Int(sourceBuffers[index].mDataByteSize), Int(targetBuffers[index].mDataByteSize))
            memcpy(to, from, size)
            targetBuffers[index].mDataByteSize = UInt32(size)
        }
        return target
    }

    private static func levelDBFS(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return -160 }
        let frames = Int(buffer.frameLength)
        var sum = 0.0
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<frames {
                let sample = Double(channels[channel][frame])
                sum += sample * sample
            }
        }
        let rms = sqrt(sum / Double(frames * Int(buffer.format.channelCount)))
        return max(-160, 20 * log10(max(rms, 1e-8)))
    }
}
