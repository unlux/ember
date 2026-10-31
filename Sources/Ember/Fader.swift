import Foundation
import EmberCore

/// Moves the screen from its current tint to a new one over a short time.
@MainActor
final class Fader {
    private let gamma: GammaController
    private var timer: Timer?

    init(gamma: GammaController) {
        self.gamma = gamma
    }

    /// Fades to `target`, or back to normal colours when `target` is nil.
    /// Starting a new fade mid-way continues from whatever is on screen.
    func fade(to target: Tint?, duration: TimeInterval) {
        cancel()
        let from = gamma.currentTint ?? .neutral
        let to = target ?? .neutral
        guard duration > 0, from != to else {
            finish(at: target)
            return
        }
        let start = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.step(from: from, to: to, target: target, start: start, duration: duration)
            }
        }
        // .common so the fade keeps running while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func step(from: Tint, to: Tint, target: Tint?, start: Date, duration: TimeInterval) {
        let progress = Date().timeIntervalSince(start) / duration
        if progress >= 1 {
            cancel()
            finish(at: target)
        } else {
            gamma.show(from.blended(with: to, by: Easing.easeInOut(progress)))
        }
    }

    /// Stops a fade where it is.
    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    private func finish(at target: Tint?) {
        if let target {
            gamma.show(target)
        } else {
            gamma.restore()
        }
    }
}
