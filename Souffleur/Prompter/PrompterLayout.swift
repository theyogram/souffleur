import AppKit

enum PrompterLayout {
    static func targetY(lineY: CGFloat, visibleHeight: CGFloat, contentHeight: CGFloat, readingLine: CGFloat) -> CGFloat {
        let fraction = min(max(readingLine, 0), 0.5)
        let maxY = max(0, contentHeight - visibleHeight)
        return min(max(0, lineY - fraction * visibleHeight), maxY)
    }
}
