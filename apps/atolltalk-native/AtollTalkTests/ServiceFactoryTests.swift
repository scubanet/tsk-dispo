import Testing
@testable import AtollTalk

@Suite struct ServiceFactoryTests {
  @Test func basicReturnsAppleTranslator() {
    let t = ServiceFactory.translator(isPro: false, model: "m", jws: { nil })
    #expect(t is AppleTranslator)
  }
  @Test func proReturnsProxyTranslator() {
    let t = ServiceFactory.translator(isPro: true, model: "m", jws: { "fake" })
    #expect(t is ProxyTranslator)
  }
}
