import AppKit
import QuartzCore

/// Fait glisser la position vers la cible à la vitesse de lecture estimée.
/// La cible avance par à-coups (un mot à la fois) ; au lieu d'accélérer puis de freiner
/// à chaque mot, on suit le rythme moyen des dernières avancées, avec une correction
/// proportionnelle pour rester calé.
@MainActor
final class ScrollAnimator: NSObject {
    var onStep: ((TimeInterval) -> Void)?
    var position: CGFloat = 0
    var target: CGFloat = 0 {
        didSet { if !snapping { noteAdvance(target - oldValue, at: clock()) } }
    }
    /// Horloge injectable pour les tests.
    var clock: () -> CFTimeInterval = CACurrentMediaTime

    private var velocity: CGFloat = 0
    /// Vitesse de lecture estimée, en points par seconde.
    private var rate: CGFloat = 0
    /// Taille moyenne d'une avancée (un mot), en points.
    private var stride: CGFloat = 0
    private var lastAdvance: CFTimeInterval?
    private var pendingAdvance: CGFloat = 0
    private var snapping = false
    private var lastTimestamp: CFTimeInterval?
    private var displayLink: CADisplayLink?

    private enum Tuning {
        static let rateBlend: CGFloat = 0.3          // poids de la dernière mesure dans la moyenne
        static let maxRate: CGFloat = 800
        static let minSample: CFTimeInterval = 0.05  // regroupe les avancées trop rapprochées
        static let maxSample: CFTimeInterval = 1.5   // au-delà : pause, la mesure ne compte pas
        static let feedWindow: CFTimeInterval = 0.9  // durée pendant laquelle le rythme est entretenu
        static let baseShare: CGFloat = 0.85         // part du rythme quand on touche la cible
        static let gapShare: CGFloat = 0.3           // correction douce selon l'écart (en mots)
        static let catchUpStrides: CGFloat = 2       // au-delà : rattrapage franc
        static let forwardGain: CGFloat = 2.5
        static let backwardGain: CGFloat = 8
        static let smoothing: CGFloat = 0.12         // constante de temps du lissage de vitesse (s)
    }

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
        snapping = true
        position = value
        target = value
        snapping = false
        velocity = 0
        pendingAdvance = 0
        lastAdvance = nil
    }

    /// Met à jour l'estimation du rythme quand la cible avance.
    func noteAdvance(_ delta: CGFloat, at now: CFTimeInterval) {
        guard delta > 0 else { return }
        guard let last = lastAdvance else {
            lastAdvance = now
            return
        }
        pendingAdvance += delta
        let elapsed = now - last
        guard elapsed >= Tuning.minSample else { return }
        if elapsed <= Tuning.maxSample {
            let speed = min(pendingAdvance / CGFloat(elapsed), Tuning.maxRate)
            rate = rate == 0 ? speed : rate * (1 - Tuning.rateBlend) + speed * Tuning.rateBlend
            stride = stride == 0 ? pendingAdvance : stride * (1 - Tuning.rateBlend) + pendingAdvance * Tuning.rateBlend
        }
        pendingAdvance = 0
        lastAdvance = now
    }

    /// Avance la position d'un pas de temps. Séparé du displayLink pour être testable.
    func advance(by dt: TimeInterval, now: CFTimeInterval) {
        let step = CGFloat(dt)
        guard step > 0 else { return }
        let gap = target - position
        let desired: CGFloat
        if gap > 0 {
            let feeding = rate > 0 && stride > 0 && (lastAdvance.map { now - $0 < Tuning.feedWindow } ?? false)
            if feeding {
                // On glisse au rythme de lecture en gardant environ un demi-mot de retard :
                // la cible saute d'un mot à la fois, la position, elle, ne s'arrête pas.
                let excess = max(0, gap - Tuning.catchUpStrides * stride)
                desired = rate * (Tuning.baseShare + Tuning.gapShare * min(gap, Tuning.catchUpStrides * stride) / stride)
                    + excess * Tuning.forwardGain
            } else {
                desired = gap * Tuning.forwardGain
            }
        } else {
            desired = gap * Tuning.backwardGain
        }
        velocity += (desired - velocity) * (1 - exp(-step / Tuning.smoothing))
        var move = velocity * step
        // Jamais au-delà de la cible : pas de rebond.
        if gap > 0 { move = min(max(move, 0), gap) } else if gap < 0 { move = max(min(move, 0), gap) } else { move = 0 }
        position += move
        if abs(target - position) < 0.05 { position = target }
    }

    @objc private func frame(_ link: CADisplayLink) {
        let dt = min(max(link.timestamp - (lastTimestamp ?? link.timestamp), 0), 1.0 / 20)
        lastTimestamp = link.timestamp
        onStep?(dt)
        advance(by: dt, now: clock())
    }
}
