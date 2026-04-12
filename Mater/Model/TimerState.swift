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
    static let pointsPerMinute: CGFloat = 20

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
    private var lastIconName: String = ""

    let preferences: AppPreferences
    private var workMinutes: Int { preferences.workMinutes }
    private var breakMinutes: Int { preferences.breakMinutes }
    private static let windSpeed: CGFloat = 500
    private var maxWorkOffset: CGFloat { CGFloat(workMinutes) * Self.pointsPerMinute }

    init(preferences: AppPreferences) {
        self.preferences = preferences
        clickSound = Self.loadSound("click")
        dingSound = Self.loadSound("ding")
        tickPlayer = WindupSoundGenerator.generate(clickCount: 1, totalDuration: 0.02)
    }

    var maxMinutes: Int { preferences.workMinutes }

    var currentMinute: Int {
        Int(ceil(Double(remainingSeconds) / 60.0))
    }

    var iconName: String {
        switch mode {
        case .stopped:
            return "icon-stopped"
        case .working:
            return "icon-\(currentMinute)"
        case .breaking:
            return "icon-\(currentMinute)-break"
        }
    }

    var iconChanged: Bool {
        let name = iconName
        if name != lastIconName {
            lastIconName = name
            return true
        }
        return false
    }

    func continuousSliderOffset(at date: Date) -> CGFloat {
        guard let startDate = cycleStartDate, cycleDuration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(startDate)
        let fraction = min(max(elapsed / cycleDuration, 0), 1)
        let sliderWidth = CGFloat(cycleDuration / 60.0) * Self.pointsPerMinute
        return sliderWidth * CGFloat(1 - fraction)
    }

    func windingSliderOffset(at date: Date) -> CGFloat {
        guard let startDate = windStartDate, windDuration > 0 else { return windToOffset }
        let t = windProgress(at: date)
        let eased = 1 - (1 - t) * (1 - t)
        return windFromOffset + (windToOffset - windFromOffset) * CGFloat(eased)
    }

    func windProgress(at date: Date) -> Double {
        guard let startDate = windStartDate, windDuration > 0 else { return 1 }
        let elapsed = date.timeIntervalSince(startDate)
        return min(max(elapsed / windDuration, 0), 1)
    }

    func dragBegan() {
        if isWinding {
            frozenSliderOffset = windingSliderOffset(at: Date())
            cancelWind()
        } else if mode != .stopped {
            frozenSliderOffset = continuousSliderOffset(at: Date())
        }

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
        frozenSliderOffset = min(max(offset, 0), maxWorkOffset)

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
        Int(round(offset / Self.pointsPerMinute))
    }

    private func startFromDrag(minutes: Int, mode newMode: TimerMode = .working) {
        let seconds = minutes * 60
        mode = newMode
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
        let targetOffset = maxWorkOffset
        let distance = abs(targetOffset - frozenSliderOffset)
        let clickCount = max(Int(round(distance / Self.pointsPerMinute)), 1)
        beginWindAnimation(from: frozenSliderOffset, to: targetOffset, clickCount: clickCount) { [weak self] in
            self?.finishWindAndBeginCycle(.working)
        }
    }

    func stop() {
        playSound(clickSound)
        windupPlayer?.stop()

        if isWinding {
            frozenSliderOffset = windingSliderOffset(at: Date())
            cancelWind()
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

    private func beginWindAnimation(
        from: CGFloat, to target: CGFloat, clickCount: Int,
        completion: @escaping @MainActor () -> Void
    ) {
        let distance = abs(target - from)
        let duration = max(Double(distance / Self.windSpeed), 0.25)

        playWindup(clickCount: clickCount, duration: duration)

        isWinding = true
        windFromOffset = from
        windToOffset = target
        windDuration = duration
        windStartDate = Date()

        windCheckTimer?.invalidate()
        windCheckTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            Task { @MainActor in
                completion()
            }
        }
    }

    private func cancelWind() {
        isWinding = false
        windCheckTimer?.invalidate()
        windCheckTimer = nil
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
        let nextMinutes = nextMode == .breaking ? breakMinutes : workMinutes
        let targetOffset = CGFloat(nextMinutes) * Self.pointsPerMinute

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.mode = nextMode
            self.beginWindAnimation(from: 0, to: targetOffset, clickCount: max(nextMinutes, 1)) { [weak self] in
                self?.finishWindAndBeginCycle(nextMode)
            }
        }
    }

    private func beginCycle(_ newMode: TimerMode) {
        let minutes = newMode == .breaking ? breakMinutes : workMinutes
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
