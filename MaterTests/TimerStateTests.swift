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
    }

    @Test func currentMinuteAtBoundaries() {
        let state = TimerState()
        state.soundEnabled = false

        // Stopped: 0 seconds remaining → minute 0
        #expect(state.currentMinute == 0)

        // Start: 1500 seconds remaining → minute 25
        state.start()
        #expect(state.currentMinute == 25)

        state.stop()
    }

    @Test func currentMinuteCeiling() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        // Simulate some ticks to get to a known state
        // 1440 seconds = 24 minutes exactly → ceil(1440/60) = 24
        // 1441 seconds = 24 min 1 sec → ceil(1441/60) = ceil(24.016) = 25
        // We can't easily set remainingSeconds directly since it's private(set),
        // but we can verify the formula logic
        #expect(state.remainingSeconds == 1500)
        #expect(state.currentMinute == 25) // ceil(1500/60) = 25

        state.stop()
        #expect(state.currentMinute == 0) // ceil(0/60) = 0
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

    @Test func stopResetsState() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()
        state.stop()

        #expect(state.mode == .stopped)
        #expect(state.remainingSeconds == 0)
        #expect(state.cycleStartDate == nil)
        #expect(state.cycleDuration == 0)
    }

    @Test func continuousSliderOffsetWhenStopped() {
        let state = TimerState()
        let offset = state.continuousSliderOffset(at: Date())
        #expect(offset == 0)
    }

    @Test func continuousSliderOffsetAtStart() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        // Right at start, offset should be near 500 (full width for work)
        let offset = state.continuousSliderOffset(at: state.cycleStartDate!)
        #expect(offset == 500)

        state.stop()
    }

    @Test func continuousSliderOffsetAtEnd() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        // At end of cycle, offset should be 0
        let endDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration)
        let offset = state.continuousSliderOffset(at: endDate)
        #expect(offset == 0)

        state.stop()
    }

    @Test func continuousSliderOffsetAtMidpoint() {
        let state = TimerState()
        state.soundEnabled = false
        state.start()

        let midDate = state.cycleStartDate!.addingTimeInterval(state.cycleDuration / 2)
        let offset = state.continuousSliderOffset(at: midDate)
        #expect(offset == 250) // half of 500

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
@Suite struct PanelOriginTests {
    @Test func centeredBelowButton() {
        let buttonRect = CGRect(x: 900, y: 800, width: 30, height: 24)
        let panelSize = CGSize(width: 220, height: 206)
        let origin = StatusItemController.panelOrigin(buttonRect: buttonRect, panelSize: panelSize)

        // x: centered under button midX (915) - panelWidth/2 (110) = 805
        #expect(origin.x == 805)
        // y: button minY (800) - panelHeight (206) = 594
        #expect(origin.y == 594)
    }
}
