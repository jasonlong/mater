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

    var body: some View {
        ZStack {
            workGradient
                .opacity(timerState.mode == .breaking ? 0 : 1)

            breakGradient
                .opacity(timerState.mode == .breaking ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()
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
                    .foregroundColor(.white)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                timerButton
                    .focusable(false)

                Spacer(minLength: 0)
            }
        }
        .animation(.linear(duration: 0.5), value: timerState.mode)
        .frame(width: 220, height: 206)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var timerButton: some View {
        let label = timerState.mode == .stopped ? "Start" : "Stop"

        Button(label) {
            if timerState.mode == .stopped {
                timerState.start()
            } else {
                timerState.stop()
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(timerState.mode == .working ? workRed : buttonDark)
        .frame(width: 95, height: 38)
        .modifier(GlassButtonModifier())
        .colorScheme(.light)
    }
}

private struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
        }
    }
}
