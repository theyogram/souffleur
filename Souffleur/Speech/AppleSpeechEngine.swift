import AVFoundation
import Foundation
import Speech

enum SpeechEngineError: LocalizedError {
    case permissionDenied
    case localeUnsupported
    case modelDownloadFailed(String)
    case engineFailure(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Accès au micro ou à la reconnaissance vocale refusé."
        case .localeUnsupported: return "Langue de reconnaissance non prise en charge."
        case .modelDownloadFailed(let message): return "Téléchargement du modèle impossible : \(message)"
        case .engineFailure(let message): return "Reconnaissance vocale interrompue : \(message)"
        }
    }
}

final class AppleSpeechEngine: SpeechEngine {
    var onError: ((SpeechEngineError) -> Void)?

    private let lock = NSLock()
    private var updateStream = AsyncStream<TranscriptUpdate> { _ in }
    private var updateContinuation: AsyncStream<TranscriptUpdate>.Continuation?
    private var transcriber: SpeechTranscriber?
    private var context = AnalysisContext()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var feedTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var session = UUID()

    var updates: AsyncStream<TranscriptUpdate> {
        lock.withLock { updateStream }
    }

    init() {}

    func prepare(locale: Locale, contextualWords: [String], progress: @escaping @Sendable (Double) -> Void) async throws {
        guard await SpeechPermissions.requestMicrophone(), await SpeechPermissions.requestSpeechRecognition() else {
            throw SpeechEngineError.permissionDenied
        }
        let preferred = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        let supported: Locale?
        if let preferred {
            supported = preferred
        } else {
            supported = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US"))
        }
        guard let supported else { throw SpeechEngineError.localeUnsupported }
        let module = SpeechTranscriber(locale: supported, transcriptionOptions: [],
                                       reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        let status = await AssetInventory.status(forModules: [module])
        guard status != .unsupported else { throw SpeechEngineError.localeUnsupported }
        if status != .installed {
            do {
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    let polling = Task.detached {
                        while !Task.isCancelled {
                            progress(min(1, max(0, request.progress.fractionCompleted)))
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                    }
                    defer { polling.cancel() }
                    try await request.downloadAndInstall()
                }
            } catch {
                throw SpeechEngineError.modelDownloadFailed(error.localizedDescription)
            }
        }
        guard await AssetInventory.status(forModules: [module]) == .installed else {
            throw SpeechEngineError.modelDownloadFailed("Le modèle n'est pas installé.")
        }
        await Task.detached { progress(1) }.value
        let newContext = AnalysisContext()
        newContext.contextualStrings[.general] = Array(contextualWords.prefix(100))
        lock.withLock {
            transcriber = module
            context = newContext
        }
    }

    func start(audio: AsyncStream<AVAudioPCMBuffer>) async throws {
        await stop()
        let (module, preparedContext) = lock.withLock { (transcriber, context) }
        guard let module else { throw SpeechEngineError.engineFailure("Le modèle n'est pas prêt.") }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
            throw SpeechEngineError.engineFailure("Aucun format audio compatible.")
        }
        let analyzer = SpeechAnalyzer(modules: [module])
        do {
            try await analyzer.setContext(preparedContext)
            try await analyzer.prepareToAnalyze(in: format)
        } catch {
            throw SpeechEngineError.engineFailure(error.localizedDescription)
        }

        var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
        let inputs = AsyncStream<AnalyzerInput>(bufferingPolicy: .bufferingNewest(20)) {
            inputContinuation = $0
        }
        guard let inputContinuation else { throw SpeechEngineError.engineFailure("Flux audio indisponible.") }
        var updateContinuation: AsyncStream<TranscriptUpdate>.Continuation?
        let updateStream = AsyncStream<TranscriptUpdate>(bufferingPolicy: .bufferingNewest(100)) {
            updateContinuation = $0
        }
        guard let updateContinuation else { throw SpeechEngineError.engineFailure("Flux de transcription indisponible.") }
        let identifier = UUID()
        lock.withLock {
            self.analyzer = analyzer
            self.inputContinuation = inputContinuation
            self.updateContinuation = updateContinuation
            self.updateStream = updateStream
            session = identifier
        }

        let analysisStart = Date()
        let results = Task.detached { [weak self] in
            do {
                for try await result in module.results {
                    let elapsed = result.range.end.seconds
                    let timestamp = elapsed.isFinite && elapsed >= 0
                        ? analysisStart.addingTimeInterval(elapsed) : Date()
                    let update = TranscriptUpdate(kind: result.isFinal ? .final : .volatile,
                                                  text: String(result.text.characters), timestamp: timestamp)
                    self?.yield(update, for: identifier)
                }
            } catch {
                self?.report(error, for: identifier)
            }
        }
        let feed = Task.detached { [weak self] in
            var converter: AVAudioConverter?
            var sourceFormat: AVAudioFormat?
            for await buffer in audio {
                if Task.isCancelled { break }
                if sourceFormat?.isEqual(buffer.format) != true {
                    sourceFormat = buffer.format
                    converter = buffer.format.isEqual(format) ? nil : AVAudioConverter(from: buffer.format, to: format)
                    if !buffer.format.isEqual(format), converter == nil {
                        self?.report(SpeechEngineError.engineFailure("Conversion audio indisponible."), for: identifier)
                        break
                    }
                }
                do {
                    let converted = try Self.convert(buffer, to: format, using: converter)
                    inputContinuation.yield(AnalyzerInput(buffer: converted))
                } catch {
                    self?.report(error, for: identifier)
                    break
                }
            }
            inputContinuation.finish()
        }
        let isCurrent = lock.withLock { () -> Bool in
            guard session == identifier else { return false }
            resultTask = results
            feedTask = feed
            return true
        }
        guard isCurrent else {
            results.cancel()
            feed.cancel()
            throw SpeechEngineError.engineFailure("Session audio annulée.")
        }
        do {
            try await analyzer.start(inputSequence: inputs)
        } catch {
            await stop()
            throw SpeechEngineError.engineFailure(error.localizedDescription)
        }
    }

    func stop() async {
        let (oldAnalyzer, oldInput, oldUpdate, oldFeed, oldResults) = lock.withLock {
            let previous = (analyzer, inputContinuation, updateContinuation, feedTask, resultTask)
            session = UUID()
            analyzer = nil
            inputContinuation = nil
            updateContinuation = nil
            feedTask = nil
            resultTask = nil
            return previous
        }
        oldFeed?.cancel()
        oldInput?.finish()
        if let oldAnalyzer { await oldAnalyzer.cancelAndFinishNow() }
        oldResults?.cancel()
        oldUpdate?.finish()
    }

    private func yield(_ update: TranscriptUpdate, for identifier: UUID) {
        let continuation = lock.withLock { session == identifier ? updateContinuation : nil }
        continuation?.yield(update)
    }

    private func report(_ error: Error, for identifier: UUID) {
        let handler = lock.withLock { session == identifier ? onError : nil }
        guard let handler else { return }
        let typed = error as? SpeechEngineError ?? .engineFailure(error.localizedDescription)
        handler(typed)
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat,
                                using converter: AVAudioConverter?) throws -> AVAudioPCMBuffer {
        guard let converter else { return buffer }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio) + 128)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw SpeechEngineError.engineFailure("Tampon audio indisponible.")
        }
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        if let conversionError { throw SpeechEngineError.engineFailure(conversionError.localizedDescription) }
        guard status != .error else { throw SpeechEngineError.engineFailure("Conversion audio échouée.") }
        return output
    }
}
