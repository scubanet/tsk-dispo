import Foundation
import AVFoundation
import OSLog

private let log = Logger(subsystem: "swiss.weckherlin.tide", category: "tts.elevenlabs")

/// `Synthesizer` impl that pipes text → ElevenLabs API → AVAudioPlayer.
///
/// Queue behaviour: each `speak(_:)` triggers an async HTTP request. The
/// returned audio is appended to an internal FIFO queue. Playback is
/// serial — the next clip starts only after the previous one finishes.
/// This matches `AppleSynthesizer`'s queue semantics so the rest of the
/// app doesn't need to care which provider is active.
public final class ElevenLabsSynthesizer: NSObject, Synthesizer, @unchecked Sendable {
  private let client: ElevenLabsClient
  private let lock = NSLock()
  private var voiceID: String
  private var audioQueue: [Data] = []
  private var currentPlayer: AVAudioPlayer?

  public init(client: ElevenLabsClient, defaultVoiceID: String) {
    self.client = client
    self.voiceID = defaultVoiceID
    super.init()
  }

  public var isSpeaking: Bool {
    lock.lock(); defer { lock.unlock() }
    return currentPlayer?.isPlaying == true || !audioQueue.isEmpty
  }

  public func setVoice(identifier: String) {
    lock.lock(); defer { lock.unlock() }
    voiceID = identifier
  }

  public func speak(_ text: String) {
    guard !text.isEmpty else { return }
    lock.lock()
    let id = voiceID
    lock.unlock()
    log.debug("requesting TTS for \(text.count, privacy: .public) chars")
    Task { [client] in
      do {
        let data = try await client.synthesize(text: text, voiceID: id)
        await MainActor.run { self.enqueue(data) }
      } catch {
        log.error("TTS failed: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  public func stop() {
    lock.lock()
    audioQueue.removeAll()
    currentPlayer?.stop()
    currentPlayer = nil
    lock.unlock()
  }

  // MARK: - Queue

  @MainActor
  private func enqueue(_ data: Data) {
    lock.lock()
    audioQueue.append(data)
    let shouldStart = currentPlayer == nil
    lock.unlock()
    if shouldStart { playNext() }
  }

  @MainActor
  private func playNext() {
    lock.lock()
    guard !audioQueue.isEmpty else {
      currentPlayer = nil
      lock.unlock()
      return
    }
    let data = audioQueue.removeFirst()
    lock.unlock()

    do {
      let player = try AVAudioPlayer(data: data)
      player.delegate = self
      lock.lock()
      currentPlayer = player
      lock.unlock()
      player.prepareToPlay()
      player.play()
    } catch {
      log.error("AVAudioPlayer init failed: \(error.localizedDescription, privacy: .public)")
      playNext()  // skip the bad clip and continue
    }
  }
}

extension ElevenLabsSynthesizer: AVAudioPlayerDelegate {
  public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in self.playNext() }
  }
}
