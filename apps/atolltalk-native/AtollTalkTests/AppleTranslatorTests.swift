import Testing
import Translation
@testable import AtollTalk

@Suite struct AppleTranslatorTests {
  @Test func translatesGermanToUkrainian() async throws {
    // Only run when the DE→UK pack is actually installed (device / prepared sim).
    // Headless CI / fresh sims have no pack → skip instead of failing or trapping.
    let availability = LanguageAvailability()
    let status = await availability.status(
      from: Locale.Language(identifier: "de"),
      to: Locale.Language(identifier: "uk"))
    guard status == .installed else { return }

    let out = try await AppleTranslator()
      .translate("Guten Tag", from: .de, to: .uk, context: "", glossary: "")
    #expect(!out.isEmpty)
  }
}
