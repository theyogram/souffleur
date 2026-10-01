import AppKit
import QuartzCore

@MainActor
final class ScrollAnimator: NSObject {
    var onStep: ((TimeInterval) -> Void)?
    var position: CGFloat = 0
    var target: CGFloat = 0
    private var velocity: CGFloat = 0
    private var lastTimestamp: CFTimeInterval?
    private var displayLink: CADisplayLink?

    func start(on view: NSView) {
        guard displayLink == nil else { return }
        let link = view.displayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    func snap(to value: CGFloat) {
        position = value
        target = value
        velocity = 0
    }

    @objc private func frame(_ link: CADisplayLink) {
        let dt = min(max(link.timestamp - (lastTimestamp ?? link.timestamp), 0), 1.0 / 20)
        lastTimestamp = link.timestamp
        onStep?(dt)
        let omega: CGFloat = 12
        let step = CGFloat(dt)
        let acceleration = omega * omega * (target - position) - 2 * omega * velocity
        velocity += acceleration * step
        position += velocity * step
        if abs(position - target) < 0.05 && abs(velocity) < 0.05 {
            position = target
            velocity = 0
        }
    }
}
