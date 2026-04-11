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
    private(set) var isDragging: Bool = false
    private(set) var dragMinute: Int = 0
    private var dragMode: TimerMode = .working

    // Winding animation state
    private(set) var isWinding: Bool = false
    private(set) var windStartDate: Date?
    private(set) var windDuration: TimeInterval = 0
    private(set) var windFromOffset: CGFloat = 0
    private(set) var windToOffset: CGFloat = 0

    private var timer: Timer?
    private var windCheckTimer: Timer?
    private var windupPlayer: AVAudioPlayer?

    private let clickSound: NSSound?
    private let dingSound: NSSound?
    private var tickPlayer: AVAudioPlayer?

    private static let workMinutes = 25
    private static let breakMinutes = 5
    private static let windSpeed: CGFloat = 500

    init() {
        clickSound = Self.loadSound("click")
        dingSound = Self.loadSound("ding")
        tickPlayer = WindupSoundGenerator.generate(clickCount: 1, totalDuration: 0.02)
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
        // 20pt per minute, derived from actual cycle duration
        let sliderWidth = CGFloat(cycleDuration / 60.0) * 20.0
        return sliderWidth * CGFloat(1 - fraction)
    }

    func windingSliderOffset(at date: Date) -> CGFloat {
        guard let startDate = windStartDate, windDuration > 0 else { return windToOffset }
        let elapsed = date.timeIntervalSince(startDate)
        let t = min(max(elapsed / windDuration, 0), 1)
        let eased = 1 - (1 - t) * (1 - t)
        return windFromOffset + (windToOffset - windFromOffset) * CGFloat(eased)
    }

    func dragBegan() {
        // Capture current position regardless of mode
        if isWinding {
            frozenSliderOffset = windingSliderOffset(at: Date())
            isWinding = false
            windCheckTimer?.invalidate()
            windCheckTimer = nil
        } else if mode != .stopped {
            frozenSliderOffset = continuousSliderOffset(at: Date())
        }

        // Pause timer if running
        timer?.invalidate()
        timer = nil
        windupPlayer?.stop()
        cycleStartDate = nil
        cycleDuration = 0

        isDragging = true
        dragMode = mode == .stopped ? .working : mode
        dragMinute = minuteFromOffset(frozenSliderOffset)
    }

    func dragChanged(offset: CGFloat) {
        guard isDragging else { return }
        frozenSliderOffset = min(max(offset, 0), 500)

        let minutes = minuteFromOffset(frozenSliderOffset)
        remainingSeconds = minutes * 60
        mode = frozenSliderOffset > 0 ? dragMode : .stopped

        if minutes != dragMinute {
            playTick()
            dragMinute = minutes
        }
    }

    func dragEnded() {
        guard isDragging else { return }
        isDragging = false
        let minutes = minuteFromOffset(frozenSliderOffset)
        if minutes >= 1 {
            startFromDrag(minutes: minutes, mode: dragMode)
        } else {
            mode = .stopped
            remainingSeconds = 0
            frozenSliderOffset = 0
        }
    }

    private func minuteFromOffset(_ offset: CGFloat) -> Int {
        Int(round(offset / 20.0))
    }

    private func startFromDrag(minutes: Int, mode newMode: TimerMode = .working) {
        let seconds = minutes * 60
        mode = newMode
        // Set total duration to match so the ruler position is correct from the start
        cycleDuration = TimeInterval(seconds)
        cycleStartDate = Date()
        remainingSeconds = seconds
        startTimer()
    }

    private func playTick() {
        guard soundEnabled else { return }
        tickPlayer?.stop()
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
    }

    func start() {
        let targetOffset: CGFloat = 500
        let distance = abs(targetOffset - frozenSliderOffset)
        let duration = max(Double(distance / Self.windSpeed), 0.25)

        // One click per minute of winding distance
        let minutesWinding = Int(round(distance / 20.0)) // 20pt per minute
        playWindup(clickCount: max(minutesWinding, 1), duration: duration)

        isWinding = true
        windFromOffset = frozenSliderOffset
        windToOffset = targetOffset
        windDuration = duration
        windStartDate = Date()

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
        let distance = targetOffset
        let duration = max(Double(distance / Self.windSpeed), 0.25)
        let clickCount = max(nextMinutes, 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.playWindup(clickCount: clickCount, duration: duration)

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

    private func playWindup(clickCount: Int, duration: TimeInterval) {
        guard soundEnabled else { return }
        windupPlayer?.stop()
        windupPlayer = WindupSoundGenerator.generate(clickCount: clickCount, totalDuration: duration)
        windupPlayer?.play()
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
