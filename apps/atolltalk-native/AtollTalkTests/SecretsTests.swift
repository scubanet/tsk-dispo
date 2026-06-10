import Testing
import Foundation
@testable import AtollTalk

@Suite struct SecretsTests {
  /// Regression guard: the ElevenLabs key must never return to the binary —
  /// STT/TTS run through the `speech` Edge Function (key server-side).
  @Test func speechProxyIsConfiguredInsteadOfAPIKey() {
    #expect(Config.speechProxyURL.absoluteString.contains("/functions/v1/speech"))
    #expect(Config.speechProxyURL.scheme == "https")
  }

  /// A fresh DeviceID is generated once and then stays stable.
  @Test func deviceIDIsStableAcrossReads() {
    let a = DeviceID.current
    let b = DeviceID.current
    #expect(a == b)
    #expect(UUID(uuidString: a) != nil)
  }
}
