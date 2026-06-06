import Testing
@testable import AtollTalk

@MainActor @Suite struct SynthesisServiceTests {
  @Test func basicTierNeverWiresElevenLabsEvenWithKey() {
    let s = SynthesisService(elevenLabsKey: "secret", voices: [.de: "voice-id"], tier: .basic)
    #expect(s.isElevenLabsActive == false)
  }
  @Test func proTierWithKeyWiresElevenLabs() {
    let s = SynthesisService(elevenLabsKey: "secret", voices: [.de: "voice-id"], tier: .pro)
    #expect(s.isElevenLabsActive == true)
  }
  @Test func proTierWithoutKeyStaysApple() {
    let s = SynthesisService(elevenLabsKey: nil, voices: [:], tier: .pro)
    #expect(s.isElevenLabsActive == false)
  }
}
