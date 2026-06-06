import Testing
@testable import AtollTalk

@Suite struct TierTests {
  @Test func proLanguagesArePro() {
    #expect(AppLanguage.tl.tier == .pro)
    #expect(AppLanguage.ceb.tier == .pro)
  }
  @Test func standardLanguagesAreBasic() {
    for l in [AppLanguage.de, .uk, .en, .it, .es, .fr] { #expect(l.tier == .basic) }
  }
  @Test func basicEqualsAppleTranslatable() {
    #expect(AppLanguage.de.appleTranslationSupported == true)
    #expect(AppLanguage.tl.appleTranslationSupported == false)
  }
}
