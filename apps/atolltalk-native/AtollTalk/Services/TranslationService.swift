import Foundation
import AtollLLM

struct TranslationService: Translator {
  let provider: any LLMProvider
  let model: String

  init(apiKey: String, model: String = Config.defaultModel, session: URLSession = .shared) {
    self.provider = AnthropicProvider(apiKey: apiKey, session: session)
    self.model = model
  }

  /// Test seam — inject a mock provider.
  init(provider: any LLMProvider, model: String = Config.defaultModel) {
    self.provider = provider
    self.model = model
  }

  static func systemPrompt(context: String, glossary: String, target: AppLanguage) -> String {
    var p = context
    p += "\n\nÜbersetze den folgenden Text nach \(target.displayName) (Code: \(target.rawValue))."
    if !glossary.isEmpty {
      p += "\n\nGlossar — diese Begriffe immer so übersetzen:\n\(glossary)"
    }
    return p
  }

  func translate(
    _ text: String, from source: AppLanguage, to target: AppLanguage,
    context: String, glossary: String
  ) async throws -> String {
    // `source` is unused: Claude detects the source language from the text.
    let system = Self.systemPrompt(context: context, glossary: glossary, target: target)
    let stream = provider.streamChat(
      messages: [LLMMessage(role: .user, content: text)],
      tools: [],
      model: model,
      systemPrompt: system
    )
    var out = ""
    for try await chunk in stream {
      if case let .text(t) = chunk { out += t }
    }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
