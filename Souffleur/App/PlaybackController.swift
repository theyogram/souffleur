import AppKit
import Observation

@MainActor
@Observable final class PlaybackController {
    let store: ScriptStore
    let prompter: PrompterWindowController
    let capture: AudioCapture
    let engine: AppleSpeechEngine
    private(set) var state: PlaybackState = .idle
    private(set) var currentScriptID: UUID?
    var selectedScriptID: UUID?
    @ObservationIgnored var onOpenLibrary: (() -> Void)?
    var cursor: Int { matcher.cursor }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var matcher = ScriptMatcher(tokens: [])
    @ObservationIgnored private var driver = ScrollDriver(mode: .voice, speed: 40, thresholdDb: -45)
    @ObservationIgnored private var sourceTokens: [ScriptToken] = []
    @ObservationIgnored private var displayedTokens: [ScriptToken] = []
    @ObservationIgnored private(set) var displayedText = ""
    @ObservationIgnored private var levelDb = -160.0
    @ObservationIgnored private var lastLatencyMs = 0.0
    @ObservationIgnored private var debugVisible = false
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    @ObservationIgnored private var settingsToken: NSObjectProtocol?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var restartCount = 0
    @ObservationIgnored private var activeLocale = ""
    @ObservationIgnored private var activeDevice = ""
    @ObservationIgnored private var activeRemoveEmptyLines = true
    @ObservationIgnored private var editingScriptID: UUID?
    @ObservationIgnored private var localeWarning: String?

    init(store: ScriptStore? = nil, prompter: PrompterWindowController? = nil,
         capture: AudioCapture = AudioCapture(), engine: AppleSpeechEngine = AppleSpeechEngine(),
         defaults: UserDefaults = .standard) {
        self.store = store ?? ScriptStore()
        self.prompter = prompter ?? PrompterWindowController()
        self.capture = capture
        self.engine = engine
        self.defaults = defaults
        defaults.register(defaults: SettingsKeys.defaults)
        applySettings()
        wireCallbacks()
        settingsToken = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                object: defaults, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsChanged() }
        }
    }

    deinit {
        if let settingsToken { NotificationCenter.default.removeObserver(settingsToken) }
    }

    func launch() {
        openLastScript()
        prompter.show()
        if store.scripts.isEmpty { onOpenLibrary?() }
    }

    func openLastScript() {
        let savedID = defaults.string(forKey: SettingsKeys.lastScriptID).flatMap(UUID.init(uuidString:))
        let script = savedID.flatMap(store.script(id:)) ?? store.scripts.first
        if let script { openScript(id: script.id) }
        else { prompter.setScript(text: "", tokens: []) }
    }

    func openScript(id: UUID) {
        guard let script = store.script(id: id) else { return }
        if state.isRunning || isPreparing { pause() }
        currentScriptID = id
        selectedScriptID = id
        // Avant toute écriture dans UserDefaults : la notification de changement est
        // synchrone, et settingsChanged rouvrirait le script en boucle si cet état était périmé.
        activeRemoveEmptyLines = defaults.bool(forKey: SettingsKeys.removeEmptyLines)
        defaults.set(id.uuidString, forKey: SettingsKeys.lastScriptID)
        sourceTokens = Tokenizer.tokenize(script.body)
        displayedText = activeRemoveEmptyLines
            ? ScriptStore.removingEmptyLines(script.body) : script.body
        displayedTokens = Tokenizer.tokenize(displayedText)
        matcher = ScriptMatcher(tokens: displayedTokens, allowBackward: defaults.bool(forKey: SettingsKeys.allowBackward))
        let index = editingScriptID == id
            ? Self.nearestWordIndex(to: script.lastCharOffset, in: sourceTokens)
            : Self.wordIndex(at: script.lastCharOffset, in: sourceTokens)
        editingScriptID = nil
        matcher.reanchor(to: index)
        prompter.setScript(text: displayedText, tokens: displayedTokens)
        prompter.setCursor(wordIndex: index, animated: false)
        prompter.show()
        if !displayedTokens.isEmpty { prompter.showMessage(nil, actionTitle: nil, action: nil) }
        updateDebug()
    }

    func edit() {
        pause()
        savePosition()
        editingScriptID = currentScriptID
        selectedScriptID = currentScriptID
        onOpenLibrary?()
    }

    func playPause() {
        switch state {
        case .listening, .preparing: pause()
        case .idle, .paused, .error: play()
        }
    }

    func play() {
        guard !displayedTokens.isEmpty else {
            prompter.showMessage("Aucun script. Appuie sur ✎ pour en coller un.", actionTitle: nil, action: nil)
            return
        }
        guard !state.isRunning && !isPreparing else { return }
        generation = UUID()
        let session = generation
        restartCount = 0
        localeWarning = nil
        let mode = driver.mode
        activeLocale = defaults.string(forKey: SettingsKeys.recognitionLocale) ?? ""
        activeDevice = defaults.string(forKey: SettingsKeys.audioInputUID) ?? ""
        if mode == .constant {
            setState(.listening)
            return
        }
        setState(.preparing(message: mode == .voice ? "Préparation de la reconnaissance vocale…" : "Préparation du micro…", progress: nil))
        playbackTask = Task { [weak self] in
            guard let self else { return }
            await stopTask?.value
            guard generation == session else { return }
            do {
                if mode == .voice {
                    let locale = await LocaleResolver.resolve(scriptText: displayedText, preferredIdentifier: activeLocale)
                    if !activeLocale.isEmpty,
                       Locale(identifier: activeLocale).language.languageCode?.identifier != locale.language.languageCode?.identifier {
                        localeWarning = "Langue indisponible. Repli sur \(LocaleResolver.displayName(for: locale)). Vérifie la langue dans Réglages."
                    }
                    let words = VocabularyExtractor.contextualWords(in: displayedText)
                    try await engine.prepare(locale: locale, contextualWords: words) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            guard let self, self.generation == session else { return }
                            self.setState(.preparing(message: "Téléchargement du modèle \(LocaleResolver.displayName(for: locale))…", progress: progress))
                        }
                    }
                } else {
                    guard await SpeechPermissions.requestMicrophone() else { throw SpeechEngineError.permissionDenied }
                }
                guard generation == session else { return }
                let audio = try capture.start(deviceUID: activeDevice.isEmpty ? nil : activeDevice)
                guard generation == session else { capture.stop(); return }
                if mode == .voice {
                    try await engine.start(audio: audio)
                    guard generation == session else { capture.stop(); await engine.stop(); return }
                    consumeUpdates(session: session)
                }
                setState(.listening)
                if let localeWarning { prompter.showMessage(localeWarning, actionTitle: nil, action: nil) }
            } catch {
                guard generation == session else { return }
                capture.stop()
                await engine.stop()
                showFailure(error)
            }
        }
    }

    func pause() {
        guard state != .idle else { return }
        generation = UUID()
        playbackTask?.cancel()
        playbackTask = nil
        updateTask?.cancel()
        updateTask = nil
        capture.stop()
        stopTask = Task { [engine] in await engine.stop() }
        savePosition()
        setState(.paused)
    }

    func restart() {
        matcher.reset()
        driver = ScrollDriver(mode: driver.mode, speed: driver.speed, thresholdDb: driver.thresholdDb)
        prompter.setCursor(wordIndex: -1, animated: state.isRunning)
        savePosition()
        updateDebug()
    }

    func close() {
        savePosition()
        generation = UUID()
        playbackTask?.cancel()
        updateTask?.cancel()
        capture.stop()
        stopTask = Task { [engine] in await engine.stop() }
        setState(.idle)
        prompter.hide()
        store.flush()
    }

    func terminate() {
        close()
        store.flush()
    }

    static func wordIndex(at offset: Int, in tokens: [ScriptToken]) -> Int {
        guard !tokens.isEmpty else { return -1 }
        return tokens.firstIndex { NSMaxRange($0.range) > offset } ?? tokens.count - 1
    }

    static func nearestWordIndex(to offset: Int, in tokens: [ScriptToken]) -> Int {
        guard !tokens.isEmpty else { return -1 }
        return tokens.indices.min { left, right in
            let a = tokens[left].range
            let b = tokens[right].range
            let aDistance = max(a.location - offset, offset - NSMaxRange(a), 0)
            let bDistance = max(b.location - offset, offset - NSMaxRange(b), 0)
            return aDistance == bDistance ? left < right : aDistance < bDistance
        } ?? -1
    }

    private var isPreparing: Bool {
        if case .preparing = state { return true }
        return false
    }

    private func wireCallbacks() {
        prompter.onEdit = { [weak self] in self?.edit() }
        prompter.onPlayPause = { [weak self] in self?.playPause() }
        prompter.onRestart = { [weak self] in self?.restart() }
        prompter.onClose = { [weak self] in self?.close() }
        prompter.onManualReanchor = { [weak self] index in
            guard let self else { return }
            matcher.reanchor(to: index)
            prompter.setCursor(wordIndex: matcher.cursor, animated: false)
            savePosition()
            updateDebug()
        }
        prompter.onFrame = { [weak self] dt in
            guard let self, state.isRunning else { return 0 }
            return driver.step(dt: dt, levelDb: levelDb)
        }
        prompter.onFontSizeStep = { [weak self] step in self?.stepFontSize(step) }
        prompter.onSpeedStep = { [weak self] step in self?.stepSpeed(step) }
        prompter.onToggleDebug = { [weak self] in
            guard let self else { return }
            debugVisible.toggle()
            updateDebug()
        }
        capture.onLevel = { [weak self] level in
            MainActor.assumeIsolated { self?.levelDb = level; self?.updateDebug() }
        }
        capture.onDeviceLost = { [weak self] in
            MainActor.assumeIsolated {
                self?.prompter.showMessage("Entrée audio débranchée. Micro par défaut utilisé.", actionTitle: nil, action: nil)
            }
        }
        engine.onError = { [weak self] error in
            Task { @MainActor [weak self] in self?.handleEngineError(error) }
        }
    }

    private func consumeUpdates(session: UUID) {
        updateTask?.cancel()
        let stream = engine.updates
        updateTask = Task { [weak self] in
            for await update in stream {
                guard let self, !Task.isCancelled, generation == session, state.isRunning else { break }
                let changed = matcher.ingest(update)
                lastLatencyMs = max(0, Date().timeIntervalSince(update.timestamp) * 1_000)
                if changed { prompter.setCursor(wordIndex: matcher.cursor, animated: true) }
                if changed { restartCount = 0 }
                updateDebug()
            }
        }
    }

    private func handleEngineError(_ error: SpeechEngineError) {
        guard state.isRunning, driver.mode == .voice else { return }
        guard restartCount < 3 else {
            pause()
            showFailure(SpeechEngineError.engineFailure("Trois redémarrages ont échoué. Réessaie ou passe en mode Constant."))
            return
        }
        restartCount += 1
        let session = generation
        updateTask?.cancel()
        capture.stop()
        Task { [weak self] in
            guard let self else { return }
            await engine.stop()
            guard generation == session, state.isRunning else { return }
            do {
                let audio = try capture.start(deviceUID: activeDevice.isEmpty ? nil : activeDevice)
                try await engine.start(audio: audio)
                guard generation == session, state.isRunning else { capture.stop(); await engine.stop(); return }
                consumeUpdates(session: session)
            } catch {
                handleEngineError(error as? SpeechEngineError ?? .engineFailure(error.localizedDescription))
            }
        }
    }

    private func savePosition() {
        guard let id = currentScriptID else { return }
        let index = matcher.cursor
        let offset = sourceTokens.indices.contains(index) ? sourceTokens[index].range.location : 0
        store.setLastCharOffset(id: id, offset)
        store.flush()
    }

    private func setState(_ newState: PlaybackState) {
        state = newState
        prompter.setPlaybackState(newState)
    }

    private func showFailure(_ error: Error) {
        let message = error.localizedDescription
        setState(.error(message))
        if let speechError = error as? SpeechEngineError, case .permissionDenied = speechError {
            prompter.showMessage(message, actionTitle: "Ouvrir les Réglages Système") {
                NSWorkspace.shared.open(SpeechPermissions.microphoneSettingsURL)
            }
        } else {
            prompter.showMessage("\(message) Passe en mode Constant ou réessaie.", actionTitle: "Réessayer") { [weak self] in
                self?.play()
            }
        }
    }

    private func updateDebug() {
        guard debugVisible else { prompter.setDebugText(nil); return }
        let info = matcher.lastDebug
        let text = "H: \(info.heardTail.joined(separator: " ")) | volatil: \(info.volatileText) | curseur: \(info.cursor) | e: \(info.bestEnd.map(String.init) ?? "-") | score: \(String(format: "%.2f", info.score)) | \(info.zone) | \(Int(lastLatencyMs)) ms | \(Int(levelDb)) dBFS"
        prompter.setDebugText(text)
    }

    private func stepFontSize(_ step: Int) {
        let size = step == 0 ? 32 : min(120, max(16, defaults.double(forKey: SettingsKeys.fontSize) + Double(step) * 2))
        defaults.set(size, forKey: SettingsKeys.fontSize)
        applySettings()
    }

    private func stepSpeed(_ step: Int) {
        guard driver.mode == .constant else { return }
        let speed = min(200, max(10, defaults.double(forKey: SettingsKeys.constantSpeed) + Double(step) * 10))
        defaults.set(speed, forKey: SettingsKeys.constantSpeed)
        applySettings()
    }

    private func settingsChanged() {
        let oldMode = driver.mode
        let mode = ScrollMode(rawValue: defaults.string(forKey: SettingsKeys.scrollMode) ?? "") ?? .voice
        let changedInput = activeDevice != (defaults.string(forKey: SettingsKeys.audioInputUID) ?? "")
        let changedLocale = activeLocale != (defaults.string(forKey: SettingsKeys.recognitionLocale) ?? "")
        let running = state.isRunning || isPreparing
        let changedLines = defaults.bool(forKey: SettingsKeys.removeEmptyLines) != activeRemoveEmptyLines
        applySettings()
        if changedLines, let currentScriptID {
            savePosition()
            openScript(id: currentScriptID)
            if running { play() }
            return
        }
        if running && (oldMode != mode || changedInput || changedLocale) {
            pause()
            play()
        }
    }

    private func applySettings() {
        prompter.apply(SettingsKeys.currentAppearance(defaults))
        let mode = ScrollMode(rawValue: defaults.string(forKey: SettingsKeys.scrollMode) ?? "") ?? .voice
        driver.mode = mode
        driver.speed = min(200, max(10, defaults.double(forKey: SettingsKeys.constantSpeed)))
        driver.thresholdDb = min(-20, max(-70, defaults.double(forKey: SettingsKeys.soundThresholdDb)))
        matcher.allowBackward = defaults.bool(forKey: SettingsKeys.allowBackward)
    }
}
