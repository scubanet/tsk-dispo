import Testing
@testable import AtollTalk

@Suite struct ServiceFactoryTests {
  @Test func basicReturnsAppleTranslator() {
    let t = ServiceFactory.translator(isPro: false, anthropicKey: "", model: "m")
    #expect(t is AppleTranslator)
  }
  @Test func proReturnsTranslationService() {
    let t = ServiceFactory.translator(isPro: true, anthropicKey: "k", model: "m")
    #expect(t is TranslationService)
  }
}
