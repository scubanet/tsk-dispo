import Foundation
import SwiftData

/// SwiftData mirror of `Card`. JSON-typed columns hold `Codable`-roundtripped
/// values for `CardTheme`, `DiveProfile?`, and `FieldVisibility`.
///
/// See `CacheConverters.swift` for `Card` ↔ `CardEntity` bridging and
/// `CacheStore` for CRUD.
@Model
final class CardEntity {
  @Attribute(.unique) var id: UUID
  var personId:               UUID
  var slug:                   String
  var title:                  String
  var subtitle:               String?
  var badge:                  String?
  var themeJSON:              String        // Codable round-tripped CardTheme
  var diveJSON:               String?       // Codable round-tripped DiveProfile?
  var fieldVisibilityJSON:    String        // Codable round-tripped FieldVisibility
  var isDefault:              Bool
  var isActive:               Bool
  var createdAt:              Date
  var updatedAt:              Date
  var lastFetched:            Date

  init(id: UUID, personId: UUID, slug: String, title: String, subtitle: String?,
       badge: String?, themeJSON: String, diveJSON: String?, fieldVisibilityJSON: String,
       isDefault: Bool, isActive: Bool, createdAt: Date, updatedAt: Date, lastFetched: Date) {
    self.id = id; self.personId = personId; self.slug = slug; self.title = title
    self.subtitle = subtitle; self.badge = badge
    self.themeJSON = themeJSON; self.diveJSON = diveJSON; self.fieldVisibilityJSON = fieldVisibilityJSON
    self.isDefault = isDefault; self.isActive = isActive
    self.createdAt = createdAt; self.updatedAt = updatedAt; self.lastFetched = lastFetched
  }
}
