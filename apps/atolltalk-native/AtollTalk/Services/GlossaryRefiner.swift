import Foundation
import FoundationModels

/// Decorator that translates via `base` (Apple on-device MT, which ignores the
/// glossary) and then optionally rewrites the result so the glossary terms are
/// applied consistently, using Apple Intelligence's on-device model. Every
/// failure or unavailability path returns the MT translation unchanged — a
/// missing model must never block a working translation.
struct GlossaryRefiner: Translator {
  let base: any Translator
  /// Test seam: defaults to the real FoundationModels refinement.
  let refine: @Sendable (_ mt: String, _ target: AppLanguage, _ glossary: String) async -> String

  init(base: any Translator,
       refine: (@Sendable (String, AppLanguage, String) async -> String)? = nil) {
    self.base = base
    self.refine = refine ?? GlossaryRefiner.modelRefine
  }

  func translate(_ text: String, from source: AppLanguage, to target: AppLanguage,
                 context: String, glossary: String) async throws -> String {
    let mt = try await base.translate(text, from: source, to: target,
                                      context: context, glossary: glossary)
    guard Config.glossaryRefinementEnabled,
          !glossary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return mt }
    return await refine(mt, target, glossary)
  }

  /// Real on-device refinement. Skips when the model is unavailable or the target
  /// language isn't supported; any thrown error falls back to `mt`.
  @Sendable static func modelRefine(_ mt: String, target: AppLanguage,
                                    glossary: String) async -> String {
    let model = SystemLanguageModel.default
    guard case .available = model.availability,
          model.supportsLocale(Locale(identifier: target.appleLocale))
    else { return mt }
    do {
      let session = LanguageModelSession(instructions: """
        Du bist ein Übersetzungs-Lektor. Wende das Glossar konsistent auf die \
        vorhandene Übersetzung an. Ändere nichts anderes an Bedeutung oder Stil. \
        Gib NUR die korrigierte Übersetzung aus, ohne Kommentar.
        """)
      let prompt = """
        Zielsprache: \(target.displayName)
        Glossar:
        \(glossary)
        Übersetzung:
        \(mt)
        """
      let out = try await session.respond(to: prompt).content
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return out.isEmpty ? mt : out
    } catch {
      return mt   // unsupportedLanguageOrLocale, refusal, exceededContextWindowSize, assetsUnavailable …
    }
  }
}
