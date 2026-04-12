import SwiftUI

private let blockWidth: CGFloat = 100
private let rulerGradient = LinearGradient(
    colors: [.white, Color(white: 0.88)],
    startPoint: .top,
    endPoint: .bottom
)

private let tickMarks = Canvas { context, size in
    let tickHeight = size.height
    let bigTickWidth: CGFloat = 3.0
    let smallTickWidth: CGFloat = 2.0

    for block in 0..<5 {
        let blockX = CGFloat(block) * blockWidth
        let positions: [CGFloat] = [0.0, 0.20, 0.40, 0.60, 0.80]

        for (index, pos) in positions.enumerated() {
            let x = blockX + pos * blockWidth
            let width = index == 0 ? bigTickWidth : smallTickWidth
            let rect = CGRect(x: x, y: 0, width: width, height: tickHeight)
            context.fill(Path(rect), with: .color(.white))
        }
    }

    let finalRect = CGRect(x: 500, y: 0, width: bigTickWidth, height: tickHeight)
    context.fill(Path(finalRect), with: .color(.white))
}

struct RulerView: View {
    var timerState: TimerState
    @State private var dragStartOffset: CGFloat = 0

    private let minuteLabels = [0, 5, 10, 15, 20, 25]
    private let sliderWidth: CGFloat = 600

    var body: some View {
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
                slider(offset: offset)
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

    private func slider(offset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(minuteLabels, id: \.self) { minute in
                    Text("\(minute)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(rulerGradient)
                        .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
                        .frame(width: blockWidth, alignment: .center)
                }
            }
            .offset(x: -blockWidth / 2)

            tickMarks
                .frame(width: 505, height: 15)
                .overlay(rulerGradient.blendMode(.sourceAtop))
                .shadow(color: .black.opacity(0.35), radius: 0.5, x: 0, y: 1)
                .padding(.top, 5)
        }
        .frame(width: sliderWidth)
        .offset(x: 109 + offset)
    }
}
