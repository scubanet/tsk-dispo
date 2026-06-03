import Testing
import AVFoundation
@testable import AtollSpeech

@Suite struct WAVExportTests {
  @Test func exportsRiffWavHeaderAt16k() throws {
    let acc = AudioBufferAccumulator()
    let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    let frames: AVAudioFrameCount = 4800            // 0.1s
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
    buf.frameLength = frames
    for i in 0..<Int(frames) {
      buf.floatChannelData![0][i] = sinf(Float(i) * 0.05) * 0.2
    }
    acc.append(buf)

    let wav = try #require(acc.exportWAV(sampleRate: 16000, channels: 1))
    #expect(wav.count > 44)
    #expect(wav.prefix(4) == Data("RIFF".utf8))
    #expect(wav.subdata(in: 8..<12) == Data("WAVE".utf8))
  }
}
