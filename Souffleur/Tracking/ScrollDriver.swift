import Foundation
import CoreGraphics

struct ScrollDriver {
    var mode: ScrollMode
    var speed: Double
    var thresholdDb: Double
    private var attackTime = 0.0
    private var holdTime = 0.0
    private let attackDuration = 0.08
    private let holdDuration = 0.4

    init(mode: ScrollMode, speed: Double, thresholdDb: Double) {
        self.mode = mode
        self.speed = speed
        self.thresholdDb = thresholdDb
    }

    mutating func step(dt: TimeInterval, levelDb: Double) -> CGFloat {
        guard dt > 0, dt.isFinite, speed.isFinite, speed > 0 else { return 0 }
        switch mode {
        case .voice:
            return 0
        case .constant:
            return CGFloat(speed * dt)
        case .sound:
            if levelDb >= thresholdDb {
                let previous = attackTime
                attackTime = min(attackDuration, attackTime + dt)
                guard attackTime >= attackDuration else { return 0 }
                holdTime = holdDuration
                return CGFloat(speed * (dt - max(0, attackDuration - previous)))
            }
            attackTime = 0
            let active = min(dt, holdTime)
            holdTime = max(0, holdTime - dt)
            return CGFloat(speed * active)
        }
    }
}
