import Testing
import AppKit
@testable import Mater

// Helper to start a cycle immediately via drag (bypasses winding animation)
@MainActor
private func startCycleViaDrag(_ state: TimerState, minutes: Int = 25) {
    state.dragBegan()
    state.dragChanged(offset: CGFloat(minutes * 20))
    state.dragEnded()
}

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

    @Test func iconNameStopped() {
        let state = TimerState()
        #expect(state.iconName == "icon-stopped")
    }

    @Test func iconNameWorking() {
        let state = TimerState()
        state.soundEnabled = false
        startCycleViaDrag(state)
        #expect(state.iconName == "icon-25")
        state.stop()
    }

    @Test func startViaButtonWindsFirst() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        // start() triggers winding, not immediate cycle
        #expect(state.isWinding == true)
        #expect(state.mode == .stopped) // mode unchanged until wind completes

        state.stop()
    }

    @Test func startViaDragBeginsImmediately() {
        let state = TimerState()
        state.soundEnabled = false
        startCycleViaDrag(state)

        #expect(state.mode == .working)
        #expect(state.remainingSeconds == 1500)
        #expect(state.cycleDuration == 1500)
        #expect(state.cycleStartDate != nil)

        state.stop()
    }

    @Test func stopResetsState() {
        let state = TimerState()
        state.soundEnabled = false
        startCycleViaDrag(state)
        state.stop()

        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
        #expect(state.cycleStartDate == nil)
    }

    @Test func continuousSliderOffsetWhenStopped() {
        let state = TimerState()
        #expect(state.continuousSliderOffset(at: Date()) == 0)
    }

    @Test func continuousSliderOffsetDerivedFromDuration() {
        let state = TimerState()
        state.soundEnabled = false
        startCycleViaDrag(state)

        // 25 min cycle = 500pt slider width (20pt/min)
        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 500)

        let endDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration)
        #expect(state.continuousSliderOffset(at: endDate) == 0)

        let midDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration / 2)
        #expect(state.continuousSliderOffset(at: midDate) == 250)

        state.stop()
    }

    @Test func currentMinute() {
        let state = TimerState()
        state.soundEnabled = false
        #expect(state.currentMinute == 0)

        startCycleViaDrag(state)
        #expect(state.currentMinute == 25)

        state.stop()
        #expect(state.currentMinute == 0)
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
        #expect(state.remainingSeconds == 600)

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

    @Test func dragWhileRunningCapturesOffset() {
        let state = TimerState()
        state.soundEnabled = false
        startCycleViaDrag(state)

        state.dragBegan()
        #expect(state.isDragging == true)
        #expect(state.frozenSliderOffset > 0)
        #expect(state.cycleStartDate == nil) // timer paused

        state.dragChanged(offset: 200)
        state.dragEnded()

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

        state.dragBegan()
        state.dragChanged(offset: 200)
        state.dragEnded()

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
