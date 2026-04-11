import AppKit
import AVFoundation
import Observation

enum TimerMode: Equatable {
    case stopped
    case working
    case breaking
}

@MainActor @Observable
final class TimerState {
    private(set) var mode: TimerMode = .stopped
    private(set) var remainingSeconds: Int = 0
    var soundEnabled: Bool = true
    var onCycleComplete: (() -> Void)?

    private(set) var cycleStartDate: Date?
    private(set) var cycleDuration: TimeInterval = 0
    private(set) var frozenSliderOffset: CGFloat = 0

    // Winding animation state
    private(set) var isWinding: Bool = false
    private(set) var windStartDate: Date?
    private(set) var windDuration: TimeInterval = 0
    private(set) var windFromOffset: CGFloat = 0
    private(set) var windToOffset: CGFloat = 0

    private var timer: Timer?
    private var windCheckTimer: Timer?

    private let windupPlayer: AVAudioPlayer?
    private let clickSound: NSSound?
    private let dingSound: NSSound?

    private static let workMinutes = 25
    private static let breakMinutes = 5
    private static let windSpeed: CGFloat = 700 // points per second

    init() {
        windupPlayer = Self.loadPlayer("windup")
        clickSound = Self.loadSound("click")
        dingSound = Self.loadSound("ding")
    }

    var currentMinute: Int {
        Int(ceil(Double(remainingSeconds) / 60.0))
    }

    var iconName: String {
        switch mode {
        case .stopped:
            return "icon-0"
        case .working:
            return "icon-\(currentMinute)"
        case .breaking:
            return "icon-\(currentMinute)-break"
        }
    }

    func continuousSliderOffset(at date: Date) -> CGFloat {
        guard let startDate = cycleStartDate, cycleDuration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(startDate)
        let fraction = min(max(elapsed / cycleDuration, 0), 1)
        let sliderWidth: CGFloat = mode == .breaking ? 100 : 500
        return sliderWidth * CGFloat(1 - fraction)
    }

    func windingSliderOffset(at date: Date) -> CGFloat {
        guard let startDate = windStartDate, windDuration > 0 else { return windToOffset }
        let elapsed = date.timeIntervalSince(startDate)
        let t = min(max(elapsed / windDuration, 0), 1)
        // Ease-out: decelerates as it reaches the target
        let eased = 1 - (1 - t) * (1 - t)
        return windFromOffset + (windToOffset - windFromOffset) * CGFloat(eased)
    }

    func start() {
        let targetOffset: CGFloat = 500
        let distance = abs(targetOffset - frozenSliderOffset)
        let duration = max(Double(distance / Self.windSpeed), 0.1)
        let windFraction = 1.0 - Double(frozenSliderOffset) / 500.0

        playWindup(fraction: max(windFraction, 0.15))

        // Animate the ruler back to start position
        isWinding = true
        windFromOffset = frozenSliderOffset
        windToOffset = targetOffset
        windDuration = duration
        windStartDate = Date()

        // Begin the cycle after winding completes
        windCheckTimer?.invalidate()
        windCheckTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishWindAndBeginCycle(.working)
            }
        }
    }

    func stop() {
        playSound(clickSound)
        windupPlayer?.stop()
        windCheckTimer?.invalidate()
        windCheckTimer = nil

        if isWinding {
            frozenSliderOffset = windingSliderOffset(at: Date())
            isWinding = false
        } else {
            frozenSliderOffset = continuousSliderOffset(at: Date())
        }

        timer?.invalidate()
        timer = nil
        mode = .stopped
        remainingSeconds = 0
        cycleStartDate = nil
        cycleDuration = 0
    }

    private func finishWindAndBeginCycle(_ newMode: TimerMode) {
        isWinding = false
        windStartDate = nil
        beginCycle(newMode)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            cycleComplete()
        }
    }

    private func cycleComplete() {
        timer?.invalidate()
        timer = nil
        cycleStartDate = nil
        cycleDuration = 0
        playSound(dingSound)
        onCycleComplete?()

        let nextMode: TimerMode = mode == .working ? .breaking : .working
        let nextMinutes = nextMode == .breaking ? Self.breakMinutes : Self.workMinutes
        let targetOffset: CGFloat = nextMode == .breaking ? 100 : 500
        let fraction = Double(nextMinutes) / Double(Self.workMinutes)
        let distance = targetOffset // winding from 0 to target
        let duration = max(Double(distance / Self.windSpeed), 0.1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.playWindup(fraction: fraction)

            self.isWinding = true
            self.windFromOffset = 0
            self.windToOffset = targetOffset
            self.windDuration = duration
            self.windStartDate = Date()

            self.windCheckTimer?.invalidate()
            self.windCheckTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.finishWindAndBeginCycle(nextMode)
                }
            }
        }
    }

    private func beginCycle(_ newMode: TimerMode) {
        let minutes = newMode == .breaking ? Self.breakMinutes : Self.workMinutes
        mode = newMode
        cycleDuration = TimeInterval(minutes * 60)
        cycleStartDate = Date()
        remainingSeconds = minutes * 60
        frozenSliderOffset = 0
        startTimer()
    }

    private func playWindup(fraction: Double) {
        guard soundEnabled, let player = windupPlayer else { return }
        player.stop()
        player.currentTime = player.duration * (1 - fraction)
        player.play()
    }

    private func playSound(_ sound: NSSound?) {
        guard soundEnabled, let sound else { return }
        sound.stop()
        sound.play()
    }

    private static func loadPlayer(_ name: String) -> AVAudioPlayer? {
        guard let path = Bundle.main.path(forResource: name, ofType: "wav") else { return nil }
        return try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    }

    private static func loadSound(_ name: String) -> NSSound? {
        guard let path = Bundle.main.path(forResource: name, ofType: "wav") else { return nil }
        return NSSound(contentsOfFile: path, byReference: false)
    }
}
