import Foundation

/// Converters between domain structs (Card/Lead/Scan from Models/) and
/// SwiftData entities (CardEntity/LeadEntity/ScanEntity).
/// JSON columns (themeJSON, diveJSON, fieldVisibilityJSON, customAnswersJSON)
/// are encoded via the standard JSONEncoder/Decoder.

enum CacheConvertError: Error {
  case encodeFailed(String)
  case decodeFailed(String)
  case unknownStatus(String)
  case unknownScanSource(String)
}

// MARK: - Card ↔ CardEntity

extension Card {
  init(entity: CardEntity) throws {
    guard let theme = try? JSONDecoder().decode(CardTheme.self,
                                                from: Data(entity.themeJSON.utf8)) else {
      throw CacheConvertError.decodeFailed("theme")
    }
    let dive: DiveProfile?
    if let diveJSON = entity.diveJSON {
      dive = try? JSONDecoder().decode(DiveProfile.self, from: Data(diveJSON.utf8))
    } else { dive = nil }
    guard let fv = try? JSONDecoder().decode(FieldVisibility.self,
                                             from: Data(entity.fieldVisibilityJSON.utf8)) else {
      throw CacheConvertError.decodeFailed("fieldVisibility")
    }
    self.init(
      id:               entity.id,
      personId:         entity.personId,
      slug:             entity.slug,
      title:            entity.title,
      subtitle:         entity.subtitle,
      badge:            entity.badge,
      theme:            theme,
      diveProfile:      dive,
      fieldVisibility:  fv,
      isDefault:        entity.isDefault,
      isActive:         entity.isActive,
      createdAt:        entity.createdAt,
      updatedAt:        entity.updatedAt
    )
  }

  func toEntity(lastFetched: Date = .now) throws -> CardEntity {
    let enc = JSONEncoder()
    guard let themeData = try? enc.encode(theme),
          let themeStr = String(data: themeData, encoding: .utf8) else {
      throw CacheConvertError.encodeFailed("theme")
    }
    let diveStr: String? = diveProfile.flatMap { dp in
      (try? enc.encode(dp)).flatMap { String(data: $0, encoding: .utf8) }
    }
    guard let fvData = try? enc.encode(fieldVisibility),
          let fvStr  = String(data: fvData, encoding: .utf8) else {
      throw CacheConvertError.encodeFailed("fieldVisibility")
    }
    return CardEntity(
      id:                  id,
      personId:            personId,
      slug:                slug,
      title:               title,
      subtitle:            subtitle,
      badge:               badge,
      themeJSON:           themeStr,
      diveJSON:            diveStr,
      fieldVisibilityJSON: fvStr,
      isDefault:           isDefault,
      isActive:            isActive,
      createdAt:           createdAt,
      updatedAt:           updatedAt,
      lastFetched:         lastFetched
    )
  }
}

// MARK: - Lead ↔ LeadEntity

extension Lead {
  init(entity: LeadEntity) throws {
    guard let status = LeadStatus(rawValue: entity.status) else {
      throw CacheConvertError.unknownStatus(entity.status)
    }
    let answers: [String: String]
    if let data = entity.customAnswersJSON.data(using: .utf8),
       let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
      answers = decoded
    } else {
      answers = [:]
    }
    self.init(
      id:                     entity.id,
      cardId:                 entity.cardId,
      firstName:              entity.firstName,
      lastName:               entity.lastName,
      email:                  entity.email,
      phone:                  entity.phone,
      message:                entity.message,
      topic:                  entity.topic,
      customAnswers:          answers,
      capturedAt:             entity.capturedAt,
      ipCountry:              entity.ipCountry,
      importedToAddressBook:  entity.importedToAddressBook,
      status:                 status,
      avatarColorHex:         entity.avatarColorHex
    )
  }

  func toEntity(lastFetched: Date = .now) -> LeadEntity {
    let answersStr: String = {
      guard let data = try? JSONEncoder().encode(customAnswers),
            let str  = String(data: data, encoding: .utf8) else {
        return "{}"
      }
      return str
    }()
    return LeadEntity(
      id:                    id,
      cardId:                cardId,
      firstName:             firstName,
      lastName:              lastName,
      email:                 email,
      phone:                 phone,
      message:               message,
      topic:                 topic,
      customAnswersJSON:     answersStr,
      capturedAt:            capturedAt,
      ipCountry:             ipCountry,
      status:                status.rawValue,
      avatarColorHex:        avatarColorHex,
      importedToAddressBook: importedToAddressBook,
      lastFetched:           lastFetched
    )
  }
}

// MARK: - Scan ↔ ScanEntity

extension Scan {
  init(entity: ScanEntity) throws {
    guard let source = Scan.Source(rawValue: entity.source) else {
      throw CacheConvertError.unknownScanSource(entity.source)
    }
    let tapped: Scan.TappedField? = entity.fieldTapped.flatMap(Scan.TappedField.init(rawValue:))
    self.init(
      id:               entity.id,
      cardId:           entity.cardId,
      scannedAt:        entity.scannedAt,
      source:           source,
      ipCountry:        entity.ipCountry,
      userAgent:        entity.userAgent,
      convertedToLead:  entity.convertedToLead,
      fieldTapped:      tapped
    )
  }

  func toEntity(lastFetched: Date = .now) -> ScanEntity {
    ScanEntity(
      id:               id,
      cardId:           cardId,
      scannedAt:        scannedAt,
      source:           source.rawValue,
      ipCountry:        ipCountry,
      userAgent:        userAgent,
      convertedToLead:  convertedToLead,
      fieldTapped:      fieldTapped?.rawValue,
      lastFetched:      lastFetched
    )
  }
}
