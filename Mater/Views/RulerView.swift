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
                Canvas { context, size in
                    let tickHeight: CGFloat = 15
                    let bigTickWidth: CGFloat = 3.0
                    let smallTickWidth: CGFloat = 2.0
                    let margin: CGFloat = 20
                    let labelY: CGFloat = 0
                    let bottomPadding: CGFloat = 8
                    let tickY: CGFloat = size.height - tickHeight - bottomPadding

                    for minute in 0...minutes {
                        let x = margin + CGFloat(minute) * spacing

                        let isMajor = minute % 5 == 0
                        let width = isMajor ? bigTickWidth : smallTickWidth
                        let tickRect = CGRect(x: x, y: tickY, width: width, height: tickHeight)
                        context.fill(Path(tickRect), with: .color(.white))

                        if minute % 5 == 0 {
                            let text = Text("\(minute)")
                                .font(.system(size: 24, weight: .bold))
                            let resolved = context.resolve(text)
                            let textSize = resolved.measure(in: CGSize(width: 100, height: 40))
                            context.draw(resolved, at: CGPoint(x: x, y: labelY + textSize.height / 2))
                        }
                    }
                }
                .foregroundStyle(rulerGradient)
                .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
                .frame(width: totalWidth + 40)
                .offset(x: 89 + offset)
            }
        }
        .clipped()
        .highPriorityGesture(dragGesture)
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
