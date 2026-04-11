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

    private var timer: Timer?

    private let windupPlayer: AVAudioPlayer?
    private let clickSound: NSSound?
    private let dingSound: NSSound?

    private static let workMinutes = 25
    private static let breakMinutes = 5

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

    func start() {
        // Wind proportional to how far the ruler needs to travel back
        let windFraction = 1.0 - frozenSliderOffset / 500.0
        playWindup(fraction: max(windFraction, 0.05))
        beginCycle(.working)
    }

    func stop() {
        playSound(clickSound)
        windupPlayer?.stop()
        frozenSliderOffset = continuousSliderOffset(at: Date())
        timer?.invalidate()
        timer = nil
        mode = .stopped
        remainingSeconds = 0
        cycleStartDate = nil
        cycleDuration = 0
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
        let fraction = Double(nextMinutes) / Double(Self.workMinutes)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.playWindup(fraction: fraction)
            self.beginCycle(nextMode)
        }
    }

    private func beginCycle(_ newMode: TimerMode) {
        let minutes = newMode == .breaking ? Self.breakMinutes : Self.workMinutes
        mode = newMode
        cycleDuration = TimeInterval(minutes * 60)
        cycleStartDate = Date()
        remainingSeconds = minutes * 60
        startTimer()
    }

    private func playWindup(fraction: Double) {
        guard soundEnabled, let player = windupPlayer else { return }
        player.stop()
        // Start playback later into the sound for shorter cycles
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
