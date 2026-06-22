import AppKit
import AVFoundation
import Observation

enum TimerMode: Equatable {
    case stopped
    case working
    case breaking
}

@MainActor
protocol TimerStateScheduledTask: AnyObject {
    func cancel()
}

@MainActor
protocol TimerStateScheduling: AnyObject {
    var now: Date { get }

    @discardableResult
    func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TimerStateScheduledTask

    @discardableResult
    func scheduleRepeating(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TimerStateScheduledTask
}

@MainActor
private final class ClosureTimerStateScheduledTask: TimerStateScheduledTask {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

final class SystemTimerStateScheduler: TimerStateScheduling {
    var now: Date { Date() }

    func schedule(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TimerStateScheduledTask {
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                action()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
        return ClosureTimerStateScheduledTask {
            workItem.cancel()
        }
    }

    func scheduleRepeating(every interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> TimerStateScheduledTask {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                action()
            }
        }
        return ClosureTimerStateScheduledTask {
            timer.invalidate()
        }
    }
}

typealias WindupPlayerFactory = @Sendable (_ clickCount: Int, _ duration: TimeInterval) async -> AVAudioPlayer?

@MainActor @Observable
final class TimerState {
    static let pointsPerMinute: CGFloat = 20

    private(set) var mode: TimerMode = .stopped
    private(set) var remainingSeconds: Int = 0
    var soundEnabled: Bool {
        get { preferences.soundEnabled }
        set {
            preferences.soundEnabled = newValue
            if !newValue {
                cancelWindupAudio()
            }
        }
    }
    var onCycleComplete: (() -> Void)?

    private(set) var cycleStartDate: Date?
    private(set) var cycleDuration: TimeInterval = 0
    private(set) var frozenSliderOffset: CGFloat = 0
    private(set) var isDragging: Bool = false
    private(set) var dragMinute: Int = 0
    private var dragMode: TimerMode = .working
    private(set) var pausedMode: TimerMode = .working

    private(set) var isMomentum: Bool = false
    private(set) var momentumVelocity: CGFloat = 0
    private(set) var momentumLastUpdate: Date?

    private(set) var isWinding: Bool = false
    private(set) var windStartDate: Date?
    private(set) var windDuration: TimeInterval = 0
    private(set) var windFromOffset: CGFloat = 0
    private(set) var windToOffset: CGFloat = 0

    private var timerTask: TimerStateScheduledTask?
    private var windCheckTask: TimerStateScheduledTask?
    private var pendingCycleTransitionTask: TimerStateScheduledTask?
    private var windupTask: Task<Void, Never>?
    private var windupGeneration = 0
    private(set) var windupPlayer: AVAudioPlayer?

    private let dingSound: NSSound?
    private let toggleOnSound: NSSound?
    private let toggleOffSound: NSSound?
    private let tickSound: NSSound?

    let preferences: AppPreferences
    private let scheduler: TimerStateScheduling
    private let makeWindupPlayer: WindupPlayerFactory
    private var workMinutes: Int { preferences.workMinutes }
    private var breakMinutes: Int { preferences.breakMinutes }
    private static let windSpeed: CGFloat = 500

    private func minutes(for mode: TimerMode) -> Int {
        mode == .breaking ? breakMinutes : workMinutes
    }
    private var maxWorkOffset: CGFloat { CGFloat(workMinutes) * Self.pointsPerMinute }

    convenience init(preferences: AppPreferences) {
        self.init(preferences: preferences, scheduler: SystemTimerStateScheduler())
    }

    convenience init(preferences: AppPreferences, scheduler: TimerStateScheduling) {
        self.init(
            preferences: preferences,
            scheduler: scheduler,
            makeWindupPlayer: { clickCount, duration in
                WindupSoundGenerator.generate(clickCount: clickCount, totalDuration: duration)
            }
        )
    }

    init(
        preferences: AppPreferences,
        scheduler: TimerStateScheduling,
        makeWindupPlayer: @escaping WindupPlayerFactory
    ) {
        self.preferences = preferences
        self.scheduler = scheduler
        self.makeWindupPlayer = makeWindupPlayer
        dingSound = Self.loadSound("ding")
        toggleOnSound = Self.loadSound("toggle_on")
        toggleOffSound = Self.loadSound("toggle_off")
        tickSound = Self.loadSound("tick")
        observePreferences()
        observeWake()
        prewarmAudio()
    }

    private func prewarmAudio() {
        // Force tick sample and Core Audio setup off the main thread.
        Task.detached(priority: .userInitiated) {
            WindupSoundGenerator.warmUpPlayback()
        }
    }

    private func observeWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resyncAfterWake()
            }
        }
    }

    private func resyncAfterWake() {
        guard mode == .working || mode == .breaking,
              let startDate = cycleStartDate else { return }

        let elapsed = scheduler.now.timeIntervalSince(startDate)
        let remaining = cycleDuration - elapsed

        if remaining <= 0 {
            cycleComplete()
        } else {
            remainingSeconds = Int(ceil(remaining))
        }
    }

    private func observePreferences() {
        withObservationTracking {
            _ = preferences.workMinutes
            _ = preferences.breakMinutes
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.handlePreferencesChanged()
                self?.observePreferences()
            }
        }
    }

    private func handlePreferencesChanged() {
        guard !isDragging, !isMomentum, !isWinding else { return }

        let newMax = preferences.workMinutes
        let newMaxOffset = CGFloat(newMax) * Self.pointsPerMinute

        if mode == .stopped {
            if frozenSliderOffset > newMaxOffset {
                frozenSliderOffset = newMaxOffset
            }
            let minutes = minuteFromOffset(frozenSliderOffset)
            remainingSeconds = minutes * 60
        } else if mode == .working, let startDate = cycleStartDate {
            let elapsed = scheduler.now.timeIntervalSince(startDate)
            let newDuration = TimeInterval(newMax * 60)
            if elapsed >= newDuration {
                stop()
            } else {
                cycleDuration = newDuration
                remainingSeconds = Int(ceil(newDuration - elapsed))
            }
        }
    }

    var visualMode: TimerMode {
        if mode == .stopped && frozenSliderOffset > 0 {
            return pausedMode
        }
        return mode
    }

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

    func continuousSliderOffset(at date: Date) -> CGFloat {
        guard let startDate = cycleStartDate, cycleDuration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(startDate)
        let remainingSeconds = max(cycleDuration - elapsed, 0)
        let remainingMinutes = remainingSeconds / 60.0
        return CGFloat(remainingMinutes) * Self.pointsPerMinute
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
        cancelPendingCycleTransition()

        if isMomentum {
            isMomentum = false
            momentumLastUpdate = nil
        } else if isWinding {
            frozenSliderOffset = windingSliderOffset(at: scheduler.now)
            cancelWind()
        } else if mode != .stopped {
            frozenSliderOffset = continuousSliderOffset(at: scheduler.now)
        }

        timerTask?.cancel()
        timerTask = nil
        cancelWindupAudio()
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

    func dragEnded(velocity: CGFloat) {
        guard isDragging else { return }
        isDragging = false

        // If thrown with enough velocity, start momentum phase
        if abs(velocity) > 30 {
            isMomentum = true
            momentumVelocity = velocity
            momentumLastUpdate = scheduler.now
            return
        }

        settleDrag()
    }

    func updateMomentum(at date: Date) {
        guard isMomentum, let lastUpdate = momentumLastUpdate else { return }
        let dt = date.timeIntervalSince(lastUpdate)
        guard dt > 0 else { return }
        momentumLastUpdate = date

        let friction: CGFloat = 0.92
        momentumVelocity *= pow(friction, CGFloat(dt * 60))

        // Project where we'd stop and find the nearest minute tick
        let projectedStop = frozenSliderOffset + momentumVelocity * 0.3
        let nearestMinuteOffset = round(projectedStop / Self.pointsPerMinute) * Self.pointsPerMinute
        let targetOffset = min(max(nearestMinuteOffset, 0), maxWorkOffset)

        // As velocity drops, blend toward the target tick mark
        let speed = abs(momentumVelocity)
        let blendThreshold: CGFloat = 150
        if speed < blendThreshold {
            let blend = 1.0 - (speed / blendThreshold)
            let springStrength: CGFloat = 12.0 * blend
            let distanceToTarget = targetOffset - frozenSliderOffset
            momentumVelocity += distanceToTarget * springStrength * CGFloat(dt)
        }

        frozenSliderOffset = min(max(frozenSliderOffset + momentumVelocity * CGFloat(dt), 0), maxWorkOffset)

        let minutes = minuteFromOffset(frozenSliderOffset)
        remainingSeconds = minutes * 60
        mode = frozenSliderOffset > 0 ? dragMode : .stopped

        if minutes != dragMinute {
            playTick()
            dragMinute = minutes
        }

        let atTarget = abs(frozenSliderOffset - targetOffset) < 0.5
        if atTarget && speed < 10 {
            frozenSliderOffset = targetOffset
            isMomentum = false
            momentumLastUpdate = nil
            playTick()
            settleDrag()
        }
    }

    private func settleDrag() {
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
        cycleStartDate = scheduler.now
        remainingSeconds = seconds
        startTimer()
    }

    private func playTick() {
        playSound(tickSound)
    }

    func start() {
        cancelPendingCycleTransition()

        let targetOffset = maxWorkOffset
        let distance = abs(targetOffset - frozenSliderOffset)
        let clickCount = max(Int(round(distance / Self.pointsPerMinute)), 1)
        beginWindAnimation(from: frozenSliderOffset, to: targetOffset, clickCount: clickCount) { [weak self] in
            self?.finishWindAndBeginCycle(.working)
        }
    }

    func stop() {
        cancelPendingCycleTransition()
        playSound(toggleOffSound)
        cancelWindupAudio()

        if isWinding {
            frozenSliderOffset = windingSliderOffset(at: scheduler.now)
            cancelWind()
        } else {
            frozenSliderOffset = continuousSliderOffset(at: scheduler.now)
        }

        timerTask?.cancel()
        timerTask = nil
        pausedMode = mode == .stopped ? .working : mode
        mode = .stopped
        remainingSeconds = 0
        cycleStartDate = nil
        cycleDuration = 0
    }

    func toggle() {
        if mode == .stopped {
            if frozenSliderOffset > 0 {
                resume()
            } else {
                start()
            }
        } else {
            stop()
        }
    }

    func resume() {
        cancelPendingCycleTransition()
        guard frozenSliderOffset >= Self.pointsPerMinute else { return }
        playSound(toggleOnSound)
        let exactSeconds = Double(frozenSliderOffset) / Double(Self.pointsPerMinute) * 60.0
        mode = pausedMode
        cycleDuration = exactSeconds
        cycleStartDate = scheduler.now
        remainingSeconds = Int(ceil(exactSeconds))
        startTimer()
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
        windStartDate = scheduler.now

        windCheckTask?.cancel()
        windCheckTask = scheduler.schedule(after: duration) {
            completion()
        }
    }

    private func cancelWind() {
        isWinding = false
        windCheckTask?.cancel()
        windCheckTask = nil
    }

    private func cancelWindupAudio() {
        windupGeneration += 1
        windupTask?.cancel()
        windupTask = nil
        windupPlayer?.stop()
        windupPlayer = nil
    }

    private func finishWindAndBeginCycle(_ newMode: TimerMode) {
        isWinding = false
        windStartDate = nil
        beginCycle(newMode)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = scheduler.scheduleRepeating(every: 1.0) { [weak self] in
            self?.tick()
        }
    }

    private func cancelPendingCycleTransition() {
        pendingCycleTransitionTask?.cancel()
        pendingCycleTransitionTask = nil
    }

    private func tick() {
        guard let startDate = cycleStartDate else { return }
        let elapsed = scheduler.now.timeIntervalSince(startDate)
        let remaining = Int(ceil(cycleDuration - elapsed))

        if remaining <= 0 {
            remainingSeconds = 0
            cycleComplete()
        } else {
            remainingSeconds = remaining
        }
    }

    private func cycleComplete() {
        cancelPendingCycleTransition()
        timerTask?.cancel()
        timerTask = nil
        cycleStartDate = nil
        cycleDuration = 0
        playSound(dingSound)
        onCycleComplete?()

        let nextMode: TimerMode = mode == .working ? .breaking : .working
        let nextMinutes = minutes(for: nextMode)
        let targetOffset = CGFloat(nextMinutes) * Self.pointsPerMinute

        pendingCycleTransitionTask = scheduler.schedule(after: 2.0) { [weak self] in
            guard let self else { return }
            self.pendingCycleTransitionTask = nil
            self.mode = nextMode
            self.beginWindAnimation(from: 0, to: targetOffset, clickCount: max(nextMinutes, 1)) { [weak self] in
                self?.finishWindAndBeginCycle(nextMode)
            }
        }
    }

    private func beginCycle(_ newMode: TimerMode) {
        let minutes = minutes(for: newMode)
        mode = newMode
        cycleDuration = TimeInterval(minutes * 60)
        cycleStartDate = scheduler.now
        remainingSeconds = minutes * 60
        frozenSliderOffset = 0
        startTimer()
    }

    private func playWindup(clickCount: Int, duration: TimeInterval) {
        cancelWindupAudio()
        guard soundEnabled else { return }

        let generation = windupGeneration
        let factory = makeWindupPlayer
        windupTask = Task.detached(priority: .userInitiated) { [weak self] in
            let player = await factory(clickCount, duration)
            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self,
                      !Task.isCancelled,
                      self.windupGeneration == generation,
                      self.soundEnabled
                else { return }

                self.windupPlayer = player
                self.windupPlayer?.play()
                self.windupTask = nil
            }
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
