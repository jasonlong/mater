import AVFoundation

struct WindupSoundGenerator {
    private static let sampleRate: Double = 44100
    private static let clickDuration: Double = 0.003

    static func generate(clickCount: Int, totalDuration: TimeInterval) -> AVAudioPlayer? {
        guard clickCount > 0, totalDuration > 0 else { return nil }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let totalFrames = AVAudioFrameCount(totalDuration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        buffer.frameLength = totalFrames

        guard let samples = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<Int(totalFrames) { samples[i] = 0 }

        var rng: UInt64 = 12345
        func nextRandom() -> Float {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int64(bitPattern: rng >> 33)) / Float(Int64.max >> 33)
        }
        func nextRandomPositive() -> Float {
            abs(nextRandom())
        }

        let clickTimes = clickTimings(count: clickCount, totalDuration: totalDuration)
        let clickFrames = Int(clickDuration * sampleRate)

        for clickTime in clickTimes {
            let startFrame = Int(clickTime * sampleRate)
            // Random amplitude variation per click for organic feel (0.5 to 1.0)
            let clickAmp = 0.5 + Double(nextRandomPositive()) * 0.5

            for i in 0..<clickFrames {
                let frame = startFrame + i
                guard frame < Int(totalFrames) else { break }
                let t = Double(i) / Double(clickFrames)

                // Very fast exponential decay for sharp transient
                let envelope = Float(exp(-t * 60.0)) * Float(clickAmp)

                // Three metallic frequency bands matching the reference
                let f1 = Float(sin(2.0 * .pi * 3000.0 * Double(i) / sampleRate)) * 0.125
                let f2 = Float(sin(2.0 * .pi * 6350.0 * Double(i) / sampleRate)) * 0.10
                let f3 = Float(sin(2.0 * .pi * 8650.0 * Double(i) / sampleRate)) * 0.0625

                let noise = nextRandom() * 0.075

                samples[frame] += (f1 + f2 + f3 + noise) * envelope
            }
        }

        guard let data = bufferToWAVData(buffer) else { return nil }
        return try? AVAudioPlayer(data: data)
    }

    private static func clickTimings(count: Int, totalDuration: TimeInterval) -> [TimeInterval] {
        guard count > 1 else { return [0] }

        var times: [TimeInterval] = []
        for i in 0..<count {
            let position = Double(i) / Double(count - 1)
            let t = 1.0 - sqrt(1.0 - position)
            times.append(t * (totalDuration - clickDuration))
        }
        return times
    }

    private static func bufferToWAVData(_ buffer: AVAudioPCMBuffer) -> Data? {
        let channels = 1
        let bitsPerSample = 16
        let bytesPerSample = bitsPerSample / 8
        let frameCount = Int(buffer.frameLength)
        let dataSize = frameCount * channels * bytesPerSample

        var data = Data()

        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(&data, UInt32(36 + dataSize))
        data.append(contentsOf: "WAVE".utf8)

        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(&data, 16)
        appendUInt16(&data, 1)
        appendUInt16(&data, UInt16(channels))
        appendUInt32(&data, UInt32(sampleRate))
        appendUInt32(&data, UInt32(sampleRate * Double(channels * bytesPerSample)))
        appendUInt16(&data, UInt16(channels * bytesPerSample))
        appendUInt16(&data, UInt16(bitsPerSample))

        data.append(contentsOf: "data".utf8)
        appendUInt32(&data, UInt32(dataSize))

        guard let samples = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<frameCount {
            let clamped = max(-1.0, min(1.0, samples[i]))
            let int16 = Int16(clamped * Float(Int16.max))
            appendInt16(&data, int16)
        }

        return data
    }

    private static func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 4))
    }

    private static func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }

    private static func appendInt16(_ data: inout Data, _ value: Int16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }
}
