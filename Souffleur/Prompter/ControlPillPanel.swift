import AppKit

@MainActor
final class ControlPillPanel: NSPanel {
    enum Button: Int { case edit, playPause, restart, close }
    var onAction: ((Button) -> Void)?
    var onHover: ((Bool) -> Void)?
    private let playButton = FirstClickButton()
    private let progress = NSProgressIndicator()
    private let hover = HoverView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 204, height: 52),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true
        hover.frame = NSRect(x: 0, y: 0, width: 204, height: 52)
        hover.onHover = { [weak self] inside in self?.onHover?(inside) }
        let glass = NSGlassEffectView(frame: hover.bounds)
        glass.style = .regular
        glass.cornerRadius = 26
        glass.autoresizingMask = [.width, .height]
        hover.addSubview(glass)
        let symbols = ["pencil", "play.fill", "arrow.counterclockwise", "xmark"]
        let labels = ["Éditer", "Lecture ou pause", "Recommencer", "Fermer"]
        for index in 0..<4 {
            let button = index == 1 ? playButton : FirstClickButton()
            button.frame = NSRect(x: 12 + CGFloat(index) * 48, y: 8, width: 36, height: 36)
            button.isBordered = false
            button.image = NSImage(systemSymbolName: symbols[index], accessibilityDescription: labels[index])
            button.contentTintColor = NSColor.white.withAlphaComponent(0.9)
            button.toolTip = labels[index]
            button.setAccessibilityLabel(labels[index])
            button.tag = index
            button.target = self
            button.action = #selector(pressed(_:))
            hover.addSubview(button)
        }
        progress.frame = playButton.frame.insetBy(dx: 7, dy: 7)
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        hover.addSubview(progress)
        contentView = hover
    }

    func setPlaybackState(_ state: PlaybackState) {
        let preparing: Bool
        if case .preparing = state { preparing = true } else { preparing = false }
        if preparing { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
        playButton.isHidden = preparing
        playButton.image = NSImage(systemSymbolName: state.isRunning ? "pause.fill" : "play.fill", accessibilityDescription: "Lecture ou pause")
        playButton.contentTintColor = state.isRunning ? .systemRed : NSColor.white.withAlphaComponent(0.9)
    }

    func setPlayEnabled(_ enabled: Bool) { playButton.isEnabled = enabled }

    @objc private func pressed(_ sender: NSButton) {
        guard let button = Button(rawValue: sender.tag) else { return }
        onAction?(button)
    }
}

@MainActor
private final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
