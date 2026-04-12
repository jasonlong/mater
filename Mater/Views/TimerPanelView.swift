import SwiftUI

private let workRed = Color(red: 0.957, green: 0.047, blue: 0.020)
private let workRedDark = Color(red: 0.902, green: 0.043, blue: 0.020)
private let breakGreen = Color(red: 0.094, green: 0.788, blue: 0.231)
private let breakGreenDark = Color(red: 0.090, green: 0.733, blue: 0.235)
private let buttonDark = Color(red: 0.306, green: 0.012, blue: 0)

private let workGradient = LinearGradient(colors: [workRed, workRedDark], startPoint: .top, endPoint: .bottom)
private let breakGradient = LinearGradient(colors: [breakGreen, breakGreenDark], startPoint: .top, endPoint: .bottom)

struct TimerPanelView: View {
    var timerState: TimerState
    var showSettings: () -> Void = {}
    #if DEBUG
    var debugState: DebugState?
    #endif

    var body: some View {
        ZStack {
            Color.white

            workGradient
                .opacity(timerState.mode == .breaking ? 0 : 1)

            breakGradient
                .opacity(timerState.mode == .breaking ? 1 : 0)

            VStack(spacing: 0) {
                debugTimeLabel
                    .frame(height: 41)

                RulerView(timerState: timerState)
                    .frame(height: 58)

                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 3)
                    }
                    .frame(height: 6)
                    .clipped()

                Text("\u{25B2}")
                    .font(.system(size: 22))
                    .foregroundStyle(rulerGradient)
                    .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                timerButton
                    .animation(.linear(duration: 0.1), value: timerState.mode)
                    .focusable(false)

                Spacer(minLength: 0)
            }

            Button(action: showSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(8)
        }
        .animation(.linear(duration: timerState.windDuration > 0 ? timerState.windDuration : 0.2), value: timerState.mode)
        .frame(width: 220, height: 206)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var debugTimeLabel: some View {
        #if DEBUG
        if debugState?.showTime == true {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let totalSeconds = if isPaused {
                    Int(ceil(Double(timerState.frozenSliderOffset) / Double(TimerState.pointsPerMinute) * 60.0))
                } else {
                    timerState.remainingSeconds
                }
                let mins = totalSeconds / 60
                let secs = totalSeconds % 60
                Text("[DEBUG: \(String(format: "%d:%02d", mins, secs))]")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        } else {
            Spacer()
        }
        #else
        Spacer()
        #endif
    }

    private var isPaused: Bool {
        timerState.mode == .stopped && timerState.frozenSliderOffset > 0
    }

    @ViewBuilder
    private var timerButton: some View {
        let label = if timerState.mode != .stopped {
            "Stop"
        } else if isPaused {
            "Resume"
        } else {
            "Start"
        }

        Button(label, action: timerState.toggle)
        .buttonStyle(.plain)
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(timerState.mode == .working ? workRed : buttonDark)
        .frame(width: 95, height: 38)
        .modifier(GlassButtonModifier())
        .colorScheme(.light)
        .overlay(alignment: .trailing) {
            if isPaused {
                Button(action: timerState.start) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 28, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .offset(x: 34)
            }
        }
    }
}

private struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            fallbackStyle(content)
        }
        #else
        fallbackStyle(content)
        #endif
    }

    private func fallbackStyle(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
    }
}
