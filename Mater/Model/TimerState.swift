import AppKit
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

    private var timer: Timer?

    private let windupSound: NSSound?
    private let clickSound: NSSound?
    private let dingSound: NSSound?

    private static let workMinutes = 25
    private static let breakMinutes = 5

    init() {
        windupSound = Self.loadSound("windup")
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
        // Offset goes from sliderWidth (start) to 0 (end)
        return sliderWidth * CGFloat(1 - fraction)
    }

    func start() {
        playSound(windupSound)
        mode = .working
        let duration = TimeInterval(Self.workMinutes * 60)
        cycleDuration = duration
        cycleStartDate = Date()
        remainingSeconds = Self.workMinutes * 60
        startTimer()
    }

    func stop() {
        playSound(clickSound)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.playSound(self.windupSound)
            if self.mode == .working {
                self.mode = .breaking
                let duration = TimeInterval(Self.breakMinutes * 60)
                self.cycleDuration = duration
                self.cycleStartDate = Date()
                self.remainingSeconds = Self.breakMinutes * 60
            } else {
                self.mode = .working
                let duration = TimeInterval(Self.workMinutes * 60)
                self.cycleDuration = duration
                self.cycleStartDate = Date()
                self.remainingSeconds = Self.workMinutes * 60
            }
            self.startTimer()
        }
    }

    private func playSound(_ sound: NSSound?) {
        guard soundEnabled, let sound else { return }
        sound.stop()
        sound.play()
    }

    private static func loadSound(_ name: String) -> NSSound? {
        guard let path = Bundle.main.path(forResource: name, ofType: "wav") else { return nil }
        return NSSound(contentsOfFile: path, byReference: false)
    }
}
