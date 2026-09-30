import AppKit

@MainActor
final class PrompterTextView: NSTextView {
    override var mouseDownCanMoveWindow: Bool { true }
    private(set) var tokens: [ScriptToken] = []
    private var script = ""
    private var prompterAppearance = PrompterAppearance()
    private var spokenIndex = -1

    init() {
        let storage = NSTextContentStorage()
        let manager = NSTextLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 560, height: CGFloat.greatestFiniteMagnitude))
        storage.addTextLayoutManager(manager)
        manager.textContainer = container
        super.init(frame: .zero, textContainer: container)
    }

    required init?(coder: NSCoder) { nil }

    func configure(text: String, tokens: [ScriptToken], appearance: PrompterAppearance, spokenIndex: Int) {
        script = text
        self.tokens = tokens
        self.prompterAppearance = appearance
        self.spokenIndex = spokenIndex
        refresh()
    }

    func updateAppearance(_ value: PrompterAppearance) {
        prompterAppearance = value
        refresh()
    }

    func updateSpokenIndex(_ value: Int) {
        let previous = spokenIndex
        spokenIndex = value
        guard prompterAppearance.dimSpokenText, let storage = textStorage else { return }
        let start = max(0, min(previous, value) + 1)
        let end = min(tokens.count, max(previous, value) + 1)
        guard start < end else { return }
        storage.beginEditing()
        for index in start..<end {
            let range = tokens[index].range
            guard NSMaxRange(range) <= storage.length else { continue }
            let color = index <= value ? NSColor.white.withAlphaComponent(0.4) : NSColor.white
            storage.addAttribute(.foregroundColor, value: color, range: range)
        }
        storage.endEditing()
    }

    private func refresh() {
        let fontSize = CGFloat(prompterAppearance.fontSize.clamped(to: 16...120))
        let base = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let font: NSFont
        switch prompterAppearance.fontFamily {
        case .system: font = base
        case .rounded: font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: fontSize) ?? base
        case .serif: font = NSFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: fontSize) ?? base
        case .mono: font = NSFont(descriptor: base.fontDescriptor.withDesign(.monospaced) ?? base.fontDescriptor, size: fontSize) ?? base
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = CGFloat(prompterAppearance.lineSpacing.clamped(to: 0.8...2))
        paragraph.alignment = switch prompterAppearance.alignment {
        case .left: .left
        case .center: .center
        case .right: .right
        }
        let value = NSMutableAttributedString(string: script, attributes: [
            .font: font, .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ])
        if prompterAppearance.dimSpokenText && spokenIndex >= 0 {
            for token in tokens.prefix(spokenIndex + 1) where NSMaxRange(token.range) <= value.length {
                value.addAttribute(.foregroundColor, value: NSColor.white.withAlphaComponent(0.4), range: token.range)
            }
        }
        textStorage?.setAttributedString(value)
        needsDisplay = true
    }

    func lineRect(for index: Int) -> CGRect? {
        guard tokens.indices.contains(index),
              let manager = textLayoutManager,
              let storage = manager.textContentManager else { return nil }
        let offset = tokens[index].range.location
        guard offset >= 0, offset < (script as NSString).length,
              let location = storage.location(storage.documentRange.location, offsetBy: offset) else { return nil }
        guard let textRange = NSTextRange(location: location, end: location) else { return nil }
        manager.ensureLayout(for: textRange)
        guard let fragment = manager.textLayoutFragment(for: location) else { return nil }
        let fragmentStart = storage.offset(from: storage.documentRange.location, to: fragment.rangeInElement.location)
        for line in fragment.textLineFragments {
            let range = NSRange(location: fragmentStart + line.characterRange.location, length: line.characterRange.length)
            if NSLocationInRange(offset, range) || (offset == NSMaxRange(range) && line === fragment.textLineFragments.last) {
                return CGRect(x: textContainerOrigin.x + fragment.layoutFragmentFrame.minX + line.typographicBounds.minX,
                              y: textContainerOrigin.y + fragment.layoutFragmentFrame.minY + line.typographicBounds.minY,
                              width: line.typographicBounds.width,
                              height: line.typographicBounds.height)
            }
        }
        return nil
    }

    func firstWordIndex(onLineAt y: CGFloat) -> Int {
        guard !tokens.isEmpty else { return -1 }
        var low = 0
        var high = tokens.count
        while low < high {
            let middle = (low + high) / 2
            guard let line = lineRect(for: middle) else { return -1 }
            if line.minY < y { low = middle + 1 } else { high = middle }
        }
        var nearest = min(low, tokens.count - 1)
        if nearest > 0,
           let before = lineRect(for: nearest - 1),
           let after = lineRect(for: nearest),
           abs(before.minY - y) <= abs(after.minY - y) {
            nearest -= 1
        }
        guard let line = lineRect(for: nearest) else { return nearest }
        while nearest > 0, let previous = lineRect(for: nearest - 1), abs(previous.minY - line.minY) < 1 {
            nearest -= 1
        }
        return nearest
    }

    var laidOutHeight: CGFloat {
        guard let manager = textLayoutManager, let range = manager.textContentManager?.documentRange else { return bounds.height }
        manager.ensureLayout(for: range)
        return manager.usageBoundsForTextContainer.height + textContainerOrigin.y * 2
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { min(max(self, limits.lowerBound), limits.upperBound) }
}
