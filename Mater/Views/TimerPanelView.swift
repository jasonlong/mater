import SwiftUI

struct TimerPanelView: View {
    var timerState: TimerState

    private var buttonTextColor: Color {
        switch timerState.mode {
        case .working:
            return Color(red: 0.957, green: 0.047, blue: 0.020) // #f40c05
        case .breaking:
            return Color(red: 0.306, green: 0.012, blue: 0) // #4e0300
        case .stopped:
            return Color(red: 0.306, green: 0.012, blue: 0) // #4e0300
        }
    }

    var body: some View {
        ZStack {
            // Work background (red gradient)
            LinearGradient(
                colors: [
                    Color(red: 0.957, green: 0.047, blue: 0.020),
                    Color(red: 0.902, green: 0.043, blue: 0.020),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(timerState.mode == .breaking ? 0 : 1)

            // Break background (green gradient)
            LinearGradient(
                colors: [
                    Color(red: 0.094, green: 0.788, blue: 0.231),
                    Color(red: 0.090, green: 0.733, blue: 0.235),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(timerState.mode == .breaking ? 1 : 0)

            // Content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 41)

                RulerView(timerState: timerState)
                    .frame(height: 58)

                // Groove
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 6)
                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 2)

                // Marker
                Text("\u{25B2}")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                // Button
                Button(timerState.mode == .stopped ? "Start" : "Stop") {
                    if timerState.mode == .stopped {
                        timerState.start()
                    } else {
                        timerState.stop()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(buttonTextColor)
                .frame(width: 95, height: 38)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
                .shadow(color: Color.black.opacity(0.23), radius: 5, x: 0, y: 3)
                .focusable(false)

                Spacer(minLength: 0)
            }
        }
        .animation(.linear(duration: 0.5), value: timerState.mode)
        .frame(width: 220, height: 206)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
