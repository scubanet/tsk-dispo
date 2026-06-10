import Testing
@testable import AtollTalk

@Suite struct ServiceFactoryTests {
  @Test func basicReturnsRefinedAppleTranslator() throws {
    let t = ServiceFactory.translator(isPro: false, model: "m", jws: { nil })
    let refiner = try #require(t as? GlossaryRefiner)
    #expect(refiner.base is AppleTranslator)
  }
  @Test func proReturnsProxyTranslator() {
    let t = ServiceFactory.translator(isPro: true, model: "m", jws: { "fake" })
    #expect(t is ProxyTranslator)
  }
}
