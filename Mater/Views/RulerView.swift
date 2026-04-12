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
    private var fullBlocks: Int { maxMinutes / 5 }
    private var extraTicks: Int { maxMinutes % 5 }
    private var minuteLabels: [Int] { stride(from: 0, through: maxMinutes, by: 5).map { $0 } }
    private var totalTickWidth: CGFloat { CGFloat(maxMinutes) * (blockWidth / 5) + 5 }
    private var sliderWidth: CGFloat { CGFloat(maxMinutes) * (blockWidth / 5) + blockWidth }

    var body: some View {
        // Read preferences outside TimelineView so changes trigger re-render
        let labels = minuteLabels
        let tickWidth = totalTickWidth
        let totalWidth = sliderWidth
        let blocks = fullBlocks
        let extra = extraTicks

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
                        let tickSpacing = blockWidth / 5

                        // Full 5-minute blocks
                        for block in 0..<blocks {
                            let blockX = CGFloat(block) * blockWidth
                            for i in 0..<5 {
                                let x = blockX + CGFloat(i) * tickSpacing
                                let width = i == 0 ? bigTickWidth : smallTickWidth
                                let rect = CGRect(x: x, y: 0, width: width, height: tickHeight)
                                context.fill(Path(rect), with: .color(.white))
                            }
                        }

                        // Partial block ticks (e.g. 3 extra minutes past the last full block)
                        let partialX = CGFloat(blocks) * blockWidth
                        for i in 0...extra {
                            let x = partialX + CGFloat(i) * tickSpacing
                            let width = i == 0 ? bigTickWidth : smallTickWidth
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
