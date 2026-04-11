import SwiftUI

struct RulerView: View {
    var timerState: TimerState

    private let minuteLabels = [0, 5, 10, 15, 20, 25]
    private let rulerWidth: CGFloat = 505
    private let sliderWidth: CGFloat = 600
    private let blockWidth: CGFloat = 100

    private var offset: CGFloat {
        // Slider starts at right (showing high minute numbers) and moves left as time passes.
        // sliderOffset is the pixel offset based on remaining time.
        // At the start of work: sliderOffset = 500, we translate -500.
        // As time passes: sliderOffset decreases toward 0, we translate toward 0.
        -timerState.sliderOffset
    }

    var body: some View {
        GeometryReader { _ in
            // The slider is wider than the viewport and slides horizontally
            VStack(alignment: .leading, spacing: 0) {
                // Minute labels
                HStack(spacing: 0) {
                    ForEach(minuteLabels, id: \.self) { minute in
                        Text("\(minute)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: blockWidth, alignment: .center)
                    }
                }
                .offset(x: -blockWidth / 2)

                // Ruler tick marks
                Canvas { context, size in
                    let tickHeight: CGFloat = size.height
                    let bigTickWidth: CGFloat = 3.0
                    let smallTickWidth: CGFloat = 2.0

                    for block in 0..<5 {
                        let blockX = CGFloat(block) * blockWidth
                        let tickPositions: [CGFloat] = [0.0, 0.20, 0.40, 0.60, 0.80]

                        for (index, pos) in tickPositions.enumerated() {
                            let x = blockX + pos * blockWidth
                            let width = index == 0 ? bigTickWidth : smallTickWidth
                            let rect = CGRect(x: x, y: 0, width: width, height: tickHeight)
                            context.fill(Path(rect), with: .color(.white))
                        }
                    }
                    // Final tick at the end
                    let finalRect = CGRect(x: 500, y: 0, width: bigTickWidth, height: tickHeight)
                    context.fill(Path(finalRect), with: .color(.white))
                }
                .frame(width: rulerWidth, height: 15)
                .padding(.top, 5)
            }
            .frame(width: sliderWidth)
            .offset(x: 109 + offset)
        }
        .clipped()
    }
}
