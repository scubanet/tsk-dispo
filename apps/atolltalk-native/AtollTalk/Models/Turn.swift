import Foundation
import SwiftData

@Model
final class Turn {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var sourceText: String
  var sourceLangCode: String
  var targetText: String
  var targetLangCode: String

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    sourceText: String,
    sourceLang: AppLanguage,
    targetText: String,
    targetLang: AppLanguage
  ) {
    self.id = id
    self.createdAt = createdAt
    self.sourceText = sourceText
    self.sourceLangCode = sourceLang.rawValue
    self.targetText = targetText
    self.targetLangCode = targetLang.rawValue
  }

  var sourceLang: AppLanguage { AppLanguage(rawValue: sourceLangCode) ?? .de }
  var targetLang: AppLanguage { AppLanguage(rawValue: targetLangCode) ?? .uk }
}
