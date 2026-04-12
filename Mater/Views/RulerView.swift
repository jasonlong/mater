import SwiftUI

private let blockWidth: CGFloat = 100
private let rulerGradient = LinearGradient(
    colors: [.white, Color(white: 0.88)],
    startPoint: .top,
    endPoint: .bottom
)

struct RulerView: View {
    var timerState: TimerState
    @State private var dragStartOffset: CGFloat = 0

    private var maxMinutes: Int { timerState.preferences.workMinutes }
    private var minuteLabels: [Int] { stride(from: 0, through: maxMinutes, by: 5).map { $0 } }
    private var totalTickWidth: CGFloat { CGFloat(maxMinutes) * tickSpacing + 5 }
    private var sliderWidth: CGFloat { CGFloat(maxMinutes) * tickSpacing + blockWidth }
    private var tickSpacing: CGFloat { blockWidth / 5 }

    var body: some View {
        // Read preferences outside TimelineView so changes trigger re-render
        let labels = minuteLabels
        let tickWidth = totalTickWidth
        let totalWidth = sliderWidth
        let minutes = maxMinutes
        let spacing = tickSpacing

        TimelineView(.animation(paused: timerState.mode == .stopped && !timerState.isWinding && !timerState.isDragging)) { timeline in
            let offset: CGFloat = if timerState.isDragging {
                -timerState.frozenSliderOffset
            } else if timerState.isWinding {
                -timerState.windingSliderOffset(at: timeline.date)
            } else if timerState.mode == .stopped {
                -timerState.frozenSliderOffset
            } else {
                -timerState.continuousSliderOffset(at: timeline.date)
            }

            GeometryReader { _ in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(labels, id: \.self) { minute in
                            Text("\(minute)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(rulerGradient)
                                .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
                                .frame(width: blockWidth, alignment: .center)
                        }
                    }
                    .offset(x: -blockWidth / 2)

                    Canvas { context, size in
                        let tickHeight = size.height
                        let bigTickWidth: CGFloat = 3.0
                        let smallTickWidth: CGFloat = 2.0

                        for minute in 0...minutes {
                            let x = CGFloat(minute) * spacing
                            let isMajor = minute % 5 == 0
                            let width = isMajor ? bigTickWidth : smallTickWidth
                            let rect = CGRect(x: x, y: 0, width: width, height: tickHeight)
                            context.fill(Path(rect), with: .color(.white))
                        }
                    }
                    .frame(width: tickWidth, height: 15)
                    .overlay(rulerGradient.blendMode(.sourceAtop))
                    .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
                    .padding(.top, 5)
                }
                .frame(width: totalWidth, alignment: .leading)
                .offset(x: 109 + offset)
            }
        }
        .clipped()
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !timerState.isDragging {
                    timerState.dragBegan()
                    dragStartOffset = timerState.frozenSliderOffset
                }
                let newOffset = dragStartOffset - value.translation.width
                timerState.dragChanged(offset: newOffset)
            }
            .onEnded { _ in
                timerState.dragEnded()
            }
    }
}
