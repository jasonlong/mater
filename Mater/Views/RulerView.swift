import SwiftUI

private let blockWidth: CGFloat = 100
let rulerGradient = LinearGradient(
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
        // Read observed values outside TimelineView so changes trigger re-render
        let labels = minuteLabels
        let tickWidth = totalTickWidth
        let totalWidth = sliderWidth
        let minutes = maxMinutes
        let spacing = tickSpacing
        let _ = timerState.frozenSliderOffset

        TimelineView(.animation(paused: timerState.mode == .stopped && !timerState.isWinding && !timerState.isDragging && !timerState.isMomentum)) { timeline in
            let offset = currentOffset(at: timeline.date)

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

    private func currentOffset(at date: Date) -> CGFloat {
        if timerState.isMomentum {
            timerState.updateMomentum(at: date)
            return -timerState.frozenSliderOffset
        } else if timerState.isDragging {
            return -timerState.frozenSliderOffset
        } else if timerState.isWinding {
            return -timerState.windingSliderOffset(at: date)
        } else if timerState.mode == .stopped {
            return -timerState.frozenSliderOffset
        } else {
            return -timerState.continuousSliderOffset(at: date)
        }
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
            .onEnded { value in
                // Derive velocity from SwiftUI's predicted end translation
                let remaining = value.predictedEndTranslation.width - value.translation.width
                let velocity = -remaining * 3 // negative because drag left = positive offset
                timerState.dragEnded(velocity: velocity)
            }
    }
}
