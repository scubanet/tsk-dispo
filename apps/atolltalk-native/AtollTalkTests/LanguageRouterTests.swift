import Testing
@testable import AtollTalk

@Suite struct LanguageRouterTests {
  let pair = LanguagePair(a: .de, b: .uk)

  @Test func germanRoutesToUkrainian() {
    let r = LanguageRouter.route(detected: .de, in: pair)
    #expect(r?.source == .de)
    #expect(r?.target == .uk)
  }
  @Test func ukrainianRoutesToGerman() {
    let r = LanguageRouter.route(detected: .uk, in: pair)
    #expect(r?.source == .uk)
    #expect(r?.target == .de)
  }
  @Test func scribeCodesMapToLanguages() {
    #expect(AppLanguage(scribeCode: "deu") == .de)
    #expect(AppLanguage(scribeCode: "de")  == .de)
    #expect(AppLanguage(scribeCode: "ukr") == .uk)
    #expect(AppLanguage(scribeCode: "uk")  == .uk)
    #expect(AppLanguage(scribeCode: "fra") == nil)
  }
}
