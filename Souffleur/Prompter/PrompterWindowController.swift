import AppKit
import QuartzCore

@MainActor
final class PrompterWindowController: NSObject {
    var onFrame: ((TimeInterval) -> CGFloat)?
    var onEdit: (() -> Void)?
    var onPlayPause: (() -> Void)?
    var onRestart: (() -> Void)?
    var onClose: (() -> Void)?
    var onManualReanchor: ((Int) -> Void)?
    var onFontSizeStep: ((Int) -> Void)?
    var onSpeedStep: ((Int) -> Void)?
    var onToggleDebug: (() -> Void)?

    private let panel: PrompterPanel
    private let pill = ControlPillPanel()
    private let root = HoverView()
    private let scroll = PrompterScrollView()
    private let textView = PrompterTextView()
    private let black = NSView()
    private let message = NSStackView()
    private let messageLabel = NSTextField(labelWithString: "")
    private let messageButton = FirstClickActionButton()
    private let debugLabel = NSTextField(labelWithString: "")
    private let animator = ScrollAnimator()
    private var appearance = PrompterAppearance()
    private var state: PlaybackState = .idle
    private var cursor = -1
    private var manualScrolling = false
    private var manualEnd: Timer?
    private var hidePillTimer: Timer?
    private var overMain = false
    private var overPill = false
    private var messageAction: (() -> Void)?
    var demoTimer: Timer?

    override init() {
        let initial = NSRect(x: 0, y: 0, width: 560, height: 320)
        panel = PrompterPanel(contentRect: initial, styleMask: [.titled, .fullSizeContentView, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.styleMask.insert(.fullSizeContentView)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 280, height: 120)
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        if !panel.setFrameUsingName("SouffleurPrompterFrame"), let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrame(NSRect(x: visible.midX - 280, y: visible.maxY - 320, width: 560, height: 320), display: false)
        }
        panel.setFrameAutosaveName("SouffleurPrompterFrame")
        setupView()
        panel.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        root.onHover = { [weak self] inside in self?.overMain = inside; self?.updatePillVisibility() }
        pill.onHover = { [weak self] inside in self?.overPill = inside; self?.updatePillVisibility() }
        pill.onAction = { [weak self] button in self?.perform(button) }
        scroll.onManualScroll = { [weak self] event in self?.manualScroll(event) }
        animator.onStep = { [weak self] dt in self?.frame(dt) }
        NotificationCenter.default.addObserver(self, selector: #selector(windowGeometryChanged), name: NSWindow.didResizeNotification, object: panel)
        NotificationCenter.default.addObserver(self, selector: #selector(windowGeometryChanged), name: NSWindow.didMoveNotification, object: panel)
        apply(appearance)
        setScript(text: "", tokens: [])
    }

    deinit {
        demoTimer?.invalidate()
        manualEnd?.invalidate()
        hidePillTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        panel.orderFrontRegardless()
        panel.addChildWindow(pill, ordered: .above)
        positionPill()
        pill.orderFrontRegardless()
        updatePillVisibility()
        animator.start(on: root)
    }

    func hide() {
        animator.stop()
        pill.orderOut(nil)
        panel.orderOut(nil)
    }

    func setScript(text: String, tokens: [ScriptToken]) {
        let length = (text as NSString).length
        let valid = tokens.filter { $0.range.location >= 0 && $0.range.length > 0 && NSMaxRange($0.range) <= length }
        textView.configure(text: text, tokens: valid, appearance: appearance, spokenIndex: cursor)
        pill.setPlayEnabled(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showMessage("Aucun script. Appuie sur ✎ pour en coller un.", actionTitle: nil, action: nil)
        } else if messageLabel.stringValue.hasPrefix("Aucun script") {
            showMessage(nil, actionTitle: nil, action: nil)
        }
        recalculate(animated: false)
    }

    func setCursor(wordIndex: Int, animated: Bool) {
        cursor = min(max(wordIndex, -1), textView.tokens.count - 1)
        textView.updateSpokenIndex(cursor)
        recalculate(animated: animated && (state.isRunning || cursor != 0) && cursor >= 0)
    }

    func apply(_ appearance: PrompterAppearance) {
        self.appearance = appearance
        textView.updateAppearance(appearance)
        black.layer?.backgroundColor = NSColor.black.withAlphaComponent(appearance.backgroundOpacity.clamped(to: 0...0.95)).cgColor
        textView.layer?.setAffineTransform(CGAffineTransform(scaleX: appearance.mirror ? -1 : 1, y: 1))
        recalculate(animated: false)
    }

    func setPlaybackState(_ state: PlaybackState) {
        let wasPreparing: Bool
        if case .preparing = self.state { wasPreparing = true } else { wasPreparing = false }
        self.state = state
        pill.setPlaybackState(state)
        switch state {
        case .preparing(let text, _):
            if let text { showMessage(text, actionTitle: nil, action: nil) }
        case .error(let text): showMessage(text, actionTitle: nil, action: nil)
        default:
            if wasPreparing { showMessage(nil, actionTitle: nil, action: nil) }
        }
        updatePillVisibility()
    }

    func setDebugText(_ text: String?) {
        debugLabel.stringValue = text ?? ""
        debugLabel.isHidden = text == nil
    }

    func showMessage(_ text: String?, actionTitle: String?, action: (() -> Void)?) {
        message.isHidden = text == nil
        messageLabel.stringValue = text ?? ""
        messageAction = action
        messageButton.isHidden = actionTitle == nil || action == nil
        messageButton.title = actionTitle ?? ""
    }

    var wordIndexAtReadingLine: Int {
        let y = scroll.contentView.bounds.minY + scroll.contentView.bounds.height * CGFloat(appearance.readingLine.clamped(to: 0...0.5))
        return textView.firstWordIndex(onLineAt: y)
    }

    private func setupView() {
        root.frame = panel.contentView?.bounds ?? .zero
        root.autoresizingMask = [.width, .height]
        root.wantsLayer = true
        root.layer?.cornerRadius = 16
        root.layer?.masksToBounds = true
        black.frame = root.bounds
        black.autoresizingMask = [.width, .height]
        black.wantsLayer = true
        root.addSubview(black)
        let glass = NSGlassEffectView(frame: root.bounds)
        glass.style = .regular
        glass.cornerRadius = 16
        glass.autoresizingMask = [.width, .height]
        root.addSubview(glass)
        scroll.frame = root.bounds.insetBy(dx: 16, dy: 10)
        scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false
        scroll.wantsLayer = true
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.verticalScrollElasticity = .none
        textView.drawsBackground = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.frame = NSRect(x: 0, y: 0, width: scroll.bounds.width, height: scroll.bounds.height)
        textView.wantsLayer = true
        scroll.documentView = textView
        root.addSubview(scroll)
        message.orientation = .vertical
        message.alignment = .centerX
        message.spacing = 8
        messageLabel.maximumNumberOfLines = 3
        messageLabel.alignment = .center
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageButton.target = self
        messageButton.action = #selector(messagePressed)
        message.addArrangedSubview(messageLabel)
        message.addArrangedSubview(messageButton)
        root.addSubview(message)
        debugLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        debugLabel.textColor = .white
        debugLabel.backgroundColor = NSColor.black.withAlphaComponent(0.6)
        debugLabel.drawsBackground = true
        debugLabel.lineBreakMode = .byTruncatingTail
        debugLabel.isHidden = true
        root.addSubview(debugLabel)
        panel.contentView = root
        layoutOverlays()
        updateFadeMask()
    }

    private func layoutOverlays() {
        message.frame = NSRect(x: 16, y: max(0, (root.bounds.height - 90) / 2), width: max(0, root.bounds.width - 32), height: 90)
        debugLabel.frame = NSRect(x: 12, y: 8, width: max(0, root.bounds.width - 24), height: 24)
    }

    private func updateFadeMask() {
        let fade = CAGradientLayer()
        fade.frame = scroll.bounds
        let fraction = min(0.5, 24 / max(scroll.bounds.height, 1))
        fade.colors = [NSColor.clear.cgColor, NSColor.white.cgColor, NSColor.white.cgColor, NSColor.clear.cgColor]
        fade.locations = [0, NSNumber(value: Double(fraction)), NSNumber(value: Double(1 - fraction)), 1]
        scroll.layer?.mask = fade
    }

    private func recalculate(animated: Bool) {
        textView.frame.size.width = scroll.contentSize.width
        let height = max(scroll.contentSize.height, textView.laidOutHeight)
        textView.frame.size.height = height
        let lineY = cursor >= 0 ? (textView.lineRect(for: cursor)?.minY ?? 0) : 0
        let target = PrompterLayout.targetY(lineY: lineY, visibleHeight: scroll.contentSize.height, contentHeight: height, readingLine: CGFloat(appearance.readingLine))
        if animated {
            animator.target = target
        } else {
            animator.snap(to: target)
            scrollTo(target)
        }
    }

    private func scrollTo(_ y: CGFloat) {
        let maxY = max(0, textView.frame.height - scroll.contentSize.height)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: min(max(0, y), maxY)))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    private func frame(_ dt: TimeInterval) {
        if !manualScrolling, let extra = onFrame?(dt), extra.isFinite {
            animator.target = min(max(0, animator.target + extra), max(0, textView.frame.height - scroll.contentSize.height))
        }
        if !manualScrolling { scrollTo(animator.position) }
    }

    private func manualScroll(_ event: NSEvent) {
        manualScrolling = true
        animator.snap(to: scroll.contentView.bounds.minY)
        manualEnd?.invalidate()
        if event.phase == .ended || event.momentumPhase == .ended {
            finishManualScroll()
        } else {
            manualEnd = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.finishManualScroll() }
            }
        }
    }

    private func finishManualScroll() {
        manualEnd?.invalidate()
        manualEnd = nil
        animator.snap(to: scroll.contentView.bounds.minY)
        manualScrolling = false
        let index = wordIndexAtReadingLine
        if index >= 0 { onManualReanchor?(index) }
    }

    private func positionPill() {
        let frame = panel.frame
        pill.setFrameOrigin(NSPoint(x: frame.midX - pill.frame.width / 2, y: frame.minY - pill.frame.height * 0.7))
    }

    private func updatePillVisibility() {
        hidePillTimer?.invalidate()
        let visible = !state.isRunning || overMain || overPill
        if visible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                pill.animator().alphaValue = 1
            }
        } else {
            hidePillTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.overMain, !self.overPill, self.state.isRunning else { return }
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.25
                        self.pill.animator().alphaValue = 0
                    }
                }
            }
        }
    }

    private func perform(_ button: ControlPillPanel.Button) {
        switch button {
        case .edit: onEdit?()
        case .playPause: onPlayPause?()
        case .restart: onRestart?()
        case .close: onClose?()
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if flags == [], event.keyCode == 49 { onPlayPause?(); return true }
        if flags == [], event.keyCode == 53 { onClose?(); return true }
        if flags == [.command] {
            switch key {
            case "r": onRestart?(); return true
            case "e": onEdit?(); return true
            case "+", "=": onFontSizeStep?(1); return true
            case "-": onFontSizeStep?(-1); return true
            case "0": onFontSizeStep?(0); return true
            default: break
            }
        }
        if flags == [.command, .shift] && (key == "+" || key == "=") { onFontSizeStep?(1); return true }
        if flags == [.command, .option] && key == "d" { onToggleDebug?(); return true }
        if flags == [] {
            switch event.keyCode {
            case 123: onSpeedStep?(-1); return true
            case 124: onSpeedStep?(1); return true
            case 125, 126:
                let current = wordIndexAtReadingLine
                let direction = event.keyCode == 125 ? 1 : -1
                let next = lineAdjacent(to: current, direction: direction)
                if next >= 0 { onManualReanchor?(next); setCursor(wordIndex: next, animated: false) }
                return true
            default: break
            }
        }
        return false
    }

    private func lineAdjacent(to index: Int, direction: Int) -> Int {
        guard textView.tokens.indices.contains(index), let currentY = textView.lineRect(for: index)?.minY else { return -1 }
        var candidate = index + direction
        while textView.tokens.indices.contains(candidate) {
            if let rect = textView.lineRect(for: candidate), abs(rect.minY - currentY) > 1 {
                return textView.firstWordIndex(onLineAt: rect.minY)
            }
            candidate += direction
        }
        return index
    }

    @objc private func windowGeometryChanged() {
        positionPill()
        layoutOverlays()
        updateFadeMask()
        recalculate(animated: false)
    }

    @objc private func messagePressed() { messageAction?() }
}

@MainActor
private final class FirstClickActionButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
