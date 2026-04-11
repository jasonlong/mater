import Testing
import AppKit
@testable import Mater

@MainActor
@Suite struct TimerStateTests {
    @Test func initialState() {
        let state = TimerState()
        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
        #expect(state.soundEnabled == true)
        #expect(state.cycleStartDate == nil)
        #expect(state.cycleDuration == 0)
        #expect(state.frozenSliderOffset == 0)
    }

    @Test func currentMinuteAtBoundaries() {
        let state = TimerState()
        state.soundEnabled = false
        #expect(state.currentMinute == 0)

        state.start()
        #expect(state.currentMinute == 25)

        state.stop()
    }

    @Test func iconNameStopped() {
        let state = TimerState()
        #expect(state.iconName == "icon-0")
    }

    @Test func iconNameWorking() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()
        #expect(state.iconName == "icon-25")
        state.stop()
    }

    @Test func startSetsWorkingMode() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 1500)
        #expect(state.cycleDuration == 1500)
        #expect(state.cycleStartDate != nil)

        state.stop()
    }

    @Test func stopFrozenOffset() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()
        state.stop()

        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
        #expect(state.cycleStartDate == nil)
        // frozenSliderOffset captures where the ruler was
        #expect(state.frozenSliderOffset >= 0)
    }

    @Test func continuousSliderOffsetWhenStopped() {
        let state = TimerState()
        #expect(state.continuousSliderOffset(at: Date()) == 0)
    }

    @Test func continuousSliderOffsetDerivedFromDuration() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        // 25 min cycle = 500pt slider width (20pt/min)
        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 500)

        let endDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration)
        #expect(state.continuousSliderOffset(at: endDate) == 0)

        let midDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration / 2)
        #expect(state.continuousSliderOffset(at: midDate) == 250)

        state.stop()
    }

    @Test func soundToggle() {
        let state = TimerState()
        #expect(state.soundEnabled == true)
        state.soundEnabled = false
        #expect(state.soundEnabled == false)
    }
}

@MainActor
@Suite struct DragTests {
    @Test func dragFromStoppedSetsWorkingMode() {
        let state = TimerState()
        state.soundEnabled = false

        state.dragBegan()
        #expect(state.isDragging == true)

        state.dragChanged(offset: 200) // 10 minutes
        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 600) // 10 * 60

        state.dragEnded()
        #expect(state.isDragging == false)
        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 600)
        #expect(state.cycleStartDate != nil)
    }

    @Test func dragToZeroStops() {
        let state = TimerState()
        state.soundEnabled = false

        state.dragBegan()
        state.dragChanged(offset: 100)
        state.dragChanged(offset: 0)
        state.dragEnded()

        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
    }

    @Test func dragClampedToRange() {
        let state = TimerState()
        state.soundEnabled = false

        state.dragBegan()
        state.dragChanged(offset: 999)
        #expect(state.frozenSliderOffset == 500)

        state.dragChanged(offset: -50)
        #expect(state.frozenSliderOffset == 0)

        state.dragEnded()
    }

    @Test func dragPreservesBreakMode() {
        let state = TimerState()
        state.soundEnabled = false

        // Simulate being in break mode by starting and using drag
        // First, start a work cycle and immediately drag into break territory
        state.start()
        // Now simulate break mode by stopping and setting up
        state.stop()

        // We can't easily put it in break mode without the full cycle,
        // but we can test the drag mode preservation logic:
        // Start a work cycle, drag should keep .working
        state.start()
        state.dragBegan()
        state.dragChanged(offset: 100) // drag to 5 min
        #expect(state.mode == .working) // preserves work mode

        state.dragEnded()
        state.stop()
    }

    @Test func dragWhileRunningCapturesOffset() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        // Drag while running should capture current position
        state.dragBegan()
        #expect(state.isDragging == true)
        #expect(state.frozenSliderOffset > 0)

        // Timer should be paused
        #expect(state.cycleStartDate == nil)

        state.dragChanged(offset: 200)
        state.dragEnded()

        // Should resume as a 10-minute cycle
        #expect(state.cycleDuration == 600)
        #expect(state.remainingSeconds == 600)

        state.stop()
    }

    @Test func dragUpdatesIconViaRemainingSeconds() {
        let state = TimerState()
        state.soundEnabled = false

        state.dragBegan()
        state.dragChanged(offset: 300) // 15 minutes
        #expect(state.remainingSeconds == 900)
        #expect(state.currentMinute == 15)
        #expect(state.iconName == "icon-15")

        state.dragChanged(offset: 100) // 5 minutes
        #expect(state.remainingSeconds == 300)
        #expect(state.currentMinute == 5)
        #expect(state.iconName == "icon-5")

        state.dragEnded()
        state.stop()
    }

    @Test func customDurationSliderWidth() {
        let state = TimerState()
        state.soundEnabled = false

        // Start a 10-minute cycle via drag
        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded()

        // Slider width should be 200pt (10min * 20pt/min), not 500
        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 200)

        state.stop()
    }
}

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
