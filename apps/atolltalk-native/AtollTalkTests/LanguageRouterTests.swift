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
    #expect(AppLanguage(scribeCode: "zho") == nil)   // Chinese — not in the supported set
  }
  @Test func swissGermanMapsToGerman() {
    #expect(AppLanguage(scribeCode: "gsw")  == .de)   // ISO 639-3 Swiss German
    #expect(AppLanguage(scribeCode: "als")  == .de)   // Alemannic
    #expect(AppLanguage(scribeCode: "Swiss German") == .de)
  }
  @Test func swissGermanRoutesToUkrainian() {
    let detected = AppLanguage(scribeCode: "gsw")
    let r = detected.flatMap { LanguageRouter.route(detected: $0, in: pair) }
    #expect(r?.source == .de)
    #expect(r?.target == .uk)
  }
  @Test func newScribeCodesMap() {
    #expect(AppLanguage(scribeCode: "en")  == .en)
    #expect(AppLanguage(scribeCode: "eng") == .en)
    #expect(AppLanguage(scribeCode: "tl")  == .tl)
    #expect(AppLanguage(scribeCode: "tgl") == .tl)
    #expect(AppLanguage(scribeCode: "fil") == .tl)   // Filipino → Tagalog
    #expect(AppLanguage(scribeCode: "ceb") == .ceb)
    #expect(AppLanguage(scribeCode: "cebuano") == .ceb)
    #expect(AppLanguage(scribeCode: "it")  == .it)
    #expect(AppLanguage(scribeCode: "ita") == .it)
    #expect(AppLanguage(scribeCode: "es")  == .es)
    #expect(AppLanguage(scribeCode: "spa") == .es)
    #expect(AppLanguage(scribeCode: "fr")  == .fr)
    #expect(AppLanguage(scribeCode: "fra") == .fr)
    #expect(AppLanguage(scribeCode: "fre") == .fr)
  }
  @Test func routesWithinEnglishTagalogPair() {
    let p = LanguagePair(a: .en, b: .tl)
    #expect(LanguageRouter.route(detected: .en, in: p)?.target == .tl)
    #expect(LanguageRouter.route(detected: .tl, in: p)?.target == .en)
    // German not in this pair → no route.
    #expect(LanguageRouter.route(detected: .de, in: p) == nil)
  }
}
