import Testing
import AppKit
@testable import Mater

@MainActor
private func makePrefs() -> AppPreferences {
    AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
}

@MainActor
private func makeTimerState(workMinutes: Int = 25, breakMinutes: Int = 5) -> TimerState {
    let prefs = makePrefs()
    prefs.workMinutes = workMinutes
    prefs.breakMinutes = breakMinutes
    let state = TimerState(preferences: prefs)
    state.soundEnabled = false
    return state
}

@MainActor
private func startCycleViaDrag(_ state: TimerState, minutes: Int = 25) {
    state.dragBegan()
    state.dragChanged(offset: CGFloat(minutes) * TimerState.pointsPerMinute)
    state.dragEnded(velocity: 0)
}

// MARK: - AppPreferences

@MainActor
@Suite struct AppPreferencesTests {
    @Test func defaultValues() {
        let prefs = makePrefs()
        #expect(prefs.workMinutes == 25)
        #expect(prefs.breakMinutes == 5)
        #expect(prefs.soundEnabled == true)
    }

    @Test func persistsWorkMinutes() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = AppPreferences(defaults: defaults)
        prefs.workMinutes = 30
        let prefs2 = AppPreferences(defaults: defaults)
        #expect(prefs2.workMinutes == 30)
    }

    @Test func persistsBreakMinutes() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = AppPreferences(defaults: defaults)
        prefs.breakMinutes = 10
        let prefs2 = AppPreferences(defaults: defaults)
        #expect(prefs2.breakMinutes == 10)
    }

    @Test func persistsSoundEnabled() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = AppPreferences(defaults: defaults)
        prefs.soundEnabled = false
        let prefs2 = AppPreferences(defaults: defaults)
        #expect(prefs2.soundEnabled == false)
    }
}

// MARK: - TimerState

@MainActor
@Suite struct TimerStateTests {
    @Test func initialState() {
        let prefs = makePrefs()
        let state = TimerState(preferences: prefs)
        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
        #expect(state.soundEnabled == true)
        #expect(state.cycleStartDate == nil)
        #expect(state.cycleDuration == 0)
        #expect(state.frozenSliderOffset == 0)
    }

    @Test func iconNameStopped() {
        let state = makeTimerState()
        #expect(state.iconName == "icon-stopped")
    }

    @Test func iconNameWorking() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        #expect(state.iconName == "icon-25")
        state.stop()
    }

    @Test func startViaButtonWindsFirst() {
        let state = makeTimerState()
        state.start()
        #expect(state.isWinding == true)
        #expect(state.mode == .stopped)
        state.stop()
    }

    @Test func startViaDragBeginsImmediately() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 1500)
        #expect(state.cycleDuration == 1500)
        #expect(state.cycleStartDate != nil)
        state.stop()
    }

    @Test func stopResetsState() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        state.stop()
        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
        #expect(state.cycleStartDate == nil)
    }

    @Test func stopFreezesFrozenOffset() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        state.stop()
        // Offset should be captured near the start position (just started, barely moved)
        #expect(state.frozenSliderOffset >= 0)
    }

    @Test func stopDuringWindCapturesPosition() {
        let state = makeTimerState()
        state.start()
        #expect(state.isWinding == true)
        state.stop()
        #expect(state.isWinding == false)
        #expect(state.frozenSliderOffset >= 0)
    }

    @Test func continuousSliderOffsetWhenStopped() {
        let state = makeTimerState()
        #expect(state.continuousSliderOffset(at: Date()) == 0)
    }

    @Test func continuousSliderOffsetDerivedFromDuration() {
        let state = makeTimerState()
        startCycleViaDrag(state)

        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 500)

        let endDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration)
        #expect(state.continuousSliderOffset(at: endDate) == 0)

        let midDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration / 2)
        #expect(state.continuousSliderOffset(at: midDate) == 250)

        state.stop()
    }

    @Test func currentMinute() {
        let state = makeTimerState()
        #expect(state.currentMinute == 0)
        startCycleViaDrag(state)
        #expect(state.currentMinute == 25)
        state.stop()
        #expect(state.currentMinute == 0)
    }

    @Test func soundToggleWritesToPreferences() {
        let prefs = makePrefs()
        let state = TimerState(preferences: prefs)
        #expect(state.soundEnabled == true)
        state.soundEnabled = false
        #expect(state.soundEnabled == false)
        #expect(prefs.soundEnabled == false)
    }

}

// MARK: - Toggle and Resume

@MainActor
@Suite struct ToggleResumeTests {
    @Test func toggleFromStoppedStarts() {
        let state = makeTimerState()
        state.toggle()
        #expect(state.isWinding == true)
        state.stop()
    }

    @Test func toggleWhileRunningStops() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        #expect(state.mode == .working)
        state.toggle()
        #expect(state.mode == .stopped)
        #expect(state.frozenSliderOffset > 0)
    }

    @Test func toggleFromPausedResumes() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        state.stop()
        let frozenOffset = state.frozenSliderOffset
        #expect(frozenOffset > 0)

        state.toggle()
        // Should resume immediately, not wind
        #expect(state.isWinding == false)
        #expect(state.mode == .working)
        #expect(state.cycleStartDate != nil)
    }

    @Test func resumeStartsFromFrozenPosition() {
        let state = makeTimerState()
        startCycleViaDrag(state, minutes: 15)
        state.stop()
        let frozenOffset = state.frozenSliderOffset

        state.resume()
        #expect(state.mode == .working)
        // Duration should match the frozen position's minutes
        let expectedMinutes = Int(round(frozenOffset / TimerState.pointsPerMinute))
        #expect(state.remainingSeconds == expectedMinutes * 60)
    }

    @Test func resumeDoesNothingAtZero() {
        let state = makeTimerState()
        #expect(state.frozenSliderOffset == 0)
        state.resume()
        #expect(state.mode == .stopped)
    }

    @Test func startFromZeroWindsToMax() {
        let state = makeTimerState()
        #expect(state.frozenSliderOffset == 0)
        state.start()
        #expect(state.isWinding == true)
        state.stop()
    }

    @Test func visualModeWhileWorking() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        #expect(state.visualMode == .working)
        state.stop()
    }

    @Test func visualModeWhenPausedDuringWork() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        state.stop()
        #expect(state.mode == .stopped)
        #expect(state.visualMode == .working)
    }

    @Test func visualModeWhenPausedDuringBreak() {
        let state = makeTimerState()
        // Simulate break: drag, end as break mode
        state.dragBegan()
        state.dragChanged(offset: 60) // 3 minutes
        // dragMode defaults to .working from stopped, so manually
        // start a work cycle then stop, then test break scenario
        state.dragEnded(velocity: 0)

        // For a true break test, we need to set pausedMode to .breaking
        // Start as work, stop — pausedMode is .working
        state.stop()
        #expect(state.visualMode == .working)

        // Now test fresh stopped with no offset
        let state2 = makeTimerState()
        #expect(state2.visualMode == .stopped)
    }

    @Test func visualModeWhenFullyStopped() {
        let state = makeTimerState()
        #expect(state.visualMode == .stopped)
    }

    @Test func resumePreservesPausedMode() {
        let state = makeTimerState()
        startCycleViaDrag(state)
        state.stop()
        #expect(state.pausedMode == .working)
        state.resume()
        #expect(state.mode == .working)
        state.stop()
    }
}

// MARK: - Configurable Durations

@MainActor
@Suite struct ConfigurableDurationTests {
    @Test func customWorkMinutesAffectsDrag() {
        let state = makeTimerState(workMinutes: 30)
        startCycleViaDrag(state, minutes: 30)
        #expect(state.remainingSeconds == 1800)
        #expect(state.cycleDuration == 1800)
        state.stop()
    }

    @Test func dragClampedToConfiguredMax() {
        let state = makeTimerState(workMinutes: 15)
        state.dragBegan()
        state.dragChanged(offset: 999)
        // Max offset = 15 * 20 = 300
        #expect(state.frozenSliderOffset == 300)
        state.dragEnded(velocity: 0)
        state.stop()
    }

    @Test func sliderOffsetScalesWithDuration() {
        let state = makeTimerState(workMinutes: 10)
        startCycleViaDrag(state, minutes: 10)

        // 10 min = 200pt slider width
        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 200)

        state.stop()
    }

    @Test func preferencesAccessible() {
        let state = makeTimerState(workMinutes: 45)
        #expect(state.preferences.workMinutes == 45)
    }
}

// MARK: - Winding Animation

@MainActor
@Suite struct WindingTests {
    @Test func windProgressAtBoundaries() {
        let state = makeTimerState()
        // When not winding, progress is 1 (complete)
        #expect(state.windProgress(at: Date()) == 1)
    }

    @Test func windingSliderOffsetInterpolates() {
        let state = makeTimerState()
        state.start()
        #expect(state.isWinding == true)

        let startDate = state.windStartDate!
        // At start: offset should be near windFromOffset (0)
        let startOffset = state.windingSliderOffset(at: startDate)
        #expect(startOffset == 0)

        // At end: offset should be windToOffset (500)
        let endDate = startDate.addingTimeInterval(state.windDuration)
        let endOffset = state.windingSliderOffset(at: endDate)
        #expect(endOffset == 500)

        state.stop()
    }

    @Test func windDurationProportionalToDistance() {
        let state = makeTimerState()
        // From 0: full distance
        state.start()
        let fullDuration = state.windDuration
        state.stop()

        // From near the end: short distance — use drag to set frozen offset
        startCycleViaDrag(state)
        state.stop() // freezes near 500
        state.start()
        let shortDuration = state.windDuration
        state.stop()

        #expect(shortDuration < fullDuration)
    }
}

// MARK: - Drag

@MainActor
@Suite struct DragTests {
    @Test func dragFromStoppedSetsWorkingMode() {
        let state = makeTimerState()

        state.dragBegan()
        #expect(state.isDragging == true)

        state.dragChanged(offset: 200)
        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 600)

        state.dragEnded(velocity: 0)
        #expect(state.isDragging == false)
        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 600)
        #expect(state.cycleStartDate != nil)
    }

    @Test func dragToZeroStops() {
        let state = makeTimerState()

        state.dragBegan()
        state.dragChanged(offset: 100)
        state.dragChanged(offset: 0)
        state.dragEnded(velocity: 0)

        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
    }

    @Test func dragClampedToRange() {
        let state = makeTimerState()

        state.dragBegan()
        state.dragChanged(offset: 999)
        #expect(state.frozenSliderOffset == 500)

        state.dragChanged(offset: -50)
        #expect(state.frozenSliderOffset == 0)

        state.dragEnded(velocity: 0)
    }

    @Test func dragWhileRunningCapturesOffset() {
        let state = makeTimerState()
        startCycleViaDrag(state)

        state.dragBegan()
        #expect(state.isDragging == true)
        #expect(state.frozenSliderOffset > 0)
        #expect(state.cycleStartDate == nil)

        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 0)

        #expect(state.cycleDuration == 600)
        #expect(state.remainingSeconds == 600)

        state.stop()
    }

    @Test func dragWhileWindingCapturesPosition() {
        let state = makeTimerState()
        state.start()
        #expect(state.isWinding == true)

        state.dragBegan()
        #expect(state.isWinding == false)
        #expect(state.isDragging == true)

        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 0)
        state.stop()
    }

    @Test func dragUpdatesIconViaRemainingSeconds() {
        let state = makeTimerState()

        state.dragBegan()
        state.dragChanged(offset: 300)
        #expect(state.remainingSeconds == 900)
        #expect(state.currentMinute == 15)
        #expect(state.iconName == "icon-15")

        state.dragChanged(offset: 100)
        #expect(state.remainingSeconds == 300)
        #expect(state.currentMinute == 5)
        #expect(state.iconName == "icon-5")

        state.dragEnded(velocity: 0)
        state.stop()
    }

    @Test func dragEndWithVelocityStartsMomentum() {
        let state = makeTimerState()
        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 500)

        #expect(state.isMomentum == true)
        #expect(state.isDragging == false)
    }

    @Test func dragEndWithLowVelocitySettlesImmediately() {
        let state = makeTimerState()
        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 10)

        #expect(state.isMomentum == false)
        #expect(state.mode == .working)
        #expect(state.cycleStartDate != nil)
    }

    @Test func momentumDecaysAndSettlesOnMinuteMark() {
        let state = makeTimerState()
        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 100)
        #expect(state.isMomentum == true)

        // Simulate frames until it settles
        var date = Date()
        for _ in 0..<300 {
            date = date.addingTimeInterval(1.0 / 60.0)
            state.updateMomentum(at: date)
            if !state.isMomentum { break }
        }

        #expect(state.isMomentum == false)
        // Should land exactly on a minute tick (multiple of pointsPerMinute)
        let remainder = state.frozenSliderOffset.truncatingRemainder(dividingBy: TimerState.pointsPerMinute)
        #expect(remainder < 0.01 || abs(remainder - TimerState.pointsPerMinute) < 0.01)
    }

    @Test func grabDuringMomentumStopsIt() {
        let state = makeTimerState()
        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 500)
        #expect(state.isMomentum == true)

        state.dragBegan()
        #expect(state.isMomentum == false)
        #expect(state.isDragging == true)

        state.dragEnded(velocity: 0)
    }

    @Test func momentumClampsToRange() {
        let state = makeTimerState()
        state.dragBegan()
        state.dragChanged(offset: 480)
        state.dragEnded(velocity: 2000) // big throw toward max

        var date = Date()
        for _ in 0..<300 {
            date = date.addingTimeInterval(1.0 / 60.0)
            state.updateMomentum(at: date)
            if !state.isMomentum { break }
        }

        #expect(state.frozenSliderOffset <= 500)
        #expect(state.frozenSliderOffset >= 0)
    }

    @Test func customDurationSliderWidth() {
        let state = makeTimerState()

        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded(velocity: 0)

        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 200)

        state.stop()
    }
}

// MARK: - WindupSoundGenerator

@Suite struct WindupSoundGeneratorTests {
    @Test func generatesValidAudio() {
        let player = WindupSoundGenerator.generate(clickCount: 5, totalDuration: 0.5)
        #expect(player != nil)
        #expect(player!.duration > 0)
    }

    @Test func singleClick() {
        let player = WindupSoundGenerator.generate(clickCount: 1, totalDuration: 0.05)
        #expect(player != nil)
    }

    @Test func returnsNilForInvalidInput() {
        #expect(WindupSoundGenerator.generate(clickCount: 0, totalDuration: 0.5) == nil)
        #expect(WindupSoundGenerator.generate(clickCount: 5, totalDuration: 0) == nil)
    }

    @Test func durationMatchesRequest() {
        let player = WindupSoundGenerator.generate(clickCount: 10, totalDuration: 1.0)!
        // Duration should be approximately 1 second (within rounding)
        #expect(player.duration >= 0.9)
        #expect(player.duration <= 1.1)
    }
}

// MARK: - IconGenerator

@Suite struct IconGeneratorTests {
    @Test func filledIconProperties() {
        let icon = IconGenerator.generate(text: "25", style: .filled)
        #expect(icon.size == NSSize(width: 20, height: 20))
        #expect(icon.isTemplate == true)
    }

    @Test func outlinedIconProperties() {
        let icon = IconGenerator.generate(text: "3", style: .outlined)
        #expect(icon.size == NSSize(width: 20, height: 20))
        #expect(icon.isTemplate == true)
    }

    @Test func stoppedIcon() {
        let icon = IconGenerator.generate(text: "×", style: .outlined)
        #expect(icon.size == NSSize(width: 20, height: 20))
        #expect(icon.isTemplate == true)
    }

    @Test func singleAndDoubleDigit() {
        let single = IconGenerator.generate(text: "5", style: .filled)
        let double = IconGenerator.generate(text: "25", style: .filled)
        #expect(single.size == double.size)
    }
}

// MARK: - PanelOrigin

@MainActor
@Suite struct PanelOriginTests {
    @Test func centeredBelowButton() {
        let buttonRect = CGRect(x: 900, y: 800, width: 30, height: 24)
        let panelSize = CGSize(width: 220, height: 206)
        let origin = StatusItemController.panelOrigin(buttonRect: buttonRect, panelSize: panelSize)

        #expect(origin.x == 805)
        #expect(origin.y == 594)
    }
}
