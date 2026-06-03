import Foundation
import AVFoundation
import AtollSpeech
import OSLog

@MainActor
final class AudioRecorder {
  enum RecorderError: Error { case permissionDenied, inputUnavailable }

  private let engine = AVAudioEngine()
  private let accumulator = AudioBufferAccumulator()
  private var isRunning = false
  private let log = Logger(subsystem: "swiss.atoll.talk", category: "audio")

  /// iOS 17+ permission request.
  func requestPermission() async -> Bool {
    await AVAudioApplication.requestRecordPermission()
  }

  func start() async throws {
    guard !isRunning else { return }
    guard await requestPermission() else { throw RecorderError.permissionDenied }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio,
                            options: [.defaultToSpeaker, .allowBluetooth])
    try session.setActive(true)

    accumulator.reset()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw RecorderError.inputUnavailable
    }

    let acc = accumulator
    let block: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
      acc.append(buffer)        // accumulator is @unchecked Sendable + lock-guarded
    }
    input.installTap(onBus: 0, bufferSize: 1024, format: format, block: block)
    engine.prepare()
    try engine.start()
    isRunning = true
    log.debug("recording started")
  }

  /// Stop and return 16 kHz mono WAV ready for Scribe (nil if no audio).
  func stop() -> Data? {
    guard isRunning else { return nil }
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    isRunning = false
    try? AVAudioSession.sharedInstance()
      .setActive(false, options: [.notifyOthersOnDeactivation])
    return accumulator.exportWAV(sampleRate: 16000, channels: 1)
  }
}
